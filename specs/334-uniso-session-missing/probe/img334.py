"""Feature 334: NRG (Nero) images of two ISO 9660 data tracks for iso334_probe.ps1.

  python -I img334.py <kind> <s1.iso> <s2.iso> <s2.lba> <out.nrg>

The sessions come from mkimg334.sh (s2.iso is addressed from the sector in s2.lba). The NRG (nrg.cpp,
"NER5"): the track data, then an ETNF chunk (0x14 bytes a track: start and length in bytes, the track
mode at 0x0B - 0 = Mode 1 / 2048 bytes a sector, the track's first sector at 0x0C), SINF chunks (one a
session: its track count), END!, and the footer "NER5" + the chunks' offset.

Kinds:
  multi       two sessions, one track each (the plug-in lists "Session 01" and "Session 02")
  multi_term  as multi, the volume descriptor set terminator of track 2 destroyed ("CD001" -> "XXXXX"):
              the descriptors still say ISO 9660, but the ISO 9660 reader does not open the track
  multi_past  as multi, track 2's start in the ETNF chunk past the end of the image
  single      one session of the two tracks (the plug-in lists only the last track)
  single_term as single, track 2's terminator destroyed (the last data track does not open)
"""
import struct
import sys

SECTOR = 2048


def chunk(cid, body):
    return cid + struct.pack(">I", len(body)) + body


def kill_terminator(data):
    data = bytearray(data)
    for s in range(16, min(len(data) // SECTOR, 128)):
        o = s * SECTOR
        if data[o] == 0xFF and data[o + 1 : o + 6] == b"CD001":
            data[o + 1 : o + 6] = b"XXXXX"
            return bytes(data), s
    raise SystemExit("no terminator found")


def main(argv):
    if len(argv) != 5:
        print(__doc__)
        return 2
    kind, p1, p2, plba, dst = argv
    s1 = open(p1, "rb").read()
    s2 = open(p2, "rb").read()
    lba2 = int(open(plba, "r").read().strip())
    if len(s1) != lba2 * SECTOR:
        raise SystemExit("s1.iso is %d bytes, s2.lba says %d sectors" % (len(s1), lba2))
    note = ""
    if kind.endswith("_term"):
        s2, t = kill_terminator(s2)
        note = "terminator of track 2 at its sector %d destroyed" % t
    data = s1 + s2
    starts = [0, len(s1)]
    if kind == "multi_past":
        starts[1] = len(data) + 0x10000000
        note = "track 2 starts at %d, the image has %d bytes of track data" % (starts[1], len(data))
    etnf = b""
    for start, length, lba in ((starts[0], len(s1), 0), (starts[1], len(s2), lba2)):
        etnf += struct.pack(">II", start, length) + bytes([0, 0, 0, 0x00]) + struct.pack(">I", lba) + bytes(4)
    if kind.startswith("multi"):
        sinf = chunk(b"SINF", struct.pack(">I", 1)) + chunk(b"SINF", struct.pack(">I", 1))
    elif kind.startswith("single"):
        sinf = chunk(b"SINF", struct.pack(">I", 2))
    else:
        raise SystemExit("unknown kind " + kind)
    chunks = chunk(b"ETNF", etnf) + sinf + chunk(b"END!", b"")
    img = data + chunks + b"NER5" + struct.pack(">Q", len(data))
    open(dst, "wb").write(img)
    print("%s: %d bytes, track 2 from sector %d%s" % (kind, len(img), lba2, ("; " + note) if note else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
