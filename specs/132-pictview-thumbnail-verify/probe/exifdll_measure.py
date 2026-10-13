# Feature 132: what does EXIF.DLL's EXIFReplaceThumbnail write for JPEG files of several shapes?
# Usage: python exifdll_measure.py <path of exif.dll> <work folder> [result file]
# For every case: the call's result, the size of the written file, whether the picture still
# decodes to the same pixels, and whether the parts that must survive (XMP, trailing data) did.
import ctypes
import io
import os
import struct
import sys

from PIL import Image


def make_jpeg(progressive=False, exif=None, size=(640, 480)):
    im = Image.new('RGB', size)
    px = im.load()
    for y in range(size[1]):
        for x in range(size[0]):
            px[x, y] = ((x * 7) & 255, (y * 5) & 255, ((x + y) * 3) & 255)
    b = io.BytesIO()
    kw = {'quality': 85, 'progressive': progressive}
    if exif is not None:
        kw['exif'] = exif
    im.save(b, 'JPEG', **kw)
    return b.getvalue()


def segments(data):
    """[(marker, start, end)] of the segments before the first SOS; end of the list = SOS offset."""
    out = []
    o = 2
    while o + 4 <= len(data):
        if data[o] != 0xFF:
            break
        m = data[o + 1]
        if m == 0xDA:
            break
        ln = struct.unpack('>H', data[o + 2:o + 4])[0]
        out.append((m, o, o + 2 + ln))
        o += 2 + ln
    return out, o


def insert_after(data, marker_after, blob):
    """Insert 'blob' behind the last segment with marker 'marker_after' (or behind SOI)."""
    segs, _ = segments(data)
    pos = 2
    for m, s, e in segs:
        if m == marker_after:
            pos = e
    return data[:pos] + blob + data[pos:]


def seg(marker, payload):
    return bytes([0xFF, marker]) + struct.pack('>H', len(payload) + 2) + payload


XMP = b'http://ns.adobe.com/xap/1.0/\x00<x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF>TC132-XMP-MARK</rdf:RDF></x:xmpmeta>'
TRAIL = b'TC132-TRAILER-' + bytes(range(256)) * 8


def exif_bytes(comment_len=0):
    ex = Image.Exif()
    ex[0x010F] = 'TandemTest'  # Make
    ex[0x0110] = 'Model 132'
    if comment_len:
        ex[0x010E] = 'D' * comment_len  # ImageDescription
    return ex.tobytes()


def build_cases():
    plain = make_jpeg()
    with_exif = make_jpeg(exif=exif_bytes())
    c = {}
    c['CTRL_PLAIN'] = plain
    c['CTRL_PROGRESSIVE'] = make_jpeg(progressive=True)
    c['CTRL_EXIF'] = with_exif
    # the usual shape of a file from a camera application: Exif APP1, then XMP APP1
    c['EXIF_THEN_XMP'] = insert_after(with_exif, 0xE1, seg(0xE1, XMP))
    c['XMP_THEN_EXIF'] = plain[:2] + seg(0xE1, XMP) + with_exif[2:]
    c['XMP_ONLY'] = insert_after(plain, 0xE0, seg(0xE1, XMP))
    # fill bytes before a marker are allowed by the standard (any number of 0xFF)
    segs, _ = segments(plain)
    dqt = [s for m, s, e in segs if m == 0xDB][0]
    c['FILL_8'] = plain[:dqt] + b'\xFF' * 8 + plain[dqt:]
    c['FILL_3'] = plain[:dqt] + b'\xFF' * 3 + plain[dqt:]
    # Exif near the 64 KB limit of a segment: with the new thumbnail it no longer fits
    c['EXIF_BIG'] = make_jpeg(exif=exif_bytes(60000))
    # data behind the end of the picture (motion photos, depth maps)
    c['TRAILER'] = plain + TRAIL
    c['TRAILER_FF00'] = plain + TRAIL + b'\xFF\x00'
    c['TRAILER_EXIF'] = with_exif + TRAIL
    # a file cut inside the picture data (decoders show the upper part)
    c['CUT_IN_SCAN'] = plain[:len(plain) * 2 // 3]
    return c


def pixels(data):
    try:
        im = Image.open(io.BytesIO(data))
        im.load()
        return im.size, im.tobytes()
    except Exception as e:  # noqa
        return None, None


def main():
    dll_path, work = sys.argv[1], sys.argv[2]
    out_path = sys.argv[3] if len(sys.argv) > 3 else None
    os.makedirs(work, exist_ok=True)
    dll = ctypes.WinDLL(dll_path)
    fn = dll.EXIFReplaceThumbnail
    fn.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
    fn.restype = ctypes.c_int

    tb = io.BytesIO()
    Image.new('RGB', (160, 120), (200, 30, 30)).save(tb, 'JPEG', quality=95)
    thumb = tb.getvalue()
    # a busier thumbnail of the same size is larger (the plug-in's own thumbnails are 4-12 KB)
    tn = Image.effect_noise((160, 120), 90).convert('RGB')
    tb = io.BytesIO()
    tn.save(tb, 'JPEG', quality=95)
    thumb_big = tb.getvalue()

    lines = ['exif.dll: ' + dll_path, 'thumbnail: %d bytes, large thumbnail: %d bytes' % (len(thumb), len(thumb_big)), '']
    bad = 0
    for name, data in build_cases().items():
        src = os.path.join(work, name + '.jpg')
        dst = os.path.join(work, name + '.new.jpg')
        open(src, 'wb').write(data)
        if os.path.exists(dst):
            os.remove(dst)
        t = thumb_big if name == 'EXIF_BIG' else thumb
        ret = fn(src.encode('mbcs'), dst.encode('mbcs'), t, len(t))
        new = open(dst, 'rb').read() if os.path.exists(dst) else None
        osize, opix = pixels(data)
        verdict = []
        if not ret:
            verdict.append('refused (returned 0)')
            if new is not None:
                verdict.append('BUT LEFT A FILE of %d bytes' % len(new))
        else:
            nsize, npix = pixels(new)
            if opix is None:
                # the original itself does not decode whole: its data must be there unchanged
                tail = data[data.index(bytes([0xFF, 0xDA])):]
                verdict.append('ok (cut original: its data are kept)' if new.endswith(tail)
                               else 'LOSS: the picture data of the cut original changed')
            elif npix is None:
                verdict.append('LOSS: the written file does not decode')
            elif opix is not None and (nsize != osize or npix != opix):
                verdict.append('LOSS: the written file decodes to another picture')
            if (b'TC132-XMP-MARK' in data) and (b'TC132-XMP-MARK' not in new):
                verdict.append('LOSS: the XMP block is gone')
            if (b'TC132-TRAILER-' in data) and (TRAIL not in new):
                verdict.append('LOSS: the data behind the picture is gone or changed')
            if (b'TC132-TRAILER-' in data) and name == 'TRAILER_FF00' and not new.endswith(TRAIL + b'\xFF\x00'):
                verdict.append('LOSS: the last bytes of the file are gone')
            if b'TandemTest' in data and b'TandemTest' not in new:
                verdict.append('LOSS: the Exif tags are gone')
            if not verdict:
                verdict.append('ok')
        if any(v.startswith('LOSS') for v in verdict):
            bad += 1
        lines.append('%-18s ret=%d  original %7d bytes -> written %s bytes : %s' % (
            name, ret, len(data), ('%7d' % len(new)) if new is not None else '   none', '; '.join(verdict)))
    lines.append('')
    lines.append('cases with a loss reported as success: %d' % bad)
    text = '\n'.join(lines)
    print(text)
    if out_path:
        open(out_path, 'w', encoding='utf-8', newline='\n').write(text + '\n')


if __name__ == '__main__':
    main()
