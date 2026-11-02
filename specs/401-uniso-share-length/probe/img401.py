"""ISO 9660 images in which two folder records point to one directory block with different data lengths.

Plain ISO 9660 (no Rock Ridge, no Joliet), written from scratch - no seed image, no WSL:

  python -I img401.py isoshare <out>    root: A (dir at block S, 2048 bytes), B (dir at S, 4096 bytes),
                                        TOP.TXT; S holds A1.TXT, S + 1 holds A2.TXT - nothing damaged,
                                        B/A2.TXT is reached only through B
  python -I img401.py isoshare2 <out>   the same with the longer record first: A (S, 4096), B (S, 2048)
  python -I img401.py isoloop <out>     root: A (dir at S, 2048 bytes), TOP.TXT, ZLAST (Z.TXT); S holds
                                        A1.TXT and L (a folder at S itself, 4096 bytes), S + 1 holds
                                        A2.TXT - a folder loop through a longer length
  python -I img401.py isohlink <out>    root: A (dir at S, 2048), B (the same block and length), TOP.TXT;
                                        S holds X.TXT - two folders name one directory (328's rule:
                                        the second is listed empty)
  python -I img401.py isomany <out>     root: A (S, 2048) and 40 folders F00..F39 at S with lengths
                                        4096, 6144, ... (crafted: each walked once), TOP.TXT; S holds
                                        A1.TXT, the following sectors hold nothing (zeros)

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


def write_iso(dst, nsect, sectors, root_lba=20, root_size=SECTOR, label=b"TC401"):
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


def cmd_share(dst, longer_first):
    root, S, a1, a2, top = 20, 21, 23, 24, 25
    first, second = (2 * SECTOR, SECTOR) if longer_first else (SECTOR, 2 * SECTOR)
    sectors = {
        root: sect(dot(root, SECTOR), dotdot(root, SECTOR), dirrec(b"A", S, first, True),
                   dirrec(b"B", S, second, True), dirrec(b"TOP.TXT;1", top, 3, False)),
        S: sect(dot(S, 2 * SECTOR), dotdot(root, SECTOR), dirrec(b"A1.TXT;1", a1, 2, False)),
        S + 1: sect(dirrec(b"A2.TXT;1", a2, 2, False)),
        a1: b"A1",
        a2: b"A2",
        top: b"TOP",
    }
    write_iso(dst, 26, sectors)
    print("isoshare%s: A (block %d, %d bytes), B (block %d, %d bytes), TOP.TXT"
          % ("2" if longer_first else "", S, first, S, second))
    return 0


def cmd_loop(dst):
    root, S, a1, a2, top, zl, z = 20, 21, 23, 24, 25, 26, 27
    sectors = {
        root: sect(dot(root, SECTOR), dotdot(root, SECTOR), dirrec(b"A", S, SECTOR, True),
                   dirrec(b"TOP.TXT;1", top, 3, False), dirrec(b"ZLAST", zl, SECTOR, True)),
        S: sect(dot(S, SECTOR), dotdot(root, SECTOR), dirrec(b"A1.TXT;1", a1, 2, False),
                dirrec(b"L", S, 2 * SECTOR, True)),
        S + 1: sect(dirrec(b"A2.TXT;1", a2, 2, False)),
        a1: b"A1",
        a2: b"A2",
        top: b"TOP",
        zl: sect(dot(zl, SECTOR), dotdot(root, SECTOR), dirrec(b"Z.TXT;1", z, 1, False)),
        z: b"Z",
    }
    write_iso(dst, 28, sectors)
    print("isoloop: A (block %d, %d bytes) holds L (block %d, %d bytes), TOP.TXT, ZLAST/Z.TXT"
          % (S, SECTOR, S, 2 * SECTOR))
    return 0


def cmd_hlink(dst):
    root, S, x, top = 20, 21, 22, 23
    sectors = {
        root: sect(dot(root, SECTOR), dotdot(root, SECTOR), dirrec(b"A", S, SECTOR, True),
                   dirrec(b"B", S, SECTOR, True), dirrec(b"TOP.TXT;1", top, 3, False)),
        S: sect(dot(S, SECTOR), dotdot(root, SECTOR), dirrec(b"X.TXT;1", x, 1, False)),
        x: b"X",
        top: b"TOP",
    }
    write_iso(dst, 24, sectors)
    print("isohlink: A and B (block %d, %d bytes), TOP.TXT" % (S, SECTOR))
    return 0


def cmd_many(dst):
    root, S, a1, top = 20, 21, 70, 71
    recs = [dot(root, SECTOR), dotdot(root, SECTOR), dirrec(b"A", S, SECTOR, True)]
    for k in range(40):
        recs.append(dirrec(b"F%02d" % k, S, (k + 2) * SECTOR, True))
    recs.append(dirrec(b"TOP.TXT;1", top, 3, False))
    sectors = {
        root: sect(*recs),
        S: sect(dot(S, SECTOR), dotdot(root, SECTOR), dirrec(b"A1.TXT;1", a1, 2, False)),
        a1: b"A1",
        top: b"TOP",
    }
    write_iso(dst, 72, sectors)
    print("isomany: A (block %d, %d bytes) and F00..F39 (block %d, 4096..83968 bytes), TOP.TXT" % (S, SECTOR, S))
    return 0


def main(argv):
    if len(argv) == 2 and argv[0] == "isoshare":
        return cmd_share(argv[1], False)
    if len(argv) == 2 and argv[0] == "isoshare2":
        return cmd_share(argv[1], True)
    if len(argv) == 2 and argv[0] == "isoloop":
        return cmd_loop(argv[1])
    if len(argv) == 2 and argv[0] == "isohlink":
        return cmd_hlink(argv[1])
    if len(argv) == 2 and argv[0] == "isomany":
        return cmd_many(argv[1])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
