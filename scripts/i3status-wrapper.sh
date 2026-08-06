#!/usr/bin/env bash
# Inject weather + volume/Bluetooth into i3status JSON for i3bar/swaybar.
# Order (left → right on the status side): weather, audio, then i3status modules.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
I3STATUS_CONF="${I3STATUS_CONF:-${XDG_CONFIG_HOME:-$HOME/.config}/i3status/config}"

WEATHER_COLOR="#EBCB8B"
AUDIO_COLOR="#89CFF0"

weather_block() {
    local text
    text=$("$SCRIPT_DIR/i3status-weather.sh")
    jq -cn --arg text "$text" --arg color "$WEATHER_COLOR" \
        '[{"full_text": $text, "name": "weather", "color": $color}]'
}

audio_block() {
    local text
    text=$("$SCRIPT_DIR/i3status-audio.sh")
    jq -cn --arg text "$text" --arg color "$AUDIO_COLOR" \
        '[{"full_text": $text, "name": "audio_bt", "color": $color}]'
}

i3status -c "$I3STATUS_CONF" | {
    IFS= read -r header || exit 0
    printf '%s\n' "$header"

    IFS= read -r array_start || exit 0
    printf '%s\n' "$array_start"

    while IFS= read -r line; do
        prefix=""
        if [[ $line == ,* ]]; then
            line="${line:1}"
            prefix=","
        fi

        weather=$(weather_block)
        audio=$(audio_block)
        printf '%s%s\n' "$prefix" "$(
            jq -cn \
                --argjson weather "$weather" \
                --argjson audio "$audio" \
                --argjson blocks "$line" \
                '$weather + $audio + $blocks'
        )"
    done
}
