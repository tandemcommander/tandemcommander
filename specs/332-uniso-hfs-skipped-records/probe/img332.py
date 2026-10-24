"""Feature 332: damaged copies of an xorriso ISO 9660 + HFS+ hybrid (mkimg332.sh) for iso332_probe.ps1.

  python -I img332.py dump  <src>          the HFS+ catalog leaf records (node, offset, avail, key, type)
  python -I img332.py <how> <src> <dst>    a copy whose catalog record of a/side.txt (the file record,
                                           parent = folder a) is damaged:
      type   its record type set to 5 (neither folder nor file nor thread)
      key    its key length set to 0xFFFF (the key does not fit the record)
      long   its name length set to 256 units, the key length to 518 (the key fits) and the record type
             0x0002 written after that key (the name is longer than 255 units)
      short  its key length grown so that 10 bytes of record data remain to the end of the node's record
             area, 0x0002 written there (a file record shorter than its structure)
  python -I img332.py udffile <ud.iso> <dst>  (genisoimage -udf) a/side.txt's file identifier points
                                           its file entry far past the end of the image (feature 330
                                           marks this; the row confirms the UDF part of the item)
  Only bytes of side.txt's record, its entry of the node's record table and the node's free space
  after the last record change; "long" and "short" first move the record into that free space (they
  would otherwise run into the next record).
  Prints what it wrote.
"""

import struct
import sys


def be16(b, o):
    return struct.unpack_from(">H", b, o)[0]


def be32(b, o):
    return struct.unpack_from(">I", b, o)[0]


def find_vh(img):
    # the HFS+ volume header: "H+" version 4, 1024 bytes into the volume (a 512-byte boundary)
    for o in range(1024, len(img) - 512, 512):
        if img[o : o + 4] == b"H+\x00\x04":
            return o
    raise SystemExit("no HFS+ volume header")


def catalog(img):
    vh = find_vh(img)
    vol = vh - 1024
    block = be32(img, vh + 40)
    fork = vh + 272  # catalogFile: logicalSize 8, clumpSize 4, totalBlocks 4, extents 8 x (start, count)
    size = struct.unpack_from(">Q", img, fork)[0]
    start, count = be32(img, fork + 16), be32(img, fork + 20)
    if count * block < size:
        raise SystemExit("the catalog has more than one extent")
    base = vol + start * block
    node_size = be16(img, base + 14 + 18)
    first_leaf = be32(img, base + 14 + 10)
    return base, node_size, first_leaf


def records(img):
    base, ns, node = catalog(img)
    out = []
    while node:
        p = base + node * ns
        n = be16(img, p + 10)
        area_end = ns - 2 * n
        offs = [be16(img, p + ns - 2 * (i + 1)) for i in range(n)]
        for i, ofs in enumerate(offs):
            r = p + ofs
            klen = be16(img, r)
            parent = be32(img, r + 2)
            nlen = be16(img, r + 6)
            name = img[r + 8 : r + 8 + 2 * nlen].decode("utf-16-be", "replace")
            rtype = be16(img, r + 2 + klen)
            out.append(dict(node=node, nodeAt=p, ns=ns, index=i, count=n, at=r, ofs=ofs,
                            avail=area_end - ofs, last=(ofs == max(offs)), klen=klen,
                            parent=parent, name=name, type=rtype))
        node = be32(img, p)
    return out


def side_record(img):
    recs = records(img)
    folders = {}
    for r in recs:
        if r["type"] == 1:
            folders[be32(img, r["at"] + 2 + r["klen"] + 8)] = r["name"]
    hits = [r for r in recs if r["type"] == 2 and r["name"] == "side.txt" and folders.get(r["parent"]) == "a"]
    if len(hits) != 1:
        raise SystemExit("side.txt's file record not found once: %d" % len(hits))
    return hits[0]


# --- UDF (genisoimage -udf; after specs/330-iso-unreadable-folder/probe/img330.py) ---

SECTOR = 2048
FAR = 0x00100000  # a sector far past the end of every image here


def le16(b, o):
    return struct.unpack_from("<H", b, o)[0]


def le32(b, o):
    return struct.unpack_from("<I", b, o)[0]


def udf_layout(b):
    """(partition start sector, offset of the file set descriptor)"""
    if le16(b, 256 * SECTOR) != 2:
        raise SystemExit("no anchor volume descriptor pointer at sector 256")
    avdp = 256 * SECTOR
    vds_len, vds_loc = le32(b, avdp + 16), le32(b, avdp + 20)
    part_start = fsd_lb = None
    for sec in range(vds_loc, vds_loc + (vds_len + SECTOR - 1) // SECTOR):
        tag = le16(b, sec * SECTOR)
        if tag == 5:
            part_start = le32(b, sec * SECTOR + 188)
        elif tag == 6:
            fsd_lb = le32(b, sec * SECTOR + 248 + 4)
        elif tag == 8:
            break
    if part_start is None or fsd_lb is None:
        raise SystemExit("no partition / logical volume descriptor")
    fsd = (part_start + fsd_lb) * SECTOR
    if le16(b, fsd) != 256:
        raise SystemExit("no file set descriptor")
    return part_start, fsd


def udf_first_ad(b, part_start, lb):
    """offset of the first allocation descriptor of the file entry at logical block lb"""
    o = (part_start + lb) * SECTOR
    tag = le16(b, o)
    if tag == 261:
        return o + 176 + le32(b, o + 168)
    if tag == 266:
        return o + 216 + le32(b, o + 208)
    raise SystemExit("no file entry at logical block %d (tag %d)" % (lb, tag))


def udf_fid(b, part_start, dir_lb, name):
    """offset of the file identifier descriptor of 'name' (8-bit OSTA name) in the folder at dir_lb"""
    ad = udf_first_ad(b, part_start, dir_lb)
    length, pos = le32(b, ad) & 0x3FFFFFFF, le32(b, ad + 4)
    p = (part_start + pos) * SECTOR
    end = p + length
    while p < end:
        if le16(b, p) != 257:
            raise SystemExit("no file identifier descriptor at %d" % p)
        lfi, liu = b[p + 19], le16(b, p + 36)
        if bytes(b[p + 38 + liu : p + 38 + liu + lfi]) == b"\x08" + name.encode("ascii"):
            return p
        p += (38 + liu + lfi + 3) & ~3
    raise SystemExit("no %s in the UDF folder" % name)


def cmd_udffile(src, dst):
    # a/side.txt's identifier points its file entry far past the end of the image
    b = bytearray(open(src, "rb").read())
    ps, fsd = udf_layout(b)
    a = udf_fid(b, ps, le32(b, fsd + 400 + 4), "a")
    side = udf_fid(b, ps, le32(b, a + 20 + 4), "side.txt")
    old = le32(b, side + 20 + 4)
    struct.pack_into("<I", b, side + 20 + 4, FAR)
    open(dst, "wb").write(bytes(b))
    print("udffile: a/side.txt's identifier: ICB %d -> %#x" % (old, FAR))
    return 0


def main(argv):
    if len(argv) == 4 and argv[1] == "udffile":
        return cmd_udffile(argv[2], argv[3])
    if len(argv) == 3 and argv[1] == "dump":
        img = open(argv[2], "rb").read()
        for r in records(img):
            r["name"] = ascii(r["name"])
            print("node %(node)d #%(index)d/%(count)d ofs %(ofs)d avail %(avail)d last %(last)s keylen %(klen)d "
                  "parent %(parent)d type %(type)d name %(name)s" % r)
        return 0
    if len(argv) != 4 or argv[1] not in ("type", "key", "long", "short"):
        print(__doc__)
        return 2
    how, src, dst = argv[1:]
    img = bytearray(open(src, "rb").read())
    r = side_record(img)
    at = r["at"]
    if how == "type":
        struct.pack_into(">H", img, at + 2 + r["klen"], 5)
    elif how == "key":
        struct.pack_into(">H", img, at, 0xFFFF)
    else:
        if not r["last"]:
            # moved into the node's free space (its entry of the record table points there; the walk
            # takes offsets in any order): the record's bytes up to the next record, 512 bytes after
            # the last record - then it is the last record of its node
            offs = sorted(x["ofs"] for x in records(img) if x["nodeAt"] == r["nodeAt"])
            length = offs[offs.index(r["ofs"]) + 1] - r["ofs"]
            new_ofs = offs[-1] + 512
            area_end = r["ofs"] + r["avail"]
            if new_ofs + 600 > area_end:
                raise SystemExit("no free space in side.txt's node")
            img[r["nodeAt"] + new_ofs : r["nodeAt"] + new_ofs + length] = img[at : at + length]
            struct.pack_into(">H", img, r["nodeAt"] + r["ns"] - 2 * (r["index"] + 1), new_ofs)
            at = r["nodeAt"] + new_ofs
            r["avail"] = area_end - new_ofs
            r["ofs"] = new_ofs
        if how == "long":
            klen = 6 + 2 * 256
            if 2 + klen + 2 > r["avail"]:
                raise SystemExit("no room for a 256-unit name in the node")
            struct.pack_into(">H", img, at + 6, 256)
        else:
            klen = r["avail"] - 2 - 10
        struct.pack_into(">H", img, at, klen)
        struct.pack_into(">H", img, at + 2 + klen, 2)
    open(dst, "wb").write(bytes(img))
    print("%s: side.txt's record (node %d, offset %d, avail %d) -> %s" % (how, r["node"], r["ofs"], r["avail"], dst))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
