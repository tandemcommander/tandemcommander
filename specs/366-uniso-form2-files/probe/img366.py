"""Feature 366: images for iso366_probe.ps1 from real vcdimager 2.0.1 output, and what each row must extract.

  python -I img366.py <data dir with vcd.bin, svcd.bin, v.mpg, s.mpg> <out dir>

Writes the images and <out dir>/expect.json: {row: {"image": file name, "files": {path: [size, sha256]},
"absent": [paths], "source": [path, source file] or null}}. The content each file must have is computed
from the image's own sectors: a Form 2 file (CD-XA attribute Form 2) = 2324 user bytes of every sector its
record spans, any other file = its record's size of 2048-byte user data - main's behaviour for the control rows.

Rows
  R-VCD-CCD   real VCD 2.0 as CloneCD (3 tracks, Mode 2 / 2352)       AVSEQ01/02.DAT 690,228 bytes, v.mpg inside
  R-VCD-NRG   the same as NRG ETNF, Mode 2 / 2336 (mode 0x03)        the same content
  R-SVCD-CCD  real SVCD as CloneCD                                    AVSEQ01.MPG == s.mpg
  R-VCD-BIN   vcd.bin alone (.bin, no .cue: the plain detection, one raw track - the ISO 9660 reader's path)
  C-MIXED     R-VCD-CCD, AVSEQ01's attributes 0x3D55 (Form 1 + Form 2): AVSEQ01 as before (2048)
  C-NOXA      R-VCD-CCD, AVSEQ01's XA signature destroyed: as before
  C-F1SUB     R-VCD-CCD, AVSEQ02's first sector's subheader Form 1: AVSEQ02 as before
  C-COOKED    the VCD's 2048-byte user data as a cooked .iso: every file as before (608,256)
  C-CUT       R-VCD-CCD cut 7 sectors before AVSEQ02's end: AVSEQ02 not extracted, the image kept
  C-SHORT240  R-VCD-CCD, AVSEQ01's record 240 sectors (its stream's video runs to sector 251): image kept
  D-DIFF2-CCD / D-DIFF2-NRG  AVSEQ02.s user data altered in every sector (review 1: the two real files are equal)
"""
import hashlib
import json
import struct
import sys

RAW = 2352


def chunk(cid, body):
    return cid + struct.pack(">I", len(body)) + body


def write_nrg(dst, tracks, counts):
    """tracks: list of (bytes, mode byte, lba) - as 335's gen335c.py"""
    data = b""
    etnf = b""
    for t, m, lba in tracks:
        etnf += struct.pack(">II", len(data), len(t)) + bytes([0, 0, 0, m]) + struct.pack(">I", lba) + bytes(4)
        data += t
    sinf = b"".join(chunk(b"SINF", struct.pack(">I", c)) for c in counts)
    img = data + chunk(b"ETNF", etnf) + sinf + chunk(b"END!", b"") + b"NER5" + struct.pack(">Q", len(data))
    open(dst, "wb").write(img)


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


def write_ccd(dst, data, points, modes, leadout=None):
    open(dst, "wb").write(data)
    lo = leadout if leadout is not None else len(data) // RAW
    open(dst[:-4] + ".ccd", "w", newline="\r\n").write(ccd_text(points, modes, lo))


def to2336(raw):
    return b"".join(raw[i * RAW + 16:(i + 1) * RAW] for i in range(len(raw) // RAW))


def user(img, lba, n):
    return img[lba * RAW + 24:lba * RAW + 24 + n]


def records(img, extent, size):
    """(name, record offset in img, extent, length, xa attrs or None, flags) of a directory"""
    out = []
    for s in range((size + 2047) // 2048):
        base = (extent + s) * RAW + 24
        pos = 0
        while pos < 2048:
            n = img[base + pos]
            if n == 0:
                break
            r = img[base + pos:base + pos + n]
            idl = r[32]
            su = 33 + idl + (1 - idl % 2)
            xa = struct.unpack(">H", r[su + 4:su + 6])[0] if len(r) >= su + 14 and r[su + 6:su + 8] == b"XA" else None
            out.append((r[33:33 + idl], base + pos, struct.unpack("<I", r[2:6])[0],
                        struct.unpack("<I", r[10:14])[0], xa, r[25], su))
            pos += n
    return out


def files_of(img):
    """{path: (record offset, extent, length, xa, su)} of every file of the image's ISO 9660 tree"""
    pvd = user(img, 16, 2048)
    out = {}

    def walk(ext, ln, path):
        for name, off, e, l, xa, flags, su in records(img, ext, ln):
            if name in (b"\x00", b"\x01"):
                continue
            nm = name.decode("latin-1").split(";")[0]
            p = path + nm
            if flags & 2:
                walk(e, l, p + "/")
            else:
                out[p] = (off, e, l, xa, su)

    walk(struct.unpack("<I", pvd[158:162])[0], struct.unpack("<I", pvd[166:170])[0], "")
    return out


def content(img, extent, length, form2):
    if form2:
        n = (length + 2047) // 2048
        return b"".join(user(img, extent + i, 2324) for i in range(n))
    n = (length + 2047) // 2048
    return b"".join(user(img, extent + i, 2048) for i in range(n))[:length]


def form2_file(img, extent, xa):
    """the feature's rule on a raw (2352) image: XA Form 2 only and a Form 2 first sector"""
    if xa is None or not (xa & 0x1000) or (xa & 0x0800) or (xa & 0x8000):
        return False
    sub = img[extent * RAW + 16:extent * RAW + 24]
    return sub[0:4] == sub[4:8] and sub[1] < 32 and (sub[2] & 0x20) != 0


def expect(img, absent=(), new_rule=True):
    out = {}
    for p, (off, e, l, xa, su) in sorted(files_of(img).items()):
        if p in absent:
            continue
        c = content(img, e, l, new_rule and form2_file(img, e, xa))
        out[p] = [len(c), hashlib.sha256(c).hexdigest()]
    return out


def patch_record(img, path, attrs=None, sig=None, length=None):
    b = bytearray(img)
    off, e, l, xa, su = files_of(img)[path]
    if attrs is not None:
        b[off + su + 4:off + su + 6] = struct.pack(">H", attrs)
    if sig is not None:
        b[off + su + 6:off + su + 8] = sig
    if length is not None:
        b[off + 10:off + 14] = struct.pack("<I", length)
        b[off + 14:off + 18] = struct.pack(">I", length)
    return bytes(b)


def main(argv):
    ddir, out = argv
    vcd = open(ddir + "/vcd.bin", "rb").read()
    svcd = open(ddir + "/svcd.bin", "rb").read()
    vmpg = open(ddir + "/v.mpg", "rb").read()
    smpg = open(ddir + "/s.mpg", "rb").read()
    vpts = [0, 450, 897]
    rows = {}

    def row(name, image, files, source=None, absent=()):
        rows[name] = {"image": image, "files": files, "absent": list(absent), "source": source}

    write_ccd(out + "/real_vcd.img", vcd, vpts, [2, 2, 2])
    ev = expect(vcd)
    row("R-VCD-CCD", "real_vcd.img", ev, ["MPEGAV/AVSEQ01.DAT", "v.mpg"])
    b = vpts + [len(vcd) // RAW]
    write_nrg(out + "/real_vcd.nrg", [(to2336(vcd[b[i] * RAW:b[i + 1] * RAW]), 0x03, b[i]) for i in range(3)], [3])
    row("R-VCD-NRG", "real_vcd.nrg", ev, ["MPEGAV/AVSEQ01.DAT", "v.mpg"])
    write_ccd(out + "/real_svcd.img", svcd, [0, 450], [2, 2])
    es = expect(svcd)
    row("R-SVCD-CCD", "real_svcd.img", es, ["MPEG2/AVSEQ01.MPG", "s.mpg"])
    open(out + "/real_vcd.bin", "wb").write(vcd)
    row("R-VCD-BIN", "real_vcd.bin", ev, ["MPEGAV/AVSEQ01.DAT", "v.mpg"])

    m = patch_record(vcd, "MPEGAV/AVSEQ01.DAT", attrs=0x3D55)
    write_ccd(out + "/mixed.img", m, vpts, [2, 2, 2])
    row("C-MIXED", "mixed.img", expect(m))
    m = patch_record(vcd, "MPEGAV/AVSEQ01.DAT", sig=b"XB")
    write_ccd(out + "/noxa.img", m, vpts, [2, 2, 2])
    row("C-NOXA", "noxa.img", expect(m))
    m = bytearray(vcd)
    e2 = files_of(vcd)["MPEGAV/AVSEQ02.DAT"][1]
    m[e2 * RAW + 16:e2 * RAW + 24] = bytes([1, 1, 0x08, 0, 1, 1, 0x08, 0])
    m = bytes(m)
    write_ccd(out + "/f1sub.img", m, vpts, [2, 2, 2])
    row("C-F1SUB", "f1sub.img", expect(m))
    cooked = b"".join(vcd[i * RAW + 24:i * RAW + 24 + 2048] for i in range(len(vcd) // RAW))
    open(out + "/cooked.iso", "wb").write(cooked)
    row("C-COOKED", "cooked.iso", expect(vcd, new_rule=False))
    n2 = (files_of(vcd)["MPEGAV/AVSEQ02.DAT"][2] + 2047) // 2048
    cut = vcd[:(e2 + n2 - 7) * RAW]
    write_ccd(out + "/cut.img", cut, vpts, [2, 2, 2], leadout=len(vcd) // RAW)
    row("C-CUT", "cut.img", expect(vcd, absent=("MPEGAV/AVSEQ02.DAT",)), absent=["MPEGAV/AVSEQ02.DAT"])
    m = patch_record(vcd, "MPEGAV/AVSEQ01.DAT", length=240 * 2048)
    write_ccd(out + "/short240.img", m, vpts, [2, 2, 2])
    row("C-SHORT240", "short240.img", expect(m))
    # review 1 (NOTE): the real VCD's two video files are byte-identical - a read from the wrong track or offset
    # would pass; AVSEQ02's user data altered in every sector, also past byte 2048 (reviewer's rev366.py)
    m = bytearray(vcd)
    n2s = (files_of(vcd)["MPEGAV/AVSEQ02.DAT"][2] + 2047) // 2048
    for i in range(n2s):
        base = (e2 + i) * RAW + 24
        for k in (0, 1000, 2047, 2048, 2200, 2323):
            m[base + k] ^= (0x5A + i) & 0xFF
    m = bytes(m)
    write_ccd(out + "/diff2.img", m, vpts, [2, 2, 2])
    ed = expect(m)
    assert ed["MPEGAV/AVSEQ01.DAT"] != ed["MPEGAV/AVSEQ02.DAT"]
    row("D-DIFF2-CCD", "diff2.img", ed, ["MPEGAV/AVSEQ01.DAT", "v.mpg"])
    write_nrg(out + "/diff2.nrg", [(to2336(m[b[i] * RAW:b[i + 1] * RAW]), 0x03, b[i]) for i in range(3)], [3])
    row("D-DIFF2-NRG", "diff2.nrg", ed, ["MPEGAV/AVSEQ01.DAT", "v.mpg"])

    # the sources must be whole in the rows' video files (the measurement of the item)
    for name, r in rows.items():
        if r["source"]:
            p, s = r["source"]
            img = svcd if name.startswith("R-SVCD") else vcd
            off, e, l, xa, su = files_of(img)[p]
            c = content(img, e, l, True)
            src = smpg if s == "s.mpg" else vmpg
            assert src in c, (name, p)
    json.dump(rows, open(out + "/expect.json", "w"), indent=1)
    for name, r in rows.items():
        print(name, r["image"], ", ".join("%s:%d" % (p, v[0]) for p, v in r["files"].items()))


if __name__ == "__main__":
    main(sys.argv[1:])
