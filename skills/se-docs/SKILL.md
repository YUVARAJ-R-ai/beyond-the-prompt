---
name: se-docs
description: Generate professional Microsoft Word (.docx) documents for software-engineering projects — WBS + Gantt, SRS, design docs, test plans, vision/scope, project reports. Sources content from the repo (docs/, workflow.md, code) and/or the GitHub project board, then builds a clean, consistently styled document with the shared python-docx engine. Use whenever the user wants a Word document / report / SRS / WBS / Gantt / design doc for a software project.
---

# se-docs — Software-Engineering Project Documents (.docx)

Produce polished, submission-ready **Word documents** for software-engineering
coursework and real projects. All documents share one styling engine
(`scripts/docgen.py`).

**Design goal: it must read like a carefully formatted human submission, not a
generated template.** Coloured corporate banners, blue header rows, rainbow Gantt
bars, and zebra striping are the tells that scream "AI-generated" — the engine
deliberately avoids them. The house style is **academic monochrome**: Times New
Roman body, justified text, plain black numbered headings with a thin rule,
light-grey table headers with black text, thin grey borders, a greyscale Gantt,
and footer page numbers. Keep it that way. If a user asks for a brand colour,
apply it sparingly (one accent, headings only) — never revert to filled colour
header rows or multi-colour bars.

## When to use
Any request for a `.docx` deliverable about a software project: WBS, Gantt /
schedule, SRS, software design document, test plan, vision & scope, risk
register, sprint/project report. If the user wants slides use `project-review-deck`;
if they want a knowledge graph use `graphify`; this skill is for **documents**.

## Prerequisite
`python-docx` must be importable (`python3 -c "import docx"`). If missing:
`pip install python-docx`. No other libraries are needed — Gantt charts are
rendered as native Word tables (shaded week cells), so `matplotlib`/`openpyxl`
are NOT required.

## Workflow

1. **Confirm the document type and title.** If the user named one ("WBS", "SRS"),
   use it. The document's main title is exactly what the user asks for.

2. **Gather content from the project — do not invent it.** In priority order:
   - `docs/*.md` (workflow, research, business, brainstorm, requirements)
   - Source code for ground-truth structure (e.g. pipeline/agent files reveal
     which issue implements what; DB models reveal entities)
   - The GitHub board via `gh issue list --json ...` and
     `gh api repos/OWNER/REPO/milestones` — **only if the user is fine with it.**
     If a board call is refused or unavailable, fall back to the local docs and
     clearly flag anything you had to infer.
   - Existing `.docx`/`.xlsx` in `docs/` for consistency (read `.docx` with
     python-docx; `.xlsx` needs `openpyxl` — skip if unavailable).

3. **Write a declarative build script** in the scratchpad that imports the engine:
   ```python
   import sys; sys.path.insert(0, "<skill-dir>/scripts")
   import docgen as dg
   doc = dg.new_document("<TITLE>", subtitle="...", meta={...})
   dg.add_heading(doc, "1. Introduction"); dg.add_body(doc, "...")
   dg.add_wbs_outline(doc, wbs_items)
   dg.add_table(doc, headers, rows, col_widths=[...], align=[...])
   sec = doc.add_section(); dg.set_landscape(sec)     # Gantt goes on landscape
   dg.add_gantt(doc, tasks, num_weeks=14)
   dg.save(doc, "docs/<Name>.docx")
   ```
   Keep the script content (the data) separate from styling (all styling lives in
   `docgen.py`). Put document data — WBS rows, task list — as plain Python lists at
   the top so it is easy to edit and re-run.

4. **Generate, then verify** by reopening with python-docx and printing
   `len(paragraphs)`, `len(tables)`, table shapes, and section orientations.
   Never claim success without reopening the file.

5. **Report** the output path, the section/table summary, and — importantly —
   list every value you **inferred** vs. sourced, so the user can correct it.

## `docgen.py` API (in `scripts/`)

- `new_document(title, subtitle=None, meta=None) -> Document`
  Centered plain-black title, italic subtitle, a thin grey rule, and a 2-col meta
  table. Sets Times New Roman 11 / 1.15 spacing and adds a centered footer page
  number. (Legacy `accent=` kwargs are accepted and ignored — theme is fixed.)
- `add_heading(doc, text, level=1)` — 1=section (black, thin underline), 2=sub, 3=minor.
- `add_body(doc, text, italic=False, size=None, justify=True)` — justified by default.
- `add_wbs_outline(doc, items)` — `items=[(wbs_id, label), ...]`; indent depth is
  inferred from the number of dots in `wbs_id` (`"1.2.3"` → depth 2).
- `add_table(doc, headers, rows, col_widths=None, zebra=False, font_size=10,
  align=None, row_depths=None, indent_col=1, bold_depths=(0,))` — **light-grey**
  header row with **black** text, thin grey borders, no zebra by default. `align`
  is a per-column list of `"left"|"center"|"right"`. The header row repeats across
  page breaks. Pass `row_depths` (one int per row) to render an **indented tree**
  inside the table — column `indent_col` indents 0.14in per level and rows at
  `bold_depths` are bolded; this is how a WBS tree and WBS dictionary become one
  table. A `"\n"` inside any cell value becomes a real line break, so numbered
  flows and step lists work inside cells.
- `add_kv_table(doc, rows, label_w=1.75, value_w=4.45, font_size=9.5)` — two-column
  label/value table from `[(label, value), ...]`. Use for use-case specifications,
  blank templates, and any form-like block.
- `add_image(doc, path, width_in=5.9, caption=None)` — centered picture with an
  optional italic grey caption. Use for tool screenshots in procedure sections.
- `add_gantt(doc, tasks, num_weeks, two_tone=True, ...)` — native-table Gantt,
  **monochrome**. Each task is `{"id","name","owner","start","end","phase"}`; a
  filled cell just means "active". `two_tone` alternates two greys per phase for
  readability; set `False` for a single grey. No colour, no legend chips. Put it
  on a **landscape** section (`dg.set_landscape(doc.add_section())`).
- `set_landscape(section)` / `set_portrait(section)`
- `shade_cell(cell, hex_fill)` — low-level cell background for custom needs.
- `save(doc, path)`

## Document-type recipes

- **WBS + Gantt** (title usually "WBS"): Introduction → WBS outline
  (`add_wbs_outline`) → WBS dictionary table (ID, Work Package, Owner, Depends on,
  Sprint) → landscape Gantt. Group work packages into deliverable-oriented phases
  aligned to sprints; trace each to an issue `#N` when one exists.
- **SRS** (IEEE-830-ish): Introduction (purpose, scope, definitions) → Overall
  Description → Functional Requirements (numbered table FR-1…) → Non-Functional
  Requirements → External Interfaces → Constraints/Assumptions.
- **Software Design Document**: Architecture overview → Component design (one
  subsection per module) → Data design (entities table from DB models) →
  Interface design → Sequence/flow descriptions.
- **Test Plan**: Scope → Test items → Approach → Test cases table (ID, Precondition,
  Steps, Expected) → Pass/fail criteria → Schedule.
- **Problem Statement / Scenario**: Problem statement → scenario narrative → scope
  (in/out table) → modules table → benefits table → aim → team details + task split.
- **SRS with IBM RequisitePro views** (a common lab exercise): register requirement
  **types** by prefix (STRQ, FR, NFR, UC); give every requirement the RequisitePro
  **attributes** (Priority, Status ∈ Proposed/Approved/Incorporated/Validated,
  Difficulty, Stability, Risk, Origin, Assigned To); then build the two views —
  an **Attribute Matrix** per type (requirements as rows, attributes as columns)
  and **Traceability Matrices** between types (X marks a link), plus a coverage
  and *suspect-link* summary. A nine-table set is: types, attribute dictionary,
  three attribute matrices, three traceability matrices, coverage summary.
- **Use Case Anatomy (SRS v1.3)**: actors table → use case inventory → blank
  template → one `add_kv_table` per use case specification → UC→FR traceability
  matrix with a per-column total row → "major requirements" derived from the
  column counts. Keep it disjoint from the attribute/traceability doc: reference
  earlier versions rather than reprinting their tables, and say so up front.

## Conventions
- Write documents into the repo's `docs/` directory.
- The main title is what the user requested, verbatim.
- Never fabricate task names, owners, dates, or requirements — source them or flag
  them as assumptions the user must confirm.
- Do not commit unless the user asks; if committing, follow the repo's commit
  convention and never `git add .`.
