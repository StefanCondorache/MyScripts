# Space Hunter

A dependency-free Bash TUI utility designed to identify large files and track system storage consumption.

---

## Technical Features

* **Proportional Padding Engine** — Dynamically measures path lengths to scale its layout perfectly to your active terminal width.
* **Storage Ratio Overview** — Pulls and displays real-time `[Used/Total]` consumption metrics alongside total free space.
* **Native Navigation Menu** — Built using pure terminal capabilities (`tput`) to process arrow-key selections without external dependencies like `dialog` or `whiptail`.
* **Configurable Item Limiting** — Allows defining a maximum result threshold on demand, preventing terminal flooding during heavy file directory sweeps.
* **Granular Target Selection** — Defaults to isolated file calculations (`-type f`), with a fallback switch to include complete structural directories.
* **Filesystem-Isolated Scanning** — Leverages root-isolated logic (`-xdev` and `du -ahx`) to safely calculate target boundaries without crossing mount points.
* **Conditional Privilege Escalation** — Only invokes `sudo` when the target actually requires it. Scanning inside your own home directory never asks for a password.

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
| **Interactive TUI Menu** | `space-hunter` | Launches the target menu, prompts for directory inclusion, and asks for a display limit. |
| **Targeted Scan (Files Only)** | `space-hunter /var/log 20` | Restricts output strictly to the top 20 largest individual files. |
| **Targeted Scan (With Directories)** | `space-hunter -d /var/log 20` | Includes cumulative directory size blocks alongside large files, bounded to 20 items. |
| **Help** | `space-hunter -h` | Prints usage and exits. |

### Flags

| Flag | Effect |
| --- | --- |
| `-d`, `--dirs` | Include directory totals, not just individual files. |
| `-h`, `--help` | Show usage. |

Flags may be placed anywhere in the command; the remaining arguments are read as `path` then `limit`. An invalid or zero limit falls back to the default of 100.

---

## Interactive TUI Layout

```text
=======================================================================
                      SPACE HUNTER STORAGE TUI                         
=======================================================================
Use [UP/DOWN] arrows to select target, [ENTER] to execute, [Q] to quit.

    Root Directory (/)                  (System Partition Root)
    User Home (/home/steppan)           (User Storage Environment)
  > /                                   ([55G/180G used] — 125G free)
    /boot/efi                           ([50M/2048M used] — 2.0G free)
    /hard                               ([175G/930G used] — 755G free)
=======================================================================

Include directories in the scan results? (y/N): n
Enter number of items to display [Default: 100]: 20
```

---

## Compatibility

Written and tested on **Arch Linux**. Requires only `bash`, `coreutils` (`du`, `df`, `sort`), `findutils` and `ncurses` (`tput`) — all present on a standard install.
