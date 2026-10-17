#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
options=()
packages=()

for argument in "$@"; do
    case "$argument" in
        --dry-run|-h|--help)
            options+=("$argument")
            ;;
        --)
            ;;
        -*)
            printf 'Unknown option: %s\n' "$argument" >&2
            exit 1
            ;;
        *)
            packages+=("$argument")
            ;;
    esac
done

exec "$SCRIPT_DIR/bootstrap" install composer "${options[@]}" -- "${packages[@]}"
