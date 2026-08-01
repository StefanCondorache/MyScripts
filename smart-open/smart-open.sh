#!/bin/bash

# Copyright (c) 2026 Condorache Ștefan-Eugen
#
# This software is released under the MIT License.

# Editor used for text-like files. Override with SMART_OPEN_EDITOR.
EDITOR_CMD="${SMART_OPEN_EDITOR:-xed}"

# Define standardized output tags
INFO="[INFO]"
ERROR="[ERROR]"

usage() {
    echo "Usage: smart-open [file|directory ...]"
    echo ""
    echo "  no arguments  Opens the current directory in the file manager."
    echo "  directory     Opened with xdg-open (file manager)."
    echo "  text / code   Opened with \$SMART_OPEN_EDITOR (default: xed)."
    echo "  anything else Handed to xdg-open (images, PDFs, video, archives...)."
}

case "$1" in
    -h|--help)
        usage
        exit 0
        ;;
esac

# Fall back to the standard editor variables if the configured one is missing
if ! command -v "${EDITOR_CMD%% *}" >/dev/null 2>&1; then
    EDITOR_CMD="${VISUAL:-$EDITOR}"
fi

# Detach launched apps so they survive closing the terminal
SETSID=$(command -v setsid)

launch() {
    $SETSID "$@" >/dev/null 2>&1 &
}

# No arguments: open the current directory
if [ $# -eq 0 ]; then
    launch xdg-open .
    exit 0
fi

STATUS=0

for target in "$@"; do
    if [ ! -e "$target" ]; then
        echo "$ERROR '$target' does not exist." >&2
        STATUS=1
        continue
    fi

    if [ -d "$target" ]; then
        launch xdg-open "$target"
        continue
    fi

    # Determine MIME type (e.g. text/plain, image/png, application/pdf)
    mime=$(file --mime-type -b "$target")

    # Text, code, structured data and empty files go to the editor
    if [ -n "$EDITOR_CMD" ] &&
       { [[ "$mime" =~ ^text/ ]] ||
         [[ "$mime" =~ json|xml|yaml|javascript|x-shellscript|x-empty ]]; }; then
        # Unquoted on purpose so editors with flags (e.g. "code -n") still work
        launch $EDITOR_CMD "$target"
    else
        launch xdg-open "$target"
    fi
done

if [ "$STATUS" -ne 0 ]; then
    echo "$INFO Some targets were skipped." >&2
fi

exit $STATUS
