# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Traces of the backlog loop in ``.agent-traces/`` (feature 342).

The format is binding: specs/342-backlog-agent-traces/contracts/traces.md.
It is the format of the reference project (2026_hscr_ai_chatbot, feature
003), so the traces of both can feed the same eval system:

  .agent-traces/index.jsonl                      one line per ended run
  .agent-traces/<YYYYMMDD-HHMMSS>-claude-<slug|triage>[-N]/
      trace.jsonl   claude's stdout unchanged + one separator line per attempt
      stderr.log    claude's stderr, one header line per attempt
      meta.json     the run (replaced atomically)

The loop (loop.py) decides when a run starts, ends or is continued; this
module only builds and writes the records.  It also copies the logs of the
loop before 342 (``.git/tandem-backlog-loop/logs/``) into the layout once.
The loop never deletes traces.

Standard library only.
"""

from __future__ import annotations

import datetime as dt
import json
import os
import re
import shutil
import subprocess
import tempfile
import time
from pathlib import Path

TRACES_DIR = ".agent-traces"
INDEX = "index.jsonl"
TRACE = "trace.jsonl"
STDERR = "stderr.log"
META = "meta.json"
FORMAT_VERSION = 1
SEPARATOR_TYPE = "backlog_loop.attempt"
HARNESS = "claude"
TRIAGE = "triage"
KINDS = ("start", "continue")
REASONS = ("-", "usage-limit", "error", "stall", "idle", "killed")  # "killed" is ours; "restart" is never written

# The logs of the loop before 342: <YYYYMMDD-HHMMSS>-<slug>.jsonl / .err, triages as -auto-triage
OLD_NAME_RE = re.compile(r"^(\d{8}-\d{6})-(.+)$")
OLD_TRIAGE = "auto-triage"


# ---------------------------------------------------------------------------
# Times and names


def iso_local(t: float | None) -> str | None:
    """ISO 8601 in local time with the offset, seconds precision (2026-10-25T14:02:00+02:00)."""
    if t is None:
        return None
    return dt.datetime.fromtimestamp(t).astimezone().isoformat(timespec="seconds")


def stamp_name(t: float) -> str:
    return dt.datetime.fromtimestamp(t).strftime("%Y%m%d-%H%M%S")


def traces_root(root: Path) -> Path:
    return Path(root) / TRACES_DIR


def new_run_dir(root: Path, slug: str, started: float) -> Path:
    """Create the folder of a new run; -2, -3 ... when the name is taken.  A folder
    is never reused: creating it is the claim."""
    base = f"{stamp_name(started)}-{HARNESS}-{slug}"
    top = traces_root(root)
    top.mkdir(parents=True, exist_ok=True)
    n = 1
    while True:
        path = top / (base if n == 1 else f"{base}-{n}")
        try:
            path.mkdir()
            return path
        except FileExistsError:
            n += 1


# ---------------------------------------------------------------------------
# Lines written before each attempt


def _check(kind: str, reason: str) -> None:
    if kind not in KINDS:
        raise ValueError(f"attempt kind {kind!r}")
    if reason not in REASONS:
        raise ValueError(f"attempt reason {reason!r}")


def ends_line(f) -> bool:
    """The file (open for append, binary) is empty or ends with a newline.  A claude killed
    mid-write leaves a partial last line; a separator glued to it would not parse (review S1)."""
    try:
        size = os.fstat(f.fileno()).st_size
        if size == 0:
            return True
        with open(f.name, "rb") as r:
            r.seek(size - 1)
            return r.read(1) == b"\n"
    except OSError:
        return True


def separator_line(attempt: int, kind: str, reason: str, started: str, session: str | None) -> bytes:
    """The line the loop appends to trace.jsonl before an attempt."""
    _check(kind, reason)
    obj = {"type": SEPARATOR_TYPE, "attempt": attempt, "kind": kind, "reason": reason, "started": started,
           "harness": HARNESS, "session_id": session}
    return (json.dumps(obj, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")


def stderr_header(attempt: int, kind: str, reason: str, started: str) -> bytes:
    """The line the loop appends to stderr.log before an attempt."""
    _check(kind, reason)
    return f"=== attempt {attempt} ({kind}, {reason}) {started} ===\n".encode("utf-8")


def attempt_record(attempt: int, kind: str, reason: str, started: str) -> dict:
    """A new attempt as meta.json lists it; the rest is filled when it ends."""
    _check(kind, reason)
    return {"attempt": attempt, "kind": kind, "reason": reason, "started": started, "ended": None,
            "ending": None, "error_kind": None, "resets_at": None, "exit_code": None, "idle_killed": False,
            "usage": {}}


# ---------------------------------------------------------------------------
# Writing


def write_json_atomic(path: Path, data: dict) -> None:
    """Replace the file whole: a reader sees the old or the new version, never half."""
    text = json.dumps(data, ensure_ascii=False, indent=2) + "\n"
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    for attempt in range(40):
        fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=path.name + ".", suffix=".tmp~")
        try:
            with os.fdopen(fd, "w", encoding="utf-8", newline="\n") as f:
                f.write(text)
            os.replace(tmp, path)
            return
        except PermissionError:  # a reader has it open (Windows)
            try:
                os.unlink(tmp)
            except OSError:
                pass
            if attempt == 39:
                raise
            time.sleep(0.05)
        except BaseException:
            try:
                os.unlink(tmp)
            except OSError:
                pass
            raise


def append_line(path: Path, data: dict) -> None:
    """One JSON line, written with one write."""
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    line = (json.dumps(data, ensure_ascii=False, separators=(",", ":")) + "\n").encode("utf-8")
    with open(path, "ab") as f:
        f.write(line)


# ---------------------------------------------------------------------------
# meta.json and the index


def build_meta(record: dict, *, phase: str | None, ended: str | None, outcome: str | None,
               feature: str | None, branch: str | None, commits: list, why: str | None,
               loop_info: dict, harness_version: str | None, model: str | None,
               imported: bool = False) -> dict:
    """meta.json of a run, in the contract's key order.  `record` is the loop's run record
    (run.json, or the auto-triage's): kind, slug, session, started (epoch), trace_attempts
    and the counters of feature 247 (limits, attempts = errors, stalls, nudges = idle kills)."""
    meta = {
        "format_version": FORMAT_VERSION,
        "kind": record.get("kind", "item"),
        "slug": record.get("slug"),
        "harness": HARNESS,
        "harness_version": harness_version,
        "model": model,
        "session_id": record.get("session"),
        "started": iso_local(record.get("started_epoch")),
        "ended": ended,
        "phase": phase,
        "outcome": outcome,
        "feature": feature,
        "branch": branch,
        "commits": list(commits),
        "why": why,
        "attempts": [dict(a) for a in record.get("trace_attempts") or []],
        "counters": {"limits": int(record.get("limits") or 0), "errors": int(record.get("attempts") or 0),
                     "stalls": int(record.get("stalls") or 0), "idles": int(record.get("nudges") or 0),
                     "restarts": 0},
        "loop": {"pid": loop_info.get("pid"), "host": loop_info.get("host"),
                 "auto_triage": loop_info.get("auto_triage")},
    }
    if imported:
        meta["imported"] = True
    return meta


def build_index_line(meta: dict, dir_name: str) -> dict:
    # an imported run does not know its attempts (the old logs have no separators)
    attempts = None if meta.get("imported") else len(meta["attempts"])
    return {"dir": dir_name, "kind": meta["kind"], "slug": meta["slug"], "harness": meta["harness"],
            "model": meta["model"], "started": meta["started"], "ended": meta["ended"], "phase": meta["phase"],
            "outcome": meta["outcome"], "feature": meta["feature"], "attempts": attempts}


def first_init(path: Path) -> tuple:
    """(session_id, model) of the first system/init event of a trace, (None, None) if none."""
    try:
        with open(path, "rb") as f:
            for raw in f:
                if b'"init"' not in raw:
                    continue
                try:
                    obj = json.loads(raw)
                except ValueError:
                    continue
                if obj.get("type") == "system" and obj.get("subtype") == "init":
                    return obj.get("session_id"), obj.get("model")
    except OSError:
        pass
    return None, None


# ---------------------------------------------------------------------------
# The commits of a run (by subject: research R7)


def commit_matches(subject: str, *, slug: str, feature: str | None, kind: str) -> bool:
    if kind == TRIAGE:
        return subject.startswith("backlog: auto-triage")
    if feature and subject.startswith(f"[{feature}]"):
        return True
    return subject.startswith(f"backlog: {slug} ") or subject == f"backlog: {slug}"


def run_commits(root: Path, started: float, ended: float | None, *, slug: str, feature: str | None,
                kind: str, base: str | None = None) -> list:
    """Short hashes, oldest first, of the commits of all branches whose subject names the run:
    those not reachable from `base` (HEAD when the run started), else - for the logs of the
    loop before 342, which recorded no base - those made while it lived.  [] when git fails."""
    cmd = ["git", "-C", str(root), "log", "--all", "--reverse", "--format=%h%x00%s"]
    if base:
        cmd.append(f"^{base}")
    else:
        cmd.append(f"--since={iso_local(started - 1)}")
        if ended is not None:
            cmd.append(f"--until={iso_local(ended + 1)}")
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace")
    except OSError:
        return []
    if res.returncode != 0:
        return []
    out = []
    for line in res.stdout.splitlines():
        h, _, subject = line.partition("\x00")
        if h and commit_matches(subject, slug=slug, feature=feature, kind=kind):
            out.append(h)
    return out


# ---------------------------------------------------------------------------
# Size (status)


def traces_size(root: Path) -> int:
    """Bytes of every file under .agent-traces/ (0 when it does not exist)."""
    total = 0
    stack = [str(traces_root(root))]
    while stack:
        try:
            it = os.scandir(stack.pop())
        except OSError:
            continue
        with it:
            for e in it:
                try:
                    if e.is_dir(follow_symlinks=False):
                        stack.append(e.path)
                    elif e.is_file(follow_symlinks=False):
                        total += e.stat(follow_symlinks=False).st_size
                except OSError:
                    continue  # vanished meanwhile
    return total


def format_size(n: int) -> str:
    value = float(n)
    for unit in ("B", "kB", "MB", "GB"):
        if value < 1024 or unit == "GB":
            return f"{int(value)} B" if unit == "B" else f"{value:.1f} {unit}"
        value /= 1024
    return f"{n} B"


# ---------------------------------------------------------------------------
# The logs of the loop before 342


def parse_old_name(stem: str) -> tuple | None:
    """(started epoch, slug, kind) of an old log name, None when it is not one."""
    m = OLD_NAME_RE.match(stem)
    if not m:
        return None
    try:
        started = dt.datetime.strptime(m.group(1), "%Y%m%d-%H%M%S").timestamp()
    except ValueError:
        return None
    if m.group(2) == OLD_TRIAGE:
        return started, TRIAGE, TRIAGE
    return started, m.group(2), "item"


def new_name_for_old(stem: str) -> str | None:
    """The run folder an old log becomes: <stamp>-claude-<slug|triage>."""
    p = parse_old_name(stem)
    if p is None:
        return None
    return f"{OLD_NAME_RE.match(stem).group(1)}-{HARNESS}-{p[1]}"


def runs_row_time(row: list) -> float | None:
    try:
        return dt.datetime.strptime(row[0].strip(), "%Y-%m-%d %H:%M").timestamp()
    except (ValueError, IndexError):
        return None


def match_runs_row(rows: list, slug: str, started: float, next_started: float | None) -> list | None:
    """The journal row of a run: the first row of the slug written at or after the minute the
    run started and before the next run of the same slug started."""
    floor = dt.datetime.fromtimestamp(started).replace(second=0, microsecond=0).timestamp()
    for row in rows:
        if len(row) < 3 or row[1].strip() != slug:
            continue
        t = runs_row_time(row)
        if t is None or t < floor:
            continue
        if next_started is not None and t >= next_started:
            continue
        return row
    return None


def cell(row: list | None, i: int) -> str | None:
    if row is None or len(row) <= i:
        return None
    v = row[i].strip()
    return None if v in ("", "-") else v


def same_bytes(a: Path, b: Path) -> bool:
    try:
        if a.stat().st_size != b.stat().st_size:
            return False
        with open(a, "rb") as fa, open(b, "rb") as fb:
            while True:
                x, y = fa.read(1 << 20), fb.read(1 << 20)
                if x != y:
                    return False
                if not x:
                    return True
    except OSError:
        return False


def remove_old(*paths: Path) -> bool:
    """Delete moved old files; a file another process holds stays (False), never a crash."""
    ok = True
    for src in paths:
        try:
            if src.exists():
                src.unlink()
        except OSError:
            ok = False
    return ok


def import_old_logs(root: Path, logs_dir: Path, runs_rows: list, skip_stems: set, loop_info: dict,
                    move: bool = False) -> tuple:
    """Copy every old <stamp>-<slug>.jsonl/.err pair into a run folder with meta.json and an
    index line, in name (= start) order.  With move, the old pair is deleted once its copy is
    verified byte for byte and its folder is in place (and logs_dir when it is left empty);
    without, logs_dir is never written.  Returns (imported, skipped)."""
    logs_dir = Path(logs_dir)
    if not logs_dir.is_dir():
        return 0, 0
    stems = sorted({p.stem for p in logs_dir.iterdir() if p.suffix in (".jsonl", ".err")})
    parsed = [(s, parse_old_name(s)) for s in stems]
    index_path = traces_root(root) / INDEX
    try:
        indexed = {json.loads(l).get("dir") for l in index_path.read_text(encoding="utf-8").splitlines() if l.strip()}
    except (OSError, ValueError):
        indexed = set()
    imported = skipped = 0
    for i, (stem, p) in enumerate(parsed):
        if p is None or stem in skip_stems:
            skipped += 1
            continue
        started, slug, kind = p
        name = new_name_for_old(stem)
        dest = traces_root(root) / name
        jsonl, err = logs_dir / f"{stem}.jsonl", logs_dir / f"{stem}.err"
        if dest.exists():
            # an import cut off after the rename: finish what it left (the index line, the delete)
            if (dest / META).is_file() and name not in indexed:
                try:
                    meta = json.loads((dest / META).read_text(encoding="utf-8"))
                    append_line(index_path, build_index_line(meta, name))
                    indexed.add(name)
                except (OSError, ValueError):
                    pass
            if move and (dest / META).is_file() and all(
                    not src.exists() or same_bytes(src, dest / dst) for src, dst in ((jsonl, TRACE), (err, STDERR))):
                remove_old(jsonl, err)
            skipped += 1
            continue
        nxt = next((q[0] for s2, q in parsed[i + 1:] if q is not None and q[1] == slug), None)
        # built under another name and renamed when complete: a folder of the final name
        # is always whole (an interrupted import leaves only a .part to start over)
        part = dest.with_name(name + ".part")
        if part.exists():
            shutil.rmtree(part)
        part.mkdir(parents=True)
        for src, dst in ((jsonl, TRACE), (err, STDERR)):
            if src.exists():
                shutil.copyfile(src, part / dst)
                if not same_bytes(src, part / dst):
                    raise OSError(f"the copy of {src} differs from it")
            else:
                (part / dst).write_bytes(b"")
        try:
            ended_epoch = jsonl.stat().st_mtime if jsonl.exists() else err.stat().st_mtime
        except OSError:
            ended_epoch = None
        session, model = first_init(part / TRACE)
        if kind == TRIAGE:
            row, feature, branch = None, None, None
            outcome, phase = ("triaged", "done") if session else (None, None)
        else:
            row = match_runs_row(runs_rows, slug, started, nxt)
            outcome, feature, branch = cell(row, 2), cell(row, 3), cell(row, 4)
            phase = "done" if row is not None else None
        commits = run_commits(root, started, ended_epoch, slug=slug, feature=feature, kind=kind) \
            if (row is not None or kind == TRIAGE) else []
        # the attempts are unknown: system/init repeats at every turn of one process, so the
        # old logs do not show where a process started (measured in planning, research R6)
        record = {"kind": kind, "slug": slug, "session": session, "started_epoch": started, "trace_attempts": []}
        meta = build_meta(record, phase=phase, ended=iso_local(ended_epoch), outcome=outcome, feature=feature,
                          branch=branch, commits=commits, why=None, loop_info=loop_info, harness_version=None,
                          model=model, imported=True)
        meta["counters"] = {"limits": None, "errors": None, "stalls": None, "idles": None, "restarts": None}
        write_json_atomic(part / META, meta)
        os.replace(part, dest)
        append_line(index_path, build_index_line(meta, name))
        indexed.add(name)
        if move:
            remove_old(jsonl, err)
        imported += 1
    if move:
        try:
            logs_dir.rmdir()  # only when nothing else is left in it
        except OSError:
            pass
    return imported, skipped
