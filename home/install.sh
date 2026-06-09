#!/usr/bin/env zsh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

for file in "$SCRIPT_DIR"/.*; do
    filename="$(basename "$file")"
    [[ "$filename" == "." || "$filename" == ".." || "$filename" == "install.sh" ]] && continue

    dest="$HOME/$filename"

    if [[ -f "$dest" ]]; then
        backup="${dest}.bak.$(date +%Y%m%d%H%M%S)"
        mv "$dest" "$backup"
        echo "Backed up $dest -> $backup"
    fi

    cp "$file" "$dest"
    chown daniel:daniel "$dest"
    chmod 744 "$dest"
    echo "Installed $filename"
done
