#!/usr/bin/env bash
# Cached weather for i3status wrapper. Prints one line: "🌤️ +26°C"
# Defaults: Palo Alto, CA in Celsius (wttr.in metric). Falls back to cache on failure.
#
# Optional overrides (export in ~/.secrets or env):
#   WTTR_LOCATION      city name or lat,lon  e.g. "London" or "37.44,-122.14"
#   WEATHER_CACHE_TTL  seconds (default 1800)

set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/i3status"
CACHE="$CACHE_DIR/weather.txt"
TTL="${WEATHER_CACHE_TTL:-1800}"
LOCATION="${WTTR_LOCATION:-Palo Alto}"

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
        printf '%s\n' '🌤 ?'
    fi
}

if [[ $(cache_age) -lt $TTL ]]; then
    cat "$CACHE"
    exit 0
fi

# m = metric (°C). Location is path-encoded by curl --get --data-urlencode via manual encode:
# spaces → + for wttr.in path segment.
loc_path=${LOCATION// /+}
url="https://wttr.in/${loc_path}?m&format=%c+%t"
text=$(curl -fsS --max-time 5 \
    -H 'Accept-Language: en' \
    -A 'i3status-weather/1.0' \
    "$url" 2>/dev/null | tr -d '\r\n' | xargs) || {
    emit_cache_or_placeholder
    exit 0
}

if [[ -z "$text" ]]; then
    emit_cache_or_placeholder
    exit 0
fi

printf '%s\n' "$text" | tee "$CACHE"
