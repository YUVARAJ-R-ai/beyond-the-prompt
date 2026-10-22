# Phase 8 — Validation & Traceability

Goal: confirm the requirements and architecture are correct, complete, consistent, and feasible before treating them as a baseline — and prove it with a traceability matrix rather than assertion.

The linter from earlier phases (`scripts/check_requirements.py`) catches form: ambiguity, missing fields, duplicate IDs. It cannot catch truth: a requirement can be perfectly well-formed and still wrong, unnecessary, or contradicted by another requirement three sections away. That's what this phase is for.

## Contents
- [1. Verification vs validation](#1-verification-vs-validation)
- [2. Review techniques](#2-review-techniques)
- [3. The review checklist](#3-the-review-checklist)
- [4. Traceability matrix](#4-traceability-matrix)
- [5. Baselining and change control](#5-baselining-and-change-control)
- [6. Sign-off](#6-sign-off)
- [Exit criteria](#exit-criteria)

---

## 1. Verification vs validation

Two different questions, both necessary, routinely conflated:

- **Verification** — are we building it right? Does the design satisfy the requirements, does the code satisfy the design, is the document internally consistent?
- **Validation** — are we building the right thing? Would this, if built exactly as specified, actually solve the Phase 1 problem for the Phase 2 stakeholders?

A requirements document can pass every verification check — well-formed, testable, traceable, non-contradictory — and still validate to nothing, because it solves a problem nobody has. Validation requires going back to a real stakeholder; it cannot be done by inspecting the document alone.

## 2. Review techniques

Pick based on stakes (the depth tier from Phase 0) and available time.

**Self-review pass.** Minimum bar, always done regardless of tier. Read the full set end-to-end in one sitting — issues that are invisible section-by-section become obvious in continuous read, particularly contradictions and drifting terminology.

**Checklist-driven review.** Systematic pass against §3 below. Catches the same class of issue as self-review but exhaustively rather than impressionistically.

**Walkthrough.** Present the requirements to stakeholders as if reading through a scenario together — "here's what happens when a coordinator does X" — rather than handing over a document to read alone. Surfaces misunderstandings a silent read misses, because people notice gaps when a story is being narrated to them that they don't notice when scanning prose.

**Formal inspection (Fagan-style).** For Rigorous tier: a moderator, a reader who paraphrases each requirement aloud (paraphrasing surfaces ambiguity the original author is blind to), and dedicated reviewers each assigned a specific defect class to hunt (one person only checks completeness, another only checks testability, another only checks consistency). Defects are logged, not fixed live — fixing live turns inspection into a design meeting and the group stops finding defects.

**Prototype-based validation.** For UX-sensitive or novel-interaction requirements, walk a stakeholder through a prototype performing the acceptance criteria and watch for hesitation or confusion, rather than asking "does this look right?" — people say yes to documents far more readily than they succeed at using the thing described.

**Model-based validation** (already partly done in Phase 6). Formal models don't just document — the act of building a state machine or a decision table surfaces gaps a prose review would miss. If a model wasn't built for something high-risk, consider building one now specifically as a validation technique.

## 3. The review checklist

Work through systematically. Each item catches a distinct, common failure mode — treat a "no" as a defect to log, not a box to skip.

**Completeness**
- [ ] Every stakeholder requirement traces to at least one FR or NFR
- [ ] Every FR has acceptance criteria covering happy path, alternates, and errors
- [ ] Every entity's lifecycle covers every state × event combination (Phase 6)
- [ ] Every external interface has a documented failure mode
- [ ] The eight coverage sweeps from Phase 4 §10 were actually run

**Correctness**
- [ ] Business rules match their authoritative source (regulation, policy, confirmed SME statement)
- [ ] Numeric NFR targets have a rationale that isn't just "seemed reasonable"
- [ ] Domain model cardinalities were interrogated, not assumed

**Consistency**
- [ ] No two requirements specify contradictory behavior for the same trigger
- [ ] Terminology matches the glossary throughout — no synonym drift
- [ ] NFR targets don't silently contradict each other (e.g., an availability target and a consistency requirement that are jointly infeasible per CAP)

**Unambiguity**
- [ ] `check_requirements.py` reports zero ambiguous-quantifier and unmeasurable-NFR findings
- [ ] Every "shall" requirement has exactly one plausible reading; if reviewers disagree on meaning, it fails this check regardless of what the linter says

**Testability**
- [ ] Every requirement has a concrete pass/fail test, in principle if not yet in practice
- [ ] Acceptance criteria are binary, not judgment calls

**Feasibility**
- [ ] Each Must-have requirement is achievable within the constraints from Phase 1 (`CON-nn`) — technically, and within the team/timeline/budget
- [ ] The NFR targets were sanity-checked against the architecture (Phase 7 §8), not left as aspirational numbers nobody validated against the design

**Necessity**
- [ ] Every requirement traces to a real stakeholder need, not a "might be nice" invented during drafting
- [ ] Gold-plating flagged and either justified or cut — a requirement with no stakeholder trace and no business rationale is a candidate for removal, not documentation debt to carry forward

**Prioritization sanity**
- [ ] Must-have count is still credible (the honesty check from Phase 2 §5), not inflated over the course of drafting

## 4. Traceability matrix

The traceability matrix is what makes every checklist item above verifiable rather than asserted, and it is what makes scope changes safe later — when a stakeholder need changes, the matrix shows exactly which FRs, NFRs, use cases, and architecture decisions are affected, instead of someone having to remember or re-derive it.

Build it both directions. Forward traceability (need → implementation) proves nothing was lost. Backward traceability (design element → need) proves nothing was invented.

```
FORWARD TRACEABILITY

STK-07 (Recover from breakdown without calling depot, <3min)
  └─ FR-014  Reassign shipment to alternate vehicle
  │    └─ UC-05  Reassign Shipment
  │    └─ US-021 As a coordinator, I want to reassign...
  │    └─ AC-014.1 .. AC-014.5
  │    └─ ADR-002 Modular monolith + async outbox (satisfies NFR-011
  │                dependency of this flow)
  ├─ FR-015  View eligible vehicles
  ├─ NFR-006 Reassignment latency p95 ≤ 2.0s
  └─ NFR-011 Full function when TMS/telemetry degraded

BACKWARD TRACEABILITY (spot-check — every design element should resolve up)

ADR-002 (async outbox pattern)
  └─ satisfies: NFR-006, NFR-011
  └─ driven by: STK-07 (transitively)
  └─ orphan check: PASS — no design element with an empty trace-up

Component: NotificationWorker
  └─ satisfies: FR-022 (notify all parties), UC-05 step 6
  └─ orphan check: PASS
```

Maintain as a table for anything past Lite tier — one row per requirement, columns for stakeholder source, use case/story, acceptance criteria, architecture element, and (once implementation starts) code module and test.

```markdown
| ID     | Source  | Satisfied by (design)      | Verified by      | Status   |
|--------|---------|------------------------------|-------------------|----------|
| FR-014 | STK-07  | ADR-002; ReassignmentSvc    | AC-014.1..5, UAT-08 | Approved |
| NFR-006| STK-07  | ADR-002 (outbox, off-path)  | Load test LT-03   | Approved |
```

**Run these checks against the matrix, not by inspection:**
- **Orphan requirements** — no stakeholder source. Either find the source or cut it.
- **Orphan design elements** — architecture with no requirement driving it. Either find the requirement it's actually satisfying (and record the trace) or remove it — this is exactly how unnecessary complexity accumulates.
- **Unsatisfied requirements** — no design element traces to them. The architecture is incomplete.
- **Unverified requirements** — no acceptance criteria or test traces to them. Cannot be called done regardless of implementation status.

This matrix is also the direct input to Phase 9: components with the densest trace lines are the ones most worth turning into a dedicated skill, because they carry the most concentrated project-specific knowledge.

## 5. Baselining and change control

Once reviewed, the requirements and architecture become the **baseline** — the reference point every future change is measured against. Baselining is a deliberate act, not something that happens automatically when people stop editing.

```
BASELINE v1.0
Date:        2026-08-12
Scope:       All FR/NFR/STK/ADR with Status = Approved
Approved by: <sponsor, tech lead, ...>
Open items:  OQ-07, OQ-11 (do not block baseline; tracked separately)
```

After baselining, every change goes through a lightweight but real process — skipping it is how scope creep happens invisibly:

1. **Propose** — what's changing and why (new stakeholder need, discovered constraint, architecture infeasibility).
2. **Impact-assess** — walk the traceability matrix to find every requirement, design element, and prior decision affected. This is the step that's skipped when there's no matrix, and it's the step whose absence causes the most rework.
3. **Decide** — accept, reject, or defer, with a named decider appropriate to the change's significance.
4. **Apply** — update the artifact, bump version, keep the ID unchanged, log the change.

```
CHANGE LOG

CR-03  2026-08-20
  Change:  NFR-006 target relaxed from p95 1.5s to p95 2.0s
  Reason:  Load testing (LT-03) showed 1.5s required a caching layer
           not justified by current volume; 2.0s still satisfies STK-07's
           3-minute end-to-end target with margin
  Impact:  ADR-002 unaffected; latency budget in Phase 5 §6 updated
  Approved by: Tech lead, 2026-08-20
```

## 6. Sign-off

For Standard and Rigorous tiers, close the phase with explicit sign-off rather than implicit consensus — implicit consensus is where disputes that were never actually resolved get discovered during implementation, at maximum cost.

| Artifact | Approver | Approved | Date |
|---|---|---|---|
| Requirements (SRS) | Product owner / sponsor | ☐ | |
| Requirements (SRS) | Tech lead | ☐ | |
| Architecture | Tech lead / architect | ☐ | |
| Security-relevant NFRs | Security reviewer | ☐ | |
| Compliance-relevant requirements | Compliance / legal | ☐ | |

For Lite tier, a single "reviewed and I'm proceeding on this basis" from the user is sufficient — but say so explicitly rather than letting the baseline happen by default.

## Exit criteria

- [ ] Full checklist in §3 worked through, defects logged and resolved or explicitly deferred
- [ ] At least one technique beyond self-review used, matched to the depth tier
- [ ] Forward and backward traceability matrix built and checked for orphans on both sides
- [ ] Every requirement has a verification method (test, UAT scenario, or explicit deferral)
- [ ] Baseline declared explicitly, with version, date, and scope
- [ ] Change control process stated for anything that follows the baseline
- [ ] Sign-off obtained at the level appropriate to the depth tier
- [ ] Open questions from every prior phase either resolved or explicitly carried forward with an owner
