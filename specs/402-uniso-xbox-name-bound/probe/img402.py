"""Feature 402: the images of iso402_probe.ps1 - an Xbox (XDVDFS) entry whose name does not lie whole in
its directory's data.

The Xbox folder walk (CXDVDFS::ScanDir) holds a directory in a heap buffer of the size its parent entry
(or the volume descriptor, for the root) gives. Each entry is a 14-byte head (left / right subtree
offsets, start sector, file size, attributes, name length) and the name. These images give a directory a
size that ends inside the last entry's name, so the name's bytes past that size are not in the buffer.

  python -I img402.py name <out>     root (60 bytes): top.txt, zlast (z.txt), then 'zz' + 198 bytes of a
                                     200-byte name past the end of the root's 60 bytes
  python -I img402.py over1 <out>    the same, the name 3 bytes long, 2 of them in the root (one byte past)
  python -I img402.py edge <out>     (control) the same, the name 'zz' 2 bytes long - it ends exactly at
                                     the end of the root's 60 bytes: listed as zz
  python -I img402.py sub <out>      root: a (40 bytes: side.txt, then a 255-byte name of which 2 bytes
                                     lie in a), top.txt, zlast (z.txt)
  python -I img402.py max <out>      root (60 bytes) as 'name', the name length 255

Every file holds its name in upper case without the extension (TOP, Z, SIDE); the last entry (damaged,
or the control's zz) points to a file holding BAD. Prints what it wrote.
"""

import struct
import sys

SECTOR = 2048


def xent(name, start, size, attr, namelen=None):
    raw = name.encode("ascii")
    n = len(raw) if namelen is None else namelen
    e = struct.pack("<HHIIBB", 0, 0, start, size, attr, n) + raw
    if namelen is None:
        e += b"\xff" * ((4 - len(e) % 4) % 4)
    return e


def write_image(dst, nsect, root, rootsize, sectors):
    img = bytearray(SECTOR * nsect)
    vd = 32 * SECTOR
    img[vd : vd + 20] = b"MICROSOFT*XBOX*MEDIA"
    img[vd + 20 : vd + 28] = struct.pack("<II", root, rootsize)
    img[vd + 0x7EC : vd + 0x7EC + 20] = b"MICROSOFT*XBOX*MEDIA"
    for s, c in sectors.items():
        img[s * SECTOR : s * SECTOR + len(c)] = c
    open(dst, "wb").write(bytes(img))


def tail(head, rest):
    """the directory sector: its bytes, then 'X' (on disk the name would go on - never read)"""
    return bytes(head) + b"X" * (SECTOR - len(head) - rest) + b"\xff" * rest


def cmd_root(dst, namelen, label):
    root, zl, z, top, bad = 33, 34, 35, 36, 37
    head = xent("top.txt", top, 3, 0x80) + xent("zlast", zl, SECTOR, 0x10)
    last = xent("zz", bad, 3, 0x80, namelen)  # the head and 2 bytes of the name
    body = head + last
    sectors = {
        root: tail(body, 0),
        zl: xent("z.txt", z, 1, 0x80) + b"\xff" * (SECTOR - 20),
        z: b"Z",
        top: b"TOP",
        bad: b"BAD",
    }
    write_image(dst, 40, root, len(body), sectors)
    print("%s: root at %d, %d bytes; its last entry's name %d bytes long, %d of them in the root"
          % (label, root, len(body), namelen, 2))
    return 0


def cmd_sub(dst):
    root, a, side, zl, z, top, bad = 33, 34, 35, 36, 37, 38, 39
    abody = xent("side.txt", side, 4, 0x80) + xent("zz", bad, 3, 0x80, 255)
    rbody = xent("a", a, len(abody), 0x10) + xent("top.txt", top, 3, 0x80) + xent("zlast", zl, SECTOR, 0x10)
    sectors = {
        root: bytes(rbody) + b"\xff" * (SECTOR - len(rbody)),
        a: tail(abody, 0),
        side: b"SIDE",
        zl: xent("z.txt", z, 1, 0x80) + b"\xff" * (SECTOR - 20),
        z: b"Z",
        top: b"TOP",
        bad: b"BAD",
    }
    write_image(dst, 42, root, SECTOR, sectors)
    print("sub: folder a at %d, %d bytes; its last entry's name 255 bytes long, 2 of them in a" % (a, len(abody)))
    return 0


def main(argv):
    if len(argv) == 2 and argv[0] == "name":
        return cmd_root(argv[1], 200, "name")
    if len(argv) == 2 and argv[0] == "over1":
        return cmd_root(argv[1], 3, "over1")
    if len(argv) == 2 and argv[0] == "edge":
        return cmd_root(argv[1], 2, "edge")
    if len(argv) == 2 and argv[0] == "max":
        return cmd_root(argv[1], 255, "max")
    if len(argv) == 2 and argv[0] == "sub":
        return cmd_sub(argv[1])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
