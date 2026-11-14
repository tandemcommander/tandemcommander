r"""Feature 428 probe: carry the folder, failures, side by side (US2, US6, SC-003, SC-006, SC-007, FR-011a).

Usage (hidden desktop - tools\run_on_hidden_desktop.ps1):
  python scenarios_probe.py --portable <portable tree exe> --normal <normal tree exe> [--only move,fail,kill,side]

move  US2 / SC-003: the left panel is left in <copy>\docs (inside the portable folder); the file
      must store it as $(PortableDir)\docs. The folder is copied elsewhere and reached through a
      subst drive letter; started there without arguments, the panel opens docs of the NEW place,
      the toggled setting is kept, and the old place's path is not in the file.
fail  US6: a deny-write ACE on the folder -> the program starts, says once that it cannot save
      (no second message at exit), writes nothing (file unchanged, no settings anywhere else);
      a damaged settings file -> the .bak is used, the user is told, the damaged file is kept aside;
      both damaged -> default settings, the user is told, both kept aside.
kill  SC-006: 20 runs that kill the program at random moments of a save; after each the settings
      file is complete (it parses) and the next start shows no "restored" / "damaged" message.
side  SC-007 / FR-011a: "Only one instance" on in the normal edition (its key backed up and
      restored) and in two portable copies; the normal one and portable A run; starting portable B
      opens its own window; starting portable A again activates A (the new process ends) - and
      never the normal edition's window.
"""

import argparse
import datetime
import os
import random
import shutil
import string
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import notrace_probe as P  # noqa: E402

ROOT = os.path.join(os.environ["TEMP"], "tc428", "scenarios")
CFG = r"HKEY_CURRENT_USER\Software\Tandem Commander\Settings\Configuration"
ok_all = True


def row(case, ok, facts):
    global ok_all
    ok_all &= P.row(case, ok, facts)


def make_copy(exe, name):
    tc = os.path.join(ROOT, name, "TC")
    shutil.rmtree(os.path.join(ROOT, name), ignore_errors=True)
    shutil.copytree(os.path.dirname(os.path.abspath(exe)), tc,
                    ignore=shutil.ignore_patterns("Intermediate", "saltests", "*.pdb", "*.ilk", "*.lib", "*.exp", "settings"))
    docs = os.path.join(tc, "docs")
    os.makedirs(docs)
    open(os.path.join(docs, "a.txt"), "w").write("a\n")
    return tc, docs


def settings_file(tc):
    return os.path.join(tc, "settings", "tandemcommander.reg")


def read_text(path):
    return open(path, "rb").read().decode("utf-16")


def parses(path):
    """A complete settings file: UTF-16 with the header, the root key, and ends with a line break."""
    try:
        t = read_text(path)
    except (OSError, UnicodeDecodeError):
        return False
    return t.startswith("Windows Registry Editor Version 5.00") and \
        "[HKEY_CURRENT_USER\\Software\\Tandem Commander\\Settings]" in t and t.endswith("\r\n")


def set_dword(path, key, name, value):
    t = read_text(path)
    line = '"%s"=dword:%08x' % (name, value)
    head = "[" + key + "]"
    lines = t.split("\r\n")
    if head in lines:
        i = lines.index(head) + 1
        j = i
        while j < len(lines) and lines[j] and not lines[j].startswith("["):
            if lines[j].startswith('"%s"=' % name):
                lines[j] = line
                break
            j += 1
        else:
            lines.insert(i, line)
    else:
        lines += [head, line, ""]
    open(path, "wb").write(("﻿" + "\r\n".join(lines)).encode("utf-16-le"))


def set_string(path, key, name, value):
    t = read_text(path)
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
    open(path, "wb").write(("\ufeff" + "\r\n".join(lines)).encode("utf-16-le"))


def has_line(path, needle):
    try:
        return needle in read_text(path)
    except (OSError, UnicodeDecodeError):
        return False


def key_count(path):
    try:
        return sum(1 for line in read_text(path).split("\r\n") if line.startswith("["))
    except (OSError, UnicodeDecodeError):
        return 0


MARK = '"Title bar prefix text"="%s"'


def lines_with_outside(text, needle, allowed_section):
    """Lines of a .reg text that hold 'needle' (case-insensitive) outside the section whose key ends
    with 'allowed_section'."""
    section = ""
    bad = []
    for line in text.split("\r\n"):
        if line.startswith("["):
            section = line
        elif needle.lower() in line.lower() and not section.lower().endswith(allowed_section.lower() + "]"):
            bad.append(section + " " + line[:120])
    return bad


def notes(dialogs, *needles):
    return [d for d in dialogs if any(n in d for n in needles)]


def run_and_close(exe, args=(), seconds=40):
    p = subprocess.Popen([exe] + list(args))
    t0 = time.time()
    dialogs = []
    while time.time() - t0 < 60 and P.alive(p) and P.main_win(p.pid) is None:
        dialogs += P.serve(p, 2)
    time.sleep(2)
    dialogs += P.serve(p, 8)
    title = P.txt(P.main_win(p.pid)) if P.main_win(p.pid) else None
    dialogs += P.stop(p, seconds)
    return title, dialogs, p


# ------------------------------------------------------------------ move
def scenario_move(exe):
    tc, docs = make_copy(exe, "move")
    exe_a = os.path.join(tc, "tandemcommander.exe")
    run_and_close(exe_a, ["-l", docs, "-r", docs])
    set_string(settings_file(tc), CFG, "Title bar prefix text", "MOVE428")  # a second setting that must travel
    title, dialogs, p = run_and_close(exe_a, ["-l", docs, "-r", docs])
    f = settings_file(tc)
    t = read_text(f) if os.path.isfile(f) else ""
    # the folder's absolute path may stay only in Default Directories (drive-bound by the value name)
    old_outside = lines_with_outside(t, tc.replace("\\", "\\\\"), "\\Default Directories")
    row("move: panel path inside the folder stored as $(PortableDir)", "$(PortableDir)\\\\docs" in t and not old_outside,
        "title %r; absolute path outside Default Directories: %s" % (title, old_outside or "none"))
    # copy to another place and reach it through a subst drive letter
    dest_parent = os.path.join(ROOT, "move", "Jiné místo \u010c\U0001F4C1")
    shutil.copytree(tc, os.path.join(dest_parent, "TC"))
    shutil.rmtree(tc)  # the old place is gone: a panel that opens "docs" can only be the new one
    # started at the non-ASCII path itself (no drive letter between) - then through a subst letter
    direct = os.path.join(dest_parent, "TC")
    title0, dialogs0, p0 = run_and_close(os.path.join(direct, "tandemcommander.exe"))
    t0 = read_text(settings_file(direct))
    row("move: started at the non-ASCII path, the panel opens the moved docs, the second setting kept",
        bool(title0) and title0.startswith("docs - ") and MARK % "MOVE428" in t0 and "$(PortableDir)\\\\docs" in t0,
        "title %r; windows %s" % (title0, [d for d in dialogs0 if d.strip() != "[#32770 '']"] or "none"))
    free = [c for c in "ZYXWVUTSRQPONMLKJ" if not os.path.exists(c + ":\\")]
    drive = free[0] + ":"
    subprocess.run(["subst", drive, dest_parent], check=True)
    try:
        exe_b = drive + "\\TC\\tandemcommander.exe"
        title2, dialogs2, p2 = run_and_close(exe_b)
        t2 = read_text(drive + "\\TC\\settings\\tandemcommander.reg")
        row("move: started at %s\\TC, the panel opens the moved docs" % drive, bool(title2) and title2.startswith("docs - "),
            "title %r; windows %s" % (title2, dialogs2 or "none"))
        # every start shows one empty, untitled dialog-class window (seen in every run, both editions);
        # anything else - an error box above all - fails the move
        others = [d for d in dialogs2 if d.startswith("[#32770") and d.strip() != "[#32770 '']"]
        row("move: no message or error box at the moved start", not others, str(others)[:300])
        old2 = lines_with_outside(t2, tc.replace("\\", "\\\\"), "\\Default Directories")
        row("move: the file still says $(PortableDir)\\docs and the second setting, no old path elsewhere",
            "$(PortableDir)\\\\docs" in t2 and MARK % "MOVE428" in t2 and not old2,
            "%d characters; %s" % (len(t2), old2 or "the old place only in Default Directories"))
    finally:
        subprocess.run(["subst", drive, "/d"])


# ------------------------------------------------------------------ fail
def icacls(path, *args):
    return subprocess.run(["icacls", path] + list(args), capture_output=True, text=True).returncode == 0


def scenario_fail(exe):
    tc, docs = make_copy(exe, "fail")
    exe_c = os.path.join(tc, "tandemcommander.exe")
    run_and_close(exe_c, ["-l", docs, "-r", docs])  # creates the settings
    f = settings_file(tc)
    row("fail: settings exist before the failure rows", P.os.path.isfile(f), f)
    bak = f + ".bak"
    run_and_close(exe_c, ["-l", docs, "-r", docs])  # a second save makes the .bak
    # unwritable folder
    before = open(f, "rb").read()
    user = os.environ["USERDOMAIN"] + "\\" + os.environ["USERNAME"]
    sessions = P.session_dirs()
    key_before = P.sha_of_key(P.KEY, os.path.join(ROOT, "fail_key_before.reg"))
    prof_before = P.files_snapshot()
    icacls(tc, "/deny", user + ":(OI)(CI)(WD,AD,WEA,WA,DC)")
    icacls(os.path.join(tc, "settings"), "/deny", user + ":(OI)(CI)(WD,AD,WEA,WA,DC)")
    try:
        p = subprocess.Popen([exe_c, "-l", docs, "-r", docs])
        t0 = time.time()
        dialogs = []
        while time.time() - t0 < 60 and P.alive(p) and P.main_win(p.pid) is None:
            dialogs += P.serve(p, 2)
        time.sleep(2)
        dialogs += P.serve(p, 10)
        told = notes(dialogs, tc)
        P.u32.PostMessageW(P.main_win(p.pid), P.WM_COMMAND, P.CM_TOGGLEHIDDENFILES, 0)
        time.sleep(1)
        P.u32.PostMessageW(P.main_win(p.pid), P.WM_COMMAND, P.CM_SAVECONFIG, 0)
        later = P.serve(p, 10)
        exit_dialogs = P.stop(p)
        row("fail: unwritable folder - told once at start", len(told) == 1, str(told)[:300])
        row("fail: unwritable folder - no second message (save, exit)", not notes(later + exit_dialogs, tc),
            str(later + exit_dialogs)[:300])
    finally:
        icacls(os.path.join(tc, "settings"), "/remove:d", user)
        icacls(tc, "/remove:d", user)
    row("fail: unwritable folder - settings file unchanged", open(f, "rb").read() == before, f)
    key_after = P.sha_of_key(P.KEY, os.path.join(ROOT, "fail_key_after.reg"))
    prof_after = P.files_snapshot()
    ours = sorted(k for k in P.diff(prof_before, prof_after) if "tandem commander" in k.lower())
    row("fail: unwritable folder - nothing saved anywhere else (installed key, profile folders)",
        key_after == key_before and not ours, "key same %s; profile entries %s" % (key_after == key_before, ours or "none"))
    row("fail: unwritable folder - session folder removed", P.session_dirs() == sessions, str(P.session_dirs()))
    # a damaged main file -> the .bak (marked: a start on defaults would not carry the mark)
    set_string(bak, CFG, "Title bar prefix text", "BAK428")
    open(f, "wb").write(b"\xff\xfeW\x00x\x00")
    title, dialogs, p = run_and_close(exe_c, ["-l", docs, "-r", docs])
    damaged = [n for n in os.listdir(os.path.join(tc, "settings")) if ".damaged-" in n]
    row("fail: damaged file - the .bak used (its mark is in the new file) and the user told",
        bool(notes(dialogs, "settings")) and parses(f) and has_line(f, MARK % "BAK428") and len(damaged) == 1,
        "messages %s; kept aside %s" % (str(notes(dialogs, "settings"))[:200], damaged))
    # both damaged -> defaults
    open(f, "wb").write(b"garbage")
    open(bak, "wb").write(b"garbage too")
    for n in damaged:
        os.remove(os.path.join(tc, "settings", n))
    title, dialogs, p = run_and_close(exe_c, ["-l", docs, "-r", docs])
    damaged2 = [n for n in os.listdir(os.path.join(tc, "settings")) if ".damaged-" in n]
    row("fail: both damaged - defaults (no mark), the user told, both kept aside",
        bool(notes(dialogs, "settings")) and len(damaged2) == 2 and parses(f) and not has_line(f, MARK % "BAK428"),
        "messages %s; kept aside %s" % (str(notes(dialogs, "settings"))[:200], damaged2))


# ------------------------------------------------------------------ kill
def scenario_kill(exe, runs=20):
    tc, docs = make_copy(exe, "kill")
    exe_k = os.path.join(tc, "tandemcommander.exe")
    run_and_close(exe_k, ["-l", docs, "-r", docs])
    f = settings_file(tc)
    set_string(f, CFG, "Title bar prefix text", "KILL428")
    keys0 = key_count(f)
    bad = []
    hit = 0  # kills that left a write in progress (a temporary file beside the settings file)
    rewritten = 0
    rnd = random.Random(428)
    for i in range(runs):
        p = subprocess.Popen([exe_k, "-l", docs, "-r", docs])
        t0 = time.time()
        while time.time() - t0 < 60 and P.alive(p) and P.main_win(p.pid) is None:
            P.serve(p, 2)
        P.send(P.main_win(p.pid), 0, 0, 0)  # the message loop runs (WM_NULL answered)
        time.sleep(1.5)
        mtime = os.stat(f).st_mtime_ns  # before the save: a rewrite during the run shows against it
        P.u32.PostMessageW(P.main_win(p.pid), P.WM_COMMAND, P.CM_TOGGLEHIDDENFILES, 0)
        P.u32.PostMessageW(P.main_win(p.pid), P.WM_COMMAND, P.CM_SAVECONFIG, 0)
        if i % 2 == 0:
            # half the runs: killed the moment the write's temporary file appears beside the
            # settings file - in the middle of writing the new file
            sd = os.path.join(tc, "settings")
            t1 = time.time()
            while time.time() - t1 < 5 and not any(n.lower().endswith(".tmp") for n in os.listdir(sd)):
                time.sleep(0.001)
        else:
            time.sleep(rnd.uniform(0.0, 0.4))  # the other half: anywhere in the save's first moments
        p.kill()
        p.wait()
        if any(n.lower().endswith(".tmp") for n in os.listdir(os.path.join(tc, "settings"))):
            hit += 1
        if os.stat(f).st_mtime_ns != mtime:
            rewritten += 1
        # complete = parses AND still the whole configuration with its mark (not a file of defaults)
        if not parses(f) or not has_line(f, MARK % "KILL428") or key_count(f) < keys0:
            bad.append(i)
    row("kill: %d kills during a save - the file always complete, every key and the mark kept" % runs, not bad,
        "bad after runs %s; %d keys at the start; kills during a write (temporary file left) %d, files rewritten %d"
        % (bad, keys0, hit, rewritten))
    row("kill: the kills landed in saves - files rewritten before the kill in at least 3 runs, a write cut in at least 1",
        rewritten >= 3 and hit >= 1, "rewritten %d, write cut %d (of %d)" % (rewritten, hit, runs))
    stale = P.session_dirs()
    row("kill: the killed process leaves its session folder", bool(stale), str(stale))
    title, dialogs, p = run_and_close(exe_k, ["-l", docs, "-r", docs])
    row("kill: the next start shows no restored / damaged message", not notes(dialogs, "settings", "nastaven"),
        str(dialogs)[:300])
    leftovers = [n for n in os.listdir(os.path.join(tc, "settings")) if n.lower().endswith(".tmp")]
    row("kill: no temporary file left after a normal start", not leftovers, str(leftovers))
    row("kill: the next start removed the crashed session folder (SC-004, FR-007)", not P.session_dirs(),
        str(P.session_dirs()))


# ------------------------------------------------------------------ two
def scenario_two(exe):
    """Two processes of ONE copy (Only One Instance off): they share the session; the first one to
    exit leaves the session to the second; the second's change is saved; the last exit removes it."""
    tc, docs = make_copy(exe, "two")
    exe_t = os.path.join(tc, "tandemcommander.exe")
    run_and_close(exe_t, ["-l", docs, "-r", docs])
    f = settings_file(tc)
    v0 = P.settings_value(f)
    p1 = subprocess.Popen([exe_t, "-l", docs])
    p2 = None
    try:
        for p in (p1,):
            t0 = time.time()
            while time.time() - t0 < 60 and P.alive(p) and P.main_win(p.pid) is None:
                P.serve(p, 2)
        p2 = subprocess.Popen([exe_t, "-r", docs])
        t0 = time.time()
        while time.time() - t0 < 60 and P.alive(p2) and P.main_win(p2.pid) is None:
            P.serve(p2, 2)
        time.sleep(2)
        sessions = P.session_dirs()
        row("two: both processes of the copy run, one session folder", P.alive(p1) and P.alive(p2) and len(sessions) == 1,
            "alive %s / %s; sessions %s" % (P.alive(p1), P.alive(p2), sessions))
        P.stop(p1)
        time.sleep(2)
        row("two: the first exit leaves the session to the second", P.alive(p2) and P.session_dirs() == sessions,
            "second alive %s; sessions %s" % (P.alive(p2), P.session_dirs()))
        P.u32.PostMessageW(P.main_win(p2.pid), P.WM_COMMAND, P.CM_TOGGLEHIDDENFILES, 0)
        time.sleep(1)
        P.u32.PostMessageW(P.main_win(p2.pid), P.WM_COMMAND, P.CM_SAVECONFIG, 0)
        P.serve(p2, 6)
        P.stop(p2)
        time.sleep(2)
        v2 = P.settings_value(f)
        row("two: the second process's change is saved; the last exit removes the session folder",
            v2 is not None and v2 != v0 and not P.session_dirs(), "value %s -> %s; sessions %s" % (v0, v2, P.session_dirs()))
    finally:
        for p in (p1, p2):
            if p is not None and P.alive(p):
                P.stop(p, 30)


# ------------------------------------------------------------------ side
def scenario_side(portable_exe, normal_exe):
    a_tc, a_docs = make_copy(portable_exe, "sideA")
    b_tc, b_docs = make_copy(portable_exe, "sideB")
    n_tc, n_docs = make_copy(normal_exe, "sideN")
    a_exe, b_exe, n_exe = (os.path.join(x, "tandemcommander.exe") for x in (a_tc, b_tc, n_tc))
    run_and_close(a_exe, ["-l", a_docs])
    run_and_close(b_exe, ["-l", b_docs])
    for tc in (a_tc, b_tc):
        set_dword(settings_file(tc), CFG, "Only One Instance", 1)
    key = r"HKCU\Software\Tandem Commander"
    backup = os.path.join(ROOT, "side_key_backup.reg")
    subprocess.run(["reg.exe", "export", key, backup, "/y"], capture_output=True, check=True)
    sha_before = P.sha_of_key(P.KEY, os.path.join(ROOT, "side_before.reg"))
    procs = []
    try:
        subprocess.run(["reg.exe", "add", key + r"\Settings\Configuration", "/v", "Only One Instance", "/t", "REG_DWORD",
                        "/d", "1", "/f"], capture_output=True, check=True)
        pn = subprocess.Popen([n_exe, "-l", n_docs])
        procs.append(pn)
        pa = subprocess.Popen([a_exe, "-l", a_docs])
        procs.append(pa)
        for p in (pn, pa):
            t0 = time.time()
            while time.time() - t0 < 60 and P.alive(p) and P.main_win(p.pid) is None:
                P.serve(p, 2)
        row("side: the normal edition and portable A run side by side", P.alive(pn) and P.alive(pa) and
            P.main_win(pn.pid) is not None and P.main_win(pa.pid) is not None, "pids %d / %d" % (pn.pid, pa.pid))
        pb = subprocess.Popen([b_exe, "-l", b_docs])
        procs.append(pb)
        t0 = time.time()
        while time.time() - t0 < 60 and P.alive(pb) and P.main_win(pb.pid) is None:
            P.serve(pb, 2)
        row("side: portable B (another folder) opens its own window", P.alive(pb) and P.main_win(pb.pid) is not None,
            "pid %d alive %s" % (pb.pid, P.alive(pb)))
        pa2 = subprocess.Popen([a_exe, "-l", a_docs])
        procs.append(pa2)
        try:
            pa2.wait(30)
            ended = True
        except subprocess.TimeoutExpired:
            ended = False
        row("side: portable A again - hands over to the running A and ends", ended and P.alive(pa) and P.alive(pn),
            "second A ended %s, first A alive %s, normal alive %s" % (ended, P.alive(pa), P.alive(pn)))
    finally:
        for p in reversed(procs):
            if P.alive(p):
                P.stop(p, 30)
        subprocess.run(["reg.exe", "delete", key, "/f"], capture_output=True)
        subprocess.run(["reg.exe", "import", backup], capture_output=True)
        sha_after = P.sha_of_key(P.KEY, os.path.join(ROOT, "side_after.reg"))
        row("side: the configuration key restored", sha_after == sha_before, sha_after)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--portable", required=True)
    ap.add_argument("--normal", required=True)
    ap.add_argument("--only", default="move,fail,kill,two,side")
    args = ap.parse_args()
    os.makedirs(ROOT, exist_ok=True)
    P.out("feature 428 scenarios probe, %s" % datetime.datetime.now().isoformat(timespec="seconds"))
    only = args.only.split(",")
    for name, fn in (("move", lambda: scenario_move(args.portable)), ("fail", lambda: scenario_fail(args.portable)),
                     ("kill", lambda: scenario_kill(args.portable)), ("two", lambda: scenario_two(args.portable)),
                     ("side", lambda: scenario_side(args.portable, args.normal))):
        if name in only:
            try:
                fn()
            except Exception as e:  # a scenario that breaks is a FAIL row, the others still run
                import traceback
                for line in traceback.format_exc().splitlines():
                    P.out("    " + line)
                row("%s: the scenario ran to its end" % name, False, "%s: %s" % (type(e).__name__, e))
    P.out("RESULT: %s" % ("PASS" if ok_all else "FAIL"))
    res_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "results")
    os.makedirs(res_dir, exist_ok=True)
    with open(os.path.join(res_dir, "scenarios-%s.txt" % datetime.datetime.now().strftime("%Y%m%d-%H%M%S")), "w", encoding="utf-8") as fo:
        fo.write("\n".join(P.LINES) + "\n")
    return 0 if ok_all else 1


if __name__ == "__main__":
    sys.exit(main())
