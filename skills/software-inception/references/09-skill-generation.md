# Phase 9 — Derived Skill Generation

Goal: convert the requirements and architecture into a set of project-specific skills, so that every future session working on this project starts with the accumulated knowledge instead of re-deriving or re-explaining it.

This phase is the payoff for everything before it. Phases 1–8 produce documents; documents get read once and then forgotten under a pile of new context. Skills get *loaded automatically* whenever their trigger matches, which means the domain glossary, the architecture rationale, and the coding conventions are present in every future coding session without anyone having to remember to paste the SRS in again.

Do not treat this as optional cleanup. A thorough inception with no derived skills leaves all that value sitting in a document nobody re-reads.

## Contents
- [1. What makes a good derived skill](#1-what-makes-a-good-derived-skill)
- [2. The standard skill set](#2-the-standard-skill-set)
- [3. Deriving each skill from specific artifacts](#3-deriving-each-skill-from-specific-artifacts)
- [4. Sizing by depth tier](#4-sizing-by-depth-tier)
- [5. Writing the descriptions](#5-writing-the-descriptions)
- [6. Running the generator](#6-running-the-generator)
- [7. Keeping skills current](#7-keeping-skills-current)
- [Exit criteria](#exit-criteria)

---

## 1. What makes a good derived skill

Not everything in the inception documents deserves to become a skill. A skill earns its place when:

- **It will be needed repeatedly**, not once. The domain glossary is consulted every session; the stakeholder interview schedule is consulted never after Phase 2 closes.
- **It's project-specific**, not general knowledge Claude already has. "How to write a REST API" is not worth a skill. "This project's REST API returns errors in the shape defined by ADR-002, and every mutating endpoint requires an Idempotency-Key header" is.
- **Getting it wrong is costly.** Business rule BR-04's eligibility logic being reimplemented slightly differently in three places is a real, expensive failure mode. A skill that states the rule once, precisely, prevents it.
- **It has a narrow, recognizable trigger.** A skill that fires on "when working on the eligibility module" is useful. A skill that tries to fire on "any coding task" duplicates SKILL.md itself and adds noise.

Conversely, skip generating a skill when the content is small enough to just live in `SKILL.md`'s references directly, when it will go stale faster than it will be read (a sprint-specific to-do list), or when no clear trigger phrase distinguishes it from everything else being worked on.

## 2. The standard skill set

Not every project needs every skill below — pick from this set based on what the architecture and requirements actually produced. Treat it as a menu, evaluated once per project.

| Skill | Source artifacts | Worth it when |
|---|---|---|
| **Domain glossary & business rules** | Phase 1 glossary, Phase 4 domain model + business rules | Almost always — cheapest to build, highest reuse |
| **Coding conventions** | Phase 7 tech stack, cross-cutting concerns | Team has agreed-on stack and standards |
| **Component skill (one per major container/service)** | Phase 7 container diagram, Phase 6 interface catalog for that component's boundaries | Component is nontrivial and will be touched repeatedly |
| **API contract** | Phase 6 interface catalog, Phase 4 FR error/alternate flows | System exposes or consumes a nontrivial API |
| **Testing & acceptance criteria** | Phase 4 acceptance criteria, Phase 8 traceability matrix | Test coverage matters and ACs are numerous |
| **ADR authoring** | Phase 7 ADR log and template | Architecture decisions will keep being made post-inception |
| **Requirements maintenance** | Phase 8 change control process, ID conventions | Requirements will evolve after baseline (nearly always) |
| **Data model & migrations** | Phase 6 logical data model | Schema is nontrivial and will evolve |
| **Security & compliance posture** | Phase 5 security NFRs, Phase 1 constraints | Regulated data or explicit security NFRs exist |

## 3. Deriving each skill from specific artifacts

Each skill should be written the same way `SKILL.md` files are written elsewhere in this environment — YAML frontmatter with `name` and a triggering `description`, then a concise, imperative body. Read `/mnt/skills/examples/skill-creator/SKILL.md` for the authoring conventions (progressive disclosure, writing style, output format patterns) before drafting these — they are real skills, not summaries.

### Domain glossary & business rules

**Source:** Phase 1 glossary, Phase 4 domain model and business rule catalog.

```yaml
---
name: <project>-domain
description: Domain glossary and business rules for <project>. Use whenever writing, reviewing, or discussing code that touches <the core domain nouns — e.g. shipments, vehicles, assignments>, to ensure terminology and business logic match the agreed definitions rather than an assumed or generic interpretation.
---
```

Body: the glossary table, the domain model (as a class diagram), and every business rule with its ID, statement, and volatility. This is the skill that prevents "delivery" meaning three different things in three different modules, per the example in Phase 1.

### Coding conventions

**Source:** Phase 7 technology stack, cross-cutting concerns section, any team style decisions made along the way.

```yaml
---
name: <project>-conventions
description: Coding conventions, project structure, and cross-cutting patterns for <project> (<stack>). Use for any code written in this repository — file organization, error handling shape, logging format, idempotency pattern, and naming conventions specific to this project.
---
```

Body: directory structure, the agreed error response shape (from Phase 7 §5), the idempotency pattern actually chosen, logging/correlation-ID requirements, and naming conventions. Pull directly from Phase 7's cross-cutting concerns section — this skill exists so a new contributor's first PR doesn't invent a fourth error-shape convention.

### Component skills

**Source:** Phase 7 container/component diagrams, the interface catalog entries where that component is either endpoint.

One skill per container worth the overhead (per §1's criteria — skip trivial ones).

```yaml
---
name: <project>-<component>
description: Internals and integration contract for the <Component Name> service in <project>. Use when implementing, debugging, or reviewing code inside this component, or when another component needs to know how to call it.
---
```

Body: the component's responsibility (one paragraph), its internal structure if modeled at C4-3, every interface it exposes or consumes (pulled straight from the Phase 6 interface catalog entries involving it — including the failure modes, idempotency notes, and data ownership), and links to the relevant ADRs.

### API contract

**Source:** Phase 6 interface catalog, Phase 4 acceptance criteria for the endpoints involved.

Worth splitting out from the component skill when the API is consumed by external parties or multiple internal teams — audiences that don't need the component's internals but do need the contract.

```yaml
---
name: <project>-api-contract
description: External API contract for <project> — endpoints, request/response shapes, error codes, idempotency, and versioning policy. Use when writing client code against this API, writing or reviewing endpoint implementations, or documenting API changes.
---
```

Body: endpoint list with method, path, purpose; request/response schemas; the shared error shape; idempotency requirements per Phase 7 §5; versioning policy from the interface catalog's `Versioning` field.

### Testing & acceptance criteria

**Source:** Phase 4 acceptance criteria (all of them), Phase 8 traceability matrix.

```yaml
---
name: <project>-testing
description: Testing approach and acceptance criteria reference for <project>. Use when writing tests, reviewing test coverage, or verifying a change against its acceptance criteria — especially before marking any FR or user story as done.
---
```

Body: testing strategy (unit/integration/e2e split, what runs where), the full AC catalog organized by FR, and the coverage sweeps from Phase 4 §10 as a standing checklist to re-run whenever a new entity or workflow is added.

### ADR authoring

**Source:** Phase 7 ADR log itself, used as worked examples.

```yaml
---
name: <project>-adr
description: Write Architecture Decision Records for <project> in the established format, and consult the existing decision log before proposing anything that might conflict with a prior decision. Use whenever a new architecturally significant choice is being made, or when someone asks "why did we do it this way".
---
```

Body: the ADR template from Phase 7 §7, the full existing log (or a pointer to it if long), and the standing instruction to check the log for a relevant prior decision before making a new one — this is what prevents the same debate happening twice with different outcomes.

### Requirements maintenance

**Source:** Phase 8 change control process, the ID conventions from the main `SKILL.md`.

```yaml
---
name: <project>-requirements
description: Add, modify, or trace requirements for <project> following the established ID scheme and change control process. Use whenever a new requirement emerges, an existing one needs to change, or someone asks what a requirement covers or where it came from.
---
```

Body: ID conventions (reused from this skill's own table), the change control steps from Phase 8 §5, and a pointer to the traceability matrix so impact assessment is habitual rather than skipped.

### Data model & migrations

**Source:** Phase 6 logical data model.

```yaml
---
name: <project>-data-model
description: Data model and migration conventions for <project> — entities, relationships, temporal/audit/multi-tenancy decisions, and migration process. Use when writing migrations, adding fields, or reviewing schema changes.
---
```

Body: the logical model, the explicit decisions from Phase 6 §5 (temporal handling, soft delete, audit, multi-tenancy, PII fields), and the migration process (how schema changes ship without downtime, per Phase 7's deployment view).

### Security & compliance posture

**Source:** Phase 5 security NFRs, Phase 1 regulatory constraints, Phase 7's auth/authz cross-cutting decisions.

```yaml
---
name: <project>-security
description: Security and compliance requirements for <project> — data classification, auth model, and regulatory obligations. Use when handling sensitive data, implementing auth/authz, or before shipping anything touching regulated data classes.
---
```

Body: data classification scheme and which fields fall in which class, the auth/authz model and enforcement points, and each regulatory obligation translated into its concrete technical requirement (per Phase 5's compliance section) rather than left as a citation.

## 4. Sizing by depth tier

- **Lite** — usually just the domain glossary skill, maybe folded into a single project-context skill alongside conventions if the project is small enough that splitting them adds more overhead than value.
- **Standard** — domain glossary, coding conventions, one skill per genuinely nontrivial component, testing skill. Skip API contract and security skills unless the project specifically has an external API or regulated data.
- **Rigorous** — the full set from §2, evaluated seriously rather than generated by default. At this tier, err toward generating a skill when in doubt — the projects that reach Rigorous tier are exactly the ones where re-deriving forgotten context is most expensive.

## 5. Writing the descriptions

Skill descriptions are the entire triggering mechanism — Claude decides whether to consult a skill based on the description alone, before reading the body. Apply the same standard used for `SKILL.md` itself: state both *what the skill contains* and *when to use it*, and lean slightly pushy rather than passive, because under-triggering (a relevant skill that never fires) is the more common failure than over-triggering.

Weak: `description: Information about the Eligibility Service.`

Strong: `description: Internals and integration contract for the Eligibility Service in the shipment reassignment project — eligibility rules (BR-04), the telemetry degraded-mode fallback, and its API surface. Use when implementing, debugging, or reviewing anything in this service, or when another component needs to know how to call it or what its failure modes are.`

The strong version names the specific business rule ID and the specific failure behavior — concrete nouns that make the description recognizable even in a large skill catalog, rather than generic phrasing that could describe any component skill in any project.

## 6. Running the generator

```bash
python scripts/generate_skills.py \
  --requirements <path-to-requirements-dir> \
  --architecture <path-to-architecture-doc> \
  --out .claude/skills/
```

The script scaffolds each skill's directory and frontmatter from the artifacts and flags which of the standard set (§2) look warranted based on what it finds — e.g., it proposes a component skill for every container in the C4-2 diagram, and proposes the security skill only if it finds NFRs tagged under the Security category in Phase 5's document.

**Treat the script's output as a draft, not a finished product.** It scaffolds structure and pulls in the source content; the judgment calls from §1 (is this actually worth a standing skill?) and the description quality from §5 still need a human or agent pass. Review the proposed set with the user before finalizing — ask which components they expect to revisit often, since that's the strongest signal for which component skills earn their keep.

If `scripts/generate_skills.py` isn't available or the environment has no scripting access, do this manually: for each entry chosen from §2, create the directory and `SKILL.md` by hand following the templates in §3, pulling content directly from the corresponding phase's output file.

## 7. Keeping skills current

Derived skills go stale exactly when the source artifacts change and the skill isn't updated alongside — which is the same failure mode documentation always has, and the reason to keep the link between skill and source artifact explicit rather than letting the skill drift into its own independent life.

Two disciplines prevent this:

- **Update the skill in the same change that updates the requirement or architecture.** When a change control entry (Phase 8 §5) modifies an NFR or an ADR, check whether any derived skill quotes the old value, and update it in the same pass.
- **Note the source artifact and version inside the skill itself** — a line like `Derived from: NFR catalog v1.2, ADR-002` — so a future reviewer can tell at a glance whether the skill is still synchronized with its source, without having to diff the whole document.

## Exit criteria

- [ ] Standard skill set (§2) evaluated against §1's criteria; a deliberate include/exclude decision made for each, not a default-generate-everything pass
- [ ] Each generated skill has a specific, pushy, recognizable description — not a generic restatement of its name
- [ ] Component skills exist for every architecturally significant container, sourced from the interface catalog
- [ ] Domain glossary skill exists in essentially every case
- [ ] Each skill traces back to the specific phase artifact(s) it was derived from, noted inside the skill
- [ ] User reviewed the proposed set and confirmed which component skills are worth maintaining
- [ ] Skills saved to `.claude/skills/` (or presented to the user for installation if the environment requires it)
