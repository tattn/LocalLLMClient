#!/bin/bash

# get_llama_version.sh
# This script retrieves the current llama.cpp version from Package.swift

set -e

if [ "$#" -eq 0 ]; then
    # If no arguments provided, use parent directory of the script
    PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
else
    # Use the provided path as the project root
    PROJECT_ROOT="$1"
fi

PACKAGE_FILE="$PROJECT_ROOT/Package.swift"

# Get the current version from Package.swift using grep and sed
# This pattern specifically looks for the let llamaVersion = "b5486" format
CURRENT_VERSION=$(grep -E "let llamaVersion = \"[a-zA-Z0-9]+\"" "$PACKAGE_FILE" | sed -E 's/.*"([a-zA-Z0-9]+)".*/\1/')

# Print the version to stdout
echo "$CURRENT_VERSION"
