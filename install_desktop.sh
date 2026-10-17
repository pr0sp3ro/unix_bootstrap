#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
desktop_module=desktop-sway
selected_backend=''
options=()

for argument in "$@"; do
    case "$argument" in
        --wayland|--xorg)
            if [[ -n $selected_backend && $selected_backend != "$argument" ]]; then
                echo 'Select either --wayland or --xorg.' >&2
                exit 1
            fi

            selected_backend=$argument

            if [[ $argument == --xorg ]]; then
                desktop_module=desktop-i3
            fi
            ;;
        --dry-run)
            options+=("$argument")
            ;;
        -h|--help)
            echo 'Usage: ./install_desktop.sh [--wayland|--xorg] [--dry-run]'
            echo 'Default: Wayland with Sway. Xorg uses i3.'
            exit 0
            ;;
        *)
            printf 'Unknown option: %s\n' "$argument" >&2
            exit 1
            ;;
    esac
done

exec "$SCRIPT_DIR/bootstrap" install "$desktop_module" "${options[@]}"
