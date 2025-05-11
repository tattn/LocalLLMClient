#!/bin/bash

DERIVED_DATA_PATH="./DerivedData"
CONFIGURATION="Debug"
BINARY_PATH="${DERIVED_DATA_PATH}/Build/Products/${CONFIGURATION}/localllm"

# Check if the binary exists and is executable
if [ ! -x "${BINARY_PATH}" ]; then
  echo "Building localllm..."
  xcodebuild -scheme localllm -configuration ${CONFIGURATION} -derivedDataPath "${DERIVED_DATA_PATH}" \
    -destination 'platform=macOS,arch=arm64' build -quiet
fi

# Run
"${BINARY_PATH}" --backend mlx "$@"