#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""One-off consolidation of the migration parts (feature 242, task T033).

Merges items that two parts made for the same work (MERGES: removed slug ->
kept slug): the removed item's texts are appended to the kept item's Notes,
its steps and log entries are added, the higher severity wins; every ledger
row that pointed to the removed slug now says merged:<kept>.  Also fixes
the circular `see` rows of the 072 audit (RW072 P0 <-> NW §6), whose items
are in consolidation.items.json, and appends the submission steps of the
audit to the submission item.  Idempotent: a second run changes nothing.
"""

import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
PARTS = ["a-code-work", "b-person-steps", "c-decided", "d-github", "numbered-1", "numbered-2", "remaining-work", "consolidation"]

MERGES = {
    "shellext-copy-hook-cuts-archive-target": "copy-hook-for-drag-out-of-archives",
    "sftp-container-person-rows": "sftp-test-container-rows-133",
    "plugin-defect-batch-131-rows": "plugin-batch-131-rows-needing-volume-or-file",
    "ftp-server-person-checks-infoline-short-names": "ftp-real-server-checks-090-116-121",
    "ftp-server-person-rows": "ftp-real-server-checks-090-116-121",
    "pictview-print-fit-and-own-photos-check": "pictview-own-photos-pipette-histogram-print",
    "pictview-thumbnail-refusal-message": "pictview-update-thumbnail-142-leftovers",
    "winget-pr-426090-follow-up": "winget-submit-release-after-pr-426090",
}

SUBMIT_STEPS = [
    "072 audit (072/REMAINING-WORK.md §P0): moderators ask for the CURRENT release - submit the newest tagged release, not 0.1.7 / 0.1.8",
    "072 audit §P0.1: 0.1.7 does not start without the Visual C++ runtime (fixed since 077) - another reason not to submit 0.1.7",
    "072 audit §P0.4: answer `Policy-Test-1.2` (not about the new code-signing certificate) with the waiver text prepared there",
    "072 audit 'Recommended plan': re-point #426090 to the current release; run the submission from `main`, never from a tag",
    "before submitting: the template fixes of `winget-manifest-fixes-from-072-audit` go in together",
]

RW072_FIX = {
    # ledger rows whose destination is the circular pointer -> the new items
    ('NW §6 "Read `072/REMAINING-WORK.md` § P0 before anything else here.', "see RW072 P0"):
        "item:winget-manifest-fixes-from-072-audit (with winget-records-stale-claims-from-072-audit and the steps of winget-submit-release-after-pr-426090; consolidation)",
}
RW072_ROWS = {
    "RW072 §P0.6": "item:winget-manifest-fixes-from-072-audit",
    "RW072 §P0.7": "item:winget-manifest-fixes-from-072-audit",
    "RW072 §P0.3": "item:winget-manifest-fixes-from-072-audit",
    "RW072 §P0.1": "merged:winget-submit-release-after-pr-426090",
    "RW072 §P0.2": "merged:winget-submit-release-after-pr-426090",
    "RW072 §P0.4": "merged:winget-submit-release-after-pr-426090",
    "RW072 §P0 \"Audit of": "item:winget-manifest-fixes-from-072-audit",
    "RW072 §P0 \"Recommended plan\" 1": "merged:winget-submit-release-after-pr-426090",
    "RW072 §P0 \"Recommended plan\" 2": "item:winget-manifest-fixes-from-072-audit",
    "RW072 §P0 \"Recommended plan\" 3": "item:winget-manifest-fixes-from-072-audit",
    "RW072 §P0 \"Recommended plan\" 4": "merged:winget-submit-release-after-pr-426090",
    "RW072 §P0 \"Repository record fixes\" — `CLAUDE.md`": "item:winget-records-stale-claims-from-072-audit",
    "RW072 §P0 \"Repository record fixes\" — `templates/": "item:winget-manifest-fixes-from-072-audit",
    "RW072 §P0 \"Repository record fixes\" — `fix-log.md`": "item:winget-records-stale-claims-from-072-audit",
    "RW072 §P0 \"Repository record fixes\" — `publish.ps1": "item:winget-records-stale-claims-from-072-audit",
}


def load(part):
    return json.loads((HERE / f"{part}.items.json").read_text(encoding="utf-8"))


def save(part, items):
    (HERE / f"{part}.items.json").write_text(json.dumps(items, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def main():
    data = {p: load(p) for p in PARTS}
    where = {d["slug"]: p for p, items in data.items() for d in items}
    by_slug = {d["slug"]: d for items in data.values() for d in items}
    for gone, kept in MERGES.items():
        if gone not in by_slug:
            continue  # already merged
        g, k = by_slug[gone], by_slug[kept]
        extra = (f"Merged from `{gone}` ({where[gone]} part): {g['title']}. "
                 f"Problem: {g.get('problem', '').strip()} Evidence: {g.get('evidence', '').strip()}"
                 + (f" Expected: {g['expected'].strip()}" if g.get("expected") else "")
                 + (f" Notes: {g['notes'].strip()}" if g.get("notes") else ""))
        k["notes"] = ((k.get("notes") or "").strip() + "\n\n" + extra).strip()
        k["severity"] = max(int(k["severity"]), int(g["severity"]))
        if k["type"] == "person-step":
            steps = list(k.get("steps") or [])
            for s in g.get("steps") or []:
                if s not in steps:
                    steps.append(s)
            if g["type"] != "person-step" and not g.get("steps"):
                steps.append(f"{g['title']} (merged from {gone})")
            k["steps"] = steps
        k["log"] = (k.get("log") or []) + [e for e in (g.get("log") or []) if e not in (k.get("log") or [])]
        data[where[gone]] = [d for d in data[where[gone]] if d["slug"] != gone]
        for items in data.values():
            for d in items:
                for key in ("related", "depends-on"):
                    lst = [kept if s == gone else s for s in d.get(key) or []]
                    d[key] = [s for i, s in enumerate(lst) if s != d["slug"] and s not in lst[:i]]
    submit = next(d for items in data.values() for d in items if d["slug"] == "winget-submit-release-after-pr-426090")
    for s in SUBMIT_STEPS:
        if s not in submit["steps"]:
            submit["steps"].append(s)
    for p, items in data.items():
        save(p, items)

    for md in sorted(HERE.glob("*.md")):
        if md.name == "README.md":
            continue
        text = md.read_text(encoding="utf-8")
        new = text
        for gone, kept in MERGES.items():
            new = re.sub(rf"\b(item|merged):{re.escape(gone)}\b", f"merged:{kept}", new)
        lines = new.split("\n")
        for i, ln in enumerate(lines):
            for (src, dest), repl in RW072_FIX.items():
                if src in ln and dest in ln:
                    lines[i] = ln[: ln.rindex("| " + dest)] + "| " + repl + " |"
            for label, repl in RW072_ROWS.items():
                if ln.startswith("| " + label) and "| see NW §6" in ln:
                    lines[i] = ln[: ln.index("| see NW §6")] + "| " + repl + " (consolidation; was: see NW §6) |"
        new = "\n".join(lines)
        if new != text:
            md.write_text(new, encoding="utf-8")
            print(f"ledger updated: {md.name}")
    print("items per part:", {p: len(v) for p, v in data.items()})


if __name__ == "__main__":
    main()
