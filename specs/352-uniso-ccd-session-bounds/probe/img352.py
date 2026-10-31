"""Feature 352: CloneCD (.img + .ccd) images whose .ccd names sessions the reader has no arrays for,
whose session sections and track splits disagree, or whose rows do not parse.

  python -I img352.py <kind> <s1.iso> <s2.iso> <out.img>

s1.iso (a.txt "A1") and s2.iso (b.txt "B2", addressed from the sector after s1) come from feature 334's
mkimg334.sh. Built on feature 351's img351.py (Mode 1 raw sectors, the same .ccd layout).

Kinds:
  ccd_m1     (control) one session, one Mode 1 track (s1)
  ccd_m1m1   (control) two [Session n] sections, two tracks whose INDEX 1 is 0 (two splits): s1, s2
  ccd_s0     as ccd_m1, [Entry 0] Session=0 - before 352 the reader wrote pointMin[-1] (heap corruption)
  ccd_s200   as ccd_m1, [Entry 0] Session=200 - wrote about 800 bytes past a one-session array
  ccd_s257   as ccd_m1, [Entry 0] Session=257 - stored in a BYTE, taken as session 1
  ccd_abs    two [Session n] sections, the second track's INDEX 1 absolute (one split): the reader read
             a session count past its session list
  ccd_split  one [Session n] section, two tracks whose INDEX 1 is 0 (two splits): the reader read
             extents[1] past a one-element array
  ccd_modex  as ccd_m1, [TRACK 1] MODE=x - the mode stayed an uninitialised stack value
  ccd_dup    as ccd_m1, [Entry 3] (the track's entry) without PLBA but with Session= twice - the row
             count matched, PLBA stayed an uninitialised stack value
  noccd      ccd_m1's image without a .ccd beside it (FR-006: unchanged, never marked)
"""
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


def entry(i, session, point, plba):
    return ["[Entry %d]" % i, "Session=%s" % session, "Point=0x%02x" % point, "ADR=0x01", "Control=0x04",
            "TrackNo=0", "AMin=0", "ASec=0", "AFrame=0", "ALBA=-150", "Zero=0", "PMin=0", "PSec=0", "PFrame=0",
            "PLBA=%d" % plba]


def write_ccd(dst, sessions, tracks, entries, edit=None):
    ccd = ["[CloneCD]", "Version=3", "[Disc]", "TocEntries=%d" % len(entries), "Sessions=%d" % sessions,
           "DataTracksScrambled=0", "CDTextLength=0"]
    for s in range(1, sessions + 1):
        ccd += ["[Session %d]" % s, "PreGapMode=1", "PreGapSubC=0"]
    for i, (session, pt, plba) in enumerate(entries):
        ccd += entry(i, session, pt, plba)
    for n, (mode, index) in enumerate(tracks, 1):
        ccd += ["[TRACK %d]" % n, "MODE=%s" % mode, "INDEX 1=%d" % index]
    if edit is not None:
        ccd = edit(ccd)
    open(dst[:-4] + ".ccd", "w", newline="\r\n").write("\n".join(ccd) + "\n")


def main(argv):
    if len(argv) != 4:
        print(__doc__)
        return 2
    kind, p1, p2, dst = argv
    s1 = open(p1, "rb").read()
    s2 = open(p2, "rb").read()
    n1 = len(s1) // SECTOR
    n2 = len(s2) // SECTOR
    one = [(1, 0xA0, 1), (1, 0xA1, 1), (1, 0xA2, n1), (1, 0x01, 0)]
    two = one + [(2, 0xA0, 2), (2, 0xA1, 2), (2, 0xA2, n1 + n2), (2, 0x02, n1)]
    if kind in ("ccd_m1", "ccd_s0", "ccd_s200", "ccd_s257", "ccd_modex", "ccd_dup"):
        open(dst, "wb").write(mode1(s1, 0))
        entries = list(one)
        tracks = [(1, 0)]
        edit = None
        if kind in ("ccd_s0", "ccd_s200", "ccd_s257"):
            entries[0] = ({"ccd_s0": 0, "ccd_s200": 200, "ccd_s257": 257}[kind],) + entries[0][1:]
        elif kind == "ccd_modex":
            tracks = [("x", 0)]
        elif kind == "ccd_dup":
            def edit(rows):
                at = rows.index("[Entry 3]")
                end = at + 1
                while end < len(rows) and not rows[end].startswith("["):
                    end += 1
                body = [r for r in rows[at + 1 : end] if not r.startswith("PLBA=")]
                body.insert(1, "Session=1")
                return rows[: at + 1] + body + rows[end:]
        write_ccd(dst, 1, tracks, entries, edit)
        note = "one Mode 1 track of %d sectors" % n1
    elif kind == "noccd":
        open(dst, "wb").write(mode1(s1, 0))
        note = "one Mode 1 track of %d sectors, no .ccd" % n1
    elif kind == "ccd_m1m1":
        open(dst, "wb").write(mode1(s1, 0) + mode1(s2, n1))
        write_ccd(dst, 2, [(1, 0), (1, 0)], two)
        note = "two sessions / two splits, %d + %d sectors" % (n1, n2)
    elif kind == "ccd_abs":
        open(dst, "wb").write(mode1(s1, 0) + mode1(s2, n1))
        write_ccd(dst, 2, [(1, 0), (1, n1)], two)
        note = "two sessions / one split (INDEX 1 absolute), %d + %d sectors" % (n1, n2)
    elif kind == "ccd_split":
        open(dst, "wb").write(mode1(s1, 0) + mode1(s2, n1))
        write_ccd(dst, 1, [(1, 0), (1, 0)], [(1, 0xA0, 1), (1, 0xA1, 2), (1, 0xA2, n1 + n2), (1, 0x01, 0), (1, 0x02, n1)])
        note = "one session / two splits, %d + %d sectors" % (n1, n2)
    else:
        raise SystemExit("unknown kind " + kind)
    print("%s: %s" % (kind, note))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
