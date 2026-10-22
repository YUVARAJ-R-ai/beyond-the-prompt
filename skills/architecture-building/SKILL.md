---
name: architecture-building
description: >
  Design the software architecture from the system definition and NFRs: architectural
  drivers, C4 L2/L3 diagrams, style & patterns with trade-offs, technology selection
  with justified alternatives, cross-cutting concerns, deployment/runtime, and ADRs.
  Use when the user says "architecture", "design the system", "tech stack", "C4
  diagrams", "ADRs", or "deployment topology". Reads docs/06-system.md and
  docs/04-nonfunctional.md; writes docs/07-architecture.md.
trigger: /architecture-building
---

# /architecture-building

You are a software architect. Produce a defensible architecture.

## Steps
1. Architectural Drivers: pull the NFRs/constraints from docs/04-nonfunctional.md
   that most shape the design and state their design impact.
2. Choose an architectural style (layered / hexagonal / microservices / event-driven
   / serverless / modular monolith) with rationale + accepted trade-offs.
3. C4 diagrams: L2 Container (apps, services, datastores, brokers + tech) and L3
   Component for the 2–3 most important containers. Reuse L0/L1 from system-building.
4. Technology Selection table: Layer | Choice | Alternatives Considered | Reason.
   Be opinionated; never end on "it depends" without a default.
5. Cross-Cutting Concerns: security, observability, logging, config, CI/CD, error
   handling, i18n.
6. Deployment & Runtime: topology, environments, scaling, DR/RTO-RPO.
7. ADRs: one per significant decision (Status / Context / Decision / Consequences).
8. Architecture Risks with mitigations.

## Output
Write `docs/07-architecture.md` with sections 7.1 Drivers, 7.2 Style, 7.3 L2 diagram,
7.4 L3 diagrams, 7.5 Tech Selection, 7.6 Cross-Cutting, 7.7 Deployment, 7.8 ADRs,
7.9 Risks.

## Rules
- Every tech choice lists alternatives considered and a reason.
- Every major decision gets an ADR.
- Confirm with the user before finalizing.
