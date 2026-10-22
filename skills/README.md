# Event Skills

These are the agent skills used at Beyond the Prompt. Each folder holds a `SKILL.md`, and some include helper files. They work in Claude Code, Antigravity/Gemini and any agent that reads `SKILL.md` skills. In Claude Code, run one by typing its trigger, for example `/new-issue`, or just describe the task.

## Install

Copy the **whole folder** of each skill you want. Don't copy only `SKILL.md`, because several skills ship helper files.

```bash
# macOS / Git Bash: for you, in every project (Claude Code)
mkdir -p ~/.claude/skills && cp -r skills/* ~/.claude/skills/

# for your team, in one repo (shared through Git, works with Zepher)
mkdir -p .zepher/skills && cp -r ../beyond-the-prompt/skills/new-issue .zepher/skills/

# with Zepher, for you everywhere, then share with Claude Code + Antigravity
cp -r skills/* ~/.zepher/skills/ && zepher skill link        # Windows: zepher skill link --copy
```

```bat
:: Windows Command Prompt, for you, in every project (Claude Code)
xcopy /E /I /Y skills "%USERPROFILE%\.claude\skills"
```

Restart the agent after installing. See [docs/zepher-guide.md](../docs/zepher-guide.md) for the Zepher commands.

**Prerequisites:** `git`, `gh` signed in (the setup script does this), and for `new-issue`, `start-task` and `plan-project`, also `jq`. On Windows, run those three from **Git Bash** (`jq`: `winget install jqlang.jq`). On macOS: `brew install jq`.

## Which skill for which part of the day

### GitHub workflow (Part 3 and capstone)

| Skill | Trigger | What it does |
| :--- | :--- | :--- |
| [plan-project](plan-project/) | `/plan-project` | Create the GitHub Project board, turn requirements into user stories and issues, plan sprints, assign teammates |
| [new-issue](new-issue/) | `/new-issue` | Turn a one-line idea into a structured issue with acceptance criteria, added to the board as Backlog |
| [start-task](start-task/) | `/start-task` | Pick your assigned issue, refine it, move it to Ready, branch, implement, commit, raise the PR, move it to In Review |
| [scrum-board](scrum-board/) | — | Sprint markdown files from a task list |
| [project-research](project-research/) | — | Research a project idea: features, tech choices, competitors, risks |

### Planning and requirements

| Skill | What it does |
| :--- | :--- |
| [brainstorming](brainstorming/) | Shape an idea into a design before coding |
| [writing-plans](writing-plans/) / [executing-plans](executing-plans/) | Write a step-by-step implementation plan, then carry it out |
| [implementation-plan-reviewer](implementation-plan-reviewer/) | Review a plan for gaps, risks and missing steps |
| [sdlc-init](sdlc-init/) / [software-inception](software-inception/) | Full front-end of the lifecycle: stakeholders → requirements → SRS → architecture |
| [stakeholder-requirements](stakeholder-requirements/), [requirements-analysis](requirements-analysis/), [functional-requirements](functional-requirements/), [non-functional-requirements](non-functional-requirements/), [system-building](system-building/), [architecture-building](architecture-building/) | Individual phases of the above |

### Building and quality

| Skill | What it does |
| :--- | :--- |
| [test-driven-development](test-driven-development/) | Write the failing test first, then the code |
| [systematic-debugging](systematic-debugging/) | Find the root cause before proposing a fix |
| [verification-before-completion](verification-before-completion/) | Run the checks before saying "done" |
| [requesting-code-review](requesting-code-review/) / [receiving-code-review](receiving-code-review/) | Ask for and act on PR reviews properly |
| [using-git-worktrees](using-git-worktrees/) / [finishing-a-development-branch](finishing-a-development-branch/) | Isolated worktrees, and wrapping up a branch |
| [frontend-design](frontend-design/) | Polished, non-generic UI |

### Multiple agents (Parts 4–5)

| Skill | What it does |
| :--- | :--- |
| [dispatching-parallel-agents](dispatching-parallel-agents/) | Split independent work across agents |
| [subagent-driven-development](subagent-driven-development/) | Execute a plan task-by-task with sub-agents and review between tasks |
| [agy-orchestrator](agy-orchestrator/) | Claude as manager, Antigravity (`agy`) agents as workers |

### Team data and demo day

| Skill | What it does |
| :--- | :--- |
| [zepher-data-vault](zepher-data-vault/) | Share `.env` secrets and big files safely with Zepher |
| [project-review-deck](project-review-deck/) | Build a demo or review deck from your code |
| [se-docs](se-docs/) | Word documents: SRS, WBS + Gantt, design docs, test plans (needs Python + `python-docx`) |

## Credits

The skills `brainstorming`, `writing-plans`, `executing-plans`, `test-driven-development`, `systematic-debugging`, `verification-before-completion`, `requesting-code-review`, `receiving-code-review`, `using-git-worktrees`, `finishing-a-development-branch`, `dispatching-parallel-agents` and `subagent-driven-development` come from [obra/superpowers](https://github.com/obra/superpowers) (MIT, see [LICENSE-superpowers](LICENSE-superpowers)). `frontend-design` comes from [anthropics/skills](https://github.com/anthropics/skills) (Apache 2.0, see [frontend-design/LICENSE.txt](frontend-design/LICENSE.txt)). The rest are the Fable Club's own.
