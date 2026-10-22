# Severity Guide — Extended Definitions & Examples

## Severity Levels

### 🔴 Critical
The plan will likely **fail, cause data loss, security breach, or irreversible harm** if this gap is not addressed before execution.

**Triggers:**
- No error handling on a step that writes to a database or sends money
- Hardcoded credentials or secrets in code
- A required step is missing entirely (e.g., no deployment step in a deploy plan)
- Irreversible operation (delete, send email to all users) with no confirmation gate
- Race condition that corrupts shared state

**Examples:**
- "The plan calls `DELETE FROM orders WHERE status='pending'` but there is no WHERE clause verification step or backup."
- "API keys are passed as CLI arguments — they will appear in process lists and logs."
- "Step 4 assumes the S3 bucket already exists but there is no step to create or verify it."

---

### 🟠 High
A significant risk that **will likely cause failure or degraded behaviour** in real-world conditions, but may not manifest in a happy-path test.

**Triggers:**
- Missing retry logic on external calls
- No timeout on network operations
- Missing rollback steps for a multi-step transaction
- Assumption about data format that is plausible but unvalidated
- Missing auth check on an endpoint that handles sensitive data

**Examples:**
- "The plan polls the third-party webhook indefinitely with no timeout or dead-letter queue."
- "Step 2 parses the CSV assuming UTF-8 encoding — no encoding validation is performed."
- "There is no rollback plan if step 5 (DB migration) partially succeeds."

---

### 🟡 Medium
A gap that **introduces meaningful risk or technical debt** but is unlikely to cause immediate failure.

**Triggers:**
- Missing logging or observability
- No input validation on internal (trusted) data
- Hardcoded values that should be config
- Missing unit tests for core logic
- Unclear ownership of a step

**Examples:**
- "There is no structured logging — debugging a production issue will rely on print statements."
- "The batch size is hardcoded to 100 — this should be a configurable parameter."
- "It's unclear whether the DevOps team or the backend team is responsible for Step 7."

---

### 🔵 Low
A **minor improvement or polish item** that does not affect correctness or reliability.

**Triggers:**
- Naming inconsistencies
- Missing comments or documentation
- Slightly inefficient approach with a better alternative
- Nice-to-have features not included

**Examples:**
- "The variable `d` in step 3 should be named `deployment_config` for clarity."
- "The plan could batch API calls in step 6 to reduce latency, though the current approach is correct."

---

## Readiness Verdicts

| Verdict | Meaning |
|---------|---------|
| 🔴 Not Ready | One or more Critical gaps; do not execute until resolved |
| 🟡 Needs Work | No Critical gaps, but multiple High gaps; resolve before prod execution |
| 🟢 Ready with Minor Fixes | No Critical or High gaps; address Medium gaps in parallel with execution |
| ✅ Ready | Only Low gaps or none; proceed with confidence |

---

## Worked Example — Severity Calibration

**Plan step:** "Deploy the new service to production by running `./deploy.sh`"

| Gap | Severity | Reasoning |
|-----|----------|-----------|
| No health-check after deploy | High | Service may start but be unhealthy; no automated detection |
| No rollback command documented | Critical | If deploy fails mid-way, team has no documented recovery path |
| `deploy.sh` not checked into version control | High | Script may differ across machines |
| Deploy time not estimated | Low | Nice to know; doesn't affect correctness |
| No mention of who runs the script | Medium | Unclear ownership could delay execution |
