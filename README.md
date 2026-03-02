# Terminal Setup — Sysadmin Edition

A portable, modern terminal configuration built around **Starship** prompt and a curated set of modern CLI tools. Designed for sysadmin workflows: SSH, Docker, directory navigation, and general server management.

Works on: **macOS** (zsh) · **Debian/Ubuntu** (bash) · **Fedora/RHEL** (bash)

Uses whatever shell the system ships with — no need to install zsh on Linux.

---

## Architecture

```
starship.toml          Shell-agnostic prompt config
.shellrc.common        Shared aliases, functions, tool init (bash + zsh compatible)
.zshrc                 ZSH-specific: sources common + adds plugins (macOS)
.bashrc.append         Bash-specific: appended to system .bashrc (Linux)
install.sh             Detects OS + shell, installs everything
```

The installer detects your default shell. On macOS (zsh), it deploys `.zshrc` with plugins. On Debian/Fedora (bash), it appends to your existing `.bashrc` without replacing it.

### What Bash gets vs ZSH

| Feature | Bash | ZSH |
|---|---|---|
| Starship prompt | ✅ | ✅ |
| All aliases (eza, bat, rg, etc.) | ✅ | ✅ |
| All functions (extract, mkcd, etc.) | ✅ | ✅ |
| fzf (Ctrl+R, Ctrl+T, Alt+C) | ✅ | ✅ |
| zoxide (smart cd) | ✅ | ✅ |
| Midnight Commander | ✅ | ✅ |
| sshs (SSH TUI picker) | ✅ | ✅ |
| Autosuggestions (ghost text) | — | ✅ |
| Syntax highlighting | — | ✅ |
| fzf-tab (fuzzy Tab completion) | — | ✅ |
| Case-insensitive completion | — | ✅ |

---

## Quick Start: macOS + iTerm2

```bash
git clone https://github.com/YOURUSER/terminal-setup.git ~/terminal-setup
cd ~/terminal-setup
bash install.sh
```

Install a Nerd Font (required for icons):
```bash
brew install --cask font-meslo-lg-nerd-font
```

Set the font in iTerm2: **Settings → Profiles → Text → Font → MesloLGS Nerd Font** (13–14pt)

Restart your shell:
```bash
exec zsh
```

### Optional iTerm2 tweaks

- **Colors**: Import [Catppuccin](https://github.com/catppuccin/iterm) or [Tokyo Night](https://github.com/enkia/tokyo-night-iterm2) for a nicer palette
- **Scrollback**: Profiles → Terminal → Check "Unlimited scrollback"

---

## Deploying on Remote Linux Servers

```bash
scp -r ~/terminal-setup user@server:~/terminal-setup
ssh user@server
cd ~/terminal-setup
bash install.sh
exec bash
```

The installer detects Debian vs Fedora automatically. On bash systems it appends to your `.bashrc` (with a backup) rather than replacing it.

**Fonts on servers**: You don't need to install a Nerd Font on the server. The font rendering happens in your local terminal (iTerm2). As long as your Mac has the Nerd Font set, icons render correctly over SSH.

### Minimal install (prompt + aliases only, no extra tools)

```bash
# Install just Starship
curl -sS https://starship.rs/install.sh | sh

# Copy configs
mkdir -p ~/.config
cp starship.toml ~/.config/starship.toml
cp .shellrc.common ~/.shellrc.common

# For bash: append to .bashrc
cat .bashrc.append >> ~/.bashrc

# Restart
exec bash
```

---

## Tool List

| Tool | Replaces | Why |
|---|---|---|
| **eza** | `ls` | Icons, git status, tree view |
| **bat** | `cat` | Syntax highlighting, line numbers |
| **fd** | `find` | Simpler syntax, faster |
| **ripgrep** | `grep` | Much faster, better defaults |
| **fzf** | — | Fuzzy finder for files, history, dirs |
| **zoxide** | `cd` | Learns directories, `z` to jump |
| **dust** | `du` | Visual disk usage |
| **duf** | `df` | Pretty disk free table |
| **btop** | `top/htop` | Modern resource monitor |
| **procs** | `ps` | Colorized process list |
| **mc** | — | Two-panel file manager (F-key shortcuts) |
| **sshs** | — | TUI SSH config browser |
| **tldr/tlrc** | `man` | Community cheat sheets |
| **jq** / **yq** | — | JSON / YAML processor |

---

## Key Shortcuts

| Shortcut | Tool | Action |
|---|---|---|
| `Ctrl+R` | fzf | Fuzzy search command history |
| `Ctrl+T` | fzf | Fuzzy find files |
| `Alt+C` | fzf | Fuzzy cd into directories |
| `z <name>` | zoxide | Jump to frequently used directory |
| `zi` | zoxide | Interactive directory picker |
| `mc` | mc | Two-panel file manager |
| `sshs` | sshs | TUI SSH connection picker |

---

## Customization

### Per-machine overrides

Create `~/.shellrc.local` for machine-specific settings. It's sourced at the end of `.shellrc.common` and is not tracked by git.

### Starship on slow SSH connections

```toml
# In starship.toml
command_timeout = 2000

# Or disable git on slow NFS filesystems
[git_branch]
disabled = true
```

### Pushing to GitHub

```bash
cd ~/terminal-setup
git init
git add -A
git commit -m "Initial terminal setup"
gh repo create terminal-setup --public --source=. --push
```

### Updating

```bash
cd ~/terminal-setup && git pull && bash install.sh && exec $SHELL
```
