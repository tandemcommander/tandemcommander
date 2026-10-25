# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Tests of tools/release/release.py (feature 243).

Run from the repository root:  python -m unittest tools/release/test_release.py -v

Every test works on a git repository built in a temporary folder from
fixtures/repo (see fixtures/README.md): tag v0.1.0 (build 184), tag v0.1.1
(build 185), work collected under "## [Unreleased]".
"""

import contextlib
import datetime as dt
import io
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import release  # noqa: E402

FIXTURE = HERE / "fixtures" / "repo"
REAL_ROOT = HERE.parents[1]
D1 = "2026-11-02"
D2 = "2026-11-05"


def git(root: Path, *args: str) -> str:
    r = subprocess.run(["git", *args], cwd=str(root), capture_output=True, text=True, encoding="utf-8")
    if r.returncode != 0:
        raise AssertionError(f"git {' '.join(args)}: {r.stderr}")
    return r.stdout


def read(root: Path, rel: str) -> str:
    return (root / rel).read_bytes().decode("utf-8").lstrip("﻿").replace("\r\n", "\n")


def write(root: Path, rel: str, text: str) -> None:
    rec = release.Record(root, rel)
    rec.text = text
    rec.save()


def replace(root: Path, rel: str, old: str, new: str, count: int = 1) -> None:
    text = read(root, rel)
    assert old in text, f"{old!r} not in {rel}"
    write(root, rel, text.replace(old, new, count))


def commit(root: Path, msg: str = "change") -> None:
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", msg)


def make_repo(tmp: Path) -> Path:
    root = tmp / "repo"
    shutil.copytree(FIXTURE, root)
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.name", "Test")
    git(root, "config", "user.email", "test@example.invalid")
    git(root, "config", "core.autocrlf", "false")
    spl = read(root, release.PATH_SPL)
    write(root, release.PATH_SPL, spl.replace("MINORB 1", "MINORB 0").replace("BUILDNUMBER 185", "BUILDNUMBER 184"))
    commit(root, "0.1.0")
    git(root, "tag", "-a", "v0.1.0", "-m", "")
    write(root, release.PATH_SPL, spl)
    commit(root, "0.1.1")
    git(root, "tag", "-a", "v0.1.1", "-m", "")
    return root


def run(root: Path, *argv: str, online: bool = False) -> tuple[int, str]:
    out = io.StringIO()
    with contextlib.redirect_stdout(out):
        code = release.main([argv[0], *argv[1:], "--root", str(root)] + ([] if online else ["--offline"]))
    return code, out.getvalue()


def fill_texts(root: Path, ver: str, build: int, date: str, issues: str = "(#4)") -> None:
    """What the skill writes after stamp: replace every placeholder and state the release."""
    replace(root, release.PATH_SPL, "TODO-SUMMARY", "two fixes - features 012, 013")
    cl = read(root, release.PATH_CHANGELOG)
    if "TODO-KIND" in cl:
        replace(root, release.PATH_CHANGELOG, "TODO-KIND release. TODO-SUMMARY", "Bug-fix release. Two fixes.")
    pv = read(root, release.PATH_PRIVACY)
    if "TODO-PRIVACY" in pv:
        replace(root, release.PATH_PRIVACY, "TODO-PRIVACY", "nothing described here differed")
    cm = read(root, release.PATH_CLAUDE)
    write(root, release.PATH_CLAUDE, re.sub(r"prepared for the\s+\S+\s+release", f"prepared for the {ver} release", cm))
    rl = read(root, release.PATH_RELEASE)
    if "Gating person steps:" not in rl:
        body = (f"\n- Prepared: the tree prepared for the release ({date}), features 012–013.\n"
                "- Gating person steps:\n  - `person-one` - Check 013\n")
        rl = re.sub(r"(## Current release: .*\n)", lambda m: m[1] + body, rl)
        write(root, release.PATH_RELEASE, rl)
    d = dt.date.fromisoformat(date)
    notes = (f"# Tandem Commander {ver}\n\n**Released {release.long_date(d)} · build {build} · Windows 11 or "
             f"newer, 64-bit · bug-fix release**\n\n## Fixed\n\n- A deep folder keeps its last file {issues}.\n"
             f"- The status bar shows accented names.\n\n---\n\n{release.NOTES_FOOTER}\n")
    write(root, f"release_notes/release_notes_v{ver}.md", notes)


class Base(unittest.TestCase):
    def setUp(self):
        self._tmp = tempfile.TemporaryDirectory()
        self.root = make_repo(Path(self._tmp.name))
        self._env = os.environ.pop("OPENSAL_BUILD_DIR", None)

    def tearDown(self):
        if self._env is not None:
            os.environ["OPENSAL_BUILD_DIR"] = self._env
        self._tmp.cleanup()

    def prepare(self, ver="0.1.2", date=D1):
        code, out = run(self.root, "stamp", ver, "--date", date)
        self.assertEqual(code, 0, out)
        fill_texts(self.root, ver, 186, date)
        code, out = run(self.root, "check", ver, "--date", date)
        self.assertEqual(code, 0, out)
        commit(self.root, f"Version {ver}")


# ---------------------------------------------------------------------------


class VersionsAndIO(unittest.TestCase):
    def test_version_forms(self):
        for good in ("0.1.10", "0.0.0", "10.20.99999"):
            self.assertIsNotNone(release.Version.parse(good), good)
        for bad in ("v0.1.10", "0.1.010", "0.1", "0.1.10.1", "0.1.123456", " 0.1.1", "0.1.1 ", "", "0.01.1"):
            self.assertIsNone(release.Version.parse(bad), bad)
        self.assertLess(release.Version.parse("0.1.9"), release.Version.parse("0.1.10"))
        self.assertEqual(release.Version.parse("0.1.10").installer, "tandemcommander-0.1.10-x64-setup.exe")

    def test_long_date(self):
        self.assertEqual(release.long_date(dt.date(2026, 11, 2)), "2 November 2026")
        self.assertEqual(release.long_date(dt.date(2026, 10, 17)), "17 October 2026")

    def test_bom_and_crlf_kept_and_unchanged_not_written(self):
        with tempfile.TemporaryDirectory() as t:
            p = Path(t) / "f.h"
            p.write_bytes(b"\xef\xbb\xbfa\r\nb\r\n")
            r = release.Record(Path(t), "f.h")
            self.assertEqual(r.text, "a\nb\n")
            mtime = p.stat().st_mtime_ns
            self.assertFalse(r.save())
            self.assertEqual(p.stat().st_mtime_ns, mtime)
            r.text = "a\nc\n"
            self.assertTrue(r.save())
            self.assertEqual(p.read_bytes(), b"\xef\xbb\xbfa\r\nc\r\n")

    def test_feature_numbers(self):
        f = release.feature_numbers("(feature 134; GitHub #7) features 138-140, 142 and 145; features 124–126")
        self.assertEqual(f, {134, 138, 139, 140, 142, 145, 124, 125, 126})
        self.assertEqual(release.issue_numbers("GitHub #7, (#5), winget-pkgs#426090, ## head"), {7, 5})


class Summary(unittest.TestCase):
    def cl(self, lead: str) -> str:
        return f"# Changelog\n\n## [0.1.2] — 2026-11-02\n\n{lead}\n\n- entry\n"

    def test_clean_up(self):
        w = release.winget_summary(self.cl("**Build 186.** Bug-fix [link](http://x) `code` — “q” ’s."), "0.1.2")
        self.assertEqual(w["text"], 'Build 186. Bug-fix link code - "q" \'s.')
        self.assertFalse(w["cut"])

    def test_cut_and_wrap(self):
        w = release.winget_summary(self.cl("**Build 186.** " + "word " * 300), "0.1.2")
        self.assertTrue(w["cut"])
        self.assertTrue(w["text"].endswith("..."))
        self.assertLessEqual(len(w["text"]), 903)
        self.assertTrue(all(len(ln) <= 78 for ln in w["lines"]))

    def test_hash_line_dropped(self):
        lead = "**Build 186.** " + "x" * 64 + " #7 fixed"   # "Build 186. xxx" is 75 columns; "#7" opens line 2
        w = release.winget_summary(self.cl(lead), "0.1.2")
        self.assertEqual([ln.strip() for ln in w["dropped"]], ["#7 fixed"])

    def test_unreleased_and_bullet(self):
        self.assertIsNone(release.winget_summary("## [0.1.2] — unreleased\n\nLead.\n", "0.1.2")["text"])
        w = release.winget_summary(self.cl("- a bullet"), "0.1.2")
        self.assertEqual(w["text"], "- a bullet")

    def test_replica_matches_published_0_1_9_manifest(self):
        manifest = REAL_ROOT / "tools/winget/manifests/0.1.9/PavelStupka.TandemCommander.locale.en-US.yaml"
        if not manifest.is_file():
            self.skipTest("no recorded 0.1.9 manifest")
        text = manifest.read_text(encoding="utf-8").replace("\r\n", "\n")
        m = re.search(r"^ReleaseNotes: \|-\n((?:  .*\n)+)", text, re.M)
        w = release.winget_summary((REAL_ROOT / "CHANGELOG.md").read_text(encoding="utf-8"), "0.1.9")
        self.assertEqual(w["lines"], m[1].rstrip("\n").split("\n"))


class NewVersion(Base):
    def test_status_not_prepared(self):
        code, out = run(self.root, "status", "0.1.2", "--date", D1)
        self.assertEqual(code, 0, out)
        self.assertIn("previous: 0.1.1 (tag v0.1.1, build 185)   build: 186", out)
        self.assertIn("state: not-prepared", out)
        self.assertIn("features: 012-013 (2)   issues: #4", out)
        self.assertIn("gating-candidate: person-one", out)

    def test_stamp_sets_all_records(self):
        code, out = run(self.root, "stamp", "0.1.2", "--date", D1)
        self.assertEqual(code, 0, out)
        self.assertIn("changed: 8 file(s)", out)
        spl = read(self.root, release.PATH_SPL)
        self.assertIn("#define VERSINFO_SALAMANDER_MINORB 2\n", spl)
        self.assertIn("#define VERSINFO_BUILDNUMBER 186\n", spl)
        self.assertIn("//       011; see CHANGELOG.md)\n// 186 - Tandem Commander 0.1.2 (TODO-SUMMARY; see CHANGELOG.md)\n\n// ! DULEZITE", spl)
        self.assertTrue((self.root / release.PATH_SPL).read_bytes().startswith(b"\xef\xbb\xbf"))
        self.assertIn('#define MyAppVersion "0.1.2"', read(self.root, release.PATH_ISS))
        cl = read(self.root, release.PATH_CHANGELOG)
        self.assertIn("## [0.1.2] — 2026-11-02\n\n**Build 186.** TODO-KIND release. TODO-SUMMARY\n\n- **Copying", cl)
        self.assertNotIn("Unreleased", cl)
        pv = read(self.root, release.PATH_PRIVACY)
        self.assertIn("describes Tandem Commander 0.1.2 (`CHANGELOG.md`). In 0.1.1, the version before it, "
                      "TODO-PRIVACY. In 0.1.0: the SFTP log kept", pv)
        self.assertIn("Last updated 2026-11-02.", pv)
        cm = read(self.root, release.PATH_CLAUDE)
        self.assertIn("**Tandem Commander 0.1.2** (internal build 186, release dated 2026-11-02;\n  carries features "
                      "012–013; previous: 0.1.1 / build 185 / tag\n  `v0.1.1`)", cm)
        self.assertIn("## Status (2026-11-02)", cm)
        self.assertIn("version **0.1.2** (internal build 186,\n  release dated 2026-11-02 — it carries features "
                      "012–013,\n  everything made since 0.1.1 / build 185 / tag `v0.1.1`)",
                      read(self.root, release.PATH_REFERENCE))
        self.assertIn("## Current release: 0.1.2 (build 186) — prepared, not published",
                      read(self.root, release.PATH_RELEASE))
        notes = read(self.root, "release_notes/release_notes_v0.1.2.md")
        self.assertIn("**Released 2 November 2026 · build 186 · Windows 11 or newer, 64-bit · TODO-KIND**", notes)
        self.assertTrue(notes.rstrip("\n").endswith(release.NOTES_FOOTER))

    def test_check_fails_on_placeholders_then_passes(self):
        run(self.root, "stamp", "0.1.2", "--date", D1)
        code, out = run(self.root, "check", "0.1.2", "--date", D1)
        self.assertEqual(code, 1)
        for rule in ("build-history", "changelog-lead", "privacy-previous", "claude-status", "release-current", "notes-todo"):
            self.assertIn(f": {rule}:", out, rule)
        fill_texts(self.root, "0.1.2", 186, D1)
        code, out = run(self.root, "check", "0.1.2", "--date", D1)
        self.assertEqual(code, 0, out)
        self.assertIn("findings: 0", out)

    def test_idempotent_after_commit(self):
        self.prepare()
        files = {p: p.stat().st_mtime_ns for p in self.root.rglob("*") if p.is_file() and ".git" not in p.parts}
        code, out = run(self.root, "stamp", "0.1.2", "--date", D1)
        self.assertEqual(code, 0, out)
        self.assertIn("unchanged", out)
        self.assertEqual(files, {p: p.stat().st_mtime_ns for p in files})
        code, out = run(self.root, "status", "0.1.2", "--date", D1)
        self.assertIn("state: prepared-today", out)

    def test_dry_run_writes_nothing(self):
        code, out = run(self.root, "stamp", "0.1.2", "--date", D1, "--dry-run")
        self.assertEqual(code, 0, out)
        self.assertIn("would change: 8 file(s)", out)
        self.assertEqual(git(self.root, "status", "--porcelain"), "")

    def test_crlf_records_stay_crlf(self):
        for rel in (release.PATH_CHANGELOG, release.PATH_CLAUDE):
            p = self.root / rel
            p.write_bytes(p.read_bytes().replace(b"\r\n", b"\n").replace(b"\n", b"\r\n"))
        commit(self.root, "crlf")
        run(self.root, "stamp", "0.1.2", "--date", D1)
        for rel in (release.PATH_CHANGELOG, release.PATH_CLAUDE):
            data = (self.root / rel).read_bytes()
            self.assertEqual(data.count(b"\n"), data.count(b"\r\n"), rel)

    def test_interface_change_updates_require_text(self):
        replace(self.root, release.PATH_SPL, "LAST_VERSION_OF_SALAMANDER 105", "LAST_VERSION_OF_SALAMANDER 106")
        replace(self.root, release.PATH_SPL, "interface 105, first shipped in version 0.1.0.",
                "interface 106, first shipped after version 0.1.1.")
        commit(self.root, "interface")
        run(self.root, "stamp", "0.1.2", "--date", D1)
        self.assertIn("interface 106, first shipped in version 0.1.2.", read(self.root, release.PATH_SPL))


class PreparedEarlier(Base):
    def add_next(self, lead: str = "", groups: bool = False):
        cl = read(self.root, release.PATH_CHANGELOG)
        sec = "## [0.1.3] — unreleased\n\n" + (lead + "\n\n" if lead else "") + \
            ("### Fixed\n\n" if groups else "") + "- **Later fix** (feature 014; GitHub #9).\n\n"
        write(self.root, release.PATH_CHANGELOG, cl.replace("## [0.1.2]", sec + "## [0.1.2]", 1))
        commit(self.root, "0.1.3 work")

    def test_fold_and_move_dates(self):
        self.prepare()
        self.add_next(lead="**Build 187.** A later lead paragraph.")
        code, out = run(self.root, "status", "0.1.2", "--date", D2)
        self.assertIn("state: prepared-earlier", out)
        code, out = run(self.root, "stamp", "0.1.2", "--date", D2)
        self.assertEqual(code, 0, out)
        self.assertIn("dropped-lead: [0.1.3] (line 7): **Build 187.** A later lead paragraph.", out)
        self.assertNotIn("A later lead paragraph", read(self.root, release.PATH_CHANGELOG))
        cl = read(self.root, release.PATH_CHANGELOG)
        self.assertEqual(cl.count("## [0.1.2]"), 1)
        self.assertNotIn("0.1.3", cl)
        self.assertIn("## [0.1.2] — 2026-11-05\n\n**Build 186.** Bug-fix release. Two fixes.\n\n- **Later fix**", cl)
        self.assertLess(cl.index("Later fix"), cl.index("Copying a deep folder"))
        self.assertIn("#define VERSINFO_BUILDNUMBER 186", read(self.root, release.PATH_SPL))
        self.assertEqual(len(release.history_entry(read(self.root, release.PATH_SPL), 186)), 1)
        self.assertIn("Last updated 2026-11-05.", read(self.root, release.PATH_PRIVACY))
        self.assertIn("release dated 2026-11-05;\n  carries features 012–014", read(self.root, release.PATH_CLAUDE))
        self.assertIn("**Released 5 November 2026 · build 186", read(self.root, "release_notes/release_notes_v0.1.2.md"))
        code, out = run(self.root, "check", "0.1.2", "--date", D2)
        self.assertEqual(code, 1)
        self.assertIn("notes-issues: GitHub #9", out)
        self.assertNotIn("changelog-heading", out)
        self.assertNotIn("privacy", out)

    def test_prose_entry_stays_in_body(self):
        """Review finding 1: a prose entry opening an unreleased section is not a lead."""
        self.prepare()
        cl = read(self.root, release.PATH_CHANGELOG)
        sec = ("## [0.1.3] — unreleased\n\nNew check (feature 014). A paragraph entry.\n\n"
               "Its second paragraph.\n\n- **A bullet** (feature 015).\n\n")
        write(self.root, release.PATH_CHANGELOG, cl.replace("## [0.1.2]", sec + "## [0.1.2]", 1))
        commit(self.root, "prose")
        code, out = run(self.root, "stamp", "0.1.2", "--date", D2)
        self.assertEqual(code, 0, out)
        self.assertNotIn("dropped-lead", out)
        cl = read(self.root, release.PATH_CHANGELOG)
        self.assertIn("## [0.1.2] — 2026-11-05\n\n**Build 186.** Bug-fix release. Two fixes.\n\n"
                      "New check (feature 014). A paragraph entry.\n\nIts second paragraph.\n\n- **A bullet**", cl)
        self.assertEqual(cl.count("A paragraph entry."), 1)

    def test_prose_unreleased_gets_placeholder(self):
        replace(self.root, release.PATH_CHANGELOG, "## [Unreleased]\n\n",
                "## [Unreleased]\n\nNew check (feature 014). A paragraph entry.\n\n")
        commit(self.root, "prose")
        run(self.root, "stamp", "0.1.2", "--date", D1)
        cl = read(self.root, release.PATH_CHANGELOG)
        self.assertIn("## [0.1.2] — 2026-11-02\n\n**Build 186.** TODO-KIND release. TODO-SUMMARY\n\n"
                      "New check (feature 014).", cl)

    def test_groups_refused(self):
        self.prepare()
        self.add_next(groups=True)
        code, out = run(self.root, "stamp", "0.1.2", "--date", D2)
        self.assertEqual(code, 1)
        self.assertIn("### groups", out)
        self.assertEqual(git(self.root, "status", "--porcelain"), "")


class Refusals(Base):
    def assert_refused(self, reason: str, *argv: str):
        before = git(self.root, "status", "--porcelain")
        code, out = run(self.root, "stamp", *argv)
        self.assertEqual(code, 1, out)
        self.assertIn(f"refused: {reason}", out)
        self.assertEqual(git(self.root, "status", "--porcelain"), before)

    def test_version_form(self):
        self.assert_refused("version-form", "0.1.02")

    def test_detached_head(self):
        git(self.root, "checkout", "-q", "--detach")
        self.assert_refused("detached-head", "0.1.2", "--date", D1)

    def test_tags_only_on_the_remote(self):
        remote = self.root.parent / "remote.git"
        git(self.root.parent, "init", "-q", "--bare", str(remote))
        git(self.root, "remote", "add", "origin", str(remote))
        git(self.root, "push", "-q", "origin", "main", "--tags")
        self.prepare()
        git(self.root, "tag", "-a", "v0.1.2", "-m", "")
        git(self.root, "push", "-q", "origin", "v0.1.2")
        git(self.root, "tag", "-d", "v0.1.2")
        code, out = run(self.root, "stamp", "0.1.2", "--date", D1, online=True)
        self.assertIn("refused: tag-exists: 0.1.2 is already released (tag v0.1.2, remote)", out)
        code, out = run(self.root, "stamp", "0.1.3", "--date", D1, online=True)
        self.assertIn("refused: no-previous-tag: the previous release tag v0.1.2 exists only on the remote", out)
        self.assertEqual(git(self.root, "status", "--porcelain"), "")

    def test_tag_exists(self):
        self.assert_refused("tag-exists", "0.1.1")
        code, out = run(self.root, "status", "0.1.1")
        self.assertIn("state: released", out)
        self.assertNotIn("inconsistent", out)
        code, out = run(self.root, "status", "0.2.0", "--date", D1)
        self.assertNotIn("inconsistent", out)

    def test_not_higher(self):
        git(self.root, "tag", "-a", "v0.1.5", "-m", "")
        self.assert_refused("not-higher", "0.1.2", "--date", D1)

    def test_minor_and_major_steps_accepted(self):
        # feature 343: the configuration root no longer follows the version - no line-change refusal
        for ver in ("0.2.0", "1.0.0"):
            code, out = run(self.root, "status", ver, "--date", D1)
            self.assertNotIn("refused", out, ver)
            self.assertNotIn("line-change", out, ver)
            self.assertNotIn("version-step", out, ver)
            self.assertIn("state: not-prepared", out, ver)

    def test_dirty_tree(self):
        (self.root / "new.txt").write_text("x")
        self.assert_refused("dirty-tree", "0.1.2", "--date", D1)

    def test_lock_held(self):
        tool = self.root / release.BACKLOG_TOOL
        tool.parent.mkdir(parents=True)
        tool.write_text("print('held by run 2026-11-01 item x')\n")
        commit(self.root, "fake lock")
        self.assert_refused("lock-held", "0.1.2", "--date", D1)

    def test_copyright_year(self):
        self.assert_refused("copyright-year", "0.1.2", "--date", "2027-01-05")

    def test_inconsistent_source(self):
        replace(self.root, release.PATH_SPL, "MINORB 1", "MINORB 7")
        commit(self.root, "odd")
        self.assert_refused("inconsistent", "0.1.2", "--date", D1)

    def test_dated_section_of_another_version(self):
        replace(self.root, release.PATH_CHANGELOG, "## [Unreleased]", "## [0.1.4] — 2026-10-01")
        commit(self.root, "odd")
        self.assert_refused("inconsistent", "0.1.2", "--date", D1)

    def test_nothing_to_release(self):
        cl = read(self.root, release.PATH_CHANGELOG)
        write(self.root, release.PATH_CHANGELOG, cl[:cl.index("## [Unreleased]")] + cl[cl.index("## [0.1.1]"):])
        commit(self.root, "empty")
        self.assert_refused("inconsistent", "0.1.2", "--date", D1)


class Warnings(Base):
    def status(self, *argv: str) -> str:
        return run(self.root, "status", *argv)[1]

    def test_branch_not_main(self):
        git(self.root, "checkout", "-q", "-b", "work")
        self.assertIn("warning: branch-not-main", self.status("0.1.2", "--date", D1))

    def test_version_step(self):
        # feature 343: from the release 0.1.1 the next versions are 0.1.2, 0.2.0 and 1.0.0
        for ver in ("0.1.3", "0.2.1", "0.3.0", "1.0.1", "2.0.0"):
            self.assertIn("warning: version-step", self.status(ver, "--date", D1), ver)
        for ver in ("0.1.2", "0.2.0", "1.0.0"):
            self.assertNotIn("version-step", self.status(ver, "--date", D1), ver)

    def test_patch_kind(self):
        # feature 343: a PATCH release carries fixes only - its lead must name a fix
        run(self.root, "stamp", "0.1.2", "--date", D1)
        fill_texts(self.root, "0.1.2", 186, D1)
        code, out = run(self.root, "check", "0.1.2", "--date", D1)
        self.assertNotIn("patch-kind", out)
        replace(self.root, release.PATH_CHANGELOG, "Bug-fix release. Two fixes.", "Feature release. Two fixes.")
        code, out = run(self.root, "check", "0.1.2", "--date", D1)
        self.assertIn("warning: patch-kind", out)
        self.assertEqual(code, 0, out)  # a warning, not a finding
        self.assertIn("warning: patch-kind", self.status("0.1.2", "--date", D1))

    def test_build_dir(self):
        os.environ["OPENSAL_BUILD_DIR"] = str(self.root / "elsewhere")
        try:
            self.assertIn("warning: build-dir", self.status("0.1.2", "--date", D1))
        finally:
            del os.environ["OPENSAL_BUILD_DIR"]

    def test_certificate(self):
        self.assertNotIn("warning: certificate", self.status("0.1.2", "--date", D1))
        self.assertIn("warning: certificate", self.status("0.1.2", "--date", "2027-07-01"))

    def test_release_branch_ahead(self):
        git(self.root, "checkout", "-q", "-b", "release-0.1.2")
        (self.root / "x.txt").write_text("x")
        commit(self.root, "on release branch")
        git(self.root, "checkout", "-q", "main")
        out = self.status("0.1.2", "--date", D1)
        self.assertIn("warning: release-branch-ahead: release-0.1.2 (1 commit(s) not in HEAD)", out)

    def test_gating_list(self):
        self.prepare()
        code, out = run(self.root, "status", "0.1.2", "--date", D1)
        self.assertIn("gating: open person-one", out)
        shutil.rmtree(self.root / "backlog/items/person-one")
        commit(self.root, "done")
        code, out = run(self.root, "status", "0.1.2", "--date", D1)
        self.assertIn("gating: done person-one", out)


SEEDED = [
    ("source-version", release.PATH_SPL, "MINORB 2", "MINORB 3"),
    ("source-build", release.PATH_SPL, "BUILDNUMBER 186", "BUILDNUMBER 187"),
    ("build-history", release.PATH_SPL, "// 186 - Tandem Commander 0.1.2 (", "// 186 - Tandem Commander 0.1.3 ("),
    ("installer-version", release.PATH_ISS, '"0.1.2"', '"0.1.1"'),
    ("changelog-heading", release.PATH_CHANGELOG, "## [0.1.2] — 2026-11-02", "## [0.1.2] — 2026-11-01"),
    ("changelog-unreleased", release.PATH_CHANGELOG, "## [0.1.2]", "## [Unreleased]\n\n- x\n\n## [0.1.2]"),
    ("changelog-history", release.PATH_CHANGELOG, "## [0.1.0] — 2026-08-04", "## [0.0.9] — 2026-08-04"),
    ("changelog-lead", release.PATH_CHANGELOG, "**Build 186.** Bug-fix", "**Build 185.** Bug-fix"),
    ("winget-summary", release.PATH_CHANGELOG, "Two fixes.", "Two fixes. " + "Long text. " * 90),
    ("privacy-version", release.PATH_PRIVACY, "describes Tandem Commander 0.1.2", "describes Tandem Commander 0.1.1"),
    ("privacy-previous", release.PATH_PRIVACY, "In 0.1.1, the version", "In 0.1.0, the version"),
    ("privacy-date", release.PATH_PRIVACY, "Last updated 2026-11-02.", "Last updated 2026-11-01."),
    ("claude-product", release.PATH_CLAUDE, "release dated 2026-11-02;", "release dated 2026-11-01;"),
    ("claude-product", release.PATH_CLAUDE, "features 012–013;", "features 012–014;"),
    ("claude-status", release.PATH_CLAUDE, "prepared for the 0.1.2 release", "prepared for the next release"),
    ("claude-status", release.PATH_CLAUDE, "prepared for the 0.1.2 release.",
     "prepared for the 0.1.2 release, the tree prepared for the release (2026-11-01)."),
    ("reference-product", release.PATH_REFERENCE, "build 185 / tag", "build 184 / tag"),
    ("release-current", release.PATH_RELEASE, "Gating person steps:", "Person steps:"),
    ("release-current", release.PATH_RELEASE, "release (2026-11-02)", "release (2026-11-01)"),
    ("release-current", release.PATH_RELEASE, "features 012–013.", "features 012–012."),
    ("notes-header", "release_notes/release_notes_v0.1.2.md", "build 186", "build 185"),
    ("notes-sections", "release_notes/release_notes_v0.1.2.md", "## Fixed", "## Fixes"),
    ("notes-footer", "release_notes/release_notes_v0.1.2.md", "full detail in `CHANGELOG.md`", "details"),
    ("notes-issues", "release_notes/release_notes_v0.1.2.md", "(#4)", "(issue 4)"),
    ("notes-todo", "release_notes/release_notes_v0.1.2.md", "accented names.", "accented names. TODO"),
]


class Check(Base):
    def test_seeded_defects(self):
        self.prepare()
        for rule, rel, old, new in SEEDED:
            with self.subTest(rule=rule):
                original = (self.root / rel).read_bytes()
                replace(self.root, rel, old, new)
                code, out = run(self.root, "check", "0.1.2", "--date", D1)
                self.assertEqual(code, 1, out)
                self.assertIn(f": {rule}:", out)
                (self.root / rel).write_bytes(original)
        self.assertEqual(run(self.root, "check", "0.1.2", "--date", D1)[0], 0)

    def test_notes_missing_and_bom(self):
        self.prepare()
        p = self.root / "release_notes/release_notes_v0.1.2.md"
        p.write_bytes(b"\xef\xbb\xbf" + p.read_bytes())
        self.assertIn(": notes-encoding:", run(self.root, "check", "0.1.2", "--date", D1)[1])
        p.unlink()
        self.assertIn(": notes-missing:", run(self.root, "check", "0.1.2", "--date", D1)[1])

    def test_interface_text(self):
        replace(self.root, release.PATH_SPL, "LAST_VERSION_OF_SALAMANDER 105", "LAST_VERSION_OF_SALAMANDER 106")
        commit(self.root, "interface")
        self.prepare()
        replace(self.root, release.PATH_SPL, "first shipped in version 0.1.2.", "first shipped in version 0.1.0.")
        self.assertIn(": interface-text:", run(self.root, "check", "0.1.2", "--date", D1)[1])

    def test_next_version_privacy_chain(self):
        """0.1.3 after a published 0.1.2: the empty "nothing differed" clause is dropped."""
        self.prepare()
        git(self.root, "tag", "-a", "v0.1.2", "-m", "")
        cl = read(self.root, release.PATH_CHANGELOG)
        write(self.root, release.PATH_CHANGELOG,
              cl.replace("## [0.1.2]", "## [Unreleased]\n\n- **Later** (feature 016).\n\n## [0.1.2]", 1))
        commit(self.root, "0.1.3 work")
        code, out = run(self.root, "stamp", "0.1.3", "--date", D2)
        self.assertEqual(code, 0, out)
        pv = read(self.root, release.PATH_PRIVACY)
        self.assertIn("describes Tandem Commander 0.1.3 (`CHANGELOG.md`). In 0.1.2, the version before it, "
                      "TODO-PRIVACY. In 0.1.0: the SFTP log kept", pv)
        self.assertNotIn("nothing described here differed", pv)
        self.assertIn("carries features 016; previous: 0.1.2 / build 186", read(self.root, release.PATH_CLAUDE))
        self.assertIn("#define VERSINFO_BUILDNUMBER 187", read(self.root, release.PATH_SPL))

    def test_single_feature_range(self):
        ns = type("C", (), {"features": {244}})()
        self.assertEqual(release.feature_range(ns, "x"), "244")
        ns.features = {12, 13}
        self.assertEqual(release.feature_range(ns, "x"), "012–013")

    def test_published_notes_of_0_1_9_pass(self):
        notes = REAL_ROOT / "release_notes/release_notes_v0.1.9.md"
        if not notes.is_file():
            self.skipTest("no published 0.1.9 notes")
        cl = (REAL_ROOT / "CHANGELOG.md").read_text(encoding="utf-8").replace("\r\n", "\n")
        sec = cl[cl.index("## [0.1.9]"):cl.index("## [0.1.8]")]
        text = notes.read_bytes().decode("utf-8").replace("\r\n", "\n")
        f = release.check_notes(text, "n", "0.1.9", 193, dt.date(2026, 10, 7), release.issue_numbers(sec))
        self.assertEqual([str(x) for x in f], [])


if __name__ == "__main__":
    unittest.main()
