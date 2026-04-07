# combo-toggle

A dynamic, command-line system utility designed to optimize Linux networking configurations and eliminate Bluetooth audio interference on machines utilizing Wi-Fi/Bluetooth combo chips.

## 1. The Context & The Problem
Most modern laptops utilize a single Network Interface Controller (NIC) "combo chip" to handle both Wi-Fi and Bluetooth. Because both protocols natively operate on the 2.4 GHz radio frequency, they are forced to share the same physical antennas. 

To manage this, the hardware utilizes a subsystem called Bluetooth Coexistence (or Packet Traffic Arbitration). This system rapidly switches antenna access between Wi-Fi data and Bluetooth audio. Under normal load, this is unnoticeable. However, Linux network managers frequently initiate background sweeps (sending Probe Requests across all channels) to locate stronger access points. 

During these sweeps, the combo chip pauses the Bluetooth stream to dedicate antenna time to the Wi-Fi sweep. This results in buffer underruns, manifesting as audio stutters, drops, or complete connection loss in Bluetooth headphones.

## 2. The Philosophy: Why a Script?
Advanced Linux users may note that this tool relies on a handful of standard `nmcli` and `bluetoothctl` commands and might ask: *"Why not just run the six commands manually?"*

While manual execution is possible, `combo-toggle` is built to provide **dynamic automation and safety** that manual typing cannot offer:
1. **Context Awareness:** To run the commands manually, a user must first run diagnostic commands to manually copy their active SSID, their specific router's hardware MAC address (BSSID), and check the operating frequency. `combo-toggle` executes this environment profiling instantly and applies the correct parameters dynamically.
2. **State Safety (Idempotency):** Redundantly applying `nmcli` modifications and restarting the connection manually will cause immediate network drops. `combo-toggle` queries the active configuration files first. If the hardware is already locked, it safely aborts to protect active data streams.
3. **Portability:** Hardcoding manual commands into an alias limits the user to a single home network. `combo-toggle` reads the environment on the fly, meaning it works flawlessly whether you are at home, in an office, or at a coffee shop.

## 3. The Solution Concept
`combo-toggle` is a Bash script that bypasses the hardware limitation using native Linux networking tools. It does not patch the kernel or require external dependencies. 

Instead, it dynamically profiles your active network environment and applies strict software-level constraints to the combo chip:
* **Physical Band Separation:** If a 5 GHz Wi-Fi network is detected, it forces the Wi-Fi radio exclusively to that band, granting Bluetooth unrestricted access to the 2.4 GHz band.
* **Passive Mode Enforcement:** By binding the NetworkManager profile to a specific router hardware address (BSSID), it prevents background channel sweeps.
* **Continuous Power Delivery:** It disables standard Wi-Fi micro-sleep states to prevent data buffering.
* **Bluetooth Isolation:** It strips the Bluetooth adapter of its ability to scan for new devices or broadcast its presence, dedicating 100% of its processing cycles to maintaining the active audio stream.

## 4. Command Breakdown & Rationale
The script relies on `nmcli` (NetworkManager) and `bluetoothctl` (BlueZ). Here is exactly what the script executes and why:

### Variable Detection
* `nmcli -t -f NAME,TYPE connection show --active`
  Detects the currently active Wi-Fi profile dynamically.
* `nmcli -f IN-USE,BSSID,FREQ device wifi list`
  Extracts the specific hardware MAC address (BSSID) and frequency of the active router connection.

### Performance Mode Configuration (`on`)
* `nmcli connection modify "$SSID" 802-11-wireless.band a|bg`
  Forces the network profile to exclusively use the 5 GHz (`a`) or 2.4 GHz (`bg`) band based on initial detection, preventing auto-negotiation channel hopping.
* `nmcli connection modify "$SSID" 802-11-wireless.bssid "$BSSID"`
  Locks the profile to a specific router hardware address. This enforces Passive Mode, stopping the OS from executing disruptive background network sweeps.
* `nmcli connection modify "$SSID" 802-11-wireless.powersave 2`
  Disables Wi-Fi power saving (value `2`) to stop the NIC from entering micro-sleep states, which causes data buffering and audio stutters.
* `bluetoothctl discoverable off` & `bluetoothctl pairable off`
  Prevents the Bluetooth adapter from broadcasting its presence or listening for pairing requests, ensuring an uninterrupted data stream to the connected headphones.

### Search Mode Configuration (`off`)
* `nmcli connection modify "$SSID" 802-11-wireless.band ""` (and `bssid ""`)
  Passing empty strings clears the custom hardware locks, returning NetworkManager to its default auto-negotiation and roaming behaviors.
* `nmcli connection modify "$SSID" 802-11-wireless.powersave 0`
  Returns power management to the default Linux kernel rules (value `0`).

## 5. Installation
To install the script as a native system command, simply clone this repository and run the automated installer. 

1. Clone the repository:
    ```bash
    git clone [https://github.com/StefanCondorache/combo-toggle.git](https://github.com/StefanCondorache/combo-toggle.git)
    cd combo-toggle
    ```

2. Run the installer:
    ```bash
    ./install.sh
    ```
    (Note: If you receive a permission error, you can bypass it by running bash install.sh instead).

The installer will securely copy the script to /usr/local/bin/ and apply the correct system permissions.

## 6. Usage
Execute the command from any terminal directory.

Enable hardware lockdown (Performance Mode):
```bash
combo-toggle on
```

Restore default scanning behavior (Search Mode):
```bash
combo-toggle off
```

## 7. Compatibility & Disclaimer
**Notice:** This script has been written for and tested exclusively on **Arch Linux**. 

While the logic is theoretically sound for any Linux distribution utilizing standard implementations of `NetworkManager` and `BlueZ` (such as Fedora, Ubuntu, or Debian), differences in default networking daemons or `wpa_supplicant` configurations on other distributions may result in unexpected behavior. Use at your own discretion.
