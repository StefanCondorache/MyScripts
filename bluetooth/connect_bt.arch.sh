#!/bin/bash

# Configuration
TARGET_VOLUME="0.50" # Set to 50%

# Define standardized output colors/tags for the UI
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

INFO="${CYAN}[INFO]${NC}"
SUCCESS="${GREEN}[SUCCESS]${NC}"
WARNING="${YELLOW}[WARNING]${NC}"
ERROR="${RED}[ERROR]${NC}"

# ==========================================
# CORE FUNCTIONS
# ==========================================

is_bluetooth_powered_on() {
    bluetoothctl show | grep -q "Powered: yes"
}

is_device_connected() {
    bluetoothctl info "$DEVICE_MAC" | grep -q "Connected: yes"
}

volume_setting() {
    echo -e "$INFO Attempting to set the volume to $TARGET_VOLUME for $DEVICE_NAME..."
    
    local deviceID=""
    local attempts=0
    
    # PipeWire sometimes takes a few seconds to create the audio sink after Bluetooth connects.
    # We will poll for it up to 5 times (1 check per second).
    while [ $attempts -lt 5 ]; do
        # Robust PipeWire parsing:
        # - `grep -i 'vol:'` skips raw hardware devices.
        # - `grep -oP '\d+(?=\.)'` ignores PipeWire's UI tree characters (│, ├) and grabs the number right before the dot.
        deviceID=$(wpctl status | grep -i "$DEVICE_NAME" | grep -i 'vol:' | grep -oP '\d+(?=\.)' | head -n 1)

        if [ -n "$deviceID" ]; then
            break
        fi
        
        sleep 1
        ((attempts++))
    done

    if [ -z "$deviceID" ]; then
        echo -e "$WARNING Could not find PipeWire audio node for $DEVICE_NAME. (Normal if this is a mouse/keyboard)."
        return 1
    fi

    wpctl set-volume "$deviceID" "$TARGET_VOLUME"

    if [ $? -eq 0 ]; then
        echo -e "$SUCCESS Volume set successfully for device ID $deviceID."
        return 0
    else
        echo -e "$ERROR Failed to set volume for device ID $deviceID."
        return 1
    fi
}

restart_services() {
    echo -e "$WARNING Failed Bluetooth connection. Resetting stack..."
    echo -e "  -> Restarting bluetooth.service..."
    sudo systemctl restart bluetooth.service
    echo -e "  -> Unblocking bluetooth radio (rfkill)..."
    sudo rfkill unblock bluetooth
    sleep 2 
}

remove_connect() {
    echo -e "$WARNING Connection keeps failing or device is not paired."
    # We must ensure cursor is visible if asking for input during a failure
    tput cnorm 2>/dev/null
    read -p "Do you want to pair / re-pair $DEVICE_NAME? (y/n): " response
    
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        echo -e "$INFO Proceeding with pairing. Please ensure the device is in pairing mode..."
        
        # Suppress error if the device isn't actually paired yet
        bluetoothctl remove "$DEVICE_MAC" >/dev/null 2>&1
        bluetoothctl discoverable on
        bluetoothctl pairable on
        
        bluetoothctl scan on > /dev/null &
        local SCAN_PID=$!

        echo -e "$INFO Scanning for $DEVICE_NAME..."
        
        local attempts=0
        while [ $attempts -lt 15 ]; do
            if bluetoothctl devices | grep -q "$DEVICE_MAC"; then
                echo -e "$SUCCESS Found $DEVICE_NAME! Stopping scan..."
                kill "$SCAN_PID" 2>/dev/null
                
                echo -e "$INFO Pairing..."
                bluetoothctl pair "$DEVICE_MAC"
                sleep 2
                
                echo -e "$INFO Trusting device..."
                bluetoothctl trust "$DEVICE_MAC"
                break
            fi
            sleep 1
            attempts=$((attempts + 1))
        done
        
        kill -0 "$SCAN_PID" 2>/dev/null && kill "$SCAN_PID"
        return 0
    else
        return 1
    fi
}

bluetooth_connect() {
    local tries=${1:-1}

    if [ "$tries" -ge 3 ]; then
        echo -e "$ERROR Failed to connect after 3 attempts."
        return 1
    fi

    echo -e "$INFO Connection attempt $tries/3..."
    local connect_output=$(bluetoothctl connect "$DEVICE_MAC" 2>&1)
    sleep 2

    if echo "$connect_output" | grep -E -q "Failed to connect|br-connection-unknown"; then 
        restart_services
    fi

    if is_device_connected; then
        echo -e "$SUCCESS Device connected successfully."
        return 0
    else 
        bluetooth_connect "$((tries + 1))"
    fi
}

process_connection() {
    if is_device_connected; then 
        echo -e "$SUCCESS $DEVICE_NAME is already connected."
        volume_setting
        return 0
    fi

    if is_bluetooth_powered_on; then
        echo -e "$INFO Bluetooth is powered on. Connecting to $DEVICE_NAME..."
        bluetooth_connect
        finished=$?
    else
        echo -e "$INFO Bluetooth is powered off. Attempting to power on..."
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

    if [ "$finished" -ne 0 ]; then
        remove_connect
        if [ $? -eq 0 ]; then
            bluetooth_connect 1
            finished=$?
        else
            finished=1
        fi
    fi

    if [ "$finished" -eq 0 ]; then
        volume_setting
        return 0
    else 
        echo -e "$ERROR Failed to establish a final connection."
        return 1
    fi
}

# ==========================================
# TERMINAL UI: ARROW KEY SELECTION
# ==========================================

select_device() {
    local selected=0
    local first_run=true

    while true; do
        # Fetch known/paired devices and newly discovered devices into an array
        mapfile -t devices < <(bluetoothctl devices)

        # Build the dynamic menu list, starting with the Scan option
        local menu_items=("Scan for new devices (100 seconds)")
        for i in "${!devices[@]}"; do
            mac=$(echo "${devices[$i]}" | awk '{print $2}')
            name=$(echo "${devices[$i]}" | cut -d' ' -f3-)
            menu_items+=("$name ($mac)")
        done

        local key=""
        local total_lines=$((6 + ${#menu_items[@]}))

        # Hide cursor for clean UI, trap ensures it comes back if user hits Ctrl+C
        tput civis
        trap 'tput cnorm; exit' EXIT INT TERM

        while true; do
            # If not the first run, move cursor up to overwrite previous menu
            if [ "$first_run" = false ]; then
                echo -en "\033[${total_lines}A"
            fi
            first_run=false

            # The \033[K clears the line from the cursor to the end, preventing ghost text
            echo -e "${CYAN}==========================================${NC}\033[K"
            echo -e "${CYAN}      BLUETOOTH DEVICE SELECTOR           ${NC}\033[K"
            echo -e "${CYAN}==========================================${NC}\033[K"
            echo -e "Use [UP/DOWN] arrows to select, [ENTER] to confirm.\033[K"
            echo -e "\033[K"

            for i in "${!menu_items[@]}"; do
                if [ "$i" -eq "$selected" ]; then
                    echo -e "  \033[1;32m> ${menu_items[$i]} \033[0m\033[K"
                else
                    echo -e "    ${menu_items[$i]}\033[K"
                fi
            done
            echo -e "${CYAN}==========================================${NC}\033[K"

            # Read single keypress silently
            read -rsn1 key
            if [[ $key == $'\e' ]]; then
                read -rsn2 key_ext
                case "$key_ext" in
                    [A|OA) # Up arrow
                        ((selected--))
                        if [ "$selected" -lt 0 ]; then selected=$((${#menu_items[@]} - 1)); fi
                        ;;
                    [B|OB) # Down arrow
                        ((selected++))
                        if [ "$selected" -ge ${#menu_items[@]} ]; then selected=0; fi
                        ;;
                esac
            elif [[ -z $key ]]; then
                # Enter key (empty string)
                break
            fi
        done

        # Restore cursor
        tput cnorm
        
        if [ "$selected" -eq 0 ]; then
            # User selected the "Scan" option
            echo ""
            echo -e "$INFO Scanning for nearby devices for 100 seconds... Please wait."
            
            # Ensure Bluetooth is on before scanning
            if ! is_bluetooth_powered_on; then
                bluetoothctl power on > /dev/null 2>&1
                sleep 1
            fi
            
            # Run scan for 100 seconds, then automatically stop
            timeout 100 bluetoothctl scan on > /dev/null 2>&1
            
            # Reset UI variables to redraw the menu with the newly discovered devices
            selected=0
            first_run=true
            echo -e "$SUCCESS Scan complete! Updating list..."
            sleep 1
            echo ""
        else
            # User selected a specific device
            trap - EXIT INT TERM
            echo "" # Add a blank line below menu
            
            # Subtract 1 because index 0 was our Scan button
            local device_idx=$((selected - 1))
            DEVICE_MAC=$(echo "${devices[$device_idx]}" | awk '{print $2}')
            DEVICE_NAME=$(echo "${devices[$device_idx]}" | cut -d' ' -f3-)
            break
        fi
    done
}

# ==========================================
# MAIN EXECUTION
# ==========================================

INTERACTIVE=true

# Check if a search argument was passed (Bypass GUI with name search)
if [ -n "$1" ]; then
    INTERACTIVE=false
    # Search paired devices for the argument (case-insensitive)
    MATCHES=$(bluetoothctl devices | grep -i "$1")
    MATCH_COUNT=$(echo "$MATCHES" | grep -c "^")

    if [ -z "$MATCHES" ]; then
        echo -e "$ERROR No paired device found matching '$1'."
        exit 1
    elif [ "$MATCH_COUNT" -gt 1 ]; then
        echo -e "$ERROR Multiple paired devices found matching '$1'. Please be more specific."
        echo "$MATCHES"
        exit 1
    else
        DEVICE_MAC=$(echo "$MATCHES" | awk '{print $2}')
        DEVICE_NAME=$(echo "$MATCHES" | cut -d' ' -f3-)
        echo -e "$INFO Fast-track mode: Identified $DEVICE_NAME ($DEVICE_MAC)"
    fi
fi

while true; do
    if [ "$INTERACTIVE" = true ]; then
        # Launch the Arrow Key TUI
        select_device
    fi

    # Execute Connection Logic
    process_connection

    if [ "$INTERACTIVE" = false ]; then
        break # Exit immediately if using fast-track arguments
    fi

    echo -e "\n${CYAN}------------------------------------------${NC}"
    read -p "Do you want to connect another device? (y/N): " run_again
    if [[ ! "$run_again" =~ ^[Yy]$ ]]; then
        echo -e "$INFO Exiting."
        break
    fi
    echo ""
done