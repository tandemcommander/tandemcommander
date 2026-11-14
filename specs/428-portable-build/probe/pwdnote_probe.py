r"""Feature 428 probe (T035): the password note of the portable edition (FR-015a, contracts/ui-identity.md).

Usage (hidden desktop - tools\run_on_hidden_desktop.ps1; a Debug build):
  python pwdnote_probe.py --portable <Debug portable tree exe>

The note is requested through the Debug seam TC_PORTABLE_TEST_PWDNOTE (as a password stored without a
master password requests it - that trigger is in the FTP / SFTP plug-ins' dialogs).

N1 the note appears once the main window is up: a box with "Set Master Password..." (Yes), "Not
   Now" (No) and a check box; "Not Now" closes it; no second note in the same session.
N2 the next start shows it again (the check box was not ticked); ticked + "Not Now" -> the file
   holds "Portable Password Note Shown"=dword:00000001.
N3 the start after that shows no note.
N4 a fresh copy: "Set Master Password..." opens the master-password dialog (cancelled here).
N5 without the seam no note appears (negative control of the seam itself).
"""

import argparse
import ctypes
import datetime
import os
import shutil
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import notrace_probe as P  # noqa: E402
import scenarios_probe as S  # noqa: E402

ROOT = os.path.join(os.environ["TEMP"], "tc428", "pwdnote")
S.ROOT = ROOT
u32 = ctypes.windll.user32
BM_CLICK, BM_GETCHECK = 0x00F5, 0x00F0
ok_all = True


def row(case, ok, facts):
    global ok_all
    ok_all &= P.row(case, ok, facts)


def btn(h, cid):
    for c in P.kids(h):
        if u32.GetDlgCtrlID(c) == cid and P.cls(c) == "Button":
            return c
    return None


def checkbox(h):
    for c in P.kids(h):
        if P.cls(c) == "Button" and (u32.GetWindowLongW(c, -16) & 0xF) in (2, 3):  # BS_CHECKBOX / BS_AUTOCHECKBOX
            return c
    return None


def note_boxes(p):
    return [h for h in P.tops(p.pid) if P.cls(h) == "#32770" and u32.IsWindowVisible(h)
            and btn(h, 6) is not None and btn(h, 7) is not None and checkbox(h) is not None]


def start(exe, seam=True):
    env = dict(os.environ)
    if seam:
        env["TC_PORTABLE_TEST_PWDNOTE"] = "1"
    else:
        env.pop("TC_PORTABLE_TEST_PWDNOTE", None)
    p = subprocess.Popen([exe], env=env)
    t0 = time.time()
    while time.time() - t0 < 60 and P.alive(p) and P.main_win(p.pid) is None:
        time.sleep(0.3)
    return p


def wait_note(p, seconds=15):
    t0 = time.time()
    while time.time() - t0 < seconds:
        b = note_boxes(p)
        if b:
            return b[0]
        time.sleep(0.3)
    return None


def press(h, cid):
    b = btn(h, cid)
    u32.PostMessageW(b, BM_CLICK, 0, 0)
    t0 = time.time()
    while time.time() - t0 < 5 and u32.IsWindow(h) and u32.IsWindowVisible(h):
        time.sleep(0.1)
    return not (u32.IsWindow(h) and u32.IsWindowVisible(h))


def file_value(tc):
    f = S.settings_file(tc)
    if not os.path.isfile(f):
        return None
    for line in S.read_text(f).splitlines():
        if line.startswith('"Portable Password Note Shown"='):
            return line.split("=", 1)[1]
    return None


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--portable", required=True)
    args = ap.parse_args()
    shutil.rmtree(ROOT, ignore_errors=True)
    os.makedirs(ROOT)
    P.out("feature 428 password-note probe, %s" % datetime.datetime.now().isoformat(timespec="seconds"))
    key_before = P.sha_of_key(None, os.path.join(ROOT, "key-before.reg"))
    tc, _ = S.make_copy(args.portable, "a")
    exe = os.path.join(tc, "tandemcommander.exe")

    # N5 first: the seam is what shows it
    p = start(exe, seam=False)
    row("N5 without the seam: no note", wait_note(p, 10) is None, "")
    P.stop(p)

    # N1
    p = start(exe)
    h = wait_note(p)
    text = P.describe(h) if h else ""
    closed = press(h, 7) if h else False
    again = wait_note(p, 8)
    row("N1 the note appears with Set Master Password / Not Now / a check box", h is not None, text[:250])
    row("N1 'Not Now' closes it, no second note in the session", closed and again is None, "closed %s, again %s" % (closed, again))
    P.stop(p)
    row("N1 not ticked: nothing stored", file_value(tc) is None, str(file_value(tc)))

    # N2
    p = start(exe)
    h = wait_note(p)
    cb = checkbox(h) if h else None
    if cb:
        u32.PostMessageW(cb, BM_CLICK, 0, 0)
        time.sleep(0.5)
    ticked = bool(cb) and u32.SendMessageW(cb, BM_GETCHECK, 0, 0) == 1
    closed = press(h, 7) if h else False
    P.stop(p)
    row("N2 shown again; ticked + Not Now -> stored in the settings file",
        h is not None and ticked and closed and file_value(tc) == "dword:00000001", "ticked %s, value %s" % (ticked, file_value(tc)))

    # N3
    p = start(exe)
    row("N3 the next start: no note", wait_note(p, 12) is None, "")
    P.stop(p)

    # N4
    tc2, _ = S.make_copy(args.portable, "b")
    p = start(os.path.join(tc2, "tandemcommander.exe"))
    h = wait_note(p)
    yes = press(h, 6) if h else False
    dlg = None
    t0 = time.time()
    while time.time() - t0 < 10 and dlg is None:
        for w in P.tops(p.pid):
            if P.cls(w) == "#32770" and u32.IsWindowVisible(w) and sum(1 for c in P.kids(w) if P.cls(c) == "Edit") >= 2:
                dlg = w
        time.sleep(0.3)
    desc = P.describe(dlg) if dlg else ""
    if dlg:
        u32.PostMessageW(dlg, 0x0111, 2, 0)  # IDCANCEL
        time.sleep(1)
    P.stop(p)
    row("N4 Set Master Password opens the master-password dialog", h is not None and yes and dlg is not None, desc[:200])

    key_after = P.sha_of_key(None, os.path.join(ROOT, "key-after.reg"))
    row("the installed edition's key is unchanged", key_before == key_after,
        "%s -> %s" % ((key_before or "none")[:16], (key_after or "none")[:16]))
    P.out("RESULT: %s" % ("PASS" if ok_all else "FAIL"))
    res_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
    os.makedirs(res_dir, exist_ok=True)
    with open(os.path.join(res_dir, "pwdnote-%s.txt" % datetime.datetime.now().strftime("%Y%m%d-%H%M%S")), "w", encoding="utf-8") as fo:
        fo.write("\n".join(P.LINES) + "\n")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
