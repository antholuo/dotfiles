#!/usr/bin/env bash
# Random lockscreen image for swaylock.
# Picks a random image from the lockscreen directory each time.

set -euo pipefail

dir="$HOME/Code/dotfiles/lockscreen"
img=$(find "$dir" -maxdepth 1 -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.webp' \) | shuf -n1)

if [[ -z "${img:-}" ]]; then
  # Fallback if the directory is empty
  exec swaylock -f -c 000000
fi

exec swaylock -f -i "$img" -s fill
