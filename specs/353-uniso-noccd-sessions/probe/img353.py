"""Feature 353: CloneCD-like raw images (.img, 2352-byte Mode 1 sectors) WITHOUT their .ccd, and a
plain (2048-byte) .img - what the ISO plug-in's detection without a .ccd lists, and whether a whole
unpack with "Delete archive after unpacking" may delete the image.

  python -I img353.py <kind> <s1.iso> <s2.iso> <out.img>

s1.iso (a.txt "A1") and s2.iso (b.txt "B2", addressed from the sector after s1) come from feature 334's
mkimg334.sh; the raw sectors as feature 352's img352.py writes them. No .ccd is written.

Kinds:
  noccd      one session (s1), raw - the listing is the whole image (352's C-NOCCD)
  noccd2     two sessions (s1, s2), raw - the detection lists s1 only; s2 lies past s1's volume
  noccd_r2   s1 + 2 raw sectors of zeros (a track-at-once run-out) - no later volume fits
  noccd_r16  s1 + 16 raw sectors of zeros - the most that cannot hold a later volume's sector 16
  noccd_r17  s1 + 17 raw sectors of zeros - a later volume's sector 16 would fit
  cooked     s1.iso as it is (2048-byte sectors, a plain disk image) - unchanged
"""
import sys

SECTOR = 2048
SYNC = b"\x00" + b"\xff" * 10 + b"\x00"


def hdr(lba, mode):
    a = lba + 150
    m, s, f = a // 4500, (a // 75) % 60, a % 75
    bcd = lambda v: ((v // 10) << 4) | (v % 10)
    return SYNC + bytes([bcd(m), bcd(s), bcd(f), mode])


def mode1(data, lba0):
    out = bytearray()
    for i in range(len(data) // SECTOR):
        out += hdr(lba0 + i, 1) + data[i * SECTOR : (i + 1) * SECTOR] + bytes(288)
    return bytes(out)


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    kind, p1, p2, dst = argv
    s1 = open(p1, "rb").read()
    s2 = open(p2, "rb").read()
    n1 = len(s1) // SECTOR
    n2 = len(s2) // SECTOR
    rest = {"noccd_r2": 2, "noccd_r16": 16, "noccd_r17": 17}
    if kind == "noccd":
        data = mode1(s1, 0)
        note = "one Mode 1 session of %d raw sectors" % n1
    elif kind == "noccd2":
        data = mode1(s1, 0) + mode1(s2, n1)
        note = "two Mode 1 sessions, %d + %d raw sectors" % (n1, n2)
    elif kind in rest:
        data = mode1(s1, 0) + mode1(bytes(SECTOR * rest[kind]), n1)
        note = "one Mode 1 session of %d raw sectors + %d raw sectors of zeros" % (n1, rest[kind])
    elif kind == "cooked":
        data = s1
        note = "one session of %d sectors of 2048 bytes" % n1
    else:
        raise SystemExit("unknown kind " + kind)
    open(dst, "wb").write(data)
    print("%s: %s" % (kind, note))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
