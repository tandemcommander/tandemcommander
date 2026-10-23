"""Feature 327: the crafted images of iso327_probe.ps1.

Every name a disc file system stores can hold bytes Windows must not take as they are: an image tool
refuses or maps them, so the probe makes a valid image with placeholder names and this script
replaces each placeholder by an unsafe name of the same length (the records keep their layout).

  python -I img327.py patch <in> <out> <set>   replace the placeholders of <set> (plain | joliet | udf)
  python -I img327.py vol <in> <out>           the primary volume identifier set to VOL_ID
  python -I img327.py xbox <out>               build an XDVDFS (Xbox) image holding XBOX_TREE

The unsafe names live here, not on a command line (backslashes, colons). Prints what it changed;
exit code 1 when a placeholder was not found.
"""

import struct
import sys

# ISO 9660 identifiers (raw bytes, with the version suffix), xorriso -rockridge off -joliet off
PLAIN = [
    ("AAAAAAAA.TXT;1", "..\\..\\ESC1.T;1"),
    ("BBBBBBBB.TXT;1", "12:30AAA.TXT;1"),
    ("CCCCCCCC.TXT;1", "CON.TXTAAAAA;1"),
    ("EEEEEEEE.TXT;1", "TRAILAAAAA..;1"),
    ("FFFFFFFF.TXT;1", "1/2FFFFF.TXT;1"),
    ("DDDDDDD", "..\\..\\D"),
]
# Joliet (UCS-2 big endian) and UDF names (OSTA compressed: 8 or 16 bits a letter), IMAPI2
UNICODE = [
    ("jjjjjjjjjj.txt", "..\\..\\jesc.txt"),
    ("jcolonaaa.txt", "12:30jaaa.txt"),
    ("jdevaaa.txt", "con.txtjaaa"),
    ("jtdotaaaa.txt", "jtrailaaaaa.."),
    ("jslashaa.txt", "j/slasha.txt"),
    ("jfolderx", "..\\..\\jd"),
]
VOL_ID = "v\\..\\..\\w"
# (name, content or None for a folder, children)
XBOX_TREE = [
    ("set", None, [
        ("..\\..\\xesc.txt", b"XESC", None),
        ("12:30x.txt", b"XCOLON", None),
        ("con.txt", b"XDEV", None),
        ("xtrail.", b"XTDOT", None),
        ("x/slash.txt", b"XSLASH", None),
        ("..\\..\\xd", None, [("inner.txt", b"INNER", None)]),
        ("top.txt", b"TOP", None),
    ]),
]

SECTOR = 2048


def replace_all(data, old, new):
    if len(old) != len(new):
        raise SystemExit("placeholder and name differ in length: %r %r" % (old, new))
    n = data.count(old)
    return data.replace(old, new), n


def cmd_patch(src, dst, which):
    data = bytearray(open(src, "rb").read())
    pairs = {"plain": PLAIN, "joliet": UNICODE, "udf": UNICODE}[which]
    missing = 0
    for old, new in pairs:
        forms = [(old.encode("ascii"), new.encode("ascii"))]
        if which != "plain":
            forms.append((old.encode("utf-16-be"), new.encode("utf-16-be")))
        total = 0
        for o, w in forms:
            data, n = replace_all(bytes(data), o, w)
            data = bytearray(data)
            total += n
        print("%s: %r -> %r: %d" % (which, old, new, total))
        if total == 0:
            missing += 1
    open(dst, "wb").write(bytes(data))
    return 1 if missing else 0


def cmd_vol(src, dst):
    data = bytearray(open(src, "rb").read())
    pvd = 16 * SECTOR
    if data[pvd] != 1 or data[pvd + 1 : pvd + 6] != b"CD001":
        print("vol: no primary volume descriptor at sector 16")
        return 1
    data[pvd + 40 : pvd + 72] = VOL_ID.encode("ascii").ljust(32, b" ")
    open(dst, "wb").write(bytes(data))
    print("vol: primary volume identifier -> %r" % VOL_ID)
    return 0


def cmd_xbox(dst):
    # sectors: 0..31 empty, 32 the volume descriptor, then one sector a folder, one a file
    sectors = {}
    nxt = [33]

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
            else:
                start = alloc()
                sectors[start] = content
                size, attr = len(content), 0x80
            ent = struct.pack("<HHIIBB", 0, 0, start, size, attr, len(raw)) + raw
            ent += b"\xff" * ((4 - len(ent) % 4) % 4)
            blob += ent
        sectors[sec] = bytes(blob) + b"\xff" * (SECTOR - len(blob))
        return sec

    root = build_dir(XBOX_TREE)
    img = bytearray(SECTOR * nxt[0])
    vd = 32 * SECTOR
    img[vd : vd + 20] = b"MICROSOFT*XBOX*MEDIA"
    img[vd + 20 : vd + 28] = struct.pack("<II", root, SECTOR)
    img[vd + 0x7EC : vd + 0x7EC + 20] = b"MICROSOFT*XBOX*MEDIA"
    for s, content in sectors.items():
        img[s * SECTOR : s * SECTOR + len(content)] = content
    open(dst, "wb").write(bytes(img))
    print("xbox: %d sectors, root at %d" % (nxt[0], root))
    return 0


def main(argv):
    if len(argv) == 4 and argv[0] == "patch":
        return cmd_patch(argv[1], argv[2], argv[3])
    if len(argv) == 3 and argv[0] == "vol":
        return cmd_vol(argv[1], argv[2])
    if len(argv) == 2 and argv[0] == "xbox":
        return cmd_xbox(argv[1])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
