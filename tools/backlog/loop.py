#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Loop over /tandem-backlog-implement - one fresh claude process per item (feature 247).

The maintainer uses bin/backlog-loop.sh (Git Bash; --help lists everything):

  bin/backlog-loop.sh start    run the loop in this window (Ctrl+C = hard stop)
  bin/backlog-loop.sh pause    finish the running item, then wait for resume
  bin/backlog-loop.sh resume   continue after a pause (also cancels a pending stop)
  bin/backlog-loop.sh stop     finish the running item, then end the loop
  bin/backlog-loop.sh kill     a hard stop from another window (as Ctrl+C in the loop's)
  bin/backlog-loop.sh status   what the loop does now

The backlog itself is bin/backlog.sh (tools/backlog/backlog.py).

Feature 344 (contract specs/344-backlog-web-app/contracts/loop-cli-additions.md)
added what a program needs to drive the loop without hosting it: `kill`,
`start --new-window` and `start --item SLUG`, the loop's lines in
``loop.log``, why the last loop ended in ``last.json``, and the backlog
app's edit lock (``.git/tandem-backlog-edit.lock``), which holds new runs
and the auto-triage while the app changes the backlog.

Design (specs/247-backlog-run-loop/spec.md, contract contracts/loop-cli.md):

* The loop never changes the tree, the backlog or the lock: the runs do.
  It reads the outcome of a run from backlog/RUNS.md (a new row) and the
  run lock (released) - never from the model's text.
* Control and state files live in the git common dir, next to the run
  lock (``.git/tandem-backlog-loop/``): the working tree stays clean.
* Every run and auto-triage leaves a trace in ``.agent-traces/`` (ignored
  by git, never deleted by the loop; traces.py, feature 342): claude's
  output, a separator line before each attempt, meta.json and a line in
  index.jsonl when the run ends.  The first start after 342 copies the
  logs of the loop before it (``.git/tandem-backlog-loop/logs/``) once.
* claude runs in its unattended retry mode (CLAUDE_CODE_RETRY_WATCHDOG=1),
  which waits out a usage limit inside the process.  A run that ends
  while its item still holds the lock is continued in the same session
  (``--resume``) - after the reported reset of a limit, after a growing
  pause for an error, or at once after Ctrl+C.
* ``claude -p`` stops the background tasks still running some time after
  the last turn ended (10 minutes by default): a reviewer whose probe runs
  longer was killed three times in 341 and the run failed.  The loop lets
  them run BG_WAIT_CEILING_MS (CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS).
* A run that only waits - its main thread schedules wakeups that report
  nothing changed while no background task runs (a reviewer ended without
  a report, seen in 320) - is stopped and continued in the same session
  with a prompt that says so; at most MAX_NUDGES times per run.
* With --auto-triage, between two runs, whenever the Inbox holds an item
  the last triage did not see (at the start: any item), the loop starts
  ``claude -p '/tandem-backlog auto-triage --commit'`` and waits for it,
  so that a finding of the last run is placed before the next item is
  chosen.  The triage commits on main itself; the loop checks afterwards
  that the tree is clean, on main and consistent.

Standard library only.  Exit codes: 0 the loop ended as asked (stop,
--max-items, --until-idle, --item), 1 it stopped for a person or was refused,
2 usage, 130 Ctrl+C or kill.
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
import traces  # noqa: E402

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
IDLE_WAKEUPS = 2             # no-op wakeups in a row, no background task: the run waits for nothing
MAX_NUDGES = 3               # continuations of one run after such idling
BG_WAIT_CEILING_MS = "7200000"  # background tasks outlive the last turn this long (reviewers: about 45 min)
TICK = 1.0                   # how often waits look at pause / stop / kill
STILL_ACTIVE = 259
LOG_MAX = 5 * 1024 * 1024    # loop.log is rotated to loop.log.1 beyond this (344)
EDIT_LOCK_NAME = "tandem-backlog-edit.lock"  # the backlog app's lock, next to the run lock (344)
EDIT_LOCK_SLACK = 2.0        # its owner was created at most this long after the lock's started_epoch
EDIT_LOCK_YOUNG = 5.0        # a lock without readable fields this young is being written: live
NEW_WINDOW_WAIT = 15.0       # start --new-window waits this long for the new loop's loop.json
WINDOW_TITLE = "Backlog loop"
FILETIME_EPOCH = 116444736000000000  # 1970-01-01 in FILETIME units (100 ns since 1601)

RESUME_PROMPT = (
    "The run of /tandem-backlog-implement in this session was interrupted ({why}). "
    "Continue it exactly where it stopped, for the same item, following the skill to its end "
    "(SKILL.md 'Continued run'): first find where you were (git branch, git status, "
    "the lock status, the fix-log, the last steps above); if a GUI probe was interrupted, "
    "restore its registry backup first (stop-rules section 2.8). Do not repeat steps "
    "that are complete. One item only; end with the final message of section 11."
)
IDLE_WHY = (
    "the loop stopped it: its wakeups reported nothing changed twice in a row while no background "
    "task was running, so what it waited for - a reviewer or a command - has ended without a "
    "report; launch it again now instead of waiting (SKILL.md step 7, 'Never idle on a reviewer "
    "that is not running')"
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


LOG = {"path": None}  # loop.log of the loop running in this process (set by cmd_start)


def say(text: str) -> None:
    print(f"[{dt.datetime.now().strftime('%H:%M')}] {text}", flush=True)
    log_line(text)


def tell(text: str) -> None:
    """A line without the time (a refusal): printed as before 344, and logged."""
    print(text, flush=True)
    log_line(text)


def log_line(text: str) -> None:
    """Append a line to loop.log with the local time: one write per line, the file closed at
    once (a held handle would block another process's rename).  A log that cannot be written
    never stops the loop."""
    path = LOG["path"]
    if path is None:
        return
    now = dt.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    data = "".join(f"{now} {line}\n" for line in (str(text).splitlines() or [""])).encode("utf-8")
    for _ in range(20):
        try:
            try:
                if path.stat().st_size + len(data) > LOG_MAX:
                    os.replace(path, path.with_name(path.name + ".1"))
            except FileNotFoundError:
                pass
            except PermissionError:
                pass  # a reader holds it without delete sharing: rotated at a later line
            with open(path, "ab", buffering=0) as f:
                f.write(data)
            return
        except FileNotFoundError:
            try:
                path.parent.mkdir(parents=True, exist_ok=True)
            except OSError:
                return
        except PermissionError:
            time.sleep(0.05)
        except OSError:
            return


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


def process_created(pid: int | None) -> float | None:
    """When a live process was created (seconds since 1970), None if it does not run; 0.0 when
    it runs but its creation time is unknown (it then counts as older than anything)."""
    ident = process_ident(pid)
    if ident is None:
        return None
    if os.name == "nt":
        return (ident - FILETIME_EPOCH) / 1e7
    try:
        boot = next(float(l.split()[1]) for l in Path("/proc/stat").read_text().splitlines() if l.startswith("btime "))
        return boot + ident / os.sysconf("SC_CLK_TCK")
    except (OSError, ValueError, StopIteration):
        return 0.0


def kill_tree(pid: int) -> None:
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(pid), "/T", "/F"], capture_output=True)
    else:
        try:
            os.killpg(os.getpgid(pid), signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass


def child_env() -> dict:
    """The environment of a claude the loop starts; a caller's own setting of a claude variable is kept."""
    env = os.environ.copy()
    env.pop("TANDEM_BACKLOG_NOW", None)  # a test clock would date the run's lock wrongly (review 2 N1)
    env.setdefault("CLAUDE_CODE_RETRY_WATCHDOG", "1")
    env.setdefault("CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS", BG_WAIT_CEILING_MS)  # a long reviewer is not killed (341)
    return env


def _interrupt(signum, frame):
    raise KeyboardInterrupt


class Killed(KeyboardInterrupt):
    """`bin/backlog-loop.sh kill` was seen: the hard stop of Ctrl+Break (344)."""


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
        self.old_logs = self.dir / "logs"          # before 342; imported once, never written
        self.imported_file = self.dir / "imported.json"
        self.traces = root / traces.TRACES_DIR
        self.kill_flag = self.dir / "kill"         # 344
        self.log_file = self.dir / "loop.log"
        self.last_file = self.dir / "last.json"
        self.edit_lock_path = self.lock_path.parent / EDIT_LOCK_NAME

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

    def edit_lock(self) -> dict | None:
        """The backlog app's edit lock: {pid, started, purpose, live}, None when there is none.
        Only read, never deleted (the app replaces a dead one).  Live = a process with its pid
        runs and was created no later than started_epoch + EDIT_LOCK_SLACK (a reused pid is not
        the owner)."""
        text = None
        for _ in range(40):
            try:
                text = backlog.read_text(self.edit_lock_path)
                break
            except FileNotFoundError:
                return None
            except (PermissionError, UnicodeDecodeError):
                time.sleep(0.05)  # being written or replaced
        fields = {}
        for line in (text or "").split("\n"):
            if ": " in line:
                k, v = line.split(": ", 1)
                fields[k.strip()] = v.strip()
        try:
            pid = int(fields["pid"])
            epoch = float(fields["started_epoch"])
        except (KeyError, ValueError):
            pid = epoch = None
        if pid is None:
            # created with an exclusive create and filled after: young = being written
            try:
                live = text is None or time.time() - self.edit_lock_path.stat().st_mtime < EDIT_LOCK_YOUNG
            except OSError:
                return None
        else:
            created = process_created(pid)
            live = created is not None and created <= epoch + EDIT_LOCK_SLACK
        return {"pid": pid, "started": fields.get("started"), "purpose": fields.get("purpose"), "live": live}


# ---------------------------------------------------------------------------
# What a claude log says (stream-json, one object per line)


class LogInfo:
    def __init__(self):
        self.result = None       # the last {"type": "result"} object
        self.rate_limit = None   # the last rate_limit_info
        self.lost = False        # --resume found no session
        self.stderr_tail = ""
        self.bg_tasks = []       # the last background_tasks_changed list
        self.idle_wakeups = 0    # wakeup ticks that only scheduled a no-op wakeup, since the last sign of work
        self.in_tick = False     # the current turn was started by a scheduled wakeup
        self.tick_counted = False

    @property
    def idle(self) -> bool:
        """The run waits for nothing: no-op wakeups in a row and no background task."""
        return self.idle_wakeups >= IDLE_WAKEUPS and not self.bg_tasks

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
        if obj.get("parent_tool_use_id"):
            info.idle_wakeups = 0  # a subagent is working
            continue
        if kind == "result":
            info.result = obj
        elif kind == "rate_limit_event" and isinstance(obj.get("rate_limit_info"), dict):
            info.rate_limit = obj["rate_limit_info"]
        elif kind == "system" and obj.get("subtype") == "background_tasks_changed":
            info.bg_tasks = list(obj.get("tasks") or [])
            info.idle_wakeups = 0  # count only the wakeups after the last change (a reviewer that just
            #                        finished leaves the list empty while the run goes on working)
        elif kind == "system" and obj.get("subtype") in ("task_progress", "task_notification"):
            info.idle_wakeups = 0
        elif kind == "command_lifecycle" and obj.get("state") == "started":
            # a turn begins: only a turn started by a scheduled wakeup can be an idle tick;
            # any other start (a message, a prompt) is activity
            info.in_tick = obj.get("wakeup_source") == "loop_wakeup"
            info.tick_counted = False
            if not info.in_tick:
                info.idle_wakeups = 0
        elif kind == "assistant":
            for part in (obj.get("message") or {}).get("content") or []:
                if isinstance(part, dict) and part.get("type") == "tool_use" and part.get("name") == "ScheduleWakeup":
                    if (part.get("input") or {}).get("noop") is not True:
                        info.idle_wakeups = 0
                    elif info.in_tick and not info.tick_counted:
                        # a fallback heartbeat in a working turn, or a second one in the same tick,
                        # does not count (review of the watchdog, SHOULD 1)
                        info.idle_wakeups += 1
                        info.tick_counted = True


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


def where(rec: dict | None) -> str:
    """Where a run's output is, for the window: its trace folder."""
    if not rec:
        return "-"
    if rec.get("trace"):
        return f"trace {traces.TRACES_DIR}/{Path(rec['trace']).name}"
    return f"log {rec.get('log')}"  # a record of the loop before 342, not moved yet


def claude_version(exe: str) -> str | None:
    """The first word of `claude --version` (2.1.310), None when it does not answer."""
    try:
        res = subprocess.run([exe, "--version"], capture_output=True, text=True, encoding="utf-8",
                             errors="replace", timeout=30, stdin=subprocess.DEVNULL)
    except (OSError, subprocess.TimeoutExpired):
        return None
    words = res.stdout.split()
    return words[0] if res.returncode == 0 and words else None


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
    """End the loop with this exit code (the message was said); reason = last.json's (344),
    by default `stopped-for-person` for 1 and `stop` otherwise."""

    def __init__(self, code: int, reason: str | None = None):
        super().__init__(code)
        self.code = code
        self.reason = reason or ("stopped-for-person" if code == 1 else "stop")


def start_options(args) -> dict:
    """The options of a start, for last.json."""
    return {"max_items": args.max_items, "max_blocked": args.max_blocked, "poll": args.poll, "model": args.model,
            "until_idle": bool(args.until_idle), "forget_run": bool(args.forget_run),
            "auto_triage": bool(args.auto_triage), "item": getattr(args, "item", None)}


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
        self.triage_source = None  # the running auto-triage's record (its trace)
        self.harness_version = getattr(args, "harness_version", None)
        self.item = getattr(args, "item", None)  # start --item (344)
        self.finished = 0        # runs with a verdict "finished" (any outcome)
        self.end_reason = None   # last.json's reason of a normal end

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
                    tell(f"refused: another loop is running (pid {other.get('pid')}, since {other.get('started', '?')}); "
                         "bin/backlog-loop.sh status shows it, bin/backlog-loop.sh stop ends it")
                    raise Stop(1)
                say(f"a loop record of pid {other.get('pid', '?')} remained (that loop ended without cleanup); taking over")
                unlink(self.repo.loop_file)
                continue
            os.close(fd)
            self.me = me
            # a stop is meant for a running loop; one left by a loop that was killed
            # (or that ended while the stop was being set) must not end this one (review N1)
            unlink(self.repo.stop_flag)
            unlink(self.repo.kill_flag)  # the same for a kill (344)
            self.write_state("starting", "-")
            return
        tell("refused: the loop record cannot be created")
        raise Stop(1)

    def unregister(self) -> None:
        data = load_json(self.repo.loop_file) or {}
        if data.get("pid") == os.getpid():
            unlink(self.repo.loop_file)
        unlink(self.repo.stop_flag)
        unlink(self.repo.kill_flag)

    def write_last(self, code: int, reason: str) -> None:
        """last.json: how this loop (or this refused start) ended; never over a live loop of
        another process (344)."""
        other = self.repo.live_loop()
        if other and other.get("pid") != os.getpid():
            return
        data = {"pid": os.getpid(), "started": stamp(self.started), "ended": stamp(), "exit_code": code,
                "reason": reason, "counts": self.counts, "items": self.items, "options": start_options(self.args)}
        try:
            self.repo.dir.mkdir(parents=True, exist_ok=True)
            save_json(self.repo.last_file, data)
        except OSError as e:
            say(f"last.json cannot be written ({e})")

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
            "trace": (self.run or self.triage_source or {}).get("trace"), "counts": self.counts, "items": self.items,
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

    def check_kill(self) -> None:
        """`bin/backlog-loop.sh kill`: the hard stop, at the next tick of any wait (344)."""
        if self.repo.kill_flag.exists():
            raise Killed()

    def wait(self, state: str, detail: str, until: float | None, recheck: bool = False) -> None:
        """Wait until `until` (None = for ever); returns early on stop / pause, or after
        one poll interval when recheck is set (the caller looks again)."""
        self.announce(state, detail, until)
        end = until if until is not None else (time.time() + self.poll if recheck else None)
        while True:
            self.check_kill()
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
        now = time.time()
        folder = traces.new_run_dir(self.repo.root, slug, now)
        run = {
            "slug": slug, "session": str(uuid.uuid4()), "started": stamp(now), "started_epoch": now, "kind": "item",
            "trace": str(folder), "log": str(folder / traces.TRACE), "err": str(folder / traces.STDERR),
            "rows_before": len(self.repo.runs()), "attempts": 0, "stalls": 0, "resumes": 0, "limits": 0, "nudges": 0,
            "lock_started": None, "phase": "new", "wait_until": None, "why": None, "child_pid": None, "child_ident": None,
            "trace_attempts": [], "next_reason": "-", "indexed": False, "base": self.head(),
        }
        self.run = run
        self.save_run()
        return run

    def save_run(self) -> None:
        save_json(self.repo.run_file, self.run)
        if self.run.get("phase") in ("failed", "lost"):
            self.finish_trace(self.run, self.run["phase"])  # a stop for a person: the run is not continued
        else:
            self.write_meta(self.run)

    def drop_run(self) -> None:
        if self.run:
            self.finish_trace(self.run, "done")
        unlink(self.repo.run_file)
        self.run = None

    # -- the trace of a run (traces.py, contract 342) -----------------------

    def head(self) -> str | None:
        """HEAD now: the commits of a run are the ones made after it (traces)."""
        try:
            return self.repo.git("rev-parse", "HEAD")
        except backlog.Refused:
            return None

    def loop_info(self) -> dict:
        return {"pid": os.getpid(), "host": socket.gethostname(), "auto_triage": bool(self.args.auto_triage)}

    def journal_row(self, rec: dict) -> list | None:
        """The run's row of RUNS.md (written since it started), None for a triage or without one."""
        if rec.get("kind") == traces.TRIAGE or "rows_before" not in rec:
            return None
        for r in self.repo.runs()[rec["rows_before"]:]:
            if len(r) > 2 and r[1] == rec["slug"]:
                return r
        return None

    def open_attempt(self, rec: dict, out, err, resume: bool) -> None:
        """Before claude starts: the separator and the header, then the offsets of this attempt."""
        atts = rec.setdefault("trace_attempts", [])
        n = len(atts) + 1
        kind = "continue" if resume else "start"
        reason = (rec.get("next_reason") or "-") if resume else "-"
        started = traces.iso_local(time.time())
        for f in (out, err):
            if not traces.ends_line(f):
                f.write(b"\n")  # a killed claude left a partial line: the separator starts a line of its own
        out.write(traces.separator_line(n, kind, reason, started, rec.get("session")))
        err.write(traces.stderr_header(n, kind, reason, started))
        out.flush()
        err.flush()
        rec["offset"], rec["err_offset"] = out.tell(), err.tell()
        atts.append(traces.attempt_record(n, kind, reason, started))

    def close_attempt(self, rec: dict, verdict: str | None = None, exit_code: int | None = None) -> None:
        """The attempt's end in meta.json (once), and the reason of the next one."""
        atts = rec.get("trace_attempts") or []
        if not atts or atts[-1].get("ended") is not None:
            return
        info = log_info(rec)
        a = atts[-1]
        a["ended"] = traces.iso_local(time.time())
        if info.result is None:
            a["ending"] = "interrupted"
        else:
            a["ending"] = "error" if info.is_error else "success"
        a["error_kind"] = ("usage-limit" if info.limited else "session-lost" if info.lost
                           else "other" if a["ending"] == "error" else None)
        a["resets_at"] = traces.iso_local(info.reset_at) if info.limited else None
        if exit_code is not None:
            a["exit_code"] = exit_code
        a["idle_killed"] = bool(rec.get("idle"))
        a["usage"] = (info.result or {}).get("usage") or {}
        rec["next_reason"] = {"limit": "usage-limit", "error": "error", "stalled": "stall"}.get(verdict, "-")
        if rec.get("idle") and verdict in ("stalled", "error"):
            rec["next_reason"] = "idle"

    def write_meta(self, rec: dict, phase: str | None = None, final: bool = False, outcome: str | None = None) -> dict | None:
        if not rec or not rec.get("trace"):
            return None
        row = self.journal_row(rec)
        kind = rec.get("kind", "item")
        if rec.get("started_epoch") is None:
            try:
                rec["started_epoch"] = dt.datetime.strptime(rec["started"], "%Y-%m-%d %H:%M:%S").timestamp()
            except (KeyError, TypeError, ValueError):
                pass
        ended = time.time() if final else None
        feature = traces.cell(row, 3)
        commits = []
        if final and rec.get("started_epoch") is not None:
            commits = traces.run_commits(self.repo.root, rec["started_epoch"], ended, slug=rec["slug"],
                                         feature=feature, kind=kind, base=rec.get("base"))
        model = self.args.model or traces.first_init(Path(rec["log"]))[1]
        meta = traces.build_meta(rec, phase=phase or rec.get("phase"), ended=traces.iso_local(ended),
                                 outcome=outcome if outcome is not None else traces.cell(row, 2),
                                 feature=feature, branch=traces.cell(row, 4), commits=commits, why=rec.get("why"),
                                 loop_info=self.loop_info(), harness_version=self.harness_version, model=model)
        try:
            traces.write_json_atomic(Path(rec["trace"]) / traces.META, meta)
        except OSError as e:  # the folder was deleted by hand: the run goes on, its record is lost
            say(f"meta.json of {where(rec)} cannot be written ({e})")
        return meta

    def finish_trace(self, rec: dict, phase: str, outcome: str | None = None) -> None:
        """The run ended (finished, dropped, or stopped for a person): final meta.json and its
        one index line."""
        if not rec or not rec.get("trace") or rec.get("indexed"):
            return
        self.close_attempt(rec)
        meta = self.write_meta(rec, phase=phase, final=True, outcome=outcome)
        if meta is None:
            return
        try:
            traces.append_line(self.repo.traces / traces.INDEX, traces.build_index_line(meta, Path(rec["trace"]).name))
        except OSError as e:
            say(f"index.jsonl cannot be written ({e})")
        rec["indexed"] = True
        if rec is self.run and self.repo.run_file.exists():
            save_json(self.repo.run_file, rec)

    def migrate_old_run(self) -> None:
        """A run recorded by the loop before 342 (its log in .git/tandem-backlog-loop/logs/)
        moves into a run folder of .agent-traces/ before it is continued; offsets stay valid."""
        run = self.run
        if run.get("trace") or not run.get("log"):
            return
        old_log, old_err = Path(run["log"]), Path(run["err"])
        name = traces.new_name_for_old(old_log.stem)
        folder = self.repo.traces / name if name else None
        if folder is None or folder.exists():
            folder = traces.new_run_dir(self.repo.root, run["slug"], time.time())
        else:
            folder.mkdir(parents=True)
        for src, dst in ((old_log, traces.TRACE), (old_err, traces.STDERR)):
            if src.exists():
                shutil.copyfile(src, folder / dst)
            else:
                (folder / dst).write_bytes(b"")
        n = int(run.get("resumes") or 0) + 1
        # the earlier attempts are known only by number; the last one stays open for the verdict
        # only when none was taken yet (cut off: running / killed / new; review S4)
        open_last = run.get("phase") in ("running", "killed", "new")
        now = traces.iso_local(time.time())
        run.update({"trace": str(folder), "log": str(folder / traces.TRACE), "err": str(folder / traces.STDERR),
                    "kind": "item", "indexed": False, "next_reason": run.get("next_reason") or "-",
                    "trace_attempts": [dict(traces.attempt_record(k + 1, "start" if k == 0 else "continue", "-", None),
                                            ended=None if (k == n - 1 and open_last) else now)
                                       for k in range(n)]})
        self.save_run()
        traces.remove_old(old_log, old_err)  # moved (the maintainer's request, 342)
        try:
            self.repo.old_logs.rmdir()  # the last old log was this run's
        except OSError:
            pass
        say(f"the interrupted run of item {run['slug']} moved to {where(run)}")

    def move_old_log(self, log: str | None) -> str | None:
        """Move one log of the loop before 342 (a record that will not be continued: a
        forgotten run, an orphan triage that ended) into .agent-traces/; its folder."""
        if not log or not self.repo.old_logs.is_dir():
            return None
        stem = Path(log).stem
        others = {p.stem for p in self.repo.old_logs.iterdir()} - {stem}
        traces.import_old_logs(self.repo.root, self.repo.old_logs, self.repo.runs(), others,
                               {"pid": None, "host": None, "auto_triage": None}, move=True)
        name = traces.new_name_for_old(stem)
        folder = self.repo.traces / name if name else None
        return str(folder) if folder is not None and folder.is_dir() else None

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
        # judged per attempt: a reason or an idle mark of an earlier attempt is not replayed later
        run["why"] = None
        run.pop("idle", None)
        cmd = list(self.claude) + ["-p", prompt, "--output-format", "stream-json", "--verbose",
                                   "--permission-mode", "bypassPermissions", *session]
        if self.args.model:
            cmd += ["--model", self.args.model]
        env = child_env()
        flags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
        Path(run["trace"]).mkdir(parents=True, exist_ok=True)  # deleted by hand meanwhile: recreated
        with open(run["log"], "ab") as out, open(run["err"], "ab") as err:
            # claude writes straight into these files: the separator goes in before it starts
            self.open_attempt(run, out, err, resume)
            try:
                self.child = subprocess.Popen(cmd, cwd=str(self.repo.root), stdin=subprocess.DEVNULL, stdout=out,
                                              stderr=err, env=env, creationflags=flags,
                                              start_new_session=(os.name != "nt"))
            except OSError as e:
                if not resume:
                    self.drop_run()
                else:
                    self.close_attempt(run)  # its separator is written: the next one gets the next number
                    run["next_reason"] = "error"
                    self.save_run()
                say(f"claude cannot be started ({e}) - the loop stops")
                raise Stop(1)
        run.update({"phase": "running", "wait_until": None, "child_pid": self.child.pid,
                    "child_ident": process_ident(self.child.pid)})
        self.save_run()
        verb = "continuing" if resume else "running"
        detail = f"{verb} item {run['slug']} (session {run['session'][:8]}, {where(run)})"
        self.announce("running", detail, safe=False)
        self.watch(lambda: self.child.poll() is None, detail)
        run["exit_code"] = self.child.returncode
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
        killed_at = 0.0
        while running():
            self.check_kill()
            if self.args.deadline and time.time() - self.started > self.args.deadline:
                if self.child is not None:
                    kill_tree(self.child.pid)
                self.stop_requested()  # raises Stop
            lines, offset = read_lines(Path(source["log"]), offset)
            if lines:
                scan(lines, info)
                if info.rate_limit:
                    self.usage = info.rate_limit
            # this run's claude - also a previous loop's (pending()), never the auto-triage's
            pid = self.child.pid if self.child is not None else (source or {}).get("child_pid")
            if info.idle and pid and source is self.run and time.time() - killed_at > 30:
                if "idle" not in told:
                    told.add("idle")
                    self.run["idle"] = True
                    self.save_run()
                    say(f"item {self.run['slug']}: the run waits for nothing (no-op wakeups, no background task) - "
                        "stopping it to continue it with a reminder")
                kill_tree(pid)
                killed_at = time.time()  # tried again after 30 s if it is still alive
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
        self.close_attempt(run, verdict, run.pop("exit_code", None))
        if run.pop("idle", False) and verdict in ("stalled", "error"):  # stopped by watch() while holding its item
            run["nudges"] = run.get("nudges", 0) + 1
            if run["nudges"] > MAX_NUDGES:
                run.update({"phase": "failed", "why": "waited for nothing too often"})
                self.save_run()
                say(f"item {slug}: the run waited for nothing {run['nudges']} times - the loop stops; {where(run)}")
                raise Stop(1)
            run.update({"phase": "waiting", "wait_until": time.time(), "why": IDLE_WHY})
            self.save_run()
            say(f"item {slug}: continuing the run with a reminder to relaunch what it waits for")
            return
        if verdict == "finished":
            self.drop_run()
            self.refusals = self.start_errors = 0
            outcome = detail
            if outcome in self.counts:
                self.counts[outcome] += 1
            if outcome != "nothing-to-do":
                self.items += 1
            self.finished += 1
            say(f"item {slug}: {outcome}")
            self.blocked_streak = self.blocked_streak + 1 if outcome == "blocked" else 0
            if self.blocked_streak >= self.args.max_blocked:
                say(f"{self.blocked_streak} runs in a row ended blocked - the loop stops; look at backlog/RUNS.md and the items' block reasons")
                raise Stop(1, "max-blocked")
            return
        if verdict == "lost":
            run["phase"] = "lost"
            run["why"] = detail
            self.save_run()
            say(f"item {slug}: the session cannot be continued ({detail}). The loop stops.")
            say(f"the item still holds the run lock; see bin/backlog-loop.sh status for what to do")
            raise Stop(1)
        if verdict == "refused-own":
            run.update({"phase": "failed", "why": f"a continuation refused its own run ({last_words(detail)})"})
            self.save_run()
            say(f"item {slug}: the continued run refused although it holds the item's lock ({last_words(detail)}) - "
                f"the loop stops; {where(run)}")
            raise Stop(1)
        if verdict == "limit":
            run["limits"] = run.get("limits", 0) + 1
            if run["limits"] > MAX_LIMITS:
                run.update({"phase": "failed", "why": "interrupted by usage limits too often"})
                self.save_run()
                say(f"item {slug}: interrupted by a usage limit {run['limits']} times - the loop stops; {where(run)}")
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
                    f"{where(run)}")
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
                    f"{where(run)}")
                raise Stop(1)
            run.update({"phase": "waiting", "wait_until": time.time(), "why": "the turn ended before the run finished"})
            self.save_run()
            say(f"item {slug}: the run ended its turn before finishing; continuing it")
            return
        # the run never took its item
        log = where(run)
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
            say(f"claude ended with an error {self.start_errors} times before taking an item ({why}) - the loop stops; {log}")
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
            say("bin/backlog-loop.sh status says what to do; then bin/backlog-loop.sh start --forget-run")
            raise Stop(1)
        if alive(run.get("child_pid"), run.get("child_ident")):
            pid, ident = run["child_pid"], run["child_ident"]
            detail = f"claude of the previous loop still works on item {run['slug']} (pid {pid}); waiting for it"
            self.announce("running", detail, safe=True)
            self.watch(lambda: alive(pid, ident), detail, safe=True)  # Ctrl+C here ends only the loop
            run.update({"child_pid": None, "child_ident": None})
            self.migrate_old_run()  # only now: that claude no longer writes to an old log
            self.save_run()
            self.conclude()
            return
        self.migrate_old_run()
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
            hint = ("; if it is this loop's own run, see bin/backlog-loop.sh status" if lock.get("slug") == run["slug"] else "")
            self.wait("waiting", f"waiting: the run lock is held by another run ({lock_words(lock)}), "
                      f"not by the interrupted run of {run['slug']}{hint}", None, recheck=True)
            return
        if phase in ("running", "killed", "new"):
            # the loop or its claude ended without a verdict (Ctrl+C in Git Bash kills both at
            # once, a reboot, a closed window): say what a hard stop would have said (review M2, S4)
            run["why"] = run.get("why") or "the loop and claude ended while it ran (a hard stop, a closed window or a restart)"
            self.close_attempt(run)
            run["next_reason"] = "killed"
            say(f"the run of item {run['slug']} was interrupted ({run['why']}); it is continued in the same session.")
            say("If a GUI probe was running then, its registry is restored first (stop-rules 2.8; %TEMP%\\tcNNN_backup.reg).")
        self.execute(resume=True)
        self.conclude()

    # -- before a new run -------------------------------------------------

    def tree_state(self) -> tuple:
        """("ok", the Backlog) when a run or a triage may start; else ("edit", why), ("lock", why)
        or ("tree", why)."""
        edit = self.repo.edit_lock()
        if edit is not None and edit["live"]:  # first: the app is changing the backlog (344)
            since = (edit.get("started") or "")[11:19] or "?"
            return "edit", f"the backlog app is changing the backlog (since {since})"
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
            return "tree", f"bin/backlog.sh check reports {len(findings)} finding(s)"
        if bl.ov is None or not backlog.overview_structurally_ok(bl.ov):
            return "tree", "backlog/BACKLOG.md is missing or malformed"
        return "ok", bl

    def item_reason(self, bl, slug: str) -> str | None:
        """Why `slug` may not run now, None when it may (the rule of `backlog next --slug`)."""
        try:
            return backlog.eligibility(bl, bl.item(slug))
        except backlog.Refused as e:
            return str(e)

    def precheck(self) -> tuple:
        kind, bl = self.tree_state()
        if kind != "ok":
            return "waiting", f"waiting: {bl}"
        if self.item:
            reason = self.item_reason(bl, self.item)
            if reason:
                return "gone", f"item {self.item} is no longer eligible ({reason})"
            return "ready", self.item
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
        if not rec.get("trace"):
            self.move_old_log(rec.get("log"))  # a triage of the loop before 342: its log moves now it ended
        self.finish_triage(rec)
        unlink(self.repo.triage_file)
        return True

    def finish_triage(self, rec: dict, phase: str | None = None) -> None:
        """An auto-triage ended (it is never continued): its final meta.json and index line."""
        if not rec.get("trace"):
            return
        info = log_info(rec)
        if phase is None:
            phase = "done" if not info.is_error else "failed"
        outcome = "triaged" if phase == "done" and not info.refused else None
        self.close_attempt(rec, exit_code=rec.pop("exit_code", None))
        self.finish_trace(rec, phase, outcome=outcome)

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
        now = time.time()
        folder = traces.new_run_dir(self.repo.root, traces.TRIAGE, now)
        session = str(uuid.uuid4())
        head = self.repo.git("rev-parse", "HEAD")
        source = {"kind": traces.TRIAGE, "slug": traces.TRIAGE, "session": session, "started_epoch": now,
                  "trace": str(folder), "log": str(folder / traces.TRACE), "err": str(folder / traces.STDERR),
                  "trace_attempts": [], "indexed": False, "base": head}
        self.triage_source = source
        detail = f"auto-triage of {len(new)} new Inbox item(s) ({where(source)})"
        self.announce("triage", detail, safe=False)  # before claude starts: the skill checks this state
        cmd = list(self.claude) + ["-p", TRIAGE_PROMPT, "--output-format", "stream-json", "--verbose",
                                   "--permission-mode", "bypassPermissions", "--session-id", session]
        if self.args.model:
            cmd += ["--model", self.args.model]
        env = child_env()
        env[TRIAGE_ENV] = str(os.getpid())
        flags = subprocess.CREATE_NEW_PROCESS_GROUP if os.name == "nt" else 0
        with open(source["log"], "ab") as out, open(source["err"], "ab") as err:
            self.open_attempt(source, out, err, resume=False)
            try:
                self.child = subprocess.Popen(cmd, cwd=str(self.repo.root), stdin=subprocess.DEVNULL, stdout=out,
                                              stderr=err, env=env, creationflags=flags,
                                              start_new_session=(os.name != "nt"))
            except OSError as e:
                self.finish_triage(source, "failed")
                self.triage_source = None
                say(f"claude cannot be started ({e}) - the loop stops")
                raise Stop(1)
        self.write_meta(source, phase="running")
        # a loop that dies leaves this record: the next one waits for the claude (review S1)
        save_json(self.repo.triage_file, dict(source, pid=self.child.pid, ident=process_ident(self.child.pid)))
        self.watch(lambda: self.child.poll() is None, detail, source=source, what="the auto-triage", state="triage")
        source["exit_code"] = self.child.returncode
        self.child = None
        self.finish_triage(source)
        self.triage_source = None
        unlink(self.repo.triage_file)
        info = log_info(source)
        if info.rate_limit:
            self.usage = info.rate_limit
        kind, why = self.tree_state()
        if kind == "tree":
            # the loop never repairs the tree: a person looks at what the triage left (also after an error)
            say(f"after the auto-triage {why} - the loop stops; {where(source)}")
            say("look at git status and git log; commit or discard (git restore backlog) what it left, "
                "then bin/backlog-loop.sh start again")
            raise Stop(1)
        if info.limited:
            self.triage_limits += 1
            if self.triage_limits > MAX_LIMITS:
                say(f"the auto-triage ended at a usage limit {self.triage_limits} times - the loop stops; "
                    f"{where(source)}")
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
                    f"{where(source)}")
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
            say(f"the auto-triage REFUSED ({last_words(info)}); {where(source)}")
            if self.triage_refusals >= MAX_REFUSALS:
                say(f"the auto-triage refused {self.triage_refusals} times in a row - the loop stops; "
                    "look at its trace and at SKILL.md section 2.5a 'From the loop'")
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

    def item_refusal(self) -> str | None:
        """start --item: why it is refused before anything starts, None when it may run (344)."""
        slug = self.item
        pending = None if self.args.forget_run else load_json(self.repo.run_file)
        if pending and pending.get("slug") != slug:
            return (f"an interrupted run of {pending.get('slug')} must be continued first "
                    "(bin/backlog-loop.sh start continues it)")
        if pending:
            return None  # the interrupted run of this very item: continuing it is its run
        try:
            reason = self.item_reason(backlog.Backlog(self.repo.root), slug)
        except backlog.Refused as e:
            reason = str(e)
        return f"item {slug} is not eligible ({reason})" if reason else None

    def main(self) -> int:
        if self.item and not self.repo.live_loop():  # a live loop: register refuses, as for any start
            why = self.item_refusal()
            if why:
                tell(f"refused: {why}")
                self.write_last(1, "refused")
                return 1
        try:
            self.register()
        except Stop as s:
            return s.code  # nothing of the other loop is touched
        code, reason = 1, "error"  # an exception that is not ours: written, then raised
        try:
            if self.args.forget_run and self.repo.run_file.exists():
                say("the record of the interrupted run is dropped (--forget-run)")
                self.run = load_json(self.repo.run_file)
                if self.run and not self.run.get("trace"):
                    self.move_old_log(self.run.get("log"))  # a run of the loop before 342 (review S2)
                elif self.run:
                    self.finish_trace(self.run, self.run.get("phase") or "failed")  # once: a stop indexed it already
                self.run = None
                unlink(self.repo.run_file)
            self.import_old_logs()
            say(f"loop started (pid {os.getpid()}); pause: bin/backlog-loop.sh pause, stop: bin/backlog-loop.sh stop, "
                "status: bin/backlog-loop.sh status")
            code = self.cycle()
            reason = self.end_reason or "stop"
            return code
        except Stop as s:
            code, reason = s.code, s.reason
            return code
        except KeyboardInterrupt as e:
            code, reason = self.hard_stop("kill" if isinstance(e, Killed) else "Ctrl+C"), "hard-stop"
            return code
        finally:
            self.write_last(code, reason)  # before loop.json goes: a reader that misses it finds this
            self.unregister()
            say("loop ended: " + ", ".join(f"{k} {v}" for k, v in self.counts.items() if k != "nothing-to-do")
                + (f", auto-triage {self.triages}" if self.args.auto_triage else "")
                + f"; traces in {traces.TRACES_DIR}/")

    def import_old_logs(self) -> None:
        """Once (imported.json): move the logs of the loop before 342 into .agent-traces/.  The
        log of a pending run is left for migrate_old_run (its claude may still write to it)."""
        if self.repo.imported_file.exists() or not self.repo.old_logs.is_dir():
            return
        pending = load_json(self.repo.run_file) or {}
        old = pending.get("log") and not pending.get("trace")
        # a run that can still be continued keeps its log for migrate_old_run; a failed or
        # lost one is only ever dropped (--forget-run), so it moves with the rest
        stuck = bool(old) and pending.get("phase") in ("failed", "lost")
        skip = {Path(pending["log"]).stem} if old and not stuck else set()
        # a 247 auto-triage may still be running and writing its log: orphan_triage moves it
        # once that claude has ended (review M1)
        triage = load_json(self.repo.triage_file) or {}
        if triage.get("log") and not triage.get("trace"):
            skip.add(Path(triage["log"]).stem)
        imported, skipped = traces.import_old_logs(self.repo.root, self.repo.old_logs, self.repo.runs(), skip,
                                                   {"pid": None, "host": None, "auto_triage": None}, move=True)
        name = traces.new_name_for_old(Path(pending["log"]).stem) if stuck else None
        if name and (self.repo.traces / name).is_dir():
            folder = self.repo.traces / name
            pending.update({"trace": str(folder), "log": str(folder / traces.TRACE),
                            "err": str(folder / traces.STDERR), "indexed": True})
            save_json(self.repo.run_file, pending)
        save_json(self.repo.imported_file, {"date": stamp(), "imported": imported, "skipped": skipped})
        left = [p.name for p in self.repo.old_logs.iterdir()] if self.repo.old_logs.is_dir() else []
        say(f"moved {imported} run log(s) of the loop before 342 into {traces.TRACES_DIR}/"
            + (f"; {len(left)} file(s) left in {self.repo.old_logs}" if left else ""))

    def cycle(self) -> int:
        while True:
            self.check_kill()
            if self.stop_requested():
                say("stop requested - the loop ends")
                self.end_reason = "stop"
                return 0
            if self.paused():
                self.wait("paused", "paused - waiting for bin/backlog-loop.sh resume", None)
                if not self.paused() and not self.stop_requested():
                    # before any precheck: a reader that saw 'paused' knows none has passed since (344)
                    self.write_state("starting", "resumed")
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
            if self.item and self.finished:
                say(f"the run of item {self.item} ended (--item) - the loop ends")
                self.end_reason = "item-done"
                return 0
            if self.args.max_items and self.items >= self.args.max_items:
                say(f"{self.items} item(s) done (--max-items) - the loop ends")
                self.end_reason = "max-items"
                return 0
            state, what = self.precheck()
            if state == "idle" and self.args.until_idle:
                say(what.split(";")[0] + " - the loop ends (--until-idle)")
                self.end_reason = "until-idle"
                return 0
            if state == "gone":
                say(what + " - the loop ends")
                raise Stop(1, "refused")
            if state != "ready":
                self.wait(state, what, None, recheck=True)
                continue
            self.run = self.new_run(what)
            self.execute(resume=False)
            self.conclude()

    def hard_stop(self, how: str = "Ctrl+C") -> int:
        """Ctrl+C / Ctrl+Break in the window, or `kill` from another one (how = "kill", 344):
        the same path, only the words name the cause."""
        try:
            return self._hard_stop(how)
        finally:
            if how == "kill":
                unlink(self.repo.kill_flag)  # handled

    def _hard_stop(self, how: str) -> int:
        child, run = self.child, self.run
        if run is None and (child is not None or self.triage_source is not None):  # the auto-triage
            if child is not None and child.poll() is None:
                kill_tree(child.pid)
                try:
                    child.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    pass
            if self.triage_source is not None:  # also when Ctrl+C came before claude started
                if child is not None:
                    self.triage_source["exit_code"] = child.returncode
                self.finish_triage(self.triage_source, "killed")  # never continued: it ends here
            unlink(self.repo.triage_file)
            say("HARD STOP: claude was killed during the auto-triage.")
            say("What it changed and did not commit stays in backlog/ (git status): commit it or discard it "
                "(git restore backlog); the next bin/backlog-loop.sh start waits for a clean tree.")
        elif child is not None:
            # also when the same Ctrl+C already ended claude: the item is cut either way (review S4)
            if child.poll() is None:
                kill_tree(child.pid)
                try:
                    child.wait(timeout=30)
                except subprocess.TimeoutExpired:
                    pass
            atts = run.get("trace_attempts") or []
            if atts and atts[-1].get("ended") is None:
                atts[-1]["exit_code"] = child.returncode  # the loop started it, so it is known
            why = "a hard stop (kill) ended the process" if how == "kill" else "a hard stop (Ctrl+C) killed the process"
            run.update({"phase": "killed", "why": why, "child_pid": None, "child_ident": None})
            self.save_run()
            say(f"HARD STOP: claude was killed while it worked on item {run['slug']}.")
            say("The item keeps the run lock; the next bin/backlog-loop.sh start continues it in the same session.")
            say("If a GUI probe was running: restore its registry backup first (%TEMP%\\tcNNN_backup.reg, stop-rules 2.8).")
        elif run and alive(run.get("child_pid"), run.get("child_ident")):
            say(f"stopped ({how}) - the claude of the previous loop keeps working on item {run['slug']}; "
                "the next bin/backlog-loop.sh start waits for it")
        elif run and self.repo.run_file.exists():
            # an interrupted run waits (limit, backoff) or its verdict was being taken (review 2 N10)
            say(f"stopped ({how}) - no claude was running; the interrupted run of item {run['slug']} keeps the "
                "run lock and the next bin/backlog-loop.sh start continues it")
        else:
            say(f"stopped ({how}) - no item of this loop was running")
        return 130



# ---------------------------------------------------------------------------
# Commands


def cmd_start(repo: Repo, args) -> int:
    if args.new_window:
        return start_new_window(repo, args)
    if args.item:
        args.max_items = 1  # --item implies one run
    if args.console_title and os.name == "nt":
        import ctypes
        ctypes.WinDLL("kernel32").SetConsoleTitleW(args.console_title)
    LOG["path"] = repo.log_file
    try:
        args.harness_version = None  # a test's --claude-cmd is not asked (it would play a step)
        if args.claude_cmd is None:
            exe = shutil.which("claude")
            if not exe:
                tell("refused: 'claude' is not on PATH")
                Loop(repo, args).write_last(1, "refused")
                return 1
            args.claude_cmd = [exe]
            args.harness_version = claude_version(exe)
        if os.name == "nt":
            signal.signal(signal.SIGBREAK, _interrupt)
        signal.signal(signal.SIGINT, _interrupt)
        if hasattr(signal, "SIGTERM"):
            signal.signal(signal.SIGTERM, _interrupt)
        return Loop(repo, args).main()
    finally:
        LOG["path"] = None


def child_start_argv(repo: Repo, args) -> list:
    """The start command of the loop in a new window: the options given, from the parsed values
    (an abbreviated or `--opt=value` spelling is rebuilt the same), without --new-window."""
    out = ["start", "--root", str(repo.root)]
    for action in start_parser(build_parser())._actions:
        dest = action.dest
        if not action.option_strings or dest in ("help", "root", "new_window", "new_window_hidden", "console_title"):
            continue
        value = getattr(args, dest, None)
        if value is None or value == action.default:
            continue
        flag = action.option_strings[-1]
        if isinstance(action, argparse._StoreTrueAction):
            out.append(flag)
        elif dest == "claude_cmd":
            out += [flag, json.dumps(value)]
        elif dest == "backoff":
            out += [flag, ",".join(repr(v) for v in value)]
        else:
            out += [flag, str(value)]
    return out + ["--console-title", WINDOW_TITLE]


def log_size(repo: Repo) -> int:
    try:
        return repo.log_file.stat().st_size
    except OSError:
        return 0


def log_since(repo: Repo, offset: int) -> list:
    """The texts of the loop.log lines written since offset (without their time)."""
    try:
        with open(repo.log_file, "rb") as f:
            if f.seek(0, os.SEEK_END) < offset:
                offset = 0  # rotated meanwhile
            f.seek(offset)
            data = f.read()
    except OSError:
        return []
    lines = data.decode("utf-8", "replace").splitlines()
    return [re.sub(r"^\d{4}-\d\d-\d\d \d\d:\d\d:\d\d ", "", l) for l in lines if l.strip()]


DETACHED = []  # the loops started by start_new_window in this process


def start_new_window(repo: Repo, args) -> int:
    """start --new-window: the loop runs in a console window of its own (Ctrl+C there is its
    hard stop); this process returns once the new loop registered loop.json (344)."""
    other = repo.live_loop()
    if other:
        print(f"refused: another loop is running (pid {other.get('pid')}, since {other.get('started', '?')}); "
              "bin/backlog-loop.sh status shows it, bin/backlog-loop.sh stop ends it", flush=True)
        return 1
    cmd = [sys.executable, "-u", str(HERE / "loop.py"), *child_start_argv(repo, args)]
    offset = log_size(repo)
    launched = time.time()
    kw = {}
    if os.name == "nt":
        kw["creationflags"] = subprocess.CREATE_NEW_CONSOLE
        if args.new_window_hidden:  # tests: the maintainer works on this machine
            si = subprocess.STARTUPINFO()
            si.dwFlags |= subprocess.STARTF_USESHOWWINDOW
            si.wShowWindow = 0  # SW_HIDE
            kw["startupinfo"] = si
    else:
        kw.update(start_new_session=True, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                  stderr=subprocess.DEVNULL)
    try:
        child = subprocess.Popen(cmd, cwd=str(repo.root), **kw)
    except OSError as e:
        print(f"refused: the loop cannot be started in a new window ({e})", flush=True)
        return 1
    while time.time() - launched < NEW_WINDOW_WAIT:
        data = load_json(repo.loop_file)
        if data and alive(data.get("pid"), data.get("ident")):
            created = process_created(data.get("pid")) or 0.0
            # its pid; or, when the Python started is a launcher, a loop created since
            if data.get("pid") == child.pid or (child.poll() is None and created >= launched - 1):
                print(f"started the loop in a new window (pid {data.get('pid')})", flush=True)
                DETACHED.append(child)  # it outlives this call by design: no "still running" warning
                return 0
        if child.poll() is not None:
            break
        time.sleep(0.1)
    said = log_since(repo, offset)
    if said:
        why = "; ".join(said[-3:])
    elif child.poll() is not None:
        why = f"it ended at once (exit {child.returncode})"
    else:
        why = f"it did not register within {NEW_WINDOW_WAIT:g} s (pid {child.pid})"
    print(f"refused: the loop in a new window did not start: {why}", flush=True)
    return 1


def describe(repo: Repo) -> dict:
    """What status prints, as data."""
    loop = load_json(repo.loop_file)
    live = bool(loop and alive(loop.get("pid"), loop.get("ident")))
    run = load_json(repo.run_file)
    triage = load_json(repo.triage_file)
    trace = (run or {}).get("trace") or ((loop or {}).get("trace") if live else None)
    return {"loop": loop, "live": live, "run": run, "triage": triage,
            "paused": repo.pause_flag.exists(),
            "stop": repo.stop_flag.exists(), "lock": repo.lock(), "lock_text": repo.lock_text(),
            "trace": trace, "traces_bytes": traces.traces_size(repo.root),
            # 344: a pending kill (a flag without a live loop is stale: the next start removes it)
            "kill": repo.kill_flag.exists() and live, "last": load_json(repo.last_file),
            "edit_lock": repo.edit_lock(), "log": str(repo.log_file),
            # 344: a claude of a dead loop still working (the item's run or the auto-triage) - the
            # same checks the text output makes, so the backlog app need not test processes itself
            "orphan": not live and bool((run and alive(run.get("child_pid"), run.get("child_ident")))
                                        or (triage and alive(triage.get("pid"), triage.get("ident"))))}


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
    control = [t for t, on in (("pause requested", d["paused"]), ("stop requested", d["stop"] and d["live"]),
                               ("kill requested", d["kill"])) if on]
    print(f"control: {', '.join(control) if control else '-'}")
    if loop:
        counts = loop.get("counts") or {}
        print("done:    " + ", ".join(f"{k} {counts.get(k, 0)}" for k in backlog.RUN_OUTCOMES if k != "nothing-to-do")
              + f" (blocked in a row: {loop.get('blocked_streak', 0)})" + ("" if d["live"] else " - the last loop"))
        if loop.get("auto_triage"):
            print(f"triage:  auto, when the Inbox has new items ({loop.get('triages', 0)} done)")
        print(f"usage:   {usage_line(loop.get('usage'))}")
    trace = d["trace"] or (run or {}).get("log")  # a run of the loop before 342 not moved yet: its log
    trace_line = f"trace:   {trace or '-'} (traces total: {traces.format_size(d['traces_bytes'])})"
    if run:
        line = f"run:     item {run['slug']}, session {run['session']}, phase {run.get('phase')}"
        if run.get("wait_until"):
            line += f", continues after {clock(run['wait_until'])}"
        if run.get("why"):
            line += f" ({run['why']})"
        print(line)
        print(trace_line)
        if run.get("phase") in ("lost", "failed"):
            slug = run["slug"]
            print("todo:    the run cannot be continued automatically. Look at its trace and its branch (the lock")
            print("         names it), finish the item by hand or stop it as a run would (SKILL.md step 10):")
            print(f"           bin/backlog.sh lock release --force ; git checkout main")
            print(f"           bin/backlog.sh block {slug} --reason '<why>'")
            print(f"           git add backlog ; git commit -m 'backlog: {slug} blocked'")
            print("         then bin/backlog-loop.sh start --forget-run")
        elif not d["live"] and alive(run.get("child_pid"), run.get("child_ident")):
            print(f"         its claude (pid {run['child_pid']}) is still working; the next bin/backlog-loop.sh start waits for it")
        elif not d["live"]:
            print("         the next bin/backlog-loop.sh start continues this run in the same session")
            if run.get("phase") in ("running", "killed", "new"):
                print("         (it was cut off: if a GUI probe was running, its registry backup is restored first -")
                print("         stop-rules 2.8, %TEMP%\\tcNNN_backup.reg; the continued run is told so)")
    if not run:
        print(trace_line)
    triage = d["triage"]
    if triage and not d["live"] and alive(triage.get("pid"), triage.get("ident")):
        print(f"triage:  the auto-triage claude of the last loop (pid {triage['pid']}) is still working; "
              "the next bin/backlog-loop.sh start waits for it")
    print(f"lock:    {d['lock_text']}")
    if d["live"]:
        triaging = loop.get("state") == "triage"
        hard = loop.get("ctrl_c_safe") is False and (triaging or (bool(run) and alive(run.get("child_pid"),
                                                                                       run.get("child_ident"))))
        print("Ctrl+C:  " + (f"HARD STOP now ({'the auto-triage' if triaging else 'an item'} is running) - "
                             "use bin/backlog-loop.sh pause / bin/backlog-loop.sh stop" if hard else "safe now (no item is running)"))
    return 0


def cmd_pause(repo: Repo, args) -> int:
    repo.dir.mkdir(parents=True, exist_ok=True)
    already = repo.pause_flag.exists()
    repo.pause_flag.write_text(stamp() + "\n", encoding="utf-8")
    d = describe(repo)
    if not d["live"]:
        print("pause set: no loop is running; the next bin/backlog-loop.sh start starts paused (bin/backlog-loop.sh resume clears it)")
    elif d["loop"].get("state") in ("running", "triage"):
        what = f"item {d['loop'].get('slug')}" if d["loop"].get("state") == "running" else "the auto-triage"
        print(f"pause {'was already ' if already else ''}requested: the loop finishes {what}, "
              "then waits for bin/backlog-loop.sh resume (bin/backlog-loop.sh status shows when)")
    else:
        print("paused: the loop waits for bin/backlog-loop.sh resume")
    run = d["run"]
    if run and d["lock"] is not None and run.get("phase") not in ("lost", "failed"):
        # review 2 N8: the interrupted run keeps its branch and lock until it is continued
        print(f"note: the interrupted run of item {run['slug']} keeps the run lock and its branch until it is "
              "continued (bin/backlog-loop.sh resume); the backlog cannot be changed safely before it finishes")
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
        print("pause cleared: no loop is running; start it with bin/backlog-loop.sh start")
    return 0


def cmd_stop(repo: Repo, args) -> int:
    live = repo.live_loop()
    if not live:
        unlink(repo.stop_flag)
        print("no loop is running" + (" (a pause is still set: bin/backlog-loop.sh resume clears it)" if repo.pause_flag.exists() else ""))
        return 0
    repo.stop_flag.write_text(stamp() + "\n", encoding="utf-8")
    if live.get("state") in ("running", "triage"):
        what = f"item {live.get('slug')}" if live.get("state") == "running" else "the auto-triage"
        print(f"stop requested: the loop finishes {what}, then ends (bin/backlog-loop.sh resume cancels it)")
    else:
        print("stop requested: the loop ends within a few seconds")
    return 0


def cmd_kill(repo: Repo, args) -> int:
    live = repo.live_loop()
    if not live:
        print("no loop is running; nothing to kill")
        return 0
    repo.kill_flag.write_text(stamp() + "\n", encoding="utf-8")
    if live.get("state") == "running":
        print(f"kill requested: the loop kills claude (item {live.get('slug')}) and ends within a few seconds, as "
              "after Ctrl+C in its window; the item keeps the run lock and the next bin/backlog-loop.sh start "
              "continues it")
    elif live.get("state") == "triage":
        print("kill requested: the loop kills the auto-triage's claude and ends within a few seconds, as after "
              "Ctrl+C in its window; what it did not commit stays in backlog/ (git status)")
    else:
        print("kill requested: the loop ends within a few seconds (a hard stop, as after Ctrl+C in its window)")
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
    p = argparse.ArgumentParser(prog="bin/backlog-loop.sh",
                                description="Loop over /tandem-backlog-implement (features 247, 342).")
    sub = p.add_subparsers(dest="command", required=True)
    s = sub.add_parser("start", parents=[common], help="run the loop in the foreground (Ctrl+C = hard stop)",
                       description="Run /tandem-backlog-implement item after item, one fresh claude process "
                                   "each. Ctrl+C = hard stop; bin/backlog-loop.sh pause, resume, stop and status "
                                   "control it from another window.",
                       epilog="Full documentation: specs/247-backlog-run-loop/contracts/loop-cli.md; "
                              "traces: specs/342-backlog-agent-traces/contracts/traces.md")
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
    s.add_argument("--item", metavar="SLUG",
                   help="run this one item, then end (implies --max-items 1; not with --until-idle); refused when "
                        "it is not eligible (backlog next --slug) or an interrupted run must be continued first")
    s.add_argument("--new-window", action="store_true",
                   help="start the loop with the other options in a new console window and return once it "
                        "runs (Ctrl+C in that window is its hard stop)")
    # tests
    s.add_argument("--new-window-hidden", action="store_true", help=argparse.SUPPRESS)  # no window pops up
    s.add_argument("--console-title", help=argparse.SUPPRESS)  # set by --new-window for the loop it starts
    s.add_argument("--claude-cmd", type=json.loads, default=None, help=argparse.SUPPRESS)
    s.add_argument("--backoff", type=seconds_list, default=BACKOFF, help=argparse.SUPPRESS)
    s.add_argument("--limit-margin", type=float, default=LIMIT_MARGIN, help=argparse.SUPPRESS)
    s.add_argument("--limit-unknown-wait", type=float, default=LIMIT_UNKNOWN_WAIT, help=argparse.SUPPRESS)
    s.add_argument("--tick", type=float, default=TICK, help=argparse.SUPPRESS)
    s.add_argument("--deadline", type=float, default=0, help=argparse.SUPPRESS)  # a test that would hang fails instead
    s = sub.add_parser("status", parents=[common], help="what the loop does now",
                       description="What the loop does now: the running item, waiting and why, usage limits, "
                                   "an interrupted run, the run lock, whether Ctrl+C is safe.")
    s.add_argument("--json", action="store_true", help="the data as JSON")
    sub.add_parser("pause", parents=[common], help="finish the running item, then wait for resume",
                   description="The running item finishes, then the loop waits for resume. Without a loop "
                               "the next start waits. Persists until resume.")
    sub.add_parser("resume", parents=[common], help="continue after a pause; cancels a pending stop",
                   description="Clear the pause and a pending stop.")
    sub.add_parser("stop", parents=[common], help="finish the running item, then end the loop",
                   description="The running item finishes, then the loop ends; a waiting loop ends at once. "
                               "Without a loop it says so and sets nothing; resume cancels a pending stop.")
    sub.add_parser("kill", parents=[common], help="hard stop from another window: kill claude, end the loop",
                   description="The hard stop of Ctrl+C in the loop's window, from another one: the loop kills "
                               "claude's process tree within a second, the item keeps the run lock and the next "
                               "start continues it (exit 130 of the loop). Without a loop it says so and sets "
                               "nothing.")
    return p


def start_parser(p: argparse.ArgumentParser) -> argparse.ArgumentParser:
    return next(a for a in p._actions if isinstance(a, argparse._SubParsersAction)).choices["start"]


COMMANDS = {"start": cmd_start, "status": cmd_status, "pause": cmd_pause, "resume": cmd_resume, "stop": cmd_stop,
            "kill": cmd_kill}


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
    if args.command == "start" and args.item and args.until_idle:
        print("usage: --item runs one item; --until-idle does not apply to it", flush=True)
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
