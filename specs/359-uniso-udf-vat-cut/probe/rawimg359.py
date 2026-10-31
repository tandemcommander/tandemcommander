"""Feature 359: a UDF image of a sequential medium (VAT) as a raw Mode 1 dump (2352-byte sectors) cut short.

    python -I rawimg.py <mkudffs 2048-byte image> <out> <sectors kept> [<partition start>] [--cooked]

Each 2048-byte sector becomes sync (12) + header (4: minute, second, frame, mode 1) + the data + 288 zero bytes
(EDC / ECC - the reader does not check them). Only the first <sectors kept> sectors are written. With
<partition start> both partition descriptors (tag 5) get that start (offset 188; the reader checks no CRC).
With --cooked the 2048-byte sectors are written as they are (no raw framing).
"""
import struct
import sys

S = 2048
SYNC = b'\x00' + b'\xff' * 10 + b'\x00'


def bcd(v):
    return ((v // 10) << 4) | (v % 10)


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    cooked = '--cooked' in sys.argv
    src, out, keep = args[0], args[1], int(args[2])
    start = int(args[3]) if len(args) > 3 else None
    img = bytearray(open(src, 'rb').read())
    if len(img) % S:
        raise SystemExit('not whole sectors: %d' % len(img))
    n = len(img) // S
    if start is not None:
        patched = 0
        for s in range(n):
            tid, ver = struct.unpack_from('<HH', img, s * S)
            loc = struct.unpack_from('<I', img, s * S + 12)[0]
            if tid == 5 and ver in (2, 3) and loc == s:
                struct.pack_into('<I', img, s * S + 188, start)
                patched += 1
        if not patched:
            raise SystemExit('no partition descriptor')
    res = bytearray()
    for s in range(min(keep, n)):
        data = bytes(img[s * S:(s + 1) * S])
        if cooked:
            res += data
            continue
        lba = s + 150
        hdr = bytes([bcd(lba // (60 * 75)), bcd((lba // 75) % 60), bcd(lba % 75), 1])
        res += SYNC + hdr + data + bytes(288)
    open(out, 'wb').write(bytes(res))
    print(out, len(res), 'bytes', min(keep, n), 'sectors', 'cooked' if cooked else 'raw 2352')


if __name__ == '__main__':
    main()
