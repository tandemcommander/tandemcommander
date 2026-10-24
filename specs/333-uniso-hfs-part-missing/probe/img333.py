"""Feature 333: damaged copies of an xorriso ISO 9660 + HFS+ hybrid (mkimg333.sh) for iso333_probe.ps1.

  python -I img333.py <how> <src> <dst>    a copy whose HFS+ part no longer opens:
      ver    the volume header's version 4 -> 5 (signature "H+" kept: not an HFS+ volume the reader takes)
      cat    the catalog's header node kind 1 -> 0 (the catalog B-tree is refused, feature 322)
      size   the catalog's logical size 0 (refused before it is loaded)
      ext    the catalog's first extent starts far past the end of the image (its read fails)
      nosig  the volume header's signature "H+" -> zeros (no HFS+ volume is declared any more)
      apmsig (review 1) the Apple partition map's entry at block 2 (hdh.iso: "Gap0", apm.iso: "EFI"
             - for apm.iso the walk fails at it) signature "PM" -> "PX"
      apmcnt (review 1) the same entry's map entry count + 1 (the walk refuses the map)
  Only the named bytes change. Prints what it wrote.
"""

import struct
import sys


def be16(b, o):
    return struct.unpack_from(">H", b, o)[0]


def be32(b, o):
    return struct.unpack_from(">I", b, o)[0]


def find_vh(img):
    # the HFS+ volume header: "H+" version 4, 1024 bytes into the volume (a 512-byte boundary)
    for o in range(1024, len(img) - 512, 512):
        if img[o : o + 4] == b"H+\x00\x04":
            return o
    raise SystemExit("no HFS+ volume header")


def main(argv):
    if len(argv) != 4 or argv[1] not in ("ver", "cat", "size", "ext", "nosig", "apmsig", "apmcnt"):
        print(__doc__)
        return 2
    how, src, dst = argv[1:]
    img = bytearray(open(src, "rb").read())
    if how in ("apmsig", "apmcnt"):
        if img[0:2] != b"ER":
            raise SystemExit("no Apple partition map")
        o = 2 * be16(img, 2)  # the entry at block 2 (the map starts at block 1)
        if img[o : o + 2] != b"PM":
            raise SystemExit("no partition map entry at block 2")
        name = bytes(img[o + 16 : o + 48]).split(b"\0")[0].decode("ascii", "replace")
        if how == "apmsig":
            img[o + 1] = ord("X")
            what = "signature PM -> PX"
        else:
            cnt = be32(img, o + 4)
            struct.pack_into(">I", img, o + 4, cnt + 1)
            what = "entry count %d -> %d" % (cnt, cnt + 1)
        open(dst, "wb").write(bytes(img))
        print("%s: partition map entry %s at block 2: %s -> %s" % (how, name, what, dst))
        return 0
    vh = find_vh(img)
    vol = vh - 1024
    block = be32(img, vh + 40)
    fork = vh + 272  # catalogFile: logicalSize 8, clumpSize 4, totalBlocks 4, extents 8 x (start, count)
    start = be32(img, fork + 16)
    what = ""
    if how == "ver":
        struct.pack_into(">H", img, vh + 2, 5)
        what = "version 4 -> 5"
    elif how == "nosig":
        struct.pack_into(">H", img, vh, 0)
        what = "signature H+ -> 0"
    elif how == "size":
        struct.pack_into(">Q", img, fork, 0)
        what = "catalog logical size -> 0"
    elif how == "ext":
        struct.pack_into(">I", img, fork + 16, 0x00FFFFF0)
        what = "catalog extent 0 start %d -> %#x" % (start, 0x00FFFFF0)
    else:
        node = vol + start * block
        if img[node + 8] != 1:
            raise SystemExit("the catalog's first node is not a header node")
        img[node + 8] = 0
        what = "catalog header node kind 1 -> 0 (at %d)" % (node + 8)
    open(dst, "wb").write(bytes(img))
    print("%s: %s (volume header at %d) -> %s" % (how, what, vh, dst))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
