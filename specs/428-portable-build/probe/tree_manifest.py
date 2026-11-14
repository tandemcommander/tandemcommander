r"""Feature 428 (SC-010): manifest of a build output tree, and comparison of two manifests.

Usage:
  python tree_manifest.py make <tree> <out.json>
  python tree_manifest.py compare <before.json> <after.json>

For every file: relative path, size, SHA-256 of the bytes and, for PE files (.exe .dll .spl .slg),
a "normalized" SHA-256 with the fields a rebuild changes without a code change zeroed: the COFF
TimeDateStamp, the optional-header CheckSum, the security directory (signature), and every debug
directory entry (time stamp + the CodeView GUID / age / path it points to). Compare reports files
added / removed and files whose normalized hash differs. Debug-only scaffolding (Intermediate\,
saltests\, *.pdb, *.ilk, *.lib, *.exp, *.iobj, *.ipdb, plugins.ver) is skipped.
"""

import hashlib
import json
import os
import struct
import sys

SKIP_DIRS = {"intermediate", "saltests"}
SKIP_EXT = {".pdb", ".ilk", ".lib", ".exp", ".iobj", ".ipdb", ".obj", ".pch", ".idb"}
SKIP_NAMES = {"plugins.ver"}
PE_EXT = {".exe", ".dll", ".spl", ".slg"}


def normalized_pe(data: bytes) -> bytes:
    b = bytearray(data)
    try:
        pe = struct.unpack_from("<I", b, 0x3C)[0]
        if b[pe:pe + 4] != b"PE\0\0":
            return bytes(b)
        coff = pe + 4
        struct.pack_into("<I", b, coff + 4, 0)  # TimeDateStamp
        nsec = struct.unpack_from("<H", b, coff + 2)[0]
        opt_size = struct.unpack_from("<H", b, coff + 16)[0]
        opt = coff + 20
        magic = struct.unpack_from("<H", b, opt)[0]
        struct.pack_into("<I", b, opt + 64, 0)  # CheckSum
        dd = opt + (96 if magic == 0x10B else 112)
        ndd = struct.unpack_from("<I", b, dd - 4)[0]
        sections = []
        sec = opt + opt_size
        for i in range(nsec):
            va, vsize, raw_size, raw_ptr = (struct.unpack_from("<I", b, sec + 12)[0],
                                            struct.unpack_from("<I", b, sec + 8)[0],
                                            struct.unpack_from("<I", b, sec + 16)[0],
                                            struct.unpack_from("<I", b, sec + 20)[0])
            sections.append((va, max(vsize, raw_size), raw_ptr))
            sec += 40

        def rva_to_off(rva):
            for va, size, ptr in sections:
                if va <= rva < va + size:
                    return ptr + (rva - va)
            return None

        # security directory (index 4) holds a file offset; drop the signature bytes entirely
        if ndd > 4:
            sec_off, sec_size = struct.unpack_from("<II", b, dd + 4 * 8)
            struct.pack_into("<II", b, dd + 4 * 8, 0, 0)
            if sec_off and sec_size and sec_off + sec_size <= len(b):
                del b[sec_off:sec_off + sec_size]
        # debug directory (index 6)
        if ndd > 6:
            dbg_rva, dbg_size = struct.unpack_from("<II", b, dd + 6 * 8)
            off = rva_to_off(dbg_rva) if dbg_rva else None
            if off is not None:
                for e in range(dbg_size // 28):
                    ent = off + e * 28
                    struct.pack_into("<I", b, ent + 4, 0)  # TimeDateStamp
                    size_of_data = struct.unpack_from("<I", b, ent + 16)[0]
                    ptr_raw = struct.unpack_from("<I", b, ent + 24)[0]
                    if ptr_raw and size_of_data and ptr_raw + size_of_data <= len(b):
                        b[ptr_raw:ptr_raw + size_of_data] = bytes(size_of_data)
    except (struct.error, IndexError):
        pass
    return bytes(b)


def make(tree: str, out: str) -> int:
    files = {}
    for root, dirs, names in os.walk(tree):
        dirs[:] = [d for d in dirs if d.lower() not in SKIP_DIRS]
        for n in names:
            ext = os.path.splitext(n)[1].lower()
            if ext in SKIP_EXT or n.lower() in SKIP_NAMES:
                continue
            p = os.path.join(root, n)
            rel = os.path.relpath(p, tree).replace("\\", "/")
            with open(p, "rb") as f:
                data = f.read()
            entry = {"size": len(data), "sha256": hashlib.sha256(data).hexdigest()}
            if ext in PE_EXT:
                entry["norm"] = hashlib.sha256(normalized_pe(data)).hexdigest()
            files[rel] = entry
    with open(out, "w", encoding="utf-8") as f:
        json.dump({"tree": tree, "files": files}, f, indent=1, sort_keys=True)
    print(f"{len(files)} files -> {out}")
    return 0


def compare(a: str, b: str) -> int:
    with open(a, encoding="utf-8") as f:
        fa = json.load(f)["files"]
    with open(b, encoding="utf-8") as f:
        fb = json.load(f)["files"]
    added = sorted(set(fb) - set(fa))
    removed = sorted(set(fa) - set(fb))
    changed = []
    for k in sorted(set(fa) & set(fb)):
        x, y = fa[k], fb[k]
        if x.get("norm") or y.get("norm"):
            if x.get("norm") != y.get("norm"):
                changed.append(k)
        elif x["sha256"] != y["sha256"]:
            changed.append(k)
    for k in added:
        print("ADDED   " + k)
    for k in removed:
        print("REMOVED " + k)
    for k in changed:
        print("CHANGED " + k)
    print(f"files {len(fa)} -> {len(fb)}: added {len(added)}, removed {len(removed)}, changed {len(changed)}")
    return 0 if not (added or removed or changed) else 1


if __name__ == "__main__":
    if len(sys.argv) == 4 and sys.argv[1] == "make":
        sys.exit(make(sys.argv[2], sys.argv[3]))
    if len(sys.argv) == 4 and sys.argv[1] == "compare":
        sys.exit(compare(sys.argv[2], sys.argv[3]))
    print(__doc__)
    sys.exit(0 if len(sys.argv) > 1 and sys.argv[1] in ("-h", "--help") else 2)
