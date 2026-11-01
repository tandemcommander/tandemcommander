"""Feature 368: ISO 9660 images holding files stored in several extents (multi-extent, ISO 9660 level 3: every
directory record of the file but the last has bit 7 of its file flags set), for iso368_probe.ps1.

  python -I img368.py <out dir>

Writes the images and <out dir>/expect.json: {image: {"files": {path: [size, sha256]}, "absent": [paths],
"kept": bool}} - what a whole unpack must leave in its target and whether the image must be kept.

Every image holds (ISO 9660 identifiers; the Rock Ridge / Joliet names in brackets)
  BIG.BIN    [big.bin / Big File.bin]  three extents out of disc order: 4096 bytes at sector 60, 2048 at
             sector 50, 1000 at sector 55 - its content is the three in record order (7144 bytes)
  SMALL.TXT  [small.txt / Small.txt]   "SMALL", one extent
  SUB/PART.BIN [sub/part.bin / Sub/Part.bin]  two extents, contiguous: 2048 at 70, 500 at 71 (2548 bytes)
  ZED.TXT    [zed.txt / Zed.txt]       "ZED", one extent (after the multi-extent records)
Images
  plain.iso    ISO 9660 only (the names as the identifiers, version removed)
  rr.iso       ISO 9660 + Rock Ridge (SP in the root's '.', NM in every record - names in lower case)
  joliet.iso   ISO 9660 + Joliet (the Joliet tree is listed)
  rrfirst.iso  rr.iso with NM only in the first record of each multi-extent file
  brkname.iso  plain.iso, BIG.BIN's last record renamed BIH.BIN: BIG.BIN's chain ends without its last record
               - BIG.BIN must not be extracted (BIH.BIN is a file of its own, 1000 bytes), the image kept
  brkend.iso   plain.iso, PART.BIN's last record flagged too (the chain runs to the directory's end): PART.BIN
               not extracted, the image kept
  dirflag.iso  plain.iso, SUB's record flagged multi-extent (a directory: the flag means nothing there) -
               everything as plain.iso
"""
import hashlib
import json
import os
import struct
import sys

S = 2048
TOTAL = 400  # sectors (the image is padded with zeros)
MULTI = 0x80
DIRF = 0x02


def both16(v):
    return struct.pack("<H", v) + struct.pack(">H", v)


def both32(v):
    return struct.pack("<I", v) + struct.pack(">I", v)


DATE = bytes([126, 10, 25, 12, 0, 0, 0])  # 2026-10-25 12:00:00 GMT


def record(ident, extent, length, flags, su=b""):
    n = len(ident)
    body = (bytes([0]) + both32(extent) + both32(length) + DATE + bytes([flags, 0, 0]) + both16(1) + bytes([n]) +
            ident)
    if n % 2 == 0:
        body += b"\x00"
    body += su
    if (len(body) + 1) % 2:
        body += b"\x00"
    return bytes([len(body) + 1]) + body


def nm(name):
    b = name.encode("ascii")
    return b"NM" + bytes([5 + len(b), 1, 0]) + b


SP = b"SP" + bytes([7, 1, 0xBE, 0xEF, 0])


def pattern(seed, n):
    out = bytearray()
    x = seed
    while len(out) < n:
        x = (x * 1103515245 + 12345) & 0x7FFFFFFF
        out += struct.pack("<I", x)
    return bytes(out[:n])


def put(img, sector, data):
    img[sector * S:sector * S + len(data)] = data


def vd(kind, root_rec, joliet, pt_size, pt_l, pt_m):
    d = bytearray(S)
    d[0] = kind
    d[1:6] = b"CD001"
    d[6] = 1
    d[8:40] = b"TC368".ljust(32, b" ")
    d[40:72] = b"TC368".ljust(32, b" ")
    d[80:88] = both32(TOTAL)
    if joliet:
        d[88:91] = b"%/E"
    d[120:124] = both16(1)
    d[124:128] = both16(1)
    d[128:132] = both16(S)
    d[132:140] = both32(pt_size)
    d[140:144] = struct.pack("<I", pt_l)
    d[148:152] = struct.pack(">I", pt_m)
    d[156:156 + 34] = root_rec
    d[813:830] = b"2026102512000000\x00"
    d[881] = 1
    return bytes(d)


def path_table(big_endian, root_sector, sub_sector, sub_ident):
    p = ">" if big_endian else "<"
    t = bytes([1, 0]) + struct.pack(p + "I", root_sector) + struct.pack(p + "H", 1) + b"\x00\x00"
    t += bytes([len(sub_ident), 0]) + struct.pack(p + "I", sub_sector) + struct.pack(p + "H", 1) + sub_ident
    if len(sub_ident) % 2:
        t += b"\x00"
    return t


# the files: name -> list of (sector, length) sections; content of each section
BIG = [(60, 4096), (50, 2048), (55, 1000)]
PART = [(70, 2048), (71, 500)]


def build(kind):
    img = bytearray(TOTAL * S)
    rr = kind in ("rr", "rrfirst")
    joliet = kind == "joliet"
    # file data
    secdata = {}
    for i, (sec, ln) in enumerate(BIG):
        secdata[(sec, ln)] = pattern(1000 + i, ln)
        put(img, sec, secdata[(sec, ln)])
    for i, (sec, ln) in enumerate(PART):
        secdata[(sec, ln)] = pattern(2000 + i, ln)
        put(img, sec, secdata[(sec, ln)])
    put(img, 40, b"SMALL")
    put(img, 41, b"ZED")
    big = b"".join(secdata[x] for x in BIG)
    part = b"".join(secdata[x] for x in PART)

    ROOT, SUBD, JROOT, JSUB = 24, 25, 26, 27

    def iso_dir(root):
        su_dot = SP if (rr and root) else b""
        recs = [record(b"\x00", ROOT if root else SUBD, S, DIRF, su_dot), record(b"\x01", ROOT, S, DIRF)]
        if root:
            for i, (sec, ln) in enumerate(BIG):
                last = i == len(BIG) - 1
                ident = b"BIG.BIN;1"
                if kind == "brkname" and last:
                    ident = b"BIH.BIN;1"
                su = b""
                if rr and (kind == "rr" or i == 0):
                    su = nm("big.bin")
                if rr and kind == "rr" and False:
                    pass
                recs.append(record(ident, sec, ln, 0 if last else MULTI, su))
            recs.append(record(b"SMALL.TXT;1", 40, 5, 0, nm("small.txt") if rr else b""))
            sub_flags = DIRF | (MULTI if kind == "dirflag" else 0)
            recs.append(record(b"SUB", SUBD, S, sub_flags, nm("sub") if rr else b""))
            recs.append(record(b"ZED.TXT;1", 41, 3, 0, nm("zed.txt") if rr else b""))
        else:
            recs[1] = record(b"\x01", ROOT, S, DIRF)
            for i, (sec, ln) in enumerate(PART):
                last = i == len(PART) - 1
                flags = 0 if (last and kind != "brkend") else MULTI
                su = nm("part.bin") if rr and (kind == "rr" or i == 0) else b""
                recs.append(record(b"PART.BIN;1", sec, ln, flags, su))
        d = b"".join(recs)
        assert len(d) <= S
        return d

    def jname(s):
        return s.encode("utf-16-be")

    def jol_dir(root):
        recs = [record(b"\x00", JROOT if root else JSUB, S, DIRF), record(b"\x01", JROOT, S, DIRF)]
        if root:
            for i, (sec, ln) in enumerate(BIG):
                recs.append(record(jname("Big File.bin;1"), sec, ln, 0 if i == len(BIG) - 1 else MULTI))
            recs.append(record(jname("Small.txt;1"), 40, 5, 0))
            recs.append(record(jname("Sub"), JSUB, S, DIRF))
            recs.append(record(jname("Zed.txt;1"), 41, 3, 0))
        else:
            for i, (sec, ln) in enumerate(PART):
                recs.append(record(jname("Part.bin;1"), sec, ln, 0 if i == len(PART) - 1 else MULTI))
        d = b"".join(recs)
        assert len(d) <= S
        return d

    put(img, ROOT, iso_dir(True))
    put(img, SUBD, iso_dir(False))
    ptl = path_table(False, ROOT, SUBD, b"SUB")
    ptm = path_table(True, ROOT, SUBD, b"SUB")
    put(img, 20, ptl)
    put(img, 21, ptm)
    put(img, 16, vd(1, record(b"\x00", ROOT, S, DIRF), False, len(ptl), 20, 21))
    nxt = 17
    if joliet:
        put(img, JROOT, jol_dir(True))
        put(img, JSUB, jol_dir(False))
        jptl = path_table(False, JROOT, JSUB, jname("Sub"))
        jptm = path_table(True, JROOT, JSUB, jname("Sub"))
        put(img, 22, jptl)
        put(img, 23, jptm)
        put(img, 17, vd(2, record(b"\x00", JROOT, S, DIRF), True, len(jptl), 22, 23))
        nxt = 18
    term = bytearray(S)
    term[0] = 0xFF
    term[1:6] = b"CD001"
    term[6] = 1
    put(img, nxt, bytes(term))

    # what a whole unpack must leave
    if joliet:
        names = {"big": "Big File.bin", "small": "Small.txt", "sub": "Sub", "part": "Part.bin", "zed": "Zed.txt"}
    elif rr:
        names = {"big": "big.bin", "small": "small.txt", "sub": "sub", "part": "part.bin", "zed": "zed.txt"}
    else:
        names = {"big": "BIG.BIN", "small": "SMALL.TXT", "sub": "SUB", "part": "PART.BIN", "zed": "ZED.TXT"}
    files = {names["small"]: b"SMALL", names["zed"]: b"ZED"}
    absent = []
    kept = False
    if kind == "brkname":
        absent.append(names["big"])
        files["BIH.BIN"] = secdata[BIG[2]]
        kept = True
    else:
        files[names["big"]] = big
    if kind == "brkend":
        absent.append(names["sub"] + "/" + names["part"])
        kept = True
    else:
        files[names["sub"] + "/" + names["part"]] = part
    exp = {"files": {k: [len(v), hashlib.sha256(v).hexdigest()] for k, v in files.items()}, "absent": absent,
           "kept": kept}
    return bytes(img), exp


def main():
    out = sys.argv[1]
    os.makedirs(out, exist_ok=True)
    expect = {}
    for kind in ("plain", "rr", "joliet", "rrfirst", "brkname", "brkend", "dirflag"):
        img, exp = build(kind)
        with open(os.path.join(out, kind + ".iso"), "wb") as f:
            f.write(img)
        expect[kind + ".iso"] = exp
    with open(os.path.join(out, "expect.json"), "w", encoding="ascii") as f:
        json.dump(expect, f, indent=1, sort_keys=True)
    print("img368: " + ", ".join(sorted(expect)))


if __name__ == "__main__":
    main()
