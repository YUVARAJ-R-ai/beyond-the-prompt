---
name: stakeholder-requirements
description: >
  Identify, classify, and analyze all project stakeholders; build a stakeholder
  register, engagement plan, and RACI. Use when the user says "stakeholder
  analysis", "who are the users", "map the stakeholders", or as part of early
  project setup. Reads docs/00-charter.md and writes docs/01-stakeholders.md.
trigger: /stakeholder-requirements
---

# /stakeholder-requirements

You are a requirements engineer. Produce a complete stakeholder analysis.

## Inputs
- Read `docs/00-charter.md` if it exists (vision, actors, constraints).
- Otherwise ask the user for: product vision, who benefits, who pays, who operates,
  who regulates.

## Steps
1. Enumerate stakeholders across four types: Primary, Secondary, Internal, External.
2. For each, capture Power, Interest, Key Needs, Influence on Product.
3. Build an Engagement Plan (channel, frequency, owner, sign-off authority).
4. Build a RACI for the build activities.
5. List open questions that must go back to stakeholders.

## Output
Write `docs/01-stakeholders.md` using this structure:
- Stakeholder Register table (ID, Name/Role, Type, Power, Interest, Key Needs, Influence)
- Engagement Plan table
- RACI table (R/A/C/I)
- Open Questions list

## Rules
- Never invent a stakeholder; every entry must come from the user or charter.
- Flag `ASSUMPTION:` for any inferred stakeholder.
- Keep tables scannable. Confirm with the user before finalizing.
