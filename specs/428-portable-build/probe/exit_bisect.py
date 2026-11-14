r"""Feature 428 diagnostics: which step of the no-trace scenario keeps the program from closing.

Usage (hidden desktop): python exit_bisect.py <tandemcommander.exe> <docs folder>
Runs: start -> one step -> WM_CLOSE, for each step alone, and reports whether the process ended
within 30 s. Uses the probe's own helpers (notrace_probe.py).
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import notrace_probe as P  # noqa: E402

exe, docs = sys.argv[1], sys.argv[2]


def step_none(p):
    pass


def step_toggle(p):
    P.u32.PostMessageW(P.main_win(p.pid), P.WM_COMMAND, P.CM_TOGGLEHIDDENFILES, 0)
    time.sleep(1)


def step_saveconfig(p):
    P.u32.PostMessageW(P.main_win(p.pid), P.WM_COMMAND, P.CM_SAVECONFIG, 0)
    print("   save dialogs:", P.serve(p, 15), flush=True)


def step_config(p):
    known = set(P.tops(p.pid))
    P.u32.PostMessageW(P.main_win(p.pid), P.WM_COMMAND, P.CM_CONFIGURATION, 0)
    cfg = None
    t0 = time.time()
    while time.time() - t0 < 15 and cfg is None:
        for h in P.tops(p.pid):
            if h not in known and P.cls(h) == "#32770":
                cfg = h
        time.sleep(0.2)
    time.sleep(1.5)
    if cfg:
        print("   OK closed it:", P.click_ok(cfg), flush=True)
    print("   config:", P.txt(cfg) if cfg else None, P.serve(p, 10), flush=True)


for name, step in (("none", step_none), ("toggle", step_toggle), ("saveconfig", step_saveconfig), ("config", step_config)):
    p, dialogs = P.start(exe, docs)
    step(p)
    time.sleep(2)
    h = P.main_win(p.pid)
    P.u32.PostMessageW(h, P.WM_CLOSE, 0, 0)
    t0 = time.time()
    while time.time() - t0 < 30 and P.alive(p):
        P.serve(p, 2)
        time.sleep(0.2)
    ended = not P.alive(p)
    print("%-11s exit after WM_CLOSE: %s (%.1f s)" % (name, "yes" if ended else "NO", time.time() - t0), flush=True)
    if not ended:
        for w in P.all_windows(p.pid):
            if "(hidden)" not in w:
                print("   visible: " + w, flush=True)
        p.kill()
        time.sleep(1)
