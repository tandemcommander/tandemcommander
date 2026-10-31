"""Feature 358 (review 2, hyb.py): UDF (VAT) + ISO 9660 hybrids and a plain ISO 9660 image holding a UDF image as file data.
python -I hyb358.py <mk_cdr.img> <outdir>
"""
import os
import struct
import sys

S = 2048


def both32(v):
    return struct.pack('<I', v) + struct.pack('>I', v)


def both16(v):
    return struct.pack('<H', v) + struct.pack('>H', v)


def dirrec(name, lba, length, isdir):
    fi = name
    ln = 33 + len(fi)
    if ln % 2:
        ln += 1
    r = bytearray(ln)
    r[0] = ln
    r[2:10] = both32(lba)
    r[10:18] = both32(length)
    r[18:25] = bytes([126, 10, 31, 12, 0, 0, 0])
    r[25] = 2 if isdir else 0
    r[28:32] = both16(1)
    r[32] = len(fi)
    r[33:33 + len(fi)] = fi
    return bytes(r)


def pvd(volsize, rootlba):
    p = bytearray(S)
    p[0] = 1
    p[1:6] = b'CD001'
    p[6] = 1
    p[8:40] = b' ' * 32
    p[40:72] = b'HYB358'.ljust(32)
    p[80:88] = both32(volsize)
    p[120:124] = both16(1)
    p[124:128] = both16(1)
    p[128:132] = both16(2048)
    p[132:140] = both32(0)
    p[156:190] = dirrec(b'\x00', rootlba, S, True)
    for o in (813, 830, 847, 864):
        p[o:o + 16] = b'0' * 16
    p[881] = 1
    return bytes(p)


def term():
    t = bytearray(S)
    t[0] = 255
    t[1:6] = b'CD001'
    t[6] = 1
    return bytes(t)


def vrs(tag):
    v = bytearray(S)
    v[1:6] = tag
    v[6] = 1
    return bytes(v)


def rootdir(rootlba, files):
    d = dirrec(b'\x00', rootlba, S, True) + dirrec(b'\x01', rootlba, S, True)
    for name, lba, length in files:
        d += dirrec(name, lba, length, False)
    return d.ljust(S, b'\x00')


def put(img, s, data):
    assert len(data) % S == 0
    img[s * S:s * S + len(data)] = data


def main():
    src, out = sys.argv[1], sys.argv[2]
    mk = open(src, 'rb').read()
    n = len(mk) // S
    text = b'hello from the ISO 9660 part of a hybrid\r\n'
    # hybrid: ISO PVD 16, terminator 17, VRS 18-20, root 21, A.TXT 22; the UDF volume of mk_cdr untouched
    for name, data100, anchor in (('h_vat_anchor_data100.img', True, True), ('h_vat_noanchor_data100.img', True, False),
                                  ('h_vat_noanchor.img', False, False), ('h_vat_anchor.img', False, True)):
        img = bytearray(mk)
        for s in range(16, 32):
            assert not any(img[s * S:(s + 1) * S]) or s in (16, 17, 18), s
        put(img, 16, pvd(n + (100 if data100 else 0), 21))
        put(img, 17, term())
        put(img, 18, vrs(b'BEA01'))
        put(img, 19, vrs(b'NSR03'))
        put(img, 20, vrs(b'TEA01'))
        put(img, 21, rootdir(21, [(b'A.TXT;1', 22, len(text))]))
        put(img, 22, text.ljust(S, b'\x00'))
        if not anchor:
            img[256 * S:257 * S] = bytes(S)
        if data100:
            img += b'\x5a' * (100 * S)
        open(os.path.join(out, name), 'wb').write(img)
        print(name, len(img) // S)
    # plain ISO 9660 holding mk_cdr + 100 sectors as the file INNER.IMG (its NSR03 at 20 + 17 = 37, inside
    # DetectTrackFS's 16-128) and A.TXT
    inner = mk + b'\x5a' * (100 * S)
    first = 20
    total = 600
    img = bytearray(total * S)
    put(img, 16, pvd(total, 18))
    put(img, 17, term())
    put(img, 18, rootdir(18, [(b'A.TXT;1', 19, len(text)), (b'INNER.IMG;1', first, len(inner))]))
    put(img, 19, text.ljust(S, b'\x00'))
    put(img, first, inner)
    open(os.path.join(out, 'p_iso_inner.img'), 'wb').write(img)
    print('p_iso_inner.img', total)


if __name__ == '__main__':
    main()
