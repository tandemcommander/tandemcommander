"""Feature 400: the images of iso400_probe.ps1 - later folders after a folder that cannot be read.

Every command of specs/330-iso-unreadable-folder/probe/img330.py (loaded from there), and:

  python -I img400.py isotwo <rd2.iso> <out>   ISO 9660 (genisoimage -R seed of a/side.txt, b/b.txt,
                                               top.txt, zlast/z.txt): the records of folders A and B
                                               in the root point past the end of the image (two
                                               different sectors)
  python -I img400.py xboxtwo <out>            an XDVDFS image of a/side.txt, b/b.txt, top.txt,
                                               zlast/z.txt with folders a and b starting past the end
                                               (two different sectors)
  python -I img400.py xboxloop <out>           an XDVDFS image of a/, top.txt, zlast/z.txt whose folder
                                               a holds 'bad' (a folder past the end) and then 'l1' and
                                               'l2' - two folders pointing back to a
  python -I img400.py xboxloop2 <out>          the same without 'bad' (no folder that cannot be read)
  python -I img400.py xboxshare <out>          (review 1) an XDVDFS image whose root holds 'b' (a folder at
                                               sector S, 2048 bytes), 'a' (the same sector S, 4096 bytes)
                                               and top.txt; S holds a1.txt, S + 1 holds a2.txt - nothing
                                               is damaged, a/a2.txt is reached only through 'a'
  python -I img400.py xboxmany <out>           (review 1) an XDVDFS image whose root holds 300 folders
                                               past the end, then top.txt and zlast/z.txt
  python -I img400.py udfhlink <ud.iso> <out>  (review 2) UDF part of ud.iso: zlast's identifier in the
                                               root points to folder a's file entry (two folders name one
                                               directory; nothing damaged)
  python -I img400.py xboxhlink <out>          (review 2) an XDVDFS root of a (sector S, 2048 bytes), b (the
                                               same), top.txt; S holds x.txt (nothing damaged)
  python -I img400.py udfloop <ud.iso> <out>   UDF part of a genisoimage -udf hybrid: side.txt's
                                               identifier in folder a becomes a folder whose ICB is
                                               folder a's own file entry (a folder inside itself)

Each prints what it wrote and exits 3 without writing when the layout is not the expected one.
"""

import importlib.util
import os
import struct
import sys

_here = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "img330", os.path.join(_here, "..", "..", "330-iso-unreadable-folder", "probe", "img330.py"))
img330 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(img330)

SECTOR = img330.SECTOR
FAR = img330.FAR
refuse = img330.refuse
le32 = img330.le32
le16 = img330.le16


def cmd_isotwo(src, dst):
    b = bytearray(open(src, "rb").read())
    root, size = img330.iso_root(b)
    done = []
    for k, name in enumerate((b"A", b"B")):
        o = img330.iso_find(b, root, size, name, True)
        img330.set_both32(b, o + 2, FAR + k)  # two different sectors: two failures, not a folder met again
        done.append("%s at %d -> %#x" % (name.decode(), o, FAR + k))
    open(dst, "wb").write(b)
    print("isotwo: folders %s" % ", ".join(done))
    return 0


def write_xbox(dst, tree, label):
    """tree: [(name, content bytes | None for a folder, children | 'FAR' | ('UP', depth))]"""
    sectors = {}
    nxt = [33]

    def alloc():
        s = nxt[0]
        nxt[0] += 1
        return s

    def build_dir(entries, parents):
        sec = alloc()
        blob = bytearray()
        for name, content, children in entries:
            raw = name.encode("ascii")
            if content is None:
                if children == "FAR":
                    start = FAR
                elif isinstance(children, tuple) and children[0] == "FAR":
                    start = FAR + children[1]
                elif isinstance(children, tuple) and children[0] == "UP":
                    start = parents[-1 - children[1]] if children[1] else sec
                else:
                    start = build_dir(children, parents + [sec])
                size, attr = SECTOR, 0x10
            else:
                start = alloc()
                sectors[start] = content
                size, attr = len(content), 0x80
            ent = struct.pack("<HHIIBB", 0, 0, start, size, attr, len(raw)) + raw
            ent += b"\xff" * ((4 - len(ent) % 4) % 4)
            blob += ent
        sectors[sec] = bytes(blob) + b"\xff" * (SECTOR - len(blob))
        return sec

    root = build_dir(tree, [])
    img = bytearray(SECTOR * nxt[0])
    vd = 32 * SECTOR
    img[vd : vd + 20] = b"MICROSOFT*XBOX*MEDIA"
    img[vd + 20 : vd + 28] = struct.pack("<II", root, SECTOR)
    img[vd + 0x7EC : vd + 0x7EC + 20] = b"MICROSOFT*XBOX*MEDIA"
    for s, content in sectors.items():
        img[s * SECTOR : s * SECTOR + len(content)] = content
    open(dst, "wb").write(bytes(img))
    print("%s: %d sectors, root at %d" % (label, nxt[0], root))
    return 0


def cmd_xboxtwo(dst):
    tree = [
        ("a", None, "FAR"),
        ("b", None, ("FAR", 1)),
        ("top.txt", b"TOP", None),
        ("zlast", None, [("z.txt", b"Z", None)]),
    ]
    return write_xbox(dst, tree, "xboxtwo (folders a at %#x, b at %#x)" % (FAR, FAR + 1))


def cmd_xboxloop(dst, damaged):
    inner = ([("bad", None, "FAR")] if damaged else []) + [("l1", None, ("UP", 0)), ("l2", None, ("UP", 0))]
    tree = [
        ("a", None, inner),
        ("top.txt", b"TOP", None),
        ("zlast", None, [("z.txt", b"Z", None)]),
    ]
    label = "xboxloop" if damaged else "xboxloop2"
    return write_xbox(dst, tree, label + " (a holds %sl1, l2 -> a)" % ("bad -> %#x, " % FAR if damaged else ""))


# review 1 of feature 400 (the reviewer's gen.py): images written entry by entry


def xent(name, start, size, attr):
    raw = name.encode("ascii")
    e = struct.pack("<HHIIBB", 0, 0, start, size, attr, len(raw)) + raw
    return e + b"\xff" * ((4 - len(e) % 4) % 4)


def xpad(b):
    return bytes(b) + b"\xff" * (SECTOR - len(b))


def write_sectors(dst, nsect, root, rootsize, sectors):
    img = bytearray(SECTOR * nsect)
    vd = 32 * SECTOR
    img[vd : vd + 20] = b"MICROSOFT*XBOX*MEDIA"
    img[vd + 20 : vd + 28] = struct.pack("<II", root, rootsize)
    img[vd + 0x7EC : vd + 0x7EC + 20] = b"MICROSOFT*XBOX*MEDIA"
    for s, c in sectors.items():
        img[s * SECTOR : s * SECTOR + len(c)] = c
    open(dst, "wb").write(bytes(img))


def cmd_xboxshare(dst):
    root, S, a1, a2, top = 33, 34, 36, 37, 38
    sectors = {
        root: xpad(xent("b", S, SECTOR, 0x10) + xent("a", S, 2 * SECTOR, 0x10) + xent("top.txt", top, 3, 0x80)),
        S: xpad(xent("a1.txt", a1, 2, 0x80)),
        S + 1: xpad(xent("a2.txt", a2, 2, 0x80)),
        a1: b"A1",
        a2: b"A2",
        top: b"TOP",
    }
    write_sectors(dst, 40, root, SECTOR, sectors)
    print("xboxshare: b (sector %d, %d bytes), a (sector %d, %d bytes), top.txt" % (S, SECTOR, S, 2 * SECTOR))
    return 0


def cmd_xboxmany(dst):
    zl, z, top = 40, 41, 42
    secs = []
    cur = bytearray()
    ents = [xent("d%03d" % i, FAR + i, SECTOR, 0x10) for i in range(300)]
    ents += [xent("top.txt", top, 3, 0x80), xent("zlast", zl, SECTOR, 0x10)]
    for e in ents:
        if len(cur) + len(e) > SECTOR:  # an entry never crosses a sector
            secs.append(xpad(cur))
            cur = bytearray()
        cur += e
    secs.append(xpad(cur))
    if 33 + len(secs) > zl:
        refuse("root of %d sectors" % len(secs))
    sectors = {33 + k: c for k, c in enumerate(secs)}
    sectors[zl] = xpad(xent("z.txt", z, 1, 0x80))
    sectors[z] = b"Z"
    sectors[top] = b"TOP"
    write_sectors(dst, 44, 33, SECTOR * len(secs), sectors)
    print("xboxmany: 300 folders at %#x.., root of %d sectors" % (FAR, len(secs)))
    return 0


def cmd_udfhlink(src, dst):
    b = bytearray(open(src, "rb").read())
    ps, fsd = img330.udf_layout(b)
    a_lb = le32(b, img330.udf_fid_a(b, ps, fsd) + 20 + 4)
    rad = img330.udf_first_ad(b, ps, le32(b, fsd + 400 + 4))
    rlen, rpos = le32(b, rad) & 0x3FFFFFFF, le32(b, rad + 4)
    p = (ps + rpos) * SECTOR
    end = p + rlen
    while p < end:
        if le16(b, p) != 257:
            refuse("no file identifier descriptor at %d" % p)
        lfi, liu = b[p + 19], le16(b, p + 36)
        if (b[p + 18] & 2) and bytes(b[p + 38 + liu : p + 38 + liu + lfi]) == b"\x08zlast":
            old = le32(b, p + 20 + 4)
            struct.pack_into("<I", b, p + 20 + 4, a_lb)
            open(dst, "wb").write(b)
            print("udfhlink: zlast's ICB %d -> %d (folder a)" % (old, a_lb))
            return 0
        p += (38 + liu + lfi + 3) & ~3
    refuse("no zlast in the UDF root")


def cmd_xboxhlink(dst):
    root, S, x, top = 33, 34, 36, 37
    sectors = {
        root: xpad(xent("a", S, SECTOR, 0x10) + xent("b", S, SECTOR, 0x10) + xent("top.txt", top, 3, 0x80)),
        S: xpad(xent("x.txt", x, 1, 0x80)),
        x: b"X",
        top: b"TOP",
    }
    write_sectors(dst, 40, root, SECTOR, sectors)
    print("xboxhlink: a and b at sector %d, %d bytes" % (S, SECTOR))
    return 0


def cmd_udfloop(src, dst):
    b = bytearray(open(src, "rb").read())
    ps, fsd = img330.udf_layout(b)
    p = img330.udf_fid_a(b, ps, fsd)
    a_lb = le32(b, p + 20 + 4)
    ad = img330.udf_first_ad(b, ps, a_lb)
    alen, apos = le32(b, ad) & 0x3FFFFFFF, le32(b, ad + 4)
    q = (ps + apos) * SECTOR
    end = q + alen
    while q < end:
        if le16(b, q) != 257:
            refuse("no file identifier descriptor at %d in folder a" % q)
        lfi, liu = b[q + 19], le16(b, q + 36)
        if bytes(b[q + 38 + liu : q + 38 + liu + lfi]) == b"\x08side.txt":
            old = le32(b, q + 20 + 4)
            b[q + 18] |= 2  # a folder
            struct.pack_into("<I", b, q + 20 + 4, a_lb)
            open(dst, "wb").write(b)
            print("udfloop: side.txt's identifier in folder a: ICB %d -> %d (folder a), made a folder" % (old, a_lb))
            return 0
        q += (38 + liu + lfi + 3) & ~3
    refuse("no side.txt in folder a")


def main(argv):
    if len(argv) == 3 and argv[0] == "isotwo":
        return cmd_isotwo(argv[1], argv[2])
    if len(argv) == 2 and argv[0] == "xboxtwo":
        return cmd_xboxtwo(argv[1])
    if len(argv) == 2 and argv[0] in ("xboxloop", "xboxloop2"):
        return cmd_xboxloop(argv[1], argv[0] == "xboxloop")
    if len(argv) == 2 and argv[0] == "xboxshare":
        return cmd_xboxshare(argv[1])
    if len(argv) == 2 and argv[0] == "xboxmany":
        return cmd_xboxmany(argv[1])
    if len(argv) == 3 and argv[0] == "udfhlink":
        return cmd_udfhlink(argv[1], argv[2])
    if len(argv) == 2 and argv[0] == "xboxhlink":
        return cmd_xboxhlink(argv[1])
    if len(argv) == 3 and argv[0] == "udfloop":
        return cmd_udfloop(argv[1], argv[2])
    return img330.main(argv)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
