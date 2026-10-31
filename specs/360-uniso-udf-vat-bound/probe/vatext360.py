"""Review 1 of feature 360 (its vatext.py): mk_cdr.img variants whose VAT 2.00 file entry uses short / long /
extended allocation descriptors (the extent path of CUDF::ReadAllocDesc) instead of embedded data. The table
is moved to the free partition sectors 280 / 281.

    python -I vatext360.py <kind> <mk_cdr.img> <out>

kinds:
    sadok      one short descriptor, extent length = information length (opens)
    sad2       two short descriptors, half the table each (opens)
    ladok      one long descriptor (opens);  extok  one extended descriptor (opens)
    sadbig     a short descriptor of 4096 bytes against an information length of 160 (before 360: heap
               corruption; now not a VAT)
    sadround   a short descriptor of 2048 bytes (a whole block; before: heap corruption; now not a VAT)
    sadcut     L_AD 12 - a second descriptor cut by the area's end (not a VAT)
    rootadt5   the ROOT folder's file entry (not the VAT) gets the reserved descriptor type 5 - the general
               reader CUDF::ReadFileEntry hangs (review 1, SHOULD 2: an Inbox item, not part of 360)
"""
import struct
import sys

S = 2048


def vatentry(img):
    n = len(img) // S
    for s in range(n - 1, max(0, n - 10) - 1, -1):
        tid = struct.unpack_from('<H', img, s * S)[0]
        if tid in (261, 266) and img[s * S + 16 + 11] == 248:
            return s, tid == 266
    raise SystemExit('no VAT entry')


def pstart(img):
    n = len(img) // S
    for s in range(n):
        if struct.unpack_from('<H', img, s * S)[0] == 5 and struct.unpack_from('<H', img, s * S + 2)[0] in (2, 3):
            return struct.unpack_from('<I', img, s * S + 188)[0]
    raise SystemExit('no partition descriptor')


def main():
    kind, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    img = open(src, 'rb').read()
    m = bytearray(img)
    if kind == 'rootadt5':
        # the root folder's file entry (file type 4): reserved descriptor type 5 - the general reader
        # CUDF::ReadFileEntry(data, bEFE, part, icbTag, ad, maxAds) has no case for it
        for r in range(len(img) // S):
            if struct.unpack_from('<H', img, r * S)[0] in (261, 266) and img[r * S + 16 + 11] == 4:
                fa = r * S + 16 + 18
                struct.pack_into('<H', m, fa, (struct.unpack_from('<H', m, fa)[0] & ~7) | 5)
                open(out, 'wb').write(bytes(m))
                print(kind, 'root entry sector', r)
                return
        raise SystemExit('no root entry')
    s, efe = vatentry(img)
    b = s * S
    ps = pstart(img)
    il = struct.unpack_from('<Q', m, b + 56)[0]
    area = b + (216 if efe else 176)
    lad_at = b + (212 if efe else 172)
    table = bytes(m[area:area + il])
    d1, d2 = 280, 281  # free sectors in the partition, before the VAT
    for d in (d1, d2):
        if m[d * S:(d + 1) * S] != bytes(S):
            raise SystemExit('sector %d not free' % d)
    l1, l2 = d1 - ps, d2 - ps
    flags_at = b + 16 + 18
    flags = struct.unpack_from('<H', m, flags_at)[0] & ~7

    def short_ad(at, length, loc):
        struct.pack_into('<II', m, at, length, loc)

    if kind in ('sadok', 'sadbig', 'sadround', 'sadcut'):
        m[d1 * S:d1 * S + il] = table
        struct.pack_into('<H', m, flags_at, flags | 0)
        length = {'sadok': il, 'sadbig': 4096, 'sadround': S, 'sadcut': il}[kind]
        short_ad(area, length, l1)
        struct.pack_into('<I', m, lad_at, 12 if kind == 'sadcut' else 8)
    elif kind == 'sad2':
        half = il // 2
        m[d1 * S:d1 * S + half] = table[:half]
        m[d2 * S:d2 * S + (il - half)] = table[half:]
        struct.pack_into('<H', m, flags_at, flags | 0)
        short_ad(area, half, l1)
        short_ad(area + 8, il - half, l2)
        struct.pack_into('<I', m, lad_at, 16)
    elif kind == 'ladok':
        m[d1 * S:d1 * S + il] = table
        struct.pack_into('<H', m, flags_at, flags | 1)
        m[area:area + 16] = bytes(16)
        struct.pack_into('<IIH', m, area, il, l1, 0)
        struct.pack_into('<I', m, lad_at, 16)
    elif kind == 'extok':
        m[d1 * S:d1 * S + il] = table
        struct.pack_into('<H', m, flags_at, flags | 2)
        m[area:area + 20] = bytes(20)
        struct.pack_into('<IIIIH', m, area, il, il, il, l1, 0)
        struct.pack_into('<I', m, lad_at, 20)
    else:
        raise SystemExit('unknown kind ' + kind)
    open(out, 'wb').write(bytes(m))
    print(kind, 'vat sector', s, 'efe', efe, 'IL', il, 'pstart', ps, 'data at', d1, d2)


if __name__ == '__main__':
    main()
