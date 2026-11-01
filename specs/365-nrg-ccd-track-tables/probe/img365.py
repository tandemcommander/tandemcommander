"""Feature 365: NRG (Nero) images read through ETNF / ETN2 track tables and CloneCD (.img + .ccd) images
of two sessions, for iso365_probe.ps1.

  python -I img365.py <kind> <s1.iso> <s2.iso> <s2.lba> <out>

s1.iso (a.txt "A1", from sector 0) and s2.iso (b.txt "B2", addressed from the sector in s2.lba - session 1's
sectors + 11400, the lead-out / lead-in / pregap no image holds) come from mkimg365.sh. Session 2's data
follows session 1's in every image (packed, as Nero's track offsets and CloneCD's .img lay them out).

NRG layout (as feature 335's img335.py): the track data, the track chunks, SINF chunks with each
session's track count, END!, the footer "NER5" + the chunks' offset. An ETNF entry is 20 bytes (start and
length in bytes as 32 bits, the mode byte at 0x0B, the track's first sector at 0x0C); an ETN2 entry 32 bytes
(start and length as 64 bits, the mode byte at 0x13, the first sector at 0x14) - libmirage's
NRG_ETN_Block. Nero's mode bytes (libmirage's mirage_parser_nrg_decode_mode): 0x00 Mode 1 / 2048,
0x03 Mode 2 / 2336, 0x05 Mode 1 / 2352 (raw), 0x06 Mode 2 / 2352 (raw).

Kinds (.nrg):
  etnf_00    (control) ETNF, two sessions, both tracks Mode 1 / 2048 (0x00)
  etnf_05    ETNF, track 2 raw Mode 1 (0x05, 2352 bytes a sector) - read as 2336 before 365
  etnf_06    ETNF, track 2 raw Mode 2 Form 1 (0x06, 2352) - read as 2048 before 365
  etn2_one   (control) ETN2, one session, one Mode 1 / 2048 track from offset 0
  etn2_00    ETN2, two sessions (a chunk each), Mode 1 / 2048 - track 2's end was its length
  etn2_03    ETN2, two sessions, track 2 Mode 2 / 2336 Form 1 (0x03) - read as 2048 before 365
  etn2_06    ETN2, two sessions, track 2 raw Mode 2 Form 1 (0x06)
  etn2_one150, etn2_150
             as etn2_one / etn2_00, the first-sector fields 150 higher (review 1: libmirage never reads
             the field - an origin other than 0 must not move the image's first track off sector 0)
Kinds (.img + .ccd, raw Mode 1 sectors of 2352 bytes, the TOC as CloneCD writes it: A0 / A1 / A2 / track
points per session, B0 / C0 (ADR 5) closing session 1, PLBA from the start of the disc):
  ccd_rel    (control) [TRACK n] INDEX 1 counted from the start of its session (both 0) - CloneCD's
             reading (libmirage, psx-spx)
  ccd_abs    track 2's INDEX 1 counted from the start of the disc (its PLBA) - the item's reading: one
             INDEX-1 split for two sessions, the last track's sector count underflowed
"""
import struct
import sys

SECTOR = 2048
SYNC = b"\x00" + b"\xff" * 10 + b"\x00"
GAP = 11400


def chunk(cid, body):
    return cid + struct.pack(">I", len(body)) + body


def hdr(lba, mode):
    a = lba + 150
    m, s, f = a // 4500, (a // 75) % 60, a % 75
    bcd = lambda v: ((v // 10) << 4) | (v % 10)
    return SYNC + bytes([bcd(m), bcd(s), bcd(f), mode])


def raw_mode1(data, lba0):
    out = bytearray()
    for i in range(len(data) // SECTOR):
        out += hdr(lba0 + i, 1) + data[i * SECTOR : (i + 1) * SECTOR] + bytes(288)
    return bytes(out)


def raw_mode2_f1(data, lba0):
    sub = bytes([0, 0, 8, 0, 0, 0, 8, 0])
    out = bytearray()
    for i in range(len(data) // SECTOR):
        out += hdr(lba0 + i, 2) + sub + data[i * SECTOR : (i + 1) * SECTOR] + bytes(280)
    return bytes(out)


def mode2_2336_f1(data):
    sub = bytes([0, 0, 8, 0, 0, 0, 8, 0])
    out = bytearray()
    for i in range(len(data) // SECTOR):
        out += sub + data[i * SECTOR : (i + 1) * SECTOR] + bytes(280)
    return bytes(out)


def etnf_entry(start, length, lba, mode):
    return struct.pack(">II", start, length) + bytes([0, 0, 0, mode]) + struct.pack(">I", lba) + bytes(4)


def etn2_entry(start, length, lba, mode):
    return struct.pack(">QQ", start, length) + bytes([0, 0, 0, mode]) + struct.pack(">I", lba) + bytes(8)


def nrg(dst, s1, s2, lba2, kind):
    t2, m2 = s2, 0x00
    if kind == "etnf_05":
        t2, m2 = raw_mode1(s2, lba2), 0x05
    elif kind in ("etnf_06", "etn2_06"):
        t2, m2 = raw_mode2_f1(s2, lba2), 0x06
    elif kind == "etn2_03":
        t2, m2 = mode2_2336_f1(s2), 0x03
    # review 1: first-sector fields counted from another origin (+150, as if with the pregap)
    base = 150 if kind in ("etn2_one150", "etn2_150") else 0
    if kind in ("etn2_one", "etn2_one150"):
        data = s1
        chunks = chunk(b"ETN2", etn2_entry(0, len(s1), base, 0x00)) + chunk(b"SINF", struct.pack(">I", 1))
    elif kind.startswith("etnf"):
        data = s1 + t2
        chunks = chunk(b"ETNF", etnf_entry(0, len(s1), 0, 0x00) + etnf_entry(len(s1), len(t2), lba2, m2))
        chunks += chunk(b"SINF", struct.pack(">I", 1)) + chunk(b"SINF", struct.pack(">I", 1))
    else:
        data = s1 + t2
        chunks = chunk(b"ETN2", etn2_entry(0, len(s1), base, 0x00)) + chunk(b"SINF", struct.pack(">I", 1))
        chunks += chunk(b"ETN2", etn2_entry(len(s1), len(t2), lba2 + base, m2)) + chunk(b"SINF", struct.pack(">I", 1))
    img = data + chunks + chunk(b"END!", b"") + b"NER5" + struct.pack(">Q", len(data))
    open(dst, "wb").write(img)
    return "%d bytes, track 2 mode 0x%02x from byte %d, sector %d" % (len(img), m2, len(s1), lba2)


def msf(lba):
    a = lba + 150
    return a // 4500, (a // 75) % 60, a % 75


def entry(i, session, point, plba, adr=1, pmsf=None):
    pm, ps, pf = pmsf if pmsf is not None else msf(plba)
    return ["[Entry %d]" % i, "Session=%d" % session, "Point=0x%02x" % point, "ADR=0x%02x" % adr, "Control=0x04",
            "TrackNo=0", "AMin=0", "ASec=0", "AFrame=0", "ALBA=-150", "Zero=0", "PMin=%d" % pm, "PSec=%d" % ps,
            "PFrame=%d" % pf, "PLBA=%d" % plba]


def ccd(dst, s1, s2, lba2, kind):
    n1 = len(s1) // SECTOR
    n2 = len(s2) // SECTOR
    rows = []
    img = raw_mode1(s1, 0) + raw_mode1(s2, lba2)
    sess = [(1, [(1, 0)], n1), (2, [(2, lba2)], lba2 + n2)]
    i = 0
    entries = []
    for (s, tracks, leadout) in sess:
        first, last = tracks[0][0], tracks[-1][0]
        entries += entry(i, s, 0xA0, (first * 60 + 0) * 75 - 150, pmsf=(first, 0, 0)); i += 1
        entries += entry(i, s, 0xA1, (last * 60) * 75 - 150, pmsf=(last, 0, 0)); i += 1
        entries += entry(i, s, 0xA2, leadout); i += 1
        for (t, plba) in tracks:
            entries += entry(i, s, t, plba); i += 1
        if s < len(sess):
            entries += entry(i, s, 0xB0, leadout + GAP, adr=5); i += 1
            entries += entry(i, s, 0xC0, 97 * 4500 - 150, adr=5, pmsf=(97, 0, 0)); i += 1
    rows += ["[CloneCD]", "Version=3", "[Disc]", "TocEntries=%d" % i, "Sessions=%d" % len(sess),
             "DataTracksScrambled=0", "CDTextLength=0"]
    for (s, _, _) in sess:
        rows += ["[Session %d]" % s, "PreGapMode=1", "PreGapSubC=0"]
    rows += entries
    for (s, tracks, _) in sess:
        for (t, plba) in tracks:
            index = plba if (kind != "ccd_rel" and s > 1) else 0
            rows += ["[TRACK %d]" % t, "MODE=1", "INDEX 1=%d" % index]
    open(dst, "wb").write(img)
    open(dst[:-4] + ".ccd", "w", newline="\r\n").write("\n".join(rows) + "\n")
    return "%d sessions, %d + %d sectors, session 2 from sector %d" % (len(sess), n1, n2, lba2)


def main(argv):
    if len(argv) != 5:
        print(__doc__)
        return 2
    kind, p1, p2, plba, dst = argv
    s1 = open(p1, "rb").read()
    s2 = open(p2, "rb").read()
    lba2 = int(open(plba, "r").read().strip())
    if lba2 != len(s1) // SECTOR + GAP:
        raise SystemExit("s2.lba says %d, s1.iso has %d sectors" % (lba2, len(s1) // SECTOR))
    if kind.startswith("etn"):
        note = nrg(dst, s1, s2, lba2, kind)
    elif kind.startswith("ccd"):
        note = ccd(dst, s1, s2, lba2, kind)
    else:
        raise SystemExit("unknown kind " + kind)
    print("%s: %s" % (kind, note))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
