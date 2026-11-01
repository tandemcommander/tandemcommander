"""Feature 370: NRG (Nero) images of two tracks whose SINF session counts do not cover the track table, for
iso370_probe.ps1 (the image information, F3 on the image).

  python -I img370.py <kind> <s1.iso> <s2.iso> <s2.lba> <out.nrg>

Built as feature 340's img340.py: the sessions come from feature 334's mkimg334.sh (s2.iso is addressed
from the sector in s2.lba); the NRG ("NER5") holds the track data of two Mode 1 tracks, an ETNF chunk
(0x14 bytes a track), one SINF chunk a session (a big-endian DWORD), END!, and the footer.

Kinds (the SINF counts; the image always holds two tracks):
  fit       1, 1            (control) each session one track
  zero      0, 2            (control) session 1 holds none, session 2 both
  over      1, 2            session 2 counts a track past the table
  short     1               one session of one track - track 2 is in no session
  none      (no SINF)       no session at all - neither track is in a session
  neg       0xFFFFFFFF, 2   session 1's count above 2^31 (an int: -1)
  negend    1, 0xFFFFFFFF   session 2's count above 2^31
"""
import struct
import sys

SECTOR = 2048

COUNTS = {
    "fit": [1, 1],
    "zero": [0, 2],
    "over": [1, 2],
    "short": [1],
    "none": [],
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
    print("%s: %d bytes, two tracks, SINF counts %s" % (kind, len(img), ", ".join("0x%X" % c for c in counts) or "none"))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
