"""Feature 363: UDF file identifiers whose implementation-use length (L_IU) puts the name past the folder walk's
buffer, for iso363_probe.ps1 - the ISO plug-in's folder walk CUDF::ScanDir / CUDF::ReadFileIdentifier.

    python -I img363.py <kind> <seed> <out>

The seed of every kind is ud.iso (genisoimage -udf, specs/330-iso-unreadable-folder/probe/mkimg330.sh:
a/side.txt SIDE, top.txt TOP, zlast/z.txt Z). Kinds:
    aiu     the root's identifier of folder a gets L_IU 0xFFFF (the name 64 KB past the identifier)
    tiu     the root's identifier of file top.txt gets L_IU 0xFFFF
    siu     folder a's identifier of file side.txt gets L_IU 0xFFFF (a sub-folder's walk)
    aiu4k   the root's identifier of folder a gets L_IU 0x1000 (the name past the 4 KB buffer, inside 64 KB)
    afi     the root's identifier of folder a gets L_IU 4000 and L_FI 255 (the name starts inside the buffer
            and ends past it)

Before feature 363 the walk read the name at 38 + L_IU, L_FI bytes, without comparing them with its
two-sector buffer. The reader checks no descriptor CRC. Each kind prints what it changed and exits 3 without
writing when the layout is not the expected one.
"""

import struct
import sys

S = 2048


def le16(b, o):
    return struct.unpack_from('<H', b, o)[0]


def le32(b, o):
    return struct.unpack_from('<I', b, o)[0]


def refuse(msg):
    print('img363: refused - ' + msg)
    sys.exit(3)


def is_entry(b, o):
    return le16(b, o) in (261, 266)


def adtype(b, e):
    return le16(b, e + 16 + 18) & 7


def udf_layout(b):
    """(partition start sector, offset of the file set descriptor) - as img330.py / img362.py"""
    if le16(b, 256 * S) != 2:
        refuse('no anchor volume descriptor pointer at sector 256')
    avdp = 256 * S
    vds_len, vds_loc = le32(b, avdp + 16), le32(b, avdp + 20)
    part_start = fsd_lb = None
    for sec in range(vds_loc, vds_loc + (vds_len + S - 1) // S):
        tag = le16(b, sec * S)
        if tag == 5:
            part_start = le32(b, sec * S + 188)
        elif tag == 6:
            fsd_lb = le32(b, sec * S + 248 + 4)
        elif tag == 8:
            break
    if part_start is None or fsd_lb is None:
        refuse('no partition / logical volume descriptor')
    fsd = (part_start + fsd_lb) * S
    if le16(b, fsd) != 256:
        refuse('no file set descriptor at %d' % (part_start + fsd_lb))
    return part_start, fsd


def root_entry(b, ps, fsd):
    e = (ps + le32(b, fsd + 400 + 4)) * S
    if not is_entry(b, e):
        refuse('no root file entry')
    return e


def first_ad(b, e):
    if adtype(b, e) not in (0, 1):
        refuse('file entry at sector %d: not short / long descriptors' % (e // S))
    return e + (216 + le32(b, e + 208) if le16(b, e) == 266 else 176 + le32(b, e + 168))


def find_fid(b, ps, e, name):
    """offset of the identifier named 'name' (8-bit OSTA name) in the folder whose file entry is at e"""
    ad = first_ad(b, e)
    flen, fpos = le32(b, ad) & 0x3FFFFFFF, le32(b, ad + 4)
    p = (ps + fpos) * S
    end = p + flen
    while p < end:
        if le16(b, p) != 257:
            refuse('no file identifier descriptor at %d' % p)
        lfi, liu = b[p + 19], le16(b, p + 36)
        if lfi and bytes(b[p + 38 + liu:p + 38 + liu + lfi]) == b'\x08' + name:
            return p
        p += (38 + liu + lfi + 3) & ~3
    refuse('no identifier %s in the folder at sector %d' % (name.decode(), e // S))


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    kind, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    m = bytearray(open(src, 'rb').read())
    ps, fsd = udf_layout(m)
    root = root_entry(m, ps, fsd)
    if kind in ('aiu', 'aiu4k', 'afi'):
        p, who = find_fid(m, ps, root, b'a'), "the root's identifier of folder a"
    elif kind == 'tiu':
        p, who = find_fid(m, ps, root, b'top.txt'), "the root's identifier of top.txt"
    elif kind == 'siu':
        a = (ps + le32(m, find_fid(m, ps, root, b'a') + 20 + 4)) * S
        if not is_entry(m, a):
            refuse('folder a: no file entry')
        p, who = find_fid(m, ps, a, b'side.txt'), "folder a's identifier of side.txt"
    else:
        refuse('unknown kind ' + kind)
    old_iu, old_fi = le16(m, p + 36), m[p + 19]
    iu = {'aiu4k': 0x1000, 'afi': 4000}.get(kind, 0xFFFF)
    struct.pack_into('<H', m, p + 36, iu)
    msg = '%s (byte %d, sector %d + %d): L_IU %d -> %d' % (who, p, p // S, p % S, old_iu, iu)
    if kind == 'afi':
        m[p + 19] = 255
        msg += ', L_FI %d -> 255' % old_fi
    open(out, 'wb').write(bytes(m))
    print('%s: %s' % (kind, msg))
    return 0


if __name__ == '__main__':
    sys.exit(main())
