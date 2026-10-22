# Beyond the Prompt — Facilitator Script

Oct 21, 2026 · @Sanjani

The full script for the Fable Club's first agentic-AI event. Participants set up their tools, learn Git and GitHub, automate the issue → branch → PR flow with the GitHub CLI, then use Orca to run and coordinate several coding agents at once. Every command below was checked against Orca CLI 1.4.220, the Orca docs and gh 2.93.

## Run of show

The suggested day is about 5 hours 30 minutes with two breaks. Setup and Git always overrun, so Parts 6 and 7 are the buffer: if you are behind, demo them instead of having everyone do them hands-on.

| # | Segment | Time | Format | What participants leave with |
| --- | --- | --- | --- | --- |
| 0 | Opening and team formation | 10 min | Talk | A team of 3–4 and a shared goal |
| 1 | Environment setup | 40 min | Hands-on | `FULLY READY` banner, plus `gh` and one agent CLI logged in |
| 2 | Git basics | 30 min | Live coding | Clone, branch, commit, push, merge conflict resolved once |
| 3 | GitHub, Projects and gh CLI | 50 min | Hands-on in teams | A team repo, board, issues and one merged PR, all from the CLI |
| — | Break | 15 min | — | — |
| 4 | Orca fundamentals | 40 min | Hands-on | Three agents racing the same task, one winner shipped |
| 5 | Orca CLI and orchestration | 35 min | Demo, then hands-on | One coordinator dispatching work to worker agents |
| 6 | Automations (scheduled jobs) | 20 min | Demo, then hands-on | One disabled automation, run once on demand |
| 7 | SSH and remote runtimes | 15 min | Demo | Knowing when to use SSH vs a Remote Orca Server vs a cloud VM |
| — | Break | 10 min | — | — |
| 8 | Team capstone | 60 min | Team build | A working feature built by agents through the full board flow |
| 9 | Demos and close | 15 min | Team demos | Show-and-tell, feedback form |

## Before the event

`setup.zsh` / `setup.bat` now cover Git, Node, Zepher, the Orca app and CLI, the GitHub CLI, and GitHub sign-in over SSH (browser login, SSH key, upload, port-443 fallback, Git name/email). The remaining risk is the coding agent: the scripts do **not** install one, and agent accounts can't be created on the day.

### Gaps the setup scripts still leave

| Missing piece | Needed in | Fix before the event |
| --- | --- | --- |
| A coding agent CLI (Claude Code, OpenCode, Antigravity, Codex…) | Parts 4–8 | Tell participants which agent to install and log in to at home. Orca launches agents; it ships no model of its own |
| An agent account or plan | Parts 4–8 | Claude Code needs a paid Claude plan or API credits. Name a free fallback (for example OpenCode with a free model, or Antigravity) for people with no paid plan |
| A GitHub account with 2FA working | Parts 2–8 | People locked out by 2FA on a new phone lose 20 minutes. Ask everyone to log in to github.com the day before |
| `jq` | Nothing, if you use `gh --jq` | Use `gh ... --jq` everywhere so Windows users never need jq |
| Claude Code on Windows | Parts 4–8 | It needs Git for Windows (Git Bash). The script installs Git, so verify `claude --version` in a new terminal |

### One week before

- [ ] Send the pre-event email: bring a charged laptop and charger, run `setup.zsh` or `setup.bat` at home until it says `FULLY READY` (it signs you in to GitHub and sets up SSH), install one agent CLI and log in to it, and confirm you can sign in to github.com with 2FA.
- [ ] Ask for each person's OS and which agent plan they have (form). Plan teams so each team has at least one working paid agent.
- [ ] Create a GitHub organization for the event (for example `fable-btp-2026`). Team repos and Projects live there, so you can see every team's board.
- [ ] Build a starter repo template: a tiny web app with a README, a `CLAUDE.md` / `AGENTS.md`, 6–8 prepared issues, and a `.worktreeinclude` (see Part 4).
- [ ] Do a full dry run on a clean macOS account **and** a clean Windows machine. Time each part.
- [ ] Record a 3-minute backup video of the Orca three-agent race, in case Wi-Fi or rate limits kill the live demo.

### Day before

- [ ] Update Orca on the demo laptop to the newest stable release and re-check `orca --version`. The CLI changes quickly, so re-run `orca <command> --help` for every command you will show.
- [ ] Test venue Wi-Fi: GitHub, npmjs.com, nodejs.org, github.com/stablyai/orca releases and your agent's API must not be blocked. Run `ssh -T git@github.com` and `ssh -T -p 443 git@ssh.github.com` from the venue network: the script falls back to port 443 when 22 is blocked, but if both fail everyone needs a hotspot.
- [ ] USB kit is ready: the `Beyond the Prompt` folder on the Ventoy stick (2.4 GB). It has installers for Git (Windows), Node 22, gh, Orca and jq for macOS and Windows, a per-OS offline npm cache for Zepher, Claude Code and OpenCode, the repo ZIP, `START-HERE.txt` and `SHA256SUMS.txt`. Copy it to 3–4 volunteer laptops the day before so there is more than one source.
- [ ] Seventy people downloading a 270 MB Orca app at once on venue Wi-Fi is the most common failure. See "Getting materials to participants" below.
- [ ] Pre-create the team repos from the template, or have each team create one in Part 3.
- [ ] Have a mobile hotspot as a backup network for the demo laptop.

### Getting materials to participants

Use these in order. Each one takes load off the next.

1. **At home, before the day (best).** The pre-event email asks everyone to run the setup script at home until `FULLY READY`. Ask for a screenshot of the banner in the event group. Anyone who sends one needs nothing on the day.
2. **Venue Wi-Fi with the script (default).** People who skipped step 1 run the setup script. It downloads only what's missing.
3. **Local network mirror (when Wi-Fi to the internet is slow but the local network works).** On a volunteer laptop, open a terminal in the copied `Beyond the Prompt` folder and run `python3 -m http.server 8000`. Put `http://<that laptop's IP>:8000` on the projector. Participants download from it at local-network speed and follow `START-HERE.txt`. A phone hotspot works as the local network if the venue blocks device-to-device traffic.
4. **USB hand-off (worst case).** Participants copy only their OS folder plus `beyond-the-prompt-main.zip` to Downloads (about 1.5 GB, around 1 minute on USB 3) and hand the stick on. They never install from the stick directly. Use 3–4 copies on volunteer laptops or sticks so 70 people aren't waiting on one.

What still needs the internet in every case: GitHub sign-in and SSH key upload (a few KB), agent login and use, and on Macs Apple's Command Line Tools for Git (`xcode-select --install`, about 700 MB from Apple, which can't legally go on the USB). Make the Mac Git step the one thing everyone does at home.

### Demo laptop state

- [ ] `gh auth status` shows the `repo`, `read:org` and `project` scopes.
- [ ] Orca open, the starter repo added, Settings → Experimental → Orchestration on, and the Orca CLI registered.
- [ ] Terminal font at 20pt or more, dark theme, notifications muted (Settings → Notifications) except agent-finished sounds.
- [ ] Close Slack, mail and anything that may pop up personal data on the projector. Never show `gh auth token`, `.env` files or pairing links on screen.

## Part 0 — Opening (10 min)

The goal is a clear promise and teams formed before any laptop opens. Script lines are in quotes. Change them to fit your voice.

> "Welcome to Beyond the Prompt, the Fable Club's first event. Most of you have used an AI chatbot. Today we go past the chat box. You will run several AI coding agents at the same time, give each one its own task, and manage them the way a tech lead manages a team."

> "Agents are only as good as the process around them. So we start with the boring, powerful part: Git, GitHub issues, a project board and pull requests. Then we hand that process to agents using Orca."

> "By the end, your team will have a board full of issues, agents working on them in parallel, and real pull requests merged into a real repo."

**House rules to say out loud:**

1. Use your own accounts. Never paste someone else's token or password, and never put keys on screen.
2. Stuck for more than 3 minutes? Raise your hand or put a sticky note on your laptop lid. Volunteers walk the room.
3. Agents can run commands on your machine. In Orca they run with permission prompts switched off by default, inside a separate worktree. Read diffs before you merge.
4. Wi-Fi is shared. Don't start big downloads unless the step needs them.

**Team formation:** teams of 3–4. Each team needs at least one person with a working paid agent and, ideally, a mix of macOS and Windows. Name a **Board owner** (keeps the Project tidy), a **Reviewer** (reads every PR) and **Builders**.

## Part 1 — Environment setup (40 min)

The target is the `FULLY READY` banner (all 7 components, including `gh` signed in over SSH), plus one agent CLI logged in. Have people who already ran the script at home start with the check-only run, then help their neighbours.

> "Everyone runs one script. It checks your laptop, installs only what's missing, and never asks for your passwords. If it says PASS or SKIPPED, you're fine. If it says ACTION REQUIRED, follow the line it prints. If it says FAIL, raise your hand."

### Step 1: get the repo

With Git already installed:

```
git clone https://github.com/The-Fable-Club/beyond-the-prompt.git
cd beyond-the-prompt
```

Without Git: open the repo page → **Code → Download ZIP** → extract it → `cd` into the folder. On Windows, extract it first. Running from inside the ZIP preview fails.

### Step 2: run the script

- macOS (Terminal): `chmod +x setup.zsh && ./setup.zsh`
- Windows (Command Prompt, not PowerShell): `setup.bat`
- Read-only check: add `--check-only`
- If only the single script file was downloaded, it bootstraps the rest itself. With a ZIP from the USB stick: `./setup.zsh --local-zip ~/Downloads/beyond-the-prompt-main.zip` or `setup.bat --local-zip "%USERPROFILE%\Downloads\beyond-the-prompt-main.zip"`

### Step 3: what the summary means

| Status | Meaning | Say this |
| --- | --- | --- |
| PASS | Installed and verified this run | "Good." |
| SKIPPED | Already installed | "Good." |
| ACTION REQUIRED | A manual step is left | "Do the printed step, open a NEW terminal, run the script again." |
| FAIL | A step failed | "Follow the numbered recovery step, or raise your hand." |

The usual ACTION REQUIRED item is the Orca CLI. Walk the room through it on the projector: open Orca → **Settings → General → Orca CLI** → register it → open a **new** terminal → with Orca still open, run `orca status --json`.

### Step 4: GitHub sign-in over SSH (done by the script, step 8)

Explain this before people run the script, because it is the one step that needs them:

> "Near the end, the script prints an 8-character code and asks you to press Enter. Your browser opens github.com. Paste the code and click Authorize. Then it may ask about an SSH key passphrase (Mac only). Pressing Enter twice is fine for today."

What the script does in that step: `gh auth login --web` with the `admin:public_key` and `project` scopes, reuses or creates `~/.ssh/id_ed25519` (never overwrites one), adds GitHub's host keys from `gh api meta`, switches to `ssh.github.com:443` if port 22 is blocked, uploads the key with `gh ssh-key add`, checks `ssh -T git@github.com`, and fills in an empty Git name/email with the GitHub no-reply address.

Manual fallback if a laptop can't run the script:

```
gh auth login --git-protocol ssh --web --scopes admin:public_key,project
# answer "Upload your SSH public key?" → Yes / "Generate a new SSH key" → Yes
ssh -T git@github.com      # "Hi <login>! You've successfully authenticated"
```

Then the agent. Use the one you announced, for example Claude Code: `npm install -g @anthropic-ai/claude-code`, then run `claude` once and log in. Anyone can test their agent by asking it one small question in the repo folder.

### Checkpoint before moving on

Ask for a show of hands on each line. Don't start Part 2 until 80% pass. Pair the rest with a volunteer.

- [ ] `git --version`
- [ ] `node --version` shows v18 or newer
- [ ] `gh auth status` shows logged in, with "Git operations protocol: ssh"
- [ ] `ssh -T git@github.com` greets them by their GitHub username
- [ ] `orca status --json` returns without an error, with Orca open
- [ ] The agent CLI starts and answers

### Failure cases you will see

| Symptom | Cause | Fix |
| --- | --- | --- |
| macOS: `permission denied` or the file is blocked | Download quarantine | `chmod +x setup.zsh && xattr -d com.apple.quarantine setup.zsh` |
| macOS: Command Line Tools dialog sits for ages | Apple download, 5–15 min on slow Wi-Fi | Let it finish, then run the script again. Move on to Part 2 with a neighbour's screen meanwhile |
| Tool installed but "command not found" | The terminal's `PATH` is stale | Close the terminal, open a new one, run again |
| macOS per-user Node not found | `~/.local/bin` is not on `PATH` | `export PATH="$HOME/.local/bin:$HOME/.npm-global/bin:$PATH"`, and add it to `~/.zshrc` |
| Windows per-user Node not found | Same | `set "PATH=%LocalAppData%\Programs\nodejs;%AppData%\npm;%PATH%"` |
| `npm install -g` fails with EACCES | Global npm folder owned by root | Use the script's per-user npm prefix. Never `sudo npm` |
| Node too old, or nvm / fnm / Volta present | The script won't touch a version manager | `nvm install --lts && nvm use --lts` |
| Someone installed `zephyr-cli` | Wrong package | `npm install -g zepher-cli` (with an e) |
| `orca: command not found` | CLI not registered, or old terminal | Settings → General → Orca CLI, then a new terminal. macOS shim is in `~/.local/bin` |
| `orca status` errors | Orca app not running | `orca open`, or launch the app, then retry |
| Linux laptop | Not supported by the scripts. The CLI is called `orca-ide` there | Install the AppImage or `.deb` from onorca.dev by hand |
| School or work laptop, no admin | Managed device | The scripts prefer per-user installs. If Orca can't install, pair the person with a teammate |
| Download stalls | Venue Wi-Fi | Hand out the USB installers and use `--local-zip` |
| GitHub over SSH: browser code never completes | Wrong GitHub account in the browser, or popup blocked | Open github.com/login/device by hand and type the code |
| GitHub over SSH: "GH_TOKEN / GITHUB_TOKEN is set" | An old token exported in the shell profile overrides login | `unset GH_TOKEN GITHUB_TOKEN`, remove it from `~/.zshrc`, re-run |
| GitHub over SSH: "unreachable on ports 22 and 443" | Network blocks SSH completely | Switch to a hotspot and re-run |
| GitHub over SSH: "key belongs to X, but gh is signed in as Y" | Old key is on a different GitHub account | Re-run with `ONBOARD_SSH_KEY_PATH=~/.ssh/id_ed25519_<login> ./setup.zsh` to make a separate key |
| Windows: "passphrase and the ssh-agent is not running" | Existing key has a passphrase | Admin PowerShell: `Get-Service ssh-agent \| Set-Service -StartupType Automatic; Start-Service ssh-agent`, re-run |
| `git push` asks for a username/password | Repo was cloned over HTTPS | `git remote set-url origin git@github.com:<owner>/<repo>.git` |

## Part 2 — Git basics (30 min)

Teach Git as "save points plus parallel timelines". Everything later, including Orca worktrees, is just this idea at scale.

> "Git is a time machine for your code. A commit is a save point. A branch is a parallel timeline where you can experiment without breaking main. GitHub is where your team shares those timelines."

### The four places your code lives

Draw this on the board: **Working folder → (git add) → Staging area → (git commit) → Local repo → (git push) → GitHub.** `git pull` brings changes back the other way.

### Live demo (type along)

```
# one-time identity (use the email on your GitHub account)
git config --global user.name "Your Name"
git config --global user.email "you@example.com"
git config --global init.defaultBranch main

mkdir git-playground && cd git-playground
git init
echo "# Playground" > README.md
git status                 # red = untracked/changed
git add README.md
git status                 # green = staged
git commit -m "docs: add README"
git log --oneline

git switch -c feature/hello   # new branch, switch to it
echo "hello" > hello.txt
git add . && git commit -m "feat: add hello"
git switch main
git merge feature/hello
git branch -d feature/hello
```

### Show a merge conflict on purpose

This is the one thing beginners fear most. Do it on stage so they see it is normal.

```
git switch -c a && echo "from A" > note.txt && git add . && git commit -m "A"
git switch main && git switch -c b && echo "from B" > note.txt && git add . && git commit -m "B"
git switch main && git merge a && git merge b    # CONFLICT
# open note.txt, keep what you want, delete the <<<<<<< ======= >>>>>>> lines
git add note.txt && git commit
```

> "When agents work in parallel, conflicts happen too. Orca has a 'Resolve with AI' button for them, but you need to know what a conflict is before you trust a robot with one."

### Worktrees, the bridge to Orca

End Part 2 with this. It sets up Part 4.

```
git worktree add ../playground-feature -b feature/x
git worktree list
git worktree remove ../playground-feature
```

> "A worktree is a second folder checked out on a different branch, sharing the same history. Two agents in two worktrees can never overwrite each other's files. Orca makes one per task automatically."

### Cheat sheet to put on a slide

| Command | What it does |
| --- | --- |
| `git status` | What changed, what's staged |
| `git add <file>` / `git add .` | Stage changes |
| `git commit -m "msg"` | Save a snapshot |
| `git log --oneline --graph` | History |
| `git switch -c <name>` | Create and move to a branch |
| `git pull` / `git push` | Sync with GitHub |
| `git diff` / `git diff --staged` | See exact changes |
| `git restore <file>` | Throw away unstaged edits |
| `git stash` / `git stash pop` | Park work for a moment |
| `git worktree add <dir> -b <branch>` | A second checkout on a new branch |

### Mistakes to expect

- `Author identity unknown`: they skipped `git config user.name/email`.
- Commits under the wrong email don't link to their GitHub profile. Check with `git log -1 --format=%ae`.
- Windows line-ending warnings (`LF will be replaced by CRLF`) are harmless. Say so before someone panics.
- `git push` asks for a password: the repo was cloned over HTTPS. Since the setup script configured SSH, switch it with `git remote set-url origin git@github.com:<owner>/<repo>.git`, and clone with `gh repo clone` or the SSH URL from now on.
- Committed a secret: deleting it in a new commit is not enough. Rotate the key.

## Part 3 — GitHub, Projects and the gh CLI (50 min)

Each team ends this part with a repo, a Project board, issues on it, and one PR merged. Every step is a `gh` command, so an agent or an Orca automation can run the same steps later.

> "Everything you click on github.com, the GitHub CLI can do from the terminal. Anything the terminal can do, an agent can do. That is how we go from 'AI writes code' to 'AI runs the workflow'."

**Windows note:** the variable syntax below (`X=$(...)`) is bash/zsh. Windows users should run Part 3 in **Git Bash**, which the setup script installs with Git. In PowerShell, `$X = gh ...` works, but cmd.exe cannot do this at all.

### The flow (put it on a slide)

1. Issue created → card in **Backlog**
2. Refined and assigned → **Ready**
3. Branch created, work started → **In Progress**
4. PR opened with `Closes #N` → **In Review**
5. PR approved and merged → issue closes → **Done** (GitHub's built-in project workflow does this move)

### Step 1: team repo (Board owner)

```
ORG=fable-btp-2026          # your event org
REPO=$ORG/team-orca         # one per team
gh repo create $REPO --public --clone --template The-Fable-Club/<starter-template>
# or, without a template:  gh repo create $REPO --public --clone --add-readme
cd team-orca

# add teammates (or add them to an org team in the UI)
gh api -X PUT repos/$REPO/collaborators/<teammate-username> -f permission=push
```

### Step 2: Project board

```
gh project create --owner $ORG --title "Team Orca Board"
NUM=$(gh project list --owner $ORG --format json --jq '.projects[] | select(.title=="Team Orca Board") | .number')
gh project link $NUM --owner $ORG --repo $REPO
```

Then do two things in the browser, because the CLI can't: switch the view layout to **Board**, and edit the **Status** field options to `Backlog, Ready, In Progress, In Review, Done`. Also open **Workflows** and check that "Item closed" and "Pull request merged" set Status to Done.

### Step 3: issues

```
gh label create "type:feature" --color 1D76DB
gh issue create --title "Add dark mode toggle" \
  --body "As a user I want a dark mode toggle so that... Acceptance: ..." \
  --label "type:feature" --assignee @me --project "Team Orca Board"
gh issue list
```

> "Good issues are prompts. Write each one so a new teammate, human or agent, could finish it without asking you anything."

### Step 4: move a card from the CLI

This is the part people find magic. Four lookups, then one edit.

```
PROJECT_ID=$(gh project view $NUM --owner $ORG --format json --jq '.id')
STATUS_ID=$(gh project field-list $NUM --owner $ORG --format json \
  --jq '.fields[] | select(.name=="Status") | .id')
IN_PROGRESS=$(gh project field-list $NUM --owner $ORG --format json \
  --jq '.fields[] | select(.name=="Status") | .options[] | select(.name=="In Progress") | .id')
ITEM_ID=$(gh project item-list $NUM --owner $ORG --limit 200 --format json \
  --jq '.items[] | select(.content.number==1) | .id')

gh project item-edit --id $ITEM_ID --project-id $PROJECT_ID \
  --field-id $STATUS_ID --single-select-option-id $IN_PROGRESS
```

Wrap it once as a function so the team can reuse it:

```
move-card() {  # usage: move-card <issue-number> "<Status name>"
  local opt item
  opt=$(gh project field-list $NUM --owner $ORG --format json \
    --jq ".fields[] | select(.name==\"Status\") | .options[] | select(.name==\"$2\") | .id")
  item=$(gh project item-list $NUM --owner $ORG --limit 200 --format json \
    --jq ".items[] | select(.content.number==$1) | .id")
  gh project item-edit --id "$item" --project-id "$PROJECT_ID" \
    --field-id "$STATUS_ID" --single-select-option-id "$opt"
}
move-card 1 "In Progress"
```

### Step 5: branch, commit, PR (Builder)

```
gh issue develop 1 --checkout --name feat/1-dark-mode   # branch linked to the issue
# ...edit code...
git add . && git commit -m "feat: add dark mode toggle (#1)"
git push -u origin HEAD
gh pr create --base main --title "Add dark mode toggle" --body "Closes #1"
move-card 1 "In Review"
```

### Step 6: review and merge (Reviewer, not the author)

```
gh pr list
gh pr checkout 2          # try it locally
gh pr diff 2
gh pr review 2 --approve  # or --request-changes -b "..."
gh pr merge 2 --squash --delete-branch
gh issue view 1           # now CLOSED, and the card moved to Done
```

> "Notice what just happened: issue, board, branch, PR, review, merge — no browser. Now imagine an agent running these exact commands for ten issues while you review."

Optional 3-minute demo: run your `/start-task` skill in Claude Code on the demo repo. It does Step 4 to Step 5 for an issue on its own.

### Edge cases in this part

| Symptom | Cause | Fix |
| --- | --- | --- |
| `your token has not been granted the required scopes` | No `project` scope | `gh auth refresh -s project` |
| `gh project create` denied in the org | Org members can't create projects | Make yourself owner, or raise members' project permissions in org settings, or use `--owner @me` |
| A project command can't find the project | Wrong `--owner` | Org projects use the org login. Personal ones use `@me` |
| `item-edit` errors on the option | Status names are case-sensitive, or the item id is empty | `echo $ITEM_ID` and check the exact option name with `field-list` |
| An issue isn't on the board | Created without `--project` | `gh project item-add $NUM --owner $ORG --url <issue-url>` |
| `item-list` misses old items | Default limit is 30 | Keep `--limit 200` |
| `Can not approve your own pull request` | GitHub rule | The Reviewer approves. That's the point of the role |
| Push to main rejected | Branch protection | Good. Use a branch and a PR |
| Card doesn't move to Done after merge | PR body lacks `Closes #N`, or the workflow is off | Fix the body, or `move-card N "Done"` |
| `API rate limit exceeded` / GraphQL errors | Projects use GraphQL; the room shares an IP | Each user has their own quota, so this is usually a loop in someone's script. Wait for the reset |

## Part 4 — Orca fundamentals (40 min)

Orca is a free, open-source desktop app (macOS, Windows, Linux) that runs many CLI coding agents side by side. Each task gets its own git worktree, its own agent terminal and its own browser tab. It has no AI model of its own: it launches the agent CLIs you already have (Claude Code, Codex, OpenCode, Antigravity, Gemini, Cursor CLI and about 40 more).

> "Yesterday's workflow: one agent, one chat, you wait. Orca's workflow: five agents, five worktrees, you review. You stop being the typist and become the tech lead."

### The mental model (one slide)

**Repo → Worktree → Agent → Diff → Ship.** Orca's docs say this loop is the whole product.

| Concept | What it is in Orca |
| --- | --- |
| Repo / Project | A local Git checkout you add. Its **base ref** (usually `origin/main`) is what new worktrees branch from |
| Worktree (workspace) | A real `git worktree`: its own folder, branch, terminals, editor tabs and browser tabs |
| Agent session | One agent CLI running in one terminal in one worktree |
| Status glyphs | Spinner = working, amber `?` = needs you, green = done, red = blocked or failed, grey = idle |
| Agent Dashboard | Kanban of all agents across worktrees (Needs You / Working / Done). Turn it on in Settings → Experimental |
| Base ref | Set per repo. Change with `orca repo set-base-ref` or repo settings |

### Live demo: race three agents on one task

1. **Add Repo** in the sidebar → pick the team repo from Part 3.
2. Click **+** next to the repo. Name it `dark-mode`, branch from `origin/main`, pick **Claude Code** in the agent picker. To link it to an issue, paste the issue URL or number in the name field.
3. Repeat twice: `dark-mode-2` with OpenCode (or Codex), `dark-mode-3` with Antigravity (or Gemini).
4. Paste the same prompt into all three: "Implement issue #1. Keep the change small, add a test, and update the README."
5. Drag tabs to the pane edges to split the screen into three.
6. Watch the status glyphs. When they go green, open each diff.
7. On the best one, use **Annotate AI Diff** to leave line comments and send them back to that agent.
8. Commit and push from the **Source Control** panel. **Generate with AI** can draft the message. Then **Create PR**. Put `Closes #1` in the body.
9. Delete the other two worktrees. Their branches go with them.

> "Different agents make different mistakes. Where all three agree, the answer is probably right. Where they disagree, you've found the hard part."

### Settings worth showing

- **Settings → Agents:** the default agent, and each agent's launch arguments. By default Orca launches agents with their permission prompts off (`claude --dangerously-skip-permissions`, `codex --dangerously-bypass-approvals-and-sandbox`, `gemini --yolo`). The idea is that the worktree is the sandbox. **Agent Permissions** switches all of them between Yolo and Manual at once. For a room of beginners on their own laptops, consider telling them to switch to **Manual**.
- **Settings → Repository → Hooks:** commands to run after each worktree is created, such as `npm install`.
- **Settings → Integrations:** connect GitHub. Orca talks to GitHub through `gh`, so `gh auth status` must be healthy.
- **Tasks** sidebar: shows the GitHub Project as a kanban. Dragging a card there writes its Status back to the Project, the same thing `move-card` did in Part 3. You can create a worktree from any card.
- **`Cmd-J` / `Ctrl-J`:** jump between worktrees.

### New worktrees are clean checkouts

Ignored files such as `.env` and `node_modules` are missing in a new worktree. That surprises everyone the first time. Two repo-root files fix it:

```
# .worktreeinclude — gitignored files COPIED into each new worktree
.env
.env.local

# orca.yaml — big gitignored folders SHARED (symlinked) into each worktree
worktree:
  sharedDirectories:
    - node_modules
```

Paths must exist in the main checkout and be gitignored. Globs aren't supported in `.worktreeinclude`.

### Memory files

Orca leaves `CLAUDE.md` and `AGENTS.md` alone; they belong to the agents. Each team should write a short `CLAUDE.md` / `AGENTS.md` with the build command, test command, and rules such as "always reference the issue number in commits". Every agent in every worktree reads it.

### Edge cases

| Symptom | Fix |
| --- | --- |
| Agent won't start | Run its CLI in a normal terminal first. If it fails there, it's a login or install problem. Check Settings → Agents shows it on `PATH` |
| No status glyph on an agent | It was typed by hand in a plain shell. Launch it from the agent picker |
| Worktree creation fails | `git fetch origin` in the repo, or the branch already has a worktree. Pick a new name |
| PR panel says GitHub CLI unavailable or auth failed | `gh auth status`, then fully quit and reopen Orca |
| Laptop slows down | Each worktree keeps file watchers alive, and browser tabs use the most RAM. Sleep or delete idle worktrees |
| Agent hits its usage limit mid-task | The status bar shows usage. Restart the same task with another agent in that worktree: `orca terminal create --worktree active --command "opencode"` |
| Agent exited | Click the **Restart** chip on the tab. Same agent, same folder |

## Part 5 — Orca CLI and orchestration (35 min)

Teach this in three levels: **drive** agents yourself from a terminal, **hand off** work to another agent, then let one agent **supervise** many. The CLI only talks to a running Orca, so `orca status --json` must succeed first.

> "Everything you clicked in Orca has a command. And because it has a command, an agent can click it too. That's how one agent becomes a manager of other agents."

### Level 1: drive agents from your terminal

```
orca status --json
orca repo list --json
orca worktree ps                              # one-line summary of every worktree

# new worktree + agent + first prompt, in one command
orca worktree create --name fix-footer --agent claude \
  --prompt "Fix issue #3: footer overlaps on mobile" --issue 3 --json

orca terminal list --json                     # find the agent's handle
orca terminal read --terminal <handle> --json # what is it doing?
orca terminal wait --terminal <handle> --for tui-idle --timeout-ms 300000 --json
orca terminal send --terminal <handle> --text "Now add a test" --enter --json

# status line on the worktree card, for humans
orca worktree set --worktree active --comment "fix done; running tests" \
  --workspace-status in-review --json
```

Rules to teach with these commands:

- Always pass `--json` in scripts, and `--timeout-ms` on every wait.
- A worktree id is the full `<repoId>::<path>`. The repo id alone isn't a worktree.
- `terminal wait` prints a result even when it times out. Check `satisfied: true` before you send. A prompt sent while an agent is still starting is lost.
- `accepted: true` on a send means the input was received, not that the agent began. Never resend just because nothing happened yet.
- `worktree create` makes a new checkout. For another agent in the same checkout: `orca terminal create --worktree active --command "codex"`.

### Level 2: hand off

A handoff gives a task to another agent and walks away. No tracking.

```
orca worktree create --name docs-refresh --no-parent --agent opencode \
  --prompt "Rewrite the README setup section for Windows users" --json
```

`--no-parent` means "this is independent work", so it branches from the repo's base, not from your current feature branch.

### Level 3: supervised orchestration

Turn it on first: **Settings → Experimental → Orchestration**. The pieces:

| Term | Meaning |
| --- | --- |
| Run | A named job with its own inbox, for example "Ship issues #4–#7" |
| Task | One unit of work with a spec and a status (pending, ready, dispatched, completed, failed, blocked) |
| Dispatch | One attempt of a task on one worker terminal |
| Worker | A supervised agent doing one task. It must report `worker_done` exactly once |
| Message | Inbox mail: `worker_done`, `question`, `escalation`, `heartbeat`… |
| Decision gate | A question that blocks a task until a human or coordinator answers |

The coordinator loop, typed by hand:

```
orca orchestration run-create --objective "Ship issues #4 to #6" --json

orca orchestration worker-start --spec "Issue #4: add a dark mode toggle. Target: src/theme. Done when: toggle works and npm test passes." \
  --worktree new-child --name issue-4 --agent claude --setup run --json
orca orchestration worker-start --spec "Issue #5: ..." --worktree new-child --name issue-5 --agent opencode --setup run --json
orca orchestration worker-start --spec "Issue #6: ..." --worktree new-child --name issue-6 --agent antigravity --setup run --json

# wait for any worker to finish, ask, or escalate (15 min)
orca orchestration check --wait --types worker_done,escalation,question --timeout-ms 900000 --json
orca orchestration reply --id <message_id> --body "Only change this page" --json
orca orchestration worker-release --dispatch <dispatch_id> --json
orca orchestration check --ack <delivery_id> --wait --types worker_done,escalation,question --timeout-ms 900000 --json
```

Useful extras:

- `--model <id> --effort high` on `worker-start` picks a model per worker (Claude, Codex, Cursor, Antigravity, OpenCode, Muse).
- `orca orchestration task-create` + `worker-start --task <id>` when tasks depend on each other. Prefer parallel waves over long chains.
- `orca orchestration send --to @all --subject "Pause" --body "..."`. Groups include `@idle`, `@claude`, `@codex`, `@opencode`.
- Workers ask blocking questions with `orca orchestration ask --question "..." --options "a,b"`, so they never get stuck at a local prompt.
- `orca orchestration worker-read --dispatch <id>` reads a worker's output after its terminal is released.

### The demo that lands: let an agent be the manager

Install Orca's own skills so agents know these commands, then give the coordinator a plain-English goal:

```
orca skills install --skill orca-cli --skill orchestration
# or: npx skills add https://github.com/stablyai/orca --skill orca-cli
```

In a Claude Code terminal inside Orca, prompt:

> "Use the orchestration skill. Read open issues with gh issue list. For each issue labelled ready, start a supervised worker in its own child worktree: Claude for backend, OpenCode for frontend. Each worker must open a PR with Closes #N. Wait for all of them, answer their questions, then give me a summary table."

Then step back and narrate the Agent Dashboard as cards move from Working to Needs You to Done.

### Edge cases

- Orchestration commands do nothing: the Experimental toggle is off, or Orca isn't running.
- `orca orchestration run` / `coordinator-start` print a notice and do nothing. They were retired. Use `run-create` + `worker-start`.
- Don't run `orca orchestration reset` while another coordinator is active. It wipes runtime-wide state.
- Antigravity supervised workers work only in local child worktrees, not over SSH.
- A worker that never sends `worker_done` isn't necessarily dead. Use `worker-list` and `worker-show` before stopping anything.
- Several agents in one worktree edit the same files. Use `--worktree new-child` for parallel work.

## Part 6 — Automations: scheduled agent jobs (20 min)

An Orca automation is a cron job whose action is "start this agent with this prompt". Each run either creates a fresh worktree in a repo (`--repo`) or reuses an existing one (`--workspace`). Teach the safe habit first: create it **disabled**, run it once by hand, read the result, then enable it.

> "Cron is how servers do chores on a timer. Orca lets the chore be 'ask an agent to review every new PR' or 'triage new issues every morning at nine'."

### Cron in 60 seconds

Five fields: **minute hour day-of-month month day-of-week** (Sunday = 0). Orca also takes the presets `hourly`, `daily`, `weekdays`, `weekly` (with `--time HH:MM`, and `--day 0-6` for weekly) and RRULE strings.

| Schedule | Means |
| --- | --- |
| `0 9 * * 1-5` | 09:00, Monday to Friday |
| `*/30 * * * *` | Every 30 minutes |
| `0 18 * * *` | 18:00 every day |
| `0 10 * * 1` | 10:00 every Monday |
| `15 */2 * * *` | 15 minutes past every second hour |

Times use the host's timezone unless you pass `--timezone Asia/Kolkata` (any IANA name).

### The safe first automation (hands-on)

```
orca automations create \
  --name "Morning triage" \
  --trigger weekdays --time 09:00 --timezone Asia/Kolkata \
  --prompt "List open issues with gh. Add a type label to any unlabelled issue and post a one-line summary comment on issues older than 3 days. Do not close anything." \
  --provider claude \
  --repo name:team-orca \
  --disabled --json

orca automations list --json
orca automations run <automationId> --json        # try it now
orca automations runs --id <automationId> --json  # check the result
orca automations edit <automationId> --enabled --json
```

Hand out [`docs/orca-automations.md`](orca-automations.md). It explains each field of the Create automation dialog and has 10 copy-paste templates with safe prompts and working prechecks.

### Three recipes for the event repos

**1. Hourly PR reviewer, only when there's something to review.** `--precheck` runs a shell command first. Exit 0 starts the agent, anything else records a skipped run and costs nothing.

```
orca automations create --name "PR review" --trigger hourly \
  --precheck 'test -n "$(gh pr list --json number -q ".[].number")"' \
  --prompt "For each open PR without a review from you, run gh pr diff, then post a review comment with gh pr review --comment. Never approve or merge." \
  --provider claude --repo name:team-orca --disabled --json
```

Warn the room: the Orca docs' example precheck is `gh pr list --json number -q .[0].number`. That exits 0 even when there are no PRs, so it never skips. Wrapping it in `test -n "..."` makes an empty list exit 1. Check it in a terminal with `...; echo $?`.

**2. End-of-day status in an existing worktree, continuing the same session.**

```
orca automations create --name "Daily status" --trigger "0 18 * * 1-5" \
  --prompt "Summarize today's merged PRs and the board's In Progress column as a short markdown note in STATUS.md" \
  --provider claude --workspace active --reuse-session --disabled --json
```

**3. Cheaper model for chores.** `--extra-agent-args="--model haiku"`. Write it with `=`, because the value starts with `--`. Only model and effort options (and Claude's `--add-dir`) are allowed. It can't be combined with `--reuse-session`.

### Management commands

| Command | Use |
| --- | --- |
| `orca automations show <id> --json` | Inspect one |
| `orca automations edit <id> --trigger "0 8 * * *"` | Change schedule, prompt, provider, target |
| `orca automations edit <id> --missed-run-grace-minutes 30` | Still run a job missed by up to 30 min (laptop asleep) |
| `orca automations edit <id> --fresh-session` | Stop reusing the old terminal |
| `orca automations remove <id>` | Delete it and its run history |

The desktop **Automations** page shows the same list, with filters for host, enabled or paused, last-run result and agent.

### Edge cases to say out loud

- **It only runs where Orca is running.** An automation is stored and scheduled on one host. If your laptop is closed at 09:00, the run is missed unless it falls within the grace window. For real always-on jobs, put them on a Remote Orca Server (Part 7) with `--host runtime:<environment-id>`.
- **Every `--repo` run makes a new worktree.** They pile up. Use the sidebar filter that hides automation-created workspaces, and clean up in Resource Manager.
- **Unattended agents run with permission prompts off.** Write prompts with explicit limits ("never merge", "never push to main", "don't delete files") and protect `main` with branch protection.
- **Cost.** An hourly job is 24 agent sessions a day. Use a precheck and a cheaper model.
- **GitHub rate limits are shared** by Orca, your terminals and every agent calling `gh` (5,000 REST calls an hour). A tight cron loop can lock your account out for the hour.
- **Agents that take the prompt after they start** (Aider, Goose, Amp) get it typed in once ready. Claude and Codex take it on the command line.

## Part 7 — SSH targets, Remote Orca Servers and cloud VMs (15 min)

Orca can run agents on machines other than your laptop. It's **SSH** (Secure Shell), not SSL. Demo it rather than having everyone do it, because it needs a server most students don't have. Orca doesn't sell hosting: every remote mode uses a machine or cloud account you control.

> "Your laptop is the steering wheel, not the engine. Agents can run on a lab server, a GPU box or a $5 VPS. They keep working when you close the lid, and you reconnect from your laptop or your phone."

### The four ways to run Orca

| Mode | Where agents and files live | Who owns the runtime | Use it when |
| --- | --- | --- | --- |
| Local | Your laptop | Your laptop's Orca | Day-to-day work, short tasks |
| SSH target | A remote host over SSH | Your laptop's Orca drives it | You have a dev box, VPS or GPU host and want agents there |
| Remote Orca Server | A machine running Orca desktop or `orca serve` | The remote machine | Agents must survive your laptop sleeping; phone access; always-on automations |
| Cloud VM (per-workspace) | A fresh sandbox per worktree, from a recipe in `orca.yaml` | Your cloud account (Vercel Sandbox, Fly, Modal, Docker…) | A clean, disposable environment for every task |

### SSH basics (2 min, for beginners)

```
ssh-keygen -t ed25519 -C "you@example.com"   # creates ~/.ssh/id_ed25519 (+ .pub)
ssh-copy-id user@server.example.com           # macOS/Linux; on Windows paste the .pub into the server's ~/.ssh/authorized_keys
ssh user@server.example.com                   # should log in without a password
```

An entry in `~/.ssh/config` lets Orca import the host by name:

```
Host labbox
  HostName server.example.com
  User student
  IdentityFile ~/.ssh/id_ed25519
```

### Demo: SSH worktree

1. **Settings → SSH → Add Target.** Fill in host, user, port and identity file, or use the OpenSSH config picker to choose `labbox`.
2. Click **Test**, then **Save**. On first contact Orca shows the host-key fingerprint and remembers it.
3. On first connect, Orca installs its own **managed server** on the host, with a pinned Node runtime, so the host's Node version doesn't matter. Git must be on the host.
4. Add the repo with the SSH target as its location, or clone it on the host from the create dialog ("Set project location").
5. Create a worktree and choose the host under **Run on**. `git worktree add` and the agent run on the remote. The editor, diff and UI stay on your laptop.
6. Start a dev server on the remote. The **Ports** tab (`Cmd+Shift+I`) detects it. One click forwards it to your laptop. Privileged ports remap (remote 80 → local 10080).
7. Close the laptop lid, reopen, reconnect: the agent kept running and the scrollback is restored.

What must be on the **remote** host, because nothing carries over from your laptop: Git, the agent CLI **logged in there**, and `gh auth login` done **there**.

### Demo: Remote Orca Server (always-on)

The easiest path is Orca desktop + Tailscale on both machines, signed in to the same tailnet.

1. On the server: **Settings → Remote Orca Servers → Advertise this app as a server → New Link**. Pick the Tailscale address (`100.x.y.z`) and **Generate Access Link**.
2. On the laptop: **Settings → Remote Orca Servers → Add Server**, name it and paste the link. **Connect**.
3. Projects, worktrees, terminals and agents now live on the server. Clients are just the UI.

Headless Linux box instead of a desktop app:

```
orca serve --pairing-address 100.64.1.20            # prints a pairing URL; Ctrl-C stops it
orca serve --pairing-address 100.64.1.20 --mobile-pairing   # QR code for the Orca phone app
orca serve service install --port 6768              # systemd user unit (Linux) / LaunchAgent (macOS)
orca serve service status
loginctl enable-linger $USER                        # Linux: keep it running after logout

# accounts and skills on a headless server
orca account add --agent claude
orca skills install --skill orca-cli --skill orchestration
```

On the laptop, `orca environment add` saves a server from its pairing code and `orca environment list` shows its id. Then `orca automations create ... --host runtime:<environment-id>` schedules an automation on the always-on server.

### Security points to say out loud

- A pairing link is a password. Never paste it in a group chat or show it on the projector. Revoke a leaked one under **Shared Server Access**.
- Never expose the Orca port to the public internet. Use Tailscale, WireGuard, a LAN or SSH forwarding.
- Don't pick `127.0.0.1` as the pairing address for another computer.
- A changed host key is rejected on purpose. Verify the new fingerprint before using the `ssh-keygen -R` command Orca suggests.
- Agents on an SSH host can only control that host's own terminals by default. **Allow this host's orca CLI to control Orca** (host → Advanced Connection) is needed for remote agents to create worktrees. Turn it on only for hosts you trust.

### Edge cases

| Symptom | Fix |
| --- | --- |
| Test fails: auth | Key not in the server's `authorized_keys`, or wrong user. Check with plain `ssh` first |
| Connect fails with a reason in Settings → SSH Hosts | The managed server can't run there (unsupported OS/CPU, `noexec` home, port forwarding refused by the SSH server) |
| Can't download the Node runtime | Use the offered **Use a Node.js mirror…**, or fix it in Settings → Advanced → Network |
| Agent "not found" on the remote | Install and log in to it on the remote. The remote uses its own `PATH` and home folder |
| PR panel empty for an SSH worktree | `gh auth login` on the remote host |
| Tailscale address not listed | Tailscale isn't connected on the server. Reconnect, then press refresh next to Connection address |
| "Download Folder" missing | The connection lacks full SFTP. Use `scp` or `tar` |
| MFA or OTP prompt on the host | Orca relays the prompt to you. Answer it in the dialog |

## Team capstone (60 min) and demos (15 min)

Each team ships one small feature set through the full board flow, with agents doing the coding and humans doing planning and review. Judge the process, not the app: a clean board, linked PRs and real reviews beat a flashy demo.

> "You're the tech leads now. Plan the work as issues, let agents build in parallel, and make sure nothing reaches main without a human reading it."

### Roles

| Role | Owns | Main tools |
| --- | --- | --- |
| Board owner | Writes 4–6 issues with acceptance criteria, keeps the board accurate | `gh issue create`, `move-card`, Orca **Tasks** |
| Builders (1–2) | One worktree and agent per issue, steering the agent | Orca worktrees, `orca worktree create --agent`, orchestration |
| Reviewer | Reads every PR diff, requests changes, merges | `gh pr review`, Orca diff + Annotate AI Diff |

### Timeline

1. **0–10 min:** pick a feature set for the starter app. Board owner writes the issues; everyone agrees on "done" for each.
2. **10–45 min:** builders launch one agent per issue in Orca, in parallel. Stretch goal: one builder runs an orchestration coordinator over all the issues.
3. **Every PR:** body has `Closes #N`; card goes to In Review; Reviewer approves or requests changes; squash-merge.
4. **45–55 min:** create one disabled automation for the repo and run it once.
5. **55–60 min:** freeze. Prepare a 2-minute demo.

### Scoring (optional)

| Points | For |
| --- | --- |
| 3 | Each issue closed by a merged PR with `Closes #N` |
| 2 | Each PR with a real review comment that led to a change |
| 3 | Two or more agents worked in parallel worktrees |
| 3 | Orchestration coordinator used |
| 2 | An automation created and run once |
| −2 | Any direct push to `main` |

### Demo format (2 min per team)

Show the board (all Done), one PR with its review thread, and the running app. Then one sentence: "What did an agent get wrong, and how did you catch it?" That answer is the real lesson of the day.

## Troubleshooting — quick reference for volunteers

Print this table for every volunteer. The part-specific tables above have more detail.

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| `command not found` right after installing | Stale terminal `PATH` | Open a new terminal |
| `orca: command not found` | CLI not registered | Orca → Settings → General → Orca CLI, new terminal |
| `orca status` fails | Orca app closed | `orca open` |
| Orca says GitHub CLI unavailable | `gh` missing or not on Orca's `PATH` | Install `gh`, fully quit and reopen Orca |
| GitHub auth errors in Orca | `gh` logged out, or stale `GITHUB_TOKEN` / `GH_TOKEN` in the shell profile | `unset GITHUB_TOKEN GH_TOKEN`, then `gh auth login` |
| Projects commands fail with a scope error | Missing `project` scope | `gh auth refresh -s project` |
| `API rate limit exceeded` | 5,000 REST calls/hour per user, shared by Orca, terminals and agents | Stop loops and automations, wait for the reset. Check with `gh api rate_limit` |
| HTTP 403 (not rate limit) or 404 | No access to the repo, or wrong remote | `git remote -v`; confirm the repo opens in the browser |
| Agent won't start in Orca | Agent not installed or not logged in | Run it in a normal terminal first |
| No agent status glyph | Agent typed by hand in a plain shell | Launch from the agent picker |
| Agent out of usage | Plan limit | Switch to the team's backup agent in the same worktree |
| `.env` missing in the worktree | New worktrees are clean checkouts | `.worktreeinclude`, or Settings → Repository → Worktree Shared Paths |
| Worktree creation fails | Base ref not fetched, or branch already checked out | `git fetch origin`; use a new name |
| Merge conflict after agents' PRs | Two agents touched the same file | Source Control → **Resolve with AI**, or resolve by hand and review |
| Commit fails on a pre-commit hook | Lint or test failed | **Fix with AI** in the failure details, then commit again |
| Laptop slow | Too many worktrees and browser tabs | Sleep or delete idle worktrees |
| Need logs for a bug report | — | Help → Open Logs; Help → Send Feedback |

## Open questions for the organizers

- [ ] How long is the event? The run of show assumes about 5.5 hours. A 3-hour slot should cut Part 7 to a 5-minute demo and halve the capstone.
- [ ] Which agent is the official one, and what is the free fallback for people without a paid plan?
- [ ] Will the chosen agent CLI be added to `setup.zsh` / `setup.bat`, or covered by the pre-event email? (`gh` and GitHub SSH are now handled by the scripts.)
- [ ] Is there an SSH server or always-on machine for the Part 7 demo (lab box, VPS, Mac mini)?
- [ ] Is the event GitHub org created, and is the starter template repo ready?
- [ ] Should participants switch agents to Manual permissions for the day?
- [ ] Timezone for the automation examples: Asia/Kolkata is assumed.

## Sources

Orca commands were checked against the installed Orca CLI 1.4.220 (`orca --help`, `orca skills get orca-cli`, `orca skills get orchestration`) and these pages:

- [Orca docs home](https://www.onorca.dev/docs) · [Install](https://www.onorca.dev/docs/install) · [Your first 3-agent session](https://www.onorca.dev/docs/first-session)
- [Worktrees](https://www.onorca.dev/docs/model/worktrees) · [Agents & sessions](https://www.onorca.dev/docs/model/agents-sessions) · [Supported agents](https://www.onorca.dev/docs/agents/supported) · [Agent hooks & memory](https://www.onorca.dev/docs/agents/hooks-memory)
- [Commit & push](https://www.onorca.dev/docs/review/commit-push) · [Hosted reviews, issues & Actions](https://www.onorca.dev/docs/review/github)
- [CLI overview](https://www.onorca.dev/docs/cli/overview) · [Orchestration](https://www.onorca.dev/docs/cli/orchestration) · [Scheduled automations](https://www.onorca.dev/docs/cli/automations) · [Worktree checkpoints](https://www.onorca.dev/docs/cli/worktree-checkpoints)
- [Ways to run Orca](https://www.onorca.dev/docs/ways-to-run) · [SSH worktrees](https://www.onorca.dev/docs/ssh) · [Remote Orca Servers](https://www.onorca.dev/docs/remote-servers)
- [Troubleshooting](https://www.onorca.dev/docs/troubleshooting) · [GitHub errors](https://www.onorca.dev/docs/github-errors)
- [GitHub CLI manual](https://cli.github.com/manual) (gh 2.93: `gh project item-edit`, `field-list`, `item-list`)
- [beyond-the-prompt repo](https://github.com/The-Fable-Club/beyond-the-prompt) (`README.md`, `setup.zsh`, `setup.bat`)
