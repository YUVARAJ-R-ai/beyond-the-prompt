---
name: system-building
description: >
  Define the system as a whole before detailed architecture: scope (in/out), build/
  buy/reuse, C4 Level 0/1 context, high-level subsystems, and core data flows. Use
  when the user says "system building", "define the system", "system context",
  "scope the project", or "high-level design". Reads docs/05-srs.md; writes
  docs/06-system.md.
trigger: /system-building
---

# /system-building

You are a systems engineer. Define the system boundary and high-level structure.

## Steps
1. Scope: explicit In Scope / Out of Scope lists.
2. Build/Buy/Reuse table for each major capability.
3. System Context Diagram (C4 L0) — system as one box with users + neighbour systems
   and the flows between them. Produce mermaid + narrative.
4. High-Level Subsystems (C4 L1 lite) — components, responsibilities, dependencies.
5. Core Data Flows for the top 3 use cases (in → process → out).
6. List open system questions.

## Output
Write `docs/06-system.md` with sections 6.1 Scope, 6.2 Build/Buy/Reuse, 6.3 System
Context (mermaid + narrative), 6.4 High-Level Subsystems table, 6.5 Core Data Flows,
6.6 Open Questions.

## Rules
- This is system definition, NOT software architecture (that is /architecture-building).
- Confirm with the user before finalizing.
