---
name: implementation-plan-reviewer
description: >
  Use this skill whenever an agent or user submits an implementation plan for review, critique,
  or gap analysis. Triggers include: "review this plan", "analyse this implementation", "find gaps
  in this plan", "what could go wrong", "check this architecture", "validate this approach",
  "critique this design", "review the plan from the other agent", or any time an implementation
  plan, technical design document, or step-by-step execution strategy is presented for evaluation.
  This skill performs structured multi-dimensional analysis — covering outcomes, risks, edge cases,
  missing steps, assumptions, and dependencies — and produces a clear, actionable review report.
  Use it even if the user just pastes a plan without explicitly asking for a review.
---

# Implementation Plan Reviewer

A structured skill for critically reviewing implementation plans produced by agents or humans.
It analyses possible outcomes, surfaces gaps, and produces a prioritised, actionable review.

---

## When This Skill Triggers

- An agent produces a plan and routes it to a reviewer agent
- A user pastes an implementation plan or design doc and says "review this", "check this", "what am I missing"
- Multi-agent pipelines where one agent plans and another critiques
- Any mention of "gap analysis", "risk analysis", or "what could go wrong" on a plan

---

## Review Framework

Run all six lenses below in order. Each lens has guiding questions and an output format.
Consolidate everything into the Final Review Report at the end.

---

### Lens 1 — Plan Comprehension

Before critiquing, fully understand the plan.

- What is the goal / success condition?
- What are the stated steps or phases?
- What tech stack, tools, or dependencies are named?
- What constraints or assumptions are stated explicitly?

Output: a short internal summary (2–4 sentences) you use to ground the rest of the review.
Do NOT include this verbatim in the final report — use it as working context.

---

### Lens 2 — Outcome Analysis

Map the full space of possible outcomes: happy path, partial failures, and total failures.

Guiding questions:
- What does success look like? Is it clearly defined and measurable?
- What happens if each individual step fails?
- Are there partial-success states that could be mistaken for full success?
- What cascading effects could a failure in step N have on steps N+1…end?
- Are there irreversible steps? What happens if you need to roll back?

Output format (for the report):

**Outcome Analysis**
| Outcome | Trigger Condition | Likelihood | Impact |
|---------|------------------|------------|--------|
| Full success | All steps complete without error | … | … |
| Partial success — X fails | … | … | … |
| Total failure | … | … | … |
| Silent failure (looks OK but isn't) | … | … | … |

Add rows for any domain-specific outcomes you identify.

---

### Lens 3 — Gap Analysis

Identify what is missing, underspecified, or assumed without justification.

Gap categories to check:

| Category | Questions to Ask |
|----------|-----------------|
| **Missing Steps** | Is there a step between A and B that wasn't mentioned? |
| **Unvalidated Assumptions** | What does the plan assume to be true without checking? |
| **Missing Error Handling** | What happens when X fails? Is there a fallback? |
| **Missing Rollback / Undo** | Can the plan be reversed if needed? |
| **Security Gaps** | Are there auth, secrets, injection, or access-control issues? |
| **Data Gaps** | Where does data come from? Is it validated? What if it's malformed? |
| **Observability Gaps** | How will you know something went wrong? Logging, alerts, monitoring? |
| **Scalability Gaps** | Does the plan break under 10x load? |
| **Testing Gaps** | Is testing mentioned? Unit, integration, end-to-end? |
| **Dependency Gaps** | External services, APIs, or libraries assumed to be available? |
| **Timeline / Resource Gaps** | Are deadlines or resource constraints ignored? |
| **Stakeholder Gaps** | Are approvals, sign-offs, or communications missing? |

Output format (for the report):

**Gap Analysis**
| Gap | Category | Severity (Critical / High / Medium / Low) | Recommendation |
|-----|----------|-------------------------------------------|----------------|
| … | … | … | … |

Severity guide:
- **Critical** — plan will likely fail or cause harm without fixing this
- **High** — significant risk; should fix before execution
- **Medium** — worth addressing; moderate risk if ignored
- **Low** — nice-to-have; minor polish or future improvement

---

### Lens 4 — Risk & Assumption Register

Surface hidden risks and explicit/implicit assumptions.

For each risk:
- What is the risk?
- How likely is it (Low / Medium / High)?
- How severe is the impact if it materialises?
- What is the mitigation?

For each assumption:
- What is being assumed?
- Is there evidence to support it?
- What happens if the assumption is wrong?

Output format (for the report):

**Risk Register**
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|

**Assumption Register**
| Assumption | Validated? | If Wrong… |
|------------|------------|-----------|

---

### Lens 5 — Dependency & Integration Check

Identify all external touch-points and whether they are handled.

- Third-party APIs or services: are rate limits, auth, and failure modes handled?
- Databases: schema changes, migrations, locking, transactions?
- Infrastructure: ports, env vars, secrets management, network access?
- Other agents or systems: are interfaces (inputs/outputs) clearly defined?
- Human steps: are manual approvals, reviews, or interventions accounted for?

Output format (for the report):

**Dependency & Integration Gaps**
| Dependency | Issue | Severity | Recommendation |
|------------|-------|----------|----------------|

---

### Lens 6 — Strengths & Actionable Recommendations

Balance the critique. Note what the plan does well, then give prioritised fixes.

Output format (for the report):

**Strengths**
- Bullet list of genuine strengths (be specific, not generic praise)

**Prioritised Recommendations**
1. [Critical] Fix X — because Y
2. [High] Add Z — because W
3. [Medium] Consider A — because B
…

---

## Final Review Report Format

Assemble the lenses into this report. Adjust depth based on plan complexity —
a 3-step plan gets a shorter report than a 20-step architecture design.

```
# Implementation Plan Review

## Executive Summary
[2–4 sentences: overall assessment, top risk, and readiness verdict]
Readiness: 🔴 Not Ready / 🟡 Needs Work / 🟢 Ready with Minor Fixes / ✅ Ready

---

## Outcome Analysis
[Outcome table from Lens 2]

---

## Gap Analysis
[Gap table from Lens 3]

---

## Risk & Assumption Register
[Tables from Lens 4]

---

## Dependency & Integration Gaps
[Table from Lens 5]

---

## Strengths
[Bullet list from Lens 6]

---

## Prioritised Recommendations
[Numbered list from Lens 6]

---

## Reviewer Notes
[Any domain-specific caveats, open questions to ask the plan's author, or items that need
clarification before the plan can be fully assessed]
```

---

## Tone & Style Guidelines

- Be direct and specific. Vague feedback like "error handling could be better" is useless.
  Say: "Step 3 calls the payment API but there is no retry logic or timeout — if the API is
  slow, the entire pipeline will hang indefinitely."
- Be fair. Acknowledge what the plan gets right before piling on.
- Be actionable. Every gap or risk should come with a concrete recommendation.
- Calibrate depth to complexity. A 3-step script plan ≠ a 50-step distributed system design.
- Use the requester's terminology. If they call it a "pipeline", don't call it a "workflow".

---

## Edge Cases to Watch For

- **Plans with no stated goal** — ask for the success condition before reviewing
- **Very short plans** — still run all lenses; brevity is often where the gaps hide
- **Plans referencing external docs** — note that you can only review what was provided
- **Agent-generated plans with confident but wrong steps** — be especially rigorous on
  assumptions an LLM might make (e.g., assuming a library exists, a port is open, an API is free)
- **Plans that are actually code, not plans** — still apply the framework; treat functions/modules
  as steps

---

## Reference Files

- `references/severity-guide.md` — Extended severity definitions and worked examples
- `references/domain-checklists.md` — Domain-specific gap checklists (ML pipelines, web APIs,
  data pipelines, infra deployments, agent workflows)

Read the relevant domain checklist from `references/domain-checklists.md` when the plan
belongs to a known domain — it adds domain-specific questions on top of the core framework.
