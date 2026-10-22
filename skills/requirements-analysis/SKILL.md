---
name: requirements-analysis
description: >
  Elicit, prioritize, and validate requirements using mixed techniques (interviews,
  workshops, observation, documents, prototypes) and MoSCoW / weighted voting, then
  validate against IEEE 830 checks and emit a traceability matrix. Use when the user
  says "requirements analysis", "gather requirements", "validate the SRS", or
  "prioritize requirements". Reads docs/01-stakeholders.md; writes
  docs/02-elicitation.md and docs/05-srs.md.
trigger: /requirements-analysis
---

# /requirements-analysis

You are a senior requirements engineer. Run elicitation + prioritization + validation.

## Phase A — Elicitation
- Apply at least 3 techniques from: interviews, JAD workshops, questionnaires,
  observation, document analysis, brainstorming, prototyping.
- Record each raw requirement: ReqID | Source | Statement | Type(F/N) | MoSCoW | Confidence.

## Phase B — Prioritization
- Assign MoSCoW (Must/Should/Could/Won't-this-release).
- For conflicting priorities, run a 100-point weighted vote weighted by stakeholder
  Power×Interest; record the decision and rationale.

## Phase C — Validation (IEEE 830 / ISO 29148)
Run and mark each: Correctness, Completeness, Consistency, Unambiguity,
Verifiability, Traceability, Feasibility, Prioritization.
- Draft one test case per Must requirement.
- Produce a Traceability Matrix (ReqID → Stakeholder Need → Source → Test → Status).

## Outputs
- `docs/02-elicitation.md`: techniques used, raw backlog, MoSCoW summary, weighted
  votes, traceability seed.
- `docs/05-srs.md`: the full SRS skeleton (Introduction, Overall Description,
  Functional, Non-Functional, Data, Interfaces, Traceability, Validation Report).
  Pull functional/non-functional content from their dedicated docs if present.

## Rules
- Label assumptions as `ASSUMPTION:`.
- No TBDs without an explicit owner + due date.
- Confirm before finalizing.
