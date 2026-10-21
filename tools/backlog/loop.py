#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Loop over /tandem-backlog-implement - one fresh claude process per item (feature 247).

The maintainer uses the wrappers in tools/backlog/ (Git Bash):

  loop-start.sh   run the loop in this window (Ctrl+C = hard stop)
  loop-pause.sh   finish the running item, then wait for loop-resume.sh
  loop-resume.sh  continue after a pause (also cancels a pending stop)
  loop-stop.sh    finish the running item, then end the loop
  loop-status.sh  what the loop does now

Design (specs/247-backlog-run-loop/spec.md, contract contracts/loop-cli.md):

* The loop never changes the tree, the backlog or the lock: the runs do.
  It reads the outcome of a run from backlog/RUNS.md (a new row) and the
  run lock (released) - never from the model's text.
* Control and state files live in the git common dir, next to the run
  lock (``.git/tandem-backlog-loop/``): the working tree stays clean.
* claude runs in its unattended retry mode (CLAUDE_CODE_RETRY_WATCHDOG=1),
  which waits out a usage limit inside the process.  A run that ends
  while its item still holds the lock is continued in the same session
  (``--resume``) - after the reported reset of a limit, after a growing
  pause for an error, or at once after Ctrl+C.
* With --auto-triage, between two runs, whenever the Inbox holds an item
  the last triage did not see (at the start: any item), the loop starts
  ``claude -p '/tandem-backlog auto-triage --commit'`` and waits for it,
  so that a finding of the last run is placed before the next item is
  chosen.  The triage commits on main itself; the loop checks afterwards
  that the tree is clean, on main and consistent.

Standard library only.  Exit codes: 0 the loop ended as asked (stop,
--max-items, --until-idle), 1 it stopped for a person or was refused,
2 usage, 130 Ctrl+C.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import time
import uuid
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import backlog  # noqa: E402

LOOP_DIR = "tandem-backlog-loop"
SKILL = "tandem-backlog-implement"
DEFAULT_POLL = 60.0
DEFAULT_MAX_BLOCKED = 3
BACKOFF = [60.0, 300.0, 900.0, 1800.0, 3600.0]  # pauses before continuing after an error
LIMIT_MARGIN = 120.0         # after the reported reset of a usage limit
LIMIT_UNKNOWN_WAIT = 1800.0  # a limit without a reported reset: try again after this
MAX_STALLS = 2               # continuations of a run that ended its turn without finishing
MAX_REFUSALS = 2             # runs in a row that did not take their item
MAX_LIMITS = 10              # continuations of one run after usage limits (claude waits most out itself)
KEEP_LOGS = 100
TICK = 1.0                   # how often waits look at pause / stop
STILL_ACTIVE = 259

RESUME_PROMPT = (
    "The run of /tandem-backlog-implement in this session was interrupted ({why}). "
    "Continue it exactly where it stopped, for the same item, following the skill to its end "
    "(SKILL.md 'Continued run'): first find where you were (git branch, git status, "
    "the lock status, the fix-log, the last steps above); if a GUI probe was interrupted, "
    "restore its registry backup first (stop-rules section 2.8). Do not repeat steps "
    "that are complete. One item only; end with the final message of section 11."
)

TRIAGE_PROMPT = "/tandem-backlog auto-triage --commit"
TRIAGE_ENV = "TANDEM_BACKLOG_LOOP_TRIAGE"  # the loop's pid: lets the skill tell the loop's triage from a stray one

LOST_RE = re.compile(r"No conversation found", re.I)
# only for an error result without an HTTP status; "Context limit reached" must not match (review S2)
LIMIT_TEXT_RE = re.compile(r"\b(usage|session|weekly|5-hour|five.hour)\s+limit\b|\bhit your (\w+ )?limit\b", re.I)


# ---------------------------------------------------------------------------
# Small helpers


def stamp(t: float | None = None) -> str:
    return dt.datetime.fromtimestamp(time.time() if t is None else t).strftime("%Y-%m-%d %H:%M:%S")


def clock(t: float) -> str:
    """A time for the window: HH:MM today, else the date too."""
    d = dt.datetime.fromtimestamp(t)
    if d.date() == dt.date.today():
        return d.strftime("%H:%M")
    return d.strftime("%Y-%m-%d %H:%M")


def say(text: str) -> None:
    print(f"[{dt.datetime.now().strftime('%H:%M')}] {text}", flush=True)


def load_json(path: Path) -> dict | None:
    for _ in range(40):
        try:
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        except FileNotFoundError:
            return None
        except (PermissionError, json.JSONDecodeError):
            time.sleep(0.05)  # a writer is replacing it
    return None


def save_json(path: Path, data: dict) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=1) + "\n"
    for attempt in range(100):
        try:
            backlog.write_text(path, text)
            return
        except PermissionError:  # a reader has it open (Windows)
            if attempt == 99:
                raise
            time.sleep(0.05)


def unlink(path: Path) -> None:
    for attempt in range(40):
        try:
            path.unlink()
            return
        except FileNotFoundError:
            return
        except PermissionError:
            if attempt == 39:
                raise
            time.sleep(0.05)


# ---------------------------------------------------------------------------
# Processes


def process_ident(pid: int | None) -> int | None:
    """An identity of a live process (its creation time), None if it does not run.
    Comparing it with the recorded one guards against a reused pid."""
    if not pid:
        return None
    if os.name == "nt":
        import ctypes
        from ctypes import wintypes
        k32 = ctypes.WinDLL("kernel32", use_last_error=True)
        k32.OpenProcess.restype = wintypes.HANDLE
        k32.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        k32.GetExitCodeProcess.argtypes = [wintypes.HANDLE, ctypes.POINTER(wintypes.DWORD)]
        k32.GetProcessTimes.argtypes = [wintypes.HANDLE] + [ctypes.POINTER(wintypes.FILETIME)] * 4
        k32.CloseHandle.argtypes = [wintypes.HANDLE]
        h = k32.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
        if not h:
            return None
        try:
            code = wintypes.DWORD()
            if not k32.GetExitCodeProcess(h, ctypes.byref(code)) or code.value != STILL_ACTIVE:
                return None
            times = [wintypes.FILETIME() for _ in range(4)]
            if not k32.GetProcessTimes(h, *(ctypes.byref(t) for t in times)):
                return None
            return (times[0].dwHighDateTime << 32) | times[0].dwLowDateTime
        finally:
            k32.CloseHandle(h)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return None
    except PermissionError:
        pass
    try:
        return int(Path(f"/proc/{pid}/stat").read_text().rsplit(")", 1)[1].split()[19])
    except (OSError, ValueError, IndexError):
        return 0


def alive(pid: int | None, ident: int | None) -> bool:
    return ident is not None and process_ident(pid) == ident


def kill_tree(pid: int) -> None:
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True)
    else:
        try:
            os.killpg(os.getpgid(pid), signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass


def _interrupt(signum, frame):
    raise KeyboardInterrupt


# ---------------------------------------------------------------------------
# The repository


class Repo:
    def __init__(self, root: Path):
        self.root = root
        self.lock_path = backlog.lock_path(root, None)
        self.dir = self.lock_path.parent / LOOP_DIR
        self.loop_file = self.dir / "loop.json"
        self.run_file = self.dir / "run.json"
        self.triage_file = self.dir / "triage.json"
        self.pause_flag = self.dir / "pause"
        self.stop_flag = self.dir / "stop"
        self.logs = self.dir / "logs"

    def git(self, *args: str) -> str:
        return backlog.git(self.root, *args)

    def lock(self) -> dict | None:
        """The run lock's fields, or None if it is free."""
        for attempt in range(40):
            try:
                return backlog.read_lock(self.lock_path)
            except FileNotFoundError:
                return None
            except PermissionError:  # being replaced (lock update)
                if attempt == 39:
                    raise
                time.sleep(0.05)

    def lock_text(self) -> str:
        fields = self.lock()
        return "free" if fields is None else backlog.describe_lock(fields)

    def runs(self) -> list:
        """The rows of backlog/RUNS.md as lists of cells."""
        path = self.root / "backlog" / "RUNS.md"
        for attempt in range(40):
            try:
                lines = backlog.read_text(path).split("\n")
                break
            except PermissionError:  # being replaced by run-log; [] would fake rows_before (review 2 N6)
                if attempt == 39:
                    raise
                time.sleep(0.05)
            except (FileNotFoundError, UnicodeDecodeError):
                return []
        blocks = backlog.table_blocks(lines, 0, len(lines))
        if len(blocks) != 1:
            return []
        a, b = blocks[0]
        return [backlog.split_row(lines[r]) for r in range(a + 2, b)]

    def live_loop(self) -> dict | None:
        data = load_json(self.loop_file)
        if data and alive(data.get("pid"), data.get("ident")):
            return data
        return None


# ---------------------------------------------------------------------------
# What a claude log says (stream-json, one object per line)


class LogInfo:
    def __init__(self):
        self.result = None       # the last {"type": "result"} object
        self.rate_limit = None   # the last rate_limit_info
        self.lost = False        # --resume found no session
        self.stderr_tail = ""

    @property
    def is_error(self) -> bool:
        return self.result is None or bool(self.result.get("is_error"))

    @property
    def text(self) -> str:
        return str((self.result or {}).get("result") or "")

    @property
    def limited(self) -> bool:
        """The attempt ended because of a usage limit.  A successful attempt never did:
        a 'rejected' event before it only means claude waited the limit out (review S1)."""
        if not self.is_error:
            return False
        if self.result is not None and self.result.get("api_error_status") == 429:
            return True
        if self.result is None and self.rate_limit and self.rate_limit.get("status") == "rejected":
            return True  # it died while waiting; an error result after a waited-out limit is an error (review 2 N3)
        return self.result is not None and self.result.get("api_error_status") is None \
            and bool(LIMIT_TEXT_RE.search(self.text))

    @property
    def reset_at(self) -> float | None:
        rl = self.rate_limit or {}
        try:
            value = float(rl.get("resetsAt"))
        except (TypeError, ValueError):
            return None
        return value if value > 0 else None

    @property
    def refused(self) -> bool:
        # also "**Outcome:** refused" and similar Markdown (review 2 N2)
        return bool(re.search(r"^[\s*_`>#-]*Outcome[\s*_`]*:[\s*_`]*refused", self.text, re.M | re.I))


def read_lines(path: Path, offset: int) -> tuple:
    """Complete lines from offset; (lines, new offset)."""
    try:
        with open(path, "rb") as f:
            f.seek(offset)
            data = f.read()
    except FileNotFoundError:
        return [], offset
    end = data.rfind(b"\n")
    if end < 0:
        return [], offset
    return data[: end + 1].decode("utf-8", "replace").splitlines(), offset + end + 1


def scan(lines: list, info: LogInfo) -> None:
    for line in lines:
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            continue
        kind = obj.get("type")
        if kind == "result":
            info.result = obj
        elif kind == "rate_limit_event" and isinstance(obj.get("rate_limit_info"), dict):
            info.rate_limit = obj["rate_limit_info"]


def log_info(run: dict) -> LogInfo:
    info = LogInfo()
    lines, _ = read_lines(Path(run["log"]), run.get("offset", 0))
    scan(lines, info)
    try:
        with open(run["err"], "rb") as f:
            f.seek(run.get("err_offset", 0))
            info.stderr_tail = f.read().decode("utf-8", "replace")[-2000:]
    except FileNotFoundError:
        pass
    info.lost = bool(LOST_RE.search(info.stderr_tail))
    return info


def lock_words(lock: dict) -> str:
    """The lock without its age: a wait's text must not change every few minutes (review 2 N7)."""
    return f"item {lock.get('slug', '-')}, branch {lock.get('branch', '-')}, since {lock.get('started', '?')}"


def inbox_slugs(bl) -> list:
    sec = bl.ov.sections.get(backlog.SEC_INBOX) if bl.ov is not None else None
    return [r.slug for r in sec.rows if r.slug] if sec else []


def last_words(info: LogInfo) -> str:
    """The last line claude left: its result text, else stderr."""
    text = (info.text or "").strip() or info.stderr_tail.strip()
    return text.splitlines()[-1].strip()[:200] if text else "no result"


def usage_line(rl: dict | None) -> str:
    if not rl:
        return "-"
    parts = []
    windows = rl.get("unifiedWindows") or {}
    for name in ("five_hour", "seven_day"):
        w = windows.get(name)
        if isinstance(w, dict) and w.get("utilization") is not None:
            text = f"{name} {round(float(w['utilization']) * 100)}%"
            if w.get("resetsAt"):
                text += f" (resets {clock(float(w['resetsAt']))})"
            parts.append(text)
    if not parts and rl.get("rateLimitType"):
        parts.append(str(rl.get("rateLimitType")))
    status = rl.get("status", "?")
    return f"{status}: " + (", ".join(parts) if parts else "-")


# ---------------------------------------------------------------------------
# The loop


class Stop(Exception):
    """End the loop with this exit code (the message was said)."""

    def __init__(self, code: int):
        super().__init__(code)
        self.code = code


class Loop:
    def __init__(self, repo: Repo, args):
        self.repo = repo
        self.args = args
        self.claude = args.claude_cmd
        self.poll = args.poll
        self.tick = args.tick
        self.backoff = args.backoff
        self.limit_margin = args.limit_margin
        self.limit_unknown_wait = args.limit_unknown_wait
        self.counts = {o: 0 for o in backlog.RUN_OUTCOMES}
        self.items = 0
        self.blocked_streak = 0
        self.refusals = 0
        self.start_errors = 0
        self.state = None
        self.since = None
        self.safe = True
        self.last_said = None
        self.child = None
        self.run = None
        self.usage = None
        self.started = time.time()
        self.triaged = None      # the Inbox slugs after the last auto-triage (None: none yet)
        self.triages = 0
        self.triage_errors = 0
        self.triage_limits = 0
        self.triage_refusals = 0

    # -- the loop's own record -------------------------------------------

    def register(self) -> None:
        self.repo.dir.mkdir(parents=True, exist_ok=True)
        me = {"pid": os.getpid(), "ident": process_ident(os.getpid()), "host": socket.gethostname(),
              "started": stamp(self.started)}
        for _ in range(2):
            try:
                fd = os.open(self.repo.loop_file, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
            except FileExistsError:
                other = load_json(self.repo.loop_file) or {}
                if alive(other.get("pid"), other.get("ident")):
                    print(f"refused: another loop is running (pid {other.get('pid')}, since {other.get('started', '?')}); "
                          "tools/backlog/loop-status.sh shows it, loop-stop.sh ends it", flush=True)
                    raise Stop(1)
                say(f"a loop record of pid {other.get('pid', '?')} remained (that loop ended without cleanup); taking over")
                unlink(self.repo.loop_file)
                continue
            os.close(fd)
            self.me = me
            # a stop is meant for a running loop; one left by a loop that was killed
            # (or that ended while the stop was being set) must not end this one (review N1)
            unlink(self.repo.stop_flag)
            self.write_state("starting", "-")
            return
        print("refused: the loop record cannot be created", flush=True)
        raise Stop(1)

    def unregister(self) -> None:
        data = load_json(self.repo.loop_file) or {}
        if data.get("pid") == os.getpid():
            unlink(self.repo.loop_file)
        unlink(self.repo.stop_flag)

    def write_state(self, state: str, detail: str, until: float | None = None, safe: bool | None = None) -> None:
        if (state, detail) != self.state:
            self.since = stamp()
        if safe is not None:
            self.safe = safe
        data = dict(self.me)
        data.update({
            "state": state, "detail": detail, "until": stamp(until) if until else None,
            "ctrl_c_safe": self.safe,
            "since": self.since, "updated": stamp(), "slug": (self.run or {}).get("slug"), "session": (self.run or {}).get("session"),
            "log": (self.run or {}).get("log"), "counts": self.counts, "items": self.items,
            "blocked_streak": self.blocked_streak, "usage": self.usage,
            "auto_triage": bool(self.args.auto_triage), "triages": self.triages,
        })
        self.state = (state, detail)
        save_json(self.repo.loop_file, data)

    def announce(self, state: str, detail: str, until: float | None = None, safe: bool = True) -> None:
        """Record the state; say it in the window when it changed."""
        self.write_state(state, detail, until, safe)
        key = (state, detail, until)
        if key != self.last_said:
            self.last_said = key
            tail = " (Ctrl+C is safe now)" if safe else " (Ctrl+C now = hard stop)"
            say(f"{detail}{tail}")

    # -- control ------------------------------------------------------------

    def stop_requested(self) -> bool:
        if self.args.deadline and time.time() - self.started > self.args.deadline:
            say(f"deadline of {self.args.deadline:g} s reached (--deadline) - the loop ends")
            raise Stop(3)
        return self.repo.stop_flag.exists()

    def paused(self) -> bool:
        return self.repo.pause_flag.exists()

    def wait(self, state: str, detail: str, until: float | None, recheck: bool = False) -> None:
        """Wait until `until` (None = for ever); returns early on stop / pause, or after
        one poll interval when recheck is set (the caller looks again)."""
        self.announce(state, detail, until)
        end = until if until is not None else (time.time() + self.poll if recheck else None)
        while True:
            if self.stop_requested():
                return
            if state != "paused" and self.paused():
                return
            if state == "paused" and not self.paused():
                return
            now = time.time()
            if end is not None and now >= end:
                return
            time.sleep(min(self.tick, end - now) if end is not None else self.tick)
            self.write_state(state, detail, until)  # heartbeat

    # -- one run ----------------------------------------------------------

    def new_run(self, slug: str) -> dict:
        self.repo.logs.mkdir(parents=True, exist_ok=True)
        name = dt.datetime.now().strftime("%Y%m%d-%H%M%S") + "-" + slug
        run = {
            "slug": slug, "session": str(uuid.uuid4()), "started": stamp(),
            "log": str(self.repo.logs / f"{name}.jsonl"), "err": str(self.repo.logs / f"{name}.err"),
            "rows_before": len(self.repo.runs()), "attempts": 0, "stalls": 0, "resumes": 0, "limits": 0,
            "lock_started": None, "phase": "new", "wait_until": None, "why": None, "child_pid": None, "child_ident": None,
        }
        save_json(self.repo.run_file, run)
        return run

    def save_run(self) -> None:
        save_json(self.repo.run_file, self.run)

    def drop_run(self) -> None:
        unlink(self.repo.run_file)
        self.run = None

    def execute(self, resume: bool) -> None:
        """Start claude for self.run and wait until it ends."""
        run = self.run
        if resume:
            prompt = RESUME_PROMPT.format(why=run.get("why") or "the process ended")
            session = ["--resume", run["session"]]
            run["resumes"] += 1
        else:
            prompt = f"/{SKILL} {run['slug']}"
            session = ["--session-id", run["session"]]
        cmd = list(self.claude) + ["-p", prompt, "--output-format", "stream-json", "--verbose",
                                   "--permission-mode", "bypassPermissions", *session]
        if self.args.model:
            cmd += ["--model", self.args.model]
        env = os.environ.copy()
        env.pop("TANDEM_BACKLOG_NOW", None)  # a test clock would date the run's lock wrongly (review 2 N1)
        env.setdefault("CLAUDE_CODE_RETRY_WATCHDOG", "1")
        flags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
        with open(run["log"], "ab") as out, open(run["err"], "ab") as err:
            run["offset"], run["err_offset"] = out.tell(), err.tell()
            try:
                self.child = subprocess.Popen(cmd, cwd=str(self.repo.root), stdin=subprocess.DEVNULL, stdout=out,
                                              stderr=err, env=env, creationflags=flags,
                                              start_new_session=(os.name != "nt"))
            except OSError as e:
                if not resume:
                    self.drop_run()
                say(f"claude cannot be started ({e}) - the loop stops")
                raise Stop(1)
        run.update({"phase": "running", "wait_until": None, "child_pid": self.child.pid,
                    "child_ident": process_ident(self.child.pid)})
        self.save_run()
        verb = "continuing" if resume else "running"
        detail = f"{verb} item {run['slug']} (session {run['session'][:8]}, log {Path(run['log']).name})"
        self.announce("running", detail, safe=False)
        self.watch(lambda: self.child.poll() is None, detail)
        self.child = None
        run.update({"child_pid": None, "child_ident": None})
        self.save_run()

    def watch(self, running, detail: str, safe: bool = False, source: dict | None = None,
              what: str = "this item", state: str = "running") -> None:
        """Wait while running(); keep the usage figures and the requests visible."""
        source = source or self.run
        offset = source.get("offset", 0)
        info = LogInfo()
        told = set()
        while running():
            if self.args.deadline and time.time() - self.started > self.args.deadline:
                if self.child is not None:
                    kill_tree(self.child.pid)
                self.stop_requested()  # raises Stop
            lines, offset = read_lines(Path(source["log"]), offset)
            if lines:
                scan(lines, info)
                if info.rate_limit:
                    self.usage = info.rate_limit
            state_detail = detail
            if info.rate_limit and info.rate_limit.get("status") == "rejected":
                reset = info.reset_at
                state_detail = detail + "; claude waits for the usage limit" + (f" until {clock(reset)}" if reset else "")
            for flag, text in (("pause", f"pause requested - the loop pauses after {what}"),
                               ("stop", f"stop requested - the loop ends after {what}")):
                if flag not in told and (self.paused() if flag == "pause" else self.stop_requested()):
                    told.add(flag)
                    say(text)
            self.announce(state, state_detail, safe=safe)
            time.sleep(self.tick)

    def our_row(self, rows: list) -> str | None:
        """The outcome of a journal row of this run's item written since it started."""
        for r in rows[self.run["rows_before"]:]:
            if len(r) > 2 and r[1] == self.run["slug"]:
                return r[2]
        return None

    def holds(self, lock: dict | None) -> bool:
        """The run lock is this run's: its item, taken after the run started, and - once
        seen - the very same lock (the file has no session id; review M1)."""
        run = self.run
        if lock is None or lock.get("slug") != run["slug"]:
            return False
        if run.get("lock_started"):
            return lock.get("started") == run["lock_started"]
        try:
            taken = dt.datetime.fromisoformat(lock.get("started", ""))
            began = dt.datetime.fromisoformat(run["started"])
        except (TypeError, ValueError):
            return False
        return taken >= began - dt.timedelta(seconds=2)

    def assess(self) -> tuple:
        """What the run's state is now: (verdict, detail)."""
        run = self.run
        rows = self.repo.runs()
        lock = self.repo.lock()
        mine = self.holds(lock)
        outcome = self.our_row(rows)
        if outcome is not None and not mine:
            return "finished", outcome
        info = log_info(run)
        if info.rate_limit:
            self.usage = info.rate_limit
        if mine and not info.is_error and info.refused:
            if run.get("lock_started") is None and run.get("resumes", 0) == 0:
                # a first attempt refused while the item's lock was taken by another run
                # (a manual one): never continue that - it is not ours (review M1)
                return "refused", info
            # a continuation refused although the loop saw this lock as the run's own:
            # keep the record (the session) and stop for a person (review 2 S1)
            return "refused-own", info
        if mine:
            run["lock_started"] = lock.get("started")
            if info.lost:
                return "lost", info.stderr_tail.strip().splitlines()[-1] if info.stderr_tail.strip() else "session not found"
            if info.limited:
                return "limit", info
            if info.is_error:
                return "error", info
            return "stalled", info
        if info.lost:
            return "start-error", info
        if info.limited:
            return "start-limit", info
        if info.result is not None and not info.is_error:
            return ("refused" if info.refused else "unrecorded"), info
        return "start-error", info

    def limit_until(self, info: LogInfo) -> float:
        reset = info.reset_at
        if reset is None or reset < time.time():
            return time.time() + self.limit_unknown_wait
        return reset + self.limit_margin

    def conclude(self) -> None:
        """Act on the state of self.run after its process ended."""
        run = self.run
        verdict, detail = self.assess()
        slug = run["slug"]
        if verdict == "finished":
            self.drop_run()
            self.refusals = self.start_errors = 0
            outcome = detail
            if outcome in self.counts:
                self.counts[outcome] += 1
            if outcome != "nothing-to-do":
                self.items += 1
            say(f"item {slug}: {outcome}")
            self.blocked_streak = self.blocked_streak + 1 if outcome == "blocked" else 0
            if self.blocked_streak >= self.args.max_blocked:
                say(f"{self.blocked_streak} runs in a row ended blocked - the loop stops; look at backlog/RUNS.md and the items' block reasons")
                raise Stop(1)
            return
        if verdict == "lost":
            run["phase"] = "lost"
            run["why"] = detail
            self.save_run()
            say(f"item {slug}: the session cannot be continued ({detail}). The loop stops.")
            say(f"the item still holds the run lock; see loop-status.sh for what to do")
            raise Stop(1)
        if verdict == "refused-own":
            run.update({"phase": "failed", "why": f"a continuation refused its own run ({last_words(detail)})"})
            self.save_run()
            say(f"item {slug}: the continued run refused although it holds the item's lock ({last_words(detail)}) - "
                f"the loop stops; log {run['log']}")
            raise Stop(1)
        if verdict == "limit":
            run["limits"] = run.get("limits", 0) + 1
            if run["limits"] > MAX_LIMITS:
                run.update({"phase": "failed", "why": "interrupted by usage limits too often"})
                self.save_run()
                say(f"item {slug}: interrupted by a usage limit {run['limits']} times - the loop stops; log {run['log']}")
                raise Stop(1)
            until = self.limit_until(detail)
            run.update({"phase": "waiting", "wait_until": until, "why": "a usage limit"})
            self.save_run()
            say(f"item {slug}: interrupted by a usage limit; continuing after {clock(until)}")
            return
        if verdict == "error":
            run["attempts"] += 1
            if run["attempts"] > len(self.backoff):
                run.update({"phase": "failed", "why": "errors"})
                self.save_run()
                say(f"item {slug}: the run ended with an error {run['attempts']} times - the loop stops; "
                    f"log {run['log']}")
                raise Stop(1)
            until = time.time() + self.backoff[run["attempts"] - 1]
            why = last_words(detail)
            run.update({"phase": "waiting", "wait_until": until, "why": f"an error: {why}"})
            self.save_run()
            say(f"item {slug}: the run ended with an error ({why}); continuing after {clock(until)}")
            return
        if verdict == "stalled":
            run["stalls"] += 1
            if run["stalls"] > MAX_STALLS:
                run.update({"phase": "failed", "why": "ended its turn without finishing"})
                self.save_run()
                say(f"item {slug}: the run ended {run['stalls']} times without finishing the item - the loop stops; "
                    f"log {run['log']}")
                raise Stop(1)
            run.update({"phase": "waiting", "wait_until": time.time(), "why": "the turn ended before the run finished"})
            self.save_run()
            say(f"item {slug}: the run ended its turn before finishing; continuing it")
            return
        # the run never took its item
        log = run["log"]
        self.drop_run()
        if verdict in ("refused", "unrecorded"):
            self.refusals += 1
            last = (detail.text.strip().splitlines() or ["-"])
            words = "; ".join(l.strip() for l in last[:3])[:300]
            if verdict == "refused":
                say(f"item {slug}: the run did not take the item ({words})")
            else:
                say(f"item {slug}: the run ended without a journal row for the item and without the lock ({words}); "
                    "look at backlog/RUNS.md and the item")
            if self.refusals >= MAX_REFUSALS:
                say(f"{self.refusals} runs in a row did not take their item - the loop stops")
                raise Stop(1)
            return
        if verdict == "start-limit":
            until = self.limit_until(detail)
            say(f"item {slug}: a usage limit before the run took the item")
            self.wait("limit", f"waiting for the usage limit to reset until {clock(until)}", until)
            return
        self.start_errors += 1
        why = last_words(detail)
        if self.start_errors > len(self.backoff):
            say(f"claude ended with an error {self.start_errors} times before taking an item ({why}) - the loop stops; log {log}")
            raise Stop(1)
        until = time.time() + self.backoff[self.start_errors - 1]
        say(f"claude ended with an error before taking item {slug} ({why})")
        self.wait("backoff", f"trying again after {clock(until)}", until)

    def pending(self) -> None:
        """A run record exists (this or an earlier loop): wait for it, continue it, or finish it."""
        run = self.run
        phase = run.get("phase")
        if phase in ("lost", "failed"):
            say(f"an interrupted run of item {run['slug']} cannot be continued automatically ({run.get('why') or phase}).")
            say("loop-status.sh says what to do; then loop-start.sh --forget-run")
            raise Stop(1)
        if alive(run.get("child_pid"), run.get("child_ident")):
            pid, ident = run["child_pid"], run["child_ident"]
            detail = f"claude of the previous loop still works on item {run['slug']} (pid {pid}); waiting for it"
            self.announce("running", detail, safe=True)
            self.watch(lambda: alive(pid, ident), detail, safe=True)  # Ctrl+C here ends only the loop
            run.update({"child_pid": None, "child_ident": None})
            self.save_run()
            self.conclude()
            return
        wait_until = run.get("wait_until")
        if phase == "waiting" and wait_until and time.time() < wait_until:
            what = "limit" if run.get("why") == "a usage limit" else "backoff"
            text = (f"waiting for the usage limit to reset until {clock(wait_until)}, then continuing item {run['slug']}"
                    if what == "limit" else f"continuing item {run['slug']} after {clock(wait_until)} ({run.get('why')})")
            self.wait(what, text, wait_until)
            return  # the caller looks at pause / stop again
        # time to continue - but only if the run still holds its lock
        lock = self.repo.lock()
        mine = self.holds(lock)
        if self.our_row(self.repo.runs()) is not None and not mine:
            self.conclude()  # it finished meanwhile
            return
        if lock is None:
            if run.get("lock_started") is None and phase in ("running", "new"):
                say(f"the interrupted run of item {run['slug']} ended before it took the item; its record is dropped")
            else:
                say(f"the interrupted run of item {run['slug']} no longer holds the lock (released by hand?); its record is dropped")
            self.drop_run()
            return
        if not mine:
            hint = ("; if it is this loop's own run, see loop-status.sh" if lock.get("slug") == run["slug"] else "")
            self.wait("waiting", f"waiting: the run lock is held by another run ({lock_words(lock)}), "
                      f"not by the interrupted run of {run['slug']}{hint}", None, recheck=True)
            return
        if phase in ("running", "killed", "new"):
            # the loop or its claude ended without a verdict (Ctrl+C in Git Bash kills both at
            # once, a reboot, a closed window): say what a hard stop would have said (review M2, S4)
            run["why"] = run.get("why") or "the loop and claude ended while it ran (a hard stop, a closed window or a restart)"
            say(f"the run of item {run['slug']} was interrupted ({run['why']}); it is continued in the same session.")
            say("If a GUI probe was running then, its registry is restored first (stop-rules 2.8; %TEMP%\\tcNNN_backup.reg).")
        self.execute(resume=True)
        self.conclude()

    # -- before a new run -------------------------------------------------

    def tree_state(self) -> tuple:
        """("ok", the Backlog) when a run or a triage may start; else ("lock", why) or ("tree", why)."""
        lock = self.repo.lock()
        if lock is not None:
            return "lock", f"the run lock is held ({lock_words(lock)})"
        try:
            branch = self.repo.git("rev-parse", "--abbrev-ref", "HEAD")
            dirty = self.repo.git("status", "--porcelain")
        except backlog.Refused as e:
            return "tree", f"git failed ({e})"
        if branch != "main":
            return "tree", f"the working tree is on '{branch}', not on main"
        if dirty:
            return "tree", "the working tree is not clean (git status)"
        bl = backlog.Backlog(self.repo.root)
        findings = backlog.check(bl)
        if findings:
            return "tree", f"python tools/backlog/backlog.py check reports {len(findings)} finding(s)"
        if bl.ov is None or not backlog.overview_structurally_ok(bl.ov):
            return "tree", "backlog/BACKLOG.md is missing or malformed"
        return "ok", bl

    def precheck(self) -> tuple:
        kind, bl = self.tree_state()
        if kind != "ok":
            return "waiting", f"waiting: {bl}"
        slug, skipped = backlog.next_eligible(bl, bl.ov)
        if slug is None:
            return "idle", f"nothing eligible in Next ({len(skipped)} row(s) skipped); waiting for an open item"
        return "ready", slug

    # -- auto-triage between runs ----------------------------------------

    def orphan_triage(self) -> bool:
        """A triage record left by a loop that died: wait for its claude if it still works,
        then drop the record; True if there was one (the caller looks at the tree again)."""
        rec = load_json(self.repo.triage_file)
        if not rec:
            return False
        pid, ident = rec.get("pid"), rec.get("ident")
        if alive(pid, ident):
            detail = f"the auto-triage claude of the previous loop still works (pid {pid}); waiting for it"
            self.announce("triage", detail, safe=True)
            self.watch(lambda: alive(pid, ident), detail, safe=True, source=rec, what="it", state="triage")
            say("the auto-triage of the previous loop ended")
        unlink(self.repo.triage_file)
        return True

    def triage_due(self) -> bool:
        """Triage when the Inbox holds an item the last triage did not see; True if it ran."""
        kind, bl = self.tree_state()
        if kind != "ok":
            return False  # the precheck waits and says why
        inbox = inbox_slugs(bl)
        new = [s for s in inbox if s not in (self.triaged or set())]
        if not new:
            self.triage_errors = 0  # an error of a triage that still committed is not retried (review N2)
            return False
        self.triage(new, inbox)
        return True

    def triage(self, new: list, inbox: list) -> None:
        """One `/tandem-backlog auto-triage --commit` in a fresh claude; it commits on main itself."""
        self.repo.logs.mkdir(parents=True, exist_ok=True)
        name = dt.datetime.now().strftime("%Y%m%d-%H%M%S") + "-auto-triage"
        source = {"log": str(self.repo.logs / f"{name}.jsonl"), "err": str(self.repo.logs / f"{name}.err")}
        head = self.repo.git("rev-parse", "HEAD")
        detail = f"auto-triage of {len(new)} new Inbox item(s) (log {Path(source['log']).name})"
        self.announce("triage", detail, safe=False)  # before claude starts: the skill checks this state
        cmd = list(self.claude) + ["-p", TRIAGE_PROMPT, "--output-format", "stream-json", "--verbose",
                                   "--permission-mode", "bypassPermissions", "--session-id", str(uuid.uuid4())]
        if self.args.model:
            cmd += ["--model", self.args.model]
        env = os.environ.copy()
        env.pop("TANDEM_BACKLOG_NOW", None)
        env.setdefault("CLAUDE_CODE_RETRY_WATCHDOG", "1")
        env[TRIAGE_ENV] = str(os.getpid())
        flags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
        with open(source["log"], "ab") as out, open(source["err"], "ab") as err:
            source["offset"], source["err_offset"] = out.tell(), err.tell()
            try:
                self.child = subprocess.Popen(cmd, cwd=str(self.repo.root), stdin=subprocess.DEVNULL, stdout=out,
                                              stderr=err, env=env, creationflags=flags,
                                              start_new_session=(os.name != "nt"))
            except OSError as e:
                say(f"claude cannot be started ({e}) - the loop stops")
                raise Stop(1)
        # a loop that dies leaves this record: the next one waits for the claude (review S1)
        save_json(self.repo.triage_file, dict(source, pid=self.child.pid, ident=process_ident(self.child.pid)))
        self.watch(lambda: self.child.poll() is None, detail, source=source, what="the auto-triage", state="triage")
        self.child = None
        unlink(self.repo.triage_file)
        info = log_info(source)
        if info.rate_limit:
            self.usage = info.rate_limit
        kind, why = self.tree_state()
        if kind == "tree":
            # the loop never repairs the tree: a person looks at what the triage left (also after an error)
            say(f"after the auto-triage {why} - the loop stops; log {source['log']}")
            say("look at git status and git log; commit or discard (git restore backlog) what it left, "
                "then loop-start.sh again")
            raise Stop(1)
        if info.limited:
            self.triage_limits += 1
            if self.triage_limits > MAX_LIMITS:
                say(f"the auto-triage ended at a usage limit {self.triage_limits} times - the loop stops; "
                    f"log {source['log']}")
                raise Stop(1)
            until = self.limit_until(info)
            say("the auto-triage ended at a usage limit")
            self.wait("limit", f"waiting for the usage limit to reset until {clock(until)}, then the auto-triage again",
                      until)
            return
        if info.is_error:
            self.triage_errors += 1
            words = last_words(info)
            if self.triage_errors > len(self.backoff):
                say(f"the auto-triage ended with an error {self.triage_errors} times ({words}) - the loop stops; "
                    f"log {source['log']}")
                raise Stop(1)
            until = time.time() + self.backoff[self.triage_errors - 1]
            say(f"the auto-triage ended with an error ({words})")
            self.wait("backoff", f"auto-triage again after {clock(until)}", until)
            return
        self.triage_errors = self.triage_limits = 0
        committed = self.repo.git("rev-parse", "HEAD") != head
        if info.refused and not committed:
            # the skill's gating and the loop disagree: the items stay new and are tried again (review S2)
            self.triage_refusals += 1
            say(f"the auto-triage REFUSED ({last_words(info)}); log {source['log']}")
            if self.triage_refusals >= MAX_REFUSALS:
                say(f"the auto-triage refused {self.triage_refusals} times in a row - the loop stops; "
                    "look at the log and at SKILL.md section 2.5a 'From the loop'")
                raise Stop(1)
            return
        self.triage_refusals = 0
        self.triages += 1
        bl = backlog.Backlog(self.repo.root)
        # items it left in Inbox are not triaged again by this loop (only new ones are)
        self.triaged = set(inbox_slugs(bl))
        if not committed:
            say(f"auto-triage: no commit ({last_words(info)}); the backlog stays as it is")
            return
        placed = sum(1 for s in inbox if s not in self.triaged)
        nxt = backlog.next_eligible(bl, bl.ov)[0] if bl.ov is not None else None
        say(f"auto-triage: {placed} Inbox item(s) placed ({len(new)} new), {len(self.triaged)} left in Inbox; "
            f"next: {nxt or 'nothing eligible'}")

    # -- the loop ---------------------------------------------------------

    def main(self) -> int:
        try:
            self.register()
        except Stop as s:
            return s.code  # nothing of the other loop is touched
        try:
            if self.args.forget_run and self.repo.run_file.exists():
                say("the record of the interrupted run is dropped (--forget-run)")
                unlink(self.repo.run_file)
            self.prune_logs()
            say(f"loop started (pid {os.getpid()}); pause: tools/backlog/loop-pause.sh, stop: loop-stop.sh, "
                "status: loop-status.sh")
            return self.cycle()
        except Stop as s:
            return s.code
        except KeyboardInterrupt:
            return self.hard_stop()
        finally:
            self.unregister()
            say("loop ended: " + ", ".join(f"{k} {v}" for k, v in self.counts.items() if k != "nothing-to-do")
                + (f", auto-triage {self.triages}" if self.args.auto_triage else "") + f"; logs in {self.repo.logs}")

    def cycle(self) -> int:
        while True:
            if self.stop_requested():
                say("stop requested - the loop ends")
                return 0
            if self.paused():
                self.wait("paused", "paused - waiting for tools/backlog/loop-resume.sh", None)
                if not self.paused() and not self.stop_requested():
                    say("resumed")
                continue
            if self.orphan_triage():
                continue
            self.run = load_json(self.repo.run_file)
            if self.run:
                self.pending()
                continue
            if self.args.auto_triage and self.triage_due():
                continue  # look at pause / stop again before the next run
            if self.args.max_items and self.items >= self.args.max_items:
                say(f"{self.items} item(s) done (--max-items) - the loop ends")
                return 0
            state, what = self.precheck()
            if state == "idle" and self.args.until_idle:
                say(what.split(";")[0] + " - the loop ends (--until-idle)")
                return 0
            if state != "ready":
                self.wait(state, what, None, recheck=True)
                continue
            self.run = self.new_run(what)
            self.execute(resume=False)
            self.conclude()

    def hard_stop(self) -> int:
        child, run = self.child, self.run
        if child is not None and run is None:  # the auto-triage
            if child.poll() is None:
                kill_tree(child.pid)
                try:
                    child.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    pass
            unlink(self.repo.triage_file)
            say("HARD STOP: claude was killed during the auto-triage.")
            say("What it changed and did not commit stays in backlog/ (git status): commit it or discard it "
                "(git restore backlog); the next loop-start.sh waits for a clean tree.")
        elif child is not None:
            # also when the same Ctrl+C already ended claude: the item is cut either way (review S4)
            if child.poll() is None:
                kill_tree(child.pid)
                try:
                    child.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    pass
            run.update({"phase": "killed", "why": "a hard stop (Ctrl+C) killed the process",
                        "child_pid": None, "child_ident": None})
            self.save_run()
            say(f"HARD STOP: claude was killed while it worked on item {run['slug']}.")
            say("The item keeps the run lock; the next loop-start.sh continues it in the same session.")
            say("If a GUI probe was running: restore its registry backup first (%TEMP%\\tcNNN_backup.reg, stop-rules 2.8).")
        elif run and alive(run.get("child_pid"), run.get("child_ident")):
            say(f"stopped (Ctrl+C) - the claude of the previous loop keeps working on item {run['slug']}; "
                "the next loop-start.sh waits for it")
        elif run and self.repo.run_file.exists():
            # an interrupted run waits (limit, backoff) or its verdict was being taken (review 2 N10)
            say(f"stopped (Ctrl+C) - no claude was running; the interrupted run of item {run['slug']} keeps the "
                "run lock and the next loop-start.sh continues it")
        else:
            say("stopped (Ctrl+C) - no item of this loop was running")
        return 130

    def prune_logs(self) -> None:
        if not self.repo.logs.is_dir():
            return
        logs = sorted(self.repo.logs.glob("*.jsonl"))
        keep = {Path(p).stem for p in logs[-KEEP_LOGS:]}
        current = load_json(self.repo.run_file) or {}
        if current.get("log"):
            keep.add(Path(current["log"]).stem)
        for p in self.repo.logs.iterdir():
            if p.suffix in (".jsonl", ".err") and p.stem not in keep:
                unlink(p)


# ---------------------------------------------------------------------------
# Commands


def cmd_start(repo: Repo, args) -> int:
    if args.claude_cmd is None:
        exe = shutil.which("claude")
        if not exe:
            print("refused: 'claude' is not on PATH", flush=True)
            return 1
        args.claude_cmd = [exe]
    if os.name == "nt":
        signal.signal(signal.SIGBREAK, _interrupt)
    signal.signal(signal.SIGINT, _interrupt)
    if hasattr(signal, "SIGTERM"):
        signal.signal(signal.SIGTERM, _interrupt)
    return Loop(repo, args).main()


def describe(repo: Repo) -> dict:
    """What status prints, as data."""
    loop = load_json(repo.loop_file)
    live = bool(loop and alive(loop.get("pid"), loop.get("ident")))
    run = load_json(repo.run_file)
    return {"loop": loop, "live": live, "run": run, "triage": load_json(repo.triage_file),
            "paused": repo.pause_flag.exists(),
            "stop": repo.stop_flag.exists(), "lock": repo.lock(), "lock_text": repo.lock_text()}


def cmd_status(repo: Repo, args) -> int:
    d = describe(repo)
    loop, run = d["loop"], d["run"]
    if args.json:
        print(json.dumps(d, ensure_ascii=False, indent=1))
        return 0
    if d["live"]:
        print(f"loop:    running (pid {loop['pid']}, host {loop.get('host')}, since {loop.get('started')})")
        print(f"state:   {loop.get('state')} - {loop.get('detail')} (since {loop.get('since')})")
    elif loop:
        print(f"loop:    not running (the loop of pid {loop.get('pid')} ended without cleanup at about {loop.get('updated')})")
    else:
        print("loop:    not running")
    control = [t for t, on in (("pause requested", d["paused"]), ("stop requested", d["stop"] and d["live"])) if on]
    print(f"control: {', '.join(control) if control else '-'}")
    if loop:
        counts = loop.get("counts") or {}
        print("done:    " + ", ".join(f"{k} {counts.get(k, 0)}" for k in backlog.RUN_OUTCOMES if k != "nothing-to-do")
              + f" (blocked in a row: {loop.get('blocked_streak', 0)})" + ("" if d["live"] else " - the last loop"))
        if loop.get("auto_triage"):
            print(f"triage:  auto, when the Inbox has new items ({loop.get('triages', 0)} done)")
        print(f"usage:   {usage_line(loop.get('usage'))}")
    if run:
        line = f"run:     item {run['slug']}, session {run['session']}, phase {run.get('phase')}"
        if run.get("wait_until"):
            line += f", continues after {clock(run['wait_until'])}"
        if run.get("why"):
            line += f" ({run['why']})"
        print(line)
        print(f"log:     {run.get('log')}")
        if run.get("phase") in ("lost", "failed"):
            slug = run["slug"]
            print("todo:    the run cannot be continued automatically. Look at its log and its branch (the lock")
            print("         names it), finish the item by hand or stop it as a run would (SKILL.md step 10):")
            print(f"           python tools/backlog/backlog.py lock release --force ; git checkout main")
            print(f"           python tools/backlog/backlog.py block {slug} --reason '<why>'")
            print(f"           git add backlog ; git commit -m 'backlog: {slug} blocked'")
            print("         then tools/backlog/loop-start.sh --forget-run")
        elif not d["live"] and alive(run.get("child_pid"), run.get("child_ident")):
            print(f"         its claude (pid {run['child_pid']}) is still working; the next loop-start.sh waits for it")
        elif not d["live"]:
            print("         the next tools/backlog/loop-start.sh continues this run in the same session")
            if run.get("phase") in ("running", "killed", "new"):
                print("         (it was cut off: if a GUI probe was running, its registry backup is restored first -")
                print("         stop-rules 2.8, %TEMP%\\tcNNN_backup.reg; the continued run is told so)")
    triage = d["triage"]
    if triage and not d["live"] and alive(triage.get("pid"), triage.get("ident")):
        print(f"triage:  the auto-triage claude of the last loop (pid {triage['pid']}) is still working; "
              "the next loop-start.sh waits for it")
    print(f"lock:    {d['lock_text']}")
    if d["live"]:
        triaging = loop.get("state") == "triage"
        hard = loop.get("ctrl_c_safe") is False and (triaging or (bool(run) and alive(run.get("child_pid"),
                                                                                       run.get("child_ident"))))
        print("Ctrl+C:  " + (f"HARD STOP now ({'the auto-triage' if triaging else 'an item'} is running) - "
                             "use loop-pause.sh / loop-stop.sh" if hard else "safe now (no item is running)"))
    return 0


def cmd_pause(repo: Repo, args) -> int:
    repo.dir.mkdir(parents=True, exist_ok=True)
    already = repo.pause_flag.exists()
    repo.pause_flag.write_text(stamp() + "\n", encoding="utf-8")
    d = describe(repo)
    if not d["live"]:
        print("pause set: no loop is running; the next loop-start.sh starts paused (loop-resume.sh clears it)")
    elif d["loop"].get("state") in ("running", "triage"):
        what = f"item {d['loop'].get('slug')}" if d["loop"].get("state") == "running" else "the auto-triage"
        print(f"pause {'was already ' if already else ''}requested: the loop finishes {what}, "
              "then waits for loop-resume.sh (loop-status.sh shows when)")
    else:
        print("paused: the loop waits for loop-resume.sh")
    run = d["run"]
    if run and d["lock"] is not None and run.get("phase") not in ("lost", "failed"):
        # review 2 N8: the interrupted run keeps its branch and lock until it is continued
        print(f"note: the interrupted run of item {run['slug']} keeps the run lock and its branch until it is "
              "continued (loop-resume.sh); the backlog cannot be changed safely before it finishes")
    return 0


def cmd_resume(repo: Repo, args) -> int:
    had_pause, had_stop = repo.pause_flag.exists(), repo.stop_flag.exists()
    unlink(repo.pause_flag)
    unlink(repo.stop_flag)
    live = repo.live_loop()
    if not had_pause and not had_stop:
        print("nothing to resume: no pause or stop was requested" + ("" if live else " (and no loop is running)"))
    elif live:
        print("resumed: the loop continues" + (" (the pending stop is cancelled)" if had_stop else ""))
    else:
        print("pause cleared: no loop is running; start it with loop-start.sh")
    return 0


def cmd_stop(repo: Repo, args) -> int:
    live = repo.live_loop()
    if not live:
        unlink(repo.stop_flag)
        print("no loop is running" + (" (a pause is still set: loop-resume.sh clears it)" if repo.pause_flag.exists() else ""))
        return 0
    repo.stop_flag.write_text(stamp() + "\n", encoding="utf-8")
    if live.get("state") in ("running", "triage"):
        what = f"item {live.get('slug')}" if live.get("state") == "running" else "the auto-triage"
        print(f"stop requested: the loop finishes {what}, then ends (loop-resume.sh cancels it)")
    else:
        print("stop requested: the loop ends within a few seconds")
    return 0


def seconds_list(text: str) -> list:
    try:
        values = [float(x) for x in text.split(",") if x.strip()]
    except ValueError:
        raise argparse.ArgumentTypeError("a comma-separated list of seconds")
    if not values or any(v < 0 for v in values):
        raise argparse.ArgumentTypeError("a comma-separated list of seconds")
    return values


def build_parser() -> argparse.ArgumentParser:
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--root", help="repository root (default: the repository containing this script)")
    p = argparse.ArgumentParser(prog="loop.py", description="Loop over /tandem-backlog-implement (feature 247).")
    sub = p.add_subparsers(dest="command", required=True)
    s = sub.add_parser("start", parents=[common], help="run the loop in the foreground (Ctrl+C = hard stop)",
                       description="Run /tandem-backlog-implement item after item, one fresh claude process "
                                   "each (tools/backlog/loop-start.sh). Ctrl+C = hard stop; loop-pause.sh, "
                                   "loop-resume.sh, loop-stop.sh and loop-status.sh control it from another window.",
                       epilog="Full documentation: specs/247-backlog-run-loop/contracts/loop-cli.md")
    s.add_argument("--max-items", type=int, default=0, help="end after N finished items (default: no limit)")
    s.add_argument("--max-blocked", type=int, default=DEFAULT_MAX_BLOCKED,
                   help=f"stop after N blocked runs in a row (default {DEFAULT_MAX_BLOCKED})")
    s.add_argument("--poll", type=float, default=DEFAULT_POLL,
                   help=f"seconds between looks at the backlog while waiting (default {DEFAULT_POLL:.0f})")
    s.add_argument("--model", help="the model of the runs (default: claude's own default)")
    s.add_argument("--until-idle", action="store_true", help="end when nothing is eligible instead of waiting")
    s.add_argument("--forget-run", action="store_true", help="drop the record of an interrupted run before starting")
    s.add_argument("--auto-triage", action="store_true",
                   help="before each run, when the Inbox has items the last triage did not see, run "
                        "'/tandem-backlog auto-triage --commit' (at the start: when the Inbox is not empty)")
    # tests
    s.add_argument("--claude-cmd", type=json.loads, default=None, help=argparse.SUPPRESS)
    s.add_argument("--backoff", type=seconds_list, default=BACKOFF, help=argparse.SUPPRESS)
    s.add_argument("--limit-margin", type=float, default=LIMIT_MARGIN, help=argparse.SUPPRESS)
    s.add_argument("--limit-unknown-wait", type=float, default=LIMIT_UNKNOWN_WAIT, help=argparse.SUPPRESS)
    s.add_argument("--tick", type=float, default=TICK, help=argparse.SUPPRESS)
    s.add_argument("--deadline", type=float, default=0, help=argparse.SUPPRESS)  # a test that would hang fails instead
    s = sub.add_parser("status", parents=[common], help="what the loop does now")
    s.add_argument("--json", action="store_true")
    sub.add_parser("pause", parents=[common], help="finish the running item, then wait for resume")
    sub.add_parser("resume", parents=[common], help="continue after a pause; cancels a pending stop")
    sub.add_parser("stop", parents=[common], help="finish the running item, then end the loop")
    return p


COMMANDS = {"start": cmd_start, "status": cmd_status, "pause": cmd_pause, "resume": cmd_resume, "stop": cmd_stop}


def main(argv=None) -> int:
    try:
        sys.stdout.reconfigure(encoding="utf-8", newline="\n")
    except (AttributeError, ValueError):
        pass
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
    except SystemExit as e:
        return 2 if e.code else 0
    if args.command == "start" and (args.max_items < 0 or args.max_blocked < 1 or args.poll <= 0):
        print("usage: --max-items >= 0, --max-blocked >= 1, --poll > 0", flush=True)
        return 2
    root = Path(args.root).resolve() if args.root else HERE.parents[1]
    try:
        repo = Repo(root)
        return COMMANDS[args.command](repo, args)
    except backlog.Refused as e:
        print(f"refused: {e}", flush=True)
        return 1


if __name__ == "__main__":
    sys.exit(main())
