"""Feature 335 (written by review 1): CloneCD (.img + .ccd) images of raw 2352-byte sectors, one session, two tracks.

  python -I ccd335.py <kind> <s1.iso> <s2.iso> <out.img>

Track 1: s1.iso as Mode 1 raw sectors (CCD MODE=1). Track 2 by kind:
  ccd_vcd       MODE=2, every sector Mode 2 Form 2 (submode 0x62) - a Video CD's MPEG track
  ccd_nofs_m1   MODE=1, s2.iso with every CD001 destroyed
  ccd_nofs_f1   MODE=2, Form 1 sectors (submode 0x08) of s2.iso with every CD001 destroyed
  ccd_f2hdr_m1  MODE=1 in the CCD, but the sectors carry a Mode 2 Form 2 header (sanity of the header read)
"""
import struct
import sys

SECTOR = 2048
SYNC = b"\x00" + b"\xff" * 10 + b"\x00"


def kill(data):
    data = bytearray(data)
    n = 0
    for s in range(16, min(len(data) // SECTOR, 128)):
        o = s * SECTOR
        if data[o + 1 : o + 6] == b"CD001":
            data[o + 1 : o + 6] = b"XXXXX"
            n += 1
    if n == 0:
        raise SystemExit("no descriptor")
    return bytes(data)


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


def mode2(data, lba0, submode, form2fill=None):
    out = bytearray()
    sub = bytes([0, 0, submode, 0, 0, 0, submode, 0])
    for i in range(len(data) // SECTOR):
        if form2fill is not None:
            body = bytes(((i + k) * form2fill) & 0xFF for k in range(2324)) + bytes(4)
        else:
            body = data[i * SECTOR : (i + 1) * SECTOR] + bytes(280)
        out += hdr(lba0 + i, 2) + sub + body
    return bytes(out)


def main(argv):
    kind, p1, p2, dst = argv
    s1 = open(p1, "rb").read()
    s2 = open(p2, "rb").read()
    n1 = len(s1) // SECTOR
    n2 = len(s2) // SECTOR
    t1 = mode1(s1, 0)
    if kind == "ccd_vcd":
        t2, m2 = mode2(s2, n1, 0x62, 13), 2
    elif kind == "ccd_nofs_m1":
        t2, m2 = mode1(kill(s2), n1), 1
    elif kind == "ccd_nofs_f1":
        t2, m2 = mode2(kill(s2), n1, 0x08), 2
    elif kind == "ccd_f2hdr_m1":
        t2, m2 = mode2(s2, n1, 0x62, 7), 1
    else:
        raise SystemExit("kind?")
    open(dst, "wb").write(t1 + t2)
    ccd = [
        "[CloneCD]", "Version=3", "[Disc]", "TocEntries=4", "Sessions=1", "DataTracksScrambled=0",
        "CDTextLength=0", "[Session 1]", "PreGapMode=1", "PreGapSubC=0",
    ]
    entries = [(0xA0, 1), (0xA1, 2), (0xA2, n1 + n2), (0x01, 0), (0x02, n1)]
    for i, (pt, plba) in enumerate(entries):
        ccd += ["[Entry %d]" % i, "Session=1", "Point=0x%02x" % pt, "ADR=0x01", "Control=0x04", "TrackNo=0",
                "AMin=0", "ASec=0", "AFrame=0", "ALBA=-150", "Zero=0", "PMin=0", "PSec=0", "PFrame=0",
                "PLBA=%d" % plba]
    ccd += ["[TRACK 1]", "MODE=1", "INDEX 1=0", "[TRACK 2]", "MODE=%d" % m2, "INDEX 1=%d" % n1]
    open(dst[:-4] + ".ccd", "w", newline="\r\n").write("\n".join(ccd) + "\n")
    print("%s: %d + %d sectors, track 2 mode %d" % (kind, n1, n2, m2))


if __name__ == "__main__":
    main(sys.argv[1:])
