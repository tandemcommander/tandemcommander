"""Feature 362: UDF folder entries without allocation descriptors (L_AD 0) for iso362_probe.ps1 - the ISO
plug-in's folder reader CUDF::MapICB(CAD, CICBTag*, CAD*) (root and sub-folders).

    python -I img362.py <kind> <seed> <out>

kinds (the seed of each is named):
    alad0       ud.iso (genisoimage -udf, specs/330-iso-unreadable-folder/probe/mkimg330.sh): folder a's file
                entry (short descriptors) gets L_AD 0 - before: a listed empty without a mark, a whole unpack
                with "Delete archive after unpacking" deleted the image
    zlad0       ud.iso: folder zlast's file entry gets L_AD 0 (the last folder of the root)
    aemb0       ud.iso: folder a's file entry becomes embedded (descriptor type 3) with L_AD 0
    rootlad0    ud.iso: the UDF root folder's file entry gets L_AD 0
    rootemb0    mk_cdr.img (mkudffs --media-type=cdr, specs/356-uniso-udf-rest/probe/mkudf356.sh): the root folder's
                embedded file entry (descriptor type 3) gets L_AD 0
    alen0       ud.iso: folder a's first (only) descriptor gets extent length 0, L_AD kept (review 1 of 362)
    rootlen0    ud.iso: the UDF root's first (only) descriptor gets extent length 0, L_AD kept (review 1 of 362)

The reader checks no descriptor CRC or checksum. Each kind prints what it changed and exits 3 without writing
when the layout is not the expected one.
"""

import struct
import sys

S = 2048


def le16(b, o):
    return struct.unpack_from('<H', b, o)[0]


def le32(b, o):
    return struct.unpack_from('<I', b, o)[0]


def refuse(msg):
    print('img362: refused - ' + msg)
    sys.exit(3)


def is_entry(b, o):
    return le16(b, o) in (261, 266)


def lad_at(b, e):
    """offset of L_AD in the file entry at e (File Entry 172, Extended File Entry 212)"""
    return e + (212 if le16(b, e) == 266 else 172)


def adtype(b, e):
    return le16(b, e + 16 + 18) & 7


def set_type(b, e, t):
    fa = e + 16 + 18
    struct.pack_into('<H', b, fa, (le16(b, fa) & ~7) | t)


def udf_layout(b):
    """(partition start sector, offset of the file set descriptor) - as img330.py / img361.py"""
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


def root_fid(b, ps, fsd, name):
    """offset of the root's file identifier descriptor of folder 'name' (8-bit OSTA name)"""
    rad = first_ad(b, root_entry(b, ps, fsd))
    rlen, rpos = le32(b, rad) & 0x3FFFFFFF, le32(b, rad + 4)
    p = (ps + rpos) * S
    end = p + rlen
    while p < end:
        if le16(b, p) != 257:
            refuse('no file identifier descriptor at %d' % p)
        lfi, liu = b[p + 19], le16(b, p + 36)
        if (b[p + 18] & 2) and bytes(b[p + 38 + liu:p + 38 + liu + lfi]) == b'\x08' + name:
            return p
        p += (38 + liu + lfi + 3) & ~3
    refuse('no folder %s in the UDF root' % name.decode())


def zero_lad(m, e, who, embed=False):
    lad = lad_at(m, e)
    old, oldt = le32(m, lad), adtype(m, e)
    if old == 0:
        refuse('%s: L_AD is already 0' % who)
    struct.pack_into('<I', m, lad, 0)
    if embed:
        set_type(m, e, 3)
        return "%s's entry (sector %d): descriptor type %d -> 3, L_AD %d -> 0" % (who, e // S, oldt, old)
    return "%s's entry (sector %d, descriptor type %d): L_AD %d -> 0" % (who, e // S, oldt, old)


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    kind, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    m = bytearray(open(src, 'rb').read())
    if kind == 'rootemb0':
        for r in range(len(m) // S):
            if is_entry(m, r * S) and m[r * S + 16 + 11] == 4:
                if adtype(m, r * S) != 3:
                    refuse('root entry sector %d: not embedded' % r)
                msg = zero_lad(m, r * S, 'root')
                break
        else:
            refuse('no root entry')
    elif kind in ('alen0', 'rootlen0'):
        ps, fsd = udf_layout(m)
        if kind == 'rootlen0':
            e, who = root_entry(m, ps, fsd), 'root'
        else:
            who = 'folder a'
            e = (ps + le32(m, root_fid(m, ps, fsd, b'a') + 20 + 4)) * S
            if not is_entry(m, e):
                refuse('folder a: no file entry')
        ad = first_ad(m, e)
        old = le32(m, ad)
        if old & 0x3FFFFFFF == 0:
            refuse('%s: the first extent length is already 0' % who)
        struct.pack_into('<I', m, ad, old & 0xC0000000)
        msg = "%s's entry (sector %d): first extent length %d -> 0, L_AD %d kept" % (
            who, e // S, old & 0x3FFFFFFF, le32(m, lad_at(m, e)))
    elif kind in ('alad0', 'zlad0', 'aemb0', 'rootlad0'):
        ps, fsd = udf_layout(m)
        if kind == 'rootlad0':
            e, who = root_entry(m, ps, fsd), 'root'
        else:
            name = b'zlast' if kind == 'zlad0' else b'a'
            who = 'folder ' + name.decode()
            lb = le32(m, root_fid(m, ps, fsd, name) + 20 + 4)
            e = (ps + lb) * S
            if not is_entry(m, e):
                refuse('%s: no file entry at logical block %d' % (who, lb))
        if adtype(m, e) not in (0, 1):
            refuse('%s: not short / long descriptors' % who)
        msg = zero_lad(m, e, who, embed=(kind == 'aemb0'))
    else:
        refuse('unknown kind ' + kind)
    open(out, 'wb').write(bytes(m))
    print('%s: %s' % (kind, msg))
    return 0


if __name__ == '__main__':
    sys.exit(main())
