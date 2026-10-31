"""Feature 355: raw (2352-byte sector) disc images opened by the ISO plug-in's plain detection under any
name (.iso, .bin, .mdf - no .cue / .mds is read) - what the listing holds, and whether a whole unpack with
"Delete archive after unpacking" may delete the image.

  python -I img355.py <kind> <s1.iso> <s2.iso> <out>

s1.iso (a.txt "A1", 176 sectors whose primary volume descriptor says 176) and s2.iso (b.txt "B2",
addressed from the sector after s1) come from feature 334's mkimg334.sh; the raw sectors as feature 353's
img353.py writes them (sync, header, user data, 288 bytes of zero EDC/ECC).

Kinds (Mode 1 unless named otherwise):
  one       s1 only - the listing is the whole image
  two       s1 + s2 - the detection lists s1 only; s2 lies past s1's volume (the defect)
  rest16    s1 + 16 sectors of user data 0x5A - no later volume's sector 16 fits
  rest17    s1 + 17 sectors of user data 0x5A - a later volume's sector 16 fits
  zero150   s1 + 150 sectors of zero user data (a post-gap as a raw dump stores it)
  run2      s1 + 2 sectors of 2352 zero bytes (a track-at-once run-out written as zeros)
  zero512   s1 + 512 sectors of zero user data (the most that is read)
  zero513   s1 + 513 sectors of zero user data (more than is read)
  zerolate  s1 + 300 sectors of zero user data, the last user byte of the last sector 1
  audio     s1 + 300 sectors of 2352 bytes of audio-like data (no sync - a CD-Extra track)
  short     s1 without its last 2 sectors (the file ends within the volume)
  bigpvd    as two, s1's volume size patched to 400 in both copies (more than the file's 352 sectors)
  xa2       s1 + s2 as Mode 2 Form 1 sectors (XA, as multi-session discs are written)
  cooked    s1.iso as it is (2048-byte sectors) - not raw, 354's rule
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


def xa(data, lba0):
    sub = bytes([0, 0, 0x08, 0]) * 2  # file 0, channel 0, submode data (Form 1), coding 0 - twice
    out = bytearray()
    for i in range(len(data) // SECTOR):
        out += hdr(lba0 + i, 2) + sub + data[i * SECTOR : (i + 1) * SECTOR] + bytes(280)
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
    zeros = {"zero150": 150, "zero512": 512, "zero513": 513}
    if kind == "one":
        data = mode1(s1, 0)
    elif kind == "two":
        data = mode1(s1, 0) + mode1(s2, n1)
    elif kind in ("rest16", "rest17"):
        data = mode1(s1, 0) + mode1(b"\x5a" * (SECTOR * int(kind[4:])), n1)
    elif kind in zeros:
        data = mode1(s1, 0) + mode1(bytes(SECTOR * zeros[kind]), n1)
    elif kind == "run2":
        data = mode1(s1, 0) + bytes(2352 * 2)
    elif kind == "zerolate":
        rest = bytearray(SECTOR * 300)
        rest[-1] = 1
        data = mode1(s1, 0) + mode1(bytes(rest), n1)
    elif kind == "audio":
        tone = bytes((i * 37 + 11) & 0xFF for i in range(2352))
        data = mode1(s1, 0) + tone * 300
    elif kind == "short":
        data = mode1(s1[: (n1 - 2) * SECTOR], 0)
    elif kind == "bigpvd":
        p = bytearray(s1)
        at = 16 * SECTOR
        p[at + 80 : at + 84] = (400).to_bytes(4, "little")
        p[at + 84 : at + 88] = (400).to_bytes(4, "big")
        data = mode1(bytes(p), 0) + mode1(s2, n1)
    elif kind == "xa2":
        data = xa(s1, 0) + xa(s2, n1)
    elif kind == "cooked":
        data = s1
    else:
        raise SystemExit("unknown kind " + kind)
    open(dst, "wb").write(data)
    print("%s: %d bytes (s1 %d + s2 %d sectors)" % (kind, len(data), n1, n2))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
