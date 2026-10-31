"""Feature 351: CloneCD (.img + .ccd) and NRG (Nero) images whose tracks the readers leave partly undescribed.

  python -I img351.py <kind> <s1.iso> <s2.iso> <out>

s1.iso (a.txt "A1") and s2.iso (b.txt "B2") come from feature 334's mkimg334.sh.

Kinds:
  ccd_m1      CloneCD, one session, one track: s1.iso as Mode 1 raw sectors (CCD MODE=1). The CCD reader
              sets no file-system type for a Mode 1 track - before 351 it kept what the heap held (Debug:
              0xCDCDCDCD, taken as "detect"; Release: often 0 = fsUnknown, the track never detected)
  ccd_m2      as ccd_m1, the track Mode 2 Form 1 (CCD MODE=2, submode 0x08)
  ccd_m1m1    CloneCD, two sessions of one Mode 1 track each: s1.iso, then s2.iso (addressed after s1;
              the plug-in lists "Session 01" / "Session 02")
  nrg_one     NRG, CUEX of one track + DAOX describing it: s1.iso as a Mode 1 track of 2048-byte sectors
              (the control - a.txt listed, the image complete)
  nrg_undesc  NRG, CUEX of two tracks, DAOX describing only track 1 (s1.iso as nrg_one); track 2's data
              (s2.iso) follows, but no DAOX entry gives its mode, sector size, start or end - before 351
              they kept what the heap held (Debug: detected as data with start / end 0xCDCD...)
"""
import struct
import sys

SECTOR = 2048
SYNC = b"\x00" + b"\xff" * 10 + b"\x00"


def hdr(lba, mode):
    a = lba + 150
    m, s, f = a // 4500, (a // 75) % 60, a % 75
    bcd = lambda v: ((v // 10) << 4) | (v % 10)
    return SYNC + bytes([bcd(m), bcd(s), bcd(f), mode])


def mode1(data, lba0):
    out = bytearray()
    for i in range(len(data) // SECTOR):
        out += hdr(lba0 + i, 1) + data[i * SECTOR : (i + 1) * SECTOR] + bytes(288)
    return bytes(out)


def mode2f1(data, lba0):
    out = bytearray()
    sub = bytes([0, 0, 0x08, 0, 0, 0, 0x08, 0])
    for i in range(len(data) // SECTOR):
        out += hdr(lba0 + i, 2) + sub + data[i * SECTOR : (i + 1) * SECTOR] + bytes(280)
    return bytes(out)


def entry(i, session, point, plba):
    return ["[Entry %d]" % i, "Session=%d" % session, "Point=0x%02x" % point, "ADR=0x01", "Control=0x04",
            "TrackNo=0", "AMin=0", "ASec=0", "AFrame=0", "ALBA=-150", "Zero=0", "PMin=0", "PSec=0", "PFrame=0",
            "PLBA=%d" % plba]


def write_ccd(dst, sessions, tracks, entries):
    ccd = ["[CloneCD]", "Version=3", "[Disc]", "TocEntries=%d" % len(entries), "Sessions=%d" % sessions,
           "DataTracksScrambled=0", "CDTextLength=0"]
    for s in range(1, sessions + 1):
        ccd += ["[Session %d]" % s, "PreGapMode=1", "PreGapSubC=0"]
    for i, (session, pt, plba) in enumerate(entries):
        ccd += entry(i, session, pt, plba)
    for n, (mode, index) in enumerate(tracks, 1):
        ccd += ["[TRACK %d]" % n, "MODE=%d" % mode, "INDEX 1=%d" % index]
    open(dst[:-4] + ".ccd", "w", newline="\r\n").write("\n".join(ccd) + "\n")


def chunk(cid, body):
    return cid + struct.pack(">I", len(body)) + body


def daox_entry(sector_size, mode, start, end):
    e = bytearray(0x2A)
    e[0x0C:0x0E] = struct.pack(">H", sector_size)
    e[0x0E] = mode
    e[0x1A:0x22] = struct.pack(">Q", start)
    e[0x22:0x2A] = struct.pack(">Q", end)
    return bytes(e)


def write_nrg(dst, data, cuex_lbas, daox_entries, first, last, count):
    # CUEX: 16 bytes of header, then 16 bytes a track (the reader takes the DWORD at +4 as its extent)
    cuex = bytes(16) + b"".join(bytes(4) + struct.pack(">I", lba) + bytes(8) for lba in cuex_lbas)
    daox = bytearray(0x16)
    daox[0x14] = first
    daox[0x15] = last
    daox = bytes(daox) + b"".join(daox_entries)
    chunks = chunk(b"CUEX", cuex) + chunk(b"DAOX", daox) + chunk(b"SINF", struct.pack(">I", count)) + chunk(b"END!", b"")
    open(dst, "wb").write(data + chunks + b"NER5" + struct.pack(">Q", len(data)))


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    kind, p1, p2, dst = argv
    s1 = open(p1, "rb").read()
    s2 = open(p2, "rb").read()
    n1 = len(s1) // SECTOR
    n2 = len(s2) // SECTOR
    if kind == "ccd_m1" or kind == "ccd_m2":
        img = mode1(s1, 0) if kind == "ccd_m1" else mode2f1(s1, 0)
        open(dst, "wb").write(img)
        write_ccd(dst, 1, [(1 if kind == "ccd_m1" else 2, 0)], [(1, 0xA0, 1), (1, 0xA1, 1), (1, 0xA2, n1), (1, 0x01, 0)])
        note = "one track, mode %d, %d sectors" % (1 if kind == "ccd_m1" else 2, n1)
    elif kind == "ccd_m1m1":
        open(dst, "wb").write(mode1(s1, 0) + mode1(s2, n1))
        # (the reader starts a session at a track whose INDEX 1 is 0 - session-relative)
        write_ccd(dst, 2, [(1, 0), (1, 0)],
                  [(1, 0xA0, 1), (1, 0xA1, 1), (1, 0xA2, n1), (1, 0x01, 0),
                   (2, 0xA0, 2), (2, 0xA1, 2), (2, 0xA2, n1 + n2), (2, 0x02, n1)])
        note = "two sessions, mode 1 tracks of %d and %d sectors" % (n1, n2)
    elif kind == "nrg_one":
        write_nrg(dst, s1, [0], [daox_entry(SECTOR, 0x00, 0, len(s1))], 1, 1, 1)
        note = "one described Mode 1 track"
    elif kind == "nrg_undesc":
        write_nrg(dst, s1 + s2, [0, n1], [daox_entry(SECTOR, 0x00, 0, len(s1))], 1, 1, 2)
        note = "CUEX two tracks, DAOX describes track 1 only"
    else:
        raise SystemExit("unknown kind " + kind)
    print("%s: %s" % (kind, note))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
