# Feature 135: what does EXIF.DLL's EXIFReplaceThumbnail do to the Exif block of REAL camera files?
# Usage: python -I exif_real_measure.py <exif.dll> <folder with *.jpg (searched recursively)> <work folder> [result file]
#        (<work folder>/thumb.jpg must exist - see main)
# For every file: the call's result; then the Exif block (first APP1 "Exif") of the original and
# of the written file is walked with this script's own TIFF reader (not the library under test):
#   IFD0, Exif IFD, GPS IFD, Interop IFD - every entry by tag: type, count and value bytes;
#   the MakerNote: its bytes and its offset from the TIFF header (makers whose block holds
#   offsets from the TIFF header break when the block moves);
#   IFD1 (the thumbnail and its tags) is expected to change and is left out.
# Also: does everything outside the Exif block obey the rule of feature 132 (re-implemented
# here in a few lines).
import ctypes
import io
import os
import struct
import sys

TYPE_SIZE = {1: 1, 2: 1, 3: 2, 4: 4, 5: 8, 6: 1, 7: 1, 8: 2, 9: 4, 10: 8, 11: 4, 12: 8, 13: 4}


def exif_block(data):
    """(tiff bytes, offset in the file) of the first Exif APP1 before SOS, or (None, -1)"""
    o = 2
    while o + 4 <= len(data) and data[o] == 0xFF:
        while o + 1 < len(data) and data[o + 1] == 0xFF:
            o += 1
        m = data[o + 1]
        if m == 0xDA:
            break
        ln = struct.unpack('>H', data[o + 2:o + 4])[0]
        if m == 0xE1 and data[o + 4:o + 10] == b'Exif\x00\x00':
            return data[o + 10:o + 2 + ln], o + 10
        o += 2 + ln
    return None, -1


def read_ifd(t, off, e, out, name, seen):
    """entries of the IFD at 'off' into out[name][tag] = (type, count, value bytes, value offset or -1)"""
    if off in seen or off + 2 > len(t):
        return 0
    seen.add(off)
    n = struct.unpack(e + 'H', t[off:off + 2])[0]
    d = out.setdefault(name, {})
    for i in range(n):
        p = off + 2 + 12 * i
        if p + 12 > len(t):
            d['<cut>'] = (0, 0, b'', -1)
            break
        tag, typ, cnt = struct.unpack(e + 'HHI', t[p:p + 8])
        size = TYPE_SIZE.get(typ, 1) * cnt
        if size <= 4:
            val, voff = t[p + 8:p + 8 + size], -1
        else:
            voff = struct.unpack(e + 'I', t[p + 8:p + 12])[0]
            val = t[voff:voff + size] if voff + size <= len(t) else b'<outside>'
        d[tag] = (typ, cnt, val, voff)
        sub = {0x8769: 'Exif', 0x8825: 'GPS', 0xA005: 'Interop'}.get(tag)
        if sub and typ in (4, 13) and cnt == 1:
            read_ifd(t, struct.unpack(e + 'I', t[p + 8:p + 12])[0], e, out, sub, seen)
    nxt = off + 2 + 12 * n
    return struct.unpack(e + 'I', t[nxt:nxt + 4])[0] if nxt + 4 <= len(t) else 0


def walk(t):
    if t is None or len(t) < 8 or t[:2] not in (b'II', b'MM'):
        return None
    e = '<' if t[:2] == b'II' else '>'
    out = {}
    seen = set()
    first = struct.unpack(e + 'I', t[4:8])[0]
    nxt = read_ifd(t, first, e, out, 'IFD0', seen)
    if nxt:
        read_ifd(t, nxt, e, out, 'IFD1', seen)
    return out


POINTERS = {0x8769, 0x8825, 0xA005}  # their values are offsets, they may change


def compare(a, b):
    """list of differences outside IFD1"""
    diffs = []
    for ifd in ('IFD0', 'Exif', 'GPS', 'Interop'):
        ea, eb = a.get(ifd), b.get(ifd)
        if ea is None and eb is None:
            continue
        if ea is None or eb is None:
            diffs.append('%s %s' % (ifd, 'ADDED' if ea is None else 'LOST'))
            continue
        for tag in sorted(set(ea) | set(eb), key=str):
            if tag in POINTERS:
                if (tag in ea) != (tag in eb):
                    diffs.append('%s pointer %04X %s' % (ifd, tag, 'added' if tag in eb else 'lost'))
                continue
            if tag not in eb:
                diffs.append('%s tag %s LOST' % (ifd, ('%04X' % tag) if isinstance(tag, int) else tag))
            elif tag not in ea:
                diffs.append('%s tag %04X added' % (ifd, tag))
            else:
                ta, ca, va, oa = ea[tag]
                tb, cb, vb, ob = eb[tag]
                if (ta, ca, va) != (tb, cb, vb):
                    diffs.append('%s tag %04X CHANGED (type %d/%d count %d/%d)' % (ifd, tag, ta, tb, ca, cb))
                elif tag == 0x927C and oa != ob:
                    diffs.append('MakerNote MOVED %d -> %d' % (oa, ob))
    return diffs


def rule132(orig, new):
    """the rule of feature 132, in short: segments other than Exif APP1 / JFXX APP0 and the tail from SOS are the same"""
    def split(d):
        segs = []
        o = 2
        while o + 4 <= len(d) and d[o] == 0xFF:
            while o + 1 < len(d) and d[o + 1] == 0xFF:
                o += 1
            m = d[o + 1]
            if m == 0xDA:
                return segs, d[o:]
            ln = struct.unpack('>H', d[o + 2:o + 4])[0]
            p = d[o + 4:o + 2 + ln]
            if not ((m == 0xE1 and p[:6] == b'Exif\x00\x00') or (m == 0xE0 and p[:5] == b'JFXX\x00')):
                segs.append((m, p))
            o += 2 + ln
        return None, None
    sa, ta = split(orig)
    sb, tb = split(new)
    return sa is not None and sb is not None and sa == sb and ta == tb


def main():
    dll_path, src_root, work = sys.argv[1], sys.argv[2], sys.argv[3]
    out_path = sys.argv[4] if len(sys.argv) > 4 else None
    os.makedirs(work, exist_ok=True)
    dll = ctypes.WinDLL(os.path.abspath(dll_path))
    fn = dll.EXIFReplaceThumbnail
    fn.argtypes = [ctypes.c_char_p, ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int]
    fn.restype = ctypes.c_int
    # the new thumbnail: <work>/thumb.jpg (any small JPEG; made once with
    # python -c "from PIL import Image; Image.effect_noise((160,120),60).convert('RGB').save(r'<work>/thumb.jpg','JPEG',quality=80)"
    # - this script itself runs in isolated mode and imports nothing outside the standard library)
    thumb = open(os.path.join(work, 'thumb.jpg'), 'rb').read()

    files = []
    for base, _, names in os.walk(src_root):
        for n in sorted(names):
            if n.lower().endswith(('.jpg', '.jpeg')):
                files.append(os.path.join(base, n))
    files.sort()
    lines = ['exif.dll: ' + dll_path, 'files: %d; thumbnail %d bytes' % (len(files), len(thumb)), '']
    count = {'same': 0, 'refused': 0, 'DIFFERENT': 0, 'no Exif (JFXX)': 0, 'RULE132': 0}
    for i, f in enumerate(files):
        rel = os.path.relpath(f, src_root).replace(os.sep, '/')
        data = open(f, 'rb').read()
        src = os.path.join(work, 'in_%03d.jpg' % i)   # ASCII names for the ANSI interface
        dst = os.path.join(work, 'out_%03d.jpg' % i)
        open(src, 'wb').write(data)
        if os.path.exists(dst):
            os.remove(dst)
        ret = fn(src.encode('mbcs'), dst.encode('mbcs'), thumb, len(thumb))
        new = open(dst, 'rb').read() if os.path.exists(dst) else None
        ta, _ = exif_block(data)
        wa = walk(ta)
        if not ret or new is None:
            count['refused'] += 1
            lines.append('%-46s refused%s' % (rel, ' (BUT LEFT A FILE)' if new is not None else ''))
            continue
        notes = []
        if not rule132(data, new):
            count['RULE132'] += 1
            notes.append('OUTSIDE THE EXIF BLOCK: the rule of 132 does not hold')
        tb2, _ = exif_block(new)
        wb = walk(tb2)
        if wa is None:
            count['no Exif (JFXX)'] += 1
            lines.append('%-46s updated, the original has no readable Exif block%s' % (rel, ('; ' + '; '.join(notes)) if notes else ''))
            continue
        if wb is None:
            count['DIFFERENT'] += 1
            lines.append('%-46s DIFFERENT: the written file has no readable Exif block' % rel)
            continue
        diffs = compare(wa, wb)
        i1 = wb.get('IFD1', {})
        off = struct.unpack(('<' if tb2[:2] == b'II' else '>') + 'I', i1[0x0201][2])[0] if 0x0201 in i1 and len(i1[0x0201][2]) == 4 else -1
        if off < 0 or tb2[off:off + len(thumb)] != thumb or 0x0202 not in i1:
            diffs.append('THE NEW THUMBNAIL IS NOT WHERE IFD1 SAYS')
        if len(tb2) + 6 > 65533:
            diffs.append('THE BLOCK DOES NOT FIT A SEGMENT')
        maker = wa.get('IFD0', {}).get(0x010F, (0, 0, b'', 0))[2].split(b'\x00')[0].decode('latin-1', 'replace').strip()
        mn = wa.get('Exif', {}).get(0x927C)
        info = '%s; MakerNote %s; Exif block %d -> %d bytes' % (maker or '?', ('%d bytes' % len(mn[2])) if mn else 'none', len(ta), len(tb2))
        if diffs or notes:
            count['DIFFERENT'] += 1
            lines.append('%-46s DIFFERENT (%s): %s' % (rel, info, '; '.join(notes + diffs[:8]) + (' ... +%d' % (len(diffs) - 8) if len(diffs) > 8 else '')))
        else:
            count['same'] += 1
            lines.append('%-46s same (%s)' % (rel, info))
    lines.append('')
    lines.append('summary: ' + ', '.join('%s %d' % kv for kv in count.items()))
    text = '\n'.join(lines)
    print(text.encode('ascii', 'backslashreplace').decode())
    if out_path:
        open(out_path, 'w', encoding='utf-8', newline='\n').write(text + '\n')


if __name__ == '__main__':
    main()
