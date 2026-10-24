"""Feature 336: disc images with Form 2 stream tracks that a listed file covers or not, for iso336_probe.ps1.

  python -I img336.py <kind> <s1c.iso> <out.nrg | out.img>

The seed s1c.iso comes from mkimg336.sh (a.txt "A1", avseq01.dat of 16384 bytes). Its avseq01.dat
directory records (ISO 9660 name "AVSEQ01.DAT;1"; both byte orders of extent and size) are patched to
start at the first sector of the stream track - as a Video CD's MPEGAV/AVSEQ01.DAT starts in its MPEG
track - with a size of COVER_SECTORS * 2048 bytes (0 for single_vcdzero). The stream tracks are 64
sectors of Mode 2 Form 2 (submode 0x62 - Form 2, video, real time), as feature 335's img335.py /
ccd335.py write them. NRG layout and ETNF mode bytes as img335.py (0x00 = Mode 1 / 2048, 0x03 = Mode 2 /
2336); CloneCD as ccd335.py (raw 2352-byte sectors, .ccd beside the .img).

  single_vcdcov   NRG, one session: track 1 s1c (avseq01.dat -> track 2), track 2 a stream - covered
  single_vcdcov2  NRG, one session: as single_vcdcov, then track 3 a second stream no file refers to
  single_vcdzero  NRG, one session: as single_vcdcov, avseq01.dat of zero bytes (covers nothing)
  single_vcdpart  NRG, one session: as single_vcdcov, avseq01.dat of 2048 bytes (1 of 64 sectors; review 2)
  multi_form2cov  NRG, two sessions: session 1 s1c (avseq01.dat -> session 2), session 2 a stream
  ccd_vcdcov      CloneCD, one session: track 1 s1c (raw Mode 1), track 2 a raw Form 2 stream - covered
"""
import struct
import sys

SECTOR = 2048
STREAM = 64
COVER_SECTORS = 8
SYNC = b"\x00" + b"\xff" * 10 + b"\x00"


def patch_avseq(iso, lba, size):
    """Points every directory record named AVSEQ01.DAT;1 at 'lba' with 'size' bytes."""
    data = bytearray(iso)
    name = b"AVSEQ01.DAT;1"
    n = 0
    at = data.find(name)
    while at >= 0:
        rec = at - 33
        if rec >= 0 and data[rec + 32] == len(name) and data[rec] >= 33 + len(name):
            data[rec + 2 : rec + 10] = struct.pack("<I", lba) + struct.pack(">I", lba)
            data[rec + 10 : rec + 18] = struct.pack("<I", size) + struct.pack(">I", size)
            n += 1
        at = data.find(name, at + 1)
    if n == 0:
        raise SystemExit("no AVSEQ01.DAT;1 record in the seed")
    return bytes(data), n


def stream_2336(fill):
    sub = bytes([0, 0, 0x62, 0, 0, 0, 0x62, 0])
    return b"".join(sub + bytes(((s + i) * fill) & 0xFF for i in range(2324)) + bytes(4) for s in range(STREAM))


def chunk(cid, body):
    return cid + struct.pack(">I", len(body)) + body


def write_nrg(dst, tracks, counts):
    """tracks: (data, first sector, ETNF mode) in order; counts: tracks per session."""
    data = b""
    etnf = b""
    for t, lba, mode in tracks:
        etnf += struct.pack(">II", len(data), len(t)) + bytes([0, 0, 0, mode]) + struct.pack(">I", lba) + bytes(4)
        data += t
    sinf = b"".join(chunk(b"SINF", struct.pack(">I", c)) for c in counts)
    chunks = chunk(b"ETNF", etnf) + sinf + chunk(b"END!", b"")
    img = data + chunks + b"NER5" + struct.pack(">Q", len(data))
    open(dst, "wb").write(img)
    return len(img)


def hdr(lba, mode):
    a = lba + 150
    m, s, f = a // 4500, (a // 75) % 60, a % 75
    bcd = lambda v: ((v // 10) << 4) | (v % 10)
    return SYNC + bytes([bcd(m), bcd(s), bcd(f), mode])


def write_ccd(dst, s1, n1):
    t1 = b"".join(hdr(i, 1) + s1[i * SECTOR : (i + 1) * SECTOR] + bytes(288) for i in range(n1))
    sub = bytes([0, 0, 0x62, 0, 0, 0, 0x62, 0])
    t2 = b"".join(hdr(n1 + i, 2) + sub + bytes(((i + k) * 13) & 0xFF for k in range(2324)) + bytes(4) for i in range(STREAM))
    open(dst, "wb").write(t1 + t2)
    ccd = [
        "[CloneCD]", "Version=3", "[Disc]", "TocEntries=4", "Sessions=1", "DataTracksScrambled=0",
        "CDTextLength=0", "[Session 1]", "PreGapMode=1", "PreGapSubC=0",
    ]
    entries = [(0xA0, 1), (0xA1, 2), (0xA2, n1 + STREAM), (0x01, 0), (0x02, n1)]
    for i, (pt, plba) in enumerate(entries):
        ccd += ["[Entry %d]" % i, "Session=1", "Point=0x%02x" % pt, "ADR=0x01", "Control=0x04", "TrackNo=0",
                "AMin=0", "ASec=0", "AFrame=0", "ALBA=-150", "Zero=0", "PMin=0", "PSec=0", "PFrame=0",
                "PLBA=%d" % plba]
    ccd += ["[TRACK 1]", "MODE=1", "INDEX 1=0", "[TRACK 2]", "MODE=2", "INDEX 1=%d" % n1]
    open(dst[:-4] + ".ccd", "w", newline="\r\n").write("\n".join(ccd) + "\n")
    return len(t1) + len(t2)


def main(argv):
    if len(argv) != 3:
        print(__doc__)
        return 2
    kind, p1, dst = argv
    s1 = open(p1, "rb").read()
    if len(s1) % SECTOR:
        raise SystemExit("s1c.iso is not whole sectors")
    n1 = len(s1) // SECTOR
    size = 0 if kind == "single_vcdzero" else (SECTOR if kind == "single_vcdpart" else COVER_SECTORS * SECTOR)
    s1p, nrec = patch_avseq(s1, n1, size)
    if kind == "ccd_vcdcov":
        total = write_ccd(dst, s1p, n1)
    elif kind in ("single_vcdcov", "single_vcdzero", "single_vcdpart"):
        total = write_nrg(dst, [(s1p, 0, 0x00), (stream_2336(13), n1, 0x03)], [2])
    elif kind == "single_vcdcov2":
        total = write_nrg(dst, [(s1p, 0, 0x00), (stream_2336(13), n1, 0x03), (stream_2336(7), n1 + STREAM, 0x03)], [3])
    elif kind == "multi_form2cov":
        total = write_nrg(dst, [(s1p, 0, 0x00), (stream_2336(13), n1, 0x03)], [1, 1])
    else:
        raise SystemExit("unknown kind " + kind)
    print("%s: %d bytes; track 1 %d sectors, avseq01.dat (%d records) -> sector %d, %d bytes" % (kind, total, n1, nrec, n1, size))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
