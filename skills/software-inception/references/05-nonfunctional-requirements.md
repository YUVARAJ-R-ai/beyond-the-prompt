# Phase 5 — Non-Functional Requirements

Goal: specify the qualities the system must exhibit, each with a number, a measurement method, and a source.

Functional requirements determine whether the system is *useful*. Non-functional requirements determine whether it is *usable, operable, and survivable* — and they drive architecture far more than functional requirements do. Two systems with identical feature lists but different availability and scale targets are different systems.

NFRs are also where most requirements documents collapse into decoration. "The system shall be highly available" is not a requirement. It's a sentiment.

## Contents
- [1. Anatomy of an NFR](#1-anatomy-of-an-nfr)
- [2. Quality attribute scenarios](#2-quality-attribute-scenarios)
- [3. Taxonomy (ISO/IEC 25010)](#3-taxonomy-isoiec-25010)
- [4. Category-by-category guidance](#4-category-by-category-guidance)
- [5. Eliciting numbers people don't have](#5-eliciting-numbers-people-dont-have)
- [6. Budgets and allocation](#6-budgets-and-allocation)
- [7. Tradeoffs](#7-tradeoffs)
- [8. Prioritization](#8-prioritization)
- [Exit criteria](#exit-criteria)

---

## 1. Anatomy of an NFR

```
NFR-006  Reassignment latency under peak load

Category:      Performance efficiency → Time behaviour
Statement:     Under peak load (120 concurrent coordinators, 40 reassignments
               per minute), the reassignment confirmation shall complete
               within 2.0 s at p95 and 5.0 s at p99, measured server-side
               from request receipt to response dispatch.
Metric:        End-to-end server-side latency, p95 / p99
Target:        p95 ≤ 2.0 s, p99 ≤ 5.0 s
Minimum:       p95 ≤ 3.5 s (below this, coordinators revert to phoning)
Conditions:    Peak load as defined; TMS responding within its own SLA
Measurement:   Load test in staging with production-shaped data, plus
               continuous APM histogram in production
Rationale:     STK-07 requires a 3-min end-to-end recovery; the interaction
               involves up to 4 sequential confirmations
Source:        Observation study 2026-08-02; current process timing
Priority:      Must
Trace:         STK-07, FR-014, FR-015
Arch. impact:  Rules out synchronous TMS call in the critical path
```

Six things make it real: a **metric**, a **target**, the **conditions** under which the target applies, a **measurement method**, a **rationale**, and the **minimum acceptable** value.

The **conditions** clause is what most NFRs omit, which makes them meaningless — "responds in 2 seconds" with no load specified is satisfiable by a single user on an idle machine.

The **minimum acceptable** value is what makes tradeoff conversations possible later. When the target proves expensive, the question becomes "can we live with 3.5s?" rather than a renegotiation from scratch.

**Percentiles, not averages.** Average latency hides the tail, and the tail is what users experience as "the system is slow." Always specify p95 or p99. An average of 800ms with a p99 of 14 seconds is a system people complain about.

## 2. Quality attribute scenarios

The six-part scenario form (from ATAM) is the most reliable way to make a quality attribute concrete. Use it whenever an NFR resists quantification — the structure forces the missing information into the open.

| Part | Question | Example |
|---|---|---|
| **Source** | Who or what generates the stimulus? | Vehicle telemetry provider |
| **Stimulus** | What happens? | Telemetry API becomes unresponsive |
| **Artifact** | What's affected? | Vehicle availability service |
| **Environment** | Under what conditions? | Peak weekday morning, 120 active coordinators |
| **Response** | What should the system do? | Serve last-known positions with staleness indicator; degrade eligibility check to capacity + certification only; alert ops |
| **Measure** | How is the response judged? | Detected within 30 s; degraded mode active within 60 s; no reassignment failures; full function restored within 2 min of API recovery |

Write scenarios for: peak load, each dependency failing, a security attack, a common change request, an operator diagnosing an incident, and a new developer's first contribution. That set covers performance, availability, security, modifiability, operability, and maintainability with six concrete artifacts instead of six vague adjectives.

The **modifiability** scenario is the most neglected and most valuable: "A developer must add a new cargo class with distinct eligibility rules. It shall be done in under 4 hours, touching at most 2 modules, with no changes to the reassignment engine." That single scenario constrains the architecture more than most functional requirements do.

## 3. Taxonomy (ISO/IEC 25010)

Walk the full taxonomy rather than writing whichever NFRs come to mind — the categories nobody thinks of unprompted are exactly the ones that cause failures. Not every subcategory applies; explicitly marking one "not applicable" is a valid and useful outcome.

| Characteristic | Sub-characteristics |
|---|---|
| **Functional suitability** | Completeness, correctness, appropriateness |
| **Performance efficiency** | Time behaviour, resource utilization, capacity |
| **Compatibility** | Co-existence, interoperability |
| **Interaction capability** (usability) | Appropriateness recognizability, learnability, operability, user error protection, engagement, inclusivity, user assistance |
| **Reliability** | Faultlessness, availability, fault tolerance, recoverability |
| **Security** | Confidentiality, integrity, non-repudiation, accountability, authenticity, resistance |
| **Maintainability** | Modularity, reusability, analysability, modifiability, testability |
| **Flexibility** (portability) | Adaptability, scalability, installability, replaceability |
| **Safety** | Operational constraint, risk identification, fail safe, hazard warning, safe integration |

Beyond the standard, these matter in practice and deserve their own treatment:

- **Operability / observability** — logging, metrics, tracing, alerting, runbooks, diagnosability
- **Compliance** — regulatory obligations that translate into technical requirements
- **Data quality and lifecycle** — accuracy, retention, archival, deletion, lineage
- **Cost** — infrastructure ceiling per unit of work; a real constraint that's rarely written down
- **Localization** — languages, formats, right-to-left, character sets, time zones
- **Sustainability** — energy and carbon budgets, increasingly a procurement requirement

## 4. Category-by-category guidance

### Performance efficiency

Specify separately: **latency** (per operation type, at percentiles), **throughput** (operations/sec sustained and peak), **capacity** (concurrent users, data volume, growth rate), and **resource ceilings** (memory, CPU, storage, bandwidth, cost per transaction).

Distinguish operation classes — interactive actions, searches, reports, batch jobs, and background sync have wildly different acceptable latencies. A single blanket "all responses under 2s" either over-constrains reports or under-constrains typing feedback.

Anchor to human perception where it applies: ~100ms feels instant, ~1s keeps flow, ~10s loses attention entirely and needs progress feedback and an escape hatch.

Always state the **load profile**: average, peak, peak-to-average ratio, burst shape, and growth. "5,000 requests/day" is meaningless if 4,000 arrive between 09:00 and 09:15.

### Reliability

**Availability** — target as a percentage *and* the measurement window and definition. 99.9% monthly means 43 minutes of downtime; 99.9% annually means 8.7 hours. Define what counts as "down": full outage only, or degraded performance too? Is scheduled maintenance excluded? Nail this down, because it's the difference between an achievable target and an impossible one.

Push back on reflexive high numbers. Each nine multiplies cost. Ask what actually happens during an outage — if coordinators fall back to phones for 20 minutes at a real but bounded cost, 99.5% may be entirely correct and dramatically cheaper.

**RTO and RPO** — how long to restore, and how much data loss is acceptable. RPO=0 requires synchronous replication and reshapes the entire data architecture; RPO=1 hour permits periodic backups. These two numbers have more architectural consequence than almost any other NFR.

**Fault tolerance** — for each dependency, define the degraded mode. "Telemetry unavailable → serve last-known position with staleness badge, disable distance-based eligibility." Systems without specified degraded modes fail completely when any dependency fails.

**Recoverability** — backup frequency, retention, restore time, and *verified* restore testing. A backup that has never been restored is a hypothesis.

### Security

Derive security requirements from threats, not from a checklist. Do a lightweight STRIDE pass per trust boundary on the context diagram: Spoofing, Tampering, Repudiation, Information disclosure, Denial of service, Elevation of privilege. Each identified threat becomes a requirement or an accepted risk.

Specify: authentication (mechanism, factors, session lifetime, lockout), authorization (model — RBAC/ABAC/ReBAC — and enforcement point), data protection (at rest, in transit, in logs, in backups; field-level for sensitive data), audit (what, retained how long, tamper-evidence), input validation, secrets management, dependency and vulnerability management with patch SLAs by severity, and incident response obligations including breach notification windows.

**Classify data first.** Public / internal / confidential / regulated. Classification drives encryption, access control, logging, retention, and residency. Do this before writing security NFRs — it makes most of them fall out mechanically.

### Interaction capability (usability)

Make usability measurable through task performance, not opinion:
- Task completion: 95% of trained coordinators complete reassignment without assistance
- Task time: median under 45 s for the common case
- Error rate: fewer than 1 in 20 attempts requires correction
- Learnability: a new coordinator completes their first unaided reassignment within 15 minutes of a 10-minute walkthrough
- Satisfaction: SUS ≥ 75

**Accessibility** is both an ethical baseline and often a legal constraint. Specify a standard and level (WCAG 2.2 AA is the common bar) and how conformance is verified. Retrofitting accessibility is many times more expensive than building it in, so this belongs here, not in a later release.

### Maintainability

Concrete and verifiable versions:
- Test coverage floors on critical paths, with the paths named
- Build and CI pipeline duration ceilings (a 40-minute pipeline changes how people work)
- Static analysis gates
- Documented public interfaces
- Onboarding time: a new developer ships a reviewed change within 3 days
- Change effort: named modifiability scenarios (see §2)

### Flexibility / scalability

State the growth horizon and the shape. "Support 10× current volume within 18 months without re-architecture" is testable and architecturally decisive. Also specify whether scaling must be horizontal, whether it must be automatic, and what the acceptable scale-up latency is.

Be honest about the horizon. Designing for 1000× when you'll reach 3× buys complexity you pay for every day and benefits you'll never see.

### Operability and observability

Ops stakeholders own these, and nobody asks them. Specify: structured logs with required fields and correlation IDs, metrics (RED — rate, errors, duration — per service at minimum), distributed tracing coverage, alert conditions with owners and runbooks, health and readiness endpoints, deployment frequency and rollback time, configuration changes without redeploy, feature flags, and data migration and rollback procedures.

"Mean time to diagnose a failed reassignment: under 10 minutes using logs alone" is a real requirement with real architectural consequences.

### Compliance

For each applicable regime, translate obligations into technical requirements rather than citing the regulation and hoping. GDPR/DPDP → data subject access within a stated window, erasure with a defined scope, consent records, lawful basis per processing activity, cross-border transfer controls. PCI-DSS → scope minimization, network segmentation, key management. Sector rules → retention minimums, audit trail immutability, reporting formats.

Compliance requirements are constraints (`CON-nn`) that generate NFRs. Both entries should exist and cross-reference.

## 5. Eliciting numbers people don't have

Stakeholders rarely know their availability target. These approaches produce defensible numbers anyway:

**Ask about consequences, not targets.** "If this were down 09:00–10:00 on a Tuesday, what happens? Who's blocked? What's the cost? At what point do you call someone?" The answers convert to availability, RTO, and degraded-mode requirements — grounded in cost rather than aspiration.

**Measure the current state.** For brownfield, existing latency, volume, and error rates give a baseline. "No worse than today" is a legitimate requirement, and often the actual one.

**Offer calibrated options.** "99% is ~7h/month down, and costs roughly X. 99.9% is ~43min, costs ~3X. 99.99% needs multi-region and costs ~10X. Which fits?" Concrete tradeoffs beat abstract questions every time.

**Use the workaround as the bar.** If the manual fallback takes 20 minutes, an outage shorter than that is nearly free. That sets the real RTO.

**Derive from business math.** Transactions/day × peak ratio × growth = throughput. Revenue/hour × outage frequency = availability value.

**Anchor to human perception and to competitors.** For latency and usability, perception thresholds are objective. For table stakes, measure a comparable product.

When a number genuinely can't be obtained, write the requirement with an `[ASSUMED]` target, a stated basis, and a validation trigger. That is far better than omission — an assumed number gets challenged and corrected; a missing one gets silently defaulted during implementation.

## 6. Budgets and allocation

For end-to-end targets spanning multiple components, decompose the budget explicitly. Otherwise every component is individually "fast" and the whole is slow, and nobody's requirement is violated.

```
NFR-006 latency budget — reassignment confirm, p95 ≤ 2.0 s

  Client render + network out        150 ms
  API gateway + auth                  50 ms
  Eligibility recheck                200 ms
  TMS assignment write (async)         0 ms  (queued, off critical path)
  Local persist + audit write        250 ms
  Event publish                       50 ms
  Response + client render           200 ms
  ─────────────────────────────────────────
  Allocated                          900 ms
  Reserve (55%)                     1100 ms
  Total                             2000 ms
```

Generous reserve is correct at this stage — early estimates are optimistic and the reserve absorbs discovery. Revisit after the first performance test.

Apply the same decomposition to availability (dependent components multiply: three components at 99.9% in series yield 99.7%), to error budgets, and to cost.

## 7. Tradeoffs

Quality attributes conflict. Document the conflicts and their resolutions — unresolved, they get decided implicitly by whoever writes the code, and inconsistently across the system.

| Tension | Nature |
|---|---|
| Performance ↔ Security | Encryption, validation, and authorization checks cost latency |
| Performance ↔ Maintainability | Caching, denormalization, and optimization add coupling |
| Availability ↔ Consistency | Partition tolerance forces a choice (CAP); state which side per data class |
| Security ↔ Usability | Every additional factor and approval step adds friction |
| Scalability ↔ Simplicity | Distribution buys headroom at the cost of operational complexity |
| Flexibility ↔ Performance | Indirection and configurability cost cycles |
| Time-to-market ↔ Everything | The tradeoff nobody writes down but everyone makes |

Resolve **per data class or per operation**, not globally. Reassignment writes need strong consistency; vehicle position display tolerates seconds of staleness. A single global consistency choice is almost always wrong in one direction or the other.

Record each resolution as an ADR in Phase 7.

## 8. Prioritization

Rank NFRs, because they compete for the same budget. Two useful lenses:

**Architectural significance** — would relaxing this requirement change the architecture? Those NFRs are the *architectural drivers* and belong in the top tier. An availability target requiring multi-region is architecturally significant; a logging format requirement is not.

**Cost of failure** — what happens if the target is missed by 20%? By 100%? Requirements with cliff-edge failure (a compliance threshold, a safety limit) outrank those that degrade gracefully.

Aim for **5–15 sharp NFRs at Standard tier**, not fifty vague ones. The top 5 architectural drivers carry forward directly into Phase 7 as the basis for architectural choice.

## Exit criteria

- [ ] Full ISO 25010 taxonomy walked; non-applicable categories explicitly marked
- [ ] Every NFR has metric, target, conditions, measurement method, rationale, and minimum acceptable
- [ ] Latency stated at percentiles, with load profile
- [ ] Availability has a window, a definition of "down", and an RTO/RPO pair
- [ ] Degraded mode defined for every external dependency
- [ ] Threat pass done per trust boundary; data classified
- [ ] Accessibility standard and level stated
- [ ] Observability requirements captured from operational stakeholders
- [ ] End-to-end targets decomposed into per-component budgets
- [ ] Conflicts identified with per-data-class resolutions
- [ ] Top 5 architectural drivers identified for Phase 7
- [ ] `check_requirements.py` reports no unmeasurable NFRs
