"""Review 3 of feature 335: images from real vcdimager output (vcd.bin / svcd.bin, raw 2352-byte sectors)
and edge layouts.

  python -I gen335c.py <data dir> <s1.iso> <out dir>

real_vcd.img/.ccd    vcdimager VCD 2.0 (3 tracks: ISO, 2 MPEG) as CloneCD
real_svcd.img/.ccd   vcdimager SVCD (2 tracks) as CloneCD
real_vcd.nrg         the same VCD as NRG ETNF, every track Mode 2 / 2336 (mode 0x03)
real_vcd_hole.img    real_vcd with track 2's sector 20 (from INDEX 01) zero-filled (a dumper's fill)
short_dmg.nrg        one session: s1 (Mode 1), a 10-sector Mode 2 / 2336 Form 1 track (zeros), then a
                     64-sector Form 2 stream - the short track's sector 16 lies in the stream track
"""
import struct
import sys

RAW = 2352


def ccd_text(points, modes, leadout):
    ccd = ["[CloneCD]", "Version=3", "[Disc]", "TocEntries=%d" % (len(points) + 3), "Sessions=1",
           "DataTracksScrambled=0", "CDTextLength=0", "[Session 1]", "PreGapMode=2", "PreGapSubC=0"]
    entries = [(0xA0, 1), (0xA1, len(points)), (0xA2, leadout)] + [(i + 1, p) for i, p in enumerate(points)]
    for i, (pt, plba) in enumerate(entries):
        ccd += ["[Entry %d]" % i, "Session=1", "Point=0x%02x" % pt, "ADR=0x01", "Control=0x04", "TrackNo=0",
                "AMin=0", "ASec=0", "AFrame=0", "ALBA=-150", "Zero=0", "PMin=0", "PSec=0", "PFrame=0",
                "PLBA=%d" % plba]
    for i, (p, m) in enumerate(zip(points, modes)):
        ccd += ["[TRACK %d]" % (i + 1), "MODE=%d" % m, "INDEX 1=%d" % p]
    return "\n".join(ccd) + "\n"


def write_ccd(dst, data, points, modes):
    open(dst, "wb").write(data)
    open(dst[:-4] + ".ccd", "w", newline="\r\n").write(ccd_text(points, modes, len(data) // RAW))


def chunk(cid, body):
    return cid + struct.pack(">I", len(body)) + body


def write_nrg(dst, tracks, counts):
    """tracks: list of (bytes, mode byte, lba)"""
    data = b""
    etnf = b""
    for t, m, lba in tracks:
        etnf += struct.pack(">II", len(data), len(t)) + bytes([0, 0, 0, m]) + struct.pack(">I", lba) + bytes(4)
        data += t
    sinf = b"".join(chunk(b"SINF", struct.pack(">I", c)) for c in counts)
    img = data + chunk(b"ETNF", etnf) + sinf + chunk(b"END!", b"") + b"NER5" + struct.pack(">Q", len(data))
    open(dst, "wb").write(img)


def to2336(raw):
    out = bytearray()
    for i in range(len(raw) // RAW):
        out += raw[i * RAW + 16:(i + 1) * RAW]
    return bytes(out)


def main(argv):
    ddir, s1p, out = argv
    vcd = open(ddir + "/vcd.bin", "rb").read()
    svcd = open(ddir + "/svcd.bin", "rb").read()
    vpts = [0, 450, 897]  # INDEX 01 of each track (vcd.cue)
    write_ccd(out + "/real_vcd.img", vcd, vpts, [2, 2, 2])
    write_ccd(out + "/real_svcd.img", svcd, [0, 450], [2, 2])
    hole = bytearray(vcd)
    s = 450 + 20
    hole[s * RAW:(s + 1) * RAW] = bytes(RAW)
    write_ccd(out + "/real_vcd_hole.img", bytes(hole), vpts, [2, 2, 2])
    # NRG ETNF 2336: track boundaries at INDEX 01 (the pregap belongs to the track before, as CCD here)
    b = vpts + [len(vcd) // RAW]
    tr = [(to2336(vcd[b[i] * RAW:b[i + 1] * RAW]), 0x03, b[i]) for i in range(3)]
    write_nrg(out + "/real_vcd.nrg", tr, [3])
    # short damaged track before a Form 2 stream
    s1 = open(s1p, "rb").read()
    n1 = len(s1) // 2048
    f1 = bytes([0, 0, 8, 0, 0, 0, 8, 0])
    short = b"".join(f1 + bytes(2328) for _ in range(10))
    f2 = bytes([1, 1, 0x62, 0x0F, 1, 1, 0x62, 0x0F])
    stream = b"".join(f2 + bytes(((i + k) * 7) & 0xFF for k in range(2324)) + bytes(4) for i in range(64))
    write_nrg(out + "/short_dmg.nrg", [(s1, 0x00, 0), (short, 0x03, n1), (stream, 0x03, n1 + 10)], [3])
    print("ok")


if __name__ == "__main__":
    main(sys.argv[1:])
