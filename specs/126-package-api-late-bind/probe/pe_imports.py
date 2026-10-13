#!/usr/bin/env python3
"""Feature 126 (GitHub issue #6): the import tables of PE files, without any tool
of the build chain - an independent look at what the Windows loader must find
before a single instruction of the program runs.

    pe_imports.py list <file.exe|dll|spl>          DLL!Function lines (static imports)
    pe_imports.py delay <file>                      the same for delay-load imports
    pe_imports.py find <dir> <Function> [...]       which PE files under <dir> import any
                                                    of the functions (static or delay)
    pe_imports.py diff <old> <new>                  static imports removed / added
    pe_imports.py check <dir> <Function> [...]      exit code = number of files under <dir>
                                                    that import one of the functions STATICALLY

Only PE32+ (x64) and PE32 files with ordinary import directories are understood;
that is all the release tree holds. Pure standard library.
"""
import os
import struct
import sys


class Pe:
    def __init__(self, path):
        self.path = path
        with open(path, "rb") as f:
            self.d = f.read()
        d = self.d
        if d[:2] != b"MZ":
            raise ValueError("not a PE file")
        pe = struct.unpack_from("<I", d, 0x3C)[0]
        if d[pe:pe + 4] != b"PE\0\0":
            raise ValueError("not a PE file")
        nsec = struct.unpack_from("<H", d, pe + 6)[0]
        optsize = struct.unpack_from("<H", d, pe + 20)[0]
        opt = pe + 24
        magic = struct.unpack_from("<H", d, opt)[0]
        self.plus = magic == 0x20B
        ddir = opt + (112 if self.plus else 96)
        self.dirs = [struct.unpack_from("<II", d, ddir + 8 * i) for i in range(16)]
        sec = opt + optsize
        self.secs = []
        for i in range(nsec):
            vsize, va, rsize, raw = struct.unpack_from("<IIII", d, sec + 40 * i + 8)
            self.secs.append((va, max(vsize, rsize), raw))

    def off(self, rva):
        for va, size, raw in self.secs:
            if va <= rva < va + size:
                return raw + rva - va
        raise ValueError("rva %x outside the sections" % rva)

    def cstr(self, rva):
        o = self.off(rva)
        e = self.d.index(b"\0", o)
        return self.d[o:e].decode("ascii", "replace")

    def _thunks(self, rva):
        names = []
        if rva == 0:
            return names
        o = self.off(rva)
        size = 8 if self.plus else 4
        fmt = "<Q" if self.plus else "<I"
        top = 1 << (63 if self.plus else 31)
        while True:
            v = struct.unpack_from(fmt, self.d, o)[0]
            if v == 0:
                break
            if v & top:
                names.append("#%d" % (v & 0xFFFF))
            else:
                names.append(self.cstr((v & 0x7FFFFFFF) + 2))
            o += size
        return names

    def imports(self):
        """[(dll, function)] of the import directory (what the loader resolves at start)."""
        rva, size = self.dirs[1]
        out = []
        if rva == 0:
            return out
        o = self.off(rva)
        while True:
            ilt, _, _, name, iat = struct.unpack_from("<IIIII", self.d, o)
            if ilt == 0 and name == 0 and iat == 0:
                break
            dll = self.cstr(name)
            for fn in self._thunks(ilt or iat):
                out.append((dll, fn))
            o += 20
        return out

    def delay_imports(self):
        """[(dll, function)] of the delay-load directory (resolved at the first call)."""
        rva, size = self.dirs[13]
        out = []
        if rva == 0:
            return out
        o = self.off(rva)
        while True:
            attrs, name, hmod, iat, int_, bound, unload, stamp = struct.unpack_from("<IIIIIIII", self.d, o)
            if name == 0:
                break
            dll = self.cstr(name)
            for fn in self._thunks(int_):
                out.append((dll, fn))
            o += 32
        return out


def pe_files(root):
    for base, _, files in os.walk(root):
        for n in sorted(files):
            if n.lower().endswith((".exe", ".dll", ".spl", ".slg")):
                yield os.path.join(base, n)


def fmt(pairs):
    return sorted("%s!%s" % (d.lower(), f) for d, f in pairs)


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    cmd = argv[1]
    if cmd == "list":
        print("\n".join(fmt(Pe(argv[2]).imports())))
        return 0
    if cmd == "delay":
        print("\n".join(fmt(Pe(argv[2]).delay_imports())))
        return 0
    if cmd in ("find", "check"):
        wanted = set(argv[3:])
        static_hits = 0
        files = 0
        for p in pe_files(argv[2]):
            try:
                pe = Pe(p)
                st = [x for x in pe.imports() if x[1] in wanted]
                dl = [x for x in pe.delay_imports() if x[1] in wanted]
            except Exception as e:  # a resource-only module without sections we understand
                print("%s: not read (%s)" % (os.path.relpath(p, argv[2]), e))
                continue
            files += 1
            if st:
                static_hits += 1
            for kind, hits in (("static", st), ("delay", dl)):
                for d, f in hits:
                    print("%s: %s import %s!%s" % (os.path.relpath(p, argv[2]), kind, d, f))
        print("%d PE files read under %s; files with a static import of %s: %d" % (files, argv[2], ", ".join(sorted(wanted)), static_hits))
        return static_hits if cmd == "check" else 0
    if cmd == "diff":
        a = set(fmt(Pe(argv[2]).imports()))
        b = set(fmt(Pe(argv[3]).imports()))
        for x in sorted(a - b):
            print("- " + x)
        for x in sorted(b - a):
            print("+ " + x)
        print("static imports: %d -> %d; removed %d, added %d" % (len(a), len(b), len(a - b), len(b - a)))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv))
