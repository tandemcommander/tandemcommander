"""Feature 338: the damaged images of iso338_probe.ps1 - files a whole unpack cannot extract whole.

  python -I img338.py readerr <plain.iso> <out>   TOP.TXT's record in the root points its data past
                                                  the end of the image (a read error at unpack)
  python -I img338.py readerr2 <plain.iso> <out>  as readerr, and Z.TXT in folder ZLAST too (two read
                                                  errors: the second comes after "Skip all")
  python -I img338.py twins <plain.iso> <out>     TOU.TXT;1's record in the root is renamed TOP.TXT;1
                                                  - two listed files of one name (contents TOP, TOU)

The seed is plain ISO 9660 by mkimg338.sh. Each prints what it wrote and exits 3 without writing
when the layout is not the expected one. The record helpers follow
specs/330-iso-unreadable-folder/probe/img330.py.
"""

import struct
import sys

SECTOR = 2048
FAR = 0x00100000  # a sector far past the end of every image here


def le32(b, o):
    return struct.unpack_from("<I", b, o)[0]


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


def set_both32(b, o, value):
    struct.pack_into("<I", b, o, value)
    struct.pack_into(">I", b, o + 4, value)


def cmd_readerr(src, dst, both):
    b = bytearray(open(src, "rb").read())
    root, size = iso_root(b)
    o = iso_find(b, root, size, b"TOP.TXT", False)
    set_both32(b, o + 2, FAR)
    msg = "readerr: TOP.TXT's record at %d -> extent %#x" % (o, FAR)
    if both:
        z = iso_find(b, root, size, b"ZLAST", True)
        zlba, zsize = le32(b, z + 2), le32(b, z + 10)
        o2 = iso_find(b, zlba, zsize, b"Z.TXT", False)
        set_both32(b, o2 + 2, FAR)
        msg += "; Z.TXT's record at %d -> extent %#x" % (o2, FAR)
    open(dst, "wb").write(b)
    print(msg + " (image %d sectors)" % (len(b) // SECTOR))
    return 0


def cmd_twins(src, dst):
    b = bytearray(open(src, "rb").read())
    root, size = iso_root(b)
    iso_find(b, root, size, b"TOP.TXT", False)
    o = iso_find(b, root, size, b"TOU.TXT", False)
    fil = b[o + 32]
    if bytes(b[o + 33 : o + 33 + fil]) != b"TOU.TXT;1":
        refuse("TOU.TXT's identifier is %r" % bytes(b[o + 33 : o + 33 + fil]))
    b[o + 33 : o + 33 + fil] = b"TOP.TXT;1"
    open(dst, "wb").write(b)
    print("twins: TOU.TXT;1's record at %d renamed TOP.TXT;1 (its data stays TOU)" % o)
    return 0


def main(argv):
    if len(argv) == 3 and argv[0] in ("readerr", "readerr2"):
        return cmd_readerr(argv[1], argv[2], argv[0] == "readerr2")
    if len(argv) == 3 and argv[0] == "twins":
        return cmd_twins(argv[1], argv[2])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
