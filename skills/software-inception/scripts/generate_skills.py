#!/usr/bin/env python3
"""
generate_skills.py — scaffold project-specific skills from inception artifacts.

This script proposes and scaffolds skills; it does not replace judgment.
It pulls structural hints (glossary terms, business rules, container names,
NFR categories) from the requirements and architecture documents and drafts
a SKILL.md skeleton for each candidate. A human or agent pass should still
review descriptions, prune skills that aren't worth maintaining, and fill in
any content the heuristics couldn't extract.

Usage:
  python generate_skills.py --requirements requirements.md \
                             --architecture architecture.md \
                             --out .claude/skills/
"""
import argparse
import re
from pathlib import Path

GLOSSARY_SECTION = re.compile(r"##\s*7?\.?\s*Glossary(.*?)(\n##\s|\Z)", re.IGNORECASE | re.DOTALL)
BUSINESS_RULES_SECTION = re.compile(r"##\s*\d*\.?\s*Business Rules(.*?)(\n##\s|\Z)", re.IGNORECASE | re.DOTALL)
CONTAINER_ROW = re.compile(r"\|\s*([A-Za-z0-9 _/-]+)\s*\|\s*([^|]+)\|\s*([^|]+)\|")
SECURITY_NFR = re.compile(r"NFR-\d+.*?(security|authentication|authorization|encryption|compliance|GDPR|PCI|HIPAA)", re.IGNORECASE)
API_MENTION = re.compile(r"\b(REST|GraphQL|external API|public API)\b", re.IGNORECASE)

SKILL_TEMPLATE = """---
name: {name}
description: {description}
---

# {title}

> Derived from: {source}. Review and refresh this whenever the source artifact changes.

{body}
"""


def read(path):
    return Path(path).read_text(encoding="utf-8", errors="ignore") if path and Path(path).exists() else ""


def slugify(name):
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def propose_domain_glossary(project, req_text, out_dir, requirements_path):
    glossary_match = GLOSSARY_SECTION.search(req_text)
    br_match = BUSINESS_RULES_SECTION.search(req_text)
    if not glossary_match and not br_match:
        return None
    body_parts = []
    if glossary_match:
        body_parts.append("## Glossary\n" + glossary_match.group(1).strip())
    if br_match:
        body_parts.append("## Business Rules\n" + br_match.group(1).strip())
    slug = f"{slugify(project)}-domain"
    write_skill(
        out_dir, slug,
        description=(
            f"Domain glossary and business rules for {project}. Use whenever writing, "
            f"reviewing, or discussing code that touches the core domain, to ensure "
            f"terminology and business logic match the agreed definitions."
        ),
        title=f"{project} — Domain",
        source=f"{requirements_path} (Glossary + Business Rules sections)",
        body="\n\n".join(body_parts),
    )
    return slug


def propose_component_skills(project, arch_text, out_dir, architecture_path):
    proposed = []
    for m in CONTAINER_ROW.finditer(arch_text):
        name, responsibility, tech = m.group(1).strip(), m.group(2).strip(), m.group(3).strip()
        if name.lower() in ("container", "responsibility", "technology", "---"):
            continue
        if len(name) < 2 or len(name) > 40:
            continue
        slug = f"{slugify(project)}-{slugify(name)}"
        write_skill(
            out_dir, slug,
            description=(
                f"Internals and integration contract for the {name} in {project}. "
                f"Use when implementing, debugging, or reviewing code inside this "
                f"component, or when another component needs to call it."
            ),
            title=f"{project} — {name}",
            source=f"{architecture_path} (Containers table)",
            body=f"**Responsibility:** {responsibility}\n\n**Technology:** {tech}\n\n"
                 f"<!-- Fill in: interface contract from the interface catalog, "
                 f"relevant ADRs, failure modes. -->",
        )
        proposed.append(slug)
    return proposed


def propose_security_skill(project, req_text, out_dir, requirements_path):
    hits = SECURITY_NFR.findall(req_text)
    if not hits:
        return None
    slug = f"{slugify(project)}-security"
    write_skill(
        out_dir, slug,
        description=(
            f"Security and compliance requirements for {project} — data classification, "
            f"auth model, and regulatory obligations. Use when handling sensitive data, "
            f"implementing auth/authz, or before shipping anything touching regulated data."
        ),
        title=f"{project} — Security & Compliance",
        source=f"{requirements_path} (Security-category NFRs)",
        body="<!-- Fill in: data classification, auth/authz model, regulatory "
             "obligations translated into concrete technical requirements. -->",
    )
    return slug


def propose_api_contract_skill(project, req_text, arch_text, out_dir, requirements_path):
    if not (API_MENTION.search(req_text) or API_MENTION.search(arch_text)):
        return None
    slug = f"{slugify(project)}-api-contract"
    write_skill(
        out_dir, slug,
        description=(
            f"External API contract for {project} — endpoints, request/response shapes, "
            f"error codes, idempotency, and versioning policy. Use when writing client "
            f"code against this API or reviewing endpoint implementations."
        ),
        title=f"{project} — API Contract",
        source=f"{requirements_path} / interface catalog",
        body="<!-- Fill in: endpoint list, shared error shape, idempotency requirements, "
             "versioning policy — pull directly from the Phase 6 interface catalog. -->",
    )
    return slug


def write_skill(out_dir, slug, description, title, source, body):
    skill_dir = Path(out_dir) / slug
    skill_dir.mkdir(parents=True, exist_ok=True)
    content = SKILL_TEMPLATE.format(
        name=slug, description=description.strip(), title=title, source=source, body=body.strip()
    )
    (skill_dir / "SKILL.md").write_text(content, encoding="utf-8")
    print(f"  drafted: {skill_dir / 'SKILL.md'}")


def main():
    ap = argparse.ArgumentParser(description="Draft project-specific skills from inception artifacts")
    ap.add_argument("--requirements", help="Path to requirements.md")
    ap.add_argument("--architecture", help="Path to architecture.md")
    ap.add_argument("--project", help="Project name (inferred from filename if omitted)")
    ap.add_argument("--out", required=True, help="Output directory for skills, e.g. .claude/skills/")
    args = ap.parse_args()

    req_text = read(args.requirements)
    arch_text = read(args.architecture)
    project = args.project or (Path(args.requirements).stem if args.requirements else "project")

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)

    print(f"Drafting candidate skills for '{project}' into {out_dir}\n")

    proposed = []
    if req_text:
        s = propose_domain_glossary(project, req_text, out_dir, args.requirements)
        if s:
            proposed.append(s)
    if arch_text:
        proposed += propose_component_skills(project, arch_text, out_dir, args.architecture)
    if req_text:
        s = propose_security_skill(project, req_text, out_dir, args.requirements)
        if s:
            proposed.append(s)
        s = propose_api_contract_skill(project, req_text, arch_text, out_dir, args.requirements)
        if s:
            proposed.append(s)

    if not proposed:
        print("No candidates found. If requirements/architecture files are non-empty, "
              "check that they follow the expected section headings "
              "(## Glossary, ## Business Rules, container tables with | Container | Responsibility | Technology |).")
        return

    print(f"\n{len(proposed)} skill(s) drafted: {', '.join(proposed)}")
    print("\nThese are drafts. Review each against references/09-skill-generation.md §1 "
          "before keeping it — prune anything that isn't worth maintaining, and sharpen "
          "each description per §5.")


if __name__ == "__main__":
    main()
