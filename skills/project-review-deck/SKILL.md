---
name: project-review-deck
description: "Build a visually appealing presentation for a project review by reviewing the actual codebase and generating slides — including data-flow / architecture diagrams — that match the user's stated requirements. Output can be a PowerPoint (.pptx) OR an interactive HTML deck with animated diagrams and transitions. Use this whenever the user wants a deck, slides, presentation, or interactive web presentation FROM their code or project, for a project review, demo day, sprint review, evaluation, panel, or sponsor update — especially when they mention 'review my repo/project', 'slides for my project', 'present my codebase', 'data flow diagram', 'architecture slides', or 'HTML presentation'. Trigger even if the user only says 'make a presentation for my project review' without spelling out every step — this skill handles asking for the requirements first, then reading the code, then building the deck."
license: Proprietary
---

# Project Review Deck

Turn a real codebase into a polished, accurate project-review presentation. The job is three phases, in order: **(1) gather requirements, (2) review the code, (3) build the deck.** Never skip phase 1 or phase 2 — a deck built without reading the code is just decoration, and a deck built without the user's requirements is a guess.

This skill orchestrates; it does not reinvent slide rendering. The output can be a **PowerPoint** (via the pptx skill) or an **interactive HTML deck** (animated diagrams + transitions) — the user picks in phase 1. Phases 1 and 2 are identical either way; only phase 3 branches by format.

---

## Phase 1 — Gather requirements (always do this first)

Before touching the code, ask the user for the spec. These answers drive everything downstream, so don't guess them. Use the `ask_user_input` tool if available (tappable options are easier than typing); otherwise ask in prose. Keep it to one round.

Ask for these six things. Sensible defaults are in brackets — offer them so the user can just confirm.

1. **Output format** — how should the deck be delivered?
   - *PowerPoint (.pptx)* — portable, editable in Office, good for emailing / uploading to a portal [default for a graded panel that expects a file]
   - *Interactive HTML deck* — a single self-contained `.html` file with animated data-flow diagrams and slide transitions; best when you'll present from a laptop/projector and want the diagram to come alive
   - *Both*
2. **Slide count** — how many slides? [default: 10–12]
3. **Text density per slide** — how wordy should slides be?
   - *Minimal* — a headline + 2–3 short phrases, talk-track lives in the speaker notes
   - *Balanced* — headline + 3–5 concise bullets [default]
   - *Detailed* — fuller paragraphs, for a leave-behind doc that reads on its own
4. **Visual elements** — what should appear besides text? (multi-select)
   - Data-flow / architecture diagram(s) [default ON — this is usually the point]
   - Stat callouts (big numbers: LOC, test coverage, endpoints, models)
   - Tech-stack icon rows
   - Screenshots / UI mockups (ask the user to provide these; don't fabricate)
   - Comparison or before/after tables
   - Timeline / roadmap
5. **Overall vibe** — what should it feel like? (pick one, see `references/vibes.md` for the palette + type pairing each one maps to)
   - *Professional / corporate* — clean, navy/charcoal, conservative [default for a graded or panel review]
   - *Modern startup / pitch* — bold, high-contrast, confident accent color
   - *Technical / engineering* — dark theme, monospace accents, diagram-forward
   - *Aesthetic / editorial* — generous whitespace, refined serif headers, muted palette
   - *Academic / research* — restrained, structured, figure-and-caption oriented
6. **Audience & purpose** (one line) — e.g. "graded 2nd-year review panel", "demo day investors", "internal sprint review". This sets tone and what to emphasize.

Also confirm: **where is the code?** (a path they uploaded, a folder in the workspace, or a GitHub URL to clone). If nothing is provided, ask for it — you cannot do phase 2 without it.

If the user has already answered some of these in the conversation, don't re-ask — confirm what you inferred and only ask for the gaps.

---

## Phase 2 — Review the codebase

Read `references/codebase-analysis.md` and follow it. The goal is to come out with a faithful mental model you can put on slides without making things up. In short:

- Map the project structure (entry points, modules, services, layers).
- Identify the **stack** (languages, frameworks, datastores, external services) from manifests, not guesses.
- Trace the **data flow**: where input enters, how it moves through the system, where it's stored, what comes out. This becomes your diagram(s).
- Pull **real numbers** for stat callouts (file/line counts, number of endpoints/components/models, test files) — only cite what you actually measured.
- Note the **features / capabilities** worth showcasing and any standout engineering decisions.

Capture all of this in a short `analysis.md` scratch file in the working directory. The deck content comes from this file — so if a claim isn't supported by the analysis, it doesn't go on a slide.

**Accuracy over flattery.** If the code is a thin prototype, present it honestly as a prototype. Don't invent components, scale numbers, or claim features that aren't there — a review panel will catch it.

---

## Phase 3 — Build the deck

Both formats share the same content, vibe, slide arc, and the rule that every claim traces to `analysis.md`. They differ only in rendering. **Build the path(s) the user chose in phase 1.**

### Shared decisions (do these first, regardless of format)
- **Apply the chosen vibe** — pull the exact palette, font pairing, and motif from `references/vibes.md`. Commit to it on every slide. The palettes are hex values that map equally to pptxgenjs fills and CSS.
- **Respect the text-density choice** literally. *Minimal* means no paragraphs on slides — detail goes to speaker notes (PPTX) or a collapsible/presenter-notes region (HTML).
- **Plan the data-flow / architecture diagram(s)** from `analysis.md`. This is the centerpiece — clear, labeled, directional.
- **Suggested slide arc** (adapt to slide count and purpose):
  1. Title — project name, one-line value prop, author/team, context
  2. Problem / motivation
  3. What it does — core features (icon rows or a 2×2 grid)
  4. Tech stack
  5. **Architecture overview** (the big diagram)
  6. **Data flow** — walk one key path end-to-end
  7. Deeper dive on the most interesting subsystem
  8. Key engineering decisions / challenges solved
  9. Stats / status (real numbers)
  10. Roadmap / next steps
  11. Closing — recap + ask (grade, feedback, funding)

  Compress or expand to hit the requested count.

### Path A — PowerPoint (.pptx)
1. **Read the pptx skill** (`/mnt/skills/public/pptx/SKILL.md`) and build from scratch with pptxgenjs unless the user supplied a template.
2. Build diagrams per `references/dataflow-diagrams.md` (native shapes for simple chains, SVG→PNG for layered architectures).
3. **QA is mandatory** — run the pptx skill's visual QA loop (render to images, inspect with fresh eyes for overflow/overlap/contrast, fix once). Check diagram labels specifically — they're the most common defect.

### Path B — Interactive HTML deck
Read `references/html-deck.md` and follow it. In short:
1. Read `frontend-design` (`/mnt/skills/public/frontend-design/SKILL.md`) for visual direction; `frontend-patterns` is available for structure if needed.
2. Produce a **single self-contained `.html` file** (CSS + JS inline, fonts/libs from CDN) so it opens anywhere with no build step.
3. Implement **slide transitions** (keyboard ← →, smooth fade/slide between slides) and **animated diagrams** — the data-flow diagram animates the path step-by-step (nodes light up, the connecting flow draws/pulses in sequence), so the presenter can walk the panel through it live.
4. Map the chosen vibe to CSS custom properties (palette → `--primary/--accent/...`, fonts → web-safe or CDN webfonts).
5. **QA** — open the file headless, screenshot a few slides, and check the same things (overflow, contrast, diagram label readability, transitions not clipping content). See `references/html-deck.md` for the headless render command.

### Deliver
**Present the file(s)** with `present_files` and a 2–3 line summary. For *Both*, present the `.pptx` and `.html` together. Don't dump a long postamble.

---

## Guardrails

- Phases are ordered. Requirements → code → deck. Don't draft slides before reading the code.
- Phases 1–2 are format-agnostic; only phase 3 branches into PPTX vs HTML. Build the path(s) the user chose.
- Every factual claim on a slide must trace back to `analysis.md`.
- Never fabricate screenshots, metrics, or components.
- One vibe, applied consistently — see `references/vibes.md` for why mixing palettes reads as AI-generated filler.
