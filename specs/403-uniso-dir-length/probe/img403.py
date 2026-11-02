"""ISO 9660 images whose folder records give a directory length that cannot be a directory of the image.

Plain ISO 9660 (no Rock Ridge, no Joliet), written from scratch - no seed image, no WSL. Built on
specs/401-uniso-share-length/probe/img401.py.

  python -I img403.py isoneg <out>      root: A (dir at block 21, 0xFFFFF800 bytes - negative as int),
                                        TOP.TXT, ZLAST (Z.TXT) - 401 review's isonegfresh
  python -I img403.py isoneg2 <out>     root: A (dir at 21, 2048 bytes; A1.TXT), B (dir at 21,
                                        0xFFFFF800), TOP.TXT, ZLAST (Z.TXT) - 401 review's isoneg
  python -I img403.py isomin <out>      root: A (dir at 21, 0x80000000 - the smallest negative int),
                                        TOP.TXT, ZLAST (Z.TXT)
  python -I img403.py isohuge <out>     root: A (dir at 21, 0x7FFFF800 - positive, near 2 GiB), TOP.TXT,
                                        ZLAST (Z.TXT)
  python -I img403.py isopast <out>     root: A (dir at 21, 3 sectors; the image ends after block 21),
                                        TOP.TXT, ZLAST (Z.TXT) - past the end of the image
  python -I img403.py isoedge <out>     root: A (dir of 3 sectors, its last one the image's last sector;
                                        A1.TXT in its first sector, A3.TXT in its last), TOP.TXT,
                                        ZLAST (Z.TXT) - nothing damaged (control)
  python -I img403.py isodeep <out>     review 1: root: TOP.TXT, D (dir at 22, 128 MiB); sector 22 + j holds
                                        one folder record Aj -> dir at 23 + j, 128 MiB (j = 0..2) - nested
                                        readable folders whose buffers the walk holds at once (sparse file,
                                        ~128 MiB)
  python -I img403.py isoover <out>     review 1: root: TOP.TXT, D (dir at 22, 256 MiB + 2048 - readable,
                                        within the image) - refused only by the length limit (sparse file,
                                        ~256 MiB)

Prints what it wrote.
"""

import struct
import sys

SECTOR = 2048


def both32(v):
    return struct.pack("<I", v) + struct.pack(">I", v)


def both16(v):
    return struct.pack("<H", v) + struct.pack(">H", v)


def dirrec(name, lba, size, isdir):
    n = len(name)
    length = 33 + n + (1 if n % 2 == 0 else 0)
    r = bytearray(length)
    r[0] = length
    r[1] = 0
    r[2:10] = both32(lba)
    r[10:18] = both32(size)
    r[18:25] = bytes([126, 11, 2, 12, 0, 0, 0])  # 2026-11-02 12:00:00 GMT
    r[25] = 0x02 if isdir else 0x00
    r[28:32] = both16(1)
    r[32] = n
    r[33 : 33 + n] = name
    return bytes(r)


def dot(lba, size):
    return dirrec(b"\x00", lba, size, True)


def dotdot(lba, size):
    return dirrec(b"\x01", lba, size, True)


def sect(*recs):
    b = b"".join(recs)
    assert len(b) <= SECTOR
    return b + b"\x00" * (SECTOR - len(b))


def write_iso(dst, nsect, sectors, root_lba=20, root_size=SECTOR, label=b"TC403"):
    img = bytearray(SECTOR * nsect)
    pvd = bytearray(SECTOR)
    pvd[0] = 1
    pvd[1:6] = b"CD001"
    pvd[6] = 1
    pvd[8:40] = b" " * 32
    pvd[40:72] = label + b" " * (32 - len(label))
    pvd[80:88] = both32(nsect)
    pvd[120:124] = both16(1)
    pvd[124:128] = both16(1)
    pvd[128:132] = both16(SECTOR)
    pvd[132:140] = both32(10)
    pvd[140:144] = struct.pack("<I", 18)
    pvd[148:152] = struct.pack(">I", 19)
    pvd[156:190] = dirrec(b"\x00", root_lba, root_size, True)
    pvd[190:813] = b" " * (813 - 190)
    pvd[881] = 1
    img[16 * SECTOR : 17 * SECTOR] = pvd
    term = bytearray(SECTOR)
    term[0] = 0xFF
    term[1:6] = b"CD001"
    term[6] = 1
    img[17 * SECTOR : 18 * SECTOR] = term
    img[18 * SECTOR : 18 * SECTOR + 10] = bytes([1, 0]) + struct.pack("<I", root_lba) + struct.pack("<H", 1) + b"\x00\x00"
    img[19 * SECTOR : 19 * SECTOR + 10] = bytes([1, 0]) + struct.pack(">I", root_lba) + struct.pack(">H", 1) + b"\x00\x00"
    for s, c in sectors.items():
        img[s * SECTOR : s * SECTOR + len(c)] = c
    open(dst, "wb").write(bytes(img))


# root at 20: [extra folder records] TOP.TXT (24), ZLAST (dir at 22: Z.TXT at 23); block 21 is A's
def cmd_one(dst, name, alen):
    root, a, zl, z, top = 20, 21, 22, 23, 24
    sectors = {
        root: sect(dot(root, SECTOR), dotdot(root, SECTOR), dirrec(b"A", a, alen, True),
                   dirrec(b"TOP.TXT;1", top, 3, False), dirrec(b"ZLAST", zl, SECTOR, True)),
        a: sect(dot(a, SECTOR), dotdot(root, SECTOR)),
        zl: sect(dot(zl, SECTOR), dotdot(root, SECTOR), dirrec(b"Z.TXT;1", z, 1, False)),
        z: b"Z",
        top: b"TOP",
    }
    write_iso(dst, 25, sectors)
    print("%s: A (block %d, 0x%08X bytes), TOP.TXT, ZLAST/Z.TXT; 25 sectors" % (name, a, alen))
    return 0


def cmd_neg2(dst):
    root, a, zl, z, top, a1 = 20, 21, 22, 23, 24, 25
    sectors = {
        root: sect(dot(root, SECTOR), dotdot(root, SECTOR), dirrec(b"A", a, SECTOR, True),
                   dirrec(b"B", a, 0xFFFFF800, True), dirrec(b"TOP.TXT;1", top, 3, False),
                   dirrec(b"ZLAST", zl, SECTOR, True)),
        a: sect(dot(a, SECTOR), dotdot(root, SECTOR), dirrec(b"A1.TXT;1", a1, 2, False)),
        zl: sect(dot(zl, SECTOR), dotdot(root, SECTOR), dirrec(b"Z.TXT;1", z, 1, False)),
        z: b"Z",
        top: b"TOP",
        a1: b"A1",
    }
    write_iso(dst, 26, sectors)
    print("isoneg2: A (block %d, 2048 bytes), B (block %d, 0xFFFFF800 bytes), TOP.TXT, ZLAST/Z.TXT" % (a, a))
    return 0


def cmd_past(dst):
    # A at the image's last sector claims 3 sectors: its 2nd and 3rd lie past the end
    root, zl, z, top, a = 20, 21, 22, 23, 24
    sectors = {
        root: sect(dot(root, SECTOR), dotdot(root, SECTOR), dirrec(b"A", a, 3 * SECTOR, True),
                   dirrec(b"TOP.TXT;1", top, 3, False), dirrec(b"ZLAST", zl, SECTOR, True)),
        zl: sect(dot(zl, SECTOR), dotdot(root, SECTOR), dirrec(b"Z.TXT;1", z, 1, False)),
        z: b"Z",
        top: b"TOP",
        a: sect(dot(a, 3 * SECTOR), dotdot(root, SECTOR)),
    }
    write_iso(dst, 25, sectors)
    print("isopast: A (block %d, 3 sectors; the image ends after block %d), TOP.TXT, ZLAST/Z.TXT" % (a, a))
    return 0


def cmd_edge(dst):
    # A's 3 sectors are the image's last 3 sectors: nothing damaged
    root, zl, z, top, a1, a3, a = 20, 21, 22, 23, 24, 25, 26
    sectors = {
        root: sect(dot(root, SECTOR), dotdot(root, SECTOR), dirrec(b"A", a, 3 * SECTOR, True),
                   dirrec(b"TOP.TXT;1", top, 3, False), dirrec(b"ZLAST", zl, SECTOR, True)),
        zl: sect(dot(zl, SECTOR), dotdot(root, SECTOR), dirrec(b"Z.TXT;1", z, 1, False)),
        z: b"Z",
        top: b"TOP",
        a1: b"A1",
        a3: b"A3",
        a: sect(dot(a, 3 * SECTOR), dotdot(root, SECTOR), dirrec(b"A1.TXT;1", a1, 2, False)),
        a + 2: sect(dirrec(b"A3.TXT;1", a3, 2, False)),
    }
    write_iso(dst, a + 3, sectors)
    print("isoedge: A (blocks %d..%d, the image's last 3 sectors; A1.TXT, A3.TXT), TOP.TXT, ZLAST/Z.TXT; %d sectors"
          % (a, a + 2, a + 3))
    return 0


def write_sparse(dst, nsect, sectors, root_lba=20):
    # the same volume as write_iso, written by seeking (the image is mostly zeros)
    head = SECTOR * 24
    small = {s: c for s, c in sectors.items() if s < 24}
    write_iso(dst, 24, small, root_lba)
    with open(dst, "r+b") as f:
        f.seek(16 * SECTOR + 80)
        f.write(both32(nsect))
        f.truncate(nsect * SECTOR)
        for s, c in sectors.items():
            if s >= 24:
                f.seek(s * SECTOR)
                f.write(c)
    assert head <= nsect * SECTOR


def cmd_deep(dst):
    # review 1 of 403 (its deep403.py, depth 3, 128 MiB folders): D_j's buffer covers the later sectors
    root, top, b, depth, length = 20, 21, 22, 3, 128 * 1024 * 1024
    sectors = {
        root: sect(dot(root, SECTOR), dotdot(root, SECTOR), dirrec(b"D", b, length, True),
                   dirrec(b"TOP.TXT;1", top, 3, False)),
        top: b"TOP",
    }
    for j in range(depth):
        sectors[b + j] = sect(dirrec(b"A%d" % j, b + j + 1, length, True))
    nsect = b + depth + length // SECTOR + 2
    write_sparse(dst, nsect, sectors)
    print("isodeep: TOP.TXT, D (block %d, %d bytes) holding A0..A%d, each a folder of %d bytes one block on; %d sectors"
          % (b, length, depth - 1, length, nsect))
    return 0


def cmd_over(dst):
    root, top, b, length = 20, 21, 22, 256 * 1024 * 1024 + SECTOR
    sectors = {
        root: sect(dot(root, SECTOR), dotdot(root, SECTOR), dirrec(b"D", b, length, True),
                   dirrec(b"TOP.TXT;1", top, 3, False)),
        top: b"TOP",
        b: sect(dot(b, length), dotdot(root, SECTOR)),
    }
    nsect = b + length // SECTOR + 2
    write_sparse(dst, nsect, sectors)
    print("isoover: TOP.TXT, D (block %d, %d bytes, readable); %d sectors" % (b, length, nsect))
    return 0


def main(argv):
    if len(argv) == 2 and argv[0] == "isoneg":
        return cmd_one(argv[1], "isoneg", 0xFFFFF800)
    if len(argv) == 2 and argv[0] == "isomin":
        return cmd_one(argv[1], "isomin", 0x80000000)
    if len(argv) == 2 and argv[0] == "isohuge":
        return cmd_one(argv[1], "isohuge", 0x7FFFF800)
    if len(argv) == 2 and argv[0] == "isoneg2":
        return cmd_neg2(argv[1])
    if len(argv) == 2 and argv[0] == "isopast":
        return cmd_past(argv[1])
    if len(argv) == 2 and argv[0] == "isoedge":
        return cmd_edge(argv[1])
    if len(argv) == 2 and argv[0] == "isodeep":
        return cmd_deep(argv[1])
    if len(argv) == 2 and argv[0] == "isoover":
        return cmd_over(argv[1])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
