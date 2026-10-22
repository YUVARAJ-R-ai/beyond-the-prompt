#!/usr/bin/env bash
# =============================================================================
# Cross-Platform Event Onboarding — Linux Setup Script (setup.sh)
# =============================================================================
# Purpose:
#   Automates and verifies the local development environment for event
#   participants on Linux (x86_64 and arm64; Ubuntu/Debian, Fedora, openSUSE,
#   Arch and similar):
#     1. Git CLI (+ OpenSSH client)
#     2. Node.js (LTS >= 18) & npm
#     3. Zepher CLI (zepher-cli -> zepher)
#     4. Orca Desktop Application (.deb / .rpm / AppImage)
#     5. Orca CLI (orca-ide on Linux)
#     6. GitHub CLI (gh)
#     7. GitHub authentication over SSH (gh login + SSH key + git identity)
#     8. AI agent CLIs (Claude Code, OpenCode)
#     9. jq
#    10. Event skills (into ~/.claude/skills)
#
#   Uses the event USB kit ('Beyond the Prompt' folder) for offline installs
#   of npm packages when it is found (or given with --offline-kit).
#
# Usage:
#   chmod +x setup.sh
#   ./setup.sh
#
# Options:
#   --check-only, --dry-run   Inspect and verify tools without installing anything
#   --no-prompt               Run non-interactively (no sudo, no browser sign-in)
#   --agents <list>           claude,opencode (default), claude, opencode, or none
#   --offline-kit <DIR>       Path of the USB kit's 'Beyond the Prompt' folder
#   --help, -h                Show usage information and exit
#
# Security & Safety Principles:
#   - Never pipes remote scripts into a shell.
#   - Verifies SHA-256 / SHA-512 checksums on every standalone download.
#   - Prefers per-user installations (~/.local); uses sudo only for the
#     distribution's own package manager (git, Orca .deb/.rpm), and asks first.
#   - Never collects, prints, or transmits API keys, tokens, or credentials.
#   - Never modifies shell startup files (~/.bashrc, ~/.profile, etc.).
#   - Never overwrites an existing SSH key; ~/.ssh/config is only changed when
#     needed (ssh-agent passphrase or port-443 fallback), inside a marked
#     block, with a backup copy.
#   - Safe, resumable, and idempotent to run repeatedly.
# =============================================================================

set -u
set -o pipefail

# -----------------------------------------------------------------------------
# Organizer Configuration Section (Isolated for easy maintenance)
# -----------------------------------------------------------------------------
readonly REPO_WEB_URL="${ONBOARD_REPO_WEB_URL:-https://github.com/The-Fable-Club/beyond-the-prompt}"
readonly REPO_ZIP_URL="${ONBOARD_REPO_ZIP_URL:-https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip}"

readonly ZEPHER_NPM_PACKAGE="zepher-cli"
readonly ZEPHER_BIN_NAME="zepher"
readonly ZEPHER_NPM_URL="https://www.npmjs.com/package/zepher-cli"
readonly MIN_NODE_MAJOR=18
readonly NODE_DIST_BASE_URL="${ONBOARD_NODE_DIST_BASE_URL:-https://nodejs.org/dist/latest-v22.x}"

readonly ORCA_WEBSITE_URL="https://www.onorca.dev"
readonly ORCA_INSTALL_DOCS_URL="https://www.onorca.dev/docs/install"
readonly ORCA_CLI_DOCS_URL="https://www.onorca.dev/docs/cli/overview"
readonly ORCA_RELEASES_DOWNLOAD_URL="${ONBOARD_ORCA_RELEASES_DOWNLOAD_URL:-https://github.com/stablyai/orca/releases/latest/download}"

readonly GH_CLI_URL="https://cli.github.com"
readonly GH_RELEASES_LATEST_URL="${ONBOARD_GH_RELEASES_LATEST_URL:-https://github.com/cli/cli/releases/latest}"
readonly GH_RELEASES_DOWNLOAD_BASE_URL="https://github.com/cli/cli/releases/download"
readonly GH_SSH_DOCS_URL="https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
# Extra token scopes on top of gh's defaults: upload SSH keys + GitHub Projects commands
readonly GH_AUTH_SCOPES="admin:public_key,project"
readonly SSH_KEY_PATH="${ONBOARD_SSH_KEY_PATH:-${HOME}/.ssh/id_ed25519}"
readonly SSH_CONFIG_BLOCK_BEGIN="# >>> beyond-the-prompt: GitHub SSH (managed by setup.sh) >>>"
readonly SSH_CONFIG_BLOCK_END="# <<< beyond-the-prompt: GitHub SSH <<<"

readonly CLAUDE_CODE_NPM_PACKAGE="@anthropic-ai/claude-code"
readonly CLAUDE_CODE_URL="https://www.npmjs.com/package/@anthropic-ai/claude-code"
readonly OPENCODE_NPM_PACKAGE="opencode-ai"
readonly OPENCODE_URL="https://opencode.ai"
readonly JQ_URL="https://jqlang.org"
readonly JQ_RELEASES_LATEST_URL="${ONBOARD_JQ_RELEASES_LATEST_URL:-https://github.com/jqlang/jq/releases/latest}"
readonly JQ_RELEASES_DOWNLOAD_BASE_URL="https://github.com/jqlang/jq/releases/download"
# Used when the "latest" redirect cannot be resolved; still verified against its sha256sum.txt
readonly JQ_FALLBACK_TAG="jq-1.8.2"
readonly SKILLS_TARGET_DIR="${ONBOARD_SKILLS_DIR:-${HOME}/.claude/skills}"
# Name of the folder on the event USB stick (see START-HERE.txt on the stick)
readonly OFFLINE_KIT_FOLDER="Beyond the Prompt"

readonly GIT_LINUX_URL="https://git-scm.com/download/linux"
readonly NODE_DOWNLOAD_URL="https://nodejs.org/en/download"

readonly USER_BIN_DIR="${ONBOARD_USER_BIN_DIR:-${HOME}/.local/bin}"

# -----------------------------------------------------------------------------
# Runtime State & Result Tracking
# -----------------------------------------------------------------------------
CHECK_ONLY="${ONBOARD_CHECK_ONLY:-0}"
NO_PROMPT="${ONBOARD_NO_PROMPT:-0}"
NETWORK_AVAILABLE=0
ARCH_NAME="unknown"
ARCH_GO="amd64"      # gh / jq naming
ARCH_NODE="x64"      # Node.js naming
PKG_MANAGER=""
NEW_TERMINAL_ADVISED=0
AGENTS_TO_INSTALL="${ONBOARD_AGENTS:-claude,opencode}"
OFFLINE_KIT_ARG="${ONBOARD_OFFLINE_KIT:-}"
OFFLINE_OS_DIR=""
OFFLINE_NPM_CACHE=""
NPM_CACHE_ARGS=()
ORCA_CLI_BIN=""

STATUS_GIT="FAIL";        DETAIL_GIT="Not checked"
STATUS_NODE="FAIL";       DETAIL_NODE="Not checked"
STATUS_ZEPHER="FAIL";     DETAIL_ZEPHER="Not checked"
STATUS_ORCA_APP="FAIL";   DETAIL_ORCA_APP="Not checked"
STATUS_ORCA_CLI="FAIL";   DETAIL_ORCA_CLI="Not checked"
STATUS_GH="FAIL";         DETAIL_GH="Not checked"
STATUS_GH_SSH="FAIL";     DETAIL_GH_SSH="Not checked"
STATUS_AGENTS="FAIL";     DETAIL_AGENTS="Not checked"
STATUS_JQ="FAIL";         DETAIL_JQ="Not checked"
STATUS_SKILLS="FAIL";     DETAIL_SKILLS="Not checked"

RECOVERY_NOTES=()

# -----------------------------------------------------------------------------
# Terminal Formatting Helpers
# -----------------------------------------------------------------------------
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'; C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'
  C_RED=$'\033[1;31m'; C_CYAN=$'\033[1;36m'; C_BLUE=$'\033[1;34m'
else
  C_RESET=""; C_BOLD=""; C_GREEN=""; C_YELLOW=""; C_RED=""; C_CYAN=""; C_BLUE=""
fi

say() { printf '%s\n' "$*"; }
print_step() { say ""; say "${C_BOLD}${C_BLUE}==> $1${C_RESET}"; }
print_info() { say "    [INFO] $1"; }
print_pass() { say "    ${C_GREEN}[PASS]${C_RESET} $1"; }
print_skip() { say "    ${C_GREEN}[SKIPPED]${C_RESET} $1"; }
print_action() { say "    ${C_YELLOW}[ACTION REQUIRED]${C_RESET} $1"; }
print_fail() { say "    ${C_RED}[FAIL]${C_RESET} $1"; }
add_recovery_note() { RECOVERY_NOTES+=("$1"); }

# Shows a path with $HOME replaced by ~
tilde() {
  local p="$1"
  if [[ "$p" == "$HOME"* ]]; then p="~${p#"$HOME"}"; fi
  printf '%s' "$p"
}

# Joins the remaining arguments with the first one
join_by() {
  local sep="$1"; shift
  local out="" item
  for item in "$@"; do
    if [[ -z "$out" ]]; then out="$item"; else out="${out}${sep}${item}"; fi
  done
  printf '%s' "$out"
}

sha256_of() { sha256sum "$1" 2>/dev/null | awk '{print tolower($1)}'; }

# SHA-512 as base64 (the format of electron-builder's latest-linux.yml)
sha512_b64_of() {
  if command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha512 -binary "$1" | base64 | tr -d '\n'
  elif command -v python3 >/dev/null 2>&1; then
    python3 -I -c 'import base64,hashlib,sys;print(base64.b64encode(hashlib.sha512(open(sys.argv[1],"rb").read()).digest()).decode(),end="")' "$1"
  else
    return 1
  fi
}

extract_zip() {
  # unzip is missing on some minimal installs; Python's zipfile is the fallback
  if command -v unzip >/dev/null 2>&1; then
    unzip -q -o "$1" -d "$2"
  elif command -v python3 >/dev/null 2>&1; then
    python3 -I -m zipfile -e "$1" "$2"
  else
    return 1
  fi
}

print_banner() {
  say ""
  say "${C_CYAN}=============================================================================${C_RESET}"
  say "${C_BOLD}  AI Development Event — Linux Environment Onboarding (setup.sh)${C_RESET}"
  say "${C_CYAN}=============================================================================${C_RESET}"
  say "This script independently detects and prepares your event tools:"
  say "  1. Git CLI                 (Version control + OpenSSH client)"
  say "  2. Node.js & npm           (JavaScript runtime >= v${MIN_NODE_MAJOR} LTS & package manager)"
  say "  3. Zepher CLI              (npm package: ${ZEPHER_NPM_PACKAGE} -> '${ZEPHER_BIN_NAME}')"
  say "  4. Orca Desktop App        (Agent Development Environment)"
  say "  5. Orca CLI                ('orca-ide' command registered via Orca Settings)"
  say "  6. GitHub CLI              ('gh' command)"
  say "  7. GitHub over SSH         (gh login in your browser + SSH key for git)"
  say "  8. AI agent CLIs           (${AGENTS_TO_INSTALL}; you sign in to them yourself)"
  say "  9. jq                      (JSON tool used by the event's GitHub skills)"
  say " 10. Event skills            (copied into ~/.claude/skills)"
  say ""
  say "${C_BLUE}Privacy & Security:${C_RESET}"
  say "  - Existing working installations are preserved and never overwritten."
  say "  - Standalone downloads are verified with SHA-256 / SHA-512 checksums."
  say "  - Prefers per-user locations (~/.local) and asks before using sudo."
  say "  - Shell startup files (~/.bashrc, ~/.profile) are never modified."
  say "  - No API keys, tokens, or personal credentials are requested or collected."
  say "    (You sign in to GitHub yourself in the browser; gh stores its own token.)"
  if [[ "$CHECK_ONLY" == "1" ]]; then
    say ""
    say "${C_YELLOW}[MODE] Running in --check-only mode (no installations will be performed).${C_RESET}"
  fi
  say "${C_CYAN}-----------------------------------------------------------------------------${C_RESET}"
}

show_help() {
  cat <<EOF
Usage: ./setup.sh [OPTIONS]

Linux onboarding script for the AI Development Event.

Options:
  --check-only, --dry-run   Verify installed tools without making any system changes
  --no-prompt               Do not use sudo or open the browser (reports what is left)
  --agents <list>           AI agent CLIs to install: claude,opencode (default), claude, opencode, or none
  --offline-kit <DIR>       Use the event USB kit ('${OFFLINE_KIT_FOLDER}' folder) for offline installs
                            (found automatically next to this repo, in ~/Downloads, or on /media and /run/media)
  --bootstrap               Download & extract full repository ZIP before running
  --local-zip <FILE>        Bootstrap repository from a local .zip archive
  --zip-url <URL>           Override repository ZIP download URL
  --sha256 <HASH>           Verify ZIP archive against expected SHA-256 hash
  --help, -h                Show this help message and exit

If the script is not executable:
  chmod +x setup.sh
  ./setup.sh
EOF
}

# -----------------------------------------------------------------------------
# Standalone Bootstrap Routine (Runs when invoked alone or when requested)
# -----------------------------------------------------------------------------
run_standalone_bootstrap() {
  local target_zip_url="$1" target_local_zip="$2" target_sha256="$3"
  shift 3

  say ""
  say "${C_CYAN}=============================================================================${C_RESET}"
  say "${C_BOLD}  AI Development Event — Standalone Repository Bootstrap${C_RESET}"
  say "${C_CYAN}=============================================================================${C_RESET}"

  local temp_dir
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/onboard-bootstrap.XXXXXX")"
  local archive_file="${temp_dir}/repo.zip"

  if [[ -n "$target_local_zip" ]]; then
    print_info "Bootstrapping from local ZIP archive: ${target_local_zip}"
    if [[ ! -f "$target_local_zip" ]]; then
      print_fail "Local ZIP file not found: ${target_local_zip}"
      rm -rf "$temp_dir"; return 1
    fi
    cp "$target_local_zip" "$archive_file"
  else
    if [[ "$target_zip_url" != https://* ]]; then
      print_fail "Refusing insecure or non-HTTPS ZIP URL: ${target_zip_url}"
      rm -rf "$temp_dir"; return 1
    fi
    print_info "Downloading repository archive from: ${target_zip_url}"
    if ! curl -fL --retry 2 --connect-timeout 10 -o "$archive_file" "$target_zip_url"; then
      print_fail "Failed to download repository ZIP. Download it in your browser and run:"
      print_info "  ./setup.sh --local-zip ~/Downloads/beyond-the-prompt-main.zip"
      rm -rf "$temp_dir"; return 1
    fi
  fi

  local magic_hex
  magic_hex="$(head -c 4 "$archive_file" 2>/dev/null | od -An -tx1 2>/dev/null | tr -d '[:space:]' || true)"
  if [[ "$magic_hex" != "504b0304" ]]; then
    print_fail "File is not a valid ZIP archive."
    rm -rf "$temp_dir"; return 1
  fi

  if [[ -n "$target_sha256" ]]; then
    local actual_sha256
    actual_sha256="$(sha256_of "$archive_file")"
    if [[ "$actual_sha256" != "${target_sha256,,}" ]]; then
      print_fail "SHA-256 checksum mismatch for repository ZIP!"
      rm -rf "$temp_dir"; return 1
    fi
    print_pass "SHA-256 checksum verified (${actual_sha256})."
  fi

  mkdir -p "${temp_dir}/extracted"
  if ! extract_zip "$archive_file" "${temp_dir}/extracted"; then
    print_fail "Failed to extract ZIP archive (install 'unzip' or 'python3')."
    rm -rf "$temp_dir"; return 1
  fi

  local found_script
  found_script="$(find "${temp_dir}/extracted" -maxdepth 3 -type f -name "setup.sh" 2>/dev/null | head -n 1 || true)"
  if [[ -z "$found_script" ]]; then
    print_fail "Could not locate 'setup.sh' inside extracted archive."
    rm -rf "$temp_dir"; return 1
  fi

  print_pass "Extracted and launching setup.sh..."
  ONBOARD_SKIP_AUTO_BOOTSTRAP=1 bash "$found_script" "$@"
  local child_rc=$?
  rm -rf "$temp_dir"
  return $child_rc
}

# -----------------------------------------------------------------------------
# Parse Command-Line Arguments
# -----------------------------------------------------------------------------
BOOTSTRAP_REQUESTED=0
BOOTSTRAP_LOCAL_ZIP=""
BOOTSTRAP_ZIP_URL="$REPO_ZIP_URL"
BOOTSTRAP_SHA256=""
FORWARD_ARGS=()

while (( $# > 0 )); do
  case "$1" in
    --check-only|--dry-run) CHECK_ONLY=1; FORWARD_ARGS+=("$1"); shift ;;
    --no-prompt|--non-interactive) NO_PROMPT=1; FORWARD_ARGS+=("$1"); shift ;;
    --bootstrap) BOOTSTRAP_REQUESTED=1; shift ;;
    --agents|--offline-kit|--local-zip|--zip-url|--sha256)
      if (( $# < 2 )); then
        say "${C_RED}[ERROR] $1 requires a value.${C_RESET}" >&2
        exit 2
      fi
      case "$1" in
        --agents) AGENTS_TO_INSTALL="$2"; FORWARD_ARGS+=("$1" "$2") ;;
        --offline-kit) OFFLINE_KIT_ARG="$2"; FORWARD_ARGS+=("$1" "$2") ;;
        --local-zip) BOOTSTRAP_REQUESTED=1; BOOTSTRAP_LOCAL_ZIP="$2" ;;
        --zip-url) BOOTSTRAP_REQUESTED=1; BOOTSTRAP_ZIP_URL="$2" ;;
        --sha256) BOOTSTRAP_SHA256="$2" ;;
      esac
      shift 2
      ;;
    --help|-h) show_help; exit 0 ;;
    *) say "${C_RED}Unknown option: $1${C_RESET}"; show_help; exit 2 ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "$BOOTSTRAP_REQUESTED" == "1" ]] || \
   { [[ ! -f "${SCRIPT_DIR}/README.md" ]] && [[ ! -f "${SCRIPT_DIR}/setup.zsh" ]] && [[ "${ONBOARD_SKIP_AUTO_BOOTSTRAP:-0}" != "1" ]]; }; then
  run_standalone_bootstrap "$BOOTSTRAP_ZIP_URL" "$BOOTSTRAP_LOCAL_ZIP" "$BOOTSTRAP_SHA256" "${FORWARD_ARGS[@]}"
  exit $?
fi

# -----------------------------------------------------------------------------
# Refresh Session PATH (In-Memory Only — Does Not Modify Shell Startup Files)
# -----------------------------------------------------------------------------
refresh_session_path() {
  if [[ "${ONBOARD_DISABLE_PATH_REFRESH:-0}" == "1" ]]; then
    return 0
  fi
  local dir
  for dir in "${HOME}/.local/node-lts/bin" "$USER_BIN_DIR" "${HOME}/.npm-global/bin" \
             "${HOME}/.volta/bin" "${HOME}/.asdf/shims" "/usr/local/bin" "/usr/bin" "/bin"; do
    if [[ -d "$dir" ]] && [[ ":${PATH}:" != *":${dir}:"* ]]; then
      export PATH="${PATH}:${dir}"
    fi
  done
  if [[ -d "${HOME}/.nvm/versions/node" ]]; then
    local latest_nvm_bin
    latest_nvm_bin="$(find "${HOME}/.nvm/versions/node" -maxdepth 2 -type d -name bin 2>/dev/null | sort -V | tail -n 1 || true)"
    if [[ -n "$latest_nvm_bin" ]] && [[ ":${PATH}:" != *":${latest_nvm_bin}:"* ]]; then
      export PATH="${PATH}:${latest_nvm_bin}"
    fi
  fi
  if command -v npm >/dev/null 2>&1; then
    local npm_prefix
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    if [[ -n "$npm_prefix" ]] && [[ -d "${npm_prefix}/bin" ]] && [[ ":${PATH}:" != *":${npm_prefix}/bin:"* ]]; then
      export PATH="${PATH}:${npm_prefix}/bin"
    fi
  fi
}

# -----------------------------------------------------------------------------
# Distribution Package Manager (only used for git/openssh and Orca .deb/.rpm)
# -----------------------------------------------------------------------------
detect_package_manager() {
  if command -v apt-get >/dev/null 2>&1; then PKG_MANAGER="apt"
  elif command -v dnf >/dev/null 2>&1; then PKG_MANAGER="dnf"
  elif command -v zypper >/dev/null 2>&1; then PKG_MANAGER="zypper"
  elif command -v pacman >/dev/null 2>&1; then PKG_MANAGER="pacman"
  else PKG_MANAGER=""
  fi
}

pkg_install_command() {
  # Prints the install command for the given packages (or local package files)
  case "$PKG_MANAGER" in
    apt) printf 'sudo apt-get install -y %s' "$*" ;;
    dnf) printf 'sudo dnf install -y %s' "$*" ;;
    zypper) printf 'sudo zypper --non-interactive install %s' "$*" ;;
    pacman) printf 'sudo pacman -S --needed --noconfirm %s' "$*" ;;
    *) return 1 ;;
  esac
}

run_with_sudo_consent() {
  # Shows the exact command, then runs it (sudo asks for the password itself)
  local cmd="$1"
  if [[ "$NO_PROMPT" == "1" ]] || [[ ! -t 0 ]]; then
    return 2
  fi
  print_info "Running: ${cmd}"
  print_info "(sudo may ask for your Linux password.)"
  if [[ "$PKG_MANAGER" == "apt" ]] && [[ "$cmd" == *"apt-get install"* ]]; then
    sudo apt-get update -qq || true
  fi
  bash -c "$cmd"
}

# -----------------------------------------------------------------------------
# Offline USB Kit & npm Helpers
# -----------------------------------------------------------------------------
detect_offline_kit() {
  # Finds the Linux folder of the event USB kit ('Beyond the Prompt/Linux'), given either
  # the kit folder or its Linux folder, next to this repo, in ~/Downloads, or on a USB stick.
  local -a roots=()
  [[ -n "$OFFLINE_KIT_ARG" ]] && roots+=("$OFFLINE_KIT_ARG")
  roots+=("${SCRIPT_DIR}/.." "${SCRIPT_DIR}/../.." "${HOME}/Downloads" "${HOME}/Downloads/${OFFLINE_KIT_FOLDER}" "${HOME}/Desktop/${OFFLINE_KIT_FOLDER}")
  local vol
  for vol in /media/"${USER:-}"/* /run/media/"${USER:-}"/* /media/* /mnt/*; do
    [[ -d "${vol}/${OFFLINE_KIT_FOLDER}" ]] && roots+=("${vol}/${OFFLINE_KIT_FOLDER}")
  done

  local root candidate
  for root in "${roots[@]}"; do
    for candidate in "${root}/Linux" "${root}"; do
      [[ -d "$candidate" ]] || continue
      candidate="$(cd "$candidate" && pwd)"
      if [[ "$(basename "$candidate")" == "Linux" ]] && \
         { [[ -f "${candidate}/npm-offline-cache.zip" ]] || [[ -d "${candidate}/npm-offline-cache/_cacache" ]]; }; then
        OFFLINE_OS_DIR="$candidate"
        return 0
      fi
    done
  done
  return 1
}

prepare_offline_npm_cache() {
  # Makes the kit's npm cache usable: an extracted local copy is used in place, a USB
  # copy is extracted once to ~/.cache (npm writes to its cache, so never use the stick).
  if [[ -n "$OFFLINE_NPM_CACHE" ]]; then
    return 0
  fi
  if [[ -z "$OFFLINE_OS_DIR" ]]; then
    return 1
  fi

  local extracted="${OFFLINE_OS_DIR}/npm-offline-cache"
  if [[ -d "${extracted}/_cacache" ]] && [[ "$extracted" != /media/* ]] && [[ "$extracted" != /run/media/* ]] && [[ -w "$extracted" ]]; then
    OFFLINE_NPM_CACHE="$extracted"
  else
    local kit_zip="${OFFLINE_OS_DIR}/npm-offline-cache.zip"
    local dest="${HOME}/.cache/beyond-the-prompt"
    [[ -f "$kit_zip" ]] || return 1
    if [[ ! -d "${dest}/npm-offline-cache/_cacache" ]]; then
      print_info "Extracting the USB kit's offline npm cache to ~/.cache/beyond-the-prompt (one time, about a minute)..."
      mkdir -p "$dest"
      if ! extract_zip "$kit_zip" "$dest"; then
        print_info "Could not extract ${kit_zip}; npm will use the internet instead."
        return 1
      fi
    fi
    OFFLINE_NPM_CACHE="${dest}/npm-offline-cache"
  fi

  # --prefer-offline uses the kit for everything it holds and the internet only for the rest;
  # --offline when there is no internet at all. npm checks every cached tarball's integrity hash.
  if [[ "$NETWORK_AVAILABLE" == "1" ]]; then
    NPM_CACHE_ARGS=(--prefer-offline --cache "$OFFLINE_NPM_CACHE")
  else
    NPM_CACHE_ARGS=(--offline --cache "$OFFLINE_NPM_CACHE")
  fi
  return 0
}

npm_global_install() {
  # Installs npm packages globally without sudo, using the USB kit's npm cache when present.
  prepare_offline_npm_cache || true
  if [[ -n "$OFFLINE_NPM_CACHE" ]]; then
    print_info "Using the offline npm cache from the USB kit ($(tilde "$OFFLINE_NPM_CACHE"))."
  fi

  local npm_global_prefix
  npm_global_prefix="$(npm prefix -g 2>/dev/null || echo "/usr/local")"

  if [[ -w "${npm_global_prefix}/lib/node_modules" ]] || [[ -w "${npm_global_prefix}" ]]; then
    print_info "Running: npm install -g $*"
    npm install -g --no-audit --no-fund "${NPM_CACHE_ARGS[@]}" "$@"
    return $?
  fi

  # Prefer writable per-user ~/.npm-global so sudo is never required
  local user_npm_prefix="${ONBOARD_USER_NPM_PREFIX:-${HOME}/.npm-global}"
  print_info "Global npm prefix (${npm_global_prefix}) requires administrator permissions."
  print_info "Installing per-user into '$(tilde "$user_npm_prefix")' to avoid requiring sudo: $*"
  mkdir -p "${user_npm_prefix}/bin" "${user_npm_prefix}/lib" "$USER_BIN_DIR"
  npm install -g --no-audit --no-fund "${NPM_CACHE_ARGS[@]}" --prefix "${user_npm_prefix}" "$@"
  local install_rc=$?
  local bin_path
  for bin_path in "${user_npm_prefix}/bin/"*; do
    [[ -e "$bin_path" ]] || continue
    ln -sf "$bin_path" "${USER_BIN_DIR}/$(basename "$bin_path")"
  done
  NEW_TERMINAL_ADVISED=1
  return $install_rc
}

resolve_latest_tag() {
  # Resolves a GitHub "releases/latest" URL to its tag through the redirect (no API rate limit)
  local tag_url
  tag_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' --retry 2 --connect-timeout 10 "$1" 2>/dev/null || true)"
  printf '%s' "${tag_url##*/tag/}"
}

# -----------------------------------------------------------------------------
# 0. Independent Prerequisite & Environment Detection
# -----------------------------------------------------------------------------
find_orca_cli() {
  ORCA_CLI_BIN=""
  local candidate
  for candidate in orca-ide orca; do
    if command -v "$candidate" >/dev/null 2>&1; then
      ORCA_CLI_BIN="$candidate"
      return 0
    fi
  done
  return 1
}

find_orca_app_linux() {
  local candidate
  for candidate in "${HOME}/Applications/Orca.AppImage" /opt/Orca/orca-ide /opt/Orca/orca /opt/orca-ide/orca-ide \
                   /usr/bin/orca-ide /usr/lib/orca-ide/orca-ide "${HOME}/Applications/"orca*.AppImage; do
    if [[ -e "$candidate" ]]; then
      printf '%s' "$candidate"
      return 0
    fi
  done
  if command -v orca-ide >/dev/null 2>&1; then
    command -v orca-ide
    return 0
  fi
  if { command -v dpkg >/dev/null 2>&1 && dpkg -s orca-ide >/dev/null 2>&1; } || \
     { command -v rpm >/dev/null 2>&1 && rpm -q orca-ide >/dev/null 2>&1; }; then
    printf 'orca-ide package'
    return 0
  fi
  return 1
}

detect_environment() {
  print_step "Step 0: Detecting Operating System, Architecture & Independent Tool States"

  local os_name distro="Linux"
  os_name="$(uname -s 2>/dev/null || echo "Unknown")"
  ARCH_NAME="$(uname -m 2>/dev/null || echo "Unknown")"
  if [[ -f /etc/os-release ]]; then
    distro="$(. /etc/os-release && printf '%s' "${PRETTY_NAME:-Linux}")"
  fi

  print_info "Running script  : setup.sh (bash ${BASH_VERSION:-unknown})"
  print_info "Operating System: ${distro} (${os_name})"
  if [[ "$os_name" != "Linux" ]]; then
    print_action "Detected non-Linux platform (${os_name}). On macOS run ./setup.zsh; on Windows run setup.bat."
  fi

  case "$ARCH_NAME" in
    x86_64|amd64) ARCH_GO="amd64"; ARCH_NODE="x64" ;;
    aarch64|arm64) ARCH_GO="arm64"; ARCH_NODE="arm64" ;;
    *) print_action "Unsupported CPU architecture '${ARCH_NAME}'; standalone downloads may fail." ;;
  esac
  print_info "Architecture    : ${ARCH_NAME}"

  detect_package_manager
  print_info "Package manager : ${PKG_MANAGER:-none detected}"

  refresh_session_path

  local tool label
  for tool in git node npm "$ZEPHER_BIN_NAME" gh jq; do
    label="$(printf '%-16s' "Detect ${tool}")"
    if command -v "$tool" >/dev/null 2>&1; then
      print_info "${label}: Found ($(command -v "$tool"))"
    else
      print_info "${label}: Not found"
    fi
  done

  local snap_orca_app=""
  if snap_orca_app="$(find_orca_app_linux)"; then
    print_info "Detect Orca App : Found (${snap_orca_app})"
  else
    print_info "Detect Orca App : Not found"
  fi
  if find_orca_cli; then
    print_info "Detect Orca CLI : Found ($(command -v "$ORCA_CLI_BIN"))"
  else
    print_info "Detect Orca CLI : Not found"
  fi

  if detect_offline_kit; then
    print_info "Detect USB kit  : Found (${OFFLINE_OS_DIR}) — used for offline npm packages"
  else
    print_info "Detect USB kit  : Not found (installs will use the internet)"
  fi
}

check_network() {
  print_step "Step 1: Checking Network Connectivity"

  if [[ "${ONBOARD_SIMULATE_OFFLINE:-0}" == "1" ]]; then
    NETWORK_AVAILABLE=0
    print_action "Network check simulated as OFFLINE (ONBOARD_SIMULATE_OFFLINE=1)."
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    NETWORK_AVAILABLE=0
    print_action "'curl' is not installed; downloads are not possible. Install it with: $(pkg_install_command curl || echo 'your package manager')"
    return 0
  fi

  if curl -fsSI --max-time 8 "https://registry.npmjs.org" >/dev/null 2>&1 || \
     curl -fsSI --max-time 8 "${ORCA_WEBSITE_URL}" >/dev/null 2>&1; then
    NETWORK_AVAILABLE=1
    print_pass "Internet connection verified."
  else
    NETWORK_AVAILABLE=0
    print_action "Unable to reach external package servers (https://registry.npmjs.org)."
    print_info "Already-installed tools will still be verified; the USB kit is used where possible."
  fi
}

# -----------------------------------------------------------------------------
# 1. Git CLI (+ OpenSSH client)
# -----------------------------------------------------------------------------
check_and_setup_git() {
  print_step "Step 2: Checking Git CLI and OpenSSH client"

  local missing=()
  command -v git >/dev/null 2>&1 || missing+=("git")
  { command -v ssh >/dev/null 2>&1 && command -v ssh-keygen >/dev/null 2>&1; } || missing+=("ssh")

  if (( ${#missing[@]} == 0 )); then
    STATUS_GIT="SKIPPED"
    DETAIL_GIT="Already installed ($(git --version 2>/dev/null | head -n 1))"
    print_skip "Git and OpenSSH are already installed: $(git --version 2>/dev/null | head -n 1)"
    return 0
  fi

  local pkgs=("git")
  case "$PKG_MANAGER" in
    apt) pkgs+=("openssh-client") ;;
    dnf|zypper) pkgs+=("openssh-clients") ;;
    pacman) pkgs+=("openssh") ;;
  esac
  local install_cmd
  install_cmd="$(pkg_install_command "${pkgs[@]}" || true)"
  print_info "Missing: $(join_by ', ' "${missing[@]}")"

  if [[ "$CHECK_ONLY" == "1" ]] || [[ "$NETWORK_AVAILABLE" != "1" ]] || [[ -z "$install_cmd" ]]; then
    STATUS_GIT="FAIL"
    DETAIL_GIT="Missing ($(join_by ', ' "${missing[@]}"))"
    print_fail "Git or OpenSSH is not installed."
    add_recovery_note "Git CLI: Run '${install_cmd:-install git and openssh with your package manager}' (see ${GIT_LINUX_URL}), then re-run ./setup.sh."
    return 0
  fi

  run_with_sudo_consent "$install_cmd"
  local rc=$?
  if [[ "$rc" == "2" ]]; then
    STATUS_GIT="ACTION REQUIRED"
    DETAIL_GIT="Needs sudo: ${install_cmd}"
    print_action "Installing Git needs sudo, which --no-prompt does not use."
    add_recovery_note "Git CLI: Run '${install_cmd}', then re-run ./setup.sh."
    return 0
  fi

  if command -v git >/dev/null 2>&1 && command -v ssh >/dev/null 2>&1; then
    STATUS_GIT="PASS"
    DETAIL_GIT="Installed ($(git --version 2>/dev/null | head -n 1))"
    print_pass "Git and OpenSSH installed: $(git --version 2>/dev/null | head -n 1)"
    return 0
  fi

  STATUS_GIT="FAIL"
  DETAIL_GIT="Package installation failed"
  print_fail "Could not install Git / OpenSSH."
  add_recovery_note "Git CLI: Run '${install_cmd}' and check its error, then re-run ./setup.sh."
}

# -----------------------------------------------------------------------------
# 2. Node.js and npm (Official Verified Standalone Per-User Archive)
# -----------------------------------------------------------------------------
detect_node_version_manager() {
  local managers=()
  [[ -n "${NVM_DIR:-}" || -d "${HOME}/.nvm" ]] && managers+=("nvm")
  [[ -n "${FNM_DIR:-}" || -d "${HOME}/.fnm" || -d "${HOME}/.local/share/fnm" ]] && managers+=("fnm")
  [[ -n "${VOLTA_HOME:-}" || -d "${HOME}/.volta" ]] && managers+=("volta")
  [[ -n "${ASDF_DIR:-}" || -d "${HOME}/.asdf" ]] && managers+=("asdf")
  join_by ', ' "${managers[@]}"
}

parse_node_major() {
  local cleaned="${1#v}"
  local major="${cleaned%%.*}"
  if [[ "$major" =~ ^[0-9]+$ ]]; then printf '%s' "$major"; else printf '0'; fi
}

install_node_standalone_linux() {
  print_info "Using the official Node.js v22 LTS standalone distribution (linux-${ARCH_NODE})..."
  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/node-standalone.XXXXXX")"

  if ! curl -fsSL --retry 2 --connect-timeout 10 -o "${tmp_dir}/SHASUMS256.txt" "${NODE_DIST_BASE_URL}/SHASUMS256.txt"; then
    rm -rf "$tmp_dir"; print_fail "Failed to download the official Node.js SHASUMS256.txt manifest."; return 1
  fi

  local match_line
  match_line="$(grep -E "node-v[0-9]+\.[0-9]+\.[0-9]+-linux-${ARCH_NODE}\.tar\.xz$" "${tmp_dir}/SHASUMS256.txt" | head -n 1 || true)"
  if [[ -z "$match_line" ]]; then
    rm -rf "$tmp_dir"; print_fail "Could not locate linux-${ARCH_NODE}.tar.xz in SHASUMS256.txt."; return 1
  fi
  local expected_sha256 archive_name
  expected_sha256="$(awk '{print tolower($1)}' <<< "$match_line")"
  archive_name="$(awk '{print $2}' <<< "$match_line")"

  print_info "Downloading official standalone Node.js archive: ${NODE_DIST_BASE_URL}/${archive_name}"
  if ! curl -fL --retry 2 --connect-timeout 15 -o "${tmp_dir}/${archive_name}" "${NODE_DIST_BASE_URL}/${archive_name}"; then
    rm -rf "$tmp_dir"; print_fail "Failed to download ${archive_name}."; return 1
  fi

  local actual_sha256
  actual_sha256="$(sha256_of "${tmp_dir}/${archive_name}")"
  if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    rm -rf "$tmp_dir"
    print_fail "SHA-256 checksum mismatch for ${archive_name}! Aborting installation."
    return 1
  fi
  print_pass "Verified official SHA-256 checksum (${actual_sha256})."

  local install_root="${ONBOARD_USER_NODE_DIR:-${HOME}/.local/node-lts}"
  print_info "Installing Node.js per-user into '$(tilde "$install_root")' (no sudo required)..."
  mkdir -p "$install_root" "$USER_BIN_DIR"
  if ! tar -xJf "${tmp_dir}/${archive_name}" -C "$install_root" --strip-components=1; then
    rm -rf "$tmp_dir"; print_fail "Failed to extract ${archive_name} (is 'xz' installed?)."; return 1
  fi
  rm -rf "$tmp_dir"

  local bin_item
  for bin_item in node npm npx corepack; do
    [[ -x "${install_root}/bin/${bin_item}" ]] && ln -sf "${install_root}/bin/${bin_item}" "${USER_BIN_DIR}/${bin_item}"
  done
  [[ ":${PATH}:" != *":${install_root}/bin:"* ]] && export PATH="${PATH}:${install_root}/bin"
  [[ ":${PATH}:" != *":${USER_BIN_DIR}:"* ]] && export PATH="${PATH}:${USER_BIN_DIR}"
  NEW_TERMINAL_ADVISED=1
  return 0
}

check_and_setup_node() {
  print_step "Step 3: Checking Node.js (>= v${MIN_NODE_MAJOR} LTS) and npm"
  refresh_session_path

  local detected_managers
  detected_managers="$(detect_node_version_manager)"
  [[ -n "$detected_managers" ]] && print_info "Detected Node version manager footprint: ${detected_managers}"

  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    local node_ver npm_ver node_major
    node_ver="$(node --version 2>/dev/null | head -n 1 || true)"
    npm_ver="$(npm --version 2>/dev/null | head -n 1 || true)"
    node_major="$(parse_node_major "$node_ver")"
    if (( node_major >= MIN_NODE_MAJOR )) && [[ -n "$npm_ver" ]]; then
      STATUS_NODE="SKIPPED"
      DETAIL_NODE="Already installed (Node ${node_ver}, npm v${npm_ver})"
      print_skip "Compatible Node.js (${node_ver}) and npm (v${npm_ver}) are already installed."
      return 0
    fi
    STATUS_NODE="FAIL"
    DETAIL_NODE="Installed Node ${node_ver:-unknown} is older than required v${MIN_NODE_MAJOR}+"
    print_action "Detected Node.js ${node_ver:-unknown}; Node.js >= v${MIN_NODE_MAJOR} is required. It will not be overwritten."
    add_recovery_note "Node.js & npm: Upgrade to Node.js LTS (e.g. 'nvm install --lts && nvm use --lts'), or remove the old distro package and re-run ./setup.sh."
    return 0
  fi

  if [[ -n "$detected_managers" ]]; then
    STATUS_NODE="ACTION REQUIRED"
    DETAIL_NODE="Version manager (${detected_managers}) detected, but Node/npm not active on PATH"
    print_action "A Node version manager (${detected_managers}) exists, but 'node' is not on PATH."
    add_recovery_note "Node.js & npm: Activate your version manager and install Node LTS (e.g. 'nvm install --lts'), then re-run ./setup.sh."
    return 0
  fi

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_NODE="FAIL"
    DETAIL_NODE="Missing (not installed; ran with --check-only)"
    print_fail "Node.js and npm are not installed."
    add_recovery_note "Node.js & npm: Re-run './setup.sh' without --check-only to install Node.js LTS per-user."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_NODE="FAIL"
    DETAIL_NODE="Missing and cannot install while offline"
    print_fail "Cannot install Node.js because network connectivity is unavailable."
    add_recovery_note "Node.js & npm: Connect to the internet and re-run ./setup.sh (see ${NODE_DOWNLOAD_URL})."
    return 0
  fi

  if install_node_standalone_linux; then
    refresh_session_path
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
      STATUS_NODE="PASS"
      DETAIL_NODE="Installed per-user standalone LTS (Node $(node --version), npm v$(npm --version))"
      print_pass "Installed and verified standalone Node.js $(node --version) and npm v$(npm --version)."
      return 0
    fi
  fi

  STATUS_NODE="FAIL"
  DETAIL_NODE="Standalone installation failed"
  print_fail "Could not automatically install and verify Node.js + npm."
  add_recovery_note "Node.js & npm: Install Node.js 22 LTS from ${NODE_DOWNLOAD_URL} (or your distro's 'nodejs' package), open a new terminal, and re-run ./setup.sh."
}

# -----------------------------------------------------------------------------
# 3. Zepher CLI (zepher-cli -> zepher)
# -----------------------------------------------------------------------------
verify_zepher_binary() {
  command -v "${ZEPHER_BIN_NAME}" >/dev/null 2>&1 && \
    [[ -n "$("${ZEPHER_BIN_NAME}" --version 2>/dev/null | head -n 1)" ]] && \
    "${ZEPHER_BIN_NAME}" --help >/dev/null 2>&1
}

check_and_setup_zepher() {
  print_step "Step 4: Checking Zepher CLI (${ZEPHER_NPM_PACKAGE})"
  refresh_session_path

  if verify_zepher_binary; then
    STATUS_ZEPHER="SKIPPED"
    DETAIL_ZEPHER="Already installed (${ZEPHER_BIN_NAME} v$("${ZEPHER_BIN_NAME}" --version 2>/dev/null | head -n 1))"
    print_skip "Zepher CLI is already installed: ${ZEPHER_BIN_NAME} v$("${ZEPHER_BIN_NAME}" --version 2>/dev/null | head -n 1)"
    return 0
  fi

  if [[ "$STATUS_NODE" != "PASS" ]] && [[ "$STATUS_NODE" != "SKIPPED" ]]; then
    STATUS_ZEPHER="FAIL"
    DETAIL_ZEPHER="Blocked because Node.js (>= v${MIN_NODE_MAJOR}) & npm are not ready"
    print_fail "Cannot install ${ZEPHER_NPM_PACKAGE} until Node.js and npm are ready."
    add_recovery_note "Zepher CLI: Install Node.js first, then re-run ./setup.sh."
    return 0
  fi

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_ZEPHER="FAIL"
    DETAIL_ZEPHER="Missing (not installed; ran with --check-only)"
    print_fail "Zepher CLI (${ZEPHER_NPM_PACKAGE}) is not installed."
    add_recovery_note "Zepher CLI: Run 'npm install -g ${ZEPHER_NPM_PACKAGE}' and verify with '${ZEPHER_BIN_NAME} --version'."
    return 0
  fi

  prepare_offline_npm_cache || true
  if [[ "$NETWORK_AVAILABLE" != "1" ]] && [[ -z "$OFFLINE_NPM_CACHE" ]]; then
    STATUS_ZEPHER="FAIL"
    DETAIL_ZEPHER="Missing and cannot verify/install while offline"
    print_fail "Cannot verify or install ${ZEPHER_NPM_PACKAGE} without internet access or the USB kit."
    add_recovery_note "Zepher CLI: Connect to the internet (or plug in the USB kit) and re-run ./setup.sh."
    return 0
  fi

  # Verify exact package identity on npm (or in the USB kit's npm cache) before installing
  print_info "Verifying package identity for '${ZEPHER_NPM_PACKAGE}' against ${ZEPHER_NPM_URL}..."
  local pkg_name_remote pkg_bin_remote
  pkg_name_remote="$(npm view "${NPM_CACHE_ARGS[@]}" "${ZEPHER_NPM_PACKAGE}" name 2>/dev/null | tr -d '[:space:]' || true)"
  pkg_bin_remote="$(npm view "${NPM_CACHE_ARGS[@]}" "${ZEPHER_NPM_PACKAGE}" "bin.${ZEPHER_BIN_NAME}" 2>/dev/null | tr -d '[:space:]' || true)"
  if [[ "$pkg_name_remote" != "${ZEPHER_NPM_PACKAGE}" ]] || [[ -z "$pkg_bin_remote" ]]; then
    STATUS_ZEPHER="FAIL"
    DETAIL_ZEPHER="Could not verify '${ZEPHER_NPM_PACKAGE}' metadata on npm registry"
    print_fail "Could not verify package identity for '${ZEPHER_NPM_PACKAGE}'; not installing an unverified package."
    add_recovery_note "Zepher CLI: Check your npm registry connection and inspect ${ZEPHER_NPM_URL}, then re-run ./setup.sh."
    return 0
  fi
  print_info "Verified package '${pkg_name_remote}' (executable '${ZEPHER_BIN_NAME}' -> '${pkg_bin_remote}')."

  npm_global_install "${ZEPHER_NPM_PACKAGE}"
  local install_rc=$?
  refresh_session_path

  if [[ "$install_rc" -eq 0 ]] && verify_zepher_binary; then
    STATUS_ZEPHER="PASS"
    DETAIL_ZEPHER="Installed (${ZEPHER_BIN_NAME} v$("${ZEPHER_BIN_NAME}" --version 2>/dev/null | head -n 1))"
    print_pass "Zepher CLI installed and verified."
    return 0
  fi

  STATUS_ZEPHER="FAIL"
  DETAIL_ZEPHER="Installation or post-install verification failed"
  print_fail "Failed to install or verify '${ZEPHER_NPM_PACKAGE}'."
  add_recovery_note "Zepher CLI: Run 'npm install -g ${ZEPHER_NPM_PACKAGE}' manually and verify with '${ZEPHER_BIN_NAME} --version' (see ${ZEPHER_NPM_URL})."
}

# -----------------------------------------------------------------------------
# 4. Orca Desktop Application (.deb / .rpm via the distro, or per-user AppImage)
# -----------------------------------------------------------------------------
download_orca_artifact() {
  # Downloads one Orca release file and verifies its SHA-512 against latest-linux*.yml
  local file_name="$1" dest_dir="$2"
  local yml_name="latest-linux.yml"
  [[ "$ARCH_GO" == "arm64" ]] && yml_name="latest-linux-arm64.yml"

  if ! curl -fsSL --retry 2 --connect-timeout 10 -o "${dest_dir}/${yml_name}" "${ORCA_RELEASES_DOWNLOAD_URL}/${yml_name}"; then
    print_fail "Failed to download Orca release metadata (${yml_name})."
    return 1
  fi
  local expected_sha512
  expected_sha512="$(awk -v f="$file_name" '
    $1 == "-" && $2 == "url:" { cur = $3; next }
    $1 == "url:" { cur = $2; next }
    $1 == "sha512:" && cur == f { print $2; exit }' "${dest_dir}/${yml_name}")"
  if [[ -z "$expected_sha512" ]]; then
    print_fail "Could not find ${file_name} in Orca's ${yml_name}."
    return 1
  fi

  print_info "Downloading official Orca installer: ${ORCA_RELEASES_DOWNLOAD_URL}/${file_name}"
  if ! curl -fL --retry 2 --connect-timeout 15 -o "${dest_dir}/${file_name}" "${ORCA_RELEASES_DOWNLOAD_URL}/${file_name}"; then
    print_fail "Failed to download ${file_name}."
    return 1
  fi

  local actual_sha512
  actual_sha512="$(sha512_b64_of "${dest_dir}/${file_name}" || true)"
  if [[ -z "$actual_sha512" ]] || [[ "$actual_sha512" != "$expected_sha512" ]]; then
    print_fail "SHA-512 checksum mismatch for ${file_name}! Refusing to install."
    return 1
  fi
  print_pass "Verified official SHA-512 checksum for ${file_name}."
  return 0
}

orca_release_file_name() {
  # Prints the Orca release file for this distro: deb, rpm, or AppImage
  local version="$1" kind="$2"
  case "$kind" in
    deb) [[ "$ARCH_GO" == "arm64" ]] && printf 'orca-ide_%s_arm64.deb' "$version" || printf 'orca-ide_%s_amd64.deb' "$version" ;;
    rpm) [[ "$ARCH_GO" == "arm64" ]] && printf 'orca-ide-%s.aarch64.rpm' "$version" || printf 'orca-ide-%s.x86_64.rpm' "$version" ;;
    appimage) [[ "$ARCH_GO" == "arm64" ]] && printf 'orca-linux-arm64.AppImage' || printf 'orca-linux.AppImage' ;;
  esac
}

install_orca_appimage() {
  local tmp_dir="$1"
  local file_name
  file_name="$(orca_release_file_name "" appimage)"
  download_orca_artifact "$file_name" "$tmp_dir" || return 1

  local apps_dir="${HOME}/Applications"
  mkdir -p "$apps_dir" "$USER_BIN_DIR" "${HOME}/.local/share/applications"
  install -m 755 "${tmp_dir}/${file_name}" "${apps_dir}/Orca.AppImage" || return 1
  cat > "${HOME}/.local/share/applications/orca-ide.desktop" <<EOF
[Desktop Entry]
Name=Orca
Comment=Agent Development Environment
Exec=${apps_dir}/Orca.AppImage %U
Terminal=false
Type=Application
Categories=Development;
EOF
  print_info "Installed Orca to $(tilde "${apps_dir}/Orca.AppImage") and added it to your app menu."

  # AppImages need FUSE 2 at runtime; most new distros ship only FUSE 3
  if ! ldconfig -p 2>/dev/null | grep -q 'libfuse.so.2'; then
    local fuse_pkg="libfuse2"
    [[ "$PKG_MANAGER" == "dnf" ]] && fuse_pkg="fuse-libs"
    [[ "$PKG_MANAGER" == "zypper" ]] && fuse_pkg="libfuse2"
    [[ "$PKG_MANAGER" == "pacman" ]] && fuse_pkg="fuse2"
    if [[ "$PKG_MANAGER" == "apt" ]] && apt-cache show libfuse2t64 >/dev/null 2>&1; then fuse_pkg="libfuse2t64"; fi
    add_recovery_note "Orca Desktop App: AppImages need FUSE 2. Run '$(pkg_install_command "$fuse_pkg" || echo "install libfuse2")' if Orca does not start."
  fi
  return 0
}

check_and_setup_orca_app() {
  print_step "Step 5: Checking Orca Desktop Application"

  local existing_app=""
  if existing_app="$(find_orca_app_linux)"; then
    STATUS_ORCA_APP="SKIPPED"
    DETAIL_ORCA_APP="Already installed (${existing_app})"
    print_skip "Orca desktop application is already installed at: ${existing_app}"
    return 0
  fi

  print_info "Orca was not found (no orca-ide package, ~/Applications/Orca.AppImage, or /opt/Orca)."

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_ORCA_APP="ACTION REQUIRED"
    DETAIL_ORCA_APP="Not installed (ran with --check-only)"
    print_action "Orca desktop application is not installed."
    add_recovery_note "Orca Desktop App: Re-run './setup.sh' without --check-only, or install the .deb/.rpm/AppImage from ${ORCA_INSTALL_DOCS_URL}."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_ORCA_APP="FAIL"
    DETAIL_ORCA_APP="Missing and cannot download while offline"
    print_fail "Cannot download Orca because network connectivity is unavailable."
    add_recovery_note "Orca Desktop App: Connect to the internet and re-run ./setup.sh, or install from ${ORCA_INSTALL_DOCS_URL}."
    return 0
  fi

  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/orca-linux.XXXXXX")"

  # Route A: the distro package (.deb / .rpm) through apt/dnf/zypper, so dependencies resolve
  local kind=""
  case "$PKG_MANAGER" in
    apt) kind="deb" ;;
    dnf|zypper) kind="rpm" ;;
  esac
  if [[ -n "$kind" ]] && [[ "$NO_PROMPT" != "1" ]] && [[ -t 0 ]]; then
    local orca_version
    orca_version="$(resolve_latest_tag "${ORCA_RELEASES_DOWNLOAD_URL%/download}")"
    orca_version="${orca_version#v}"
    if [[ "$orca_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
      local file_name
      file_name="$(orca_release_file_name "$orca_version" "$kind")"
      if download_orca_artifact "$file_name" "$tmp_dir"; then
        chmod 644 "${tmp_dir}/${file_name}"
        chmod 755 "$tmp_dir"
        if run_with_sudo_consent "$(pkg_install_command "${tmp_dir}/${file_name}")"; then
          local pkg_app=""
          if pkg_app="$(find_orca_app_linux)"; then
            rm -rf "$tmp_dir"
            STATUS_ORCA_APP="PASS"
            DETAIL_ORCA_APP="Installed ${kind} package (${pkg_app})"
            print_pass "Orca installed from the official .${kind} package: ${pkg_app}"
            return 0
          fi
        fi
        print_info "The .${kind} package did not install cleanly; falling back to the per-user AppImage..."
      fi
    else
      print_info "Could not resolve the latest Orca version; using the per-user AppImage instead."
    fi
  fi

  # Route B: per-user AppImage (no sudo)
  if install_orca_appimage "$tmp_dir"; then
    rm -rf "$tmp_dir"
    STATUS_ORCA_APP="PASS"
    DETAIL_ORCA_APP="Installed per-user AppImage (~/Applications/Orca.AppImage)"
    print_pass "Orca AppImage installed and verified."
    return 0
  fi

  rm -rf "$tmp_dir"
  STATUS_ORCA_APP="ACTION REQUIRED"
  DETAIL_ORCA_APP="Manual download required (${ORCA_INSTALL_DOCS_URL})"
  print_action "Could not complete the automated Orca installation."
  add_recovery_note "Orca Desktop App: Download the .deb, .rpm or AppImage from ${ORCA_INSTALL_DOCS_URL}, install it, and re-run ./setup.sh."
}

# -----------------------------------------------------------------------------
# 5. Orca CLI (orca-ide on Linux)
# -----------------------------------------------------------------------------
print_orca_cli_registration_guide() {
  print_info "How to enable and register the Orca CLI:"
  print_info "  1. Open the Orca desktop application."
  print_info "  2. In Orca, go to: Settings -> General -> Orca CLI"
  print_info "  3. Click to register/enable the command on your PATH (on Linux it is called 'orca-ide')."
  print_info "  4. Open a NEW terminal window so the updated PATH takes effect."
  print_info "  5. Verify with: orca-ide status --json"
  print_info "  Official CLI documentation: ${ORCA_CLI_DOCS_URL}"
}

check_and_setup_orca_cli() {
  print_step "Step 6: Checking Orca CLI ('orca-ide')"
  refresh_session_path

  if ! find_orca_cli; then
    STATUS_ORCA_CLI="ACTION REQUIRED"
    if [[ "$STATUS_ORCA_APP" == "PASS" ]] || [[ "$STATUS_ORCA_APP" == "SKIPPED" ]]; then
      DETAIL_ORCA_CLI="Orca is installed, but its CLI is not yet registered on PATH"
      print_action "Orca is installed, but the 'orca-ide' CLI is not yet on your PATH."
    else
      DETAIL_ORCA_CLI="Install Orca first, then register CLI in Settings -> General -> Orca CLI"
      print_action "The Orca CLI is not available (Orca must be installed first)."
    fi
    print_orca_cli_registration_guide
    add_recovery_note "Orca CLI: Open Orca -> Settings -> General -> Orca CLI to register 'orca-ide', open a new terminal, and run 'orca-ide status --json'."
    return 0
  fi

  local orca_bin_path
  orca_bin_path="$(command -v "$ORCA_CLI_BIN")"
  print_info "Found '${ORCA_CLI_BIN}' on PATH: ${orca_bin_path}"

  if "$ORCA_CLI_BIN" status --json >/dev/null 2>&1; then
    STATUS_ORCA_CLI="SKIPPED"
    DETAIL_ORCA_CLI="Registered on PATH and verified ('${ORCA_CLI_BIN} status --json' succeeded)"
    print_skip "Orca CLI is registered and verified via '${ORCA_CLI_BIN} status --json'."
    return 0
  fi

  if "$ORCA_CLI_BIN" --help >/dev/null 2>&1 || "$ORCA_CLI_BIN" --version >/dev/null 2>&1; then
    STATUS_ORCA_CLI="ACTION REQUIRED"
    DETAIL_ORCA_CLI="CLI is on PATH, but '${ORCA_CLI_BIN} status --json' requires Orca to be running"
    print_action "'${ORCA_CLI_BIN}' is on PATH, but could not reach a running Orca session."
    add_recovery_note "Orca CLI: Launch Orca so '${ORCA_CLI_BIN} status --json' can connect to it."
    return 0
  fi

  STATUS_ORCA_CLI="FAIL"
  DETAIL_ORCA_CLI="Found '${orca_bin_path}', but execution failed"
  print_fail "'${ORCA_CLI_BIN}' was found at ${orca_bin_path}, but failed verification."
  print_orca_cli_registration_guide
  add_recovery_note "Orca CLI: Re-register the CLI in Orca under Settings -> General -> Orca CLI (see ${ORCA_CLI_DOCS_URL})."
}

# -----------------------------------------------------------------------------
# 6. GitHub CLI (Official Verified Standalone Per-User Archive)
# -----------------------------------------------------------------------------
verify_gh_binary() {
  command -v gh >/dev/null 2>&1 && gh --version >/dev/null 2>&1
}

install_gh_standalone_linux() {
  print_info "Resolving the latest official GitHub CLI release from: ${GH_RELEASES_LATEST_URL}"
  local gh_tag gh_ver
  gh_tag="$(resolve_latest_tag "$GH_RELEASES_LATEST_URL")"
  gh_ver="${gh_tag#v}"
  if [[ ! "$gh_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_fail "Could not determine the latest GitHub CLI version."
    return 1
  fi

  local base_url="${GH_RELEASES_DOWNLOAD_BASE_URL}/v${gh_ver}"
  local archive_name="gh_${gh_ver}_linux_${ARCH_GO}.tar.gz"
  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/gh-standalone.XXXXXX")"

  if ! curl -fsSL --retry 2 --connect-timeout 10 -o "${tmp_dir}/checksums.txt" "${base_url}/gh_${gh_ver}_checksums.txt"; then
    rm -rf "$tmp_dir"; print_fail "Failed to download the GitHub CLI checksum manifest."; return 1
  fi
  local expected_sha256
  expected_sha256="$(awk -v f="$archive_name" '$2 == f {print tolower($1)}' "${tmp_dir}/checksums.txt" | head -n 1)"
  if [[ -z "$expected_sha256" ]]; then
    rm -rf "$tmp_dir"; print_fail "Could not locate ${archive_name} in the checksum manifest."; return 1
  fi

  print_info "Downloading official GitHub CLI archive: ${base_url}/${archive_name}"
  if ! curl -fL --retry 2 --connect-timeout 15 -o "${tmp_dir}/${archive_name}" "${base_url}/${archive_name}"; then
    rm -rf "$tmp_dir"; print_fail "Failed to download ${archive_name}."; return 1
  fi
  local actual_sha256
  actual_sha256="$(sha256_of "${tmp_dir}/${archive_name}")"
  if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    rm -rf "$tmp_dir"; print_fail "SHA-256 checksum mismatch for ${archive_name}! Aborting installation."; return 1
  fi
  print_pass "Verified official SHA-256 checksum (${actual_sha256})."

  local install_root="${ONBOARD_USER_GH_DIR:-${HOME}/.local/gh}"
  print_info "Installing GitHub CLI per-user into '$(tilde "$install_root")' (no sudo required)..."
  mkdir -p "$install_root" "$USER_BIN_DIR"
  if ! tar -xzf "${tmp_dir}/${archive_name}" -C "$install_root" --strip-components=1; then
    rm -rf "$tmp_dir"; print_fail "Failed to extract ${archive_name}."; return 1
  fi
  rm -rf "$tmp_dir"
  ln -sf "${install_root}/bin/gh" "${USER_BIN_DIR}/gh"
  [[ ":${PATH}:" != *":${USER_BIN_DIR}:"* ]] && export PATH="${PATH}:${USER_BIN_DIR}"
  NEW_TERMINAL_ADVISED=1
  return 0
}

check_and_setup_gh() {
  print_step "Step 7: Checking GitHub CLI ('gh')"
  refresh_session_path

  if verify_gh_binary; then
    STATUS_GH="SKIPPED"
    DETAIL_GH="Already installed ($(gh --version 2>/dev/null | head -n 1))"
    print_skip "GitHub CLI is already installed: $(gh --version 2>/dev/null | head -n 1)"
    return 0
  fi

  print_info "GitHub CLI ('gh') was not found on PATH."

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_GH="FAIL"
    DETAIL_GH="Missing (not installed; ran with --check-only)"
    print_fail "GitHub CLI is not installed."
    add_recovery_note "GitHub CLI: Re-run './setup.sh' without --check-only, or install from ${GH_CLI_URL}."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_GH="FAIL"
    DETAIL_GH="Missing and cannot install while offline"
    print_fail "Cannot install GitHub CLI because network connectivity is unavailable."
    add_recovery_note "GitHub CLI: Connect to the internet and re-run ./setup.sh."
    return 0
  fi

  if install_gh_standalone_linux && verify_gh_binary; then
    STATUS_GH="PASS"
    DETAIL_GH="Installed per-user standalone ($(gh --version 2>/dev/null | head -n 1))"
    print_pass "GitHub CLI installed and verified: $(gh --version 2>/dev/null | head -n 1)"
    return 0
  fi

  STATUS_GH="FAIL"
  DETAIL_GH="Automatic installation failed"
  print_fail "Could not automatically install and verify GitHub CLI."
  add_recovery_note "GitHub CLI: Install it from ${GH_CLI_URL} (Linux packages for apt/dnf/zypper), open a new terminal, and re-run ./setup.sh."
}

# -----------------------------------------------------------------------------
# 7. GitHub Authentication over SSH (gh login + SSH key + git identity)
# -----------------------------------------------------------------------------
github_ssh_probe() {
  # Prints one of: ok:<login> | denied | hostkey | unreachable
  # 'ssh -T git@github.com' exits 1 even on success, so classify by its message.
  local out
  out="$(ssh -T -o ConnectTimeout=10 -o StrictHostKeyChecking=yes "$@" git@github.com 2>&1 </dev/null || true)"
  if [[ "$out" == *"successfully authenticated"* ]]; then
    local login="${out#*Hi }"
    printf 'ok:%s' "${login%%\!*}"
  elif [[ "$out" == *"Host key verification failed"* ]] || [[ "$out" == *"REMOTE HOST IDENTIFICATION HAS CHANGED"* ]]; then
    printf 'hostkey'
  elif [[ "$out" == *"Permission denied"* ]]; then
    printf 'denied'
  else
    printf 'unreachable'
  fi
}

ensure_github_known_hosts() {
  # Trust GitHub's host keys as published by the GitHub API over authenticated HTTPS,
  # instead of accepting whatever key answers on first connect.
  local force="$1"
  local known_hosts="${HOME}/.ssh/known_hosts"
  local keys
  keys="$(gh api meta --jq '.ssh_keys[]' 2>/dev/null || true)"
  if [[ -z "$keys" ]]; then
    print_info "Could not fetch GitHub's published SSH host keys ('gh api meta')."
    return 1
  fi

  mkdir -p "${HOME}/.ssh"
  chmod 700 "${HOME}/.ssh" 2>/dev/null || true
  touch "$known_hosts"

  local host key
  for host in "github.com" "[ssh.github.com]:443"; do
    if [[ "$force" == "1" ]]; then
      ssh-keygen -R "$host" -f "$known_hosts" >/dev/null 2>&1 || true
    fi
    if ! ssh-keygen -F "$host" -f "$known_hosts" >/dev/null 2>&1; then
      while IFS= read -r key; do
        [[ -n "$key" ]] && printf '%s %s\n' "$host" "$key" >> "$known_hosts"
      done <<< "$keys"
      print_info "Added GitHub's official SSH host keys for ${host} to ~/.ssh/known_hosts."
    fi
  done
  return 0
}

write_github_ssh_config() {
  # Prepends one marked 'Host github.com' block (replacing an older copy of it) so it
  # takes precedence over any later github.com entries in ~/.ssh/config.
  local use_port_443="$1"
  local ssh_config="${HOME}/.ssh/config"
  local tmp_config
  tmp_config="$(mktemp "${HOME}/.ssh/config.XXXXXX")" || return 1

  {
    printf '%s\n' "${SSH_CONFIG_BLOCK_BEGIN}" "Host github.com"
    if [[ "$use_port_443" == "1" ]]; then
      printf '%s\n' "  HostName ssh.github.com" "  Port 443"
    fi
    printf '%s\n' "  User git" "  IdentityFile $(tilde "$SSH_KEY_PATH")" "  AddKeysToAgent yes" "${SSH_CONFIG_BLOCK_END}" ""
    if [[ -f "$ssh_config" ]]; then
      awk -v b="${SSH_CONFIG_BLOCK_BEGIN}" -v e="${SSH_CONFIG_BLOCK_END}" \
        '$0 == b {skip = 1; next} $0 == e {skip = 0; after = 1; next} after && $0 == "" {after = 0; next} {after = 0} !skip' "$ssh_config"
    fi
  } > "$tmp_config"

  if [[ -f "$ssh_config" ]]; then
    cp "$ssh_config" "${ssh_config}.bak-beyond-the-prompt"
    print_info "Backed up ~/.ssh/config to ~/.ssh/config.bak-beyond-the-prompt"
  fi
  chmod 600 "$tmp_config"
  mv "$tmp_config" "$ssh_config"
  print_info "Updated the managed 'Host github.com' block at the top of ~/.ssh/config."
}

configure_git_identity_from_github() {
  # Only fills in a missing global user.name / user.email; never replaces existing values.
  local cur_name cur_email
  cur_name="$(git config --global user.name 2>/dev/null || true)"
  cur_email="$(git config --global user.email 2>/dev/null || true)"
  if [[ -n "$cur_name" ]] && [[ -n "$cur_email" ]]; then
    print_info "Git identity already set: ${cur_name} <${cur_email}>"
    return 0
  fi

  local gh_id gh_login gh_name
  gh_id="$(gh api user --jq .id 2>/dev/null || true)"
  gh_login="$(gh api user --jq .login 2>/dev/null || true)"
  gh_name="$(gh api user --jq '.name // ""' 2>/dev/null || true)"
  if [[ -z "$gh_id" ]] || [[ -z "$gh_login" ]]; then
    print_info "Could not read your GitHub profile to set the Git identity; set it with 'git config --global user.name/user.email'."
    return 0
  fi

  if [[ -z "$cur_name" ]]; then
    git config --global user.name "${gh_name:-$gh_login}"
    print_info "Set Git user.name to '${gh_name:-$gh_login}'."
  fi
  if [[ -z "$cur_email" ]]; then
    git config --global user.email "${gh_id}+${gh_login}@users.noreply.github.com"
    print_info "Set Git user.email to your GitHub no-reply address (${gh_id}+${gh_login}@users.noreply.github.com)."
  fi
}

check_and_setup_github_ssh() {
  print_step "Step 8: Checking GitHub authentication over SSH (gh login + SSH key)"

  if [[ "$STATUS_GH" != "PASS" ]] && [[ "$STATUS_GH" != "SKIPPED" ]]; then
    STATUS_GH_SSH="FAIL"
    DETAIL_GH_SSH="Blocked because GitHub CLI is not ready"
    print_fail "Cannot configure GitHub authentication until the GitHub CLI ('gh') is installed."
    add_recovery_note "GitHub over SSH: Install GitHub CLI first (${GH_CLI_URL}), then re-run ./setup.sh."
    return 0
  fi

  if ! command -v ssh >/dev/null 2>&1 || ! command -v ssh-keygen >/dev/null 2>&1; then
    STATUS_GH_SSH="FAIL"
    DETAIL_GH_SSH="OpenSSH ('ssh', 'ssh-keygen') not found"
    print_fail "OpenSSH client tools were not found on PATH."
    add_recovery_note "GitHub over SSH: Install the OpenSSH client ($(pkg_install_command openssh-client || echo 'openssh')), then re-run ./setup.sh."
    return 0
  fi

  # Current state
  local auth_out="" gh_logged_in=0 gh_protocol="" probe=""
  if auth_out="$(gh auth status --hostname github.com 2>&1)"; then
    gh_logged_in=1
  fi
  gh_protocol="$(gh config get git_protocol --host github.com 2>/dev/null || true)"
  probe="$(github_ssh_probe -o BatchMode=yes)"

  if (( gh_logged_in )) && [[ "$auth_out" == *"'project'"* ]] && [[ "$gh_protocol" == "ssh" ]] && [[ "$probe" == ok:* ]]; then
    STATUS_GH_SSH="SKIPPED"
    DETAIL_GH_SSH="Already set up (gh + SSH as ${probe#ok:})"
    print_skip "gh is logged in, uses SSH for git, and 'ssh -T git@github.com' authenticates as ${probe#ok:}."
    [[ "$CHECK_ONLY" != "1" ]] && configure_git_identity_from_github
    return 0
  fi

  local missing=""
  (( gh_logged_in )) || missing+="gh not logged in; "
  if (( gh_logged_in )) && [[ "$auth_out" != *"'project'"* ]]; then missing+="token lacks 'project' scope; "; fi
  [[ "$gh_protocol" == "ssh" ]] || missing+="gh git protocol is '${gh_protocol:-https}'; "
  [[ "$probe" == ok:* ]] || missing+="SSH to GitHub: ${probe}; "
  print_info "Current state: ${missing%; }"

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_GH_SSH="FAIL"
    DETAIL_GH_SSH="Not configured (${missing%; })"
    print_fail "GitHub authentication over SSH is not fully configured."
    add_recovery_note "GitHub over SSH: Re-run './setup.sh' without --check-only to sign in and set up your SSH key."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_GH_SSH="FAIL"
    DETAIL_GH_SSH="Cannot sign in to GitHub while offline"
    print_fail "GitHub sign-in needs internet access."
    add_recovery_note "GitHub over SSH: Connect to the internet and re-run ./setup.sh."
    return 0
  fi

  if [[ -n "${GH_TOKEN:-}" ]] || [[ -n "${GITHUB_TOKEN:-}" ]]; then
    STATUS_GH_SSH="ACTION REQUIRED"
    DETAIL_GH_SSH="GH_TOKEN / GITHUB_TOKEN is set and overrides gh login"
    print_action "A GH_TOKEN or GITHUB_TOKEN environment variable is set; gh uses it instead of a normal login."
    add_recovery_note "GitHub over SSH: Run 'unset GH_TOKEN GITHUB_TOKEN' (and remove them from your shell profile), then re-run ./setup.sh."
    return 0
  fi

  if [[ "$NO_PROMPT" == "1" ]] || [[ ! -t 0 ]]; then
    STATUS_GH_SSH="ACTION REQUIRED"
    DETAIL_GH_SSH="Interactive browser sign-in required"
    print_action "GitHub sign-in needs an interactive terminal and a browser."
    add_recovery_note "GitHub over SSH: Re-run './setup.sh' in a normal terminal (without --no-prompt) to sign in to GitHub."
    return 0
  fi

  # 1. Sign in to gh (browser device flow), or add missing scopes to an existing login
  local needed_scopes="project"
  [[ "$probe" == ok:* ]] || needed_scopes="${GH_AUTH_SCOPES}"
  if (( ! gh_logged_in )); then
    print_info "Signing in to GitHub. Copy the one-time code printed below, press Enter, and approve it in your browser."
    if ! gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key --scopes "${GH_AUTH_SCOPES}"; then
      STATUS_GH_SSH="FAIL"
      DETAIL_GH_SSH="GitHub sign-in did not complete"
      print_fail "'gh auth login' did not complete."
      add_recovery_note "GitHub over SSH: Run 'gh auth login --git-protocol ssh --web --scopes ${GH_AUTH_SCOPES}' manually (or enter the code at https://github.com/login/device), then re-run ./setup.sh."
      return 0
    fi
  else
    local scope_missing=0 scope
    IFS=',' read -r -a scope_list <<< "$needed_scopes"
    for scope in "${scope_list[@]}"; do
      [[ "$auth_out" == *"'${scope}'"* ]] || scope_missing=1
    done
    if (( scope_missing )); then
      print_info "Adding token scopes '${needed_scopes}' to your existing gh login (approve it in your browser)..."
      if ! gh auth refresh --hostname github.com --scopes "${needed_scopes}"; then
        STATUS_GH_SSH="FAIL"
        DETAIL_GH_SSH="Could not add required token scopes (${needed_scopes})"
        print_fail "'gh auth refresh' did not complete."
        add_recovery_note "GitHub over SSH: Run 'gh auth refresh --scopes ${needed_scopes}', then re-run ./setup.sh."
        return 0
      fi
    fi
  fi
  gh config set git_protocol ssh --host github.com >/dev/null 2>&1 || true

  local gh_login
  gh_login="$(gh api user --jq .login 2>/dev/null || true)"
  print_pass "gh is signed in${gh_login:+ as ${gh_login}} and set to use SSH for git."

  # 2. SSH key (an existing key is never overwritten)
  local pub_path="${SSH_KEY_PATH}.pub"
  if [[ ! -f "$SSH_KEY_PATH" ]]; then
    mkdir -p "$(dirname "$SSH_KEY_PATH")"
    chmod 700 "$(dirname "$SSH_KEY_PATH")" 2>/dev/null || true
    print_info "Creating a new ed25519 SSH key at $(tilde "$SSH_KEY_PATH")."
    print_info "Tip: a passphrase is optional. If you set one, your desktop's ssh-agent/keyring will remember it."
    if ! ssh-keygen -t ed25519 -C "${gh_login:-github}@beyond-the-prompt" -f "$SSH_KEY_PATH"; then
      STATUS_GH_SSH="FAIL"
      DETAIL_GH_SSH="SSH key generation failed"
      print_fail "ssh-keygen did not create a key."
      add_recovery_note "GitHub over SSH: Run 'ssh-keygen -t ed25519' manually, then re-run ./setup.sh."
      return 0
    fi
  else
    print_info "Using existing SSH key: $(tilde "$SSH_KEY_PATH")"
    if [[ ! -f "$pub_path" ]]; then
      ssh-keygen -y -f "$SSH_KEY_PATH" > "$pub_path" 2>/dev/null || true
    fi
  fi

  if [[ ! -s "$pub_path" ]]; then
    STATUS_GH_SSH="FAIL"
    DETAIL_GH_SSH="Public key $(tilde "$pub_path") is missing"
    print_fail "Could not find or recreate the public key ${pub_path}."
    add_recovery_note "GitHub over SSH: Recreate it with 'ssh-keygen -y -f ${SSH_KEY_PATH} > ${pub_path}', then re-run ./setup.sh."
    return 0
  fi

  # Keep earlier choices: a previous run may have switched github.com to port 443
  local use_port_443=0
  if [[ -f "${HOME}/.ssh/config" ]] && \
     awk -v b="${SSH_CONFIG_BLOCK_BEGIN}" -v e="${SSH_CONFIG_BLOCK_END}" \
       '$0 == b {in_block = 1} $0 == e {in_block = 0} in_block && /Port 443/ {found = 1} END {exit !found}' "${HOME}/.ssh/config"; then
    use_port_443=1
  fi

  local agent_failed=0
  if ! ssh-keygen -y -P "" -f "$SSH_KEY_PATH" >/dev/null 2>&1; then
    if [[ -n "${SSH_AUTH_SOCK:-}" ]]; then
      print_info "Your key has a passphrase; adding it to your ssh-agent so git does not ask every time..."
      ssh-add "$SSH_KEY_PATH" || agent_failed=1
      write_github_ssh_config "$use_port_443"
    else
      agent_failed=1
    fi
  fi

  # 3. Trust GitHub's host keys, then find a working route (port 22, else 443)
  ensure_github_known_hosts 0
  probe="$(github_ssh_probe -o BatchMode=yes)"
  if [[ "$probe" == "hostkey" ]]; then
    print_info "Your known_hosts has an outdated GitHub host key; replacing it with GitHub's current keys..."
    ensure_github_known_hosts 1
    probe="$(github_ssh_probe -o BatchMode=yes)"
  fi
  if [[ "$probe" == "unreachable" ]]; then
    local probe_443
    probe_443="$(github_ssh_probe -o BatchMode=yes -o HostName=ssh.github.com -o Port=443)"
    if [[ "$probe_443" != "unreachable" ]]; then
      print_info "SSH port 22 is blocked on this network; switching github.com to ssh.github.com port 443."
      use_port_443=1
      write_github_ssh_config "$use_port_443"
      probe="$(github_ssh_probe -o BatchMode=yes)"
    fi
  fi

  # 4. Upload the public key if GitHub does not recognise it yet
  if [[ "$probe" == "denied" ]]; then
    local key_title="beyond-the-prompt $(hostname 2>/dev/null || echo linux)"
    print_info "Uploading $(tilde "$pub_path") to your GitHub account as '${key_title}'..."
    gh ssh-key add "$pub_path" --title "$key_title" --type authentication || true
    probe="$(github_ssh_probe -o BatchMode=yes)"
  fi

  if [[ "$probe" == ok:* ]]; then
    local ssh_login="${probe#ok:}"
    if [[ -n "$gh_login" ]] && [[ "$ssh_login" != "$gh_login" ]]; then
      STATUS_GH_SSH="ACTION REQUIRED"
      DETAIL_GH_SSH="SSH key belongs to '${ssh_login}', but gh is signed in as '${gh_login}'"
      print_action "Your SSH key authenticates as '${ssh_login}', but gh is signed in as '${gh_login}'."
      add_recovery_note "GitHub over SSH: Use one GitHub account for both. Either 'gh auth login' as ${ssh_login}, or set ONBOARD_SSH_KEY_PATH to a new key path (e.g. ~/.ssh/id_ed25519_${gh_login}) and re-run ./setup.sh."
      return 0
    fi
    STATUS_GH_SSH="PASS"
    DETAIL_GH_SSH="Signed in as ${ssh_login}; git uses SSH"
    [[ "$use_port_443" == "1" ]] && DETAIL_GH_SSH+=" (port 443)"
    print_pass "'ssh -T git@github.com' authenticates as ${ssh_login}."
    configure_git_identity_from_github
    return 0
  fi

  if (( agent_failed )) && [[ "$probe" == "denied" ]]; then
    STATUS_GH_SSH="ACTION REQUIRED"
    DETAIL_GH_SSH="Key has a passphrase and no ssh-agent holds it"
    print_action "Your SSH key has a passphrase, but no ssh-agent is holding it."
    add_recovery_note "GitHub over SSH: Run 'eval \"\$(ssh-agent -s)\" && ssh-add ${SSH_KEY_PATH}', then check with 'ssh -T git@github.com' (it will ask for your passphrase)."
    return 0
  fi

  STATUS_GH_SSH="FAIL"
  case "$probe" in
    unreachable)
      DETAIL_GH_SSH="GitHub SSH unreachable on ports 22 and 443"
      print_fail "Could not reach GitHub over SSH on port 22 or 443 (network or firewall)."
      add_recovery_note "GitHub over SSH: This network blocks SSH. Try another network or hotspot, then re-run ./setup.sh (see ${GH_SSH_DOCS_URL})."
      ;;
    hostkey)
      DETAIL_GH_SSH="GitHub host key could not be verified"
      print_fail "GitHub's SSH host key could not be verified."
      add_recovery_note "GitHub over SSH: Run 'ssh-keygen -R github.com', then re-run ./setup.sh."
      ;;
    *)
      DETAIL_GH_SSH="GitHub rejected the SSH key"
      print_fail "GitHub did not accept $(tilde "$pub_path") (upload may have failed, or the key is on another account)."
      add_recovery_note "GitHub over SSH: Run 'gh ssh-key add ${pub_path}' and check https://github.com/settings/keys, then re-run ./setup.sh."
      ;;
  esac
}

# -----------------------------------------------------------------------------
# 8. AI Coding Agent CLIs (Claude Code, OpenCode) via npm
# -----------------------------------------------------------------------------
agent_package_for() {
  case "$1" in
    claude) printf '%s' "${CLAUDE_CODE_NPM_PACKAGE}" ;;
    opencode) printf '%s' "${OPENCODE_NPM_PACKAGE}" ;;
    *) return 1 ;;
  esac
}

verify_agent_binary() {
  command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1
}

add_agent_login_note() {
  # Signing in to an agent happens in the browser with the participant's own account.
  local steps=() agent
  for agent in "$@"; do
    case "$agent" in
      claude) steps+=("run 'claude' once and sign in with your Claude account") ;;
      opencode) steps+=("run 'opencode auth login' (or use its free models)") ;;
    esac
  done
  if (( ${#steps[@]} > 0 )); then
    add_recovery_note "Sign in to your AI agent before the event: $(join_by '; ' "${steps[@]}")."
  fi
}

check_and_setup_agents() {
  print_step "Step 9: Checking AI coding agent CLIs (${AGENTS_TO_INSTALL})"

  if [[ "$AGENTS_TO_INSTALL" == "none" ]]; then
    STATUS_AGENTS="SKIPPED"
    DETAIL_AGENTS="Not requested (--agents none)"
    print_skip "Agent installation skipped (--agents none)."
    return 0
  fi

  refresh_session_path

  local wanted=() missing_pkgs=() found_notes=() agent pkg
  IFS=',' read -r -a requested <<< "$AGENTS_TO_INSTALL"
  for agent in "${requested[@]}"; do
    if ! pkg="$(agent_package_for "$agent")"; then
      print_action "Unknown agent '${agent}' ignored (use claude, opencode, or none)."
      continue
    fi
    wanted+=("$agent")
    if verify_agent_binary "$agent"; then
      found_notes+=("${agent} $("$agent" --version 2>/dev/null | head -n 1)")
    else
      missing_pkgs+=("$pkg")
    fi
  done

  if (( ${#wanted[@]} == 0 )); then
    STATUS_AGENTS="FAIL"
    DETAIL_AGENTS="No valid agent in --agents '${AGENTS_TO_INSTALL}'"
    add_recovery_note "AI agents: Re-run with '--agents claude,opencode' (or claude / opencode / none)."
    return 0
  fi

  if (( ${#missing_pkgs[@]} == 0 )); then
    STATUS_AGENTS="SKIPPED"
    DETAIL_AGENTS="Already installed ($(join_by ', ' "${found_notes[@]}"))"
    print_skip "Agent CLIs already installed: $(join_by ', ' "${found_notes[@]}")"
    add_agent_login_note "${wanted[@]}"
    return 0
  fi

  print_info "Not installed yet: $(join_by ', ' "${missing_pkgs[@]}")"

  if [[ "$STATUS_NODE" != "PASS" ]] && [[ "$STATUS_NODE" != "SKIPPED" ]]; then
    STATUS_AGENTS="FAIL"
    DETAIL_AGENTS="Blocked because Node.js (>= v${MIN_NODE_MAJOR}) & npm are not ready"
    print_fail "Cannot install agent CLIs until Node.js and npm are ready."
    add_recovery_note "AI agents: Install Node.js first, then re-run ./setup.sh."
    return 0
  fi

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_AGENTS="FAIL"
    DETAIL_AGENTS="Missing ($(join_by ', ' "${missing_pkgs[@]}"); ran with --check-only)"
    print_fail "Agent CLIs not installed: $(join_by ', ' "${missing_pkgs[@]}")"
    add_recovery_note "AI agents: Re-run './setup.sh' without --check-only to install them."
    return 0
  fi

  prepare_offline_npm_cache || true
  if [[ "$NETWORK_AVAILABLE" != "1" ]] && [[ -z "$OFFLINE_NPM_CACHE" ]]; then
    STATUS_AGENTS="FAIL"
    DETAIL_AGENTS="Missing and cannot install while offline"
    print_fail "Cannot install agent CLIs without internet access or the USB kit."
    add_recovery_note "AI agents: Connect to the internet (or plug in the USB kit) and re-run ./setup.sh."
    return 0
  fi

  print_info "Installing $(join_by ', ' "${missing_pkgs[@]}") (a few hundred MB from the internet; seconds from the USB kit)..."
  # One npm run per agent (retried once), so a failing agent never blocks the other
  for pkg in "${missing_pkgs[@]}"; do
    npm_global_install "$pkg" || { print_info "Retrying ${pkg} once..."; npm_global_install "$pkg"; } || true
  done
  refresh_session_path

  local ok_notes=() failed=()
  for agent in "${wanted[@]}"; do
    if verify_agent_binary "$agent"; then
      ok_notes+=("${agent} $("$agent" --version 2>/dev/null | head -n 1)")
    else
      failed+=("$agent")
    fi
  done

  if (( ${#failed[@]} == 0 )); then
    STATUS_AGENTS="PASS"
    DETAIL_AGENTS="Installed ($(join_by ', ' "${ok_notes[@]}"))"
    print_pass "Agent CLIs installed and verified: $(join_by ', ' "${ok_notes[@]}")"
    add_agent_login_note "${wanted[@]}"
    return 0
  fi

  STATUS_AGENTS="FAIL"
  DETAIL_AGENTS="Could not install or verify: $(join_by ', ' "${failed[@]}")"
  print_fail "Could not install or verify: $(join_by ', ' "${failed[@]}")"
  add_recovery_note "AI agents: Run 'npm install -g ${missing_pkgs[*]}' in a new terminal and check the error (see ${CLAUDE_CODE_URL} / ${OPENCODE_URL})."
}

# -----------------------------------------------------------------------------
# 9. jq (JSON tool used by the event's GitHub workflow skills)
# -----------------------------------------------------------------------------
install_jq_standalone_linux() {
  local asset="jq-linux-${ARCH_GO}"
  local jq_tag
  jq_tag="$(resolve_latest_tag "$JQ_RELEASES_LATEST_URL")"
  if [[ ! "$jq_tag" =~ ^jq-[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    print_info "Could not resolve the latest jq release; using ${JQ_FALLBACK_TAG}."
    jq_tag="$JQ_FALLBACK_TAG"
  fi
  local base_url="${JQ_RELEASES_DOWNLOAD_BASE_URL}/${jq_tag}"
  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/jq-standalone.XXXXXX")"

  print_info "Downloading official jq ${jq_tag#jq-} from ${base_url}/${asset}"
  if ! curl -fsSL --retry 2 --connect-timeout 10 -o "${tmp_dir}/sha256sum.txt" "${base_url}/sha256sum.txt" || \
     ! curl -fL --retry 2 --connect-timeout 15 -o "${tmp_dir}/${asset}" "${base_url}/${asset}"; then
    rm -rf "$tmp_dir"; print_fail "Failed to download jq."; return 1
  fi

  local expected_sha256 actual_sha256
  expected_sha256="$(awk -v f="$asset" '$2 == f {print tolower($1)}' "${tmp_dir}/sha256sum.txt" | head -n 1)"
  actual_sha256="$(sha256_of "${tmp_dir}/${asset}")"
  if [[ -z "$expected_sha256" ]] || [[ "$actual_sha256" != "$expected_sha256" ]]; then
    rm -rf "$tmp_dir"; print_fail "SHA-256 checksum mismatch for ${asset}! Refusing to install."; return 1
  fi
  print_pass "Verified official SHA-256 checksum (${actual_sha256})."

  mkdir -p "$USER_BIN_DIR"
  install -m 755 "${tmp_dir}/${asset}" "${USER_BIN_DIR}/jq"
  local rc=$?
  rm -rf "$tmp_dir"
  [[ ":${PATH}:" != *":${USER_BIN_DIR}:"* ]] && export PATH="${PATH}:${USER_BIN_DIR}"
  NEW_TERMINAL_ADVISED=1
  return $rc
}

check_and_setup_jq() {
  print_step "Step 10: Checking jq (used by the /new-issue, /start-task and /plan-project skills)"
  refresh_session_path

  if command -v jq >/dev/null 2>&1 && jq --version >/dev/null 2>&1; then
    STATUS_JQ="SKIPPED"
    DETAIL_JQ="Already installed ($(jq --version 2>/dev/null))"
    print_skip "jq is already installed: $(jq --version 2>/dev/null) ($(command -v jq))"
    return 0
  fi

  print_info "jq was not found on PATH."

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_JQ="FAIL"
    DETAIL_JQ="Missing (not installed; ran with --check-only)"
    print_fail "jq is not installed."
    add_recovery_note "jq: Re-run './setup.sh' without --check-only, or run '$(pkg_install_command jq || echo 'install jq')'."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" == "1" ]] && install_jq_standalone_linux && command -v jq >/dev/null 2>&1; then
    STATUS_JQ="PASS"
    DETAIL_JQ="Installed per-user standalone ($(jq --version 2>/dev/null))"
    print_pass "jq installed and verified: $(jq --version 2>/dev/null)"
    return 0
  fi

  STATUS_JQ="FAIL"
  DETAIL_JQ="Automatic installation failed"
  print_fail "Could not install jq."
  add_recovery_note "jq: Run '$(pkg_install_command jq || echo 'install jq with your package manager')' (see ${JQ_URL})."
}

# -----------------------------------------------------------------------------
# 10. Event Skills (copied into Claude Code's skills folder)
# -----------------------------------------------------------------------------
check_and_setup_skills() {
  print_step "Step 11: Installing the event skills into Claude Code ($(tilde "$SKILLS_TARGET_DIR"))"

  local src_dir="${SCRIPT_DIR}/skills"
  if [[ ! -d "$src_dir" ]]; then
    STATUS_SKILLS="FAIL"
    DETAIL_SKILLS="skills/ folder not found next to setup.sh"
    print_fail "The repo's skills/ folder was not found at ${src_dir}."
    add_recovery_note "Event skills: Re-download the repo (it contains skills/) and re-run ./setup.sh."
    return 0
  fi

  # A skill that already exists is never replaced, so personal or newer copies stay intact.
  local to_copy=() present=() skill_dir name
  for skill_dir in "$src_dir"/*/; do
    [[ -f "${skill_dir}SKILL.md" ]] || continue
    name="$(basename "$skill_dir")"
    if [[ -e "${SKILLS_TARGET_DIR}/${name}" ]]; then
      present+=("$name")
    else
      to_copy+=("$name")
    fi
  done
  local total=$(( ${#to_copy[@]} + ${#present[@]} ))

  if (( ${#to_copy[@]} == 0 )); then
    STATUS_SKILLS="SKIPPED"
    DETAIL_SKILLS="All ${total} event skills already present"
    print_skip "All ${total} event skills are already in $(tilde "$SKILLS_TARGET_DIR")."
    return 0
  fi

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_SKILLS="FAIL"
    DETAIL_SKILLS="${#to_copy[@]} of ${total} event skills not installed (ran with --check-only)"
    print_fail "${#to_copy[@]} of ${total} event skills are not installed."
    add_recovery_note "Event skills: Re-run './setup.sh' without --check-only to copy them into $(tilde "$SKILLS_TARGET_DIR")."
    return 0
  fi

  mkdir -p "$SKILLS_TARGET_DIR"
  local copy_failed=()
  for name in "${to_copy[@]}"; do
    cp -R "${src_dir}/${name}" "${SKILLS_TARGET_DIR}/${name}" || copy_failed+=("$name")
  done

  if (( ${#copy_failed[@]} > 0 )); then
    STATUS_SKILLS="FAIL"
    DETAIL_SKILLS="Could not copy: $(join_by ', ' "${copy_failed[@]}")"
    print_fail "Could not copy skills: $(join_by ', ' "${copy_failed[@]}")"
    add_recovery_note "Event skills: Copy the folders from skills/ into $(tilde "$SKILLS_TARGET_DIR") by hand."
    return 0
  fi

  STATUS_SKILLS="PASS"
  DETAIL_SKILLS="Installed ${#to_copy[@]} skills (${#present[@]} already present, left unchanged)"
  print_pass "Copied ${#to_copy[@]} event skills into $(tilde "$SKILLS_TARGET_DIR") (${#present[@]} already present were left unchanged)."
  print_info "Restart Claude Code to pick them up. Try /new-issue or /start-task inside your team repo."
}

# -----------------------------------------------------------------------------
# Final Summary & Readiness Report
# -----------------------------------------------------------------------------
format_status_badge() {
  case "$1" in
    PASS) printf '%s' "${C_GREEN}PASS           ${C_RESET}" ;;
    SKIPPED) printf '%s' "${C_GREEN}SKIPPED        ${C_RESET}" ;;
    "ACTION REQUIRED") printf '%s' "${C_YELLOW}ACTION REQUIRED${C_RESET}" ;;
    *) printf '%s' "${C_RED}FAIL           ${C_RESET}" ;;
  esac
}

print_summary() {
  say ""
  say "${C_CYAN}=============================================================================${C_RESET}"
  say "${C_BOLD}  Onboarding Setup Summary (Linux — ${ARCH_NAME})${C_RESET}"
  say "${C_CYAN}=============================================================================${C_RESET}"
  say "  Component            Status           Details"
  say "  -------------------- ---------------- -------------------------------------"
  say "  1. Git CLI           $(format_status_badge "$STATUS_GIT") ${DETAIL_GIT}"
  say "  2. Node.js & npm     $(format_status_badge "$STATUS_NODE") ${DETAIL_NODE}"
  say "  3. Zepher CLI        $(format_status_badge "$STATUS_ZEPHER") ${DETAIL_ZEPHER}"
  say "  4. Orca Desktop App  $(format_status_badge "$STATUS_ORCA_APP") ${DETAIL_ORCA_APP}"
  say "  5. Orca CLI          $(format_status_badge "$STATUS_ORCA_CLI") ${DETAIL_ORCA_CLI}"
  say "  6. GitHub CLI        $(format_status_badge "$STATUS_GH") ${DETAIL_GH}"
  say "  7. GitHub over SSH   $(format_status_badge "$STATUS_GH_SSH") ${DETAIL_GH_SSH}"
  say "  8. AI agent CLIs     $(format_status_badge "$STATUS_AGENTS") ${DETAIL_AGENTS}"
  say "  9. jq                $(format_status_badge "$STATUS_JQ") ${DETAIL_JQ}"
  say " 10. Event skills      $(format_status_badge "$STATUS_SKILLS") ${DETAIL_SKILLS}"
  say "${C_CYAN}-----------------------------------------------------------------------------${C_RESET}"
  say "  Status Legend:"
  say "    PASS            = Installed and verified during this run."
  say "    SKIPPED         = Already installed and verified (no reinstall needed)."
  say "    ACTION REQUIRED = Manual user action required (see next steps below)."
  say "    FAIL            = Required check or installation failed."
  say "${C_CYAN}-----------------------------------------------------------------------------${C_RESET}"

  if [[ "$NEW_TERMINAL_ADVISED" == "1" ]]; then
    say ""
    say "${C_BLUE}  [PATH Notice] New programs were installed into ~/.local/bin.${C_RESET}"
    say "  Most distros put ~/.local/bin on PATH at login. If 'gh' or 'zepher' is not found"
    say "  in a new terminal, add this line to ~/.bashrc:  export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi

  local fail_count=0 action_count=0 st
  for st in "$STATUS_GIT" "$STATUS_NODE" "$STATUS_ZEPHER" "$STATUS_ORCA_APP" "$STATUS_ORCA_CLI" \
            "$STATUS_GH" "$STATUS_GH_SSH" "$STATUS_AGENTS" "$STATUS_JQ" "$STATUS_SKILLS"; do
    if [[ "$st" == "FAIL" ]]; then
      (( fail_count += 1 ))
    elif [[ "$st" == "ACTION REQUIRED" ]]; then
      (( action_count += 1 ))
    fi
  done

  if (( ${#RECOVERY_NOTES[@]} > 0 )); then
    say ""
    say "${C_BOLD}Recommended Next Steps / Manual Actions:${C_RESET}"
    local idx=1 note
    for note in "${RECOVERY_NOTES[@]}"; do
      say "  ${idx}. ${note}"
      (( idx += 1 ))
    done
    say ""
    say "${C_BOLD}Official Documentation & Download Links:${C_RESET}"
    say "  - Git CLI        : ${GIT_LINUX_URL}"
    say "  - Node.js LTS    : ${NODE_DOWNLOAD_URL}"
    say "  - Zepher CLI     : ${ZEPHER_NPM_URL}"
    say "  - Orca Install   : ${ORCA_INSTALL_DOCS_URL}"
    say "  - Orca CLI Docs  : ${ORCA_CLI_DOCS_URL}"
    say "  - GitHub CLI     : ${GH_CLI_URL}"
    say "  - GitHub SSH     : ${GH_SSH_DOCS_URL}"
  fi

  say ""
  if (( fail_count == 0 && action_count == 0 )); then
    say "${C_GREEN}=============================================================================${C_RESET}"
    say "${C_GREEN}  FINAL READINESS STATUS: FULLY READY${C_RESET}"
    say "${C_GREEN}  All required tools and CLIs are installed, verified, and ready for the event!${C_RESET}"
    say "${C_GREEN}=============================================================================${C_RESET}"
    return 0
  elif (( fail_count == 0 )); then
    say "${C_YELLOW}=============================================================================${C_RESET}"
    say "${C_YELLOW}  FINAL READINESS STATUS: PARTIALLY READY (${action_count} manual action(s) required)${C_RESET}"
    say "${C_YELLOW}  Complete the manual steps listed above and re-run './setup.sh' in a new terminal.${C_RESET}"
    say "${C_YELLOW}=============================================================================${C_RESET}"
    return 0
  else
    say "${C_RED}=============================================================================${C_RESET}"
    say "${C_RED}  FINAL READINESS STATUS: NOT READY (${fail_count} failure(s), ${action_count} manual action(s))${C_RESET}"
    say "${C_RED}  Follow the recovery steps above and re-run './setup.sh'.${C_RESET}"
    say "${C_RED}=============================================================================${C_RESET}"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# Main Execution Flow
# -----------------------------------------------------------------------------
main() {
  print_banner
  detect_environment
  check_network
  check_and_setup_git
  check_and_setup_node
  check_and_setup_zepher
  check_and_setup_orca_app
  check_and_setup_orca_cli
  check_and_setup_gh
  check_and_setup_github_ssh
  check_and_setup_agents
  check_and_setup_jq
  check_and_setup_skills
  print_summary
}

if [[ "${ONBOARD_SOURCE_ONLY:-0}" != "1" ]]; then
  main "$@"
fi
