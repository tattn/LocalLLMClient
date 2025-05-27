#!/bin/bash

set -e

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
PACKAGE_FILE="$PROJECT_ROOT/Package.swift"

cd "$PROJECT_ROOT/scripts"

echo "Fetching latest release from ggml-org/llama.cpp..."

if [ -n "$GITHUB_TOKEN" ]; then
    LATEST_TAG=$(curl -s -H "Authorization: Bearer $GITHUB_TOKEN" "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
else
    LATEST_TAG=$(curl -s "https://api.github.com/repos/ggml-org/llama.cpp/releases/latest" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
fi

if [ -z "$LATEST_TAG" ]; then
    echo "Error: Could not fetch the latest release tag"
    exit 1
fi

echo "Latest release tag: $LATEST_TAG"

CURRENT_VERSION=$("$PROJECT_ROOT/scripts/get_llama_version.sh")

echo "Current version: $CURRENT_VERSION"

if [ "$CURRENT_VERSION" = "$LATEST_TAG" ]; then
    echo "Already using the latest version. No update needed."
    exit 0
fi

TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

XC_FRAMEWORK_FILE="llama-${LATEST_TAG}-xcframework.zip"
XC_FRAMEWORK_URL="https://github.com/ggml-org/llama.cpp/releases/download/${LATEST_TAG}/${XC_FRAMEWORK_FILE}"

echo "Downloading $XC_FRAMEWORK_URL..."
curl -L -o "$XC_FRAMEWORK_FILE" "$XC_FRAMEWORK_URL"

echo "Computing checksum..."
CHECKSUM=$(swift package compute-checksum "$XC_FRAMEWORK_FILE")

echo "New checksum: $CHECKSUM"

# Update Package.swift - version
sed -i '' "s/let llamaVersion = \"$CURRENT_VERSION\"/let llamaVersion = \"$LATEST_TAG\"/" "$PACKAGE_FILE"

# Update Package.swift - checksum
sed -i '' "s/checksum: \"[a-f0-9]*\"/checksum: \"$CHECKSUM\"/" "$PACKAGE_FILE"

# Clean up
cd "$PROJECT_ROOT"
rm -rf "$TEMP_DIR"

echo "Package.swift has been updated to use llama.cpp version $LATEST_TAG"

echo "Updating git submodules..."
git fetch --tags
git -C "$PROJECT_ROOT/Sources/LocalLLMClientLlamaC/exclude/llama.cpp" checkout tags/$LATEST_TAG
echo "All submodules have been updated."