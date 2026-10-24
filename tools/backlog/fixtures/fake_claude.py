# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""A stand-in for `claude -p` in the tests of loop.py (feature 247).

It plays one step of a plan per invocation and records the call.  The plan
is a JSON file named by FAKE_CLAUDE_PLAN: {"steps": [...], "calls": [...]};
a step is a name or {"do": name, ...}.  It changes the backlog of the
repository it runs in (its working directory) the way a real run would:
the run lock, the item, a journal row, a commit.

Steps: close, block, split, notrepro (a finished run); limit [in: seconds],
limit-noreset, crash, stall, watchdog-stall, context-error, row-keep-lock (an
interrupted run holding the lock); limit-start, crash-start, refuse,
refuse-other, lost (a run that never took its item); release (finish a run
that wrote its row but kept the lock); hang [seconds, then: step] (sleeps
holding the lock, then plays `then`); idle [seconds] (holds the lock, no
background task, two no-op wakeups, then sleeps - the loop must stop it);
idle-busy [seconds] (the same wakeups while a background task runs, then
the task ends, a working wakeup, and the run closes - never stopped).
A finished run with `add: slug
[, severity: n]` first records a new Inbox item.  For the loop's
auto-triage: triage (every Inbox item to Next - severity 7+ at the top -
and a commit), triage-none (no change, no commit), triage-dirty (a change
left uncommitted), triage-hang
[seconds] (sleeps, then triage); each first checks what the skill checks
(loop status: the pid of TANDEM_BACKLOG_LOOP_TRIAGE, state triage, lock
free) and refuses otherwise, unless `nogate` is set; crash-start,
limit-start and refuse work there too.
"""

import json
import os
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import backlog  # noqa: E402

ROOT = Path.cwd()


def bl(*args):
    code = backlog.main(["--root", str(ROOT), *args])
    if code not in (0,):
        raise SystemExit(f"fake: backlog.py {' '.join(args)} -> {code}")


def git(*args):
    subprocess.run(["git", "-C", str(ROOT), *args], check=True, capture_output=True)


def emit(obj):
    print(json.dumps(obj), flush=True)


def result(text, error=False, status=None):
    emit({"type": "result", "subtype": "success", "is_error": error, "api_error_status": status,
          "result": text, "session_id": SESSION})


def wakeup(noop, tick=True):
    """A turn started by a scheduled wakeup (tick) that schedules the next one."""
    if tick:
        emit({"type": "command_lifecycle", "command_uuid": "fake", "state": "started",
              "wakeup_source": "loop_wakeup", "session_id": SESSION})
    emit({"type": "assistant", "message": {"role": "assistant", "content": [
        {"type": "tool_use", "id": "toolu_fake", "name": "ScheduleWakeup",
         "input": {"delaySeconds": 600, "noop": noop, "prompt": "continue", "reason": "fake"}}]},
        "parent_tool_use_id": None, "session_id": SESSION})


def lock_slug():
    try:
        return backlog.read_lock(backlog.lock_path(ROOT, None)).get("slug")
    except FileNotFoundError:
        return None


def ensure_lock(slug):
    if lock_slug() != slug:
        bl("lock", "acquire", "--slug", slug)


def finish(slug, outcome, step=None):
    ensure_lock(slug)
    if (step or {}).get("add"):
        new = step["add"]
        bl("new", "--title", f"Found by {slug}: {new}", "--type", "bug", "--severity", str(step.get("severity", 9)),
           "--area", "tooling", "--source", "manual", "--slug", new, "--problem", "p", "--evidence", "e",
           "--expected", "x")
    if outcome == "closed":
        bl("remove", slug, "--reason", "fake close")
    else:
        bl("block", slug, "--reason", f"fake {outcome}")
    bl("run-log", "--outcome", outcome, "--slug", slug, "--note", "fake")
    git("add", "-A")
    git("commit", "-q", "-m", f"fake: {slug} {outcome}")
    bl("lock", "release", "--slug", slug)
    result(f"Outcome: {outcome}\nItem: {slug}")


def loop_gate():
    """What SKILL.md 2.5a 'From the loop' checks before a triage; None when it may proceed."""
    pid = os.environ.get("TANDEM_BACKLOG_LOOP_TRIAGE")
    if not pid:
        return "TANDEM_BACKLOG_LOOP_TRIAGE is not set"
    loop_py = Path(__file__).resolve().parents[1] / "loop.py"
    out = subprocess.run([sys.executable, str(loop_py), "status", "--root", str(ROOT)], capture_output=True,
                         text=True, encoding="utf-8").stdout
    if f"loop:    running (pid {pid}," not in out:
        return f"the loop of pid {pid} is not running"
    if "\nstate:   triage" not in out:
        return "the loop is not in state triage"
    if "\nlock:    free" not in out:
        return "the run lock is held"
    return None


def play(step, slug):
    do = step["do"]
    if do in ("close", "block", "split", "notrepro"):
        finish(slug, {"close": "closed", "notrepro": "not-reproduced"}.get(do, do + ("ed" if do == "block" else "")),
               step)
        return 0
    if do in ("triage", "triage-dirty", "triage-hang", "triage-none") and not step.get("nogate"):
        why = loop_gate()
        if why:
            result(f"Outcome: refused ({why})")
            return 0
    if do == "triage-hang":
        (Path(os.environ["FAKE_CLAUDE_PLAN"]).parent / "fake.pid").write_text(str(os.getpid()))
        time.sleep(step.get("seconds", 60))
        return play({"do": "triage", "nogate": True}, slug)
    if do == "triage":
        b = backlog.Backlog(ROOT)
        for row in list(b.ov.sections[backlog.SEC_INBOX].rows):
            top = int(b.items[row.slug].header["severity"]) >= 7
            bl("move", row.slug, "--section", "next", *(["--position", "1"] if top else []))
        git("add", "-A")
        git("commit", "-q", "-m", "backlog: auto-triage (fake)")
        result("Placed every Inbox item.")
        return 0
    if do == "triage-none":
        result("Every Inbox item stays in Inbox (rule B).")
        return 0
    if do == "triage-dirty":
        with open(ROOT / "backlog" / "BACKLOG.md", "a", encoding="utf-8") as f:
            f.write("\n")
        result("Left a change.")
        return 0
    if do in ("limit", "limit-start"):
        if do == "limit":
            ensure_lock(slug)
        reset = int(time.time() + step.get("in", 1))
        emit({"type": "rate_limit_event", "rate_limit_info": {
            "status": "rejected", "resetsAt": reset, "rateLimitType": "five_hour",
            "unifiedWindows": {"five_hour": {"utilization": 1.0, "resetsAt": reset}}}})
        result("You've hit your limit", error=True, status=429)
        return 1
    if do == "limit-noreset":
        ensure_lock(slug)
        result("Claude usage limit reached", error=True, status=429)
        return 1
    if do in ("crash", "crash-start"):
        if do == "crash":
            ensure_lock(slug)
        print("fake: boom", file=sys.stderr, flush=True)
        return 3
    if do == "stall":
        ensure_lock(slug)
        result("I stopped here.")
        return 0
    if do == "row-keep-lock":
        ensure_lock(slug)
        bl("remove", slug, "--reason", "fake close")
        bl("run-log", "--outcome", "closed", "--slug", slug, "--note", "fake")
        git("add", "-A")
        git("commit", "-q", "-m", f"fake: {slug} closed, lock kept")
        result("Outcome: closed (lock not released)")
        return 0
    if do == "release":
        bl("lock", "release", "--slug", slug)
        result("Outcome: closed")
        return 0
    if do == "refuse":
        result("Outcome: refused (precondition: fake)")
        return 0
    if do == "refuse-other":
        # a manual run took the same item's lock first; this run refuses (review M1)
        if lock_slug() is None:
            bl("lock", "acquire", "--slug", slug)
        result("Outcome: refused (another run in progress: held by item " + slug + ")")
        return 0
    if do == "crash-other-lock":
        # another item's run holds the lock when this one dies
        bl("lock", "acquire", "--slug", "someone-else")
        return 3
    if do == "watchdog-stall":
        # claude waited a limit out in-process, then the turn ended without finishing (review S1)
        ensure_lock(slug)
        emit({"type": "rate_limit_event", "rate_limit_info": {"status": "rejected", "resetsAt": int(time.time()) - 5}})
        result("I stopped here.")
        return 0
    if do == "context-error":
        ensure_lock(slug)
        result("Context limit reached", error=True)
        return 1
    if do == "lost":
        print(f"No conversation found with session ID: {SESSION}", file=sys.stderr, flush=True)
        return 1
    if do in ("idle", "idle-busy"):
        ensure_lock(slug)
        busy = do == "idle-busy"
        emit({"type": "system", "subtype": "background_tasks_changed",
              "tasks": [{"task_id": "a1", "task_type": "local_agent"}] if busy else []})
        for _ in range(2):
            wakeup(noop=True)
            result("Waiting for the review.")
        time.sleep(step.get("seconds", 30 if not busy else 1))
        if not busy:
            result("Still waiting.")
            return 0
        emit({"type": "system", "subtype": "task_notification", "task_id": "a1", "status": "completed"})
        emit({"type": "system", "subtype": "background_tasks_changed", "tasks": []})
        wakeup(noop=False)
        time.sleep(0.5)  # the loop looks at the log meanwhile: a finished task is not idling
        finish(slug, "closed")
        return 0
    if do == "hang":
        ensure_lock(slug)
        (Path(os.environ["FAKE_CLAUDE_PLAN"]).parent / "fake.pid").write_text(str(os.getpid()))
        time.sleep(step.get("seconds", 60))
        return play({"do": step.get("then", "close")}, slug)
    raise SystemExit(f"fake: unknown step {do}")


def main():
    global SESSION
    argv = sys.argv[1:]
    plan_path = Path(os.environ["FAKE_CLAUDE_PLAN"])
    plan = json.loads(plan_path.read_text(encoding="utf-8"))
    prompt = argv[argv.index("-p") + 1]
    resume = "--resume" in argv
    SESSION = argv[argv.index("--resume" if resume else "--session-id") + 1]
    slug = lock_slug() if resume else prompt.split()[-1]
    step = plan["steps"].pop(0) if plan["steps"] else "refuse"
    step = {"do": step} if isinstance(step, str) else step
    plan["calls"].append({"argv": argv, "prompt": prompt, "resume": resume, "session": SESSION, "slug": slug,
                          "step": step["do"], "watchdog": os.environ.get("CLAUDE_CODE_RETRY_WATCHDOG"),
                          "bg_ceiling": os.environ.get("CLAUDE_CODE_PRINT_BG_WAIT_CEILING_MS"),
                          "test_clock": os.environ.get("TANDEM_BACKLOG_NOW"),
                          "triage_env": os.environ.get("TANDEM_BACKLOG_LOOP_TRIAGE"),
                          "pid": os.getpid(), "cwd": str(ROOT)})
    plan_path.write_text(json.dumps(plan, indent=1), encoding="utf-8")
    emit({"type": "system", "subtype": "init", "session_id": SESSION})
    return play(step, slug)


SESSION = None
if __name__ == "__main__":
    sys.exit(main())
