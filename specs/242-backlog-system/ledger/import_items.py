#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""One-off importer of the migrated items (feature 242, task T033).

Reads ledger/<part>.items.json of every migration part and creates the items
in backlog/ through the backlog tool's own model (tools/backlog/backlog.py):
the same header writer, the same value and body rules, the same overview
renderer and the full check at the end.  `backlog.py new` is not used
because migrated items carry their historical `created`, `verified` and log
entries, which `new` deliberately does not accept.

Order of rows: Next by severity (high first), then part, then the part's own
order; Decisions and Person steps by part, then order; Parked / Rejected are
sorted by the tool.  The maintainer re-orders at triage.

Usage (repository root):  python specs/242-backlog-system/ledger/import_items.py [--dry-run]
"""

import json
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / "tools" / "backlog"))
import backlog as B  # noqa: E402

PARTS = ["a-code-work", "d-github", "numbered-1", "numbered-2", "remaining-work", "consolidation", "b-person-steps", "c-decided"]
MIGRATION_DATE = "2026-10-17"
SECTION = {"next": B.SEC_NEXT, "decisions": B.SEC_DECISIONS, "person": B.SEC_PERSON,
           "parked": B.SEC_PARKED, "rejected": B.SEC_REJECTED}
PART_LABEL = {
    "a-code-work": "specs/NEXT-WORK.md §A (code work)",
    "b-person-steps": "specs/NEXT-WORK.md header and §B (person steps)",
    "c-decided": "specs/NEXT-WORK.md §C and 'Recorded, deliberately not on the list'",
    "d-github": "specs/NEXT-WORK.md §D (GitHub issues after 0.1.9)",
    "numbered-1": "specs/NEXT-WORK.md §R, §0–§4",
    "numbered-2": "specs/NEXT-WORK.md §5–§8",
    "remaining-work": "specs/*/REMAINING-WORK.md",
    "consolidation": "the consolidation of the migration parts",
}


def para(text) -> list:
    text = (text or "").strip()
    return text.split("\n") if text else ["(not stated in the source)"]


def body_for(d: dict, part: str) -> list:
    out = ["", f"# {d['title']}", "", "## Problem", "", *para(d.get("problem")), "",
           "## Evidence", "", *para(d.get("evidence")), "", "## Expected", "", *para(d.get("expected")), ""]
    if (d.get("approach") or "").strip():
        out += ["## Approach", "", *para(d["approach"]), ""]
    if (d.get("notes") or "").strip():
        out += ["## Notes", "", *para(d["notes"]), ""]
    if d["type"] == "decision":
        out += ["## Question", "", *para(d.get("question")), "",
                "## Options", "", *para(d.get("options")), "",
                "## Recommendation", "", *para(d.get("recommendation")), ""]
    if d["type"] == "person-step":
        steps = d.get("steps") or []
        out += ["## Steps", ""] + [s if s.lstrip().startswith("- [") else f"- [ ] {s}" for s in steps] + [""]
    log = sorted((e[0], e[1]) for e in (d.get("log") or []))
    log.append((MIGRATION_DATE, f"migrated from {PART_LABEL[part]} (feature 242)"))
    out += ["## Log", ""] + [f"- {date} {B.EMDASH} {text}" for date, text in log]
    return out


def main() -> int:
    dry = "--dry-run" in sys.argv
    bl = B.Backlog(ROOT)
    ov = bl.require_overview()
    records, problems = [], []
    seen = {}
    for pi, part in enumerate(PARTS):
        path = HERE / f"{part}.items.json"
        if not path.is_file():
            problems.append(f"{part}: {path.name} missing")
            continue
        for d in json.loads(path.read_text(encoding="utf-8")):
            slug = d["slug"]
            if slug in seen:
                problems.append(f"slug '{slug}' in {part} and {seen[slug]}")
                continue
            seen[slug] = part
            records.append((pi, part, d))
    # validate every record with the tool's rules before writing anything
    for pi, part, d in records:
        header = {
            "title": d["title"].strip(), "type": d["type"], "status": d["status"],
            "severity": str(d["severity"]), "area": d["area"], "source": d["source"],
            "who": d["who"], "created": d.get("created") or MIGRATION_DATE,
            "updated": max(MIGRATION_DATE, d.get("created") or MIGRATION_DATE),
            "verified": d.get("verified") or "-", "effort": d.get("effort") or "-",
            "feature": "-", "related": d.get("related") or [], "depends-on": d.get("depends-on") or [],
            "reason": (d.get("reason") or "-").strip() or "-",
        }
        it = B.Item(slug=d["slug"], folder=bl.items_dir / d["slug"], header=header, ok=True)
        it.header_lines = {k: 1 for k in B.HEADER_KEYS}
        it.body = body_for(d, part)
        it.body_start = len(B.HEADER_KEYS) + 3
        errs = [m for _, _, m in B.value_findings(it, ov, ROOT)] + [m for _, _, m in B.body_findings(it)]
        if not B.valid_slug(d["slug"]):
            errs.append("invalid slug")
        for key in B.LIST_KEYS:
            for s in it.list_of(key):
                if s not in seen:
                    errs.append(f"{key} '{s}' is not a migrated slug")
        exp = B.expected_section(it)
        if SECTION.get(d["section"]) != exp:
            errs.append(f"section '{d['section']}' does not fit (expected '{exp}')")
        if errs:
            problems.append(f"{part}/{d['slug']}: " + "; ".join(errs))
        d["_item"] = it
    if problems:
        print("\n".join(problems))
        print(f"REFUSED: {len(problems)} problem(s); nothing written")
        return 1
    print(f"{len(records)} items valid")
    if dry:
        return 0
    for _, _, d in records:
        bl.save_item(d["_item"])

    def key(rec):
        pi, _, d = rec
        sec = SECTION[d["section"]]
        if sec == B.SEC_NEXT:
            return (-int(d["severity"]), pi, d.get("order") or 0)
        return (pi, d.get("order") or 0)

    for name in (B.SEC_NEXT, B.SEC_DECISIONS, B.SEC_PERSON, B.SEC_PARKED, B.SEC_REJECTED):
        recs = sorted((r for r in records if SECTION[r[2]["section"]] == name), key=key)
        ov.sections[name].rows += [B.Row(slug=r[2]["slug"], cells=[], lineno=0) for r in recs]
    bl.load()
    bl.ov.sections = ov.sections  # keep the row lists built above
    bl.save_overview()
    findings = B.check(bl)
    B.print_findings(findings)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
