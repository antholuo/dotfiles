# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# --- History (unlimited, shared across tmux panes) ---
HISTSIZE=-1
HISTFILESIZE=-1
HISTCONTROL=ignoredups:ignorespace
shopt -s histappend
PROMPT_COMMAND="history -a; history -c; history -r${PROMPT_COMMAND:+; $PROMPT_COMMAND}"

# Check the window size after each command
shopt -s checkwinsize

# Make less more friendly for non-text input files
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# --- Prompt ---
# Chroot detection (Debian)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
esac

# --- Colors ---
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# --- Aliases ---
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'

# --- Git aliases ---
alias gs='git status'
alias gst='git status -sb'
alias ga='git add'
alias gaa='git add --all'
alias gap='git add -p'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend'
alias gcan='git commit --amend --no-edit'
alias gd='git diff'
alias gdc='git diff --cached'
alias gds='git diff --staged'
alias gl='git log'
alias glo='git log --oneline --graph --decorate --all'
alias gb='git branch'
alias gba='git branch -a'
alias gbd='git branch -d'
alias gbD='git branch -D'
alias gco='git checkout'
alias gsw='git switch'
alias gswc='git switch -c'
alias gf='git fetch'
alias gfa='git fetch --all --prune'
alias gfo='git fetch origin'
alias gpl='git pull'
alias gplp='git pull --prune'
alias gpu='git push'
alias gpf='git push --force-with-lease'
alias gr='git rebase'
alias gri='git rebase -i'
alias grc='git rebase --continue'
alias gra='git rebase --abort'
alias gcp='git cherry-pick'
alias gcl='git clone'
alias gsh='git show'
alias gsta='git stash'
alias gstp='git stash pop'
alias gundo='git reset --soft HEAD~1'
# Note: gcb is already used for git-clean-branches (see Git helpers below)


# --- Completions ---
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# --- PATH ---
export PATH="$HOME/.local/bin:$PATH"
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
[ -d "$HOME/.grok/bin" ] && export PATH="$HOME/.grok/bin:$PATH"

# --- Editor ---
export VISUAL="nvim"
export EDITOR="nvim"

# --- Starship prompt ---
eval "$(starship init bash)"

# --- fzf ---
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Ctrl+G: fuzzy search only git-changed files (staged + unstaged)
fzf-git-changed-files() {
    local file
    file=$(git diff --name-only HEAD 2>/dev/null | fzf --height 40% --layout=reverse --border=none --inline-info)
    if [[ -n "$file" ]]; then
        READLINE_LINE="${READLINE_LINE}${file}"
        READLINE_POINT=${#READLINE_LINE}
    fi
}
bind -x '"\C-g": fzf-git-changed-files'

# --- Cargo/Rust ---
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"

# --- Git helpers ---
git-clean-branches() {
    git fetch --prune

    local branches
    branches=$(git branch -vv | awk '/: gone]/{print $1}')

    if [[ -z "$branches" ]]; then
        echo "No stale local branches to delete."
        return 0
    fi

    local dry_run=false
    local force=false

    for arg in "$@"; do
        case "$arg" in
            --dry-run|-m) dry_run=true ;;
            --force|-f)   force=true ;;
        esac
    done

    if $dry_run; then
        echo "[Dry Run] The following branches would be deleted:"
        echo "$branches" | while read -r branch; do
            echo "  - $branch"
        done
    elif $force; then
        echo "[Force] Deleting the following branches (including unmerged):"
        echo "$branches" | while read -r branch; do
            echo "  - $branch"
            git branch -D "$branch"
        done
    else
        echo "Deleting the following branches:"
        echo "$branches" | while read -r branch; do
            echo "  - $branch"
            git branch -d "$branch"
        done
    fi
}
alias gcb='git-clean-branches'

# --- Iface helpers ---
# Helper to bring interface up
iface_up() {
    local iface="${1:?Usage: iface_up <interface>}"

    echo "Bringing up interface: $iface"

    # Bring up the interface
    sudo ip link set dev "$iface" up

    # Assign the IP (standard TMC subnet)
    sudo ip addr add 172.31.31.2/22 dev "$iface"

    # Disable VLAN filter (required for etherloopcan)
    sudo ethtool -K "$iface" rx-vlan-filter off

    echo "Done. $iface is up with 172.31.31.2/22, VLAN filter disabled."
}

export MOZ_ENABLED_WAYLAND=1


# --- Secrets (tokens, API keys — not committed to dotfiles) ---
[ -f ~/.secrets ] && source ~/.secrets

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
# <<< grok installer <<<
