# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Tests of tools/backlog/backlog.py (feature 242).

Run from the repository root:  python -m unittest tools/backlog/test_backlog.py -v

Every test works on a copy of fixtures/valid in a temporary folder.  The
seeded-defect cases (one per check rule, SC-004) are mutations of that copy,
listed in SEEDED below - each changes exactly one thing.
"""

import argparse
import contextlib
import io
import os
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import backlog  # noqa: E402

VALID = HERE / "fixtures" / "valid"
NOW = "2026-10-17T10:00:00"


def replace_once(path: Path, old: str, new: str) -> None:
    text = path.read_text(encoding="utf-8")
    assert text.count(old) >= 1, f"{old!r} not in {path}"
    path.write_text(text.replace(old, new, 1), encoding="utf-8", newline="\n")


def item(root: Path, slug: str) -> Path:
    return root / "backlog" / "items" / slug / "desc.md"


def overview(root: Path) -> Path:
    return root / "backlog" / "BACKLOG.md"


FTP = "ftp-per-server-encoding-flag"
DISK = "disk-map-context-menu-crash"


def _rename_folder(r):
    old = r / "backlog" / "items" / "help-footers-still-say-open-salamander"
    old.rename(old.with_name("Help_Footers"))


def _dup_row(r):
    p = overview(r)
    lines = p.read_text(encoding="utf-8").split("\n")
    i = next(k for k, ln in enumerate(lines) if f"items/{FTP}/" in ln)
    lines.insert(i + 1, lines[i])
    p.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def _drop_row(r):
    p = overview(r)
    lines = [ln for ln in p.read_text(encoding="utf-8").split("\n") if "items/help-footers" not in ln]
    p.write_text("\n".join(lines), encoding="utf-8", newline="\n")


# rule-id -> mutation of a copy of the valid fixture
SEEDED = {
    "layout": lambda r: (r / "backlog" / "stray.txt").write_text("x", encoding="utf-8"),
    "slug": _rename_folder,
    "desc-missing": lambda r: (r / "backlog" / "items" / "empty-item").mkdir(),
    "header": lambda r: replace_once(item(r, FTP), "who: agent\n", ""),
    "value": lambda r: replace_once(item(r, FTP), "severity: 3", "severity: 11"),
    "required": lambda r: replace_once(item(r, FTP), "reason: -", "reason: because"),
    "feature-missing": lambda r: shutil.rmtree(r / "specs" / "243-example"),
    "body": lambda r: replace_once(item(r, FTP), "## Evidence\n", ""),
    "ref": lambda r: replace_once(item(r, FTP), "related: [archive-pack-refuses-a-long-folder-silently]", "related: [no-such-item]"),
    "cycle": lambda r: replace_once(item(r, FTP), "depends-on: []", f"depends-on: [{DISK}]"),
    "github": lambda r: (r / "backlog" / "items" / "ship-network-plugin" / "issue.md").unlink(),
    "orphan": _drop_row,
    "dangling": lambda r: replace_once(overview(r), "| Item | Area | Reason |\n|---|---|---|\n", "| Item | Area | Reason |\n|---|---|---|\n| [Ghost](items/ghost/desc.md) | tooling | - |\n"),
    "duplicate": _dup_row,
    "section": lambda r: replace_once(item(r, FTP), "status: open", "status: new"),
    "derived": lambda r: replace_once(overview(r), "| improvement | 3 | ftp |", "| improvement | 9 | ftp |"),
    "overview": lambda r: replace_once(overview(r), "## Parked\n", ""),
    "runs": lambda r: replace_once(r / "backlog" / "RUNS.md", "| nothing-to-do |", "| exploded |"),
}


def _github_duplicate(r):
    replace_once(item(r, FTP), "source: leftover:224", "source: github#5")
    (r / "backlog" / "items" / FTP / "issue.md").write_text("number: 5\n", encoding="utf-8")


# further seeded defects: sub-rules of a rule (name -> (rule, mutation)),
# each one change; review-tool S15 showed these were not covered
SEEDED_MORE = {
    "github-duplicate": ("github", _github_duplicate),
    "updated-before-created": ("value", lambda r: replace_once(item(r, FTP), "updated: 2026-10-17", "updated: 2026-10-01")),
    "verified-format": ("value", lambda r: replace_once(item(r, FTP), "verified: -", "verified: yesterday")),
    "control-character": ("value", lambda r: replace_once(item(r, FTP), "title: FTP per-server", "title: FTP\tper-server")),
    "log-date-order": ("body", lambda r: replace_once(item(r, FTP), "(source leftover:224)\n", "(source leftover:224)\n- 2026-01-01 — earlier\n")),
    "title-line": ("body", lambda r: replace_once(item(r, FTP), "\n# FTP per-server encoding flag\n", "\n# Another title\n")),
    "steps-checklist": ("body", lambda r: replace_once(item(r, "release-0-1-10-person-checks"), "- [ ] (to be written)", "nothing yet")),
    "self-reference": ("ref", lambda r: replace_once(item(r, FTP), "related: [archive-pack-refuses-a-long-folder-silently]", f"related: [{FTP}]")),
    "rejected-dependency": ("ref", lambda r: replace_once(item(r, FTP), "depends-on: []", "depends-on: [b-2-systemic-comparison]")),
    "not-utf8": ("header", lambda r: item(r, FTP).write_bytes(item(r, FTP).read_text(encoding="utf-8").replace("FTP per-server", "Žluťoučký").encode("cp1250"))),
    "hand-written-row": ("overview", lambda r: replace_once(overview(r), "| Item | Area | Reason |\n|---|---|---|\n", "| Item | Area | Reason |\n|---|---|---|\n| a note by hand | - | - |\n")),
}


class Base(unittest.TestCase):
    def setUp(self):
        os.environ["TANDEM_BACKLOG_NOW"] = NOW
        self.tmp = Path(tempfile.mkdtemp(prefix="bl242-"))
        self.root = self.tmp / "repo"
        shutil.copytree(VALID, self.root)
        self.lock_dir = self.tmp / "lock"
        self.lock_dir.mkdir()

    def tearDown(self):
        os.environ.pop("TANDEM_BACKLOG_NOW", None)
        shutil.rmtree(self.tmp, ignore_errors=True)

    def run_tool(self, *args, stdin=None):
        buf = io.StringIO()
        saved = sys.stdin
        if stdin is not None:
            # a real text stream over bytes, as a pipe gives it (sys.stdin.buffer exists)
            sys.stdin = io.TextIOWrapper(io.BytesIO(stdin.encode("utf-8")), encoding="utf-8")
        try:
            with contextlib.redirect_stdout(buf), contextlib.redirect_stderr(io.StringIO()):
                code = backlog.main(["--root", str(self.root), "--lock-dir", str(self.lock_dir), *args])
        finally:
            sys.stdin = saved
        return code, buf.getvalue()

    def findings(self):
        return backlog.check(backlog.Backlog(self.root))

    def header(self, slug):
        return backlog.parse_item(self.root / "backlog" / "items" / slug).header

    def section_of(self, slug):
        return backlog.Backlog(self.root).ov.section_of(slug)


class CheckTests(Base):
    def test_valid_fixture_has_no_findings(self):
        self.assertEqual(self.findings(), [])
        code, out = self.run_tool("check")
        self.assertEqual(code, 0)
        self.assertIn("TOTAL: 0", out)

    def test_every_rule_is_detected(self):
        expected_rules = {
            "layout", "slug", "desc-missing", "header", "value", "required", "feature-missing",
            "body", "ref", "cycle", "github", "orphan", "dangling", "duplicate", "section",
            "derived", "overview", "runs",
        }
        self.assertEqual(set(SEEDED), expected_rules)
        for rule, mutate in SEEDED.items():
            with self.subTest(rule=rule):
                self.tearDown()
                self.setUp()
                mutate(self.root)
                rules = {f[2] for f in self.findings()}
                self.assertIn(rule, rules)
                code, out = self.run_tool("check")
                self.assertEqual(code, 1)
                self.assertIn(f": {rule}: ", out)

    def test_every_sub_rule_is_detected(self):
        for name, (rule, mutate) in SEEDED_MORE.items():
            with self.subTest(case=name):
                self.tearDown()
                self.setUp()
                mutate(self.root)
                self.assertIn(rule, {f[2] for f in self.findings()})

    def test_header_round_trip_is_byte_identical(self):
        for folder in (self.root / "backlog" / "items").iterdir():
            path = folder / "desc.md"
            it = backlog.parse_item(folder)
            self.assertTrue(it.ok, folder.name)
            self.assertEqual(backlog.render_item(it), path.read_text(encoding="utf-8"))

    def test_sync_is_idempotent(self):
        before = overview(self.root).read_text(encoding="utf-8")
        code, _ = self.run_tool("sync")
        self.assertEqual(code, 0)
        self.assertEqual(overview(self.root).read_text(encoding="utf-8"), before)

    def test_sync_restores_derived_cells(self):
        SEEDED["derived"](self.root)
        code, _ = self.run_tool("sync")
        self.assertEqual(code, 0)
        self.assertEqual(self.findings(), [])

    def test_sync_refuses_when_rows_and_items_differ(self):
        _drop_row(self.root)
        code, out = self.run_tool("sync")
        self.assertEqual(code, 1)
        self.assertIn("has no row", out)


class SlugTests(unittest.TestCase):
    def test_derivation(self):
        self.assertEqual(backlog.derive_slug("Žluťoučký kůň: test"), "zlutoucky-kun-test")
        self.assertEqual(backlog.derive_slug("  FTP -- per/server   flag!! "), "ftp-per-server-flag")
        self.assertEqual(backlog.derive_slug("!!!"), "")

    def test_long_title_cut_at_hyphen(self):
        slug = backlog.derive_slug("word " * 30)
        self.assertLessEqual(len(slug), backlog.SLUG_MAX)
        self.assertTrue(backlog.valid_slug(slug))
        self.assertFalse(slug.endswith("-"))
        self.assertTrue(all(part == "word" for part in slug.split("-")))


class NewAndListTests(Base):
    def test_new_goes_to_inbox(self):
        code, out = self.run_tool("new", "--title", "Ein neuer Fehler: Ä", "--type", "bug", "--severity", "5", "--area", "viewer")
        self.assertEqual(code, 0, out)
        self.assertEqual(out.split("\n")[0], "ein-neuer-fehler-a")
        self.assertEqual(self.section_of("ein-neuer-fehler-a")[0], "Inbox")
        h = self.header("ein-neuer-fehler-a")
        self.assertEqual((h["status"], h["source"], h["created"]), ("new", "manual", "2026-10-17"))

    def test_new_refuses_existing_slug(self):
        code, out = self.run_tool("new", "--title", "FTP per-server encoding flag", "--type", "bug", "--severity", "5", "--area", "ftp")
        self.assertEqual(code, 1)
        self.assertIn("already exists", out)
        self.assertIn(FTP, out)

    def test_new_refuses_title_without_slug(self):
        code, out = self.run_tool("new", "--title", "!!!", "--type", "bug", "--severity", "5", "--area", "ftp")
        self.assertEqual(code, 1)
        self.assertIn("pass --slug", out)

    def test_new_refuses_invalid_values_and_writes_nothing(self):
        code, out = self.run_tool("new", "--title", "Bad area", "--type", "bug", "--severity", "5", "--area", "nowhere")
        self.assertEqual(code, 1)
        self.assertFalse((self.root / "backlog" / "items" / "bad-area").exists())

    def test_list_order_and_filters(self):
        import json
        code, out = self.run_tool("list", "--json")
        self.assertEqual(code, 0)
        rows = json.loads(out)
        self.assertEqual([r["slug"] for r in rows][:3], ["archive-pack-refuses-a-long-folder-silently", DISK, FTP])
        code, out = self.run_tool("list", "--json", "--section", "next", "--min-severity", "5")
        self.assertEqual([r["slug"] for r in json.loads(out)], [DISK])


class MaintainTests(Base):
    def test_move_inbox_to_next_position(self):
        code, out = self.run_tool("move", "typed-path-with-a-pipe-brackets", "--section", "next", "--position", "2")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.section_of("typed-path-with-a-pipe-brackets"), ("Next", 1))
        self.assertEqual(self.header("typed-path-with-a-pipe-brackets")["status"], "open")
        self.assertIn(f"items/{FTP}/", [ln for ln in overview(self.root).read_text(encoding="utf-8").split("\n") if ln.startswith("| 3 |")][0])

    def test_move_to_parked_needs_reason(self):
        code, out = self.run_tool("move", FTP, "--section", "parked")
        self.assertEqual(code, 1)
        code, out = self.run_tool("move", FTP, "--section", "parked", "--reason", "not now")
        self.assertEqual(code, 0, out)
        h = self.header(FTP)
        self.assertEqual((h["status"], h["reason"]), ("parked", "not now"))

    def test_move_restores_orphan_row(self):
        # reference.md §6: an orphan item gets its row back by 'move'
        _drop_row(self.root)
        self.assertIn("orphan", {f[2] for f in self.findings()})
        code, out = self.run_tool("move", "help-footers-still-say-open-salamander", "--section", "parked",
                                  "--reason", "cosmetic, one mechanical pass when wanted")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.findings(), [])

    def test_move_to_in_progress_refused(self):
        code, out = self.run_tool("move", FTP, "--section", "in progress")
        self.assertEqual(code, 1)
        self.assertIn("start", out)

    def test_reopen_rejected_needs_reason_and_clears_it(self):
        slug = "b-2-systemic-comparison"
        code, _ = self.run_tool("move", slug, "--section", "next")
        self.assertEqual(code, 1)
        code, out = self.run_tool("move", slug, "--section", "next", "--reason", "new evidence")
        self.assertEqual(code, 0, out)
        h = self.header(slug)
        self.assertEqual((h["status"], h["reason"]), ("open", "-"))
        self.assertIn("reopened: new evidence", item(self.root, slug).read_text(encoding="utf-8"))

    def test_block_unblock(self):
        self.assertEqual(self.run_tool("block", FTP, "--reason", "waiting")[0], 0)
        self.assertEqual(self.header(FTP)["status"], "blocked")
        self.assertEqual(self.run_tool("unblock", FTP)[0], 0)
        h = self.header(FTP)
        self.assertEqual((h["status"], h["reason"]), ("open", "-"))

    def test_set_refuses_status_and_bad_values(self):
        self.assertEqual(self.run_tool("set", FTP, "status=open")[0], 1)
        self.assertEqual(self.run_tool("set", FTP, "severity=12")[0], 1)
        self.assertEqual(self.header(FTP)["severity"], "3")

    def test_set_title_keeps_slug(self):
        code, out = self.run_tool("set", FTP, "title=FTP encoding per server", "severity=4")
        self.assertEqual(code, 0, out)
        text = item(self.root, FTP).read_text(encoding="utf-8")
        self.assertIn("\n# FTP encoding per server\n", text)
        self.assertIn("title: FTP encoding per server", text)
        self.assertEqual(self.findings(), [])

    def test_set_type_relocates_row(self):
        code, out = self.run_tool("set", "ship-network-plugin", "type=feature")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.section_of("ship-network-plugin")[0], "Next")

    def test_verify_and_log(self):
        self.assertEqual(self.run_tool("verify", FTP, "--commit", "abcdef1", "--note", "still there")[0], 0)
        self.assertEqual(self.header(FTP)["verified"], "2026-10-17 abcdef1")
        self.assertEqual(self.run_tool("log", FTP, "a note")[0], 0)
        self.assertIn("- 2026-10-17 — a note", item(self.root, FTP).read_text(encoding="utf-8"))


class RunTests(Base):
    def test_next_skips_ineligible(self):
        code, out = self.run_tool("next")
        self.assertEqual(code, 0)
        self.assertIn(f"skipped: {DISK}: status blocked", out)
        self.assertTrue(out.strip().endswith(FTP))

    def test_next_depends_on_unmet(self):
        self.run_tool("unblock", DISK)
        code, out = self.run_tool("next")
        self.assertIn(f"skipped: {DISK}: depends-on {FTP}", out)

    def test_next_nothing_to_do_and_ineligible_slug(self):
        self.run_tool("block", FTP, "--reason", "x")
        code, out = self.run_tool("next")
        self.assertEqual((code, out.strip().split("\n")[-1]), (0, "nothing-to-do"))
        self.assertEqual(self.run_tool("next", "--slug", "ship-network-plugin")[0], 1)

    def test_start_and_remove(self):
        (self.root / "specs" / "244-ftp").mkdir()
        code, out = self.run_tool("start", FTP, "--feature", "244")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.section_of(FTP)[0], "In progress")
        self.assertEqual(self.run_tool("remove", FTP, "--feature", "245")[0], 1)
        code, out = self.run_tool("remove", FTP, "--feature", "244")
        self.assertEqual(code, 0, out)
        self.assertFalse((self.root / "backlog" / "items" / FTP).exists())
        self.assertEqual(self.header(DISK)["depends-on"], [])
        self.assertIn(f"dependency {FTP} done in feature 244", item(self.root, DISK).read_text(encoding="utf-8"))
        self.assertEqual(self.findings(), [])

    def test_run_log(self):
        code, out = self.run_tool("run-log", "--outcome", "closed", "--slug", FTP, "--feature", "244", "--branch", "244-x", "--inbox", "2")
        self.assertEqual(code, 0, out)
        self.assertIn("| 2026-10-17 10:00 | ftp-per-server-encoding-flag | closed | 244 | 244-x | 2 | - | - |",
                      (self.root / "backlog" / "RUNS.md").read_text(encoding="utf-8"))
        self.assertEqual(self.run_tool("run-log", "--outcome", "exploded")[0], 1)

    def test_lock(self):
        self.assertEqual(self.run_tool("lock", "status")[1].strip(), "free")
        self.assertEqual(self.run_tool("lock", "acquire", "--slug", FTP, "--branch", "244-x")[0], 0)
        code, out = self.run_tool("lock", "acquire", "--slug", "other")
        self.assertEqual(code, 1)
        self.assertIn(FTP, out)
        self.assertNotIn("STALE", out)
        os.environ["TANDEM_BACKLOG_NOW"] = "2026-10-18T11:00:00"
        self.assertIn("STALE", self.run_tool("lock", "status")[1])
        self.assertEqual(self.run_tool("lock", "release", "--slug", "other")[0], 1)
        self.assertEqual(self.run_tool("lock", "release", "--slug", FTP)[0], 0)
        self.assertEqual(self.run_tool("lock", "acquire")[0], 0)
        self.assertEqual(self.run_tool("lock", "release", "--force")[0], 0)
        self.assertEqual(self.run_tool("lock", "release", "--force")[0], 1)


class ReviewFixTests(Base):
    """Behaviour asked for by specs/242-backlog-system/review-tool.md (finding ids in the names)."""

    def test_m2_hand_written_row_kept_and_sync_refuses(self):
        SEEDED_MORE["hand-written-row"][1](self.root)
        self.assertEqual(self.run_tool("log", FTP, "touch")[0], 1)  # check after the change reports the row
        self.assertIn("| a note by hand | - | - |", overview(self.root).read_text(encoding="utf-8"))
        before = overview(self.root).stat().st_mtime_ns
        code, out = self.run_tool("sync")
        self.assertEqual(code, 1)
        self.assertTrue(out.startswith("refused:"), out)
        self.assertIn("row without an item link", out)
        self.assertEqual(overview(self.root).stat().st_mtime_ns, before)
        self.assertIn("| a note by hand | - | - |", overview(self.root).read_text(encoding="utf-8"))

    def test_s1_title_quoting_a_link_does_not_take_the_row(self):
        code, out = self.run_tool("new", "--title", f"Duplicate of (items/{FTP}/desc.md) here", "--slug", "quoting-a-link",
                                  "--type", "tech-debt", "--severity", "1", "--area", "tooling")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.run_tool("log", DISK, "touch")[0], 0)
        self.assertEqual(self.findings(), [])
        self.assertEqual(self.section_of("quoting-a-link")[0], "Inbox")

    def test_s2_line_breaks_refused_nothing_written(self):
        before = item(self.root, FTP).read_text(encoding="utf-8")
        self.assertEqual(self.run_tool("block", FTP, "--reason", "waiting\nsecond line")[0], 1)
        self.assertEqual(self.run_tool("set", FTP, "title=Two\nlines")[0], 1)
        self.assertEqual(item(self.root, FTP).read_text(encoding="utf-8"), before)
        code, _ = self.run_tool("new", "--title", "Two\nlines", "--type", "bug", "--severity", "1", "--area", "tooling")
        self.assertEqual(code, 1)
        self.assertFalse((self.root / "backlog" / "items" / "two-lines").exists())

    def test_s5_not_utf8_is_a_finding_not_a_crash(self):
        SEEDED_MORE["not-utf8"][1](self.root)
        code, out = self.run_tool("check")
        self.assertEqual(code, 1)
        self.assertIn("not valid UTF-8", out)
        self.assertIn("TOTAL:", out)

    def test_s6_headings_in_a_fence_are_text(self):
        replace_once(item(self.root, FTP), "## Expected\n", "```\n## Log\n- 2026-01-01 — quoted\n```\n\n## Expected\n")
        self.assertEqual(self.findings(), [])
        self.assertEqual(self.run_tool("log", FTP, "where does this go")[0], 0)
        text = item(self.root, FTP).read_text(encoding="utf-8")
        self.assertTrue(text.rstrip().endswith("— where does this go"))

    def test_s8_move_never_unblocks(self):
        code, out = self.run_tool("move", DISK, "--section", "next", "--position", "2", "--reason", "server available")
        self.assertEqual(code, 0, out)
        h = self.header(DISK)
        self.assertEqual((h["status"], h["reason"]), ("blocked", "needs a real mouse"))
        self.assertIn("still blocked: needs a real mouse", item(self.root, DISK).read_text(encoding="utf-8"))

    def test_s9_leaving_rejected_needs_a_reason_also_to_inbox(self):
        code, out = self.run_tool("move", "b-2-systemic-comparison", "--section", "inbox")
        self.assertEqual(code, 1)
        code, out = self.run_tool("move", "b-2-systemic-comparison", "--section", "inbox", "--reason", "new evidence")
        self.assertEqual(code, 0, out)
        text = item(self.root, "b-2-systemic-comparison").read_text(encoding="utf-8")
        self.assertIn("reopened: new evidence", text)
        self.assertNotIn("None", text)

    def test_s12_lock_update_records_the_branch(self):
        self.run_tool("lock", "acquire", "--slug", FTP)
        self.assertEqual(self.run_tool("lock", "update", "--slug", "other", "--branch", "x")[0], 1)
        self.assertEqual(self.run_tool("lock", "update", "--slug", FTP, "--branch", "244-ftp")[0], 0)
        self.assertIn("branch 244-ftp", self.run_tool("lock", "status")[1])

    def test_s14_close_without_a_feature(self):
        self.assertEqual(self.run_tool("remove", FTP)[0], 1)  # neither --feature nor --reason
        self.assertEqual(self.run_tool("remove", FTP, "--feature", "244", "--reason", "x")[0], 1)
        self.assertEqual(self.run_tool("remove", "archive-pack-refuses-a-long-folder-silently", "--reason", "x")[0], 1)
        code, out = self.run_tool("remove", FTP, "--reason", "fixed by feature 230")
        self.assertEqual(code, 0, out)
        self.assertFalse((self.root / "backlog" / "items" / FTP).exists())
        self.assertIn(f"dependency {FTP} closed: fixed by feature 230", item(self.root, DISK).read_text(encoding="utf-8"))
        self.assertEqual(self.findings(), [])

    def test_remove_cleans_related_too(self):
        code, out = self.run_tool("remove", "archive-pack-refuses-a-long-folder-silently", "--feature", "243")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.header(FTP)["related"], [])
        self.assertIn("related item archive-pack-refuses-a-long-folder-silently done in feature 243",
                      item(self.root, FTP).read_text(encoding="utf-8"))

    def test_n8_remove_with_a_read_only_file(self):
        note = self.root / "backlog" / "items" / DISK / "evidence" / "note.txt"
        os.chmod(note, 0o444)
        self.run_tool("unblock", DISK)
        self.run_tool("block", DISK, "--reason", "x")
        code, out = self.run_tool("remove", DISK, "--reason", "obsolete")
        self.assertEqual(code, 0, out)
        self.assertFalse(note.parent.parent.exists())

    def test_start_refuses_an_ineligible_item(self):
        self.assertEqual(self.run_tool("start", DISK, "--feature", "250")[0], 1)
        self.assertEqual(self.header(DISK)["status"], "blocked")

    def test_sync_refuses_duplicates(self):
        _dup_row(self.root)
        before = overview(self.root).stat().st_mtime_ns
        code, out = self.run_tool("sync")
        self.assertEqual(code, 1)
        self.assertTrue(out.startswith("refused:"), out)
        self.assertIn("more than once", out)
        self.assertEqual(overview(self.root).stat().st_mtime_ns, before)

    def test_decision_with_who_person_stays_in_decisions(self):
        code, out = self.run_tool("set", "ship-network-plugin", "who=person")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.section_of("ship-network-plugin")[0], "Decisions for the maintainer")

    def test_inbox_is_sorted_by_created(self):
        os.environ["TANDEM_BACKLOG_NOW"] = "2026-10-01T09:00:00"
        self.run_tool("new", "--title", "Older item", "--type", "bug", "--severity", "1", "--area", "tooling")
        text = overview(self.root).read_text(encoding="utf-8")
        older = text.index("items/older-item/")
        newer = text.index("items/typed-path-with-a-pipe-brackets/")
        self.assertLess(older, newer)

    def test_n5_next_unknown_slug_json(self):
        import json
        code, out = self.run_tool("next", "--slug", "no-such-item", "--json")
        self.assertEqual(code, 1)
        self.assertEqual(json.loads(out)["refused"], "no-such-item")

    def test_n6_validated_before_writing(self):
        before = item(self.root, FTP).read_text(encoding="utf-8")
        self.assertEqual(self.run_tool("verify", FTP, "--commit", "ABCDEF1")[0], 1)
        self.assertEqual(self.run_tool("set", FTP, "depends-on=b-2-systemic-comparison")[0], 1)
        self.assertEqual(self.run_tool("set", FTP, f"depends-on={DISK}")[0], 1)  # DISK depends on FTP: a cycle
        self.assertEqual(item(self.root, FTP).read_text(encoding="utf-8"), before)

    def test_n6_type_change_adds_its_sections(self):
        code, out = self.run_tool("set", FTP, "type=decision")
        self.assertEqual(code, 0, out)
        self.assertIn("## Question", item(self.root, FTP).read_text(encoding="utf-8"))
        self.assertEqual(self.section_of(FTP)[0], "Decisions for the maintainer")
        self.assertEqual(self.findings(), [])

    def test_list_needs_and_related_to(self):
        import json
        code, out = self.run_tool("list", "--needs", FTP, "--json")
        self.assertEqual([r["slug"] for r in json.loads(out)], [DISK])
        code, out = self.run_tool("list", "--related-to", "archive-pack-refuses-a-long-folder-silently", "--json")
        self.assertEqual([r["slug"] for r in json.loads(out)], [FTP])

    def test_position_below_one_refused(self):
        self.assertEqual(self.run_tool("move", "typed-path-with-a-pipe-brackets", "--section", "next", "--position", "0")[0], 1)

    def test_person_step_needs_who_person(self):
        code, out = self.run_tool("new", "--title", "A check by hand", "--type", "person-step", "--who", "agent",
                                  "--severity", "2", "--area", "tooling")
        self.assertEqual(code, 1)
        self.assertIn("who: person", out)

    def test_n9_title_ending_in_backslash(self):
        code, out = self.run_tool("new", "--title", "Ends with a backslash \\", "--slug", "ends-with-backslash",
                                  "--type", "bug", "--severity", "1", "--area", "tooling")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.findings(), [])
        self.assertEqual(self.section_of("ends-with-backslash")[0], "Inbox")


class ImportGithubTests(Base):
    def setUp(self):
        super().setUp()
        self.calls = []
        self.saved = backlog.fetch_json

        def fake(url):
            self.calls.append(url)
            if url.endswith("/issues/9"):
                return {"number": 9, "title": "Crash on F5 é", "body": "First para.\r\n\r\nSecond.",
                        "html_url": "https://github.com/x/9", "user": {"login": "rep"},
                        "created_at": "2026-10-10T08:00:00Z", "comments": 2}
            if "/issues/9/comments" in url:
                return [{"user": {"login": "a"}, "created_at": "2026-10-11T00:00:00Z", "body": "c1"},
                        {"user": {"login": "b"}, "created_at": "2026-10-12T00:00:00Z", "body": "c2"}]
            if url.endswith("/issues/10"):
                return {"number": 10, "title": "Many comments", "body": "## Describe the bug\nCopy crashes.\n\nMore.",
                        "html_url": "https://github.com/x/10", "user": {"login": "rep"},
                        "created_at": "2026-10-10T08:00:00Z", "comments": 105}
            if "/issues/10/comments" in url:
                page = int(url.rsplit("page=", 1)[1])
                n = 100 if page == 1 else 5 if page == 2 else 0
                return [{"user": {"login": f"u{page}-{i}"}, "created_at": "2026-10-11T00:00:00Z", "body": f"p{page}c{i}"}
                        for i in range(n)]
            if url.endswith("/issues/11"):
                return {"number": 11, "title": "Count differs", "body": "x", "html_url": "u", "comments": 3}
            if "/issues/11/comments" in url:
                return [{"user": {"login": "a"}, "body": "only one"}]
            raise backlog.urllib.error.URLError("offline")

        backlog.fetch_json = fake

    def tearDown(self):
        backlog.fetch_json = self.saved
        super().tearDown()

    def test_import_creates_item_with_issue_text(self):
        code, out = self.run_tool("import-github", "9", "--area", "file-ops")
        self.assertEqual(code, 0, out)
        slug = out.split("\n")[0]
        folder = self.root / "backlog" / "items" / slug
        issue = (folder / "issue.md").read_text(encoding="utf-8")
        self.assertTrue(issue.startswith("number: 9\n"))
        self.assertIn("First para.\n\nSecond.", issue)
        self.assertIn("### b, 2026-10-12", issue)
        self.assertTrue((folder / "reply.md").read_text(encoding="utf-8").startswith("state: not-sent"))
        h = self.header(slug)
        self.assertEqual((h["source"], h["status"], h["title"]), ("github#9", "new", "Crash on F5 é"))
        self.assertEqual(self.findings(), [])

    def test_all_comment_pages_and_heading_body(self):
        code, out = self.run_tool("import-github", "10", "--area", "file-ops")
        self.assertEqual(code, 0, out)
        slug = out.split("\n")[0]
        issue = (self.root / "backlog" / "items" / slug / "issue.md").read_text(encoding="utf-8")
        self.assertIn("p2c4", issue)
        self.assertEqual(issue.count("\n### "), 105)
        self.assertIn("> Copy crashes.", item(self.root, slug).read_text(encoding="utf-8"))
        self.assertEqual(self.findings(), [])

    def test_comment_count_mismatch_refused(self):
        code, out = self.run_tool("import-github", "11", "--area", "file-ops")
        self.assertEqual(code, 1)
        self.assertIn("comments", out)
        self.assertFalse((self.root / "backlog" / "items" / "count-differs").exists())

    def test_second_import_refused(self):
        self.run_tool("import-github", "9", "--area", "file-ops")
        code, out = self.run_tool("import-github", "9", "--area", "file-ops")
        self.assertEqual(code, 1)
        self.assertIn("already imported", out)

    def test_already_imported_via_fixture(self):
        code, out = self.run_tool("import-github", "5", "--area", "file-ops")
        self.assertEqual(code, 1)
        self.assertIn("ship-network-plugin", out)

    def test_network_error_writes_nothing(self):
        before = sorted(p.name for p in (self.root / "backlog" / "items").iterdir())
        code, out = self.run_tool("import-github", "77", "--area", "file-ops")
        self.assertEqual(code, 1)
        self.assertIn("cannot read issue", out)
        self.assertEqual(sorted(p.name for p in (self.root / "backlog" / "items").iterdir()), before)


def _issue(num, title, labels, comments=0, **extra):
    return {"number": num, "title": title, "body": f"Body of {num}.", "html_url": f"https://github.com/x/{num}",
            "user": {"login": "rep"}, "created_at": "2026-10-10T08:00:00Z", "comments": comments,
            "labels": [{"name": n} for n in labels], **extra}


class ImportLabelledTests(Base):
    LIST = [
        _issue(25, "Paste fails in a folder with an exclamation mark", ["bug", "ai backlog"]),
        _issue(5, "Already in the backlog", ["bug", "ai backlog"]),
        _issue(20, "A pull request", ["ai backlog"], pull_request={}),
        _issue(21, "Fixed already", ["bug", "ai backlog", "fixed"]),
        _issue(22, "Paste fails in a folder with an exclamation mark", ["bug", "ai backlog"], comments=1),
        _issue(23, "Compare folders by content", ["enhancement", "ai backlog"]),
        _issue(24, "Explain the plug-in list", ["documentation", "ai backlog"]),
    ]

    def setUp(self):
        super().setUp()
        self.calls = []
        self.saved = backlog.fetch_json

        def fake(url):
            self.calls.append(url)
            if "/issues?" in url:
                return list(self.LIST) if url.endswith("page=1") else []
            if "/issues/22/comments" in url:
                return [{"user": {"login": "a"}, "created_at": "2026-10-11T00:00:00Z", "body": "me too"}]
            if url.endswith("/issues/23"):
                return self.LIST[5]
            raise backlog.urllib.error.URLError("offline")

        backlog.fetch_json = fake

    def tearDown(self):
        backlog.fetch_json = self.saved
        super().tearDown()

    def items(self):
        return sorted(p.name for p in (self.root / "backlog" / "items").iterdir())

    def test_list_request_is_open_issues_with_the_label(self):
        self.run_tool("import-github", "--label", "ai backlog", "--dry-run")
        self.assertIn("/issues?state=open&labels=ai%20backlog&per_page=100&page=1", self.calls[0])

    def test_dry_run_writes_nothing(self):
        before = self.items()
        code, out = self.run_tool("import-github", "--label", "ai backlog", "--dry-run")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.items(), before)
        self.assertIn("would import #23 [enhancement, ai backlog] as feature, panels-ui", out)
        self.assertIn("would import #24 [documentation, ai backlog] as improvement, help-docs", out)
        self.assertIn("skipped #5: already imported as 'ship-network-plugin'", out)
        self.assertTrue(out.rstrip().endswith("would import 4, skipped 3, failed 0"))

    def test_import_skips_and_types_from_labels(self):
        code, out = self.run_tool("import-github", "--label", "ai backlog")
        self.assertEqual(code, 1, out)  # #25 has the title of #22: its slug exists
        self.assertIn("skipped #20: a pull request", out)
        self.assertIn("skipped #21: labelled fixed", out)
        self.assertIn("failed #25: item 'paste-fails-in-a-folder-with-an-exclamation-mark' already exists", out)
        self.assertIn("imported 3, skipped 3, failed 1", out)
        got = {ln.split()[1]: ln.split()[2] for ln in out.split("\n") if ln.startswith("imported #")}
        self.assertEqual(sorted(got), ["#22", "#23", "#24"])
        h = {n: self.header(s) for n, s in got.items()}
        self.assertEqual((h["#22"]["type"], h["#22"]["area"], h["#22"]["source"], h["#22"]["status"]),
                         ("bug", "panels-ui", "github#22", "new"))
        self.assertEqual((h["#23"]["type"], h["#24"]["type"], h["#24"]["area"]), ("feature", "improvement", "help-docs"))
        issue = (self.root / "backlog" / "items" / got["#22"] / "issue.md").read_text(encoding="utf-8")
        self.assertIn("\nlabels: bug, ai backlog\n", issue)
        self.assertIn("me too", issue)
        self.assertEqual(self.findings(), [])
        code, out = self.run_tool("import-github", "--label", "ai backlog", "--dry-run")
        self.assertIn("skipped #22: already imported as", out)

    def test_issue_removed_earlier_is_not_imported_again(self):
        if not shutil.which("git"):
            self.skipTest("git not installed")
        import subprocess

        def g(*a):
            subprocess.run(["git", "-C", str(self.root), "-c", "user.name=t", "-c", "user.email=t@t", *a],
                           check=True, capture_output=True)
        g("init", "-q")
        g("add", "-A")
        g("commit", "-q", "-m", "fixture")
        code, out = self.run_tool("import-github", "23", "--area", "panels-ui")
        self.assertEqual(code, 0, out)
        slug = out.split("\n")[0]
        g("add", "-A")
        g("commit", "-q", "-m", "import")
        code, out = self.run_tool("remove", slug, "--reason", "fixed by feature 244; maintainer 2026-10-17")
        self.assertEqual(code, 0, out)
        g("add", "-A")
        g("commit", "-q", "-m", "closed")
        code, out = self.run_tool("import-github", "--label", "ai backlog", "--dry-run")
        self.assertRegex(out, r"skipped #23: imported before; its item left the backlog \(commit [0-9a-f]{7,}\)")

    def test_repository_without_commits_has_no_history(self):
        if not shutil.which("git"):
            self.skipTest("git not installed")
        import subprocess
        subprocess.run(["git", "-C", str(self.root), "init", "-q"], check=True, capture_output=True)
        code, out = self.run_tool("import-github", "--label", "ai backlog", "--dry-run")
        self.assertEqual(code, 0, out)
        self.assertIn("would import #23", out)

    def test_broken_read_of_one_issue_fails_only_that_issue(self):
        fake = backlog.fetch_json

        def broken(url):
            if "/issues/22/comments" in url:
                raise backlog.http.client.IncompleteRead(b"")
            return fake(url)

        backlog.fetch_json = broken
        code, out = self.run_tool("import-github", "--label", "ai backlog")
        self.assertEqual(code, 1, out)
        self.assertIn("failed #22: cannot read the comments of issue #22", out)
        self.assertIn("imported #23 ", out)
        self.assertIn("imported 3, skipped 3, failed 1", out)  # #25 takes the slug #22 did not
        self.assertEqual(self.findings(), [])

    def test_invalid_values_refused_before_github_is_asked(self):
        for args in (["--area", "bogus"], ["--severity", "42"]):
            code, out = self.run_tool("import-github", "--label", "ai backlog", "--dry-run", *args)
            self.assertEqual(code, 1, args)
            self.assertTrue(out.startswith("refused: invalid values"), out)
        self.assertEqual(self.calls, [])

    def test_single_number_takes_type_from_labels(self):
        code, out = self.run_tool("import-github", "23", "--area", "panels-ui")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.header(out.split("\n")[0])["type"], "feature")

    def test_argument_combinations_refused(self):
        for args in (["import-github", "--area", "panels-ui"],
                     ["import-github", "23", "--label", "ai backlog"],
                     ["import-github", "23"],
                     ["import-github", "23", "--area", "panels-ui", "--dry-run"],
                     ["import-github", "--label", "ai backlog", "--slug", "x"]):
            code, out = self.run_tool(*args)
            self.assertEqual(code, 1, args)
            self.assertTrue(out.startswith("refused:"), out)
        self.assertEqual(self.calls, [])

    def test_list_error_writes_nothing(self):
        backlog.fetch_json = lambda url: (_ for _ in ()).throw(backlog.urllib.error.URLError("offline"))
        before = self.items()
        code, out = self.run_tool("import-github", "--label", "ai backlog")
        self.assertEqual(code, 1)
        self.assertIn("cannot list the issues labelled 'ai backlog'", out)
        self.assertEqual(self.items(), before)


# ---------------------------------------------------------------------------
# Feature 344: read commands with JSON, --ref, --input-json, --json results,
# reorder, set --position, body, step, decide, reply
# (specs/344-backlog-web-app/contracts/backlog-cli-additions.md)

import hashlib  # noqa: E402
import json  # noqa: E402

PERSON = "release-0-1-10-person-checks"
DECISION = "ship-network-plugin"
INBOX = "typed-path-with-a-pipe-brackets"
ARCHIVE = "archive-pack-refuses-a-long-folder-silently"
RESULT_KEYS = ["ok", "refused", "slugs", "section", "position", "notices", "findings", "written"]
# the text a web app sends: shell syntax, quotes, backslashes, Czech letters, many lines
NASTY = ("Backticks `rm -rf /` and $(rm -rf x) and ${HOME} and 'single' \"double\" quotes;\n"
         "back\\slash \\\\server\\share\\ and a tab\there; Žluťoučký kůň úpěl ďábelské ódy.\n"
         "    indented code line\n"
         "> a quote | with a pipe [and brackets](not/a/link)\n")


def tree_bytes(root: Path) -> dict:
    return {p.relative_to(root).as_posix(): p.read_bytes() for p in root.rglob("*")
            if p.is_file() and ".git" not in p.relative_to(root).parts}


def changed_paths(before: dict, after: dict) -> set:
    return {k for k in set(before) | set(after) if before.get(k) != after.get(k)}


class F344(Base):
    def run_json(self, *args, stdin=None):
        code, out = self.run_tool(*args, stdin=stdin)
        try:
            return code, json.loads(out)
        except ValueError:
            self.fail(f"not one JSON object (exit {code}): {out!r}")

    def assert_result(self, obj):
        self.assertEqual(list(obj), RESULT_KEYS)


class BoardJsonTests(F344):
    def test_board_sections_rows_and_revision(self):
        code, b = self.run_json("board", "--json")
        self.assertEqual(code, 0)
        self.assertEqual(b["revision"], hashlib.sha256(overview(self.root).read_bytes()).hexdigest())
        self.assertEqual(b["last_triaged"], "2026-10-17")
        self.assertEqual([s["name"] for s in b["sections"]], backlog.SECTIONS)
        self.assertEqual([s["ordered"] for s in b["sections"]], [True, True, True, True, False, False, False])
        nxt = b["sections"][1]["rows"]
        self.assertEqual([(r["position"], r["slug"]) for r in nxt], [(1, DISK), (2, FTP)])
        self.assertEqual(nxt[0]["title"], "Disk Map context menu crash")
        self.assertIs(type(nxt[0]["severity"]), int)
        self.assertEqual(nxt[0]["severity"], 8)
        self.assertEqual(nxt[0]["depends-on"], [FTP])
        self.assertIsNone(nxt[1]["verified"])
        self.assertIsNone(nxt[1]["reason"])
        inbox = b["sections"][4]["rows"]
        self.assertEqual(inbox[0]["title"], "Typed path with a | pipe [brackets]")
        self.assertIsNone(inbox[0]["position"])
        self.assertEqual(b["unreadable"], [])
        self.assertNotIn("body", nxt[0])

    def test_note_rows_and_unreadable_items(self):
        SEEDED_MORE["hand-written-row"][1](self.root)
        SEEDED["header"](self.root)  # FTP loses 'who'
        code, b = self.run_json("board", "--json")
        self.assertEqual(code, 0)
        self.assertEqual(b["sections"][5]["rows"][0], {"note": "| a note by hand | - | - |"})  # Parked, file order
        self.assertEqual([u["slug"] for u in b["unreadable"]], [FTP])
        self.assertEqual(b["unreadable"][0]["path"], f"backlog/items/{FTP}/desc.md")
        self.assertIn("missing keys", b["unreadable"][0]["finding"])
        row = b["sections"][1]["rows"][1]
        self.assertEqual((row["position"], row["slug"], row["title"]), (2, FTP, None))

    def test_with_body_adds_body_and_issue(self):
        code, b = self.run_json("board", "--json", "--with-body")
        self.assertEqual(code, 0)
        rows = {r["slug"]: r for s in b["sections"] for r in s["rows"]}
        text = item(self.root, FTP).read_text(encoding="utf-8")
        self.assertEqual(rows[FTP]["body"], text.split("\n---\n", 1)[1])
        self.assertIsNone(rows[FTP]["issue"])
        issue = (self.root / "backlog" / "items" / DECISION / "issue.md").read_text(encoding="utf-8")
        self.assertEqual(rows[DECISION]["issue"], issue)

    def test_board_text(self):
        code, out = self.run_tool("board")
        self.assertEqual(code, 0)
        self.assertIn(FTP, out)


class ShowJsonTests(F344):
    def test_every_field(self):
        code, s = self.run_json("show", FTP, "--json")
        self.assertEqual(code, 0)
        self.assertEqual(s["slug"], FTP)
        self.assertEqual(s["revision"], hashlib.sha256(item(self.root, FTP).read_bytes()).hexdigest())
        for key in backlog.HEADER_KEYS:
            self.assertIn(key, s)
        self.assertEqual((s["severity"], s["verified"], s["effort"], s["feature"], s["reason"]), (3, None, None, None, None))
        self.assertEqual((s["related"], s["depends-on"]), ([ARCHIVE], []))
        self.assertEqual((s["section"], s["position"]), ("Next", 2))
        self.assertEqual([b["name"] for b in s["body"]], ["Problem", "Evidence", "Expected", "Log"])
        self.assertEqual(s["body"][0]["markdown"], "(to be written)")
        self.assertEqual(s["log"], [{"date": "2026-10-17", "text": "created (source leftover:224)"},
                                    {"date": "2026-10-17", "text": "moved to Next"}])
        self.assertEqual((s["steps"], s["options"]), ([], []))
        self.assertEqual(s["files"], {"issue": None, "reply": None, "evidence": []})
        self.assertEqual(s["dependents"], [DISK])
        self.assertEqual(s["findings"], [])
        self.assertEqual(s["eligibility"], {"eligible": True, "reason": None})

    def test_files_eligibility_and_steps(self):
        s = self.run_json("show", DISK, "--json")[1]
        self.assertEqual(s["eligibility"], {"eligible": False, "reason": "status blocked"})
        self.assertEqual(s["files"]["evidence"], ["note.txt"])
        s = self.run_json("show", DECISION, "--json")[1]
        self.assertEqual(s["files"]["issue"]["number"], 5)
        self.assertEqual(s["files"]["issue"]["head"]["author"], "someone")
        self.assertEqual(s["files"]["reply"], {"state": "not-sent"})
        self.assertEqual(s["section"], "Decisions for the maintainer")
        replace_once(item(self.root, PERSON), "- [ ] (to be written)", "- [x] build it\n- [ ] sign it\n  more words")
        s = self.run_json("show", PERSON, "--json")[1]
        self.assertEqual(s["steps"], [{"index": 1, "done": True, "text": "build it"},
                                      {"index": 2, "done": False, "text": "sign it"}])

    def test_options_forms(self):
        replace_once(item(self.root, DECISION), "## Options\n\n(to be written)",
                     "## Options\n\nIntro text.\n\n### A - keep it\n\nSome text.\n\n- **B - drop it.** Cheaper.\n  continued\n"
                     "- C - something else\n- **D**: last")
        s = self.run_json("show", DECISION, "--json")[1]
        self.assertEqual([o["key"] for o in s["options"]], ["A", "B", "C", "D"])
        self.assertEqual(s["options"][0]["text"], "A - keep it\n\nSome text.")
        self.assertEqual(s["options"][1]["text"], "**B - drop it.** Cheaper.\n  continued")

    def test_unknown_slug_and_own_findings(self):
        code, out = self.run_tool("show", "no-such-item", "--json")
        self.assertEqual((code, out.strip()), (1, "refused: no item 'no-such-item'"))
        SEEDED["value"](self.root)  # FTP severity 11
        s = self.run_json("show", FTP, "--json")[1]
        self.assertIsNone(s["severity"])
        self.assertIn("value", {f["rule"] for f in s["findings"]})
        self.assertTrue(all(set(f) == {"path", "line", "rule", "message"} for f in s["findings"]))
        self.assertEqual(self.run_json("show", DISK, "--json")[1]["findings"], [])


class CheckLegendJsonTests(F344):
    def test_check_json(self):
        self.assertEqual(self.run_json("check", "--json"), (0, {"total": 0, "findings": []}))
        SEEDED["runs"](self.root)
        code, c = self.run_json("check", "--json")
        self.assertEqual(code, 1)
        self.assertEqual(c["total"], len(c["findings"]))
        self.assertEqual(c["findings"][0]["rule"], "runs")
        self.assertEqual(self.run_json("--json", "check")[0], 1)  # the global form

    def test_legend_json(self):
        code, lg = self.run_json("legend", "--json")
        self.assertEqual(code, 0)
        self.assertEqual(list(lg), ["types", "statuses", "areas", "who", "efforts", "sources", "severity"])
        self.assertEqual([t["value"] for t in lg["types"]][:2], ["bug", "feature"])
        self.assertEqual(lg["types"][0]["meaning"], "the program does something wrong")
        self.assertEqual(len(lg["areas"]), 18)
        self.assertEqual([e["value"] for e in lg["efforts"]], ["S", "M", "L", "?"])
        self.assertEqual(lg["sources"][1], {"form": "github#N", "meaning": "GitHub issue N (`issue.md` holds its text)"})
        self.assertEqual([s["range"] for s in lg["severity"]], ["9–10", "7–8", "4–6", "1–3", "0"])
        self.assertEqual(self.run_tool("legend")[0], 0)


class RefTests(F344):
    def setUp(self):
        super().setUp()
        if not shutil.which("git"):
            self.skipTest("git not installed")

        def g(*a):
            subprocess.run(["git", "-C", str(self.root), "-c", "user.name=t", "-c", "user.email=t@t",
                            "-c", "core.autocrlf=false", *a], check=True, capture_output=True)
        # LF in the tree as in the objects, so that a revision (hash of the bytes) is the same in both
        for path in self.root.rglob("*"):
            if path.is_file():
                path.write_bytes(path.read_bytes().replace(b"\r\n", b"\n"))
        g("init", "-q")
        g("symbolic-ref", "HEAD", "refs/heads/main")
        g("add", "-A")
        g("commit", "-q", "-m", "fixture")
        self.reads = [("board", "--json", "--with-body"), ("list", "--json"), ("show", DISK, "--json"),
                      ("next", "--json"), ("legend", "--json"), ("show", DECISION, "--json")]
        self.expected = [self.run_tool(*r) for r in self.reads]
        # the working tree moves on: a run's branch state, an edited legend
        self.assertEqual(self.run_tool("move", FTP, "--section", "parked", "--reason", "later")[0], 0)
        replace_once(overview(self.root), "| `tooling` |", "| `tools` |")
        replace_once(item(self.root, DISK), "## Problem\n", "## Problem\n\nchanged in the tree\n")

    def test_read_commands_give_the_ref(self):
        self.assertNotEqual(self.run_tool(*self.reads[0]), self.expected[0])  # the tree differs
        for r, want in zip(self.reads, self.expected):
            with self.subTest(r=r):
                self.assertEqual(self.run_tool(*r, "--ref", "main"), want)
        self.assertEqual(self.run_tool("--ref", "main", "board", "--json", "--with-body"), self.expected[0])

    def test_no_working_tree_file_is_opened(self):
        shutil.rmtree(self.root / "backlog")  # gone from the tree, present in the commit
        for r, want in zip(self.reads, self.expected):
            self.assertEqual(self.run_tool(*r, "--ref", "main"), want, r)

    @unittest.skipUnless(os.name == "nt", "a byte-range lock is a Windows test")
    def test_a_locked_working_tree_file_does_not_matter(self):
        import msvcrt
        path = overview(self.root)
        with open(path, "r+b") as f:
            msvcrt.locking(f.fileno(), msvcrt.LK_NBLCK, path.stat().st_size)
            try:
                with self.assertRaises(PermissionError):  # negative control: the tree is unreadable
                    self.run_tool("board", "--json")
                self.assertEqual(self.run_tool("board", "--json", "--with-body", "--ref", "main"), self.expected[0])
            finally:
                f.seek(0)
                msvcrt.locking(f.fileno(), msvcrt.LK_UNLCK, path.stat().st_size)

    def test_ref_refused_for_changing_commands_and_check(self):
        before = tree_bytes(self.root)
        for args in (["check", "--ref", "main"], ["--ref", "main", "check"], ["--ref", "main", "log", FTP, "x"],
                     ["--ref", "main", "move", INBOX, "--section", "next"], ["sync", "--ref", "main"]):
            self.assertEqual(self.run_tool(*args)[0], 2, args)
        self.assertEqual(tree_bytes(self.root), before)

    def test_unknown_ref_refused(self):
        code, out = self.run_tool("board", "--json", "--ref", "no-such-branch")
        self.assertEqual(code, 1)
        self.assertTrue(out.startswith("refused:"), out)


class InputJsonTests(F344):
    def test_new_takes_every_text_field(self):
        data = {"title": "Ünïcode title from JSON", "problem": NASTY, "evidence": "ev", "expected": "exp",
                "approach": "appr", "notes": "nts", "question": "q?", "options": "- A - one", "recommendation": "A",
                "steps": "- [ ] a step"}
        code, out = self.run_tool("--input-json", "-", "new", "--type", "bug", "--severity", "5", "--area", "viewer",
                                  stdin=json.dumps(data))
        self.assertEqual(code, 0, out)
        slug = out.split("\n")[0]
        s = self.run_json("show", slug, "--json")[1]
        self.assertEqual(s["title"], data["title"])
        got = {b["name"]: b["markdown"] for b in s["body"]}
        self.assertEqual(list(got), backlog.KNOWN_HEADINGS)
        self.assertEqual(got["Problem"], NASTY.rstrip("\n"))
        self.assertEqual((got["Approach"], got["Notes"], got["Steps"]), ("appr", "nts", "- [ ] a step"))
        self.assertEqual(self.findings(), [])

    def test_twenty_thousand_characters_round_trip_byte_exact(self):
        text = (NASTY * 100)[:20000].rstrip("\n ") + " end"
        self.assertGreaterEqual(len(text), 19990)
        data = json.dumps({"title": "Long problem", "problem": text})
        code, out = self.run_tool("--input-json", "-", "new", "--type", "bug", "--severity", "5", "--area", "viewer", stdin=data)
        self.assertEqual(code, 0, out)
        s = self.run_json("show", "long-problem", "--json")[1]
        self.assertEqual(s["body"][0]["markdown"], text)
        self.assertIn(text.encode("utf-8"), item(self.root, "long-problem").read_bytes())

    def test_round_trip_through_a_real_pipe(self):
        text = NASTY * 3 + "last line"
        env = dict(os.environ, TANDEM_BACKLOG_NOW=NOW, PYTHONIOENCODING="cp1250")  # a hostile console encoding
        tool = str(HERE / "backlog.py")
        r = subprocess.run([sys.executable, tool, "--root", str(self.root), "--input-json", "-", "new", "--type", "bug",
                            "--severity", "5", "--area", "viewer", "--json"],
                           input=json.dumps({"title": "Piped", "problem": text}, ensure_ascii=False).encode("utf-8"),
                           capture_output=True, env=env)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertEqual(json.loads(r.stdout.decode("utf-8"))["slugs"], ["piped"])
        r = subprocess.run([sys.executable, tool, "--root", str(self.root), "show", "piped", "--json"],
                           capture_output=True, env=env)
        self.assertNotIn(b"\r\n", r.stdout)
        self.assertEqual(json.loads(r.stdout.decode("utf-8"))["body"][0]["markdown"], text)

    def test_keys_per_command(self):
        cases = [
            (["set", FTP, "severity=4"], {"title": "New FTP title", "log": "retitled"}, "title: New FTP title"),
            (["log", FTP], {"text": "from json"}, "— from json"),
            (["verify", FTP, "--commit", "abcdef1"], {"note": "seen"}, "verified at abcdef1: seen"),
            (["move", INBOX, "--section", "parked"], {"reason": "not now"}, "reason: not now"),
            (["block", FTP], {"reason": "waiting for x"}, "reason: waiting for x"),
        ]
        for args, data, want in cases:
            with self.subTest(args=args):
                code, out = self.run_tool("--input-json", "-", *args, stdin=json.dumps(data))
                self.assertEqual(code, 0, out)
                slug = args[1]
                self.assertIn(want, item(self.root, slug).read_text(encoding="utf-8"))
        self.assertEqual(self.run_tool("--input-json", "-", "unblock", FTP, stdin='{"note": "free"}')[0], 0)
        self.assertIn("unblocked: free", item(self.root, FTP).read_text(encoding="utf-8"))
        code, out = self.run_tool("--input-json", "-", "remove", FTP, stdin='{"reason": "done elsewhere"}')
        self.assertEqual(code, 0, out)
        self.assertIn(f"dependency {FTP} closed: done elsewhere", item(self.root, DISK).read_text(encoding="utf-8"))

    def test_refusals_write_nothing(self):
        before = tree_bytes(self.root)
        refused = [
            (["log", FTP, "on the line"], {"text": "and in json"}, "text given twice"),
            (["block", FTP, "--reason", "a"], {"reason": "b"}, "reason given twice"),
            (["set", FTP, "title=A"], {"title": "B"}, "title given twice"),
            (["log", FTP], {"text": "x", "colour": "red"}, "unknown key 'colour'"),
            (["move", INBOX, "--section", "next"], {"title": "x"}, "unknown key 'title'"),
            (["log", FTP], {"text": 5}, "must be a string"),
            (["block", FTP], {"reason": "two\nlines"}, "one line"),
            (["set", FTP], {"title": "two\nlines"}, "one line"),
            (["new", "--type", "bug", "--severity", "1", "--area", "tooling"], {"title": "t\tab"}, "one line"),
            (["log", FTP], '{"text": "a", "text": "b"}', "text given twice"),
        ]
        for args, data, want in refused:
            with self.subTest(args=args, data=data):
                code, out = self.run_tool("--input-json", "-", *args, stdin=data if isinstance(data, str) else json.dumps(data))
                self.assertEqual(code, 1, out)
                self.assertTrue(out.startswith("refused:"), out)
                self.assertIn(want, out)
        for bad in ("{not json", "", "[1, 2]", '"text"'):
            with self.subTest(bad=bad):
                self.assertEqual(self.run_tool("--input-json", "-", "log", FTP, stdin=bad)[0], 2)
        self.assertEqual(self.run_tool("--input-json", "-", "check", stdin="{}")[0], 2)
        self.assertEqual(self.run_tool("--input-json", "file.json", "log", FTP)[0], 2)
        self.assertEqual(tree_bytes(self.root), before)

    def test_required_text_still_required(self):
        self.assertEqual(self.run_tool("log", FTP)[0], 2)
        self.assertEqual(self.run_tool("block", FTP)[0], 2)
        self.assertEqual(self.run_tool("new", "--type", "bug", "--severity", "1", "--area", "tooling")[0], 2)
        self.assertEqual(self.run_tool("set", FTP)[0], 2)
        self.assertEqual(self.run_tool("--input-json", "-", "log", FTP, stdin="{}")[0], 2)

    def test_new_body_validated_before_writing(self):
        code, out = self.run_tool("--input-json", "-", "new", "--type", "bug", "--severity", "1", "--area", "tooling",
                                  stdin=json.dumps({"title": "Bad body", "problem": "x\n\n## Log\n\n- nothing"}))
        self.assertEqual(code, 1)
        self.assertTrue(out.startswith("refused:"), out)
        self.assertFalse((self.root / "backlog" / "items" / "bad-body").exists())


class JsonResultTests(F344):
    def changing(self, args, stdin=None, want_code=0):
        before = tree_bytes(self.root)
        code, obj = self.run_json(*args, stdin=stdin)
        self.assertEqual(code, want_code, obj)
        self.assert_result(obj)
        after = tree_bytes(self.root)
        # every change is listed; a listed file was written (maybe with the same bytes) or deleted
        self.assertLessEqual(changed_paths(before, after), set(obj["written"]), args)
        self.assertTrue(all(w in before or w in after for w in obj["written"]), obj["written"])
        self.assertEqual(len(obj["written"]), len(set(obj["written"])))
        return obj

    def test_every_changing_command(self):
        (self.root / "specs" / "244-ftp").mkdir()
        o = self.changing(["--json", "new", "--title", "Fresh one", "--type", "bug", "--severity", "2", "--area", "viewer"])
        self.assertEqual((o["ok"], o["refused"], o["slugs"], o["section"], o["position"]), (True, None, ["fresh-one"], "Inbox", None))
        self.assertEqual(o["written"], ["backlog/items/fresh-one/desc.md", "backlog/BACKLOG.md"])
        o = self.changing(["set", DECISION, "type=feature", "--json"])
        self.assertEqual((o["section"], o["position"]), ("Next", 3))
        self.assertEqual(o["notices"], ["moved to 'Next' (type / who changed)"])
        o = self.changing(["--json", "move", "fresh-one", "--section", "next", "--position", "1"])
        self.assertEqual((o["section"], o["position"]), ("Next", 1))
        self.changing(["--json", "log", FTP, "a note"])
        self.changing(["--json", "verify", FTP, "--commit", "abcdef1"])
        self.changing(["--json", "block", "fresh-one", "--reason", "x"])
        self.changing(["--json", "unblock", "fresh-one"])
        o = self.changing(["--json", "start", FTP, "--feature", "244"])
        self.assertEqual(o["section"], "In progress")
        o = self.changing(["--json", "remove", FTP, "--feature", "244"])
        self.assertEqual((o["slugs"], o["section"], o["position"]), ([FTP], None, None))
        self.assertIn(f"backlog/items/{FTP}/desc.md", o["written"])
        self.assertIn(f"backlog/items/{DISK}/desc.md", o["written"])
        self.assertEqual(o["written"][-1], "backlog/BACKLOG.md")
        o = self.changing(["--json", "block", DISK, "--reason", "x"], want_code=1)
        self.assertEqual((o["ok"], o["written"]), (False, []))
        self.assertIn("only an open item", o["refused"])
        o = self.changing(["--json", "remove", DISK, "--reason", "gone"])
        self.assertIn(f"backlog/items/{DISK}/evidence/note.txt", o["written"])
        self.changing(["--json", "sync"])
        o = self.changing(["--json", "run-log", "--outcome", "closed", "--slug", FTP])
        self.assertEqual(o["written"], ["backlog/RUNS.md"])

    def test_findings_after_the_write(self):
        SEEDED["runs"](self.root)
        o = self.changing(["--json", "log", FTP, "x"], want_code=1)
        self.assertTrue(o["ok"])
        self.assertEqual(o["findings"][0]["rule"], "runs")
        self.assertTrue(o["written"])

    def test_refused_json_and_lock_not_json(self):
        o = self.changing(["--json", "log", "no-such", "x"], want_code=1)
        self.assertEqual((o["ok"], o["refused"], o["written"]), (False, "no item 'no-such'", []))
        o = self.changing(["--json", "--input-json", "-", "log", FTP], stdin='{"bad": "x"}', want_code=1)
        self.assertFalse(o["ok"])
        self.assertEqual(self.run_tool("--json", "lock", "status")[0], 2)

    def test_import_github_json(self):
        saved = backlog.fetch_json
        backlog.fetch_json = lambda url: {"number": 9, "title": "Crash on F5", "body": "Text.", "html_url": "u",
                                          "user": {"login": "r"}, "created_at": "2026-10-10T08:00:00Z", "comments": 0}
        try:
            o = self.changing(["--json", "import-github", "9", "--area", "file-ops"])
        finally:
            backlog.fetch_json = saved
        self.assertEqual(o["slugs"], ["crash-on-f5"])
        self.assertIn("backlog/items/crash-on-f5/issue.md", o["written"])


class ReorderAndPositionTests(F344):
    def setUp(self):
        super().setUp()
        os.environ["TANDEM_BACKLOG_NOW"] = "2026-10-20T09:00:00"

    def test_reorder(self):
        items_before = {s: item(self.root, s).read_bytes() for s in (FTP, DISK)}
        code, out = self.run_tool("--input-json", "-", "reorder", "--section", "next", stdin=json.dumps({"order": [FTP, DISK]}))
        self.assertEqual(code, 0, out)
        self.assertIn("reordered 'Next': 2 rows", out)
        self.assertEqual((self.section_of(FTP), self.section_of(DISK)), (("Next", 0), ("Next", 1)))
        self.assertEqual({s: item(self.root, s).read_bytes() for s in (FTP, DISK)}, items_before)  # no log line
        self.assertIn("Last triaged: 2026-10-20", overview(self.root).read_text(encoding="utf-8"))
        self.assertEqual(self.findings(), [])

    def test_reorder_keeps_note_rows_after_their_item(self):
        replace_once(overview(self.root), "| blocked |\n", "| blocked |\n| a note under Disk Map |\n")
        code, o = self.run_json("--json", "--input-json", "-", "reorder", "--section", "Next", stdin=json.dumps({"order": [FTP, DISK]}))
        self.assertEqual(code, 1)  # the note row is a finding, but the order is written
        self.assertEqual(o["written"], ["backlog/BACKLOG.md"])
        lines = overview(self.root).read_text(encoding="utf-8").split("\n")
        i = next(k for k, ln in enumerate(lines) if f"items/{DISK}/" in ln)
        self.assertEqual(lines[i + 1], "| a note under Disk Map |")
        self.assertIn(f"items/{FTP}/", lines[i - 1])

    def test_reorder_refusals(self):
        before = tree_bytes(self.root)
        for section, order in (("next", [FTP]), ("next", [FTP, DISK, DISK]), ("next", [FTP, DISK, INBOX]),
                               ("next", [FTP, "ghost"]), ("inbox", [INBOX])):
            code, out = self.run_tool("--input-json", "-", "reorder", "--section", section, stdin=json.dumps({"order": order}))
            self.assertEqual(code, 1, (section, order))
            self.assertTrue(out.startswith("refused:"), out)
        self.assertIn("the order must name exactly the rows of 'Next'",
                      self.run_tool("--input-json", "-", "reorder", "--section", "next", stdin='{"order": []}')[1])
        self.assertEqual(self.run_tool("reorder", "--section", "next")[0], 2)  # the order comes from stdin
        self.assertEqual(self.run_tool("--input-json", "-", "reorder", "--section", "next", stdin='{"order": "x"}')[0], 1)
        self.assertEqual(tree_bytes(self.root), before)

    def test_set_position(self):
        code, out = self.run_tool("set", DECISION, "type=feature", "--position", "1")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.section_of(DECISION), ("Next", 0))
        self.assertEqual(self.findings(), [])
        before = tree_bytes(self.root)
        code, out = self.run_tool("set", FTP, "severity=5", "--position", "1")
        self.assertEqual(code, 1)
        self.assertIn("use move", out)
        self.assertEqual(self.run_tool("set", PERSON, "type=bug", "who=agent", "--position", "0")[0], 1)
        self.assertEqual(tree_bytes(self.root), before)


class BodyStepTests(F344):
    def body(self, slug, section, data, *extra):
        return self.run_tool("--input-json", "-", "body", slug, "--section", section, *extra, stdin=json.dumps(data))

    def sections(self, slug):
        return [b["name"] for b in self.run_json("show", slug, "--json")[1]["body"]]

    def test_replace_add_remove(self):
        code, out = self.body(FTP, "Problem", {"markdown": "The real problem.\n\n" + NASTY})
        self.assertEqual(code, 0, out)
        s = self.run_json("show", FTP, "--json")[1]
        self.assertEqual(s["body"][0]["markdown"], "The real problem.\n\n" + NASTY.rstrip("\n"))
        self.assertEqual(s["log"][-1]["text"], "edited Problem")
        self.assertEqual(self.body(FTP, "Notes", {"markdown": "a note", "log": "noted"})[0], 0)
        self.assertEqual(self.body(FTP, "approach", {"markdown": "do it"})[0], 0)
        self.assertEqual(self.sections(FTP), ["Problem", "Evidence", "Expected", "Approach", "Notes", "Log"])
        self.assertEqual(self.run_json("show", FTP, "--json")[1]["log"][-2]["text"], "noted")
        self.assertEqual(self.body(FTP, "Notes", {"remove": True})[0], 0)
        self.assertEqual(self.sections(FTP), ["Problem", "Evidence", "Expected", "Approach", "Log"])
        self.assertEqual(self.findings(), [])

    def test_body_refusals(self):
        before = tree_bytes(self.root)
        for slug, section, data in ((FTP, "Log", {"markdown": "x"}), (FTP, "Problem", {"remove": True}),
                                    (DECISION, "Question", {"remove": True}), (PERSON, "Steps", {"remove": True}),
                                    (FTP, "Notes", {"remove": True}),  # absent
                                    (FTP, "Problem", {"markdown": "x\n\n## Log\n\n- 2026-10-17 — fake"}),
                                    (FTP, "Problem", {"markdown": "```\nunclosed fence"}),
                                    (PERSON, "Steps", {"markdown": "no checklist"}),
                                    (FTP, "Problem", {"markdown": "x", "remove": True}),
                                    (FTP, "Problem", {"markdown": "  \n"}),
                                    (FTP, "Elsewhere", {"markdown": "x"})):
            with self.subTest(section=section, data=data):
                code, out = self.body(slug, section, data)
                self.assertEqual(code, 1, out)
                self.assertTrue(out.startswith("refused:"), out)
        self.assertEqual(self.run_tool("body", FTP, "--section", "Notes")[0], 2)  # the text comes from stdin
        self.assertEqual(tree_bytes(self.root), before)

    def test_remove_question_of_a_bug(self):
        replace_once(item(self.root, FTP), "## Log\n", "## Question\n\nWhy?\n\n## Log\n")
        self.assertEqual(self.body(FTP, "Question", {"remove": True})[0], 0)
        self.assertEqual(self.findings(), [])

    def test_step(self):
        replace_once(item(self.root, PERSON), "- [ ] (to be written)", "- [ ] build it\n- [ ] sign it")
        code, out = self.run_tool("--input-json", "-", "step", PERSON, "2", "--done", stdin='{"note": "signed on the box"}')
        self.assertEqual(code, 0, out)
        s = self.run_json("show", PERSON, "--json")[1]
        self.assertEqual([st["done"] for st in s["steps"]], [False, True])
        self.assertEqual(s["log"][-1]["text"], "step 2 done: signed on the box")
        self.assertEqual(self.run_tool("step", PERSON, "2", "--undone")[0], 0)
        s = self.run_json("show", PERSON, "--json")[1]
        self.assertEqual([st["done"] for st in s["steps"]], [False, False])
        self.assertEqual(s["log"][-1]["text"], "step 2 reopened")
        before = tree_bytes(self.root)
        for args in (["step", PERSON, "3", "--done"], ["step", PERSON, "0", "--done"], ["step", FTP, "1", "--done"],
                     ["step", PERSON, "1", "--undone"]):
            code, out = self.run_tool(*args)
            self.assertEqual(code, 1, args)
            self.assertTrue(out.startswith("refused:"), out)
        self.assertEqual(self.run_tool("step", PERSON, "1")[0], 2)
        self.assertEqual(tree_bytes(self.root), before)
        self.assertEqual(self.findings(), [])

    def test_reply(self):
        reply = self.root / "backlog" / "items" / DECISION / "reply.md"
        code, o = self.run_json("--json", "reply", DECISION, "--state", "sent")
        self.assertEqual(code, 0, o)
        self.assertEqual(reply.read_text(encoding="utf-8"), "state: sent 2026-10-17\n\nDraft.\n")
        self.assertEqual(o["written"], [f"backlog/items/{DECISION}/reply.md", f"backlog/items/{DECISION}/desc.md", "backlog/BACKLOG.md"])
        self.assertIn("— reply marked sent", item(self.root, DECISION).read_text(encoding="utf-8"))
        self.assertEqual(self.run_tool("reply", DECISION, "--state", "not-sent")[0], 0)
        self.assertTrue(reply.read_text(encoding="utf-8").startswith("state: not-sent\n"))
        code, out = self.run_tool("reply", FTP, "--state", "sent")
        self.assertEqual(code, 1)
        self.assertIn("reply.md", out)
        self.assertEqual(self.findings(), [])


class DecideTests(F344):
    def decide(self, *args, decision="Ship it in 0.3.", slug=DECISION):
        return self.run_tool("--input-json", "-", "decide", slug, *args, stdin=json.dumps({"decision": decision}))

    def log_texts(self, slug=DECISION):
        return [e["text"] for e in self.run_json("show", slug, "--json")[1]["log"]]

    def test_keep(self):
        code, out = self.decide("--option", "A", "--then", "keep")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.log_texts()[-1], "maintainer decision 2026-10-17: option A - Ship it in 0.3.")
        self.assertEqual(self.section_of(DECISION)[0], "Decisions for the maintainer")

    def test_move_with_type(self):
        code, out = self.decide("--option", "B", "--then", "move:next@1", "--type", "feature")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.section_of(DECISION), ("Next", 0))
        h = self.header(DECISION)
        self.assertEqual((h["type"], h["status"]), ("feature", "open"))
        self.assertEqual(self.log_texts()[-3:], ["maintainer decision 2026-10-17: option B - Ship it in 0.3.",
                                                 "set type=feature", "moved to Next position 1"])
        self.assertEqual(self.findings(), [])

    def test_set_type_with_who_and_position(self):
        code, out = self.decide("--option", "A", "--then", "set-type:person-step,who:person@1")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.section_of(DECISION), ("Person steps", 0))
        self.assertIn("## Steps", item(self.root, DECISION).read_text(encoding="utf-8"))
        self.assertEqual(self.findings(), [])

    def test_park_and_close(self):
        code, out = self.decide("--option", "C", "--then", "park", decision="Not before 1.0.")
        self.assertEqual(code, 0, out)
        h = self.header(DECISION)
        self.assertEqual((h["status"], h["reason"]), ("parked", "Not before 1.0."))
        self.assertEqual(self.findings(), [])
        self.tearDown()
        self.setUp()
        replace_once(item(self.root, FTP), "related: [archive-pack-refuses-a-long-folder-silently]",
                     f"related: [{ARCHIVE}, {DECISION}]")
        code, out = self.run_tool("--json", "--input-json", "-", "decide", DECISION, "--option", "A", "--then", "close",
                                  stdin='{"decision": "Shipped already."}')
        self.assertEqual(code, 0, out)
        self.assertFalse((self.root / "backlog" / "items" / DECISION).exists())
        self.assertIn(f"related item {DECISION} closed: Shipped already.", item(self.root, FTP).read_text(encoding="utf-8"))
        self.assertEqual(self.findings(), [])

    def test_refusals(self):
        before = tree_bytes(self.root)
        for args, slug in ((["--option", "A", "--then", "keep"], FTP),
                           (["--option", "A", "--then", "explode"], DECISION),
                           (["--option", "A", "--then", "move:in-progress"], DECISION),
                           (["--option", "A", "--then", "move:next"], DECISION),  # a decision does not go to Next
                           (["--option", "A", "--then", "set-type:decision"], DECISION),
                           (["--option", "A", "--then", "set-type:nonsense"], DECISION),
                           (["--option", "A", "--then", "park", "--type", "bug"], DECISION)):
            with self.subTest(args=args):
                code, out = self.decide(*args, slug=slug)
                self.assertEqual(code, 1, out)
                self.assertTrue(out.startswith("refused:"), out)
        self.assertEqual(tree_bytes(self.root), before)
        replace_once(item(self.root, DECISION), "## Options\n\n(to be written)", "## Options\n\n- **A** - one\n- **B** - two")
        before = tree_bytes(self.root)
        code, out = self.decide("--option", "Z", "--then", "keep")
        self.assertEqual(code, 1)
        self.assertIn("option 'Z'", out)
        self.assertEqual(self.run_tool("decide", DECISION, "--option", "A", "--then", "keep")[0], 2)  # no decision text
        self.assertEqual(tree_bytes(self.root), before)


def git_bash():
    """Git's bash (on Windows `bash` on PATH may be WSL's)."""
    if os.name != "nt":
        return shutil.which("bash")
    exe = shutil.which("git")
    if exe:
        for up in Path(exe).resolve().parents[:3]:
            cand = up / "bin" / "bash.exe"
            if cand.is_file():
                return str(cand)
    return None


class BinTests(Base):
    """bin/backlog.sh runs this tool (feature 342); the loop is bin/backlog-loop.sh."""

    BIN = HERE.parents[1] / "bin" / "backlog.sh"

    def sh(self, *args):
        bash = git_bash()
        if not bash:
            self.skipTest("needs Git Bash")
        env = dict(os.environ)
        env.pop("TANDEM_BACKLOG_NOW", None)
        r = subprocess.run([bash, str(self.BIN), *args], capture_output=True, text=True, encoding="utf-8", env=env)
        return r.returncode, r.stdout, r.stderr

    def snapshot(self):
        return {p.relative_to(self.root).as_posix(): p.read_bytes() for p in self.root.rglob("*") if p.is_file()}

    def test_help_lists_every_command_and_names_the_loop(self):
        for args in (["--help"], ["-h"], ["help"]):
            code, out, _ = self.sh(*args)
            self.assertEqual(code, 0, args)
            self.assertTrue(out.startswith("Usage: bin/backlog.sh"), out)
            self.assertIn("bin/backlog-loop.sh", out)
            sub = next(a for a in backlog.build_parser()._actions if isinstance(a, argparse._SubParsersAction))
            for command in sub.choices:
                self.assertIn(command, out)
            self.assertIn("usage: bin/backlog.sh", out)  # the tool names the script, not backlog.py
        code, out, err = self.sh()
        self.assertEqual(code, 2)
        self.assertEqual(out, "")
        self.assertIn("Usage: bin/backlog.sh", err)
        code, out, _ = self.sh("list", "--help")
        self.assertEqual(code, 0)
        self.assertIn("usage: bin/backlog.sh list", out)

    def test_a_command_gives_what_the_tool_gives(self):
        code, out, _ = self.sh("--root", str(self.root), "list", "--json")
        self.assertEqual(code, 0)
        os.environ.pop("TANDEM_BACKLOG_NOW", None)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.assertEqual(backlog.main(["--root", str(self.root), "list", "--json"]), 0)
        self.assertEqual(out, buf.getvalue())
        self.assertEqual(self.sh("--root", str(self.root), "check")[:2], (0, "TOTAL: 0\n"))

    def test_the_former_loop_words_are_usage_errors_and_change_nothing(self):
        """Clarification Q3: no alias and no hint - the tool's own usage error."""
        before = self.snapshot()
        for args in (["pause"], ["resume"], ["stop"], ["status"], ["start"], ["start", "--auto-triage"]):
            code, out, err = self.sh("--root", str(self.root), *args)
            self.assertEqual(code, 2, args)
            self.assertIn("usage: bin/backlog.sh", err)
        self.assertEqual(self.snapshot(), before)


if __name__ == "__main__":
    unittest.main()
