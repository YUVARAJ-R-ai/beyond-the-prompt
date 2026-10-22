# Zepher Guide — Beyond the Prompt

Zepher (`zepher-cli`, command `zepher`) is the shared memory and rulebook for every AI agent on your team. You write project rules, decisions, tasks and skills **once** in a `.zepher/` folder. `zepher sync` then writes them into each agent's own config file: `CLAUDE.md` for Claude Code, `.cursorrules` for Cursor, `.gemini/rules/` for Antigravity/Gemini, `.windsurfrules`, and `.github/copilot-instructions.md`. Every agent your team runs in Orca follows the same rules and remembers the same decisions.

Checked against `zepher-cli` **0.3.1** (`zepher --help` on every command) and the [Zepher README](https://github.com/YUVARAJ-R-ai/zepher#readme).

- npm: [zepher-cli](https://www.npmjs.com/package/zepher-cli) · Source: [github.com/YUVARAJ-R-ai/zepher](https://github.com/YUVARAJ-R-ai/zepher) · Requires Node.js 18+
- Spelling: **zepher** with an **e**. `zephyr-cli` is a different package.

---

## Why it matters at this event

| Problem in a team using agents | What Zepher does | Command |
| :--- | :--- | :--- |
| Each teammate's agent follows different rules | One rule set, compiled into every agent's config | `zepher rule add` → `zepher sync` |
| Agents forget decisions when the context window resets | Decisions (ADRs) and memory live in files the agent reads | `zepher adr create`, `zepher remember` |
| Claude in one worktree doesn't know what Antigravity did in another | A handoff note with branch, commits and open tasks | `zepher handoff` |
| Skills only exist on one person's laptop | Skills are kept in the repo under `.zepher/skills/` and shared | copy folder, `zepher skill pin`, `zepher skill link` |
| `.env` files get pasted into chat or committed | Encrypted team vault, `.gitignore`d automatically, secrets masked for AI | `zepher vault track/seal/unseal` |
| Someone hand-edits `CLAUDE.md` and the team drifts | CI check that fails on drift | `zepher verify` |

How it fits the day: **GitHub Projects** holds *what* to build (issues, board). **Zepher** holds *how* to build it (rules, decisions, memory, skills). **Orca** runs the agents that do the building.

---

## Install and check

The event setup script already installs it. To do it by hand:

```bash
npm install -g zepher-cli
zepher --version      # 0.3.1
zepher doctor         # health check
```

---

## First 5 minutes in a team repo (do this once per team)

```bash
cd team-repo
zepher init                       # creates .zepher/ and AGENTS.md (and ~/.zepher on first use)

# team rules — every agent will follow these
zepher rule add "Reference the GitHub issue number in every commit message, e.g. 'feat: add login (#12)'" \
  -t "Commit convention" -p 90 --always-apply
zepher rule add "Run npm test before saying a task is done" -t "Verify before done" -p 85 --always-apply
zepher rule add "Use TypeScript strict mode; never use 'any'" -t "Typing" --globs "src/**/*.ts" -p 70

# a decision the whole team agreed on
zepher adr create "Use Vite + React for the frontend" -s Accepted \
  -c "Fast dev server, team knows React" -d "Vite + React 18 + Tailwind" -a "Next.js, plain HTML"

# preview, then write CLAUDE.md, .cursorrules, .claude.json (MCP) etc.
zepher sync --dry-run
zepher sync

git add .zepher AGENTS.md CLAUDE.md .cursorrules .claude.json
git commit -m "chore: add Zepher rules and decisions"
git push
```

Teammates pull and run `zepher sync`. Everyone's agents now share the same instructions.

> If the repo already has a hand-written `CLAUDE.md` or `.cursorrules`, `zepher sync` stops instead of overwriting it. Run `zepher import` first to pull those rules into Zepher. Use `--force` only if you are sure.

---

## Using the event skills from this repo with Zepher

This repo's [`skills/`](../skills/) folder holds the event skills (`/new-issue`, `/start-task`, `/plan-project`, TDD, debugging, code review…).

**Important:** `zepher skill install <path>/SKILL.md` copies **only** the `SKILL.md` file. Skills with extra files (`systematic-debugging`, `brainstorming`, `software-inception`, `se-docs`…) lose them. Copy whole folders instead:

```bash
# share with the team: put the skill in the repo
mkdir -p .zepher/skills
cp -r ../beyond-the-prompt/skills/new-issue ../beyond-the-prompt/skills/start-task .zepher/skills/
zepher skill list
zepher sync

# or just for you, on every project: global scope
cp -r ../beyond-the-prompt/skills/* ~/.zepher/skills/
zepher skill link          # exposes ~/.zepher/skills to Claude Code and Antigravity
```

Windows: `zepher skill link` creates symlinks, which need Developer Mode or an admin prompt. Use `zepher skill link --copy` instead.

Single-file skills (`new-issue`, `start-task`, `plan-project`, `scrum-board`…) also work with `zepher skill install ./skills/new-issue/SKILL.md`.

---

## Daily loop during the capstone

```bash
zepher status                                   # what's active
zepher task create "Issue #4 dark mode" -o "Toggle in header, persists in localStorage"
zepher task list
zepher remember "API base URL comes from VITE_API_URL" -t architecture
zepher recall "API"
zepher task block <id> -r "Waiting for backend endpoint #7"
zepher task complete <id>
zepher handoff -o "Dark mode" -c "Toggle + tests done" -a "Review PR #9"   # before switching agent or worktree
zepher context                                  # refresh .zepher/context/current.md
```

Tip for Orca: before starting a new agent in another worktree on the same feature, run `zepher handoff`. Then tell the new agent: "Read the latest file in `.zepher/handoffs/` first."

---

## Connecting agents (MCP)

`zepher mcp` starts a stdio MCP server. `zepher sync` registers it for you in `.claude.json` (Claude Code) and `.cursor/mcp.json` (Cursor):

```json
{ "mcpServers": { "zepher": { "command": "zepher", "args": ["mcp"] } } }
```

Claude Code also accepts `claude mcp add zepher -- zepher mcp`.

The server gives agents these tools, so they can read and update Zepher by themselves:

| MCP tool | What the agent uses it for |
| :--- | :--- |
| `zepher_project_context` | Load rules, stack, active tasks, blockers, ADRs and memory before working |
| `zepher_search_memory` / `zepher_write_memory` | Look up or save conventions, architecture notes, constraints, lessons |
| `zepher_task_create` / `_list` / `_complete` / `_block` | Track its own sub-tasks |
| `zepher_decision_create` / `zepher_decision_list` | Record or check ADRs before big changes |
| `zepher_get_rules` / `zepher_add_rule` | Read or add engineering rules |
| `zepher_list_skills` | See available skills |
| `zepher_sync` | Re-generate agent config files after adding rules or skills |
| `zepher_generate_handoff` | Write a handoff note at the end of a session |

The intended agent loop (written into `AGENTS.md` by `zepher init`) is: **before work** read context, tasks and decisions. **During work** create and block tasks, and record decisions. **After work** complete tasks, write memory, generate a handoff and sync.

---

## Full command reference (zepher-cli 0.3.1)

### Setup and health

| Command | Options | What it does |
| :--- | :--- | :--- |
| `zepher init` | `-g, --global` | Create `.zepher/` (and `AGENTS.md`) in this project, or `~/.zepher` with `-g` |
| `zepher status` | | Project status, active tasks, memory, tracked files |
| `zepher doctor` | | Health check of paths, lockfiles, integrations |
| `zepher capabilities` | | Which features and integrations are active |
| `zepher agent bootstrap` | | Generate a full agent setup (`AGENTS.md`, project skills, agent personas) |

### Sync to agents

| Command | Options | What it does |
| :--- | :--- | :--- |
| `zepher sync` | `-d, --dry-run` · `-f, --force` · `-a, --adapter <cursor\|claude\|windsurf\|copilot\|gemini>` | Write rules and skills into each agent's config and register the MCP server |
| `zepher watch` | | Re-sync automatically whenever `.zepher/` changes |
| `zepher verify` | | Exit non-zero if committed agent files drifted from Zepher (use in CI) |
| `zepher import` | `-f, --force` | Pull rules out of existing `CLAUDE.md`, `.cursorrules`, etc. into Zepher |

### Rules

| Command | Options | What it does |
| :--- | :--- | :--- |
| `zepher rule add "<text>"` | `-t <title>` · `-p <1-100>` · `--tags a,b` · `--globs "src/**/*.ts"` · `--always-apply` · `-g` | Add a rule. Higher priority appears first. Globs scope it to files |
| `zepher rule list` | | List global and project rules with IDs |
| `zepher rule remove <id>` | `-g` | Remove a rule |

### Memory, context, handoffs

| Command | Options | What it does |
| :--- | :--- | :--- |
| `zepher remember "<text>"` | `-t <conventions\|architecture\|project\|constraints\|lessons>` (default conventions) · `-g` | Save a fact. Secrets are scanned for and refused |
| `zepher recall "<query>"` | | Search project and global memory |
| `zepher context` | | Rebuild `.zepher/context/current.md` |
| `zepher handoff` | `-o <objective>` · `-c <completed>` · `-b <blockers>` · `-n <notes>` · `-a <next action>` | Write a session handoff (adds branch, recent commits, active tasks) to `.zepher/handoffs/` |

### Tasks

| Command | Options | What it does |
| :--- | :--- | :--- |
| `zepher task create "<name>"` | `-o <objective>` | New task in `.zepher/tasks/active/` |
| `zepher task list` | `-s <active\|completed\|blocked\|all>` | List tasks (default active) |
| `zepher task show <id>` | | Task details |
| `zepher task complete <id>` | | Move to `completed/` |
| `zepher task block <id>` | `-r <reason>` | Move to `blocked/` with a reason |

### Architecture decisions (ADRs)

| Command | Options | What it does |
| :--- | :--- | :--- |
| `zepher adr create "<title>"` | `-s <Proposed\|Accepted\|Deprecated\|Superseded>` · `-c <context>` · `-d <decision>` · `-a <alternatives>` | Write `.zepher/decisions/ADR-XXXX-<title>.md` |
| `zepher adr list` | | List ADRs |
| `zepher adr show <query>` | | Show an ADR by number, ID or title words |

### Skills

| Command | Options | What it does |
| :--- | :--- | :--- |
| `zepher skill install <path-or-URL-to-SKILL.md>` | `-n <name>` · `-g` | Install a single-file skill (see the folder note above) |
| `zepher skill list` | | List skills with versions and source |
| `zepher skill update [name]` | `-a, --all` · `-g` | Update from upstream source |
| `zepher skill pin <name>` | | Copy a global skill into the project to freeze its version |
| `zepher skill unpin <name>` | | Go back to the global version |
| `zepher skill remove <name>` | `-g` | Remove a skill |
| `zepher skill harvest` | `-l, --local` · `--overwrite` | Collect skills from `~/.claude` and `~/.gemini` into Zepher |
| `zepher skill link` | `--copy` | Share Zepher's global skills with Claude Code and Antigravity |

### Hooks

| Command | Options | What it does |
| :--- | :--- | :--- |
| `zepher hook add <name>` | `-s <pre-sync\|post-sync\|pre-commit\|post-commit>` · `-r "<command>"` · `-g` | Run a command at a stage, e.g. `zepher hook add tests -s pre-commit -r "npm test"` |
| `zepher hook list` | | List hooks |
| `zepher hook run <stage>` | | Run a stage's hooks now |
| `zepher hook remove <name>` | `-g` | Remove a hook |
| `zepher hook install-git` / `uninstall-git` | | Add or remove the bridge in `.git/hooks/pre-commit` |

### Vault (secrets) and assets (big files)

| Command | Options | What it does |
| :--- | :--- | :--- |
| `zepher vault track <path>` | `-t <secret\|seed\|binary\|doc>` | Track a private file and add it to `.gitignore` |
| `zepher vault seal` | `-p <passphrase>` | Encrypt tracked files to `.zepher/vault/*.enc` (AES-256-GCM) |
| `zepher vault unseal` | `-p <passphrase>` | Decrypt, merging with your local `.env` edits |
| `zepher vault status` | | What is tracked, sealed or changed |
| `zepher asset track <path>` | `-t <tag>` · `-s <local\|r2\|s3\|ssh>` | Track a large file outside Git |
| `zepher asset stash <path>` | | Store it in the blob store |
| `zepher asset pull <path>` | | Restore it with a SHA-256 check |

### Integrations and MCP

| Command | What it does |
| :--- | :--- |
| `zepher integrate` | Interactive menu of integrations (codebase-memory-mcp, Graphify, Everything Claude Code) |
| `zepher integrate status` / `doctor` | Show or check integrations |
| `zepher integrate enable <id>` / `disable <id>` | Turn one on or off |
| `zepher mcp` | Start the MCP server (agents launch this, not you) |

---

## Safety notes

- **Always pass your own vault passphrase.** If you leave out `-p`, `zepher vault seal`/`unseal` uses the built-in default `zepher-team-key`. Anyone with the repo could decrypt it. Use a long random passphrase from the team's password manager.
- Prefer `-p "$TEAM_VAULT_KEY"` (an environment variable) to typing the passphrase itself, so it stays out of shell history. Never put it in a rule, memory note or chat with an agent.
- Commit `.zepher/` (rules, decisions, tasks, skills, `vault/*.enc`), never the unsealed files. `vault track` already `.gitignore`s them.
- `zepher sync` writes **all** of your global skills into `CLAUDE.md`. If you have many personal skills, that file gets large. Keep event skills in the project's `.zepher/skills/` and review `zepher sync --dry-run` before committing.
- Run `zepher verify` in CI (or `zepher hook install-git`) so hand-edits to `CLAUDE.md` get caught.

## Troubleshooting

| Symptom | Fix |
| :--- | :--- |
| `zepher: command not found` | Open a new terminal. Check `npm prefix -g`'s `bin` folder is on `PATH`, or re-run the setup script |
| `sync` refuses to write `CLAUDE.md` | It was hand-written. Run `zepher import`, then `zepher sync` |
| Skill missing its helper files | It was installed with `skill install`. Copy the whole folder into `.zepher/skills/` |
| `skill link` fails on Windows | `zepher skill link --copy` |
| Agent doesn't see Zepher tools | Run `zepher sync`, restart the agent, check `.claude.json` has the `zepher` MCP entry |
| `verify` fails in CI | Someone edited a generated file. Run `zepher sync` and commit |
