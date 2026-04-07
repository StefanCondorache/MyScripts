#!/bin/bash

# Check if an argument was provided
if [ -z "$1" ]; then
    echo "Usage: combo-toggle {on|off}"
    echo "  on  - Performance Mode (Locks current Wi-Fi & Bluetooth)"
    echo "  off - Search Mode (Restores default scanning)"
    exit 1
fi

# 1. Automatically detect the ACTIVE Wi-Fi connection name
# We use -t (terse format) to safely grab the name even if it has spaces
SSID=$(nmcli -t -f NAME,TYPE connection show --active | grep 802-11-wireless | head -n 1 | cut -d: -f1)

if [ -z "$SSID" ]; then
    echo "❌ Error: No active Wi-Fi connection detected."
    echo "Please connect to a network first so the script knows what to lock."
    exit 1
fi

if [ "$1" == "on" ]; then
    # 2. Extract BSSID and Frequency of the currently connected network
    # We grep for the line starting with an asterisk (*) to find the active AP
    WIFI_INFO=$(nmcli -f IN-USE,BSSID,FREQ device wifi list | grep '^\*')
    BSSID=$(echo "$WIFI_INFO" | awk '{print $2}')
    FREQ=$(echo "$WIFI_INFO" | awk '{print $3}')

    echo "📡 Detected Network: $SSID"
    echo "🔗 Target BSSID: $BSSID"

    # 3. Determine the frequency band to lock (5GHz or 2.4GHz)
    if [[ "$FREQ" == 5* ]]; then
        BAND="a"
        echo "📊 Frequency: $FREQ MHz (5 GHz) - Perfect physical separation."
    elif [[ "$FREQ" == 2* ]]; then
        BAND="bg"
        echo "📊 Frequency: $FREQ MHz (2.4 GHz) - Applying Traffic Cop optimization."
    else
        BAND=""
        echo "📊 Frequency: Unknown ($FREQ). Proceeding with standard locks."
    fi

    echo "⚙️  Locking down combo chip (Performance Mode)..."
    
    # Apply Wi-Fi Lockdown Rules
    if [ -n "$BAND" ]; then
        nmcli connection modify "$SSID" 802-11-wireless.band "$BAND"
    fi
    nmcli connection modify "$SSID" 802-11-wireless.bssid "$BSSID"
    nmcli connection modify "$SSID" 802-11-wireless.powersave 2
    
    # Restart connection quietly to apply rules
    nmcli connection up "$SSID" > /dev/null
    
    # Apply Bluetooth Lockdown Rules
    bluetoothctl discoverable off > /dev/null
    bluetoothctl pairable off > /dev/null
    
    echo "✅ Performance Mode: ACTIVE"

elif [ "$1" == "off" ]; then
    echo "⚙️  Restoring combo chip (Search Mode) for '$SSID'..."
    
    # Clear Wi-Fi rules (empty quotes return to default)
    nmcli connection modify "$SSID" 802-11-wireless.band ""
    nmcli connection modify "$SSID" 802-11-wireless.bssid ""
    nmcli connection modify "$SSID" 802-11-wireless.powersave 0
    
    # Restart connection quietly to apply rules
    nmcli connection up "$SSID" > /dev/null
    
    # Restore Bluetooth scanning
    bluetoothctl discoverable on > /dev/null
    bluetoothctl pairable on > /dev/null
    
    echo "🔍 Search Mode: ACTIVE"

else
    echo "❌ Invalid argument."
    echo "Usage: combo-toggle {on|off}"
    exit 1
fi