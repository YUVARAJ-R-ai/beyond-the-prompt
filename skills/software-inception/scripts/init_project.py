#!/usr/bin/env python3
"""
init_project.py — scaffold a software-inception workspace.

Usage:
  python init_project.py --name "Shipment Reassignment System" --tier standard --out ./workspace

Creates the artifact skeleton appropriate to the chosen depth tier, copying
templates from ../assets and writing empty ID registries so IDs stay unique
and are never accidentally reused across phases.
"""
import argparse
import datetime
import shutil
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parent.parent
ASSETS = SKILL_DIR / "assets"

ID_PREFIXES = [
    "STK", "BR", "FR", "NFR", "UC", "US", "CON", "ASM", "RSK", "IF", "ADR", "OQ"
]

LITE_TEMPLATE = """\
# Inception — {name}

**Tier:** Lite &nbsp;|&nbsp; **Status:** Draft &nbsp;|&nbsp; **Created:** {date}

## 1. Problem
Who / what they're trying to do / what blocks them / cost of status quo / what "solved" looks like.

## 2. Top Stakeholders
| ID | Role | Goal | Priority |
|---|---|---|---|
| STK-01 | | | |

## 3. Scope
In / Out / Deferred.

## 4. Functional Requirements (8–15)
### FR-001 — <Title>
Statement · Trace · Priority · Acceptance criteria

## 5. Non-Functional Requirements (5–8)
### NFR-001 — <Title>
Category · Statement · Metric/Target · Rationale

## 6. Architecture Sketch
Containers, chosen style, one-paragraph rationale.

## 7. Key Decisions (2–3 ADRs, condensed)
### ADR-001 — <Title>
Context · Decision · Consequences

## 8. Open Questions
| ID | Question | Default if unresolved |
|---|---|---|
"""

DIR_LAYOUT = {
    "lite": {
        "files": {"inception.md": LITE_TEMPLATE},
    },
    "standard": {
        "dirs": ["adrs"],
        "files": {
            "stakeholder-register.md": None,   # copied from assets
            "requirements.md": None,
            "architecture.md": None,
        },
    },
    "rigorous": {
        "dirs": ["adrs", "interviews", "models"],
        "files": {
            "stakeholder-register.md": None,
            "requirements.md": None,
            "architecture.md": None,
            "risk-register.md": None,
            "traceability-matrix.md": None,
        },
    },
}

RISK_REGISTER_TEMPLATE = """\
# Risk Register — {name}

| ID | Risk | Likelihood | Impact | Mitigation | Owner | Status |
|---|---|---|---|---|---|---|
"""

TRACEABILITY_TEMPLATE = """\
# Traceability Matrix — {name}

| ID | Source (STK) | Design element | Verified by | Status |
|---|---|---|---|---|
"""


def write_id_registry(out: Path):
    registry = out / "_id-registry.md"
    lines = [
        "# ID Registry\n",
        "Append-only. Never reuse or renumber an ID, even if the item is withdrawn.\n",
    ]
    for prefix in ID_PREFIXES:
        lines.append(f"\n## {prefix}\n")
        lines.append("<!-- e.g. FR-001  Reassign shipment  (added 2026-08-14) -->\n")
    registry.write_text("".join(lines), encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description="Scaffold a software-inception workspace")
    ap.add_argument("--name", required=True, help="Project name")
    ap.add_argument("--tier", required=True, choices=["lite", "standard", "rigorous"])
    ap.add_argument("--out", required=True, help="Output directory")
    args = ap.parse_args()

    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    date = datetime.date.today().isoformat()

    layout = DIR_LAYOUT[args.tier]

    for d in layout.get("dirs", []):
        (out / d).mkdir(parents=True, exist_ok=True)

    for filename, inline_template in layout["files"].items():
        dest = out / filename
        if dest.exists():
            print(f"skip (exists): {dest}")
            continue
        if inline_template is not None:
            dest.write_text(inline_template.format(name=args.name, date=date), encoding="utf-8")
        elif filename == "risk-register.md":
            dest.write_text(RISK_REGISTER_TEMPLATE.format(name=args.name), encoding="utf-8")
        elif filename == "traceability-matrix.md":
            dest.write_text(TRACEABILITY_TEMPLATE.format(name=args.name), encoding="utf-8")
        else:
            # Copy the matching asset template if one exists, else leave a stub.
            asset_map = {
                "stakeholder-register.md": "stakeholder-register.md",
                "requirements.md": "requirements-template.md",
                "architecture.md": "architecture-template.md",
            }
            src = ASSETS / asset_map.get(filename, filename)
            if src.exists():
                shutil.copy(src, dest)
            else:
                dest.write_text(f"# {filename}\n\n<!-- template not found: {src} -->\n", encoding="utf-8")
        print(f"created: {dest}")

    if "adrs" in layout.get("dirs", []):
        adr_template_src = ASSETS / "adr-template.md"
        if adr_template_src.exists():
            shutil.copy(adr_template_src, out / "adrs" / "ADR-TEMPLATE.md")

    write_id_registry(out)
    print(f"\nWorkspace ready at {out} (tier: {args.tier})")


if __name__ == "__main__":
    main()
