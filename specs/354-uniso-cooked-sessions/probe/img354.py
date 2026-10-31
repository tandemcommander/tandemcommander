"""Feature 354: cooked (2048-byte sector) disc images - what the ISO plug-in's plain detection lists
(the volume whose primary volume descriptor is at sector 16), and whether a whole unpack with "Delete
archive after unpacking" may delete the image.

  python -I img354.py <kind> <s1.iso> <s2.iso> <out>

s1.iso (a.txt "A1", 176 sectors, its primary volume descriptor says 176) and s2.iso (b.txt "B2",
addressed from the sector after s1) come from feature 334's mkimg334.sh. Every image is cooked: no CD
sync pattern, 2048 bytes a sector, no .ccd beside it.

Kinds:
  plain      s1 as it is - the file equals the volume (unchanged: deleted)
  two        s1 + s2 joined - a second session past the first volume (the defect: deleted, b.txt lost)
  rest16     s1 + 16 sectors of 0x5A - too few for a later volume's sector 16 (unchanged: deleted)
  rest17     s1 + 17 sectors of 0x5A - a later volume's sector 16 fits (kept)
  zero168    s1 + 168 sectors of zeros - xorriso's native padding outside the volume (deleted)
  zero512    s1 + 512 sectors of zeros - the most zero sectors read (deleted)
  zero513    s1 + 513 sectors of zeros - more than is read: not all checked (kept)
  zerolate   s1 + 300 sectors of zeros whose last byte is 1 - the whole tail is read (kept)
  short      s1 without its last 2 sectors - the file ends within the volume (kept, as 353)
  bigpvd     as two, s1's volume size patched to 400 in both copies (more than the file's 352 sectors:
             a size that cannot be trusted - kept, as 353)
"""
import sys

SECTOR = 2048


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    kind, p1, p2, dst = argv
    s1 = open(p1, "rb").read()
    s2 = open(p2, "rb").read()
    n1 = len(s1) // SECTOR
    n2 = len(s2) // SECTOR
    if kind == "plain":
        data = s1
        note = "one volume of %d sectors" % n1
    elif kind == "two":
        data = s1 + s2
        note = "two sessions, %d + %d sectors" % (n1, n2)
    elif kind in ("rest16", "rest17"):
        k = int(kind[4:])
        data = s1 + b"\x5a" * (SECTOR * k)
        note = "one volume of %d sectors + %d sectors of 0x5A" % (n1, k)
    elif kind in ("zero168", "zero512", "zero513"):
        k = int(kind[4:])
        data = s1 + bytes(SECTOR * k)
        note = "one volume of %d sectors + %d sectors of zeros" % (n1, k)
    elif kind == "zerolate":
        data = s1 + bytes(SECTOR * 300 - 1) + b"\x01"
        note = "one volume of %d sectors + 300 sectors of zeros, the last byte 1" % n1
    elif kind == "short":
        data = s1[: (n1 - 2) * SECTOR]
        note = "a volume of %d sectors cut to %d" % (n1, n1 - 2)
    elif kind == "bigpvd":
        p = bytearray(s1)
        at = 16 * SECTOR
        p[at + 80 : at + 84] = (400).to_bytes(4, "little")
        p[at + 84 : at + 88] = (400).to_bytes(4, "big")
        data = bytes(p) + s2
        note = "two sessions, %d + %d sectors, session 1's volume size 400" % (n1, n2)
    else:
        raise SystemExit("unknown kind " + kind)
    open(dst, "wb").write(data)
    print("%s: %s" % (kind, note))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
