#!/usr/bin/env bash
# Output current volume (percentage) and connected Bluetooth device for i3bar.
# Bluetooth devices with battery support render as: MOMENTUM 4(🔋100%) - 42%

set -euo pipefail

# bluetoothctl colorizes even when piped (e.g. ESC[1;30m...ESC[0m); strip CSI SGR.
strip_ansi() {
    # shellcheck disable=SC2001
    sed $'s/\033\\[[0-9;]*[[:alpha:]]//g' <<<"$1"
}

volume_display() {
    local line pct muted=""

    if ! line=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | head -1); then
        printf '?'
        return
    fi

    if pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | grep -q 'yes'; then
        muted=" muted"
    fi

    pct=$(awk -F'/' '{gsub(/[^0-9]/, "", $2); print $2}' <<<"$line")
    printf '%s%%%s' "${pct:-?}" "$muted"
}

# Battery % for a Bluetooth MAC via bluetoothctl, empty if unavailable.
bt_battery_pct() {
    local mac=$1 info pct

    info=$(strip_ansi "$(bluetoothctl info "$mac" 2>/dev/null)") || return 0
    pct=$(awk -F'[()]' '/Battery Percentage:/ { gsub(/[[:space:]]/, "", $2); print $2; exit }' <<<"$info")
    if [[ -n "$pct" && "$pct" =~ ^[0-9]+$ ]]; then
        printf '%s' "$pct"
    fi
}

# Connected BT device as "Name(🔋N%)", or fallback to PulseAudio sink description.
device_display() {
    local line mac name bat default_sink

    line=$(strip_ansi "$(bluetoothctl devices Connected 2>/dev/null | head -1)") || true
    if [[ -n "$line" ]]; then
        # "Device AA:BB:CC:DD:EE:FF Some Name"
        mac=$(awk '{print $2}' <<<"$line")
        name=$(cut -d' ' -f3- <<<"$line")
        bat=$(bt_battery_pct "$mac")
        if [[ -n "$bat" ]]; then
            printf '%s(🔋%s%%)' "$name" "$bat"
        else
            printf '%s' "$name"
        fi
        return
    fi

    default_sink=$(pactl get-default-sink 2>/dev/null) || return 1
    pactl list sinks 2>/dev/null | awk -v sink="$default_sink" '
        /^Name: / { name = $2 }
        /^Description: / {
            if (name == sink) {
                sub(/^Description: /, "")
                print
                exit
            }
        }
    '
}

main() {
    local vol device

    vol=$(volume_display)
    device=$(device_display)

    if [[ -n "$device" ]]; then
        printf '%s - %s' "$device" "$vol"
    else
        printf '%s' "$vol"
    fi
}

main "$@"
