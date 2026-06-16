# Space Hunter

A dependency-free Bash TUI utility designed to identify large files and track system storage consumption.

---

## Technical Features

* **Proportional Padding Engine** — Dynamically measures path lengths to scale its layout perfectly to your active terminal width.
* **Storage Ratio Overview** — Pulls and displays real-time `[Used/Total]` consumption metrics alongside total free space.
* **Native Navigation Menu** — Built using pure terminal capabilities (`tput`) to process arrow-key selections without external dependencies like `dialog` or `whiptail`.
* **Configurable Item Limiting** — Allows defining a maximum result threshold on demand, preventing terminal flooding during heavy file directory sweeps.
* **Filesystem-Isolated Scanning** — Leverages root-isolated logic (`du -ahx`) to safely calculate target boundaries without crossing mount points.

---

## Quick Start

### Automated Installation
```bash
chmod +x install.sh
./install.sh

```

The installer strips the `.sh` extension automatically to register `space-hunter` as a standard system-wide command.

### Command Usage

| Execution Context | Command Syntax | Description |
| --- | --- | --- |
| **Interactive TUI Menu** | `space-hunter` | Launches the target menu and prompts for an optional display limit. |
| **Targeted Scan (Default Limit)** | `space-hunter /var/log` | Scans the path and defaults to showing the top 100 entries. |
| **Targeted Scan (Custom Limit)** | `space-hunter /var/log 20` | Scans the path and restricts output to the top 20 largest items. |

---

## Interactive TUI Layout

```text
=======================================================================
                      SPACE HUNTER STORAGE TUI                         
=======================================================================
Use [UP/DOWN] arrows to select target, [ENTER] to execute.

    Root Directory (/)                  (System Partition Root)
    User Home (/home/steppan)           (User Storage Environment)
  > /                                   ([55G/180G used] — 125G free)
    /boot/efi                           ([50M/2048M used] — 2.0G free)
    /hard                               ([175G/930G used] — 755G free)
=======================================================================

Enter number of items to display [Default: 100]: 20
