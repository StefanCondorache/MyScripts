#!/bin/bash

# --- Configuration Variables ---
SSID="Steppan-wifi"
BSSID="52:51:F2:2F:7C:1D"
INTERFACE=$(iw dev | awk '$1=="Interface"{print $2}') # Auto-detects your wifi interface

# Check if an argument was provided
if [ -z "$1" ]; then
    echo "Usage: combo-toggle {on|off}"
    echo "  on  - Performance Mode (Locked 5GHz, No Scanning, No Power Save)"
    echo "  off - Search Mode (Default Scanning, Default Power Save)"
    exit 1
fi

if [ "$1" == "on" ]; then
    echo "Locking down combo chip (Performance Mode)..."
    
    # Wi-Fi Lockdown
    nmcli connection modify "$SSID" 802-11-wireless.band a
    nmcli connection modify "$SSID" 802-11-wireless.bssid "$BSSID"
    nmcli connection modify "$SSID" 802-11-wireless.powersave 2
    
    # Restart connection quietly
    nmcli connection up "$SSID" > /dev/null
    
    # Bluetooth Lockdown
    bluetoothctl discoverable off > /dev/null
    bluetoothctl pairable off > /dev/null
    
    echo "✅ Performance Mode: ACTIVE"

elif [ "$1" == "off" ]; then
    echo "Restoring combo chip (Search Mode)..."
    
    # Wi-Fi Reset (Empty quotes clear the locks)
    nmcli connection modify "$SSID" 802-11-wireless.band ""
    nmcli connection modify "$SSID" 802-11-wireless.bssid ""
    nmcli connection modify "$SSID" 802-11-wireless.powersave 0
    
    # Restart connection quietly
    nmcli connection up "$SSID" > /dev/null
    
    # Bluetooth Reset
    bluetoothctl discoverable on > /dev/null
    bluetoothctl pairable on > /dev/null
    
    echo "🔍 Search Mode: ACTIVE"

else
    echo "Invalid argument."
    echo "Usage: combo-toggle {on|off}"
    exit 1
fi