# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Tests of tools/backlog/traces.py (feature 342).

Run from the repository root:  python -m unittest tools/backlog/test_traces.py -v

The pure parts of the trace format: names, the lines written before an
attempt, meta.json and the index line, the commit filter, the size walk, and
the copy of the logs of the loop before 342.  The loop's use of them is
tested in test_loop.py.
"""

import datetime as dt
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import traces  # noqa: E402

OLD = HERE / "fixtures" / "old_logs"
META_KEYS = ["format_version", "kind", "slug", "harness", "harness_version", "model", "session_id", "started",
             "ended", "phase", "outcome", "feature", "branch", "commits", "why", "attempts", "counters", "loop"]
INDEX_KEYS = ["dir", "kind", "slug", "harness", "model", "started", "ended", "phase", "outcome", "feature",
              "attempts"]


def git(root, *args, env=None):
    return subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True, text=True,
                          env=env).stdout


class TmpCase(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp(prefix="traces342-"))

    def tearDown(self):
        shutil.rmtree(self.tmp, ignore_errors=True)


class NameTests(TmpCase):
    def test_iso_local_has_the_offset(self):
        t = dt.datetime(2026, 10, 25, 14, 2, 0).timestamp()
        s = traces.iso_local(t)
        self.assertTrue(s.startswith("2026-10-25T14:02:00"), s)
        self.assertRegex(s, r"[+-]\d\d:\d\d$")
        self.assertIsNone(traces.iso_local(None))

    def test_run_dir_names_and_suffixes(self):
        t = dt.datetime(2026, 10, 25, 14, 2, 0).timestamp()
        a = traces.new_run_dir(self.tmp, "some-slug", t)
        b = traces.new_run_dir(self.tmp, "some-slug", t)
        c = traces.new_run_dir(self.tmp, "some-slug", t)
        d = traces.new_run_dir(self.tmp, "triage", t)
        self.assertEqual(a.name, "20261025-140200-claude-some-slug")
        self.assertEqual(b.name, "20261025-140200-claude-some-slug-2")
        self.assertEqual(c.name, "20261025-140200-claude-some-slug-3")
        self.assertEqual(d.name, "20261025-140200-claude-triage")
        self.assertEqual(a.parent, self.tmp / ".agent-traces")


class LineTests(unittest.TestCase):
    def test_separator_bytes(self):
        line = traces.separator_line(2, "continue", "usage-limit", "2026-10-25T15:10:03+02:00", "abc")
        self.assertEqual(line, b'{"type":"backlog_loop.attempt","attempt":2,"kind":"continue","reason":"usage-limit",'
                               b'"started":"2026-10-25T15:10:03+02:00","harness":"claude","session_id":"abc"}\n')

    def test_header_bytes(self):
        self.assertEqual(traces.stderr_header(1, "start", "-", "2026-10-25T14:02:00+02:00"),
                         b"=== attempt 1 (start, -) 2026-10-25T14:02:00+02:00 ===\n")

    def test_unknown_reason_or_kind_is_refused(self):
        for kind, reason in (("start", "restart"), ("start", "x"), ("resume", "-")):
            with self.subTest(kind=kind, reason=reason):
                with self.assertRaises(ValueError):
                    traces.separator_line(1, kind, reason, "t", None)
                with self.assertRaises(ValueError):
                    traces.stderr_header(1, kind, reason, "t")
        for reason in traces.REASONS:
            traces.separator_line(1, "continue", reason, "t", None)

    def test_attempt_record_keys(self):
        a = traces.attempt_record(1, "start", "-", "t")
        self.assertEqual(list(a), ["attempt", "kind", "reason", "started", "ended", "ending", "error_kind",
                                   "resets_at", "exit_code", "idle_killed", "usage"])


class WriteTests(TmpCase):
    def test_atomic_write_leaves_no_temporary_file(self):
        p = self.tmp / "a" / "meta.json"
        traces.write_json_atomic(p, {"x": 1})
        traces.write_json_atomic(p, {"x": 2})
        self.assertEqual(json.loads(p.read_text(encoding="utf-8")), {"x": 2})
        self.assertEqual([q.name for q in p.parent.iterdir()], ["meta.json"])

    def test_append_line(self):
        p = self.tmp / "index.jsonl"
        traces.append_line(p, {"a": "ž"})
        traces.append_line(p, {"b": 2})
        self.assertEqual(p.read_bytes(), '{"a":"ž"}\n{"b":2}\n'.encode("utf-8"))


class MetaTests(unittest.TestCase):
    def record(self):
        return {"kind": "item", "slug": "s", "session": "u", "started_epoch": 1_792_000_000.0,
                "trace_attempts": [traces.attempt_record(1, "start", "-", "t1"),
                                   traces.attempt_record(2, "continue", "usage-limit", "t2")],
                "limits": 1, "attempts": 2, "stalls": 3, "nudges": 4}

    def test_meta_keys_values_and_counters(self):
        m = traces.build_meta(self.record(), phase="done", ended="e", outcome="closed", feature="343",
                              branch="343-s", commits=["a1"], why=None,
                              loop_info={"pid": 7, "host": "h", "auto_triage": True},
                              harness_version="2.1.310", model="m")
        self.assertEqual(list(m), META_KEYS)
        self.assertEqual(m["format_version"], 1)
        self.assertEqual(m["harness"], "claude")
        self.assertEqual(m["started"], traces.iso_local(1_792_000_000.0))
        self.assertEqual(m["counters"], {"limits": 1, "errors": 2, "stalls": 3, "idles": 4, "restarts": 0})
        self.assertEqual(m["loop"], {"pid": 7, "host": "h", "auto_triage": True})
        self.assertEqual(len(m["attempts"]), 2)
        self.assertNotIn("imported", m)

    def test_unknown_values_are_null(self):
        m = traces.build_meta({"slug": "s"}, phase=None, ended=None, outcome=None, feature=None, branch=None,
                              commits=[], why=None, loop_info={}, harness_version=None, model=None)
        for k in ("harness_version", "model", "session_id", "started", "ended", "phase", "outcome", "feature",
                  "branch", "why"):
            self.assertIsNone(m[k], k)
        self.assertEqual(m["kind"], "item")
        self.assertEqual(m["attempts"], [])

    def test_index_line(self):
        m = traces.build_meta(self.record(), phase="done", ended="e", outcome="closed", feature="343",
                              branch="b", commits=[], why=None, loop_info={}, harness_version=None, model="m")
        line = traces.build_index_line(m, "d")
        self.assertEqual(list(line), INDEX_KEYS)
        self.assertEqual(line["attempts"], 2)
        self.assertEqual(line["dir"], "d")


class CommitTests(TmpCase):
    def test_commit_filter(self):
        m = traces.commit_matches
        self.assertTrue(m("[343] the fix", slug="s", feature="343", kind="item"))
        self.assertFalse(m("[3430] other", slug="s", feature="343", kind="item"))
        self.assertTrue(m("backlog: s blocked (343)", slug="s", feature=None, kind="item"))
        self.assertFalse(m("backlog: s-longer blocked", slug="s", feature=None, kind="item"))
        self.assertFalse(m("backlog: auto-triage - 1 placed", slug="s", feature=None, kind="item"))
        self.assertTrue(m("backlog: auto-triage - 1 placed", slug="triage", feature=None, kind="triage"))
        self.assertFalse(m("[343] x", slug="triage", feature=None, kind="triage"))

    def test_run_commits_from_git(self):
        repo = self.tmp / "r"
        repo.mkdir()
        git(repo, "init", "-q", "-b", "main")
        git(repo, "config", "user.email", "t@example.invalid")
        git(repo, "config", "user.name", "t")
        base = int(time.time()) - 600
        subjects = ["fixture", "[343] specify", "backlog: other-slug x", "backlog: some-slug blocked (343)",
                    "backlog: auto-triage - 1 placed", "[343] merge main"]
        for i, s in enumerate(subjects):
            (repo / f"f{i}").write_text(s, encoding="utf-8")
            git(repo, "add", "-A")
            when = f"@{base + 60 * i} +0000"
            env = dict(os.environ, GIT_COMMITTER_DATE=when, GIT_AUTHOR_DATE=when)
            git(repo, "commit", "-q", "-m", s, env=env)
        hashes = git(repo, "log", "--reverse", "--format=%h").split()
        got = traces.run_commits(repo, base + 30, None, slug="some-slug", feature="343", kind="item")
        self.assertEqual(got, [hashes[1], hashes[3], hashes[5]])
        got = traces.run_commits(repo, base + 30, base + 200, slug="some-slug", feature="343", kind="item")
        self.assertEqual(got, [hashes[1], hashes[3]])
        got = traces.run_commits(repo, base + 30, None, slug="some-slug", feature=None, kind="item")
        self.assertEqual(got, [hashes[3]])
        got = traces.run_commits(repo, base - 100, None, slug="triage", feature=None, kind="triage")
        self.assertEqual(got, [hashes[4]])
        # with the run's base (HEAD at its start) time plays no part: only commits after it count
        full = git(repo, "log", "--reverse", "--format=%H").split()
        got = traces.run_commits(repo, 0, None, slug="some-slug", feature="343", kind="item", base=full[2])
        self.assertEqual(got, [hashes[3], hashes[5]])
        got = traces.run_commits(repo, 0, None, slug="triage", feature=None, kind="triage", base=full[4])
        self.assertEqual(got, [])
        self.assertEqual(traces.run_commits(self.tmp / "none", base, None, slug="s", feature=None, kind="item"), [])


class SizeTests(TmpCase):
    def test_size_and_format(self):
        self.assertEqual(traces.traces_size(self.tmp), 0)
        d = traces.new_run_dir(self.tmp, "s", time.time())
        (d / "trace.jsonl").write_bytes(b"x" * 1000)
        (d / "stderr.log").write_bytes(b"y" * 24)
        traces.append_line(self.tmp / ".agent-traces" / "index.jsonl", {})
        self.assertEqual(traces.traces_size(self.tmp), 1024 + 3)
        self.assertEqual(traces.format_size(5), "5 B")
        self.assertEqual(traces.format_size(1536), "1.5 kB")
        self.assertEqual(traces.format_size(547 * 1024 * 1024), "547.0 MB")
        self.assertEqual(traces.format_size(5 * 1024 ** 3), "5.0 GB")

    def test_status_size_of_1000_runs_is_fast(self):
        """SC-004: the walk costs one stat per file, whatever the file sizes, so 1,000 folders of
        three small files stand for 1,000 folders of 5 GB."""
        top = self.tmp / ".agent-traces"
        expected = 0
        for i in range(1000):
            d = top / f"20261025-{i:06d}-claude-s"
            d.mkdir(parents=True)
            for name, n in (("trace.jsonl", i % 7 + 1), ("stderr.log", 1), ("meta.json", 2)):
                (d / name).write_bytes(b"x" * n)
                expected += n
        t0 = time.perf_counter()
        size = traces.traces_size(self.tmp)
        took = time.perf_counter() - t0
        self.assertEqual(size, expected)
        self.assertLess(took, 2.0, f"{took:.2f} s")


class OldLogTests(TmpCase):
    def test_parse_old_name(self):
        started = dt.datetime(2026, 10, 24, 12, 17, 38).timestamp()
        self.assertEqual(traces.parse_old_name("20261024-121738-some-slug"), (started, "some-slug", "item"))
        self.assertEqual(traces.parse_old_name("20261024-121738-auto-triage"), (started, "triage", "triage"))
        self.assertIsNone(traces.parse_old_name("notes"))
        self.assertEqual(traces.new_name_for_old("20261024-121738-auto-triage"), "20261024-121738-claude-triage")
        self.assertEqual(traces.new_name_for_old("20261024-121738-x"), "20261024-121738-claude-x")

    def test_runs_row_matching(self):
        rows = [["2026-10-24 10:00", "s", "blocked", "-", "-"],
                ["2026-10-24 12:17", "other", "closed", "340", "340-x"],
                ["2026-10-24 12:49", "s", "closed", "341", "341-s"],
                ["2026-10-24 15:00", "s", "closed", "342", "342-s"]]
        started = dt.datetime(2026, 10, 24, 12, 17, 38).timestamp()
        nxt = dt.datetime(2026, 10, 24, 13, 0, 0).timestamp()
        self.assertEqual(traces.match_runs_row(rows, "s", started, nxt)[3], "341")
        self.assertEqual(traces.match_runs_row(rows, "s", started, None)[3], "341")
        late = dt.datetime(2026, 10, 24, 12, 50, 0).timestamp()
        self.assertIsNone(traces.match_runs_row(rows, "s", late, nxt))  # its row would be at or after 12:50
        self.assertIsNone(traces.match_runs_row(rows, "none", started, None))
        same_minute = dt.datetime(2026, 10, 24, 12, 17, 0).timestamp()
        self.assertEqual(traces.match_runs_row(rows, "other", same_minute + 5, None)[3], "340")

    def test_first_init(self):
        p = self.tmp / "t.jsonl"
        p.write_text("\n".join(json.dumps(o) for o in (
            {"type": "assistant", "message": {"content": "init"}},
            {"type": "system", "subtype": "init", "session_id": "u", "model": "m1"},
            {"type": "system", "subtype": "init", "session_id": "u", "model": "m2"})) + "\n", encoding="utf-8")
        self.assertEqual(traces.first_init(p), ("u", "m1"))
        self.assertEqual(traces.first_init(self.tmp / "none"), (None, None))

    def test_import_of_the_fixture_logs(self):
        logs = self.tmp / "logs"
        shutil.copytree(OLD, logs)
        before = {p.name: p.read_bytes() for p in logs.iterdir()}
        rows = [["2026-10-24 12:49", "iso-plug-in-an-nrg-session-count-above-the-image-s-tracks", "closed", "340",
                 "340-nrg-session-count", "2", "-", "n"],
                ["2026-10-24 14:46", "ftp-an-upload-to-a-server-named-another-way-localhost-vs-127", "closed", "341",
                 "341-ftp-upload-cache-alias", "3", "-", "n"]]
        imported, skipped = traces.import_old_logs(self.tmp, logs, rows, {"20261023-000000-skip-me"}, {})
        self.assertEqual((imported, skipped), (4, 1))
        self.assertEqual({p.name: p.read_bytes() for p in logs.iterdir()}, before)  # never written
        top = self.tmp / ".agent-traces"
        index = [json.loads(l) for l in (top / "index.jsonl").read_text(encoding="utf-8").splitlines()]
        self.assertEqual([i["dir"] for i in index], sorted(i["dir"] for i in index))  # start order
        by = {i["dir"]: i for i in index}
        for stem in [s for s in {p.stem for p in logs.iterdir()} if s != "20261023-000000-skip-me"]:
            name = traces.new_name_for_old(stem)
            with self.subTest(stem):
                self.assertIn(name, by)
                self.assertEqual((top / name / "trace.jsonl").read_bytes(), (logs / f"{stem}.jsonl").read_bytes())
                self.assertEqual((top / name / "stderr.log").read_bytes(), (logs / f"{stem}.err").read_bytes())
                meta = json.loads((top / name / "meta.json").read_text(encoding="utf-8"))
                self.assertEqual(list(meta)[:len(META_KEYS)], META_KEYS)
                self.assertTrue(meta["imported"])
                self.assertEqual(list(by[name]), INDEX_KEYS)
        closed = by["20261024-121738-claude-iso-plug-in-an-nrg-session-count-above-the-image-s-tracks"]
        self.assertEqual((closed["outcome"], closed["feature"], closed["phase"], closed["attempts"]),
                         ("closed", "340", "done", None))  # attempts unknown in old logs
        cont = by["20261024-125035-claude-ftp-an-upload-to-a-server-named-another-way-localhost-vs-127"]
        self.assertEqual((cont["outcome"], cont["feature"], cont["model"]), ("closed", "341", "claude-opus-5-5[1m]"))
        tri = by["20261024-124945-claude-triage"]
        self.assertEqual((tri["kind"], tri["slug"], tri["outcome"]), ("triage", "triage", "triaged"))
        orphan = by["20261020-090000-claude-a-run-without-a-journal-row"]
        self.assertEqual((orphan["outcome"], orphan["phase"]), (None, None))
        meta = json.loads((top / closed["dir"] / "meta.json").read_text(encoding="utf-8"))
        self.assertEqual(meta["branch"], "340-nrg-session-count")
        self.assertEqual(meta["session_id"], "11111111-1111-4111-8111-111111111111")
        self.assertEqual(meta["model"], "claude-opus-5-5[1m]")
        self.assertEqual(meta["attempts"], [])
        self.assertIsNone(meta["counters"]["errors"])
        self.assertEqual(meta["commits"], [])  # no git repository around the fixture
        # a second import finds every folder and adds nothing
        self.assertEqual(traces.import_old_logs(self.tmp, logs, rows, {"20261023-000000-skip-me"}, {}), (0, 5))
        self.assertEqual(len((top / "index.jsonl").read_text(encoding="utf-8").splitlines()), 4)


if __name__ == "__main__":
    unittest.main()
