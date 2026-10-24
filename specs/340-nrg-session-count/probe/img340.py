"""Feature 340: NRG (Nero) images whose SINF session counts do not fit the track table, for iso340_probe.ps1.

  python -I img340.py <kind> <s1.iso> <s2.iso> <s2.lba> <out.nrg>

The sessions come from feature 334's mkimg334.sh (s2.iso is addressed from the sector in s2.lba). The
NRG (nrg.cpp, "NER5"): the track data of two Mode 1 tracks (s1, s2), an ETNF chunk (0x14 bytes a track:
start and length in bytes, the mode at 0x0B, the first sector at 0x0C - as img334.py), one SINF chunk a
session (its track count, a big-endian DWORD read from the image), END!, and the footer "NER5" + the
chunks' offset.

Kinds (the SINF counts; the image always holds two tracks):
  fit       1, 1            (control) each session one track - "Session 01" a.txt, "Session 02" b.txt
  zero      0, 2            (control) the counts add up to the tracks - session 1 holds none
  over      1, 2            session 2 counts a track past the table
  over1000  1, 1000         session 2 counts 999 tracks past the table
  extra     1, 1, 1         a third session whose track the image does not hold
  neg       0xFFFFFFFF, 2   session 1's count read as a negative int (the plug-in walked track -1 next)
  negend    1, 0xFFFFFFFF   session 2's count read as a negative int (its track was never listed)
"""
import struct
import sys

SECTOR = 2048

COUNTS = {
    "fit": [1, 1],
    "zero": [0, 2],
    "over": [1, 2],
    "over1000": [1, 1000],
    "extra": [1, 1, 1],
    "neg": [0xFFFFFFFF, 2],
    "negend": [1, 0xFFFFFFFF],
}


def chunk(cid, body):
    return cid + struct.pack(">I", len(body)) + body


def main(argv):
    if len(argv) != 5:
        print(__doc__)
        return 2
    kind, p1, p2, plba, dst = argv
    if kind not in COUNTS:
        raise SystemExit("unknown kind " + kind)
    s1 = open(p1, "rb").read()
    s2 = open(p2, "rb").read()
    lba2 = int(open(plba, "r").read().strip())
    if len(s1) != lba2 * SECTOR:
        raise SystemExit("s1.iso is %d bytes, s2.lba says %d sectors" % (len(s1), lba2))
    data = s1 + s2
    entries = [(0, len(s1), 0, 0x00), (len(s1), len(s2), lba2, 0x00)]
    etnf = b""
    for start, length, lba, mode in entries:
        etnf += struct.pack(">II", start, length) + bytes([0, 0, 0, mode]) + struct.pack(">I", lba) + bytes(4)
    counts = COUNTS[kind]
    sinf = b"".join(chunk(b"SINF", struct.pack(">I", c)) for c in counts)
    chunks = chunk(b"ETNF", etnf) + sinf + chunk(b"END!", b"")
    img = data + chunks + b"NER5" + struct.pack(">Q", len(data))
    open(dst, "wb").write(img)
    print("%s: %d bytes, two tracks, SINF counts %s" % (kind, len(img), ", ".join("0x%X" % c for c in counts)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
