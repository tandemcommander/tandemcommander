r"""Feature 428 probe: Options > Import Configuration in the portable edition (FR-013).

Usage (hidden desktop - tools\run_on_hidden_desktop.ps1):
  python import_probe.py --portable <portable tree exe>

I1 command: copy SRC runs with its left panel in SRC\docs (its file then says $(PortableDir)\docs)
   and gets "Only One Instance" = 1 written into its file; copy DST runs, Import Configuration is
   driven (the open dialog gets SRC's settings file, Open, "Close now?" -> No): DST\settings\
   import.reg is a byte copy, DST's own file is untouched by the exit save.
I2 next start: DST starts alone -> no error box, import.reg is gone, DST's file has Only One
   Instance = 1 and $(PortableDir)\docs, and no path of SRC anywhere (the token was expanded to
   DST's folder: the window title is "docs - ...").
I3 joined start: DST runs, import.reg is placed, a second DST process starts (it joins the
   session; with Only One Instance it activates the first and ends) -> import.reg is still there;
   after both are closed, the next lone start imports it (gone).
I4 refused file: a .reg with a key outside the configuration -> the command shows the import
   error at once, writes no import.reg and asks no question.
"""

import argparse
import ctypes
import datetime
import os
import shutil
import subprocess
import sys
import time
from ctypes import wintypes

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import notrace_probe as P  # noqa: E402
import scenarios_probe as S  # noqa: E402

u32 = ctypes.WinDLL("user32", use_last_error=True)
ROOT = os.path.join(os.environ["TEMP"], "tc428", "import")
S.ROOT = ROOT
CM_IMPORTCONFIG = 934
WM_COMMAND = 0x0111
WM_SETTEXT = 0x000C
BM_CLICK = 0x00F5
ok_all = True


def row(case, ok, facts):
    global ok_all
    ok_all &= P.row(case, ok, facts)


def dialogs_of(pid):
    return [h for h in P.tops(pid) if P.cls(h) == "#32770" and u32.IsWindowVisible(h)]


def wait_dialog(pid, pred, seconds=20):
    t0 = time.time()
    while time.time() - t0 < seconds:
        for h in dialogs_of(pid):
            if pred(h):
                return h
        time.sleep(0.2)
    return None


def child_by_id(h, cid, klass=None):
    for c in P.kids(h):
        if u32.GetDlgCtrlID(c) == cid and (klass is None or P.cls(c) == klass):
            return c
    return None


def press(h, cid):
    b = child_by_id(h, cid, "Button")
    if b is None:
        return False
    u32.PostMessageW(b, BM_CLICK, 0, 0)
    t0 = time.time()
    while time.time() - t0 < 5 and u32.IsWindow(h) and u32.IsWindowVisible(h):
        time.sleep(0.1)
    return not (u32.IsWindow(h) and u32.IsWindowVisible(h))


def is_open_dialog(h):
    return child_by_id(h, 1148) is not None  # the file name box (cmb13 / edt1) of the common dialog


def drive_import(p, file):
    """Options > Import Configuration with 'file' typed into the open dialog; returns the texts of
    the boxes that followed (the question is answered No, an error box OK)."""
    main = P.main_win(p.pid)
    u32.PostMessageW(main, WM_COMMAND, CM_IMPORTCONFIG, 0)
    dlg = wait_dialog(p.pid, is_open_dialog)
    if dlg is None:
        return None, ["no open dialog: %s" % [P.describe(h) for h in dialogs_of(p.pid)]]
    box = child_by_id(dlg, 1148)
    edit = box if P.cls(box) == "Edit" else next((c for c in P.kids(box) if P.cls(c) == "Edit"), None)
    buf = ctypes.create_unicode_buffer(file)
    P.send(edit, WM_SETTEXT, 0, ctypes.addressof(buf))
    time.sleep(0.3)
    press(dlg, 1)  # Open
    seen = []
    t0 = time.time()
    while time.time() - t0 < 15:
        boxes = [h for h in dialogs_of(p.pid) if not is_open_dialog(h)]
        if not boxes:
            if seen and time.time() - t0 > 3:
                break
            time.sleep(0.2)
            continue
        for h in boxes:
            seen.append(P.describe(h))
            if child_by_id(h, 7, "Button") is not None:  # the question: No
                seen[-1] = "QUESTION " + seen[-1]
                press(h, 7)
            else:
                press(h, 1) or press(h, 2)
        time.sleep(0.5)
    return True, seen


def drive_export(p, file):
    """Options > Export Configuration into 'file': every box is answered (a question Yes, a message
    OK), the save dialog gets the name. Returns the texts of the boxes."""
    u32.PostMessageW(P.main_win(p.pid), WM_COMMAND, 855, 0)  # CM_EXPORTCONFIG
    seen = []
    t0 = time.time()
    while time.time() - t0 < 30:
        if os.path.isfile(file) and not dialogs_of(p.pid) and time.time() - t0 > 3:
            break
        for h in dialogs_of(p.pid):
            # the save dialog builds its controls a moment after it appears - give it that moment
            # before taking it for a message box (the first run pressed Save with the default name)
            t1 = time.time()
            while not is_open_dialog(h) and time.time() - t1 < 2 and                     any(P.cls(c) in ("DirectUIHWND", "ComboBoxEx32", "DUIViewWndClassName") for c in P.kids(h)):
                time.sleep(0.2)
            # the Explorer-style save dialog: its file name box is an Edit with id 1001 inside a ComboBox
            # (measured; the open dialog's is 1148)
            save_edit = next((c for c in P.kids(h) if P.cls(c) == "Edit" and u32.GetDlgCtrlID(c) == 1001), None)                 if any(P.cls(c) == "DUIViewWndClassName" for c in P.kids(h)) else None
            if is_open_dialog(h) or save_edit is not None:
                box = child_by_id(h, 1148)
                edit = save_edit if save_edit is not None else                     (box if P.cls(box) == "Edit" else next((c for c in P.kids(box) if P.cls(c) == "Edit"), None))
                buf = ctypes.create_unicode_buffer(file)
                P.send(edit, WM_SETTEXT, 0, ctypes.addressof(buf))
                time.sleep(0.3)
                press(h, 1)
            else:
                seen.append(P.describe(h))
                if child_by_id(h, 6, "Button") is not None:
                    press(h, 6)  # Yes (save the configuration first / overwrite)
                else:
                    press(h, 1) or press(h, 2)
        time.sleep(0.4)
    return seen


def value(path, name):
    if not os.path.isfile(path):
        return None
    for line in S.read_text(path).splitlines():
        if line.startswith('"%s"=dword:' % name):
            return int(line.split(":", 1)[1], 16)
    return None


def start(exe, args=()):
    p = subprocess.Popen([exe] + list(args))
    t0 = time.time()
    dialogs = []
    while time.time() - t0 < 60 and P.alive(p) and P.main_win(p.pid) is None:
        dialogs += P.serve(p, 2)
    time.sleep(2)
    dialogs += P.serve(p, 6)
    return p, dialogs


def errors(dialogs):
    return [d for d in dialogs if d.startswith("[#32770") and d.strip() != "[#32770 '']"]


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--portable", required=True)
    args = ap.parse_args()
    shutil.rmtree(ROOT, ignore_errors=True)
    os.makedirs(ROOT)
    P.out("feature 428 import probe, %s" % datetime.datetime.now().isoformat(timespec="seconds"))
    key_file = os.path.join(ROOT, "installed-key.reg")
    key_before = P.sha_of_key(None, key_file)

    src, src_docs = S.make_copy(args.portable, "src")
    dst, dst_docs = S.make_copy(args.portable, "dst")
    src_exe = os.path.join(src, "tandemcommander.exe")
    dst_exe = os.path.join(dst, "tandemcommander.exe")
    S.run_and_close(src_exe, ["-l", src_docs, "-r", src_docs])
    src_file = S.settings_file(src)
    S.set_dword(src_file, S.CFG, "Only One Instance", 1)
    src_bytes = open(src_file, "rb").read()
    row("setup: SRC's file names its folder $(PortableDir)\\docs", "$(PortableDir)\\\\docs" in S.read_text(src_file),
        "%d bytes" % len(src_bytes))

    # I1
    p, d0 = start(dst_exe)
    before = open(S.settings_file(dst), "rb").read() if os.path.isfile(S.settings_file(dst)) else b""
    ran, boxes = drive_import(p, src_file)
    pending = os.path.join(dst, "settings", "import.reg")
    row("I1 command: the file is kept as settings\\import.reg (a byte copy)",
        ran and os.path.isfile(pending) and open(pending, "rb").read() == src_bytes, "boxes %s" % boxes)
    row("I1 command: the question was asked (a Yes / No box naming the file)",
        any(b.startswith("QUESTION") and src_file in b.replace("\\\\", "\\") for b in boxes), str(boxes)[:300])
    P.stop(p)
    row("I1 exit: import.reg stays, DST's file has no Only One Instance = 1",
        os.path.isfile(pending) and value(S.settings_file(dst), "Only One Instance") != 1,
        "value %s; file changed by the exit save: %s" % (value(S.settings_file(dst), "Only One Instance"),
                                                         open(S.settings_file(dst), "rb").read() != before))

    # I2
    title, dialogs, p = S.run_and_close(dst_exe)
    t = S.read_text(S.settings_file(dst))
    src_left = [l for l in t.splitlines() if src.lower().replace("\\", "\\\\") in l.lower()]
    row("I2 next start: imported - import.reg gone, Only One Instance = 1, no error box",
        not os.path.exists(pending) and value(S.settings_file(dst), "Only One Instance") == 1 and not errors(dialogs),
        "boxes %s" % (errors(dialogs) or "none"))
    row("I2 next start: $(PortableDir) expanded to DST (title docs, file keeps the token, no SRC path)",
        bool(title) and title.startswith("docs - ") and "$(PortableDir)\\\\docs" in t and not src_left,
        "title %r; SRC paths %s" % (title, src_left[:2] or "none"))

    # I3
    p1, _ = start(dst_exe)
    shutil.copyfile(src_file, pending)
    p2 = subprocess.Popen([dst_exe])
    t0 = time.time()
    while time.time() - t0 < 30 and P.alive(p2):
        P.serve(p2, 2)
    second_ended = not P.alive(p2)
    row("I3 joined start: import.reg stays while another process of the copy runs",
        os.path.isfile(pending), "second process ended (Only One Instance): %s" % second_ended)
    if P.alive(p2):
        P.stop(p2)
    P.stop(p1)
    title, dialogs, p = S.run_and_close(dst_exe)
    row("I3 lone start afterwards: imported (import.reg gone), no error box",
        not os.path.exists(pending) and not errors(dialogs), "boxes %s" % (errors(dialogs) or "none"))

    # I5 portable -> another edition: the exported file names the folders absolutely (a token would
    # mean nothing to an installed copy) and holds the configuration's root key
    exported = os.path.join(ROOT, "exported from portable.reg")
    p, _ = start(dst_exe)
    boxes = drive_export(p, exported)
    P.stop(p)
    et = S.read_text(exported) if os.path.isfile(exported) else ""
    dst_docs_reg = dst_docs.replace("\\", "\\\\").lower()
    row("I5 Export Configuration from the portable copy: absolute paths, no $(PortableDir), our root key",
        bool(et) and "$(PortableDir)" not in et and dst_docs_reg in et.lower()
        and "[HKEY_CURRENT_USER\\Software\\Tandem Commander\\Settings]" in et,
        "%d characters; boxes %s" % (len(et), [b[:60] for b in boxes]))

    # I6 installed -> portable: the installed edition's configuration as its Export Configuration
    # writes it (the Settings key, the same format) imports into the portable copy - a mark set in it arrives in the copy's file
    inst = os.path.join(ROOT, "exported from installed.reg")
    subprocess.run(["reg.exe", "export", "HKCU\\Software\\Tandem Commander\\Settings", inst, "/y"], capture_output=True)
    if os.path.isfile(inst):
        S.set_string(inst, S.CFG, "Title bar prefix text", "INST428")
        shutil.copyfile(inst, pending)
        title, dialogs, p = S.run_and_close(dst_exe)
        row("I6 the installed edition's export imports into the portable copy (its mark arrives)",
            not os.path.exists(pending) and '"Title bar prefix text"="INST428"' in S.read_text(S.settings_file(dst))
            and not errors(dialogs), "boxes %s" % (errors(dialogs) or "none"))
    else:
        row("I6 the installed edition's export imports into the portable copy", False, "no installed configuration to export")

    # I4
    bad = os.path.join(ROOT, "bad.reg")
    open(bad, "wb").write(("﻿Windows Registry Editor Version 5.00\r\n\r\n"
                           "[HKEY_CURRENT_USER\\Software\\Tandem Commander\\Settings\\Configuration]\r\n"
                           "\"Only One Instance\"=dword:00000000\r\n\r\n"
                           "[HKEY_CURRENT_USER\\Software\\Probe428Other]\r\n\"x\"=dword:00000001\r\n\r\n").encode("utf-16-le"))
    p, _ = start(dst_exe)
    ran, boxes = drive_import(p, bad)
    row("I4 refused file: an error box, no question, no import.reg",
        ran and boxes and not any(b.startswith("QUESTION") for b in boxes) and not os.path.exists(pending),
        "boxes %s" % str(boxes)[:300])
    P.stop(p)

    key_after = P.sha_of_key(None, os.path.join(ROOT, "installed-key-after.reg"))
    row("the installed edition's key is unchanged (SHA-256 of its export)", key_before == key_after,
        "%s -> %s" % ((key_before or "none")[:16], (key_after or "none")[:16]))
    P.out("RESULT: %s" % ("PASS" if ok_all else "FAIL"))
    res_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
    os.makedirs(res_dir, exist_ok=True)
    with open(os.path.join(res_dir, "import-%s.txt" % datetime.datetime.now().strftime("%Y%m%d-%H%M%S")), "w", encoding="utf-8") as fo:
        fo.write("\n".join(P.LINES) + "\n")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
