# AI Development Event — Participant Environment Onboarding

Welcome! This repository prepares your laptop for our hands-on AI development event. Whether you are a first-time attendee on a brand-new laptop (with **no Git** and **no package managers** installed) or an experienced developer, these scripts will inspect your environment, install missing tools safely, and give you a clear readiness report.

---

## Supported Operating Systems

| Operating System | Supported Architectures | Single Entry-Point Script | Terminal to Use |
| :--- | :--- | :--- | :--- |
| **macOS** (macOS 13 Ventura or newer recommended) | Apple Silicon (`arm64`) & Intel (`x86_64`) | `setup.zsh` | **Terminal** (Zsh) |
| **Windows** (Windows 10 / Windows 11) | 64-bit (`x64` / `ARM64`) | `setup.bat` | **Command Prompt** (`cmd.exe`) |
| **Linux** (Ubuntu/Debian, Fedora, openSUSE, Arch) | `x86_64` & `arm64` | `setup.sh` | Any terminal (bash) |

---

## Repository Configuration

| Resource | Official Location |
| :--- | :--- |
| **Repository URL** | [https://github.com/The-Fable-Club/beyond-the-prompt](https://github.com/The-Fable-Club/beyond-the-prompt) |
| **Clone URL** | `https://github.com/The-Fable-Club/beyond-the-prompt.git` |
| **Direct ZIP Archive Download** | [https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip](https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip) |

*(If you ever fork or mirror this repository under a different organization, you can update `REPO_WEB_URL` and `REPO_ZIP_URL` at the top of [`setup.zsh`](file:///Users/rpshakkthi/documents/rakshith/beyond-the-prompt/setup.zsh) and [`setup.bat`](file:///Users/rpshakkthi/documents/rakshith/beyond-the-prompt/setup.bat).)*

---

## Prerequisites

1. **A reliable internet connection** (to download tools and npm packages).
2. **A personal laptop** with at least **2 GB of free disk space**.
3. **No pre-installed Git, Homebrew, or `winget` required**:
   - The initial bootstrap and setup scripts work even when Git, Homebrew (macOS), and `winget` (Windows) are completely absent.
4. **Your own accounts and credentials**:
   > **Important Account & Security Notice:** This repository and its scripts **never** request, collect, print, store, or transmit your passwords, API keys, or access tokens. You must sign in to any AI tools or services during the event using **your own personal accounts and credentials**.

---

## What Gets Installed & Verified

Each component is detected independently:

| Component | Plain-English Description | Package / Binary |
| :--- | :--- | :--- |
| **1. Git CLI** | Version control tool used to clone repositories, manage branches, and create isolated Git worktrees for AI coding agents. | `git` |
| **2. Node.js & npm** | The JavaScript runtime (**Node.js v18+ LTS**, installs v22 LTS when needed) and package manager (**npm**) required to run modern AI CLI tools. | `node`, `npm` |
| **3. Zepher CLI** | **Zepher** ([`zepher-cli`](https://www.npmjs.com/package/zepher-cli)) — a persistent context, memory, and universal agent environment manager that synchronizes rules and skills across AI coding agents. *(Specifically `zepher-cli`, never `zephyr-cli`.)* | `zepher` |
| **4. Orca Desktop App** | **Orca** ([onorca.dev](https://www.onorca.dev)) — an Agent Development Environment (ADE) desktop application for running and coordinating AI coding agents in isolated Git worktrees. | `Orca.app` (macOS) / `Orca.exe` (Windows) |
| **5. Orca CLI** | The command-line interface bundled with the Orca desktop app for scripting worktrees, agent terminals, and the built-in browser from your shell. | `orca` |
| **6. GitHub CLI** | GitHub from the terminal: issues, Project boards, branches, and pull requests. Orca also uses it for its PR and Checks panels. | `gh` |
| **7. GitHub over SSH** | Signs `gh` in to **your** GitHub account (in your browser), creates an SSH key if you don't have one, uploads it to GitHub, and makes `git` use SSH. Also fills in your Git name/email if they are empty. | `gh auth`, `~/.ssh/id_ed25519` |
| **8. AI agent CLIs** | Claude Code and OpenCode, installed with npm (from the USB kit's offline cache when present). Choose with `--agents claude`, `--agents opencode` or `--agents none`. You sign in to them yourself. | `claude`, `opencode` |
| **9. jq** | Small JSON tool used by the `/new-issue`, `/start-task` and `/plan-project` skills. | `jq` |
| **10. Event skills** | Copies this repo's [`skills/`](skills/) into Claude Code's skills folder. Skills you already have with the same name are left untouched. | `~/.claude/skills` |

### What the GitHub-over-SSH step does (and doesn't do)

1. **Signs in with `gh auth login --web`.** You copy a one-time code and approve it on github.com. The script never sees your password or token; `gh` stores the token in the macOS Keychain / Windows Credential Manager. It requests two scopes on top of `gh`'s defaults: `admin:public_key` (to upload your SSH key) and `project` (for GitHub Projects commands used at the event).
2. **Uses your existing `~/.ssh/id_ed25519` if you have one.** It is never overwritten. If there is none, a new ed25519 key is created. On macOS you may choose a passphrase (it is saved in the Keychain). On Windows the new key has no passphrase so `git` works without prompts. Add one later with `ssh-keygen -p`.
3. **Trusts GitHub's real host keys.** They are fetched from the GitHub API over HTTPS (`gh api meta`) and written to `known_hosts`, so there is no "Are you sure you want to continue connecting?" guesswork. Outdated GitHub entries are replaced.
4. **Works on networks that block SSH port 22** (common on campus and venue Wi-Fi). If port 22 is blocked but 443 works, it adds a clearly marked `Host github.com` block to `~/.ssh/config` that routes SSH through `ssh.github.com:443`, after backing up the file to `config.bak-beyond-the-prompt`.
5. **Uploads the public key** with `gh ssh-key add`, titled `beyond-the-prompt <computer name>`.
6. **Verifies** with `ssh -T git@github.com` and checks that the SSH key and `gh` belong to the same GitHub account.
7. **Sets `git config --global user.name/user.email` only if they are empty**, using your GitHub no-reply address (`<id>+<login>@users.noreply.github.com`).

Run with `--no-prompt` and this step reports `ACTION REQUIRED` instead of opening a browser.

---

## Quick Start Instructions

Participants only need to run **one script** for their operating system (`setup.zsh` on macOS, `setup.bat` on Windows, `setup.sh` on Linux).

### Option A: Clone with Git (If Git is Already Installed)

```bash
git clone https://github.com/The-Fable-Club/beyond-the-prompt.git
cd beyond-the-prompt
```

Then run the script for your operating system:
- **macOS**: `chmod +x setup.zsh && ./setup.zsh`
- **Windows**: `setup.bat`
- **Linux**: `chmod +x setup.sh && ./setup.sh`

---

### Option B: Download ZIP (If Git is Not Installed)

1. Open [https://github.com/The-Fable-Club/beyond-the-prompt](https://github.com/The-Fable-Club/beyond-the-prompt) in your browser.
2. Click **Code → Download ZIP** (or direct download: [main.zip](https://github.com/The-Fable-Club/beyond-the-prompt/archive/refs/heads/main.zip)).
3. **Extract the ZIP file**:
   - **macOS**: Double-click the `.zip` file in Finder, open Terminal, and `cd` into the extracted folder.
   - **Windows**: Right-click the `.zip` file in File Explorer, click **Extract All...**, and `cd` into the folder in Command Prompt.
4. Run:
   - **macOS**: `chmod +x setup.zsh && ./setup.zsh`
   - **Windows**: `setup.bat`
- **Linux**: `chmod +x setup.sh && ./setup.sh`

---

### Option C: Single-File Standalone Execution (Automatic Bootstrap)

If you downloaded only `setup.zsh` (macOS) or `setup.bat` (Windows) by itself outside the repository:
- Running `./setup.zsh` or `setup.bat` will automatically detect standalone mode, download and verify the repository ZIP into a temporary workspace, and launch the full setup!
- You can also pass a downloaded ZIP file directly:
  - **macOS**: `./setup.zsh --local-zip ~/Downloads/beyond-the-prompt-main.zip`
  - **Windows**: `setup.bat --local-zip "%USERPROFILE%\Downloads\beyond-the-prompt-main.zip"`

---

### Slow Internet at the Venue? Use the Offline Kit

Volunteers carry a USB kit (`Beyond the Prompt` folder) with the official installers for Git (Windows), Node.js 22, GitHub CLI, Orca and jq. It also has an offline npm cache for Zepher, Claude Code and OpenCode, and a copy of this repo. Open `START-HERE.txt` on the USB, copy your OS folder to your laptop, install from it, then run the setup script as below. It will mark those tools `SKIPPED` and only use the internet for GitHub sign-in.

---

### Step 2A: Run the Setup Script on macOS

Inside the repository folder in **Terminal**, run:

```zsh
chmod +x setup.zsh
./setup.zsh
```

*To inspect your machine without installing anything (read-only check):*
```zsh
./setup.zsh --check-only
```

---

### Step 2C: Run the Setup Script on Linux

In any terminal inside the repository folder:

```bash
chmod +x setup.sh
./setup.sh
```

It installs Node.js, GitHub CLI and jq per-user into `~/.local` (no sudo). It only uses `sudo` for your distribution's package manager, and shows the command first: for Git/OpenSSH if missing, and for Orca's `.deb`/`.rpm` on apt, dnf and zypper systems. Other distributions, and runs with `--no-prompt`, get Orca's AppImage in `~/Applications` instead. On Linux the Orca CLI is called `orca-ide`. NixOS isn't handled; install the tools through your configuration and use `--check-only`.

### Step 2B: Run the Setup Script on Windows

Inside the repository folder in **Command Prompt** (`cmd.exe`), run:

```bat
setup.bat
```

*To inspect your machine without installing anything (read-only check):*
```bat
setup.bat --check-only
```

---

## How the Scripts Work Without Homebrew or `winget`

Neither script assumes a package manager is installed, and neither script ever installs an unofficial package manager or pipes remote scripts into your shell.

### macOS Behavior (With and Without Homebrew)

| Component | When Homebrew is Installed | When Homebrew is Absent (Standalone Fallback) |
| :--- | :--- | :--- |
| **Git CLI** | Uses Apple's official `xcode-select --install` (or `brew install git` fallback). | Uses Apple's built-in `xcode-select --install` (Command Line Developer Tools) — no Homebrew needed. |
| **Node.js & npm** | Installs `node@22` via `brew install node@22`. | Downloads the official **Node.js v22 LTS** standalone archive (`node-v22.x.x-darwin-arm64.tar.gz` or `darwin-x64.tar.gz`) from `https://nodejs.org/dist/latest-v22.x/`, verifies its **SHA-256 checksum** against the official `SHASUMS256.txt` manifest, and installs it **per-user** into `~/.local/node-lts` with symlinks in `~/.local/bin` (**zero `sudo` / admin rights required**). |
| **Zepher CLI** | Installs globally via `npm install -g zepher-cli` (uses per-user `~/.npm-global` if `/usr/local` requires `sudo`). | Installs per-user into `~/.local/node-lts` or `~/.npm-global` via `npm install -g zepher-cli` (**zero `sudo` required**). |
| **GitHub CLI** | Installs via `brew install gh`. | Downloads the official `gh_<version>_macOS_arm64.zip` or `macOS_amd64.zip` from GitHub Releases, verifies its **SHA-256 checksum** against the release's `checksums.txt`, and installs it **per-user** into `~/.local/gh` with a symlink in `~/.local/bin` (**zero `sudo`**). |
| **Orca Desktop App** | Installs via `brew install --cask stablyai/orca/orca`. | Downloads the official `orca-macos-arm64.dmg` or `orca-macos-x64.dmg` from GitHub Releases, verifies its **SHA-256 digest** against the official GitHub Release API and its **Apple code signature** via `codesign --verify --deep --strict`, mounts the `.dmg` read-only, and copies `Orca.app` into `/Applications` (if writable) or per-user `~/Applications/Orca.app`. |

> **Why Homebrew Is Never Installed Automatically:** Installing Homebrew modifies system directories (`/opt/homebrew` on Apple Silicon or `/usr/local` on Intel), installs system-wide build tools, and requires administrator (`sudo`) access. Because all event tools can be installed using Apple's built-in tools and official standalone distributions, `setup.zsh` never forces a Homebrew installation.

### Windows Behavior (With and Without `winget`)

| Component | When `winget` is Installed | When `winget` is Absent (Standalone Fallback) |
| :--- | :--- | :--- |
| **Git CLI** | Runs `winget install --id Git.Git --scope user -e --source winget` (falling back to standard scope if needed). | Opens the official Git for Windows download page (`https://git-scm.com/download/win`), guides you through the official standalone installer (supporting per-user installation without admin rights), pauses, refreshes `PATH`, and re-verifies `git --version`. |
| **Node.js & npm** | Runs `winget install --id OpenJS.NodeJS.LTS -e --source winget`. | Downloads the official **Node.js v22 LTS** standalone Windows archive (`node-v22.x.x-win-x64.zip` or `win-arm64.zip`) from `https://nodejs.org/dist/latest-v22.x/`, verifies its **SHA-256 checksum** via `certutil -hashfile` against `SHASUMS256.txt`, and extracts it **per-user** into `%LocalAppData%\Programs\nodejs` (**zero Administrator rights required**). |
| **Zepher CLI** | Verifies package metadata on npm and runs `npm install -g zepher-cli`. | Verifies package metadata on npm and runs `npm install -g zepher-cli` into per-user `%AppData%\npm`. |
| **GitHub CLI** | Runs `winget install --id GitHub.cli -e --source winget`. | Downloads the official `gh_<version>_windows_amd64.zip` or `windows_arm64.zip` from GitHub Releases, verifies its **SHA-256 checksum** via `certutil -hashfile` against the release's `checksums.txt`, and extracts it **per-user** into `%LocalAppData%\Programs\gh` (**zero Administrator rights required**). |
| **Orca Desktop App** | Opens `https://www.onorca.dev/docs/install` (Orca does not publish an official `winget` package ID), pauses for the official installer (`orca-windows-setup.exe`), and verifies `Orca.exe`. | Same official standalone installer flow (`%LocalAppData%\Programs\Orca\Orca.exe` per-user installation). |

---

## Understanding Your Setup Summary, Permissions & Partial Readiness

At the end of every run, the script prints a summary table with a status for each component:

- **`PASS`**: Installed and verified during this run.
- **`SKIPPED`**: Already installed and verified—nothing needed to be reinstalled.
- **`ACTION REQUIRED`**: Automated checks succeeded, but a manual step is needed from you (for example, completing the macOS Command Line Tools dialog, finishing the Orca Windows installer, or enabling the Orca CLI inside Orca Settings).
- **`FAIL`**: A required check or installation step failed. Follow the numbered recovery step printed below the table.

### Final Readiness Banner
- **`FULLY READY`**: All 10 components show `PASS` or `SKIPPED`. You are 100% ready for the event!
- **`PARTIALLY READY`**: Core tools are in place and zero errors occurred, but one or more items show `ACTION REQUIRED`. Complete the listed manual instructions, **open a new terminal window**, and re-run the setup script to reach `FULLY READY`.
- **`NOT READY`**: One or more required components reported `FAIL`. Follow the recovery instructions in the terminal output or the Troubleshooting section below, then re-run the script.

### Permissions & Limitations
- **Per-User First**: Both scripts prefer per-user directories (`~/.local`, `~/Applications` on macOS; `%LocalAppData%\Programs`, `%AppData%\npm` on Windows) so administrator privileges are avoided whenever possible.
- **When OS Prompts Appear**:
  - macOS may display a GUI prompt when `xcode-select --install` installs Apple Command Line Tools, or ask for your password if Homebrew Cask moves `Orca.app` into `/Applications`.
  - Windows User Account Control (UAC) may prompt for permission if `winget` installs a system-wide MSI package.
- **Resumable & Idempotent**: You can interrupt or re-run `./setup.zsh` and `setup.bat` as many times as needed. Any component completed in an earlier run or installed manually will be detected and marked `SKIPPED`.

---

## Troubleshooting Guide

### 1. macOS Permissions: `"permission denied"` or Gatekeeper Quarantine
If macOS blocks `setup.zsh` from running after downloading a ZIP:
```zsh
chmod +x setup.zsh
xattr -d com.apple.quarantine setup.zsh 2>/dev/null || true
./setup.zsh
```

### 2. Newly Installed Tools Are Not Found (`PATH` Refresh Needed)
When an installer finishes, your currently open terminal window may not yet include the new binary directory on its `PATH`.
- **Fix**: Close your current Terminal or Command Prompt window, open a **brand-new** terminal window, `cd` back into this repository, and re-run `./setup.zsh` (macOS) or `setup.bat` (Windows).
- **Per-User PATH on macOS** (if standalone Node.js or npm packages were installed into `~/.local/bin`):
  ```zsh
  export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"
  ```
- **Per-User PATH on Windows** (if standalone Node.js was extracted into `%LocalAppData%\Programs\nodejs`):
  ```bat
  set "PATH=%LocalAppData%\Programs\nodejs;%AppData%\npm;%PATH%"
  ```

### 3. Git Installation Issues
- **macOS**: Wait for the `Install Command Line Developer Tools` progress bar to finish completely, then re-run `./setup.zsh`. If the popup does not appear, download Git from [https://git-scm.com/download/mac](https://git-scm.com/download/mac).
- **Windows**: Download and run the official **64-bit Git for Windows Setup** from [https://git-scm.com/download/win](https://git-scm.com/download/win) using the default options, open a new Command Prompt, and re-run `setup.bat`.

### 4. Node.js or npm Version / Version Manager Issues
`zepher-cli` requires **Node.js v18.0.0 or newer** (v22 LTS recommended).
- If you use a Node version manager (**nvm**, **nvm-windows**, **fnm**, **Volta**, or **asdf**), the setup script intentionally avoids overwriting it. Switch to an LTS version using your version manager:
  ```bash
  # macOS (nvm)
  nvm install --lts && nvm use --lts

  # Windows Command Prompt (nvm-windows)
  nvm install lts
  nvm use lts
  ```
- Otherwise, download the official **Node.js LTS** installer (`.pkg` for macOS or `.msi` for Windows) from [https://nodejs.org/en/download](https://nodejs.org/en/download).

### 5. `zepher-cli` Package Installation Failures
- Make sure you install **`zepher-cli`** (with an **`e`**), **not** `zephyr-cli`:
  ```bash
  npm install -g zepher-cli
  zepher --version
  ```

### 6. Orca CLI (`orca`) Registration & Verification Issues
Installing the Orca desktop app does not automatically place `orca` on your `PATH`.
1. Open the **Orca** desktop application.
2. Open **Settings → General → Orca CLI**.
3. Click to register/enable the `orca` command on your `PATH`.
4. **Open a new terminal window** (macOS Terminal or Windows Command Prompt).
5. Keep the **Orca desktop application open and running**, then verify:
   ```bash
   orca status --json
   ```

### 7. GitHub CLI & SSH Issues

| Symptom | Fix |
| :--- | :--- |
| `gh: command not found` after install | Open a **new** terminal. Standalone installs live in `~/.local/bin` (macOS) or `%LocalAppData%\Programs\gh\bin` (Windows). |
| Browser code never completes | Open [https://github.com/login/device](https://github.com/login/device) yourself and type the code. Make sure you're signed in to the right GitHub account. |
| `GH_TOKEN / GITHUB_TOKEN is set` | Remove the variable (`unset GH_TOKEN GITHUB_TOKEN` on macOS, Environment Variables on Windows), open a new terminal, re-run. |
| "SSH unreachable on ports 22 and 443" | The network blocks SSH entirely. Switch to a phone hotspot and re-run. |
| "SSH key belongs to X, but gh is signed in as Y" | Your existing key is on another GitHub account. Sign `gh` in as that account, or re-run with `ONBOARD_SSH_KEY_PATH=~/.ssh/id_ed25519_<login>` to make a separate key. |
| Windows: "Key has a passphrase and the Windows ssh-agent is not running" | In an Administrator PowerShell: `Get-Service ssh-agent \| Set-Service -StartupType Automatic; Start-Service ssh-agent`, then re-run. |
| Check it by hand | `gh auth status` and `ssh -T git@github.com` (prints "Hi &lt;login&gt;! You've successfully authenticated"). |
| Old repos still ask for a password | They were cloned over HTTPS. Switch one with `git remote set-url origin git@github.com:<owner>/<repo>.git`. |

---

## Event Guides

- [Orca automation templates](docs/orca-automations.md): what each field in Orca's *Create automation* dialog does, a safe prompt skeleton, and 10 ready-to-paste automations
- [Zepher guide](docs/zepher-guide.md): every Zepher command and how a team uses it with its agents
- [Skills guide](docs/skills-guide.md): why and how to use each of the 31 event skills, in one page
- [Event skills](skills/README.md): `/new-issue`, `/start-task`, `/plan-project` and 28 more

---

## Official Tool Documentation

- **Git CLI**: [https://git-scm.com/doc](https://git-scm.com/doc)
  - macOS Downloads: [https://git-scm.com/download/mac](https://git-scm.com/download/mac)
  - Windows Downloads: [https://git-scm.com/download/win](https://git-scm.com/download/win)
- **Node.js & npm**: [https://nodejs.org/en/download](https://nodejs.org/en/download)
  - Official v22 LTS Distribution & Checksums: [https://nodejs.org/dist/latest-v22.x/](https://nodejs.org/dist/latest-v22.x/)
- **Zepher CLI (`zepher-cli`)**: [https://www.npmjs.com/package/zepher-cli](https://www.npmjs.com/package/zepher-cli)
- **Orca Website**: [https://www.onorca.dev](https://www.onorca.dev)
- **Orca Installation Guide**: [https://www.onorca.dev/docs/install](https://www.onorca.dev/docs/install)
- **Orca CLI Overview**: [https://www.onorca.dev/docs/cli/overview](https://www.onorca.dev/docs/cli/overview)
- **GitHub CLI**: [https://cli.github.com](https://cli.github.com)
- **GitHub SSH guide**: [https://docs.github.com/en/authentication/connecting-to-github-with-ssh](https://docs.github.com/en/authentication/connecting-to-github-with-ssh)
