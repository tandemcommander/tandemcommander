"""Feature 364: UDF folders stored in more than one extent, or read short of their Information Length, for
iso364_probe.ps1 - the ISO plug-in's folder reader CUDF::MapICB / CUDF::ScanDir.

    python -I img364.py <kind> <seed> <out>

Seeds: big364.iso (mkimg364.sh: genisoimage -udf -R, root and sub with 40 files a_rather_long_file_name_NN.txt
each - every folder's data about 2.9 KB in ONE extent) and ud.iso (specs/330-iso-unreadable-folder/probe/
mkimg330.sh: a/side.txt SIDE, top.txt TOP, zlast/z.txt Z). Kinds:
    rootsplit   big364.iso: the root's one descriptor (L bytes at block X) becomes two contiguous ones -
                2048 bytes at X + L - 2048 at X + 1 (a valid fragmented folder; review 1 of feature 362)
    rootfrag    big364.iso: as rootsplit, the second extent moved to a free (zero) block F and block X + 1
                zeroed - a folder whose extents are not contiguous
    subsplit    big364.iso: as rootsplit for folder sub (a sub-folder's walk)
    subfrag     big364.iso: as rootfrag for folder sub
    rootcont    big364.iso: the root's descriptors 2048 bytes at X + an allocation extent descriptor (extent
                type 3: "the descriptors continue there") - the rest is not read
    rootunrec   big364.iso: as rootsplit, the second extent of type 1 (allocated, not recorded)
    alen38      ud.iso: folder a's one extent 88 -> 38 bytes, its Information Length kept 88 (review 3 of 362)
    alen40      ud.iso: as alen38 with 40 bytes

The reader checks no descriptor CRC. Each kind prints what it changed and exits 3 without writing when the
layout is not the expected one.
"""

import struct
import sys

S = 2048


def le16(b, o):
    return struct.unpack_from('<H', b, o)[0]


def le32(b, o):
    return struct.unpack_from('<I', b, o)[0]


def le64(b, o):
    return struct.unpack_from('<Q', b, o)[0]


def refuse(msg):
    print('img364: refused - ' + msg)
    sys.exit(3)


def is_entry(b, o):
    return le16(b, o) in (261, 266)


def adtype(b, e):
    return le16(b, e + 16 + 18) & 7


def udf_layout(b):
    """(partition start sector, offset of the file set descriptor) - as img330.py / img363.py"""
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


def ad_area(b, e):
    """(offset of the descriptors, offset of L_AD, descriptor size)"""
    t = adtype(b, e)
    if t not in (0, 1):
        refuse('file entry at sector %d: not short / long descriptors' % (e // S))
    if le16(b, e) == 266:
        return e + 216 + le32(b, e + 208), e + 212, 8 if t == 0 else 16
    return e + 176 + le32(b, e + 168), e + 172, 8 if t == 0 else 16


def find_fid(b, ps, e, name):
    """offset of the identifier named 'name' (8-bit OSTA name) in the folder whose file entry is at e"""
    ad, _, _ = ad_area(b, e)
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


def child_entry(b, ps, e, name):
    c = (ps + le32(b, find_fid(b, ps, e, name) + 20 + 4)) * S
    if not is_entry(b, c):
        refuse('folder %s: no file entry' % name.decode())
    return c


def put_ad(b, o, size, length, etype, loc, part):
    struct.pack_into('<II', b, o, (etype << 30) | length, loc)
    if size == 16:
        struct.pack_into('<H', b, o + 8, part)
        b[o + 10:o + 16] = bytes(6)


def free_block(b, ps, after):
    """a partition block >= 'after' whose sector is all zero and not the image's last (the window reads two
    sectors; genisoimage leaves no padding past the partition, single zero sectors lie between the files' data)"""
    zero = bytes(S)
    n = len(b) // S
    for s in range(ps + after, n - 1):
        if bytes(b[s * S:(s + 1) * S]) == zero:
            return s - ps
    refuse('no free block after %d' % after)


def split(b, ps, e, who, mode):
    """the folder at entry e: its one descriptor into two (mode split / frag / cont / unrec)"""
    ad, lad_off, size = ad_area(b, e)
    if le32(b, lad_off) != size:
        refuse('%s: L_AD %d, not one descriptor' % (who, le32(b, lad_off)))
    raw = le32(b, ad)
    length, etype, loc = raw & 0x3FFFFFFF, raw >> 30, le32(b, ad + 4)
    part = le16(b, ad + 8) if size == 16 else 0
    info = le64(b, e + 56)
    if etype != 0 or length <= S or length > 2 * S or info != length:
        refuse('%s: extent %d bytes of type %d, Information Length %d - not one recorded extent of 2048 .. 4096'
               % (who, length, etype, info))
    if any(b[ad + size:ad + 2 * size]) or (ad + 2 * size) > (e + S):
        refuse('%s: no room for a second descriptor' % who)
    rest = length - S
    second_loc, second_type, second_len = loc + 1, 0, rest
    msg = ''
    if mode == 'frag':
        f = free_block(b, ps, loc + 2)
        src = (ps + loc + 1) * S
        b[(ps + f) * S:(ps + f + 1) * S] = b[src:src + S]
        b[src:src + S] = bytes(S)
        second_loc = f
        msg = ', block %d copied to free block %d and zeroed' % (loc + 1, f)
    elif mode == 'cont':
        second_loc, second_type, second_len = free_block(b, ps, loc + 2), 3, S
    elif mode == 'unrec':
        second_type = 1
    put_ad(b, ad, size, S, 0, loc, part)
    put_ad(b, ad + size, size, second_len, second_type, second_loc, part)
    struct.pack_into('<I', b, lad_off, 2 * size)
    return '%s (entry at sector %d, %d-byte descriptors): %d bytes at %d -> %d at %d + %d of type %d at %d%s' % (
        who, e // S, size, length, loc, S, loc, second_len, second_type, second_loc, msg)


def shorten(b, ps, e, who, new_len):
    ad, lad_off, size = ad_area(b, e)
    raw = le32(b, ad)
    length = raw & 0x3FFFFFFF
    info = le64(b, e + 56)
    if le32(b, lad_off) != size or raw >> 30 != 0 or length != 88 or info != 88:
        refuse('%s: not one recorded 88-byte extent with Information Length 88 (%d, %d)' % (who, length, info))
    struct.pack_into('<I', b, ad, new_len)
    return '%s (entry at sector %d): extent 88 -> %d bytes, Information Length kept %d' % (who, e // S, new_len, info)


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    kind, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    m = bytearray(open(src, 'rb').read())
    ps, fsd = udf_layout(m)
    root = root_entry(m, ps, fsd)
    modes = {'rootsplit': 'split', 'rootfrag': 'frag', 'rootcont': 'cont', 'rootunrec': 'unrec',
             'subsplit': 'split', 'subfrag': 'frag'}
    if kind in modes:
        if kind.startswith('root'):
            msg = split(m, ps, root, 'the root', modes[kind])
        else:
            msg = split(m, ps, child_entry(m, ps, root, b'sub'), 'folder sub', modes[kind])
    elif kind in ('alen38', 'alen40'):
        msg = shorten(m, ps, child_entry(m, ps, root, b'a'), 'folder a', int(kind[4:]))
    else:
        refuse('unknown kind ' + kind)
    open(out, 'wb').write(bytes(m))
    print('%s: %s' % (kind, msg))
    return 0


if __name__ == '__main__':
    sys.exit(main())
