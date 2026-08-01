# ArchScript

A collection of small, self-contained Bash tools written to solve specific annoyances on my Arch Linux setup. Each one lives in its own folder with its own installer and README, and installs as a system-wide command.

## The Tools

| Tool | Command | What it does |
| --- | --- | --- |
| [smart-open](smart-open/) | `smart-open [file...]` | Universal opener. Routes files by MIME type: text and code to your editor, everything else to the desktop default. |
| [space-hunter](space-hunter/) | `space-hunter [path] [limit]` | Finds what is eating your disk. Arrow-key TUI listing mount points with usage, then lists the largest files. |
| [bluetooth](bluetooth/) | `connect_bt [device]` | Self-healing Bluetooth manager. TUI device picker, automatic daemon recovery, PipeWire volume setup. |
| [combo-toggle](combo-toggle/) | `combo-toggle {on\|off\|status}` | Stops Bluetooth audio stutter on Wi-Fi/BT combo chips by locking the Wi-Fi profile to one band and access point. |

## Installation

Every tool follows the same pattern — clone once, then install the ones you want:

```bash
git clone https://github.com/StefanCondorache/combo-toggle.git
cd combo-toggle/space-hunter
./install.sh
```

Each installer asks for confirmation, checks its dependencies, then copies the script to `/usr/local/bin/` without the `.sh` extension. You will be prompted for your sudo password at that step. Uninstalling is just `sudo rm /usr/local/bin/<command>`.

## Conventions

Shared across all four tools, so they behave predictably:

* Pure Bash, no runtime dependencies beyond standard system utilities (`nmcli`, `bluetoothctl`, `du`, `file`).
* TUIs are built on `tput` and ANSI escapes — no `dialog` or `whiptail`.
* `-h` / `--help` on every command.
* Tagged output: `[INFO]`, `[SUCCESS]`, `[WARNING]`, `[ERROR]`.
* Interactive by default, scriptable via arguments.

## Compatibility

Written for and tested on **Arch Linux**. The logic is standard enough for any distribution running NetworkManager, BlueZ and freedesktop.org tooling, but defaults and daemon behaviour differ elsewhere. Read the script before running it, and adjust for your setup.

## Licence

MIT. See [LICENCE](LICENCE).
