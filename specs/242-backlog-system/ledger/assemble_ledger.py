#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Assemble specs/242-backlog-system/migration-ledger.md from the ledger parts (T033)."""

import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
PARTS = ["b-person-steps", "a-code-work", "c-decided", "d-github", "numbered-1", "numbered-2",
         "remaining-work", "consolidation"]
KINDS = [("item:", "item"), ("merged:", "merged"), ("see", "see"), ("release-checklist", "release-checklist"),
         ("done", "done"), ("not migrated", "not migrated")]

HEAD = """# Migration ledger (feature 242)

Every entry of the old sources (`specs/NEXT-WORK.md` at `7993914c` = NW, the
five `specs/*/REMAINING-WORK.md` = RW068…RW080) with its destination in
`backlog/`. Rules and destination forms: `ledger/README.md`. The parts below
are the per-agent ledgers, concatenated unchanged; *consolidation* records
the merges made afterwards (a removed item's rows say `merged:<kept>`).
`see …` rows point to the row of another part that carries the destination;
`release-checklist` rows are in `backlog/RELEASE.md`.
"""


def main():
    counts, body = {}, []
    for p in PARTS:
        text = (HERE / f"{p}.md").read_text(encoding="utf-8")
        for line in text.split("\n"):
            if not line.startswith("| ") or line.startswith("| Source") or re.match(r"^\|\s*-{3,}", line):
                continue
            cells = [c.strip() for c in re.split(r"(?<!\\)\|", line)[1:-1]]
            if len(cells) < 2:
                continue
            dest = cells[-1]
            kind = next((k for prefix, k in KINDS if dest.startswith(prefix)), "other")
            counts[kind] = counts.get(kind, 0) + 1
        content = text.split("\n", 1)[1] if text.startswith("#") else text
        body += ["", f"## Part: {p}", "", content.strip()]
    total = sum(counts.values())
    table = ["| Destination kind | Rows |", "|---|---|"]
    table += [f"| {k} | {v} |" for k, v in sorted(counts.items())] + [f"| **total** | **{total}** |"]
    (HERE.parent / "migration-ledger.md").write_text(HEAD + "\n" + "\n".join(table) + "\n" + "\n".join(body) + "\n",
                                                     encoding="utf-8")
    print(counts, total)


if __name__ == "__main__":
    main()
