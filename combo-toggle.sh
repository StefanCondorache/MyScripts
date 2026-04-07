#!/bin/bash

# Define standardized output tags for system logging
INFO="[INFO]"
SUCCESS="[SUCCESS]"
WARNING="[WARNING]"
ERROR="[ERROR]"

# Validate arguments
if [ -z "$1" ]; then
    echo "$INFO Usage: combo-toggle {on|off}"
    echo "       on  - Enable Performance Mode"
    echo "       off - Enable Search Mode"
    exit 1
fi

# 1. Detect the active Wi-Fi connection profile
SSID=$(nmcli -t -f NAME,TYPE connection show --active | grep 802-11-wireless | head -n 1 | cut -d: -f1)

if [ -z "$SSID" ]; then
    echo "$ERROR No active Wi-Fi connection detected."
    exit 1
fi

# 2. Check the current state of the profile to prevent redundant network drops
# We query the specific BSSID rule attached to the profile. If it has text, it is locked.
CURRENT_LOCK=$(nmcli -g 802-11-wireless.bssid connection show "$SSID")

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
    
    nmcli connection up "$SSID" > /dev/null
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
    
    nmcli connection up "$SSID" > /dev/null
    echo "$SUCCESS NetworkManager profile parameters cleared. Connection restarted."
    
    bluetoothctl discoverable on > /dev/null
    bluetoothctl pairable on > /dev/null
    echo "$SUCCESS Bluetooth adapter scanning protocols enabled."
    
    echo "$SUCCESS Search Mode initialization complete."

else
    echo "$ERROR Invalid argument provided."
    exit 1
fi