# Orca Automations — Templates for Beyond the Prompt

An automation is a scheduled agent run: at a set time, Orca starts the agent you picked, in the workspace you picked, and gives it your prompt. Below: what each field in **Create automation** means, how to write a prompt that is safe to run while nobody is watching, and ten templates to copy.

Open it from Orca's **Automations** page → **Create automation**. These templates use the **Orca** tab of the dialog. **Use template** fills in Orca's own examples.

---

## 1. The fields, one by one

| Field | What it does | Pick this at the event |
| :--- | :--- | :--- |
| **Name** | Shown in the Automations list and run history | Verb + target, e.g. `Morning issue triage` |
| **Prompt** | The instructions the agent gets on every run. Supports skills, file paths and commands like `/goal` | Use the prompt skeleton in section 2 |
| **Agent** | Which CLI runs it (Antigravity, Claude Code, OpenCode, Codex…) | Whichever agent your team is signed in to on this computer |
| **Host** | The machine that stores and runs the schedule | `Local …` for the event. Runs only happen while that machine is on and Orca is running |
| **Project** | The repo the run belongs to | Your team repo |
| **Workspace → Worktree** | Run inside one **existing** worktree every time | Read-only jobs (triage, review, digests) on your `main` worktree |
| **Workspace → New run** | Create a **fresh worktree** for every run | Jobs that change code (fixes, docs PRs). Each run gets its own branch |
| **Session → Fresh** | Start a new agent conversation each run | Default. Every run starts clean |
| **Session → Reuse** | Send the prompt to the previous run's agent session, if it is still open | Only for "continue yesterday's work" jobs in a fixed worktree |
| **Schedule / Time** | Hourly, Daily, Weekdays, Weekly, or a custom cron | Weekdays 09:00 for triage, Hourly for PR review |
| **Grace** | If the computer was asleep at the scheduled time, still run if it wakes up within this window | `1 hour` for hourly jobs, `2–12 hours` for daily jobs |
| **Precheck + Timeout** | A shell command run first. Exit code 0 means run the agent; any other code means skip this run at no cost | Always set one. Keep the timeout short (`1 min`) |

> **The default precheck in the dialog never skips.** `gh pr list --json number -q '.[0].number'` exits with 0 even when there are no PRs. Wrap it in `test -n "$( … )"`, as in every template below, so an empty result exits with 1. Check a precheck in a terminal first: `<precheck>; echo $?`
>
> The prechecks here are written for macOS and Linux hosts. On a Windows host, test them first, or leave the precheck empty.

"Once saved, runs automatically until paused". Right after creating an automation, open it in the list and click **Run now**, read the run, then pause or edit it. Or create it from the CLI with `--disabled` (section 5).

---

## 2. Prompt skeleton (use this for every automation)

Nobody is watching when an automation runs. The agent can't ask you anything, and in Orca agents run with permission prompts off. So the prompt has to say exactly what to do, what never to do, and what "done" looks like.

```text
GOAL: <one sentence: what this run must achieve>

CONTEXT
- Repo: the current directory (a GitHub repo; use `gh` for issues, PRs and the project board).
- Read first: <files, e.g. README.md, AGENTS.md / CLAUDE.md, .zepher/context/current.md>
- Use skill: <optional, e.g. /new-issue, /start-task, systematic-debugging>

STEPS
1. <first concrete step, with the command if you know it>
2. <…>
3. <…>

RULES (never break these)
- Never push to main, never merge a PR, never close or delete issues, never force-push.
- Never print, commit or post secrets, tokens or .env contents.
- Only touch <files / labels / scope>. If the work needs more than that, stop.
- If something is unclear or fails twice, stop and report it instead of guessing.

DONE WHEN
- <observable result, e.g. "every open issue has a type label" or "a draft PR exists and npm test passes">

REPORT
End with a short summary: what you did, links to anything you created, and anything that needs a human.
```

Tips:
- **One job per automation.** "Triage and fix and review" fails in confusing ways. Make three automations instead.
- **Name the exact commands** (`gh issue list --search "no:label"`). The agent wastes less time, and runs come out the same every time.
- **Leave a trail.** Ask for a comment, a draft PR or a file. Then you can see the result on GitHub, not only in the run log.
- **Cap the work.** "At most 5 issues per run" stops one run from doing everything at once.

---

## 3. Templates

Placeholders are in `<ANGLE BRACKETS>`. Replace them before saving.

### 3.1 Morning issue triage

| Field | Value |
| :--- | :--- |
| Name | `Morning issue triage` |
| Workspace / Session | Worktree (`main`) / Fresh |
| Schedule | Weekdays 09:00 · Grace 3 hours |
| Precheck | `test -n "$(gh issue list --state open --search 'no:label' --json number -q '.[].number')"` |

```text
GOAL: Every open issue without a label gets a type label and a short triage comment.

CONTEXT
- Repo: current directory. Labels in use: type:feature, type:bug, type:chore, type:docs.

STEPS
1. Run: gh issue list --state open --search "no:label" --json number,title,body --limit 10
2. For each issue (at most 10), decide its type from the title and body.
3. Add the label: gh issue edit <number> --add-label "type:<type>"
4. If acceptance criteria are missing, comment once with 2–3 suggested criteria:
   gh issue comment <number> --body "<suggested acceptance criteria>"

RULES
- Never close, reassign or retitle issues. Only add labels and one comment per issue.
- Skip any issue that already has a comment from you.

DONE WHEN
- No open issue is left without a label.

REPORT
List each issue number, the label you added, and whether you commented.
```

### 3.2 PR first-pass reviewer

| Field | Value |
| :--- | :--- |
| Name | `PR first-pass review` |
| Workspace / Session | Worktree (`main`) / Fresh |
| Schedule | Hourly · Grace 1 hour |
| Precheck | `test -n "$(gh pr list --state open --search 'draft:false' --json number -q '.[].number')"` |

```text
GOAL: Every open, non-draft PR gets one helpful first-pass review comment.

STEPS
1. gh pr list --state open --search "draft:false" --json number,title,author,reviews --limit 5
2. Skip PRs you already reviewed (a review or comment from you exists).
3. For each remaining PR: read `gh pr view <n>` and `gh pr diff <n>`.
4. Check: does it do what the linked issue (Closes #N) asks? Obvious bugs? Missing tests?
   Secrets or debug code? Changes outside the issue's scope?
5. Post one review as a comment: gh pr review <n> --comment --body "<review>"
   Format: Summary (1 line) · Must fix · Should fix · Nice to have. Quote file:line.

RULES
- Use --comment only. Never --approve, never --request-changes, never merge or close.
- Be specific and kind; no style nitpicks unless they hide a bug.

DONE WHEN
- Every open non-draft PR has one review comment from you.

REPORT
List PR numbers reviewed and the single most important finding for each.
```

### 3.3 Daily stand-up digest

| Field | Value |
| :--- | :--- |
| Name | `Stand-up digest` |
| Workspace / Session | Worktree (`main`) / Fresh |
| Schedule | Weekdays 18:00 · Grace 12 hours |
| Precheck | `test -n "$(gh issue list --search 'Stand-up log in:title' --json number -q '.[0].number')"` |

Create one issue titled **Stand-up log** first. This automation comments on it every day.

```text
GOAL: Post today's team stand-up summary as a comment on the "Stand-up log" issue.

STEPS
1. Find the issue: gh issue list --search "Stand-up log in:title" --json number -q '.[0].number'
2. Collect the last 24 hours:
   - Merged PRs: gh pr list --state merged --search "merged:>=<yesterday's date>" --json number,title,author
   - Open PRs waiting for review: gh pr list --state open --json number,title,author,reviewDecision
   - Board: issues In Progress and In Review (gh project item-list <PROJECT_NUMBER> --owner <OWNER> --format json)
3. Write a comment with three sections: Done · In progress · Blocked / needs review.
   One line per item, with the person's @handle and the #number.
4. Post it: gh issue comment <number> --body-file <tmp file>

RULES
- Read-only except for that one comment. Don't edit issues, PRs or the board.

DONE WHEN
- One new comment exists on the Stand-up log issue for today.

REPORT
Paste the comment you posted.
```

### 3.4 Agent-ready issue → draft PR (capstone stretch goal)

| Field | Value |
| :--- | :--- |
| Name | `Build one agent-ready issue` |
| Workspace / Session | **New run** / Fresh |
| Schedule | Hourly during the capstone · Grace 30 min |
| Precheck | `test -n "$(gh issue list --state open --label agent-ready --search 'no:assignee' --json number -q '.[].number')"` |

Label issues `agent-ready` when they have clear acceptance criteria and you're happy for an agent to try them.

```text
GOAL: Implement ONE open issue labelled agent-ready and open a draft PR for it.

CONTEXT
- Read AGENTS.md / CLAUDE.md for build and test commands.
- Use skill: /start-task (follow its steps, but stop before any merge).

STEPS
1. Pick the oldest: gh issue list --state open --label agent-ready --search "no:assignee" --json number,title -q '.[0]'
2. Assign yourself and mark it: gh issue edit <n> --add-assignee @me --remove-label agent-ready --add-label agent-working
3. Create a branch: gh issue develop <n> --checkout --name agent/<n>-<short-slug>
4. Implement the acceptance criteria. Add or update tests.
5. Run the test command until it passes (at most 3 attempts).
6. Commit with "#<n>" in the message, push the branch, and open a DRAFT PR:
   gh pr create --draft --title "<issue title>" --body "Closes #<n>. <summary of the change and how it was tested>"

RULES
- Exactly one issue per run. Never push to main, never merge, never mark the PR ready.
- If tests still fail after 3 attempts, or the issue is unclear: comment on the issue explaining why,
  re-add the agent-ready label, remove agent-working, and stop.

DONE WHEN
- A draft PR linked with "Closes #<n>" exists and the tests pass on its branch.

REPORT
Issue number, PR link, test result, and anything a reviewer should look at first.
```

### 3.5 Main branch went red → fix PR

| Field | Value |
| :--- | :--- |
| Name | `Fix failing main` |
| Workspace / Session | **New run** / Fresh |
| Schedule | Hourly · Grace 1 hour |
| Precheck | `gh run list --branch main --limit 1 --json conclusion -q '.[0].conclusion' \| grep -qx failure` |

```text
GOAL: Find why the latest CI run on main failed and open a draft PR that fixes it.

CONTEXT
- Use skill: systematic-debugging (root cause first, no guess-fixes).

STEPS
1. gh run list --branch main --limit 1 --json databaseId,name,headSha
2. gh run view <id> --log-failed   (read the failing step)
3. Reproduce locally with the same command. Find the root cause.
4. Fix it on a branch named fix/ci-<short-sha>, run the tests, push, and open a DRAFT PR
   titled "fix(ci): <cause>" with the root cause and the evidence in the body.

RULES
- Don't skip, delete or weaken tests to make CI pass. Don't touch CI config unless it is the cause.
- If a PR titled "fix(ci)" is already open, comment your findings there instead of opening another.

DONE WHEN
- A draft PR exists whose branch passes the previously failing command.

REPORT
Root cause in one sentence, the PR link, and how you verified it.
```

### 3.6 Weekly dependency and security audit

| Field | Value |
| :--- | :--- |
| Name | `Weekly dependency audit` |
| Workspace / Session | Worktree (`main`) / Fresh |
| Schedule | Weekly, Monday 10:00 · Grace 12 hours |
| Precheck | `test -f package.json` (or `requirements.txt`, `go.mod`… for your stack) |

```text
GOAL: Report risky or outdated dependencies as one GitHub issue. Change no code.

STEPS
1. Run `npm audit --json` and `npm outdated --json` (or your stack's equivalents).
2. Keep only: high/critical vulnerabilities, and major-version updates of direct dependencies.
3. If an open issue titled "Dependency audit" exists, comment the new findings on it.
   Otherwise create one: gh issue create --title "Dependency audit" --label "type:chore" --body-file <tmp file>
4. For each finding: package, current → safe version, severity, and the advisory link.

RULES
- Don't run `npm audit fix`, don't edit package files, don't open PRs.

DONE WHEN
- The findings (or "no new findings") are posted on the Dependency audit issue.

REPORT
Count of high/critical findings and the issue link.
```

### 3.7 Docs drift check

| Field | Value |
| :--- | :--- |
| Name | `README matches the code` |
| Workspace / Session | **New run** / Fresh |
| Schedule | Weekly, Friday 16:00 · Grace 12 hours |
| Precheck | `test -n "$(git log --since='7 days ago' --oneline origin/main -- src)"` |

```text
GOAL: Make README.md and docs/ match what the code does now, as a draft PR.

STEPS
1. git log --since="7 days ago" --stat origin/main   (see what changed)
2. For each change, check whether README.md or docs/ describe the old behaviour:
   setup commands, environment variables, scripts in package.json, API routes.
3. Fix only the outdated sentences. Open a DRAFT PR titled "docs: sync with code (week of <date>)".

RULES
- Edit only README.md and files under docs/. Never change code.
- If nothing is outdated, make no PR. Just report "docs are up to date".

DONE WHEN
- Either a draft docs PR exists, or the report says nothing needed changing.

REPORT
Each outdated statement you found and how you changed it.
```

### 3.8 End-of-day Zepher handoff

| Field | Value |
| :--- | :--- |
| Name | `End-of-day handoff` |
| Workspace / Session | Worktree (your feature worktree) / **Reuse** |
| Schedule | Weekdays 19:00 · Grace 12 hours |
| Precheck | `command -v zepher && test -d .zepher` |

```text
GOAL: Leave a handoff so tomorrow's agent (or teammate) can continue this worktree without re-explaining.

STEPS
1. Check state: git status, git log --oneline -10, zepher task list.
2. Record anything new and non-obvious you learned today:
   zepher remember "<fact>" -t <architecture|conventions|constraints|lessons>
3. Write the handoff:
   zepher handoff -o "<what this branch is for>" -c "<done today>" -b "<blockers>" -a "<next action>"
4. Update the card: orca worktree set --worktree active --comment "<one-line status>"

RULES
- Don't commit, push or change code in this run.

DONE WHEN
- A new file exists in .zepher/handoffs/ and the worktree card shows today's status.

REPORT
The next action you wrote.
```

### 3.9 Board hygiene

| Field | Value |
| :--- | :--- |
| Name | `Board hygiene` |
| Workspace / Session | Worktree (`main`) / Fresh |
| Schedule | Weekdays 12:00 · Grace 3 hours |
| Precheck | `gh auth status 2>&1 \| grep -q "'project'"` |

```text
GOAL: The project board matches reality. Fix stale cards and report what you moved.

CONTEXT
- Board: project <PROJECT_NUMBER> owned by <OWNER>. Status options: Backlog, Ready, In Progress, In Review, Done.

STEPS
1. gh project item-list <PROJECT_NUMBER> --owner <OWNER> --limit 200 --format json
2. Find mismatches:
   - Card in Done/In Review but the issue is still open with no open PR → move to In Progress.
   - Issue has an open PR with "Closes #N" but the card is in Backlog/Ready/In Progress → move to In Review.
   - Card "In Progress" with no commits on its branch for 3+ days → leave it, but list it as stale.
3. Move cards with gh project item-edit (look up the field and option IDs with gh project field-list).

RULES
- Never move a card to Done (GitHub does that when the PR merges). Never close issues.
- At most 15 moves per run.

DONE WHEN
- No mismatches of the first two kinds remain.

REPORT
A table: issue · from → to · reason. Then the list of stale In Progress cards with their assignees.
```

### 3.10 Nightly test health

| Field | Value |
| :--- | :--- |
| Name | `Nightly test health` |
| Workspace / Session | **New run** / Fresh |
| Schedule | Daily 23:00 · Grace 8 hours |
| Precheck | `test -f package.json` |

```text
GOAL: Run the full test suite on the latest main and report failures and flaky tests as issues.

STEPS
1. Install dependencies (npm ci) and run the full test suite twice.
2. A test that fails both times is broken. A test that fails once and passes once is flaky.
3. For each broken or flaky test: search open issues for its name first; if none exists, create
   gh issue create --title "test: <name> is <broken|flaky>" --label "type:bug" --body "<error, file:line, how to reproduce>"

RULES
- Don't fix code, don't skip tests, don't open PRs.

DONE WHEN
- Every broken or flaky test has exactly one open issue.

REPORT
Pass/fail counts for both runs and the issues you created.
```

---

## 4. Safety checklist before you click Create

- [ ] The prompt has a **RULES** block: no push to main, no merging, no closing issues, no secrets.
- [ ] Jobs that change code use **New run**, so every run gets its own worktree and branch, and open **draft** PRs.
- [ ] A **precheck** is set, and you saw it exit non-zero when there is nothing to do.
- [ ] `main` is protected on GitHub (Settings → Branches), so even a bad run can't push to it.
- [ ] You ran it once by hand and read the result.
- [ ] The agent on this host is signed in, and `gh auth status` works in a normal terminal on the same machine.

Costs and limits: an hourly job is 24 agent sessions a day. Prechecks and "at most N per run" caps keep that down. `gh` shares one hourly GitHub API budget (about 5,000 calls) between you, Orca and every automation, and a chatty job can use it up.

---

## 5. Same thing from the CLI

On Linux the command is `orca-ide`; on macOS and Windows it is `orca`.

```bash
orca automations create \
  --name "Morning issue triage" \
  --trigger weekdays --time 09:00 \
  --provider claude \
  --workspace active \
  --precheck "test -n \"\$(gh issue list --state open --search 'no:label' --json number -q '.[].number')\"" \
  --prompt "$(cat prompts/morning-triage.md)" \
  --missed-run-grace-minutes 180 \
  --disabled --json

orca automations list --json
orca automations run <automationId> --json         # try it now
orca automations runs --id <automationId> --json   # read the result
orca automations edit <automationId> --enabled --json
```

| CLI flag | Dialog field |
| :--- | :--- |
| `--provider` | Agent |
| `--repo <selector>` | New run, with a fresh worktree per run (`--workspace-mode new-per-run`) |
| `--workspace <selector>` | Worktree, an existing one (`active` = the one you're in) |
| `--reuse-session` / `--fresh-session` | Session Reuse / Fresh |
| `--trigger hourly\|daily\|weekdays\|weekly\|"<cron>"` + `--time` / `--day` | Schedule + Time |
| `--missed-run-grace-minutes` | Grace |
| `--precheck` / `--precheck-timeout` | Precheck / Timeout |
| `--host runtime:<id>` | Host (a paired Orca server) |
| `--extra-agent-args="--model <id>"` | Advanced → Extra agent arguments (model or effort only) |

Tip: keep each prompt in your repo, for example `prompts/morning-triage.md`, so the team reviews prompt changes in PRs like code.
