#!/bin/bash

# Configuration
SOURCE_FILE="connect_bt.sh"
TARGET_DIR="/usr/local/bin"
COMMAND_NAME="connect_bt"

# Define colors for output
CYAN='\033[0;36m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${CYAN}==========================================${NC}"
echo -e "${CYAN}   Bluetooth Manager Installer            ${NC}"
echo -e "${CYAN}==========================================${NC}"

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[ERROR] Please run this installer with root privileges.${NC}"
  echo -e "Usage: sudo ./install.sh"
  exit 1
fi

# Check if the source script exists in the current directory
if [ ! -f "$SOURCE_FILE" ]; then
  echo -e "${RED}[ERROR] $SOURCE_FILE not found in the current directory.${NC}"
  echo "Please run this installer from the same folder as the script."
  exit 1
fi

echo -e "[INFO] Installing to ${TARGET_DIR}/${COMMAND_NAME}..."

# Copy the file and strip the .sh extension for a cleaner command
cp "$SOURCE_FILE" "${TARGET_DIR}/${COMMAND_NAME}"

# Ensure the newly copied file is executable
chmod +x "${TARGET_DIR}/${COMMAND_NAME}"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}[SUCCESS] Installation complete!${NC}"
    echo -e "\nYou can now run the tool from anywhere by typing:\n  ${GREEN}${COMMAND_NAME}${NC}\n"
else
    echo -e "${RED}[ERROR] Failed to copy the file to ${TARGET_DIR}.${NC}"
    exit 1
fi