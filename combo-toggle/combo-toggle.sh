#!/bin/bash

# Copyright (c) 2026 Condorache Ștefan-Eugen
# 
# This software is released under the MIT License.

# Define standardized output tags for system logging
INFO="[INFO]"
SUCCESS="[SUCCESS]"
WARNING="[WARNING]"
ERROR="[ERROR]"

usage() {
    echo "Usage: combo-toggle {on|off|status}"
    echo "       on     - Enable Performance Mode (lock band/BSSID, disable powersave & BT scanning)"
    echo "       off    - Enable Search Mode (restore NetworkManager defaults)"
    echo "       status - Report which mode the active profile is currently in"
}

# Validate arguments
case "$1" in
    on|off|status) ;;
    -h|--help)
        usage
        exit 0
        ;;
    "")
        echo "$INFO No argument provided."
        usage
        exit 1
        ;;
    *)
        echo "$ERROR Invalid argument provided: $1"
        usage
        exit 1
        ;;
esac

# Verify the required tooling is present
for dep in nmcli bluetoothctl; do
    if ! command -v "$dep" >/dev/null 2>&1; then
        echo "$ERROR '$dep' not found. This script requires NetworkManager and BlueZ."
        exit 1
    fi
done

# 1. Detect the active Wi-Fi connection profile
# Strip the trailing type field instead of cutting on ':' so profile names containing colons survive
SSID=$(nmcli -t -f NAME,TYPE connection show --active |
       grep ':802-11-wireless$' | head -n 1 |
       sed -e 's/:802-11-wireless$//' -e 's/\\:/:/g')

if [ -z "$SSID" ]; then
    echo "$ERROR No active Wi-Fi connection detected."
    exit 1
fi

# 2. Check the current state of the profile to prevent redundant network drops
# We query the specific BSSID rule attached to the profile. If it has text, it is locked.
CURRENT_LOCK=$(nmcli -g 802-11-wireless.bssid connection show "$SSID")

# Report mode and exit
if [ "$1" == "status" ]; then
    if [ -n "$CURRENT_LOCK" ]; then
        # nmcli -g escapes the colons in a MAC address
        echo "$INFO Profile '$SSID': Performance Mode is ACTIVE (locked to BSSID ${CURRENT_LOCK//\\:/:})."
    else
        echo "$INFO Profile '$SSID': Search Mode is ACTIVE (default roaming behaviour)."
    fi
    exit 0
fi

if [ "$1" == "on" ] && [ -n "$CURRENT_LOCK" ]; then
    echo "$INFO Hardware is already isolated. Performance Mode is currently ACTIVE."
    echo "        Aborting to prevent unnecessary network interruption."
    exit 0
elif [ "$1" == "off" ] && [ -z "$CURRENT_LOCK" ]; then
    echo "$INFO Hardware is already running default configurations. Search Mode is currently ACTIVE."
    echo "        Aborting to prevent unnecessary network interruption."
    exit 0
fi

echo "$SUCCESS Active connection identified. Variable [SSID] recorded as: $SSID"

# Process Performance Mode
if [ "$1" == "on" ]; then
    
    WIFI_INFO=$(nmcli -f IN-USE,BSSID,FREQ device wifi list | grep '^\*')
    BSSID=$(echo "$WIFI_INFO" | awk '{print $2}')
    FREQ=$(echo "$WIFI_INFO" | awk '{print $3}')

    # Without a BSSID the modify call below would silently clear the lock instead of setting it
    if [[ ! "$BSSID" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        echo "$ERROR Could not read the BSSID of the active access point."
        echo "        Aborting to avoid writing an empty lock to the profile."
        exit 1
    fi

    echo "$SUCCESS Hardware parameters extracted. Variable [BSSID] recorded as: $BSSID"
    
    if [[ "$FREQ" == 5* ]]; then
        BAND="a"
        echo "$INFO 5 GHz Wi-Fi frequency detected."
    elif [[ "$FREQ" == 2* ]]; then
        BAND="bg"
        echo "$WARNING [DIAGNOSTIC RECOMMENDATION]"
        echo "          Wi-Fi and Bluetooth are sharing the 2.4 GHz band."
        echo "          Script will optimize traffic, but switching to a 5 GHz network is recommended."
    else
        BAND=""
    fi

    echo "$INFO Initializing hardware lockdown (Performance Mode)..."
    
    if [ -n "$BAND" ]; then
        nmcli connection modify "$SSID" 802-11-wireless.band "$BAND"
    fi
    nmcli connection modify "$SSID" 802-11-wireless.bssid "$BSSID"
    nmcli connection modify "$SSID" 802-11-wireless.powersave 2
    
    if ! nmcli connection up "$SSID" > /dev/null; then
        echo "$ERROR Failed to bring the connection back up. Run 'combo-toggle off' to restore defaults."
        exit 1
    fi
    echo "$SUCCESS NetworkManager profile updated and connection restarted successfully."
    
    bluetoothctl discoverable off > /dev/null
    bluetoothctl pairable off > /dev/null
    echo "$SUCCESS Bluetooth adapter scanning protocols disabled."
    
    echo "$SUCCESS Performance Mode initialization complete."

# Process Search Mode
elif [ "$1" == "off" ]; then
    echo "$INFO Restoring default hardware configuration (Search Mode) for profile: $SSID..."
    
    nmcli connection modify "$SSID" 802-11-wireless.band ""
    nmcli connection modify "$SSID" 802-11-wireless.bssid ""
    nmcli connection modify "$SSID" 802-11-wireless.powersave 0
    
    if ! nmcli connection up "$SSID" > /dev/null; then
        echo "$ERROR Failed to bring the connection back up. Check 'nmcli connection show'."
        exit 1
    fi
    echo "$SUCCESS NetworkManager profile parameters cleared. Connection restarted."
    
    bluetoothctl discoverable on > /dev/null
    bluetoothctl pairable on > /dev/null
    echo "$SUCCESS Bluetooth adapter scanning protocols enabled."
    
    echo "$SUCCESS Search Mode initialization complete."
fi