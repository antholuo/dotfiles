#!/usr/bin/env bash
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --------------------------------------------------------------------------
# Helpers
# --------------------------------------------------------------------------
info()  { printf '\033[1;34m[info]\033[0m  %s\n' "$*"; }
ok()    { printf '\033[1;32m[ok]\033[0m    %s\n' "$*"; }
warn()  { printf '\033[1;33m[warn]\033[0m  %s\n' "$*"; }
die()   { printf '\033[1;31m[err]\033[0m   %s\n' "$*" >&2; exit 1; }

command_exists() { command -v "$1" &>/dev/null; }

# Run a cargo install but warn and continue on failure instead of aborting.
cargo_install() {
    local crate="$1"; shift
    # shellcheck disable=SC1091
    source "$HOME/.cargo/env" 2>/dev/null || true
    if cargo install --locked "$crate" "$@"; then
        ok "$crate installed"
    else
        warn "$crate failed to install — skipping (see above for details)"
    fi
}

link_file() {
    local src="$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ]; then
        rm "$dst"
    elif [ -e "$dst" ]; then
        warn "Backing up existing $dst -> ${dst}.bak"
        mv "$dst" "${dst}.bak"
    fi
    ln -s "$src" "$dst"
    ok "Linked $dst -> $src"
}

usage() {
    cat <<EOF
Usage: ./install.sh [OPTIONS]

Options:
  --from=USER@HOST   SCP secrets and SSH keys from an existing machine
  -h, --help         Show this help

Examples:
  ./install.sh
  ./install.sh --from=anni@nuc1
EOF
}

# --------------------------------------------------------------------------
# Argument parsing
# --------------------------------------------------------------------------
FROM_HOST=""

for arg in "$@"; do
    case "$arg" in
        --from=*) FROM_HOST="${arg#--from=}" ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown argument: $arg (try --help)" ;;
    esac
done

# --------------------------------------------------------------------------
# 1. System packages (apt)
#    Curated list also lives in packages/apt-core.txt for migration diffs.
# --------------------------------------------------------------------------
info "Installing system packages..."
sudo apt-get update -qq

# Install packages one logical group at a time so a single missing name
# does not abort the whole set (Ubuntu package renames happen).
apt_install_group() {
    # shellcheck disable=SC2068
    sudo apt-get install -y -qq $@ 2>/dev/null || warn "Some packages failed in: $*"
}

apt_install_group \
    git tmux ripgrep fd-find bat curl wget unzip \
    build-essential pkg-config libdbus-1-dev \
    python3 python3-pip python3-venv python-is-python3 \
    btop tig xclip wl-clipboard silversearcher-ag \
    nodejs npm clang clangd jq ncdu net-tools usbutils \
    openssh-server ca-certificates software-properties-common pipx

apt_install_group \
    sway swaybg swayidle swaylock waybar i3status \
    bemenu j4-dmenu-desktop grim flameshot alacritty \
    xdg-desktop-portal xdg-desktop-portal-wlr \
    network-manager-gnome alsa-utils

apt_install_group \
    bluez upower pulseaudio-utils \
    pipewire pipewire-pulse wireplumber libspa-0.2-bluetooth

apt_install_group \
    mosh can-utils wireshark sshfs screen lrzsz pass

# fd is installed as fdfind on Debian/Ubuntu
if command_exists fdfind && ! command_exists fd; then
    sudo ln -sf "$(which fdfind)" /usr/local/bin/fd
    ok "Linked fdfind -> fd"
fi

# bat is installed as batcat on Debian/Ubuntu
if command_exists batcat && ! command_exists bat; then
    sudo ln -sf "$(which batcat)" /usr/local/bin/bat
    ok "Linked batcat -> bat"
fi

# Wireshark: allow non-root capture non-interactively, add user to group
info "Configuring Wireshark for non-root capture..."
echo "wireshark-common wireshark-common/install-setuid boolean true" \
    | sudo debconf-set-selections
sudo dpkg-reconfigure -f noninteractive wireshark-common
sudo usermod -aG wireshark "$USER"
ok "Wireshark configured (re-login for group to apply)"

ok "System packages installed"

# --------------------------------------------------------------------------
# 2. Locale (UTF-8)
# --------------------------------------------------------------------------
info "Ensuring UTF-8 locale..."
if ! locale -a 2>/dev/null | grep -qi "en_US.utf8"; then
    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8
    ok "Locale en_US.UTF-8 generated"
else
    ok "Locale en_US.UTF-8 already available"
fi

# --------------------------------------------------------------------------
# 3. Iosevka Nerd Font
# --------------------------------------------------------------------------
FONT_DIR="$HOME/.local/share/fonts"
if ! fc-list 2>/dev/null | grep -qi "Iosevka Nerd"; then
    info "Installing Iosevka Nerd Font..."
    mkdir -p "$FONT_DIR"
    curl -L https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Iosevka.tar.xz \
        -o /tmp/Iosevka.tar.xz
    tar -xf /tmp/Iosevka.tar.xz -C "$FONT_DIR"
    fc-cache -fv >/dev/null 2>&1
    rm /tmp/Iosevka.tar.xz
    ok "Iosevka Nerd Font installed"
else
    ok "Iosevka Nerd Font already installed"
fi

# --------------------------------------------------------------------------
# 4. Neovim (prebuilt release)
# --------------------------------------------------------------------------
if ! command_exists nvim; then
    info "Installing Neovim..."
    NVIM_VERSION="v0.12.2"
    curl -L "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-x86_64.tar.gz" \
        -o /tmp/nvim-linux-x86_64.tar.gz
    sudo rm -rf /opt/nvim-linux-x86_64
    sudo tar -C /opt -xzf /tmp/nvim-linux-x86_64.tar.gz
    rm /tmp/nvim-linux-x86_64.tar.gz
    ok "Neovim ${NVIM_VERSION} installed to /opt/nvim-linux-x86_64"
else
    ok "Neovim already installed: $(nvim --version | head -1)"
fi

# --------------------------------------------------------------------------
# 5. lazy.nvim (pre-install so nvim doesn't need to bootstrap on first open)
# --------------------------------------------------------------------------
LAZY_PATH="$HOME/.local/share/nvim/lazy/lazy.nvim"
if [ ! -f "$LAZY_PATH/lua/lazy/init.lua" ]; then
    info "Pre-installing lazy.nvim..."
    rm -rf "$LAZY_PATH"
    git clone --filter=blob:none --branch=stable \
        https://github.com/folke/lazy.nvim.git "$LAZY_PATH"
    ok "lazy.nvim installed"
else
    ok "lazy.nvim already present"
fi

# --------------------------------------------------------------------------
# 6. fzf (git install — apt version does not work, always build from source)
# --------------------------------------------------------------------------
info "Installing fzf from source..."
# Remove apt-installed fzf if present — it conflicts with the source build
sudo apt-get remove -y fzf 2>/dev/null || true
# Always wipe and re-clone so we get a clean, up-to-date build
rm -rf "$HOME/.fzf"
git clone --depth 1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
"$HOME/.fzf/install" --bin --key-bindings --completion --no-update-rc
ok "fzf installed from source"

# --------------------------------------------------------------------------
# 7. Starship prompt
# --------------------------------------------------------------------------
if ! command_exists starship; then
    info "Installing Starship..."
    curl -sS https://starship.rs/install.sh | sh -s -- --yes
    ok "Starship installed"
else
    ok "Starship already installed: $(starship --version | head -1)"
fi

# --------------------------------------------------------------------------
# 7. Rust / Cargo
# --------------------------------------------------------------------------
if ! command_exists cargo; then
    info "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # shellcheck disable=SC1091
    source "$HOME/.cargo/env"
    ok "Rust installed"
else
    ok "Rust already installed"
fi

# tree-sitter-cli (needed by nvim treesitter)
if ! command_exists tree-sitter; then
    info "Installing tree-sitter-cli..."
    cargo_install tree-sitter-cli
fi

# bluetui — Bluetooth device TUI (optional convenience)
if ! command_exists bluetui; then
    info "Installing bluetui..."
    cargo_install bluetui
else
    ok "bluetui already installed"
fi

# --------------------------------------------------------------------------
# 8. AstroNvim recommended tools (lazygit, bottom, gdu)
# --------------------------------------------------------------------------
# lazygit — AstroNvim binds <Leader>tl / <Leader>gg
if ! command_exists lazygit; then
    info "Installing lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" \
        | grep -Po '"tag_name": "v\K[^"]*')
    curl -Lo /tmp/lazygit.tar.gz \
        "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar -xf /tmp/lazygit.tar.gz -C /tmp lazygit
    sudo install /tmp/lazygit /usr/local/bin
    rm /tmp/lazygit /tmp/lazygit.tar.gz
    ok "lazygit installed"
else
    ok "lazygit already installed"
fi

# bottom (btm) — AstroNvim binds <Leader>tt
if ! command_exists btm; then
    info "Installing bottom..."
    cargo_install bottom
else
    ok "bottom already installed"
fi

# gdu — AstroNvim binds <Leader>tu
if ! command_exists gdu; then
    info "Installing gdu..."
    curl -L https://github.com/dundee/gdu/releases/latest/download/gdu_linux_amd64.tgz \
        -o /tmp/gdu.tgz
    tar -xf /tmp/gdu.tgz -C /tmp
    sudo install /tmp/gdu_linux_amd64 /usr/local/bin/gdu
    rm /tmp/gdu.tgz /tmp/gdu_linux_amd64
    ok "gdu installed"
else
    ok "gdu already installed"
fi

# --------------------------------------------------------------------------
# 9. Alacritty themes
# --------------------------------------------------------------------------
ALACRITTY_THEMES_DIR="$HOME/.config/alacritty/themes"
if [ ! -d "$ALACRITTY_THEMES_DIR" ]; then
    info "Installing Alacritty themes..."
    mkdir -p "$HOME/.config/alacritty"
    git clone --depth 1 https://github.com/alacritty/alacritty-theme "$ALACRITTY_THEMES_DIR"
    ok "Alacritty themes installed"
else
    ok "Alacritty themes already present"
fi

STARSHIP_TOML="$HOME/.config/starship.toml"
if [ ! -f "$STARSHIP_TOML" ]; then
    mkdir -p "$HOME/.config"
    printf 'command_timeout = 3000\n' > "$STARSHIP_TOML"
    ok "Created $STARSHIP_TOML"
else
    ok "starship.toml already present"
fi

# --------------------------------------------------------------------------
# 10. Flameshot (Wayland/grim backend)
# --------------------------------------------------------------------------
FLAMESHOT_INI="$HOME/.config/flameshot/flameshot.ini"
if [ ! -f "$FLAMESHOT_INI" ]; then
    info "Creating flameshot config with grim backend..."
    mkdir -p "$HOME/.config/flameshot"
    cat > "$FLAMESHOT_INI" <<'INI'
[General]
useGrimAdapter=true
INI
    ok "Flameshot configured to use grim adapter"
else
    if ! grep -qE 'useGrim(Adapter)?=true' "$FLAMESHOT_INI" 2>/dev/null; then
        warn "Flameshot config exists but grim not enabled — set useGrimAdapter=true under [General] in $FLAMESHOT_INI"
    else
        ok "Flameshot already configured with grim"
    fi
fi

# --------------------------------------------------------------------------
# 11. Google Chrome
# --------------------------------------------------------------------------
if ! command_exists google-chrome-stable && ! command_exists google-chrome; then
    info "Installing Google Chrome..."
    curl -L https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb \
        -o /tmp/google-chrome.deb
    sudo dpkg -i /tmp/google-chrome.deb 2>/dev/null || true
    sudo apt-get install -f -y -qq   # fix any dependency gaps
    rm /tmp/google-chrome.deb
    ok "Google Chrome installed"
else
    ok "Google Chrome already installed"
fi

# --------------------------------------------------------------------------
# 12. Snaps (Spotify, Mattermost)
# --------------------------------------------------------------------------
if ! snap list spotify &>/dev/null 2>&1; then
    info "Installing Spotify..."
    sudo snap install spotify
    ok "Spotify installed"
else
    ok "Spotify already installed"
fi

if ! snap list mattermost-desktop &>/dev/null 2>&1; then
    info "Installing Mattermost Desktop..."
    sudo snap install mattermost-desktop
    ok "Mattermost Desktop installed"
else
    ok "Mattermost Desktop already installed"
fi

# --------------------------------------------------------------------------
# 13. Claude Code CLI
# --------------------------------------------------------------------------
if ! command_exists claude; then
    info "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh -o /tmp/install-claude.sh
    chmod +x /tmp/install-claude.sh
    /tmp/install-claude.sh
    rm -f /tmp/install-claude.sh
    ok "Claude Code installed"
else
    ok "Claude Code already installed: $(claude --version 2>/dev/null | head -1)"
fi

# --------------------------------------------------------------------------
# 14. Grok CLI (public x.ai installer)
# --------------------------------------------------------------------------
if ! command_exists grok; then
    info "Installing Grok CLI..."
    if curl -fsSL https://x.ai/desktop/install.sh -o /tmp/install-grok.sh 2>/dev/null; then
        bash /tmp/install-grok.sh
        ok "Grok installed from x.ai"
    else
        warn "Grok install failed — install manually:"
        warn "  curl -fsSL https://x.ai/desktop/install.sh | bash"
    fi
    rm -f /tmp/install-grok.sh
else
    ok "Grok already installed: $(grok --version 2>/dev/null | head -1)"
fi

# --------------------------------------------------------------------------
# 15. asammdf (MDF/CAN log GUI) in ~/.venv/asammdf
# --------------------------------------------------------------------------
ASAMMDF_VENV="$HOME/.venv/asammdf"
if [ ! -x "$ASAMMDF_VENV/bin/asammdf" ]; then
    info "Installing asammdf[gui] into $ASAMMDF_VENV ..."
    mkdir -p "$HOME/.venv"
    if python3 -m venv "$ASAMMDF_VENV" \
        && "$ASAMMDF_VENV/bin/pip" install --upgrade pip \
        && "$ASAMMDF_VENV/bin/pip" install 'asammdf[gui]'; then
        ok "asammdf[gui] installed → $ASAMMDF_VENV"
        info "  Run:  $ASAMMDF_VENV/bin/asammdf"
        info "  Or:    source $ASAMMDF_VENV/bin/activate && asammdf"
    else
        warn "asammdf[gui] install failed — install manually when network allows:"
        warn "  python3 -m venv $ASAMMDF_VENV"
        warn "  $ASAMMDF_VENV/bin/pip install 'asammdf[gui]'"
    fi
else
    ok "asammdf already present: $ASAMMDF_VENV/bin/asammdf"
fi

# --------------------------------------------------------------------------
# 16. Symlink dotfiles
# --------------------------------------------------------------------------
info "Linking dotfiles..."

link_file "$DOTFILES_DIR/bashrc"       "$HOME/.bashrc"
link_file "$DOTFILES_DIR/tmux.conf"    "$HOME/.tmux.conf"

# gitconfig — don't clobber existing (may have machine-specific email)
if [ ! -f "$HOME/.gitconfig" ]; then
    link_file "$DOTFILES_DIR/gitconfig" "$HOME/.gitconfig"
else
    warn "~/.gitconfig already exists — skipping (check gitconfig in repo)"
fi

link_file "$DOTFILES_DIR/config/nvim"             "$HOME/.config/nvim"
link_file "$DOTFILES_DIR/config/lazygit/config.yml" "$HOME/.config/lazygit/config.yml"
link_file "$DOTFILES_DIR/alacritty.toml"          "$HOME/.config/alacritty/alacritty.toml"
link_file "$DOTFILES_DIR/sway/config"             "$HOME/.config/sway/config"

# Waybar configs (optional / unused; bar is i3status + wrapper)
mkdir -p "$HOME/.config/waybar"
link_file "$DOTFILES_DIR/waybar/config"           "$HOME/.config/waybar/config"
link_file "$DOTFILES_DIR/waybar/style.css"        "$HOME/.config/waybar/style.css"
link_file "$DOTFILES_DIR/waybar/weather.sh"       "$HOME/.config/waybar/weather.sh"
chmod +x "$DOTFILES_DIR/waybar/weather.sh"

# i3status wrapper scripts (weather + audio/BT for swaybar)
link_file "$DOTFILES_DIR/i3_config"               "$HOME/.config/i3/config"
link_file "$DOTFILES_DIR/i3status.conf"           "$HOME/.config/i3status/config"
mkdir -p "$HOME/.config/i3/scripts"
link_file "$DOTFILES_DIR/scripts/i3status-audio.sh"    "$HOME/.config/i3/scripts/i3status-audio.sh"
link_file "$DOTFILES_DIR/scripts/i3status-weather.sh"  "$HOME/.config/i3/scripts/i3status-weather.sh"
link_file "$DOTFILES_DIR/scripts/i3status-wrapper.sh"  "$HOME/.config/i3/scripts/i3status-wrapper.sh"
link_file "$DOTFILES_DIR/scripts/startup-terminals.sh" "$HOME/.config/i3/scripts/startup-terminals.sh"
chmod +x "$DOTFILES_DIR/scripts/i3status-audio.sh" \
         "$DOTFILES_DIR/scripts/i3status-weather.sh" \
         "$DOTFILES_DIR/scripts/i3status-wrapper.sh" \
         "$DOTFILES_DIR/scripts/startup-terminals.sh"

# --------------------------------------------------------------------------
# 17. Set nvim as default editor system-wide
# --------------------------------------------------------------------------
if command_exists nvim; then
    sudo update-alternatives --install /usr/bin/editor editor /opt/nvim-linux-x86_64/bin/nvim 60 2>/dev/null || true
    sudo update-alternatives --set editor /opt/nvim-linux-x86_64/bin/nvim 2>/dev/null || true
fi

# --------------------------------------------------------------------------
# 18. Create ~/.secrets template if missing
# --------------------------------------------------------------------------
if [ -n "$FROM_HOST" ]; then
    ok "~/.secrets will be handled by --from sync below — skipping template"
elif [ ! -f "$HOME/.secrets" ]; then
    cat > "$HOME/.secrets" <<'SECRETS'
# Shell secrets — sourced by .bashrc, never committed.
# export ANTHROPIC_AUTH_TOKEN="..."
# export GROK_DEPLOYMENT_KEY="..."
SECRETS
    ok "Created ~/.secrets template — add your tokens there"
else
    ok "~/.secrets already exists"
fi

# --------------------------------------------------------------------------
# 19. --from: sync secrets and SSH keys from an existing machine
# --------------------------------------------------------------------------
if [ -n "$FROM_HOST" ]; then
    info "Syncing from $FROM_HOST ..."
    info "(You may be prompted for the password of $FROM_HOST)"

    # Open a single multiplexed SSH connection — password entered once here,
    # all subsequent ssh/scp calls reuse it without prompting again.
    SSH_CTRL=$(mktemp -u /tmp/ssh-ctrl-XXXXXX)
    _from_cleanup() { ssh -O exit -o ControlPath="$SSH_CTRL" "$FROM_HOST" 2>/dev/null || true; rm -f "$SSH_CTRL"; }
    trap _from_cleanup EXIT

    if ! ssh -fNM \
            -o ControlMaster=yes \
            -o ControlPath="$SSH_CTRL" \
            -o ConnectTimeout=10 \
            -o StrictHostKeyChecking=accept-new \
            "$FROM_HOST"; then
        warn "Could not connect to $FROM_HOST — skipping --from sync"
        trap - EXIT
        _from_cleanup
    else
        # Convenience wrappers that route through the control socket
        _ssh() { ssh -o ControlMaster=no -o ControlPath="$SSH_CTRL" "$FROM_HOST" "$@"; }
        _scp() { scp -o ControlMaster=no -o ControlPath="$SSH_CTRL" "$@"; }

        # ~/.secrets
        if _scp "$FROM_HOST:~/.secrets" "$HOME/.secrets" 2>/dev/null; then
            chmod 600 "$HOME/.secrets"
            ok "~/.secrets copied from $FROM_HOST"
        else
            warn "~/.secrets not found on $FROM_HOST"
        fi

        # ~/.ssh (keys + config) — skip if this machine already has keys
        if [ -z "$(ls -A "$HOME/.ssh" 2>/dev/null)" ]; then
            info "Copying ~/.ssh from $FROM_HOST ..."
            mkdir -p "$HOME/.ssh"
            _scp -r "$FROM_HOST:~/.ssh/." "$HOME/.ssh/"
            chmod 700 "$HOME/.ssh"
            chmod 600 "$HOME/.ssh"/id_* "$HOME/.ssh/config" 2>/dev/null || true
            chmod 644 "$HOME/.ssh"/*.pub 2>/dev/null || true
            ok "~/.ssh copied from $FROM_HOST"
        else
            warn "~/.ssh already populated — skipping (remove manually to force overwrite)"
        fi

        ok "Sync from $FROM_HOST complete"
        trap - EXIT
        _from_cleanup
    fi
fi

# --------------------------------------------------------------------------
# Done
# --------------------------------------------------------------------------
echo ""
ok "All done! Open a new shell or run: source ~/.bashrc"
echo ""
info "Post-install checklist:"
echo "  1. Review ~/.gitconfig (name/email set in dotfiles/gitconfig)"
echo "  2. Add API tokens to ~/.secrets  (or re-run with --from=USER@HOST)"
echo "  3. Open nvim — Lazy will auto-install plugins on first launch"
echo "  4. In nvim: :LspInstall, :TSInstall, :DapInstall for language support"
echo "  5. Re-login for group changes to apply (wireshark, docker, …)"
echo "  6. Log into a graphical Sway session; status bar should show weather + BT battery when connected"
