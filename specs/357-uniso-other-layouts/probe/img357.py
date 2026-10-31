"""Feature 357: disc images the ISO plug-in's plain detection opens through a layout other than "raw with the
CD sync pattern at sector 0" (355) or "cooked, 2048-byte sectors from offset 0" (354) - what the listing
holds, and whether a whole unpack with "Delete archive after unpacking" may delete the image.

  python -I img357.py <layout>-<variant> <s1.iso> <s2.iso> <out>

s1.iso (a.txt "A1", 176 sectors whose primary volume descriptor says 176) and s2.iso (b.txt "B2",
addressed from the sector after s1) come from feature 334's mkimg334.sh.

Layouts (CISOImage::Open's plain branch, the order of its checks; none has the sync pattern at offset 0):
  nrg      0x4B000 bytes of zeros, then 2048-byte sectors        (CheckForNRG)
  2336     sectors of 2336 bytes: 8-byte subheader + 2048 + 280   (CheckFor2336, first offset)
  ncd      0x16E4E bytes of zeros, then 2048-byte sectors        (CheckForNCD)
  pdi      0x130 bytes of zeros, then 2048-byte sectors          (CheckForPDI)
  ecdc     sectors of 2352 bytes, sync and header zeroed: 24 zero bytes + 2048 + 280 (CheckForECDC)
  cif      RIFF imag / disc / info chunks (44 bytes), then sectors of 8 + 2048 bytes (CheckForCIF)
  c2d      0x20000 bytes of zeros, then 2048-byte sectors        (CheckForC2D, WinOnCD)
  c2dm2    0x76220 bytes of zeros, then Mode 2 Form 1 sectors (sync, header, subheader) (CheckForC2D)
  roxio    0x120 bytes of zeros, then 2048-byte sectors          (CheckForC2D, Roxio Image Format 3.0;
           a file shorter than 0x7F53E bytes is not opened at all - CheckForC2D returns before)
  cif2332  sectors of 2332 bytes: 8-byte subheader + 2048 + 276   (CheckForCIF2332)

Variants:
  one      s1 only - the listing is the whole image
  two      s1 + s2 - the detection lists s1 only; s2 lies past s1's volume (the defect)
  rest16   s1 + 16 sectors of user data 0x5A - no later volume's sector 16 fits
  rest17   s1 + 17 sectors of user data 0x5A - a later volume's sector 16 fits
  zero150  s1 + 150 sectors of zero user data (a post-gap)
  zero513  s1 + 513 sectors of zero user data (more than is read)
  short    s1 without its last 2 sectors (the file ends within the volume)

The script mirrors the plain detection's order of checks and refuses to write an image that an earlier
check would open through another layout (prints the layout the detection picks).
"""
import sys

SECTOR = 2048
SYNC = b"\x00" + b"\xff" * 10 + b"\x00"
XA_SUB = bytes([0, 0, 0x08, 0]) * 2  # file 0, channel 0, submode data (Form 1), coding 0 - twice


def msf(lba, mode):
    a = lba + 150
    m, s, f = a // 4500, (a // 75) % 60, a % 75
    bcd = lambda v: ((v // 10) << 4) | (v % 10)
    return SYNC + bytes([bcd(m), bcd(s), bcd(f), mode])


def sectors(data):
    return [data[i * SECTOR : (i + 1) * SECTOR] for i in range(len(data) // SECTOR)]


def riff(ident, body=b""):
    return b"RIFF" + (len(body) + 4).to_bytes(4, "little") + ident + body


CIF_PREFIX = riff(b"imag") + riff(b"disc") + riff(b"info") + bytes(8)  # 12 + 12 + 12 + 8 = 44 bytes


def build(layout, data):
    s = sectors(data)
    if layout == "nrg":
        return bytes(0x4B000) + data
    if layout == "2336":
        return b"".join(XA_SUB + x + bytes(280) for x in s)
    if layout == "ncd":
        return bytes(0x16E4E) + data
    if layout == "pdi":
        return bytes(0x130) + data
    if layout == "ecdc":
        return b"".join(bytes(24) + x + bytes(280) for x in s)
    if layout == "cif":
        return CIF_PREFIX + b"".join(XA_SUB + x for x in s)
    if layout == "c2d":
        return bytes(0x20000) + data
    if layout == "c2dm2":
        return bytes(0x76220) + b"".join(msf(i, 2) + XA_SUB + x + bytes(280) for i, x in enumerate(s))
    if layout == "roxio":
        return bytes(0x120) + data
    if layout == "cif2332":
        return b"".join(XA_SUB + x + bytes(276) for x in s)
    raise SystemExit("unknown layout " + layout)


def cd(img, at):
    return img[at : at + 6] == b"\x01CD001"


def udf(img, at):
    return img[at : at + 6] == b"\x00BEA01"


def detect(img):
    """The plain branch of CISOImage::Open for a file without the sync pattern at offset 0."""
    if img[:12] == SYNC:
        return "raw start (355)"
    if cd(img, 0x8000) or udf(img, 0x8000):
        return "cooked (354)"
    if cd(img, 0x4B000 + 0x8000) or udf(img, 0x4B000 + 0x8000):
        return "nrg"
    if cd(img, 0x9208) or cd(img, 0x5EAC8):
        return "2336"
    if cd(img, 0x1EE4E):
        return "ncd"
    if cd(img, 0x8130):
        return "pdi"
    if cd(img, 0x9318):
        return "ecdc"
    if img[0:4] == b"RIFF" and img[8:12] == b"imag":
        return "cif"
    if cd(img, 0x28000):
        return "c2d"
    # CheckForC2D returns FALSE when 0x7F538 cannot be read: a Roxio image shorter than that never opens
    if len(img) >= 0x7F538 + 6:
        if cd(img, 0x7F538):
            return "c2dm2"
        if cd(img, 0x8120):
            return "roxio"
    if cd(img, 0x91C8):
        return "cif2332"
    return "none"


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    kind, p1, p2, dst = argv
    layout, variant = kind.split("-", 1)
    s1 = open(p1, "rb").read()
    s2 = open(p2, "rb").read()
    n1 = len(s1) // SECTOR
    if variant == "one":
        data = s1
    elif variant == "two":
        data = s1 + s2
    elif variant in ("rest16", "rest17"):
        data = s1 + b"\x5a" * (SECTOR * int(variant[4:]))
    elif variant in ("zero150", "zero513"):
        data = s1 + bytes(SECTOR * int(variant[4:]))
    elif variant == "short":
        data = s1[: (n1 - 2) * SECTOR]
    else:
        raise SystemExit("unknown variant " + variant)
    img = build(layout, data)
    got = detect(img)
    if got != layout:
        raise SystemExit("%s: the detection would pick %s, not %s - not written" % (kind, got, layout))
    open(dst, "wb").write(img)
    print("%s: %d bytes, %d data sectors, detected as %s" % (kind, len(img), len(data) // SECTOR, got))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
