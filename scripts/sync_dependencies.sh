#!/bin/bash

# Script to update external dependencies based on URLs in file headers
# This script will scan files in the LlamaSwiftExperimentalC folder,
# find URLs in the headers, and update the files with the latest content.

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_DIR="${PROJECT_DIR}/Sources/LlamaSwiftExperimentalC"

# Color codes for terminal output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Temporary directory for downloaded content
TMP_DIR=$(mktemp -d)
trap 'rm -rf "$TMP_DIR"' EXIT  # Clean up the temp directory on exit

# Function to log messages with color
log() {
  local color="$1"
  local message="$2"
  echo -e "${color}${message}${NC}"
}

# Function to extract URL from file header
extract_url() {
  local file="$1"
  local url_line=$(head -n 5 "$file" | grep -o "//.*https://.*" | head -n 1)
  echo "$url_line" | grep -o "https://.*" | tr -d '\r' | tr -d ' ' | head -n 1
}

# Function to convert GitHub URLs to raw content URLs
convert_to_raw_url() {
  local url="$1"
  if [[ "$url" == *"github.com"* && "$url" != *"raw.githubusercontent.com"* ]]; then
    echo "$url" | sed 's|github\.com|raw.githubusercontent.com|' | sed 's|/blob/|/|'
  else
    echo "$url"
  fi
}

# Function to download a file from URL
download_file() {
  local url="$1"
  local output_file="$2"
  curl -s -L -o "$output_file" "$url"
  return $?
}

# Function to process a single file
process_file() {
  local file="$1"
  local filename=$(basename "$file")
  log "$YELLOW" "Processing ${filename}..."
  
  # Extract URL from file header
  local url=$(extract_url "$file")
  
  if [[ -z "$url" ]]; then
    log "$YELLOW" "  No URL found in header"
    return 1  # This is a skipped file, not an error
  fi
  
  log "$NC" "  Found URL: ${url}"
  
  # Get raw URL for direct download
  local raw_url=$(convert_to_raw_url "$url")
  
  # Download the file
  log "$NC" "  Downloading from ${raw_url}..."
  local downloaded_file="${TMP_DIR}/${filename}"
  download_file "$raw_url" "$downloaded_file"
  
  if [ $? -ne 0 ] || [ ! -s "$downloaded_file" ]; then
    log "$RED" "  Failed to download or empty file"
    return 2
  fi
  
  # Check if there are actual differences (ignoring the URL line)
  local diff_count=$(diff -I "// .*https://" "$downloaded_file" "$file" | wc -l)
  
  if [ "$diff_count" -eq 0 ]; then
    log "$GREEN" "  File is already up-to-date"
    return 0
  fi
  
  # Format the URL with $SOURCE= prefix for better readability
  local formatted_url="// \$SOURCE=${url}"
  
  # Create a new file with the URL at the top followed by the downloaded content
  {
    echo "$formatted_url"
    cat "$downloaded_file"
  } > "${TMP_DIR}/${filename}.new"
  
  # Replace the original file with our new version
  mv "${TMP_DIR}/${filename}.new" "$file"
  
  log "$GREEN" "  Successfully updated $filename"
  return 0
}

# Main execution

log "$GREEN" "Starting sync of external dependencies"
log "$NC" "Scanning files in ${TARGET_DIR}..."

# Get a list of candidate files to check (cpp and h files)
FILES=$(find "${TARGET_DIR}" -type f \( -name "*.cpp" -o -name "*.h" -o -name "*.c" \))
UPDATED_COUNT=0
SKIPPED_COUNT=0
ERROR_COUNT=0

for file in $FILES; do
  process_file "$file"
  result=$?
  
  case $result in
    0) ((UPDATED_COUNT++)) ;;
    1) ((SKIPPED_COUNT++)) ;;
    *) ((ERROR_COUNT++)) ;;
  esac
done

echo
log "$GREEN" "Dependency sync complete!"
log "$NC" "Summary: ${GREEN}${UPDATED_COUNT} updated${NC}, ${YELLOW}${SKIPPED_COUNT} skipped${NC}, ${RED}${ERROR_COUNT} errors${NC}"