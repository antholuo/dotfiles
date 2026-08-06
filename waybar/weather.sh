#!/usr/bin/env bash
# Cached weather for Waybar (JSON: text + tooltip).
# Uses wttr.in for auto-IP location; falls back to last good cache on failure.
#
# Optional overrides (export in ~/.secrets or env):
#   WTTR_LOCATION   city name or lat,lon  e.g. "London" or "37.77,-122.42"
#   WEATHER_CACHE_TTL  seconds (default 1800)

set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/waybar"
CACHE="$CACHE_DIR/weather.json"
TTL="${WEATHER_CACHE_TTL:-1800}"
LOCATION="${WTTR_LOCATION:-}"

mkdir -p "$CACHE_DIR"

cache_age() {
    if [[ ! -f "$CACHE" ]]; then
        echo 999999
        return
    fi
    echo $(($(date +%s) - $(stat -c %Y "$CACHE")))
}

emit_cache_or_placeholder() {
    if [[ -f "$CACHE" ]]; then
        cat "$CACHE"
    else
        printf '%s\n' '{"text":"🌤 ?","tooltip":"Weather unavailable"}'
    fi
}

if [[ $(cache_age) -lt $TTL ]]; then
    cat "$CACHE"
    exit 0
fi

# wttr.in format: line1 = bar text, line2 = tooltip
# %c condition glyph, %t temperature, %l location, %C text condition, %w wind
url="https://wttr.in/${LOCATION}?format=%c+%t%0A%l:+%C+%t,+%w"
raw=$(curl -fsS --max-time 5 \
    -H 'Accept-Language: en' \
    -A 'waybar-weather/1.0' \
    "$url" 2>/dev/null) || {
    emit_cache_or_placeholder
    exit 0
}

text=$(printf '%s' "$raw" | sed -n '1p' | tr -d '\r' | xargs)
tooltip=$(printf '%s' "$raw" | sed -n '2p' | tr -d '\r' | xargs)

if [[ -z "$text" ]]; then
    emit_cache_or_placeholder
    exit 0
fi

if [[ -z "$tooltip" ]]; then
    tooltip="$text"
fi

# JSON-escape via jq
jq -cn --arg text "$text" --arg tooltip "$tooltip" \
    '{text: $text, tooltip: $tooltip}' | tee "$CACHE"
