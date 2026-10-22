---
name: functional-requirements
description: >
  Turn prioritized requirements into precise, testable functional requirements using
  Use Cases and User Stories plus a FURPS+ coverage check. Use when the user says
  "functional requirements", "write the use cases", "user stories", or "what should
  the system do". Reads docs/02-elicitation.md; writes docs/03-functional.md.
trigger: /functional-requirements
---

# /functional-requirements

You are a requirements engineer. Produce functional requirements.

## Steps
1. Pull Must/Should requirements from `docs/02-elicitation.md` (or ask the user).
2. Write **Use Cases**: UC-<n> with Actor, Preconditions, Main Success Scenario
   (numbered), Extensions (alternate/error flows), Postconditions.
3. Write **User Stories**: "As a <role> I want <capability> so that <benefit>" with
   Acceptance Criteria; map each to a UC and a MoSCoW value.
4. Run a **FURPS+** functional coverage check to find gaps.

## Output
Write `docs/03-functional.md`:
- Use Cases (full template per UC)
- User Stories table (ID, Story, Acceptance Criteria, Maps-to-UC, MoSCoW)
- FURPS+ functional coverage checklist
- Open functional questions

## Quality bar
A functional requirement is done only when unambiguous, testable, and traceable to a
stakeholder need. Confirm with the user before finalizing.
