# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Tests of tools/backlog/backlog.py (feature 242).

Run from the repository root:  python -m unittest tools/backlog/test_backlog.py -v

Every test works on a copy of fixtures/valid in a temporary folder.  The
seeded-defect cases (one per check rule, SC-004) are mutations of that copy,
listed in SEEDED below - each changes exactly one thing.
"""

import contextlib
import io
import os
import shutil
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

    def run_tool(self, *args):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = backlog.main(["--root", str(self.root), "--lock-dir", str(self.lock_dir), *args])
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


if __name__ == "__main__":
    unittest.main()
