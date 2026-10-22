@echo off
setlocal EnableExtensions EnableDelayedExpansion

REM ===========================================================================
REM Cross-Platform Event Onboarding — Windows Setup Script (setup.bat)
REM ===========================================================================
REM Purpose:
REM   Automates and verifies the local development environment for event
REM   participants on Windows (Command Prompt compatible):
REM     1. Git CLI (Git for Windows)
REM     2. Node.js (LTS >= 18) & npm
REM     3. Zepher CLI (zepher-cli -> zepher)
REM     4. Orca Desktop Application (Orca.exe)
REM     5. Orca CLI (orca)
REM     6. GitHub CLI (gh)
REM     7. GitHub authentication over SSH (gh login + SSH key + git identity)
REM     8. AI agent CLIs (Claude Code, OpenCode)
REM     9. jq
REM    10. Event skills (into %USERPROFILE%\.claude\skills)
REM
REM   Uses the event USB kit ('Beyond the Prompt' folder) for offline installs
REM   of npm packages, jq and the Orca installer when it is found (or given
REM   with --offline-kit).
REM
REM   Works both when cloned via Git and when run from an extracted GitHub ZIP
REM   archive (or via 'bootstrap.bat') on a clean Windows PC without Git or
REM   winget.
REM
REM Usage:
REM   setup.bat
REM   setup.bat --check-only
REM   setup.bat --no-prompt
REM   setup.bat --help
REM
REM Security & Safety Principles:
REM   - Compatible with standard Windows Command Prompt (cmd.exe).
REM   - Avoids nested parentheses to prevent expansion bugs with 'Program Files (x86)'.
REM   - Verifies SHA-256 checksums on standalone downloads via 'certutil -hashfile'.
REM   - Prefers per-user install paths (%LocalAppData%\Programs) to avoid admin prompts.
REM   - Never installs unofficial package managers (Chocolatey/Scoop) as workarounds.
REM   - Never pipes remote scripts into a shell or weakens security policies.
REM   - Never requests, collects, prints, or transmits API keys or passwords.
REM   - Never overwrites an existing SSH key; %USERPROFILE%\.ssh\config is only
REM     changed for the port-443 fallback, inside a marked block, with a backup.
REM   - Safe, resumable, and idempotent to run repeatedly.
REM ===========================================================================

REM ---------------------------------------------------------------------------
REM Organizer Configuration Section (Isolated for easy maintenance)
REM ---------------------------------------------------------------------------
set "REPO_WEB_URL=https://github.com/The-Fable-Club/beyond-the-prompt"
if defined ONBOARD_REPO_WEB_URL set "REPO_WEB_URL=%ONBOARD_REPO_WEB_URL%"
set "REPO_ZIP_URL=https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip"
if defined ONBOARD_REPO_ZIP_URL set "REPO_ZIP_URL=%ONBOARD_REPO_ZIP_URL%"

set "ZEPHER_NPM_PACKAGE=zepher-cli"
set "ZEPHER_BIN_NAME=zepher"
set "ZEPHER_NPM_URL=https://www.npmjs.com/package/zepher-cli"
set "ZEPHER_GITHUB_URL=https://github.com/YUVARAJ-R-ai/zepher"
set "MIN_NODE_MAJOR=18"
set "NODE_DIST_BASE_URL=https://nodejs.org/dist/latest-v22.x"
if defined ONBOARD_NODE_DIST_BASE_URL set "NODE_DIST_BASE_URL=%ONBOARD_NODE_DIST_BASE_URL%"

set "WINGET_GIT_ID=Git.Git"
set "WINGET_NODE_ID=OpenJS.NodeJS.LTS"

set "ORCA_WEBSITE_URL=https://www.onorca.dev"
set "ORCA_INSTALL_DOCS_URL=https://www.onorca.dev/docs/install"
set "ORCA_CLI_DOCS_URL=https://www.onorca.dev/docs/cli/overview"
set "ORCA_WINDOWS_INSTALLER_URL=https://github.com/stablyai/orca/releases/latest/download/orca-windows-setup.exe"
set "ORCA_RELEASES_URL=https://github.com/stablyai/orca/releases"
set "ORCA_RELEASES_DOWNLOAD_URL=https://github.com/stablyai/orca/releases/latest/download"

set "WINGET_GH_ID=GitHub.cli"
set "GH_CLI_URL=https://cli.github.com"
set "GH_RELEASES_LATEST_URL=https://github.com/cli/cli/releases/latest"
if defined ONBOARD_GH_RELEASES_LATEST_URL set "GH_RELEASES_LATEST_URL=%ONBOARD_GH_RELEASES_LATEST_URL%"
set "GH_RELEASES_DOWNLOAD_BASE_URL=https://github.com/cli/cli/releases/download"
set "GH_SSH_DOCS_URL=https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
REM Extra token scopes on top of gh's defaults: upload SSH keys + GitHub Projects commands
set "GH_AUTH_SCOPES=admin:public_key,project"
set "SSH_CONFIG_BLOCK_BEGIN=# BEGIN beyond-the-prompt GitHub SSH - managed by setup.bat"
set "SSH_CONFIG_BLOCK_END=# END beyond-the-prompt GitHub SSH"

set "CLAUDE_CODE_NPM_PACKAGE=@anthropic-ai/claude-code"
set "CLAUDE_CODE_URL=https://www.npmjs.com/package/@anthropic-ai/claude-code"
set "OPENCODE_NPM_PACKAGE=opencode-ai"
set "OPENCODE_URL=https://opencode.ai"
set "WINGET_JQ_ID=jqlang.jq"
set "JQ_URL=https://jqlang.org"
set "JQ_RELEASES_LATEST_URL=https://github.com/jqlang/jq/releases/latest"
set "JQ_RELEASES_DOWNLOAD_BASE_URL=https://github.com/jqlang/jq/releases/download"
REM Used when the "latest" redirect cannot be resolved; still verified against its sha256sum.txt
set "JQ_FALLBACK_TAG=jq-1.8.2"
set "SKILLS_TARGET_DIR=%USERPROFILE%\.claude\skills"
if defined ONBOARD_SKILLS_DIR set "SKILLS_TARGET_DIR=%ONBOARD_SKILLS_DIR%"
REM Name of the folder on the event USB stick (see START-HERE.txt on the stick)
set "OFFLINE_KIT_FOLDER=Beyond the Prompt"

set "GIT_WINDOWS_URL=https://git-scm.com/download/win"
set "NODE_DOWNLOAD_URL=https://nodejs.org/en/download"

REM ---------------------------------------------------------------------------
REM Runtime State & Result Tracking
REM ---------------------------------------------------------------------------
set "CHECK_ONLY=0"
if defined ONBOARD_CHECK_ONLY set "CHECK_ONLY=%ONBOARD_CHECK_ONLY%"
set "NO_PROMPT=0"
if defined ONBOARD_NO_PROMPT set "NO_PROMPT=%ONBOARD_NO_PROMPT%"
set "NETWORK_AVAILABLE=0"
set "HAS_WINGET=0"
set "IS_ADMIN=0"
set "NEW_TERMINAL_ADVISED=0"
set "SCRIPT_DIR=%~dp0"

set "BOOTSTRAP_REQUESTED=0"
set "BOOTSTRAP_LOCAL_ZIP="
set "BOOTSTRAP_ZIP_URL=%REPO_ZIP_URL%"
set "BOOTSTRAP_SHA256="
set "FORWARD_ARGS="

set "STATUS_GIT=FAIL"
set "DETAIL_GIT=Not checked"

set "STATUS_NODE=FAIL"
set "DETAIL_NODE=Not checked"

set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Not checked"

set "STATUS_ORCA_APP=FAIL"
set "DETAIL_ORCA_APP=Not checked"

set "STATUS_ORCA_CLI=FAIL"
set "DETAIL_ORCA_CLI=Not checked"

set "STATUS_GH=FAIL"
set "DETAIL_GH=Not checked"

set "STATUS_GH_SSH=FAIL"
set "DETAIL_GH_SSH=Not checked"

set "STATUS_AGENTS=FAIL"
set "DETAIL_AGENTS=Not checked"

set "STATUS_JQ=FAIL"
set "DETAIL_JQ=Not checked"

set "STATUS_SKILLS=FAIL"
set "DETAIL_SKILLS=Not checked"

set "AGENTS_TO_INSTALL=claude,opencode"
if defined ONBOARD_AGENTS set "AGENTS_TO_INSTALL=%ONBOARD_AGENTS%"
set "OFFLINE_KIT_ARG="
if defined ONBOARD_OFFLINE_KIT set "OFFLINE_KIT_ARG=%ONBOARD_OFFLINE_KIT%"
set "OFFLINE_OS_DIR="
set "OFFLINE_NPM_CACHE="
set "NPM_CACHE_ARGS="

set "RECOVERY_COUNT=0"

REM ---------------------------------------------------------------------------
REM Parse Command-Line Arguments
REM ---------------------------------------------------------------------------
:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="--check-only" set "CHECK_ONLY=1" & set "FORWARD_ARGS=!FORWARD_ARGS! --check-only" & shift & goto :parse_args
if /I "%~1"=="--dry-run" set "CHECK_ONLY=1" & set "FORWARD_ARGS=!FORWARD_ARGS! --dry-run" & shift & goto :parse_args
if /I "%~1"=="--no-prompt" set "NO_PROMPT=1" & set "FORWARD_ARGS=!FORWARD_ARGS! --no-prompt" & shift & goto :parse_args
if /I "%~1"=="--non-interactive" set "NO_PROMPT=1" & set "FORWARD_ARGS=!FORWARD_ARGS! --non-interactive" & shift & goto :parse_args
if /I "%~1"=="--bootstrap" set "BOOTSTRAP_REQUESTED=1" & shift & goto :parse_args
if /I "%~1"=="--agents" goto :arg_agents
if /I "%~1"=="--offline-kit" goto :arg_offline_kit
if /I "%~1"=="--local-zip" goto :arg_local_zip
if /I "%~1"=="--zip-url" goto :arg_zip_url
if /I "%~1"=="--sha256" goto :arg_sha256
if /I "%~1"=="--help" goto :show_help
if /I "%~1"=="-h" goto :show_help
if /I "%~1"=="/?" goto :show_help

echo [ERROR] Unknown option: %~1
goto :show_help_error

:arg_local_zip
if "%~2"=="" echo [ERROR] --local-zip requires a file path argument. & goto :show_help_error
set "BOOTSTRAP_REQUESTED=1"
set "BOOTSTRAP_LOCAL_ZIP=%~2"
shift
shift
goto :parse_args

:arg_zip_url
if "%~2"=="" echo [ERROR] --zip-url requires a URL argument. & goto :show_help_error
set "BOOTSTRAP_REQUESTED=1"
set "BOOTSTRAP_ZIP_URL=%~2"
shift
shift
goto :parse_args

:arg_agents
if "%~2"=="" echo [ERROR] --agents requires a list such as claude,opencode or none. & goto :show_help_error
set "AGENTS_TO_INSTALL=%~2"
set "FORWARD_ARGS=!FORWARD_ARGS! --agents "%~2""
shift
shift
goto :parse_args

:arg_offline_kit
if "%~2"=="" echo [ERROR] --offline-kit requires the path of the '%OFFLINE_KIT_FOLDER%' folder. & goto :show_help_error
set "OFFLINE_KIT_ARG=%~2"
set "FORWARD_ARGS=!FORWARD_ARGS! --offline-kit "%~2""
shift
shift
goto :parse_args

:arg_sha256
if "%~2"=="" echo [ERROR] --sha256 requires a 64-character hex digest. & goto :show_help_error
set "BOOTSTRAP_SHA256=%~2"
shift
shift
goto :parse_args

:show_help
echo.
echo Usage: setup.bat [OPTIONS]
echo.
echo Windows onboarding script for the AI Development Event.
echo.
echo Options:
echo   --check-only, --dry-run        Verify installed tools without making changes
echo   --no-prompt, --non-interactive Do not pause for interactive browser prompts
echo   --agents "^<LIST^>"              AI agent CLIs: "claude,opencode" (default), claude, opencode, or none
echo                                  (quote a list: cmd.exe splits arguments at commas)
echo   --offline-kit ^<DIR^>            Use the event USB kit ('%OFFLINE_KIT_FOLDER%' folder) for offline installs
echo                                  (found automatically next to this repo, in Downloads, or on any USB drive)
echo   --bootstrap                    Download ^& extract full repository ZIP before running
echo   --local-zip ^<FILE^>             Bootstrap repository from a local .zip archive
echo   --zip-url ^<URL^>                Override repository ZIP download URL
echo   --sha256 ^<HASH^>                Verify ZIP archive against expected SHA-256 hash
echo   --help, -h, /?                 Show this help message and exit
echo.
exit /b 0

:show_help_error
echo Run "setup.bat --help" for usage instructions.
exit /b 2

:args_done

REM Auto-bootstrap if explicitly requested OR running standalone without repo context
if "%BOOTSTRAP_REQUESTED%"=="1" goto :check_do_bootstrap
if "%ONBOARD_SKIP_AUTO_BOOTSTRAP%"=="1" goto :run_main_setup
if not exist "%SCRIPT_DIR%README.md" if not exist "%SCRIPT_DIR%setup.zsh" goto :check_do_bootstrap
goto :run_main_setup

:check_do_bootstrap
call :run_standalone_bootstrap
set "BOOTSTRAP_RC=%ERRORLEVEL%"
endlocal & exit /b %BOOTSTRAP_RC%

:run_main_setup
REM ---------------------------------------------------------------------------
REM Main Execution Flow
REM ---------------------------------------------------------------------------
call :print_banner
call :detect_environment
call :check_network
call :setup_git
call :setup_node
call :setup_zepher
call :setup_orca_app
call :setup_orca_cli
call :setup_gh
call :setup_github_ssh
call :setup_agents
call :setup_jq
call :setup_skills
call :print_summary
set "FINAL_EXIT_CODE=%ERRORLEVEL%"
endlocal & exit /b %FINAL_EXIT_CODE%

REM ===========================================================================
REM Subroutines
REM ===========================================================================

:run_standalone_bootstrap
echo.
echo =============================================================================
echo   AI Development Event — Windows Standalone Repository Bootstrap
echo =============================================================================
echo   - Bootstrapping repository files into a verified temporary workspace...
echo -----------------------------------------------------------------------------

set "BOOTSTRAP_TMP_DIR=%TEMP%\onboard-bootstrap-%RANDOM%-%RANDOM%"
mkdir "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
if errorlevel 1 (
    echo     [FAIL] Could not create temporary directory: %BOOTSTRAP_TMP_DIR%
    exit /b 1
)

set "BOOTSTRAP_ZIP_FILE=%BOOTSTRAP_TMP_DIR%\repo.zip"
set "BOOTSTRAP_EXTRACT_DIR=%BOOTSTRAP_TMP_DIR%\extracted"

if defined BOOTSTRAP_LOCAL_ZIP (
    echo     [INFO] Bootstrapping from local ZIP archive: %BOOTSTRAP_LOCAL_ZIP%
    if not exist "%BOOTSTRAP_LOCAL_ZIP%" (
        echo     [FAIL] Local ZIP file not found: %BOOTSTRAP_LOCAL_ZIP%
        rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
        exit /b 1
    )
    copy /Y "%BOOTSTRAP_LOCAL_ZIP%" "%BOOTSTRAP_ZIP_FILE%" >nul 2>nul
    if errorlevel 1 (
        echo     [FAIL] Could not copy local ZIP file to temporary workspace.
        rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
        exit /b 1
    )
    goto :verify_bootstrap_zip
)

if "%BOOTSTRAP_ZIP_URL%"=="" goto :bootstrap_url_missing
if /I "%BOOTSTRAP_ZIP_URL%"=="<REPOSITORY_ZIP_URL>" goto :bootstrap_url_missing
echo "%BOOTSTRAP_ZIP_URL%" | find "<" >nul 2>nul
if not errorlevel 1 goto :bootstrap_url_missing

if /I not "!BOOTSTRAP_ZIP_URL:~0,8!"=="https://" (
    echo     [FAIL] Refusing insecure or non-HTTPS ZIP URL: %BOOTSTRAP_ZIP_URL%
    rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
    exit /b 1
)

where curl >nul 2>nul
if errorlevel 1 (
    echo     [FAIL] 'curl.exe' was not found on PATH to download the repository archive.
    echo     [INFO] Please download the ZIP in your browser and run:
    echo            setup.bat --local-zip "C:\path\to\repo.zip"
    rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
    exit /b 1
)

echo     [INFO] Downloading repository archive from: %BOOTSTRAP_ZIP_URL%
curl -fL --retry 2 --connect-timeout 10 -o "%BOOTSTRAP_ZIP_FILE%" "%BOOTSTRAP_ZIP_URL%"
if errorlevel 1 (
    echo     [FAIL] Failed to download repository ZIP from %BOOTSTRAP_ZIP_URL%
    echo     [INFO] Please download the ZIP manually in your browser and run:
    echo            setup.bat --local-zip "%%USERPROFILE%%\Downloads\<repo>.zip"
    rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
    exit /b 1
)
goto :verify_bootstrap_zip

:bootstrap_url_missing
echo     [ACTION REQUIRED] Repository ZIP URL placeholder has not been configured yet.
echo     Please download the repository ZIP from GitHub and run:
echo       setup.bat --local-zip "%%USERPROFILE%%\Downloads\<repo>.zip"
rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
exit /b 1

:verify_bootstrap_zip
if not exist "%BOOTSTRAP_ZIP_FILE%" (
    echo     [FAIL] Downloaded archive file is missing.
    rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
    exit /b 1
)

if defined BOOTSTRAP_SHA256 (
    set "ACTUAL_BOOT_SHA="
    for /f "skip=1 tokens=1" %%H in ('certutil -hashfile "%BOOTSTRAP_ZIP_FILE%" SHA256 2^>nul') do (
        if not defined ACTUAL_BOOT_SHA set "ACTUAL_BOOT_SHA=%%H"
    )
    if /I not "!ACTUAL_BOOT_SHA!"=="%BOOTSTRAP_SHA256%" (
        echo     [FAIL] SHA-256 checksum mismatch for repository ZIP!
        echo            Expected: %BOOTSTRAP_SHA256%
        echo            Actual  : !ACTUAL_BOOT_SHA!
        rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
        exit /b 1
    )
    echo     [PASS] SHA-256 checksum verified (!ACTUAL_BOOT_SHA!).
)

mkdir "%BOOTSTRAP_EXTRACT_DIR%" >nul 2>nul

where tar >nul 2>nul
if not errorlevel 1 (
    tar -tf "%BOOTSTRAP_ZIP_FILE%" >nul 2>nul
    if errorlevel 1 (
        echo     [FAIL] File is not a valid ZIP archive or failed integrity check.
        rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
        exit /b 1
    )
    echo     [PASS] ZIP archive integrity verified.
    echo     [INFO] Extracting repository archive...
    tar -xf "%BOOTSTRAP_ZIP_FILE%" -C "%BOOTSTRAP_EXTRACT_DIR%"
    if errorlevel 1 (
        echo     [FAIL] Failed to extract ZIP archive.
        rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
        exit /b 1
    )
    goto :find_extracted_setup
)

powershell -NoProfile -Command "Expand-Archive -LiteralPath '%BOOTSTRAP_ZIP_FILE%' -DestinationPath '%BOOTSTRAP_EXTRACT_DIR%' -Force" >nul 2>nul
if errorlevel 1 (
    echo     [FAIL] Failed to extract ZIP archive via Expand-Archive.
    rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
    exit /b 1
)
echo     [PASS] ZIP archive extracted and verified.

:find_extracted_setup
set "EXTRACTED_SETUP_BAT="
for /f "delims=" %%F in ('dir /b /s "%BOOTSTRAP_EXTRACT_DIR%\setup.bat" 2^>nul') do (
    if not defined EXTRACTED_SETUP_BAT set "EXTRACTED_SETUP_BAT=%%F"
)

if not defined EXTRACTED_SETUP_BAT (
    echo     [FAIL] Could not locate 'setup.bat' inside extracted archive.
    rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
    exit /b 1
)

echo     [PASS] Extracted and launching setup.bat...
echo.
set "ONBOARD_SKIP_AUTO_BOOTSTRAP=1"
call "!EXTRACTED_SETUP_BAT!" %FORWARD_ARGS%
set "EXTRACTED_BAT_RC=%ERRORLEVEL%"
rmdir /s /q "%BOOTSTRAP_TMP_DIR%" >nul 2>nul
exit /b %EXTRACTED_BAT_RC%

:print_banner
echo.
echo =============================================================================
echo   AI Development Event — Windows Environment Onboarding (setup.bat)
echo =============================================================================
echo This script independently detects and prepares your required event tools:
echo   1. Git CLI                 (Git for Windows)
echo   2. Node.js ^& npm           (JavaScript runtime ^>= v%MIN_NODE_MAJOR% LTS ^& package manager)
echo   3. Zepher CLI              (npm package: %ZEPHER_NPM_PACKAGE% -^> '%ZEPHER_BIN_NAME%')
echo   4. Orca Desktop App        (Agent Development Environment)
echo   5. Orca CLI                ('orca' command registered via Orca Settings)
echo   6. GitHub CLI              ('gh' command)
echo   7. GitHub over SSH         (gh login in your browser + SSH key for git)
echo   8. AI agent CLIs           (%AGENTS_TO_INSTALL%; you sign in to them yourself)
echo   9. jq                      (JSON tool used by the event's GitHub skills)
echo  10. Event skills            (copied into %%USERPROFILE%%\.claude\skills)
echo.
echo Privacy ^& Security:
echo   - Works even if Git and winget are not pre-installed.
echo   - Existing working installations are preserved and never overwritten.
echo   - Standalone downloads are verified with SHA-256 checksums via certutil.
echo   - Prefers per-user install paths (%LocalAppData%\Programs) to avoid admin prompts.
echo   - No API keys, tokens, or personal credentials are requested or collected.
echo     (You sign in to GitHub yourself in the browser; gh stores its token in Windows Credential Manager.)
if "%CHECK_ONLY%"=="1" echo. & echo [MODE] Running in --check-only mode (no installations will be performed).
echo -----------------------------------------------------------------------------
exit /b 0

:add_recovery
set /a RECOVERY_COUNT+=1
set "RECOVERY_%RECOVERY_COUNT%=%~1"
exit /b 0

:add_path_if_exists
REM %~1 = directory to add, %~2 = optional required file inside directory
if "%~1"=="" exit /b 0
if not exist "%~1" exit /b 0
if not "%~2"=="" if not exist "%~1\%~2" exit /b 0
echo ";!PATH!;" | find /I ";%~1;" >nul 2>nul
if errorlevel 1 set "PATH=!PATH!;%~1"
exit /b 0

:refresh_path
REM Refresh current session PATH with standard per-user & system Windows locations
REM (In-memory only; never overwrites system/user Registry PATH directly)
if "%ONBOARD_DISABLE_PATH_REFRESH%"=="1" exit /b 0
call :add_path_if_exists "%LocalAppData%\Programs\Git\cmd" "git.exe"
call :add_path_if_exists "%ProgramFiles%\Git\cmd" "git.exe"
call :add_path_if_exists "%ProgramFiles(x86)%\Git\cmd" "git.exe"
call :add_path_if_exists "%LocalAppData%\Programs\nodejs" "node.exe"
call :add_path_if_exists "%ProgramFiles%\nodejs" "node.exe"
call :add_path_if_exists "%ProgramFiles(x86)%\nodejs" "node.exe"
call :add_path_if_exists "%AppData%\npm" ""
call :add_path_if_exists "%LocalAppData%\Volta\bin" "volta.exe"
call :add_path_if_exists "%LocalAppData%\Programs\Orca" ""
call :add_path_if_exists "%ProgramFiles%\GitHub CLI" "gh.exe"
call :add_path_if_exists "%LocalAppData%\Programs\GitHub CLI" "gh.exe"
call :add_path_if_exists "%LocalAppData%\Programs\gh\bin" "gh.exe"
call :add_path_if_exists "%LocalAppData%\Microsoft\WinGet\Links" ""
call :add_path_if_exists "%LocalAppData%\Programs\jq" "jq.exe"
if defined ONBOARD_USER_GH_DIR call :add_path_if_exists "%ONBOARD_USER_GH_DIR%\bin" "gh.exe"
exit /b 0

:detect_environment
echo.
echo ==^> Step 0: Detecting Operating System ^& Independent Tool States
echo     [INFO] Running script    : setup.bat (Windows Command Prompt)
echo     [INFO] Architecture      : %PROCESSOR_ARCHITECTURE%
for /f "tokens=*" %%V in ('ver 2^>nul') do if not "%%V"=="" echo     [INFO] Windows Version   : %%V

net session >nul 2>nul
if errorlevel 1 goto :not_admin
set "IS_ADMIN=1"
echo     [INFO] Privilege Level   : Administrator Command Prompt
goto :check_winget

:not_admin
set "IS_ADMIN=0"
echo     [INFO] Privilege Level   : Standard User (per-user installs preferred; UAC only if needed)

:check_winget
call :refresh_path
if "%ONBOARD_FORCE_NO_WINGET%"=="1" goto :no_winget_found
where winget >nul 2>nul
if errorlevel 1 goto :no_winget_found
set "HAS_WINGET=1"
set "WINGET_VER="
for /f "tokens=*" %%W in ('winget --version 2^>nul') do set "WINGET_VER=%%W"
echo     [INFO] Detect winget     : Found (winget !WINGET_VER!)
goto :detect_other_tools

:no_winget_found
set "HAS_WINGET=0"
echo     [INFO] Detect winget     : Not installed (will use official standalone installers / steps)

:detect_other_tools
where git >nul 2>nul
if errorlevel 1 echo     [INFO] Detect Git CLI    : Not found
if not errorlevel 1 echo     [INFO] Detect Git CLI    : Found on PATH

where node >nul 2>nul
if errorlevel 1 echo     [INFO] Detect Node.js    : Not found
if not errorlevel 1 echo     [INFO] Detect Node.js    : Found on PATH

where npm >nul 2>nul
if errorlevel 1 echo     [INFO] Detect npm        : Not found
if not errorlevel 1 echo     [INFO] Detect npm        : Found on PATH

where %ZEPHER_BIN_NAME% >nul 2>nul
if errorlevel 1 echo     [INFO] Detect Zepher CLI : Not found
if not errorlevel 1 echo     [INFO] Detect Zepher CLI : Found on PATH

call :find_orca_windows
if errorlevel 1 echo     [INFO] Detect Orca App   : Not found
if not errorlevel 1 echo     [INFO] Detect Orca App   : Found (!FOUND_ORCA_PATH!)

where orca >nul 2>nul
if errorlevel 1 echo     [INFO] Detect Orca CLI   : Not found
if not errorlevel 1 echo     [INFO] Detect Orca CLI   : Found on PATH

where gh >nul 2>nul
if errorlevel 1 echo     [INFO] Detect GitHub CLI : Not found
if not errorlevel 1 echo     [INFO] Detect GitHub CLI : Found on PATH

call :detect_offline_kit
if errorlevel 1 echo     [INFO] Detect USB kit    : Not found (installs will use the internet)
if not errorlevel 1 echo     [INFO] Detect USB kit    : Found (!OFFLINE_OS_DIR!) - used for npm packages, jq and Orca
exit /b 0

:check_network
echo.
echo ==^> Step 1: Checking Network Connectivity
if "%ONBOARD_SIMULATE_OFFLINE%"=="1" goto :network_simulated_offline

where curl >nul 2>nul
if errorlevel 1 goto :network_try_ping

curl -fsSI --max-time 8 "https://registry.npmjs.org" >nul 2>nul
if not errorlevel 1 goto :network_ok

curl -fsSI --max-time 8 "%ORCA_WEBSITE_URL%" >nul 2>nul
if not errorlevel 1 goto :network_ok

:network_try_ping
ping -n 1 -w 4000 registry.npmjs.org >nul 2>nul
if not errorlevel 1 goto :network_ok

set "NETWORK_AVAILABLE=0"
echo     [ACTION REQUIRED] Unable to reach external package servers (https://registry.npmjs.org).
echo     [INFO] Already-installed tools will still be checked, but downloads require internet access.
exit /b 0

:network_simulated_offline
set "NETWORK_AVAILABLE=0"
echo     [ACTION REQUIRED] Network check simulated as OFFLINE (ONBOARD_SIMULATE_OFFLINE=1).
exit /b 0

:network_ok
set "NETWORK_AVAILABLE=1"
echo     [PASS] Internet connection verified.
exit /b 0

REM ---------------------------------------------------------------------------
REM Offline USB Kit & npm Helpers
REM ---------------------------------------------------------------------------
:detect_offline_kit
REM Finds the Windows folder of the event USB kit ('Beyond the Prompt\Windows'), given either
REM the kit folder or its Windows folder, next to this repo, in Downloads, or on any drive.
set "OFFLINE_OS_DIR="
if defined OFFLINE_KIT_ARG call :kit_try "%OFFLINE_KIT_ARG%"
if not defined OFFLINE_OS_DIR call :kit_try "%SCRIPT_DIR%.."
if not defined OFFLINE_OS_DIR call :kit_try "%SCRIPT_DIR%..\.."
if not defined OFFLINE_OS_DIR call :kit_try "%USERPROFILE%\Downloads"
if not defined OFFLINE_OS_DIR call :kit_try "%USERPROFILE%\Downloads\%OFFLINE_KIT_FOLDER%"
if not defined OFFLINE_OS_DIR for %%D in (D E F G H I J K L M N O P Q R S T U V W X Y Z) do call :kit_try_drive %%D
if defined OFFLINE_OS_DIR exit /b 0
exit /b 1

:kit_try_drive
REM 'vol' first, so empty card readers never pop up a "no disk" dialog
if defined OFFLINE_OS_DIR exit /b 0
vol %~1: >nul 2>nul
if errorlevel 1 exit /b 0
if exist "%~1:\%OFFLINE_KIT_FOLDER%\Windows" call :kit_try "%~1:\%OFFLINE_KIT_FOLDER%"
exit /b 0

:kit_try
if "%~1"=="" exit /b 0
if exist "%~1\Windows\npm-offline-cache.zip" set "OFFLINE_OS_DIR=%~f1\Windows" & exit /b 0
if exist "%~1\Windows\npm-offline-cache\_cacache" set "OFFLINE_OS_DIR=%~f1\Windows" & exit /b 0
if /I "%~nx1"=="Windows" if exist "%~1\npm-offline-cache.zip" set "OFFLINE_OS_DIR=%~f1" & exit /b 0
exit /b 0

:kit_sha256_for
REM %~1 = kit file path as listed in SHA256SUMS.txt; sets KIT_SHA (empty if unknown)
set "KIT_SHA="
if not defined OFFLINE_OS_DIR exit /b 0
if not exist "%OFFLINE_OS_DIR%\..\SHA256SUMS.txt" exit /b 0
for /f "tokens=1,2" %%A in ('findstr /C:"%~1" "%OFFLINE_OS_DIR%\..\SHA256SUMS.txt" 2^>nul') do if "%%B"=="%~1" set "KIT_SHA=%%A"
exit /b 0

:prepare_offline_npm_cache
REM Makes the kit's npm cache usable: an extracted copy inside your user folder is used in
REM place; anything else (the USB stick) is extracted once to %LocalAppData%, because npm
REM writes to its cache.
if defined OFFLINE_NPM_CACHE exit /b 0
if not defined OFFLINE_OS_DIR exit /b 1
if not exist "%OFFLINE_OS_DIR%\npm-offline-cache\_cacache" goto :npm_cache_from_zip
set "KIT_OUTSIDE_PROFILE=!OFFLINE_OS_DIR:%USERPROFILE%=!"
if "!KIT_OUTSIDE_PROFILE!"=="!OFFLINE_OS_DIR!" goto :npm_cache_from_zip
set "OFFLINE_NPM_CACHE=%OFFLINE_OS_DIR%\npm-offline-cache"
goto :npm_cache_ready

:npm_cache_from_zip
if not exist "%OFFLINE_OS_DIR%\npm-offline-cache.zip" exit /b 1
set "NPM_CACHE_DEST=%LocalAppData%\beyond-the-prompt"
if exist "%NPM_CACHE_DEST%\npm-offline-cache\_cacache" goto :npm_cache_extracted
echo     [INFO] Extracting the USB kit's offline npm cache to %%LocalAppData%%\beyond-the-prompt (one time, about a minute)...
mkdir "%NPM_CACHE_DEST%" >nul 2>nul
tar -xf "%OFFLINE_OS_DIR%\npm-offline-cache.zip" -C "%NPM_CACHE_DEST%"
if errorlevel 1 echo     [INFO] Could not extract the kit's npm cache; npm will use the internet instead. & exit /b 1

:npm_cache_extracted
set "OFFLINE_NPM_CACHE=%NPM_CACHE_DEST%\npm-offline-cache"

:npm_cache_ready
REM --prefer-offline uses the kit for everything it holds and the internet only for the rest;
REM --offline when there is no internet at all. npm checks every cached tarball's integrity hash.
if "%NETWORK_AVAILABLE%"=="1" set "NPM_CACHE_ARGS=--prefer-offline --cache "!OFFLINE_NPM_CACHE!""
if not "%NETWORK_AVAILABLE%"=="1" set "NPM_CACHE_ARGS=--offline --cache "!OFFLINE_NPM_CACHE!""
exit /b 0

:npm_global_install
REM Installs npm packages globally (per-user %AppData%\npm), using the kit's cache when present.
call :prepare_offline_npm_cache
if defined OFFLINE_NPM_CACHE echo     [INFO] Using the offline npm cache from the USB kit (!OFFLINE_NPM_CACHE!).
echo     [INFO] Running: npm install -g %*
call npm install -g --no-audit --no-fund !NPM_CACHE_ARGS! %*
exit /b %ERRORLEVEL%

REM ---------------------------------------------------------------------------
REM 1. Git CLI
REM ---------------------------------------------------------------------------
:setup_git
echo.
echo ==^> Step 2: Checking Git CLI
call :refresh_path

where git >nul 2>nul
if errorlevel 1 goto :git_missing

set "GIT_VER="
for /f "tokens=*" %%G in ('git --version 2^>nul') do set "GIT_VER=%%G"
if not defined GIT_VER goto :git_missing

set "STATUS_GIT=SKIPPED"
set "DETAIL_GIT=Already installed (!GIT_VER!)"
echo     [SKIPPED] Git is already installed and available on PATH: !GIT_VER!
exit /b 0

:git_missing
echo     [INFO] Git CLI was not found on PATH.
echo     [INFO] Bootstrap Note: If you haven't cloned the repo yet, use 'bootstrap.bat' or GitHub's 'Download ZIP'.

if "%CHECK_ONLY%"=="1" goto :git_fail_check_only
if not "%NETWORK_AVAILABLE%"=="1" goto :git_fail_offline
if not "%HAS_WINGET%"=="1" goto :git_no_winget

echo     [INFO] Installing Git for Windows via winget ('winget install --id %WINGET_GIT_ID% --scope user -e --source winget')...
echo     [INFO] Attempting per-user scope first; if unsupported, standard winget install will run.
winget install --id "%WINGET_GIT_ID%" --scope user -e --source winget >nul 2>nul
if errorlevel 1 winget install --id "%WINGET_GIT_ID%" -e --source winget
set "WINGET_GIT_RC=%ERRORLEVEL%"

call :refresh_path
where git >nul 2>nul
if errorlevel 1 goto :git_install_failed

set "GIT_VER="
for /f "tokens=*" %%G in ('git --version 2^>nul') do set "GIT_VER=%%G"
if not defined GIT_VER goto :git_install_failed

set "STATUS_GIT=PASS"
set "DETAIL_GIT=Installed via winget (!GIT_VER!)"
set "NEW_TERMINAL_ADVISED=1"
echo     [PASS] Git installed and verified: !GIT_VER!
exit /b 0

:git_install_failed
if "%WINGET_GIT_RC%"=="0" goto :git_needs_new_terminal
set "STATUS_GIT=FAIL"
set "DETAIL_GIT=winget installation failed (exit code !WINGET_GIT_RC!)"
echo     [FAIL] Could not verify Git on PATH after winget installation attempt.
echo     [INFO] Official Git for Windows download: %GIT_WINDOWS_URL%
call :add_recovery "Git CLI: Open a new Command Prompt window and re-run setup.bat, or install Git manually from %GIT_WINDOWS_URL%."
exit /b 0

:git_needs_new_terminal
set "STATUS_GIT=ACTION REQUIRED"
set "DETAIL_GIT=Installer completed; open a new Command Prompt to refresh PATH"
set "NEW_TERMINAL_ADVISED=1"
echo     [ACTION REQUIRED] Git installer completed, but this Command Prompt session needs a PATH refresh.
echo     [INFO] Open a NEW Command Prompt window and re-run setup.bat to verify 'git --version'.
call :add_recovery "Git CLI: Open a new Command Prompt window so the updated PATH takes effect, then re-run setup.bat."
exit /b 0

:git_fail_check_only
set "STATUS_GIT=FAIL"
set "DETAIL_GIT=Missing (not installed; ran with --check-only)"
echo     [FAIL] Git is not installed.
call :add_recovery "Git CLI: Re-run 'setup.bat' without --check-only, or download Git for Windows from %GIT_WINDOWS_URL%."
exit /b 0

:git_fail_offline
set "STATUS_GIT=FAIL"
set "DETAIL_GIT=Missing and cannot install while offline"
echo     [FAIL] Git is missing and network connectivity is unavailable.
call :add_recovery "Git CLI: Connect to the internet and install Git from %GIT_WINDOWS_URL%."
exit /b 0

:git_no_winget
echo     [INFO] Windows Package Manager (winget) is not available on this system.
echo     [INFO] This script will NOT install an unofficial package manager.
echo     [INFO] Official Git for Windows standalone installer page: %GIT_WINDOWS_URL%

if "%NO_PROMPT%"=="1" goto :git_no_winget_manual

echo     [INFO] Opening official Git for Windows download page in your default browser...
start "" "%GIT_WINDOWS_URL%" >nul 2>nul
echo     [INFO] 1. Download and run the official Git for Windows Setup (.exe).
echo     [INFO] 2. Tip: Select 'Only show new options' or default settings (per-user install works without admin).
echo     [INFO] 3. Once the Git installer finishes, press any key here to re-check...
pause >nul

call :refresh_path
where git >nul 2>nul
if errorlevel 1 goto :git_no_winget_manual

set "GIT_VER="
for /f "tokens=*" %%G in ('git --version 2^>nul') do set "GIT_VER=%%G"
if not defined GIT_VER goto :git_no_winget_manual

set "STATUS_GIT=PASS"
set "DETAIL_GIT=Installed via official standalone installer (!GIT_VER!)"
set "NEW_TERMINAL_ADVISED=1"
echo     [PASS] Git installed and verified: !GIT_VER!
exit /b 0

:git_no_winget_manual
set "STATUS_GIT=ACTION REQUIRED"
set "DETAIL_GIT=winget unavailable; install official standalone Git from %GIT_WINDOWS_URL%"
echo     [ACTION REQUIRED] Please install Git using the official standalone installer at:
echo     [INFO]   %GIT_WINDOWS_URL%
echo     [INFO] After installation finishes, open a NEW Command Prompt and re-run setup.bat.
call :add_recovery "Git CLI: Download and run the official Git for Windows standalone installer from %GIT_WINDOWS_URL%, open a new Command Prompt, and re-run setup.bat."
exit /b 0

REM ---------------------------------------------------------------------------
REM 2. Node.js and npm (winget or Official Verified Standalone Per-User Archive)
REM ---------------------------------------------------------------------------
:install_node_standalone_windows
set "WIN_NODE_ARCH=x64"
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "WIN_NODE_ARCH=arm64"

echo     [INFO] Using official Node.js v22 LTS standalone per-user distribution (win-!WIN_NODE_ARCH!)...
echo     [INFO] Fetching official SHA-256 checksum manifest: %NODE_DIST_BASE_URL%/SHASUMS256.txt

where curl >nul 2>nul
if errorlevel 1 exit /b 1
where tar >nul 2>nul
if errorlevel 1 exit /b 1
where certutil >nul 2>nul
if errorlevel 1 exit /b 1

set "NODE_TMP_DIR=%TEMP%\node-standalone-%RANDOM%-%RANDOM%"
mkdir "%NODE_TMP_DIR%" >nul 2>nul
if errorlevel 1 exit /b 1

set "SHASUMS_FILE=%NODE_TMP_DIR%\SHASUMS256.txt"
curl -fsSL --retry 2 --connect-timeout 10 -o "%SHASUMS_FILE%" "%NODE_DIST_BASE_URL%/SHASUMS256.txt"
if errorlevel 1 goto :node_std_cleanup_fail

set "EXPECTED_NODE_SHA="
set "NODE_ZIP_NAME="
for /f "tokens=1,2" %%A in ('findstr /R /C:"node-v[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*-win-!WIN_NODE_ARCH!\.zip$" "%SHASUMS_FILE%" 2^>nul') do (
    if not defined NODE_ZIP_NAME (
        set "EXPECTED_NODE_SHA=%%A"
        set "NODE_ZIP_NAME=%%B"
    )
)
if not defined NODE_ZIP_NAME goto :node_std_cleanup_fail
if not defined EXPECTED_NODE_SHA goto :node_std_cleanup_fail

set "NODE_ZIP_PATH=%NODE_TMP_DIR%\!NODE_ZIP_NAME!"
echo     [INFO] Downloading official standalone archive: %NODE_DIST_BASE_URL%/!NODE_ZIP_NAME!
curl -fL --retry 2 --connect-timeout 15 -o "%NODE_ZIP_PATH%" "%NODE_DIST_BASE_URL%/!NODE_ZIP_NAME!"
if errorlevel 1 goto :node_std_cleanup_fail

echo     [INFO] Verifying SHA-256 checksum via certutil against official Node.js manifest...
set "ACTUAL_NODE_SHA="
for /f "skip=1 tokens=1" %%H in ('certutil -hashfile "%NODE_ZIP_PATH%" SHA256 2^>nul') do (
    if not defined ACTUAL_NODE_SHA set "ACTUAL_NODE_SHA=%%H"
)
if /I not "!ACTUAL_NODE_SHA!"=="!EXPECTED_NODE_SHA!" goto :node_std_sha_mismatch
echo     [PASS] Verified official SHA-256 checksum (!ACTUAL_NODE_SHA!).

set "USER_NODE_ROOT=%LocalAppData%\Programs\nodejs"
if defined ONBOARD_USER_NODE_DIR set "USER_NODE_ROOT=%ONBOARD_USER_NODE_DIR%"
echo     [INFO] Extracting Node.js per-user into '!USER_NODE_ROOT!' (no Administrator rights required)...

tar -xf "%NODE_ZIP_PATH%" -C "%NODE_TMP_DIR%"
if errorlevel 1 goto :node_std_cleanup_fail

set "EXTRACTED_SUBFOLDER=!NODE_ZIP_NAME:.zip=!"
if not exist "%NODE_TMP_DIR%\!EXTRACTED_SUBFOLDER!\node.exe" goto :node_std_cleanup_fail

mkdir "!USER_NODE_ROOT!" >nul 2>nul
xcopy /E /I /Y /Q "%NODE_TMP_DIR%\!EXTRACTED_SUBFOLDER!\*" "!USER_NODE_ROOT!\" >nul 2>nul
if errorlevel 1 goto :node_std_cleanup_fail

rmdir /s /q "%NODE_TMP_DIR%" >nul 2>nul
call :add_path_if_exists "!USER_NODE_ROOT!" "node.exe"
set "NEW_TERMINAL_ADVISED=1"
echo     [INFO] Note for future Command Prompt windows: Add '!USER_NODE_ROOT!' to your User PATH environment variable.
exit /b 0

:node_std_sha_mismatch
echo     [FAIL] SHA-256 checksum mismatch for !NODE_ZIP_NAME!! Aborting installation.
echo     [INFO] Expected: !EXPECTED_NODE_SHA!
echo     [INFO] Actual  : !ACTUAL_NODE_SHA!

:node_std_cleanup_fail
if exist "%NODE_TMP_DIR%" rmdir /s /q "%NODE_TMP_DIR%" >nul 2>nul
exit /b 1

:setup_node
echo.
echo ==^> Step 3: Checking Node.js (^>= v%MIN_NODE_MAJOR% LTS) and npm
call :refresh_path

set "DETECTED_NVM="
if defined NVM_HOME set "DETECTED_NVM=nvm-windows"
if exist "%AppData%\nvm\nvm.exe" set "DETECTED_NVM=nvm-windows"
if defined VOLTA_HOME set "DETECTED_NVM=Volta"
if exist "%LocalAppData%\Volta\bin\volta.exe" set "DETECTED_NVM=Volta"
if defined FNM_DIR set "DETECTED_NVM=fnm"

if defined DETECTED_NVM echo     [INFO] Detected Node version manager footprint: !DETECTED_NVM!

where node >nul 2>nul
if errorlevel 1 goto :node_missing

where npm >nul 2>nul
if errorlevel 1 goto :npm_missing_only

set "NODE_VER="
for /f "tokens=*" %%N in ('node --version 2^>nul') do set "NODE_VER=%%N"
set "NPM_VER="
for /f "tokens=*" %%M in ('call npm --version 2^>nul') do set "NPM_VER=%%M"

if not defined NODE_VER goto :node_missing
if not defined NPM_VER goto :npm_missing_only

REM Parse Node major version (strip leading 'v' and take first token before '.')
set "NODE_VER_CLEAN=!NODE_VER:v=!"
set "NODE_MAJOR=0"
for /f "tokens=1 delims=." %%A in ("!NODE_VER_CLEAN!") do set "NODE_MAJOR=%%A"

if !NODE_MAJOR! GEQ %MIN_NODE_MAJOR% goto :node_already_ok

echo     [ACTION REQUIRED] Detected Node.js !NODE_VER! (npm v!NPM_VER!), but %ZEPHER_NPM_PACKAGE% requires Node.js ^>= v%MIN_NODE_MAJOR%.0.0.
echo     [INFO] To avoid breaking your existing Node setup, this script will NOT overwrite it automatically.
set "STATUS_NODE=FAIL"
set "DETAIL_NODE=Installed Node !NODE_VER! is older than required v%MIN_NODE_MAJOR%+"
call :add_recovery "Node.js & npm: Upgrade Node.js to v%MIN_NODE_MAJOR%+ LTS using your version manager or the official installer at %NODE_DOWNLOAD_URL%."
exit /b 0

:node_already_ok
set "STATUS_NODE=SKIPPED"
set "DETAIL_NODE=Already installed (Node !NODE_VER!, npm v!NPM_VER!)"
echo     [SKIPPED] Compatible Node.js (!NODE_VER!) and npm (v!NPM_VER!) are already installed.
exit /b 0

:npm_missing_only
set "STATUS_NODE=FAIL"
set "DETAIL_NODE=Node.js is present, but 'npm' was not found on PATH"
echo     [FAIL] Node.js is installed, but 'npm' is missing from PATH.
call :add_recovery "Node.js & npm: Reinstall Node.js LTS (which includes npm) from %NODE_DOWNLOAD_URL% and open a new Command Prompt."
exit /b 0

:node_missing
echo     [INFO] Node.js and npm were not found on PATH.

if defined DETECTED_NVM goto :node_nvm_inactive
if "%CHECK_ONLY%"=="1" goto :node_fail_check_only
if not "%NETWORK_AVAILABLE%"=="1" goto :node_fail_offline
if not "%HAS_WINGET%"=="1" goto :node_try_standalone

echo     [INFO] Installing Node.js LTS via winget ('winget install --id %WINGET_NODE_ID% -e --source winget')...
echo     [INFO] Note: Windows User Account Control (UAC) may prompt you for permission to install Node.js.
winget install --id "%WINGET_NODE_ID%" -e --source winget
set "WINGET_NODE_RC=%ERRORLEVEL%"

call :refresh_path
where node >nul 2>nul
if errorlevel 1 goto :node_try_standalone
where npm >nul 2>nul
if errorlevel 1 goto :node_try_standalone

set "NODE_VER="
for /f "tokens=*" %%N in ('node --version 2^>nul') do set "NODE_VER=%%N"
set "NPM_VER="
for /f "tokens=*" %%M in ('call npm --version 2^>nul') do set "NPM_VER=%%M"

if not defined NODE_VER goto :node_try_standalone
if not defined NPM_VER goto :node_try_standalone

set "NODE_VER_CLEAN=!NODE_VER:v=!"
set "NODE_MAJOR=0"
for /f "tokens=1 delims=." %%A in ("!NODE_VER_CLEAN!") do set "NODE_MAJOR=%%A"

if !NODE_MAJOR! LSS %MIN_NODE_MAJOR% goto :node_try_standalone

set "STATUS_NODE=PASS"
set "DETAIL_NODE=Installed via winget (Node !NODE_VER!, npm v!NPM_VER!)"
set "NEW_TERMINAL_ADVISED=1"
echo     [PASS] Installed and verified Node.js (!NODE_VER!) and npm (v!NPM_VER!).
exit /b 0

:node_try_standalone
call :install_node_standalone_windows
if errorlevel 1 goto :node_install_failed

call :refresh_path
where node >nul 2>nul
if errorlevel 1 goto :node_install_failed
where npm >nul 2>nul
if errorlevel 1 goto :node_install_failed

set "NODE_VER="
for /f "tokens=*" %%N in ('node --version 2^>nul') do set "NODE_VER=%%N"
set "NPM_VER="
for /f "tokens=*" %%M in ('call npm --version 2^>nul') do set "NPM_VER=%%M"

if not defined NODE_VER goto :node_install_failed
if not defined NPM_VER goto :node_install_failed

set "NODE_VER_CLEAN=!NODE_VER:v=!"
set "NODE_MAJOR=0"
for /f "tokens=1 delims=." %%A in ("!NODE_VER_CLEAN!") do set "NODE_MAJOR=%%A"

if !NODE_MAJOR! LSS %MIN_NODE_MAJOR% goto :node_install_failed

set "STATUS_NODE=PASS"
set "DETAIL_NODE=Installed per-user standalone LTS (Node !NODE_VER!, npm v!NPM_VER!)"
echo     [PASS] Installed and verified standalone Node.js (!NODE_VER!) and npm (v!NPM_VER!).
exit /b 0

:node_install_failed
set "STATUS_NODE=FAIL"
set "DETAIL_NODE=Automatic installation failed; install official .msi from %NODE_DOWNLOAD_URL%"
echo     [FAIL] Could not automatically install and verify Node.js and npm.
echo     [INFO] Official Node.js LTS download: %NODE_DOWNLOAD_URL%
call :add_recovery "Node.js & npm: Download and run the official Node.js LTS Windows Installer (.msi) from %NODE_DOWNLOAD_URL%, open a new Command Prompt, and re-run setup.bat."
exit /b 0

:node_nvm_inactive
set "STATUS_NODE=ACTION REQUIRED"
set "DETAIL_NODE=Version manager (!DETECTED_NVM!) detected, but Node/npm not active on PATH"
echo     [ACTION REQUIRED] Detected !DETECTED_NVM!, but 'node' is not active on PATH.
echo     [INFO] Skipping system-wide Node installation to avoid conflicting with !DETECTED_NVM!.
call :add_recovery "Node.js & npm: Use !DETECTED_NVM! to install and activate Node.js LTS (e.g., 'nvm install lts' and 'nvm use lts'), or install from %NODE_DOWNLOAD_URL%."
exit /b 0

:node_fail_check_only
set "STATUS_NODE=FAIL"
set "DETAIL_NODE=Missing (not installed; ran with --check-only)"
echo     [FAIL] Node.js and npm are not installed.
call :add_recovery "Node.js & npm: Re-run 'setup.bat' without --check-only, or install Node.js LTS from %NODE_DOWNLOAD_URL%."
exit /b 0

:node_fail_offline
set "STATUS_NODE=FAIL"
set "DETAIL_NODE=Missing and cannot install while offline"
echo     [FAIL] Cannot install Node.js because network connectivity is unavailable.
call :add_recovery "Node.js & npm: Connect to the internet and install Node.js LTS from %NODE_DOWNLOAD_URL%."
exit /b 0

REM ---------------------------------------------------------------------------
REM 3. Zepher CLI (zepher-cli -> zepher)
REM ---------------------------------------------------------------------------
:setup_zepher
echo.
echo ==^> Step 4: Checking Zepher CLI (%ZEPHER_NPM_PACKAGE%)
call :refresh_path

REM Guard against accidental confusion with 'zephyr-cli'
if /I "%ZEPHER_NPM_PACKAGE%"=="zephyr-cli" goto :zepher_bad_pkg
if /I not "%ZEPHER_NPM_PACKAGE%"=="zepher-cli" goto :zepher_bad_pkg
goto :zepher_pkg_ok

:zepher_bad_pkg
set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Package identity mismatch (%ZEPHER_NPM_PACKAGE% != zepher-cli)"
echo     [FAIL] Refusing to install '%ZEPHER_NPM_PACKAGE%'. Only verified package 'zepher-cli' is allowed (do not confuse with 'zephyr-cli').
call :add_recovery "Zepher CLI: Ensure ZEPHER_NPM_PACKAGE is set to 'zepher-cli' (%ZEPHER_NPM_URL%)."
exit /b 0

:zepher_pkg_ok
where %ZEPHER_BIN_NAME% >nul 2>nul
if errorlevel 1 goto :zepher_missing

set "ZEPHER_VER="
for /f "tokens=*" %%Z in ('call "%ZEPHER_BIN_NAME%" --version 2^>nul') do set "ZEPHER_VER=%%Z"
if not defined ZEPHER_VER goto :zepher_missing

call "%ZEPHER_BIN_NAME%" --help >nul 2>nul
if errorlevel 1 goto :zepher_missing

set "STATUS_ZEPHER=SKIPPED"
set "DETAIL_ZEPHER=Already installed (%ZEPHER_BIN_NAME% v!ZEPHER_VER!)"
echo     [SKIPPED] Zepher CLI is already installed and verified: %ZEPHER_BIN_NAME% v!ZEPHER_VER!
exit /b 0

:zepher_missing
echo     [INFO] Zepher CLI ('%ZEPHER_BIN_NAME%') is not currently installed.

if "%STATUS_NODE%"=="PASS" goto :zepher_node_ready
if "%STATUS_NODE%"=="SKIPPED" goto :zepher_node_ready

set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Blocked because Node.js (^>= v%MIN_NODE_MAJOR%) ^& npm are not ready"
echo     [FAIL] Cannot install %ZEPHER_NPM_PACKAGE% because a compatible Node.js (^>= v%MIN_NODE_MAJOR%) and npm environment is not available.
call :add_recovery "Zepher CLI: First install Node.js LTS from %NODE_DOWNLOAD_URL%, then run 'npm install -g %ZEPHER_NPM_PACKAGE%'."
exit /b 0

:zepher_node_ready
if "%CHECK_ONLY%"=="1" goto :zepher_fail_check_only
call :prepare_offline_npm_cache
if not "%NETWORK_AVAILABLE%"=="1" if not defined OFFLINE_NPM_CACHE goto :zepher_fail_offline

REM Verify exact package identity on npm (or in the USB kit's npm cache) before installing
echo     [INFO] Verifying package identity for '%ZEPHER_NPM_PACKAGE%' against %ZEPHER_NPM_URL%...
set "REMOTE_PKG_NAME="
for /f "tokens=*" %%P in ('call npm view !NPM_CACHE_ARGS! "%ZEPHER_NPM_PACKAGE%" name 2^>nul') do set "REMOTE_PKG_NAME=%%P"
set "REMOTE_PKG_BIN="
for /f "tokens=*" %%B in ('call npm view !NPM_CACHE_ARGS! "%ZEPHER_NPM_PACKAGE%" "bin.%ZEPHER_BIN_NAME%" 2^>nul') do set "REMOTE_PKG_BIN=%%B"

if /I not "!REMOTE_PKG_NAME!"=="%ZEPHER_NPM_PACKAGE%" goto :zepher_verify_failed
if not defined REMOTE_PKG_BIN goto :zepher_verify_failed

echo     [INFO] Verified package '!REMOTE_PKG_NAME!' (executable '%ZEPHER_BIN_NAME%' -^> '!REMOTE_PKG_BIN!').
call :npm_global_install "%ZEPHER_NPM_PACKAGE%"
set "NPM_INSTALL_RC=%ERRORLEVEL%"

call :refresh_path
if not "!NPM_INSTALL_RC!"=="0" goto :zepher_install_failed

where %ZEPHER_BIN_NAME% >nul 2>nul
if errorlevel 1 goto :zepher_install_failed

set "ZEPHER_VER="
for /f "tokens=*" %%Z in ('call "%ZEPHER_BIN_NAME%" --version 2^>nul') do set "ZEPHER_VER=%%Z"
if not defined ZEPHER_VER goto :zepher_install_failed

call "%ZEPHER_BIN_NAME%" --help >nul 2>nul
if errorlevel 1 goto :zepher_install_failed

set "STATUS_ZEPHER=PASS"
set "DETAIL_ZEPHER=Installed (%ZEPHER_BIN_NAME% v!ZEPHER_VER!)"
set "NEW_TERMINAL_ADVISED=1"
echo     [PASS] Zepher CLI installed and verified: %ZEPHER_BIN_NAME% v!ZEPHER_VER!
exit /b 0

:zepher_fail_check_only
set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Missing (not installed; ran with --check-only)"
echo     [FAIL] Zepher CLI (%ZEPHER_NPM_PACKAGE%) is not installed.
call :add_recovery "Zepher CLI: Run 'npm install -g %ZEPHER_NPM_PACKAGE%' and verify with '%ZEPHER_BIN_NAME% --version'."
exit /b 0

:zepher_fail_offline
set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Missing and cannot verify/install while offline"
echo     [FAIL] Cannot verify or install %ZEPHER_NPM_PACKAGE% without internet access.
call :add_recovery "Zepher CLI: Connect to the internet (or plug in the USB kit) and re-run setup.bat."
exit /b 0

:zepher_verify_failed
set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Could not verify '%ZEPHER_NPM_PACKAGE%' metadata on npm registry"
echo     [FAIL] Could not verify package identity or '%ZEPHER_BIN_NAME%' executable for '%ZEPHER_NPM_PACKAGE%' on npm.
echo     [INFO] Stopping installation step to avoid installing an unverified package. Official URL: %ZEPHER_NPM_URL%
call :add_recovery "Zepher CLI: Check your internet/npm connection and inspect %ZEPHER_NPM_URL%, then run 'npm install -g %ZEPHER_NPM_PACKAGE%'."
exit /b 0

:zepher_install_failed
set "STATUS_ZEPHER=FAIL"
set "DETAIL_ZEPHER=Installation or post-install verification failed"
echo     [FAIL] Failed to install or verify '%ZEPHER_NPM_PACKAGE%'.
echo     [INFO] Official package page: %ZEPHER_NPM_URL%
call :add_recovery "Zepher CLI: Open a new Command Prompt and run 'npm install -g %ZEPHER_NPM_PACKAGE%', then verify with '%ZEPHER_BIN_NAME% --version'."
exit /b 0

REM ---------------------------------------------------------------------------
REM 4. Orca Desktop Application (Orca.exe)
REM ---------------------------------------------------------------------------
:check_single_orca_path
if "%~1"=="" exit /b 1
if exist "%~1" set "FOUND_ORCA_PATH=%~1" & exit /b 0
exit /b 1

:find_orca_windows
set "FOUND_ORCA_PATH="
if defined ONBOARD_ORCA_EXE_PATH call :check_single_orca_path "%ONBOARD_ORCA_EXE_PATH%"
if defined FOUND_ORCA_PATH exit /b 0

call :check_single_orca_path "%LocalAppData%\Programs\Orca\Orca.exe"
if defined FOUND_ORCA_PATH exit /b 0

call :check_single_orca_path "%LocalAppData%\Programs\orca\Orca.exe"
if defined FOUND_ORCA_PATH exit /b 0

call :check_single_orca_path "%LocalAppData%\orca\Orca.exe"
if defined FOUND_ORCA_PATH exit /b 0

call :check_single_orca_path "%ProgramFiles%\Orca\Orca.exe"
if defined FOUND_ORCA_PATH exit /b 0

call :check_single_orca_path "%ProgramFiles(x86)%\Orca\Orca.exe"
if defined FOUND_ORCA_PATH exit /b 0

where orca >nul 2>nul
if errorlevel 1 exit /b 1

for /f "tokens=*" %%O in ('where orca 2^>nul') do if not defined FOUND_ORCA_PATH set "FOUND_ORCA_PATH=%%O"
if defined FOUND_ORCA_PATH exit /b 0
exit /b 1

:setup_orca_app
echo.
echo ==^> Step 5: Checking Orca Desktop Application
call :find_orca_windows
if errorlevel 1 goto :orca_app_not_found

set "STATUS_ORCA_APP=SKIPPED"
set "DETAIL_ORCA_APP=Already installed (!FOUND_ORCA_PATH!)"
echo     [SKIPPED] Orca desktop application is already installed at: !FOUND_ORCA_PATH!
exit /b 0

:orca_app_not_found
echo     [INFO] Orca desktop application was not detected in standard Windows installation directories.
echo     [INFO] Orca distributes its official Windows installer via:
echo     [INFO]   Official Install Docs     : %ORCA_INSTALL_DOCS_URL%
echo     [INFO]   Official Windows Installer: %ORCA_WINDOWS_INSTALLER_URL%
echo     [INFO]   (Note: Orca does not publish an official winget package ID; unattended silent install is not used for security.)

if "%CHECK_ONLY%"=="1" goto :orca_app_action_needed
if "%NO_PROMPT%"=="1" goto :orca_app_action_needed

call :install_orca_windows
if errorlevel 1 goto :orca_manual_install
call :find_orca_windows
if errorlevel 1 goto :orca_manual_install
set "STATUS_ORCA_APP=PASS"
set "DETAIL_ORCA_APP=Installed (!FOUND_ORCA_PATH!)"
echo     [PASS] Orca desktop application installed at: !FOUND_ORCA_PATH!
exit /b 0

:orca_manual_install
echo.
echo     [ACTION REQUIRED] Please install the Orca desktop application using the official installer.
echo     [INFO] Opening the official Orca installation page in your default web browser...
start "" "%ORCA_INSTALL_DOCS_URL%" >nul 2>nul
echo     [INFO] 1. Download and run the Windows installer from %ORCA_INSTALL_DOCS_URL%
echo     [INFO] 2. Complete the Orca setup wizard.
echo     [INFO] 3. Once installation finishes, press any key here to re-check...
pause >nul

call :find_orca_windows
if errorlevel 1 goto :orca_app_action_needed

set "STATUS_ORCA_APP=PASS"
set "DETAIL_ORCA_APP=Installed (!FOUND_ORCA_PATH!)"
echo     [PASS] Orca desktop application detected at: !FOUND_ORCA_PATH!
exit /b 0

:install_orca_windows
REM Gets the official installer (USB kit, else GitHub Releases), verifies it, and runs it.
set "ORCA_TMP_DIR=%TEMP%\orca-setup-%RANDOM%-%RANDOM%"
mkdir "%ORCA_TMP_DIR%" >nul 2>nul
if errorlevel 1 exit /b 1
set "ORCA_SETUP_EXE=%ORCA_TMP_DIR%\orca-windows-setup.exe"

REM Route 1: the USB kit, checked against the kit's SHA256SUMS.txt
if not defined OFFLINE_OS_DIR goto :orca_dl_online
if not exist "%OFFLINE_OS_DIR%\orca\orca-windows-setup.exe" goto :orca_dl_online
call :kit_sha256_for "Windows/orca/orca-windows-setup.exe"
if not defined KIT_SHA goto :orca_dl_online
echo     [INFO] Copying the Orca installer from the USB kit...
copy /Y "%OFFLINE_OS_DIR%\orca\orca-windows-setup.exe" "%ORCA_SETUP_EXE%" >nul
if errorlevel 1 goto :orca_dl_online
set "ACTUAL_ORCA_SHA="
for /f "skip=1 tokens=1" %%H in ('certutil -hashfile "%ORCA_SETUP_EXE%" SHA256 2^>nul') do if not defined ACTUAL_ORCA_SHA set "ACTUAL_ORCA_SHA=%%H"
if /I not "!ACTUAL_ORCA_SHA!"=="!KIT_SHA!" goto :orca_dl_online
echo     [PASS] Verified SHA-256 checksum of the kit installer (!ACTUAL_ORCA_SHA!).
goto :orca_run_installer

:orca_dl_online
REM Route 2: GitHub Releases, checked against the SHA-512 in Orca's latest.yml
if not "%NETWORK_AVAILABLE%"=="1" goto :orca_installer_failed
echo     [INFO] Downloading the official Orca installer: %ORCA_WINDOWS_INSTALLER_URL%
curl -fsSL --retry 2 --connect-timeout 10 -o "%ORCA_TMP_DIR%\latest.yml" "%ORCA_RELEASES_DOWNLOAD_URL%/latest.yml"
if errorlevel 1 goto :orca_installer_failed
set "EXPECTED_ORCA_SHA512="
for /f "tokens=1,2" %%A in ('findstr /B /C:"sha512:" "%ORCA_TMP_DIR%\latest.yml"') do if not defined EXPECTED_ORCA_SHA512 set "EXPECTED_ORCA_SHA512=%%B"
if not defined EXPECTED_ORCA_SHA512 goto :orca_installer_failed
curl -fL --retry 2 --connect-timeout 15 -o "%ORCA_SETUP_EXE%" "%ORCA_WINDOWS_INSTALLER_URL%"
if errorlevel 1 goto :orca_installer_failed
set "ACTUAL_ORCA_SHA512="
for /f "delims=" %%H in ('powershell -NoProfile -Command "$s=[IO.File]::OpenRead('%ORCA_SETUP_EXE%'); [Convert]::ToBase64String([Security.Cryptography.SHA512]::Create().ComputeHash($s)); $s.Close()" 2^>nul') do set "ACTUAL_ORCA_SHA512=%%H"
if not "!ACTUAL_ORCA_SHA512!"=="!EXPECTED_ORCA_SHA512!" goto :orca_installer_mismatch
echo     [PASS] Verified official SHA-512 checksum of orca-windows-setup.exe.

:orca_run_installer
echo     [INFO] Starting the Orca installer. Finish the setup wizard; this window waits for it.
start "" /wait "%ORCA_SETUP_EXE%"
rmdir /s /q "%ORCA_TMP_DIR%" >nul 2>nul
exit /b 0

:orca_installer_mismatch
echo     [FAIL] SHA-512 checksum mismatch for orca-windows-setup.exe! Refusing to run it.

:orca_installer_failed
if exist "%ORCA_TMP_DIR%" rmdir /s /q "%ORCA_TMP_DIR%" >nul 2>nul
exit /b 1

:orca_app_action_needed
set "STATUS_ORCA_APP=ACTION REQUIRED"
set "DETAIL_ORCA_APP=Manual installation required from %ORCA_INSTALL_DOCS_URL%"
echo     [ACTION REQUIRED] Orca desktop application is not yet installed.
call :add_recovery "Orca Desktop App: Download and run the official Windows installer from %ORCA_INSTALL_DOCS_URL% (%ORCA_WINDOWS_INSTALLER_URL%), then re-run setup.bat."
exit /b 0

REM ---------------------------------------------------------------------------
REM 5. Orca CLI (orca)
REM ---------------------------------------------------------------------------
:print_orca_cli_guide
echo     [INFO] How to enable and register the Orca CLI on Windows:
echo     [INFO]   1. Open the Orca desktop application.
echo     [INFO]   2. Navigate to: Settings -^> General -^> Orca CLI
echo     [INFO]   3. Click to register/enable the 'orca' command on your PATH.
echo     [INFO]   4. Open a NEW Command Prompt or PowerShell window so the updated PATH loads.
echo     [INFO]   5. Verify with: where orca ^&^& orca status --json
echo     [INFO]   Official CLI documentation: %ORCA_CLI_DOCS_URL%
exit /b 0

:setup_orca_cli
echo.
echo ==^> Step 6: Checking Orca CLI ('orca')
call :refresh_path
REM Never assume installing the desktop app automatically registers the CLI.
where orca >nul 2>nul
if errorlevel 1 goto :orca_cli_missing

set "ORCA_CLI_PATH="
for /f "tokens=*" %%C in ('where orca 2^>nul') do if not defined ORCA_CLI_PATH set "ORCA_CLI_PATH=%%C"
echo     [INFO] Found 'orca' executable on PATH: !ORCA_CLI_PATH!
echo     [INFO] Verifying with documented command: orca status --json

call orca status --json >nul 2>nul
if not errorlevel 1 goto :orca_cli_verified

call orca --help >nul 2>nul
if not errorlevel 1 goto :orca_cli_needs_running_app
call orca --version >nul 2>nul
if not errorlevel 1 goto :orca_cli_needs_running_app

set "STATUS_ORCA_CLI=FAIL"
set "DETAIL_ORCA_CLI=Found '!ORCA_CLI_PATH!', but execution failed"
echo     [FAIL] 'orca' was found at !ORCA_CLI_PATH!, but failed verification.
call :print_orca_cli_guide
call :add_recovery "Orca CLI: Re-register the CLI inside Orca under Settings -> General -> Orca CLI (see %ORCA_CLI_DOCS_URL%)."
exit /b 0

:orca_cli_verified
set "STATUS_ORCA_CLI=SKIPPED"
set "DETAIL_ORCA_CLI=Registered on PATH and verified ('orca status --json' succeeded)"
echo     [SKIPPED] Orca CLI is registered and verified via 'orca status --json'.
exit /b 0

:orca_cli_needs_running_app
set "STATUS_ORCA_CLI=ACTION REQUIRED"
set "DETAIL_ORCA_CLI=CLI is on PATH (!ORCA_CLI_PATH!), but 'orca status --json' requires Orca app to be running"
echo     [ACTION REQUIRED] 'orca' CLI is registered on PATH (!ORCA_CLI_PATH!), but 'orca status --json' could not reach a running Orca session.
echo     [INFO] Please launch the Orca desktop app and run 'orca status --json' to confirm full connectivity.
call :add_recovery "Orca CLI: Launch the Orca desktop application so 'orca status --json' can connect to the active Orca instance."
exit /b 0

:orca_cli_missing
set "STATUS_ORCA_CLI=ACTION REQUIRED"
if "%STATUS_ORCA_APP%"=="PASS" goto :orca_cli_app_present
if "%STATUS_ORCA_APP%"=="SKIPPED" goto :orca_cli_app_present

set "DETAIL_ORCA_CLI=Install Orca desktop app first, then register CLI in Settings -^> General -^> Orca CLI"
echo     [ACTION REQUIRED] The 'orca' CLI is not available on PATH (install Orca desktop app first).
goto :orca_cli_missing_finish

:orca_cli_app_present
set "DETAIL_ORCA_CLI=Orca app is installed, but 'orca' CLI is not yet registered on PATH"
echo     [ACTION REQUIRED] Orca desktop app is installed, but the 'orca' CLI is not yet registered on your PATH.

:orca_cli_missing_finish
call :print_orca_cli_guide
call :add_recovery "Orca CLI: Open the Orca app -> Settings -> General -> Orca CLI to register 'orca' on your PATH, open a new Command Prompt, and run 'orca status --json' (see %ORCA_CLI_DOCS_URL%)."
exit /b 0

REM ---------------------------------------------------------------------------
REM 6. GitHub CLI (winget or Official Verified Standalone Per-User Archive)
REM ---------------------------------------------------------------------------
:install_gh_standalone_windows
set "WIN_GH_ARCH=amd64"
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "WIN_GH_ARCH=arm64"

where curl >nul 2>nul
if errorlevel 1 exit /b 1
where tar >nul 2>nul
if errorlevel 1 exit /b 1
where certutil >nul 2>nul
if errorlevel 1 exit /b 1

REM Resolve the version through the releases/latest redirect instead of the GitHub API,
REM so a room full of laptops behind one IP does not hit the unauthenticated API limit.
echo     [INFO] Resolving the latest official GitHub CLI release from: %GH_RELEASES_LATEST_URL%
set "GH_TAG_URL="
for /f "delims=" %%U in ('curl -fsSLI -o NUL -w "%%{url_effective}" --retry 2 --connect-timeout 10 "%GH_RELEASES_LATEST_URL%" 2^>nul') do set "GH_TAG_URL=%%U"
if not defined GH_TAG_URL exit /b 1
set "GH_DL_VER=!GH_TAG_URL:*/tag/v=!"
if "!GH_DL_VER!"=="!GH_TAG_URL!" exit /b 1

set "GH_TMP_DIR=%TEMP%\gh-standalone-%RANDOM%-%RANDOM%"
mkdir "%GH_TMP_DIR%" >nul 2>nul
if errorlevel 1 exit /b 1

set "GH_ZIP_NAME=gh_!GH_DL_VER!_windows_!WIN_GH_ARCH!.zip"
set "GH_BASE_URL=%GH_RELEASES_DOWNLOAD_BASE_URL%/v!GH_DL_VER!"
echo     [INFO] Fetching official checksum manifest: !GH_BASE_URL!/gh_!GH_DL_VER!_checksums.txt
curl -fsSL --retry 2 --connect-timeout 10 -o "%GH_TMP_DIR%\checksums.txt" "!GH_BASE_URL!/gh_!GH_DL_VER!_checksums.txt"
if errorlevel 1 goto :gh_std_cleanup_fail

set "EXPECTED_GH_SHA="
for /f "tokens=1,2" %%A in ('findstr /C:"!GH_ZIP_NAME!" "%GH_TMP_DIR%\checksums.txt" 2^>nul') do (
    if /I "%%B"=="!GH_ZIP_NAME!" if not defined EXPECTED_GH_SHA set "EXPECTED_GH_SHA=%%A"
)
if not defined EXPECTED_GH_SHA goto :gh_std_cleanup_fail

echo     [INFO] Downloading official GitHub CLI archive: !GH_BASE_URL!/!GH_ZIP_NAME!
curl -fL --retry 2 --connect-timeout 15 -o "%GH_TMP_DIR%\!GH_ZIP_NAME!" "!GH_BASE_URL!/!GH_ZIP_NAME!"
if errorlevel 1 goto :gh_std_cleanup_fail

echo     [INFO] Verifying SHA-256 checksum via certutil against the official GitHub CLI manifest...
set "ACTUAL_GH_SHA="
for /f "skip=1 tokens=1" %%H in ('certutil -hashfile "%GH_TMP_DIR%\!GH_ZIP_NAME!" SHA256 2^>nul') do (
    if not defined ACTUAL_GH_SHA set "ACTUAL_GH_SHA=%%H"
)
if /I not "!ACTUAL_GH_SHA!"=="!EXPECTED_GH_SHA!" goto :gh_std_sha_mismatch
echo     [PASS] Verified official SHA-256 checksum (!ACTUAL_GH_SHA!).

set "USER_GH_ROOT=%LocalAppData%\Programs\gh"
if defined ONBOARD_USER_GH_DIR set "USER_GH_ROOT=%ONBOARD_USER_GH_DIR%"
echo     [INFO] Extracting GitHub CLI per-user into '!USER_GH_ROOT!' (no Administrator rights required)...
mkdir "!USER_GH_ROOT!" >nul 2>nul
tar -xf "%GH_TMP_DIR%\!GH_ZIP_NAME!" -C "!USER_GH_ROOT!"
if errorlevel 1 goto :gh_std_cleanup_fail
if not exist "!USER_GH_ROOT!\bin\gh.exe" goto :gh_std_cleanup_fail

rmdir /s /q "%GH_TMP_DIR%" >nul 2>nul
call :add_path_if_exists "!USER_GH_ROOT!\bin" "gh.exe"
set "NEW_TERMINAL_ADVISED=1"
echo     [INFO] Note for future Command Prompt windows: Add '!USER_GH_ROOT!\bin' to your User PATH environment variable.
exit /b 0

:gh_std_sha_mismatch
echo     [FAIL] SHA-256 checksum mismatch for !GH_ZIP_NAME!! Aborting installation.
echo     [INFO] Expected: !EXPECTED_GH_SHA!
echo     [INFO] Actual  : !ACTUAL_GH_SHA!

:gh_std_cleanup_fail
if exist "%GH_TMP_DIR%" rmdir /s /q "%GH_TMP_DIR%" >nul 2>nul
exit /b 1

:verify_gh_after_install
REM %~1 = how it was installed (used in the summary details)
where gh >nul 2>nul
if errorlevel 1 exit /b 1
set "GH_VER="
for /f "tokens=*" %%G in ('gh --version 2^>nul') do if not defined GH_VER set "GH_VER=%%G"
if not defined GH_VER exit /b 1
set "STATUS_GH=PASS"
set "DETAIL_GH=%~1 (!GH_VER!)"
set "NEW_TERMINAL_ADVISED=1"
echo     [PASS] GitHub CLI installed and verified: !GH_VER!
exit /b 0

:setup_gh
echo.
echo ==^> Step 7: Checking GitHub CLI ('gh')
call :refresh_path

where gh >nul 2>nul
if errorlevel 1 goto :gh_missing

set "GH_VER="
for /f "tokens=*" %%G in ('gh --version 2^>nul') do if not defined GH_VER set "GH_VER=%%G"
if not defined GH_VER goto :gh_missing

set "STATUS_GH=SKIPPED"
set "DETAIL_GH=Already installed (!GH_VER!)"
echo     [SKIPPED] GitHub CLI is already installed: !GH_VER!
exit /b 0

:gh_missing
echo     [INFO] GitHub CLI ('gh') was not found on PATH.

if "%CHECK_ONLY%"=="1" goto :gh_fail_check_only
if not "%NETWORK_AVAILABLE%"=="1" goto :gh_fail_offline
if not "%HAS_WINGET%"=="1" goto :gh_try_standalone

echo     [INFO] Installing GitHub CLI via winget ('winget install --id %WINGET_GH_ID% -e --source winget')...
echo     [INFO] Note: Windows User Account Control (UAC) may prompt you for permission to install GitHub CLI.
winget install --id "%WINGET_GH_ID%" -e --source winget
call :refresh_path
call :verify_gh_after_install "Installed via winget"
if not errorlevel 1 exit /b 0
echo     [INFO] winget installation did not complete; attempting the official standalone archive...

:gh_try_standalone
call :install_gh_standalone_windows
if errorlevel 1 goto :gh_install_failed
call :refresh_path
call :verify_gh_after_install "Installed per-user standalone"
if not errorlevel 1 exit /b 0

:gh_install_failed
set "STATUS_GH=FAIL"
set "DETAIL_GH=Automatic installation failed; install from %GH_CLI_URL%"
echo     [FAIL] Could not automatically install and verify GitHub CLI.
call :add_recovery "GitHub CLI: Download and run the official Windows installer (.msi) from %GH_CLI_URL%, open a new Command Prompt, and re-run setup.bat."
exit /b 0

:gh_fail_check_only
set "STATUS_GH=FAIL"
set "DETAIL_GH=Missing (not installed; ran with --check-only)"
echo     [FAIL] GitHub CLI is not installed.
call :add_recovery "GitHub CLI: Re-run 'setup.bat' without --check-only, or install from %GH_CLI_URL%."
exit /b 0

:gh_fail_offline
set "STATUS_GH=FAIL"
set "DETAIL_GH=Missing and cannot install while offline"
echo     [FAIL] Cannot install GitHub CLI because network connectivity is unavailable.
call :add_recovery "GitHub CLI: Connect to the internet and re-run setup.bat, or install from %GH_CLI_URL%."
exit /b 0

REM ---------------------------------------------------------------------------
REM 7. GitHub Authentication over SSH (gh login + SSH key + git identity)
REM ---------------------------------------------------------------------------
:find_ssh_tools
set "SSH_EXE="
set "SSH_KEYGEN_EXE="
set "SSH_ADD_EXE="
for /f "delims=" %%P in ('where ssh 2^>nul') do if not defined SSH_EXE set "SSH_EXE=%%P"
for /f "delims=" %%P in ('where ssh-keygen 2^>nul') do if not defined SSH_KEYGEN_EXE set "SSH_KEYGEN_EXE=%%P"
for /f "delims=" %%P in ('where ssh-add 2^>nul') do if not defined SSH_ADD_EXE set "SSH_ADD_EXE=%%P"
REM Fall back to Windows' built-in OpenSSH client, then to the copy bundled with Git for Windows
if not defined SSH_EXE if exist "%SystemRoot%\System32\OpenSSH\ssh.exe" set "SSH_EXE=%SystemRoot%\System32\OpenSSH\ssh.exe"
if not defined SSH_KEYGEN_EXE if exist "%SystemRoot%\System32\OpenSSH\ssh-keygen.exe" set "SSH_KEYGEN_EXE=%SystemRoot%\System32\OpenSSH\ssh-keygen.exe"
if not defined SSH_ADD_EXE if exist "%SystemRoot%\System32\OpenSSH\ssh-add.exe" set "SSH_ADD_EXE=%SystemRoot%\System32\OpenSSH\ssh-add.exe"
if not defined SSH_EXE if exist "%ProgramFiles%\Git\usr\bin\ssh.exe" set "SSH_EXE=%ProgramFiles%\Git\usr\bin\ssh.exe"
if not defined SSH_KEYGEN_EXE if exist "%ProgramFiles%\Git\usr\bin\ssh-keygen.exe" set "SSH_KEYGEN_EXE=%ProgramFiles%\Git\usr\bin\ssh-keygen.exe"
if not defined SSH_EXE if exist "%LocalAppData%\Programs\Git\usr\bin\ssh.exe" set "SSH_EXE=%LocalAppData%\Programs\Git\usr\bin\ssh.exe"
if not defined SSH_KEYGEN_EXE if exist "%LocalAppData%\Programs\Git\usr\bin\ssh-keygen.exe" set "SSH_KEYGEN_EXE=%LocalAppData%\Programs\Git\usr\bin\ssh-keygen.exe"
if not defined SSH_EXE exit /b 1
if not defined SSH_KEYGEN_EXE exit /b 1
exit /b 0

:github_ssh_probe
REM %~1 = extra ssh options. Sets GH_PROBE to ok / denied / hostkey / unreachable
REM and GH_PROBE_LOGIN on success. 'ssh -T git@github.com' exits 1 even on success,
REM so the result is read from its message.
set "GH_PROBE=unreachable"
set "GH_PROBE_LOGIN="
set "GH_PROBE_FILE=%TEMP%\gh-ssh-probe-%RANDOM%-%RANDOM%.txt"
"%SSH_EXE%" -T -o ConnectTimeout=10 -o StrictHostKeyChecking=yes %~1 git@github.com > "!GH_PROBE_FILE!" 2>&1 < nul
findstr /C:"successfully authenticated" "!GH_PROBE_FILE!" >nul 2>nul
if not errorlevel 1 goto :ghp_ok
findstr /C:"Host key verification failed" /C:"REMOTE HOST IDENTIFICATION HAS CHANGED" "!GH_PROBE_FILE!" >nul 2>nul
if not errorlevel 1 set "GH_PROBE=hostkey" & goto :ghp_done
findstr /C:"Permission denied" "!GH_PROBE_FILE!" >nul 2>nul
if not errorlevel 1 set "GH_PROBE=denied"
goto :ghp_done

:ghp_ok
set "GH_PROBE=ok"
REM The line reads "Hi <login>! You've successfully authenticated..."; delayed expansion
REM drops the lone "!" that follows the login when the token is assigned.
for /f "tokens=2" %%A in ('findstr /C:"successfully authenticated" "!GH_PROBE_FILE!"') do if not defined GH_PROBE_LOGIN set "GH_PROBE_LOGIN=%%A"

:ghp_done
del "!GH_PROBE_FILE!" >nul 2>nul
exit /b 0

:ensure_github_known_hosts
REM Trust GitHub's host keys as published by the GitHub API over authenticated HTTPS,
REM instead of accepting whatever key answers on first connect.
REM %~1 = 1 to replace existing GitHub entries first.
set "GH_KH=%USERPROFILE%\.ssh\known_hosts"
set "GH_META_FILE=%TEMP%\gh-meta-%RANDOM%-%RANDOM%.txt"
gh api meta --jq ".ssh_keys[]" > "!GH_META_FILE!" 2>nul
if errorlevel 1 goto :ghkh_fail
for %%F in ("!GH_META_FILE!") do if %%~zF EQU 0 goto :ghkh_fail
if not exist "%USERPROFILE%\.ssh" mkdir "%USERPROFILE%\.ssh"
if not exist "!GH_KH!" type nul > "!GH_KH!"
call :ghkh_host "github.com" "%~1"
call :ghkh_host "[ssh.github.com]:443" "%~1"
del "!GH_META_FILE!" >nul 2>nul
exit /b 0

:ghkh_fail
echo     [INFO] Could not fetch GitHub's published SSH host keys ('gh api meta').
del "!GH_META_FILE!" >nul 2>nul
exit /b 1

:ghkh_host
if "%~2"=="1" "%SSH_KEYGEN_EXE%" -R "%~1" -f "!GH_KH!" >nul 2>nul
"%SSH_KEYGEN_EXE%" -F "%~1" -f "!GH_KH!" >nul 2>nul
if not errorlevel 1 exit /b 0
for /f "usebackq delims=" %%K in ("!GH_META_FILE!") do >>"!GH_KH!" echo %~1 %%K
echo     [INFO] Added GitHub's official SSH host keys for %~1 to %%USERPROFILE%%\.ssh\known_hosts.
exit /b 0

:write_github_ssh_config_443
REM Prepends one marked 'Host github.com' block that routes SSH through port 443.
set "GH_SSH_CFG=%USERPROFILE%\.ssh\config"
set "GH_CFG_TMP=%USERPROFILE%\.ssh\config.tmp-beyond-the-prompt"
if not exist "!GH_SSH_CFG!" goto :ghcfg_write
findstr /C:"%SSH_CONFIG_BLOCK_BEGIN%" "!GH_SSH_CFG!" >nul 2>nul
if not errorlevel 1 exit /b 0
copy /Y "!GH_SSH_CFG!" "!GH_SSH_CFG!.bak-beyond-the-prompt" >nul
echo     [INFO] Backed up %%USERPROFILE%%\.ssh\config to config.bak-beyond-the-prompt

:ghcfg_write
> "!GH_CFG_TMP!" echo %SSH_CONFIG_BLOCK_BEGIN%
>>"!GH_CFG_TMP!" echo Host github.com
>>"!GH_CFG_TMP!" echo   HostName ssh.github.com
>>"!GH_CFG_TMP!" echo   Port 443
>>"!GH_CFG_TMP!" echo   User git
>>"!GH_CFG_TMP!" echo %SSH_CONFIG_BLOCK_END%
>>"!GH_CFG_TMP!" echo.
if exist "!GH_SSH_CFG!" type "!GH_SSH_CFG!" >> "!GH_CFG_TMP!"
move /Y "!GH_CFG_TMP!" "!GH_SSH_CFG!" >nul
echo     [INFO] Added a managed 'Host github.com' block at the top of %%USERPROFILE%%\.ssh\config.
exit /b 0

:configure_git_identity
REM Only fills in a missing global user.name / user.email; never replaces existing values.
where git >nul 2>nul
if errorlevel 1 exit /b 0
set "GIT_CUR_NAME="
set "GIT_CUR_EMAIL="
for /f "delims=" %%N in ('git config --global user.name 2^>nul') do set "GIT_CUR_NAME=%%N"
for /f "delims=" %%E in ('git config --global user.email 2^>nul') do set "GIT_CUR_EMAIL=%%E"
if defined GIT_CUR_NAME if defined GIT_CUR_EMAIL echo     [INFO] Git identity already set: !GIT_CUR_NAME! ^<!GIT_CUR_EMAIL!^> & exit /b 0

set "GH_USER_ID="
set "GH_USER_LOGIN="
set "GH_USER_NAME="
for /f "delims=" %%A in ('gh api user --jq .id 2^>nul') do set "GH_USER_ID=%%A"
for /f "delims=" %%A in ('gh api user --jq .login 2^>nul') do set "GH_USER_LOGIN=%%A"
for /f "delims=" %%A in ('gh api user --jq .name 2^>nul') do set "GH_USER_NAME=%%A"
if not defined GH_USER_ID goto :git_identity_unknown
if not defined GH_USER_LOGIN goto :git_identity_unknown
if not defined GH_USER_NAME set "GH_USER_NAME=!GH_USER_LOGIN!"

if not defined GIT_CUR_NAME git config --global user.name "!GH_USER_NAME!"
if not defined GIT_CUR_NAME echo     [INFO] Set Git user.name to '!GH_USER_NAME!'.
if not defined GIT_CUR_EMAIL git config --global user.email "!GH_USER_ID!+!GH_USER_LOGIN!@users.noreply.github.com"
if not defined GIT_CUR_EMAIL echo     [INFO] Set Git user.email to your GitHub no-reply address (!GH_USER_ID!+!GH_USER_LOGIN!@users.noreply.github.com).
exit /b 0

:git_identity_unknown
echo     [INFO] Could not read your GitHub profile to set the Git identity; set it with 'git config --global user.name/user.email'.
exit /b 0

:setup_github_ssh
echo.
echo ==^> Step 8: Checking GitHub authentication over SSH (gh login + SSH key)
if "%STATUS_GH%"=="PASS" goto :ghs_gh_ready
if "%STATUS_GH%"=="SKIPPED" goto :ghs_gh_ready
set "STATUS_GH_SSH=FAIL"
set "DETAIL_GH_SSH=Blocked because GitHub CLI is not ready"
echo     [FAIL] Cannot configure GitHub authentication until the GitHub CLI ('gh') is installed.
call :add_recovery "GitHub over SSH: Install GitHub CLI first (%GH_CLI_URL%), then re-run setup.bat."
exit /b 0

:ghs_gh_ready
call :find_ssh_tools
if not errorlevel 1 goto :ghs_tools_ready
set "STATUS_GH_SSH=FAIL"
set "DETAIL_GH_SSH=OpenSSH client (ssh, ssh-keygen) not found"
echo     [FAIL] OpenSSH client tools were not found.
call :add_recovery "GitHub over SSH: Enable 'OpenSSH Client' under Settings -> System -> Optional features (or install Git for Windows), open a new Command Prompt, and re-run setup.bat."
exit /b 0

:ghs_tools_ready
set "GH_SSH_KEY=%USERPROFILE%\.ssh\id_ed25519"
if defined ONBOARD_SSH_KEY_PATH set "GH_SSH_KEY=%ONBOARD_SSH_KEY_PATH%"
set "GHS_AGENT_FAILED=0"
set "GHS_USED_443=0"

REM Current state
set "GHS_AUTH_FILE=%TEMP%\gh-auth-status-%RANDOM%-%RANDOM%.txt"
set "GHS_LOGGED_IN=0"
gh auth status --hostname github.com > "!GHS_AUTH_FILE!" 2>&1
if not errorlevel 1 set "GHS_LOGGED_IN=1"
set "GHS_HAS_PROJECT=0"
findstr /C:"'project'" "!GHS_AUTH_FILE!" >nul 2>nul
if not errorlevel 1 set "GHS_HAS_PROJECT=1"
set "GHS_HAS_KEYSCOPE=0"
findstr /C:"'admin:public_key'" "!GHS_AUTH_FILE!" >nul 2>nul
if not errorlevel 1 set "GHS_HAS_KEYSCOPE=1"
del "!GHS_AUTH_FILE!" >nul 2>nul
set "GHS_PROTOCOL="
for /f "delims=" %%P in ('gh config get git_protocol --host github.com 2^>nul') do set "GHS_PROTOCOL=%%P"
call :github_ssh_probe "-o BatchMode=yes"

if not "!GHS_LOGGED_IN!"=="1" goto :ghs_needs_setup
if not "!GHS_HAS_PROJECT!"=="1" goto :ghs_needs_setup
if /I not "!GHS_PROTOCOL!"=="ssh" goto :ghs_needs_setup
if not "!GH_PROBE!"=="ok" goto :ghs_needs_setup

set "STATUS_GH_SSH=SKIPPED"
set "DETAIL_GH_SSH=Already set up (gh + SSH as !GH_PROBE_LOGIN!)"
echo     [SKIPPED] gh is logged in, uses SSH for git, and 'ssh -T git@github.com' authenticates as !GH_PROBE_LOGIN!.
if not "%CHECK_ONLY%"=="1" call :configure_git_identity
exit /b 0

:ghs_needs_setup
echo     [INFO] Current state: gh logged in=!GHS_LOGGED_IN!, 'project' scope=!GHS_HAS_PROJECT!, git protocol=!GHS_PROTOCOL!, SSH to GitHub=!GH_PROBE!

if "%CHECK_ONLY%"=="1" goto :ghs_fail_check_only
if not "%NETWORK_AVAILABLE%"=="1" goto :ghs_fail_offline
if defined GH_TOKEN goto :ghs_env_token
if defined GITHUB_TOKEN goto :ghs_env_token
if "%NO_PROMPT%"=="1" goto :ghs_needs_interactive

REM 1. Sign in to gh (browser device flow), or add missing scopes to an existing login
if "!GHS_LOGGED_IN!"=="1" goto :ghs_refresh_scopes
echo     [INFO] Signing in to GitHub. Copy the one-time code printed below, press Enter, and approve it in your browser.
gh auth login --hostname github.com --git-protocol ssh --web --skip-ssh-key --scopes "%GH_AUTH_SCOPES%"
if errorlevel 1 goto :ghs_login_failed
goto :ghs_signed_in

:ghs_refresh_scopes
set "GHS_NEEDED_SCOPES="
if not "!GHS_HAS_PROJECT!"=="1" set "GHS_NEEDED_SCOPES=project"
if not "!GH_PROBE!"=="ok" if not "!GHS_HAS_KEYSCOPE!"=="1" set "GHS_NEEDED_SCOPES=%GH_AUTH_SCOPES%"
if not defined GHS_NEEDED_SCOPES goto :ghs_signed_in
echo     [INFO] Adding token scopes '!GHS_NEEDED_SCOPES!' to your existing gh login (approve it in your browser)...
gh auth refresh --hostname github.com --scopes "!GHS_NEEDED_SCOPES!"
if errorlevel 1 goto :ghs_refresh_failed

:ghs_signed_in
gh config set git_protocol ssh --host github.com >nul 2>nul
set "GHS_LOGIN="
for /f "delims=" %%L in ('gh api user --jq .login 2^>nul') do set "GHS_LOGIN=%%L"
echo     [PASS] gh is signed in as !GHS_LOGIN! and set to use SSH for git.

REM 2. SSH key (an existing key is never overwritten)
if exist "!GH_SSH_KEY!" goto :ghs_key_exists
for %%D in ("!GH_SSH_KEY!") do if not exist "%%~dpD" mkdir "%%~dpD"
echo     [INFO] Creating a new ed25519 SSH key at !GH_SSH_KEY!
echo     [INFO] It has no passphrase so git works without extra prompts. Add one later with: ssh-keygen -p -f "!GH_SSH_KEY!"
"%SSH_KEYGEN_EXE%" -t ed25519 -C "!GHS_LOGIN!@beyond-the-prompt" -f "!GH_SSH_KEY!" -N ""
if errorlevel 1 goto :ghs_keygen_failed
goto :ghs_key_ready

:ghs_key_exists
echo     [INFO] Using existing SSH key: !GH_SSH_KEY!
if not exist "!GH_SSH_KEY!.pub" "%SSH_KEYGEN_EXE%" -y -f "!GH_SSH_KEY!" > "!GH_SSH_KEY!.pub" 2>nul

:ghs_key_ready
if not exist "!GH_SSH_KEY!.pub" goto :ghs_pub_missing
"%SSH_KEYGEN_EXE%" -y -P "" -f "!GH_SSH_KEY!" >nul 2>nul
if errorlevel 1 call :ghs_load_passphrase_key

REM Keep earlier choices: a previous run may have switched github.com to port 443
if exist "%USERPROFILE%\.ssh\config" findstr /C:"%SSH_CONFIG_BLOCK_BEGIN%" "%USERPROFILE%\.ssh\config" >nul 2>nul
if exist "%USERPROFILE%\.ssh\config" if not errorlevel 1 set "GHS_USED_443=1"

REM 3. Trust GitHub's host keys, then find a working route (port 22, else 443)
call :ensure_github_known_hosts 0
call :github_ssh_probe "-o BatchMode=yes"
if not "!GH_PROBE!"=="hostkey" goto :ghs_after_hostkey
echo     [INFO] Your known_hosts has an outdated GitHub host key; replacing it with GitHub's current keys...
call :ensure_github_known_hosts 1
call :github_ssh_probe "-o BatchMode=yes"

:ghs_after_hostkey
if not "!GH_PROBE!"=="unreachable" goto :ghs_after_route
call :github_ssh_probe "-o BatchMode=yes -o HostName=ssh.github.com -o Port=443"
if "!GH_PROBE!"=="unreachable" goto :ghs_after_route
echo     [INFO] SSH port 22 is blocked on this network; switching github.com to ssh.github.com port 443.
set "GHS_USED_443=1"
call :write_github_ssh_config_443
call :github_ssh_probe "-o BatchMode=yes"

:ghs_after_route
REM 4. Upload the public key if GitHub does not recognise it yet
if not "!GH_PROBE!"=="denied" goto :ghs_final
echo     [INFO] Uploading !GH_SSH_KEY!.pub to your GitHub account as 'beyond-the-prompt %COMPUTERNAME%'...
gh ssh-key add "!GH_SSH_KEY!.pub" --title "beyond-the-prompt %COMPUTERNAME%" --type authentication
call :github_ssh_probe "-o BatchMode=yes"

:ghs_final
if "!GH_PROBE!"=="ok" goto :ghs_success
if "!GHS_AGENT_FAILED!"=="1" goto :ghs_agent_action
set "STATUS_GH_SSH=FAIL"
if "!GH_PROBE!"=="unreachable" goto :ghs_fail_unreachable
if "!GH_PROBE!"=="hostkey" goto :ghs_fail_hostkey
set "DETAIL_GH_SSH=GitHub rejected the SSH key"
echo     [FAIL] GitHub did not accept !GH_SSH_KEY!.pub (upload may have failed, or the key is on another account).
call :add_recovery "GitHub over SSH: Run 'gh ssh-key add %%USERPROFILE%%\.ssh\id_ed25519.pub' and check https://github.com/settings/keys, then re-run setup.bat."
exit /b 0

:ghs_fail_unreachable
set "DETAIL_GH_SSH=GitHub SSH unreachable on ports 22 and 443"
echo     [FAIL] Could not reach GitHub over SSH on port 22 or 443 (network or firewall).
call :add_recovery "GitHub over SSH: This network blocks SSH. Try another network or hotspot, then re-run setup.bat (see %GH_SSH_DOCS_URL%)."
exit /b 0

:ghs_fail_hostkey
set "DETAIL_GH_SSH=GitHub host key could not be verified"
echo     [FAIL] GitHub's SSH host key could not be verified.
call :add_recovery "GitHub over SSH: Run 'ssh-keygen -R github.com', then re-run setup.bat."
exit /b 0

:ghs_success
if not defined GHS_LOGIN goto :ghs_success_ok
if /I "!GH_PROBE_LOGIN!"=="!GHS_LOGIN!" goto :ghs_success_ok
set "STATUS_GH_SSH=ACTION REQUIRED"
set "DETAIL_GH_SSH=SSH key belongs to '!GH_PROBE_LOGIN!', but gh is signed in as '!GHS_LOGIN!'"
echo     [ACTION REQUIRED] Your SSH key authenticates as '!GH_PROBE_LOGIN!', but gh is signed in as '!GHS_LOGIN!'.
call :add_recovery "GitHub over SSH: Use one GitHub account for both. Either 'gh auth login' as !GH_PROBE_LOGIN!, or set ONBOARD_SSH_KEY_PATH to a new key path (e.g. %%USERPROFILE%%\.ssh\id_ed25519_!GHS_LOGIN!) and re-run setup.bat."
exit /b 0

:ghs_success_ok
set "STATUS_GH_SSH=PASS"
set "DETAIL_GH_SSH=Signed in as !GH_PROBE_LOGIN!; git uses SSH"
if "!GHS_USED_443!"=="1" set "DETAIL_GH_SSH=!DETAIL_GH_SSH! (port 443)"
echo     [PASS] 'ssh -T git@github.com' authenticates as !GH_PROBE_LOGIN!.
call :configure_git_identity
exit /b 0

:ghs_load_passphrase_key
REM An existing key with a passphrase only works without prompts through the Windows
REM ssh-agent service; git must then use Windows' OpenSSH so it talks to that agent.
echo     [INFO] Your existing key has a passphrase; adding it to the Windows ssh-agent...
if not defined SSH_ADD_EXE set "GHS_AGENT_FAILED=1" & exit /b 0
"%SSH_ADD_EXE%" "!GH_SSH_KEY!"
if errorlevel 1 set "GHS_AGENT_FAILED=1" & exit /b 0
set "GHS_SSH_COMMAND="
for /f "delims=" %%C in ('git config --global core.sshCommand 2^>nul') do set "GHS_SSH_COMMAND=%%C"
if defined GHS_SSH_COMMAND exit /b 0
set "GHS_SSH_FWD=!SSH_EXE:\=/!"
git config --global core.sshCommand "\"!GHS_SSH_FWD!\""
echo     [INFO] Set git core.sshCommand to Windows OpenSSH so git uses the ssh-agent.
exit /b 0

:ghs_agent_action
set "STATUS_GH_SSH=ACTION REQUIRED"
set "DETAIL_GH_SSH=Key has a passphrase and the Windows ssh-agent is not running"
echo     [ACTION REQUIRED] Your SSH key has a passphrase, but the Windows ssh-agent service is not running.
call :add_recovery "GitHub over SSH: In an Administrator PowerShell run 'Get-Service ssh-agent | Set-Service -StartupType Automatic; Start-Service ssh-agent', then re-run setup.bat. Or set ONBOARD_SSH_KEY_PATH to a new key path and re-run to create a key without a passphrase."
exit /b 0

:ghs_fail_check_only
set "STATUS_GH_SSH=FAIL"
set "DETAIL_GH_SSH=Not configured (ran with --check-only)"
echo     [FAIL] GitHub authentication over SSH is not fully configured.
call :add_recovery "GitHub over SSH: Re-run 'setup.bat' without --check-only to sign in and set up your SSH key."
exit /b 0

:ghs_fail_offline
set "STATUS_GH_SSH=FAIL"
set "DETAIL_GH_SSH=Cannot sign in to GitHub while offline"
echo     [FAIL] GitHub sign-in needs internet access.
call :add_recovery "GitHub over SSH: Connect to the internet and re-run setup.bat."
exit /b 0

:ghs_env_token
set "STATUS_GH_SSH=ACTION REQUIRED"
set "DETAIL_GH_SSH=GH_TOKEN / GITHUB_TOKEN is set and overrides gh login"
echo     [ACTION REQUIRED] A GH_TOKEN or GITHUB_TOKEN environment variable is set; gh uses it instead of a normal login.
call :add_recovery "GitHub over SSH: Remove GH_TOKEN / GITHUB_TOKEN (System Properties -> Environment Variables), open a new Command Prompt, and re-run setup.bat."
exit /b 0

:ghs_needs_interactive
set "STATUS_GH_SSH=ACTION REQUIRED"
set "DETAIL_GH_SSH=Interactive browser sign-in required"
echo     [ACTION REQUIRED] GitHub sign-in needs an interactive Command Prompt and a browser.
call :add_recovery "GitHub over SSH: Re-run 'setup.bat' without --no-prompt to sign in to GitHub."
exit /b 0

:ghs_login_failed
set "STATUS_GH_SSH=FAIL"
set "DETAIL_GH_SSH=GitHub sign-in did not complete"
echo     [FAIL] 'gh auth login' did not complete.
call :add_recovery "GitHub over SSH: Run 'gh auth login --git-protocol ssh --web --scopes %GH_AUTH_SCOPES%' manually (or enter the code at https://github.com/login/device), then re-run setup.bat."
exit /b 0

:ghs_refresh_failed
set "STATUS_GH_SSH=FAIL"
set "DETAIL_GH_SSH=Could not add required token scopes (!GHS_NEEDED_SCOPES!)"
echo     [FAIL] 'gh auth refresh' did not complete.
call :add_recovery "GitHub over SSH: Run 'gh auth refresh --scopes !GHS_NEEDED_SCOPES!', then re-run setup.bat."
exit /b 0

:ghs_keygen_failed
set "STATUS_GH_SSH=FAIL"
set "DETAIL_GH_SSH=SSH key generation failed"
echo     [FAIL] ssh-keygen did not create a key.
call :add_recovery "GitHub over SSH: Run 'ssh-keygen -t ed25519' manually, then re-run setup.bat."
exit /b 0

:ghs_pub_missing
set "STATUS_GH_SSH=FAIL"
set "DETAIL_GH_SSH=Public key !GH_SSH_KEY!.pub is missing"
echo     [FAIL] Could not find or recreate the public key !GH_SSH_KEY!.pub
call :add_recovery "GitHub over SSH: Recreate it with: ssh-keygen -y -f %%USERPROFILE%%\.ssh\id_ed25519 > %%USERPROFILE%%\.ssh\id_ed25519.pub, then re-run setup.bat."
exit /b 0

REM ---------------------------------------------------------------------------
REM 8. AI Coding Agent CLIs (Claude Code, OpenCode) via npm
REM ---------------------------------------------------------------------------
:agent_check
REM %~1 = agent command (claude / opencode). Updates AGENTS_WANTED, AGENTS_FOUND, AGENTS_MISSING_PKGS.
set "AG_PKG="
if /I "%~1"=="claude" set "AG_PKG=%CLAUDE_CODE_NPM_PACKAGE%"
if /I "%~1"=="opencode" set "AG_PKG=%OPENCODE_NPM_PACKAGE%"
if not defined AG_PKG echo     [ACTION REQUIRED] Unknown agent '%~1' ignored (use claude, opencode, or none). & exit /b 0
set "AGENTS_WANTED=!AGENTS_WANTED! %~1"
where %~1 >nul 2>nul
if errorlevel 1 goto :agent_check_missing
set "AG_VER="
for /f "tokens=*" %%V in ('call %~1 --version 2^>nul') do if not defined AG_VER set "AG_VER=%%V"
if not defined AG_VER goto :agent_check_missing
set "AGENTS_FOUND=!AGENTS_FOUND! %~1 !AG_VER!;"
exit /b 0

:agent_check_missing
set "AGENTS_MISSING_PKGS=!AGENTS_MISSING_PKGS! !AG_PKG!"
exit /b 0

:npm_install_with_retry
call :npm_global_install %1
if not errorlevel 1 exit /b 0
echo     [INFO] Retrying %~1 once...
call :npm_global_install %1
exit /b 0

:add_agent_login_note
REM Signing in to an agent happens in the browser with the participant's own account.
set "AG_LOGIN_STEPS="
echo %AGENTS_WANTED% | findstr /I /C:"claude" >nul 2>nul
if not errorlevel 1 set "AG_LOGIN_STEPS=run 'claude' once and sign in with your Claude account"
echo %AGENTS_WANTED% | findstr /I /C:"opencode" >nul 2>nul
if not errorlevel 1 if defined AG_LOGIN_STEPS set "AG_LOGIN_STEPS=!AG_LOGIN_STEPS!; run 'opencode auth login' (or use its free models)"
if not errorlevel 1 if not defined AG_LOGIN_STEPS set "AG_LOGIN_STEPS=run 'opencode auth login' (or use its free models)"
if defined AG_LOGIN_STEPS call :add_recovery "Sign in to your AI agent before the event: !AG_LOGIN_STEPS!. On Windows, Claude Code uses Git Bash, which setup installed with Git."
exit /b 0

:setup_agents
echo.
echo ==^> Step 9: Checking AI coding agent CLIs (%AGENTS_TO_INSTALL%)
if /I "%AGENTS_TO_INSTALL%"=="none" goto :agents_none
call :refresh_path

set "AGENTS_WANTED="
set "AGENTS_FOUND="
set "AGENTS_MISSING_PKGS="
for %%A in (%AGENTS_TO_INSTALL:,= %) do call :agent_check %%A
if not defined AGENTS_WANTED goto :agents_invalid
if not defined AGENTS_MISSING_PKGS goto :agents_all_present

echo     [INFO] Not installed yet:!AGENTS_MISSING_PKGS!
if "%STATUS_NODE%"=="PASS" goto :agents_node_ready
if "%STATUS_NODE%"=="SKIPPED" goto :agents_node_ready
set "STATUS_AGENTS=FAIL"
set "DETAIL_AGENTS=Blocked because Node.js (^>= v%MIN_NODE_MAJOR%) ^& npm are not ready"
echo     [FAIL] Cannot install agent CLIs until Node.js and npm are ready.
call :add_recovery "AI agents: Install Node.js first, then re-run setup.bat."
exit /b 0

:agents_node_ready
if "%CHECK_ONLY%"=="1" goto :agents_fail_check_only
call :prepare_offline_npm_cache
if not "%NETWORK_AVAILABLE%"=="1" if not defined OFFLINE_NPM_CACHE goto :agents_fail_offline

echo     [INFO] Installing:!AGENTS_MISSING_PKGS! (a few hundred MB from the internet; seconds from the USB kit)...
REM One npm run per agent (retried once), so a failing agent never blocks the other
for %%P in (!AGENTS_MISSING_PKGS!) do call :npm_install_with_retry %%P
call :refresh_path

set "AGENTS_RECHECK=!AGENTS_WANTED!"
set "AGENTS_WANTED="
set "AGENTS_FOUND="
set "AGENTS_MISSING_PKGS="
for %%A in (!AGENTS_RECHECK!) do call :agent_check %%A
if defined AGENTS_MISSING_PKGS goto :agents_install_failed

set "STATUS_AGENTS=PASS"
set "DETAIL_AGENTS=Installed (!AGENTS_FOUND:~1!)"
set "NEW_TERMINAL_ADVISED=1"
echo     [PASS] Agent CLIs installed and verified:!AGENTS_FOUND!
call :add_agent_login_note
exit /b 0

:agents_all_present
set "STATUS_AGENTS=SKIPPED"
set "DETAIL_AGENTS=Already installed (!AGENTS_FOUND:~1!)"
echo     [SKIPPED] Agent CLIs already installed:!AGENTS_FOUND!
call :add_agent_login_note
exit /b 0

:agents_none
set "STATUS_AGENTS=SKIPPED"
set "DETAIL_AGENTS=Not requested (--agents none)"
echo     [SKIPPED] Agent installation skipped (--agents none).
exit /b 0

:agents_invalid
set "STATUS_AGENTS=FAIL"
set "DETAIL_AGENTS=No valid agent in --agents '%AGENTS_TO_INSTALL%'"
call :add_recovery "AI agents: Re-run with --agents "claude,opencode" (or claude / opencode / none)."
exit /b 0

:agents_fail_check_only
set "STATUS_AGENTS=FAIL"
set "DETAIL_AGENTS=Missing (!AGENTS_MISSING_PKGS:~1!; ran with --check-only)"
echo     [FAIL] Agent CLIs not installed:!AGENTS_MISSING_PKGS!
call :add_recovery "AI agents: Re-run 'setup.bat' without --check-only to install them."
exit /b 0

:agents_fail_offline
set "STATUS_AGENTS=FAIL"
set "DETAIL_AGENTS=Missing and cannot install while offline"
echo     [FAIL] Cannot install agent CLIs without internet access or the USB kit.
call :add_recovery "AI agents: Connect to the internet (or plug in the USB kit) and re-run setup.bat."
exit /b 0

:agents_install_failed
set "STATUS_AGENTS=FAIL"
set "DETAIL_AGENTS=Could not install or verify:!AGENTS_MISSING_PKGS!"
echo     [FAIL] Could not install or verify:!AGENTS_MISSING_PKGS!
call :add_recovery "AI agents: Open a new Command Prompt, run 'npm install -g!AGENTS_MISSING_PKGS!' and check the error (see %CLAUDE_CODE_URL% / %OPENCODE_URL%)."
exit /b 0

REM ---------------------------------------------------------------------------
REM 9. jq (JSON tool used by the event's GitHub workflow skills)
REM ---------------------------------------------------------------------------
:install_jq_standalone_windows
set "JQ_ASSET=jq-windows-amd64.exe"
if /I "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "JQ_ASSET=jq-windows-arm64.exe"
set "JQ_TMP_DIR=%TEMP%\jq-standalone-%RANDOM%-%RANDOM%"
mkdir "%JQ_TMP_DIR%" >nul 2>nul
if errorlevel 1 exit /b 1
set "JQ_SRC="
set "EXPECTED_JQ_SHA="

REM Route 1: the USB kit (x64 build; it also runs on ARM through emulation)
if not defined OFFLINE_OS_DIR goto :jq_dl_online
if not exist "%OFFLINE_OS_DIR%\jq\jq-windows-amd64.exe" goto :jq_dl_online
call :kit_sha256_for "Windows/jq/jq-windows-amd64.exe"
if not defined KIT_SHA goto :jq_dl_online
set "JQ_SRC=%OFFLINE_OS_DIR%\jq\jq-windows-amd64.exe"
set "EXPECTED_JQ_SHA=!KIT_SHA!"
echo     [INFO] Using jq from the USB kit: !JQ_SRC!
goto :jq_verify

:jq_dl_online
REM Route 2: the official GitHub release, checked against its sha256sum.txt
if not "%NETWORK_AVAILABLE%"=="1" goto :jq_std_fail
set "JQ_TAG_URL="
for /f "delims=" %%U in ('curl -fsSLI -o NUL -w "%%{url_effective}" --retry 2 --connect-timeout 10 "%JQ_RELEASES_LATEST_URL%" 2^>nul') do set "JQ_TAG_URL=%%U"
set "JQ_TAG=%JQ_FALLBACK_TAG%"
if defined JQ_TAG_URL set "JQ_TAG=!JQ_TAG_URL:*/tag/=!"
if defined JQ_TAG_URL if "!JQ_TAG!"=="!JQ_TAG_URL!" set "JQ_TAG=%JQ_FALLBACK_TAG%"
set "JQ_BASE_URL=%JQ_RELEASES_DOWNLOAD_BASE_URL%/!JQ_TAG!"
echo     [INFO] Downloading official jq from !JQ_BASE_URL!/!JQ_ASSET!
curl -fsSL --retry 2 --connect-timeout 10 -o "%JQ_TMP_DIR%\sha256sum.txt" "!JQ_BASE_URL!/sha256sum.txt"
if errorlevel 1 goto :jq_std_fail
curl -fL --retry 2 --connect-timeout 15 -o "%JQ_TMP_DIR%\!JQ_ASSET!" "!JQ_BASE_URL!/!JQ_ASSET!"
if errorlevel 1 goto :jq_std_fail
for /f "tokens=1,2" %%A in ('findstr /C:"!JQ_ASSET!" "%JQ_TMP_DIR%\sha256sum.txt" 2^>nul') do if "%%B"=="!JQ_ASSET!" set "EXPECTED_JQ_SHA=%%A"
set "JQ_SRC=%JQ_TMP_DIR%\!JQ_ASSET!"

:jq_verify
if not defined EXPECTED_JQ_SHA goto :jq_std_fail
set "ACTUAL_JQ_SHA="
for /f "skip=1 tokens=1" %%H in ('certutil -hashfile "!JQ_SRC!" SHA256 2^>nul') do if not defined ACTUAL_JQ_SHA set "ACTUAL_JQ_SHA=%%H"
if /I not "!ACTUAL_JQ_SHA!"=="!EXPECTED_JQ_SHA!" goto :jq_std_mismatch
echo     [PASS] Verified official SHA-256 checksum (!ACTUAL_JQ_SHA!).

REM %AppData%\npm is already on the user PATH after a Node.js install; otherwise use a per-user folder
set "JQ_DEST_DIR=%LocalAppData%\Programs\jq"
if exist "%AppData%\npm" set "JQ_DEST_DIR=%AppData%\npm"
mkdir "!JQ_DEST_DIR!" >nul 2>nul
copy /Y "!JQ_SRC!" "!JQ_DEST_DIR!\jq.exe" >nul
if errorlevel 1 goto :jq_std_fail
rmdir /s /q "%JQ_TMP_DIR%" >nul 2>nul
call :add_path_if_exists "!JQ_DEST_DIR!" "jq.exe"
set "NEW_TERMINAL_ADVISED=1"
exit /b 0

:jq_std_mismatch
echo     [FAIL] SHA-256 checksum mismatch for jq! Refusing to install.

:jq_std_fail
if exist "%JQ_TMP_DIR%" rmdir /s /q "%JQ_TMP_DIR%" >nul 2>nul
exit /b 1

:setup_jq
echo.
echo ==^> Step 10: Checking jq (used by the /new-issue, /start-task and /plan-project skills)
call :refresh_path
where jq >nul 2>nul
if errorlevel 1 goto :jq_missing
set "JQ_VER="
for /f "tokens=*" %%J in ('jq --version 2^>nul') do set "JQ_VER=%%J"
if not defined JQ_VER goto :jq_missing
set "STATUS_JQ=SKIPPED"
set "DETAIL_JQ=Already installed (!JQ_VER!)"
echo     [SKIPPED] jq is already installed: !JQ_VER!
exit /b 0

:jq_missing
echo     [INFO] jq was not found on PATH.
if "%CHECK_ONLY%"=="1" goto :jq_fail_check_only
if not "%HAS_WINGET%"=="1" goto :jq_try_standalone
if not "%NETWORK_AVAILABLE%"=="1" goto :jq_try_standalone
echo     [INFO] Installing jq via winget ('winget install --id %WINGET_JQ_ID% -e --source winget')...
winget install --id "%WINGET_JQ_ID%" -e --source winget
call :refresh_path
where jq >nul 2>nul
if not errorlevel 1 goto :jq_installed

:jq_try_standalone
call :install_jq_standalone_windows
if errorlevel 1 goto :jq_install_failed
where jq >nul 2>nul
if errorlevel 1 goto :jq_install_failed

:jq_installed
set "JQ_VER="
for /f "tokens=*" %%J in ('jq --version 2^>nul') do set "JQ_VER=%%J"
set "STATUS_JQ=PASS"
set "DETAIL_JQ=Installed (!JQ_VER!)"
set "NEW_TERMINAL_ADVISED=1"
echo     [PASS] jq installed and verified: !JQ_VER!
exit /b 0

:jq_fail_check_only
set "STATUS_JQ=FAIL"
set "DETAIL_JQ=Missing (not installed; ran with --check-only)"
echo     [FAIL] jq is not installed.
call :add_recovery "jq: Re-run 'setup.bat' without --check-only, or run 'winget install jqlang.jq'."
exit /b 0

:jq_install_failed
set "STATUS_JQ=FAIL"
set "DETAIL_JQ=Automatic installation failed"
echo     [FAIL] Could not install jq.
call :add_recovery "jq: Run 'winget install jqlang.jq', or download jq-windows-amd64.exe from %JQ_URL% and save it as %%AppData%%\npm\jq.exe."
exit /b 0

REM ---------------------------------------------------------------------------
REM 10. Event Skills (copied into Claude Code's skills folder)
REM ---------------------------------------------------------------------------
:skill_inspect
REM %~1 = skill folder path. Counts skills that are present / still to copy.
if not exist "%~1\SKILL.md" exit /b 0
if exist "%SKILLS_TARGET_DIR%\%~nx1" set /a SKILLS_PRESENT+=1 & exit /b 0
set /a SKILLS_TO_COPY+=1
exit /b 0

:skill_copy
REM %~1 = skill folder path. A skill that already exists is never replaced.
if not exist "%~1\SKILL.md" exit /b 0
if exist "%SKILLS_TARGET_DIR%\%~nx1" exit /b 0
xcopy /E /I /Q /Y "%~1" "%SKILLS_TARGET_DIR%\%~nx1" >nul 2>nul
if errorlevel 1 set "SKILLS_COPY_FAILED=!SKILLS_COPY_FAILED! %~nx1"
exit /b 0

:setup_skills
echo.
echo ==^> Step 11: Installing the event skills into Claude Code (%SKILLS_TARGET_DIR%)
if not exist "%SCRIPT_DIR%skills" goto :skills_missing_src

set "SKILLS_PRESENT=0"
set "SKILLS_TO_COPY=0"
for /d %%S in ("%SCRIPT_DIR%skills\*") do call :skill_inspect "%%~fS"
set /a SKILLS_TOTAL=SKILLS_PRESENT+SKILLS_TO_COPY

if !SKILLS_TO_COPY! EQU 0 goto :skills_all_present
if "%CHECK_ONLY%"=="1" goto :skills_fail_check_only

mkdir "%SKILLS_TARGET_DIR%" >nul 2>nul
set "SKILLS_COPY_FAILED="
for /d %%S in ("%SCRIPT_DIR%skills\*") do call :skill_copy "%%~fS"
if defined SKILLS_COPY_FAILED goto :skills_copy_failed

set "STATUS_SKILLS=PASS"
set "DETAIL_SKILLS=Installed !SKILLS_TO_COPY! skills (!SKILLS_PRESENT! already present, left unchanged)"
echo     [PASS] Copied !SKILLS_TO_COPY! event skills into %SKILLS_TARGET_DIR% (!SKILLS_PRESENT! already present were left unchanged).
echo     [INFO] Restart Claude Code to pick them up. Try /new-issue or /start-task inside your team repo.
exit /b 0

:skills_all_present
set "STATUS_SKILLS=SKIPPED"
set "DETAIL_SKILLS=All !SKILLS_TOTAL! event skills already present"
echo     [SKIPPED] All !SKILLS_TOTAL! event skills are already in %SKILLS_TARGET_DIR%.
exit /b 0

:skills_fail_check_only
set "STATUS_SKILLS=FAIL"
set "DETAIL_SKILLS=!SKILLS_TO_COPY! of !SKILLS_TOTAL! event skills not installed (ran with --check-only)"
echo     [FAIL] !SKILLS_TO_COPY! of !SKILLS_TOTAL! event skills are not installed.
call :add_recovery "Event skills: Re-run 'setup.bat' without --check-only to copy them into %SKILLS_TARGET_DIR%."
exit /b 0

:skills_missing_src
set "STATUS_SKILLS=FAIL"
set "DETAIL_SKILLS=skills\ folder not found next to setup.bat"
echo     [FAIL] The repo's skills\ folder was not found at %SCRIPT_DIR%skills.
call :add_recovery "Event skills: Re-download the repo (it contains skills\) and re-run setup.bat."
exit /b 0

:skills_copy_failed
set "STATUS_SKILLS=FAIL"
set "DETAIL_SKILLS=Could not copy:!SKILLS_COPY_FAILED!"
echo     [FAIL] Could not copy skills:!SKILLS_COPY_FAILED!
call :add_recovery "Event skills: Copy the folders from skills\ into %SKILLS_TARGET_DIR% by hand."
exit /b 0

REM ---------------------------------------------------------------------------
REM Final Summary & Readiness Report
REM ---------------------------------------------------------------------------
:pad_status
set "PAD_IN=%~1               "
set "PAD_OUT=!PAD_IN:~0,15!"
exit /b 0

:print_summary
echo.
echo =============================================================================
echo   Onboarding Setup Summary (Windows — %PROCESSOR_ARCHITECTURE%)
echo =============================================================================
echo   Component            Status          Details
echo   -------------------- --------------- --------------------------------------
call :pad_status "%STATUS_GIT%"
echo   1. Git CLI           !PAD_OUT! !DETAIL_GIT!
call :pad_status "%STATUS_NODE%"
echo   2. Node.js ^& npm     !PAD_OUT! !DETAIL_NODE!
call :pad_status "%STATUS_ZEPHER%"
echo   3. Zepher CLI        !PAD_OUT! !DETAIL_ZEPHER!
call :pad_status "%STATUS_ORCA_APP%"
echo   4. Orca Desktop App  !PAD_OUT! !DETAIL_ORCA_APP!
call :pad_status "%STATUS_ORCA_CLI%"
echo   5. Orca CLI          !PAD_OUT! !DETAIL_ORCA_CLI!
call :pad_status "%STATUS_GH%"
echo   6. GitHub CLI        !PAD_OUT! !DETAIL_GH!
call :pad_status "%STATUS_GH_SSH%"
echo   7. GitHub over SSH   !PAD_OUT! !DETAIL_GH_SSH!
call :pad_status "%STATUS_AGENTS%"
echo   8. AI agent CLIs     !PAD_OUT! !DETAIL_AGENTS!
call :pad_status "%STATUS_JQ%"
echo   9. jq                !PAD_OUT! !DETAIL_JQ!
call :pad_status "%STATUS_SKILLS%"
echo  10. Event skills      !PAD_OUT! !DETAIL_SKILLS!
echo -----------------------------------------------------------------------------
echo   Status Legend:
echo     PASS            = Installed and verified during this run.
echo     SKIPPED         = Already installed and verified (no reinstall needed).
echo     ACTION REQUIRED = Manual user action required (see next steps below).
echo     FAIL            = Required check or installation failed.
echo -----------------------------------------------------------------------------

if "%NEW_TERMINAL_ADVISED%"=="1" (
    echo.
    echo   [PATH Notice] New binaries were installed during this session.
    echo   Please open a NEW Command Prompt window after this script finishes so your
    echo   updated PATH is active in future terminal sessions.
)

set "FAIL_COUNT=0"
set "ACTION_COUNT=0"

for %%S in ("%STATUS_GIT%" "%STATUS_NODE%" "%STATUS_ZEPHER%" "%STATUS_ORCA_APP%" "%STATUS_ORCA_CLI%" "%STATUS_GH%" "%STATUS_GH_SSH%" "%STATUS_AGENTS%" "%STATUS_JQ%" "%STATUS_SKILLS%") do (
    if /I "%%~S"=="FAIL" set /a FAIL_COUNT+=1
    if /I "%%~S"=="ACTION REQUIRED" set /a ACTION_COUNT+=1
)

if !RECOVERY_COUNT! LEQ 0 goto :check_final_counts

echo.
echo Recommended Next Steps / Manual Actions:
for /L %%I in (1,1,!RECOVERY_COUNT!) do echo   %%I. !RECOVERY_%%I!
echo.
echo Official Documentation ^& Download Links:
echo   - Git CLI        : %GIT_WINDOWS_URL%
echo   - Node.js LTS    : %NODE_DOWNLOAD_URL%
echo   - Zepher CLI     : %ZEPHER_NPM_URL%
echo   - Orca Website   : %ORCA_WEBSITE_URL%
echo   - Orca Install   : %ORCA_INSTALL_DOCS_URL%
echo   - Orca CLI Docs  : %ORCA_CLI_DOCS_URL%
echo   - GitHub CLI     : %GH_CLI_URL%
echo   - GitHub SSH     : %GH_SSH_DOCS_URL%

:check_final_counts
echo.
if !FAIL_COUNT! GTR 0 goto :summary_not_ready
if !ACTION_COUNT! GTR 0 goto :summary_partially_ready

echo =============================================================================
echo   FINAL READINESS STATUS: FULLY READY
echo   All required tools and CLIs are installed, verified, and ready for the event!
echo =============================================================================
exit /b 0

:summary_partially_ready
echo =============================================================================
echo   FINAL READINESS STATUS: PARTIALLY READY (!ACTION_COUNT! manual action(s) required)
echo   Automated steps succeeded, but please complete the manual steps listed above
echo   and re-run "setup.bat" in a new Command Prompt window to confirm readiness.
echo =============================================================================
exit /b 0

:summary_not_ready
echo =============================================================================
echo   FINAL READINESS STATUS: NOT READY (!FAIL_COUNT! failure(s), !ACTION_COUNT! manual action(s))
echo   One or more required components could not be verified. Follow the recovery
echo   steps above and re-run "setup.bat".
echo =============================================================================
exit /b 1
