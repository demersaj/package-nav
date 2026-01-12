#!/bin/bash

# Navigator App Update Script with PKG Creation
set -e  # Exit on any error

# Capture the original directory where the script was run from
ORIGINAL_DIR="$(pwd)"

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load .env file if it exists
ENV_FILE="$SCRIPT_DIR/.env"
if [[ -f "$ENV_FILE" ]]; then
    echo "Loading environment variables from .env file..."
    # Export variables from .env file, ignoring comments and empty lines
    # Using set -a to automatically export all variables
    set -a
    # Create a temporary file with cleaned content (no comments, no empty lines)
    TEMP_ENV=$(mktemp)
    grep -v '^[[:space:]]*#' "$ENV_FILE" | grep -v '^[[:space:]]*$' > "$TEMP_ENV"
    source "$TEMP_ENV"
    rm -f "$TEMP_ENV"
    set +a
fi

# Configuration
APP_NAME="Navigator"
#DMG_URL="https://example.com/path/to/Navigator.dmg"  # Replace with actual URL

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Sensitive configuration from environment variables
COMPANY_NAME="${COMPANY_NAME:-}"
TEAM_ID="${TEAM_ID:-}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"
JSON_URL="${JSON_URL:-}"

# Validate required environment variables
if [[ -z "$COMPANY_NAME" ]]; then
    echo -e "${RED}Error: COMPANY_NAME environment variable is not set${NC}"
    exit 1
fi

if [[ -z "$TEAM_ID" ]]; then
    echo -e "${RED}Error: TEAM_ID environment variable is not set${NC}"
    exit 1
fi

if [[ -z "$NOTARY_PROFILE" ]]; then
    echo -e "${RED}Error: NOTARY_PROFILE environment variable is not set${NC}"
    exit 1
fi

if [[ -z "$JSON_URL" ]]; then
    echo -e "${RED}Error: JSON_URL environment variable is not set${NC}"
    exit 1
fi

DEVELOPER_ID_INSTALLER="Developer ID Installer: $COMPANY_NAME ($TEAM_ID)"

echo -e "${YELLOW}Starting Navigator app update and packaging process...${NC}"

# Create temporary workspace
TEMP_DIR=$(mktemp -d)
echo "Created temp directory: $TEMP_DIR"


# Download the latest Navigator DMG automatically

set -e

echo "Navigator Latest Version Downloader"
echo "========================================"
echo ""

# Fetch the latest version info
echo "Fetching latest version info..."
JSON_DATA=$(curl -s "$JSON_URL")

# Parse JSON using grep and sed (works without jq)
VERSION=$(echo "$JSON_DATA" | grep -o '"version": *"[^"]*"' | head -1 | sed 's/"version": *"\([^"]*\)"/\1/')
DMG_URL=$(echo "$JSON_DATA" | grep -o '"url": *"[^"]*"' | head -1 | sed 's/"url": *"\([^"]*\)"/\1/')
SHA256=$(echo "$JSON_DATA" | grep -o '"sha256": *"[^"]*"' | head -1 | sed 's/"sha256": *"\([^"]*\)"/\1/')

# Validate that version was extracted
if [[ -z "$VERSION" ]]; then
    echo -e "${RED}Error: Failed to extract version from JSON response${NC}"
    exit 1
fi

# Extract filename from URL
FILENAME=$(basename "$DMG_URL")

echo "Latest version: $VERSION"
echo "Download URL: $DMG_URL"
echo "SHA256: $SHA256"
echo ""

# Download the file
echo "Downloading $FILENAME..."
curl -# -L -o "$FILENAME" "$DMG_URL"

echo ""
echo "✓ Download complete!"
echo "Saved to: $(pwd)/$FILENAME"
echo ""
echo "You can verify the download with:"
echo "  shasum -a 256 $FILENAME"
echo "Expected: $SHA256"
echo ""


# Cleanup function
cleanup() {
    echo -e "${YELLOW}Cleaning up...${NC}"
    if [[ -d "$TEMP_DIR" ]]; then
        # Unmount DMG if still mounted
        if [[ -d "/Volumes/$APP_NAME" ]]; then
            hdiutil detach "/Volumes/$APP_NAME" -force 2>/dev/null || true
        fi
        rm -rf "$TEMP_DIR"
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Step 1: Download the latest DMG
echo -e "${YELLOW}Step 1: Downloading latest Navigator DMG...${NC}"
DMG_PATH="$TEMP_DIR/Navigator.dmg"
curl -L -o "$DMG_PATH" "$DMG_URL"

# Verify download
if [[ ! -f "$DMG_PATH" ]]; then
    echo -e "${RED}Error: Failed to download DMG${NC}"
    exit 1
fi

# Step 2: Mount DMG and extract app
echo -e "${YELLOW}Step 2: Extracting application from DMG...${NC}"
hdiutil attach "$DMG_PATH" -nobrowse -mountpoint "/Volumes/$APP_NAME"

# Copy app to temp directory
APP_SOURCE="/Volumes/$APP_NAME/$APP_NAME.app"
APP_PATH="$TEMP_DIR/$APP_NAME.app"

if [[ ! -d "$APP_SOURCE" ]]; then
    echo -e "${RED}Error: $APP_NAME.app not found in DMG${NC}"
    exit 1
fi

cp -R "$APP_SOURCE" "$APP_PATH"

# Unmount DMG
hdiutil detach "/Volumes/$APP_NAME"

# Step 3: Verify the app and check code signing
echo -e "${YELLOW}Step 3: Verifying application and code signing...${NC}"
if [[ ! -d "$APP_PATH" ]]; then
    echo -e "${RED}Error: Application copy failed${NC}"
    exit 1
fi

# Test if app executable exists
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/$APP_NAME"
if [[ ! -f "$EXECUTABLE_PATH" ]]; then
    echo -e "${RED}Error: App executable not found${NC}"
    exit 1
fi

# Make executable if needed
chmod +x "$EXECUTABLE_PATH"



echo -e "${GREEN}✓ Developer ID Installer certificate found${NC}"

# Step 5: Create signed package using productbuild
echo -e "${YELLOW}Step 5: Creating signed package with productbuild...${NC}"
PKG_PATH="$TEMP_DIR/$APP_NAME.pkg"

# Sanitize version string for use in filename (replace spaces, special chars with hyphens)
SANITIZED_VERSION=$(echo "$VERSION" | sed 's/[^a-zA-Z0-9._-]/-/g' | sed 's/--*/-/g' | sed 's/^-\|-$//g')
FINAL_PKG_PATH="$ORIGINAL_DIR/$APP_NAME-${SANITIZED_VERSION}.pkg"

echo -e "${GREEN}Package will be named: $(basename "$FINAL_PKG_PATH")${NC}"
echo "Creating package with command:"
echo "productbuild --component \"$APP_PATH\" /Applications --sign \"$DEVELOPER_ID_INSTALLER\" \"$PKG_PATH\""

productbuild --component "$APP_PATH" /Applications --sign "$DEVELOPER_ID_INSTALLER" "$PKG_PATH"

# Step 6: Verify package signature
echo -e "${YELLOW}Step 6: Verifying package signature...${NC}"
SIGNATURE_CHECK=$(pkgutil --check-signature "$PKG_PATH")
echo "$SIGNATURE_CHECK"

if ! echo "$SIGNATURE_CHECK" | grep -q "signed by a developer certificate issued by Apple for distribution"; then
    echo -e "${RED}Error: Package signature verification failed${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Package signature verified${NC}"

# Step 7: Notarize the package
echo -e "${YELLOW}Step 7: Submitting package for notarization...${NC}"
NOTARIZATION_OUTPUT=$(xcrun notarytool submit "$PKG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait)

if echo "$NOTARIZATION_OUTPUT" | grep -q "status: Accepted"; then
    echo -e "${GREEN}✓ Notarization successful${NC}"
else
    echo -e "${RED}Error: Notarization failed${NC}"
    echo "$NOTARIZATION_OUTPUT"
    exit 1
fi

# Pre-stapling validation checks
echo -e "${YELLOW}Pre-stapling validation checks...${NC}"

# Check if package still exists and is accessible
if [[ ! -f "$PKG_PATH" ]]; then
    echo -e "${RED}Error: Package file not found at $PKG_PATH${NC}"
    exit 1
fi

# Check package signature before stapling
echo -e "${YELLOW}Checking package signature before stapling...${NC}"
PRE_STAPLE_SIGNATURE=$(pkgutil --check-signature "$PKG_PATH" 2>&1)
if ! echo "$PRE_STAPLE_SIGNATURE" | grep -q "signed by a developer certificate issued by Apple for distribution"; then
    echo -e "${RED}Error: Package signature invalid before stapling${NC}"
    echo "$PRE_STAPLE_SIGNATURE"
    exit 1
fi

echo -e "${GREEN}✓ Pre-stapling checks passed${NC}"

# Step 8: Staple notarization ticket
echo -e "${YELLOW}Step 8: Stapling notarization ticket...${NC}"
STAPLE_OUTPUT=$(xcrun stapler staple "$PKG_PATH" 2>&1)
STAPLE_EXIT_CODE=$?

if [[ $STAPLE_EXIT_CODE -ne 0 ]]; then
    echo -e "${RED}Error: Failed to staple notarization ticket${NC}"
    echo "$STAPLE_OUTPUT"
    exit 1
fi

echo -e "${GREEN}✓ Notarization ticket stapled successfully${NC}"

# Step 9: Check package signature after stapling
echo -e "${YELLOW}Step 9: Checking package signature after stapling...${NC}"
POST_STAPLE_SIGNATURE=$(pkgutil --check-signature "$PKG_PATH" 2>&1)
echo "Post-stapling signature check:"
echo "$POST_STAPLE_SIGNATURE"

if ! echo "$POST_STAPLE_SIGNATURE" | grep -q "signed by a developer certificate issued by Apple for distribution"; then
    echo -e "${RED}Error: Package signature invalid after stapling${NC}"
    echo -e "${YELLOW}This may indicate the stapling process corrupted the package signature${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Package signature valid after stapling${NC}"

# Step 10: Validate notarization
echo -e "${YELLOW}Step 10: Validating notarization...${NC}"
VALIDATION_OUTPUT=$(xcrun stapler validate "$PKG_PATH" 2>&1)
VALIDATION_EXIT_CODE=$?

echo "Validation output:"
echo "$VALIDATION_OUTPUT"

# Check for various success indicators
if [[ $VALIDATION_EXIT_CODE -eq 0 ]] && (echo "$VALIDATION_OUTPUT" | grep -q "validated\|accepted\|success\|worked" || [[ -z "$VALIDATION_OUTPUT" ]]); then
    echo -e "${GREEN}✓ Notarization validation successful${NC}"
else
    echo -e "${RED}Error: Notarization validation failed${NC}"
    echo -e "${YELLOW}Validation exit code: $VALIDATION_EXIT_CODE${NC}"
    
    # Additional debugging information
    echo -e "\n${YELLOW}Additional debugging information:${NC}"
    echo "Package path: $PKG_PATH"
    echo "Package exists: $(test -f "$PKG_PATH" && echo "Yes" || echo "No")"
    
    # Check if package is still signed after stapling
    echo -e "\n${YELLOW}Package signature after stapling:${NC}"
    pkgutil --check-signature "$PKG_PATH"
    
    # Try alternative validation method
    echo -e "\n${YELLOW}Alternative validation with spctl:${NC}"
    spctl --assess -vvv --type install "$PKG_PATH" 2>&1 || echo "spctl validation also failed"
    
    exit 1
fi

# Step 11: Move to final location
mv "$PKG_PATH" "$FINAL_PKG_PATH"

echo -e "${GREEN}✅ Update process completed successfully!${NC}"
echo -e "${GREEN}✅ Package created: $FINAL_PKG_PATH${NC}"
echo -e "${GREEN}✅ Package is signed, notarized, and ready for distribution${NC}"

# Display final package info
echo -e "\n${YELLOW}Final package information:${NC}"
pkgutil --check-signature "$FINAL_PKG_PATH"

# Create installation command example
echo -e "\n${YELLOW}Installation command:${NC}"
echo "sudo installer -pkg \"$FINAL_PKG_PATH\" -target /Applications"

# Step 12:Clean up old Navigator files
echo -e "\n${YELLOW}Step 11: Cleaning up old Navigator files...${NC}"
./cleanup_old_versions.sh
