#!/bin/bash
# Automatically start terminal windows + tmux on sway login / config load.
# - Workspace 1: ~/Code + tmux session "code"
# - Workspace 2: ~ + tmux session "home"
# - Workspace 3: ~ + tmux session "scratch"
#
# Run from sway config with:
#   exec --no-startup-id $HOME/.config/i3/scripts/startup-terminals.sh
#
# NOTE: This will run on `swaymsg reload` too. If that happens you may get
# duplicate terminal windows — just close the extras.

LOG_FILE="$HOME/.cache/sway-startup.log"
mkdir -p "$(dirname "$LOG_FILE")"

# Redirect all output to a log file so we can debug what happened on startup.
exec >>"$LOG_FILE" 2>&1

echo "=== $(date '+%F %T') startup-terminals.sh started ==="
echo "USER=$USER HOME=$HOME"
echo "SWAYSOCK=${SWAYSOCK:-<unset>}"
echo "XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-<unset>}"
echo "PATH=$PATH"
echo "Boot ID: $(cat /proc/sys/kernel/random/boot_id 2>/dev/null || echo unknown)"

# Small delay so that sway is fully ready, fonts, bar, etc. are up.
sleep 2

launch_terminal() {
    local ws="$1"
    local session="$2"
    local cwd="$3"

    mkdir -p "$cwd"
    echo ">>> ws$ws: alacritty --working-directory $cwd -e tmux new-session -A -s $session"

    # Best practice: do the workspace switch + exec in one swaymsg command.
    # -A on tmux: create the session or attach if it already exists.
    if swaymsg "workspace number $ws; exec alacritty --working-directory \"$cwd\" -e tmux new-session -A -s \"$session\""; then
        echo "    success"
    else
        echo "    ERROR from swaymsg"
    fi

    sleep 0.3
}

launch_terminal 1 code "$HOME/Code"
launch_terminal 2 home "$HOME"
launch_terminal 3 scratch "$HOME"

swaymsg "workspace number 1" >/dev/null 2>&1 || true

echo "=== $(date '+%F %T') startup-terminals.sh finished ==="
