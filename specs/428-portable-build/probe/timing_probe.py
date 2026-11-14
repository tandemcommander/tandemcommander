r"""Feature 428 probe (T062, SC-009): start-up and save-at-exit time, portable vs. installed edition.

Usage (hidden desktop):
  python timing_probe.py --portable <Release portable exe> --normal <Release normal exe> [--runs 7]

Each run: start -> the main window answers WM_NULL (start-up time); then the panels' list is left
alone 3 s, WM_CLOSE -> the process has ended (exit time: the configuration save and, in the
portable edition, writing settings\tandemcommander.reg). The first run of each edition is a warm-up
and not counted. Medians are compared: SC-009 asks for the portable edition within 10 %. The normal
edition's registry key is backed up and restored; the portable copy runs in %TEMP%\tc428\timing.
"""

import argparse
import ctypes
import datetime
import os
import shutil
import statistics
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import notrace_probe as P  # noqa: E402
import scenarios_probe as S  # noqa: E402

ROOT = os.path.join(os.environ["TEMP"], "tc428", "timing")
S.ROOT = ROOT
u32 = ctypes.windll.user32


def one(exe, docs, change=True):
    t0 = time.perf_counter()
    p = subprocess.Popen([exe, "-l", docs, "-r", docs])
    while P.alive(p) and P.main_win(p.pid) is None:
        time.sleep(0.005)
    h = P.main_win(p.pid)
    P.send(h, 0, 0, 0)
    t_start = time.perf_counter() - t0
    if change:  # a real change, so the exit really saves (and the portable edition writes its file)
        u32.PostMessageW(h, P.WM_COMMAND, P.CM_TOGGLEHIDDENFILES, 0)
    time.sleep(3)
    t1 = time.perf_counter()
    u32.PostMessageW(h, 0x0010, 0, 0)  # WM_CLOSE
    try:
        p.wait(60)
    except subprocess.TimeoutExpired:
        p.kill()
        return t_start, None
    return t_start, time.perf_counter() - t1


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--portable", required=True)
    ap.add_argument("--normal", required=True)
    ap.add_argument("--runs", type=int, default=7)
    args = ap.parse_args()
    shutil.rmtree(ROOT, ignore_errors=True)
    os.makedirs(ROOT)
    P.out("feature 428 timing probe, %s" % datetime.datetime.now().isoformat(timespec="seconds"))
    tc, docs = S.make_copy(args.portable, "p")
    port_exe = os.path.join(tc, "tandemcommander.exe")
    backup = os.path.join(ROOT, "key.reg")
    key_before = P.sha_of_key(None, os.path.join(ROOT, "key-before.reg"))
    subprocess.run(["reg.exe", "export", "HKCU\\Software\\Tandem Commander", backup, "/y"], capture_output=True)
    # the same configuration for both: the installed edition's (the maintainer's real one) is imported
    # into the portable copy first (Options > Import Configuration's pending file, applied at a start)
    inst = os.path.join(ROOT, "installed.reg")
    subprocess.run(["reg.exe", "export", "HKCU\\Software\\Tandem Commander\\Settings", inst, "/y"], capture_output=True)
    os.makedirs(os.path.join(tc, "settings"), exist_ok=True)
    shutil.copyfile(inst, os.path.join(tc, "settings", "import.reg"))
    one(port_exe, docs, change=False)
    same = not os.path.exists(os.path.join(tc, "settings", "import.reg"))
    P.out("  the portable copy runs on the installed edition's configuration: %s (%d bytes settings file)"
          % (same, os.path.getsize(S.settings_file(tc)) if os.path.isfile(S.settings_file(tc)) else 0))
    res = {"portable": [], "normal": []}
    try:
        for i in range(args.runs + 1):  # interleaved, the first pair is the warm-up
            for name, exe in (("portable", port_exe), ("normal", args.normal)):
                r = one(exe, docs)
                if i > 0:
                    res[name].append(r)
                P.out("  run %d %-8s start %.3f s, exit %s s" % (i, name, r[0], "%.3f" % r[1] if r[1] is not None else "KILLED"))
    finally:
        subprocess.run(["reg.exe", "delete", "HKCU\\Software\\Tandem Commander", "/f"], capture_output=True)
        subprocess.run(["reg.exe", "import", backup], capture_output=True)
    ok = same
    for k, label in ((0, "start-up"), (1, "exit with save")):
        a = statistics.median(r[k] for r in res["portable"] if r[k] is not None)
        b = statistics.median(r[k] for r in res["normal"] if r[k] is not None)
        within = a <= b * 1.10
        ok &= P.row("SC-009 %s: portable median within 10 %% of the installed edition" % label, within,
                    "portable %.3f s, installed %.3f s (%+.1f %%)" % (a, b, (a / b - 1) * 100))
    # the start's hash stands for the file (no dump at start): a run without a change must not
    # rewrite the file (its time stamp and bytes stay), and the .bak is not rotated
    f = S.settings_file(tc)
    before = (os.stat(f).st_mtime_ns, open(f, "rb").read(), os.stat(f + ".bak").st_mtime_ns if os.path.exists(f + ".bak") else None)
    one(port_exe, docs, change=False)
    one(port_exe, docs, change=False)
    after = (os.stat(f).st_mtime_ns, open(f, "rb").read(), os.stat(f + ".bak").st_mtime_ns if os.path.exists(f + ".bak") else None)
    ok &= P.row("two runs without a change leave the settings file and its .bak untouched", before == after,
                "time stamp same %s, bytes same %s, .bak same %s" % (before[0] == after[0], before[1] == after[1], before[2] == after[2]))
    key_after = P.sha_of_key(None, os.path.join(ROOT, "key-after.reg"))
    ok &= P.row("the installed edition's key restored", key_before == key_after,
                "%s -> %s" % ((key_before or "none")[:16], (key_after or "none")[:16]))
    P.out("RESULT: %s" % ("PASS" if ok else "FAIL"))
    res_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
    os.makedirs(res_dir, exist_ok=True)
    with open(os.path.join(res_dir, "timing-%s.txt" % datetime.datetime.now().strftime("%Y%m%d-%H%M%S")), "w", encoding="utf-8") as fo:
        fo.write("\n".join(P.LINES) + "\n")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
