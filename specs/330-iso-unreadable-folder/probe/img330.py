"""Feature 330: the damaged images of iso330_probe.ps1 - a folder whose directory cannot be read.

  python -I img330.py isoext <rd.iso> <out>   ISO 9660 (genisoimage -R seed): folder A's directory
                                              record in the primary volume's root points past the end
                                              of the image (review 4 of 328's patchrd.py)
  python -I img330.py isorec <rd.iso> <out>   ISO 9660: the record of SIDE.TXT inside folder A's
                                              directory gets a little-endian extent that differs from
                                              its big-endian one (the reader's record safety check)
  python -I img330.py udfext <ud.iso> <out>   UDF part of a genisoimage -udf hybrid: folder a's file
                                              entry keeps its place, its allocation descriptor (the
                                              directory's data) points past the end of the image
  python -I img330.py isozero <rd.iso> <out>  ISO 9660: folder A's record gets DataLength 0 (the walk
                                              returns without a word)
  python -I img330.py udficb <ud.iso> <out>   UDF: folder a's identifier in the root points its file
                                              entry (ICB) past the end - the folder was listed empty
                                              without a word
  python -I img330.py udftag <ud.iso> <out>   UDF: the first identifier of folder a's directory gets
                                              an invalid tag ("Invalid UDF Tag ID.")
  python -I img330.py udfroot <ud.iso> <out>  UDF: the file set descriptor's root ICB points past the
                                              end ("Bad root ICB") - nothing of the UDF part is listed
  python -I img330.py udfavdp <ud.iso> <out>  UDF: the anchor's main volume descriptor sequence points
                                              past the end - the UDF part does not open ("Cannot read
                                              sector"), the hybrid lists its ISO 9660 part only
  python -I img330.py isoroot <rd.iso> <out>  ISO 9660: the primary volume's root directory points past
                                              the end - nothing is listed
  python -I img330.py xbox <out>              an XDVDFS (Xbox) image of a/side.txt, top.txt,
                                              zlast/z.txt (a before zlast)
  python -I img330.py xboxext <out>           the same, folder a's start sector past the end

Each prints what it wrote and exits 3 without writing when the layout is not the expected one.
The xbox writer follows specs/329-uniso-other-readers-refused/probe/img329.py; isozero, udficb,
udftag and udfroot follow the images of 330's first (stopped) reviewer, udfavdp and isoroot those
of its second.
"""

import struct
import sys

SECTOR = 2048
FAR = 0x00100000  # a sector far past the end of every image here


def le32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def le16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def refuse(msg):
    print("layout not as expected: " + msg)
    sys.exit(3)


def iso_records(b, lba, size):
    """(offset, length, flags, identifier) of every directory record of a directory extent"""
    o = lba * SECTOR
    end = o + size
    while o < end:
        n = b[o]
        if n == 0:
            o = (o // SECTOR + 1) * SECTOR
            continue
        fil = b[o + 32]
        yield o, n, b[o + 25], bytes(b[o + 33 : o + 33 + fil])
        o += n


def iso_root(b):
    pvd = 16 * SECTOR
    if b[pvd] != 1 or bytes(b[pvd + 1 : pvd + 6]) != b"CD001":
        refuse("no primary volume descriptor at sector 16")
    return le32(b, pvd + 156 + 2), le32(b, pvd + 156 + 10)


def iso_find(b, lba, size, name, isdir):
    for o, n, flags, ident in iso_records(b, lba, size):
        if bool(flags & 2) == isdir and ident.split(b";")[0] == name:
            return o
    refuse("no record %r" % name)


def set_both32(b, o, value, be_value=None):
    struct.pack_into("<I", b, o, value)
    struct.pack_into(">I", b, o + 4, value if be_value is None else be_value)


def cmd_isoext(src, dst):
    b = bytearray(open(src, "rb").read())
    root, size = iso_root(b)
    o = iso_find(b, root, size, b"A", True)
    set_both32(b, o + 2, FAR)
    open(dst, "wb").write(b)
    print("isoext: folder A's record at %d -> extent %#x (image %d sectors)" % (o, FAR, len(b) // SECTOR))
    return 0


def cmd_isorec(src, dst):
    b = bytearray(open(src, "rb").read())
    root, size = iso_root(b)
    a = iso_find(b, root, size, b"A", True)
    alba, asize = le32(b, a + 2), le32(b, a + 10)
    o = iso_find(b, alba, asize, b"SIDE.TXT", False)
    good = le32(b, o + 2)
    struct.pack_into("<I", b, o + 2, good + 1)  # the big-endian copy keeps the true extent
    open(dst, "wb").write(b)
    print("isorec: SIDE.TXT's record at %d in folder A (extent %d) -> LE %d, BE %d" % (o, alba, good + 1, good))
    return 0


def cmd_isoroot(src, dst):
    b = bytearray(open(src, "rb").read())
    root, _ = iso_root(b)
    set_both32(b, 16 * SECTOR + 156 + 2, FAR)
    open(dst, "wb").write(b)
    print("isoroot: the primary volume's root directory %d -> %#x" % (root, FAR))
    return 0


def cmd_udfavdp(src, dst):
    b = bytearray(open(src, "rb").read())
    if udf_tag(b, 256) != 2:
        refuse("no anchor volume descriptor pointer at sector 256")
    o = 256 * SECTOR + 20
    old = le32(b, o)
    struct.pack_into("<I", b, o, FAR)
    open(dst, "wb").write(b)
    print("udfavdp: the anchor's main volume descriptor sequence %d -> %#x" % (old, FAR))
    return 0


def cmd_isozero(src, dst):
    b = bytearray(open(src, "rb").read())
    root, size = iso_root(b)
    o = iso_find(b, root, size, b"A", True)
    set_both32(b, o + 10, 0)
    open(dst, "wb").write(b)
    print("isozero: folder A's record at %d -> data length 0" % o)
    return 0


# --- UDF (ECMA-167 / OSTA UDF as genisoimage writes it) ---


def udf_tag(b, sec):
    return le16(b, sec * SECTOR)


def udf_layout(b):
    """(partition start sector, offset of the file set descriptor)"""
    if udf_tag(b, 256) != 2:
        refuse("no anchor volume descriptor pointer at sector 256")
    avdp = 256 * SECTOR
    vds_len, vds_loc = le32(b, avdp + 16), le32(b, avdp + 20)
    part_start = fsd_lb = None
    for sec in range(vds_loc, vds_loc + (vds_len + SECTOR - 1) // SECTOR):
        tag = udf_tag(b, sec)
        if tag == 5:
            part_start = le32(b, sec * SECTOR + 188)
        elif tag == 6:
            fsd_lb = le32(b, sec * SECTOR + 248 + 4)
        elif tag == 8:
            break
    if part_start is None or fsd_lb is None:
        refuse("no partition / logical volume descriptor")
    fsd = (part_start + fsd_lb) * SECTOR
    if le16(b, fsd) != 256:
        refuse("no file set descriptor at %d" % (part_start + fsd_lb))
    return part_start, fsd


def udf_first_ad(b, part_start, lb):
    """offset of the first allocation descriptor of the file entry at logical block lb"""
    o = (part_start + lb) * SECTOR
    tag = le16(b, o)
    if tag == 261:
        first = o + 176 + le32(b, o + 168)
    elif tag == 266:
        first = o + 216 + le32(b, o + 208)
    else:
        refuse("no file entry at logical block %d (tag %d)" % (lb, tag))
    if le16(b, o + 16 + 18) & 7 not in (0, 1):
        refuse("file entry at logical block %d: embedded data" % lb)
    return first


def udf_fid_a(b, part_start, fsd):
    """offset of folder a's file identifier descriptor in the root"""
    rad = udf_first_ad(b, part_start, le32(b, fsd + 400 + 4))
    rlen, rpos = le32(b, rad) & 0x3FFFFFFF, le32(b, rad + 4)
    p = (part_start + rpos) * SECTOR
    end = p + rlen
    while p < end:
        if le16(b, p) != 257:
            refuse("no file identifier descriptor at %d" % p)
        lfi, liu = b[p + 19], le16(b, p + 36)
        if (b[p + 18] & 2) and bytes(b[p + 38 + liu : p + 38 + liu + lfi]) == b"\x08a":
            return p
        p += (38 + liu + lfi + 3) & ~3
    refuse("no folder a in the UDF root")


def cmd_udfmore(kind, src, dst):
    b = bytearray(open(src, "rb").read())
    ps, fsd = udf_layout(b)
    if kind == "udfroot":
        old = le32(b, fsd + 400 + 4)
        struct.pack_into("<I", b, fsd + 400 + 4, FAR)
        msg = "the file set descriptor's root ICB %d -> %#x" % (old, FAR)
    else:
        p = udf_fid_a(b, ps, fsd)
        a_lb = le32(b, p + 20 + 4)
        if kind == "udficb":
            struct.pack_into("<I", b, p + 20 + 4, FAR)
            msg = "folder a's identifier: ICB %d -> %#x" % (a_lb, FAR)
        else:
            d = (ps + le32(b, udf_first_ad(b, ps, a_lb) + 4)) * SECTOR
            if le16(b, d) != 257:
                refuse("folder a's directory does not start with an identifier")
            struct.pack_into("<H", b, d, 0x0999)
            msg = "folder a's directory at sector %d: first identifier's tag -> 0x0999" % (d // SECTOR)
    open(dst, "wb").write(b)
    print("%s: %s" % (kind, msg))
    return 0


def cmd_udfext(src, dst):
    b = bytearray(open(src, "rb").read())
    if udf_tag(b, 256) != 2:
        refuse("no anchor volume descriptor pointer at sector 256")
    avdp = 256 * SECTOR
    vds_len, vds_loc = le32(b, avdp + 16), le32(b, avdp + 20)
    part_start = None
    fsd_lb = None
    for sec in range(vds_loc, vds_loc + (vds_len + SECTOR - 1) // SECTOR):
        tag = udf_tag(b, sec)
        o = sec * SECTOR
        if tag == 5:  # partition descriptor
            part_start = le32(b, o + 188)
        elif tag == 6:  # logical volume descriptor: the file set descriptor's long_ad at 248
            fsd_lb = le32(b, o + 248 + 4)
        elif tag == 8:  # terminating descriptor
            break
    if part_start is None or fsd_lb is None:
        refuse("no partition / logical volume descriptor")
    fsd = (part_start + fsd_lb) * SECTOR
    if le16(b, fsd) != 256:
        refuse("no file set descriptor at %d" % (part_start + fsd_lb))
    root_lb = le32(b, fsd + 400 + 4)

    def entry(lb):
        """(offset of the file entry, offset of its first allocation descriptor, AD type)"""
        o = (part_start + lb) * SECTOR
        tag = le16(b, o)
        if tag == 261:  # file entry
            ea, ad = le32(b, o + 168), le32(b, o + 172)
            first = o + 176 + ea
        elif tag == 266:  # extended file entry
            ea, ad = le32(b, o + 208), le32(b, o + 212)
            first = o + 216 + ea
        else:
            refuse("no file entry at logical block %d (tag %d)" % (lb, tag))
        kind = le16(b, o + 16 + 18) & 7
        if kind not in (0, 1) or ad < 8:
            refuse("file entry at logical block %d: AD type %d, %d bytes of ADs" % (lb, kind, ad))
        return o, first, kind

    _, rad, rkind = entry(root_lb)
    rlen, rpos = le32(b, rad) & 0x3FFFFFFF, le32(b, rad + 4)
    p = (part_start + rpos) * SECTOR
    end = p + rlen
    a_lb = None
    while p < end:
        if le16(b, p) != 257:  # file identifier descriptor
            refuse("no file identifier descriptor at %d" % p)
        lfi, liu = b[p + 19], le16(b, p + 36)
        icb_lb = le32(b, p + 20 + 4)
        fi = bytes(b[p + 38 + liu : p + 38 + liu + lfi])
        if (b[p + 18] & 2) and fi == b"\x08a":
            a_lb = icb_lb
        p += (38 + liu + lfi + 3) & ~3
    if a_lb is None:
        refuse("no folder a in the UDF root")
    fe, ad, kind = entry(a_lb)
    old = le32(b, ad + 4)
    struct.pack_into("<I", b, ad + 4, FAR)  # short_ad / long_ad: the position after the length
    open(dst, "wb").write(b)
    print("udfext: partition at %d, folder a's file entry at logical block %d, its directory %d -> %#x (AD type %d)" % (part_start, a_lb, old, FAR, kind))
    return 0


# --- XDVDFS ---

TREE = [
    ("a", None, [("side.txt", b"SIDE", None)]),
    ("top.txt", b"TOP", None),
    ("zlast", None, [("z.txt", b"Z", None)]),
]


def cmd_xbox(dst, damaged):
    sectors = {}
    nxt = [33]
    patched = []

    def alloc():
        s = nxt[0]
        nxt[0] += 1
        return s

    def build_dir(entries):
        sec = alloc()
        blob = bytearray()
        for name, content, children in entries:
            raw = name.encode("ascii")
            if content is None:
                start = build_dir(children)
                size, attr = SECTOR, 0x10
                if damaged and name == "a":
                    patched.append(start)
                    start = FAR
            else:
                start = alloc()
                sectors[start] = content
                size, attr = len(content), 0x80
            ent = struct.pack("<HHIIBB", 0, 0, start, size, attr, len(raw)) + raw
            ent += b"\xff" * ((4 - len(ent) % 4) % 4)
            blob += ent
        sectors[sec] = bytes(blob) + b"\xff" * (SECTOR - len(blob))
        return sec

    root = build_dir(TREE)
    img = bytearray(SECTOR * nxt[0])
    vd = 32 * SECTOR
    img[vd : vd + 20] = b"MICROSOFT*XBOX*MEDIA"
    img[vd + 20 : vd + 28] = struct.pack("<II", root, SECTOR)
    img[vd + 0x7EC : vd + 0x7EC + 20] = b"MICROSOFT*XBOX*MEDIA"
    for s, content in sectors.items():
        img[s * SECTOR : s * SECTOR + len(content)] = content
    open(dst, "wb").write(bytes(img))
    extra = ("; folder a's start sector %d -> %#x" % (patched[0], FAR)) if damaged else ""
    print("xbox: %d sectors, root at %d%s" % (nxt[0], root, extra))
    return 0


def main(argv):
    if len(argv) == 3 and argv[0] == "isoext":
        return cmd_isoext(argv[1], argv[2])
    if len(argv) == 3 and argv[0] == "isorec":
        return cmd_isorec(argv[1], argv[2])
    if len(argv) == 3 and argv[0] == "isozero":
        return cmd_isozero(argv[1], argv[2])
    if len(argv) == 3 and argv[0] == "isoroot":
        return cmd_isoroot(argv[1], argv[2])
    if len(argv) == 3 and argv[0] == "udfavdp":
        return cmd_udfavdp(argv[1], argv[2])
    if len(argv) == 3 and argv[0] == "udfext":
        return cmd_udfext(argv[1], argv[2])
    if len(argv) == 3 and argv[0] in ("udficb", "udftag", "udfroot"):
        return cmd_udfmore(argv[0], argv[1], argv[2])
    if len(argv) == 2 and argv[0] in ("xbox", "xboxext"):
        return cmd_xbox(argv[1], argv[0] == "xboxext")
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
