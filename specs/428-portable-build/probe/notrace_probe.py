r"""Feature 428 probe (T015 / T030, SC-002, US1): a portable session leaves no trace.

Usage (on the hidden desktop - tools\run_on_hidden_desktop.ps1):
  python notrace_probe.py --exe <tree>\tandemcommander.exe --label portable
  python notrace_probe.py --exe <normal tree>\tandemcommander.exe --label normal   (negative control)

What it does:
 1. copies the program tree (without intermediates, PDBs) to %TEMP%\tc428\notrace\<label>\TC - the
    "unpacked" folder - and makes a small document folder (a .cpp, a .md, a .txt);
 2. backs up HKCU\Software\Tandem Commander (reg export) and keeps its SHA-256;
 3. takes two snapshots of HKCU (every key: last-write time, value and subkey count) and of the
    profile places the program could use (%APPDATA% / %LOCALAPPDATA% top level, their Tandem
    Commander folders in full, the jump-list folder) 20 s apart without the program - what changes
    then is Windows' and other programs' noise;
 4. starts the copy (left / right panel in the document folder), answers its start-up dialogs,
    toggles "hide hidden files" (a setting it must keep), opens Configuration and presses OK, opens
    the .cpp and the .md with F3 (the WebView2 viewers), saves the configuration, closes;
 5. takes the third snapshot: every change after the noise snapshot that is not noise is listed;
 6. starts the copy again and closes it: the setting came back from settings\tandemcommander.reg;
 7. restores the backup of the configuration key and verifies its hash.

Verdicts (portable): no registry key changed under HKCU\Software\Tandem Commander or anywhere the
noise does not explain; no profile change; the session folder existed during the run (WebView2
inside it) and is gone after each exit; the settings file exists and holds the toggled value; the
second start shows it. For the normal edition the same rows are expected to FAIL (negative control).
"""

import argparse
import ctypes
import datetime
import hashlib
import os
import shutil
import subprocess
import sys
import time
import winreg
from ctypes import wintypes

u32 = ctypes.WinDLL("user32", use_last_error=True)
EnumProc = ctypes.WINFUNCTYPE(wintypes.BOOL, wintypes.HWND, wintypes.LPARAM)
u32.EnumWindows.argtypes = [EnumProc, wintypes.LPARAM]
u32.EnumChildWindows.argtypes = [wintypes.HWND, EnumProc, wintypes.LPARAM]
u32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
u32.GetClassNameW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
u32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
u32.IsWindowVisible.argtypes = [wintypes.HWND]
u32.IsWindow.argtypes = [wintypes.HWND]
u32.GetDlgCtrlID.argtypes = [wintypes.HWND]
u32.PostMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
u32.SendMessageTimeoutW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM, wintypes.UINT,
                                    wintypes.UINT, ctypes.POINTER(ctypes.c_size_t)]

WM_COMMAND, WM_CLOSE, WM_KEYDOWN, WM_KEYUP = 0x0111, 0x0010, 0x0100, 0x0101
CM_CONFIGURATION, CM_SAVECONFIG, CM_TOGGLEHIDDENFILES = 686, 687, 853
MAIN_CLASS = "TandemCommanderMainWindowVer01"
LIST_CLASS = "SalamanderItemsBox"
KEY = r"Software\Tandem Commander"
HIDE_VALUE = "Hide Hidden and System Files and Directories"
FATAL = ("Run-Time Check", "Debug Error", "Assertion", "Runtime Library", "Stack around", "problem has occurred",
         "Unhandled exception", "handles remained")

LINES = []


def out(s):
    print(s, flush=True)
    LINES.append(s)


def row(case, ok, facts):
    out("%-6s %-44s %s" % ("PASS" if ok else "FAIL", case, facts))
    return ok


# ---------------------------------------------------------------- windows
def cls(h):
    b = ctypes.create_unicode_buffer(256)
    u32.GetClassNameW(h, b, 256)
    return b.value


def txt(h):
    b = ctypes.create_unicode_buffer(4096)
    u32.GetWindowTextW(h, b, 4096)
    return b.value


def tops(pid):
    res = []

    def cb(h, l):
        p = wintypes.DWORD()
        u32.GetWindowThreadProcessId(h, ctypes.byref(p))
        if p.value == pid and u32.IsWindowVisible(h) and cls(h) not in ("UAC_InputIndicatorOverlayWnd", "UAC Input Indicator"):
            res.append(h)
        return True
    u32.EnumWindows(EnumProc(cb), 0)
    return res


def kids(h):
    res = []

    def cb(c, l):
        res.append(c)
        return True
    u32.EnumChildWindows(h, EnumProc(cb), 0)
    return res


def click_ok(dlg):
    """OK of a dialog the way a user presses it (BM_CLICK on the button with id IDOK); a posted
    WM_COMMAND IDOK leaves a property sheet's modal loop running (measured: the program then
    refuses to close, in both editions)."""
    # the Configuration dialog's OK button has id 5 (probe 123's Cfg-Close); a direct child of the dialog
    u32.GetParent.argtypes = [wintypes.HWND]
    u32.GetParent.restype = wintypes.HWND
    btn = None
    for c in kids(dlg):
        if cls(c) == "Button" and u32.IsWindowVisible(c) and u32.GetParent(c) == dlg and \
                (txt(c).replace("&", "") == "OK" or u32.GetDlgCtrlID(c) in (1, 5)):
            btn = c
            break
    if btn is None:
        return False
    cid = u32.GetDlgCtrlID(btn)
    u32.PostMessageW(btn, 0x00F5, 0, 0)  # BM_CLICK
    t0 = time.time()
    while time.time() - t0 < 4 and u32.IsWindow(dlg):
        time.sleep(0.1)
    if u32.IsWindow(dlg):
        u32.PostMessageW(dlg, WM_COMMAND, cid, 0)
        t0 = time.time()
        while time.time() - t0 < 4 and u32.IsWindow(dlg):
            time.sleep(0.1)
    return not u32.IsWindow(dlg)


def main_win(pid):
    for h in tops(pid):
        if cls(h) == MAIN_CLASS:
            return h
    return None


def describe(h):
    texts = [txt(c) for c in kids(h) if txt(c)]
    return "[%s '%s'] %s" % (cls(h), txt(h), " | ".join(texts)[:300])


def send(h, msg, w, l, timeout=30000):
    r = ctypes.c_size_t()
    return u32.SendMessageTimeoutW(h, msg, w, l, 0, timeout, ctypes.byref(r)) != 0


def alive(proc):
    return proc.poll() is None


def serve(proc, seconds=20, answer=True):
    """Answers dialogs (OK / Yes / the default button) until the program is idle; returns their texts."""
    seen = []
    idle = None
    t0 = time.time()
    while time.time() - t0 < seconds and alive(proc):
        wins = [h for h in tops(proc.pid) if cls(h) != MAIN_CLASS]
        if not wins:
            if idle is None:
                idle = time.time()
            if time.time() - idle > 1.5:
                break
            time.sleep(0.1)
            continue
        idle = None
        for h in wins:
            d = describe(h)
            if d not in seen:
                seen.append(d)
            if cls(h) == "#32770" and answer:
                u32.PostMessageW(h, WM_COMMAND, 1, 0)  # IDOK
                time.sleep(0.3)
                if u32.IsWindow(h) and u32.IsWindowVisible(h):
                    u32.PostMessageW(h, WM_COMMAND, 6, 0)  # IDYES
        time.sleep(0.4)
    return seen


def fatal_in(texts):
    return [t for t in texts if any(f in t for f in FATAL)]


def start(exe, docs):
    p = subprocess.Popen([exe, "-l", docs, "-r", docs])
    t0 = time.time()
    dialogs = []
    while time.time() - t0 < 90 and alive(p) and main_win(p.pid) is None:
        dialogs += serve(p, 3)
        time.sleep(0.2)
    if main_win(p.pid) is None:
        raise RuntimeError("the program did not show its main window; dialogs: %s" % dialogs)
    send(main_win(p.pid), 0, 0, 0)
    time.sleep(2)
    dialogs += serve(p, 15)
    return p, dialogs


def all_windows(pid):
    """Every top-level window of the process, visible or not (diagnostics)."""
    res = []

    def cb(h, l):
        p = wintypes.DWORD()
        u32.GetWindowThreadProcessId(h, ctypes.byref(p))
        if p.value == pid:
            res.append("%s%s" % ("" if u32.IsWindowVisible(h) else "(hidden) ", describe(h)))
        return True
    u32.EnumWindows(EnumProc(cb), 0)
    return res


def stop(p, seconds=40):
    h = main_win(p.pid)
    if h:
        u32.PostMessageW(h, WM_CLOSE, 0, 0)
    t0 = time.time()
    dialogs = []
    while time.time() - t0 < seconds and alive(p):
        dialogs += serve(p, 2)
        time.sleep(0.2)
    if alive(p):
        for w in all_windows(p.pid):
            out("    at the timeout: " + w)
        p.kill()
        dialogs.append("KILLED after %d s" % seconds)
    return dialogs


def key(pid, vk):
    lists = [c for c in kids(main_win(pid)) if cls(c) == LIST_CLASS and u32.IsWindowVisible(c)]
    if not lists:
        raise RuntimeError("panel list not found")
    send(lists[0], WM_KEYDOWN, vk, 1)
    send(lists[0], WM_KEYUP, vk, 0xC0000001)


# ---------------------------------------------------------------- snapshots
def reg_snapshot():
    snap = {}

    def walk(h, path):
        try:
            nsub, nval, lw = winreg.QueryInfoKey(h)
        except OSError:
            return
        snap[path] = (lw, nval, nsub)
        for i in range(nsub):
            try:
                name = winreg.EnumKey(h, i)
                s = winreg.OpenKey(h, name)
            except OSError:
                continue
            walk(s, path + "\\" + name)
            s.Close()
    walk(winreg.HKEY_CURRENT_USER, "HKCU")
    return snap


# what Windows itself records about any program it runs (FR-007: outside the requirement) - keys
# whose values may name the program's path without the program writing them
WINDOWS_RECORDERS = ("\\explorer\\userassist", "\\shell\\muicache", "\\appcompatflags",
                     "\\explorer\\featureusage", "\\restartmanager", "\\windows\\shell\\bags",
                     "\\shell\\bagmru", "\\explorer\\comdlg32")
# places where a program's write would be a real trace however it is named
SENSITIVE = ("hkcu\\software\\classes\\clsid", "hkcu\\software\\classes\\*", "hkcu\\software\\classes\\directory",
             "hkcu\\software\\classes\\drive", "hkcu\\software\\classes\\folder",
             "hkcu\\software\\microsoft\\windows\\currentversion\\run",
             "hkcu\\software\\microsoft\\windows\\currentversion\\uninstall",
             "hkcu\\software\\microsoft\\windows\\currentversion\\app paths", "hkcu\\control panel",
             "hkcu\\environment")


def values_naming(path, needles):
    """Values of one HKCU key (path 'HKCU\\...') whose name or data holds one of 'needles'
    (lower-case; strings, and UTF-16 / ANSI bytes of binary data)."""
    hits = []
    try:
        k = winreg.OpenKey(winreg.HKEY_CURRENT_USER, path[5:])
    except OSError:
        return hits
    i = 0
    while True:
        try:
            name, data, typ = winreg.EnumValue(k, i)
        except OSError:
            break
        i += 1
        if isinstance(data, bytes):
            texts = [data.decode("utf-16-le", "ignore"), data.decode("latin-1", "ignore")]
        elif isinstance(data, list):
            texts = [" ".join(data)]
        else:
            texts = [str(data)]
        texts.append(name)
        if any(n in t.lower() for t in texts for n in needles):
            hits.append("%s :: %s" % (path, name))
    k.Close()
    return hits


def file_state(root, full):
    res = {}
    if not os.path.isdir(root):
        return res
    if not full:
        for e in os.scandir(root):
            try:
                st = e.stat(follow_symlinks=False)
            except OSError:
                continue
            res[e.path] = (st.st_mtime_ns, st.st_size if e.is_file(follow_symlinks=False) else -1)
        return res
    for dp, dn, fn in os.walk(root):
        for n in dn + fn:
            p = os.path.join(dp, n)
            try:
                st = os.stat(p, follow_symlinks=False)
            except OSError:
                continue
            res[p] = (st.st_mtime_ns, st.st_size)
    return res


def files_snapshot():
    a, l = os.environ["APPDATA"], os.environ["LOCALAPPDATA"]
    snap = {}
    snap.update(file_state(a, False))
    snap.update(file_state(l, False))
    snap.update(file_state(os.path.join(a, "Tandem Commander"), True))
    snap.update(file_state(os.path.join(l, "Tandem Commander"), True))
    snap.update(file_state(os.path.join(a, r"Microsoft\Windows\Recent\CustomDestinations"), True))
    return snap


def diff(a, b):
    ch = set()
    for k in set(a) | set(b):
        if a.get(k) != b.get(k):
            ch.add(k)
    return ch


def sha_of_key(path, file):
    if os.path.exists(file):
        os.remove(file)
    r = subprocess.run(["reg.exe", "export", "HKCU\\" + KEY, file, "/y"], capture_output=True)
    if r.returncode != 0:
        return None
    return hashlib.sha256(open(file, "rb").read()).hexdigest()


def session_dirs():
    t = os.environ["TEMP"]
    return sorted(e.name for e in os.scandir(t) if e.is_dir() and e.name.startswith("TandemCommander-portable-"))


def settings_value(settings_file):
    if not os.path.isfile(settings_file):
        return None
    text = open(settings_file, "rb").read().decode("utf-16")
    for line in text.splitlines():
        if line.startswith('"%s"=dword:' % HIDE_VALUE):
            return int(line.split(":", 1)[1], 16)
    return None


# ---------------------------------------------------------------- main
def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--exe", required=True)
    ap.add_argument("--label", default="portable")
    ap.add_argument("--noise-seconds", type=int, default=20)
    ap.add_argument("--skip-viewers", action="store_true", help="diagnostics: no F3")
    args = ap.parse_args()
    portable = args.label == "portable"

    root = os.path.join(os.environ["TEMP"], "tc428", "notrace", args.label)
    tc = os.path.join(root, "TC")
    docs = os.path.join(root, "docs")
    shutil.rmtree(root, ignore_errors=True)
    shutil.copytree(os.path.dirname(os.path.abspath(args.exe)), tc,
                    ignore=shutil.ignore_patterns("Intermediate", "saltests", "*.pdb", "*.ilk", "*.lib", "*.exp", "settings"))
    os.makedirs(docs)
    open(os.path.join(docs, "a_sample.cpp"), "w").write("int main()\n{\n    return 0;\n}\n")
    open(os.path.join(docs, "b_readme.md"), "w").write("# Probe 428\n\nA *Markdown* file.\n")
    open(os.path.join(docs, "c_plain.txt"), "w").write("plain\n")
    exe = os.path.join(tc, "tandemcommander.exe")
    settings_file = os.path.join(tc, "settings", "tandemcommander.reg")
    out("feature 428 no-trace probe, %s edition, %s" % (args.label, datetime.datetime.now().isoformat(timespec="seconds")))
    out("copy: " + tc)

    backup = os.path.join(root, "key_backup.reg")
    key_existed = subprocess.run(["reg.exe", "query", "HKCU\\" + KEY], capture_output=True).returncode == 0
    if key_existed:
        subprocess.run(["reg.exe", "export", "HKCU\\" + KEY, backup, "/y"], capture_output=True, check=True)
    key_sha_before = sha_of_key(KEY, os.path.join(root, "key_before.reg")) if key_existed else None
    out("configuration key of the installed edition: %s, SHA-256 %s" % ("present" if key_existed else "absent", key_sha_before))

    ok_all = True
    # US1-4 / the reverse of SC-007: a sentinel in the installed edition's configuration - a title
    # bar prefix - that the portable copy must never show (it reads nothing of the installed key);
    # the normal edition (negative control) shows it
    SENTINEL = "SENTINEL428"
    cfg_path = KEY + r"\Settings\Configuration"
    try:
        ck = winreg.CreateKey(winreg.HKEY_CURRENT_USER, cfg_path)
        winreg.SetValueEx(ck, "Title bar prefix", 0, winreg.REG_DWORD, 1)
        winreg.SetValueEx(ck, "Title bar prefix text", 0, winreg.REG_SZ, SENTINEL)
        ck.Close()
    except OSError as e:
        out("could not write the sentinel: %s" % e)
    key_sha_before_run = sha_of_key(KEY, os.path.join(root, "key_sentinel.reg"))
    try:
        sessions_before = session_dirs()
        reg_a, files_a = reg_snapshot(), files_snapshot()
        time.sleep(args.noise_seconds)
        reg_b, files_b = reg_snapshot(), files_snapshot()
        noise_reg, noise_files = diff(reg_a, reg_b), diff(files_a, files_b)
        out("noise in %d s without the program: %d registry keys, %d profile entries" % (args.noise_seconds, len(noise_reg), len(noise_files)))

        # ---- session 1
        p, dialogs = start(exe, docs)
        out("start dialogs: %s" % (dialogs or "none"))
        title1 = txt(main_win(p.pid))
        ok_all &= row("the installed edition's settings are not read (no sentinel prefix in the title)", SENTINEL not in title1,
                      repr(title1))
        new_sessions = [s for s in session_dirs() if s not in sessions_before]
        if portable:
            ok_all &= row("session folder created in %TEMP%", len(new_sessions) == 1, str(new_sessions))
        u32.PostMessageW(main_win(p.pid), WM_COMMAND, CM_TOGGLEHIDDENFILES, 0)
        time.sleep(1)
        known = set(tops(p.pid))
        u32.PostMessageW(main_win(p.pid), WM_COMMAND, CM_CONFIGURATION, 0)
        cfg = None
        t0 = time.time()
        while time.time() - t0 < 15 and cfg is None:
            for h in tops(p.pid):
                if h not in known and cls(h) == "#32770":
                    cfg = h
            time.sleep(0.2)
        cfg_title = txt(cfg) if cfg else None
        closed = False
        if cfg:
            time.sleep(1.5)
            closed = click_ok(cfg)
        dialogs = serve(p, 10)
        ok_all &= row("Configuration opened and closed with OK", cfg is not None and closed, "%s; %s" % (cfg_title, dialogs or "no other window"))
        # the viewers: Home, Down -> a_sample.cpp, F3; then b_readme.md
        viewer_titles = []
        webview_seen = False
        for down in (() if args.skip_viewers else (1, 1)):
            key(p.pid, 0x24 if not viewer_titles else 0x28)  # Home first, then Down
            if not viewer_titles:
                for _ in range(down):
                    key(p.pid, 0x28)
            known = set(tops(p.pid))
            u32.PostMessageW(main_win(p.pid), WM_COMMAND, 742, 0)  # CM_VIEW (F3) on the focused item
            v = None
            t0 = time.time()
            while time.time() - t0 < 20:
                for h in tops(p.pid):
                    if h not in known and cls(h) != "#32770":
                        v = h
                if v:
                    break
                time.sleep(0.3)
            time.sleep(6)  # the web viewer creates its environment
            if v is None:
                for w in all_windows(p.pid):
                    out("    after F3, no new window; windows: " + w)
            for s in session_dirs():
                if os.path.isdir(os.path.join(os.environ["TEMP"], s, "WebView2")):
                    webview_seen = True
            viewer_titles.append((cls(v), txt(v)) if v else None)
            if v:
                u32.PostMessageW(v, WM_CLOSE, 0, 0)
                time.sleep(2)
            serve(p, 5)
        out("viewers: %s" % viewer_titles)
        if portable:
            ok_all &= row("WebView2 data in the session folder", webview_seen, "a session folder had WebView2 while a viewer was open")
        u32.PostMessageW(main_win(p.pid), WM_COMMAND, CM_SAVECONFIG, 0)
        dialogs = serve(p, 15)
        time.sleep(3)
        fat = fatal_in(dialogs)
        dialogs += stop(p)
        ok_all &= row("session 1 ended normally", not fatal_in(dialogs) and p.returncode is not None, str(dialogs or "no window"))
        time.sleep(3)
        after1 = [s for s in session_dirs() if s not in sessions_before]
        if portable:
            ok_all &= row("session folder removed at exit", not after1, str(after1))
        v1 = settings_value(settings_file)
        if portable:
            ok_all &= row("settings file written with the toggled value (1; the default is 0)", v1 == 1, "%s = %s" % (settings_file, v1))

        reg_c, files_c = reg_snapshot(), files_snapshot()
        reg_ch = sorted(k for k in diff(reg_b, reg_c) if k not in noise_reg)
        files_ch = sorted(k for k in diff(files_b, files_c) if k not in noise_files)
        ours = [k for k in reg_ch if "tandem" in k.lower() or "salamander" in k.lower()]
        # the WebView2 runtime (msedgewebview2.exe, part of Windows) keeps its own state when a web
        # viewer creates an environment - for any program that uses it; not the program's writes
        runtime_reg = [k for k in reg_ch if k.lower().startswith(("hkcu\\software\\microsoft\\edgewebview",
                                                                  "hkcu\\software\\microsoft\\edgeupdate"))]

        def webview_jumplist(path):
            try:
                return path.lower().endswith(".customdestinations-ms") and b"msedgewebview2.exe" in open(path, "rb").read()
            except OSError:
                return False
        runtime_files = [k for k in files_ch if webview_jumplist(k)]
        # the time stamp of the temporary folder itself changes when the session folder is created
        # and removed in it (FR-007 allows it; that the session folder is gone is its own row) -
        # whether it shows depends on other processes touching %TEMP% during the noise period
        temp_dir = os.path.normcase(os.path.abspath(os.environ["TEMP"]))
        temp_entry = [k for k in files_ch if os.path.normcase(os.path.abspath(k)) == temp_dir]
        program_files = [k for k in files_ch if k not in runtime_files and k not in temp_entry]
        for k in reg_ch[:40]:
            out("    registry change (not noise%s): %s" % (", WebView2 runtime" if k in runtime_reg else "", k))
        for k in files_ch[:40]:
            out("    profile change (not noise%s): %s" % (", WebView2 runtime" if k in runtime_files else
                                                          ", the temporary folder's time stamp" if k in temp_entry else "", k))
        ok_all &= row("no registry key of ours changed", not ours, "%d changes outside the noise, %d of them ours, %d the WebView2 runtime's"
                      % (len(reg_ch), len(ours), len(runtime_reg)))
        sensitive = [k for k in reg_ch if k.lower().startswith(SENSITIVE)]
        ok_all &= row("no change in shell / start-up / uninstall / environment / Control Panel keys", not sensitive,
                      ", ".join(sensitive[:6]) or "none")
        needles = [tc.lower(), os.path.basename(exe).lower(), "tandem commander", "tandemcommander"]
        naming = []
        for k in reg_ch:
            if k in runtime_reg or any(r in k.lower() for r in WINDOWS_RECORDERS):
                continue
            naming += values_naming(k, needles)
        ok_all &= row("no changed value anywhere in HKCU names the program or its folder (Windows' own records aside)",
                      not naming, ", ".join(naming[:6]) or "none")
        ok_all &= row("no profile change by the program", not program_files,
                      "%d entries; %d the WebView2 runtime's (its jump list); %d the temporary folder's time stamp"
                      % (len(files_ch), len(runtime_files), len(temp_entry)))
        key_sha_mid = sha_of_key(KEY, os.path.join(root, "key_mid.reg"))
        ok_all &= row("installed edition's key unchanged", key_sha_mid == key_sha_before_run, "%s" % key_sha_mid)

        # ---- session 2: the setting comes back
        p, dialogs = start(exe, docs)
        dialogs += stop(p)
        time.sleep(3)
        v2 = settings_value(settings_file)
        after2 = [s for s in session_dirs() if s not in sessions_before]
        if portable:
            ok_all &= row("second start: the setting is kept", v1 == 1 and v2 == 1, "value %s -> %s" % (v1, v2))
            ok_all &= row("second start: session folder removed", not after2, str(after2))
            ok_all &= row("second start: no window but the main one", not fatal_in(dialogs), str(dialogs or "none"))
    finally:
        subprocess.run(["reg.exe", "delete", "HKCU\\" + KEY, "/f"], capture_output=True)
        if key_existed:
            subprocess.run(["reg.exe", "import", backup], capture_output=True)
            restored = sha_of_key(KEY, os.path.join(root, "key_after.reg"))
            out("configuration key restored; identical to the backup: %s" % (restored == key_sha_before))
    out("RESULT: %s" % ("PASS" if ok_all else "FAIL"))
    res_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
    os.makedirs(res_dir, exist_ok=True)
    with open(os.path.join(res_dir, "notrace-%s-%s.txt" % (args.label, datetime.datetime.now().strftime("%Y%m%d-%H%M%S"))), "w", encoding="utf-8") as f:
        f.write("\n".join(LINES) + "\n")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
