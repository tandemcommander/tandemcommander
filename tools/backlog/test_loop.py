# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Tests of tools/backlog/loop.py and its wrappers (feature 247).

Run from the repository root:  python -m unittest tools/backlog/test_loop.py -v

Every test works in a temporary git repository made from fixtures/valid,
with fixtures/fake_claude.py in place of `claude` (a plan of steps per test).
The loop runs in-process when only its decisions matter, and as a separate
process when pause / stop / Ctrl+Break / a second loop are tested.
"""

import contextlib
import datetime as dt
import io
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import backlog  # noqa: E402
import loop  # noqa: E402
import traces  # noqa: E402

VALID = HERE / "fixtures" / "valid"
FAKE = HERE / "fixtures" / "fake_claude.py"
LOOP = HERE / "loop.py"
BIN = HERE.parents[1] / "bin" / "backlog-loop.sh"
OLD_LOGS = HERE / "fixtures" / "old_logs"
META_KEYS = ["format_version", "kind", "slug", "harness", "harness_version", "model", "session_id", "started",
             "ended", "phase", "outcome", "feature", "branch", "commits", "why", "attempts", "counters", "loop"]
INDEX_KEYS = ["dir", "kind", "slug", "harness", "model", "started", "ended", "phase", "outcome", "feature",
              "attempts"]
FTP = "ftp-per-server-encoding-flag"
DISK = "disk-map-context-menu-crash"
FAST = ["--poll", "0.2", "--tick", "0.05", "--backoff", "0.1,0.2", "--limit-margin", "0",
        "--limit-unknown-wait", "0.3", "--deadline", "60"]


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


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True, text=True).stdout


class Base(unittest.TestCase):
    def setUp(self):
        os.environ.pop("TANDEM_BACKLOG_NOW", None)
        self.tmp = Path(tempfile.mkdtemp(prefix="loop247-"))
        self.root = self.tmp / "repo"
        shutil.copytree(VALID, self.root)
        git(self.root, "init", "-q", "-b", "main")
        git(self.root, "config", "user.email", "t@example.invalid")
        git(self.root, "config", "user.name", "t")
        git(self.root, "config", "core.autocrlf", "false")
        git(self.root, "add", "-A")
        git(self.root, "commit", "-q", "-m", "fixture")
        self.plan = self.tmp / "plan.json"
        os.environ["FAKE_CLAUDE_PLAN"] = str(self.plan)
        self.repo = loop.Repo(self.root)
        self.handlers = {s: signal.getsignal(s) for s in self.signals()}
        self.procs = []

    def tearDown(self):
        for p in self.procs:
            if p.poll() is None:
                loop.kill_tree(p.pid)
                p.wait(timeout=30)
        for s, h in self.handlers.items():
            signal.signal(s, h)
        os.environ.pop("FAKE_CLAUDE_PLAN", None)
        shutil.rmtree(self.tmp, ignore_errors=True)

    @staticmethod
    def signals():
        out = [signal.SIGINT]
        if os.name == "nt":
            out.append(signal.SIGBREAK)
        return out

    # -- helpers -------------------------------------------------------

    def bl(self, *args):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = backlog.main(["--root", str(self.root), *args])
        self.assertIn(code, (0,), buf.getvalue())
        return buf.getvalue()

    def commit(self, msg="test"):
        git(self.root, "add", "-A")
        git(self.root, "commit", "-q", "-m", msg)

    def add_items(self, n):
        """n more open items at the end of Next; returns their slugs."""
        slugs = []
        for i in range(n):
            slug = f"extra-item-{i + 1}"
            self.bl("new", "--title", f"Extra item {i + 1}", "--type", "bug", "--severity", "3", "--area", "tooling",
                    "--slug", slug, "--problem", "p", "--evidence", "e", "--expected", "x")
            self.bl("move", slug, "--section", "next")
            slugs.append(slug)
        self.commit("extra items")
        return slugs

    def write_plan(self, steps):
        self.plan.write_text(json.dumps({"steps": steps, "calls": []}), encoding="utf-8")

    def calls(self):
        return json.loads(self.plan.read_text(encoding="utf-8"))["calls"]

    def start_args(self, *extra):
        return ["start", "--root", str(self.root), "--claude-cmd", json.dumps([sys.executable, str(FAKE)]),
                *FAST, *extra]

    def run_loop(self, *extra):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = loop.main(self.start_args(*extra))
        return code, buf.getvalue()

    def ctl(self, *args):
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = loop.main([args[0], "--root", str(self.root), *args[1:]])
        return code, buf.getvalue()

    def spawn_loop(self, *extra):
        out = open(self.tmp / f"loop-{len(self.procs)}.out", "wb")
        flags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
        p = subprocess.Popen([sys.executable, "-u", str(LOOP), *self.start_args(*extra)], stdout=out,
                             stderr=subprocess.STDOUT, creationflags=flags)
        p.out_path = out.name
        out.close()
        self.procs.append(p)
        return p

    def output(self, p):
        return Path(p.out_path).read_text(encoding="utf-8", errors="replace")

    def wait_for(self, cond, timeout=30.0, what="condition"):
        end = time.time() + timeout
        while time.time() < end:
            if cond():
                return
            time.sleep(0.05)
        self.fail(f"timed out waiting for {what}")

    def loop_state(self):
        return (loop.load_json(self.repo.loop_file) or {}).get("state")

    def runs(self):
        return self.repo.runs()

    def lock_slug(self):
        return (self.repo.lock() or {}).get("slug")

    # -- traces (feature 342) ------------------------------------------

    def trace_dirs(self):
        top = self.root / ".agent-traces"
        return sorted(p for p in top.iterdir() if p.is_dir()) if top.is_dir() else []

    def index(self):
        p = self.root / ".agent-traces" / "index.jsonl"
        return [json.loads(l) for l in p.read_text(encoding="utf-8").splitlines()] if p.exists() else []

    def check_trace(self, d, *, kind="item", slug=None, reasons=("-",), phase="done", outcome=None):
        """A run folder against contracts/traces.md; returns its meta."""
        text = (d / "trace.jsonl").read_text(encoding="utf-8").splitlines()
        lines = [json.loads(l) for l in text if l.startswith("{")]  # the fake also prints plain lines
        self.assertTrue(text[0].startswith('{"type":"backlog_loop.attempt"'), text[0])
        seps = [o for o in lines if o.get("type") == "backlog_loop.attempt"]
        self.assertEqual([s["reason"] for s in seps], list(reasons), d.name)
        self.assertEqual([s["attempt"] for s in seps], list(range(1, len(reasons) + 1)))
        self.assertEqual([s["kind"] for s in seps], ["start"] + ["continue"] * (len(reasons) - 1))
        self.assertEqual(lines[0]["type"], "backlog_loop.attempt")  # before anything claude wrote
        for s in seps:
            self.assertEqual(s["harness"], "claude")
            self.assertRegex(s["started"], r"^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d[+-]\d\d:\d\d$")
        headers = [l for l in (d / "stderr.log").read_text(encoding="utf-8").splitlines() if l.startswith("=== attempt ")]
        self.assertEqual(len(headers), len(reasons))
        meta = json.loads((d / "meta.json").read_text(encoding="utf-8"))
        self.assertEqual(list(meta), META_KEYS)
        self.assertEqual((meta["kind"], meta["harness"], meta["phase"], meta["outcome"]),
                         (kind, "claude", phase, outcome), d.name)
        self.assertEqual(len(meta["attempts"]), len(reasons))
        self.assertEqual([a["reason"] for a in meta["attempts"]], list(reasons))
        if slug is not None:
            self.assertEqual(meta["slug"], slug)
            self.assertTrue(d.name.endswith(f"-claude-{slug}"), d.name)
        self.assertEqual(meta["model"], "fake-model")
        self.assertEqual(meta["session_id"], seps[0]["session_id"])
        if phase in ("done", "failed", "lost"):
            self.assertIsNotNone(meta["ended"])
            for a in meta["attempts"]:
                self.assertIsNotNone(a["ended"])
                self.assertIn(a["ending"], ("success", "error", "interrupted"))
        return meta

    def assert_clean_tree(self):
        self.assertEqual(git(self.root, "status", "--porcelain"), "")
        self.assertFalse((self.repo.dir / "logs").exists())

    def pending_record(self, phase, **extra):
        self.repo.dir.mkdir(parents=True, exist_ok=True)
        run = {"slug": FTP, "session": "22222222-2222-4222-8222-222222222222", "started": loop.stamp(time.time() - 60),
               "log": str(self.tmp / "p.jsonl"), "err": str(self.tmp / "p.err"), "rows_before": len(self.runs()),
               "attempts": 0, "stalls": 0, "resumes": 0, "limits": 0, "lock_started": None, "phase": phase,
               "wait_until": None, "why": None, "child_pid": None, "child_ident": None}
        run.update(extra)
        loop.save_json(self.repo.run_file, run)
        return run

    # -- feature 344 ---------------------------------------------------

    def last(self):
        return loop.load_json(self.repo.dir / "last.json")

    def loop_log(self):
        p = self.repo.dir / "loop.log"
        return p.read_text(encoding="utf-8") if p.exists() else ""

    def write_edit_lock(self, pid, epoch, purpose="move an item"):
        started = dt.datetime.fromtimestamp(epoch).strftime("%Y-%m-%dT%H:%M:%S")
        path = self.repo.dir.parent / "tandem-backlog-edit.lock"
        path.write_text(f"pid: {pid}\nstarted_epoch: {epoch}\nstarted: {started}\npurpose: {purpose}\n",
                        encoding="utf-8")
        return path, started


class RunTests(Base):
    def test_items_one_after_another_then_idle(self):
        self.bl("unblock", DISK)
        self.commit()
        self.write_plan(["close", "close"])
        before = len(self.runs())
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        calls = self.calls()
        self.assertEqual([c["slug"] for c in calls], [FTP, DISK])  # Next order; DISK depended on FTP
        for c in calls:
            self.assertEqual(c["prompt"], f"/tandem-backlog-implement {c['slug']}")
            self.assertFalse(c["resume"])
            self.assertEqual(c["watchdog"], "1")
            self.assertEqual(c["bg_ceiling"], loop.BG_WAIT_CEILING_MS)  # a reviewer outlives the turn (341)
            self.assertEqual(Path(c["cwd"]).resolve(), self.root.resolve())
            argv = c["argv"]
            for flag, value in (("--output-format", "stream-json"), ("--permission-mode", "bypassPermissions")):
                self.assertEqual(argv[argv.index(flag) + 1], value)
            self.assertIn("--verbose", argv)
        self.assertNotEqual(calls[0]["session"], calls[1]["session"])
        rows = self.runs()
        self.assertEqual(len(rows), before + 2)
        self.assertEqual([r[2] for r in rows[-2:]], ["closed", "closed"])
        self.assertIn("closed 2", out)
        self.assertIn("nothing eligible", out)
        self.assertFalse(self.repo.loop_file.exists())
        self.assertFalse(self.repo.run_file.exists())
        self.assertEqual(len(self.trace_dirs()), 2)
        dirs = [self.root / ".agent-traces" / i["dir"] for i in self.index()]  # in the order the runs ended
        for d, slug in zip(dirs, (FTP, DISK)):
            meta = self.check_trace(d, slug=slug, outcome="closed")
            row = next(r for r in rows if r[1] == slug)
            feature = row[3]
            self.assertRegex(feature, r"^9\d\d$")
            self.assertEqual((meta["feature"], meta["branch"]), (feature, f"{feature}-{slug}"))
            subjects = [git(self.root, "log", "-1", "--format=%s", h).strip() for h in meta["commits"]]
            self.assertEqual(subjects, [f"[{feature}] fake: {slug} closed"])
            self.assertEqual(meta["attempts"][0]["ending"], "success")
            self.assertEqual(meta["attempts"][0]["exit_code"], 0)
            self.assertEqual(meta["attempts"][0]["usage"], {"input_tokens": 1, "output_tokens": 1})
            self.assertEqual(meta["loop"]["auto_triage"], False)
            self.assertIsNone(meta["harness_version"])  # --claude-cmd is not asked for its version
        index = self.index()
        self.assertEqual([i["dir"] for i in index], [d.name for d in dirs])
        self.assertEqual([list(i) for i in index], [INDEX_KEYS] * 2)
        self.assertEqual([(i["outcome"], i["attempts"]) for i in index], [("closed", 1)] * 2)
        self.assert_clean_tree()

    def test_caller_watchdog_setting_is_kept(self):
        self.write_plan(["close"])
        os.environ["CLAUDE_CODE_RETRY_WATCHDOG"] = "0"
        os.environ["CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS"] = "0"
        try:
            self.run_loop("--until-idle")
        finally:
            os.environ.pop("CLAUDE_CODE_RETRY_WATCHDOG")
            os.environ.pop("CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS")
        self.assertEqual(self.calls()[0]["watchdog"], "0")
        self.assertEqual(self.calls()[0]["bg_ceiling"], "0")

    def test_model_is_passed(self):
        self.write_plan(["close"])
        self.run_loop("--until-idle", "--model", "haiku")
        argv = self.calls()[0]["argv"]
        self.assertEqual(argv[argv.index("--model") + 1], "haiku")

    def test_max_items(self):
        self.add_items(2)
        self.write_plan(["close", "close", "close"])
        code, out = self.run_loop("--max-items", "2")
        self.assertEqual(code, 0, out)
        self.assertEqual(len(self.calls()), 2)
        self.assertIn("--max-items", out)

    def test_blocked_in_a_row_stop_the_loop(self):
        self.add_items(4)
        self.write_plan(["block", "close", "block", "block", "close"])
        code, out = self.run_loop("--max-blocked", "2")
        self.assertEqual(code, 1, out)
        self.assertEqual([c["step"] for c in self.calls()], ["block", "close", "block", "block"])
        self.assertIn("2 runs in a row ended blocked", out)
        self.assertIn("blocked 3", out)

    def test_split_and_not_reproduced_count_and_reset_the_streak(self):
        self.add_items(3)
        self.write_plan(["block", "split", "block", "notrepro", "block"])
        code, out = self.run_loop("--max-blocked", "2", "--until-idle")
        self.assertEqual(code, 0, out)
        self.assertIn("split 1", out)
        self.assertIn("not-reproduced 1", out)

    def test_usage_limit_continues_the_same_session_after_the_reset(self):
        self.write_plan([{"do": "limit", "in": 2}, "close"])
        t0 = time.time()
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        first, second = self.calls()
        self.assertTrue(second["resume"])
        self.assertEqual(second["session"], first["session"])
        self.assertIn("interrupted (a usage limit)", second["prompt"])
        self.assertGreaterEqual(time.time() - t0, 1.0)  # resetsAt = int(now + 2) >= now + 1
        self.assertEqual(self.runs()[-1][2], "closed")
        self.assertIn("interrupted by a usage limit", out)
        (d,) = self.trace_dirs()  # one run, one folder, two attempts
        meta = self.check_trace(d, slug=FTP, reasons=("-", "usage-limit"), outcome="closed")
        first = meta["attempts"][0]
        self.assertEqual((first["ending"], first["error_kind"]), ("error", "usage-limit"))
        self.assertIsNotNone(first["resets_at"])
        self.assertEqual(meta["counters"]["limits"], 1)
        self.assertEqual(len(self.index()), 1)
        self.assert_clean_tree()

    def test_usage_limit_without_a_reset_time_waits_the_default(self):
        self.write_plan(["limit-noreset", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertTrue(self.calls()[1]["resume"])

    def test_errors_are_continued_after_a_pause(self):
        self.write_plan(["crash", "crash", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        calls = self.calls()
        self.assertEqual([c["resume"] for c in calls], [False, True, True])
        self.assertEqual(len({c["session"] for c in calls}), 1)
        self.assertIn("fake: boom", out)
        (d,) = self.trace_dirs()
        meta = self.check_trace(d, slug=FTP, reasons=("-", "error", "error"), outcome="closed")
        self.assertEqual([a["ending"] for a in meta["attempts"]], ["interrupted", "interrupted", "success"])
        self.assertEqual(meta["counters"]["errors"], 2)
        self.assertIn("fake: boom", (d / "stderr.log").read_text(encoding="utf-8"))

    def test_too_many_errors_stop_and_the_record_stays(self):
        self.write_plan(["crash", "crash", "crash", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual(len(self.calls()), 3)
        run = loop.load_json(self.repo.run_file)
        self.assertEqual(run["phase"], "failed")
        (d,) = self.trace_dirs()
        self.check_trace(d, slug=FTP, reasons=("-", "error", "error"), phase="failed")
        self.assertEqual([i["phase"] for i in self.index()], ["failed"])  # indexed at the stop for a person
        _, status = self.ctl("status")
        self.assertIn("cannot be continued automatically", status)
        self.assertIn("--forget-run", status)
        self.assertIn(f"trace:   {d}", status)
        # a new start refuses to guess
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual(len(self.calls()), 3)
        # the maintainer cleans up and starts with --forget-run
        self.bl("lock", "release", "--force")
        code, out = self.run_loop("--until-idle", "--forget-run")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.calls()[-1]["step"], "close")
        self.assertFalse(self.calls()[-1]["resume"])
        # --forget-run did not index the failed run a second time; the new run has its own folder
        self.assertEqual([i["phase"] for i in self.index()], ["failed", "done"])
        self.assertEqual(len(self.trace_dirs()), 2)

    def test_a_turn_ended_early_is_continued_at_most_twice(self):
        self.write_plan(["stall", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertEqual([c["resume"] for c in self.calls()], [False, True])
        (d,) = self.trace_dirs()
        self.check_trace(d, slug=FTP, reasons=("-", "stall"), outcome="closed")
        self.tearDown()
        self.setUp()
        self.write_plan(["stall", "stall", "stall", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual(len(self.calls()), 3)
        self.assertIn("without finishing", out)

    def test_a_run_that_waits_for_nothing_is_stopped_and_continued_with_a_reminder(self):
        # seen in 320: the reviewer was killed, the run kept scheduling no-op wakeups
        self.write_plan([{"do": "idle", "seconds": 30}, "close"])
        started = time.time()
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertLess(time.time() - started, 20, "the idle run was not stopped")
        calls = self.calls()
        self.assertEqual([c["resume"] for c in calls], [False, True])
        self.assertIn("launch it again now instead of waiting", calls[1]["prompt"])
        self.assertEqual(calls[1]["session"], calls[0]["session"])
        self.assertIn("waits for nothing", out)
        self.assertEqual(self.runs()[-1][2], "closed")
        (d,) = self.trace_dirs()
        meta = self.check_trace(d, slug=FTP, reasons=("-", "idle"), outcome="closed")
        self.assertTrue(meta["attempts"][0]["idle_killed"])
        self.assertFalse(meta["attempts"][1]["idle_killed"])
        self.assertEqual(meta["counters"]["idles"], 1)

    def test_wakeups_while_a_background_task_runs_are_not_idling(self):
        self.write_plan([{"do": "idle-busy", "seconds": 1}])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertEqual([c["resume"] for c in self.calls()], [False])
        self.assertNotIn("waits for nothing", out)
        self.assertEqual(self.runs()[-1][2], "closed")

    def test_waiting_for_nothing_is_continued_at_most_max_nudges_times(self):
        self.write_plan([{"do": "idle", "seconds": 30}] * (loop.MAX_NUDGES + 1) + ["close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual(len(self.calls()), loop.MAX_NUDGES + 1)
        self.assertIn("waited for nothing", out)

    def test_idle_counting_in_the_log(self):
        def info_of(*objs):
            info = loop.LogInfo()
            loop.scan([json.dumps(o) for o in objs], info)
            return info

        def wake(noop, parent=None):
            return {"type": "assistant", "parent_tool_use_id": parent, "message": {"content": [
                {"type": "tool_use", "name": "ScheduleWakeup", "input": {"noop": noop}}]}}

        none = {"type": "system", "subtype": "background_tasks_changed", "tasks": []}
        busy = {"type": "system", "subtype": "background_tasks_changed", "tasks": [{"task_id": "a"}]}
        tick = {"type": "command_lifecycle", "state": "started", "wakeup_source": "loop_wakeup"}
        other = {"type": "command_lifecycle", "state": "started"}  # a message or a prompt started the turn
        bash = {"type": "assistant", "message": {"content": [{"type": "tool_use", "name": "Bash", "input": {}}]}}
        self.assertTrue(info_of(none, tick, wake(True), tick, wake(True)).idle)
        # the 320 pattern: each tick looked at git status, then scheduled the next no-op wakeup
        self.assertTrue(info_of(none, tick, bash, wake(True), tick, bash, wake(True)).idle)
        self.assertFalse(info_of(none, tick, wake(True)).idle)  # one is not enough
        self.assertFalse(info_of(busy, tick, wake(True), tick, wake(True)).idle)  # a reviewer still runs
        self.assertFalse(info_of(none, tick, wake(True), tick, wake(False), tick, wake(True)).idle)  # progress between
        self.assertFalse(info_of(tick, wake(True), tick, wake(True), none).idle)  # the list changed after them
        self.assertFalse(info_of(none, tick, wake(True), {"type": "system", "subtype": "task_progress"},
                                 tick, wake(True)).idle)
        self.assertFalse(info_of(none, tick, wake(True), {"type": "user", "parent_tool_use_id": "t"},
                                 tick, wake(True)).idle)
        self.assertFalse(info_of(none, tick, wake(True, parent="t"), tick, wake(True, parent="t")).idle)  # a subagent's
        # heartbeats of a working turn are not ticks (review of the watchdog, SHOULD 1)
        self.assertFalse(info_of(none, wake(True), wake(True)).idle)
        self.assertFalse(info_of(none, other, wake(True), bash, wake(True)).idle)
        self.assertFalse(info_of(none, tick, wake(True), wake(True)).idle)  # twice in one tick counts once
        self.assertFalse(info_of(none, tick, wake(True), other, tick, wake(True)).idle)  # a message between

    def test_a_lost_session_stops_the_loop(self):
        self.write_plan([{"do": "limit", "in": 0}, "lost"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual(loop.load_json(self.repo.run_file)["phase"], "lost")
        self.assertIn("cannot be continued", out)
        self.assertEqual(self.lock_slug(), FTP)
        (d,) = self.trace_dirs()
        meta = self.check_trace(d, slug=FTP, reasons=("-", "usage-limit"), phase="lost")
        self.assertEqual(meta["attempts"][1]["error_kind"], "session-lost")
        self.assertEqual([(i["phase"], i["attempts"]) for i in self.index()], [("lost", 2)])

    def test_refusals(self):
        self.write_plan(["refuse", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertEqual(len(self.calls()), 2)
        self.assertIn("did not take the item", out)
        # the refused run and the closed one: a folder and an index line each
        self.assertEqual([(i["phase"], i["outcome"]) for i in self.index()], [("done", None), ("done", "closed")])
        self.assertEqual(len(self.trace_dirs()), 2)
        self.tearDown()
        self.setUp()
        self.write_plan(["refuse", "refuse", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual(len(self.calls()), 2)
        self.assertFalse(self.repo.run_file.exists())

    def test_errors_before_the_item_was_taken_start_afresh(self):
        self.write_plan(["crash-start", {"do": "limit-start", "in": 0}, "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        calls = self.calls()
        self.assertEqual([c["resume"] for c in calls], [False, False, False])
        self.assertEqual(len({c["session"] for c in calls}), 3)

    def test_a_row_written_while_the_lock_is_held_is_not_finished(self):
        self.write_plan(["row-keep-lock", "release"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertEqual([c["resume"] for c in self.calls()], [False, True])
        self.assertIn("closed 1", out)
        self.assertIsNone(self.repo.lock())

    def test_a_refusal_under_another_runs_lock_of_the_same_item_is_not_continued(self):
        """Review M1: a manual run took the item's lock first; the loop's run refused."""
        self.write_plan(["refuse-other"])
        code, out = self.run_loop("--until-idle", "--deadline", "3")
        self.assertEqual(code, 3, out)  # it waits for the other run's lock until the deadline
        self.assertEqual([c["resume"] for c in self.calls()], [False])
        self.assertIn("did not take the item", out)
        self.assertIn("run lock is held", out)
        self.assertFalse(self.repo.run_file.exists())

    def test_a_continuation_that_refuses_keeps_the_record_and_stops(self):
        """Review 2 S1: the loop saw the lock as the run's own; a refusal then is not a manual run's."""
        self.write_plan([{"do": "limit", "in": 0}, "refuse", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual([c["resume"] for c in self.calls()], [False, True])
        run = loop.load_json(self.repo.run_file)
        self.assertEqual(run["phase"], "failed")
        self.assertIn("refused although it holds", out)

    def test_the_test_clock_is_not_passed_to_claude(self):
        """Review 2 N1: TANDEM_BACKLOG_NOW would date the run's lock before the run."""
        self.write_plan(["close"])
        os.environ["TANDEM_BACKLOG_NOW"] = "2026-01-01T00:00:00"
        try:
            code, out = self.run_loop("--until-idle")
        finally:
            os.environ.pop("TANDEM_BACKLOG_NOW")
        self.assertEqual(code, 0, out)
        self.assertIsNone(self.calls()[0]["test_clock"])

    def test_another_items_lock_is_not_this_runs(self):
        self.write_plan(["crash-other-lock", "close"])
        code, out = self.run_loop("--until-idle", "--deadline", "3")
        self.assertEqual(code, 3, out)
        self.assertEqual([c["resume"] for c in self.calls()], [False])
        self.assertIn("run lock is held", out)

    def test_a_limit_claude_waited_out_does_not_hide_a_stall(self):
        """Review S1: a 'rejected' event before a successful end is not a limit."""
        self.write_plan(["watchdog-stall", "watchdog-stall", "watchdog-stall", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual(len(self.calls()), 3)
        self.assertIn("without finishing", out)
        self.assertNotIn("interrupted by a usage limit", out)

    def test_a_context_limit_is_an_error_not_a_usage_limit(self):
        """Review S2: 'Context limit reached' counts as an error with its bound."""
        self.write_plan(["context-error", "context-error", "context-error", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual(len(self.calls()), 3)
        self.assertNotIn("usage limit", out)

    def test_usage_limits_are_bounded(self):
        self.write_plan([{"do": "limit", "in": 0}] * (loop.MAX_LIMITS + 1) + ["close"])
        code, out = self.run_loop("--until-idle", "--limit-unknown-wait", "0.05")
        self.assertEqual(code, 1, out)
        self.assertEqual(len(self.calls()), loop.MAX_LIMITS + 1)
        self.assertIn(f"interrupted by a usage limit {loop.MAX_LIMITS + 1} times", out)

    def test_each_attempt_is_judged_by_its_own_part_of_the_log(self):
        """A limit, then crashes: the crashes count as errors (the old 429 is not read again)."""
        self.write_plan([{"do": "limit", "in": 0}, "crash", "crash", "crash", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual(len(self.calls()), 4)
        self.assertIn("ended with an error 3 times", out)

    def test_a_stale_stop_does_not_end_a_new_loop(self):
        """Review N1: a stop left by a killed loop."""
        self.repo.dir.mkdir(parents=True)
        self.repo.stop_flag.write_text("x", encoding="utf-8")
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertEqual(len(self.calls()), 1)

    def test_a_run_cut_off_with_its_loop_is_continued_with_the_registry_warning(self):
        """Review M2: Ctrl+C in Git Bash kills loop and claude at once - no HARD STOP was said."""
        self.pending_record("running")
        self.bl("lock", "acquire", "--slug", FTP)
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        call, = self.calls()
        self.assertTrue(call["resume"])
        self.assertEqual(call["session"], "22222222-2222-4222-8222-222222222222")
        self.assertIn("registry", out)
        self.assertIn("closed 1", out)

    def test_a_pending_run_of_the_loop_before_342_moves_into_a_trace_and_is_continued(self):
        """FR-014: its log (in the old place) becomes the start of a run folder, then deleted."""
        self.pending_record("running", resumes=1)
        old_log, old_err = self.tmp / "p.jsonl", self.tmp / "p.err"
        old_log.write_bytes(b'{"type":"system","subtype":"init","session_id":"22222222-2222-4222-8222-222222222222",'
                            b'"model":"fake-model"}\n')
        old_err.write_bytes(b"old stderr\n")
        before = old_log.read_bytes()
        self.bl("lock", "acquire", "--slug", FTP)
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertTrue(self.calls()[0]["resume"])
        self.assertFalse(old_log.exists() or old_err.exists())  # moved
        (d,) = self.trace_dirs()
        data = (d / "trace.jsonl").read_bytes()
        self.assertTrue(data.startswith(before))  # the earlier output first, unchanged
        seps = [json.loads(l) for l in data.decode().splitlines() if '"backlog_loop.attempt"' in l]
        self.assertEqual([(s["attempt"], s["kind"], s["reason"]) for s in seps], [(3, "continue", "killed")])
        meta = json.loads((d / "meta.json").read_text(encoding="utf-8"))
        self.assertEqual([a["reason"] for a in meta["attempts"]], ["-", "-", "killed"])
        self.assertEqual((meta["phase"], meta["outcome"]), ("done", "closed"))
        self.assertTrue((d / "stderr.log").read_text(encoding="utf-8").startswith("old stderr\n"))
        self.assertEqual(len(self.index()), 1)

    def test_a_pending_run_waits_while_another_item_holds_the_lock(self):
        self.pending_record("killed", why="a hard stop")
        self.bl("lock", "acquire", "--slug", "someone-else")
        code, out = self.run_loop("--until-idle", "--deadline", "2")
        self.assertEqual(code, 3, out)
        self.assertFalse(self.plan.exists() and self.calls())
        self.assertIn("held by another run", out)

    def test_a_lock_of_the_same_item_taken_before_the_run_is_not_its(self):
        self.pending_record("killed", why="a hard stop")
        os.environ["TANDEM_BACKLOG_NOW"] = "2026-01-01T00:00:00"
        try:
            self.bl("lock", "acquire", "--slug", FTP)
        finally:
            os.environ.pop("TANDEM_BACKLOG_NOW")
        code, out = self.run_loop("--until-idle", "--deadline", "2")
        self.assertEqual(code, 3, out)
        self.assertFalse(self.plan.exists() and self.calls())
        self.assertIn("held by another run", out)

    def test_a_replaced_lock_of_the_same_item_is_not_its(self):
        self.pending_record("killed", why="a hard stop", lock_started="2026-01-01T00:00:00")
        self.bl("lock", "acquire", "--slug", FTP)
        code, out = self.run_loop("--until-idle", "--deadline", "2")
        self.assertEqual(code, 3, out)
        self.assertFalse(self.plan.exists() and self.calls())

    def test_a_pending_run_whose_lock_was_released_by_hand_is_dropped(self):
        """Review N2: another item's row is not this run's outcome."""
        self.pending_record("killed", why="a hard stop")
        self.bl("run-log", "--outcome", "closed", "--slug", "some-other-item", "--note", "by hand")
        self.commit()
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertIn("no longer holds the lock", out)
        call, = self.calls()
        self.assertFalse(call["resume"])  # a fresh run of the item

    def test_hard_stop_when_claude_already_ended(self):
        """Review S4: the same Ctrl+C ended claude first - still a hard stop."""
        args = loop.build_parser().parse_args(self.start_args())
        lp = loop.Loop(self.repo, args)
        lp.run = self.pending_record("running")
        lp.child = subprocess.Popen([sys.executable, "-c", "pass"])
        lp.child.wait()
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            self.assertEqual(lp.hard_stop(), 130)
        self.assertIn("HARD STOP", buf.getvalue())
        self.assertEqual(loop.load_json(self.repo.run_file)["phase"], "killed")

    def test_claude_missing(self):
        code, out = self.run_loop("--until-idle", "--claude-cmd", json.dumps([str(self.tmp / "no-such.exe")]))
        self.assertEqual(code, 1, out)
        self.assertIn("cannot be started", out)
        self.assertFalse(self.repo.run_file.exists())

    def test_usage(self):
        self.assertEqual(loop.main(["start", "--max-blocked", "0"]), 2)
        self.assertEqual(loop.main(["nonsense"]), 2)


class PrecheckTests(Base):
    def precheck(self):
        args = loop.build_parser().parse_args(self.start_args())
        return loop.Loop(self.repo, args).precheck()

    def test_ready(self):
        self.assertEqual(self.precheck(), ("ready", FTP))

    def test_lock_held(self):
        self.bl("lock", "acquire", "--slug", "someone")
        state, why = self.precheck()
        self.assertEqual(state, "waiting")
        self.assertIn("run lock is held", why)

    def test_not_on_main(self):
        git(self.root, "checkout", "-q", "-b", "248-x")
        self.assertIn("not on main", self.precheck()[1])

    def test_dirty_tree(self):
        (self.root / "scratch.txt").write_text("x", encoding="utf-8")
        self.assertIn("not clean", self.precheck()[1])

    def test_check_findings(self):
        p = self.root / "backlog" / "items" / FTP / "desc.md"
        p.write_text(p.read_text(encoding="utf-8").replace("severity: 3", "severity: 11"), encoding="utf-8")
        self.commit()
        self.assertIn("finding", self.precheck()[1])

    def test_nothing_eligible(self):
        self.bl("block", FTP, "--reason", "x")
        self.commit()
        state, why = self.precheck()
        self.assertEqual(state, "idle")
        self.assertIn("2 row(s) skipped", why)


class ProcessTests(Base):
    """The loop as a separate process: control from outside, Ctrl+Break."""

    def test_pause_resume_stop(self):
        self.bl("unblock", DISK)
        self.commit()
        self.write_plan([{"do": "hang", "seconds": 1.5}, "close"])
        p = self.spawn_loop()
        self.wait_for(lambda: self.plan.exists() and len(self.calls()) == 1, what="first call")
        code, out = self.ctl("pause")
        self.assertIn("pause requested", out)
        self.assertIn(FTP, out)
        _, status = self.ctl("status")
        self.assertIn("pause requested", status)
        self.assertIn("HARD STOP now", status)
        self.wait_for(lambda: self.loop_state() == "paused", what="paused")
        self.assertEqual(len(self.calls()), 1)
        _, status = self.ctl("status")
        self.assertIn("safe now", status)
        self.assertIn("closed 1", status)
        code, out = self.ctl("resume")
        self.assertIn("resumed", out)
        self.wait_for(lambda: len(self.calls()) == 2 and self.loop_state() == "idle", what="second item, then idle")
        code, out = self.ctl("stop")
        self.assertIn("ends within a few seconds", out)
        self.assertEqual(p.wait(timeout=30), 0, self.output(p))
        self.assertFalse(self.repo.stop_flag.exists())
        self.assertFalse(self.repo.loop_file.exists())
        self.assertIn("closed 2", self.output(p))

    def test_stop_while_an_item_runs_finishes_it_first(self):
        self.bl("unblock", DISK)
        self.commit()
        self.write_plan([{"do": "hang", "seconds": 1.5}, "close"])
        p = self.spawn_loop()
        self.wait_for(lambda: self.plan.exists() and len(self.calls()) == 1, what="first call")
        code, out = self.ctl("stop")
        self.assertIn("finishes item", out)
        self.assertEqual(p.wait(timeout=30), 0, self.output(p))
        self.assertEqual(len(self.calls()), 1)
        self.assertEqual(self.runs()[-1][2], "closed")
        self.assertIn("stop requested", self.output(p))

    def test_a_pause_set_before_the_start_holds_it(self):
        self.write_plan(["close"])
        _, out = self.ctl("pause")
        self.assertIn("starts paused", out)
        p = self.spawn_loop()
        self.wait_for(lambda: self.loop_state() == "paused", what="paused")
        time.sleep(0.5)
        self.assertFalse(self.plan.exists() and self.calls())
        self.ctl("stop")
        self.assertEqual(p.wait(timeout=30), 0)
        self.assertTrue(self.repo.pause_flag.exists())  # a pause persists
        _, out = self.ctl("resume")
        self.assertIn("pause cleared", out)

    def test_waiting_for_a_clean_tree(self):
        self.write_plan(["close"])
        (self.root / "scratch.txt").write_text("x", encoding="utf-8")
        p = self.spawn_loop()
        self.wait_for(lambda: self.loop_state() == "waiting", what="waiting")
        _, status = self.ctl("status")
        self.assertIn("not clean", status)
        self.assertIn("safe now", status)
        time.sleep(0.5)
        self.assertFalse(self.plan.exists() and self.calls())
        (self.root / "scratch.txt").unlink()
        self.wait_for(lambda: self.plan.exists() and len(self.calls()) == 1 and self.loop_state() == "idle",
                      what="the item after the tree was cleaned")
        self.ctl("stop")
        self.assertEqual(p.wait(timeout=30), 0)

    def test_one_loop_per_repository(self):
        self.write_plan([])
        self.bl("block", FTP, "--reason", "x")
        self.commit()
        p = self.spawn_loop()
        self.wait_for(lambda: self.loop_state() == "idle", what="idle")
        code, out = self.run_loop()
        self.assertEqual(code, 1, out)
        self.assertIn("another loop is running", out)
        self.assertNotIn("loop ended", out)  # the refused start ran nothing
        _, status = self.ctl("status")
        self.assertIn(f"pid {p.pid}", status)
        self.ctl("stop")
        self.assertEqual(p.wait(timeout=30), 0)

    def test_refused_start_keeps_the_other_loops_stop(self):
        self.write_plan([])
        self.bl("block", FTP, "--reason", "x")
        self.commit()
        p = self.spawn_loop("--poll", "30", "--tick", "2")
        self.wait_for(lambda: self.loop_state() == "idle", what="idle")
        self.repo.stop_flag.write_text("x", encoding="utf-8")  # stop seen by the loop only at its next tick
        code, out = self.run_loop()
        self.assertEqual(code, 1, out)
        self.assertTrue(self.repo.stop_flag.exists() or p.poll() is not None)
        self.assertEqual(p.wait(timeout=30), 0)

    def test_a_dead_loops_record_is_taken_over(self):
        dead = subprocess.Popen([sys.executable, "-c", "pass"])
        ident = loop.process_ident(dead.pid)
        dead.wait()
        self.repo.dir.mkdir(parents=True)
        loop.save_json(self.repo.loop_file, {"pid": dead.pid, "ident": ident or 1, "started": "x", "state": "running"})
        _, status = self.ctl("status")
        self.assertIn("ended without cleanup", status)
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertIn("taking over", out)

    @unittest.skipUnless(os.name == "nt", "Ctrl+Break is Windows")
    def test_ctrl_break_kills_the_item_and_the_next_start_continues_it(self):
        self.write_plan([{"do": "hang", "seconds": 60}, "close"])
        p = self.spawn_loop()
        pid_file = self.tmp / "fake.pid"
        self.wait_for(pid_file.exists, what="the fake's pid")
        fake_pid = int(pid_file.read_text())
        fake_ident = loop.process_ident(fake_pid)
        self.assertIsNotNone(fake_ident)
        _, status = self.ctl("status")
        self.assertIn("HARD STOP now", status)
        os.kill(p.pid, signal.CTRL_BREAK_EVENT)
        self.assertEqual(p.wait(timeout=30), 130, self.output(p))
        self.assertIn("HARD STOP", self.output(p))
        self.assertFalse(loop.alive(fake_pid, fake_ident))
        run = loop.load_json(self.repo.run_file)
        self.assertEqual(run["phase"], "killed")
        self.assertEqual(self.lock_slug(), FTP)
        self.assertFalse(self.repo.loop_file.exists())
        _, status = self.ctl("status")
        self.assertIn("continues this run in the same session", status)
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        first, second = self.calls()
        self.assertTrue(second["resume"])
        self.assertEqual(second["session"], first["session"])
        self.assertIn("hard stop", second["prompt"])
        self.assertEqual(self.runs()[-1][2], "closed")
        (d,) = self.trace_dirs()  # the killed attempt and its continuation share the folder
        meta = self.check_trace(d, slug=FTP, reasons=("-", "killed"), outcome="closed")
        self.assertEqual(meta["attempts"][0]["ending"], "interrupted")
        self.assertEqual(len(self.index()), 1)

    def test_ctrl_c_while_waiting_ends_quietly(self):
        if os.name != "nt":
            self.skipTest("Ctrl+Break is Windows")
        self.write_plan([])
        self.bl("block", FTP, "--reason", "x")
        self.commit()
        p = self.spawn_loop()
        self.wait_for(lambda: self.loop_state() == "idle", what="idle")
        os.kill(p.pid, signal.CTRL_BREAK_EVENT)
        self.assertEqual(p.wait(timeout=30), 130)
        self.assertIn("no item of this loop was running", self.output(p))
        self.assertFalse(self.repo.run_file.exists())

    def test_a_claude_left_by_a_killed_loop_is_waited_for(self):
        """The loop died, its claude kept working: the next loop waits for it, never starts a second."""
        self.write_plan([{"do": "hang", "seconds": 5, "then": "close"}])
        rows = len(self.runs())
        orphan = subprocess.Popen([sys.executable, str(FAKE), "-p", f"/tandem-backlog-implement {FTP}",
                                   "--session-id", "11111111-1111-4111-8111-111111111111"], cwd=str(self.root),
                                  stdout=subprocess.DEVNULL)
        self.procs.append(orphan)
        self.wait_for(lambda: (self.tmp / "fake.pid").exists(), what="the orphan")
        self.repo.dir.mkdir(parents=True, exist_ok=True)
        loop.save_json(self.repo.run_file, {
            "slug": FTP, "session": "11111111-1111-4111-8111-111111111111", "started": "x",
            "log": str(self.tmp / "o.jsonl"), "err": str(self.tmp / "o.err"), "rows_before": rows,
            "attempts": 0, "stalls": 0, "resumes": 0, "phase": "running", "wait_until": None, "why": None,
            "child_pid": orphan.pid, "child_ident": loop.process_ident(orphan.pid)})
        _, status = self.ctl("status")
        self.assertIn("is still working; the next bin/backlog-loop.sh start waits for it", status)  # review 2 N5
        self.assertTrue(json.loads(self.ctl("status", "--json")[1])["orphan"])  # 344: the same check as data
        p = self.spawn_loop("--until-idle")
        self.wait_for(lambda: "previous loop" in str((loop.load_json(self.repo.loop_file) or {}).get("detail")),
                      what="waiting for the orphan")
        _, status = self.ctl("status")
        self.assertIn("safe now", status)  # review 2 S2: Ctrl+C would end only the loop
        self.assertEqual(p.wait(timeout=30), 0, self.output(p))
        out = self.output(p)
        self.assertIn("previous loop still works", out)
        self.assertEqual(len(self.calls()), 1)  # only the orphan's own call
        self.assertIn("closed 1", out)


class ControlTests(Base):
    def test_commands_without_a_loop(self):
        code, out = self.ctl("status")
        self.assertEqual(code, 0)
        self.assertIn("loop:    not running", out)
        self.assertIn("lock:    free", out)
        _, out = self.ctl("stop")
        self.assertIn("no loop is running", out)
        self.assertFalse(self.repo.stop_flag.exists())
        _, out = self.ctl("resume")
        self.assertIn("nothing to resume", out)
        _, out = self.ctl("pause")
        self.assertIn("starts paused", out)
        _, out = self.ctl("status")
        self.assertIn("pause requested", out)
        _, out = self.ctl("stop")
        self.assertIn("a pause is still set", out)
        _, out = self.ctl("resume")
        self.assertIn("pause cleared", out)
        self.assertFalse(self.repo.pause_flag.exists())
        code, out = self.ctl("status", "--json")
        self.assertEqual(json.loads(out)["paused"], False)

    def test_status_shows_the_trace_and_the_size_of_all_traces(self):
        _, out = self.ctl("status")
        self.assertIn("trace:   - (traces total: 0 B)", out)
        self.assertNotIn("log:", out)
        self.write_plan(["close"])
        self.run_loop("--until-idle")
        (d,) = self.trace_dirs()
        size = traces.traces_size(self.root)
        self.assertGreater(size, 0)
        _, out = self.ctl("status")
        self.assertIn(f"(traces total: {traces.format_size(size)})", out)
        data = json.loads(self.ctl("status", "--json")[1])
        self.assertEqual(data["traces_bytes"], size)
        self.assertIn("trace", data)

    def test_files_live_in_the_git_dir_not_in_the_tree(self):
        self.ctl("pause")
        self.assertEqual(self.repo.dir.parent.resolve(), (self.root / ".git").resolve())
        self.assertEqual(git(self.root, "status", "--porcelain"), "")

    def test_bin_backlog_loop_sh(self):
        bash = git_bash()
        if not bash:
            self.skipTest("needs Git Bash")

        def sh(*args):
            r = subprocess.run([bash, str(BIN), *args], capture_output=True, text=True, encoding="utf-8")
            return r.returncode, r.stdout + r.stderr
        root = ["--root", str(self.root)]
        self.assertEqual(sh("status", *root)[0], 0)
        self.assertIn("loop:    not running", sh("status", *root)[1])
        self.assertIn("starts paused", sh("pause", *root)[1])
        self.assertIn("pause requested", sh("status", *root)[1])
        self.assertIn("pause cleared", sh("resume", *root)[1])
        self.assertIn("no loop is running", sh("stop", *root)[1])
        self.assertIn("no loop is running", sh("kill", *root)[1])
        for args in (["--help"], ["-h"], ["help"]):
            code, out = sh(*args)
            self.assertEqual(code, 0, args)
            self.assertTrue(out.startswith("Usage: bin/backlog-loop.sh <command>"), out)
            self.assertIn("bin/backlog.sh", out)  # where the backlog itself is
            self.assertIn(".agent-traces/", out)
        # every option of start that a user may pass is in the overview
        start = next(a for a in loop.build_parser()._actions if isinstance(a, loop.argparse._SubParsersAction))
        for action in start.choices["start"]._actions:
            if action.help != loop.argparse.SUPPRESS:
                for flag in action.option_strings:
                    if flag.startswith("--"):
                        self.assertIn(flag, out)
        for command in ("start", "pause", "resume", "stop", "kill", "status"):
            self.assertIn(f"  {command} ", out)
            code, cout = sh(command, "--help")
            self.assertEqual(code, 0, command)
            self.assertIn(f"usage: bin/backlog-loop.sh {command}", cout)
        self.assertIn("--max-items", sh("start", "--help")[1])
        self.assertEqual(sh()[0], 2)
        code, out = sh("bogus")
        self.assertEqual(code, 2)
        self.assertIn("unknown command 'bogus'", out)
        self.write_plan(["close"])
        # forward slashes: bash collapses the doubled backslashes of JSON on the way to a native program
        cmd = json.dumps([Path(sys.executable).as_posix(), FAKE.as_posix()])
        code, out = sh("start", *root, "--claude-cmd", cmd, *FAST, "--until-idle")
        self.assertEqual(code, 0, out)
        self.assertIn("closed 1", out)
        self.assertNotIn(b"\r", BIN.read_bytes())


class LogTests(unittest.TestCase):
    def info(self, *objs):
        info = loop.LogInfo()
        loop.scan([json.dumps(o) for o in objs] + ["not json", ""], info)
        return info

    def test_limit_signals(self):
        self.assertTrue(self.info({"type": "result", "is_error": True, "api_error_status": 429, "result": "x"}).limited)
        self.assertTrue(self.info({"type": "result", "is_error": True, "result": "You've hit your limit · resets 5pm"}).limited)
        self.assertTrue(self.info({"type": "rate_limit_event", "rate_limit_info": {"status": "rejected", "resetsAt": 5}}).limited)
        self.assertFalse(self.info({"type": "result", "is_error": True, "api_error_status": 404, "result": "bad model"}).limited)
        self.assertFalse(self.info({"type": "result", "is_error": False, "result": "the rate limit of the API is mentioned"}).limited)
        self.assertFalse(self.info({"type": "rate_limit_event", "rate_limit_info": {"status": "allowed_warning"}}).limited)
        # review S1 / S2: a limit waited out before a successful end, and the context limit
        self.assertFalse(self.info({"type": "rate_limit_event", "rate_limit_info": {"status": "rejected", "resetsAt": 5}},
                                   {"type": "result", "is_error": False, "result": "done"}).limited)
        self.assertFalse(self.info({"type": "result", "is_error": True, "result": "Context limit reached"}).limited)
        self.assertFalse(self.info({"type": "result", "is_error": True, "api_error_status": 500,
                                    "result": "usage limit text in a server error"}).limited)
        # review 2 N3: an error after a limit claude had waited out is an error
        self.assertFalse(self.info({"type": "rate_limit_event", "rate_limit_info": {"status": "rejected", "resetsAt": 5}},
                                   {"type": "result", "is_error": True, "api_error_status": 500, "result": "x"}).limited)

    def test_reset_and_refusal(self):
        info = self.info({"type": "rate_limit_event", "rate_limit_info": {"status": "rejected", "resetsAt": 1792443600}})
        self.assertEqual(info.reset_at, 1792443600.0)
        self.assertIsNone(self.info().reset_at)
        self.assertTrue(self.info({"type": "result", "is_error": False, "result": "x\nOutcome: refused (a)"}).refused)
        self.assertFalse(self.info({"type": "result", "is_error": False, "result": "Outcome: closed"}).refused)
        self.assertTrue(self.info({"type": "result", "is_error": False, "result": "**Outcome:** refused (x)"}).refused)
        self.assertFalse(self.info({"type": "result", "is_error": False, "result": "The outcome: it was refused"}).refused)
        self.assertTrue(self.info().is_error)  # no result at all

    def test_usage_line(self):
        rl = {"status": "allowed_warning", "unifiedWindows": {"five_hour": {"utilization": 0.01, "resetsAt": 1792449600},
                                                              "seven_day": {"utilization": 0.93, "resetsAt": 1792443600}}}
        line = loop.usage_line(rl)
        self.assertTrue(line.startswith("allowed_warning: five_hour 1%"), line)
        self.assertIn("seven_day 93%", line)
        self.assertEqual(loop.usage_line(None), "-")

    def test_partial_last_line_is_left_for_later(self):
        d = Path(tempfile.mkdtemp(prefix="loop247-"))
        try:
            p = d / "x.jsonl"
            p.write_bytes(b'{"type":"system"}\n{"type":"res')
            lines, off = loop.read_lines(p, 0)
            self.assertEqual(lines, ['{"type":"system"}'])
            self.assertEqual(off, len(b'{"type":"system"}\n'))
        finally:
            shutil.rmtree(d)

    def test_process_identity(self):
        self.assertIsNotNone(loop.process_ident(os.getpid()))
        self.assertTrue(loop.alive(os.getpid(), loop.process_ident(os.getpid())))
        self.assertFalse(loop.alive(os.getpid(), 12345))  # a reused pid has another identity
        self.assertFalse(loop.alive(None, None))


class AutoTriageTests(Base):
    """--auto-triage: '/tandem-backlog auto-triage --commit' before a run when the Inbox has new items."""

    def prompts(self):
        return [c["prompt"] for c in self.calls()]

    def test_triage_first_and_after_a_run_that_adds_an_item(self):
        self.write_plan(["triage", {"do": "close", "add": "critical-find"}, "triage", "close"])
        code, out = self.run_loop("--auto-triage", "--max-items", "2")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.prompts(), [loop.TRIAGE_PROMPT, f"/tandem-backlog-implement {FTP}",
                                          loop.TRIAGE_PROMPT, "/tandem-backlog-implement critical-find"])
        calls = self.calls()
        self.assertEqual(calls[0]["triage_env"], str(os.getpid()))
        self.assertIsNone(calls[1]["triage_env"])
        self.assertEqual({c["bg_ceiling"] for c in calls}, {loop.BG_WAIT_CEILING_MS})
        argv = calls[0]["argv"]
        self.assertEqual(argv[argv.index("--permission-mode") + 1], "bypassPermissions")
        self.assertIn("--session-id", argv)
        self.assertIn("auto-triage: 1 Inbox item(s) placed (1 new), 0 left in Inbox; next: critical-find", out)
        self.assertIn("auto-triage 2", out)
        self.assertNotIn("REFUSED", out)  # the fake checked the loop's status as the skill does
        self.assertFalse(self.repo.triage_file.exists())
        index = self.index()
        self.assertEqual([(i["kind"], i["slug"], i["outcome"]) for i in index],
                         [("triage", "triage", "triaged"), ("item", FTP, "closed"),
                          ("triage", "triage", "triaged"), ("item", "critical-find", "closed")])
        for i in index:
            d = self.root / ".agent-traces" / i["dir"]
            if i["kind"] == "triage":
                self.assertRegex(d.name, r"^\d{8}-\d{6}-claude-triage(-\d+)?$")
                meta = self.check_trace(d, kind="triage", slug="triage", outcome="triaged")
                subjects = [git(self.root, "log", "-1", "--format=%s", h).strip() for h in meta["commits"]]
                self.assertEqual(subjects, ["backlog: auto-triage (fake)"])
                self.assertTrue(meta["loop"]["auto_triage"])
        self.assert_clean_tree()

    def test_the_last_item_of_max_items_is_triaged_after(self):
        self.write_plan(["triage", {"do": "close", "add": "late-find"}, "triage"])
        code, out = self.run_loop("--auto-triage", "--max-items", "1")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.prompts(), [loop.TRIAGE_PROMPT, f"/tandem-backlog-implement {FTP}", loop.TRIAGE_PROMPT])
        bl = backlog.Backlog(self.root)
        self.assertEqual(bl.ov.sections[backlog.SEC_NEXT].rows[0].slug, "late-find")

    def test_without_the_option_no_triage(self):
        self.write_plan(["close"])
        code, out = self.run_loop("--max-items", "1")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.prompts(), [f"/tandem-backlog-implement {FTP}"])

    def test_items_left_in_inbox_are_not_triaged_again(self):
        self.write_plan(["triage-none", "close", "close", "close"])
        code, out = self.run_loop("--auto-triage", "--until-idle")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.prompts().count(loop.TRIAGE_PROMPT), 1)
        self.assertEqual(self.prompts()[1], f"/tandem-backlog-implement {FTP}")
        self.assertIn("auto-triage: no commit", out)

    def test_a_refusal_is_said_and_tried_again(self):
        self.write_plan(["refuse", "triage", "close"])
        code, out = self.run_loop("--auto-triage", "--max-items", "1")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.prompts(), [loop.TRIAGE_PROMPT, loop.TRIAGE_PROMPT, f"/tandem-backlog-implement {FTP}"])
        self.assertIn("the auto-triage REFUSED", out)
        self.assertIn("auto-triage 1", out)  # a refusal is not counted as done

    def test_two_refusals_in_a_row_stop_the_loop(self):
        self.write_plan(["refuse", "refuse", "close"])
        code, out = self.run_loop("--auto-triage")
        self.assertEqual(code, 1, out)
        self.assertEqual(self.prompts(), [loop.TRIAGE_PROMPT, loop.TRIAGE_PROMPT])
        self.assertIn("refused 2 times in a row", out)

    def test_an_error_is_retried_after_a_pause(self):
        self.write_plan(["crash-start", "triage", "close"])
        code, out = self.run_loop("--auto-triage", "--max-items", "1")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.prompts(), [loop.TRIAGE_PROMPT, loop.TRIAGE_PROMPT, f"/tandem-backlog-implement {FTP}"])
        self.assertIn("the auto-triage ended with an error", out)

    def test_errors_beyond_the_backoff_stop_the_loop(self):
        self.write_plan(["crash-start", "crash-start", "crash-start", "triage"])
        code, out = self.run_loop("--auto-triage")
        self.assertEqual(code, 1, out)
        self.assertEqual(self.prompts(), [loop.TRIAGE_PROMPT] * 3)  # FAST backoff has two pauses
        self.assertIn("ended with an error 3 times", out)

    def test_a_usage_limit_is_waited_out(self):
        self.write_plan([{"do": "limit-start", "in": 0}, "triage", "close"])
        code, out = self.run_loop("--auto-triage", "--max-items", "1")
        self.assertEqual(code, 0, out)
        self.assertEqual(self.prompts(), [loop.TRIAGE_PROMPT, loop.TRIAGE_PROMPT, f"/tandem-backlog-implement {FTP}"])
        self.assertIn("the auto-triage ended at a usage limit", out)

    def test_ctrl_break_during_the_triage(self):
        if os.name != "nt":
            self.skipTest("Ctrl+Break is Windows")
        self.write_plan([{"do": "triage-hang", "seconds": 60}])
        p = self.spawn_loop("--auto-triage")
        pid_file = self.tmp / "fake.pid"
        self.wait_for(pid_file.exists, what="the fake's pid")
        fake_pid = int(pid_file.read_text())
        fake_ident = loop.process_ident(fake_pid)
        _, status = self.ctl("status")
        self.assertIn("state:   triage", status)
        self.assertIn("HARD STOP now (the auto-triage is running)", status)
        self.assertTrue(self.repo.triage_file.exists())
        os.kill(p.pid, signal.CTRL_BREAK_EVENT)
        self.assertEqual(p.wait(timeout=30), 130, self.output(p))
        self.assertIn("HARD STOP: claude was killed during the auto-triage", self.output(p))
        self.assertFalse(loop.alive(fake_pid, fake_ident))
        self.assertFalse(self.repo.triage_file.exists())
        self.assertFalse(self.repo.run_file.exists())
        (d,) = self.trace_dirs()  # a killed triage is never continued: it ends here, indexed
        self.check_trace(d, kind="triage", slug="triage", phase="killed")
        self.assertEqual([i["phase"] for i in self.index()], ["killed"])

    def test_stop_and_pause_during_the_triage_wait_for_it(self):
        self.write_plan([{"do": "triage-hang", "seconds": 3}, "close"])
        p = self.spawn_loop("--auto-triage")
        self.wait_for(lambda: (self.tmp / "fake.pid").exists(), what="the triage")
        _, said = self.ctl("pause")
        self.assertIn("finishes the auto-triage, then waits", said)
        self.ctl("resume")
        _, said = self.ctl("stop")
        self.assertIn("finishes the auto-triage, then ends", said)
        self.assertEqual(p.wait(timeout=30), 0, self.output(p))
        self.assertIn("1 Inbox item(s) placed", self.output(p))
        self.assertEqual(self.prompts(), [loop.TRIAGE_PROMPT])  # no run after the stop

    def test_a_triage_left_by_a_dead_loop_is_waited_for(self):
        self.write_plan([{"do": "triage-hang", "seconds": 4, "nogate": True}, "close"])
        orphan = subprocess.Popen([sys.executable, str(FAKE), "-p", loop.TRIAGE_PROMPT, "--session-id",
                                   "22222222-2222-4222-8222-222222222222"], cwd=str(self.root),
                                  stdout=subprocess.DEVNULL)
        self.procs.append(orphan)
        self.wait_for(lambda: (self.tmp / "fake.pid").exists(), what="the orphan")
        self.repo.dir.mkdir(parents=True, exist_ok=True)
        loop.save_json(self.repo.triage_file, {"log": str(self.tmp / "t.jsonl"), "err": str(self.tmp / "t.err"),
                                               "offset": 0, "err_offset": 0, "pid": orphan.pid,
                                               "ident": loop.process_ident(orphan.pid)})
        _, status = self.ctl("status")
        self.assertIn("auto-triage claude of the last loop", status)
        p = self.spawn_loop("--auto-triage", "--max-items", "1")
        self.wait_for(lambda: "previous loop" in str((loop.load_json(self.repo.loop_file) or {}).get("detail")),
                      what="waiting for the orphan")
        _, status = self.ctl("status")
        self.assertIn("safe now", status)
        self.assertEqual(p.wait(timeout=30), 0, self.output(p))
        out = self.output(p)
        self.assertIn("the auto-triage of the previous loop ended", out)
        # its commit placed the Inbox item: no second triage, then the run
        self.assertEqual(self.prompts(), [loop.TRIAGE_PROMPT, f"/tandem-backlog-implement {FTP}"])
        self.assertFalse(self.repo.triage_file.exists())

    def test_a_triage_that_leaves_the_tree_changed_stops_the_loop(self):
        self.write_plan(["triage-dirty", "close"])
        code, out = self.run_loop("--auto-triage", "--max-items", "1")
        self.assertEqual(code, 1, out)
        self.assertEqual(self.prompts(), [loop.TRIAGE_PROMPT])
        self.assertIn("after the auto-triage the working tree is not clean", out)
        self.assertFalse(self.repo.loop_file.exists())

    def test_no_triage_while_the_tree_is_not_ready(self):
        # a dirty tree: neither a triage nor a run starts; the precheck waits and says why
        (self.root / "stray.txt").write_text("x", encoding="utf-8")
        self.write_plan(["triage"])
        code, out = self.run_loop("--auto-triage", "--deadline", "1.5")
        self.assertEqual(code, 3, out)
        self.assertEqual(self.prompts(), [])
        self.assertIn("the working tree is not clean", out)


class KeepTracesTests(Base):
    def test_no_trace_is_ever_deleted(self):
        """FR-003 / SC-003: the 247 loop kept the newest 100 logs; traces are kept whole."""
        top = self.root / ".agent-traces"
        for i in range(105):
            d = top / f"20260101-{i:06d}-claude-x"
            d.mkdir(parents=True)
            (d / "trace.jsonl").write_text("{}\n", encoding="utf-8")
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertEqual(len(self.trace_dirs()), 106)
        self.assert_clean_tree()


class ImportTests(Base):
    """The first start after 342 moves the logs of the loop before it into .agent-traces/ once."""

    def old_logs(self):
        logs = self.repo.dir / "logs"
        self.repo.dir.mkdir(parents=True, exist_ok=True)
        shutil.copytree(OLD_LOGS, logs)
        return logs, {p.name: p.read_bytes() for p in logs.iterdir()}

    def test_the_old_logs_are_moved_once(self):
        logs, before = self.old_logs()
        self.write_plan([])
        self.bl("block", FTP, "--reason", "x")
        self.commit()
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertIn("moved 5 run log(s) of the loop before 342 into .agent-traces/", out)
        self.assertFalse(logs.exists())  # empty, removed
        top = self.root / ".agent-traces"
        for name, data in before.items():
            stem, ext = name.rsplit(".", 1)
            d = top / traces.new_name_for_old(stem)
            self.assertEqual((d / ("trace.jsonl" if ext == "jsonl" else "stderr.log")).read_bytes(), data, name)
            self.assertTrue(json.loads((d / "meta.json").read_text(encoding="utf-8"))["imported"])
        index = self.index()
        self.assertEqual(len(index), 5)
        self.assertEqual([i["dir"] for i in index], sorted(i["dir"] for i in index))
        self.assertEqual(loop.load_json(self.repo.imported_file)["imported"], 5)
        self.assert_clean_tree()
        # never again: not even after the maintainer deleted traces and old logs came back
        shutil.rmtree(top / index[0]["dir"])
        self.old_logs()
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertNotIn("moved", out)
        self.assertEqual(len(self.index()), 5)
        self.assertFalse((top / index[0]["dir"]).exists())

    def test_the_log_of_a_failed_pending_run_moves_with_the_rest(self):
        """It is never continued (only --forget-run drops it): its record follows the move."""
        logs, _ = self.old_logs()
        stem = "20261024-125035-ftp-an-upload-to-a-server-named-another-way-localhost-vs-127"
        self.repo.dir.mkdir(parents=True, exist_ok=True)
        loop.save_json(self.repo.run_file, {
            "slug": FTP, "session": "22222222-2222-4222-8222-222222222222", "started": "2026-10-24 12:50:35",
            "log": str(logs / f"{stem}.jsonl"), "err": str(logs / f"{stem}.err"), "rows_before": len(self.runs()),
            "attempts": 0, "stalls": 3, "resumes": 2, "limits": 0, "lock_started": None, "phase": "failed",
            "wait_until": None, "why": "ended its turn without finishing", "child_pid": None, "child_ident": None})
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)  # still a stop for a person
        self.assertIn("moved 5 run log(s)", out)
        self.assertFalse(logs.exists())
        run = loop.load_json(self.repo.run_file)
        self.assertEqual(Path(run["trace"]).name, traces.new_name_for_old(stem))
        self.assertTrue(Path(run["log"]).is_file())
        _, status = self.ctl("status")
        self.assertIn(f"trace:   {run['trace']}", status)
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle", "--forget-run")
        self.assertEqual(code, 0, out)
        dirs = [i["dir"] for i in self.index()]
        self.assertEqual(dirs.count(traces.new_name_for_old(stem)), 1)  # not indexed again when forgotten
        self.assertEqual(len(dirs), 6)  # the 5 moved + the new run of the item

    def test_review_r1_a_separator_after_a_partial_line_starts_its_own_line(self):
        """Review S1: claude killed mid-write left half a line; the next separator must still parse."""
        d = traces.new_run_dir(self.root, FTP, time.time() - 60)
        sep = traces.separator_line(1, "start", "-", traces.iso_local(time.time() - 60),
                                    "22222222-2222-4222-8222-222222222222")
        (d / "trace.jsonl").write_bytes(sep + b'{"type":"system","subtype":"init","session_id":"x","model":"m"}\n'
                                        + b'{"type":"assistant","message":{"content":[{"type":"text","te')
        (d / "stderr.log").write_bytes(b"=== attempt 1 (start, -) x ===\npartial")
        self.repo.dir.mkdir(parents=True, exist_ok=True)
        loop.save_json(self.repo.run_file, {
            "slug": FTP, "session": "22222222-2222-4222-8222-222222222222", "started": loop.stamp(time.time() - 60),
            "started_epoch": time.time() - 60, "kind": "item", "trace": str(d), "log": str(d / "trace.jsonl"),
            "err": str(d / "stderr.log"), "rows_before": len(self.runs()), "attempts": 0, "stalls": 0,
            "resumes": 0, "limits": 0, "nudges": 0, "lock_started": None, "phase": "killed", "wait_until": None,
            "why": "a hard stop", "child_pid": None, "child_ident": None, "offset": len(sep), "err_offset": 0,
            "trace_attempts": [traces.attempt_record(1, "start", "-", "x")], "next_reason": "-",
            "indexed": False, "base": None})
        self.bl("lock", "acquire", "--slug", FTP)
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        seps = []
        for line in (d / "trace.jsonl").read_text(encoding="utf-8").splitlines():
            if '"backlog_loop.attempt"' in line:
                seps.append(json.loads(line)["attempt"])  # each one parses: a line of its own
        self.assertEqual(seps, [1, 2])
        headers = [l for l in (d / "stderr.log").read_text(encoding="utf-8").splitlines() if l.startswith("=== attempt")]
        self.assertEqual(len(headers), 2)

    def test_review_r2_forget_run_after_the_import_moves_the_old_log_of_the_run(self):
        """Review S2: the import skipped a continuable old run, which was then forgotten."""
        logs, _ = self.old_logs()
        stem = "20261024-125035-ftp-an-upload-to-a-server-named-another-way-localhost-vs-127"
        loop.save_json(self.repo.run_file, {
            "slug": FTP, "session": "22222222-2222-4222-8222-222222222222", "started": loop.stamp(time.time() - 60),
            "log": str(logs / f"{stem}.jsonl"), "err": str(logs / f"{stem}.err"), "rows_before": len(self.runs()),
            "attempts": 0, "stalls": 0, "resumes": 0, "limits": 0, "lock_started": None, "phase": "killed",
            "wait_until": None, "why": "a hard stop", "child_pid": None, "child_ident": None})
        self.ctl("pause")
        code, out = self.run_loop("--until-idle", "--deadline", "2")
        self.assertEqual(code, 3, out)  # imported, then waited paused
        self.assertTrue(self.repo.imported_file.exists())
        self.assertTrue((logs / f"{stem}.jsonl").exists())  # left to its run
        self.ctl("resume")
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle", "--forget-run")
        self.assertEqual(code, 0, out)
        self.assertFalse(logs.exists())  # its log moved when the run was forgotten
        self.assertIn(traces.new_name_for_old(stem), [i["dir"] for i in self.index()])

    def test_review_r3_the_log_of_a_247_triage_still_running_is_moved_after_it_ends(self):
        """Review M1: the import must not move a log another process still writes."""
        logs, _ = self.old_logs()
        tri = logs / "20261025-080000-auto-triage.jsonl"
        tri.write_bytes(b'{"type":"system","subtype":"init","session_id":"t","model":"m"}\n')
        (logs / "20261025-080000-auto-triage.err").write_bytes(b"")
        writer = subprocess.Popen([sys.executable, "-c",
                                   "import sys,time\nf=open(sys.argv[1],'ab',buffering=0)\n"
                                   "for i in range(80):\n f.write(b'{\"type\":\"x\",\"i\":%d}\\n'%i); time.sleep(0.05)\n",
                                   str(tri)])
        self.procs.append(writer)
        time.sleep(0.3)
        loop.save_json(self.repo.triage_file, {"log": str(tri), "err": str(logs / "20261025-080000-auto-triage.err"),
                                               "pid": writer.pid, "ident": loop.process_ident(writer.pid)})
        self.write_plan([])
        self.bl("block", FTP, "--reason", "x")
        self.commit()
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertIn("the auto-triage of the previous loop ended", out)
        d = self.root / ".agent-traces" / "20261025-080000-claude-triage"
        self.assertEqual((d / "trace.jsonl").read_bytes().count(b"\n"), 81)  # nothing written after a copy was lost
        self.assertFalse(logs.exists())
        self.assertEqual([i["dir"] for i in self.index()].count(d.name), 1)

    def test_review_r4_an_import_cut_off_after_the_rename_is_finished_next_time(self):
        """Review S3: the folder is in place under its final name, but no index line and the old pair stayed."""
        logs, _ = self.old_logs()
        stem = "20261024-121738-iso-plug-in-an-nrg-session-count-above-the-image-s-tracks"
        name = traces.new_name_for_old(stem)
        # what the import leaves when cut off between os.replace and the index line
        traces.import_old_logs(self.root, logs, [], {s for s in {p.stem for p in logs.iterdir()} if s != stem}, {})
        lines = (self.root / ".agent-traces" / "index.jsonl").read_text(encoding="utf-8")
        (self.root / ".agent-traces" / "index.jsonl").write_text("", encoding="utf-8")
        self.assertIn(name, lines)
        self.assertTrue((logs / f"{stem}.jsonl").exists())  # not moved (move=False above)
        self.write_plan([])
        self.bl("block", FTP, "--reason", "x")
        self.commit()
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertFalse(logs.exists())
        self.assertEqual([i["dir"] for i in self.index()].count(name), 1)

    def test_the_log_of_a_pending_run_is_left_to_its_run(self):
        logs, _ = self.old_logs()
        stem = "20261024-125035-ftp-an-upload-to-a-server-named-another-way-localhost-vs-127"
        self.repo.dir.mkdir(parents=True, exist_ok=True)
        loop.save_json(self.repo.run_file, {
            "slug": FTP, "session": "22222222-2222-4222-8222-222222222222", "started": loop.stamp(time.time() - 60),
            "log": str(logs / f"{stem}.jsonl"), "err": str(logs / f"{stem}.err"), "rows_before": len(self.runs()),
            "attempts": 0, "stalls": 0, "resumes": 0, "limits": 0, "lock_started": None, "phase": "killed",
            "wait_until": None, "why": "a hard stop", "child_pid": None, "child_ident": None})
        self.bl("lock", "acquire", "--slug", FTP)
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertIn("moved 4 run log(s)", out)
        self.assertTrue(self.calls()[0]["resume"])
        index = self.index()
        self.assertEqual(len(index), 5)  # 4 imported + the continued run, which ended
        run_line = index[-1]
        self.assertEqual((run_line["slug"], run_line["outcome"], run_line["attempts"]), (FTP, "closed", 2))
        self.assertEqual(run_line["dir"], traces.new_name_for_old(stem))
        self.assertFalse(logs.exists())


# ---------------------------------------------------------------------------
# Feature 344: specs/344-backlog-web-app/contracts/loop-cli-additions.md


class KillTests(Base):
    """`kill`: a hard stop from another process, handled like Ctrl+Break in the loop's window."""

    def test_kill_while_an_item_runs_is_a_hard_stop_and_the_next_start_continues(self):
        self.write_plan([{"do": "hang", "seconds": 60}, "close"])
        p = self.spawn_loop()
        pid_file = self.tmp / "fake.pid"
        self.wait_for(pid_file.exists, what="the fake's pid")
        fake_pid = int(pid_file.read_text())
        fake_ident = loop.process_ident(fake_pid)
        self.assertIsNotNone(fake_ident)
        code, out = self.ctl("kill")
        self.assertEqual(code, 0)
        self.assertIn("kill requested", out)
        self.assertEqual(p.wait(timeout=30), 130, self.output(p))
        said = self.output(p)
        self.assertIn(f"HARD STOP: claude was killed while it worked on item {FTP}.", said)
        self.assertIn("registry backup", said)
        self.assertFalse(loop.alive(fake_pid, fake_ident))
        run = loop.load_json(self.repo.run_file)
        self.assertEqual(run["phase"], "killed")
        self.assertEqual(run["why"], "a hard stop (kill) ended the process")
        self.assertEqual(self.lock_slug(), FTP)  # the item keeps the lock
        self.assertFalse(self.repo.loop_file.exists())
        self.assertFalse((self.repo.dir / "kill").exists())  # handled, removed
        (d,) = self.trace_dirs()
        self.assertEqual(json.loads((d / "meta.json").read_text(encoding="utf-8"))["phase"], "killed")
        last = self.last()
        self.assertEqual((last["pid"], last["reason"], last["exit_code"]), (p.pid, "hard-stop", 130))
        self.assertIn("HARD STOP: claude was killed", self.loop_log())
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        first, second = self.calls()
        self.assertTrue(second["resume"])
        self.assertEqual(second["session"], first["session"])
        self.assertIn("a hard stop (kill) ended the process", second["prompt"])
        self.check_trace(d, slug=FTP, reasons=("-", "killed"), outcome="closed")

    def test_kill_while_waiting_and_the_status_shows_it(self):
        self.write_plan([])
        self.bl("block", FTP, "--reason", "x")
        self.commit()
        p = self.spawn_loop("--poll", "30", "--tick", "3")
        self.wait_for(lambda: self.loop_state() == "idle", what="idle")
        code, out = self.ctl("kill")
        self.assertEqual(code, 0)
        self.assertIn("kill requested", out)
        _, status = self.ctl("status")  # the loop looks at the flag only every 3 s
        self.assertIn("kill requested", status)
        self.assertEqual(p.wait(timeout=30), 130, self.output(p))
        self.assertIn("stopped (kill) - no item of this loop was running", self.output(p))
        self.assertFalse((self.repo.dir / "kill").exists())
        self.assertEqual(self.last()["reason"], "hard-stop")
        self.assertFalse(json.loads(self.ctl("status", "--json")[1])["kill"])

    def test_kill_during_the_auto_triage(self):
        self.write_plan([{"do": "triage-hang", "seconds": 60}])
        p = self.spawn_loop("--auto-triage")
        pid_file = self.tmp / "fake.pid"
        self.wait_for(pid_file.exists, what="the fake's pid")
        fake_pid = int(pid_file.read_text())
        fake_ident = loop.process_ident(fake_pid)
        self.ctl("kill")
        self.assertEqual(p.wait(timeout=30), 130, self.output(p))
        self.assertIn("HARD STOP: claude was killed during the auto-triage", self.output(p))
        self.assertFalse(loop.alive(fake_pid, fake_ident))
        self.assertFalse(self.repo.triage_file.exists())
        (d,) = self.trace_dirs()
        self.check_trace(d, kind="triage", slug="triage", phase="killed")

    def test_kill_without_a_loop_sets_nothing(self):
        code, out = self.ctl("kill")
        self.assertEqual(code, 0)
        self.assertIn("no loop is running", out)
        self.assertFalse((self.repo.dir / "kill").exists())

    def test_a_stale_kill_is_removed_by_the_next_start(self):
        self.repo.dir.mkdir(parents=True)
        (self.repo.dir / "kill").write_text("x", encoding="utf-8")
        _, status = self.ctl("status")
        self.assertNotIn("kill requested", status)  # no loop: nothing is pending
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertEqual(len(self.calls()), 1)
        self.assertFalse((self.repo.dir / "kill").exists())


class LoopLogTests(Base):
    def test_every_line_the_loop_says_is_in_loop_log(self):
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        lines = self.loop_log().splitlines()
        for line in lines:
            self.assertRegex(line, r"^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d ")
        said = [l.split("] ", 1)[1] for l in out.splitlines()]
        self.assertEqual([l[20:] for l in lines], said)
        self.assertIn("loop started", lines[0])
        self.assertIn("loop ended", lines[-1])

    def test_loop_log_is_appended_and_rotated(self):
        self.repo.dir.mkdir(parents=True)
        log = self.repo.dir / "loop.log"
        old = b"x" * 1900 + b"\n"
        log.write_bytes(old)
        self.write_plan(["close"])
        keep = loop.LOG_MAX
        loop.LOG_MAX = 2000
        try:
            code, out = self.run_loop("--until-idle")
        finally:
            loop.LOG_MAX = keep
        self.assertEqual(code, 0, out)
        self.assertEqual((self.repo.dir / "loop.log.1").read_bytes(), old)
        self.assertLessEqual(log.stat().st_size, 2000)
        self.assertIn("loop ended", self.loop_log())

    def test_a_refused_start_is_in_the_log(self):
        self.write_plan([])
        self.bl("block", FTP, "--reason", "x")
        self.commit()
        p = self.spawn_loop()
        self.wait_for(lambda: self.loop_state() == "idle", what="idle")
        code, out = self.run_loop()
        self.assertEqual(code, 1, out)
        self.assertIn("refused: another loop is running", self.loop_log())
        self.assertIsNone(self.last())  # the other loop's record is not touched
        self.ctl("stop")
        self.assertEqual(p.wait(timeout=30), 0)
        last = self.last()
        self.assertEqual((last["pid"], last["reason"], last["exit_code"]), (p.pid, "stop", 0))


class LastTests(Base):
    """last.json: why the last loop ended."""

    def test_until_idle_and_the_fields(self):
        self.write_plan(["close"])
        code, out = self.run_loop("--until-idle", "--model", "haiku")
        self.assertEqual(code, 0, out)
        last = self.last()
        self.assertEqual(list(last), ["pid", "started", "ended", "exit_code", "reason", "counts", "items", "options"])
        self.assertEqual((last["pid"], last["exit_code"], last["reason"], last["items"]),
                         (os.getpid(), 0, "until-idle", 1))
        self.assertEqual(last["counts"]["closed"], 1)
        for key in ("started", "ended"):
            self.assertRegex(last[key], r"^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d$")
        self.assertEqual(last["options"], {"max_items": 0, "max_blocked": 3, "poll": 0.2, "model": "haiku",
                                           "until_idle": True, "forget_run": False, "auto_triage": False,
                                           "item": None})

    def test_reasons(self):
        self.add_items(3)
        self.write_plan(["close"])
        self.assertEqual(self.run_loop("--max-items", "1")[0], 0)
        self.assertEqual(self.last()["reason"], "max-items")
        self.write_plan(["block", "block"])
        self.assertEqual(self.run_loop("--max-blocked", "2")[0], 1)
        self.assertEqual(self.last()["reason"], "max-blocked")
        self.write_plan(["crash", "crash", "crash"])
        self.assertEqual(self.run_loop()[0], 1)
        self.assertEqual((self.last()["reason"], self.last()["exit_code"]), ("stopped-for-person", 1))

    def test_an_unexpected_error(self):
        args = loop.build_parser().parse_args(self.start_args())
        lp = loop.Loop(self.repo, args)

        def boom():
            raise RuntimeError("boom")
        lp.cycle = boom
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(RuntimeError):
                lp.main()
        self.assertEqual((self.last()["reason"], self.last()["exit_code"]), ("error", 1))
        self.assertFalse(self.repo.loop_file.exists())


class EditLockTests(Base):
    """The backlog app's edit lock (.git/tandem-backlog-edit.lock) holds new runs and the auto-triage."""

    def precheck(self):
        args = loop.build_parser().parse_args(self.start_args())
        return loop.Loop(self.repo, args).precheck()

    def test_a_live_lock_waits(self):
        epoch = time.time()
        path, started = self.write_edit_lock(os.getpid(), epoch)
        state, why = self.precheck()
        self.assertEqual(state, "waiting")
        self.assertEqual(why, "waiting: the backlog app is changing the backlog (since "
                              f"{dt.datetime.fromtimestamp(epoch).strftime('%H:%M:%S')})")
        data = json.loads(self.ctl("status", "--json")[1])
        self.assertEqual(data["edit_lock"], {"pid": os.getpid(), "started": started, "purpose": "move an item",
                                             "live": True})
        self.assertTrue(path.exists())

    def test_a_dead_lock_is_ignored_and_kept(self):
        dead = subprocess.Popen([sys.executable, "-c", "pass"])
        dead.wait()
        path, _ = self.write_edit_lock(dead.pid, time.time())
        self.assertEqual(self.precheck(), ("ready", FTP))
        self.assertTrue(path.exists())  # never deleted: the app replaces it
        self.assertFalse(json.loads(self.ctl("status", "--json")[1])["edit_lock"]["live"])

    def test_a_reused_pid_is_not_the_owner(self):
        created = loop.process_created(os.getpid())
        self.assertIsNotNone(created)
        self.write_edit_lock(os.getpid(), created - 10)  # taken before this process existed
        self.assertEqual(self.precheck(), ("ready", FTP))
        self.write_edit_lock(os.getpid(), created - 1)  # within the 2 s slack
        self.assertEqual(self.precheck()[0], "waiting")

    def test_no_auto_triage_while_the_app_edits(self):
        self.write_edit_lock(os.getpid(), time.time())
        self.write_plan(["triage"])
        code, out = self.run_loop("--auto-triage", "--deadline", "1.5")
        self.assertEqual(code, 3, out)
        self.assertFalse(self.plan.exists() and self.calls())
        self.assertIn("the backlog app is changing the backlog", out)

    def test_a_waiting_loop_starts_when_the_lock_is_gone(self):
        path, _ = self.write_edit_lock(os.getpid(), time.time())
        self.write_plan(["close"])
        p = self.spawn_loop("--until-idle")
        self.wait_for(lambda: "backlog app" in str((loop.load_json(self.repo.loop_file) or {}).get("detail")),
                      what="waiting for the edit lock")
        time.sleep(0.3)
        self.assertFalse(self.plan.exists() and self.calls())
        path.unlink()
        self.assertEqual(p.wait(timeout=30), 0, self.output(p))
        self.assertEqual(len(self.calls()), 1)

    def test_leaving_pause_writes_starting_resumed_before_the_precheck(self):
        args = loop.build_parser().parse_args(self.start_args())
        lp = loop.Loop(self.repo, args)
        self.ctl("pause")
        seen = []
        real_wait = lp.wait

        def wait(state, detail, until, recheck=False):
            if state == "paused":
                loop.unlink(self.repo.pause_flag)  # bin/backlog-loop.sh resume from another window
                return None
            return real_wait(state, detail, until, recheck)

        def precheck():
            seen.append(loop.load_json(self.repo.loop_file))
            raise loop.Stop(0)
        lp.wait, lp.precheck = wait, precheck
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(lp.main(), 0)
        self.assertEqual((seen[0]["state"], seen[0]["detail"]), ("starting", "resumed"))

    def test_status_json_has_the_new_keys(self):
        data = json.loads(self.ctl("status", "--json")[1])
        for key in ("loop", "live", "run", "triage", "paused", "stop", "lock", "lock_text", "trace", "traces_bytes"):
            self.assertIn(key, data)
        self.assertEqual((data["kill"], data["last"], data["edit_lock"], data["orphan"]), (False, None, None, False))
        self.assertEqual(Path(data["log"]), self.repo.dir / "loop.log")
        self.write_plan(["close"])
        self.run_loop("--until-idle")
        self.assertEqual(json.loads(self.ctl("status", "--json")[1])["last"]["reason"], "until-idle")


class ItemTests(Base):
    """start --item SLUG: one run of a named item."""

    def next_rows(self):
        return [r.slug for r in backlog.Backlog(self.root).ov.sections[backlog.SEC_NEXT].rows]

    def test_a_named_item_runs_once_and_the_order_stays(self):
        slugs = self.add_items(2)
        before = self.next_rows()
        self.write_plan(["close", "close"])
        code, out = self.run_loop("--item", slugs[1])
        self.assertEqual(code, 0, out)
        self.assertEqual([c["slug"] for c in self.calls()], [slugs[1]])
        self.assertEqual(self.runs()[-1][1:3], [slugs[1], "closed"])
        self.assertEqual(self.next_rows(), [s for s in before if s != slugs[1]])
        (d,) = self.trace_dirs()
        self.check_trace(d, slug=slugs[1], outcome="closed")
        last = self.last()
        self.assertEqual((last["reason"], last["exit_code"]), ("item-done", 0))
        self.assertEqual((last["options"]["item"], last["options"]["max_items"]), (slugs[1], 1))

    def test_a_named_items_run_is_continued_like_any_run(self):
        self.write_plan(["stall", "close", "close"])
        code, out = self.run_loop("--item", FTP)
        self.assertEqual(code, 0, out)
        self.assertEqual([c["resume"] for c in self.calls()], [False, True])  # continued as any run
        self.assertEqual(self.last()["reason"], "item-done")

    def test_a_not_eligible_item_is_refused(self):
        self.write_plan(["close"])
        code, out = self.run_loop("--item", DISK)  # blocked in the fixture
        self.assertEqual(code, 1, out)
        self.assertIn(f"refused: item {DISK} is not eligible (status blocked)", out)
        self.assertFalse(self.plan.exists() and self.calls())
        self.assertFalse(self.repo.loop_file.exists())
        self.assertEqual((self.last()["reason"], self.last()["exit_code"]), ("refused", 1))
        code, out = self.run_loop("--item", "no-such-item")
        self.assertEqual(code, 1, out)
        self.assertIn("refused: item no-such-item is not eligible", out)

    def test_refused_while_an_interrupted_run_must_be_continued(self):
        slugs = self.add_items(1)
        self.pending_record("killed", why="a hard stop")
        self.bl("lock", "acquire", "--slug", FTP)
        self.write_plan(["close"])
        code, out = self.run_loop("--item", slugs[0])
        self.assertEqual(code, 1, out)
        self.assertIn(f"an interrupted run of {FTP} must be continued first", out)
        self.assertFalse(self.plan.exists() and self.calls())
        self.assertTrue(self.repo.run_file.exists())

    def test_with_until_idle_is_a_usage_error(self):
        code, out = self.run_loop("--item", FTP, "--until-idle")
        self.assertEqual(code, 2, out)
        self.assertFalse(self.repo.loop_file.exists())


@unittest.skipUnless(os.name == "nt", "a new console window is Windows")
class NewWindowTests(Base):
    """start --new-window, started hidden (--new-window-hidden): no window pops up on the maintainer's desktop."""

    def tearDown(self):
        live = self.repo.live_loop()
        if live and live.get("pid") != os.getpid():
            loop.kill_tree(live["pid"])
        super().tearDown()

    def test_start_in_a_new_window(self):
        self.write_plan([])
        self.bl("block", FTP, "--reason", "x")
        self.commit()
        code, out = self.run_loop("--new-window", "--new-window-hidden")
        self.assertEqual(code, 0, out)
        m = re.search(r"^started the loop in a new window \(pid (\d+)\)$", out, re.M)
        self.assertIsNotNone(m, out)
        pid = int(m.group(1))
        data = loop.load_json(self.repo.loop_file)
        self.assertEqual(data["pid"], pid)
        self.assertTrue(loop.alive(pid, data["ident"]))
        self.wait_for(lambda: self.loop_state() == "idle", what="idle")
        code, out = self.run_loop("--new-window", "--new-window-hidden")
        self.assertEqual(code, 1, out)
        self.assertIn("another loop is running", out)
        self.ctl("stop")
        self.wait_for(lambda: not self.repo.loop_file.exists(), what="the loop ended")
        self.wait_for(lambda: (self.last() or {}).get("pid") == pid, what="its last.json")
        self.assertEqual(self.last()["reason"], "stop")
        self.assertIn(f"loop started (pid {pid})", self.loop_log())

    def test_an_error_of_the_new_loop_is_reported_from_its_log(self):
        self.write_plan(["close"])
        code, out = self.run_loop("--new-window", "--new-window-hidden", "--item", DISK)
        self.assertEqual(code, 1, out)
        self.assertIn(f"item {DISK} is not eligible (status blocked)", out)
        self.assertNotIn("started the loop", out)
        self.assertFalse(self.plan.exists() and self.calls())


if __name__ == "__main__":
    unittest.main()
