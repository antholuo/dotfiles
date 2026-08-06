# dotfiles

Personal dotfiles for Ubuntu + Sway. Dvorak layout, Neovim/AstroNvim, tmux, Alacritty.

## Quick start

```bash
# 1. Generate/transfer SSH key and add it to GitHub (see install_steps.txt §0)
# 2. Clone
mkdir -p ~/Code && git clone git@github.com:antholuo/dotfiles.git ~/Code/dotfiles
# 3. Install — optionally pull secrets from an old machine
cd ~/Code/dotfiles && ./install.sh [--from=USER@HOST]
# 4. Follow remaining manual steps
cat install_steps.txt
```

### install.sh flags

| Flag | Effect |
|------|--------|
| `--from=USER@HOST` | SCP `~/.secrets` and `~/.ssh/` from an existing machine |

```bash
# Migration example
./install.sh --from=anni@nuc1
```

## What's inside

| File / Dir | Purpose |
|------------|---------|
| `install.sh` | One-shot bootstrap: apt packages, fonts, tools, symlinks |
| `install_steps.txt` | Full migration guide including manual steps (SSH, Docker, etc.) |
| `bashrc` | Shell config: aliases, git shortcuts, starship, fzf, PATH |
| `tmux.conf` | Mouse, vi-mode, wl-clipboard integration, 50k scrollback |
| `gitconfig` | Push defaults, nvim as editor |
| `sway/config` | Sway WM — Dvorak bindings, swayidle/swaylock, i3status bar, nm-applet |
| `i3_config` | Legacy i3 config (same keybindings) |
| `i3status.conf` | Status bar config (used via wrapper) |
| `waybar/` | Optional Waybar configs (not started by default) |
| `alacritty.toml` | Terminal — Iosevka Nerd Font, theme import |
| `config/nvim/` | AstroNvim config (lazy-lock.json pins plugin versions) |
| `config/lazygit/config.yml` | Lazygit monorepo performance defaults (no auto-fetch/refresh) |
| `scripts/` | i3status weather + audio/BT wrapper, startup terminals |
| `packages/` | apt-core.txt + migration snapshots (cargo, snap, /usr/local/bin) |

## Automated by install.sh

- apt core packages (see `packages/apt-core.txt`)
- Iosevka Nerd Font
- Neovim v0.12.2 → `/opt/nvim-linux-x86_64/`
- fzf, Starship, Rust/Cargo
- tree-sitter-cli, bluetui, lazygit, gdu, bottom (btm)
- Alacritty themes
- All symlinks into `~/.config/` and `~/`
- `asammdf[gui]` in `~/.venv/asammdf`

## Manual steps (summary)

See `install_steps.txt` for full detail.

1. SSH key — generate or copy from old machine
2. `~/.secrets` — add API tokens (never committed)
3. User groups — `docker wireshark plugdev dialout`
4. Docker CE, Chrome, snaps (Spotify, Mattermost) — optional
5. First nvim launch — Lazy auto-installs plugins; then `:LspInstall`, `:TSInstall`

## Key bindings (Sway, Dvorak)

`$mod` = Super

| Binding | Action |
|---------|--------|
| `$mod+Return` | Alacritty terminal |
| `$mod+e` | App launcher (bemenu) |
| `$mod+h/t/n/s` | Focus left/down/up/right |
| `$mod+Shift+H/T/N/S` | Move window |
| `$mod+l` | Lock screen |
| `$mod+u` | Fullscreen toggle |
| `$mod+p` | Resize mode |
| `$mod+Shift+P` | Flameshot screenshot |
| `$mod+1–0` | Switch workspace |

## Neovim

AstroNvim with:
- LSP via Mason (`clangd`, `lua_ls`, `pyright`)
- Treesitter, DAP, none-ls, fzf-lua
- Plugin versions pinned in `config/nvim/lazy-lock.json`

`<Space>gg` lazygit · `<Space>tt` bottom · `<Space>tu` gdu · `<Space>zf` fzf
