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
import io
import json
import os
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

VALID = HERE / "fixtures" / "valid"
FAKE = HERE / "fixtures" / "fake_claude.py"
LOOP = HERE / "loop.py"
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
        logs = list(self.repo.logs.glob("*.jsonl"))
        self.assertEqual(len(logs), 2)

    def test_caller_watchdog_setting_is_kept(self):
        self.write_plan(["close"])
        os.environ["CLAUDE_CODE_RETRY_WATCHDOG"] = "0"
        try:
            self.run_loop("--until-idle")
        finally:
            os.environ.pop("CLAUDE_CODE_RETRY_WATCHDOG")
        self.assertEqual(self.calls()[0]["watchdog"], "0")

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

    def test_too_many_errors_stop_and_the_record_stays(self):
        self.write_plan(["crash", "crash", "crash", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual(len(self.calls()), 3)
        run = loop.load_json(self.repo.run_file)
        self.assertEqual(run["phase"], "failed")
        _, status = self.ctl("status")
        self.assertIn("cannot be continued automatically", status)
        self.assertIn("--forget-run", status)
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

    def test_a_turn_ended_early_is_continued_at_most_twice(self):
        self.write_plan(["stall", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertEqual([c["resume"] for c in self.calls()], [False, True])
        self.tearDown()
        self.setUp()
        self.write_plan(["stall", "stall", "stall", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual(len(self.calls()), 3)
        self.assertIn("without finishing", out)

    def test_a_lost_session_stops_the_loop(self):
        self.write_plan([{"do": "limit", "in": 0}, "lost"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 1, out)
        self.assertEqual(loop.load_json(self.repo.run_file)["phase"], "lost")
        self.assertIn("cannot be continued", out)
        self.assertEqual(self.lock_slug(), FTP)

    def test_refusals(self):
        self.write_plan(["refuse", "close"])
        code, out = self.run_loop("--until-idle")
        self.assertEqual(code, 0, out)
        self.assertEqual(len(self.calls()), 2)
        self.assertIn("did not take the item", out)
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

    def pending_record(self, phase, **extra):
        self.repo.dir.mkdir(parents=True, exist_ok=True)
        run = {"slug": FTP, "session": "22222222-2222-4222-8222-222222222222", "started": loop.stamp(time.time() - 60),
               "log": str(self.tmp / "p.jsonl"), "err": str(self.tmp / "p.err"), "rows_before": len(self.runs()),
               "attempts": 0, "stalls": 0, "resumes": 0, "limits": 0, "lock_started": None, "phase": phase,
               "wait_until": None, "why": None, "child_pid": None, "child_ident": None}
        run.update(extra)
        loop.save_json(self.repo.run_file, run)
        return run

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
        self.assertIn("is still working; the next loop-start.sh waits for it", status)  # review 2 N5
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

    def test_files_live_in_the_git_dir_not_in_the_tree(self):
        self.ctl("pause")
        self.assertEqual(self.repo.dir.parent.resolve(), (self.root / ".git").resolve())
        self.assertEqual(git(self.root, "status", "--porcelain"), "")

    def test_wrappers(self):
        bash = git_bash()
        if not bash:
            self.skipTest("needs Git Bash")

        def sh(name, *args):
            r = subprocess.run([bash, str(HERE / name), "--root", str(self.root), *args], capture_output=True,
                               text=True, encoding="utf-8")
            return r.returncode, r.stdout + r.stderr
        self.assertEqual(sh("loop-status.sh")[0], 0)
        self.assertIn("loop:    not running", sh("loop-status.sh")[1])
        self.assertIn("starts paused", sh("loop-pause.sh")[1])
        self.assertIn("pause requested", sh("loop-status.sh")[1])
        self.assertIn("pause cleared", sh("loop-resume.sh")[1])
        self.assertIn("no loop is running", sh("loop-stop.sh")[1])
        code, out = sh("loop-start.sh", "--help")
        self.assertEqual(code, 0)
        self.assertIn("--max-items", out)
        self.write_plan(["close"])
        # forward slashes: bash collapses the doubled backslashes of JSON on the way to a native program
        cmd = json.dumps([Path(sys.executable).as_posix(), FAKE.as_posix()])
        code, out = sh("loop-start.sh", "--claude-cmd", cmd, *FAST, "--until-idle")
        self.assertEqual(code, 0, out)
        self.assertIn("closed 1", out)
        for name in ("loop-start.sh", "loop-pause.sh", "loop-resume.sh", "loop-stop.sh", "loop-status.sh"):
            self.assertNotIn(b"\r", (HERE / name).read_bytes(), name)


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


class PruneTests(Base):
    def test_old_logs_are_pruned_the_current_kept(self):
        self.repo.logs.mkdir(parents=True)
        for i in range(loop.KEEP_LOGS + 5):
            (self.repo.logs / f"2026{i:04d}-x.jsonl").write_text("", encoding="utf-8")
            (self.repo.logs / f"2026{i:04d}-x.err").write_text("", encoding="utf-8")
        loop.save_json(self.repo.run_file, {"log": str(self.repo.logs / "20260000-x.jsonl"), "phase": "lost",
                                            "slug": FTP, "session": "s"})
        args = loop.build_parser().parse_args(self.start_args())
        loop.Loop(self.repo, args).prune_logs()
        names = {p.name for p in self.repo.logs.iterdir()}
        self.assertEqual(len([n for n in names if n.endswith(".jsonl")]), loop.KEEP_LOGS + 1)
        self.assertIn("20260000-x.jsonl", names)
        self.assertIn("20260000-x.err", names)
        self.assertNotIn("20260001-x.jsonl", names)


if __name__ == "__main__":
    unittest.main()
