r"""Feature 428 probe (T051): the new-version check of the portable edition (contracts/update-check-portable.md).

Usage (hidden desktop - tools\run_on_hidden_desktop.ps1; a Debug build - the seam
TC_UPDATECHECK_URL exists only there):
  python update_probe.py --portable <Debug portable tree exe>

Uses feature 123's fixture server (specs/123-new-version-check/probe/updserver.py) on 127.0.0.1.
The copy runs in English (Configuration "Language" = english.slg in its settings file).

U1 with-portable (9.9.9 with the installer AND the portable ZIP): Help > Check for New Version shows
   the notification for 9.9.9 with the portable hint ("This is the portable edition..."); no
   "Download & Install", no "Install Now", no level list (visible controls only).
U2 newer (9.9.9 with the installer only): the release is not offered - no window names 9.9.9.
U3 portable-not-uploaded (the ZIP asset still "open"): not offered either.
U4 Configuration > General: "When a new version is found" and its label are hidden.
U5 nothing was downloaded: the server saw only /latest requests; %LOCALAPPDATA%\Tandem Commander\
   Updates has no new file; the installed edition's key is unchanged.
"""

import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import notrace_probe as P  # noqa: E402
import scenarios_probe as S  # noqa: E402
import identity_probe as I  # noqa: E402
import ctypes  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
SERVER = os.path.join(HERE, "..", "..", "123-new-version-check", "probe", "updserver.py")
ROOT = os.path.join(os.environ["TEMP"], "tc428", "update")
S.ROOT = ROOT
PORT = 8428
u32 = ctypes.windll.user32
ok_all = True


def row(case, ok, facts):
    global ok_all
    ok_all &= P.row(case, ok, facts)


def all_text(h):
    """The window's title and the texts of its VISIBLE controls."""
    return P.txt(h) + " | " + " | ".join(P.txt(c) for c in P.kids(h) if P.txt(c) and u32.IsWindowVisible(c))


def start(exe, fixture):
    env = dict(os.environ)
    env["TC_UPDATECHECK_URL"] = "http://127.0.0.1:%d/latest/%s" % (PORT, fixture)
    p = subprocess.Popen([exe], env=env)
    t0 = time.time()
    while time.time() - t0 < 60 and P.alive(p) and P.main_win(p.pid) is None:
        time.sleep(0.3)
    time.sleep(6)  # the check at start-up, if it runs, has time to answer
    return p


def windows(p):
    return [h for h in P.tops(p.pid) if P.cls(h) != P.MAIN_CLASS and u32.IsWindowVisible(h)]


def manual_check(p, shot=None):
    """Help > Check for New Version; the texts of every window that is up 12 s later."""
    for h in windows(p):  # a notification of the start-up check first
        u32.PostMessageW(h, 0x0111, 2, 0)
    time.sleep(1)
    u32.PostMessageW(P.main_win(p.pid), 0x0111, 2217, 0)
    seen = {}
    t0 = time.time()
    while time.time() - t0 < 12:
        for h in windows(p):
            seen[h] = all_text(h)
        time.sleep(0.5)
    for h in windows(p):
        if shot and "9.9.9" in all_text(h):
            I.grab(h, shot)
        u32.PostMessageW(h, 0x0111, 2, 0)  # IDCANCEL
    time.sleep(1)
    return list(seen.values())


def updates_files():
    d = os.path.join(os.environ["LOCALAPPDATA"], "Tandem Commander", "Updates")
    return sorted(os.listdir(d)) if os.path.isdir(d) else []


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--portable", required=True)
    args = ap.parse_args()
    shutil.rmtree(ROOT, ignore_errors=True)
    os.makedirs(ROOT)
    P.out("feature 428 update probe, %s" % datetime.datetime.now().isoformat(timespec="seconds"))
    key_before = P.sha_of_key(None, os.path.join(ROOT, "key-before.reg"))
    upd_before = updates_files()
    log = os.path.join(ROOT, "requests.log")
    srv = subprocess.Popen([sys.executable, SERVER, "--port", str(PORT), "--log", log])
    time.sleep(1.5)
    try:
        tc, docs = S.make_copy(args.portable, "copy")
        exe = os.path.join(tc, "tandemcommander.exe")
        S.run_and_close(exe)
        I.set_string(S.settings_file(tc), S.CFG, "Language", "english.slg")

        for case, fixture, offered in (("U1", "with-portable", True), ("U2", "newer", False),
                                       ("U3", "portable-not-uploaded", False)):
            p = start(exe, fixture)
            texts = manual_check(p, os.path.join(HERE, "..", "evidence", "update_notice_portable.png") if offered else None)
            notice = [t for t in texts if "9.9.9" in t]
            if offered:
                t = notice[0] if notice else ""
                row("%s %s: the notification offers 9.9.9 with the portable hint" % (case, fixture),
                    bool(notice) and "This is the portable edition" in t, "%s" % texts)
                row("%s %s: no Download & Install, no Install Now, no level list" % (case, fixture),
                    bool(notice) and "Download && Install" not in t and "Download & Install" not in t and "Install Now" not in t
                    and "new version is found" not in t, t[:300])
            else:
                # not offered, and the check the user started says so (a box) - no window at all would
                # also mean "not offered", but then the command did nothing visible
                row("%s %s: the release is not offered (no window names 9.9.9); the check reports it could not check" % (case, fixture),
                    not notice and len(texts) >= 1, "%s" % texts)
            if case == "U1":
                # U4 the General page
                u32.PostMessageW(P.main_win(p.pid), 0x0111, 686, 0)  # CM_CONFIGURATION
                dlg = None
                t0 = time.time()
                while time.time() - t0 < 15 and dlg is None:
                    for h in windows(p):
                        if I.child(h, 6298) is not None:
                            dlg = h
                    time.sleep(0.3)
                lvl = I.child(dlg, 6298) if dlg else None
                lab = I.child(dlg, 6297) if dlg else None
                row("U4 General page: the level list and its label are hidden",
                    dlg is not None and lvl is not None and not u32.IsWindowVisible(lvl) and lab is not None and not u32.IsWindowVisible(lab),
                    "dialog %s, list visible %s, label visible %s" % (bool(dlg), lvl and bool(u32.IsWindowVisible(lvl)),
                                                                     lab and bool(u32.IsWindowVisible(lab))))
                if dlg:
                    P.click_ok(dlg)
            P.stop(p)
    finally:
        try:
            import urllib.request
            urllib.request.urlopen("http://127.0.0.1:%d/stop" % PORT, timeout=5)
        except Exception:
            pass
        time.sleep(1)
        if srv.poll() is None:
            srv.kill()
    paths = []
    if os.path.isfile(log):
        for line in open(log, encoding="utf-8"):
            try:
                paths.append(json.loads(line).get("path", "?"))
            except ValueError:
                pass
    row("U5 the server saw only version requests (nothing downloaded)",
        bool(paths) and all(x.startswith(("/latest/", "/end/")) or x == "/stop" for x in paths), "%d requests: %s" % (len(paths), sorted(set(paths))))
    row("U5 no new file in %LOCALAPPDATA%\\Tandem Commander\\Updates", updates_files() == upd_before,
        "%s -> %s" % (upd_before, updates_files()))
    key_after = P.sha_of_key(None, os.path.join(ROOT, "key-after.reg"))
    row("the installed edition's key is unchanged", key_before == key_after,
        "%s -> %s" % ((key_before or "none")[:16], (key_after or "none")[:16]))
    P.out("RESULT: %s" % ("PASS" if ok_all else "FAIL"))
    res_dir = os.path.join(HERE, "results")
    os.makedirs(res_dir, exist_ok=True)
    with open(os.path.join(res_dir, "update-%s.txt" % datetime.datetime.now().strftime("%Y%m%d-%H%M%S")), "w", encoding="utf-8") as fo:
        fo.write("\n".join(P.LINES) + "\n")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
