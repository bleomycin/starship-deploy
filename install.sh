#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  Terminal Setup Installer — macOS / Debian / Fedora             ║
# ║  Shell-agnostic: deploys for bash or zsh based on system default║
# ║  Run: bash install.sh                                           ║
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
success() { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
fail()    { echo -e "${RED}[FAIL]${NC}  $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─── Privilege helper (sudo when needed, direct when root) ──────
as_root() {
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
    else
        sudo "$@"
    fi
}

# ─── Parse flags ────────────────────────────────────────────────
INSTALL_ZSH=""
for arg in "$@"; do
    case "$arg" in
        --zsh) INSTALL_ZSH=1 ;;
    esac
done

# ─── Detect platform ─────────────────────────────────────────────
OS="$(uname -s)"
DISTRO=""
if [[ "$OS" == "Linux" ]]; then
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="$ID"
    fi
fi

# ─── Detect default shell ────────────────────────────────────────
DEFAULT_SHELL="$(basename "${SHELL:-/bin/bash}")"
CURRENT_USER="${USER:-$(whoami)}"
info "Detected: $OS ${DISTRO:+($DISTRO)} — default shell: $DEFAULT_SHELL — user: $CURRENT_USER"
echo ""

# ─── macOS: Install via Homebrew ──────────────────────────────────
install_macos() {
    info "=== macOS Installation ==="
    echo ""

    if ! command -v brew &>/dev/null; then
        info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
    fi
    success "Homebrew ready"

    info "Installing packages via Homebrew..."
    brew install \
        starship \
        eza \
        bat \
        fd \
        ripgrep \
        fzf \
        zoxide \
        btop \
        dust \
        duf \
        procs \
        jq \
        yq \
        wget \
        curl \
        tree \
        ncdu \
        tlrc \
        sshs \
        midnight-commander \
        gping \
        doggo \
        viddy

    success "All Homebrew packages installed"
}

# ─── Debian/Ubuntu ────────────────────────────────────────────────
install_debian() {
    info "=== Debian/Ubuntu Installation ==="
    echo ""

    as_root apt update

    info "Installing apt packages..."
    as_root apt install -y \
        curl \
        wget \
        git \
        gpg \
        jq \
        tree \
        ncdu \
        unzip \
        bat \
        fd-find \
        ripgrep \
        fzf \
        mc

    # Starship
    if ! command -v starship &>/dev/null; then
        info "Installing Starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi
    success "Starship installed"

    # eza
    if ! command -v eza &>/dev/null; then
        info "Installing eza..."
        as_root mkdir -p /etc/apt/keyrings
        wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | as_root gpg --yes --dearmor -o /etc/apt/keyrings/gierens.gpg
        echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" | as_root tee /etc/apt/sources.list.d/gierens.list
        as_root chmod 644 /etc/apt/keyrings/gierens.gpg
        as_root apt update
        as_root apt install -y eza
    fi
    success "eza installed"

    # zoxide
    if ! command -v zoxide &>/dev/null; then
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    fi

    # btop
    if ! command -v btop &>/dev/null; then
        as_root apt install -y btop 2>/dev/null || warn "btop not in apt, install manually"
    fi

    # dust
    if ! command -v dust &>/dev/null; then
        info "Installing dust..."
        local DUST_VER=$(curl -s https://api.github.com/repos/bootandy/dust/releases/latest | jq -r '.tag_name' | tr -d 'v')
        local ARCH=$(dpkg --print-architecture)
        if [[ "$ARCH" == "amd64" ]]; then
            wget -qO /tmp/dust.deb "https://github.com/bootandy/dust/releases/latest/download/du-dust_${DUST_VER}-1_${ARCH}.deb" 2>/dev/null || rm -f /tmp/dust.deb
            if [[ -s /tmp/dust.deb ]]; then
                as_root dpkg -i /tmp/dust.deb
                rm /tmp/dust.deb
            else
                warn "dust: download failed, install manually"
            fi
        else
            warn "dust: download manually for $ARCH from https://github.com/bootandy/dust/releases"
        fi
    fi

    # duf
    if ! command -v duf &>/dev/null; then
        as_root apt install -y duf 2>/dev/null || warn "duf not in apt, install manually"
    fi

    # procs
    if ! command -v procs &>/dev/null; then
        info "Installing procs..."
        local PROCS_TAG=$(curl -s https://api.github.com/repos/dalance/procs/releases/latest | jq -r '.tag_name')
        local ARCH=$(uname -m)
        wget -qO /tmp/procs.zip "https://github.com/dalance/procs/releases/latest/download/procs-${PROCS_TAG}-${ARCH}-linux.zip" 2>/dev/null || rm -f /tmp/procs.zip
        if [[ -s /tmp/procs.zip ]]; then
            unzip -o /tmp/procs.zip -d /tmp/procs_bin
            as_root mv /tmp/procs_bin/procs /usr/local/bin/
            rm -rf /tmp/procs.zip /tmp/procs_bin
        else
            warn "procs: download failed, install manually"
        fi
    fi

    # sshs
    if ! command -v sshs &>/dev/null; then
        info "Installing sshs..."
        local ARCH=$(uname -m)
        [[ "$ARCH" == "x86_64" ]] && local SSHS_ARCH="amd64"
        [[ "$ARCH" == "aarch64" ]] && local SSHS_ARCH="arm64"
        if [[ -n "${SSHS_ARCH:-}" ]]; then
            wget -qO /tmp/sshs "https://github.com/quantumsheep/sshs/releases/latest/download/sshs-linux-${SSHS_ARCH}" 2>/dev/null || rm -f /tmp/sshs
            if [[ -s /tmp/sshs ]]; then
                chmod +x /tmp/sshs
                as_root mv /tmp/sshs /usr/local/bin/
            else
                warn "sshs: download failed, install manually"
            fi
        fi
    fi

    # gping
    if ! command -v gping &>/dev/null; then
        info "Installing gping..."
        if ! as_root apt install -y gping 2>/dev/null; then
            local ARCH=$(uname -m)
            [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
            wget -qO /tmp/gping.tar.gz "https://github.com/orf/gping/releases/latest/download/gping-Linux-gnu-${ARCH}.tar.gz" 2>/dev/null || rm -f /tmp/gping.tar.gz
            if [[ -s /tmp/gping.tar.gz ]]; then
                tar xzf /tmp/gping.tar.gz -C /tmp
                as_root mv /tmp/gping /usr/local/bin/
                rm /tmp/gping.tar.gz
            else
                warn "gping: download failed, install manually"
            fi
        fi
    fi

    # doggo
    if ! command -v doggo &>/dev/null; then
        info "Installing doggo..."
        local ARCH=$(uname -m)
        [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
        wget -qO /tmp/doggo.tar.gz "https://github.com/mr-karan/doggo/releases/download/v1.1.5/doggo_1.1.5_Linux_${ARCH}.tar.gz" 2>/dev/null || rm -f /tmp/doggo.tar.gz
        if [[ -s /tmp/doggo.tar.gz ]]; then
            tar xzf /tmp/doggo.tar.gz -C /tmp doggo
            as_root mv /tmp/doggo /usr/local/bin/
            rm /tmp/doggo.tar.gz
        else
            warn "doggo: download failed, install manually"
        fi
    fi

    # viddy
    if ! command -v viddy &>/dev/null; then
        info "Installing viddy..."
        local ARCH=$(uname -m)
        [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
        wget -qO /tmp/viddy.tar.gz "https://github.com/sachaos/viddy/releases/download/v1.3.0/viddy-v1.3.0-linux-${ARCH}.tar.gz" 2>/dev/null || rm -f /tmp/viddy.tar.gz
        if [[ -s /tmp/viddy.tar.gz ]]; then
            tar xzf /tmp/viddy.tar.gz -C /tmp viddy
            as_root mv /tmp/viddy /usr/local/bin/
            rm /tmp/viddy.tar.gz
        else
            warn "viddy: download failed, install manually"
        fi
    fi

    as_root apt install -y tldr 2>/dev/null || true

    # yq
    if ! command -v yq &>/dev/null; then
        local ARCH=$(uname -m)
        [[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
        [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
        as_root wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" 2>/dev/null && as_root chmod +x /usr/local/bin/yq || warn "yq: install manually"
    fi

    success "All packages installed"
}

# ─── Fedora/RHEL ──────────────────────────────────────────────────
install_fedora() {
    info "=== Fedora Installation ==="
    echo ""

    info "Installing dnf packages..."
    as_root dnf install -y --setopt=strict=0 \
        curl \
        wget \
        git \
        jq \
        tree \
        ncdu \
        unzip \
        bat \
        fd-find \
        ripgrep \
        fzf \
        eza \
        btop \
        duf \
        procs \
        mc

    # Starship
    if ! command -v starship &>/dev/null; then
        info "Installing Starship..."
        curl -sS https://starship.rs/install.sh | sh -s -- -y
    fi
    success "Starship installed"

    # eza (GitHub binary fallback)
    if ! command -v eza &>/dev/null; then
        info "Installing eza from GitHub..."
        local ARCH=$(uname -m)
        wget -qO /tmp/eza.tar.gz "https://github.com/eza-community/eza/releases/latest/download/eza_${ARCH}-unknown-linux-gnu.tar.gz" 2>/dev/null || rm -f /tmp/eza.tar.gz
        if [[ -s /tmp/eza.tar.gz ]]; then
            tar xzf /tmp/eza.tar.gz -C /tmp
            as_root mv /tmp/eza /usr/local/bin/
            rm /tmp/eza.tar.gz
        else
            warn "eza: download failed, install manually"
        fi
    fi

    # zoxide
    if ! command -v zoxide &>/dev/null; then
        curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
    fi

    # btop (GitHub binary fallback)
    if ! command -v btop &>/dev/null; then
        info "Installing btop from GitHub..."
        local ARCH=$(uname -m)
        wget -qO /tmp/btop.tbz "https://github.com/aristocratos/btop/releases/latest/download/btop-${ARCH}-linux-musl.tbz" 2>/dev/null || rm -f /tmp/btop.tbz
        if [[ -s /tmp/btop.tbz ]]; then
            mkdir -p /tmp/btop_install
            tar xjf /tmp/btop.tbz -C /tmp/btop_install
            as_root /tmp/btop_install/btop/install.sh /usr/local
            rm -rf /tmp/btop.tbz /tmp/btop_install
        else
            warn "btop: download failed, install manually"
        fi
    fi

    # dust
    if ! command -v dust &>/dev/null; then
        info "Installing dust from GitHub..."
        local DUST_VER=$(curl -s https://api.github.com/repos/bootandy/dust/releases/latest | jq -r '.tag_name' | tr -d 'v')
        local ARCH=$(uname -m)
        wget -qO /tmp/dust.tar.gz "https://github.com/bootandy/dust/releases/latest/download/dust-${DUST_VER}-${ARCH}-unknown-linux-gnu.tar.gz" 2>/dev/null || rm -f /tmp/dust.tar.gz
        if [[ -s /tmp/dust.tar.gz ]]; then
            tar xzf /tmp/dust.tar.gz -C /tmp
            as_root mv /tmp/dust-*/dust /usr/local/bin/
            rm -rf /tmp/dust*
        else
            warn "dust: download failed, install manually"
        fi
    fi

    # duf (GitHub binary fallback)
    if ! command -v duf &>/dev/null; then
        info "Installing duf from GitHub..."
        local ARCH=$(uname -m)
        [[ "$ARCH" == "x86_64" ]] && local DUF_ARCH="amd64"
        [[ "$ARCH" == "aarch64" ]] && local DUF_ARCH="arm64"
        if [[ -n "${DUF_ARCH:-}" ]]; then
            wget -qO /tmp/duf.rpm "https://github.com/muesli/duf/releases/latest/download/duf_0.8.1_linux_${DUF_ARCH}.rpm" 2>/dev/null || rm -f /tmp/duf.rpm
            if [[ -s /tmp/duf.rpm ]]; then
                as_root rpm -i /tmp/duf.rpm 2>/dev/null || true
                rm /tmp/duf.rpm
            else
                warn "duf: download failed, install manually"
            fi
        fi
    fi

    # procs (GitHub binary fallback)
    if ! command -v procs &>/dev/null; then
        info "Installing procs from GitHub..."
        local PROCS_TAG=$(curl -s https://api.github.com/repos/dalance/procs/releases/latest | jq -r '.tag_name')
        local ARCH=$(uname -m)
        wget -qO /tmp/procs.zip "https://github.com/dalance/procs/releases/latest/download/procs-${PROCS_TAG}-${ARCH}-linux.zip" 2>/dev/null || rm -f /tmp/procs.zip
        if [[ -s /tmp/procs.zip ]]; then
            unzip -o /tmp/procs.zip -d /tmp/procs_bin
            as_root mv /tmp/procs_bin/procs /usr/local/bin/
            rm -rf /tmp/procs.zip /tmp/procs_bin
        else
            warn "procs: download failed, install manually"
        fi
    fi

    # sshs
    if ! command -v sshs &>/dev/null; then
        info "Installing sshs from GitHub..."
        local ARCH=$(uname -m)
        [[ "$ARCH" == "x86_64" ]] && local SSHS_ARCH="amd64"
        [[ "$ARCH" == "aarch64" ]] && local SSHS_ARCH="arm64"
        if [[ -n "${SSHS_ARCH:-}" ]]; then
            wget -qO /tmp/sshs "https://github.com/quantumsheep/sshs/releases/latest/download/sshs-linux-${SSHS_ARCH}" 2>/dev/null || rm -f /tmp/sshs
            if [[ -s /tmp/sshs ]]; then
                chmod +x /tmp/sshs
                as_root mv /tmp/sshs /usr/local/bin/
            else
                warn "sshs: download failed, install manually"
            fi
        fi
    fi

    # gping
    if ! command -v gping &>/dev/null; then
        info "Installing gping..."
        if ! as_root dnf install -y gping 2>/dev/null; then
            local ARCH=$(uname -m)
            [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
            wget -qO /tmp/gping.tar.gz "https://github.com/orf/gping/releases/latest/download/gping-Linux-gnu-${ARCH}.tar.gz" 2>/dev/null || rm -f /tmp/gping.tar.gz
            if [[ -s /tmp/gping.tar.gz ]]; then
                tar xzf /tmp/gping.tar.gz -C /tmp
                as_root mv /tmp/gping /usr/local/bin/
                rm /tmp/gping.tar.gz
            else
                warn "gping: download failed, install manually"
            fi
        fi
    fi

    # doggo
    if ! command -v doggo &>/dev/null; then
        info "Installing doggo..."
        local ARCH=$(uname -m)
        [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
        wget -qO /tmp/doggo.tar.gz "https://github.com/mr-karan/doggo/releases/download/v1.1.5/doggo_1.1.5_Linux_${ARCH}.tar.gz" 2>/dev/null || rm -f /tmp/doggo.tar.gz
        if [[ -s /tmp/doggo.tar.gz ]]; then
            tar xzf /tmp/doggo.tar.gz -C /tmp doggo
            as_root mv /tmp/doggo /usr/local/bin/
            rm /tmp/doggo.tar.gz
        else
            warn "doggo: download failed, install manually"
        fi
    fi

    # viddy
    if ! command -v viddy &>/dev/null; then
        info "Installing viddy..."
        local ARCH=$(uname -m)
        [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
        wget -qO /tmp/viddy.tar.gz "https://github.com/sachaos/viddy/releases/download/v1.3.0/viddy-v1.3.0-linux-${ARCH}.tar.gz" 2>/dev/null || rm -f /tmp/viddy.tar.gz
        if [[ -s /tmp/viddy.tar.gz ]]; then
            tar xzf /tmp/viddy.tar.gz -C /tmp viddy
            as_root mv /tmp/viddy /usr/local/bin/
            rm /tmp/viddy.tar.gz
        else
            warn "viddy: download failed, install manually"
        fi
    fi

    as_root dnf install -y --setopt=strict=0 tldr yq 2>/dev/null || true

    # yq (GitHub binary fallback)
    if ! command -v yq &>/dev/null; then
        info "Installing yq from GitHub..."
        local ARCH=$(uname -m)
        [[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
        [[ "$ARCH" == "aarch64" ]] && ARCH="arm64"
        as_root wget -qO /usr/local/bin/yq "https://github.com/mikefarah/yq/releases/latest/download/yq_linux_${ARCH}" 2>/dev/null && as_root chmod +x /usr/local/bin/yq || warn "yq: install manually"
    fi

    success "All packages installed"
}

# ─── Install ZSH shell (Linux only) ──────────────────────────────
install_zsh_shell() {
    if [[ "$OS" != "Linux" ]]; then
        return
    fi

    info "Installing ZSH and setting as default shell..."

    case "$DISTRO" in
        debian|ubuntu|pop|linuxmint|raspbian)
            as_root apt install -y zsh
            ;;
        fedora|rhel|centos|rocky|alma)
            as_root dnf install -y zsh
            ;;
    esac
    success "ZSH installed"

    local ZSH_PATH
    ZSH_PATH="$(command -v zsh)"

    info "Setting default shell to $ZSH_PATH for $CURRENT_USER..."
    as_root chsh -s "$ZSH_PATH" "$CURRENT_USER"
    success "Default shell for $CURRENT_USER → $ZSH_PATH"

    if [[ "$CURRENT_USER" != "root" ]]; then
        info "Setting default shell to $ZSH_PATH for root..."
        as_root chsh -s "$ZSH_PATH" root
        success "Default shell for root → $ZSH_PATH"
    fi

    DEFAULT_SHELL="zsh"
}

# ─── ZSH Plugins (only if using ZSH) ─────────────────────────────
install_zsh_plugins() {
    info "Installing ZSH plugins..."
    mkdir -p ~/.zsh/plugins

    if [[ ! -d ~/.zsh/plugins/zsh-autosuggestions ]]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/plugins/zsh-autosuggestions
    fi

    if [[ ! -d ~/.zsh/plugins/zsh-syntax-highlighting ]]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/plugins/zsh-syntax-highlighting
    fi

    if [[ ! -d ~/.zsh/plugins/zsh-completions ]]; then
        git clone --depth=1 https://github.com/zsh-users/zsh-completions ~/.zsh/plugins/zsh-completions
    fi

    if [[ ! -d ~/.zsh/plugins/fzf-tab ]]; then
        git clone --depth=1 https://github.com/Aloxaf/fzf-tab ~/.zsh/plugins/fzf-tab
    fi

    success "ZSH plugins installed"
}

# ─── Diff helper: show meaningful custom lines in existing config ─
# Filters out comments, blank lines, and common boilerplate
show_custom_lines() {
    local file="$1"
    local label="$2"
    if [[ ! -f "$file" ]]; then
        return
    fi

    # Extract lines that look like user customizations:
    # - export/alias/function/eval/source lines
    # - PATH modifications
    # - Skip blank lines, comments, and common default .bashrc/.zshrc boilerplate
    local custom_lines
    custom_lines=$(grep -vE '^\s*$|^\s*#|^\s*fi$|^\s*;;$|^\s*esac$|^\s*then$|^\s*else$|^\s*\{$|^\s*\}$' "$file" \
        | grep -vE '^\s*(if |case |\[ |for |while |do$|done$)' \
        | grep -vE 'bash_completion|enable color support|colored GCC|make less more friendly' \
        | grep -vE '^\s*unset ' \
        || true)

    if [[ -n "$custom_lines" ]]; then
        echo ""
        warn "Your existing $label contains customizations:"
        echo "────────────────────────────────────────────"
        echo "$custom_lines"
        echo "────────────────────────────────────────────"
        echo ""
        info "A backup will be saved to ${file}.bak"
        info "To carry forward any of the above, add them to ~/.shellrc.local"
        info "(which is sourced automatically and not tracked by git)."
        echo ""
        read -rp "Proceed with replacing $label? [Y/n] " answer
        if [[ "$answer" =~ ^[Nn] ]]; then
            warn "Skipped $label — no changes made."
            return 1
        fi
    fi
    return 0
}

# ─── Deploy config files ─────────────────────────────────────────
deploy_configs() {
    info "Deploying configuration files..."

    # Starship config (always — shell-agnostic)
    mkdir -p ~/.config
    if [[ -f ~/.config/starship.toml ]]; then
        cp ~/.config/starship.toml ~/.config/starship.toml.bak
        warn "Backed up existing starship.toml → starship.toml.bak"
    fi
    cp "$SCRIPT_DIR/starship.toml" ~/.config/starship.toml
    success "starship.toml → ~/.config/starship.toml"

    # Shared shell config (always)
    if [[ -f ~/.shellrc.common ]]; then
        cp ~/.shellrc.common ~/.shellrc.common.bak
        warn "Backed up existing .shellrc.common → .shellrc.common.bak"
    fi
    cp "$SCRIPT_DIR/.shellrc.common" ~/.shellrc.common
    success ".shellrc.common → ~/.shellrc.common"

    # Create .shellrc.local if it doesn't exist (for carrying forward customizations)
    if [[ ! -f ~/.shellrc.local ]]; then
        cat > ~/.shellrc.local << 'LOCALEOF'
# ╔══════════════════════════════════════════════════════════════════╗
# ║  .shellrc.local — Machine-specific overrides                    ║
# ║  This file is sourced by .shellrc.common and is NOT tracked     ║
# ║  by git. Put per-machine PATH additions, exports, aliases, etc. ║
# ║  from your old shell config here.                               ║
# ╚══════════════════════════════════════════════════════════════════╝

LOCALEOF
        success "Created ~/.shellrc.local (add machine-specific overrides here)"
    fi

    # eza theme
    # eza inherits Nord colors from the terminal palette by default.
    # If you want a custom eza theme, place it at ~/.config/eza/theme.yml
    # Available themes: https://github.com/eza-community/eza-themes
    mkdir -p ~/.config/eza

    # Shell-specific config
    if [[ "$DEFAULT_SHELL" == "zsh" ]]; then
        info "Detected ZSH — deploying full ZSH config + plugins"
        if [[ -f ~/.zshrc ]]; then
            if show_custom_lines ~/.zshrc "~/.zshrc"; then
                cp ~/.zshrc ~/.zshrc.bak
                warn "Backed up existing .zshrc → .zshrc.bak"
                cp "$SCRIPT_DIR/.zshrc" ~/.zshrc
                success ".zshrc → ~/.zshrc"
            fi
        else
            cp "$SCRIPT_DIR/.zshrc" ~/.zshrc
            success ".zshrc → ~/.zshrc"
        fi
        install_zsh_plugins
    else
        info "Detected Bash — appending to existing .bashrc"
        if [[ -f ~/.bashrc ]] && grep -q "shellrc.common" ~/.bashrc; then
            warn ".bashrc already has our config block"
            echo ""
            read -rp "Replace the existing config block with the latest version? [Y/n] " answer
            if [[ ! "$answer" =~ ^[Nn] ]]; then
                cp ~/.bashrc ~/.bashrc.bak
                warn "Backed up existing .bashrc → .bashrc.bak"
                # Remove old config block and append fresh one
                sed -i '/^# ── Terminal setup (added by install.sh) ──$/,$d' ~/.bashrc
                echo "" >> ~/.bashrc
                echo "# ── Terminal setup (added by install.sh) ──" >> ~/.bashrc
                cat "$SCRIPT_DIR/.bashrc.append" >> ~/.bashrc
                success "Updated terminal config block in ~/.bashrc"
            else
                warn "Skipped .bashrc — no changes made."
            fi
        else
            if [[ -f ~/.bashrc ]]; then
                cp ~/.bashrc ~/.bashrc.bak
                warn "Backed up existing .bashrc → .bashrc.bak"
            fi
            echo "" >> ~/.bashrc
            echo "# ── Terminal setup (added by install.sh) ──" >> ~/.bashrc
            cat "$SCRIPT_DIR/.bashrc.append" >> ~/.bashrc
            success ".bashrc.append → appended to ~/.bashrc"
        fi
    fi
}

# ─── Nerd Font check ─────────────────────────────────────────────
check_nerd_font() {
    echo ""
    warn "IMPORTANT: This setup requires a Nerd Font for icons to render."
    info "Recommended: 'MesloLGS Nerd Font' or 'JetBrainsMono Nerd Font'"
    echo ""
    if [[ "$OS" == "Darwin" ]]; then
        info "Install on macOS:"
        echo "    brew install --cask font-meslo-lg-nerd-font"
        echo ""
        info "Then in iTerm2:"
        echo "    Settings → Profiles → Text → Font → MesloLGS Nerd Font"
    else
        info "On a headless server, the font only matters on your LOCAL terminal"
        info "(the one you SSH from). If your Mac already has a Nerd Font set in"
        info "iTerm2, icons will render correctly over SSH — no font needed on"
        info "the server itself."
    fi
    echo ""
}

# ─── Main ─────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║       Terminal Setup Installer — Sysadmin Edition           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

case "$OS" in
    Darwin) install_macos  ;;
    Linux)
        case "$DISTRO" in
            debian|ubuntu|pop|linuxmint|raspbian) install_debian ;;
            fedora|rhel|centos|rocky|alma)        install_fedora ;;
            *) fail "Unsupported distro: $DISTRO. Install packages manually, then re-run with: bash install.sh" ;;
        esac
        ;;
    *) fail "Unsupported OS: $OS" ;;
esac

# ─── Optional ZSH installation (Linux only) ─────────────────────
if [[ "$OS" == "Linux" && "$DEFAULT_SHELL" != "zsh" ]]; then
    if [[ -n "$INSTALL_ZSH" ]]; then
        install_zsh_shell
    else
        echo ""
        local ZSH_PROMPT="Install zsh and set as default shell"
        if [[ "$CURRENT_USER" == "root" ]]; then
            ZSH_PROMPT+=" for root? [y/N] "
        else
            ZSH_PROMPT+=" for $CURRENT_USER and root? [y/N] "
        fi
        read -rp "$ZSH_PROMPT" zsh_answer
        if [[ "$zsh_answer" =~ ^[Yy] ]]; then
            install_zsh_shell
        fi
    fi
fi

deploy_configs
check_nerd_font

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  ✅  Installation complete!                                 ║"
echo "║                                                             ║"
echo "║  Restart your shell:                                        ║"
if [[ "$DEFAULT_SHELL" == "zsh" ]]; then
echo "║    exec zsh                                                 ║"
else
echo "║    exec bash                                                ║"
fi
echo "║                                                             ║"
echo "║  Quick test:  starship --version && eza --version           ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""
