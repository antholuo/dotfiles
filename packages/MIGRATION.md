# System migration notes

Snapshot date: 2026-07-06  
Source host OS: Ubuntu 26.04 LTS (resolute)  
Session: Sway + swaybar + i3status (via `scripts/i3status-wrapper.sh`; weather + audio)

This directory records what was installed on the machine so a fresh box can be rebuilt
without hunting through history. Prefer **`install.sh` + `steps.txt`** for automated setup;
use the snapshots below for gap-filling.

## Snapshot files

| File | Contents |
|------|----------|
| `apt-core.txt` | Curated packages `install.sh` should install |
| `apt-manual-snapshot.txt` | Full `apt-mark showmanual` from the old machine |
| `snap-snapshot.txt` | `snap list` |
| `cargo-snapshot.txt` | `cargo install --list` |
| `usr-local-bin-snapshot.txt` | `/usr/local/bin` inventory |

Many entries in `apt-manual-snapshot.txt` come from the Ubuntu desktop seed (GNOME, printers,
language packs). Do **not** install that whole list blindly on a minimal/Sway-only setup.

## Run order on a new machine

1. Clone this repo.
2. `./install.sh` (installs apt core, tools, fonts, nvim, rust, symlinks, etc.).
3. Finish anything in `steps.txt` that is still manual.
4. Restore secrets: `~/.secrets` (never committed).
5. Reinstall optional stacks below.

## Optional (not fully automated)

### Docker (CE)

```bash
# Official Docker apt repo (see https://docs.docker.com/engine/install/ubuntu/)
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"
```

Old machine also had: `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`.

### Google Chrome

```bash
# Add Google's signing key + apt source, then:
sudo apt-get install -y google-chrome-stable
```

### Snaps worth reinstalling (user-facing)

From the old machine:

- `spotify`
- `mattermost-desktop`
- `firefox` (often preinstalled via snap on Ubuntu)
- `bottom` (optional — `cargo install bottom` / `btm` is preferred and already in `install.sh`)

Canonical scaffolding snaps (`bare`, `core22`, `core24`, `gnome-*`, `mesa-*`, `snapd`, etc.)
reappear automatically as dependencies.

```bash
sudo snap install spotify
sudo snap install mattermost-desktop
```

### Cargo crates (beyond install.sh)

`install.sh` installs: `tree-sitter-cli`, `bottom`.

Also present on old machine:

```bash
cargo install --locked bluetui   # Bluetooth TUI
```

### `/usr/local/bin` extras (manual)

| Tool | Notes |
|------|--------|
| `starship` | Installed by `install.sh` via upstream script |
| `lazygit` | Installed by `install.sh` |
| `gdu` | Installed by `install.sh` |
| `fd`, `bat` | Symlinks to Debian `fdfind` / `batcat` |

### Groups / udev

Old user groups included: `docker`, `wireshark`, `plugdev`, `dialout`, `lpadmin`, …

```bash
sudo usermod -aG docker,wireshark,plugdev,dialout "$USER"
# re-login for groups to apply
```

Wireshark non-root capture may need:

```bash
sudo dpkg-reconfigure wireshark-common   # allow non-superusers
```

### Python / pipx

- `pipx` installed via apt; reinstall tools with `pipx install …` as needed.
- User pip had only `orjson` — not critical.
- `asammdf` is installed via pip into `~/.venv/asammdf` as `asammdf[gui]` (see install.sh).
- `python3.11` + `python3.11-venv` and `pyenv-runtime` were present for older runtimes.

### Flameshot (Wayland)

Config key used on current machine:

```ini
[General]
useGrimAdapter=true
```

(`install.sh` writes this under `~/.config/flameshot/flameshot.ini`.)

### Status bar Bluetooth battery

`scripts/i3status-audio.sh` shows connected BT device + battery + volume, e.g.:

```text
MOMENTUM 4(🔋100%) - 2%
```

Requires: `bluez`, `pulseaudio-utils` (pactl), `jq` (wrapper), and a device that exposes
battery over BlueZ (Momentum 4 does).

## Secrets & machine-local (do not commit)

- `~/.secrets` — API tokens
- `~/.ssh/` — keys and config
- Browser profiles, Mattermost/Spotify login state
- Any local git remotes / tokens under `~/.config/git` if present

## Verify after migration

```bash
sway --version
i3status -v
bluetoothctl --version
nvim --version
starship --version
lazygit --version
btm --version
# with headphones connected:
~/.config/i3/scripts/i3status-audio.sh
# expect: DEVICE(🔋N%) - VOL%
```
