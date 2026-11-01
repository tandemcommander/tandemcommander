"""Feature 377: test images derived from a UDF 2.50 image written by Windows' IMAPI2FS.

    python -I img377.py swap    <in.iso> <out.bin>   the logical volume descriptor and the partition
                                                     descriptor of the main sequence exchanged (PD first);
                                                     tag locations and tag checksums fixed
    python -I img377.py metafar <in.iso> <out.bin>   the metadata partition map's metadata file location set
                                                     to 0x00FFFF00 (past the image); descriptor CRC and tag
                                                     checksum fixed

Prints one line: mode, size and what was changed. Exit 1 when the input has not the expected layout.
"""
import struct
import sys

S = 2048
TAG_PD, TAG_LVD, TAG_TERM = 5, 6, 8


def crc_ccitt(data):
    crc = 0
    for b in data:
        crc ^= b << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else (crc << 1)
            crc &= 0xFFFF
    return crc


def fix_tag(buf, off, location=None, recrc=False):
    if location is not None:
        struct.pack_into('<I', buf, off + 12, location)
    if recrc:
        crclen, = struct.unpack_from('<H', buf, off + 10)
        struct.pack_into('<H', buf, off + 8, crc_ccitt(bytes(buf[off + 16:off + 16 + crclen])))
    buf[off + 4] = sum(buf[off + i] for i in range(16) if i != 4) & 0xFF


def main_sequence(buf):
    anchor = 256 * S
    if struct.unpack_from('<H', buf, anchor)[0] != 2:
        sys.exit('no anchor at 256')
    length, loc = struct.unpack_from('<II', buf, anchor + 16)
    return loc, loc + length // S


def find(buf, first, last, tag):
    for n in range(first, last):
        if struct.unpack_from('<H', buf, n * S)[0] == tag:
            return n
    return None


def main():
    mode, src, dst = sys.argv[1:4]
    buf = bytearray(open(src, 'rb').read())
    first, last = main_sequence(buf)
    lvd = find(buf, first, last, TAG_LVD)
    pd = find(buf, first, last, TAG_PD)
    if lvd is None or pd is None:
        sys.exit('no LVD / PD in the main sequence')
    if mode == 'swap':
        if lvd > pd:
            sys.exit('the LVD already follows the PD')
        a, b = bytes(buf[lvd * S:(lvd + 1) * S]), bytes(buf[pd * S:(pd + 1) * S])
        buf[lvd * S:(lvd + 1) * S] = b
        buf[pd * S:(pd + 1) * S] = a
        fix_tag(buf, lvd * S, location=lvd)
        fix_tag(buf, pd * S, location=pd)
        what = 'PD now at %d, LVD at %d' % (lvd, pd)
    elif mode == 'metafar':
        o = lvd * S
        count, = struct.unpack_from('<I', buf, o + 268)
        off = o + 440
        done = False
        for _ in range(count):
            t, ln = buf[off], buf[off + 1]
            if t == 2 and bytes(buf[off + 5:off + 28]) == b'*UDF Metadata Partition':
                old, = struct.unpack_from('<I', buf, off + 40)
                struct.pack_into('<I', buf, off + 40, 0x00FFFF00)
                done = True
                break
            off += ln
        if not done:
            sys.exit('no metadata partition map')
        fix_tag(buf, o, recrc=True)
        what = 'metadata file location %d -> 0x00FFFF00' % old
    else:
        sys.exit('unknown mode ' + mode)
    open(dst, 'wb').write(buf)
    print('%s: %d bytes, %s' % (mode, len(buf), what))


if __name__ == '__main__':
    main()
