#!/usr/bin/env python3
"""
check_requirements.py — lint a requirements document (or a directory of them)
for the mechanical failure modes that show up constantly in requirements
writing: ambiguous quantifiers, unmeasurable NFRs, compound requirements,
duplicate/missing IDs, requirements with no acceptance criteria, and
orphans with no stakeholder trace.

This catches FORM, not TRUTH. A requirement can pass every check here and
still be wrong or unnecessary — that's what the Phase 8 review checklist is
for. Nothing should reach review with lint errors outstanding, though.

Usage:
  python check_requirements.py requirements.md
  python check_requirements.py ./workspace/          # scans *.md recursively
"""
import argparse
import re
import sys
from collections import defaultdict
from pathlib import Path

ID_PATTERN = re.compile(
    r"\b(STK|BR|FR|NFR|UC|US|CON|ASM|RSK|IF|ADR|OQ)-(\d{2,3})\b"
)

# Words that hide an unstated number. Checked case-insensitively, word-boundary.
AMBIGUOUS_TERMS = [
    "fast", "quickly", "slow", "robust", "user-friendly", "user friendly",
    "intuitive", "seamless", "seamlessly", "efficient", "efficiently",
    "appropriate", "sufficient", "sufficiently", "timely", "minimal",
    "optimal", "easily", "flexible", "scalable", "reasonable", "reasonably",
    "as needed", "as required", "as necessary", "adequate", "acceptable",
    "convenient", "simple", "easy", "responsive", "high performance",
    "high-performance", "modern", "state of the art", "state-of-the-art",
    "etc", "and so on", "and/or", "including but not limited to",
    "such as",
]

# Requires: the word "shall" (a requirement statement) containing " and "
# without also containing acceptance-criteria language nearby — heuristic
# flag for compound requirements, not a hard proof.
COMPOUND_HINT = re.compile(r"shall[^.]*\band\b[^.]*\band\b", re.IGNORECASE)

NFR_NUMERIC_HINT = re.compile(
    r"(\d+(\.\d+)?\s?(ms|s|sec|second|seconds|min|minute|minutes|hour|hours|%|percent|"
    r"req/s|rps|tps|MB|GB|KB|users|concurrent))",
    re.IGNORECASE,
)


def find_ids(text):
    """Return list of (prefix, number, full_id, line_no)."""
    out = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        for m in ID_PATTERN.finditer(line):
            prefix, num = m.group(1), m.group(2)
            out.append((prefix, num, f"{prefix}-{num}", lineno))
    return out


def split_into_requirement_blocks(text):
    """
    Split on lines that introduce a requirement/NFR (### FR-xxx or a line
    starting with FR-xxx / NFR-xxx). Returns list of (id, block_text).
    """
    lines = text.splitlines()
    blocks = []
    current_id = None
    current_lines = []
    header_pattern = re.compile(
        r"^\s*(#{2,4}\s*)?(FR|NFR)-(\d{2,3})\b"
    )
    for line in lines:
        m = header_pattern.match(line)
        if m:
            if current_id:
                blocks.append((current_id, "\n".join(current_lines)))
            current_id = f"{m.group(2)}-{m.group(3)}"
            current_lines = [line]
        elif current_id:
            current_lines.append(line)
    if current_id:
        blocks.append((current_id, "\n".join(current_lines)))
    return blocks


def check_duplicates_and_ids(all_ids, findings):
    seen = defaultdict(list)
    for prefix, num, full_id, lineno in all_ids:
        seen[full_id].append(lineno)
    # A requirement ID that is *introduced* (appears as a header, i.e. many
    # times) is expected to repeat via trace references elsewhere, so we only
    # flag true duplicate *definitions* — heuristic: more than one heading
    # line for the same ID.
    header_ids = defaultdict(list)
    return seen


def check_ambiguous_terms(text, findings, filename):
    for lineno, line in enumerate(text.splitlines(), start=1):
        lower = line.lower()
        for term in AMBIGUOUS_TERMS:
            if re.search(rf"\b{re.escape(term)}\b", lower):
                findings["ambiguous_quantifier"].append(
                    f"{filename}:{lineno}: ambiguous term '{term}' — "
                    f"replace with a number or move to a measurable NFR\n"
                    f"    > {line.strip()}"
                )


def check_compound_requirements(blocks, findings, filename):
    for req_id, block in blocks:
        if req_id.startswith("FR") and COMPOUND_HINT.search(block):
            findings["compound_requirement"].append(
                f"{filename}: {req_id}: statement uses 'and' twice with 'shall' — "
                f"likely two behaviors in one requirement, consider splitting"
            )


def check_unmeasurable_nfrs(blocks, findings, filename):
    for req_id, block in blocks:
        if req_id.startswith("NFR"):
            has_number = bool(NFR_NUMERIC_HINT.search(block))
            has_metric_field = bool(re.search(r"(metric|target)\s*:", block, re.IGNORECASE))
            if not has_number and not has_metric_field:
                findings["unmeasurable_nfr"].append(
                    f"{filename}: {req_id}: no numeric target or Metric/Target field found — "
                    f"cannot be verified as written"
                )


def check_missing_acceptance_criteria(blocks, findings, filename):
    for req_id, block in blocks:
        if req_id.startswith("FR"):
            has_ac = bool(
                re.search(r"acceptance criteria", block, re.IGNORECASE)
                or re.search(rf"AC-{req_id.split('-')[1]}", block)
            )
            if not has_ac:
                findings["missing_acceptance_criteria"].append(
                    f"{filename}: {req_id}: no acceptance criteria found"
                )


def check_orphan_trace(blocks, findings, filename):
    for req_id, block in blocks:
        has_trace = bool(re.search(r"trace(\s*to)?\s*:.*STK-\d+", block, re.IGNORECASE))
        if not has_trace:
            findings["orphan_no_stakeholder_trace"].append(
                f"{filename}: {req_id}: no 'Trace to: STK-nn' found — "
                f"either add the source or confirm this is intentional (e.g. derived from a constraint)"
            )


def check_duplicate_definitions(text, findings, filename):
    header_pattern = re.compile(r"^\s*#{2,4}\s*(FR|NFR|UC|US|ADR)-(\d{2,3})\b", re.MULTILINE)
    seen = defaultdict(int)
    for m in header_pattern.finditer(text):
        full_id = f"{m.group(1)}-{m.group(2)}"
        seen[full_id] += 1
    for full_id, count in seen.items():
        if count > 1:
            findings["duplicate_id"].append(
                f"{filename}: {full_id}: defined as a heading {count} times — IDs must be unique"
            )


CATEGORY_LABELS = {
    "ambiguous_quantifier": "Ambiguous quantifiers / unmeasurable adjectives",
    "compound_requirement": "Likely compound requirements",
    "unmeasurable_nfr": "NFRs with no numeric target",
    "missing_acceptance_criteria": "FRs missing acceptance criteria",
    "orphan_no_stakeholder_trace": "Requirements with no stakeholder trace",
    "duplicate_id": "Duplicate ID definitions",
}


def lint_file(path: Path, findings):
    text = path.read_text(encoding="utf-8", errors="ignore")
    filename = str(path)
    blocks = split_into_requirement_blocks(text)
    all_ids = find_ids(text)

    check_ambiguous_terms(text, findings, filename)
    check_compound_requirements(blocks, findings, filename)
    check_unmeasurable_nfrs(blocks, findings, filename)
    check_missing_acceptance_criteria(blocks, findings, filename)
    check_orphan_trace(blocks, findings, filename)
    check_duplicate_definitions(text, findings, filename)


def main():
    ap = argparse.ArgumentParser(description="Lint requirements documents")
    ap.add_argument("path", help="Requirements file or directory")
    ap.add_argument("--fail-on-warn", action="store_true",
                     help="Exit non-zero if any finding at all is present")
    args = ap.parse_args()

    target = Path(args.path)
    files = [target] if target.is_file() else sorted(target.rglob("*.md"))

    if not files:
        print(f"No markdown files found at {target}")
        sys.exit(1)

    findings = defaultdict(list)
    for f in files:
        lint_file(f, findings)

    total = sum(len(v) for v in findings.values())

    print(f"Checked {len(files)} file(s).\n")
    if total == 0:
        print("No issues found. (Form-level check only — still run the Phase 8 review.)")
        sys.exit(0)

    for category, label in CATEGORY_LABELS.items():
        items = findings.get(category, [])
        if not items:
            continue
        print(f"\n== {label} ({len(items)}) ==")
        for item in items:
            print(f"  - {item}")

    print(f"\nTotal findings: {total}")
    print("Resolve or explicitly accept each before treating this phase as complete.")

    if args.fail_on_warn and total > 0:
        sys.exit(1)


if __name__ == "__main__":
    main()
