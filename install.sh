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
DEPLOY_TRACKING_DIR="$HOME/.config/starship-deploy/deployed"
BASHRC_MARKER="# ── Terminal setup (added by install.sh) ──"

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
UPGRADE_MODE=""
for arg in "$@"; do
    case "$arg" in
        --zsh) INSTALL_ZSH=1 ;;
        --upgrade) UPGRADE_MODE=1 ;;
        --help|-h)
            echo "Usage: bash install.sh [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  (no flags)    Fresh install — backup existing configs and deploy new ones"
            echo "  --upgrade     Smart upgrade — three-way merge, keeps your modifications"
            echo "  --zsh         Install zsh and set as default shell (Linux only)"
            echo "  --help, -h    Show this help message"
            exit 0
            ;;
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

# ─── Portable sed -i (BSD macOS vs GNU Linux) ────────────────────
sed_inplace() {
    if [[ "$OS" == "Darwin" ]]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# ─── Find original deployed version from git history ─────────────
# Searches the repo's git log for the version of a file that most
# closely matches the user's current file. Outputs a temp file path
# containing the best-matching version, or nothing if not found.
find_deploy_base() {
    local repo_file="$1"
    local user_file="$2"

    # Get path relative to SCRIPT_DIR (repo root)
    local rel_path
    rel_path="${repo_file#$SCRIPT_DIR/}"

    # Verify this is a git repo
    if ! git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
        return 1
    fi

    local best_commit=""
    local best_diff=999999
    local tmp
    tmp=$(mktemp)

    while IFS= read -r commit; do
        if git -C "$SCRIPT_DIR" show "${commit}:${rel_path}" > "$tmp" 2>/dev/null; then
            local diff_lines
            diff_lines=$(diff "$tmp" "$user_file" 2>/dev/null | wc -l | tr -d ' ')
            if (( diff_lines < best_diff )); then
                best_diff=$diff_lines
                best_commit=$commit
            fi
            # Exact match — stop early
            if (( diff_lines == 0 )); then
                break
            fi
        fi
    done < <(git -C "$SCRIPT_DIR" log --format=%H -- "$rel_path" 2>/dev/null)

    rm -f "$tmp"

    if [[ -n "$best_commit" ]]; then
        local base_file
        base_file=$(mktemp)
        git -C "$SCRIPT_DIR" show "${best_commit}:${rel_path}" > "$base_file" 2>/dev/null
        echo "$base_file"
        return 0
    fi
    return 1
}

# ─── Save a copy to the deploy tracking directory ────────────────
save_deployed() {
    local src="$1"
    local basename="$2"
    mkdir -p "$DEPLOY_TRACKING_DIR"
    cp "$src" "$DEPLOY_TRACKING_DIR/$basename"
}

# Build the effective .zshrc for this OS (appends macOS extras on Darwin)
build_zshrc() {
    local tmp
    tmp=$(mktemp)
    cat "$SCRIPT_DIR/.zshrc" > "$tmp"
    if [[ "$OS" == "Darwin" && -f "$SCRIPT_DIR/.zshrc.macos" ]]; then
        cat "$SCRIPT_DIR/.zshrc.macos" >> "$tmp"
    fi
    echo "$tmp"
}

# ─── Update ZSH plugins via git ──────────────────────────────────
update_plugins() {
    info "Updating ZSH plugins..."
    local plugin_dir="$HOME/.zsh/plugins"
    if [[ ! -d "$plugin_dir" ]]; then
        warn "No plugins directory found — skipping plugin update"
        return
    fi

    local updated=0
    local failed=0
    for dir in "$plugin_dir"/*/; do
        [[ ! -d "$dir/.git" ]] && continue
        local name
        name=$(basename "$dir")
        info "  Updating $name..."

        # Detect default branch
        local default_branch
        default_branch=$(git -C "$dir" symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||') || true
        if [[ -z "$default_branch" ]]; then
            default_branch=$(git -C "$dir" remote show origin 2>/dev/null | grep 'HEAD branch' | awk '{print $NF}') || true
        fi
        [[ -z "$default_branch" ]] && default_branch="master"

        # Try fetch + fast-forward
        if git -C "$dir" fetch --depth=1 origin "$default_branch" 2>/dev/null; then
            if git -C "$dir" merge --ff-only "origin/$default_branch" 2>/dev/null; then
                success "  $name updated"
                ((updated++)) || true
            else
                # Fast-forward failed — re-clone
                warn "  $name: fast-forward failed, re-cloning..."
                local remote_url
                remote_url=$(git -C "$dir" remote get-url origin 2>/dev/null)
                if [[ -n "$remote_url" ]]; then
                    rm -rf "$dir"
                    if git clone --depth=1 "$remote_url" "$dir" 2>/dev/null; then
                        success "  $name re-cloned"
                        ((updated++)) || true
                    else
                        warn "  $name: re-clone failed"
                        ((failed++)) || true
                    fi
                else
                    warn "  $name: no remote URL, skipping"
                    ((failed++)) || true
                fi
            fi
        else
            warn "  $name: fetch failed, skipping"
            ((failed++)) || true
        fi
    done

    if ((updated > 0)); then
        success "$updated plugin(s) updated"
    fi
    if ((failed > 0)); then
        warn "$failed plugin(s) had errors (non-fatal)"
    fi
    if ((updated == 0 && failed == 0)); then
        info "All plugins already up to date"
    fi
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

# ─── Smart deploy: three-way merge for config files ──────────────
smart_deploy() {
    local repo_file="$1"
    local dest="$2"
    local basename="$3"
    local deployed="$DEPLOY_TRACKING_DIR/$basename"

    # No destination file — fresh deploy
    if [[ ! -f "$dest" ]]; then
        cp "$repo_file" "$dest"
        save_deployed "$repo_file" "$basename"
        success "$basename → $dest (fresh deploy)"
        return
    fi

    # No baseline — first upgrade run
    if [[ ! -f "$deployed" ]]; then
        if diff -q "$dest" "$repo_file" &>/dev/null; then
            # Files match — create baseline, nothing to do
            save_deployed "$repo_file" "$basename"
            info "$basename: already up to date (baseline created)"
            return
        else
            # Files differ — try to find the original version from git history
            local found_base
            found_base=$(find_deploy_base "$repo_file" "$dest") || true
            if [[ -n "$found_base" ]]; then
                info "$basename: found original version in git history, attempting merge..."
                local tmp_merge
                tmp_merge=$(mktemp)
                cp "$dest" "$tmp_merge"
                if git merge-file "$tmp_merge" "$found_base" "$repo_file" 2>/dev/null; then
                    # Clean merge — auto-apply
                    cp "$dest" "${dest}.bak"
                    cp "$tmp_merge" "$dest"
                    save_deployed "$repo_file" "$basename"
                    rm -f "$tmp_merge" "$found_base"
                    success "$basename: auto-merged (backup saved to ${dest}.bak)"
                else
                    # Merge has conflicts — enter interactive resolution with the found base
                    rm -f "$tmp_merge"
                    warn "$basename: merge has conflicts, entering interactive resolution"
                    resolve_conflict "$repo_file" "$dest" "$found_base" "$basename"
                    rm -f "$found_base"
                fi
            else
                warn "$basename: no upgrade baseline found, files differ"
                resolve_conflict "$repo_file" "$dest" "" "$basename"
            fi
            return
        fi
    fi

    # Has baseline — apply three-way truth table
    local repo_changed="" user_changed=""
    if ! diff -q "$deployed" "$repo_file" &>/dev/null; then
        repo_changed=1
    fi
    if ! diff -q "$deployed" "$dest" &>/dev/null; then
        user_changed=1
    fi

    if [[ -z "$repo_changed" && -z "$user_changed" ]]; then
        info "$basename: already up to date"
    elif [[ -n "$repo_changed" && -z "$user_changed" ]]; then
        cp "$dest" "${dest}.bak"
        cp "$repo_file" "$dest"
        save_deployed "$repo_file" "$basename"
        success "$basename: updated (backup saved to ${dest}.bak)"
    elif [[ -z "$repo_changed" && -n "$user_changed" ]]; then
        info "$basename: repo unchanged, keeping your modifications"
    else
        # Both changed
        warn "$basename: both you and upstream have changes"
        resolve_conflict "$repo_file" "$dest" "$deployed" "$basename"
    fi
}

# ─── Interactive conflict resolution ─────────────────────────────
resolve_conflict() {
    local repo_file="$1"
    local dest="$2"
    local deployed="$3"  # empty string if no baseline
    local label="$4"

    while true; do
        echo ""
        echo "╔══════════════════════════════════════════════════════════════╗"
        printf "║  Conflict: %-49s║\n" "$label"
        echo "╚══════════════════════════════════════════════════════════════╝"
        echo ""
        echo "  [d] Show diff (your file vs upstream)"
        echo "  [s] Side-by-side diff"
        echo "  [m] Auto-merge via git merge-file"
        echo "  [k] Keep mine (skip upstream)"
        echo "  [u] Use upstream (backup yours to .bak)"
        echo "  [e] Open in editor for manual merge"
        echo ""
        read -rp "Choose action: " choice

        case "$choice" in
            d)
                echo ""
                diff -u "$dest" "$repo_file" || true
                echo ""
                ;;
            s)
                echo ""
                diff -y --width=120 "$dest" "$repo_file" || true
                echo ""
                ;;
            m)
                local merge_base="$deployed"
                local auto_base=""
                if [[ -z "$merge_base" ]]; then
                    # Try to find base from git history
                    info "Searching git history for merge base..."
                    auto_base=$(find_deploy_base "$repo_file" "$dest") || true
                    if [[ -n "$auto_base" ]]; then
                        merge_base="$auto_base"
                        info "Found likely original version in git history"
                    else
                        warn "No baseline available — cannot do three-way merge"
                        warn "Use [d] to view diff, then [e] to edit manually"
                        continue
                    fi
                fi
                local tmp_merge
                tmp_merge=$(mktemp)
                cp "$dest" "$tmp_merge"
                if git merge-file "$tmp_merge" "$merge_base" "$repo_file" 2>/dev/null; then
                    cp "$dest" "${dest}.bak"
                    cp "$tmp_merge" "$dest"
                    save_deployed "$repo_file" "$label"
                    rm -f "$tmp_merge" "$auto_base"
                    success "$label: clean merge applied (backup saved)"
                    return
                else
                    # Merge has conflicts
                    warn "Merge has conflict markers — opening in editor for review"
                    cp "$dest" "${dest}.bak"
                    cp "$tmp_merge" "$dest"
                    rm -f "$tmp_merge" "$auto_base"
                    "${EDITOR:-vi}" "$dest"
                    # Check for remaining conflict markers
                    if grep -q '^<<<<<<<\|^=======\|^>>>>>>>' "$dest" 2>/dev/null; then
                        warn "Conflict markers still present in $label — resolve manually"
                    else
                        save_deployed "$repo_file" "$label"
                        success "$label: merge resolved"
                    fi
                    return
                fi
                ;;
            k)
                info "$label: keeping your version (upstream skipped)"
                # Do NOT update baseline — user re-prompted on next upstream change
                return
                ;;
            u)
                cp "$dest" "${dest}.bak"
                cp "$repo_file" "$dest"
                save_deployed "$repo_file" "$label"
                success "$label: updated to upstream (backup saved)"
                return
                ;;
            e)
                cp "$dest" "${dest}.bak"
                cp "$repo_file" "$dest"
                "${EDITOR:-vi}" "$dest"
                save_deployed "$repo_file" "$label"
                success "$label: manually edited (backup saved)"
                return
                ;;
            *)
                warn "Invalid choice. Please select d, s, m, k, u, or e."
                ;;
        esac
    done
}

# ─── Smart deploy for .bashrc block ──────────────────────────────
smart_deploy_bash() {
    local repo_file="$SCRIPT_DIR/.bashrc.append"
    local dest="$HOME/.bashrc"
    local basename="bashrc_block"
    local deployed="$DEPLOY_TRACKING_DIR/$basename"
    local marker_escaped
    marker_escaped=$(printf '%s' "$BASHRC_MARKER" | sed 's/[[\.*^$/]/\\&/g')

    # No .bashrc — create with config block
    if [[ ! -f "$dest" ]]; then
        echo "" >> "$dest"
        echo "$BASHRC_MARKER" >> "$dest"
        cat "$repo_file" >> "$dest"
        save_deployed "$repo_file" "$basename"
        success ".bashrc: created with config block"
        return
    fi

    # Check if marker exists
    if ! grep -qF "$BASHRC_MARKER" "$dest"; then
        # No marker — append fresh block
        cp "$dest" "${dest}.bak"
        echo "" >> "$dest"
        echo "$BASHRC_MARKER" >> "$dest"
        cat "$repo_file" >> "$dest"
        save_deployed "$repo_file" "$basename"
        success ".bashrc: config block appended (backup saved)"
        return
    fi

    # Extract current block (everything after marker to EOF)
    local current_block
    current_block=$(sed -n "/^${marker_escaped}$/,\$p" "$dest" | tail -n +2)

    local new_block
    new_block=$(cat "$repo_file")

    # No baseline — first upgrade
    if [[ ! -f "$deployed" ]]; then
        if [[ "$current_block" == "$new_block" ]]; then
            save_deployed "$repo_file" "$basename"
            info ".bashrc block: already up to date (baseline created)"
            return
        else
            # Try to find original version from git history
            local tmp_current
            tmp_current=$(mktemp)
            echo "$current_block" > "$tmp_current"
            local found_base
            found_base=$(find_deploy_base "$repo_file" "$tmp_current") || true
            if [[ -n "$found_base" ]]; then
                info ".bashrc block: found original version in git history, attempting merge..."
                local tmp_merge
                tmp_merge=$(mktemp)
                cp "$tmp_current" "$tmp_merge"
                if git merge-file "$tmp_merge" "$found_base" "$repo_file" 2>/dev/null; then
                    # Clean merge — auto-apply
                    cp "$dest" "${dest}.bak"
                    sed_inplace "/^${marker_escaped}$/,\$d" "$dest"
                    echo "$BASHRC_MARKER" >> "$dest"
                    cat "$tmp_merge" >> "$dest"
                    save_deployed "$repo_file" "$basename"
                    rm -f "$tmp_merge" "$found_base" "$tmp_current"
                    success ".bashrc block: auto-merged (backup saved)"
                    return
                else
                    warn ".bashrc block: merge has conflicts"
                    rm -f "$tmp_merge" "$found_base"
                fi
            fi

            # Fall back to manual resolution
            warn ".bashrc block: no upgrade baseline found, blocks differ"
            local tmp_new
            tmp_new=$(mktemp)
            echo "$new_block" > "$tmp_new"
            echo ""
            diff -u --label "current .bashrc block" --label "upstream .bashrc.append" "$tmp_current" "$tmp_new" || true
            echo ""
            read -rp ".bashrc block: [k]eep yours / [u]se upstream / [e]dit? " choice
            case "$choice" in
                u)
                    cp "$dest" "${dest}.bak"
                    sed_inplace "/^${marker_escaped}$/,\$d" "$dest"
                    echo "$BASHRC_MARKER" >> "$dest"
                    cat "$repo_file" >> "$dest"
                    save_deployed "$repo_file" "$basename"
                    success ".bashrc block: updated to upstream (backup saved)"
                    ;;
                e)
                    cp "$dest" "${dest}.bak"
                    "${EDITOR:-vi}" "$dest"
                    save_deployed "$repo_file" "$basename"
                    success ".bashrc block: manually edited (backup saved)"
                    ;;
                *)
                    info ".bashrc block: keeping your version"
                    ;;
            esac
            rm -f "$tmp_current" "$tmp_new"
            return
        fi
    fi

    # Has baseline — apply truth table
    local deployed_block
    deployed_block=$(cat "$deployed")

    local repo_changed="" user_changed=""
    if [[ "$deployed_block" != "$new_block" ]]; then
        repo_changed=1
    fi
    if [[ "$deployed_block" != "$current_block" ]]; then
        user_changed=1
    fi

    if [[ -z "$repo_changed" && -z "$user_changed" ]]; then
        info ".bashrc block: already up to date"
    elif [[ -n "$repo_changed" && -z "$user_changed" ]]; then
        cp "$dest" "${dest}.bak"
        sed_inplace "/^${marker_escaped}$/,\$d" "$dest"
        echo "$BASHRC_MARKER" >> "$dest"
        cat "$repo_file" >> "$dest"
        save_deployed "$repo_file" "$basename"
        success ".bashrc block: updated (backup saved)"
    elif [[ -z "$repo_changed" && -n "$user_changed" ]]; then
        info ".bashrc block: repo unchanged, keeping your modifications"
    else
        warn ".bashrc block: both you and upstream have changes"
        local tmp_current tmp_new tmp_deployed
        tmp_current=$(mktemp)
        tmp_new=$(mktemp)
        tmp_deployed=$(mktemp)
        echo "$current_block" > "$tmp_current"
        echo "$new_block" > "$tmp_new"
        echo "$deployed_block" > "$tmp_deployed"
        echo ""
        diff -u --label "current .bashrc block" --label "upstream .bashrc.append" "$tmp_current" "$tmp_new" || true
        echo ""
        read -rp ".bashrc block: [m]erge / [k]eep yours / [u]se upstream / [e]dit? " choice
        case "$choice" in
            m)
                local tmp_merge
                tmp_merge=$(mktemp)
                cp "$tmp_current" "$tmp_merge"
                if git merge-file "$tmp_merge" "$tmp_deployed" "$tmp_new" 2>/dev/null; then
                    cp "$dest" "${dest}.bak"
                    sed_inplace "/^${marker_escaped}$/,\$d" "$dest"
                    echo "$BASHRC_MARKER" >> "$dest"
                    cat "$tmp_merge" >> "$dest"
                    save_deployed "$repo_file" "$basename"
                    rm -f "$tmp_merge"
                    success ".bashrc block: clean merge applied (backup saved)"
                else
                    warn "Merge has conflict markers — opening in editor"
                    cp "$dest" "${dest}.bak"
                    sed_inplace "/^${marker_escaped}$/,\$d" "$dest"
                    echo "$BASHRC_MARKER" >> "$dest"
                    cat "$tmp_merge" >> "$dest"
                    rm -f "$tmp_merge"
                    "${EDITOR:-vi}" "$dest"
                    if grep -q '^<<<<<<<\|^=======\|^>>>>>>>' "$dest" 2>/dev/null; then
                        warn "Conflict markers still present — resolve manually"
                    else
                        save_deployed "$repo_file" "$basename"
                        success ".bashrc block: merge resolved"
                    fi
                fi
                ;;
            u)
                cp "$dest" "${dest}.bak"
                sed_inplace "/^${marker_escaped}$/,\$d" "$dest"
                echo "$BASHRC_MARKER" >> "$dest"
                cat "$repo_file" >> "$dest"
                save_deployed "$repo_file" "$basename"
                success ".bashrc block: updated to upstream (backup saved)"
                ;;
            e)
                cp "$dest" "${dest}.bak"
                "${EDITOR:-vi}" "$dest"
                save_deployed "$repo_file" "$basename"
                success ".bashrc block: manually edited (backup saved)"
                ;;
            *)
                info ".bashrc block: keeping your version"
                ;;
        esac
        rm -f "$tmp_current" "$tmp_new" "$tmp_deployed"
    fi
}

# ─── Upgrade mode entry point ────────────────────────────────────
upgrade() {
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║       Terminal Setup — Upgrade Mode                        ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""

    # 1. Run OS-specific package installer (idempotent — picks up new tools)
    info "Checking for new/updated packages..."
    case "$OS" in
        Darwin) install_macos ;;
        Linux)
            case "$DISTRO" in
                debian|ubuntu|pop|linuxmint|raspbian) install_debian ;;
                fedora|rhel|centos|rocky|alma)        install_fedora ;;
                *) fail "Unsupported distro: $DISTRO" ;;
            esac
            ;;
        *) fail "Unsupported OS: $OS" ;;
    esac

    echo ""
    info "=== Upgrading configurations ==="
    echo ""

    # 2. Update ZSH plugins (if using ZSH)
    if [[ "$DEFAULT_SHELL" == "zsh" ]]; then
        update_plugins
        echo ""
    fi

    # 3. Smart deploy config files
    mkdir -p ~/.config
    smart_deploy "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml" "starship.toml"
    smart_deploy "$SCRIPT_DIR/.shellrc.common" "$HOME/.shellrc.common" "shellrc.common"

    if [[ "$DEFAULT_SHELL" == "zsh" ]]; then
        local zshrc_src
        zshrc_src=$(build_zshrc)
        smart_deploy "$zshrc_src" "$HOME/.zshrc" "zshrc"
        rm -f "$zshrc_src"
    else
        smart_deploy_bash
    fi

    # 4. Ensure .shellrc.local exists
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

    # 5. Completion banner
    echo ""
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║  ✅  Upgrade complete!                                      ║"
    echo "║                                                             ║"
    echo "║  Restart your shell:                                        ║"
    if [[ "$DEFAULT_SHELL" == "zsh" ]]; then
    echo "║    exec zsh                                                 ║"
    else
    echo "║    exec bash                                                ║"
    fi
    echo "╚══════════════════════════════════════════════════════════════╝"
    echo ""
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
    save_deployed "$SCRIPT_DIR/starship.toml" "starship.toml"
    success "starship.toml → ~/.config/starship.toml"

    # Shared shell config (always)
    if [[ -f ~/.shellrc.common ]]; then
        cp ~/.shellrc.common ~/.shellrc.common.bak
        warn "Backed up existing .shellrc.common → .shellrc.common.bak"
    fi
    cp "$SCRIPT_DIR/.shellrc.common" ~/.shellrc.common
    save_deployed "$SCRIPT_DIR/.shellrc.common" "shellrc.common"
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
        local zshrc_src
        zshrc_src=$(build_zshrc)
        if [[ -f ~/.zshrc ]]; then
            if show_custom_lines ~/.zshrc "~/.zshrc"; then
                cp ~/.zshrc ~/.zshrc.bak
                warn "Backed up existing .zshrc → .zshrc.bak"
                cp "$zshrc_src" ~/.zshrc
                save_deployed "$zshrc_src" "zshrc"
                success ".zshrc → ~/.zshrc"
            fi
        else
            cp "$zshrc_src" ~/.zshrc
            save_deployed "$zshrc_src" "zshrc"
            success ".zshrc → ~/.zshrc"
        fi
        rm -f "$zshrc_src"
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
                sed_inplace '/^# ── Terminal setup (added by install.sh) ──$/,$d' ~/.bashrc
                echo "" >> ~/.bashrc
                echo "$BASHRC_MARKER" >> ~/.bashrc
                cat "$SCRIPT_DIR/.bashrc.append" >> ~/.bashrc
                save_deployed "$SCRIPT_DIR/.bashrc.append" "bashrc_block"
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
            echo "$BASHRC_MARKER" >> ~/.bashrc
            cat "$SCRIPT_DIR/.bashrc.append" >> ~/.bashrc
            save_deployed "$SCRIPT_DIR/.bashrc.append" "bashrc_block"
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

# ─── Upgrade mode: smart three-way merge instead of fresh install ─
if [[ -n "$UPGRADE_MODE" ]]; then
    upgrade
    exit 0
fi

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
