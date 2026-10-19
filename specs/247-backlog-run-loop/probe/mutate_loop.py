# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Negative controls of tools/backlog/loop.py (feature 247): one mutation per copy of
tools/backlog, then tools/backlog/test_loop.py must fail.
Usage: python specs/247-backlog-run-loop/probe/mutate_loop.py [name ...]
Expected: every mutant CAUGHT."""
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

SRC = Path(__file__).resolve().parents[3] / "tools" / "backlog"
OUT = Path(tempfile.gettempdir()) / "tc247_mutants"

M = {
    "watchdog-off": ('env.setdefault("CLAUDE_CODE_RETRY_WATCHDOG", "1")', 'pass'),
    "resume-starts-a-new-session": ('session = ["--resume", run["session"]]', 'session = ["--session-id", run["session"]]'),
    "finished-while-holding-the-lock": ('if outcome is not None and not mine:\n            return "finished"',
                                        'if outcome is not None:\n            return "finished"'),
    # after the review of 2026-10-19 (its survivors and the fixes of M1, S1, S2, N1, N2, M2, S4)
    "log-offset-ignored": ('lines, _ = read_lines(Path(run["log"]), run.get("offset", 0))', 'lines, _ = read_lines(Path(run["log"]), 0)'),
    "other-items-lock-in-pending": ('        if not mine:\n            hint = ', '        if False:\n            hint = '),
    "holds-any-holder": ('if lock is None or lock.get("slug") != run["slug"]:\n            return False',
                         'if lock is None:\n            return False'),
    "lock-time-unchecked": ('return taken >= began - dt.timedelta(seconds=2)', 'return True'),
    "lock-identity-unchecked": ('return lock.get("started") == run["lock_started"]', 'return True'),
    "refusal-under-own-lock-continued": ('if mine and not info.is_error and info.refused:', 'if False:'),
    "success-counted-as-limit": ('        if not self.is_error:\n            return False\n', ''),
    "context-limit-as-usage": ('|\\bhit your (\\w+ )?limit\\b"', '|\\bhit your (\\w+ )?limit\\b|limit reached"'),
    "limits-unbounded": ('if run["limits"] > MAX_LIMITS:', 'if False:'),
    "stale-stop-kept": ('            unlink(self.repo.stop_flag)\n            self.write_state("starting"',
                        '            self.write_state("starting"'),
    "row-of-any-item": ('if len(r) > 2 and r[1] == self.run["slug"]:', 'if len(r) > 2:'),
    "no-notice-after-a-cut-off": ('        if phase in ("running", "killed", "new"):', '        if False:'),
    # after review round 2
    "refusal-of-a-continuation-dropped": ('return "refused-own", info', 'return "refused", info'),
    "orphan-wait-announced-as-hard": ('detail, safe=True)  # Ctrl+C here ends only the loop', 'detail, safe=False)'),
    "test-clock-passed-to-claude": ('        env.pop("TANDEM_BACKLOG_NOW", None)', '        pass'),
    "error-after-a-waited-limit-is-a-limit": ('if self.result is None and self.rate_limit and', 'if self.rate_limit and'),
    "markdown-refusal-missed": ('r"^[\\s*_`>#-]*Outcome[\\s*_`]*:[\\s*_`]*refused"', 'r"^\\s*Outcome:\\s*refused"'),
    "hard-stop-needs-a-live-child": ('        if child is not None:\n            # also', '        if child is not None and child.poll() is None:\n            # also'),
    "hard-stop-does-not-kill": ('            kill_tree(child.pid)\n', '            pass\n'),
    "precheck-ignores-a-dirty-tree": ('if dirty:', 'if False:'),
    "precheck-ignores-the-lock": ('        if lock is not None:\n            return "waiting"', '        if False:\n            return "waiting"'),
    "blocked-streak-never-resets": ('if outcome == "blocked" else 0', 'if outcome == "blocked" else self.blocked_streak'),
    "limit-treated-as-error": ('            if info.limited:\n                return "limit", info', '            if False:\n                return "limit", info'),
    "reset-time-ignored": ('        return reset + self.limit_margin', '        return time.time() + self.limit_margin'),
    "stop-not-one-shot": ('            unlink(self.repo.loop_file)\n        unlink(self.repo.stop_flag)', '            unlink(self.repo.loop_file)'),
    "pause-ignored": ('            if self.paused():\n                self.wait("paused"', '            if False:\n                self.wait("paused"'),
    "pid-reuse-unchecked": ('return ident is not None and process_ident(pid) == ident', 'return process_ident(pid) is not None'),
    "orphan-not-waited-for": ('        if alive(run.get("child_pid"), run.get("child_ident")):', '        if False:'),
    "errors-unbounded": ('if run["attempts"] > len(self.backoff):', 'if False:'),
    "second-loop-allowed": ('                if alive(other.get("pid"), other.get("ident")):', '                if False:'),
    "refusals-unbounded": ('if self.refusals >= MAX_REFUSALS:', 'if False:'),
    "stalls-unbounded": ('if run["stalls"] > MAX_STALLS:', 'if False:'),
    "lost-session-ignored": ('            if info.lost:\n                return "lost"', '            if False:\n                return "lost"'),
    "idle-starts-claude": ('            if state != "ready":', '            if state not in ("ready", "idle"):'),
    "slug-not-passed": ('prompt = f"/{SKILL} {run[\'slug\']}"', 'prompt = f"/{SKILL}"'),
    "refused-start-touches-the-other-loop": ('            return s.code  # nothing of the other loop is touched',
                                             '            self.unregister()\n            return s.code'),
}


def main():
    names = sys.argv[1:] or list(M)
    survived = []
    for name in names:
        old, new = M[name]
        d = OUT / name
        if d.exists():
            shutil.rmtree(d)
        shutil.copytree(SRC, d, ignore=shutil.ignore_patterns("__pycache__"))
        p = d / "loop.py"
        text = p.read_text(encoding="utf-8")
        if text.count(old) != 1:
            print(f"{name}: PATTERN NOT FOUND ({text.count(old)})", flush=True)
            survived.append(name)
            continue
        p.write_text(text.replace(old, new), encoding="utf-8", newline="\n")
        try:
            res = subprocess.run([sys.executable, "-m", "unittest", "test_loop.py"], cwd=d, capture_output=True,
                                 text=True, timeout=1800)
        except subprocess.TimeoutExpired:
            print(f"{name}: CAUGHT (the tests hung)", flush=True)
            continue
        verdict = "CAUGHT" if res.returncode else "SURVIVED"
        if verdict == "SURVIVED":
            survived.append(name)
        failing = [ln.split(" (")[0] for ln in res.stderr.splitlines() if ln.startswith(("FAIL:", "ERROR:"))]
        print(f"{name}: {verdict} {failing[:3]}", flush=True)
        shutil.rmtree(d, ignore_errors=True)
    print(f"{len(names) - len(survived)} caught, {len(survived)} survived: {survived}", flush=True)


if __name__ == "__main__":
    main()
