#!/bin/bash

INFO="[INFO]"
SUCCESS="[SUCCESS]"
WARNING="[WARNING]"
ERROR="[ERROR]"


# 1. DISCLAIMER & USER CONSENT
echo "==========================================================="
echo "             COMBO-TOGGLE AUTOMATED INSTALLER              "
echo "==========================================================="
echo "$WARNING DISCLAIMER & TERMS OF USE"
echo "This installer will copy the 'combo-toggle.sh' script to your"
echo "system's binary directory (/usr/local/bin/) so it can be run"
echo "as a standard command."
echo ""
echo "This tool modifies NetworkManager and Bluetooth states. By"
echo "proceeding, you acknowledge that you understand what this script"
echo "does and accept full responsibility for its installation and use."
echo "==========================================================="

read -p "Do you want to continue? (y/N): " CONSENT

if [[ "$CONSENT" != "y" && "$CONSENT" != "Y" ]]; then
    echo "$INFO Installation aborted."
    exit 0
fi

# 2. VERIFY SOURCE FILE
if [ ! -f "combo-toggle.sh" ]; then
    echo "$ERROR 'combo-toggle.sh' not found in the current directory."
    echo "        Please ensure both files are in the same folder."
    exit 1
fi

echo ""
echo "$INFO Beginning installation..."
echo "$INFO You may be prompted for your sudo password to write to /usr/local/bin."

# 3. INSTALL & SET PERMISSIONS
TARGET_PATH="/usr/local/bin/combo-toggle"

# Copy the file to the binaries folder (dropping the .sh extension for clean command line use)
sudo cp combo-toggle.sh "$TARGET_PATH"

# Make the copied file executable
sudo chmod +x "$TARGET_PATH"

# Verify the file exists and is executable
if [ -x "$TARGET_PATH" ]; then
    echo "$SUCCESS Installation complete! The script has been deployed to $TARGET_PATH."
    echo "$INFO Usage: combo-toggle {on|off}"
    echo "       on  - Enable Performance Mode"
    echo "       off - Enable Search Mode"
else
    echo "$ERROR Installation failed. Could not verify target executable."
    exit 1
fi