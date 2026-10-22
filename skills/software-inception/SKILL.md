---
name: software-inception
description: Run the full front end of the software lifecycle — stakeholder analysis, requirements elicitation, functional and non-functional requirements, use cases and system modeling, architecture design, ADRs, and traceability — then generate project-specific skills from the resulting artifacts. Use this whenever someone is starting a new system, app, platform, or major feature and needs an SRS, requirements document, requirement analysis, user stories, use case diagrams, a stakeholder register, quality attribute scenarios, an architecture or high-level/low-level design document, a tech stack decision, or a C4 diagram. Also use it when someone says "help me plan this project", "what should I build", "design the system for X", "write the SRS for my project", "do the requirement analysis", or is preparing a software engineering deliverable, capstone report, hackathon build plan, or design review — even if they don't name a specific document. Use it before writing implementation code for anything non-trivial.
---

# Software Inception

The front end of a project is where the cheap decisions live. A requirement fixed during elicitation costs nearly nothing; the same defect found in production costs orders of magnitude more. This skill runs that front end properly — from "someone has a vague idea" through to a validated requirements baseline, an architecture with recorded rationale, and a set of generated project skills that carry the decisions forward into implementation.

## Core stance

**Requirements are discovered, not transcribed.** Users describe solutions they've imagined ("I need a dropdown of statuses"); the job is to recover the need underneath ("operators must reclassify a shipment mid-transit"). Always ask *why* one level past what you were told.

**Every requirement must be falsifiable.** If you cannot describe a test that would fail when the requirement is unmet, it isn't a requirement — it's a wish. "The system shall be user-friendly" fails this test. "A trained operator shall complete order entry in under 90 seconds with fewer than 2 errors in 20 attempts" passes.

**Write for the reader who wasn't there.** Artifacts survive the conversation. Anything that lives only in the chat — an assumption, a rejected alternative, a constraint someone mentioned in passing — is lost work.

**Match depth to stakes.** A weekend hackathon build and a payments platform do not deserve the same 60-page SRS. Pick a tier in Phase 0 and hold to it.

## Depth tiers

Establish this before doing anything else, because it governs every phase.

| Tier | Fits | Produces | Rough effort |
|---|---|---|---|
| **Lite** | Hackathon, prototype, personal project, single feature | One combined `inception.md`: problem, top stakeholders, 8–15 FRs, 5–8 NFRs, architecture sketch, 2–3 ADRs | 1 pass |
| **Standard** | Course capstone, startup MVP, internal tool, team project | Separate SRS + architecture doc + ADR log + traceability matrix | Full phase sequence, condensed |
| **Rigorous** | Regulated, safety-critical, enterprise, multi-team, external contract | Full artifact set with formal stakeholder register, quality attribute scenarios, interface catalog, risk register, review sign-off | Full phase sequence, every artifact |

When unsure, ask. When the user won't choose, infer from the stakes and say which tier you picked.

## Workflow

Phases are ordered by dependency, not by ceremony. Later phases legitimately send you back to earlier ones — discovering an architectural constraint often invalidates a requirement, and that is the process working, not failing. Do not let backtracking feel like an error; record what changed and why.

Read the reference file for a phase **when you start that phase**, not upfront. Each is self-contained.

| # | Phase | Reference | Output |
|---|---|---|---|
| 0 | Frame the engagement | *(below)* | Tier, project type, artifact plan |
| 1 | Problem & context discovery | `references/01-discovery.md` | Problem statement, scope, context diagram, constraints, assumptions, glossary |
| 2 | Stakeholder analysis | `references/02-stakeholders.md` | Stakeholder register, power/interest map, personas, STK requirements |
| 3 | Elicitation | `references/03-elicitation.md` | Raw needs, interview notes, conflict log |
| 4 | Functional requirements | `references/04-functional-requirements.md` | FR catalog, user stories, use cases, acceptance criteria, domain model |
| 5 | Non-functional requirements | `references/05-nonfunctional-requirements.md` | NFR catalog with measurable targets, quality attribute scenarios |
| 6 | System modeling | `references/06-system-modeling.md` | Data model, state machines, sequence diagrams, interface catalog |
| 7 | Architecture | `references/07-architecture.md` | Architecture doc, C4 views, tech stack, ADRs, risk register |
| 8 | Validation & traceability | `references/08-validation.md` | Review results, traceability matrix, baseline |
| 9 | Derived skill generation | `references/09-skill-generation.md` | Project-specific skills in `.claude/skills/` |

### Phase 0 — Frame the engagement

Before any analysis, establish four things. Ask them together in one pass rather than interrogating one at a time.

1. **What is being built, in one sentence** — and whether it's greenfield, a rewrite, a feature in an existing system, or an academic deliverable.
2. **Who it's for and who pays** — real users, buyers, operators, regulators.
3. **Hard constraints already fixed** — deadline, budget, mandated stack, existing system it must live inside, coursework rubric, compliance regime.
4. **Depth tier** — from the table above.

For an academic deliverable, ask for the rubric or question paper. Grading criteria are the real requirements for that artifact, and they frequently mandate specific diagrams (DFD levels, ER, UML class/sequence/use-case) that this skill would otherwise deprioritize.

Then scaffold the workspace:

```bash
python scripts/init_project.py --name "<project>" --tier <lite|standard|rigorous> --out <dir>
```

This creates the artifact skeleton with correct front matter and ID registries. If the user prefers a single document, use `--tier lite`.

### Working with the user during phases 1–5

Do not silently invent requirements. The single most common failure mode is generating a plausible, fluent, entirely fictional requirements document. Guard against it:

- **Ask in batches, not one at a time.** Use the interactive question tool where available; otherwise group 3–6 related questions per message.
- **Mark every unverified item.** Anything you inferred rather than were told gets tagged `[ASSUMED]` inline and lands in the assumptions register with a validation owner. Assumptions are legitimate — unlabeled assumptions are not.
- **Offer a strawman when the user is stuck.** "Here's what I'd assume for a system like this — correct me where I'm wrong" gets far more signal than an open question, especially from users who haven't thought about NFRs before.
- **Timebox.** If the user wants to move, move. Capture the gap as an open question and continue; a document with 6 flagged unknowns beats a stalled interview.

### ID conventions

Use these prefixes consistently — the linter, traceability matrix, and skill generator all depend on them.

| Prefix | Meaning | Example |
|---|---|---|
| `STK-nn` | Stakeholder requirement / goal | STK-03 |
| `BR-nn` | Business rule | BR-07 |
| `FR-nnn` | Functional requirement | FR-014 |
| `NFR-nnn` | Non-functional requirement | NFR-006 |
| `UC-nn` | Use case | UC-05 |
| `US-nnn` | User story | US-021 |
| `CON-nn` | Constraint | CON-02 |
| `ASM-nn` | Assumption | ASM-04 |
| `RSK-nn` | Risk | RSK-09 |
| `IF-nn` | External interface | IF-03 |
| `ADR-nnn` | Architecture decision record | ADR-002 |
| `OQ-nn` | Open question | OQ-11 |

IDs are permanent. When a requirement dies, mark it `Status: Withdrawn` and keep the ID — never renumber, because renumbering silently corrupts every downstream reference.

### Quality gate — run before declaring any phase complete

```bash
python scripts/check_requirements.py <requirements-file-or-dir>
```

The linter catches the mechanical failures reliably: ambiguous quantifiers ("fast", "robust", "as needed"), unmeasurable NFRs, compound requirements hiding two behaviors in one "and", duplicate or missing IDs, requirements with no acceptance criteria, and orphans with no stakeholder trace. It is not a substitute for the review checklist in Phase 8 — it catches form, not truth — but nothing should reach review with lint errors outstanding.

### Phase 9 — the point of all this

Once the architecture is settled, the requirements and design encode a large amount of project-specific knowledge that would otherwise be re-explained in every future session. Convert it into skills: a domain glossary skill, a coding-conventions skill matched to the chosen stack, one skill per major component or service, an API contract skill, a testing skill wired to the acceptance criteria, and an ADR-writing skill seeded with existing decisions.

`references/09-skill-generation.md` covers which skills are worth generating (and which are noise), how to derive each one from specific artifacts, and how to run the generator. Do not skip this because the "real work" feels done — this is the step that makes the front-end investment pay off during implementation.

## Deliverable formats

Default to Markdown in the workspace — it diffs, it's greppable, and the scripts read it.

Convert at the end if the user needs something else:
- **Word/PDF report** (course submissions, client deliverables) — read `/mnt/skills/public/docx/SKILL.md` or `/mnt/skills/public/pdf/SKILL.md` first.
- **Slides** for a design review — read `/mnt/skills/public/pptx/SKILL.md`.
- **Diagrams** — Mermaid inline in Markdown by default (renders in most viewers and survives version control). For rendered visuals in chat, use the visualizer. For a docx, render Mermaid to PNG and embed.

## Common failure modes

**Solution-first framing.** The user opens with "I'm building a React app with Postgres and Redis." Accept it as a constraint (`CON-nn`, source: user preference), then still do Phase 1. Half the time the stated stack survives; the other half, Phase 5 surfaces a requirement that breaks it, and it's much cheaper to learn that now.

**NFR theater.** Copying a generic list — "the system shall be scalable, secure, maintainable" — produces text that no one can test and no one will read. Every NFR needs a number, a measurement method, and a source. Fewer, sharper NFRs beat a complete-looking taxonomy.

**Architecture by default.** Reaching for microservices, Kubernetes, and event sourcing on a three-person project with 200 users. Architecture follows from quality attributes; if no NFR demands independent scaling or independent deployment, a modular monolith is the honest answer. Record the rejected alternative in an ADR so the reasoning is visible later.

**The 60-page document nobody reads.** Length is not rigor. If a section doesn't change a decision or enable a test, cut it.

**Traceability as an afterthought.** Building the matrix at the end means reverse-engineering justifications for requirements whose origins are lost. Record the source at the moment a requirement is written.
