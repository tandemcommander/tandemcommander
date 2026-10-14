"""Feature 165 probe helper: ZIP entry counts.

    python zipcount.py make <arc.zip> <N>     N members d/a000000.txt ... (every second one *.del);
                                              zip64 end records when N >= 65535 (Python's rule)
    python zipcount.py files <dir> <N> [pfx]  N small files <pfx>000000.txt ... in <dir>
    python zipcount.py eocd <arc.zip>         prints RECORDS <walked> EOCD <total16> <disk16>
                                              Z64 <yes|no> <total64> <disk64> EFFECTIVE <n> OK <0|1>
        RECORDS: central records walked by the directory's size and offset (as zipfile reads);
        EFFECTIVE: the count a reader that trusts the end record gets (the zip64 value when the
        16-bit field holds 0xFFFF and a zip64 record exists, else the 16-bit value); OK: both
        equal, and a count of 65535 or more is in a zip64 record.
"""
import os
import struct
import sys
import zipfile


def name(i):
    return 'd/a%06d.%s' % (i, 'del' if i % 2 else 'txt')


def make(arc, n):
    with zipfile.ZipFile(arc, 'w', zipfile.ZIP_DEFLATED, allowZip64=True) as z:
        for i in range(n):
            z.writestr(zipfile.ZipInfo(name(i), (2026, 1, 2, 3, 4, 6)), ('m%d\r\n' % i).encode('ascii'))
    print('ok')


def files(d, n, pfx):
    os.makedirs(d, exist_ok=True)
    for i in range(n):
        with open(os.path.join(d, '%s%06d.txt' % (pfx, i)), 'wb') as f:
            f.write(('f%d\r\n' % i).encode('ascii'))
    print('ok')


def eocd(arc):
    data = open(arc, 'rb').read()
    p = data.rfind(b'PK\x05\x06')
    if p < 0:
        print('NO EOCD OK 0')
        return
    _, disk, sdisk, dtot, tot, size, offs, clen = struct.unpack('<IHHHHIIH', data[p:p + 22])
    z64 = False
    tot64 = dtot64 = -1
    loc = p - 20
    if loc >= 0 and data[loc:loc + 4] == b'PK\x06\x07':
        _, zdisk, zoffs, ndisks = struct.unpack('<IIQI', data[loc:loc + 20])
        if data[zoffs:zoffs + 4] == b'PK\x06\x06':
            z64 = True
            (sig, rsize, vmade, vneed, d1, d2, dtot64, tot64, size64, offs64) = struct.unpack(
                '<IQHHIIQQQQ', data[zoffs:zoffs + 56])
            size, offs = size64, offs64
    # walk the central directory
    q, end, walked = offs, offs + size, 0
    while q < end and data[q:q + 4] == b'PK\x01\x02':
        nl, el, cl = struct.unpack('<HHH', data[q + 28:q + 34])
        q += 46 + nl + el + cl
        walked += 1
    eff = tot64 if (tot == 0xFFFF and z64) else tot
    # Python's zipfile reads it too: every member, a clean test
    try:
        with zipfile.ZipFile(arc) as z:
            n = len(z.infolist())
            bad = z.testzip()
        zf = 'ZIPFILE %d %s' % (n, 'clean' if bad is None else 'BAD')
        zok = n == walked and bad is None
    except Exception as e:
        zf, zok = 'ZIPFILE error %s' % e.__class__.__name__, False
    ok = int(eff == walked and (walked < 0xFFFF or (z64 and tot64 == walked)) and q == end and zok)
    print('RECORDS %d EOCD %d %d Z64 %s %d %d EFFECTIVE %d %s OK %d' % (walked, tot, dtot, 'yes' if z64 else 'no',
                                                                       tot64, dtot64, eff, zf, ok))


def makewrong(arc, n):
    """As make, then the end records replaced by a plain one whose count is n modulo 65,536 - the
    archive an earlier version of the ZIP plug-in wrote when it packed n files."""
    make(arc, n)
    data = open(arc, 'rb').read()
    p = data.rfind(b'PK\x05\x06')
    loc = p - 20
    assert data[loc:loc + 4] == b'PK\x06\x07'
    _, zdisk, zoffs, ndisks = struct.unpack('<IIQI', data[loc:loc + 20])
    rec = struct.unpack('<IQHHIIQQQQ', data[zoffs:zoffs + 56])
    size, offs = rec[8], rec[9]
    assert size < 0xFFFFFFFF and offs < 0xFFFFFFFF
    wrong = n % 65536
    eocd = struct.pack('<IHHHHIIH', 0x06054B50, 0, 0, wrong, wrong, size, offs, 0)
    open(arc, 'wb').write(data[:zoffs] + eocd)


if sys.argv[1] == 'make':
    make(sys.argv[2], int(sys.argv[3]))
elif sys.argv[1] == 'makewrong':
    makewrong(sys.argv[2], int(sys.argv[3]))
elif sys.argv[1] == 'files':
    files(sys.argv[2], int(sys.argv[3]), sys.argv[4] if len(sys.argv) > 4 else 'f')
else:
    eocd(sys.argv[2])
