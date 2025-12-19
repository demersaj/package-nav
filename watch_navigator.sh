#!/bin/bash

# Navigator Version Watcher
# This script checks for new Navigator versions and automatically runs pkg_nav.sh

set -e

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load .env file if it exists
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
    set -a
    TEMP_ENV=$(mktemp)
    grep -v '^[[:space:]]*#' "$ENV_FILE" | grep -v '^[[:space:]]*$' > "$TEMP_ENV"
    source "$TEMP_ENV"
    rm -f "$TEMP_ENV"
    set +a
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Version tracking file
VERSION_FILE="$SCRIPT_DIR/.last_version"
LOG_FILE="$SCRIPT_DIR/watch.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if JSON_URL is set
if [[ -z "$JSON_URL" ]]; then
    log "${RED}Error: JSON_URL environment variable is not set${NC}"
    exit 1
fi

log "${BLUE}Checking for new Navigator version...${NC}"

# Fetch the latest version info
JSON_DATA=$(curl -s "$JSON_URL" || echo "")

if [[ -z "$JSON_DATA" ]]; then
    log "${RED}Error: Failed to fetch version information${NC}"
    exit 1
fi

# Parse JSON to get version
VERSION=$(echo "$JSON_DATA" | grep -o '"version": *"[^"]*"' | head -1 | sed 's/"version": *"\([^"]*\)"/\1/')

if [[ -z "$VERSION" ]]; then
    log "${RED}Error: Failed to parse version from JSON${NC}"
    exit 1
fi

log "${BLUE}Latest version available: $VERSION${NC}"

# Check if we have a stored version
LAST_VERSION=""
if [[ -f "$VERSION_FILE" ]]; then
    LAST_VERSION=$(cat "$VERSION_FILE" | tr -d '[:space:]')
fi

# Compare versions
if [[ "$VERSION" == "$LAST_VERSION" ]]; then
    log "${GREEN}No new version detected. Current version: $VERSION${NC}"
    exit 0
fi

# New version detected!
if [[ -z "$LAST_VERSION" ]]; then
    log "${YELLOW}First run detected. Version: $VERSION${NC}"
else
    log "${YELLOW}New version detected! Updating from $LAST_VERSION to $VERSION${NC}"
fi

# Update the version file
echo "$VERSION" > "$VERSION_FILE"

# Run the packaging script
log "${GREEN}Starting package creation for version $VERSION...${NC}"

# Change to script directory and run pkg_nav.sh
cd "$SCRIPT_DIR"
if [[ -f "$SCRIPT_DIR/pkg_nav.sh" ]]; then
    bash "$SCRIPT_DIR/pkg_nav.sh" 2>&1 | tee -a "$LOG_FILE"
    EXIT_CODE=${PIPESTATUS[0]}
    
    if [[ $EXIT_CODE -eq 0 ]]; then
        log "${GREEN}✓ Package creation completed successfully for version $VERSION${NC}"
    else
        log "${RED}✗ Package creation failed for version $VERSION (exit code: $EXIT_CODE)${NC}"
        exit $EXIT_CODE
    fi
else
    log "${RED}Error: pkg_nav.sh not found at $SCRIPT_DIR/pkg_nav.sh${NC}"
    exit 1
fi

