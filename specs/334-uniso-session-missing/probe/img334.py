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
  single_past as single, track 2's start past the end of the image
  single_raw  as single, track 2 zeros - readable raw data without a file system (Video CD-like)
  single_mixed one session: track 1 data (s1), track 2 audio
  multi_mixed as single_mixed, one track a session
  multi_unknown as multi, track 2's mode byte 0x10 (a mode the plug-in calls unknown)
  multi_extra as multi, plus a third (audio) track no session count covers
  audio_cd    one session of two audio tracks
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
    if kind == "single_raw":
        s2 = bytes(len(s2))  # readable raw data, no file system (as a Video CD's MPEG track)
        note = "track 2 is zeros (no file system)"
    data = s1 + s2
    audio = bytes((i * 7) & 0xFF for i in range(2352 * 300))  # 300 raw audio sectors
    # (start, length, first sector, mode byte at 0x0B: 0x00 = Mode 1, 0x07 = audio, 0x10 = a mode
    # the plug-in does not name - "unknown")
    entries = [(0, len(s1), 0, 0x00), (len(s1), len(s2), lba2, 0x00)]
    counts = [1, 1] if kind.startswith("multi") else [2]
    if kind in ("multi_past", "single_past"):
        entries[1] = (len(data) + 0x10000000, len(s2), lba2, 0x00)
        note = "track 2 starts at %d, the image has %d bytes of track data" % (entries[1][0], len(data))
    elif kind == "multi_unknown":
        entries[1] = (len(s1), len(s2), lba2, 0x10)
        note = "track 2's mode byte 0x10"
    elif kind == "multi_extra":
        entries.append((len(data), len(audio), lba2 + len(s2) // SECTOR, 0x07))
        data = data + audio
        note = "a third (audio) track that no session count covers"
    elif kind == "single_mixed":
        entries = [(0, len(s1), 0, 0x00), (len(s1), len(audio), lba2, 0x07)]
        data = s1 + audio
        note = "one session: a data track and an audio track"
    elif kind == "multi_mixed":
        entries = [(0, len(s1), 0, 0x00), (len(s1), len(audio), lba2, 0x07)]
        data = s1 + audio
        note = "session 1 a data track, session 2 an audio track"
    elif kind == "audio_cd":
        entries = [(0, len(audio), 0, 0x07), (len(audio), len(audio), len(audio) // 2352, 0x07)]
        data = audio + audio
        counts = [2]
        note = "one session of two audio tracks"
    elif kind not in ("multi", "multi_term", "single", "single_term", "single_raw"):
        raise SystemExit("unknown kind " + kind)
    etnf = b""
    for start, length, lba, mode in entries:
        etnf += struct.pack(">II", start, length) + bytes([0, 0, 0, mode]) + struct.pack(">I", lba) + bytes(4)
    sinf = b"".join(chunk(b"SINF", struct.pack(">I", c)) for c in counts)
    chunks = chunk(b"ETNF", etnf) + sinf + chunk(b"END!", b"")
    img = data + chunks + b"NER5" + struct.pack(">Q", len(data))
    open(dst, "wb").write(img)
    print("%s: %d bytes, track 2 from sector %d%s" % (kind, len(img), lba2, ("; " + note) if note else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
