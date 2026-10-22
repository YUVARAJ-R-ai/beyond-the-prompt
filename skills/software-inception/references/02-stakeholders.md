# Phase 2 — Stakeholder Analysis

Goal: identify everyone who can affect or is affected by the system, understand what each actually wants, and convert that into stakeholder requirements that functional requirements can trace back to.

The requirements you get are a function of who you asked. Missing a stakeholder class doesn't produce visibly incomplete requirements — it produces requirements that look complete and fail in a category no one considered.

## Contents
- [1. Identification](#1-identification)
- [2. Stakeholder register](#2-stakeholder-register)
- [3. Power/interest analysis](#3-powerinterest-analysis)
- [4. Personas](#4-personas)
- [5. Stakeholder requirements](#5-stakeholder-requirements)
- [6. Conflict resolution](#6-conflict-resolution)
- [Exit criteria](#exit-criteria)

---

## 1. Identification

Work through categories rather than free-associating — free association reliably yields users, buyers, and developers, and misses the rest.

**Primary (direct users)** — anyone who touches the interface. Split by role, not by department: a "manager" who approves 5 requests a day and a "manager" who reviews 300 are different stakeholders regardless of title.

**Secondary (indirect)** — receive output, provide input, or are affected by decisions the system makes. Customers who get the emails. Downstream teams consuming the data. People whose work the system reschedules.

**Operational** — keep it running. Sysadmins, SREs, DBAs, support desk, on-call. They own the NFRs nobody else asks for: observability, deployability, diagnosability. If you never talk to them, you will ship a system that cannot be operated, and you will find out during the first incident.

**Governance** — approve, fund, or constrain. Sponsor, product owner, security review, architecture board, legal, compliance, procurement, DPO. They rarely use the system but can stop it.

**External** — regulators, auditors, partner organizations, integrators, third-party vendors whose SLAs become your SLAs.

**Negative stakeholders** — those whose position worsens: staff whose work is automated, teams losing control of a process, competitors, and adversaries. The last group is a requirements source: attackers define your security requirements as surely as users define your functional ones.

**Non-human** — scheduled jobs, other systems, ML pipelines, monitoring agents. They have needs (rate limits, stable schemas, idempotency) and no voice, so record them explicitly.

**Prompts that surface the forgotten:** Who fixes it at 3am? Who gets blamed when the number is wrong? Who has to sign off before launch? Whose spreadsheet does this replace? Who reads the data we produce? Who currently does this manually? Whose job changes?

## 2. Stakeholder register

| Field | Notes |
|---|---|
| ID | `STK-nn` |
| Name / role | Individual if known, else role |
| Category | Primary / Secondary / Operational / Governance / External / Negative |
| Population | How many; how often they use it |
| Goals | What they want from this system |
| Pain points | What frustrates them today |
| Success criteria | How *they* judge whether it worked |
| Influence | High / Medium / Low |
| Interest | High / Medium / Low |
| Attitude | Champion / Supportive / Neutral / Skeptical / Opposed |
| Domain expertise | Expert / Intermediate / Novice |
| Tech proficiency | Affects UI and training requirements |
| Access | Can we actually talk to them? Via whom? |
| Engagement plan | Interview / workshop / survey / observe / proxy |

The **Access** field earns its place. If a stakeholder class is unreachable, you're working from a proxy, and proxy-derived requirements are systematically distorted — managers describe how work *should* happen, not how it does. Flag proxy-sourced requirements with lower confidence and validate them early.

Use `assets/stakeholder-register.md` as the template.

## 3. Power/interest analysis

Classify each stakeholder on influence over the project vs interest in the outcome, then engage accordingly.

```
High influence │  KEEP SATISFIED          │  MANAGE CLOSELY
               │  (sponsor, security,     │  (product owner, primary
               │   compliance)            │   users, ops lead)
               │  Consult on decisions    │  Involve continuously,
               │  affecting them; don't   │  co-own requirements
               │  drown in detail         │
               ├──────────────────────────┼──────────────────────────
 Low influence │  MONITOR                 │  KEEP INFORMED
               │  (adjacent teams)        │  (secondary users, support)
               │  Low-effort updates      │  Regular updates; their
               │                          │  input matters even
               │                          │  without authority
               └──────────────────────────┴──────────────────────────
                  Low interest               High interest
```

Two failure patterns this catches:

- **High-influence, low-interest stakeholders discovered late.** Security review that appears two weeks before launch with a mandatory finding. Consult them in Phase 1, not at the gate.
- **High-interest, low-influence stakeholders ignored.** Frontline users usually have the highest-quality requirements and the least authority. Systematically discounting them yields a product the buyer approves and the users route around.

## 4. Personas

For the 3–5 highest-value primary stakeholder groups, write a persona. Personas earn their keep only if grounded in real observation; invented ones just launder assumptions into apparent evidence. If you haven't talked to anyone in the group, label it `[PROVISIONAL]`.

```
PERSONA: <Name>, <role>
Grounding:      <interviews conducted / observation / provisional>

Context of use
  Environment:  <desk, warehouse floor, in vehicle, shared kiosk>
  Device:       <what they actually have>
  Interruptions:<continuous / occasional / focused>
  Frequency:    <100x/day vs 2x/month — drives the entire interaction design>
  Expertise:    <domain / technical>

Goals
  Primary:      <the job they're hired to do>
  Secondary:    <what else they need from this>

Frustrations today
  <specific, observed, with cost>

Workarounds
  <the spreadsheet, the WhatsApp group, the sticky note — each one is
   an unmet requirement with evidence attached>

Success looks like
  <in their words>

Constraints
  <gloves, one hand free, no signal, screen reader, shared login,
   low-end Android, 30-second window between customers>

Quote
  "<something they actually said>"
```

The **workarounds** section is the most productive. People build workarounds only for needs strong enough to justify the effort, which makes each one a pre-validated requirement.

**Usage frequency** deserves special attention because it changes design more than any other factor. A 100×/day task needs keyboard-first, dense, memorizable flows; a 2×/month task needs guidance, defaults, and forgiveness. Designing the first like the second is the most common usability failure in internal tools.

## 5. Stakeholder requirements

Stakeholder requirements sit between business goals and system requirements: what a stakeholder needs to accomplish, stated without solution language. They are the traceability anchor — every functional requirement should trace up to at least one.

Format:

```
STK-07: A dispatch coordinator must be able to reassign an in-transit
        shipment to an alternate vehicle and have all affected parties
        informed, without leaving their current task.

Source:     Interview, R. Kumar (coordinator, Chennai depot), 2026-08-04
Category:   Primary
Priority:   Must
Rationale:  Current process takes 22 min and leaves shipment status stale;
            drives 30% of customer service escalations.
Satisfied by: FR-014, FR-015, FR-022, NFR-004
```

Note what's absent: no screens, no buttons, no technology. That's deliberate — it preserves solution freedom for Phase 7 while still being specific enough to test.

**Prioritize with MoSCoW, with a rule that makes it honest:** Must-have means the release is worthless without it. If more than ~60% of requirements are Must, the prioritization is fake and needs redoing. Force the question: "if we shipped without this, would you still deploy?"

Alternatives when MoSCoW is too coarse: **Kano** (basic/performance/delight — good for understanding satisfaction curves), or **cost-of-delay ranking** for portfolio decisions.

## 6. Conflict resolution

Stakeholder needs conflict. This is normal and must be resolved explicitly — unresolved conflicts don't disappear, they get decided implicitly by whoever writes the code, which is the worst possible resolution mechanism.

**Typical axes:**
- Security/compliance vs usability (approval steps vs speed)
- Finance vs everyone (cost ceiling vs capability)
- Ops vs product (stability vs release velocity)
- Power users vs novices (density vs guidance)
- Individual vs organization (autonomy vs standardization)

**Log each conflict:**

```
CONFLICT C-03
Between:      STK-04 (Compliance: dual approval on all refunds)
              STK-07 (Support lead: refund under ₹500 in one click)
Nature:       Control vs cycle time
Options:      (a) Dual approval always — 4 min avg, compliance satisfied
              (b) Threshold-based — single approval under ₹500 with full
                  audit trail and daily sampled review
              (c) Post-hoc review — fastest, weakest control
Decision:     (b)
Decided by:   Compliance lead + Head of Support, 2026-08-06
Rationale:    Risk-weighted: sub-₹500 refunds are 71% of volume and 6% of
              value; audit trail plus 10% daily sampling preserves the
              control objective at a fraction of the cycle-time cost.
Affects:      FR-031, FR-032, NFR-009, BR-04
```

**Escalation ladder:** reframe to interests rather than positions (both parties usually want "no fraudulent refunds", not "an approval button") → find an option satisfying both → make the tradeoff explicit with data → escalate to the sponsor with a recommendation. Never resolve by picking whoever spoke most recently or most loudly.

**When a conflict can't be resolved now**, log it as an open question `OQ-nn` with a decision deadline and a default that applies if the deadline passes. Silent deferral becomes a defect.

## Exit criteria

- [ ] All six categories swept, including operational, negative, and non-human
- [ ] Register complete with influence, interest, attitude, and access
- [ ] Power/interest map produced; engagement approach set per quadrant
- [ ] Personas for top 3–5 primary groups, provisional ones labeled
- [ ] Stakeholder requirements written solution-free, each with source and priority
- [ ] MoSCoW passes the honesty check (Musts are genuinely release-blocking)
- [ ] Conflicts logged with decision, rationale, and decider — or an OQ with a deadline
- [ ] Unreachable stakeholder classes flagged as proxy-sourced
