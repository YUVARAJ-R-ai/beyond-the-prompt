#!/usr/bin/env zsh
# =============================================================================
# Cross-Platform Event Onboarding — macOS Setup Script (setup.zsh)
# =============================================================================
# Purpose:
#   Automates and verifies the local development environment for event
#   participants on macOS (Apple Silicon and Intel):
#     1. Git CLI
#     2. Node.js (LTS >= 18) & npm
#     3. Zepher CLI (zepher-cli -> zepher)
#     4. Orca Desktop Application (Orca.app)
#     5. Orca CLI (orca)
#     6. GitHub CLI (gh)
#     7. GitHub authentication over SSH (gh login + SSH key + git identity)
#     8. AI agent CLIs (Claude Code, OpenCode)
#     9. jq
#    10. Event skills (into ~/.claude/skills)
#
#   Uses the event USB kit ('Beyond the Prompt' folder) for offline installs
#   of npm packages and jq when it is found (or given with --offline-kit).
#
#   Works both when cloned via Git and when run from an extracted GitHub ZIP
#   archive (or via './bootstrap.zsh') on a clean Mac without Git or Homebrew.
#
# Usage:
#   chmod +x setup.zsh
#   ./setup.zsh
#
# Options:
#   --check-only, --dry-run   Inspect and verify tools without installing anything
#   --no-prompt               Run non-interactively without pausing for prompts
#   --help, -h                Show usage information and exit
#
# Security & Safety Principles:
#   - Never pipes remote scripts into a shell.
#   - Verifies SHA-256 checksums / Apple code signatures on standalone downloads.
#   - Prefers per-user installations to avoid unnecessary administrator privileges.
#   - Never collects, prints, or transmits API keys, tokens, or credentials.
#   - Never modifies shell startup files (~/.zshrc, ~/.zprofile, etc.).
#   - Never overwrites an existing SSH key; ~/.ssh/config is only changed when
#     needed (Keychain passphrase or port-443 fallback), inside a marked block,
#     with a backup copy.
#   - Safe, resumable, and idempotent to run repeatedly.
# =============================================================================

emulate -L zsh
setopt PIPE_FAIL
setopt NO_UNSET

# -----------------------------------------------------------------------------
# Organizer Configuration Section (Isolated for easy maintenance)
# -----------------------------------------------------------------------------
readonly REPO_WEB_URL="${ONBOARD_REPO_WEB_URL:-https://github.com/The-Fable-Club/beyond-the-prompt}"
readonly REPO_ZIP_URL="${ONBOARD_REPO_ZIP_URL:-https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip}"

readonly ZEPHER_NPM_PACKAGE="zepher-cli"
readonly ZEPHER_BIN_NAME="zepher"
readonly ZEPHER_NPM_URL="https://www.npmjs.com/package/zepher-cli"
readonly ZEPHER_GITHUB_URL="https://github.com/YUVARAJ-R-ai/zepher"
readonly MIN_NODE_MAJOR=18
readonly HOMEBREW_NODE_FORMULA="node@22"
readonly NODE_DIST_BASE_URL="${ONBOARD_NODE_DIST_BASE_URL:-https://nodejs.org/dist/latest-v22.x}"

readonly ORCA_BREW_CASK="stablyai/orca/orca"
readonly ORCA_WEBSITE_URL="https://www.onorca.dev"
readonly ORCA_INSTALL_DOCS_URL="https://www.onorca.dev/docs/install"
readonly ORCA_CLI_DOCS_URL="https://www.onorca.dev/docs/cli/overview"
readonly ORCA_DMG_ARM64_URL="https://github.com/stablyai/orca/releases/latest/download/orca-macos-arm64.dmg"
readonly ORCA_DMG_X64_URL="https://github.com/stablyai/orca/releases/latest/download/orca-macos-x64.dmg"
readonly ORCA_RELEASES_API_URL="${ONBOARD_ORCA_RELEASES_API_URL:-https://api.github.com/repos/stablyai/orca/releases/latest}"
readonly ORCA_RELEASES_URL="https://github.com/stablyai/orca/releases"

readonly GH_CLI_URL="https://cli.github.com"
readonly GH_RELEASES_LATEST_URL="${ONBOARD_GH_RELEASES_LATEST_URL:-https://github.com/cli/cli/releases/latest}"
readonly GH_RELEASES_DOWNLOAD_BASE_URL="https://github.com/cli/cli/releases/download"
readonly GH_SSH_DOCS_URL="https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
# Extra token scopes on top of gh's defaults: upload SSH keys + GitHub Projects commands
readonly GH_AUTH_SCOPES="admin:public_key,project"
readonly SSH_KEY_PATH="${ONBOARD_SSH_KEY_PATH:-${HOME}/.ssh/id_ed25519}"
readonly SSH_CONFIG_BLOCK_BEGIN="# >>> beyond-the-prompt: GitHub SSH (managed by setup.zsh) >>>"
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

readonly GIT_MACOS_URL="https://git-scm.com/download/mac"
readonly NODE_DOWNLOAD_URL="https://nodejs.org/en/download"
readonly HOMEBREW_DOCS_URL="https://brew.sh"

# -----------------------------------------------------------------------------
# Runtime State & Result Tracking
# -----------------------------------------------------------------------------
CHECK_ONLY="${ONBOARD_CHECK_ONLY:-0}"
NO_PROMPT="${ONBOARD_NO_PROMPT:-0}"
NETWORK_AVAILABLE=0
ARCH_NAME="unknown"
IS_APPLE_SILICON=0
HAS_HOMEBREW=0
NEW_TERMINAL_ADVISED=0

STATUS_GIT="FAIL"
DETAIL_GIT="Not checked"

STATUS_NODE="FAIL"
DETAIL_NODE="Not checked"

STATUS_ZEPHER="FAIL"
DETAIL_ZEPHER="Not checked"

STATUS_ORCA_APP="FAIL"
DETAIL_ORCA_APP="Not checked"

STATUS_ORCA_CLI="FAIL"
DETAIL_ORCA_CLI="Not checked"

STATUS_GH="FAIL"
DETAIL_GH="Not checked"

STATUS_GH_SSH="FAIL"
DETAIL_GH_SSH="Not checked"

STATUS_AGENTS="FAIL"
DETAIL_AGENTS="Not checked"

STATUS_JQ="FAIL"
DETAIL_JQ="Not checked"

STATUS_SKILLS="FAIL"
DETAIL_SKILLS="Not checked"

AGENTS_TO_INSTALL="${ONBOARD_AGENTS:-claude,opencode}"
OFFLINE_KIT_ARG="${ONBOARD_OFFLINE_KIT:-}"
OFFLINE_OS_DIR=""
OFFLINE_NPM_CACHE=""
typeset -a NPM_CACHE_ARGS
NPM_CACHE_ARGS=()

typeset -a RECOVERY_NOTES
RECOVERY_NOTES=()

# -----------------------------------------------------------------------------
# Terminal Formatting Helpers
# -----------------------------------------------------------------------------
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
  readonly C_RESET=$'\033[0m'
  readonly C_BOLD=$'\033[1m'
  readonly C_GREEN=$'\033[1;32m'
  readonly C_YELLOW=$'\033[1;33m'
  readonly C_RED=$'\033[1;31m'
  readonly C_CYAN=$'\033[1;36m'
  readonly C_BLUE=$'\033[1;34m'
else
  readonly C_RESET=""
  readonly C_BOLD=""
  readonly C_GREEN=""
  readonly C_YELLOW=""
  readonly C_RED=""
  readonly C_CYAN=""
  readonly C_BLUE=""
fi

print_banner() {
  print ""
  print "${C_CYAN}=============================================================================${C_RESET}"
  print "${C_BOLD}  AI Development Event — macOS Environment Onboarding (setup.zsh)${C_RESET}"
  print "${C_CYAN}=============================================================================${C_RESET}"
  print "This script independently detects and prepares your event tools:"
  print "  1. Git CLI                 (Version control)"
  print "  2. Node.js & npm           (JavaScript runtime >= v${MIN_NODE_MAJOR} LTS & package manager)"
  print "  3. Zepher CLI              (npm package: ${ZEPHER_NPM_PACKAGE} -> '${ZEPHER_BIN_NAME}')"
  print "  4. Orca Desktop App        (Agent Development Environment)"
  print "  5. Orca CLI                ('orca' command registered via Orca Settings)"
  print "  6. GitHub CLI              ('gh' command)"
  print "  7. GitHub over SSH         (gh login in your browser + SSH key for git)"
  print "  8. AI agent CLIs           (${AGENTS_TO_INSTALL}; you sign in to them yourself)"
  print "  9. jq                      (JSON tool used by the event's GitHub skills)"
  print " 10. Event skills            (copied into ~/.claude/skills)"
  print ""
  print "${C_BLUE}Note on macOS Execution Permissions:${C_RESET}"
  print "  If macOS ever blocks this script from running, execute:"
  print "    chmod +x setup.zsh"
  print "    xattr -d com.apple.quarantine setup.zsh 2>/dev/null || true"
  print ""
  print "${C_BLUE}Privacy & Security:${C_RESET}"
  print "  - Works even if Git and Homebrew are not pre-installed."
  print "  - Existing working installations are preserved and never overwritten."
  print "  - Standalone installers are verified with SHA-256 / Apple code signatures."
  print "  - Prefers per-user locations (~/.local, ~/Applications) to avoid sudo."
  print "  - Shell startup files (~/.zshrc, ~/.zprofile) are never modified."
  print "  - No API keys, tokens, or personal credentials are requested or collected."
  print "    (You sign in to GitHub yourself in the browser; gh stores its token in the macOS Keychain.)"
  if [[ "$CHECK_ONLY" == "1" ]]; then
    print ""
    print "${C_YELLOW}[MODE] Running in --check-only mode (no installations will be performed).${C_RESET}"
  fi
  print "${C_CYAN}-----------------------------------------------------------------------------${C_RESET}"
}

print_step() {
  print ""
  print "${C_BOLD}${C_BLUE}==> $1${C_RESET}"
}

print_info() {
  print "    [INFO] $1"
}

print_pass() {
  print "    ${C_GREEN}[PASS]${C_RESET} $1"
}

print_skip() {
  print "    ${C_GREEN}[SKIPPED]${C_RESET} $1"
}

print_action() {
  print "    ${C_YELLOW}[ACTION REQUIRED]${C_RESET} $1"
}

print_fail() {
  print "    ${C_RED}[FAIL]${C_RESET} $1"
}

add_recovery_note() {
  RECOVERY_NOTES+=("$1")
}

show_help() {
  cat <<EOF
Usage: ./setup.zsh [OPTIONS]

macOS onboarding script for the AI Development Event.

Options:
  --check-only, --dry-run   Verify installed tools without making any system changes
  --no-prompt               Do not pause for interactive confirmation prompts
  --agents <list>           AI agent CLIs to install: claude,opencode (default), claude, opencode, or none
  --offline-kit <DIR>       Use the event USB kit ('${OFFLINE_KIT_FOLDER}' folder) for offline installs
                            (found automatically next to this repo, in ~/Downloads, or on /Volumes/*)
  --bootstrap               Download & extract full repository ZIP before running
  --local-zip <FILE>        Bootstrap repository from a local .zip archive
  --zip-url <URL>           Override repository ZIP download URL
  --sha256 <HASH>           Verify ZIP archive against expected SHA-256 hash
  --help, -h                Show this help message and exit

If macOS blocks script execution due to permissions:
  chmod +x setup.zsh
  ./setup.zsh
EOF
}

# -----------------------------------------------------------------------------
# Standalone Bootstrap Routine (Runs when invoked alone or when requested)
# -----------------------------------------------------------------------------
run_standalone_bootstrap() {
  local target_zip_url="$1"
  local target_local_zip="$2"
  local target_sha256="$3"
  shift 3
  local -a forward_args
  forward_args=("$@")

  print ""
  print "${C_CYAN}=============================================================================${C_RESET}"
  print "${C_BOLD}  AI Development Event — Standalone Repository Bootstrap${C_RESET}"
  print "${C_CYAN}=============================================================================${C_RESET}"
  print "  - Bootstrapping repository files into a verified temporary workspace..."
  print "${C_CYAN}-----------------------------------------------------------------------------${C_RESET}"

  local temp_dir
  temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/onboard-bootstrap.XXXXXX")"
  local archive_file="${temp_dir}/repo.zip"

  if [[ -n "$target_local_zip" ]]; then
    print "    [INFO] Bootstrapping from local ZIP archive: ${target_local_zip}"
    if [[ ! -f "$target_local_zip" ]]; then
      print "    ${C_RED}[FAIL]${C_RESET} Local ZIP file not found: ${target_local_zip}" >&2
      rm -rf "$temp_dir"
      return 1
    fi
    cp "$target_local_zip" "$archive_file"
  else
    if [[ -z "$target_zip_url" ]] || [[ "$target_zip_url" == *"<"* ]]; then
      print "    ${C_YELLOW}[ACTION REQUIRED]${C_RESET} Repository ZIP URL placeholder has not been configured yet."
      print "    Please download the repository ZIP from GitHub and run:"
      print "      ./setup.zsh --local-zip ~/Downloads/<repo>.zip"
      rm -rf "$temp_dir"
      return 1
    fi

    if [[ "$target_zip_url" != https://* ]]; then
      print "    ${C_RED}[FAIL]${C_RESET} Refusing insecure or non-HTTPS ZIP URL: ${target_zip_url}" >&2
      rm -rf "$temp_dir"
      return 1
    fi

    if ! command -v curl >/dev/null 2>&1; then
      print "    ${C_RED}[FAIL]${C_RESET} 'curl' is required to download the repository archive." >&2
      rm -rf "$temp_dir"
      return 1
    fi

    print "    [INFO] Downloading repository archive from: ${target_zip_url}"
    if ! curl -fL --retry 2 --connect-timeout 10 -o "$archive_file" "$target_zip_url"; then
      print "    ${C_RED}[FAIL]${C_RESET} Failed to download repository ZIP from ${target_zip_url}" >&2
      print "    [INFO] Please download the ZIP manually in your browser and run:" >&2
      print "           ./setup.zsh --local-zip ~/Downloads/<repo>.zip" >&2
      rm -rf "$temp_dir"
      return 1
    fi
  fi

  # Verify ZIP magic bytes (PK\x03\x04)
  local magic_hex=""
  magic_hex="$(head -c 4 "$archive_file" 2>/dev/null | od -An -tx1 2>/dev/null | tr -d '[:space:]' || true)"
  if [[ "$magic_hex" != "504b0304" ]]; then
    print "    ${C_RED}[FAIL]${C_RESET} File is not a valid ZIP archive (magic header: '${magic_hex:-none}', expected '504b0304')." >&2
    rm -rf "$temp_dir"
    return 1
  fi

  # Optional SHA-256 check
  if [[ -n "$target_sha256" ]]; then
    local actual_sha256
    actual_sha256="$(shasum -a 256 "$archive_file" 2>/dev/null | awk '{print tolower($1)}' || true)"
    if [[ "$actual_sha256" != "${target_sha256:l}" ]]; then
      print "    ${C_RED}[FAIL]${C_RESET} SHA-256 checksum mismatch for repository ZIP!" >&2
      print "           Expected: ${target_sha256:l}" >&2
      print "           Actual  : ${actual_sha256:-unknown}" >&2
      rm -rf "$temp_dir"
      return 1
    fi
    print "    ${C_GREEN}[PASS]${C_RESET} SHA-256 checksum verified (${actual_sha256})."
  fi

  if ! unzip -tq "$archive_file" >/dev/null 2>&1; then
    print "    ${C_RED}[FAIL]${C_RESET} ZIP archive integrity check failed." >&2
    rm -rf "$temp_dir"
    return 1
  fi
  print "    ${C_GREEN}[PASS]${C_RESET} ZIP archive integrity verified."

  local extract_dir="${temp_dir}/extracted"
  mkdir -p "$extract_dir"
  if ! unzip -q "$archive_file" -d "$extract_dir"; then
    print "    ${C_RED}[FAIL]${C_RESET} Failed to extract ZIP archive." >&2
    rm -rf "$temp_dir"
    return 1
  fi

  local found_script
  found_script="$(find "$extract_dir" -maxdepth 3 -type f -name "setup.zsh" 2>/dev/null | head -n 1 || true)"
  if [[ -z "$found_script" ]] || [[ ! -s "$found_script" ]]; then
    print "    ${C_RED}[FAIL]${C_RESET} Could not locate 'setup.zsh' inside extracted archive." >&2
    rm -rf "$temp_dir"
    return 1
  fi

  chmod +x "$found_script" 2>/dev/null || true
  print "    ${C_GREEN}[PASS]${C_RESET} Extracted and launching setup.zsh..."
  print ""

  ONBOARD_SKIP_AUTO_BOOTSTRAP=1 /bin/zsh "$found_script" "${forward_args[@]}"
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
typeset -a FORWARD_ARGS
FORWARD_ARGS=()

while (( $# > 0 )); do
  case "$1" in
    --check-only|--dry-run)
      CHECK_ONLY=1
      FORWARD_ARGS+=("$1")
      shift
      ;;
    --no-prompt|--non-interactive)
      NO_PROMPT=1
      FORWARD_ARGS+=("$1")
      shift
      ;;
    --bootstrap)
      BOOTSTRAP_REQUESTED=1
      shift
      ;;
    --agents)
      if (( $# < 2 )); then
        print "${C_RED}[ERROR] --agents requires a list such as claude,opencode or none.${C_RESET}" >&2
        exit 2
      fi
      AGENTS_TO_INSTALL="$2"
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --offline-kit)
      if (( $# < 2 )); then
        print "${C_RED}[ERROR] --offline-kit requires the path of the '${OFFLINE_KIT_FOLDER}' folder.${C_RESET}" >&2
        exit 2
      fi
      OFFLINE_KIT_ARG="$2"
      FORWARD_ARGS+=("$1" "$2")
      shift 2
      ;;
    --local-zip)
      if (( $# < 2 )); then
        print "${C_RED}[ERROR] --local-zip requires a file path argument.${C_RESET}" >&2
        exit 2
      fi
      BOOTSTRAP_REQUESTED=1
      BOOTSTRAP_LOCAL_ZIP="$2"
      shift 2
      ;;
    --zip-url)
      if (( $# < 2 )); then
        print "${C_RED}[ERROR] --zip-url requires a URL argument.${C_RESET}" >&2
        exit 2
      fi
      BOOTSTRAP_REQUESTED=1
      BOOTSTRAP_ZIP_URL="$2"
      shift 2
      ;;
    --sha256)
      if (( $# < 2 )); then
        print "${C_RED}[ERROR] --sha256 requires a 64-character hex digest.${C_RESET}" >&2
        exit 2
      fi
      BOOTSTRAP_SHA256="$2"
      shift 2
      ;;
    --help|-h)
      show_help
      exit 0
      ;;
    *)
      print "${C_RED}Unknown option: $1${C_RESET}"
      show_help
      exit 2
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Auto-bootstrap if explicitly requested OR running standalone without repo context
if [[ "$BOOTSTRAP_REQUESTED" == "1" ]] || \
   { [[ ! -f "${SCRIPT_DIR}/README.md" ]] && [[ ! -f "${SCRIPT_DIR}/setup.bat" ]] && [[ "${ONBOARD_SKIP_AUTO_BOOTSTRAP:-0}" != "1" ]]; }; then
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

  local -a candidate_dirs
  candidate_dirs=(
    "${HOME}/.local/node-lts/bin"
    "${HOME}/.local/bin"
    "${HOME}/.npm-global/bin"
    "/opt/homebrew/bin"
    "/opt/homebrew/sbin"
    "/opt/homebrew/opt/${HOMEBREW_NODE_FORMULA}/bin"
    "/opt/homebrew/opt/node@20/bin"
    "/usr/local/bin"
    "/usr/local/sbin"
    "/usr/local/opt/${HOMEBREW_NODE_FORMULA}/bin"
    "/usr/local/opt/node@20/bin"
    "${HOME}/.volta/bin"
    "${HOME}/.asdf/shims"
    "${HOME}/.fnm"
    "/usr/bin"
    "/bin"
    "/usr/sbin"
    "/sbin"
  )

  if [[ -d "${HOME}/.nvm/versions/node" ]]; then
    local latest_nvm_bin
    latest_nvm_bin="$(find "${HOME}/.nvm/versions/node" -maxdepth 2 -type d -name bin 2>/dev/null | sort -V | tail -n 1 || true)"
    if [[ -n "$latest_nvm_bin" ]]; then
      candidate_dirs+=("$latest_nvm_bin")
    fi
  fi

  local dir
  for dir in "${candidate_dirs[@]}"; do
    if [[ -d "$dir" ]] && [[ ":${PATH}:" != *":${dir}:"* ]]; then
      export PATH="${PATH}:${dir}"
    fi
  done

  if command -v npm >/dev/null 2>&1; then
    local npm_prefix=""
    npm_prefix="$(npm prefix -g 2>/dev/null || true)"
    if [[ -n "$npm_prefix" ]] && [[ -d "${npm_prefix}/bin" ]] && [[ ":${PATH}:" != *":${npm_prefix}/bin:"* ]]; then
      export PATH="${PATH}:${npm_prefix}/bin"
    fi
  fi
}

# -----------------------------------------------------------------------------
# Offline USB Kit & npm Helpers
# -----------------------------------------------------------------------------
detect_offline_kit() {
  # Finds the macOS folder of the event USB kit ('Beyond the Prompt/macOS'), given either
  # the kit folder or its macOS folder, next to this repo, in ~/Downloads, or on a USB volume.
  local -a roots
  roots=()
  [[ -n "$OFFLINE_KIT_ARG" ]] && roots+=("$OFFLINE_KIT_ARG")
  roots+=("${SCRIPT_DIR}/.." "${SCRIPT_DIR}/../.." "${HOME}/Downloads" "${HOME}/Downloads/${OFFLINE_KIT_FOLDER}" "${HOME}/Desktop/${OFFLINE_KIT_FOLDER}")
  local vol
  for vol in /Volumes/*(N/); do
    roots+=("${vol}/${OFFLINE_KIT_FOLDER}")
  done

  local root candidate
  for root in "${roots[@]}"; do
    for candidate in "${root}/macOS" "${root}"; do
      if [[ "${candidate:A:t}" == "macOS" ]] && \
         { [[ -f "${candidate}/npm-offline-cache.zip" ]] || [[ -d "${candidate}/npm-offline-cache/_cacache" ]]; }; then
        OFFLINE_OS_DIR="${candidate:A}"
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
  if [[ -d "${extracted}/_cacache" ]] && [[ "$extracted" != /Volumes/* ]] && [[ -w "$extracted" ]]; then
    OFFLINE_NPM_CACHE="$extracted"
  else
    local kit_zip="${OFFLINE_OS_DIR}/npm-offline-cache.zip"
    local dest="${HOME}/.cache/beyond-the-prompt"
    [[ -f "$kit_zip" ]] || return 1
    if [[ ! -d "${dest}/npm-offline-cache/_cacache" ]]; then
      print_info "Extracting the USB kit's offline npm cache to ~/.cache/beyond-the-prompt (one time, about a minute)..."
      mkdir -p "$dest"
      if ! unzip -q -o "$kit_zip" -d "$dest"; then
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
    print_info "Using the offline npm cache from the USB kit (${OFFLINE_NPM_CACHE/#${HOME}/~})."
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
  local user_bin_dir="${ONBOARD_USER_BIN_DIR:-${HOME}/.local/bin}"
  print_info "Global npm prefix (${npm_global_prefix}) requires administrator permissions."
  print_info "Installing per-user into '${user_npm_prefix}' to avoid requiring sudo: $*"
  mkdir -p "${user_npm_prefix}/bin" "${user_npm_prefix}/lib" "$user_bin_dir"
  npm install -g --no-audit --no-fund "${NPM_CACHE_ARGS[@]}" --prefix "${user_npm_prefix}" "$@"
  local install_rc=$?
  local bin_path
  for bin_path in "${user_npm_prefix}/bin/"*(N); do
    ln -sf "$bin_path" "${user_bin_dir}/${bin_path:t}"
  done
  NEW_TERMINAL_ADVISED=1
  print_info "Note: To use these commands in future terminal sessions, ensure '~/.local/bin' is on your PATH."
  return $install_rc
}

kit_sha256_for() {
  # Prints the expected SHA-256 of a kit file (path relative to the kit root) from SHA256SUMS.txt
  local rel_path="$1"
  local sums_file="${OFFLINE_OS_DIR:h}/SHA256SUMS.txt"
  [[ -f "$sums_file" ]] || return 1
  tr -d '\r' < "$sums_file" | awk -v f="$rel_path" '$2 == f {print tolower($1)}' | head -n 1
}

# -----------------------------------------------------------------------------
# 0. Independent Prerequisite & Environment Detection
# -----------------------------------------------------------------------------
is_git_usable_macos() {
  if ! command -v git >/dev/null 2>&1; then
    return 1
  fi

  local git_path
  git_path="$(command -v git 2>/dev/null || true)"

  # On macOS, /usr/bin/git is an Apple shim that opens a GUI popup if Xcode
  # Command Line Tools are not installed. Check xcode-select -p first!
  if [[ "$git_path" == "/usr/bin/git" ]]; then
    local xcode_check_cmd="${ONBOARD_XCODE_CHECK_CMD:-xcode-select -p}"
    if ! eval "$xcode_check_cmd" >/dev/null 2>&1; then
      return 1
    fi
  fi

  git --version >/dev/null 2>&1
  return $?
}

find_orca_app_macos() {
  local -a search_paths
  if [[ -n "${ONBOARD_ORCA_APP_PATHS:-}" ]]; then
    search_paths=("${(@s/:/)ONBOARD_ORCA_APP_PATHS}")
  else
    search_paths=(
      "/Applications/Orca.app"
      "${HOME}/Applications/Orca.app"
    )
  fi

  local candidate
  for candidate in "${search_paths[@]}"; do
    if [[ -d "$candidate" ]]; then
      print "$candidate"
      return 0
    fi
  done
  return 1
}

detect_environment() {
  print_step "Step 0: Detecting Operating System, Architecture & Independent Tool States"

  local os_name
  os_name="$(uname -s 2>/dev/null || echo "Unknown")"
  ARCH_NAME="$(uname -m 2>/dev/null || echo "Unknown")"

  print_info "Running script  : setup.zsh (Zsh ${ZSH_VERSION:-unknown})"
  print_info "Operating System: ${os_name}"

  if [[ "$os_name" != "Darwin" ]]; then
    print_action "Detected non-macOS platform (${os_name}). This script is designed for macOS."
    print_info "On Windows, please run: setup.bat in Command Prompt."
  fi

  # Detect Apple Silicon even if running inside a Rosetta 2 x86_64 terminal
  local arm64_capable="0"
  arm64_capable="$(sysctl -n hw.optional.arm64 2>/dev/null || echo "0")"
  if [[ "$ARCH_NAME" == "arm64" ]] || [[ "$arm64_capable" == "1" ]]; then
    IS_APPLE_SILICON=1
    if [[ "$ARCH_NAME" != "arm64" ]]; then
      print_info "Architecture    : Apple Silicon (arm64 hardware running under Rosetta 2 x86_64 translation)"
    else
      print_info "Architecture    : Apple Silicon (arm64)"
    fi
  else
    IS_APPLE_SILICON=0
    print_info "Architecture    : Intel (${ARCH_NAME})"
  fi

  refresh_session_path

  # Independent detection snapshot (never assumes any package manager or tool exists)
  if [[ "${ONBOARD_FORCE_NO_BREW:-0}" != "1" ]] && command -v brew >/dev/null 2>&1; then
    HAS_HOMEBREW=1
    local brew_ver
    brew_ver="$(brew --version 2>/dev/null | head -n 1 || echo "Homebrew")"
    print_info "Detect Homebrew : Found (${brew_ver} at $(command -v brew))"
  else
    HAS_HOMEBREW=0
    print_info "Detect Homebrew : Not installed (will use official standalone installers)"
  fi

  if is_git_usable_macos; then
    print_info "Detect Git CLI  : Found ($(command -v git))"
  else
    print_info "Detect Git CLI  : Not found"
  fi

  if command -v node >/dev/null 2>&1; then
    print_info "Detect Node.js  : Found ($(node --version 2>/dev/null | head -n 1 || echo "unknown") at $(command -v node))"
  else
    print_info "Detect Node.js  : Not found"
  fi

  if command -v npm >/dev/null 2>&1; then
    print_info "Detect npm      : Found (v$(npm --version 2>/dev/null | head -n 1 || echo "unknown") at $(command -v npm))"
  else
    print_info "Detect npm      : Not found"
  fi

  if command -v "${ZEPHER_BIN_NAME}" >/dev/null 2>&1; then
    print_info "Detect Zepher   : Found ($(command -v "${ZEPHER_BIN_NAME}"))"
  else
    print_info "Detect Zepher   : Not found"
  fi

  local snap_orca_app=""
  if snap_orca_app="$(find_orca_app_macos)"; then
    print_info "Detect Orca App : Found (${snap_orca_app})"
  else
    print_info "Detect Orca App : Not found"
  fi

  if command -v orca >/dev/null 2>&1; then
    print_info "Detect Orca CLI : Found ($(command -v orca))"
  else
    print_info "Detect Orca CLI : Not found"
  fi

  if command -v gh >/dev/null 2>&1; then
    print_info "Detect GitHub CLI: Found ($(command -v gh))"
  else
    print_info "Detect GitHub CLI: Not found"
  fi

  if detect_offline_kit; then
    print_info "Detect USB kit  : Found (${OFFLINE_OS_DIR}) — used for offline npm packages and jq"
  else
    print_info "Detect USB kit  : Not found (installs will use the internet)"
  fi
}

check_network() {
  print_step "Step 1: Checking Network Connectivity"

  if [[ "${ONBOARD_SIMULATE_OFFLINE:-0}" == "1" ]]; then
    NETWORK_AVAILABLE=0
    print_action "Network check simulated as OFFLINE (ONBOARD_SIMULATE_OFFLINE=1)."
    print_info "Existing local installations will still be checked."
    return 0
  fi

  if ! command -v curl >/dev/null 2>&1; then
    NETWORK_AVAILABLE=0
    print_action "'curl' is not available to verify network access."
    return 0
  fi

  if curl -fsSI --max-time 8 "https://registry.npmjs.org" >/dev/null 2>&1 || \
     curl -fsSI --max-time 8 "${ORCA_WEBSITE_URL}" >/dev/null 2>&1; then
    NETWORK_AVAILABLE=1
    print_pass "Internet connection verified."
  else
    NETWORK_AVAILABLE=0
    print_action "Unable to reach external package servers (https://registry.npmjs.org)."
    print_info "Already-installed tools will still be verified, but downloads cannot proceed while offline."
  fi
}

# -----------------------------------------------------------------------------
# 1. Git CLI
# -----------------------------------------------------------------------------
check_and_setup_git() {
  print_step "Step 2: Checking Git CLI"

  if is_git_usable_macos; then
    local git_ver
    git_ver="$(git --version 2>/dev/null | head -n 1)"
    STATUS_GIT="SKIPPED"
    DETAIL_GIT="Already installed (${git_ver})"
    print_skip "Git is already installed and available on PATH: ${git_ver}"
    return 0
  fi

  print_info "Git CLI was not detected (or Apple Command Line Tools are not yet installed)."
  print_info "Bootstrap Note: If you haven't cloned the repo yet, you can always use './bootstrap.zsh' or GitHub's 'Download ZIP'."

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_GIT="FAIL"
    DETAIL_GIT="Missing (not installed; ran with --check-only)"
    print_fail "Git is not installed."
    add_recovery_note "Git CLI: Run 'xcode-select --install' in Terminal (or download from ${GIT_MACOS_URL}), then re-run ./setup.zsh."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_GIT="FAIL"
    DETAIL_GIT="Missing and cannot install while offline"
    print_fail "Git is missing and network connectivity is unavailable."
    add_recovery_note "Git CLI: Connect to the internet and run 'xcode-select --install' or download from ${GIT_MACOS_URL}."
    return 0
  fi

  # Prefer Apple's Command Line Tools on macOS (works without Homebrew!)
  if command -v xcode-select >/dev/null 2>&1; then
    print_info "Requesting Apple Command Line Developer Tools installation ('xcode-select --install')..."
    print_info "A macOS dialog window may appear asking you to click 'Install' and agree to the license."

    xcode-select --install >/dev/null 2>&1
    local xcs_rc=$?

    if is_git_usable_macos; then
      local git_ver_after
      git_ver_after="$(git --version 2>/dev/null | head -n 1)"
      STATUS_GIT="PASS"
      DETAIL_GIT="Installed (${git_ver_after})"
      print_pass "Git installed and verified: ${git_ver_after}"
      return 0
    fi

    # xcode-select --install launches an asynchronous GUI installer on macOS.
    # Never falsely claim installation completed while the dialog is still running.
    if [[ "$xcs_rc" -eq 0 ]]; then
      STATUS_GIT="ACTION REQUIRED"
      DETAIL_GIT="macOS Command Line Tools installer launched — complete the GUI prompt"
      print_action "The macOS Command Line Developer Tools installer dialog has been opened."
      print_info "Please complete the installation in the macOS popup window, then re-run ./setup.zsh."
      add_recovery_note "Git CLI: Complete the macOS 'Install Command Line Developer Tools' popup window, or install via '${GIT_MACOS_URL}', then re-run ./setup.zsh."
      return 0
    fi
  fi

  # Fallback: If Homebrew is available, try brew install git
  if [[ "$HAS_HOMEBREW" == "1" ]]; then
    print_info "Attempting to install Git via Homebrew ('brew install git')..."
    if brew install git; then
      refresh_session_path
      if is_git_usable_macos; then
        local git_ver_brew
        git_ver_brew="$(git --version 2>/dev/null | head -n 1)"
        STATUS_GIT="PASS"
        DETAIL_GIT="Installed via Homebrew (${git_ver_brew})"
        print_pass "Git installed and verified: ${git_ver_brew}"
        return 0
      fi
    fi
  fi

  STATUS_GIT="FAIL"
  DETAIL_GIT="Automatic installation did not complete"
  print_fail "Could not verify a working Git installation."
  print_info "Official download & instructions: ${GIT_MACOS_URL}"
  add_recovery_note "Git CLI: Run 'xcode-select --install' or download Git from ${GIT_MACOS_URL}, then open a new terminal and re-run ./setup.zsh."
}

# -----------------------------------------------------------------------------
# 2. Node.js and npm (Homebrew or Official Verified Standalone Per-User Archive)
# -----------------------------------------------------------------------------
detect_node_version_manager() {
  local managers=()
  [[ -n "${NVM_DIR:-}" || -d "${HOME}/.nvm" ]] && managers+=("nvm")
  [[ -n "${FNM_DIR:-}" || -d "${HOME}/.fnm" ]] && managers+=("fnm")
  [[ -n "${VOLTA_HOME:-}" || -d "${HOME}/.volta" ]] && managers+=("volta")
  [[ -n "${ASDF_DIR:-}" || -d "${HOME}/.asdf" ]] && managers+=("asdf")
  if (( ${#managers[@]} > 0 )); then
    print "${(j:, :)managers}"
  else
    print ""
  fi
}

parse_node_major() {
  local raw_ver="$1"
  local cleaned="${raw_ver#v}"
  local major="${cleaned%%.*}"
  if [[ "$major" =~ ^[0-9]+$ ]]; then
    print "$major"
  else
    print "0"
  fi
}

install_node_standalone_macos() {
  local arch_suffix="x64"
  if [[ "$IS_APPLE_SILICON" == "1" ]]; then
    arch_suffix="arm64"
  fi

  print_info "Homebrew is not installed. Using official Node.js v22 LTS standalone distribution (${arch_suffix})..."
  print_info "Fetching official SHA-256 checksum manifest from: ${NODE_DIST_BASE_URL}/SHASUMS256.txt"

  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/node-standalone.XXXXXX")"

  local shasums_file="${tmp_dir}/SHASUMS256.txt"
  if ! curl -fsSL --retry 2 --connect-timeout 10 -o "$shasums_file" "${NODE_DIST_BASE_URL}/SHASUMS256.txt"; then
    rm -rf "$tmp_dir"
    print_fail "Failed to download official Node.js SHASUMS256.txt manifest."
    return 1
  fi

  local match_line
  match_line="$(grep -E "node-v[0-9]+\.[0-9]+\.[0-9]+-darwin-${arch_suffix}\.tar\.gz$" "$shasums_file" | head -n 1 || true)"
  if [[ -z "$match_line" ]]; then
    rm -rf "$tmp_dir"
    print_fail "Could not locate darwin-${arch_suffix}.tar.gz entry in SHASUMS256.txt."
    return 1
  fi

  local expected_sha256 archive_name
  expected_sha256="$(print "$match_line" | awk '{print tolower($1)}')"
  archive_name="$(print "$match_line" | awk '{print $2}')"

  local archive_path="${tmp_dir}/${archive_name}"
  local download_url="${NODE_DIST_BASE_URL}/${archive_name}"

  print_info "Downloading official standalone Node.js archive: ${download_url}"
  if ! curl -fL --retry 2 --connect-timeout 15 -o "$archive_path" "$download_url"; then
    rm -rf "$tmp_dir"
    print_fail "Failed to download ${download_url}."
    return 1
  fi

  print_info "Verifying SHA-256 checksum against official Node.js manifest..."
  local actual_sha256
  actual_sha256="$(shasum -a 256 "$archive_path" 2>/dev/null | awk '{print tolower($1)}' || true)"

  if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    rm -rf "$tmp_dir"
    print_fail "SHA-256 checksum mismatch for ${archive_name}! Aborting installation."
    print_info "Expected: ${expected_sha256}"
    print_info "Actual  : ${actual_sha256:-unknown}"
    return 1
  fi
  print_pass "Verified official SHA-256 checksum (${actual_sha256})."

  local install_root="${ONBOARD_USER_NODE_DIR:-${HOME}/.local/node-lts}"
  local user_bin_dir="${ONBOARD_USER_BIN_DIR:-${HOME}/.local/bin}"

  print_info "Installing Node.js per-user into '${install_root}' (no administrator/sudo required)..."
  mkdir -p "$install_root" "$user_bin_dir"

  if ! tar -xzf "$archive_path" -C "$install_root" --strip-components=1; then
    rm -rf "$tmp_dir"
    print_fail "Failed to extract ${archive_name} into ${install_root}."
    return 1
  fi

  rm -rf "$tmp_dir"

  # Create symlinks in ~/.local/bin so user tools are available in standard per-user bin
  local bin_item
  for bin_item in node npm npx corepack; do
    if [[ -x "${install_root}/bin/${bin_item}" ]]; then
      ln -sf "${install_root}/bin/${bin_item}" "${user_bin_dir}/${bin_item}"
    fi
  done

  if [[ ":${PATH}:" != *":${install_root}/bin:"* ]]; then
    export PATH="${PATH}:${install_root}/bin"
  fi
  if [[ ":${PATH}:" != *":${user_bin_dir}:"* ]]; then
    export PATH="${PATH}:${user_bin_dir}"
  fi

  NEW_TERMINAL_ADVISED=1
  print_info "Note for future terminal sessions: Ensure '${user_bin_dir}' is in your PATH:"
  print_info "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  return 0
}

check_and_setup_node() {
  print_step "Step 3: Checking Node.js (>= v${MIN_NODE_MAJOR} LTS) and npm"

  refresh_session_path

  local detected_managers
  detected_managers="$(detect_node_version_manager)"
  if [[ -n "$detected_managers" ]]; then
    print_info "Detected Node version manager footprint: ${detected_managers}"
  fi

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

    print_action "Detected Node.js ${node_ver:-unknown} (npm ${npm_ver:-unknown}), but ${ZEPHER_NPM_PACKAGE} requires Node.js >= v${MIN_NODE_MAJOR}.0.0."
    print_info "To avoid breaking your existing Node setup${detected_managers:+ (${detected_managers})}, this script will NOT overwrite it automatically."
    STATUS_NODE="FAIL"
    DETAIL_NODE="Installed Node ${node_ver:-unknown} is older than required v${MIN_NODE_MAJOR}+"
    if [[ -n "$detected_managers" ]]; then
      add_recovery_note "Node.js & npm: Upgrade Node to v${MIN_NODE_MAJOR}+ LTS using your version manager (${detected_managers}), e.g. 'nvm install --lts && nvm use --lts', or visit ${NODE_DOWNLOAD_URL}."
    else
      add_recovery_note "Node.js & npm: Upgrade Node.js to v${MIN_NODE_MAJOR}+ LTS via 'brew upgrade node' or the official installer at ${NODE_DOWNLOAD_URL}."
    fi
    return 0
  fi

  if command -v node >/dev/null 2>&1 && ! command -v npm >/dev/null 2>&1; then
    local partial_node_ver
    partial_node_ver="$(node --version 2>/dev/null | head -n 1 || echo "unknown")"
    STATUS_NODE="FAIL"
    DETAIL_NODE="Node (${partial_node_ver}) found, but 'npm' is missing from PATH"
    print_fail "Node.js (${partial_node_ver}) is installed, but 'npm' was not found on PATH."
    add_recovery_note "Node.js & npm: Reinstall Node.js LTS (which bundles npm) from ${NODE_DOWNLOAD_URL} or fix your Node version manager PATH."
    return 0
  fi

  print_info "Node.js and npm were not found on PATH."

  if [[ -n "$detected_managers" ]]; then
    print_action "A Node version manager (${detected_managers}) directory exists on your machine, but 'node' is not on PATH."
    print_info "Skipping standalone/system Node installation to avoid conflicting with ${detected_managers}."
    STATUS_NODE="ACTION REQUIRED"
    DETAIL_NODE="Version manager (${detected_managers}) detected, but Node/npm not active on PATH"
    add_recovery_note "Node.js & npm: Activate your version manager (${detected_managers}) and install Node LTS (e.g., 'nvm install --lts'), or install from ${NODE_DOWNLOAD_URL}."
    return 0
  fi

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_NODE="FAIL"
    DETAIL_NODE="Missing (not installed; ran with --check-only)"
    print_fail "Node.js and npm are not installed."
    add_recovery_note "Node.js & npm: Re-run './setup.zsh' without --check-only to install Node.js LTS automatically, or download from ${NODE_DOWNLOAD_URL}."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_NODE="FAIL"
    DETAIL_NODE="Missing and cannot install while offline"
    print_fail "Cannot install Node.js because network connectivity is unavailable."
    add_recovery_note "Node.js & npm: Connect to the internet and re-run ./setup.zsh, or install Node.js LTS from ${NODE_DOWNLOAD_URL}."
    return 0
  fi

  # Route A: Homebrew is available
  if [[ "$HAS_HOMEBREW" == "1" ]]; then
    print_info "Installing Node.js LTS via Homebrew ('brew install ${HOMEBREW_NODE_FORMULA}')..."
    if brew install "${HOMEBREW_NODE_FORMULA}"; then
      refresh_session_path
      if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
        local new_node_ver new_npm_ver new_major
        new_node_ver="$(node --version 2>/dev/null | head -n 1 || true)"
        new_npm_ver="$(npm --version 2>/dev/null | head -n 1 || true)"
        new_major="$(parse_node_major "$new_node_ver")"
        if (( new_major >= MIN_NODE_MAJOR )) && [[ -n "$new_npm_ver" ]]; then
          STATUS_NODE="PASS"
          DETAIL_NODE="Installed via Homebrew (Node ${new_node_ver}, npm v${new_npm_ver})"
          NEW_TERMINAL_ADVISED=1
          print_pass "Installed and verified Node.js (${new_node_ver}) and npm (v${new_npm_ver})."
          print_info "Note: Open a new terminal window after setup (or run 'brew link --overwrite ${HOMEBREW_NODE_FORMULA}') if 'node' is not found in other tabs."
          return 0
        fi
      fi
    fi
    print_info "Homebrew Node installation did not complete; attempting official standalone Node.js LTS installer..."
  fi

  # Route B: Official verified standalone per-user distribution from nodejs.org (works without Homebrew or sudo!)
  if install_node_standalone_macos; then
    refresh_session_path
    if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
      local std_node_ver std_npm_ver std_major
      std_node_ver="$(node --version 2>/dev/null | head -n 1 || true)"
      std_npm_ver="$(npm --version 2>/dev/null | head -n 1 || true)"
      std_major="$(parse_node_major "$std_node_ver")"
      if (( std_major >= MIN_NODE_MAJOR )) && [[ -n "$std_npm_ver" ]]; then
        STATUS_NODE="PASS"
        DETAIL_NODE="Installed per-user standalone LTS (Node ${std_node_ver}, npm v${std_npm_ver})"
        print_pass "Installed and verified standalone Node.js (${std_node_ver}) and npm (v${std_npm_ver})."
        return 0
      fi
    fi
  fi

  STATUS_NODE="FAIL"
  DETAIL_NODE="Standalone and package-manager installation failed"
  print_fail "Could not automatically install and verify Node.js + npm."
  print_info "Official Node.js LTS macOS installer (.pkg): ${NODE_DOWNLOAD_URL}"
  add_recovery_note "Node.js & npm: Download and run the official macOS (.pkg) LTS installer from ${NODE_DOWNLOAD_URL}, open a new terminal, and re-run ./setup.zsh."
}

# -----------------------------------------------------------------------------
# 3. Zepher CLI (zepher-cli -> zepher)
# -----------------------------------------------------------------------------
verify_zepher_binary() {
  if ! command -v "${ZEPHER_BIN_NAME}" >/dev/null 2>&1; then
    return 1
  fi

  local ver_out
  ver_out="$("${ZEPHER_BIN_NAME}" --version 2>/dev/null | head -n 1 || true)"
  if [[ -z "$ver_out" ]]; then
    return 1
  fi

  if ! "${ZEPHER_BIN_NAME}" --help >/dev/null 2>&1; then
    return 1
  fi

  return 0
}

check_and_setup_zepher() {
  print_step "Step 4: Checking Zepher CLI (${ZEPHER_NPM_PACKAGE})"

  # Guard against accidental confusion with 'zephyr-cli'
  if [[ "${ZEPHER_NPM_PACKAGE}" == "zephyr-cli" ]] || [[ "${ZEPHER_NPM_PACKAGE}" != "zepher-cli" ]]; then
    STATUS_ZEPHER="FAIL"
    DETAIL_ZEPHER="Package identity mismatch (${ZEPHER_NPM_PACKAGE} != zepher-cli)"
    print_fail "Refusing to install '${ZEPHER_NPM_PACKAGE}'. Only verified package 'zepher-cli' is allowed (do not confuse with 'zephyr-cli')."
    add_recovery_note "Zepher CLI: Ensure ZEPHER_NPM_PACKAGE is set to 'zepher-cli' (${ZEPHER_NPM_URL})."
    return 0
  fi

  refresh_session_path

  if verify_zepher_binary; then
    local existing_zepher_ver
    existing_zepher_ver="$("${ZEPHER_BIN_NAME}" --version 2>/dev/null | head -n 1)"
    STATUS_ZEPHER="SKIPPED"
    DETAIL_ZEPHER="Already installed (${ZEPHER_BIN_NAME} v${existing_zepher_ver})"
    print_skip "Zepher CLI is already installed and verified: ${ZEPHER_BIN_NAME} v${existing_zepher_ver} ($(command -v "${ZEPHER_BIN_NAME}"))"
    return 0
  fi

  print_info "Zepher CLI ('${ZEPHER_BIN_NAME}') is not currently installed."

  if [[ "$STATUS_NODE" != "PASS" ]] && [[ "$STATUS_NODE" != "SKIPPED" ]]; then
    STATUS_ZEPHER="FAIL"
    DETAIL_ZEPHER="Blocked because Node.js (>= v${MIN_NODE_MAJOR}) & npm are not ready"
    print_fail "Cannot install ${ZEPHER_NPM_PACKAGE} because a compatible Node.js (>= v${MIN_NODE_MAJOR}) and npm environment is not available."
    add_recovery_note "Zepher CLI: First install Node.js LTS from ${NODE_DOWNLOAD_URL}, then run 'npm install -g ${ZEPHER_NPM_PACKAGE}'."
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
    print_fail "Cannot verify or install ${ZEPHER_NPM_PACKAGE} without internet access."
    add_recovery_note "Zepher CLI: Connect to the internet (or plug in the USB kit) and re-run ./setup.zsh."
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
    print_fail "Could not verify package identity or '${ZEPHER_BIN_NAME}' executable for '${ZEPHER_NPM_PACKAGE}' on npm."
    print_info "Stopping installation step to avoid installing an unverified package. Official URL: ${ZEPHER_NPM_URL}"
    add_recovery_note "Zepher CLI: Check your npm registry connection and inspect ${ZEPHER_NPM_URL}, then run 'npm install -g ${ZEPHER_NPM_PACKAGE}'."
    return 0
  fi

  print_info "Verified package '${pkg_name_remote}' (executable '${ZEPHER_BIN_NAME}' -> '${pkg_bin_remote}')."

  local install_cmd_rc=1
  npm_global_install "${ZEPHER_NPM_PACKAGE}"
  install_cmd_rc=$?

  refresh_session_path

  if [[ "$install_cmd_rc" -eq 0 ]] && verify_zepher_binary; then
    local installed_zepher_ver
    installed_zepher_ver="$("${ZEPHER_BIN_NAME}" --version 2>/dev/null | head -n 1)"
    STATUS_ZEPHER="PASS"
    DETAIL_ZEPHER="Installed (${ZEPHER_BIN_NAME} v${installed_zepher_ver})"
    print_pass "Zepher CLI installed and verified: ${ZEPHER_BIN_NAME} v${installed_zepher_ver}"
    return 0
  fi

  STATUS_ZEPHER="FAIL"
  DETAIL_ZEPHER="Installation or post-install verification failed"
  print_fail "Failed to install or verify '${ZEPHER_NPM_PACKAGE}'."
  print_info "Official package page: ${ZEPHER_NPM_URL}"
  add_recovery_note "Zepher CLI: Run 'npm install -g ${ZEPHER_NPM_PACKAGE}' manually and verify with '${ZEPHER_BIN_NAME} --version' (see ${ZEPHER_NPM_URL})."
}

# -----------------------------------------------------------------------------
# 4. Orca Desktop Application (Homebrew Cask or Official Standalone DMG)
# -----------------------------------------------------------------------------
install_orca_dmg_standalone_macos() {
  local dmg_url="$1"
  local dmg_filename="$2"
  local arch_label="$3"

  print_info "Homebrew is not installed. Attempting official Orca standalone DMG installation (${arch_label})..."
  print_info "Fetching official release metadata from: ${ORCA_RELEASES_API_URL}"

  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/orca-dmg.XXXXXX")"
  local dmg_path="${tmp_dir}/${dmg_filename}"
  local release_json="${tmp_dir}/release.json"

  local expected_sha256=""
  if curl -fsSL --retry 2 --connect-timeout 10 -o "$release_json" "${ORCA_RELEASES_API_URL}" 2>/dev/null; then
    # Extract sha256 digest for the specific DMG asset
    expected_sha256="$(grep -B 3 -A 6 "\"name\": \"${dmg_filename}\"" "$release_json" 2>/dev/null | grep -oE "sha256:[0-9a-fA-F]{64}" | head -n 1 | cut -d: -f2 | tr '[:upper:]' '[:lower:]' || true)"
  fi

  print_info "Downloading official Orca installer: ${dmg_url}"
  if ! curl -fL --retry 2 --connect-timeout 15 -o "$dmg_path" "$dmg_url"; then
    rm -rf "$tmp_dir"
    print_fail "Failed to download ${dmg_url}."
    return 1
  fi

  if [[ -n "$expected_sha256" ]]; then
    print_info "Verifying SHA-256 digest against official Orca GitHub Release metadata..."
    local actual_sha256
    actual_sha256="$(shasum -a 256 "$dmg_path" 2>/dev/null | awk '{print tolower($1)}' || true)"
    if [[ "$actual_sha256" != "$expected_sha256" ]]; then
      rm -rf "$tmp_dir"
      print_fail "SHA-256 checksum mismatch for ${dmg_filename}!"
      print_info "Expected: ${expected_sha256}"
      print_info "Actual  : ${actual_sha256:-unknown}"
      return 1
    fi
    print_pass "Verified official SHA-256 checksum (${actual_sha256})."
  fi

  if ! command -v hdiutil >/dev/null 2>&1; then
    rm -rf "$tmp_dir"
    return 1
  fi

  local mount_point="${tmp_dir}/mnt"
  mkdir -p "$mount_point"
  print_info "Mounting ${dmg_filename} read-only..."
  if ! hdiutil attach "$dmg_path" -mountpoint "$mount_point" -nobrowse -readonly -quiet; then
    rm -rf "$tmp_dir"
    print_fail "Could not mount ${dmg_filename}."
    return 1
  fi

  if [[ ! -d "${mount_point}/Orca.app" ]]; then
    hdiutil detach "$mount_point" -quiet 2>/dev/null || true
    rm -rf "$tmp_dir"
    print_fail "Orca.app was not found inside mounted ${dmg_filename}."
    return 1
  fi

  # Verify Apple code signature before copying
  if command -v codesign >/dev/null 2>&1; then
    print_info "Verifying Apple code signature on Orca.app..."
    if ! codesign --verify --deep --strict "${mount_point}/Orca.app" >/dev/null 2>&1; then
      hdiutil detach "$mount_point" -quiet 2>/dev/null || true
      rm -rf "$tmp_dir"
      print_fail "Orca.app code signature verification failed! Refusing to install."
      return 1
    fi
    print_pass "Verified Apple code signature on Orca.app."
  fi

  # Prefer /Applications if writable without sudo, otherwise per-user ~/Applications
  local target_apps_dir="${HOME}/Applications"
  if [[ -n "${ONBOARD_ORCA_INSTALL_DIR:-}" ]]; then
    target_apps_dir="${ONBOARD_ORCA_INSTALL_DIR}"
  elif [[ -w "/Applications" ]]; then
    target_apps_dir="/Applications"
  fi

  mkdir -p "$target_apps_dir"
  print_info "Copying Orca.app to '${target_apps_dir}/Orca.app'..."
  local copy_rc=0
  ditto "${mount_point}/Orca.app" "${target_apps_dir}/Orca.app" || copy_rc=$?

  hdiutil detach "$mount_point" -quiet 2>/dev/null || true
  rm -rf "$tmp_dir"

  if [[ "$copy_rc" -ne 0 ]] || [[ ! -d "${target_apps_dir}/Orca.app" ]]; then
    print_fail "Failed to copy Orca.app into ${target_apps_dir}."
    return 1
  fi

  return 0
}

check_and_setup_orca_app() {
  print_step "Step 5: Checking Orca Desktop Application"

  local existing_app=""
  if existing_app="$(find_orca_app_macos)"; then
    STATUS_ORCA_APP="SKIPPED"
    DETAIL_ORCA_APP="Already installed (${existing_app})"
    print_skip "Orca desktop application is already installed at: ${existing_app}"
    return 0
  fi

  print_info "Orca.app was not found in /Applications or ~/Applications."

  local recommended_dmg_url="${ORCA_DMG_X64_URL}"
  local recommended_dmg_name="orca-macos-x64.dmg"
  local arch_label="Intel (x64)"
  if [[ "$IS_APPLE_SILICON" == "1" ]]; then
    recommended_dmg_url="${ORCA_DMG_ARM64_URL}"
    recommended_dmg_name="orca-macos-arm64.dmg"
    arch_label="Apple Silicon (arm64)"
  fi

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_ORCA_APP="ACTION REQUIRED"
    DETAIL_ORCA_APP="Not installed (ran with --check-only)"
    print_action "Orca desktop application is not installed."
    print_info "Install with Homebrew: brew install --cask ${ORCA_BREW_CASK}"
    print_info "Or download for ${arch_label}: ${recommended_dmg_url}"
    add_recovery_note "Orca Desktop App: Re-run './setup.zsh' without --check-only, or install via 'brew install --cask ${ORCA_BREW_CASK}' / ${ORCA_INSTALL_DOCS_URL}."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_ORCA_APP="FAIL"
    DETAIL_ORCA_APP="Missing and cannot download while offline"
    print_fail "Cannot download or install Orca because network connectivity is unavailable."
    add_recovery_note "Orca Desktop App: Connect to the internet and re-run ./setup.zsh or download from ${ORCA_INSTALL_DOCS_URL}."
    return 0
  fi

  # Route A: Homebrew Cask if Homebrew is available
  if [[ "$HAS_HOMEBREW" == "1" ]]; then
    print_info "Installing Orca via official Homebrew Cask ('brew install --cask ${ORCA_BREW_CASK}')..."
    print_info "Note: macOS may ask for your password to move Orca.app into /Applications."

    if brew install --cask "${ORCA_BREW_CASK}"; then
      local installed_app=""
      if installed_app="$(find_orca_app_macos)"; then
        STATUS_ORCA_APP="PASS"
        DETAIL_ORCA_APP="Installed via Homebrew (${installed_app})"
        print_pass "Orca desktop application installed and verified at: ${installed_app}"
        return 0
      fi
    fi

    STATUS_ORCA_APP="FAIL"
    DETAIL_ORCA_APP="Homebrew cask installation failed or Orca.app not found afterward"
    print_fail "Homebrew installation of '${ORCA_BREW_CASK}' did not complete cleanly."
    print_info "Official installation docs : ${ORCA_INSTALL_DOCS_URL}"
    print_info "Direct download (${arch_label}): ${recommended_dmg_url}"
    add_recovery_note "Orca Desktop App: Download the macOS installer for ${arch_label} from ${ORCA_INSTALL_DOCS_URL} (${recommended_dmg_url}) and move Orca.app to /Applications."
    return 0
  fi

  # Route B: Official standalone DMG when Homebrew is absent (no Homebrew installation required!)
  if install_orca_dmg_standalone_macos "$recommended_dmg_url" "$recommended_dmg_name" "$arch_label"; then
    local dmg_installed_app=""
    if dmg_installed_app="$(find_orca_app_macos)"; then
      STATUS_ORCA_APP="PASS"
      DETAIL_ORCA_APP="Installed via official standalone DMG (${dmg_installed_app})"
      print_pass "Orca desktop application installed and verified at: ${dmg_installed_app}"
      return 0
    fi
  fi

  # Fallback if standalone DMG download/mount could not complete automatically
  STATUS_ORCA_APP="ACTION REQUIRED"
  DETAIL_ORCA_APP="Manual download required (${ORCA_INSTALL_DOCS_URL})"
  print_action "Could not complete automated DMG installation of Orca."
  print_info "Note on Homebrew: Homebrew is NOT installed automatically because it modifies"
  print_info "system directories (/opt/homebrew or /usr/local) and requires administrator access."
  print_info "Please install Orca manually using the official download page:"
  print_info "  Official Install Page          : ${ORCA_INSTALL_DOCS_URL}"
  print_info "  Direct Download (${arch_label}): ${recommended_dmg_url}"
  print_info "After opening the .dmg and dragging Orca.app into /Applications, re-run ./setup.zsh."
  add_recovery_note "Orca Desktop App: Download Orca from ${ORCA_INSTALL_DOCS_URL} (${recommended_dmg_url}), move Orca.app to /Applications, and re-run ./setup.zsh."
}

# -----------------------------------------------------------------------------
# 5. Orca CLI (orca)
# -----------------------------------------------------------------------------
print_orca_cli_registration_guide() {
  print_info "How to enable and register the Orca CLI:"
  print_info "  1. Open the Orca desktop application (/Applications/Orca.app or ~/Applications/Orca.app)."
  print_info "  2. In Orca, go to: Settings -> General -> Orca CLI"
  print_info "  3. Click to register/enable the 'orca' command on your PATH."
  print_info "  4. Open a NEW terminal window so the updated PATH takes effect."
  print_info "  5. Verify with: command -v orca && orca status --json"
  print_info "  Official CLI documentation: ${ORCA_CLI_DOCS_URL}"
}

check_and_setup_orca_cli() {
  print_step "Step 6: Checking Orca CLI ('orca')"

  refresh_session_path

  # Never assume installing Orca.app automatically registers the CLI on PATH.
  if ! command -v orca >/dev/null 2>&1; then
    STATUS_ORCA_CLI="ACTION REQUIRED"
    if [[ "$STATUS_ORCA_APP" == "PASS" ]] || [[ "$STATUS_ORCA_APP" == "SKIPPED" ]]; then
      DETAIL_ORCA_CLI="Orca.app is installed, but 'orca' CLI is not yet registered on PATH"
      print_action "Orca desktop app is installed, but the 'orca' CLI is not yet on your PATH."
    else
      DETAIL_ORCA_CLI="Install Orca desktop app first, then register CLI in Settings -> General -> Orca CLI"
      print_action "The 'orca' CLI is not available on PATH (Orca desktop app must be installed first)."
    fi
    print_orca_cli_registration_guide
    add_recovery_note "Orca CLI: Open the Orca app -> Settings -> General -> Orca CLI to register 'orca' on your PATH, open a new terminal, and run 'orca status --json' (see ${ORCA_CLI_DOCS_URL})."
    return 0
  fi

  local orca_bin_path
  orca_bin_path="$(command -v orca 2>/dev/null || true)"
  print_info "Found 'orca' executable on PATH: ${orca_bin_path}"
  print_info "Verifying with documented command: orca status --json"

  local status_output=""
  if status_output="$(orca status --json 2>&1)"; then
    STATUS_ORCA_CLI="SKIPPED"
    DETAIL_ORCA_CLI="Registered on PATH and verified ('orca status --json' succeeded)"
    print_skip "Orca CLI is registered and verified via 'orca status --json'."
    return 0
  fi

  # If 'orca status --json' returned non-zero, check if the binary works when Orca GUI isn't running
  if orca --help >/dev/null 2>&1 || orca --version >/dev/null 2>&1; then
    STATUS_ORCA_CLI="ACTION REQUIRED"
    DETAIL_ORCA_CLI="CLI is on PATH (${orca_bin_path}), but 'orca status --json' requires Orca app to be running"
    print_action "'orca' CLI is registered on PATH (${orca_bin_path}), but 'orca status --json' could not reach a running Orca session."
    print_info "Please launch the Orca desktop app and run 'orca status --json' to confirm full connectivity."
    add_recovery_note "Orca CLI: Launch the Orca desktop application so 'orca status --json' can connect to the active Orca instance."
    return 0
  fi

  STATUS_ORCA_CLI="FAIL"
  DETAIL_ORCA_CLI="Found '${orca_bin_path}', but execution failed"
  print_fail "'orca' was found at ${orca_bin_path}, but failed verification."
  print_orca_cli_registration_guide
  add_recovery_note "Orca CLI: Re-register the CLI in Orca under Settings -> General -> Orca CLI (see ${ORCA_CLI_DOCS_URL})."
}

# -----------------------------------------------------------------------------
# 6. GitHub CLI (Homebrew or Official Verified Standalone Per-User Archive)
# -----------------------------------------------------------------------------
verify_gh_binary() {
  command -v gh >/dev/null 2>&1 && gh --version >/dev/null 2>&1
}

install_gh_standalone_macos() {
  local arch_suffix="amd64"
  if [[ "$IS_APPLE_SILICON" == "1" ]]; then
    arch_suffix="arm64"
  fi

  # Resolve the version through the releases/latest redirect instead of the GitHub API,
  # so a room full of laptops behind one IP does not hit the unauthenticated API limit.
  print_info "Resolving the latest official GitHub CLI release from: ${GH_RELEASES_LATEST_URL}"
  local tag_url gh_ver
  tag_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' --retry 2 --connect-timeout 10 "${GH_RELEASES_LATEST_URL}" 2>/dev/null || true)"
  gh_ver="${tag_url##*/tag/v}"
  if [[ ! "$gh_ver" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    print_fail "Could not determine the latest GitHub CLI version (resolved URL: '${tag_url:-none}')."
    return 1
  fi

  local base_url="${GH_RELEASES_DOWNLOAD_BASE_URL}/v${gh_ver}"
  local archive_name="gh_${gh_ver}_macOS_${arch_suffix}.zip"
  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/gh-standalone.XXXXXX")"
  local checksums_file="${tmp_dir}/checksums.txt"
  local archive_path="${tmp_dir}/${archive_name}"

  print_info "Fetching official checksum manifest: ${base_url}/gh_${gh_ver}_checksums.txt"
  if ! curl -fsSL --retry 2 --connect-timeout 10 -o "$checksums_file" "${base_url}/gh_${gh_ver}_checksums.txt"; then
    rm -rf "$tmp_dir"
    print_fail "Failed to download the official GitHub CLI checksum manifest."
    return 1
  fi

  local expected_sha256
  expected_sha256="$(awk -v f="$archive_name" '$2 == f {print tolower($1)}' "$checksums_file" | head -n 1)"
  if [[ -z "$expected_sha256" ]]; then
    rm -rf "$tmp_dir"
    print_fail "Could not locate ${archive_name} in the GitHub CLI checksum manifest."
    return 1
  fi

  print_info "Downloading official GitHub CLI archive: ${base_url}/${archive_name}"
  if ! curl -fL --retry 2 --connect-timeout 15 -o "$archive_path" "${base_url}/${archive_name}"; then
    rm -rf "$tmp_dir"
    print_fail "Failed to download ${archive_name}."
    return 1
  fi

  local actual_sha256
  actual_sha256="$(shasum -a 256 "$archive_path" 2>/dev/null | awk '{print tolower($1)}' || true)"
  if [[ "$actual_sha256" != "$expected_sha256" ]]; then
    rm -rf "$tmp_dir"
    print_fail "SHA-256 checksum mismatch for ${archive_name}! Aborting installation."
    print_info "Expected: ${expected_sha256}"
    print_info "Actual  : ${actual_sha256:-unknown}"
    return 1
  fi
  print_pass "Verified official SHA-256 checksum (${actual_sha256})."

  if ! unzip -q "$archive_path" -d "${tmp_dir}/extracted"; then
    rm -rf "$tmp_dir"
    print_fail "Failed to extract ${archive_name}."
    return 1
  fi

  local extracted_dir="${tmp_dir}/extracted/gh_${gh_ver}_macOS_${arch_suffix}"
  if [[ ! -x "${extracted_dir}/bin/gh" ]]; then
    rm -rf "$tmp_dir"
    print_fail "The 'gh' executable was not found inside ${archive_name}."
    return 1
  fi

  local install_root="${ONBOARD_USER_GH_DIR:-${HOME}/.local/gh}"
  local user_bin_dir="${ONBOARD_USER_BIN_DIR:-${HOME}/.local/bin}"
  print_info "Installing GitHub CLI per-user into '${install_root}' (no administrator/sudo required)..."
  mkdir -p "$install_root" "$user_bin_dir"
  if ! ditto "$extracted_dir" "$install_root"; then
    rm -rf "$tmp_dir"
    print_fail "Failed to copy GitHub CLI into ${install_root}."
    return 1
  fi
  rm -rf "$tmp_dir"

  ln -sf "${install_root}/bin/gh" "${user_bin_dir}/gh"
  if [[ ":${PATH}:" != *":${user_bin_dir}:"* ]]; then
    export PATH="${PATH}:${user_bin_dir}"
  fi

  NEW_TERMINAL_ADVISED=1
  print_info "Note for future terminal sessions: Ensure '${user_bin_dir}' is in your PATH:"
  print_info "  export PATH=\"\$HOME/.local/bin:\$PATH\""
  return 0
}

check_and_setup_gh() {
  print_step "Step 7: Checking GitHub CLI ('gh')"

  refresh_session_path

  if verify_gh_binary; then
    local gh_ver
    gh_ver="$(gh --version 2>/dev/null | head -n 1)"
    STATUS_GH="SKIPPED"
    DETAIL_GH="Already installed (${gh_ver})"
    print_skip "GitHub CLI is already installed: ${gh_ver} ($(command -v gh))"
    return 0
  fi

  print_info "GitHub CLI ('gh') was not found on PATH."

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_GH="FAIL"
    DETAIL_GH="Missing (not installed; ran with --check-only)"
    print_fail "GitHub CLI is not installed."
    add_recovery_note "GitHub CLI: Re-run './setup.zsh' without --check-only, or install from ${GH_CLI_URL}."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_GH="FAIL"
    DETAIL_GH="Missing and cannot install while offline"
    print_fail "Cannot install GitHub CLI because network connectivity is unavailable."
    add_recovery_note "GitHub CLI: Connect to the internet and re-run ./setup.zsh, or install from ${GH_CLI_URL}."
    return 0
  fi

  # Route A: Homebrew is available
  if [[ "$HAS_HOMEBREW" == "1" ]]; then
    print_info "Installing GitHub CLI via Homebrew ('brew install gh')..."
    if brew install gh; then
      refresh_session_path
      if verify_gh_binary; then
        local brew_gh_ver
        brew_gh_ver="$(gh --version 2>/dev/null | head -n 1)"
        STATUS_GH="PASS"
        DETAIL_GH="Installed via Homebrew (${brew_gh_ver})"
        print_pass "GitHub CLI installed and verified: ${brew_gh_ver}"
        return 0
      fi
    fi
    print_info "Homebrew installation did not complete; attempting the official standalone archive..."
  fi

  # Route B: Official verified standalone per-user archive from GitHub Releases
  if install_gh_standalone_macos; then
    refresh_session_path
    if verify_gh_binary; then
      local std_gh_ver
      std_gh_ver="$(gh --version 2>/dev/null | head -n 1)"
      STATUS_GH="PASS"
      DETAIL_GH="Installed per-user standalone (${std_gh_ver})"
      print_pass "GitHub CLI installed and verified: ${std_gh_ver}"
      return 0
    fi
  fi

  STATUS_GH="FAIL"
  DETAIL_GH="Automatic installation failed"
  print_fail "Could not automatically install and verify GitHub CLI."
  add_recovery_note "GitHub CLI: Download the macOS installer from ${GH_CLI_URL}, open a new terminal, and re-run ./setup.zsh."
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
    print "ok:${login%%\!*}"
  elif [[ "$out" == *"Host key verification failed"* ]] || [[ "$out" == *"REMOTE HOST IDENTIFICATION HAS CHANGED"* ]]; then
    print "hostkey"
  elif [[ "$out" == *"Permission denied"* ]]; then
    print "denied"
  else
    print "unreachable"
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
      for key in "${(@f)keys}"; do
        print -r -- "${host} ${key}" >> "$known_hosts"
      done
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
    print -r -- "${SSH_CONFIG_BLOCK_BEGIN}"
    print -r -- "Host github.com"
    if [[ "$use_port_443" == "1" ]]; then
      print -r -- "  HostName ssh.github.com"
      print -r -- "  Port 443"
    fi
    print -r -- "  User git"
    print -r -- "  IdentityFile ${SSH_KEY_PATH/#${HOME}/~}"
    print -r -- "  AddKeysToAgent yes"
    print -r -- "  IgnoreUnknown UseKeychain"
    print -r -- "  UseKeychain yes"
    print -r -- "${SSH_CONFIG_BLOCK_END}"
    print ""
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

  local user_line gh_id gh_login gh_name
  user_line="$(gh api user --jq '"\(.id)\t\(.login)\t\(.name // "")"' 2>/dev/null || true)"
  IFS=$'\t' read -r gh_id gh_login gh_name <<< "$user_line"
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
    add_recovery_note "GitHub over SSH: Install GitHub CLI first (${GH_CLI_URL}), then re-run ./setup.zsh."
    return 0
  fi

  if ! command -v ssh >/dev/null 2>&1 || ! command -v ssh-keygen >/dev/null 2>&1; then
    STATUS_GH_SSH="FAIL"
    DETAIL_GH_SSH="OpenSSH ('ssh', 'ssh-keygen') not found"
    print_fail "OpenSSH client tools were not found on PATH."
    add_recovery_note "GitHub over SSH: macOS ships OpenSSH in /usr/bin; make sure /usr/bin is on your PATH and re-run ./setup.zsh."
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
    if [[ "$CHECK_ONLY" != "1" ]]; then
      configure_git_identity_from_github
    fi
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
    add_recovery_note "GitHub over SSH: Re-run './setup.zsh' without --check-only to sign in and set up your SSH key."
    return 0
  fi

  if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
    STATUS_GH_SSH="FAIL"
    DETAIL_GH_SSH="Cannot sign in to GitHub while offline"
    print_fail "GitHub sign-in needs internet access."
    add_recovery_note "GitHub over SSH: Connect to the internet and re-run ./setup.zsh."
    return 0
  fi

  if [[ -n "${GH_TOKEN:-}" ]] || [[ -n "${GITHUB_TOKEN:-}" ]]; then
    STATUS_GH_SSH="ACTION REQUIRED"
    DETAIL_GH_SSH="GH_TOKEN / GITHUB_TOKEN is set and overrides gh login"
    print_action "A GH_TOKEN or GITHUB_TOKEN environment variable is set; gh uses it instead of a normal login."
    add_recovery_note "GitHub over SSH: Run 'unset GH_TOKEN GITHUB_TOKEN' (and remove them from your shell profile if exported there), then re-run ./setup.zsh."
    return 0
  fi

  if [[ "$NO_PROMPT" == "1" ]] || [[ ! -t 0 ]]; then
    STATUS_GH_SSH="ACTION REQUIRED"
    DETAIL_GH_SSH="Interactive browser sign-in required"
    print_action "GitHub sign-in needs an interactive terminal and a browser."
    add_recovery_note "GitHub over SSH: Re-run './setup.zsh' in a normal Terminal window (without --no-prompt) to sign in to GitHub."
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
      add_recovery_note "GitHub over SSH: Run 'gh auth login --git-protocol ssh --web --scopes ${GH_AUTH_SCOPES}' manually (or enter the code at https://github.com/login/device), then re-run ./setup.zsh."
      return 0
    fi
  else
    local scope_missing=0 scope
    for scope in "${(@s/,/)needed_scopes}"; do
      [[ "$auth_out" == *"'${scope}'"* ]] || scope_missing=1
    done
    if (( scope_missing )); then
      print_info "Adding token scopes '${needed_scopes}' to your existing gh login (approve it in your browser)..."
      if ! gh auth refresh --hostname github.com --scopes "${needed_scopes}"; then
        STATUS_GH_SSH="FAIL"
        DETAIL_GH_SSH="Could not add required token scopes (${needed_scopes})"
        print_fail "'gh auth refresh' did not complete."
        add_recovery_note "GitHub over SSH: Run 'gh auth refresh --scopes ${needed_scopes}', then re-run ./setup.zsh."
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
    mkdir -p "${SSH_KEY_PATH:h}"
    chmod 700 "${SSH_KEY_PATH:h}" 2>/dev/null || true
    print_info "Creating a new ed25519 SSH key at ${SSH_KEY_PATH/#${HOME}/~}."
    print_info "Tip: a passphrase is optional. If you set one, it is saved in your macOS Keychain."
    if ! ssh-keygen -t ed25519 -C "${gh_login:-github}@beyond-the-prompt" -f "$SSH_KEY_PATH"; then
      STATUS_GH_SSH="FAIL"
      DETAIL_GH_SSH="SSH key generation failed"
      print_fail "ssh-keygen did not create a key."
      add_recovery_note "GitHub over SSH: Run 'ssh-keygen -t ed25519' manually, then re-run ./setup.zsh."
      return 0
    fi
  else
    print_info "Using existing SSH key: ${SSH_KEY_PATH/#${HOME}/~}"
    if [[ ! -f "$pub_path" ]]; then
      ssh-keygen -y -f "$SSH_KEY_PATH" > "$pub_path" 2>/dev/null || true
    fi
  fi

  if [[ ! -s "$pub_path" ]]; then
    STATUS_GH_SSH="FAIL"
    DETAIL_GH_SSH="Public key ${pub_path/#${HOME}/~} is missing"
    print_fail "Could not find or recreate the public key ${pub_path}."
    add_recovery_note "GitHub over SSH: Recreate it with 'ssh-keygen -y -f ${SSH_KEY_PATH} > ${pub_path}', then re-run ./setup.zsh."
    return 0
  fi

  # Keep earlier choices: a previous run may have switched github.com to port 443
  local use_port_443=0
  if [[ -f "${HOME}/.ssh/config" ]] && \
     awk -v b="${SSH_CONFIG_BLOCK_BEGIN}" -v e="${SSH_CONFIG_BLOCK_END}" \
       '$0 == b {in_block = 1} $0 == e {in_block = 0} in_block && /Port 443/ {found = 1} END {exit !found}' "${HOME}/.ssh/config"; then
    use_port_443=1
  fi

  if ! ssh-keygen -y -P "" -f "$SSH_KEY_PATH" >/dev/null 2>&1; then
    print_info "Your key has a passphrase; adding it to the macOS Keychain so git does not ask every time..."
    ssh-add --apple-use-keychain "$SSH_KEY_PATH" 2>/dev/null || ssh-add "$SSH_KEY_PATH" || true
    write_github_ssh_config "$use_port_443"
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
    local key_title="beyond-the-prompt $(scutil --get ComputerName 2>/dev/null || hostname -s 2>/dev/null || echo mac)"
    print_info "Uploading ${pub_path/#${HOME}/~} to your GitHub account as '${key_title}'..."
    gh ssh-key add "$pub_path" --title "$key_title" --type authentication || true
    probe="$(github_ssh_probe -o BatchMode=yes)"
  fi

  if [[ "$probe" == ok:* ]]; then
    local ssh_login="${probe#ok:}"
    if [[ -n "$gh_login" ]] && [[ "$ssh_login" != "$gh_login" ]]; then
      STATUS_GH_SSH="ACTION REQUIRED"
      DETAIL_GH_SSH="SSH key belongs to '${ssh_login}', but gh is signed in as '${gh_login}'"
      print_action "Your SSH key authenticates as '${ssh_login}', but gh is signed in as '${gh_login}'."
      add_recovery_note "GitHub over SSH: Use one GitHub account for both. Either 'gh auth login' as ${ssh_login}, or set ONBOARD_SSH_KEY_PATH to a new key path (e.g. ~/.ssh/id_ed25519_${gh_login}) and re-run ./setup.zsh."
      return 0
    fi
    STATUS_GH_SSH="PASS"
    DETAIL_GH_SSH="Signed in as ${ssh_login}; git uses SSH$([[ "$use_port_443" == "1" ]] && print " (port 443)")"
    print_pass "'ssh -T git@github.com' authenticates as ${ssh_login}."
    configure_git_identity_from_github
    return 0
  fi

  STATUS_GH_SSH="FAIL"
  case "$probe" in
    unreachable)
      DETAIL_GH_SSH="GitHub SSH unreachable on ports 22 and 443"
      print_fail "Could not reach GitHub over SSH on port 22 or 443 (network or firewall)."
      add_recovery_note "GitHub over SSH: This network blocks SSH. Try another network or hotspot, then re-run ./setup.zsh (see ${GH_SSH_DOCS_URL})."
      ;;
    hostkey)
      DETAIL_GH_SSH="GitHub host key could not be verified"
      print_fail "GitHub's SSH host key could not be verified."
      add_recovery_note "GitHub over SSH: Run 'ssh-keygen -R github.com', then re-run ./setup.zsh."
      ;;
    *)
      DETAIL_GH_SSH="GitHub rejected the SSH key"
      print_fail "GitHub did not accept ${pub_path/#${HOME}/~} (upload may have failed, or the key is on another account)."
      add_recovery_note "GitHub over SSH: Run 'gh ssh-key add ${pub_path}' and check https://github.com/settings/keys, then re-run ./setup.zsh."
      ;;
  esac
}

# -----------------------------------------------------------------------------
# 8. AI Coding Agent CLIs (Claude Code, OpenCode) via npm
# -----------------------------------------------------------------------------
agent_package_for() {
  case "$1" in
    claude) print "${CLAUDE_CODE_NPM_PACKAGE}" ;;
    opencode) print "${OPENCODE_NPM_PACKAGE}" ;;
    *) return 1 ;;
  esac
}

verify_agent_binary() {
  command -v "$1" >/dev/null 2>&1 && "$1" --version >/dev/null 2>&1
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

  local -a wanted missing_pkgs found_notes
  wanted=()
  missing_pkgs=()
  found_notes=()
  local agent pkg
  for agent in "${(@s/,/)AGENTS_TO_INSTALL}"; do
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
    DETAIL_AGENTS="Already installed (${(j:, :)found_notes})"
    print_skip "Agent CLIs already installed: ${(j:, :)found_notes}"
    add_agent_login_note "${wanted[@]}"
    return 0
  fi

  print_info "Not installed yet: ${(j:, :)missing_pkgs}"

  if [[ "$STATUS_NODE" != "PASS" ]] && [[ "$STATUS_NODE" != "SKIPPED" ]]; then
    STATUS_AGENTS="FAIL"
    DETAIL_AGENTS="Blocked because Node.js (>= v${MIN_NODE_MAJOR}) & npm are not ready"
    print_fail "Cannot install agent CLIs until Node.js and npm are ready."
    add_recovery_note "AI agents: Install Node.js first, then re-run ./setup.zsh."
    return 0
  fi

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_AGENTS="FAIL"
    DETAIL_AGENTS="Missing (${(j:, :)missing_pkgs}; ran with --check-only)"
    print_fail "Agent CLIs not installed: ${(j:, :)missing_pkgs}"
    add_recovery_note "AI agents: Re-run './setup.zsh' without --check-only to install ${(j:, :)missing_pkgs}."
    return 0
  fi

  prepare_offline_npm_cache || true
  if [[ "$NETWORK_AVAILABLE" != "1" ]] && [[ -z "$OFFLINE_NPM_CACHE" ]]; then
    STATUS_AGENTS="FAIL"
    DETAIL_AGENTS="Missing and cannot install while offline"
    print_fail "Cannot install agent CLIs without internet access or the USB kit."
    add_recovery_note "AI agents: Connect to the internet (or plug in the USB kit) and re-run ./setup.zsh."
    return 0
  fi

  print_info "Installing ${(j:, :)missing_pkgs} (a few hundred MB from the internet; seconds from the USB kit)..."
  # One npm run per agent (retried once), so a failing agent never blocks the other
  for pkg in "${missing_pkgs[@]}"; do
    npm_global_install "$pkg" || { print_info "Retrying ${pkg} once..."; npm_global_install "$pkg"; } || true
  done
  refresh_session_path

  local -a ok_notes failed
  ok_notes=()
  failed=()
  for agent in "${wanted[@]}"; do
    if verify_agent_binary "$agent"; then
      ok_notes+=("${agent} $("$agent" --version 2>/dev/null | head -n 1)")
    else
      failed+=("$agent")
    fi
  done

  if (( ${#failed[@]} == 0 )); then
    STATUS_AGENTS="PASS"
    DETAIL_AGENTS="Installed (${(j:, :)ok_notes})"
    print_pass "Agent CLIs installed and verified: ${(j:, :)ok_notes}"
    add_agent_login_note "${wanted[@]}"
    return 0
  fi

  STATUS_AGENTS="FAIL"
  DETAIL_AGENTS="Could not install or verify: ${(j:, :)failed}"
  print_fail "Could not install or verify: ${(j:, :)failed}"
  add_recovery_note "AI agents: Run 'npm install -g ${(j: :)missing_pkgs}' in a new terminal and check the error (see ${CLAUDE_CODE_URL} / ${OPENCODE_URL})."
}

add_agent_login_note() {
  # Signing in to an agent happens in the browser with the participant's own account.
  local -a steps
  steps=()
  local agent
  for agent in "$@"; do
    case "$agent" in
      claude) steps+=("run 'claude' once and sign in with your Claude account") ;;
      opencode) steps+=("run 'opencode auth login' (or use its free models)") ;;
    esac
  done
  if (( ${#steps[@]} > 0 )); then
    add_recovery_note "Sign in to your AI agent before the event: ${(j:; :)steps}."
  fi
}

# -----------------------------------------------------------------------------
# 9. jq (JSON tool used by the event's GitHub workflow skills)
# -----------------------------------------------------------------------------
install_jq_standalone_macos() {
  local arch_suffix="amd64"
  if [[ "$IS_APPLE_SILICON" == "1" ]]; then
    arch_suffix="arm64"
  fi
  local asset="jq-macos-${arch_suffix}"
  local user_bin_dir="${ONBOARD_USER_BIN_DIR:-${HOME}/.local/bin}"
  local tmp_dir
  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/jq-standalone.XXXXXX")"
  local src="" expected_sha256=""

  # Route 1: the USB kit, checked against the kit's SHA256SUMS.txt
  if [[ -n "$OFFLINE_OS_DIR" ]] && [[ -f "${OFFLINE_OS_DIR}/jq/${asset}" ]]; then
    expected_sha256="$(kit_sha256_for "macOS/jq/${asset}" || true)"
    if [[ -n "$expected_sha256" ]]; then
      src="${OFFLINE_OS_DIR}/jq/${asset}"
      print_info "Using jq from the USB kit: ${src}"
    fi
  fi

  # Route 2: the official GitHub release, checked against its sha256sum.txt
  if [[ -z "$src" ]]; then
    if [[ "$NETWORK_AVAILABLE" != "1" ]]; then
      rm -rf "$tmp_dir"
      return 1
    fi
    local tag_url jq_tag
    tag_url="$(curl -fsSLI -o /dev/null -w '%{url_effective}' --retry 2 --connect-timeout 10 "${JQ_RELEASES_LATEST_URL}" 2>/dev/null || true)"
    jq_tag="${tag_url##*/tag/}"
    if [[ ! "$jq_tag" =~ ^jq-[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
      print_info "Could not resolve the latest jq release; using ${JQ_FALLBACK_TAG}."
      jq_tag="$JQ_FALLBACK_TAG"
    fi
    local base_url="${JQ_RELEASES_DOWNLOAD_BASE_URL}/${jq_tag}"
    print_info "Downloading official jq ${jq_tag#jq-} from ${base_url}/${asset}"
    if ! curl -fsSL --retry 2 --connect-timeout 10 -o "${tmp_dir}/sha256sum.txt" "${base_url}/sha256sum.txt" || \
       ! curl -fL --retry 2 --connect-timeout 15 -o "${tmp_dir}/${asset}" "${base_url}/${asset}"; then
      rm -rf "$tmp_dir"
      print_fail "Failed to download jq."
      return 1
    fi
    expected_sha256="$(awk -v f="$asset" '$2 == f {print tolower($1)}' "${tmp_dir}/sha256sum.txt" | head -n 1)"
    src="${tmp_dir}/${asset}"
  fi

  local actual_sha256
  actual_sha256="$(shasum -a 256 "$src" 2>/dev/null | awk '{print tolower($1)}' || true)"
  if [[ -z "$expected_sha256" ]] || [[ "$actual_sha256" != "$expected_sha256" ]]; then
    rm -rf "$tmp_dir"
    print_fail "SHA-256 checksum mismatch for ${asset}! Refusing to install."
    print_info "Expected: ${expected_sha256:-unknown}"
    print_info "Actual  : ${actual_sha256:-unknown}"
    return 1
  fi
  print_pass "Verified official SHA-256 checksum (${actual_sha256})."

  mkdir -p "$user_bin_dir"
  cp "$src" "${user_bin_dir}/jq" && chmod 755 "${user_bin_dir}/jq"
  local cp_rc=$?
  rm -rf "$tmp_dir"
  if [[ ":${PATH}:" != *":${user_bin_dir}:"* ]]; then
    export PATH="${PATH}:${user_bin_dir}"
  fi
  NEW_TERMINAL_ADVISED=1
  return $cp_rc
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
    add_recovery_note "jq: Re-run './setup.zsh' without --check-only, or install from ${JQ_URL}."
    return 0
  fi

  if [[ "$HAS_HOMEBREW" == "1" ]] && [[ "$NETWORK_AVAILABLE" == "1" ]]; then
    print_info "Installing jq via Homebrew ('brew install jq')..."
    if brew install jq && command -v jq >/dev/null 2>&1; then
      STATUS_JQ="PASS"
      DETAIL_JQ="Installed via Homebrew ($(jq --version 2>/dev/null))"
      print_pass "jq installed and verified: $(jq --version 2>/dev/null)"
      return 0
    fi
    print_info "Homebrew installation did not complete; trying the official standalone binary..."
  fi

  if install_jq_standalone_macos && command -v jq >/dev/null 2>&1 && jq --version >/dev/null 2>&1; then
    STATUS_JQ="PASS"
    DETAIL_JQ="Installed per-user standalone ($(jq --version 2>/dev/null))"
    print_pass "jq installed and verified: $(jq --version 2>/dev/null)"
    return 0
  fi

  STATUS_JQ="FAIL"
  DETAIL_JQ="Automatic installation failed"
  print_fail "Could not install jq."
  add_recovery_note "jq: Install with 'brew install jq', or download the macOS binary from ${JQ_URL} into ~/.local/bin/jq."
}

# -----------------------------------------------------------------------------
# 10. Event Skills (copied into Claude Code's skills folder)
# -----------------------------------------------------------------------------
check_and_setup_skills() {
  print_step "Step 11: Installing the event skills into Claude Code (${SKILLS_TARGET_DIR/#${HOME}/~})"

  local src_dir="${SCRIPT_DIR}/skills"
  if [[ ! -d "$src_dir" ]]; then
    STATUS_SKILLS="FAIL"
    DETAIL_SKILLS="skills/ folder not found next to setup.zsh"
    print_fail "The repo's skills/ folder was not found at ${src_dir}."
    add_recovery_note "Event skills: Re-download the repo (it contains skills/) and re-run ./setup.zsh."
    return 0
  fi

  # A skill that already exists is never replaced, so personal or newer copies stay intact.
  local -a to_copy present
  to_copy=()
  present=()
  local skill_dir name
  for skill_dir in "$src_dir"/*(N/); do
    [[ -f "${skill_dir}/SKILL.md" ]] || continue
    name="${skill_dir:t}"
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
    print_skip "All ${total} event skills are already in ${SKILLS_TARGET_DIR/#${HOME}/~}."
    return 0
  fi

  if [[ "$CHECK_ONLY" == "1" ]]; then
    STATUS_SKILLS="FAIL"
    DETAIL_SKILLS="${#to_copy[@]} of ${total} event skills not installed (ran with --check-only)"
    print_fail "${#to_copy[@]} of ${total} event skills are not installed."
    add_recovery_note "Event skills: Re-run './setup.zsh' without --check-only to copy them into ${SKILLS_TARGET_DIR/#${HOME}/~}."
    return 0
  fi

  mkdir -p "$SKILLS_TARGET_DIR"
  local -a copy_failed
  copy_failed=()
  for name in "${to_copy[@]}"; do
    cp -R "${src_dir}/${name}" "${SKILLS_TARGET_DIR}/${name}" || copy_failed+=("$name")
  done

  if (( ${#copy_failed[@]} > 0 )); then
    STATUS_SKILLS="FAIL"
    DETAIL_SKILLS="Could not copy: ${(j:, :)copy_failed}"
    print_fail "Could not copy skills: ${(j:, :)copy_failed}"
    add_recovery_note "Event skills: Copy the folders from skills/ into ${SKILLS_TARGET_DIR/#${HOME}/~} by hand."
    return 0
  fi

  STATUS_SKILLS="PASS"
  DETAIL_SKILLS="Installed ${#to_copy[@]} skills (${#present[@]} already present, left unchanged)"
  print_pass "Copied ${#to_copy[@]} event skills into ${SKILLS_TARGET_DIR/#${HOME}/~} (${#present[@]} already present were left unchanged)."
  print_info "Restart Claude Code to pick them up. Try /new-issue or /start-task inside your team repo."
}

# -----------------------------------------------------------------------------
# Final Summary & Readiness Report
# -----------------------------------------------------------------------------
format_status_badge() {
  local st="$1"
  case "$st" in
    PASS)
      print "${C_GREEN}PASS           ${C_RESET}"
      ;;
    SKIPPED)
      print "${C_GREEN}SKIPPED        ${C_RESET}"
      ;;
    "ACTION REQUIRED")
      print "${C_YELLOW}ACTION REQUIRED${C_RESET}"
      ;;
    *)
      print "${C_RED}FAIL           ${C_RESET}"
      ;;
  esac
}

print_summary() {
  print ""
  print "${C_CYAN}=============================================================================${C_RESET}"
  print "${C_BOLD}  Onboarding Setup Summary (macOS — ${ARCH_NAME})${C_RESET}"
  print "${C_CYAN}=============================================================================${C_RESET}"
  print "  Component            Status           Details"
  print "  -------------------- ---------------- -------------------------------------"
  print "  1. Git CLI           $(format_status_badge "$STATUS_GIT") ${DETAIL_GIT}"
  print "  2. Node.js & npm     $(format_status_badge "$STATUS_NODE") ${DETAIL_NODE}"
  print "  3. Zepher CLI        $(format_status_badge "$STATUS_ZEPHER") ${DETAIL_ZEPHER}"
  print "  4. Orca Desktop App  $(format_status_badge "$STATUS_ORCA_APP") ${DETAIL_ORCA_APP}"
  print "  5. Orca CLI          $(format_status_badge "$STATUS_ORCA_CLI") ${DETAIL_ORCA_CLI}"
  print "  6. GitHub CLI        $(format_status_badge "$STATUS_GH") ${DETAIL_GH}"
  print "  7. GitHub over SSH   $(format_status_badge "$STATUS_GH_SSH") ${DETAIL_GH_SSH}"
  print "  8. AI agent CLIs     $(format_status_badge "$STATUS_AGENTS") ${DETAIL_AGENTS}"
  print "  9. jq                $(format_status_badge "$STATUS_JQ") ${DETAIL_JQ}"
  print " 10. Event skills      $(format_status_badge "$STATUS_SKILLS") ${DETAIL_SKILLS}"
  print "${C_CYAN}-----------------------------------------------------------------------------${C_RESET}"
  print "  Status Legend:"
  print "    PASS            = Installed and verified during this run."
  print "    SKIPPED         = Already installed and verified (no reinstall needed)."
  print "    ACTION REQUIRED = Manual user action required (see next steps below)."
  print "    FAIL            = Required check or installation failed."
  print "${C_CYAN}-----------------------------------------------------------------------------${C_RESET}"

  if [[ "$NEW_TERMINAL_ADVISED" == "1" ]]; then
    print ""
    print "${C_BLUE}  [PATH Notice] New binaries were installed during this session.${C_RESET}"
    print "  Please open a NEW terminal window after this script finishes so your"
    print "  updated PATH is active in future terminal sessions."
  fi

  local fail_count=0
  local action_count=0
  local st
  for st in "$STATUS_GIT" "$STATUS_NODE" "$STATUS_ZEPHER" "$STATUS_ORCA_APP" "$STATUS_ORCA_CLI" "$STATUS_GH" "$STATUS_GH_SSH" "$STATUS_AGENTS" "$STATUS_JQ" "$STATUS_SKILLS"; do
    if [[ "$st" == "FAIL" ]]; then
      (( fail_count += 1 ))
    elif [[ "$st" == "ACTION REQUIRED" ]]; then
      (( action_count += 1 ))
    fi
  done

  if (( ${#RECOVERY_NOTES[@]} > 0 )); then
    print ""
    print "${C_BOLD}Recommended Next Steps / Manual Actions:${C_RESET}"
    local idx=1
    local note
    for note in "${RECOVERY_NOTES[@]}"; do
      print "  ${idx}. ${note}"
      (( idx += 1 ))
    done
    print ""
    print "${C_BOLD}Official Documentation & Download Links:${C_RESET}"
    print "  - Git CLI        : ${GIT_MACOS_URL}"
    print "  - Node.js LTS    : ${NODE_DOWNLOAD_URL}"
    print "  - Zepher CLI     : ${ZEPHER_NPM_URL}"
    print "  - Orca Website   : ${ORCA_WEBSITE_URL}"
    print "  - Orca Install   : ${ORCA_INSTALL_DOCS_URL}"
    print "  - Orca CLI Docs  : ${ORCA_CLI_DOCS_URL}"
    print "  - GitHub CLI     : ${GH_CLI_URL}"
    print "  - GitHub SSH     : ${GH_SSH_DOCS_URL}"
  fi

  print ""
  if (( fail_count == 0 && action_count == 0 )); then
    print "${C_GREEN}=============================================================================${C_RESET}"
    print "${C_GREEN}  FINAL READINESS STATUS: FULLY READY${C_RESET}"
    print "${C_GREEN}  All required tools and CLIs are installed, verified, and ready for the event!${C_RESET}"
    print "${C_GREEN}=============================================================================${C_RESET}"
    return 0
  elif (( fail_count == 0 && action_count > 0 )); then
    print "${C_YELLOW}=============================================================================${C_RESET}"
    print "${C_YELLOW}  FINAL READINESS STATUS: PARTIALLY READY (${action_count} manual action(s) required)${C_RESET}"
    print "${C_YELLOW}  Automated steps succeeded, but please complete the manual steps listed above${C_RESET}"
    print "${C_YELLOW}  and re-run './setup.zsh' in a new terminal window to confirm full readiness.${C_RESET}"
    print "${C_YELLOW}=============================================================================${C_RESET}"
    return 0
  else
    print "${C_RED}=============================================================================${C_RESET}"
    print "${C_RED}  FINAL READINESS STATUS: NOT READY (${fail_count} failure(s), ${action_count} manual action(s))${C_RESET}"
    print "${C_RED}  One or more required components could not be verified. Follow the recovery${C_RESET}"
    print "${C_RED}  steps above and re-run './setup.zsh'.${C_RESET}"
    print "${C_RED}=============================================================================${C_RESET}"
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

main "$@"
