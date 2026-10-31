"""Feature 350: NRG (Nero) images with damaged CUEX chunks for nrg350_probe.ps1.

  python -I img350.py <kind> <out.nrg>

The NRG layout read by src/plugins/uniso/nrg.cpp ("NER5"): the track data (two audio tracks of 10
raw sectors each, silence), then the chunks - CUEX (16 bytes of header, then 16 bytes a track: the
reader makes one audio track per entry), DAOX (0x16 bytes of header, first / last track at 0x14 /
0x15, then 0x2A bytes a track), SINF (one session of two tracks), END! - and the footer "NER5" + the
chunks' offset (as feature 329's img329.py).

Kinds:
  ok     the two audio tracks (a control: the plug-in lists "Audio Track 01" and "Audio Track 02")
  short  a CUEX chunk of 8 bytes and a padding chunk "PADD" of 96 MiB before ok's chunks: the first
         CUEX holds no entry (before 350: (8 - 16) / 16 underflowed to 268,435,455 entries and the
         reader made one track from every 16 bytes of the padding until the end of the file)
  past   a CUEX chunk claiming 0xFFFFFFF0 bytes (past the end of the image) and the 96 MiB padding
         before ok's chunks: the chunk does not fit the image - it is skipped, so the chunk list ends
         at the end of the file and the image does not open as NRG (before 350: the reader made a
         track from every 16 bytes up to the end of the file first)
  odd    ok, the CUEX chunk 4 bytes longer than its two entries (16 + 2 x 16 + 4): the reader takes
         its two entries and continues after the chunk (before 350: the next chunk header was read
         4 bytes early, "DAOX" taken as a size - the image did not open as NRG)
  zero   ok's chunks after a CUEX chunk of 0 bytes (no entry; before 350: its "header" was read from
         the next chunk - the image did not open)
  shortnz ok's chunks after a CUEX chunk of 8 bytes "ABCDEFGH" (no entry; the next header is read
         after them - review 1: unlike short's zeros, these bytes are no empty chunk header)
  inside a CUEX chunk of 16 + 96 MiB bytes lying within the image, then ok's chunks (review 1: it
         fits the image but claims 6.3 million entries - more than a CD's 99 tracks, skipped; before
         the cap the fixed reader built every one of them, 1.5 GB, 3 minutes)
  idx2   review 2: Nero's real CUEX layout (8-byte index records: lead-in, per track index 0 and
         index 1..99, lead-out) for 2 audio tracks of 10 sectors with index points 1..99 - 202
         records, 100 of the reader's entries; a real disc, it opens with its 2 tracks (review 1's
         99-entry cap refused it)
  idx20  as idx2, 20 audio tracks with index points 1..10 - 222 records, 110 entries; opens with its
         20 tracks
"""
import struct
import sys

RAW = 2352
PAD = 96 * 1024 * 1024


def chunk(cid, body, size=None):
    return cid + struct.pack(">I", len(body) if size is None else size) + body


def bcd(n):
    return ((n // 10) << 4) | (n % 10)


def rec(track, index, lba):
    # a Nero CUEX index record: mode, track (BCD, 0xAA = lead-out), index (BCD), 0, LBA (BE, signed)
    return struct.pack(">BBBBi", 0x01, track, index, 0, lba)


def real_layout(dst, ntracks, nidx):
    # (review 2, after its imgrev.py) audio tracks of 10 raw sectors, the CUEX in Nero's real layout
    sect = 10
    data = bytes(ntracks * sect * RAW)
    cuex = rec(0, 0, -150)
    for t in range(1, ntracks + 1):
        base = (t - 1) * sect
        cuex += rec(bcd(t), 0, base - (150 if t == 1 else 0))
        for i in range(1, nidx + 1):
            cuex += rec(bcd(t), bcd(i), base + (i - 1) * sect // nidx)
    cuex += rec(0xAA, 1, ntracks * sect)
    daox = bytearray(0x16)
    daox[0x14] = 1
    daox[0x15] = ntracks
    for t in range(ntracks):
        e = bytearray(0x2A)
        e[0x0C:0x0E] = struct.pack(">H", RAW)
        e[0x0E] = 0x07
        e[0x1A:0x22] = struct.pack(">Q", t * sect * RAW)
        e[0x22:0x2A] = struct.pack(">Q", (t + 1) * sect * RAW)
        daox += e
    sinf = struct.pack(">I", ntracks)
    chunks = chunk(b"CUEX", cuex) + chunk(b"DAOX", bytes(daox)) + chunk(b"SINF", sinf) + chunk(b"END!", b"")
    img = data + chunks + b"NER5" + struct.pack(">Q", len(data))
    with open(dst, "wb") as f:
        f.write(img)
    print("%d tracks: %d bytes, CUEX %d bytes = %d records = %d entries" % (ntracks, len(img), len(cuex), len(cuex) // 8, (len(cuex) - 16) // 16))
    return 0


def main(argv):
    if len(argv) != 2 or argv[0] not in ("ok", "short", "past", "odd", "zero", "shortnz", "inside", "idx2", "idx20"):
        print(__doc__)
        return 2
    kind, dst = argv
    if kind == "idx2":
        return real_layout(dst, 2, 99)
    if kind == "idx20":
        return real_layout(dst, 20, 10)
    tracks = [(0, 10 * RAW), (10 * RAW, 20 * RAW)]
    data = bytes(20 * RAW)
    cuex = bytes(16) + b"".join(bytes(4) + struct.pack(">I", 0) + bytes(8) for _ in tracks)
    if kind == "odd":
        cuex += b"\x01\x02\x03\x04"
    daox = bytearray(0x16)
    daox[0x14] = 1
    daox[0x15] = len(tracks)
    for start, end in tracks:
        t = bytearray(0x2A)
        t[0x0C:0x0E] = struct.pack(">H", RAW)
        t[0x0E] = 0x07
        t[0x1A:0x22] = struct.pack(">Q", start)
        t[0x22:0x2A] = struct.pack(">Q", end)
        daox += t
    sinf = struct.pack(">I", len(tracks))
    good = chunk(b"CUEX", cuex) + chunk(b"DAOX", bytes(daox)) + chunk(b"SINF", sinf) + chunk(b"END!", b"")
    if kind == "short":
        chunks = chunk(b"CUEX", bytes(8)) + chunk(b"PADD", bytes(PAD)) + good
    elif kind == "past":
        chunks = chunk(b"CUEX", b"", 0xFFFFFFF0) + chunk(b"PADD", bytes(PAD)) + good
    elif kind == "zero":
        chunks = chunk(b"CUEX", b"") + good
    elif kind == "shortnz":
        chunks = chunk(b"CUEX", b"ABCDEFGH") + good
    elif kind == "inside":
        chunks = chunk(b"CUEX", bytes(16 + PAD)) + good
    else:
        chunks = good
    img = data + chunks + b"NER5" + struct.pack(">Q", len(data))
    with open(dst, "wb") as f:
        f.write(img)
    print("%s: %d bytes, chunks at %d" % (kind, len(img), len(data)))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
