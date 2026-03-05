# Terminal Setup — Sysadmin Edition

A portable, modern terminal configuration built around **Starship** prompt and a curated set of modern CLI tools. Designed for sysadmin workflows: SSH, Docker, directory navigation, and general server management.

Works on: **macOS** (zsh) · **Debian/Ubuntu** (bash/zsh) · **Fedora/RHEL** (bash/zsh)

Uses whatever shell the system ships with. On Linux, optionally install zsh and set it as default with `--zsh`.

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
git clone https://github.com/bleomycin/starship-deploy.git ~/starship-deploy
cd ~/starship-deploy
bash install.sh
```

Install a Nerd Font (required for icons):
```bash
brew install --cask font-jetbrains-mono-nerd-font
# or: brew install --cask font-meslo-lg-nerd-font
```

Set the font in iTerm2: **Settings → Profiles → Text → Font → JetBrainsMono Nerd Font Mono** (13–14pt)

Restart your shell:
```bash
exec zsh
```

### Color theme

This setup uses the **One Half Dark** color palette. To apply it in iTerm2:

1. Browse themes at [iterm2colorschemes.com](https://iterm2colorschemes.com) and download **One Half Dark** (or any theme you prefer)
2. In iTerm2: **Settings → Profiles → Colors → Color Presets... → Import...**
3. Select the downloaded `.itermcolors` file
4. Choose **One Half Dark** from the Color Presets dropdown

### Optional iTerm2 tweaks

- **Scrollback**: Profiles → Terminal → Check "Unlimited scrollback"

---

## Deploying on Remote Linux Servers

```bash
git clone https://github.com/bleomycin/starship-deploy.git ~/starship-deploy
cd ~/starship-deploy
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

### Updating

Pull the latest repo and run with `--upgrade` for smart three-way merge:

```bash
cd ~/starship-deploy && git pull && bash install.sh --upgrade
```

The upgrade mode:
- Installs any new packages added to the repo
- Updates ZSH plugins via `git fetch`/`git merge --ff-only`
- Detects whether you or upstream changed each config file
- Auto-updates files you haven't modified; skips files only you changed
- Prompts with an interactive menu when both sides changed (diff, merge, keep, use upstream, edit)

Tracks what was last deployed in `~/.config/starship-deploy/deployed/` to enable accurate change detection.

For a full re-deploy (replaces everything with backup):

```bash
bash install.sh
```
