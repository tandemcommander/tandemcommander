"""Feature 366 measurement: the ISO 9660 records of a raw (2352-byte) Video CD image, their XA attributes,
and what a 2048-byte or a 2324-byte read of each file's sectors gives against the source MPEG.

  python -I vcdscan.py <bin> [<source mpeg> <dir/file to compare>] [<extracted file>]
"""
import struct
import sys

RAW = 2352


def sector(img, lba):
    return img[lba * RAW:(lba + 1) * RAW]


def user2048(img, lba):
    return sector(img, lba)[24:24 + 2048]


def user2324(img, lba):
    return sector(img, lba)[24:24 + 2324]


def records(img, extent, size):
    out = []
    data = b"".join(user2048(img, extent + i) for i in range((size + 2047) // 2048))
    pos = 0
    while pos < len(data):
        n = data[pos]
        if n == 0:
            pos = (pos // 2048 + 1) * 2048
            continue
        r = data[pos:pos + n]
        ext = struct.unpack("<I", r[2:6])[0]
        ln = struct.unpack("<I", r[10:14])[0]
        flags = r[25]
        idl = r[32]
        name = r[33:33 + idl]
        su = 33 + idl + (1 - idl % 2)
        sysuse = r[su:]
        xa = None
        if len(sysuse) >= 14 and sysuse[6:8] == b"XA":
            xa = struct.unpack(">H", sysuse[4:6])[0]
        out.append((name, ext, ln, flags, xa, sysuse[:14].hex()))
        pos += n
    return out


def main(argv):
    img = open(argv[0], "rb").read()
    pvd = user2048(img, 16)
    root = pvd[156:156 + 34]
    rext = struct.unpack("<I", root[2:6])[0]
    rlen = struct.unpack("<I", root[10:14])[0]
    files = {}

    def walk(ext, ln, path):
        for name, e, l, flags, xa, su in records(img, ext, ln):
            if name in (b"\x00", b"\x01"):
                continue
            p = (path + "/" if path else "") + name.decode("latin-1")
            print("%-30s extent %6d size %8d flags %02x XA %s  su %s" % (p, e, l, flags,
                                                                       "-" if xa is None else "%04x" % xa, su))
            if flags & 2:
                walk(e, l, p)
            else:
                files[p] = (e, l, xa)

    walk(rext, rlen, "")
    if len(argv) >= 3:
        src = open(argv[1], "rb").read()
        e, l, xa = files[argv[2]]
        n = (l + 2047) // 2048
        subs = [sector(img, e + i)[16:24] for i in range(n)]
        form2 = sum(1 for s in subs if s[2] & 0x20)
        print("file %s: %d sectors, %d Form 2 by subheader" % (argv[2], n, form2))
        a2048 = b"".join(user2048(img, e + i) for i in range(n))[:l]
        a2324 = b"".join(user2324(img, e + i) for i in range(n))
        print("2048-read: %d bytes, source %d bytes found in it: %s" % (len(a2048), len(src), src in a2048))
        print("2324-read: %d bytes, source found in it: %s at %d" % (len(a2324), src in a2324, a2324.find(src)))
        rest = a2324[:a2324.find(src)] + a2324[a2324.find(src) + len(src):]
        print("2324-read outside the source: %d bytes, all zero: %s" % (len(rest), rest == bytes(len(rest))))
        if len(argv) >= 4:
            x = open(argv[3], "rb").read()
            print("extracted %s: %d bytes; == 2048-read: %s; == 2324-read: %s" % (argv[3], len(x), x == a2048,
                                                                                  x == a2324))


if __name__ == "__main__":
    main(sys.argv[1:])
