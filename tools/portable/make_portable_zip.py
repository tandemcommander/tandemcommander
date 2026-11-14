r"""Feature 428: the portable package - setup\output\tandemcommander-<ver>-x64-portable.zip
(a version already released - its tag exists - goes to <build dir>\tandemcommander\ instead:
setup\output keeps the published files).

Usage:
  python tools/portable/make_portable_zip.py <portable output tree> [<out.zip>]
  python tools/portable/make_portable_zip.py --help

Packs the portable edition's Release tree (build\tandemcommander\Release_x64_portable) into one
top-level folder TandemCommander-<ver>-portable\ (contract: specs/428-portable-build/contracts/
package-layout.md):
  - every file of the tree except build byproducts (*.pdb *.lib *.exp *.ilk *.iobj *.ipdb, any
    Intermediate\ or obj\ folder), the shell extension (utils\salext*.dll - the portable edition
    never registers it) and a settings\ folder (a tree that was run);
  - LICENSE (as LICENSE.txt), doc\third_party.txt, doc\license\*.txt, and 7-Zip's licence and the
    LGPL text it refers to (doc\license\7zip_license.txt, doc\license\license_lgpl21.txt);
  - tools\portable\README-portable.txt.
Entries are sorted, every time stamp is the commit time of HEAD (two builds of one commit give the
same file list, and the same files apart from the build time stamps the compiler and linker put in -
zip_check.py Z8 compares them that way); written to <out.zip>.part and renamed at the end, so an interrupted
run leaves nothing that looks finished. Refuses a tree whose tandemcommander.exe is not the
portable edition (its RCDATA TC_PORTABLE_EDITION and its FileDescription).
Exit code 0 on success, 1 on any failure.
"""

import ctypes
import fnmatch
import os
import re
import subprocess
import sys
import time
import zipfile
from ctypes import wintypes

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SPL_VERS = os.path.join(ROOT, "src", "plugins", "shared", "spl_vers.h")
EXCLUDE_FILES = ("*.pdb", "*.lib", "*.exp", "*.ilk", "*.iobj", "*.ipdb")
EXCLUDE_DIRS = ("intermediate", "obj", "settings", "saltests")
EXCLUDE_REL = ("utils/salext*.dll",)


def shown_path(path):
    """The path relative to the repository for messages; the absolute path on another drive."""
    try:
        return os.path.relpath(path, ROOT)
    except ValueError:
        return path


def released(ver):
    """TRUE when the tag v<ver> exists (the version is published)."""
    try:
        r = subprocess.run(["git", "-C", ROOT, "tag", "--list", "v" + ver], capture_output=True, text=True, timeout=30)
    except (OSError, subprocess.SubprocessError):
        return True  # git cannot tell: never risk writing over a published file (the build folder is used)
    if r.returncode != 0:
        return True
    return r.stdout.strip() == "v" + ver


def version():
    text = open(SPL_VERS, encoding="utf-8-sig", errors="replace").read()

    def macro(name):
        m = re.search(r"^\s*#define\s+" + name + r"\s+(\d+)\s*$", text, re.M)
        if not m:
            raise SystemExit("make_portable_zip: %s not found in %s" % (name, SPL_VERS))
        return int(m.group(1))
    return "%d.%d.%d" % (macro("VERSINFO_SALAMANDER_MAJOR"), macro("VERSINFO_SALAMANDER_MINORA"),
                         macro("VERSINFO_SALAMANDER_MINORB"))


def commit_time():
    try:
        r = subprocess.run(["git", "-C", ROOT, "log", "-1", "--format=%ct"], capture_output=True, text=True, timeout=30)
        t = int(r.stdout.strip())
    except (OSError, ValueError, subprocess.SubprocessError):
        t = 1767225600  # 2026-01-01, when git cannot tell
    lt = time.gmtime(max(t, 315532800))  # zip cannot hold a time before 1980
    return (lt.tm_year, lt.tm_mon, lt.tm_mday, lt.tm_hour, lt.tm_min, lt.tm_sec - lt.tm_sec % 2)


def exe_edition(exe):
    """(has the portable marker, FileDescription) of an executable."""
    k32 = ctypes.WinDLL("kernel32", use_last_error=True)
    k32.LoadLibraryExW.argtypes = [wintypes.LPCWSTR, wintypes.HANDLE, wintypes.DWORD]
    k32.LoadLibraryExW.restype = wintypes.HMODULE
    k32.FindResourceW.argtypes = [wintypes.HMODULE, wintypes.LPCWSTR, wintypes.LPCWSTR]
    k32.FindResourceW.restype = wintypes.HANDLE
    k32.FreeLibrary.argtypes = [wintypes.HMODULE]
    h = k32.LoadLibraryExW(exe, None, 0x2 | 0x20)  # LOAD_LIBRARY_AS_DATAFILE | AS_IMAGE_RESOURCE
    marker = False
    if h:
        marker = bool(k32.FindResourceW(h, "TC_PORTABLE_EDITION", ctypes.cast(10, wintypes.LPCWSTR)))  # RT_RCDATA
        k32.FreeLibrary(h)
    ver = ctypes.WinDLL("version")
    size = ver.GetFileVersionInfoSizeW(exe, None)
    desc = ""
    if size:
        buf = ctypes.create_string_buffer(size)
        if ver.GetFileVersionInfoW(exe, 0, size, buf):
            p = ctypes.c_void_p()
            n = wintypes.UINT()
            tr = ctypes.c_void_p()
            if ver.VerQueryValueW(buf, "\\VarFileInfo\\Translation", ctypes.byref(tr), ctypes.byref(n)) and n.value >= 4:
                lang, cp = ctypes.cast(tr, ctypes.POINTER(wintypes.WORD))[0], ctypes.cast(tr, ctypes.POINTER(wintypes.WORD))[1]
                q = "\\StringFileInfo\\%04x%04x\\FileDescription" % (lang, cp)
                if ver.VerQueryValueW(buf, q, ctypes.byref(p), ctypes.byref(n)) and n.value:
                    desc = ctypes.wstring_at(p, n.value).rstrip("\0")
    return marker, desc


def excluded(rel):
    parts = rel.lower().split("/")
    if any(p in EXCLUDE_DIRS for p in parts[:-1]):
        return True
    name = parts[-1]
    if any(fnmatch.fnmatch(name, pat) for pat in EXCLUDE_FILES):
        return True
    return any(fnmatch.fnmatch(rel.lower(), pat) for pat in EXCLUDE_REL)


def collect(tree):
    files = []
    for dp, dn, fn in os.walk(tree):
        dn[:] = [d for d in dn if d.lower() not in EXCLUDE_DIRS]
        for n in fn:
            p = os.path.join(dp, n)
            rel = os.path.relpath(p, tree).replace("\\", "/")
            if not excluded(rel):
                files.append((rel, p))
    return files


def main(argv):
    if len(argv) < 2 or argv[1] in ("--help", "-h", "/?"):
        print(__doc__.strip())
        return 0 if len(argv) >= 2 else 1
    tree = os.path.abspath(argv[1])
    ver = version()
    name = "tandemcommander-%s-x64-portable.zip" % ver
    if len(argv) > 2:
        out = os.path.abspath(argv[2])
    elif released(ver):
        # setup\output keeps the published files of a released version: a build of an unbumped tree
        # (the closing pass before /tandem-release) goes into the build folder instead
        build = os.environ.get("OPENSAL_BUILD_DIR") or os.path.join(ROOT, "build")
        out = os.path.join(build, "tandemcommander", name)
        print("make_portable_zip: version %s is released (tag v%s) - the ZIP goes to %s, setup\\output stays as published"
              % (ver, ver, shown_path(out)))
    else:
        out = os.path.join(ROOT, "setup", "output", name)
    exe = os.path.join(tree, "tandemcommander.exe")
    if not os.path.isfile(exe):
        print("make_portable_zip: FAILED - %s is missing" % exe)
        return 1
    marker, desc = exe_edition(exe)
    if not marker or "(portable)" not in desc:
        print("make_portable_zip: FAILED - %s is not the portable edition (marker %s, description '%s')" % (exe, marker, desc))
        return 1
    top = "TandemCommander-%s-portable" % ver
    entries = [(top + "/" + rel, p) for rel, p in collect(tree)]
    extra = [("LICENSE.txt", os.path.join(ROOT, "LICENSE")),
             ("README-portable.txt", os.path.join(ROOT, "tools", "portable", "README-portable.txt")),
             ("doc/third_party.txt", os.path.join(ROOT, "doc", "third_party.txt"))]
    for n in sorted(os.listdir(os.path.join(ROOT, "doc", "license"))):
        if n.lower().endswith(".txt"):
            extra.append(("doc/license/" + n, os.path.join(ROOT, "doc", "license", n)))
    # 7-Zip (plugins/7zip/7za.dll) is LGPL: its licence and the LGPL text travel with it
    # (doc/third_party.txt says a copy is included)
    seven = os.path.join(ROOT, "src", "plugins", "7zip", "7za", "DOC")
    extra.append(("doc/license/license_lgpl21.txt", os.path.join(seven, "copying.txt")))
    extra.append(("doc/license/7zip_license.txt", os.path.join(seven, "License.txt")))
    for rel, p in extra:
        if not os.path.isfile(p):
            print("make_portable_zip: FAILED - %s is missing" % p)
            return 1
        entries.append((top + "/" + rel, p))
    entries.sort(key=lambda e: e[0].encode("utf-8"))
    leaked = [n for n, _ in entries if excluded(n[len(top) + 1:])]
    if leaked:
        print("make_portable_zip: FAILED - excluded files would be packaged: %s" % ", ".join(leaked[:5]))
        return 1
    stamp = commit_time()
    os.makedirs(os.path.dirname(out), exist_ok=True)
    part = out + ".part"
    if os.path.exists(part):
        os.remove(part)
    total = 0
    with zipfile.ZipFile(part, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, p in entries:
            info = zipfile.ZipInfo(name, date_time=stamp)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            info.create_system = 0
            with open(p, "rb") as f:
                data = f.read()
            if name == top + "/README-portable.txt":  # the one text with the version in it
                data = data.replace(b"@VERSION@", ver.encode("ascii"))
            total += len(data)
            z.writestr(info, data)
    os.replace(part, out)
    print("make_portable_zip: OK - %s (%d files, %.1f MB unpacked, %.1f MB packed)"
          % (shown_path(out), len(entries), total / 1048576.0, os.path.getsize(out) / 1048576.0))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
