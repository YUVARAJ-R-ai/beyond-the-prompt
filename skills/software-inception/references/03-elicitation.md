# Phase 3 — Elicitation

Goal: get accurate needs out of people who mostly can't state them directly.

Elicitation is not note-taking. Stakeholders describe solutions instead of problems, omit everything they consider obvious, remember the exception better than the rule, and describe the process as designed rather than as performed. Technique selection is how you compensate.

## Contents
- [1. Technique selection](#1-technique-selection)
- [2. Interviewing](#2-interviewing)
- [3. Observation](#3-observation)
- [4. Workshops](#4-workshops)
- [5. Document and data archaeology](#5-document-and-data-archaeology)
- [6. Prototyping as elicitation](#6-prototyping-as-elicitation)
- [7. When the only stakeholder is the person in the chat](#7-when-the-only-stakeholder-is-the-person-in-the-chat)
- [8. Capturing output](#8-capturing-output)
- [Exit criteria](#exit-criteria)

---

## 1. Technique selection

No single technique is sufficient; each has a characteristic blind spot. Triangulate — use at least two, and treat disagreements between them as signal rather than noise.

| Technique | Best for | Blind spot | Cost |
|---|---|---|---|
| **Interview** | Depth, rationale, individual goals | People describe intent, not behavior | Medium |
| **Observation / shadowing** | Actual workflow, tacit knowledge, workarounds | Doesn't reveal why; observer effect | High |
| **Workshop** | Resolving conflicts, cross-functional scope | Loud voices dominate; groupthink | High |
| **Survey** | Breadth, frequency data, prioritization at scale | Only answers what you thought to ask | Low |
| **Document analysis** | Rules, regulations, current-state process | Documents describe the intended, not the real | Low |
| **Data / log analysis** | Ground truth on volumes and actual usage | Shows what, never why | Low–Medium |
| **Prototyping** | Surfacing unstated expectations, UI needs | Anchors thinking on the first design shown | Medium |
| **Competitor / analog analysis** | Baseline expectations, table stakes | Copies their constraints along with their ideas | Low |
| **Incident / support ticket review** | Failure modes, edge cases, real pain, NFRs | Biased toward reported problems | Low |

**Highest-yield-per-hour, in order:** support ticket review (pain that's already documented and costed), observation (workarounds and tacit rules), then structured interviews.

## 2. Interviewing

### Structure

1. **Frame** (2 min) — purpose, duration, what happens with their input, and that you want problems not solutions.
2. **Context** (5 min) — their role, how the system fits their day. Warms them up and calibrates everything after.
3. **Walkthrough** (20 min) — a recent real instance, start to finish. This is the core.
4. **Exceptions** (10 min) — what goes wrong, how often, what they do about it.
5. **Wishes** (5 min) — magic-wand question, then dig for the underlying need.
6. **Close** (3 min) — what did I not ask about? who else should I talk to? Both questions routinely produce the most valuable answers.

### Question patterns that work

**Anchor to a specific recent instance.** "Walk me through the last shipment you reassigned" beats "how do you reassign shipments." Generalized questions get idealized answers; specific instances get real ones, including the phone call to the depot that never appears in the process document.

**Ask about exceptions by rate, not existence.** "How often does the vehicle turn out to be already loaded?" — the answer distinguishes "rare edge case, handle manually" from "happens 40% of the time and is actually the main flow."

**Chase the workaround.** "Is there anything you keep track of outside the system?" Every spreadsheet, WhatsApp group, and notebook is a requirement with proof of demand.

**Convert solutions upward.** When told "I need an export button," ask "what do you do with the file after you export it?" Half the time the real requirement is a scheduled report or an integration, and the button was just the only mechanism they could imagine.

**Ask what would make it worse.** "What would make this system annoying enough that you'd go back to the spreadsheet?" People articulate deal-breakers much more precisely than desires.

**Probe consequences for NFRs.** "If this were down for an hour on a Tuesday morning, what happens?" gets you an availability requirement grounded in cost, instead of a reflexive "99.99%".

### Anti-patterns

- **Leading questions** — "You'd want notifications for this, right?" gets agreement regardless of truth.
- **Compound questions** — two questions, one answer, ambiguous which.
- **Jargon** — the stakeholder nods rather than admitting they don't know what "idempotent" means; you record confirmation you didn't get.
- **Filling silence** — after a question, wait. Three seconds of silence often produces the most useful sentence in the interview.
- **Debating feasibility mid-interview** — "that would be hard" ends disclosure. Capture it; assess later.
- **Accepting "it depends"** — always follow with "depends on what? give me an example of each case." That's a branching rule waiting to be written down.

### Recording

Write up within a few hours; recall decays fast. Separate **what they said** (verbatim where it matters) from **what you inferred**. Send the summary back for correction — cheapest validation available, and stakeholders correct written statements far more readily than they volunteer information.

## 3. Observation

Watch the work happen. What you learn here is what nobody thinks to tell you, because to them it isn't information — it's just how things are.

Look for:

- **Steps absent from the documented process** — the check on a second screen, the "does this look right?" to a colleague.
- **Physical and environmental context** — standing, gloves, one hand on a phone, sunlight on the screen, 40 seconds before the next customer.
- **Interruption patterns** — how often the task is suspended and resumed. Determines whether you need durable draft state, which is an architectural concern, not a UI nicety.
- **Error and recovery** — what they do when something goes wrong. Recovery paths are systematically underspecified because nobody describes them unprompted.
- **Information sources consulted** — every other window, printout, or person is an integration requirement or a data gap.
- **Where they hesitate** — hesitation marks ambiguity in the current process; it will become ambiguity in your requirements unless resolved.

Ask "why did you do that?" *after* the task, not during — narrating changes behavior.

**Contextual inquiry** is the structured version: observe, then interview about what you observed, with the artifacts in front of you. Highest quality output of any technique; also the most expensive.

## 4. Workshops

Use when you need cross-functional agreement or have conflicts to resolve. Do not use for initial discovery — group settings suppress the minority reports that carry the most information.

**Format that works:**
- 5–9 people, all necessary decision-makers present. Missing decision-makers turn the workshop into a status meeting.
- Pre-read circulated 48h ahead: context diagram, current draft requirements, and the specific decisions on the table.
- Silent-write-then-share for idea generation — prevents anchoring on whoever speaks first.
- Visible artifact throughout (whiteboard, shared doc). Verbal agreement without a visible artifact reliably turns out to have been three different agreements.
- Close by reading back decisions and owners.

**Event storming** deserves specific mention for complex domains: participants write domain events on stickies along a timeline, then add commands, actors, policies, and aggregates. It surfaces the domain model, the process boundaries, and the disagreements in a few hours — and the resulting aggregates map almost directly onto architectural components in Phase 7.

## 5. Document and data archaeology

**Documents:** regulations and standards (mandatory requirements, verbatim), existing process docs and SOPs, training material (reveals what's confusing), contracts and SLAs (binding NFRs), audit findings, prior project post-mortems.

Treat process documentation with suspicion — it describes the intended process. Compare it against observation; every discrepancy is either a documentation defect or an undocumented real requirement, and both are worth knowing.

**Data:** this is where you find ground truth.

- Row counts and growth rates → capacity and scalability requirements grounded in fact
- Actual usage distribution by feature → priorities that contradict stated priorities
- Value distributions → the real edge cases (the order with 4,000 line items, the customer with 12 addresses)
- Null rates and default values → optional fields, workflow gaps, fields nobody fills
- Free-text columns → unmet structured-data requirements, always
- Peak-vs-average ratios → performance targets that matter

**Support tickets and incident reports** are the highest-signal source most teams ignore. Categorize a few hundred: the top categories by volume are your usability requirements, the top by severity are your reliability requirements, and the recurring "how do I…" questions are your discoverability requirements.

## 6. Prototyping as elicitation

Use when stakeholders can't articulate what they want but will recognize it, or when a proposed interaction is genuinely novel.

- **Low fidelity first** (paper, wireframe). High-fidelity prototypes attract feedback on colors and fonts while structural problems slide past — and they make people reluctant to request changes, because the thing looks finished.
- **Prototype the disputed part**, not the whole system.
- **Give a realistic task and watch them attempt it.** Do not demo. A demo tests your explanation; a task tests the design.
- **Beware anchoring** — the first design shown becomes the reference point. Show two or three genuinely different options when the interaction model itself is undecided.
- **Throw it away.** Prototypes that graduate into production carry the shortcuts that made them fast.

## 7. When the only stakeholder is the person in the chat

Common case: a solo developer, student, or founder with no other stakeholders available. Adapt rather than skip.

- **Interview them properly.** Use the walkthrough structure on their own idea. "Walk me through what a user does on day one" surfaces more gaps than any amount of independent speculation.
- **Have them role-play the stakeholders they can't reach.** "You're the warehouse supervisor — what would annoy you about this?" People access knowledge in character that they can't retrieve directly.
- **Substitute public data for interviews.** App store reviews of comparable products, Reddit and forum complaints, competitor documentation, support forums. Real user language, freely available, and it beats invention.
- **Present a strawman and invite correction.** "Here's what I'd assume — tell me where I'm wrong." Far more productive than open questions when the user hasn't thought about the area yet, which is nearly always true of NFRs.
- **Label everything unvalidated.** Requirements derived without stakeholder contact are hypotheses. Mark them `[ASSUMED]` and list the cheapest validation for each. This matters most for academic and hackathon projects, where the temptation to generate a confident fictional document is strongest.

## 8. Capturing output

Raw elicitation output is messy: needs, complaints, solutions, constraints, and contradictions mixed together. Keep it raw first, then classify — cleaning too early loses the original phrasing, which is often the most precise record of what was meant.

For each captured item record: what was said, who said it, when, technique used, classification (need / constraint / solution-idea / business rule / complaint / question), and confidence.

Then convert:
- **Needs** → stakeholder requirements (Phase 2) → functional requirements (Phase 4)
- **Quality expectations** → NFRs (Phase 5)
- **Business rules** → the `BR-nn` catalog (Phase 4)
- **Solution ideas** → the option pool for Phase 7, *not* directly into requirements
- **Complaints** → problem statement evidence and acceptance criteria
- **Contradictions** → conflict log (Phase 2)
- **Unknowns** → open questions with owners and deadlines

Keep a **decision journal** running from here on: date, decision, alternatives, rationale, decider. Three months later, "why did we do it this way?" has an answer, and Phase 7's ADRs are half-written already.

## Exit criteria

- [ ] At least two techniques used; disagreements between them investigated
- [ ] Every primary stakeholder group covered directly or explicitly flagged as proxied
- [ ] Real usage data consulted where it exists (volumes, distributions, feature usage)
- [ ] Support tickets / incidents reviewed if available
- [ ] Raw notes captured with source and confidence, then classified
- [ ] Solution-language statements traced back to underlying needs
- [ ] Open questions logged with owners and deadlines
- [ ] Interview summaries sent back to sources for correction
