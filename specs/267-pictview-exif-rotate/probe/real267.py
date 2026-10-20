"""Feature 267: the Exif facts of real camera files, read independently of WIC.

    python -I real267.py <folder with *.jpg (searched recursively)>

One line per file: "<relative path>|app1=<0/1>|orient=<n or ->|dims=<WxH or ->|size=<WxH>".
app1 = an Exif APP1 block before the picture data (own walker, as feature 132's rule);
orient / dims = tag 274 of IFD0 and tags 40962 / 40963 of the Exif IFD (own TIFF reader);
size = the picture's size from the SOF segment. Pure ASCII output.
"""
import os
import struct
import sys


def segments(data):
    o = 2
    while o + 4 <= len(data) and data[o] == 0xFF:
        while o + 1 < len(data) and data[o + 1] == 0xFF:
            o += 1
        m = data[o + 1]
        if m == 0xDA or m == 0xD9:
            return
        ln = struct.unpack('>H', data[o + 2:o + 4])[0]
        yield m, data[o + 4:o + 2 + ln]
        o += 2 + ln


def ifd_entries(t, off, e):
    out = {}
    if off + 2 > len(t):
        return out, 0
    n = struct.unpack(e + 'H', t[off:off + 2])[0]
    for i in range(n):
        p = off + 2 + 12 * i
        if p + 12 > len(t):
            break
        tag, typ, cnt = struct.unpack(e + 'HHI', t[p:p + 8])
        raw = t[p + 8:p + 12]
        if typ == 3:
            val = struct.unpack(e + 'H', raw[:2])[0]
        elif typ == 4:
            val = struct.unpack(e + 'I', raw)[0]
        else:
            val = None
        out[tag] = val
    return out, n


def main():
    root = sys.argv[1]
    for dp, _, fs in os.walk(root):
        for f in sorted(fs):
            if not f.lower().endswith(('.jpg', '.jpeg')):
                continue
            path = os.path.join(dp, f)
            rel = os.path.relpath(path, root).replace('\\', '/')
            data = open(path, 'rb').read()
            app1, orient, dims, size = 0, '-', '-', '-'
            for m, body in segments(data):
                if 0xC0 <= m <= 0xCF and m not in (0xC4, 0xC8, 0xCC) and len(body) >= 5:
                    h, w = struct.unpack('>HH', body[1:5])
                    size = '%dx%d' % (w, h)
                if m == 0xE1 and body[:6] == b'Exif\0\0' and not app1:
                    app1 = 1
                    t = body[6:]
                    e = '<' if t[:2] == b'II' else '>'
                    try:
                        ifd0, _ = ifd_entries(t, struct.unpack(e + 'I', t[4:8])[0], e)
                        if 274 in ifd0 and ifd0[274] is not None:
                            orient = str(ifd0[274])
                        if 0x8769 in ifd0 and ifd0[0x8769]:
                            sub, _ = ifd_entries(t, ifd0[0x8769], e)
                            if sub.get(40962) is not None and sub.get(40963) is not None:
                                dims = '%dx%d' % (sub[40962], sub[40963])
                    except struct.error:
                        pass
            print('%s|app1=%d|orient=%s|dims=%s|size=%s' % (rel, app1, orient, dims, size))


if __name__ == '__main__':
    main()
