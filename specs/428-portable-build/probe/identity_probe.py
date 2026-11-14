r"""Feature 428 probe (T042 / T047): how the portable edition presents itself (contracts/ui-identity.md).

Usage (hidden desktop - tools\run_on_hidden_desktop.ps1):
  python identity_probe.py --portable <portable tree exe> --normal <normal tree exe>

T  title: in each of the 8 enabled languages (Configuration "Language" written into the copy's
   settings file) the main window's title holds "Tandem Commander <ver>... [portable]"; the
   normal edition's title has no "[portable]".
A  About (Help > About, CM_HELP_ABOUT): the label 32601 and the link 32602 exist below the version
   line in every language; the label's translated text (from translations/<lang>/salamand.slt)
   fits its control in the dialog's font; the link fits or is shortened (the tooltip has the whole
   path - not read here); activating the link (a posted click) closes the box and the active
   panel shows settings\ (title "settings - "). The normal
   edition's About has neither control.
I  icon: every image of src/res/salamand_portable.ico is an RT_ICON of the portable exe and the
   images of src/res/salamand.ico that differ from it are not; the normal exe the other way round.
S  screenshots of the About box in the Default and the Dark theme (CM_THEME_DEFAULT / DARK) -
   evidence/about_portable_<theme>.png; High Contrast and the taskbar badge are person checks.
"""

import argparse
import ctypes
import datetime
import os
import re
import shutil
import struct
import subprocess
import sys
import time
from ctypes import wintypes

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import notrace_probe as P  # noqa: E402
import scenarios_probe as S  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
ROOT = os.path.join(os.environ["TEMP"], "tc428", "identity")
S.ROOT = ROOT
EVIDENCE = os.path.join(HERE, "..", "evidence")
LANGS = ["czech", "german", "french", "dutch", "hungarian", "romanian", "slovak", "spanish"]
CM_HELP_ABOUT, CM_THEME_DEFAULT, CM_THEME_DARK = 2216, 2943, 2944
IDC_LABEL, IDC_LINK = 32601, 32602
WM_COMMAND, WM_GETFONT, WM_LBUTTONDOWN, WM_LBUTTONUP = 0x0111, 0x0031, 0x0201, 0x0202
u32 = ctypes.WinDLL("user32", use_last_error=True)
g32 = ctypes.WinDLL("gdi32", use_last_error=True)
k32 = ctypes.WinDLL("kernel32", use_last_error=True)
for f, a, r in ((u32.GetDC, [wintypes.HWND], wintypes.HDC), (u32.ReleaseDC, [wintypes.HWND, wintypes.HDC], ctypes.c_int),
                (g32.SelectObject, [wintypes.HDC, wintypes.HGDIOBJ], wintypes.HGDIOBJ),
                (g32.GetTextExtentPoint32W, [wintypes.HDC, wintypes.LPCWSTR, ctypes.c_int, ctypes.POINTER(wintypes.SIZE)], wintypes.BOOL),
                (u32.SendMessageW, [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM], ctypes.c_ssize_t),
                (u32.GetClientRect, [wintypes.HWND, ctypes.POINTER(wintypes.RECT)], wintypes.BOOL),
                (u32.GetWindowRect, [wintypes.HWND, ctypes.POINTER(wintypes.RECT)], wintypes.BOOL),
                (u32.PrintWindow, [wintypes.HWND, wintypes.HDC, wintypes.UINT], wintypes.BOOL),
                (g32.CreateCompatibleDC, [wintypes.HDC], wintypes.HDC),
                (g32.CreateCompatibleBitmap, [wintypes.HDC, ctypes.c_int, ctypes.c_int], wintypes.HBITMAP),
                (g32.GetBitmapBits, [wintypes.HBITMAP, ctypes.c_long, ctypes.c_void_p], ctypes.c_long),
                (g32.DeleteObject, [wintypes.HGDIOBJ], wintypes.BOOL), (g32.DeleteDC, [wintypes.HDC], wintypes.BOOL)):
    f.argtypes, f.restype = a, r
ok_all = True


def row(case, ok, facts):
    global ok_all
    ok_all &= P.row(case, ok, facts)


def slt_text(lang, sid):
    for line in open(os.path.join(REPO, "translations", lang, "salamand.slt"), encoding="utf-8-sig", errors="replace"):
        if line.startswith("%d," % sid):
            m = re.match(r'\d+,\d+,"(.*)"\s*$', line)
            return m.group(1).replace('""', '"') if m else None
    return None


def set_string(path, key, name, value):
    t = S.read_text(path)
    line = '"%s"="%s"' % (name, value)
    lines = t.split("\r\n")
    head = "[" + key + "]"
    i = lines.index(head) + 1
    j = i
    while j < len(lines) and lines[j] and not lines[j].startswith("["):
        if lines[j].startswith('"%s"=' % name):
            lines[j] = line
            break
        j += 1
    else:
        lines.insert(i, line)
    open(path, "wb").write(("﻿" + "\r\n".join(lines)).encode("utf-16-le"))


def child(h, cid):
    for c in P.kids(h):
        if u32.GetDlgCtrlID(c) == cid:
            return c
    return None


def ink_box(dlg, ctrl):
    """The ink of a control as painted in its dialog (PrintWindow, the probe never selects the
    program's GDI objects - a font handle of another process does not select): (right-most and
    lowest ink pixel relative to the control, its width, its height); None without ink."""
    from PIL import Image
    tmp = os.path.join(ROOT, "ink.png")
    grab(dlg, tmp)
    img = Image.open(tmp).convert("RGB")
    dr, cr = wintypes.RECT(), wintypes.RECT()
    u32.GetWindowRect(dlg, ctypes.byref(dr))
    u32.GetWindowRect(ctrl, ctypes.byref(cr))
    box = img.crop((cr.left - dr.left, cr.top - dr.top, cr.right - dr.left, cr.bottom - dr.top))
    w, h = box.size
    px = box.load()
    from collections import Counter
    bg = Counter(px[x, y] for x in range(w) for y in range(h)).most_common(1)[0][0]
    ink = [(x, y) for x in range(w) for y in range(h) if sum(abs(a - b) for a, b in zip(px[x, y], bg)) > 120]
    if not ink:
        return None
    return max(x for x, _ in ink), max(y for _, y in ink), w, h


def text_fit(ctrl, text):
    """(height the text needs wrapped at the control's width, the control's height, its width)"""
    u32.DrawTextW.argtypes = [wintypes.HDC, wintypes.LPCWSTR, ctypes.c_int, ctypes.POINTER(wintypes.RECT), wintypes.UINT]
    font = u32.SendMessageW(ctrl, WM_GETFONT, 0, 0)
    dc = u32.GetDC(ctrl)
    old = g32.SelectObject(dc, font)
    r = wintypes.RECT()
    u32.GetClientRect(ctrl, ctypes.byref(r))
    t = wintypes.RECT(0, 0, r.right - r.left, 0)
    u32.DrawTextW(dc, text, -1, ctypes.byref(t), 0x400 | 0x10 | 0x800)  # DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX
    g32.SelectObject(dc, old)
    u32.ReleaseDC(ctrl, dc)
    return t.bottom, r.bottom - r.top, r.right - r.left


def open_about(p):
    u32.PostMessageW(P.main_win(p.pid), WM_COMMAND, CM_HELP_ABOUT, 0)
    t0 = time.time()
    while time.time() - t0 < 15:
        for h in P.tops(p.pid):
            if P.cls(h) == "#32770" and u32.IsWindowVisible(h) and P.kids(h):
                return h
        time.sleep(0.2)
    return None


def close_box(h):
    u32.PostMessageW(h, WM_COMMAND, 2, 0)  # IDCANCEL
    t0 = time.time()
    while time.time() - t0 < 5 and u32.IsWindow(h):
        time.sleep(0.1)


def grab(h, path):
    from PIL import Image
    r = wintypes.RECT()
    u32.GetWindowRect(h, ctypes.byref(r))
    w, hh = r.right - r.left, r.bottom - r.top
    sdc = u32.GetDC(None)
    mdc = g32.CreateCompatibleDC(sdc)
    bmp = g32.CreateCompatibleBitmap(sdc, w, hh)
    old = g32.SelectObject(mdc, bmp)
    u32.PrintWindow(h, mdc, 2)  # PW_RENDERFULLCONTENT
    buf = ctypes.create_string_buffer(w * hh * 4)
    g32.GetBitmapBits(bmp, w * hh * 4, buf)
    g32.SelectObject(mdc, old)
    g32.DeleteObject(bmp)
    g32.DeleteDC(mdc)
    u32.ReleaseDC(None, sdc)
    Image.frombuffer("RGBA", (w, hh), buf.raw, "raw", "BGRA", 0, 1).convert("RGB").save(path)
    return w, hh


def ico_images(path):
    data = open(path, "rb").read()
    n = struct.unpack_from("<H", data, 4)[0]
    res = []
    for i in range(n):
        _w, _h, _c, _r, _p, _b, size, off = struct.unpack_from("<BBBBHHII", data, 6 + 16 * i)
        res.append(data[off:off + size])
    return res


def exe_icons(exe):
    k32.LoadLibraryExW.argtypes = [wintypes.LPCWSTR, wintypes.HANDLE, wintypes.DWORD]
    k32.LoadLibraryExW.restype = wintypes.HMODULE
    k32.FindResourceW.argtypes = [wintypes.HMODULE, ctypes.c_void_p, ctypes.c_void_p]
    k32.FindResourceW.restype = wintypes.HANDLE
    k32.LoadResource.argtypes = [wintypes.HMODULE, wintypes.HANDLE]
    k32.LoadResource.restype = wintypes.HGLOBAL
    k32.LockResource.argtypes = [wintypes.HGLOBAL]
    k32.LockResource.restype = ctypes.c_void_p
    k32.SizeofResource.argtypes = [wintypes.HMODULE, wintypes.HANDLE]
    k32.SizeofResource.restype = wintypes.DWORD
    h = k32.LoadLibraryExW(exe, None, 0x2 | 0x20)

    def res(typ, rid):
        r = k32.FindResourceW(h, ctypes.c_void_p(rid), ctypes.c_void_p(typ))
        if not r:
            return None
        return ctypes.string_at(k32.LockResource(k32.LoadResource(h, r)), k32.SizeofResource(h, r))
    grp = res(14, 960)  # RT_GROUP_ICON, IDI_SALAMANDER
    imgs = []
    if grp:
        n = struct.unpack_from("<H", grp, 4)[0]
        for i in range(n):
            rid = struct.unpack_from("<H", grp, 6 + 14 * i + 12)[0]
            imgs.append(res(3, rid))
    return imgs


def start(exe, args=()):
    p = subprocess.Popen([exe] + list(args))
    t0 = time.time()
    while time.time() - t0 < 60 and P.alive(p) and P.main_win(p.pid) is None:
        P.serve(p, 2)
    time.sleep(2)
    P.serve(p, 6)
    return p


def about_checks(p, lang, portable, shots=None):
    box = open_about(p)
    if box is None:
        row("A %s: About opens" % lang, False, "no box")
        return
    lab, link = child(box, IDC_LABEL), child(box, IDC_LINK)
    if not portable:
        row("A normal: About has no portable lines", lab is None and link is None, "label %s, link %s" % (lab, link))
        close_box(box)
        return
    want = slt_text(lang, 13748) if lang != "english" else "Portable edition - settings are kept in this folder:"
    if lab is None or link is None:
        row("A %s: the portable lines exist" % lang, False, "label %s, link %s" % (lab, link))
        close_box(box)
        return
    shown = P.txt(lab)
    ink = ink_box(box, lab)
    # cut text runs to the control's right edge (a clipped glyph) - whole text ends before it
    row("A %s: the label shows the language's text, not cut at its edge" % lang,
        want is not None and shown == want and ink is not None and ink[0] < ink[2] - 2,
        "%r: ink up to x %s of %s, y %s of %s" % (shown, ink and ink[0], ink and ink[2], ink and ink[1], ink and ink[3]))
    if shots:
        for theme, cmd in shots:
            close_box(box)
            u32.PostMessageW(P.main_win(p.pid), WM_COMMAND, cmd, 0)
            time.sleep(2.5)
            box = open_about(p)
            time.sleep(1.0)
            f = os.path.join(EVIDENCE, "about_portable_%s.png" % theme)
            w, h = grab(box, f)
            row("S %s: About screenshot" % theme, os.path.isfile(f), "%s (%d x %d)" % (os.path.relpath(f, REPO), w, h))
        link = child(box, IDC_LINK)
    # activate the link with Enter (CHyperLink hit-tests a click at GetMessagePos, which a posted
    # click does not carry - the keyboard path runs the same ExecuteIt)
    u32.PostMessageW(link, 0x0100, 0x0D, 1)  # WM_KEYDOWN VK_RETURN
    u32.PostMessageW(link, 0x0101, 0x0D, 0xC0000001)
    t0 = time.time()
    while time.time() - t0 < 8 and u32.IsWindow(box):
        time.sleep(0.2)
    time.sleep(1.5)
    title = P.txt(P.main_win(p.pid))
    row("A %s: the link closes the box and the panel shows settings" % lang,
        not u32.IsWindow(box) and title.lower().startswith("settings - "), "title %r" % title)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--portable", required=True)
    ap.add_argument("--normal", required=True)
    args = ap.parse_args()
    shutil.rmtree(ROOT, ignore_errors=True)
    os.makedirs(ROOT)
    os.makedirs(EVIDENCE, exist_ok=True)
    P.out("feature 428 identity probe, %s" % datetime.datetime.now().isoformat(timespec="seconds"))
    key_before = P.sha_of_key(None, os.path.join(ROOT, "key-before.reg"))

    # I icon resources
    port_ico = ico_images(os.path.join(REPO, "src", "res", "salamand_portable.ico"))
    norm_ico = ico_images(os.path.join(REPO, "src", "res", "salamand.ico"))
    pe, ne = exe_icons(args.portable), exe_icons(args.normal)
    row("I portable exe: IDI_SALAMANDER = salamand_portable.ico",
        len(pe) == len(port_ico) and all(i in pe for i in port_ico) and not any(i in pe for i in norm_ico if i not in port_ico),
        "%d images in the exe, %d in the .ico" % (len(pe), len(port_ico)))
    row("I normal exe: IDI_SALAMANDER = salamand.ico (no badge)",
        all(i in ne for i in norm_ico) and not any(i in ne for i in port_ico if i not in norm_ico), "%d images" % len(ne))

    tc, docs = S.make_copy(args.portable, "copy")
    exe = os.path.join(tc, "tandemcommander.exe")
    S.run_and_close(exe, ["-l", docs, "-r", docs])  # creates the settings file
    settings = os.path.join(tc, "settings")
    for i, lang in enumerate(LANGS):
        set_string(S.settings_file(tc), S.CFG, "Language", lang + ".slg")
        p = start(exe, ["-l", docs, "-r", docs])
        title = P.txt(P.main_win(p.pid))
        row("T %s: title says [portable]" % lang, re.search(r"Tandem Commander \d+\.\d+\.\d+( \(x64\))? \[portable\]( \(|$| ST$)", title) is not None,
            "%r" % title)
        shots = [("default", CM_THEME_DEFAULT), ("dark", CM_THEME_DARK)] if i == 0 else             [("de-default", CM_THEME_DEFAULT)] if lang == "german" else None
        about_checks(p, lang, True, shots=shots)
        if i == 0:
            u32.PostMessageW(P.main_win(p.pid), WM_COMMAND, CM_THEME_DEFAULT, 0)
            time.sleep(1.5)
        P.stop(p)
        # the link opened THIS copy's settings folder: the active panel's path is stored as it
        # (the link's own text is painted by the program and not readable from outside)
        t = S.read_text(S.settings_file(tc)) if os.path.isfile(S.settings_file(tc)) else ""
        row("A %s: the panel the link opened is the copy's settings folder" % lang,
            '"Path"="$(PortableDir)\\\\settings"' in t, "stored panel paths: %s"
            % [l for l in t.splitlines() if l.startswith('"Path"=')][:2])
    row("A: the settings folder exists after the runs", os.path.isdir(settings), settings)

    # FR-006a: copy to the clipboard from an archive needs the shell extension, which the portable
    # edition never registers - it says so (the message is shown before any clipboard use)
    import zipfile
    arc = os.path.join(docs, "x.zip")
    with zipfile.ZipFile(arc, "w") as z:
        z.writestr("inner.txt", "inner\n")
    p = start(exe, ["-l", arc, "-r", docs])
    title = P.txt(P.main_win(p.pid))
    known = set(P.tops(p.pid))
    P.key(p.pid, 0x24)  # Home
    P.key(p.pid, 0x28)  # Down -> inner.txt (after "..")
    u32.PostMessageW(P.main_win(p.pid), WM_COMMAND, 773, 0)  # CM_CLIPCOPY (Ctrl+C)
    box = None
    t0 = time.time()
    while time.time() - t0 < 10 and box is None:
        for h in P.tops(p.pid):
            if h not in known and P.cls(h) == "#32770" and u32.IsWindowVisible(h):
                box = h
        time.sleep(0.3)
    text = P.describe(box) if box else ""
    want = (slt_text(LANGS[-1], 13747) or "")[:25]
    row("X FR-006a: Ctrl+C in a ZIP panel says the Explorer integration is not available",
        "x.zip" in title.lower() and box is not None and want and want in text, "title %r; box %s" % (title, text[:200]))
    if box:
        close_box(box)
    P.stop(p)

    # the normal edition: no change (its registry key is backed up and restored by P's helpers)
    backup = os.path.join(ROOT, "normal-key.reg")
    subprocess.run(["reg.exe", "export", "HKCU\\Software\\Tandem Commander", backup, "/y"], capture_output=True)
    try:
        p = start(args.normal, ["-l", docs, "-r", docs])
        title = P.txt(P.main_win(p.pid))
        row("T normal: no [portable] in the title", "[portable]" not in title and "Tandem Commander" in title, "%r" % title)
        about_checks(p, "normal", False)
        P.stop(p)
    finally:
        subprocess.run(["reg.exe", "delete", "HKCU\\Software\\Tandem Commander", "/f"], capture_output=True)
        subprocess.run(["reg.exe", "import", backup], capture_output=True)
    key_after = P.sha_of_key(None, os.path.join(ROOT, "key-after.reg"))
    row("the installed edition's key is as before (restored)", key_before == key_after,
        "%s -> %s" % ((key_before or "none")[:16], (key_after or "none")[:16]))
    P.out("NOT DRIVEN: High Contrast About (a system setting), the badge on a real taskbar in Light / Dark, "
          "the taskbar grouping by executable path (person checks)")
    P.out("RESULT: %s" % ("PASS" if ok_all else "FAIL"))
    res_dir = os.path.join(HERE, "results")
    os.makedirs(res_dir, exist_ok=True)
    with open(os.path.join(res_dir, "identity-%s.txt" % datetime.datetime.now().strftime("%Y%m%d-%H%M%S")), "w", encoding="utf-8") as fo:
        fo.write("\n".join(P.LINES) + "\n")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
