# Skills Guide — Beyond the Prompt

A **skill** is a saved playbook (`SKILL.md`) that teaches your agent how to do one job well, such as filing a proper GitHub issue, debugging by root cause, or planning sprints. The setup script copies all 31 event skills into `~/.claude/skills`. The files are in [`skills/`](../skills/).

## How to use a skill

| Agent | How |
| :--- | :--- |
| **Claude Code** | Type `/<skill-name>`, e.g. `/new-issue add dark mode toggle`. Or describe the task and Claude picks the matching skill by itself. |
| **Antigravity / Gemini** | Run `zepher skill link` once to share the skills, then say *"use the systematic-debugging skill to …"*. |
| **OpenCode / others** | Say *"follow skills/<name>/SKILL.md to …"*. Any agent can read the file. |
| **Orca automations** | Put `/new-issue` or *"use the start-task skill"* in the automation prompt. See [orca-automations.md](orca-automations.md). |

Restart the agent after installing new skills.

## The flow they're built for

```text
idea ──► brainstorming ──► plan-project ──► new-issue ──► start-task ──► test-driven-development
                                                              │                    │
                                              systematic-debugging ◄── bug ────────┘
                                                              │
                     verification-before-completion ──► requesting-code-review ──► merge
```

---

## 1. GitHub workflow (Part 3 and the capstone)

| Skill | Why | How |
| :--- | :--- | :--- |
| **plan-project** | Turns a rough idea into a ready GitHub Project board in one go, so the team starts with real issues instead of a blank board | `/plan-project`. Answer its questions; it creates the board, user stories, issues, sprint milestones and assignees. `/plan-project sprint` plans only the next sprint |
| **new-issue** | Every issue gets a type, a clear description and acceptance criteria, which makes it a good prompt for an agent later | `/new-issue "login page crashes on empty password"`. It detects bug/feature/chore/docs, shows you the issue, then creates it in Backlog |
| **start-task** | One command from "assigned issue" to "PR in review": refine, branch, implement, commit, PR, move the card | `/start-task`, or `/start-task 12` for issue #12. **Needs a `dev` branch.** It merges the feature branch into `dev` and opens a `dev → main` PR. Use `--branch-only` or `--pr-only` for just one stage |
| **scrum-board** | Quick sprint plan as markdown files, without GitHub Projects | *"make a scrum board from these tasks"*. Writes 1-week sprint files |
| **project-research** | Know the features, competitors and risks before choosing what to build | *"research my project: a study-group finder for VIT"*. Produces a research report |

`new-issue`, `start-task` and `plan-project` use `gh` and `jq`. On Windows run them from **Git Bash**.

## 2. Thinking before coding

| Skill | Why | How |
| :--- | :--- | :--- |
| **brainstorming** | Stops the agent from coding the first idea; it asks questions and explores options first. It has an optional browser "visual companion" for mock-ups | *"let's brainstorm the dashboard feature"*. Answer one question at a time; you get a short design to approve |
| **writing-plans** | A step-by-step plan that a person or another agent can follow exactly | *"write an implementation plan for issue #12"*. Saves a plan with small, testable steps |
| **implementation-plan-reviewer** | Finds missing steps, risks and edge cases in a plan before anyone builds it | Paste a plan and say *"review this plan"* |
| **executing-plans** | Works through a written plan task by task, checking each one | *"execute the plan in docs/plans/dark-mode.md"* |

## 3. Building and quality

| Skill | Why | How |
| :--- | :--- | :--- |
| **test-driven-development** | Write the failing test first, then the code. The agent proves its change works | *"implement #12 with TDD"*. Red → green → refactor |
| **systematic-debugging** | Finds the root cause before changing code, instead of trying random fixes | *"the build fails with X, debug it"*. Investigate → hypothesis → test → fix |
| **verification-before-completion** | The agent must run the tests and show the output before saying "done" | Runs by itself before claiming success, or say *"verify before you finish"* |
| **requesting-code-review** | Gets an independent review of your branch before merging | *"review my changes before I open the PR"* |
| **receiving-code-review** | Handles review comments carefully: checks each one, pushes back on wrong ones, doesn't blindly apply everything | *"address the review comments on PR #9"* |
| **using-git-worktrees** | Works in an isolated worktree, so experiments never break your main checkout (Orca does this for you too) | *"start this feature in a new worktree"* |
| **finishing-a-development-branch** | Wraps up: tests pass, then you choose merge, PR, keep or discard, and it cleans up | *"I'm done with this branch"* |
| **frontend-design** | Polished, non-generic UI instead of the default AI look | *"design the landing page for our app"* |

## 4. Many agents at once (Parts 4–5)

| Skill | Why | How |
| :--- | :--- | :--- |
| **dispatching-parallel-agents** | Splits independent problems across several agents running at the same time | *"these 3 test files fail for unrelated reasons, fix them in parallel"* |
| **subagent-driven-development** | Runs a plan with a fresh sub-agent per task and a review between tasks, for higher quality on long plans | *"execute this plan with subagents"* |
| **agy-orchestrator** | Claude plans and reviews; cheaper Antigravity (`agy`) agents do the repetitive coding. Saves your Claude usage | *"use antigravity to do the mechanical parts of this refactor"*. Needs `agy` installed and signed in |

## 5. Requirements and design documents (software-engineering course work)

Each phase reads the previous phase's file in `docs/` and writes the next one, so run them in order, or run `sdlc-init` to do all of them.

| Skill | Why | How |
| :--- | :--- | :--- |
| **sdlc-init** / **software-inception** | All the early phases in one go: stakeholders → requirements → SRS → system → architecture. `software-inception` also generates project-specific skills at the end | `/sdlc-init` in a new repo, or *"do the requirement analysis and architecture for my app"* |
| **stakeholder-requirements** | Who the users are, what they need, and who decides (register + RACI) | `/stakeholder-requirements` → `docs/01-stakeholders.md` |
| **requirements-analysis** | Gather and prioritise requirements (MoSCoW), validate them, traceability matrix | `/requirements-analysis` → `docs/02-elicitation.md`, `docs/05-srs.md` |
| **functional-requirements** | Use cases and user stories that can be tested | `/functional-requirements` → `docs/03-functional.md` |
| **non-functional-requirements** | Measurable performance, security and availability targets (ISO 25010) | `/non-functional-requirements` → `docs/04-nonfunctional.md` |
| **system-building** | Scope, build/buy/reuse, system context and data flows | `/system-building` → `docs/06-system.md` |
| **architecture-building** | C4 diagrams, tech stack with alternatives, ADRs | `/architecture-building` → `docs/07-architecture.md` |
| **se-docs** | Formatted Word documents: SRS, WBS + Gantt, design docs, test plans, reports | *"make a Word SRS for this repo"*. Needs Python and `pip install python-docx` |

## 6. Team data and demo day

| Skill | Why | How |
| :--- | :--- | :--- |
| **zepher-data-vault** | Share `.env` secrets and large files with the team safely (encrypted vault, blob storage), never in Git or chat | *"set up a Zepher vault for our .env"*. See [zepher-guide.md](zepher-guide.md) |
| **project-review-deck** | Builds a demo deck from your actual code, with architecture and data-flow diagrams, as PowerPoint or an interactive HTML deck | *"make slides for our capstone demo"* |

---

## Tips

- **Name the skill when it matters.** The agent picks skills by their description, but `/start-task 12` or *"use systematic-debugging"* is faster and more reliable.
- **Skills stack.** `start-task` + `test-driven-development` + `verification-before-completion` is a very good default for capstone issues.
- **Make your own.** A skill is just a folder with a `SKILL.md`: a name, a one-line description of *when* to use it, then the steps. Put it in `.zepher/skills/` in your repo to share it with the team.

Credits: 12 skills come from [obra/superpowers](https://github.com/obra/superpowers) (MIT) and `frontend-design` from [anthropics/skills](https://github.com/anthropics/skills) (Apache 2.0). See [skills/README.md](../skills/README.md).
