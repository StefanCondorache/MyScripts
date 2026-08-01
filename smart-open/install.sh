#!/bin/bash

# Copyright (c) 2026 Condorache Ștefan-Eugen
#
# This software is released under the MIT License.

# Configuration
SOURCE_FILE="smart-open.sh"
TARGET_PATH="/usr/local/bin/smart-open"

INFO="[INFO]"
SUCCESS="[SUCCESS]"
WARNING="[WARNING]"
ERROR="[ERROR]"

# 1. DISCLAIMER & USER CONSENT
echo "==========================================================="
echo "               SMART-OPEN AUTOMATED INSTALLER              "
echo "==========================================================="
echo "$WARNING DISCLAIMER & TERMS OF USE"
echo "This installer will copy the 'smart-open.sh' script to your"
echo "system's binary directory ($TARGET_PATH) so it can be run"
echo "as a standard system-wide command."
echo ""
echo "This tool launches your desktop applications on demand."
echo "By proceeding, you accept full responsibility for its use."
echo "==========================================================="

read -p "Do you want to continue? (y/N): " CONSENT

if [[ "$CONSENT" != "y" && "$CONSENT" != "Y" ]]; then
    echo "$INFO Installation aborted."
    exit 0
fi

# 2. VERIFY SOURCE FILE EXISTS
if [ ! -f "$SOURCE_FILE" ]; then
    echo "$ERROR '$SOURCE_FILE' not found in the current directory."
    echo "        Please ensure both files are in the same folder."
    exit 1
fi

# 3. CHECK DEPENDENCIES
if ! command -v xdg-open >/dev/null 2>&1; then
    echo "$WARNING 'xdg-open' not found (package: xdg-utils). The command will"
    echo "          install, but it cannot open files until you add it."
fi

echo ""
echo "$INFO Beginning installation..."
echo "$INFO You may be prompted for your sudo password to write to /usr/local/bin."

# 4. DEPLOY & SET PERMISSIONS
# Copy the file to the binaries folder (dropping the .sh extension for a clean CLI command)
sudo cp "$SOURCE_FILE" "$TARGET_PATH"
sudo chmod +x "$TARGET_PATH"

# Verify the file exists and is executable
if [ -x "$TARGET_PATH" ]; then
    echo ""
    echo "$SUCCESS Installation complete! The script has been deployed to $TARGET_PATH."
    echo "$INFO Usage: smart-open [file|directory ...]"
    echo "       Running 'smart-open' without arguments opens the current directory."
    echo "$INFO Tip: alias o='smart-open' in your ~/.bashrc for a one-letter opener."
else
    echo "$ERROR Installation failed. Could not verify target executable."
    exit 1
fi
