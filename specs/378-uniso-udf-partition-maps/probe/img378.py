"""Backlog item iso-plug-in-a-crafted-udf-partition-map-count-reads-past-the: UDF images whose logical volume
descriptor (LVD) declares partition maps that do not fit, derived from an image written by Windows' IMAPI2FS.

    python -I imgmaps.py <mode> <in.iso> <out.bin>

    count   the map count set to 100000 (the table and its one map unchanged; the bytes after it are zero, a
            map length of 0)
    len0    the first map's length byte set to 0 (the count unchanged)
    table   the map table length set to 4 (shorter than the first map, 6 bytes)
    run     the map count set to 100000 and the sector after the real maps filled with 0xFF (maps of type 255,
            length 255): a reader without a bound walks past the 2048-byte sector
    many    the map count set to 300 and the table length to 1608 (the whole rest of the sector), filled with
            the first map repeated (type 1, length 6) - 268 maps fit, the count does not

The LVD is found in the main volume descriptor sequence named by the anchor at sector 256; its descriptor CRC
and tag checksum are fixed (the plug-in checks neither; the image stays well formed otherwise). Prints one line:
mode, size and what was changed. Exit 1 when the input has not the expected layout.
"""
import struct
import sys

S = 2048
TAG_LVD = 6


def crc_ccitt(data):
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else (crc << 1)
            crc &= 0xFFFF
    return crc


def fix_tag(buf, off):
    # the CRC covers the descriptor after the tag; a longer descriptor (table length changed) is covered up to
    # the sector's end at most
    maplen, = struct.unpack_from('<I', buf, off + 264)
    crclen = min(440 + maplen, S) - 16
    struct.pack_into('<H', buf, off + 10, crclen)
    struct.pack_into('<H', buf, off + 8, crc_ccitt(bytes(buf[off + 16:off + 16 + crclen])))
    buf[off + 4] = sum(buf[off + i] for i in range(16) if i != 4) & 0xFF


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    mode, src, dst = sys.argv[1:4]
    buf = bytearray(open(src, 'rb').read())
    anchor = 256 * S
    if struct.unpack_from('<H', buf, anchor)[0] != 2:
        sys.exit('no anchor at 256')
    length, loc = struct.unpack_from('<II', buf, anchor + 16)
    lvd = None
    for n in range(loc, loc + length // S):
        if struct.unpack_from('<H', buf, n * S)[0] == TAG_LVD:
            lvd = n
            break
    if lvd is None:
        sys.exit('no LVD in the main sequence')
    o = lvd * S
    maplen, count = struct.unpack_from('<II', buf, o + 264)
    if count < 1 or buf[o + 440] != 1 or buf[o + 441] != 6:
        sys.exit('the first map is not a type 1 map of 6 bytes')
    if mode == 'count':
        struct.pack_into('<I', buf, o + 268, 100000)
        what = 'map count %d -> 100000' % count
    elif mode == 'len0':
        buf[o + 441] = 0
        what = 'first map length 6 -> 0'
    elif mode == 'table':
        struct.pack_into('<I', buf, o + 264, 4)
        what = 'map table length %d -> 4' % maplen
    elif mode == 'run':
        struct.pack_into('<I', buf, o + 268, 100000)
        for i in range(o + 440 + maplen, o + S):
            buf[i] = 0xFF
        what = 'map count %d -> 100000, sector after the maps 0xFF' % count
    elif mode == 'many':
        first = bytes(buf[o + 440:o + 446])
        struct.pack_into('<I', buf, o + 264, S - 440)
        struct.pack_into('<I', buf, o + 268, 300)
        for i in range(o + 440, o + S - 5, 6):
            buf[i:i + 6] = first
        what = 'map table length %d -> %d, count %d -> 300, the first map repeated' % (maplen, S - 440, count)
    else:
        sys.exit('unknown mode ' + mode)
    fix_tag(buf, o)
    open(dst, 'wb').write(buf)
    print('%s: %d bytes, LVD at %d, %s' % (mode, len(buf), lvd, what))


if __name__ == '__main__':
    main()
