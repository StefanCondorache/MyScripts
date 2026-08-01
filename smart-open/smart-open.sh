#!/usr/bin/env bash

# If no file is provided, open current directory in xdg-open
if [ -z "$1" ]; then
    xdg-open .
    exit 0
fi

for file in "$@"; do
    # Check if file exists
    if [ ! -e "$file" ]; then
        echo "Error: '$file' does not exist."
        continue
    fi

    # Check if it's a directory
    if [ -d "$file" ]; then
        xdg-open "$file" &
        continue
    fi

    # Determine MIME type (e.g., text/plain, image/png, application/pdf)
    mime=$(file --mime-type -b "$file")

    # If it's plain text, code, or JSON/XML/etc., open with xed
    if [[ "$mime" =~ ^text/ ]] || [[ "$mime" =~ json|xml|yaml|javascript|x-shellscript ]]; then
        xed "$file" &
    else
        # Fall back to default system application for binaries, images, PDFs, videos, etc.
        xdg-open "$file" >/dev/null 2>&1 &
    fi
done
