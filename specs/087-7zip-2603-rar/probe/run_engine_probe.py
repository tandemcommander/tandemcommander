"""Feature 087 engine probe.

    python run_engine_probe.py <7za.dll> [--label NAME]

Uses obj/7zdrive.exe (build_7zdrive.cmd) against the given engine DLL and the
independent reference C:\\Program Files\\7-Zip\\7z.exe:

  RAR   every fixture of specs/084-archiver-cleanup/probe/fixtures/rar with its
        expected outcome: extracted tree identical to the reference
        extraction, or a clean failure (damaged, wrong/missing password,
        missing volume, non-first part)
  7Z    the 084 Unicode fixture; archives CREATED by the driver (plain, solid,
        encrypted, encrypted headers) tested by the reference and extracted
        back identical to the source; a wrong password fails
  NAMES a hostile 7z (unsafe entry names) extracts entirely inside the
        target folder, with no alternate data stream
  MEM   RAR5 copies declaring a 2 GiB / 128 GiB dictionary (make_bigdict.py):
        128 GiB refused, 2 GiB refused under a 1 GiB limit, allowed by default
  TIME  listing a 10,000-entry 7z (reported, compared by the caller)

Exit code 0 = every check passed.
"""

import ctypes
import filecmp
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
DRIVE = os.path.join(HERE, "obj", "7zdrive.exe")
SEVEN = r"C:\Program Files\7-Zip\7z.exe"
RAR = os.path.join(ROOT, "specs", "084-archiver-cleanup", "probe", "fixtures", "rar")
Z7 = os.path.join(ROOT, "specs", "084-archiver-cleanup", "probe", "fixtures", "7z")

# fixture -> (password or None, expectation "ok" | "fail")
RAR_CASES = [
    ("test_read_format_rar.rar", None, "ok"),
    ("test_read_format_rar_unicode.rar", None, "ok"),
    ("test_read_format_rar_encryption_data.rar", "12345678", "ok"),
    ("test_read_format_rar_encryption_header.rar", "12345678", "ok"),
    ("test_read_format_rar_encryption_data.rar", "wrong", "fail"),
    ("test_read_format_rar_encryption_header.rar", None, "fail"),
    ("test_read_format_rar4_encrypted.rar", None, "fail"),
    ("test_read_format_rar4_encrypted_filenames.rar", "password", "ok"),
    ("test_read_format_rar5_compressed.rar", None, "ok"),
    ("test_read_format_rar5_encrypted.rar", None, "fail"),
    ("test_read_format_rar5_encrypted_filenames.rar", "password", "ok"),
    ("test_read_format_rar5_unicode.rar", None, "ok"),
    ("test_read_format_rar_multivolume.part0001.rar", None, "ok"),
    ("test_read_format_rar5_multiarchive.part01.rar", None, "ok"),
    ("test_read_format_rar_multivolume.part0002.rar", None, "fail"),
    ("test_read_format_rar5_multiarchive.part02.rar", None, "fail"),
    ("damaged_rar5.rar", None, "fail"),
]

failures = 0


def check(name, cond, detail=""):
    global failures
    print(("PASS " if cond else "FAIL ") + name + (" - " + detail if detail else ""))
    if not cond:
        failures += 1


def drive(dll, *args):
    r = subprocess.run([DRIVE, args[0], dll] + list(args[1:]), capture_output=True, text=True,
                       encoding="utf-8", errors="replace", timeout=600)
    return r.returncode, r.stdout + r.stderr


def reference_extract(archive, out, password):
    args = [SEVEN, "x", "-y", "-o" + out, archive]
    args.insert(2, "-p" + (password or ""))
    return subprocess.run(args, capture_output=True, text=True, timeout=600).returncode


def tree(path):
    files = {}
    for base, dirs, names in os.walk(path):
        for n in names:
            full = os.path.join(base, n)
            files[os.path.relpath(full, path)] = full
    return files


def same_tree(a, b, ignore=()):
    ta, tb = tree(a), tree(b)
    for k in ignore:  # links the driver skips (the reference creates them as links)
        ta.pop(k, None)
    if set(ta) != set(tb):
        return False, "names differ: only-a %s only-b %s" % (sorted(set(ta) - set(tb))[:3], sorted(set(tb) - set(ta))[:3])
    for k in ta:
        if not filecmp.cmp(ta[k], tb[k], shallow=False):
            return False, "content differs: " + k
    return True, "%d files" % len(ta)


def streams(path):
    """names of the NTFS data streams of a file (::$DATA = the main one)"""
    k32 = ctypes.windll.kernel32

    class WIN32_FIND_STREAM_DATA(ctypes.Structure):
        _fields_ = [("StreamSize", ctypes.c_longlong), ("cStreamName", ctypes.c_wchar * 296)]

    data = WIN32_FIND_STREAM_DATA()
    k32.FindFirstStreamW.restype = ctypes.c_void_p
    h = k32.FindFirstStreamW(ctypes.c_wchar_p(path), 0, ctypes.byref(data), 0)
    if h in (None, ctypes.c_void_p(-1).value):
        return []
    names = [data.cStreamName]
    while k32.FindNextStreamW(ctypes.c_void_p(h), ctypes.byref(data)):
        names.append(data.cStreamName)
    k32.FindClose(ctypes.c_void_p(h))
    return names


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    dll = os.path.abspath(sys.argv[1])
    label = sys.argv[3] if len(sys.argv) > 3 and sys.argv[2] == "--label" else os.path.basename(dll)
    print("engine: %s (%s)" % (dll, label))
    rc, out = drive(dll, "formats")
    print(out.strip().splitlines()[0] if out.strip() else out)
    # every compression setting the plug-in offers is accepted (review of S1, finding 3)
    rc, out = drive(dll, "props")
    check("7Z every offered compression setting accepted", rc == 0, out.strip().splitlines()[-1])
    work = tempfile.mkdtemp(prefix="p087_")
    try:
        # ---------------------------------------------------------- RAR
        for name, pw, expect in RAR_CASES:
            arc = os.path.join(RAR, name)
            got = os.path.join(work, "got")
            ref = os.path.join(work, "ref")
            shutil.rmtree(got, ignore_errors=True)
            shutil.rmtree(ref, ignore_errors=True)
            args = ["extract", arc, got] + (["-p" + pw] if pw else [])
            rc, out = drive(dll, *args)
            tag = "RAR %s%s" % (name, " -p" + pw if pw else "")
            if expect == "ok":
                reference_extract(arc, ref, pw)
                links = [l.split("skipped link: ", 1)[1].strip() for l in out.splitlines() if "skipped link: " in l]
                same, why = same_tree(ref, got, links) if rc == 0 else (False, out.strip().splitlines()[-1] if out.strip() else "")
                if links:
                    why += ", links skipped (not created): %d" % len(links)
                check(tag + " extracts identical", rc == 0 and same, why)
            else:
                check(tag + " fails cleanly", rc == 1, out.strip().splitlines()[-1] if out.strip() else "rc=%d" % rc)
        # missing volume: copy the RAR5 set without part 3
        mv = os.path.join(work, "missing")
        os.makedirs(mv)
        for n in os.listdir(RAR):
            if n.startswith("test_read_format_rar5_multiarchive") and "part03" not in n:
                shutil.copy(os.path.join(RAR, n), mv)
        rc, out = drive(dll, "extract", os.path.join(mv, "test_read_format_rar5_multiarchive.part01.rar"),
                        os.path.join(work, "got_mv"))
        check("RAR5 set with a missing part fails cleanly", rc == 1, out.strip().splitlines()[-1])

        # ---------------------------------------------------------- 7Z
        for name in os.listdir(Z7):
            arc = os.path.join(Z7, name)
            got, ref = os.path.join(work, "z_got"), os.path.join(work, "z_ref")
            shutil.rmtree(got, ignore_errors=True)
            shutil.rmtree(ref, ignore_errors=True)
            rc, out = drive(dll, "extract", arc, got)
            reference_extract(arc, ref, None)
            same, why = same_tree(ref, got) if rc == 0 else (False, out)
            check("7Z fixture %s extracts identical" % name, rc == 0 and same, why)
        src = os.path.join(work, "src")
        os.makedirs(os.path.join(src, "sub dir"))
        with open(os.path.join(src, "a.txt"), "wb") as f:
            f.write(b"feature 087\r\n" * 5000)
        with open(os.path.join(src, "sub dir", "\u010d\u00e1st \u4e2d\u6587.bin"), "wb") as f:
            f.write(os.urandom(200000))
        with open(os.path.join(src, "empty.txt"), "wb"):
            pass
        variants = [("plain", []), ("store", ["-mx=0"]), ("nonsolid", ["-ms=off"]),
                    ("encrypted", ["-pZz087pw"]), ("encrypted_headers", ["-pZz087pw", "-mhe"])]
        for vname, vargs in variants:
            arc = os.path.join(work, vname + ".7z")
            rc, out = drive(dll, "create", arc, src, *vargs)
            pw = "Zz087pw" if "-pZz087pw" in vargs else None
            ref_ok = subprocess.run([SEVEN, "t", "-p" + (pw or ""), arc], capture_output=True).returncode == 0
            got = os.path.join(work, "c_" + vname)
            rc2, out2 = drive(dll, "extract", arc, got, *(["-p" + pw] if pw else []))
            same, why = same_tree(src, got) if rc2 == 0 else (False, out2)
            check("7Z create %s: reference tests OK, round trip identical" % vname,
                  rc == 0 and ref_ok and rc2 == 0 and same, why)
            if pw:
                rc3, out3 = drive(dll, "extract", arc, os.path.join(work, "w_" + vname), "-pwrong")
                check("7Z %s with a wrong password fails" % vname, rc3 == 1, out3.strip().splitlines()[-1])

        # ---------------------------------------------------------- NAMES
        hostile = os.path.join(work, "hostile.7z")
        drive(dll, "hostile", hostile)
        target = os.path.join(work, "h", "a", "b", "target")
        rc, out = drive(dll, "extract", hostile, target)
        outside = [p for p in tree(os.path.join(work, "h")) if not p.startswith(os.path.join("a", "b", "target"))]
        check("NAMES hostile archive: nothing outside the target", rc == 0 and not outside,
              "outside: %s" % outside if outside else "%d files inside" % len(tree(target)))
        ads = [p for p in tree(target).values() if any(s != "::$DATA" for s in streams(p))]
        check("NAMES hostile archive: no alternate data stream", not ads, str(ads))
        drive_root = [n for n in ("escape_drive.txt", "escape_root.txt") if os.path.exists("C:\\" + n)]
        check("NAMES hostile archive: nothing written to C:\\", not drive_root, str(drive_root))

        # ---------------------------------------------------------- MEM
        big = os.path.join(work, "bigdict")
        subprocess.run([sys.executable, os.path.join(HERE, "make_bigdict.py"),
                        os.path.join(RAR, "test_read_format_rar5_compressed.rar"), big], check=True)
        for name, extra, ok in (("dict128g.rar", [], False), ("dict2g.rar", ["-mem=1073741824"], False),
                                ("dict2g.rar", [], True)):
            got = os.path.join(work, "mem_got")
            shutil.rmtree(got, ignore_errors=True)
            rc, out = drive(dll, "extract", os.path.join(big, name), got, *extra)
            asked = "memory request:" in out
            refused = rc == 1 and "0x8007000E" in out
            what = "allowed" if ok else "refused"
            check("MEM %s%s %s" % (name, " " + extra[0] if extra else "", what),
                  asked and (rc == 0 if ok else refused), out.strip().splitlines()[-1])

        # ---------------------------------------------------------- TIME
        big = os.path.join(work, "big.7z")
        drive(dll, "bigtree", big, "10000")
        t0 = time.perf_counter()
        rc, out = drive(dll, "list", big)
        dt = time.perf_counter() - t0
        print("TIME listing 10,000 entries: %.3f s (rc %d)" % (dt, rc))
    finally:
        shutil.rmtree(work, ignore_errors=True)
    print("engine probe (%s): %d failed" % (label, failures))
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
