"""Feature 335: NRG (Nero) images of a data track in which no file system is found, for iso335_probe.ps1.

  python -I img335.py <kind> <s1.iso> <s2.iso> <s2.lba> <out.nrg>

The seed sessions come from feature 334's mkimg334.sh (s1.iso: a.txt "A1"; s2.iso: b.txt "B2", addressed
from the sector in s2.lba). The NRG layout is feature 334's img334.py ("NER5": the track data, an ETNF
chunk of 0x14 bytes a track - start and length in bytes, the mode byte at 0x0B, the track's first sector
at 0x0C -, SINF chunks with each session's track count, END!, the footer "NER5" + the chunks' offset).
ETNF mode bytes used here (nrg.cpp readETNF / SetTrackTypeMode): 0x00 = Mode 1, 2048 bytes a sector;
0x03 = Mode 2, 2336 bytes a sector (an 8-byte subheader, then the user data - no sync, no header).

Track 2 of every kind is session 2's track (s2.iso) or a stand-in of the same length in sectors:
  multi_nofs     two sessions; track 2 Mode 1 / 2048, every "CD001" of its sectors 16..127 destroyed
                 ("CD001" -> "XXXXX"): no file system is found, the files of session 2 are lost to a listing
  multi_ok_2336  two sessions; track 2 Mode 2 / 2336 in Form 1 sectors (submode 0x08), intact - a control
                 that the plug-in reads such a track (lists b.txt)
  multi_nofs_f1  as multi_ok_2336, every "CD001" destroyed (a damaged Mode 2 Form 1 data session)
  multi_form2    two sessions; track 2 Mode 2 / 2336 in Form 2 sectors (submode 0x62 - Form 2, video,
                 real time: a Video CD's MPEG stream), no file system
  single_vcd     one session: track 1 s1 (Mode 1), track 2 as multi_form2 (a Video CD's layout: an
                 ISO 9660 track, then the MPEG track)
  single_nofs    one session: track 1 s1, track 2 as multi_nofs
  single_raw     one session: track 1 s1, track 2 Mode 1 / 2048 zeros (feature 334's S-RAW image)
"""
import struct
import sys

SECTOR = 2048


def chunk(cid, body):
    return cid + struct.pack(">I", len(body)) + body


def kill_descriptors(data):
    data = bytearray(data)
    n = 0
    for s in range(16, min(len(data) // SECTOR, 128)):
        o = s * SECTOR
        if data[o + 1 : o + 6] == b"CD001":
            data[o + 1 : o + 6] = b"XXXXX"
            n += 1
    if n == 0:
        raise SystemExit("no volume descriptor found")
    return bytes(data), n


def mode2_2336(data, submode, fill):
    """Sectors of 2336 bytes: subheader (file, channel, submode, coding - twice), then the user data:
    Form 1 = 2048 bytes + 280 bytes of EDC / ECC (zeros), Form 2 = 2324 bytes + 4 bytes of EDC."""
    sub = bytes([0, 0, submode, 0, 0, 0, submode, 0])
    out = bytearray()
    for s in range(len(data) // SECTOR):
        user = data[s * SECTOR : (s + 1) * SECTOR]
        if submode & 0x20:
            body = bytes(((s + i) * fill) & 0xFF for i in range(2324)) + bytes(4)
        else:
            body = user + bytes(280)
        out += sub + body
    return bytes(out)


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
    mode = 0x00
    if kind in ("multi_nofs", "single_nofs"):
        t2, n = kill_descriptors(s2)
        note = "track 2 Mode 1, %d volume descriptors destroyed" % n
    elif kind == "single_raw":
        t2 = bytes(len(s2))
        note = "track 2 Mode 1 zeros"
    elif kind == "multi_ok_2336":
        t2 = mode2_2336(s2, 0x08, 0)
        mode = 0x03
        note = "track 2 Mode 2 / 2336 Form 1, intact"
    elif kind == "multi_nofs_f1":
        k, n = kill_descriptors(s2)
        t2 = mode2_2336(k, 0x08, 0)
        mode = 0x03
        note = "track 2 Mode 2 / 2336 Form 1, %d volume descriptors destroyed" % n
    elif kind in ("multi_form2", "single_vcd"):
        t2 = mode2_2336(s2, 0x62, 13)
        mode = 0x03
        note = "track 2 Mode 2 / 2336 Form 2 (MPEG-like stream)"
    else:
        raise SystemExit("unknown kind " + kind)
    data = s1 + t2
    entries = [(0, len(s1), 0, 0x00), (len(s1), len(t2), lba2, mode)]
    counts = [1, 1] if kind.startswith("multi") else [2]
    etnf = b""
    for start, length, lba, m in entries:
        etnf += struct.pack(">II", start, length) + bytes([0, 0, 0, m]) + struct.pack(">I", lba) + bytes(4)
    sinf = b"".join(chunk(b"SINF", struct.pack(">I", c)) for c in counts)
    chunks = chunk(b"ETNF", etnf) + sinf + chunk(b"END!", b"")
    img = data + chunks + b"NER5" + struct.pack(">Q", len(data))
    open(dst, "wb").write(img)
    print("%s: %d bytes, track 2 from sector %d; %s" % (kind, len(img), lba2, note))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
