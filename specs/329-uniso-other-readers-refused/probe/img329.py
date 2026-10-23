"""Feature 329: the crafted images of iso329_probe.ps1 (no image tool writes them in WSL).

  python -I img329.py xbox <out>   an XDVDFS (Xbox) image of 328's deep tree:
                                   a<59 x>/b<59 x>/c<59 x>/d<59 x>/e<59 x>/deep.txt (a folder part of
                                   305 bytes - the panel listing refuses deep.txt), a<59 x>/side.txt,
                                   top.txt, zlast/z.txt (after the deep folder in the directory)
  python -I img329.py nrg <out>    an NRG (Nero) image of two audio tracks: CUEX / DAOX / SINF / CDTX
                                   chunks, CD-Text labels "SHORT" and 253 x "L" - the second track's
                                   name ("02 " + the label, 256 bytes) is refused by the listing

Built on specs/327-uniso-safe-names/probe/img327.py (xbox). Prints what it wrote.
"""

import struct
import sys

SECTOR = 2048
SEG = "x" * 59
XBOX_TREE = [
    ("a" + SEG, None, [
        ("b" + SEG, None, [
            ("c" + SEG, None, [
                ("d" + SEG, None, [
                    ("e" + SEG, None, [("deep.txt", b"DEEP", None)]),
                ]),
            ]),
        ]),
        ("side.txt", b"SIDE", None),
    ]),
    ("top.txt", b"TOP", None),
    ("zlast", None, [("z.txt", b"Z", None)]),
]
LONG_LABEL = "L" * 253


def cmd_xbox(dst):
    # sectors: 0..31 empty, 32 the volume descriptor, then one sector a folder, one a file
    sectors = {}
    nxt = [33]

    def alloc():
        s = nxt[0]
        nxt[0] += 1
        return s

    def build_dir(entries):
        sec = alloc()
        blob = bytearray()
        for name, content, children in entries:
            raw = name.encode("ascii")
            if content is None:
                start = build_dir(children)
                size, attr = SECTOR, 0x10
            else:
                start = alloc()
                sectors[start] = content
                size, attr = len(content), 0x80
            ent = struct.pack("<HHIIBB", 0, 0, start, size, attr, len(raw)) + raw
            ent += b"\xff" * ((4 - len(ent) % 4) % 4)
            blob += ent
        if len(blob) > SECTOR:
            raise SystemExit("a folder does not fit one sector")
        sectors[sec] = bytes(blob) + b"\xff" * (SECTOR - len(blob))
        return sec

    root = build_dir(XBOX_TREE)
    img = bytearray(SECTOR * nxt[0])
    vd = 32 * SECTOR
    img[vd : vd + 20] = b"MICROSOFT*XBOX*MEDIA"
    img[vd + 20 : vd + 28] = struct.pack("<II", root, SECTOR)
    img[vd + 0x7EC : vd + 0x7EC + 20] = b"MICROSOFT*XBOX*MEDIA"
    for s, content in sectors.items():
        img[s * SECTOR : s * SECTOR + len(content)] = content
    open(dst, "wb").write(bytes(img))
    print("xbox: %d sectors, root at %d" % (nxt[0], root))
    return 0


def chunk(cid, body):
    return cid + struct.pack(">I", len(body)) + body


def cmd_nrg(dst):
    # (nrg.cpp) the track data: two audio tracks of 10 raw sectors each, silence
    raw = 2352
    tracks = [(0, 10 * raw), (10 * raw, 20 * raw)]
    data = bytes(20 * raw)
    # CUEX: 16 bytes header, then 16 bytes a track (the reader makes one audio track per entry)
    cuex = bytes(16) + b"".join(bytes(4) + struct.pack(">I", 0) + bytes(8) for _ in tracks)
    # DAOX: 0x16 bytes header (first / last track at 0x14 / 0x15), then 0x2A bytes a track:
    # sector size (BE word) at 0x0C, mode 0x07 (audio) at 0x0E, start / end (BE 64) at 0x1A / 0x22
    daox = bytearray(0x16)
    daox[0x14] = 1
    daox[0x15] = len(tracks)
    for start, end in tracks:
        t = bytearray(0x2A)
        t[0x0C:0x0E] = struct.pack(">H", raw)
        t[0x0E] = 0x07
        t[0x1A:0x22] = struct.pack(">Q", start)
        t[0x22:0x2A] = struct.pack(">Q", end)
        daox += t
    # SINF: one session of two tracks
    sinf = struct.pack(">I", len(tracks))
    # CDTX: 4 bytes of flags, then blocks of 12 bytes of text and 6 other bytes; the text is the
    # volume label and one label a track, each 0-terminated
    text = b"TC329\0" + b"SHORT\0" + LONG_LABEL.encode("ascii") + b"\0"
    blocks = (len(text) + 11) // 12
    text = text.ljust(blocks * 12, b"\0")
    cdtx = bytearray(18 * blocks)
    for k in range(blocks):
        cdtx[4 + 18 * k : 4 + 18 * k + 12] = text[12 * k : 12 * k + 12]
    chunks = chunk(b"CUEX", cuex) + chunk(b"DAOX", bytes(daox)) + chunk(b"SINF", sinf) + chunk(b"CDTX", bytes(cdtx)) + chunk(b"END!", b"")
    img = data + chunks + b"NER5" + struct.pack(">Q", len(data))
    open(dst, "wb").write(img)
    print("nrg: %d bytes, chunks at %d, labels SHORT and %d x L" % (len(img), len(data), len(LONG_LABEL)))
    return 0


def main(argv):
    if len(argv) == 2 and argv[0] == "xbox":
        return cmd_xbox(argv[1])
    if len(argv) == 2 and argv[0] == "nrg":
        return cmd_nrg(argv[1])
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
