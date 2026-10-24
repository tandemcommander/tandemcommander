"""Feature 337: disc images whose Form 2 stream track a listed file covers wholly, partly, or up to empty
gap sectors, for iso337_probe.ps1. Built on feature 336's img336.py.

  python -I img337.py <kind> <s1c.iso> <out.nrg | out.img>

The seed s1c.iso comes from 336's mkimg336.sh (a.txt "A1", avseq01.dat). Its avseq01.dat directory
records (ISO 9660 name "AVSEQ01.DAT;1"; both byte orders of extent and size) are patched to start at the
first sector of the stream track with the size of the kind. The stream tracks are 64 sectors of Mode 2
Form 2: data sectors with submode 0x62 (Form 2, video, real time) and user data ((s + i) * fill) & 0xFF;
empty sectors as vcdimager writes its gaps (subheader 00 00 20 00 twice, 2324 zero bytes). NRG layout and
ETNF mode bytes as img336.py (0x00 = Mode 1 / 2048, 0x03 = Mode 2 / 2336); CloneCD raw 2352-byte sectors
with a .ccd beside the .img.

  336's kinds (avseq01.dat covers 8 of 64 data sectors unless named):
  single_vcdcov    NRG, one session: track 1 s1c, track 2 a stream
  single_vcdcov2   as single_vcdcov, then track 3 a second stream no file refers to
  single_vcdzero   as single_vcdcov, avseq01.dat of zero bytes
  single_vcdpart   as single_vcdcov, avseq01.dat of 2048 bytes (1 of 64 sectors)
  multi_form2cov   NRG, two sessions: session 1 s1c, session 2 the stream
  ccd_vcdcov       CloneCD, one session, as single_vcdcov
  337's kinds:
  single_vcdfull   as single_vcdcov, avseq01.dat over all 64 sectors
  ccd_vcdfull      as ccd_vcdcov, over all 64 sectors
  multi_form2full  as multi_form2cov, over all 64 sectors
  single_vcdgap    the stream's last 16 sectors empty, avseq01.dat over the first 48
  ccd_vcdgap       CloneCD, as single_vcdgap
  single_vcdtail   as single_vcdgap, but the last 16 sectors hold data
  (review 1)
  single_vcdbyte   as single_vcdcov, avseq01.dat of 63 * 2048 + 1 bytes (the last sector extracted in part)
  ccd_vcdtrunc     as ccd_vcdgap, then the first 1200 bytes of a 65th stream sector (data); the lead-out
                   after it - the image ends inside that sector
"""
import struct
import sys

SECTOR = 2048
STREAM = 64
SYNC = b"\x00" + b"\xff" * 10 + b"\x00"
DATA_SUB = bytes([0, 0, 0x62, 0, 0, 0, 0x62, 0])
EMPTY_SUB = bytes([0, 0, 0x20, 0, 0, 0, 0x20, 0])

# kind -> (container, sessions, avseq01.dat sectors (bytes for 'zero' / 'part'), first empty sector)
KINDS = {
    "single_vcdcov": ("nrg", 1, 8 * SECTOR, STREAM),
    "single_vcdcov2": ("nrg2", 1, 8 * SECTOR, STREAM),
    "single_vcdzero": ("nrg", 1, 0, STREAM),
    "single_vcdpart": ("nrg", 1, SECTOR, STREAM),
    "multi_form2cov": ("nrg", 2, 8 * SECTOR, STREAM),
    "ccd_vcdcov": ("ccd", 1, 8 * SECTOR, STREAM),
    "single_vcdfull": ("nrg", 1, STREAM * SECTOR, STREAM),
    "ccd_vcdfull": ("ccd", 1, STREAM * SECTOR, STREAM),
    "multi_form2full": ("nrg", 2, STREAM * SECTOR, STREAM),
    "single_vcdgap": ("nrg", 1, 48 * SECTOR, 48),
    "ccd_vcdgap": ("ccd", 1, 48 * SECTOR, 48),
    "single_vcdtail": ("nrg", 1, 48 * SECTOR, STREAM),
    "single_vcdbyte": ("nrg", 1, 63 * SECTOR + 1, STREAM),
    "ccd_vcdtrunc": ("ccd+", 1, 48 * SECTOR, 48),
}


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


def payload(s, fill, empty_from):
    """The subheader and 2324 user bytes of stream sector s."""
    if s >= empty_from:
        return EMPTY_SUB + bytes(2324)
    return DATA_SUB + bytes(((s + i) * fill) & 0xFF for i in range(2324))


def stream_2336(fill, empty_from):
    return b"".join(payload(s, fill, empty_from) + bytes(4) for s in range(STREAM))


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


def write_ccd(dst, s1, n1, empty_from, part=0):
    """part: the first 'part' bytes of one more stream sector (data) end the image (review 1)."""
    t1 = b"".join(hdr(i, 1) + s1[i * SECTOR : (i + 1) * SECTOR] + bytes(288) for i in range(n1))
    t2 = b"".join(hdr(n1 + i, 2) + payload(i, 13, empty_from) + bytes(4) for i in range(STREAM))
    if part:
        t2 += (hdr(n1 + STREAM, 2) + payload(STREAM, 13, STREAM + 1) + bytes(4))[:part]
    open(dst, "wb").write(t1 + t2)
    ccd = [
        "[CloneCD]", "Version=3", "[Disc]", "TocEntries=4", "Sessions=1", "DataTracksScrambled=0",
        "CDTextLength=0", "[Session 1]", "PreGapMode=1", "PreGapSubC=0",
    ]
    entries = [(0xA0, 1), (0xA1, 2), (0xA2, n1 + STREAM + (1 if part else 0)), (0x01, 0), (0x02, n1)]
    for i, (pt, plba) in enumerate(entries):
        ccd += ["[Entry %d]" % i, "Session=1", "Point=0x%02x" % pt, "ADR=0x01", "Control=0x04", "TrackNo=0",
                "AMin=0", "ASec=0", "AFrame=0", "ALBA=-150", "Zero=0", "PMin=0", "PSec=0", "PFrame=0",
                "PLBA=%d" % plba]
    ccd += ["[TRACK 1]", "MODE=1", "INDEX 1=0", "[TRACK 2]", "MODE=2", "INDEX 1=%d" % n1]
    open(dst[:-4] + ".ccd", "w", newline="\r\n").write("\n".join(ccd) + "\n")
    return len(t1) + len(t2)


def main(argv):
    if len(argv) != 3 or argv[0] not in KINDS:
        print(__doc__)
        return 2
    kind, p1, dst = argv
    box, sessions, size, empty_from = KINDS[kind]
    s1 = open(p1, "rb").read()
    if len(s1) % SECTOR:
        raise SystemExit("s1c.iso is not whole sectors")
    n1 = len(s1) // SECTOR
    s1p, nrec = patch_avseq(s1, n1, size)
    if box == "ccd":
        total = write_ccd(dst, s1p, n1, empty_from)
    elif box == "ccd+":
        total = write_ccd(dst, s1p, n1, empty_from, 1200)
    elif box == "nrg2":
        total = write_nrg(dst, [(s1p, 0, 0x00), (stream_2336(13, empty_from), n1, 0x03),
                                (stream_2336(7, STREAM), n1 + STREAM, 0x03)], [3])
    else:
        counts = [2] if sessions == 1 else [1, 1]
        total = write_nrg(dst, [(s1p, 0, 0x00), (stream_2336(13, empty_from), n1, 0x03)], counts)
    print("%s: %d bytes; track 1 %d sectors, avseq01.dat (%d records) -> sector %d, %d bytes; stream sectors %d.. empty"
          % (kind, total, n1, nrec, n1, size, empty_from))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
