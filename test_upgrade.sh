#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════╗
# ║  Sandbox test for install.sh --upgrade                          ║
# ║  Runs entirely in /tmp — never touches the real system          ║
# ╚══════════════════════════════════════════════════════════════════╝
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_DIR=$(mktemp -d)
PASS=0
FAIL=0
TESTS_RUN=0

cleanup() {
    rm -rf "$TEST_DIR"
}
trap cleanup EXIT

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

test_pass() {
    ((PASS++)) || true
    ((TESTS_RUN++)) || true
    echo -e "${GREEN}  PASS${NC}: $1"
}

test_fail() {
    ((FAIL++)) || true
    ((TESTS_RUN++)) || true
    echo -e "${RED}  FAIL${NC}: $1"
    if [[ -n "${2:-}" ]]; then
        echo -e "${RED}        $2${NC}"
    fi
}

assert_file_exists() {
    if [[ -f "$1" ]]; then
        test_pass "$2"
    else
        test_fail "$2" "File not found: $1"
    fi
}

assert_file_not_exists() {
    if [[ ! -f "$1" ]]; then
        test_pass "$2"
    else
        test_fail "$2" "File unexpectedly exists: $1"
    fi
}

assert_file_contains() {
    if grep -qF "$2" "$1" 2>/dev/null; then
        test_pass "$3"
    else
        test_fail "$3" "Expected '$2' in $1"
    fi
}

assert_file_equals() {
    if diff -q "$1" "$2" &>/dev/null; then
        test_pass "$3"
    else
        test_fail "$3" "Files differ: $1 vs $2"
    fi
}

assert_file_not_equals() {
    if ! diff -q "$1" "$2" &>/dev/null; then
        test_pass "$3"
    else
        test_fail "$3" "Files should differ but are identical"
    fi
}

# ─── Setup: create a fake HOME with repo files ──────────────────
setup_fake_home() {
    local test_name="$1"
    local fake_home="$TEST_DIR/$test_name"
    mkdir -p "$fake_home/.config"
    echo "$fake_home"
}

# ─── Source install.sh in a subshell with stubs ──────────────────
# We can't source the whole file (it runs immediately), so we'll
# extract just the functions and test them directly.

# Create a version of install.sh that only defines functions + vars
# without executing the main flow
create_function_library() {
    local lib="$TEST_DIR/install_lib.sh"
    cat > "$lib" << 'STUBEOF'
# Stubs for system-altering functions
install_macos() { : ; }
install_debian() { : ; }
install_fedora() { : ; }
install_zsh_shell() { : ; }
install_zsh_plugins() { : ; }
check_nerd_font() { : ; }
as_root() { : ; }
show_custom_lines() { return 0; }
STUBEOF

    # Extract everything from install.sh between the first function
    # and the main flow, plus the variable definitions
    # Simpler: just source the whole file but redefine dangerous parts
    # and prevent the main flow from running

    # Actually, let's just extract the functions we need to test
    # by sourcing install.sh with modifications
    cat >> "$lib" << VAREOF
OS="$(uname -s)"
DISTRO=""
DEFAULT_SHELL="zsh"
CURRENT_USER="testuser"
SCRIPT_DIR="$SCRIPT_DIR"
VAREOF

    # Append the color/logging functions and all new functions from install.sh
    # Extract: info, success, warn, fail, sed_inplace, save_deployed,
    # update_plugins, smart_deploy, resolve_conflict, smart_deploy_bash, upgrade, deploy_configs
    sed -n '
        /^RED=/,/^fail()/p
        /^DEPLOY_TRACKING_DIR=/p
        /^BASHRC_MARKER=/p
        /^sed_inplace()/,/^}/p
        /^save_deployed()/,/^}/p
        /^smart_deploy()/,/^}/p
        /^deploy_configs()/,/^}/p
    ' "$SCRIPT_DIR/install.sh" >> "$lib" 2>/dev/null || true

    echo "$lib"
}

# Better approach: source install.sh in a controlled way
run_in_sandbox() {
    local fake_home="$1"
    local shell_type="${2:-zsh}"
    local extra_code="$3"

    (
        # Override HOME
        export HOME="$fake_home"

        # Set variables that install.sh sets at top level
        OS="$(uname -s)"
        DISTRO=""
        DEFAULT_SHELL="$shell_type"
        CURRENT_USER="testuser"
        SCRIPT_DIR="$SCRIPT_DIR"
        DEPLOY_TRACKING_DIR="$fake_home/.config/starship-deploy/deployed"
        BASHRC_MARKER="# ── Terminal setup (added by install.sh) ──"

        # Colors
        RED='\033[0;31m'
        GREEN='\033[0;32m'
        YELLOW='\033[0;33m'
        CYAN='\033[0;36m'
        NC='\033[0m'

        info()    { echo -e "${CYAN}[INFO]${NC}  $*"; }
        success() { echo -e "${GREEN}[OK]${NC}    $*"; }
        warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
        fail()    { echo -e "${RED}[FAIL]${NC}  $*"; return 1; }

        # Stub out dangerous functions
        install_macos() { :; }
        install_debian() { :; }
        install_fedora() { :; }
        install_zsh_shell() { :; }
        install_zsh_plugins() { :; }
        check_nerd_font() { :; }
        as_root() { :; }
        show_custom_lines() { return 0; }
        update_plugins() { info "update_plugins stubbed"; }

        # Source just the function definitions from install.sh
        # We need: sed_inplace, save_deployed, smart_deploy, resolve_conflict,
        # smart_deploy_bash, upgrade, deploy_configs
        eval "$(sed -n '/^sed_inplace()/,/^}$/p' "$SCRIPT_DIR/install.sh")"
        eval "$(sed -n '/^save_deployed()/,/^}$/p' "$SCRIPT_DIR/install.sh")"

        # For multi-line functions with nested braces, we need a smarter extract
        # Let's use awk to extract functions properly
        extract_func() {
            local func_name="$1"
            local file="$2"
            awk "/^${func_name}\\(\\)/{found=1; depth=0} found{
                for(i=1;i<=length(\$0);i++){
                    c=substr(\$0,i,1)
                    if(c==\"{\") depth++
                    if(c==\"}\") depth--
                }
                print
                if(found && depth==0 && /}/) exit
            }" "$file"
        }

        eval "$(extract_func sed_inplace "$SCRIPT_DIR/install.sh")"
        eval "$(extract_func save_deployed "$SCRIPT_DIR/install.sh")"
        eval "$(extract_func find_deploy_base "$SCRIPT_DIR/install.sh")"
        eval "$(extract_func smart_deploy "$SCRIPT_DIR/install.sh")"
        eval "$(extract_func resolve_conflict "$SCRIPT_DIR/install.sh")"
        eval "$(extract_func smart_deploy_bash "$SCRIPT_DIR/install.sh")"
        eval "$(extract_func upgrade "$SCRIPT_DIR/install.sh")"
        eval "$(extract_func deploy_configs "$SCRIPT_DIR/install.sh")"

        # Run the test code
        eval "$extra_code"
    )
}

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Sandbox Tests for install.sh --upgrade                     ║"
echo "║  All operations in: $TEST_DIR"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 1: syntax check
# ═══════════════════════════════════════════════════════════════════
echo "── Test 1: Syntax check ──"
if bash -n "$SCRIPT_DIR/install.sh" 2>&1; then
    test_pass "install.sh passes bash -n"
else
    test_fail "install.sh has syntax errors"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 2: Function extraction works
# ═══════════════════════════════════════════════════════════════════
echo "── Test 2: Function extraction ──"
FAKE_HOME=$(setup_fake_home "test2")
output=$(run_in_sandbox "$FAKE_HOME" "zsh" '
    type sed_inplace 2>&1
    type save_deployed 2>&1
    type find_deploy_base 2>&1
    type smart_deploy 2>&1
    type resolve_conflict 2>&1
    type smart_deploy_bash 2>&1
    type upgrade 2>&1
    type deploy_configs 2>&1
' 2>&1) || true

for func in sed_inplace save_deployed find_deploy_base smart_deploy resolve_conflict smart_deploy_bash upgrade deploy_configs; do
    if echo "$output" | grep -q "${func}.*function" 2>/dev/null; then
        test_pass "Function $func extracted successfully"
    else
        test_fail "Function $func not found" "$(echo "$output" | grep "$func" || echo 'not in output')"
    fi
done
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 3: save_deployed creates tracking dir and file
# ═══════════════════════════════════════════════════════════════════
echo "── Test 3: save_deployed ──"
FAKE_HOME=$(setup_fake_home "test3")
run_in_sandbox "$FAKE_HOME" "zsh" '
    save_deployed "$SCRIPT_DIR/starship.toml" "starship.toml"
' 2>&1 | grep -v '^\[' || true

assert_file_exists "$FAKE_HOME/.config/starship-deploy/deployed/starship.toml" \
    "save_deployed creates file in tracking dir"
assert_file_equals "$SCRIPT_DIR/starship.toml" \
    "$FAKE_HOME/.config/starship-deploy/deployed/starship.toml" \
    "Deployed copy matches source"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 4: deploy_configs creates baselines (fresh install, ZSH)
# ═══════════════════════════════════════════════════════════════════
echo "── Test 4: deploy_configs creates baselines (ZSH) ──"
FAKE_HOME=$(setup_fake_home "test4")
run_in_sandbox "$FAKE_HOME" "zsh" '
    mkdir -p "$HOME/.config"
    deploy_configs
' 2>&1 | sed 's/^/    /'
echo ""

assert_file_exists "$FAKE_HOME/.config/starship.toml" \
    "starship.toml deployed"
assert_file_exists "$FAKE_HOME/.shellrc.common" \
    ".shellrc.common deployed"
assert_file_exists "$FAKE_HOME/.zshrc" \
    ".zshrc deployed"
assert_file_exists "$FAKE_HOME/.shellrc.local" \
    ".shellrc.local created"
assert_file_exists "$FAKE_HOME/.config/starship-deploy/deployed/starship.toml" \
    "Baseline saved: starship.toml"
assert_file_exists "$FAKE_HOME/.config/starship-deploy/deployed/shellrc.common" \
    "Baseline saved: shellrc.common"
assert_file_exists "$FAKE_HOME/.config/starship-deploy/deployed/zshrc" \
    "Baseline saved: zshrc"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 5: deploy_configs creates baselines (Bash)
# ═══════════════════════════════════════════════════════════════════
echo "── Test 5: deploy_configs creates baselines (Bash) ──"
FAKE_HOME=$(setup_fake_home "test5")
run_in_sandbox "$FAKE_HOME" "bash" '
    mkdir -p "$HOME/.config"
    deploy_configs
' 2>&1 | sed 's/^/    /'
echo ""

assert_file_exists "$FAKE_HOME/.bashrc" \
    ".bashrc created with append block"
assert_file_contains "$FAKE_HOME/.bashrc" "Terminal setup (added by install.sh)" \
    ".bashrc contains marker"
assert_file_exists "$FAKE_HOME/.config/starship-deploy/deployed/bashrc_block" \
    "Baseline saved: bashrc_block"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 6: smart_deploy — no changes (already up to date)
# ═══════════════════════════════════════════════════════════════════
echo "── Test 6: smart_deploy — no changes ──"
FAKE_HOME=$(setup_fake_home "test6")
output=$(run_in_sandbox "$FAKE_HOME" "zsh" '
    mkdir -p "$HOME/.config"
    # Simulate previous deploy
    cp "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml"
    save_deployed "$SCRIPT_DIR/starship.toml" "starship.toml"

    # Now smart_deploy with same file — should say up to date
    smart_deploy "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml" "starship.toml"
' 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "already up to date"; then
    test_pass "No-change case detected as up to date"
else
    test_fail "No-change case not detected" "$output"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 7: smart_deploy — repo changed, user didn't
# ═══════════════════════════════════════════════════════════════════
echo "── Test 7: smart_deploy — repo changed only ──"
FAKE_HOME=$(setup_fake_home "test7")
# Create a "modified repo file"
MODIFIED_REPO="$TEST_DIR/modified_starship.toml"
cp "$SCRIPT_DIR/starship.toml" "$MODIFIED_REPO"
echo "# new upstream change" >> "$MODIFIED_REPO"

output=$(run_in_sandbox "$FAKE_HOME" "zsh" "
    mkdir -p \"\$HOME/.config\"
    # Simulate previous deploy (with original)
    cp \"\$SCRIPT_DIR/starship.toml\" \"\$HOME/.config/starship.toml\"
    save_deployed \"\$SCRIPT_DIR/starship.toml\" \"starship.toml\"

    # Now smart_deploy with modified repo file — should auto-update
    smart_deploy \"$MODIFIED_REPO\" \"\$HOME/.config/starship.toml\" \"starship.toml\"
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "updated"; then
    test_pass "Repo-only change auto-updates"
else
    test_fail "Repo-only change not auto-updated" "$output"
fi
assert_file_exists "$FAKE_HOME/.config/starship.toml.bak" \
    "Backup created on auto-update"
assert_file_contains "$FAKE_HOME/.config/starship.toml" "new upstream change" \
    "Dest file has new upstream content"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 8: smart_deploy — user changed, repo didn't
# ═══════════════════════════════════════════════════════════════════
echo "── Test 8: smart_deploy — user changed only ──"
FAKE_HOME=$(setup_fake_home "test8")
output=$(run_in_sandbox "$FAKE_HOME" "zsh" '
    mkdir -p "$HOME/.config"
    # Simulate previous deploy
    cp "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml"
    save_deployed "$SCRIPT_DIR/starship.toml" "starship.toml"

    # User modifies the file
    echo "# my custom tweak" >> "$HOME/.config/starship.toml"

    # Smart deploy with unchanged repo — should keep user changes
    smart_deploy "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml" "starship.toml"
' 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "keeping your modifications"; then
    test_pass "User-only change preserved"
else
    test_fail "User-only change not preserved" "$output"
fi
assert_file_contains "$FAKE_HOME/.config/starship.toml" "my custom tweak" \
    "User's custom content still in file"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 9: smart_deploy — fresh deploy (no dest file)
# ═══════════════════════════════════════════════════════════════════
echo "── Test 9: smart_deploy — fresh deploy ──"
FAKE_HOME=$(setup_fake_home "test9")
output=$(run_in_sandbox "$FAKE_HOME" "zsh" '
    mkdir -p "$HOME/.config"
    # No existing file — should do fresh deploy
    smart_deploy "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml" "starship.toml"
' 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "fresh deploy"; then
    test_pass "Fresh deploy detected"
else
    test_fail "Fresh deploy not detected" "$output"
fi
assert_file_exists "$FAKE_HOME/.config/starship.toml" \
    "File deployed"
assert_file_exists "$FAKE_HOME/.config/starship-deploy/deployed/starship.toml" \
    "Baseline created on fresh deploy"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 10: smart_deploy — no baseline (first upgrade), files match
# ═══════════════════════════════════════════════════════════════════
echo "── Test 10: smart_deploy — no baseline, files match ──"
FAKE_HOME=$(setup_fake_home "test10")
output=$(run_in_sandbox "$FAKE_HOME" "zsh" '
    mkdir -p "$HOME/.config"
    # File exists but no baseline (pre-upgrade install)
    cp "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml"
    # No save_deployed — simulating pre-upgrade state

    smart_deploy "$SCRIPT_DIR/starship.toml" "$HOME/.config/starship.toml" "starship.toml"
' 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "baseline created"; then
    test_pass "No-baseline matching files creates baseline"
else
    test_fail "No-baseline matching files not handled" "$output"
fi
assert_file_exists "$FAKE_HOME/.config/starship-deploy/deployed/starship.toml" \
    "Baseline created when files match"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 11: smart_deploy_bash — fresh (no .bashrc)
# ═══════════════════════════════════════════════════════════════════
echo "── Test 11: smart_deploy_bash — fresh ──"
FAKE_HOME=$(setup_fake_home "test11")
output=$(run_in_sandbox "$FAKE_HOME" "bash" '
    smart_deploy_bash
' 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "created with config block"; then
    test_pass "Bash fresh deploy creates block"
else
    test_fail "Bash fresh deploy failed" "$output"
fi
assert_file_exists "$FAKE_HOME/.bashrc" ".bashrc created"
assert_file_contains "$FAKE_HOME/.bashrc" "Terminal setup (added by install.sh)" \
    ".bashrc has marker"
assert_file_contains "$FAKE_HOME/.bashrc" "shellrc.common" \
    ".bashrc sources shellrc.common"
assert_file_exists "$FAKE_HOME/.config/starship-deploy/deployed/bashrc_block" \
    "Bash block baseline saved"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 12: smart_deploy_bash — no changes
# ═══════════════════════════════════════════════════════════════════
echo "── Test 12: smart_deploy_bash — no changes ──"
FAKE_HOME=$(setup_fake_home "test12")
output=$(run_in_sandbox "$FAKE_HOME" "bash" '
    # First deploy
    smart_deploy_bash
    # Second deploy — should be up to date
    smart_deploy_bash
' 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "already up to date"; then
    test_pass "Bash no-change case detected"
else
    test_fail "Bash no-change case not detected" "$output"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 13: smart_deploy_bash — no marker in existing .bashrc
# ═══════════════════════════════════════════════════════════════════
echo "── Test 13: smart_deploy_bash — existing .bashrc without marker ──"
FAKE_HOME=$(setup_fake_home "test13")
output=$(run_in_sandbox "$FAKE_HOME" "bash" '
    echo "# existing bashrc content" > "$HOME/.bashrc"
    echo "export FOO=bar" >> "$HOME/.bashrc"
    smart_deploy_bash
' 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "appended"; then
    test_pass "Block appended to existing .bashrc"
else
    test_fail "Block not appended" "$output"
fi
assert_file_contains "$FAKE_HOME/.bashrc" "export FOO=bar" \
    "Original content preserved"
assert_file_contains "$FAKE_HOME/.bashrc" "Terminal setup (added by install.sh)" \
    "Marker appended"
assert_file_exists "$FAKE_HOME/.bashrc.bak" \
    "Backup created"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 14: smart_deploy_bash — user modified block, repo unchanged
# ═══════════════════════════════════════════════════════════════════
echo "── Test 14: smart_deploy_bash — user changed block only ──"
FAKE_HOME=$(setup_fake_home "test14")
output=$(run_in_sandbox "$FAKE_HOME" "bash" '
    # Initial deploy
    smart_deploy_bash
    # User adds a line after the block
    echo "# my custom bash addition" >> "$HOME/.bashrc"
    # Upgrade — repo unchanged, user changed
    smart_deploy_bash
' 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "keeping your modifications"; then
    test_pass "User-only bash block change preserved"
else
    test_fail "User-only bash block change not preserved" "$output"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 15: sed_inplace works on this platform
# ═══════════════════════════════════════════════════════════════════
echo "── Test 15: sed_inplace ──"
FAKE_HOME=$(setup_fake_home "test15")
SED_TEST="$TEST_DIR/sed_test.txt"
echo -e "line1\nREMOVE_ME\nline3" > "$SED_TEST"
output=$(run_in_sandbox "$FAKE_HOME" "zsh" "
    sed_inplace '/REMOVE_ME/d' '$SED_TEST'
" 2>&1)

if grep -q "REMOVE_ME" "$SED_TEST" 2>/dev/null; then
    test_fail "sed_inplace did not remove line"
else
    test_pass "sed_inplace works on $(uname -s)"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 16: upgrade() function runs without error
# ═══════════════════════════════════════════════════════════════════
echo "── Test 16: upgrade() end-to-end (ZSH) ──"
FAKE_HOME=$(setup_fake_home "test16")
output=$(run_in_sandbox "$FAKE_HOME" "zsh" '
    mkdir -p "$HOME/.config"
    upgrade
' 2>&1)
exit_code=$?
echo "$output" | sed 's/^/    /'

if [[ $exit_code -eq 0 ]]; then
    test_pass "upgrade() completed without error"
else
    test_fail "upgrade() exited with code $exit_code"
fi
if echo "$output" | grep -q "Upgrade complete"; then
    test_pass "upgrade() shows completion banner"
else
    test_fail "upgrade() missing completion banner"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 17: upgrade() end-to-end for bash
# ═══════════════════════════════════════════════════════════════════
echo "── Test 17: upgrade() end-to-end (Bash) ──"
FAKE_HOME=$(setup_fake_home "test17")
output=$(run_in_sandbox "$FAKE_HOME" "bash" '
    mkdir -p "$HOME/.config"
    upgrade
' 2>&1)
exit_code=$?
echo "$output" | sed 's/^/    /'

if [[ $exit_code -eq 0 ]]; then
    test_pass "upgrade() bash completed without error"
else
    test_fail "upgrade() bash exited with code $exit_code"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 18: Full cycle — deploy then upgrade with no changes
# ═══════════════════════════════════════════════════════════════════
echo "── Test 18: Full cycle — deploy then upgrade ──"
FAKE_HOME=$(setup_fake_home "test18")
output=$(run_in_sandbox "$FAKE_HOME" "zsh" '
    mkdir -p "$HOME/.config"
    # Step 1: Fresh deploy
    deploy_configs
    # Step 2: Upgrade with no changes
    upgrade
' 2>&1)
echo "$output" | sed 's/^/    /'

up_to_date_count=$(echo "$output" | grep -c "already up to date" || true)
if [[ $up_to_date_count -ge 2 ]]; then
    test_pass "Multiple files reported as up to date after deploy+upgrade"
else
    test_fail "Expected >=2 'up to date' messages, got $up_to_date_count"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 19: resolve_conflict — both changed, pick [u]se upstream
# ═══════════════════════════════════════════════════════════════════
echo "── Test 19: resolve_conflict — [u]se upstream ──"
FAKE_HOME=$(setup_fake_home "test19")
REPO_V2="$TEST_DIR/test19_repo.toml"
echo "repo version 2 content" > "$REPO_V2"
output=$(printf 'u\n' | run_in_sandbox "$FAKE_HOME" "zsh" "
    mkdir -p \"\$HOME/.config\"
    # Baseline = v1
    echo 'original content' > \"\$HOME/.config/starship.toml\"
    mkdir -p \"\$DEPLOY_TRACKING_DIR\"
    echo 'original content' > \"\$DEPLOY_TRACKING_DIR/starship.toml\"
    # User modified
    echo 'original content with user tweak' > \"\$HOME/.config/starship.toml\"
    # Repo changed too
    smart_deploy '$REPO_V2' \"\$HOME/.config/starship.toml\" 'starship.toml'
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "updated to upstream"; then
    test_pass "resolve_conflict [u] updates to upstream"
else
    test_fail "resolve_conflict [u] did not update" "$output"
fi
assert_file_exists "$FAKE_HOME/.config/starship.toml.bak" \
    "Backup created before upstream replace"
if grep -q "repo version 2 content" "$FAKE_HOME/.config/starship.toml" 2>/dev/null; then
    test_pass "Dest file has upstream content after [u]"
else
    test_fail "Dest file missing upstream content"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 20: resolve_conflict — both changed, pick [k]eep mine
# ═══════════════════════════════════════════════════════════════════
echo "── Test 20: resolve_conflict — [k]eep mine ──"
FAKE_HOME=$(setup_fake_home "test20")
REPO_V2="$TEST_DIR/test20_repo.toml"
echo "repo version 2 content" > "$REPO_V2"
output=$(printf 'k\n' | run_in_sandbox "$FAKE_HOME" "zsh" "
    mkdir -p \"\$HOME/.config\"
    mkdir -p \"\$DEPLOY_TRACKING_DIR\"
    echo 'original content' > \"\$DEPLOY_TRACKING_DIR/starship.toml\"
    echo 'my custom version' > \"\$HOME/.config/starship.toml\"
    smart_deploy '$REPO_V2' \"\$HOME/.config/starship.toml\" 'starship.toml'
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "keeping your version"; then
    test_pass "resolve_conflict [k] keeps user version"
else
    test_fail "resolve_conflict [k] did not keep" "$output"
fi
if grep -q "my custom version" "$FAKE_HOME/.config/starship.toml" 2>/dev/null; then
    test_pass "Dest file still has user content after [k]"
else
    test_fail "Dest file lost user content after [k]"
fi
# Baseline should NOT be updated (user re-prompted next time)
if grep -q "original content" "$FAKE_HOME/.config/starship-deploy/deployed/starship.toml" 2>/dev/null; then
    test_pass "Baseline NOT updated after [k] (re-prompt on next run)"
else
    test_fail "Baseline was incorrectly updated after [k]"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 21: resolve_conflict — [d]iff then [u]se upstream
# ═══════════════════════════════════════════════════════════════════
echo "── Test 21: resolve_conflict — [d]iff then [u] ──"
FAKE_HOME=$(setup_fake_home "test21")
REPO_V2="$TEST_DIR/test21_repo.toml"
echo "upstream v2" > "$REPO_V2"
output=$(printf 'd\nu\n' | run_in_sandbox "$FAKE_HOME" "zsh" "
    mkdir -p \"\$HOME/.config\"
    mkdir -p \"\$DEPLOY_TRACKING_DIR\"
    echo 'baseline' > \"\$DEPLOY_TRACKING_DIR/starship.toml\"
    echo 'user modified' > \"\$HOME/.config/starship.toml\"
    smart_deploy '$REPO_V2' \"\$HOME/.config/starship.toml\" 'starship.toml'
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "^---\|^+++\|^@@"; then
    test_pass "[d] showed unified diff output"
else
    test_fail "[d] did not show diff" "$output"
fi
if echo "$output" | grep -q "updated to upstream"; then
    test_pass "After [d], [u] updates to upstream"
else
    test_fail "After [d], [u] did not update" "$output"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 22: resolve_conflict — [s]ide-by-side then [k]eep
# ═══════════════════════════════════════════════════════════════════
echo "── Test 22: resolve_conflict — [s]ide-by-side then [k] ──"
FAKE_HOME=$(setup_fake_home "test22")
REPO_V2="$TEST_DIR/test22_repo.toml"
echo "upstream v2" > "$REPO_V2"
output=$(printf 's\nk\n' | run_in_sandbox "$FAKE_HOME" "zsh" "
    mkdir -p \"\$HOME/.config\"
    mkdir -p \"\$DEPLOY_TRACKING_DIR\"
    echo 'baseline' > \"\$DEPLOY_TRACKING_DIR/starship.toml\"
    echo 'user version' > \"\$HOME/.config/starship.toml\"
    smart_deploy '$REPO_V2' \"\$HOME/.config/starship.toml\" 'starship.toml'
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "|"; then
    test_pass "[s] showed side-by-side output"
else
    test_fail "[s] did not show side-by-side" "$output"
fi
if echo "$output" | grep -q "keeping your version"; then
    test_pass "After [s], [k] keeps user version"
else
    test_fail "After [s], [k] did not keep" "$output"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 23: resolve_conflict — [m]erge (clean three-way)
# ═══════════════════════════════════════════════════════════════════
echo "── Test 23: resolve_conflict — [m]erge (clean) ──"
FAKE_HOME=$(setup_fake_home "test23")
# Create three versions that merge cleanly:
# baseline: line1 / line2 / line3
# user:     USER1 / line2 / line3    (changed line1)
# repo:     line1 / line2 / REPO3    (changed line3)
# merge:    USER1 / line2 / REPO3
BASELINE_F="$TEST_DIR/test23_baseline"
USER_F="$TEST_DIR/test23_user"
REPO_F="$TEST_DIR/test23_repo"
printf 'line1\nline2\nline3\n' > "$BASELINE_F"
printf 'USER1\nline2\nline3\n' > "$USER_F"
printf 'line1\nline2\nREPO3\n' > "$REPO_F"

output=$(printf 'm\n' | run_in_sandbox "$FAKE_HOME" "zsh" "
    mkdir -p \"\$HOME/.config\"
    mkdir -p \"\$DEPLOY_TRACKING_DIR\"
    cp '$BASELINE_F' \"\$DEPLOY_TRACKING_DIR/test.conf\"
    cp '$USER_F' \"\$HOME/.config/test.conf\"
    smart_deploy '$REPO_F' \"\$HOME/.config/test.conf\" 'test.conf'
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "clean merge applied"; then
    test_pass "[m] clean merge succeeded"
else
    test_fail "[m] clean merge failed" "$output"
fi
# Check merged content
if grep -q "USER1" "$FAKE_HOME/.config/test.conf" 2>/dev/null && \
   grep -q "REPO3" "$FAKE_HOME/.config/test.conf" 2>/dev/null; then
    test_pass "Merged file has both user and repo changes"
else
    test_fail "Merged file missing changes" "$(cat "$FAKE_HOME/.config/test.conf" 2>/dev/null)"
fi
assert_file_exists "$FAKE_HOME/.config/test.conf.bak" \
    "Backup created before merge"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 24: resolve_conflict — [m] with no baseline (should refuse)
# ═══════════════════════════════════════════════════════════════════
echo "── Test 24: resolve_conflict — [m] refused without baseline ──"
FAKE_HOME=$(setup_fake_home "test24")
REPO_F="$TEST_DIR/test24_repo"
echo "repo content" > "$REPO_F"
output=$(printf 'm\nu\n' | run_in_sandbox "$FAKE_HOME" "zsh" "
    mkdir -p \"\$HOME/.config\"
    echo 'user content' > \"\$HOME/.config/test.conf\"
    # No baseline — smart_deploy will call resolve_conflict with empty deployed
    smart_deploy '$REPO_F' \"\$HOME/.config/test.conf\" 'test.conf'
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "No baseline available"; then
    test_pass "[m] correctly refused without baseline"
else
    test_fail "[m] did not refuse without baseline" "$output"
fi
if echo "$output" | grep -q "updated to upstream"; then
    test_pass "Fell through to [u] after [m] refusal"
else
    test_fail "Did not fall through to [u]" "$output"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 25: resolve_conflict — invalid choice then valid
# ═══════════════════════════════════════════════════════════════════
echo "── Test 25: resolve_conflict — invalid choice then [k] ──"
FAKE_HOME=$(setup_fake_home "test25")
REPO_F="$TEST_DIR/test25_repo"
echo "repo v2" > "$REPO_F"
output=$(printf 'x\nz\nk\n' | run_in_sandbox "$FAKE_HOME" "zsh" "
    mkdir -p \"\$HOME/.config\"
    mkdir -p \"\$DEPLOY_TRACKING_DIR\"
    echo 'baseline' > \"\$DEPLOY_TRACKING_DIR/test.conf\"
    echo 'user version' > \"\$HOME/.config/test.conf\"
    smart_deploy '$REPO_F' \"\$HOME/.config/test.conf\" 'test.conf'
" 2>&1)
echo "$output" | sed 's/^/    /'

invalid_count=$(echo "$output" | grep -c "Invalid choice" || true)
if [[ $invalid_count -ge 2 ]]; then
    test_pass "Invalid choices correctly rejected ($invalid_count times)"
else
    test_fail "Expected 2 invalid choice warnings, got $invalid_count"
fi
if echo "$output" | grep -q "keeping your version"; then
    test_pass "Eventually accepted valid [k] choice"
else
    test_fail "Did not accept valid choice after invalids" "$output"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 26: smart_deploy — no baseline, files differ, pick [u]
# ═══════════════════════════════════════════════════════════════════
echo "── Test 26: smart_deploy — no baseline + differ, [u] ──"
FAKE_HOME=$(setup_fake_home "test26")
REPO_F="$TEST_DIR/test26_repo"
echo "upstream version" > "$REPO_F"
output=$(printf 'u\n' | run_in_sandbox "$FAKE_HOME" "zsh" "
    mkdir -p \"\$HOME/.config\"
    echo 'different local version' > \"\$HOME/.config/test.conf\"
    # No baseline saved — first upgrade
    smart_deploy '$REPO_F' \"\$HOME/.config/test.conf\" 'test.conf'
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "no upgrade baseline"; then
    test_pass "No-baseline + differ detected"
else
    test_fail "No-baseline + differ not detected" "$output"
fi
if echo "$output" | grep -q "updated to upstream"; then
    test_pass "[u] applied in no-baseline scenario"
else
    test_fail "[u] not applied" "$output"
fi
assert_file_exists "$FAKE_HOME/.config/starship-deploy/deployed/test.conf" \
    "Baseline created after resolution"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 27: smart_deploy_bash — both changed, pick [u]se upstream
# ═══════════════════════════════════════════════════════════════════
echo "── Test 27: smart_deploy_bash — both changed, [u] ──"
FAKE_HOME=$(setup_fake_home "test27")
# Create a modified SCRIPT_DIR with a new .bashrc.append
FAKE_SCRIPT="$TEST_DIR/test27_script"
mkdir -p "$FAKE_SCRIPT"
printf '# new upstream bashrc content\n[ -f ~/.shellrc.common ] && . ~/.shellrc.common\n# upstream addition\n' > "$FAKE_SCRIPT/.bashrc.append"

output=$(printf 'u\n' | run_in_sandbox "$FAKE_HOME" "bash" "
    # Override SCRIPT_DIR to use our modified repo
    SCRIPT_DIR='$FAKE_SCRIPT'

    # Simulate a previous deploy with 'v1' baseline
    mkdir -p \"\$HOME\"
    echo '# ── Terminal setup (added by install.sh) ──' > \"\$HOME/.bashrc\"
    echo '# original bashrc content' >> \"\$HOME/.bashrc\"

    mkdir -p \"\$DEPLOY_TRACKING_DIR\"
    echo '# original bashrc content' > \"\$DEPLOY_TRACKING_DIR/bashrc_block\"

    # User also modified the block
    echo '# user custom line' >> \"\$HOME/.bashrc\"

    smart_deploy_bash
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "both you and upstream"; then
    test_pass "Bash both-changed detected"
else
    test_fail "Bash both-changed not detected" "$output"
fi
if echo "$output" | grep -q "updated to upstream"; then
    test_pass "Bash [u] updates to upstream"
else
    test_fail "Bash [u] did not update" "$output"
fi
assert_file_exists "$FAKE_HOME/.bashrc.bak" "Bash backup created"
assert_file_contains "$FAKE_HOME/.bashrc" "upstream addition" \
    "Bash block has new upstream content"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 28: smart_deploy_bash — both changed, pick [k]eep
# ═══════════════════════════════════════════════════════════════════
echo "── Test 28: smart_deploy_bash — both changed, [k]eep ──"
FAKE_HOME=$(setup_fake_home "test28")
FAKE_SCRIPT="$TEST_DIR/test28_script"
mkdir -p "$FAKE_SCRIPT"
printf '# new upstream v2\n' > "$FAKE_SCRIPT/.bashrc.append"

output=$(printf 'k\n' | run_in_sandbox "$FAKE_HOME" "bash" "
    SCRIPT_DIR='$FAKE_SCRIPT'
    mkdir -p \"\$HOME\"
    echo '# ── Terminal setup (added by install.sh) ──' > \"\$HOME/.bashrc\"
    echo '# original content' >> \"\$HOME/.bashrc\"
    echo '# user custom line' >> \"\$HOME/.bashrc\"

    mkdir -p \"\$DEPLOY_TRACKING_DIR\"
    echo '# original content' > \"\$DEPLOY_TRACKING_DIR/bashrc_block\"

    smart_deploy_bash
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "keeping your version"; then
    test_pass "Bash [k] keeps user version"
else
    test_fail "Bash [k] did not keep" "$output"
fi
assert_file_contains "$FAKE_HOME/.bashrc" "user custom line" \
    "User custom line still in .bashrc after [k]"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 29: smart_deploy_bash — no baseline, blocks differ, pick [u]
# (Uses a non-git SCRIPT_DIR to force manual fallback — git history
#  would auto-merge if we used the real repo)
# ═══════════════════════════════════════════════════════════════════
echo "── Test 29: smart_deploy_bash — no baseline + differ, [u] ──"
FAKE_HOME=$(setup_fake_home "test29")
FAKE_SCRIPT29="$TEST_DIR/test29_script"
mkdir -p "$FAKE_SCRIPT29"
cp "$SCRIPT_DIR/.bashrc.append" "$FAKE_SCRIPT29/.bashrc.append"
output=$(run_in_sandbox "$FAKE_HOME" "bash" "
    SCRIPT_DIR='$FAKE_SCRIPT29'
    # Create .bashrc with marker and different block
    echo '# existing stuff' > \"\$HOME/.bashrc\"
    echo \"\$BASHRC_MARKER\" >> \"\$HOME/.bashrc\"
    echo '# old hand-edited block' >> \"\$HOME/.bashrc\"
    # No baseline — first upgrade, block differs from repo
    smart_deploy_bash
" 2>&1 <<< "u")
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "no upgrade baseline"; then
    test_pass "Bash no-baseline differ detected"
else
    test_fail "Bash no-baseline differ not detected" "$output"
fi
if echo "$output" | grep -q "updated to upstream"; then
    test_pass "Bash no-baseline [u] applied"
else
    test_fail "Bash no-baseline [u] not applied" "$output"
fi
assert_file_contains "$FAKE_HOME/.bashrc" "shellrc.common" \
    "Block replaced with upstream content"
assert_file_contains "$FAKE_HOME/.bashrc" "existing stuff" \
    "Content before marker preserved"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 30: smart_deploy_bash — no baseline, blocks differ, pick [k]
# (Uses a non-git SCRIPT_DIR to force manual fallback)
# ═══════════════════════════════════════════════════════════════════
echo "── Test 30: smart_deploy_bash — no baseline + differ, [k]eep ──"
FAKE_HOME=$(setup_fake_home "test30")
FAKE_SCRIPT30="$TEST_DIR/test30_script"
mkdir -p "$FAKE_SCRIPT30"
cp "$SCRIPT_DIR/.bashrc.append" "$FAKE_SCRIPT30/.bashrc.append"
output=$(run_in_sandbox "$FAKE_HOME" "bash" "
    SCRIPT_DIR='$FAKE_SCRIPT30'
    echo '# existing stuff' > \"\$HOME/.bashrc\"
    echo \"\$BASHRC_MARKER\" >> \"\$HOME/.bashrc\"
    echo '# my hand-crafted block' >> \"\$HOME/.bashrc\"
    smart_deploy_bash
" 2>&1 <<< "k")
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "keeping your version"; then
    test_pass "Bash no-baseline [k] keeps user block"
else
    test_fail "Bash no-baseline [k] did not keep" "$output"
fi
assert_file_contains "$FAKE_HOME/.bashrc" "my hand-crafted block" \
    "User block content preserved after [k]"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 31: smart_deploy_bash — merge (clean three-way)
# ═══════════════════════════════════════════════════════════════════
echo "── Test 31: smart_deploy_bash — [m]erge (clean) ──"
FAKE_HOME=$(setup_fake_home "test31")
FAKE_SCRIPT="$TEST_DIR/test31_script"
mkdir -p "$FAKE_SCRIPT"
# Need enough lines between changes so git merge-file doesn't treat them as
# overlapping hunks. Changes on line 2 (user) and line 7 (repo).
# baseline: L1 / L2 / L3 / L4 / L5 / L6 / L7
# user:     L1 / USER_CHANGE / L3 / L4 / L5 / L6 / L7
# repo:     L1 / L2 / L3 / L4 / L5 / L6 / REPO_CHANGE
# merge:    L1 / USER_CHANGE / L3 / L4 / L5 / L6 / REPO_CHANGE
printf 'L1\nL2\nL3\nL4\nL5\nL6\nREPO_CHANGE\n' > "$FAKE_SCRIPT/.bashrc.append"

output=$(printf 'm\n' | run_in_sandbox "$FAKE_HOME" "bash" "
    SCRIPT_DIR='$FAKE_SCRIPT'
    mkdir -p \"\$HOME\"
    echo '# preamble' > \"\$HOME/.bashrc\"
    echo \"\$BASHRC_MARKER\" >> \"\$HOME/.bashrc\"
    printf 'L1\nUSER_CHANGE\nL3\nL4\nL5\nL6\nL7\n' >> \"\$HOME/.bashrc\"

    mkdir -p \"\$DEPLOY_TRACKING_DIR\"
    printf 'L1\nL2\nL3\nL4\nL5\nL6\nL7\n' > \"\$DEPLOY_TRACKING_DIR/bashrc_block\"

    smart_deploy_bash
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "clean merge applied"; then
    test_pass "Bash [m] clean merge succeeded"
else
    test_fail "Bash [m] clean merge failed" "$output"
fi
if grep -q "USER_CHANGE" "$FAKE_HOME/.bashrc" 2>/dev/null && \
   grep -q "REPO_CHANGE" "$FAKE_HOME/.bashrc" 2>/dev/null; then
    test_pass "Bash merged block has both user and repo changes"
else
    test_fail "Bash merged block missing changes" "$(cat "$FAKE_HOME/.bashrc" 2>/dev/null)"
fi
assert_file_contains "$FAKE_HOME/.bashrc" "preamble" \
    "Preamble before marker preserved after merge"
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 32: find_deploy_base — finds match in git history
# ═══════════════════════════════════════════════════════════════════
echo "── Test 32: find_deploy_base — finds match in git history ──"
FAKE_HOME=$(setup_fake_home "test32")
# Use an actual repo file (starship.toml) — it has git history
# Create a "user file" that matches the current version
USER_COPY="$TEST_DIR/test32_user.toml"
cp "$SCRIPT_DIR/starship.toml" "$USER_COPY"
output=$(run_in_sandbox "$FAKE_HOME" "zsh" "
    result=\$(find_deploy_base \"\$SCRIPT_DIR/starship.toml\" '$USER_COPY') || true
    if [[ -n \"\$result\" && -f \"\$result\" ]]; then
        echo 'FOUND_BASE=yes'
        echo \"BASE_FILE=\$result\"
        # The found base should be a valid file
        echo \"BASE_LINES=\$(wc -l < \"\$result\" | tr -d ' ')\"
        rm -f \"\$result\"
    else
        echo 'FOUND_BASE=no'
    fi
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "FOUND_BASE=yes"; then
    test_pass "find_deploy_base found a match in git history"
else
    test_fail "find_deploy_base did not find a match" "$output"
fi
if echo "$output" | grep -qE "BASE_LINES=[1-9]"; then
    test_pass "Found base file has content"
else
    test_fail "Found base file is empty or missing" "$output"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 33: find_deploy_base — returns failure for non-repo file
# ═══════════════════════════════════════════════════════════════════
echo "── Test 33: find_deploy_base — non-repo file returns failure ──"
FAKE_HOME=$(setup_fake_home "test33")
NON_REPO_FILE="$TEST_DIR/test33_nonexistent.conf"
echo "not in repo" > "$NON_REPO_FILE"
USER_FILE="$TEST_DIR/test33_user.conf"
echo "user version" > "$USER_FILE"
output=$(run_in_sandbox "$FAKE_HOME" "zsh" "
    if find_deploy_base '$NON_REPO_FILE' '$USER_FILE' >/dev/null 2>&1; then
        echo 'RESULT=found'
    else
        echo 'RESULT=not_found'
    fi
" 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "RESULT=not_found"; then
    test_pass "find_deploy_base correctly returns failure for non-repo file"
else
    test_fail "find_deploy_base should not find non-repo files" "$output"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 34: smart_deploy — no baseline, auto-merge via git history
# ═══════════════════════════════════════════════════════════════════
echo "── Test 34: smart_deploy — no baseline, auto-merge via git history ──"
FAKE_HOME=$(setup_fake_home "test34")
# Use a real repo file so find_deploy_base can search git history.
# Simulate: user has a modified copy of .shellrc.common (added a line at the end),
# and the repo has the current version. find_deploy_base should find the version
# closest to the user's file and auto-merge.
output=$(run_in_sandbox "$FAKE_HOME" "zsh" '
    mkdir -p "$HOME/.config"
    # User has the current repo version + a custom addition
    cp "$SCRIPT_DIR/.shellrc.common" "$HOME/.shellrc.common"
    echo "# my custom alias" >> "$HOME/.shellrc.common"
    # No baseline — simulating first upgrade
    # smart_deploy should find the original in git history and auto-merge
    smart_deploy "$SCRIPT_DIR/.shellrc.common" "$HOME/.shellrc.common" "shellrc.common"
' 2>&1)
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "auto-merged\|already up to date\|baseline created"; then
    test_pass "No-baseline auto-merge with git history succeeded"
else
    test_fail "No-baseline auto-merge did not succeed" "$output"
fi
# User's custom line should still be present
if grep -q "my custom alias" "$FAKE_HOME/.shellrc.common" 2>/dev/null; then
    test_pass "User's custom addition preserved after auto-merge"
else
    test_fail "User's custom addition lost after auto-merge"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# TEST 35: find_deploy_base — function extraction check
# ═══════════════════════════════════════════════════════════════════
echo "── Test 35: find_deploy_base — function is callable ──"
FAKE_HOME=$(setup_fake_home "test35")
output=$(run_in_sandbox "$FAKE_HOME" "zsh" '
    type find_deploy_base 2>&1
' 2>&1) || true
echo "$output" | sed 's/^/    /'

if echo "$output" | grep -q "find_deploy_base.*function"; then
    test_pass "find_deploy_base extracted and callable"
else
    test_fail "find_deploy_base not callable" "$output"
fi
echo ""

# ═══════════════════════════════════════════════════════════════════
# RESULTS
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║  Results: $PASS passed, $FAIL failed (out of $TESTS_RUN)               "
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

if [[ $FAIL -gt 0 ]]; then
    exit 1
fi
exit 0
