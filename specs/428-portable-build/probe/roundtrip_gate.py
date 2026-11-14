r"""Feature 428 gate test (T009): the portable store's dump -> parse round trip loses nothing.

Usage: python roundtrip_gate.py <portable Debug tandemcommander.exe> [--work <dir>]

1. copies the real HKCU\Software\Tandem Commander\Settings (opened read-only, never written) into
   a private hive src.dat, and adds a key __gate428 with synthetic values: every value type, empty
   values, a 1 MB binary, 255-character and non-BMP names, strings with the program folder (they
   must come back identical after $(SalDir) and back), a literal $(SalDir) typed by a user, an
   embedded NUL, a string without its terminator;
2. runs  tandemcommander.exe --portabletest-roundtrip src.dat dump.reg dst.dat <programDir>
   (the store's own DumpSession -> settings file -> LoadSettingsFile -> Seed);
3. compares src.dat and dst.dat recursively by raw bytes: every key, value name, type and data.

Exit code 0 = 0 differences. Every difference is printed. Documented normalizations are listed
separately and do not fail the gate: an empty REG_SZ / REG_MULTI_SZ gets its terminator, a REG_SZ
ends at its first NUL (Export Configuration does the same since 174), the program folder inside a
value takes the folder's own spelling. A $(SalDir) typed by the user comes back exactly as typed.
"""

import ctypes
import os
import subprocess
import sys
from ctypes import wintypes

adv = ctypes.WinDLL("advapi32", use_last_error=True)
HKEY = wintypes.HKEY
HKCU = HKEY(0x80000001)
KEY_READ = 0x20019
KEY_ALL = 0xF003F
REG_NONE, REG_SZ, REG_EXPAND_SZ, REG_BINARY, REG_DWORD, REG_MULTI_SZ, REG_QWORD = 0, 1, 2, 3, 4, 7, 11

adv.RegLoadAppKeyW.argtypes = [wintypes.LPCWSTR, ctypes.POINTER(HKEY), wintypes.DWORD, wintypes.DWORD, wintypes.DWORD]
adv.RegOpenKeyExW.argtypes = [HKEY, wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.POINTER(HKEY)]
adv.RegCreateKeyExW.argtypes = [HKEY, wintypes.LPCWSTR, wintypes.DWORD, wintypes.LPCWSTR, wintypes.DWORD,
                                wintypes.DWORD, ctypes.c_void_p, ctypes.POINTER(HKEY), ctypes.POINTER(wintypes.DWORD)]
adv.RegCloseKey.argtypes = [HKEY]
adv.RegEnumKeyExW.argtypes = [HKEY, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD),
                              ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p, ctypes.c_void_p]
adv.RegEnumValueW.argtypes = [HKEY, wintypes.DWORD, wintypes.LPWSTR, ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p,
                              ctypes.POINTER(wintypes.DWORD), ctypes.c_void_p, ctypes.POINTER(wintypes.DWORD)]
adv.RegSetValueExW.argtypes = [HKEY, wintypes.LPCWSTR, wintypes.DWORD, wintypes.DWORD, ctypes.c_void_p, wintypes.DWORD]
adv.RegFlushKey.argtypes = [HKEY]

ROOT = "Software\\Tandem Commander\\Settings"


def check(rc, what):
    if rc != 0:
        raise SystemExit("%s failed: %d" % (what, rc))


def load(path):
    h = HKEY()
    check(adv.RegLoadAppKeyW(path, ctypes.byref(h), KEY_ALL, 0, 0), "RegLoadAppKey " + path)
    return h


def open_key(parent, sub, access=KEY_READ):
    h = HKEY()
    rc = adv.RegOpenKeyExW(parent, sub, 0, access, ctypes.byref(h))
    return h if rc == 0 else None


def create_key(parent, sub):
    h = HKEY()
    d = wintypes.DWORD()
    check(adv.RegCreateKeyExW(parent, sub, 0, None, 0, KEY_ALL, None, ctypes.byref(h), ctypes.byref(d)), "create " + sub)
    return h


def subkeys(h):
    out = []
    i = 0
    while True:
        buf = ctypes.create_unicode_buffer(512)
        n = wintypes.DWORD(512)
        rc = adv.RegEnumKeyExW(h, i, buf, ctypes.byref(n), None, None, None, None)
        if rc != 0:
            break
        out.append(buf.value)
        i += 1
    return out


def values(h):
    out = {}
    i = 0
    while True:
        name = ctypes.create_unicode_buffer(16384)
        nl = wintypes.DWORD(16384)
        t = wintypes.DWORD()
        size = wintypes.DWORD(0)
        rc = adv.RegEnumValueW(h, i, name, ctypes.byref(nl), None, ctypes.byref(t), None, ctypes.byref(size))
        if rc != 0:
            break
        data = (ctypes.c_ubyte * max(size.value, 1))()
        nl = wintypes.DWORD(16384)
        size2 = wintypes.DWORD(size.value)
        check(adv.RegEnumValueW(h, i, name, ctypes.byref(nl), None, ctypes.byref(t), data, ctypes.byref(size2)), "enum value")
        out[name.value] = (t.value, bytes(data[:size2.value]))
        i += 1
    return out


def set_raw(h, name, typ, data):
    buf = (ctypes.c_ubyte * max(len(data), 1)).from_buffer_copy(data if data else b"\0")
    check(adv.RegSetValueExW(h, name, 0, typ, buf, len(data)), "set " + name)


def copy_tree(src, dst):
    for name, (t, data) in values(src).items():
        set_raw(dst, name, t, data)
    for k in subkeys(src):
        s = open_key(src, k)
        d = create_key(dst, k)
        copy_tree(s, d)
        adv.RegCloseKey(s)
        adv.RegCloseKey(d)


def sz(s):
    return (s + "\0").encode("utf-16-le")


def add_synthetic(settings, program_dir):
    g = create_key(settings, "__gate428")
    set_raw(g, "sz plain", REG_SZ, sz("hello"))
    set_raw(g, "sz empty", REG_SZ, sz(""))
    set_raw(g, "sz czech", REG_SZ, sz("P\u0159\u00edli\u0161 \u017elu\u0165ou\u010dk\u00fd k\u016f\u0148"))
    set_raw(g, "sz non-BMP \U0001F4C1", REG_SZ, sz("folder \U0001F4C1 \U00020000"))
    set_raw(g, "sz program dir", REG_SZ, sz(program_dir + "\\tools\\x.exe"))
    set_raw(g, "sz program dir itself", REG_SZ, sz(program_dir))
    set_raw(g, "sz program dir quoted cmd", REG_SZ, sz('"' + program_dir + '\\a b\\x.exe" /p "' + program_dir + '"'))
    set_raw(g, "sz longer name not inside", REG_SZ, sz(program_dir + "2\\x.exe"))
    set_raw(g, "sz other case", REG_SZ, sz(program_dir.upper() + "\\Y.EXE"))
    set_raw(g, "sz user typed saldir", REG_SZ, sz("$(SalDir)\\typed.exe"))
    set_raw(g, "expand sz", REG_EXPAND_SZ, sz("%USERPROFILE%\\x;" + program_dir + "\\y"))
    set_raw(g, "multi sz", REG_MULTI_SZ, sz("one") + sz(program_dir + "\\two") + sz("\U0001F600") + b"\0\0")
    set_raw(g, "multi sz empty", REG_MULTI_SZ, b"\0\0")
    set_raw(g, "binary 200KB", REG_BINARY, bytes((i * 7 + 3) & 0xFF for i in range(200 * 1024)))  # 1 MB: the registry refuses it (1450)
    set_raw(g, "binary empty", REG_BINARY, b"")
    set_raw(g, "dword", REG_DWORD, (0xDEADBEEF).to_bytes(4, "little"))
    set_raw(g, "qword", REG_QWORD, (0x0123456789ABCDEF).to_bytes(8, "little"))
    set_raw(g, "", REG_SZ, sz("the default value"))
    set_raw(g, "n" * 255, REG_DWORD, (7).to_bytes(4, "little"))
    set_raw(g, "sz embedded NUL", REG_SZ, "a\0b\0".encode("utf-16-le"))
    set_raw(g, "sz no terminator", REG_SZ, "abc".encode("utf-16-le"))
    k = create_key(g, "key \u010d\u0159 \U0001F4C1")
    set_raw(k, "x", REG_DWORD, (1).to_bytes(4, "little"))
    adv.RegCloseKey(k)
    adv.RegCloseKey(g)


PROGRAM_DIR = None  # set by main: the folder the seam is told the program lives in


def normalization(ta, da, tb, db, where=""):
    """The name of a documented normalization that turns (ta, da) into (tb, db), or None."""
    if ta != tb:
        return None
    if ta in (REG_SZ, REG_EXPAND_SZ):
        if da == b"" and db == b"\0\0":
            return "an empty string gets its terminator"
        units = [da[i:i + 2] for i in range(0, len(da) - 1, 2)]
        if b"\0\0" in units[:-1]:  # an embedded NUL before the end
            first = units.index(b"\0\0")
            if db == b"".join(units[:first]) + b"\0\0":
                return "a REG_SZ ends at its first NUL (as Export Configuration since 174)"
        try:
            sa, sb = da.decode("utf-16-le"), db.decode("utf-16-le")
        except UnicodeDecodeError:
            return None
        # only the one synthetic value written in another case, and only to the folder's spelling
        if (sa != sb and sa.lower() == sb.lower() and where.endswith("\\__gate428\\'sz other case'")
                and PROGRAM_DIR is not None and sb.startswith(PROGRAM_DIR)):
            return "the program folder takes the folder's own spelling (case)"
    if ta == REG_MULTI_SZ and da == b"\0\0" and db == b"\0\0\0\0":
        return "an empty list gets its terminator"
    return None


def compare(a, b, path, diffs, normalized=None):
    va, vb = values(a), values(b)
    for n in sorted(set(va) | set(vb)):
        if n not in vb:
            diffs.append("MISSING value %s\\%r" % (path, n))
        elif n not in va:
            diffs.append("EXTRA value %s\\%r" % (path, n))
        elif va[n] != vb[n]:
            ta, da = va[n]
            tb, db = vb[n]
            why = normalization(ta, da, tb, db, "%s\\%r" % (path, n))
            if why is not None and normalized is not None:
                normalized.append("%s\\%r: %s" % (path, n, why))
                continue
            diffs.append("DIFFERENT value %s\\%r: type %d/%d, %d/%d bytes, %r / %r" % (path, n, ta, tb, len(da), len(db), da[:80], db[:80]))
    ka, kb = set(subkeys(a)), set(subkeys(b))
    for k in sorted(ka | kb):
        if k not in kb:
            diffs.append("MISSING key %s\\%s" % (path, k))
            continue
        if k not in ka:
            diffs.append("EXTRA key %s\\%s" % (path, k))
            continue
        sa, sb = open_key(a, k), open_key(b, k)
        compare(sa, sb, path + "\\" + k, diffs, normalized)
        adv.RegCloseKey(sa)
        adv.RegCloseKey(sb)


def count(h):
    keys, vals = 1, len(values(h))
    for k in subkeys(h):
        s = open_key(h, k)
        a, b = count(s)
        adv.RegCloseKey(s)
        keys += a
        vals += b
    return keys, vals


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print(__doc__)
        return 0 if len(sys.argv) > 1 else 2
    exe = os.path.abspath(sys.argv[1])
    work = os.path.join(os.environ["TEMP"], "tc428", "gate")
    if "--work" in sys.argv:
        work = sys.argv[sys.argv.index("--work") + 1]
    os.makedirs(work, exist_ok=True)
    for f in os.listdir(work):
        os.remove(os.path.join(work, f))
    src_path, dump_path, dst_path = (os.path.join(work, n) for n in ("src.dat", "dump.reg", "dst.dat"))
    program_dir = "E:\\Fake Portable\\Tandem \u010c\U0001F4C1"
    global PROGRAM_DIR
    PROGRAM_DIR = program_dir

    real = open_key(HKCU, ROOT, KEY_READ)
    if real is None:
        raise SystemExit("no configuration under HKCU\\" + ROOT + " to copy")
    src = load(src_path)
    settings = create_key(src, ROOT)
    copy_tree(real, settings)
    adv.RegCloseKey(real)
    add_synthetic(settings, program_dir)
    adv.RegCloseKey(settings)
    keys, vals = count(src)
    adv.RegFlushKey(src)
    adv.RegCloseKey(src)
    print("source hive: %d keys, %d values (real configuration + __gate428)" % (keys, vals))

    rc = subprocess.run([exe, "--portabletest-roundtrip", src_path, dump_path, dst_path, program_dir]).returncode
    print("seam exit code:", rc)
    if rc != 0:
        return 1
    with open(dump_path, "rb") as f:
        dump = f.read().decode("utf-16")
    print("dump: %d characters; $(PortableDir): %d (strings; REG_EXPAND_SZ / REG_MULTI_SZ are hex); user-typed $(SalDir): %d; "
          "program folder left in the text: %d" % (len(dump), dump.count("$(PortableDir)"), dump.count("$(SalDir)"),
                                                  dump.lower().count(program_dir.lower().replace("\\", "\\\\"))))

    a, b = load(src_path), load(dst_path)
    diffs = []
    normalized = []
    compare(a, b, "", diffs, normalized)
    adv.RegCloseKey(a)
    adv.RegCloseKey(b)
    for d in normalized:
        print("NORMALIZED (documented) " + d)
    for d in diffs:
        print(d)
    print("normalized: %d, differences: %d" % (len(normalized), len(diffs)))
    # the dump must really carry the token: each synthetic value inside the folder names it, the one
    # whose folder only starts like the program folder ("...2\\x.exe") keeps its absolute path
    lines = {}
    for line in dump.split("\r\n"):
        if line.startswith('"sz '):
            lines[line.split('"=', 1)[0][1:]] = line
    want_token = ["sz program dir", "sz program dir itself", "sz program dir quoted cmd", "sz other case"]
    missing = [n for n in want_token if "$(PortableDir)" not in lines.get(n, "")]
    quoted = lines.get("sz program dir quoted cmd", "")
    prefix = lines.get("sz longer name not inside", "")
    token_ok = not missing and quoted.count("$(PortableDir)") == 2 and "$(PortableDir)" not in prefix and \
        (program_dir + "2").lower().replace("\\", "\\\\") in prefix.lower()
    print("token check: %s (missing in %s; quoted command %d tokens; prefix-only folder kept absolute %s)"
          % ("PASS" if token_ok else "FAIL", missing or "none", quoted.count("$(PortableDir)"),
             "$(PortableDir)" not in prefix))
    ok = not diffs and token_ok
    print("RESULT: %s" % ("PASS" if ok else "FAIL"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
