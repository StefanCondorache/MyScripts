#!/bin/bash

# Define standardized output tags for system logging
INFO="[INFO]"
SUCCESS="[SUCCESS]"
WARNING="[WARNING]"
ERROR="[ERROR]"

# Validate arguments
if [ -z "$1" ]; then
    echo "$INFO Usage: combo-toggle {on|off}"
    echo "       on  - Enable Performance Mode (Locks Wi-Fi parameters & disables Bluetooth scanning)"
    echo "       off - Enable Search Mode (Restores default network scanning behavior)"
    exit 1
fi

# 1. Detect the active Wi-Fi connection profile
SSID=$(nmcli -t -f NAME,TYPE connection show --active | grep 802-11-wireless | head -n 1 | cut -d: -f1)

if [ -z "$SSID" ]; then
    echo "$ERROR No active Wi-Fi connection detected."
    echo "        Please ensure you are connected to a network before initializing the script."
    exit 1
fi

echo "$SUCCESS Active connection identified. Variable [SSID] recorded as: $SSID"

# Process Performance Mode
if [ "$1" == "on" ]; then
    # 2. Extract hardware parameters of the current connection
    WIFI_INFO=$(nmcli -f IN-USE,BSSID,FREQ device wifi list | grep '^\*')
    BSSID=$(echo "$WIFI_INFO" | awk '{print $2}')
    FREQ=$(echo "$WIFI_INFO" | awk '{print $3}')

    echo "$SUCCESS Hardware parameters extracted. Variable [BSSID] recorded as: $BSSID"
    echo "$SUCCESS Frequency data extracted. Variable [FREQ] recorded as: $FREQ MHz"

    # 3. Assess the frequency band and provide diagnostic recommendations
    if [[ "$FREQ" == 5* ]]; then
        BAND="a"
        echo "$INFO 5 GHz Wi-Fi frequency detected. Variable [BAND] recorded as: $BAND"
        echo "$SUCCESS Optimal physical separation achieved. Wi-Fi and Bluetooth are on separate bands."
    elif [[ "$FREQ" == 2* ]]; then
        BAND="bg"
        echo "$INFO 2.4 GHz Wi-Fi frequency detected. Variable [BAND] recorded as: $BAND"
        echo "$WARNING [DIAGNOSTIC RECOMMENDATION]"
        echo "          Bluetooth devices operate exclusively on the 2.4 GHz frequency band."
        echo "          Your Wi-Fi is currently sharing this same band, forcing the hardware to multiplex."
        echo "          While this script will minimize interference by disabling background scanning,"
        echo "          connecting to a 5 GHz Wi-Fi network is highly recommended for complete isolation."
    else
        BAND=""
        echo "$INFO Frequency outside standard parameters. Variable [BAND] remains unassigned."
    fi

    echo "$INFO Initializing hardware lockdown (Performance Mode)..."
    
    # Apply standard Wi-Fi restrictions
    if [ -n "$BAND" ]; then
        nmcli connection modify "$SSID" 802-11-wireless.band "$BAND"
    fi
    nmcli connection modify "$SSID" 802-11-wireless.bssid "$BSSID"
    nmcli connection modify "$SSID" 802-11-wireless.powersave 2
    
    # Reload connection
    nmcli connection up "$SSID" > /dev/null
    echo "$SUCCESS NetworkManager profile updated and connection restarted successfully."
    
    # Apply Bluetooth restrictions
    bluetoothctl discoverable off > /dev/null
    bluetoothctl pairable off > /dev/null
    echo "$SUCCESS Bluetooth adapter scanning protocols disabled."
    
    echo "$SUCCESS Performance Mode initialization complete. Hardware isolated."

# Process Search Mode
elif [ "$1" == "off" ]; then
    echo "$INFO Restoring default hardware configuration (Search Mode) for profile: $SSID..."
    
    # Clear custom Wi-Fi restrictions
    nmcli connection modify "$SSID" 802-11-wireless.band ""
    nmcli connection modify "$SSID" 802-11-wireless.bssid ""
    nmcli connection modify "$SSID" 802-11-wireless.powersave 0
    
    # Reload connection
    nmcli connection up "$SSID" > /dev/null
    echo "$SUCCESS NetworkManager profile parameters cleared. Connection restarted."
    
    # Restore Bluetooth functionality
    bluetoothctl discoverable on > /dev/null
    bluetoothctl pairable on > /dev/null
    echo "$SUCCESS Bluetooth adapter scanning protocols enabled."
    
    echo "$SUCCESS Search Mode initialization complete. Hardware restored to default operations."

else
    echo "$ERROR Invalid argument provided."
    echo "        Usage: combo-toggle {on|off}"
    exit 1
fi