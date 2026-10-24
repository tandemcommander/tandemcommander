"""Feature 339: copies of an xorriso ISO 9660 + HFS+ hybrid (specs/332-uniso-hfs-skipped-records/probe/
mkimg332.sh: a/side.txt only in the HFS+ part, top.txt, zlast/z.txt) whose HFS+ file records say the
content is not in the data fork, for iso339_probe.ps1.

  python -I img339.py dump <src>                 the HFS+ file records (name, parent, flags, forks)
  python -I img339.py <how> <src> <dst> [names]  a copy; names = side (a/side.txt, default), top
                                                 (top.txt in the HFS+ root), comma-separated
      rsrc     the data fork moved to the resource fork, the data fork emptied (TN1150: a file whose
               content is only in its resource fork, as a custom icon file "Icon\\r")
      comp     UF_COMPRESSED (0x20) set in the BSD owner flags, S_IFREG in the file mode, the data fork
               moved to the resource fork (decmpfs type 4: the compressed data in the resource fork)
      compin   UF_COMPRESSED and S_IFREG set, both forks emptied (decmpfs type 3: the data inline in
               the com.apple.decmpfs attribute)
      flag     UF_COMPRESSED and S_IFREG set, the forks kept (macOS reads a compressed file's content
               through decmpfs, never from the data fork)
      nomode   UF_COMPRESSED set, the file mode 0 (TN1150: S_IFMT 0 = the BSD permissions are not
               initialised, the flags are not read), the data fork kept - an ordinary file
      both     the resource fork set to a copy of the data fork (the data fork kept: a file with both
               forks - the data fork is the file's content)
  Only bytes of the named file records change. Prints what it wrote.
"""

import struct
import sys

UF_COMPRESSED = 0x20
S_IFREG = 0o100000
PERM = 32  # HFSPlusCatalogFile: permissions (ownerID 4, groupID 4, adminFlags 1, ownerFlags 1, fileMode 2, special 4)
DATA = 88  # dataFork (logicalSize 8, clumpSize 4, totalBlocks 4, extents 8 x 8)
RSRC = 168  # resourceFork
FORK = 80


def be16(b, o):
    return struct.unpack_from(">H", b, o)[0]


def be32(b, o):
    return struct.unpack_from(">I", b, o)[0]


def find_vh(img):
    for o in range(1024, len(img) - 512, 512):
        if img[o : o + 4] == b"H+\x00\x04":
            return o
    raise SystemExit("no HFS+ volume header")


def catalog(img):
    vh = find_vh(img)
    vol = vh - 1024
    block = be32(img, vh + 40)
    fork = vh + 272
    size = struct.unpack_from(">Q", img, fork)[0]
    start, count = be32(img, fork + 16), be32(img, fork + 20)
    if count * block < size:
        raise SystemExit("the catalog has more than one extent")
    base = vol + start * block
    return base, be16(img, base + 14 + 18), be32(img, base + 14 + 10)


def records(img):
    base, ns, node = catalog(img)
    out = []
    while node:
        p = base + node * ns
        n = be16(img, p + 10)
        for i in range(n):
            r = p + be16(img, p + ns - 2 * (i + 1))
            klen = be16(img, r)
            nlen = be16(img, r + 6)
            out.append(dict(at=r, body=r + 2 + klen, parent=be32(img, r + 2),
                            name=img[r + 8 : r + 8 + 2 * nlen].decode("utf-16-be", "replace"),
                            type=be16(img, r + 2 + klen)))
        node = be32(img, p)
    return out


def file_record(img, which):
    recs = records(img)
    folders = {be32(img, r["body"] + 8): r["name"] for r in recs if r["type"] == 1}
    if which == "side":
        hits = [r for r in recs if r["type"] == 2 and r["name"] == "side.txt" and folders.get(r["parent"]) == "a"]
    elif which == "top":
        hits = [r for r in recs if r["type"] == 2 and r["name"] == "top.txt" and r["parent"] == 2]
    else:
        raise SystemExit("unknown file " + which)
    if len(hits) != 1:
        raise SystemExit("%s's file record not found once: %d" % (which, len(hits)))
    return hits[0]


def describe(img, r):
    b = r["body"]
    return "owner flags %#x mode %#o data %d rsrc %d" % (img[b + PERM + 9], be16(img, b + PERM + 10),
                                                        struct.unpack_from(">Q", img, b + DATA)[0],
                                                        struct.unpack_from(">Q", img, b + RSRC)[0])


def main(argv):
    if len(argv) == 3 and argv[1] == "dump":
        img = open(argv[2], "rb").read()
        for r in records(img):
            if r["type"] == 2:
                print("%s parent %d: %s" % (ascii(r["name"]), r["parent"], describe(img, r)))
        return 0
    if len(argv) not in (4, 5) or argv[1] not in ("rsrc", "comp", "compin", "flag", "nomode", "both"):
        print(__doc__)
        return 2
    how, src, dst = argv[1:4]
    names = (argv[4] if len(argv) == 5 else "side").split(",")
    img = bytearray(open(src, "rb").read())
    for which in names:
        r = file_record(img, which)
        b = r["body"]
        before = describe(img, r)
        data = bytes(img[b + DATA : b + DATA + FORK])
        if how in ("rsrc", "comp"):
            img[b + RSRC : b + RSRC + FORK] = data
            img[b + DATA : b + DATA + FORK] = bytes(FORK)
        elif how == "compin":
            img[b + RSRC : b + RSRC + FORK] = bytes(FORK)
            img[b + DATA : b + DATA + FORK] = bytes(FORK)
        elif how == "both":
            img[b + RSRC : b + RSRC + FORK] = data
        if how in ("comp", "compin", "flag"):
            img[b + PERM + 9] |= UF_COMPRESSED
            struct.pack_into(">H", img, b + PERM + 10, (be16(img, b + PERM + 10) & 0o7777) | S_IFREG
                             if be16(img, b + PERM + 10) & 0o170000 == 0 else be16(img, b + PERM + 10))
        elif how == "nomode":
            img[b + PERM + 9] |= UF_COMPRESSED
            struct.pack_into(">H", img, b + PERM + 10, 0)
        print("%s: %s.txt %s -> %s" % (how, which, before, describe(img, r)))
    open(dst, "wb").write(bytes(img))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
