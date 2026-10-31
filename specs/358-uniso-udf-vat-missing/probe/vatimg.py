"""Feature 358: UDF images of a sequential medium (a virtual allocation table, VAT) written by mkudffs
(mkudf356.sh, mkvat358.sh), with more in the file than the volume - the images of review 2 of feature 356
(compose2.py, %TEMP%\\rev356b) - or with a damaged VAT header (review 1 of 358, craft.py).

    python -I vatimg.py <kind> <mkudffs image> <out>

kinds (S = 2048-byte sectors; mkudffs --media-type=cdr 4000 writes a ~300-sector volume ending with its
VAT, its partition descriptor claims the whole 4000 sectors):
    data100    the volume + 100 sectors of 0x5A (the VAT is not in the file's last sectors)
    toclaim    the volume + 0x5A up to the claimed 4000 sectors (the VAT sector the reader asks for is read
               from the 0x5A data, the read past it fails: "Error reading virtual allocation table")
    claim16    the volume + 0x5A up to 4016 sectors (every sector the reader looks at is 0x5A)
    claim100z  the volume + 0x5A up to 4000 sectors + 100 zero sectors
    hdlong     a VAT 2.00 whose header length (the table's first 16-bit value) is 8 bytes longer than the
               VAT file - before 358 the entry count wrapped and the table pointer lay past the buffer
    hdeq       a VAT 2.00 whose header length equals the VAT file's length: 0 entries - before 358 the
               reader still translated virtual block 0 (entry 0, one past the table)
"""
import struct
import sys

S = 2048


def vat200(img):
    """the last file entry (tag 261, extended 266) of file type 248 among the last 10 sectors:
    (sector, offset of the table in the image, information length)"""
    n = len(img) // S
    for s in range(n - 1, max(0, n - 10) - 1, -1):
        tid = struct.unpack_from('<H', img, s * S)[0]
        if tid not in (261, 266):
            continue
        efe = tid == 266
        if img[s * S + 16 + 11] != 248:
            continue
        il = struct.unpack_from('<Q', img, s * S + 56)[0]
        lea = struct.unpack_from('<I', img, s * S + (208 if efe else 168))[0]
        return s, s * S + 176 + (40 if efe else 0) + lea, il
    raise SystemExit('no VAT 2.00 file entry in the last 10 sectors')


def main():
    kind, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    img = open(src, 'rb').read()
    if len(img) % S:
        raise SystemExit('not whole sectors: %d' % len(img))
    n = len(img) // S
    if kind == 'data100':
        res = img + b'\x5a' * (100 * S)
    elif kind == 'toclaim':
        res = img + b'\x5a' * ((4000 - n) * S)
    elif kind == 'claim16':
        res = img + b'\x5a' * ((4016 - n) * S)
    elif kind == 'claim100z':
        res = img + b'\x5a' * ((4000 - n) * S) + bytes(100 * S)
    elif kind in ('hdlong', 'hdeq'):
        # the table is embedded in the file entry (mkudffs), so changing its first word changes no CRC the
        # reader checks
        s, off, il = vat200(img)
        m = bytearray(img)
        struct.pack_into('<H', m, off, il + 8 if kind == 'hdlong' else il)
        res = bytes(m)
    else:
        raise SystemExit('unknown kind ' + kind)
    open(out, 'wb').write(res)
    print(kind, len(res) // S, 'sectors')


if __name__ == '__main__':
    main()
