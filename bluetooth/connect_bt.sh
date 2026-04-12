#!/bin/bash

Device_MAC="40:72:18:8A:23:81"

is_bluetooth_powered_on(){
	/usr/bin/bluetoothctl show | grep -q "Powered: yes"
}

is_device_connected(){
	/usr/bin/bluetoothctl info "$Device_MAC" | grep -q "Connected: yes"
}

volume_setting(){
	echo "Attempting to set the volume on 50%"
	local deviceID=$(wpctl status | awk '/JBL LIVE PRO 2 TWS/ && /\[vol:/ { print $3 }' | grep -oP '\d+' | head -n 1)

	if [ -z "$deviceID" ]; then
		echo "ERROR: Could not find the PipeWire device ID"
		return 1
	fi

	wpctl set-volume "$deviceID" "0.57"

	if [ $? -eq 0 ]; then
       		echo "Volume set successfully for $deviceID."
        	return 0
    	else
        	echo "ERROR: Failed to set volume for $deviceID."
        	return 1
    	fi
}

restart_services(){
		echo "Failed Bluetooth connection."
		echo "Restarting bluetooth (systemctl) ..."
		sudo /usr/bin/systemctl restart bluetooth.service

		echo "Enabling bluetooth (systemctl) ..."
		sudo /usr/bin/systemctl enable bluetooth.service

		echo "Unblocking bluetooth (rfkill) ..."
		sudo /usr/sbin/rfkill unblock bluetooth
}

remove_connect(){
    echo "Do you wanna try removing the device and connecting again? (y/n)"
    read -r response
    if [ "$response" = "y" ]; then
        echo "Proceeding with removal and reconnection..."
	echo "It could take a while..."

	bluetoothctl --remove "$Device_MAC";
	bluetoothctl --discoverable --on
	bluetoothctl --pairable --on
	bluetoothctl --scan --on &

	local SCAN_PID=$!

	while read -r line; do
    		echo "Found device: $line"
    		if [[ "$line" == *"$Device_MAC"* && "$line" == *"JBL LIVE PRO 2 TWS"* ]]; then
        		echo "Found JBL headphones! Stopping scan..."
        		kill "$SCAN_PID"
        		bluetoothctl pair "$Device_MAC"
        		break 
    		fi
	done
    else
        exit 1;
    fi
}


bluetooth_connect(){

	local tries=${1:-1}

	if [ "$tries" -ge "3" ]; then
        	echo "Failed to connect after 3 attempts."
        	return 1; fi

	local connect_output=$(/usr/bin/bluetoothctl -- connect "$Device_MAC" 2>&1)
	sleep 2

	if echo "$connect_output" | grep -E -q "Failed to connect|br-connection-unknown"; then restart_services; fi

	if is_device_connected; then
		echo "Device connected successfully after $tries attempts."
		return 0

	else bluetooth_connect "$((tries+1))"; fi
}

echo "Bluetooth connection check in 3"; sleep 0.5

for i in {2..1..-1}
do
	echo "                              $i"
	sleep 0.5
done

if is_device_connected; then echo "Device is connected."; sleep 1; exit; fi

if is_bluetooth_powered_on; then
	echo "Bluetooth is already powered on. Connecting to $Device_MAC..."
	bluetooth_connect
	finished=$?
else
	echo "Bluetooth is not powered on. Attempting to power on..."
	/usr/bin/bluetoothctl -- power on
	sleep 1

	if is_bluetooth_powered_on; then
		bluetooth_connect
		sleep 3;
		finished=$?
	else
		restart_services

		/usr/bin/bluetoothctl -- power on
		sleep 1

		bluetooth_connect
		finished=$?
	fi
fi

if [ "$finished" -ne 0 ]; then
    remove_connect
    finished=$?
fi

volume_setting

if [ "$finished" -eq 0 -a $? -eq 0 ]; then sleep 2; exit 0
else echo "Failed to connect/set the volume. "; sleep 2; exit 1; fi



