# Smart Open (`smart-open`)

A one-command universal opener. Give it anything — a file, a folder, a list of both — and it picks the right application instead of making you remember which one.

Text and code go to your editor. Everything else goes to the desktop default.

---

## Features

* **MIME-based routing** — Uses `file --mime-type` rather than file extensions, so an extensionless script still opens in the editor and a mislabelled `.txt` image still opens in the image viewer.
* **Multiple targets** — Accepts any number of files and directories in a single call, each routed independently.
* **Detached launching** — Applications are started with `setsid`, so closing the terminal (or the SSH session) does not kill what you opened.
* **Configurable editor** — Defaults to `xed`, falls back to `$VISUAL` / `$EDITOR` if it is not installed, and to `xdg-open` if neither is set.
* **Bare invocation** — Running `smart-open` with no arguments opens the current directory in your file manager.

---

## Prerequisites

* **xdg-utils** (`xdg-open`) — Resolves the desktop default application. Required.
* **file** — MIME detection. Present on every standard install.
* **util-linux** (`setsid`) — Detaches launched processes. Optional; without it the script still works.
* An editor — `xed` by default, but any editor works (see [Configuration](#configuration)).

---

## Installation

1. Clone the repository:
    ```bash
    git clone https://github.com/StefanCondorache/combo-toggle.git
    cd combo-toggle/smart-open
    ```

2. Run the installer:
    ```bash
    ./install.sh
    ```

The installer copies the script to `/usr/local/bin/smart-open` and drops the `.sh` extension, registering it as a system-wide command.

---

## Usage

| Command | Result |
| --- | --- |
| `smart-open` | Opens the current directory in the file manager. |
| `smart-open notes.md` | Opens in the editor. |
| `smart-open report.pdf photo.jpg` | Both handed to their desktop defaults. |
| `smart-open src/ main.py` | Folder in the file manager, file in the editor. |
| `smart-open -h` | Shows usage. |

Missing paths are reported on stderr and skipped; the remaining targets still open, and the command exits with status `1`.

### Suggested alias

```bash
# ~/.bashrc
alias o='smart-open'
```

Then `o .`, `o config.yml`, `o *.png`.

---

## Routing rules

| MIME type | Opens with |
| --- | --- |
| `text/*` | Editor |
| `*json*`, `*xml*`, `*yaml*`, `*javascript*`, `*x-shellscript*` | Editor |
| `inode/x-empty` (empty file) | Editor |
| Directory | `xdg-open` (file manager) |
| Everything else | `xdg-open` (images, PDFs, video, archives, binaries) |

---

## Configuration

Set `SMART_OPEN_EDITOR` to use a different editor. Flags are supported:

```bash
# ~/.bashrc
export SMART_OPEN_EDITOR="code -n"
```

If that command is not installed, the script falls back to `$VISUAL`, then `$EDITOR`, then `xdg-open`.

---

## Compatibility

Written and tested on **Arch Linux** with a standard freedesktop.org environment. It relies only on `xdg-open` and `file`, so it should work on any Linux desktop; the only distribution-specific default is `xed` (Cinnamon/Mint), which you can change with `SMART_OPEN_EDITOR`.
