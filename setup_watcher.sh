#!/bin/bash

# Setup script for Navigator version watcher
# This script installs/uninstalls the launchd service

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLIST_NAME="com.navigator.watcher.plist"
PLIST_SOURCE="$SCRIPT_DIR/$PLIST_NAME"
PLIST_DEST="$HOME/Library/LaunchAgents/$PLIST_NAME"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

case "${1:-}" in
    install)
        echo -e "${BLUE}Installing Navigator version watcher...${NC}"
        
        # Check if plist exists
        if [[ ! -f "$PLIST_SOURCE" ]]; then
            echo -e "${RED}Error: $PLIST_SOURCE not found${NC}"
            exit 1
        fi
        
        # Create LaunchAgents directory if it doesn't exist
        mkdir -p "$HOME/Library/LaunchAgents"
        
        # Update paths in plist to match current directory and copy to destination
        echo -e "${YELLOW}Creating plist with updated paths...${NC}"
        sed "s|/Users/huxley-47/dev/package-nav|$SCRIPT_DIR|g" "$PLIST_SOURCE" > "$PLIST_DEST"
        
        # Load the service
        echo -e "${YELLOW}Loading launchd service...${NC}"
        launchctl load "$PLIST_DEST" 2>/dev/null || launchctl bootstrap "gui/$UID" "$PLIST_DEST"
        
        echo -e "${GREEN}✓ Watcher installed successfully!${NC}"
        echo -e "${GREEN}The watcher will check for new versions every hour.${NC}"
        echo -e "${YELLOW}To check status: launchctl list | grep navigator${NC}"
        echo -e "${YELLOW}To view logs: tail -f $SCRIPT_DIR/watch.log${NC}"
        ;;
        
    uninstall)
        echo -e "${BLUE}Uninstalling Navigator version watcher...${NC}"
        
        # Unload the service
        if [[ -f "$PLIST_DEST" ]]; then
            echo -e "${YELLOW}Unloading launchd service...${NC}"
            launchctl unload "$PLIST_DEST" 2>/dev/null || launchctl bootout "gui/$UID" "$PLIST_DEST" 2>/dev/null || true
        fi
        
        # Remove plist
        if [[ -f "$PLIST_DEST" ]]; then
            echo -e "${YELLOW}Removing plist file...${NC}"
            rm -f "$PLIST_DEST"
        fi
        
        echo -e "${GREEN}✓ Watcher uninstalled successfully!${NC}"
        ;;
        
    status)
        echo -e "${BLUE}Navigator watcher status:${NC}"
        if launchctl list | grep -q "com.navigator.watcher"; then
            echo -e "${GREEN}✓ Watcher is running${NC}"
            launchctl list | grep "com.navigator.watcher"
        else
            echo -e "${RED}✗ Watcher is not running${NC}"
        fi
        
        if [[ -f "$SCRIPT_DIR/.last_version" ]]; then
            LAST_VERSION=$(cat "$SCRIPT_DIR/.last_version")
            echo -e "${BLUE}Last processed version: $LAST_VERSION${NC}"
        else
            echo -e "${YELLOW}No version has been processed yet${NC}"
        fi
        ;;
        
    test)
        echo -e "${BLUE}Running watcher test...${NC}"
        "$SCRIPT_DIR/watch_navigator.sh"
        ;;
        
    *)
        echo "Usage: $0 {install|uninstall|status|test}"
        echo ""
        echo "Commands:"
        echo "  install   - Install the watcher as a launchd service"
        echo "  uninstall - Remove the watcher service"
        echo "  status   - Check if the watcher is running"
        echo "  test     - Run the watcher once manually"
        exit 1
        ;;
esac

