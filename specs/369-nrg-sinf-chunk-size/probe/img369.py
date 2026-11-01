"""Feature 369: NRG (Nero) images whose SINF chunk is not 4 bytes, for iso369_probe.ps1.

  python -I img369.py <kind> <s1.iso> <s2.iso> <s2.lba> <out.nrg>

Built as feature 340's img340.py: the track data of two Mode 1 tracks (s1, s2 from feature 334's
mkimg334.sh), an ETNF chunk (0x14 bytes a track), the SINF chunks, END!, and the footer "NER5" + the
chunks' offset. A SINF chunk holds one big-endian DWORD - the session's track count (libmirage: 4 bytes).

Kinds (the SINF chunks, as (size, count); the image always holds two tracks, one a session):
  fit       (4, 1), (4, 1)              control: "Session 01" a.txt, "Session 02" b.txt
  sinf8     (8, 1 + 4 zero bytes), (4, 1)   the first SINF chunk 4 bytes longer than its count
  sinf8tail (4, 1), (8, 1 + 4 zero bytes)   the last SINF chunk 4 bytes longer than its count
  sinf2     (2, 0x0000), (4, 1)         the first SINF chunk 2 bytes - shorter than a count
  sinf0     (0, -), (4, 1), (4, 1)      an empty SINF chunk before two whole ones
"""
import struct
import sys

SECTOR = 2048

# each SINF chunk as its body
KINDS = {
    "fit": [struct.pack(">I", 1), struct.pack(">I", 1)],
    "sinf8": [struct.pack(">I", 1) + bytes(4), struct.pack(">I", 1)],
    "sinf8tail": [struct.pack(">I", 1), struct.pack(">I", 1) + bytes(4)],
    "sinf2": [bytes(2), struct.pack(">I", 1)],
    "sinf0": [b"", struct.pack(">I", 1), struct.pack(">I", 1)],
}


def chunk(cid, body):
    return cid + struct.pack(">I", len(body)) + body


def main(argv):
    if len(argv) != 5:
        print(__doc__)
        return 2
    kind, p1, p2, plba, dst = argv
    if kind not in KINDS:
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
    bodies = KINDS[kind]
    sinf = b"".join(chunk(b"SINF", b) for b in bodies)
    chunks = chunk(b"ETNF", etnf) + sinf + chunk(b"END!", b"")
    img = data + chunks + b"NER5" + struct.pack(">Q", len(data))
    open(dst, "wb").write(img)
    print("%s: %d bytes, two tracks, SINF chunks of %s bytes" % (kind, len(img), ", ".join(str(len(b)) for b in bodies)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
