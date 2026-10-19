# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""End-to-end probe of the backlog loop with the REAL claude (feature 247).

A temporary git repository made from tools/backlog/fixtures/valid gets a stand-in
skill `.claude/skills/tandem-backlog-implement/SKILL.md` that does what a run does
to the backlog (lock, item, journal row, commit, release) without implementing
anything, and waits once in the middle.  The real loop (tools/backlog/loop.py of
this tree, --root on the temporary repository) runs it with a cheap model:

  E1  the loop starts claude for the first eligible item (a fresh session)
  E2  while the item runs, status says "HARD STOP now"; Ctrl+Break hard-stops the
      loop: exit 130, the claude process tree is killed, the lock stays
  E3  a new start continues the same session (--resume) and the item finishes:
      a 'closed' journal row, the lock free, the loop ends idle (--until-idle)
  E4  the log holds both segments with one session id; the usage figures were read

Costs a few cents (model haiku).  Windows only (Ctrl+Break).
Usage: python specs/247-backlog-run-loop/probe/e2e_real_claude.py [--model haiku] [--keep]
Prints one PASS / FAIL line per row and a summary; exit 0 when all pass.
"""

import argparse
import json
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time
from pathlib import Path

TREE = Path(__file__).resolve().parents[3]
TOOLS = TREE / "tools" / "backlog"
sys.path.insert(0, str(TOOLS))
import loop  # noqa: E402

FTP = "ftp-per-server-encoding-flag"

SKILL = """---
name: "tandem-backlog-implement"
description: "Stand-in of the backlog run for the feature 247 probe. Takes the item slug as the argument."
user-invocable: true
---

## User Input

```text
$ARGUMENTS
```

You are a stand-in for an implementation run in a test repository. The argument is
an item SLUG. Do exactly these steps with the Bash tool, one command per call, from
the repository root, and nothing else. Do not read or change any other file.

1. `python tools/backlog/backlog.py lock acquire --slug SLUG` (if it prints that the
   lock is already held by SLUG, this is a continued run: go on with step 2).
2. `python tools/e2e_work.py` - it takes a while the first time; wait for it.
3. `python tools/backlog/backlog.py remove SLUG --reason 'e2e probe'` (if it says
   there is no such item, it was already done: go on).
4. `python tools/backlog/backlog.py run-log --outcome closed --slug SLUG --note 'e2e probe'`
5. `git add -A` and then `git commit -q -m 'e2e: SLUG closed'`
6. `python tools/backlog/backlog.py lock release --slug SLUG`

Then reply with exactly two lines:
Outcome: closed
Item: SLUG
"""

WORK = """import time
from pathlib import Path
marker = Path(".git") / "e2e-worked"
if not marker.exists():
    marker.write_text("x")
    Path(".git", "e2e-working").write_text("x")
    time.sleep(120)
print("work done")
"""


def git(root, *args):
    return subprocess.run(["git", "-C", str(root), *args], check=True, capture_output=True, text=True).stdout


def make_repo(base: Path) -> Path:
    root = base / "repo"
    shutil.copytree(TOOLS / "fixtures" / "valid", root)
    (root / "specs" / "243-example").mkdir(parents=True)
    (root / "specs" / "243-example" / "README.md").write_text("fixture\n", encoding="utf-8")
    (root / "tools" / "backlog").mkdir(parents=True)
    shutil.copy2(TOOLS / "backlog.py", root / "tools" / "backlog" / "backlog.py")
    (root / "tools" / "e2e_work.py").write_text(WORK, encoding="utf-8")
    skill = root / ".claude" / "skills" / "tandem-backlog-implement"
    skill.mkdir(parents=True)
    (skill / "SKILL.md").write_text(SKILL, encoding="utf-8", newline="\n")
    (root / ".gitignore").write_text("__pycache__/\n", encoding="utf-8")
    git(root, "init", "-q", "-b", "main")
    git(root, "config", "user.email", "e2e@example.invalid")
    git(root, "config", "user.name", "e2e")
    git(root, "add", "-A")
    git(root, "commit", "-q", "-m", "e2e fixture")
    return root


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", default="haiku")
    ap.add_argument("--keep", action="store_true")
    a = ap.parse_args()
    if os.name != "nt":
        print("Windows only")
        return 2
    base = Path(tempfile.mkdtemp(prefix="tc247-e2e-"))
    root = make_repo(base)
    repo = loop.Repo(root)
    rows0 = len(repo.runs())
    results = []

    def row(name, ok, detail=""):
        results.append(ok)
        print(f"{'PASS' if ok else 'FAIL'} {name} {detail}", flush=True)

    def start(label):
        out = open(base / f"loop-{label}.out", "wb")
        p = subprocess.Popen([sys.executable, "-u", str(TOOLS / "loop.py"), "start", "--root", str(root),
                              "--model", a.model, "--until-idle", "--poll", "2"],
                             stdout=out, stderr=subprocess.STDOUT,
                             creationflags=subprocess.CREATE_NEW_PROCESS_GROUP)
        out.close()
        return p

    def status():
        return subprocess.run([sys.executable, str(TOOLS / "loop.py"), "status", "--root", str(root)],
                              capture_output=True, text=True, encoding="utf-8").stdout

    print(f"repository: {root}", flush=True)
    p = start("1")
    working = root / ".git" / "e2e-working"
    end = time.time() + 300
    while time.time() < end and not working.exists() and p.poll() is None:
        time.sleep(1)
    run = loop.load_json(repo.run_file) or {}
    row("E1 fresh session for the first eligible item", working.exists() and run.get("slug") == FTP
        and run.get("resumes") == 0, f"(slug {run.get('slug')}, session {run.get('session')})")
    st = status()
    row("E2a status while the item runs says HARD STOP", "HARD STOP now" in st, "")
    child_pid, child_ident = run.get("child_pid"), run.get("child_ident")
    os.kill(p.pid, signal.CTRL_BREAK_EVENT)
    try:
        code = p.wait(timeout=60)
    except subprocess.TimeoutExpired:
        code = None
    out1 = (base / "loop-1.out").read_text(encoding="utf-8", errors="replace")
    time.sleep(2)
    run = loop.load_json(repo.run_file) or {}
    lock = repo.lock() or {}
    row("E2b Ctrl+Break: exit 130, claude killed, lock kept, run record 'killed'",
        code == 130 and not loop.alive(child_pid, child_ident) and lock.get("slug") == FTP and run.get("phase") == "killed",
        f"(exit {code}, claude alive {loop.alive(child_pid, child_ident)}, lock {lock.get('slug')}, phase {run.get('phase')})")
    session = run.get("session")

    p = start("2")
    try:
        code = p.wait(timeout=600)
    except subprocess.TimeoutExpired:
        loop.kill_tree(p.pid)
        code = None
    out2 = (base / "loop-2.out").read_text(encoding="utf-8", errors="replace")
    rows = repo.runs()
    row("E3 the next start continued the same session and closed the item",
        code == 0 and len(rows) == rows0 + 1 and rows[-1][1] == FTP and rows[-1][2] == "closed"
        and repo.lock() is None and not repo.run_file.exists() and "continuing item" in out2,
        f"(exit {code}, last row {rows[-1][:3] if rows else None}, lock {repo.lock_text()})")
    logs = sorted(repo.logs.glob("*.jsonl"))
    sessions, usage = set(), False
    if logs:
        for line in logs[-1].read_text(encoding="utf-8", errors="replace").splitlines():
            try:
                obj = json.loads(line)
            except ValueError:
                continue
            if obj.get("session_id"):
                sessions.add(obj["session_id"])
            usage = usage or obj.get("type") == "rate_limit_event"
    row("E4 one log, one session id in both segments, usage figures seen",
        len(logs) == 1 and sessions == {session} and usage, f"(logs {len(logs)}, sessions {sessions}, usage {usage})")
    print("--- loop 1 ---\n" + out1 + "--- loop 2 ---\n" + out2, flush=True)
    ok = all(results)
    print(f"{sum(results)}/{len(results)} PASS", flush=True)
    if not a.keep and ok:
        shutil.rmtree(base, ignore_errors=True)
    else:
        print(f"kept: {base}")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
