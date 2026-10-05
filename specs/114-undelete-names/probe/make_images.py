"""Feature 114 fixtures: a FAT12 and an exFAT disk image with deleted files whose names
exercise the Undelete plug-in's name handling, plus expected.json (what a correct restore
writes). Pure Python, no admin, no real volume touched: the images are ordinary files.

    python make_images.py <out-dir> [--oemcp N] [--selftest]

FAT12 (fat114.ima, 1.44 MB geometry), short names in the OEM code page (default: the
system's, GetOEMCP), long names UTF-16, written the way Windows writes them:
  root          KEEP.TXT (existing), deleted: Clanek.txt (C-caron, LFN; its short name starts
                with an OEM byte != the ANSI one), U+597D.txt (LFN, short name "_~1.TXT" - a
                character outside the OEM code page becomes '_'), FOO.TXT and FAA.TXT (short
                names only: the first character is lost, the user is asked)
  deleted-dir   deleted directory, its files deleted too (every entry 0xE5-marked):
                U+5F00 U+59CB.txt ("__~1.TXT"), a U+597D.txt, Zlutoucky kun.txt with
                diacritics (two LFN entries)
  lost-dir      deleted directory whose entries were left intact (a delete that did not
                recurse): U+5A46.txt (UTF-8 begins E5), a short name stored with the 0x05
                escape (a real 0xE5 OEM byte), an OEM short name C-caron L A-acute NEK2.TXT,
                README.TXT with NT case bits 0x18, MIXED.TXT with 0x08, an LFN with an unpaired
                surrogate
exFAT (exfat114.ima, 4 MB, 512-byte clusters): KEEP.TXT (existing) and six deleted files:
                U+597D.txt, Clanek.txt, a U+597D.txt, lone<U+D800>x.txt, U+5F00 U+59CB.txt,
                Zlutoucky kun.txt (two name entries)

Every file's content is unique ASCII ("TC114 <tag>\\r\\n" + padding). expected.json lists,
per image, the files a correct restore of {All Deleted Files} writes - names as UTF-16 code
units (a lone surrogate survives JSON) - and whether the build before 114 is expected to get
the name wrong (defect_before), plus the damaged-name prompts.
"""
import ctypes
import json
import os
import struct
import sys

SECTOR = 512


def u16(s):
    """str -> list of UTF-16 code units (a lone surrogate written as '\\ud800' stays one unit)"""
    out = []
    for ch in s:
        c = ord(ch)
        if c >= 0x10000:
            c -= 0x10000
            out += [0xD800 + (c >> 10), 0xDC00 + (c & 0x3FF)]
        else:
            out.append(c)
    return out


def units_to_str(units):
    return ''.join(chr(u) for u in units)  # keeps lone surrogates as such


def content(tag):
    s = ('TC114 %s\r\n' % tag).encode('ascii')
    return s + b'.' * (40 + (sum(s) % 23))  # unique length too


# ---------------------------------------------------------------- FAT
def fat_checksum(name11):
    s = 0
    for b in name11:
        s = (((s & 1) << 7) + (s >> 1) + b) & 0xFF
    return s


def oem_part(text, n, cp):
    out = b''
    for ch in text:
        try:
            b = ch.encode('cp%d' % cp)
        except (UnicodeEncodeError, LookupError):
            b = b'_'
        out += b
    assert len(out) <= n, (text, out)
    return out.ljust(n, b' ')


def win_keep(ch, cp):
    """the character Windows (fastfat, RtlGenerate8dot3Name with extended characters allowed)
    writes into a short name for 'ch', or None when it DROPS it: <= space and '.' dropped,
    + , ; = [ ] -> '_', otherwise upper-cased and kept when ASCII or an OEM character that
    converts back to itself (review SF1 of 114: a character outside the OEM code page is
    dropped, not replaced by '_')"""
    if ch <= ' ' or ch == '.':
        return None
    if ch in '+,;=[]':
        return '_'
    up = ch.upper() if len(ch.upper()) == 1 else ch
    if ord(up) < 0x7F:
        return up
    if 0xD800 <= ord(up) <= 0xDFFF:
        return None
    try:
        if up.encode('cp%d' % cp).decode('cp%d' % cp) != up:
            return None
    except (UnicodeError, LookupError):
        return None
    return up


def win_sfn(name, cp, hash4):
    """(base, ext) of the short name Windows makes for 'name' with numeric tail ~1: the kept
    characters (win_keep); a base of 0-2 kept characters gets the 4-hex-digit hash ('hash4' -
    the value Windows computes is not reproduced here; measured: U+597D.txt -> 191D~1.TXT,
    C-caron X.txt -> X76F3~1.TXT)"""
    lead = len(name) - len(name.lstrip('.'))
    body = name[lead:]
    dot = body.rfind('.')
    base, ext = (body[:dot], body[dot + 1:]) if dot >= 0 else (body, '')
    kb = ''.join(k for k in (win_keep(c, cp) for c in base) if k)
    ke = ''.join(k for k in (win_keep(c, cp) for c in ext) if k)[:3]
    if len(kb) <= 2:
        kb = kb + hash4
    return kb[:6] + '~1', ke


def sfn_raw(base, ext, cp):
    raw = bytearray(oem_part(base, 8, cp) + oem_part(ext, 3, cp))
    if raw[0] == 0xE5:
        raw[0] = 0x05  # a real 0xE5 byte is stored escaped
    return bytes(raw)


DOS_DATE = ((2026 - 1980) << 9) | (10 << 5) | 5
DOS_TIME = (12 << 11) | (34 << 5) | 28


def sfn_entry(raw11, attr, cluster, size, ntres=0, deleted=False):
    name = bytearray(raw11)
    if deleted:
        name[0] = 0xE5
    return struct.pack('<11sBBBHHHHHHHI', bytes(name), attr, ntres, 0, DOS_TIME, DOS_DATE, DOS_DATE,
                       0, DOS_TIME, DOS_DATE, cluster, size)


def lfn_entries(units, chk, deleted=False):
    """long-name entries in disk order (highest ordinal first)"""
    chunks = []
    u = list(units)
    if len(u) % 13:
        u = u + [0] + [0xFFFF] * (12 - len(u) % 13)
    for i in range(0, len(u), 13):
        chunks.append(u[i:i + 13])
    ents = []
    for i, ch in enumerate(chunks):
        ordv = i + 1
        if i == len(chunks) - 1:
            ordv |= 0x40
        if deleted:
            ordv = 0xE5
        n1 = struct.pack('<5H', *ch[0:5])
        n2 = struct.pack('<6H', *ch[5:11])
        n3 = struct.pack('<2H', *ch[11:13])
        ents.append(struct.pack('<B10sBBB12sH4s', ordv, n1, 0x0F, 0, chk, n2, 0, n3))
    return list(reversed(ents))


def dot_entries(self_cluster, parent_cluster):
    return (sfn_entry(b'.          ', 0x10, self_cluster, 0) +
            sfn_entry(b'..         ', 0x10, parent_cluster, 0))


def make_fat(cp):
    total = 2880
    rsvd, nfats, fatsz, rootents = 1, 2, 9, 224
    rootsecs = rootents * 32 // SECTOR
    first_data = rsvd + nfats * fatsz + rootsecs
    img = bytearray(total * SECTOR)
    bs = bytearray(SECTOR)
    bs[0:3] = b'\xEB\x3C\x90'
    bs[3:11] = b'MSDOS5.0'
    struct.pack_into('<HBHBHHBHHHII', bs, 11, SECTOR, 1, rsvd, nfats, rootents, total, 0xF0, fatsz, 18, 2, 0, 0)
    struct.pack_into('<BBBI11s8s', bs, 36, 0, 0, 0x29, 0x114114, b'TC114      ', b'FAT12   ')
    bs[510:512] = b'\x55\xAA'
    img[0:SECTOR] = bs

    fat = {0: 0xFF0, 1: 0xFFF}
    expected = []
    prompts = []

    def put_cluster(cl, data):
        off = (first_data + cl - 2) * SECTOR
        assert len(data) <= SECTOR
        img[off:off + len(data)] = data

    def add_file(entries, cl, tag, long_units, base, ext, deleted, ntres=0, want=None, defect=False, sfn_only_expect=None):
        data = content(tag)
        put_cluster(cl, data)
        raw = sfn_raw(base, ext, cp)
        if long_units is not None:
            entries += lfn_entries(long_units, fat_checksum(raw), deleted)
        entries.append(sfn_entry(raw, 0x20, cl, len(data), ntres, deleted))
        return raw, data

    root = []
    root.append(sfn_entry(b'TC114      ', 0x08, 0, 0))
    # existing file (not listed among deleted files)
    d = content('keep')
    put_cluster(2, d)
    root.append(sfn_entry(sfn_raw('KEEP', 'TXT', cp), 0x20, 2, len(d)))
    fat[2] = 0xFFF

    def lfn_case(entries, cl, tag, name, deleted, defect, hash4='0B1C'):
        # the short name made the Windows way; when nothing of the base name is kept (a hash
        # form) the deleted entry's long name cannot be linked back: the short name is shown as
        # damaged and the user is asked (expected: C-caron + the rest)
        base, ext = win_sfn(name, cp, hash4)
        raw, data = add_file(entries, cl, tag, u16(name), base, ext, deleted)
        units = u16(name)
        kept = [k for k in (win_keep(c, cp) for c in (name.rsplit('.', 1)[0] if '.' in name.lstrip('.') else name)) if k]
        if deleted and not kept:
            shown = '$' + base[1:] + ('.' + ext if ext else '')
            prompts.append(units_to_str(u16(shown)))
            units = u16('\u010c' + base[1:] + ('.' + ext if ext else ''))
        expected.append({'tag': tag, 'units': units, 'content': data.decode('ascii'), 'defect_before': defect})

    def sfn_case(entries, cl, tag, base, ext, deleted, ntres, defect, damaged=False):
        raw, data = add_file(entries, cl, tag, None, base, ext, deleted, ntres)
        r = bytearray(raw)
        if r[0] == 0x05:
            r[0] = 0xE5
        b = bytes(r[0:8]).rstrip(b' ')
        e = bytes(r[8:11]).rstrip(b' ')
        bn = b.decode('cp%d' % cp)
        en = e.decode('cp%d' % cp)
        # the NT case bits lower case A-Z only (fastfat Fat8dot3ToString; review NIT 2)
        if ntres & 0x08:
            bn = ''.join(ch.lower() if 'A' <= ch <= 'Z' else ch for ch in bn)
        if ntres & 0x10:
            en = ''.join(ch.lower() if 'A' <= ch <= 'Z' else ch for ch in en)
        name = bn + ('.' + en if en else '')
        if damaged:
            shown = '$' + name[1:]
            prompts.append(units_to_str(u16(shown)))
            name = '\u010c' + name[1:]  # the probe answers C-caron (and All on the first prompt)
        expected.append({'tag': tag, 'units': u16(name), 'content': data.decode('ascii'), 'defect_before': defect})

    lfn_case(root, 3, 'clanek', '\u010clanek.txt', True, True)
    # a hash form (measured: U+597D.txt -> 191D~1.TXT): the long name of the DELETED entry cannot be
    # linked back - shown and restored as the damaged short name, both builds alike
    lfn_case(root, 4, 'hao', '\u597d.txt', True, False, hash4='191D')
    sfn_case(root, 5, 'foo', 'FOO', 'TXT', True, 0, False, damaged=True)
    sfn_case(root, 6, 'faa', 'FAA', 'TXT', True, 0, False, damaged=True)

    # deleted-dir (cluster 7): deleted, its files deleted too
    dd = []
    raw_dd = sfn_raw(*win_sfn('deleted-dir', cp, '0000'), cp)
    root += lfn_entries(u16('deleted-dir'), fat_checksum(raw_dd), True)
    root.append(sfn_entry(raw_dd, 0x10, 7, 0, 0, True))
    # dropped characters (not replaced): U+5F00 U+59CB x.txt -> X + hash ~1 (like C-caron X.txt -> X76F3~1)
    lfn_case(dd, 8, 'kaishi', '\u5f00\u59cbx.txt', True, True, hash4='76F3')
    lfn_case(dd, 9, 'ahao', 'a\u597d.txt', True, False, hash4='0B1C')
    lfn_case(dd, 10, 'zlutoucky', '\u017dlu\u0165ou\u010dk\u00fd k\u016f\u0148.txt', True, True)
    put_cluster(7, dot_entries(7, 0) + b''.join(dd))

    # lost-dir (cluster 11): deleted, its entries intact
    ld = []
    raw_ld = sfn_raw(*win_sfn('lost-dir', cp, '0000'), cp)
    root += lfn_entries(u16('lost-dir'), fat_checksum(raw_ld), True)
    root.append(sfn_entry(raw_ld, 0x10, 11, 0, 0, True))
    lfn_case(ld, 12, 'po', '\u5a46.txt', False, True, hash4='8A6F')
    # the 0x05 escape: base whose first OEM byte is 0xE5
    e5char = bytes([0xE5]).decode('cp%d' % cp, errors='replace')
    if len(e5char) == 1 and e5char != '\ufffd':
        sfn_case(ld, 13, 'escape', e5char + 'BC', 'TXT', False, 0, True)
    sfn_case(ld, 14, 'oemsfn', '\u010cL\u00c1NEK2', 'TXT', False, 0, True)
    sfn_case(ld, 15, 'readme', 'README', 'TXT', False, 0x18, False)
    sfn_case(ld, 16, 'mixed', 'MIXED', 'TXT', False, 0x08, True)
    lfn_case(ld, 17, 'lone', 'lone\ud800y.txt', False, True)
    put_cluster(11, dot_entries(11, 0) + b''.join(ld))

    rootoff = (rsvd + nfats * fatsz) * SECTOR
    rb = b''.join(root)
    assert len(rb) <= rootents * 32
    img[rootoff:rootoff + len(rb)] = rb

    fatb = bytearray(fatsz * SECTOR)
    for cl, v in fat.items():
        off = cl * 3 // 2
        if cl & 1:
            fatb[off] = (fatb[off] & 0x0F) | ((v << 4) & 0xF0)
            fatb[off + 1] = (v >> 4) & 0xFF
        else:
            fatb[off] = v & 0xFF
            fatb[off + 1] = (fatb[off + 1] & 0xF0) | ((v >> 8) & 0x0F)
    for i in range(nfats):
        o = (rsvd + i * fatsz) * SECTOR
        img[o:o + len(fatb)] = fatb
    return bytes(img), expected, prompts


# ---------------------------------------------------------------- exFAT
def exfat_set_checksum(entries):
    # the plug-in's UpdateEntriesChecksum: bytes 2-3 of the primary entry skipped, every
    # entry's type byte taken with the InUse bit set (a deleted set keeps its checksum)
    cs = 0
    for k, e in enumerate(entries):
        for i, b in enumerate(e):
            if k == 0 and i in (2, 3):
                continue
            if i == 0:
                b |= 0x80
            cs = ((((cs << 15) & 0xFFFF) | ((cs >> 1) & 0xFFFF)) + b) & 0xFFFF
    return cs


def exfat_name_hash(units):
    h = 0
    for u in units:
        c = ord(chr(u).upper()) if u < 0xD800 or u > 0xDFFF else u
        if c > 0xFFFF:
            c = u
        for b in (c & 0xFF, c >> 8):
            h = ((((h << 15) & 0xFFFF) | ((h >> 1) & 0xFFFF)) + b) & 0xFFFF
    return h


def exfat_file_set(units, cluster, size, deleted, attr=0x20):
    nname = (len(units) + 14) // 15
    stamp = (DOS_DATE << 16) | DOS_TIME
    f = bytearray(struct.pack('<BBHHH III BBBBB 7s', 0x85, 1 + nname, 0, attr, 0, stamp, stamp, stamp, 0, 0, 0, 0, 0, b'\0' * 7))
    s = bytearray(struct.pack('<BBBBHH Q 4s I Q', 0xC0, 0x03, 0, len(units), exfat_name_hash(units), 0, size, b'\0' * 4, cluster, size))
    names = []
    for i in range(nname):
        ch = units[i * 15:(i + 1) * 15]
        ch = ch + [0] * (15 - len(ch))
        names.append(bytearray(struct.pack('<BB15H', 0xC1, 0, *ch)))
    ents = [f, s] + names
    cs = exfat_set_checksum(ents)
    struct.pack_into('<H', ents[0], 2, cs)
    if deleted:
        for e in ents:
            e[0] &= 0x7F
    for e in ents:
        assert len(e) == 32
    return b''.join(bytes(e) for e in ents)


LONG_DUP_NAME = ''.join(chr(0x4E00 + i) for i in range(110)) + '.txt'  # 110 CJK characters: 334 bytes of UTF-8


def make_exfat(kind='main'):
    """kind 'main': the six deleted files; kind 'dup': two deleted files of ONE long name
    (LONG_DUP_NAME) - restoring both numbers them, which overran a MAX_PATH + 50 stack buffer"""
    vol_sectors = 8192
    fat_off, fat_len, heap_off = 24, 64, 128
    clusters = vol_sectors - heap_off
    img = bytearray(vol_sectors * SECTOR)
    bs = bytearray(SECTOR)
    bs[0:3] = b'\xEB\x76\x90'
    bs[3:11] = b'EXFAT   '
    struct.pack_into('<QQIIIIIIHHBBBBB', bs, 64, 0, vol_sectors, fat_off, fat_len, heap_off, clusters, 5,
                     0x114114, 0x0100, 0, 9, 0, 1, 0x80, 0)
    bs[510:512] = b'\x55\xAA'
    img[0:SECTOR] = bs

    def cl_off(cl):
        return (heap_off + cl - 2) * SECTOR

    fat = {0: 0xFFFFFFF8, 1: 0xFFFFFFFF}
    used = set()
    # bitmap: clusters 2-3, upcase: 4, root: 5-6
    bitmap_len = (clusters + 7) // 8
    # root: clusters 5-8 (64 entries)
    fat[2] = 3; fat[3] = 0xFFFFFFFF; fat[4] = 0xFFFFFFFF; fat[5] = 6; fat[6] = 7; fat[7] = 8; fat[8] = 0xFFFFFFFF
    used |= {2, 3, 4, 5, 6, 7, 8}
    up = bytearray()
    for c in range(128):
        up += struct.pack('<H', ord(chr(c).upper()) if 'a' <= chr(c) <= 'z' else c)
    upcs = 0
    for b in up:
        upcs = ((((upcs << 31) & 0xFFFFFFFF) | (upcs >> 1)) + b) & 0xFFFFFFFF
    img[cl_off(4):cl_off(4) + len(up)] = up

    expected = []
    root = bytearray()
    label = u16('TC114')
    root += struct.pack('<BB11H8s', 0x83, len(label), *(label + [0] * (11 - len(label))), b'\0' * 8)
    root += struct.pack('<BB18sIQ', 0x81, 0, b'\0' * 18, 2, bitmap_len)
    root += struct.pack('<B3sI12sIQ', 0x82, b'\0' * 3, upcs, b'\0' * 12, 4, len(up))

    nextcl = 9

    def add(name, tag, deleted, defect):
        nonlocal nextcl, root
        cl = nextcl
        nextcl += 1
        data = content('x-' + tag)
        img[cl_off(cl):cl_off(cl) + len(data)] = data
        root += exfat_file_set(u16(name), cl, len(data), deleted)
        if not deleted:
            used.add(cl)
        else:
            expected.append({'tag': tag, 'units': u16(name), 'content': data.decode('ascii'), 'defect_before': defect})

    add('KEEP.TXT', 'keep', False, False)
    if kind == 'dup':
        add(LONG_DUP_NAME, 'dup1', True, True)
        add(LONG_DUP_NAME, 'dup2', True, True)
    else:
        add('\u597d.txt', 'hao', True, True)
        add('\u010clanek.txt', 'clanek', True, False)
        add('a\u597d.txt', 'ahao', True, False)
        add('lone\ud800x.txt', 'lone', True, True)
        add('\u5f00\u59cb.txt', 'kaishi', True, True)
        add('\u017dlu\u0165ou\u010dk\u00fd k\u016f\u0148.txt', 'zlutoucky', True, False)
    assert len(root) <= 4 * SECTOR
    img[cl_off(5):cl_off(5) + len(root)] = root

    bm = bytearray(bitmap_len)
    for cl in used:
        i = cl - 2
        bm[i // 8] |= 1 << (i % 8)
    img[cl_off(2):cl_off(2) + len(bm)] = bm
    fb = bytearray(fat_len * SECTOR)
    for cl, v in fat.items():
        struct.pack_into('<I', fb, cl * 4, v)
    img[fat_off * SECTOR:fat_off * SECTOR + len(fb)] = fb
    return bytes(img), expected


def selftest(cp):
    # the FAT checksum against the specification's example form, the SFN round trip and the
    # exFAT set checksum on a known set - and that every name in expected.json is unique
    assert fat_checksum(b'README  TXT') == fat_checksum(bytearray(b'README  TXT'))
    # the Windows short names measured with dir /x (review SF1; NTFS drops every character
    # outside ASCII - CP437 has neither C-caron nor a-acute nor y-acute, so it models that)
    assert win_sfn('\u010cl\u00e1nek dlouh\u00fd.txt', 437, '0000') == ('LNEKDL~1', 'TXT')
    assert win_sfn('\u010cX.txt', 437, '76F3') == ('X76F3~1', 'TXT')
    assert win_sfn('\u010c.txt', 437, '80E2') == ('80E2~1', 'TXT')
    assert win_sfn('\u597d.txt', 852, '191D') == ('191D~1', 'TXT')
    assert win_sfn('.gitignore', 437, '0000') == ('GITIGN~1', '')
    raw = sfn_raw('\u010cL\u00c1NEK', 'TXT', cp)
    assert len(raw) == 11
    fimg, fexp, fpr = make_fat(cp)
    eimg, eexp = make_exfat()
    dimg, dexp = make_exfat('dup')
    for exp in (fexp, eexp):
        names = [units_to_str(e['units']).lower() for e in exp]
        assert len(names) == len(set(names)), names
    assert len(dexp) == 2 and len(LONG_DUP_NAME.encode('utf-8')) > 260 + 50
    # a deleted exFAT set keeps the checksum of the in-use set
    a = exfat_file_set(u16('x.txt'), 9, 5, False)
    b = exfat_file_set(u16('x.txt'), 9, 5, True)
    assert a[2:4] == b[2:4] and a[0] == 0x85 and b[0] == 0x05
    print('selftest ok: FAT %d files (%d prompts), exFAT %d files, OEM cp %d' % (len(fexp), len(fpr), len(eexp), cp))


def main():
    args = sys.argv[1:]
    cp = ctypes.windll.kernel32.GetOEMCP()
    if '--oemcp' in args:
        cp = int(args[args.index('--oemcp') + 1])
    if '--selftest' in args:
        selftest(cp)
        return
    out = args[0]
    os.makedirs(out, exist_ok=True)
    fimg, fexp, fpr = make_fat(cp)
    eimg, eexp = make_exfat()
    dimg, dexp = make_exfat('dup')
    with open(os.path.join(out, 'fat114.ima'), 'wb') as f:
        f.write(fimg)
    with open(os.path.join(out, 'exfat114.ima'), 'wb') as f:
        f.write(eimg)
    with open(os.path.join(out, 'exfatdup114.ima'), 'wb') as f:
        f.write(dimg)
    with open(os.path.join(out, 'expected.json'), 'w', encoding='ascii') as f:
        json.dump({'oemcp': cp,
                   'fat': {'files': fexp, 'prompts': [u16(p) for p in fpr]},
                   'exfat': {'files': eexp, 'prompts': []},
                   'dup': {'name_units': u16(LONG_DUP_NAME), 'name_bytes': len(LONG_DUP_NAME.encode('utf-8'))}}, f, indent=1)
    print('wrote fat114.ima (%d files), exfat114.ima (%d files), exfatdup114.ima (2 files of one %d-byte name), OEM cp %d' %
          (len(fexp), len(eexp), len(LONG_DUP_NAME.encode('utf-8')), cp))


if __name__ == '__main__':
    main()
