#!/bin/bash

# Configuration
DEVICE_MAC="40:72:18:8A:23:81"
DEVICE_NAME="JBL LIVE PRO 2 TWS"
TARGET_VOLUME="0.65" # Set to 65%

# Define standardized output tags
INFO="   [INFO]"
SUCCESS="[SUCCESS]"
WARNING="[WARNING]"
ERROR="  [ERROR]"

is_bluetooth_powered_on() {
    bluetoothctl show | grep -q "Powered: yes"
}

is_device_connected() {
    bluetoothctl info "$DEVICE_MAC" | grep -q "Connected: yes"
}

volume_setting() {
    echo "$INFO Attempting to set the volume to $TARGET_VOLUME..."
    
    # Robust PipeWire parsing: Looks for the exact ID number right before the device name
    local deviceID=$(wpctl status | grep "$DEVICE_NAME" | grep -oP '^\s*\*?\s*\K\d+(?=\.)' | head -n 1)

    if [ -z "$deviceID" ]; then
        echo "$ERROR Could not find the PipeWire device ID for $DEVICE_NAME."
        return 1
    fi

    wpctl set-volume "$deviceID" "$TARGET_VOLUME"

    if [ $? -eq 0 ]; then
        echo "$SUCCESS Volume set successfully for device ID $deviceID."
        return 0
    else
        echo "$ERROR Failed to set volume for device ID $deviceID."
        return 1
    fi
}

restart_services() {
    echo "$WARNING Failed Bluetooth connection. Resetting stack..."
    
    echo "  -> Restarting bluetooth.service..."
    sudo systemctl restart bluetooth.service

    echo "  -> Unblocking bluetooth radio (rfkill)..."
    sudo rfkill unblock bluetooth
    
    # Give the daemon a second to initialize after restart
    sleep 2 
}

remove_connect() {
    echo "$WARNING Connection keeps failing."
    read -p "Do you want to completely remove the device and re-pair it? (y/n): " response
    
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        echo "$INFO Proceeding with removal and reconnection. Please put headphones in pairing mode..."
        
        # Arch uses clean syntax without the '--' flags
        bluetoothctl remove "$DEVICE_MAC"
        bluetoothctl discoverable on
        bluetoothctl pairable on
        
        # Start scan in the background
        bluetoothctl scan on > /dev/null &
        local SCAN_PID=$!

        echo "$INFO Scanning for $DEVICE_NAME..."
        
        # Wait for the device to appear in the scan results
        local attempts=0
        while [ $attempts -lt 15 ]; do
            if bluetoothctl devices | grep -q "$DEVICE_MAC"; then
                echo "$SUCCESS Found $DEVICE_NAME! Stopping scan..."
                kill "$SCAN_PID"
                
                echo "$INFO Pairing..."
                bluetoothctl pair "$DEVICE_MAC"
                sleep 2
                
                echo "$INFO Trusting device..."
                bluetoothctl trust "$DEVICE_MAC"
                break
            fi
            sleep 1
            attempts=$((attempts + 1))
        done
        
        # Cleanup scan if loop timed out
        kill -0 "$SCAN_PID" 2>/dev/null && kill "$SCAN_PID"
    else
        exit 1
    fi
}

bluetooth_connect() {
    local tries=${1:-1}

    if [ "$tries" -ge 3 ]; then
        echo "$ERROR Failed to connect after 3 attempts."
        return 1
    fi

    echo "$INFO Connection attempt $tries/3..."
    local connect_output=$(bluetoothctl connect "$DEVICE_MAC" 2>&1)
    sleep 2

    # If it fails with specific daemon errors, restart the systemctl service
    if echo "$connect_output" | grep -E -q "Failed to connect|br-connection-unknown"; then 
        restart_services
    fi

    if is_device_connected; then
        echo "$SUCCESS Device connected successfully."
        return 0
    else 
        bluetooth_connect "$((tries + 1))"
    fi
}

# --- MAIN EXECUTION ---

echo "Bluetooth connection check in 3..."; sleep 0.5
echo "                              2..."; sleep 0.5
echo "                              1..."; sleep 0.5

if is_device_connected; then 
    echo "$SUCCESS Device is already connected."
    volume_setting
    exit 0
fi

if is_bluetooth_powered_on; then
    echo "$INFO Bluetooth is powered on. Connecting to $DEVICE_MAC..."
    bluetooth_connect
    finished=$?
else
    echo "$INFO Bluetooth is powered off. Attempting to power on..."
    bluetoothctl power on
    sleep 2

    if is_bluetooth_powered_on; then
        bluetooth_connect
        finished=$?
    else
        restart_services
        bluetoothctl power on
        sleep 2
        bluetooth_connect
        finished=$?
    fi
fi

# Fallback to re-pairing if standard connection failed
if [ "$finished" -ne 0 ]; then
    remove_connect
    # If pairing succeeded, try to connect one last time
    bluetooth_connect 1
    finished=$?
fi

if [ "$finished" -eq 0 ]; then
    volume_setting
    sleep 2
    exit 0
else 
    echo "$ERROR Failed to establish a final connection."
    sleep 2
    exit 1
fi