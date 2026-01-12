#!/bin/bash

# Cleanup script to remove older Navigator versions
# Keeps only the latest version of packages and DMGs

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Cleaning up old Navigator versions...${NC}"
echo ""

# Find all Navigator packages
PKG_FILES=($(ls -t Navigator-*.pkg 2>/dev/null))
DMG_FILES=($(ls -t navigator-*-mac-arm64.dmg 2>/dev/null))

# Function to extract version number from filename
extract_version() {
    echo "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# Function to compare versions (returns 1 if v1 > v2, 0 if equal, -1 if v1 < v2)
version_compare() {
    local v1=$1
    local v2=$2
    
    # Split versions into arrays
    IFS='.' read -ra V1 <<< "$v1"
    IFS='.' read -ra V2 <<< "$v2"
    
    # Compare each component
    for i in {0..2}; do
        if [[ ${V1[$i]} -gt ${V2[$i]} ]]; then
            echo 1
            return
        elif [[ ${V1[$i]} -lt ${V2[$i]} ]]; then
            echo -1
            return
        fi
    done
    echo 0
}

# Find latest package version
LATEST_PKG_VERSION=""
LATEST_PKG_FILE=""
if [[ ${#PKG_FILES[@]} -gt 0 ]]; then
    for file in "${PKG_FILES[@]}"; do
        version=$(extract_version "$file")
        if [[ -z "$LATEST_PKG_VERSION" ]]; then
            LATEST_PKG_VERSION=$version
            LATEST_PKG_FILE=$file
        else
            comparison=$(version_compare "$version" "$LATEST_PKG_VERSION")
            if [[ $comparison -gt 0 ]]; then
                LATEST_PKG_VERSION=$version
                LATEST_PKG_FILE=$file
            fi
        fi
    done
fi

# Find latest DMG version
LATEST_DMG_VERSION=""
LATEST_DMG_FILE=""
if [[ ${#DMG_FILES[@]} -gt 0 ]]; then
    for file in "${DMG_FILES[@]}"; do
        version=$(extract_version "$file")
        if [[ -z "$LATEST_DMG_VERSION" ]]; then
            LATEST_DMG_VERSION=$version
            LATEST_DMG_FILE=$file
        else
            comparison=$(version_compare "$version" "$LATEST_DMG_VERSION")
            if [[ $comparison -gt 0 ]]; then
                LATEST_DMG_VERSION=$version
                LATEST_DMG_FILE=$file
            fi
        fi
    done
fi

# Remove old packages
if [[ ${#PKG_FILES[@]} -gt 0 ]]; then
    echo -e "${YELLOW}Packages found:${NC}"
    for file in "${PKG_FILES[@]}"; do
        if [[ "$file" == "$LATEST_PKG_FILE" ]]; then
            echo -e "  ${GREEN}KEEP: $file (latest)${NC}"
        else
            echo -e "  ${RED}DELETE: $file${NC}"
            rm -f "$file"
        fi
    done
    echo ""
fi

# Remove old DMGs
if [[ ${#DMG_FILES[@]} -gt 0 ]]; then
    echo -e "${YELLOW}DMG files found:${NC}"
    for file in "${DMG_FILES[@]}"; do
        if [[ "$file" == "$LATEST_DMG_FILE" ]]; then
            echo -e "  ${GREEN}KEEP: $file (latest)${NC}"
        else
            echo -e "  ${RED}DELETE: $file${NC}"
            rm -f "$file"
        fi
    done
    echo ""
fi

# Summary
if [[ ${#PKG_FILES[@]} -eq 0 ]] && [[ ${#DMG_FILES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No Navigator files found to clean up.${NC}"
else
    echo -e "${GREEN}✓ Cleanup complete!${NC}"
    if [[ -n "$LATEST_PKG_VERSION" ]]; then
        echo -e "${GREEN}Latest package: Navigator-${LATEST_PKG_VERSION}.pkg${NC}"
    fi
    if [[ -n "$LATEST_DMG_VERSION" ]]; then
        echo -e "${GREEN}Latest DMG: navigator-${LATEST_DMG_VERSION}-mac-arm64.dmg${NC}"
    fi
fi
