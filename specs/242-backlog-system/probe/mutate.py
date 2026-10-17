# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Negative controls of tools/backlog (feature 242): one mutation per copy of backlog.py,
then the unit tests must fail.  Usage: python specs/242-backlog-system/probe/mutate.py [name ...]
Expected: every mutant CAUGHT except first-link-wins (equivalent: escaping leaves one real link per row)."""
import shutil
import subprocess
import tempfile
import sys
from pathlib import Path

SRC = Path(__file__).resolve().parents[3] / "tools" / "backlog"
OUT = Path(tempfile.gettempdir()) / "tc242_mutants"

M = {
    "github-duplicate-off": ('if num in github_seen:', 'if False and num in github_seen:'),
    "updated-before-created-off": ('and h["updated"] < h["created"]:', 'and False:'),
    "decision-precedence-swapped": (
        '        if h.get("type") == "decision":\n            return SEC_DECISIONS\n        if h.get("who") == "person" or h.get("type") == "person-step":\n            return SEC_PERSON',
        '        if h.get("who") == "person" or h.get("type") == "person-step":\n            return SEC_PERSON\n        if h.get("type") == "decision":\n            return SEC_DECISIONS'),
    "log-date-order-off": ('if m.group(1) < last:', 'if False:'),
    "self-ref-off": ('if other == slug:', 'if False:'),
    "rejected-dependency-off": ('elif key == "depends-on" and items[other].ok', 'elif False and items[other].ok'),
    "remove-keeps-related": ('for key in LIST_KEYS:\n            if it.slug in other.list_of(key):',
                             'for key in ["depends-on"]:\n            if it.slug in other.list_of(key):'),
    "inbox-not-sorted": ('    if section not in ORDERED:\n        rows = sorted(', '    if False:\n        rows = sorted('),
    "steps-checklist-off": ("if not any(re.match(r\"^\\s*- \\[[ xX]\\] \", body[i]) for i in range(idx + 1, nxt)):", "if False:"),
    "title-line-check-off": ('if first is None or first[1] != "# " + title:', 'if first is None:'),
    "verified-format-off": ('if not m or not valid_date(m.group(1)):\n            bad("verified"', 'if False:\n            bad("verified"'),
    "start-ignores-eligibility": ('    reason = eligibility(bl, it)\n    if reason:\n        raise Refused(f"not eligible for a run: {reason}")', '    reason = None'),
    "remove-ignores-feature": ('if not args.force and (h["status"] != "in-progress" or h["feature"] != args.feature):', 'if False:'),
    "sync-ignores-duplicates": ('if listed.count(s) > 1:', 'if False:'),
    "next-reports-blocked-as-eligible": ('if h["status"] != "open":', 'if h["status"] not in ("open", "blocked"):'),
    "move-unblocks": ('    elif old_status == "blocked":\n        # moving never unblocks', '    elif False:\n        # moving never unblocks'),
    "import-dup-check-off": ('if it.ok and it.header.get("source") == f"github#{num}":', 'if False:'),
    "orphan-off": ('if slug not in seen:', 'if False:'),
    "lock-not-exclusive": ('fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)', 'fd = os.open(path, os.O_CREAT | os.O_WRONLY)'),
    "hand-row-dropped": ('        if not r.slug:\n            out.append(ov.lines[r.lineno - 1])\n            continue', '        if not r.slug:\n            continue'),
    "sync-ignores-row-findings": ('    if ov.errors:\n        raise Refused("BACKLOG.md has findings', '    if False:\n        raise Refused("BACKLOG.md has findings'),
    "one-line-off": ('    if CONTROL_RE.search(text or ""):\n        raise Refused', '    if False:\n        raise Refused'),
    "fence-off": ('if s.startswith("```") or s.startswith("~~~"):', 'if False:'),
    "first-link-wins": ('return found[-1] if found else None', 'return found[0] if found else None'),
    "validate-rejected-dep-off": ('elif key == "depends-on" and bl.items[s].ok', 'elif False and bl.items[s].ok'),
    "validate-cycle-off": ('        if it.slug in cyc:\n            errs.append', '        if False:\n            errs.append'),
    "close-in-progress-allowed": ('        if h["status"] == "in-progress":\n            raise Refused("an in-progress', '        if False:\n            raise Refused("an in-progress'),
    "comment-count-unchecked": ('if len(comments) != int(issue.get("comments") or 0):', 'if False:'),
    "single-page": ('        if len(batch) < 100:\n            return out', '        return out'),
    "verify-commit-unchecked": ('if not re.fullmatch(r"[0-9a-f]{7,40}", commit):', 'if False:'),
    "type-sections-not-added": ('    added = ensure_type_sections(it)', '    added = []'),
    "utf8-crash": ('    except UnicodeDecodeError as e:\n        item.errors.append', '    except ZeroDivisionError as e:\n        item.errors.append'),
}


def main():
    names = sys.argv[1:] or list(M)
    survived = []
    for name in names:
        old, new = M[name]
        d = OUT / name
        if d.exists():
            shutil.rmtree(d)
        shutil.copytree(SRC, d, ignore=shutil.ignore_patterns("__pycache__"))
        p = d / "backlog.py"
        text = p.read_text(encoding="utf-8")
        if text.count(old) != 1:
            print(f"{name}: PATTERN NOT FOUND ({text.count(old)})")
            continue
        p.write_text(text.replace(old, new), encoding="utf-8", newline="\n")
        res = subprocess.run([sys.executable, "-m", "unittest", "test_backlog.py"], cwd=d, capture_output=True, text=True)
        verdict = "CAUGHT" if res.returncode else "SURVIVED"
        if verdict == "SURVIVED":
            survived.append(name)
        print(f"{name}: {verdict}")
    print(f"{len(names) - len(survived)} caught, {len(survived)} survived: {survived}")


if __name__ == "__main__":
    main()
