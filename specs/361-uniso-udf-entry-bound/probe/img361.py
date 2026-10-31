"""Feature 361: damaged UDF file entries for iso361_probe.ps1 - the general file-entry reader
CUDF::ReadFileEntry(data, bEFE, part, icbTag, ad, maxAds) of the ISO plug-in.

    python -I img361.py <kind> <seed> <out>

kinds:
    rootadt5    mk_cdr.img (mkudffs --media-type=cdr): the ROOT folder's file entry (file type 4) gets the
                reserved descriptor type 5 (review 1 of feature 360, vatext360.py rootadt5) - before: the reader
                never advanced, Tandem Commander stopped answering
    foldadt5    ud.iso (genisoimage -udf, specs/330-iso-unreadable-folder/probe/mkimg330.sh): folder a's file
                entry gets descriptor type 5 - before: a hang when the walk descends into a
    foldleabig  ud.iso: folder a's file entry gets L_EA 0x10000000 - before: the 32-bit area start lies 256 MB
                past the reader's 2048-byte sector (an access violation)
    fileadt5    ud.iso: file top.txt's file entry gets descriptor type 5 - the listing reads its size only;
                before: Unpack hung
    metaadt5    a UDF 2.50 image (mkudffs --udfrev=0x0250): the metadata file's entry (file type 250) gets
                descriptor type 5 - before: a hang while the volume opens

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
    print('img361: refused - ' + msg)
    sys.exit(3)


def set_type(m, entry, t):
    fa = entry + 16 + 18
    old = le16(m, fa)
    struct.pack_into('<H', m, fa, (old & ~7) | t)
    return old & 7


def is_entry(b, o):
    return le16(b, o) in (261, 266)


def udf_layout(b):
    """(partition start sector, offset of the file set descriptor) - as img330.py"""
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


def first_ad(b, ps, lb):
    o = (ps + lb) * S
    if le16(b, o) == 261:
        first = o + 176 + le32(b, o + 168)
    elif le16(b, o) == 266:
        first = o + 216 + le32(b, o + 208)
    else:
        refuse('no file entry at logical block %d' % lb)
    if le16(b, o + 16 + 18) & 7 not in (0, 1):
        refuse('file entry at logical block %d: not short / long descriptors' % lb)
    return first


def root_fid(b, ps, fsd, name, isdir):
    """offset of the root's file identifier descriptor of 'name' (8-bit OSTA name)"""
    rad = first_ad(b, ps, le32(b, fsd + 400 + 4))
    rlen, rpos = le32(b, rad) & 0x3FFFFFFF, le32(b, rad + 4)
    p = (ps + rpos) * S
    end = p + rlen
    while p < end:
        if le16(b, p) != 257:
            refuse('no file identifier descriptor at %d' % p)
        lfi, liu = b[p + 19], le16(b, p + 36)
        if bool(b[p + 18] & 2) == isdir and bytes(b[p + 38 + liu:p + 38 + liu + lfi]) == b'\x08' + name:
            return p
        p += (38 + liu + lfi + 3) & ~3
    refuse('no %s in the UDF root' % name.decode())


def main():
    if len(sys.argv) != 4:
        print(__doc__)
        return 2
    kind, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    m = bytearray(open(src, 'rb').read())
    if kind == 'rootadt5':
        for r in range(len(m) // S):
            if is_entry(m, r * S) and m[r * S + 16 + 11] == 4:
                old = set_type(m, r * S, 5)
                msg = 'root entry sector %d: descriptor type %d -> 5' % (r, old)
                break
        else:
            refuse('no root entry')
    elif kind == 'metaadt5':
        for r in range(len(m) // S):
            if is_entry(m, r * S) and m[r * S + 16 + 11] == 250:
                old = set_type(m, r * S, 5)
                msg = 'metadata file entry sector %d: descriptor type %d -> 5' % (r, old)
                break
        else:
            refuse('no metadata file entry (file type 250)')
    elif kind in ('foldadt5', 'foldleabig', 'fileadt5'):
        ps, fsd = udf_layout(m)
        if kind == 'fileadt5':
            p = root_fid(m, ps, fsd, b'top.txt', False)
            who = 'file top.txt'
        else:
            p = root_fid(m, ps, fsd, b'a', True)
            who = 'folder a'
        lb = le32(m, p + 20 + 4)
        e = (ps + lb) * S
        if not is_entry(m, e):
            refuse('%s: no file entry at logical block %d' % (who, lb))
        if kind == 'foldleabig':
            lea_at = e + (208 if le16(m, e) == 266 else 168)
            old = le32(m, lea_at)
            struct.pack_into('<I', m, lea_at, 0x10000000)
            msg = "%s's entry (sector %d): L_EA %d -> 0x10000000" % (who, e // S, old)
        else:
            old = set_type(m, e, 5)
            msg = "%s's entry (sector %d): descriptor type %d -> 5" % (who, e // S, old)
    else:
        refuse('unknown kind ' + kind)
    open(out, 'wb').write(bytes(m))
    print('%s: %s' % (kind, msg))
    return 0


if __name__ == '__main__':
    sys.exit(main())
