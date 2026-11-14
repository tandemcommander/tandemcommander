r"""Feature 428 probe (T036): checks a built portable ZIP against contracts/package-layout.md.

Usage:
  python zip_check.py <portable.zip> [<second build of the same commit>.zip]

Checks:
  Z1 one top-level folder TandemCommander-<ver>-portable/, nothing else at the root
  Z2 required files present (the exe, >= 20 plugins, >= 8 language modules, LICENSE.txt,
     README-portable.txt, doc/third_party.txt, doc/license/license_gpl.txt)
  Z3 no excluded file (*.pdb *.lib *.exp *.ilk *.iobj *.ipdb, Intermediate/, obj/, settings/,
     utils/salext*.dll)
  Z4 the packed tandemcommander.exe is the portable edition (RCDATA TC_PORTABLE_EDITION and
     FileDescription "... (portable)"), checked on a copy extracted to a temporary folder
  Z5 entries sorted by UTF-8 byte order, files only, all deflated
  Z6 every time stamp equal
  Z7 the README is <= 60 lines
  Z8 (with a second ZIP of the same commit, SC-005) a: the same entry list; b: every file the same,
     or the same apart from the build time stamps (see normalize)
Prints one line per check and "ZIP CHECK: PASS" / "ZIP CHECK: FAIL"; exit code 0 / 1.
"""

import fnmatch
import os
import re
import sys
import tempfile
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "portable"))
import make_portable_zip as mpz  # noqa: E402  (exe_edition, excluded)

results = []


BUILT_STAMP = re.compile(rb"[A-Z][a-z]{2} [ 0-9][0-9] [0-9]{4}, [0-9]{2}:[0-9]{2}:[0-9]{2}")  # __DATE__ ", " __TIME__


def _zero(buf, off, n):
    if 0 <= off and off + n <= len(buf):
        buf[off:off + n] = b"\0" * n


def normalize(data):
    """The bytes of a build product with what differs between two builds of one commit by design
    zeroed: in a PE file the link time stamps (COFF header, debug directory, export directory), the
    header check sum, the PDB identity (CodeView GUID and age) and the embedded build time
    ("Built: " __DATE__ ", " __TIME__ of the core); in plugins.ver the leading version number, a
    time value by design (feature 029's auto-install trigger)."""
    buf = bytearray(data)
    if data[:2] != b"MZ":
        m = re.match(rb"\d+", data)
        if m:  # plugins.ver: "<time number>\r\n<time number>:<plugin>..."
            buf = bytearray(re.sub(rb"(^|\n)\d+", rb"\g<1>0", data))
        return bytes(buf)
    import struct
    try:
        e = struct.unpack_from("<I", data, 0x3C)[0]
        if data[e:e + 4] != b"PE\0\0":
            return bytes(buf)
        _zero(buf, e + 8, 4)  # COFF TimeDateStamp
        nsec = struct.unpack_from("<H", data, e + 6)[0]
        optsize = struct.unpack_from("<H", data, e + 20)[0]
        opt = e + 24
        magic = struct.unpack_from("<H", data, opt)[0]
        _zero(buf, opt + 64, 4)  # CheckSum
        dd = opt + (112 if magic == 0x20B else 96)
        secs = []
        for k in range(nsec):
            s = opt + optsize + 40 * k
            vsize, va, rawsize, raw = struct.unpack_from("<IIII", data, s + 8)
            secs.append((va, max(vsize, rawsize), raw))

        def off(rva):
            for va, size, raw in secs:
                if va <= rva < va + size:
                    return raw + rva - va
            return -1
        exp_rva = struct.unpack_from("<I", data, dd)[0]
        if exp_rva:
            _zero(buf, off(exp_rva) + 4, 4)  # IMAGE_EXPORT_DIRECTORY.TimeDateStamp
        dbg_rva, dbg_size = struct.unpack_from("<II", data, dd + 6 * 8)
        if dbg_rva:
            d0 = off(dbg_rva)
            for k in range(dbg_size // 28):
                d = d0 + 28 * k
                _zero(buf, d + 4, 4)  # TimeDateStamp
                typ, size, _addr, ptr = struct.unpack_from("<IIII", data, d + 12)
                if typ == 2 and data[ptr:ptr + 4] == b"RSDS":
                    _zero(buf, ptr + 4, 20)  # GUID + age
                elif typ == 16:  # REPRO: a hash of the image
                    _zero(buf, ptr, size)
    except struct.error:
        pass
    for m in BUILT_STAMP.finditer(bytes(buf)):
        _zero(buf, m.start(), m.end() - m.start())
    return bytes(buf)


def check(name, ok, detail=""):
    results.append(ok)
    print("%s %s%s" % ("PASS" if ok else "FAIL", name, (" - " + detail) if detail else ""))


def main(argv):
    if len(argv) < 2 or argv[1] in ("--help", "-h"):
        print(__doc__.strip())
        return 0 if len(argv) >= 2 else 1
    path = argv[1]
    z = zipfile.ZipFile(path)
    infos = z.infolist()
    names = [i.filename for i in infos]
    m = re.search(r"tandemcommander-(\d+\.\d+\.\d+)-x64-portable\.zip$", os.path.basename(path))
    ver = m.group(1) if m else mpz.version()
    top = "TandemCommander-%s-portable" % ver

    roots = sorted({n.split("/", 1)[0] for n in names})
    check("Z1 one top folder", roots == [top] and all("/" in n for n in names), "roots %s" % roots)

    rel = [n[len(top) + 1:] for n in names if n.startswith(top + "/")]
    relset = set(r.lower() for r in rel)
    required = ["tandemcommander.exe", "LICENSE.txt", "README-portable.txt", "doc/third_party.txt",
                "doc/license/license_gpl.txt", "doc/license/license_lgpl21.txt", "doc/license/7zip_license.txt"]
    missing = [r for r in required if r.lower() not in relset]
    plugins = [r for r in rel if r.lower().startswith("plugins/") and r.lower().endswith(".spl")]
    langs = [r for r in rel if r.lower().startswith("lang/") and r.lower().endswith(".slg")]
    check("Z2 required files", not missing and len(plugins) >= 20 and len(langs) >= 8,
          "missing %s, %d plugins, %d languages" % (missing, len(plugins), len(langs)))

    # the contract's list written out here, not the packer's own excluded() - a pattern dropped from
    # the packer must still be caught (test-adequacy review)
    bad_ext = (".pdb", ".lib", ".exp", ".ilk", ".iobj", ".ipdb", ".obj", ".pch", ".idb", ".tlog")
    bad_dir = ("intermediate", "obj", "settings", "saltests")
    leaked = [r for r in rel if r.lower().endswith(bad_ext) or any(d in bad_dir for d in r.lower().split("/")[:-1])]
    salext = [r for r in rel if fnmatch.fnmatch(r.lower(), "*salext*.dll")]
    check("Z3 no excluded file", not leaked and not salext, ", ".join((leaked + salext)[:5]))

    with tempfile.TemporaryDirectory(prefix="tc428zip_") as tmp:
        exe = os.path.join(tmp, "tandemcommander.exe")
        with open(exe, "wb") as f:
            f.write(z.read(top + "/tandemcommander.exe"))
        marker, desc = mpz.exe_edition(exe)
    check("Z4 portable exe", marker and desc.endswith("(portable)"), "marker %s, description '%s'" % (marker, desc))

    files_only = all(not n.endswith("/") for n in names)
    deflated = all(i.compress_type == zipfile.ZIP_DEFLATED for i in infos)
    ordered = names == sorted(names, key=lambda n: n.encode("utf-8"))
    check("Z5 sorted, files only, deflate", ordered and files_only and deflated,
          "sorted %s, files only %s, deflate %s" % (ordered, files_only, deflated))

    stamps = {i.date_time for i in infos}
    check("Z6 one time stamp", len(stamps) == 1, str(sorted(stamps)[:3]))

    readme = z.read(top + "/README-portable.txt").decode("utf-8")
    lines = readme.splitlines()
    check("Z7 README", len(lines) <= 60 and "@VERSION@" not in readme and ver in readme,
          "%d lines, version filled %s" % (len(lines), ver in readme))

    if len(argv) > 2:
        z2 = zipfile.ZipFile(argv[2])
        names2 = [i.filename for i in z2.infolist()]
        check("Z8a same entry list as the second build", names == names2,
              "only here %s, only there %s" % (sorted(set(names) - set(names2))[:3], sorted(set(names2) - set(names))[:3]))
        same, stamped, differ = 0, 0, []
        for i in infos:
            if i.filename not in names2:
                continue
            j = z2.getinfo(i.filename)
            if i.CRC == j.CRC and i.file_size == j.file_size:
                same += 1
                continue
            x, y = z.read(i.filename), z2.read(i.filename)
            if len(x) == len(y) and normalize(x) == normalize(y):
                stamped += 1
            else:
                differ.append(i.filename)
        check("Z8b same program files as the second build", not differ,
              "%d identical, %d differing only in build time stamps, %d differing otherwise %s"
              % (same, stamped, len(differ), differ[:4]))

    total = sum(i.file_size for i in infos)
    print("  %d entries, %.1f MB unpacked, %.1f MB packed" % (len(infos), total / 1048576.0, os.path.getsize(path) / 1048576.0))
    ok = all(results)
    print("ZIP CHECK: %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
