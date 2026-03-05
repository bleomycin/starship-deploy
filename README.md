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
~/.shellrc.local       Per-machine overrides (created by installer, not tracked)
~/.config/starship-deploy/deployed/
                       Baselines of last-deployed configs (used by --upgrade)
```

The installer detects your default shell. On macOS (zsh), it deploys `.zshrc` with plugins. On Debian/Fedora (bash), it appends to your existing `.bashrc` without replacing it.

### What Bash gets vs ZSH

| Feature | Bash | ZSH |
|---|---|---|
| Starship prompt | Yes | Yes |
| All aliases (eza, bat, rg, etc.) | Yes | Yes |
| All functions (extract, mkcd, etc.) | Yes | Yes |
| Docker, systemd, SSH, network shortcuts | Yes | Yes |
| fzf (Ctrl+R, Ctrl+T, Alt+C) | Yes | Yes |
| zoxide (smart cd) | Yes | Yes |
| Midnight Commander | Yes | Yes |
| sshs (SSH TUI picker) | Yes | Yes |
| Built-in `help` cheat sheet | Yes | Yes |
| Autosuggestions (ghost text) | — | Yes |
| Syntax highlighting | — | Yes |
| fzf-tab (fuzzy Tab completion) | — | Yes |
| Case-insensitive completion | — | Yes |

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

## Installer Flags

```bash
bash install.sh              # Fresh install (backup + replace)
bash install.sh --zsh        # Also install zsh and set as default shell (Linux)
bash install.sh --upgrade    # Smart upgrade with three-way merge
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
| **gping** | `ping` | Ping with a live graph |
| **doggo** | `dig` | Modern DNS client |
| **viddy** | `watch` | Modern watch with diff highlighting |
| **mc** | — | Two-panel file manager (F-key shortcuts) |
| **sshs** | — | TUI SSH config browser |
| **tldr/tlrc** | `man` | Community cheat sheets |
| **jq** / **yq** | — | JSON / YAML processor |

---

## Key Shortcuts & Aliases

After installation, type `help` for the full cheat sheet. Here are the highlights:

### Navigation

| Shortcut | Tool | Action |
|---|---|---|
| `Ctrl+R` | fzf | Fuzzy search command history |
| `Ctrl+T` | fzf | Fuzzy find files |
| `Alt+C` | fzf | Fuzzy cd into directories |
| `z <name>` | zoxide | Jump to frequently used directory |
| `zi` | zoxide | Interactive directory picker |
| `mc` | mc | Two-panel file manager |
| `mkcd <dir>` | — | Create directory and cd into it |

### File listing (eza)

| Alias | Action |
|---|---|
| `ls` | List with icons, directories first |
| `ll` | Long list + hidden + git status |
| `la` | All files including hidden |
| `lt` | Tree view, 3 levels deep |
| `llt` | Tree + details, 2 levels |
| `lcth` | Long list sorted by change time |

### SSH

| Alias | Action |
|---|---|
| `sshs` | TUI picker — browse ~/.ssh/config visually |
| `sshk <email>` | Generate ed25519 key |
| `sshcopy` | Copy public key to remote host |
| `sshinfo <host>` | SSH + print hostname, uptime, memory, disk |
| `scpto <file> [path]` | SCP to host (fzf-pick host) |
| `scpfrom <path> [local]` | SCP from host (fzf-pick host) |

### Docker

| Alias | Action |
|---|---|
| `d` / `dc` | docker / docker compose |
| `dps` / `dpsa` | Running / all containers (clean table) |
| `dlog <name>` | Follow container logs (last 100 lines) |
| `dsh <name>` | Shell into container (tries bash, then sh) |
| `dstats` | Live CPU/memory/network per container |
| `dprune` | Remove ALL unused containers/images/volumes |

### Systemd (Linux)

| Alias | Action |
|---|---|
| `scs <svc>` | systemctl status |
| `scr <svc>` | systemctl restart |
| `scls` | List all service units |
| `scfailed` | List failed units |
| `jlogf <svc>` | Follow journalctl logs live |

### Network

| Alias | Action |
|---|---|
| `ports` | Show listening ports |
| `myip` | Public IP address |
| `localip` | Local/LAN IP address |
| `portcheck <host> <port>` | Test if host:port is open |
| `killport <port>` | Kill process(es) on a port |
| `gping <host>` | Ping with live graph |
| `doggo <domain>` | DNS lookup |

### Bypassing aliases

Many commands are aliased to modern replacements. To use the original, prefix with `\`:

```bash
\ls       # real ls (not eza)
\cat      # real cat (not bat)
\grep     # real grep (not ripgrep)
\du       # real du (not dust)
\ps       # real ps (not procs)
```

---

## Customization

### Per-machine overrides

`~/.shellrc.local` is sourced at the end of `.shellrc.common`. Put machine-specific PATH additions, exports, or aliases here. It's created by the installer and not tracked by git.

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
