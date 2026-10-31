"""Feature 360: UDF images of a sequential medium (a virtual allocation table, VAT - mkudffs
--media-type=cdr, specs/356-uniso-udf-rest/probe/mkudf356.sh) whose VAT file entry is damaged so that the ISO
plug-in's VAT reader (CUDF::ReadVAT / ReadAllocDesc) used to write past its table buffer or read past the
2048-byte sector it parses.

    python -I vat360.py <kind> <mkudffs image> <out>

The VAT 2.00 file entry (tag 261 or extended 266, file type 248) is the last one among the image's last 10
sectors (a UDF 1.50 VAT: the last one of file type 0); mkudffs embeds the table in it (ICB flags & 7 == 3, InformationLength == L_AD). The reader checks no
descriptor CRC, so the fields are changed in place. kinds:
    ilm4      InformationLength lowered by 4, L_AD kept (review 1 of feature 358: the Debug CRT's "HEAP
              CORRUPTION DETECTED", the block allocated in ReadVAT)
    ladbig    L_AD raised to 4096: the descriptor area reaches past the sector, the copy past the table
    adtype5   ICB flags' descriptor type 5 (reserved): the reader took an uninitialised descriptor and never
              advanced (len 0)
    leahuge   L_EA 0xFFFFFF00: the 32-bit area offset wrapped to the sector's start
    ilhuge    InformationLength + 2^32: the buffer was allocated with the length cut to 32 bits
"""
import struct
import sys

S = 2048


def vatentry(img):
    """(sector, extended) of the VAT's file entry among the last 10 sectors: the last one of file type 248
    (UDF 2.00+), else the last one of file type 0 (the UDF 1.50 VAT, mkvat358.sh)"""
    n = len(img) // S
    for ft in (248, 0):
        for s in range(n - 1, max(0, n - 10) - 1, -1):
            tid = struct.unpack_from('<H', img, s * S)[0]
            if tid not in (261, 266):
                continue
            if img[s * S + 16 + 11] != ft:
                continue
            return s, tid == 266
    raise SystemExit('no VAT file entry in the last 10 sectors')


def main():
    kind, src, out = sys.argv[1], sys.argv[2], sys.argv[3]
    img = open(src, 'rb').read()
    if len(img) % S:
        raise SystemExit('not whole sectors: %d' % len(img))
    s, efe = vatentry(img)
    b = s * S
    m = bytearray(img)
    lea_at = b + (208 if efe else 168)
    lad_at = b + (212 if efe else 172)
    il = struct.unpack_from('<Q', m, b + 56)[0]
    lad = struct.unpack_from('<I', m, lad_at)[0]
    flags = struct.unpack_from('<H', m, b + 16 + 18)[0]
    if kind == 'ilm4':
        struct.pack_into('<Q', m, b + 56, il - 4)
    elif kind == 'ladbig':
        struct.pack_into('<I', m, lad_at, 4096)
    elif kind == 'adtype5':
        struct.pack_into('<H', m, b + 16 + 18, (flags & ~7) | 5)
    elif kind == 'leahuge':
        struct.pack_into('<I', m, lea_at, 0xFFFFFF00)
    elif kind == 'ilhuge':
        struct.pack_into('<Q', m, b + 56, il + (1 << 32))
    else:
        raise SystemExit('unknown kind ' + kind)
    open(out, 'wb').write(bytes(m))
    print(kind, 'sector', s, 'efe', efe, 'IL', il, 'L_AD', lad, 'flags', flags & 7)


if __name__ == '__main__':
    main()
