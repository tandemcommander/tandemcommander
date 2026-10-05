"""Feature 115 fixtures: a FAT12 and an exFAT disk image whose deleted files exercise the Undelete
plug-in's duplicate handling, plus expected.json. Pure Python (standard library), no admin, no
real volume touched: the images are ordinary files. The writers of feature 114
(specs/114-undelete-names/probe/make_images.py) are reused.

    python make_images115.py <out-dir> [--oemcp N] [--selftest]

fatdup115.ima (FAT12, 1.44 MB):
  root        KEEP.TXT (existing); deleted C-caron.txt and c-caron.txt (one name for Windows -
              deleted one after the other); the deleted directories:
  old-dir     deleted, cluster 7, holding the deleted dupe.txt (60 bytes)
  moved-dir   deleted, ALSO cluster 7 (the directory moved, then deleted): the plug-in reads the
              cluster twice (LoadDeletedDirectories, on purpose) - {All Deleted Files} lists
              dupe.txt twice with the same data runs; RemoveDuplicateFiles must leave one
  t1, t2      deleted, clusters 9 / 11, each holding a deleted same.txt of 12 bytes with
              DIFFERENT content: two files, not duplicates (the old memcmp of 12 bytes of the
              44-byte DATA_POINTERS saw only StartVCN = LastVCN = 0 and removed one)
exfatnum115.ima (exFAT, 4 MB): KEEP.TXT (existing); deleted C-caron.txt, c-caron.txt (one name for
              Windows: the restore list must number them) and a.txt, A.txt (the ASCII control:
              numbered by both builds)

Every file's content is unique ASCII. expected.json describes groups of restored files of
{All Deleted Files}: 'one' (exactly this name and content), 'numbered' (the members as
"<stem> (k)<ext>", k = 1..n in any order, each with its own content), 'anyone' (exactly one of the
members under its plain name - what the build before writes after the overwrite prompt is
answered Skip); 'fixed' and 'before' say what each build is expected to write.
"""
import importlib.util
import json
import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    'make_images114', os.path.join(HERE, '..', '..', '114-undelete-names', 'probe', 'make_images.py'))
m114 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(m114)

SECTOR = 512
u16 = m114.u16

C_CARON = '\u010c'
c_CARON = '\u010d'


def content(tag, size=None):
    s = ('TC115 %s\r\n' % tag).encode('ascii')
    if size is not None:  # exactly 'size' bytes (the tiny files)
        s = ('TC115 %s' % tag).encode('ascii')
        assert len(s) <= size, (tag, size)
        return s + b'.' * (size - len(s))
    return s + b'.' * (44 + (sum(s) % 23))  # over 44 bytes: past the DATA_POINTERS structure


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
    struct.pack_into('<BBBI11s8s', bs, 36, 0, 0, 0x29, 0x115115, b'TC115      ', b'FAT12   ')
    bs[510:512] = b'\x55\xAA'
    img[0:SECTOR] = bs
    fat = {0: 0xFF0, 1: 0xFFF}
    data = {}

    def put_cluster(cl, b):
        off = (first_data + cl - 2) * SECTOR
        assert len(b) <= SECTOR
        img[off:off + len(b)] = b

    def lfn_file(entries, cl, name, b, deleted, hash4):
        put_cluster(cl, b)
        base, ext = m114.win_sfn(name, cp, hash4)
        raw = m114.sfn_raw(base, ext, cp)
        entries += m114.lfn_entries(u16(name), m114.fat_checksum(raw), deleted)
        entries.append(m114.sfn_entry(raw, 0x20, cl, len(b), 0, deleted))

    def lfn_dir(entries, cl, name, hash4):
        raw = m114.sfn_raw(*m114.win_sfn(name, cp, hash4), cp)
        entries += m114.lfn_entries(u16(name), m114.fat_checksum(raw), True)
        entries.append(m114.sfn_entry(raw, 0x10, cl, 0, 0, True))

    root = [m114.sfn_entry(b'TC115      ', 0x08, 0, 0)]
    keep = content('keep')
    put_cluster(2, keep)
    root.append(m114.sfn_entry(m114.sfn_raw('KEEP', 'TXT', cp), 0x20, 2, len(keep)))
    fat[2] = 0xFFF

    # one directory cluster (7) reached from two deleted directory entries
    data['dupe'] = content('dupe')
    dd = []
    lfn_file(dd, 8, 'dupe.txt', data['dupe'], True, '0000')
    put_cluster(7, m114.dot_entries(7, 0) + b''.join(dd))
    lfn_dir(root, 7, 'old-dir', '0000')
    lfn_dir(root, 7, 'moved-dir', '0000')

    # two different small files of one name in two deleted directories
    data['tiny1'] = content('tiny-1', 12)
    data['tiny2'] = content('tiny-2', 12)
    for dcl, fcl, tag, dname in ((9, 10, 'tiny1', 't1'), (11, 12, 'tiny2', 't2')):
        t = []
        lfn_file(t, fcl, 'same.txt', data[tag], True, '0000')
        put_cluster(dcl, m114.dot_entries(dcl, 0) + b''.join(t))
        lfn_dir(root, dcl, dname, '0000')

    # C-caron.txt and c-caron.txt deleted from the root (the short names get the hash form of
    # Windows for a 1-character base: the kept C-caron + 4 hex digits)
    data['Ccap'] = content('C-caron')
    data['csmall'] = content('c-caron')
    lfn_file(root, 13, C_CARON + '.txt', data['Ccap'], True, '1A2B')
    lfn_file(root, 14, c_CARON + '.txt', data['csmall'], True, '3C4D')

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

    a = lambda x: x.decode('ascii')
    groups = [
        {'tag': 'dupe', 'members': [{'stem': 'dupe', 'ext': '.txt', 'content': a(data['dupe'])}],
         'fixed': 'one', 'before': 'twice',
         'why': 'one file read twice (two deleted directory entries of one cluster): one copy'},
        {'tag': 'tiny', 'members': [{'stem': 'same', 'ext': '.txt', 'content': a(data['tiny1'])},
                                    {'stem': 'same', 'ext': '.txt', 'content': a(data['tiny2'])}],
         'fixed': 'numbered', 'before': 'anyone',
         'why': 'two different 12-byte files of one name: both (the old memcmp removed one)'},
        {'tag': 'caron', 'members': [{'stem': C_CARON, 'ext': '.txt', 'content': a(data['Ccap'])},
                                     {'stem': c_CARON, 'ext': '.txt', 'content': a(data['csmall'])}],
         'fixed': 'numbered', 'before': 'anyone',
         'why': 'C-caron.txt and c-caron.txt are one name for Windows: numbered in the listing'},
    ]
    return bytes(img), groups


def make_exfat():
    vol_sectors = 8192
    fat_off, fat_len, heap_off = 24, 64, 128
    clusters = vol_sectors - heap_off
    img = bytearray(vol_sectors * SECTOR)
    bs = bytearray(SECTOR)
    bs[0:3] = b'\xEB\x76\x90'
    bs[3:11] = b'EXFAT   '
    struct.pack_into('<QQIIIIIIHHBBBBB', bs, 64, 0, vol_sectors, fat_off, fat_len, heap_off, clusters, 5,
                     0x115115, 0x0100, 0, 9, 0, 1, 0x80, 0)
    bs[510:512] = b'\x55\xAA'
    img[0:SECTOR] = bs

    def cl_off(cl):
        return (heap_off + cl - 2) * SECTOR

    fat = {0: 0xFFFFFFF8, 1: 0xFFFFFFFF, 2: 3, 3: 0xFFFFFFFF, 4: 0xFFFFFFFF, 5: 6, 6: 7, 7: 8, 8: 0xFFFFFFFF}
    used = {2, 3, 4, 5, 6, 7, 8}
    bitmap_len = (clusters + 7) // 8
    up = bytearray()
    for c in range(128):
        up += struct.pack('<H', ord(chr(c).upper()) if 'a' <= chr(c) <= 'z' else c)
    upcs = 0
    for b in up:
        upcs = ((((upcs << 31) & 0xFFFFFFFF) | (upcs >> 1)) + b) & 0xFFFFFFFF
    img[cl_off(4):cl_off(4) + len(up)] = up
    root = bytearray()
    label = u16('TC115')
    root += struct.pack('<BB11H8s', 0x83, len(label), *(label + [0] * (11 - len(label))), b'\0' * 8)
    root += struct.pack('<BB18sIQ', 0x81, 0, b'\0' * 18, 2, bitmap_len)
    root += struct.pack('<B3sI12sIQ', 0x82, b'\0' * 3, upcs, b'\0' * 12, 4, len(up))
    nextcl = [9]
    data = {}

    def add(name, tag, deleted):
        cl = nextcl[0]
        nextcl[0] += 1
        d = content('x-' + tag)
        data[tag] = d
        img[cl_off(cl):cl_off(cl) + len(d)] = d
        root.extend(m114.exfat_file_set(u16(name), cl, len(d), deleted))
        if not deleted:
            used.add(cl)

    add('KEEP.TXT', 'keep', False)
    add(C_CARON + '.txt', 'Ccap', True)
    add(c_CARON + '.txt', 'csmall', True)
    add('a.txt', 'asmall', True)
    add('A.txt', 'Acap', True)
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

    a = lambda x: x.decode('ascii')
    groups = [
        {'tag': 'caron', 'members': [{'stem': C_CARON, 'ext': '.txt', 'content': a(data['Ccap'])},
                                     {'stem': c_CARON, 'ext': '.txt', 'content': a(data['csmall'])}],
         'fixed': 'numbered', 'before': 'anyone',
         'why': 'C-caron.txt and c-caron.txt are one name for Windows: numbered by the restore list'},
        {'tag': 'ascii', 'members': [{'stem': 'a', 'ext': '.txt', 'content': a(data['asmall'])},
                                     {'stem': 'A', 'ext': '.txt', 'content': a(data['Acap'])}],
         'fixed': 'numbered', 'before': 'numbered',
         'why': 'the control: a.txt and A.txt numbered by both builds'},
    ]
    return bytes(img), groups


def jsonable(groups):
    out = []
    for g in groups:
        h = dict(g)
        h['members'] = [{'stem_units': u16(m['stem']), 'ext': m['ext'], 'content': m['content']} for m in g['members']]
        out.append(h)
    return out


def selftest(cp):
    fimg, fg = make_fat(cp)
    eimg, eg = make_exfat()
    assert len(fimg) == 2880 * SECTOR and len(eimg) == 8192 * SECTOR
    tiny = [m['content'] for m in fg[1]['members']]
    assert all(len(t) == 12 for t in tiny) and tiny[0] != tiny[1], tiny
    assert len(fg[0]['members'][0]['content']) > 44
    # the two deleted directory entries of the root point at one cluster
    first_root = (1 + 2 * 9) * SECTOR
    ents = [fimg[first_root + i:first_root + i + 32] for i in range(0, 224 * 32, 32)]
    dirs = [struct.unpack_from('<H', e, 26)[0] for e in ents if e[0] == 0xE5 and e[11] == 0x10]
    assert dirs.count(7) == 2, dirs
    # every content is unique
    allc = [m['content'] for g in fg + eg for m in g['members']]
    assert len(allc) == len(set(allc))
    print('selftest ok: FAT %d groups, exFAT %d groups, OEM cp %d' % (len(fg), len(eg), cp))


def main():
    import ctypes
    args = sys.argv[1:]
    cp = ctypes.windll.kernel32.GetOEMCP()
    if '--oemcp' in args:
        cp = int(args[args.index('--oemcp') + 1])
    if '--selftest' in args:
        selftest(cp)
        return
    out = args[0]
    os.makedirs(out, exist_ok=True)
    fimg, fg = make_fat(cp)
    eimg, eg = make_exfat()
    dimg, dexp = m114.make_exfat('dup')  # 114's image: two deleted files of one 334-byte CJK name (View row)
    for name, b in (('fatdup115.ima', fimg), ('exfatnum115.ima', eimg), ('exfatdup114.ima', dimg)):
        with open(os.path.join(out, name), 'wb') as f:
            f.write(b)
    with open(os.path.join(out, 'expected115.json'), 'w', encoding='ascii') as f:
        json.dump({'oemcp': cp, 'fat': jsonable(fg), 'exfat': jsonable(eg),
                   'view': {'name_units': u16(m114.LONG_DUP_NAME), 'name_bytes': len(m114.LONG_DUP_NAME.encode('utf-8')),
                            'contents': [e['content'] for e in dexp]}}, f, indent=1)
    print('wrote fatdup115.ima (%d groups), exfatnum115.ima (%d groups), exfatdup114.ima, OEM cp %d' % (len(fg), len(eg), cp))


if __name__ == '__main__':
    main()
