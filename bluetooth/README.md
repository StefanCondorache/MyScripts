# Smart Linux Bluetooth Manager (`connect_bt`)

A highly robust, terminal-based Bluetooth connection manager for modern Linux distributions.

Originally built to automate connecting and configuring JBL headphones, this script has evolved into a universal, self-healing Bluetooth utility. It features a clean arrow-key Terminal UI (TUI), automatic daemon recovery, smart hardware identification, and native PipeWire audio integration.

## Features

* **Interactive TUI:** A clean, cursor-driven menu to select devices using arrow keys. No external UI dependencies (like `dialog` or `whiptail`) required.

* **Fast-Track Mode:** Pass a device name or MAC address as an argument to skip the menu and connect instantly (perfect for keyboard shortcuts). You can optionally pass a target volume as a second argument!

* **Smart Identity Resolution:**
  * Automatically detects Apple/Privacy-focused devices using randomized MAC addresses.
  * Queries local Linux hardware databases (`hwdata`) to identify the manufacturer of unknown devices (e.g., Logitech, Samsung).

* **Automated Audio Configuration:** Detects if the connecting device is an audio output (headphones/speakers). If so, it waits for PipeWire to initialize the audio sink and automatically sets the volume to a safe 50% (or your custom choice). Skips this step seamlessly for mice and keyboards.

* **Self-Healing Stack:** If a connection fails due to a daemon hang or `br-connection-unknown` error, the script automatically restarts `bluetooth.service` via `systemctl`, unblocks the radio via `rfkill`, and retries.

* **Active Discovery:** Built-in scanning option to discover and pair brand-new devices directly from the terminal, with a customizable scan duration.

## Prerequisites

This script is highly portable but relies on modern Linux standards:

* **BlueZ** (`bluetoothctl`): The core Linux Bluetooth stack.
* **systemd** (`systemctl`): Used to restart the Bluetooth daemon if it hangs.
* **rfkill**: Used to unblock the Bluetooth radio module.
* **PipeWire / WirePlumber** (`wpctl`): *Optional.* Used for automatic volume adjustment. If you are on an older PulseAudio system, the script will simply skip the volume configuration.
* **hwdata** (`/usr/share/hwdata/oui.txt`): *Optional.* Used to resolve manufacturer names for unknown MAC addresses.

## Installation

1. Download or clone the repository containing `connect_bt.sh` and `install.sh` to your machine.

2. Run the included installation script with root privileges:

   ```bash
   chmod +x install.sh
   sudo ./install.sh
   ```

This will automatically install the tool into `/usr/local/bin/connect_bt`, making it accessible globally.

## Usage

### 1. Interactive Menu

Run the command from anywhere to launch the Terminal UI:

```bash
connect_bt
```

* Use the **Up/Down arrow keys** to navigate.
* Press **Enter** to connect to a known device.
* Select **"🔎 Scan for new devices"** to actively listen for nearby unpaired devices (you will be prompted for how many seconds to scan).
* When connecting to an audio device, you will be prompted to optionally set a custom volume level.

### 2. Fast-Track (CLI Arguments)

If you want to bind a specific headset to a keyboard shortcut, pass part of its name or its MAC address directly to the command. It will bypass the menu and connect instantly. 

You can also pass an optional second argument to instantly set the playback volume.

```bash
# Connect using a partial name (Uses default 50% volume)
connect_bt "JBL"

# Connect and instantly set volume to 75%
connect_bt "JBL" 0.75

# Connect using a MAC address and set volume to 100%
connect_bt "40:72:18:8A:23:81" 1.0
```

## Configuration

You can easily tweak the script's default behavior by editing the configuration variables at the very top of `connect_bt.sh` (or `/usr/local/bin/connect_bt` if already installed). These act as the defaults when you press "Enter" at the interactive prompts:

```bash
TARGET_VOLUME="0.50" # Default volume level applied to audio devices (0.50 = 50%)
SCAN_DURATION="10"   # Default duration the active discovery scan runs (in seconds)
```

## Troubleshooting: Finding an iPhone or iPad

Modern mobile devices use Bluetooth Low Energy (BLE) MAC randomization. They hide their real names and scramble their MAC addresses every 15 minutes to prevent tracking. The script will correctly identify these as `Hidden Device (Randomized Privacy MAC)`.

**To pair an iPhone for the first time:**

1. Unlock your iPhone and go to **Settings > Bluetooth**.
2. Leave the screen awake and on that menu (this temporarily disables Apple's privacy scramble).
3. Run the script and select **"🔎 Scan for new devices"**.
4. Your iPhone's real name will now appear in the list. Select it to pair!