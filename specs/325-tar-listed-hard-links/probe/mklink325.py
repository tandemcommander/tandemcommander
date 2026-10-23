# Feature 325 probe fixture: writes one tar per probe row with Python's tarfile.
# Usage: python -I mklink325.py <ROW> <out>. Pure ASCII. A row ending in -GZ is gzip-compressed.
import gzip
import io
import sys
import tarfile

BIG = ('0123456789abcdef' * 8192).encode('ascii')   # 128 KiB: the data spans many blocks and buffers


def add(tf, name, data):
    ti = tarfile.TarInfo(name)
    ti.size = len(data)
    ti.mtime = 1000000000
    ti.mode = 0o644
    tf.addfile(ti, io.BytesIO(data))


def link(tf, name, target, kind=tarfile.LNKTYPE):
    ti = tarfile.TarInfo(name)
    ti.type = kind
    ti.linkname = target
    ti.mtime = 1000000000
    ti.mode = 0o644
    tf.addfile(ti)


def make(fill, fmt=tarfile.PAX_FORMAT):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode='w', format=fmt) as tf:
        fill(tf)
    return buf.getvalue()


def main():
    row, out = sys.argv[1], sys.argv[2]
    base = row[:-3] if row.endswith('-GZ') else row
    if base.startswith('COPY-CHAIN') or base.startswith('COPY-EXIST'):
        def fill(tf):
            add(tf, 'a.txt', BIG)
            add(tf, 'sub/c.txt', b'C')
            link(tf, 'sub/b.txt', 'a.txt')
            link(tf, 'sub/e.txt', 'sub/b.txt')                 # a link to a link
    elif base.startswith('COPY-MISSING'):
        def fill(tf):
            add(tf, 'sub/c.txt', b'C')
            link(tf, 'sub/b.txt', 'missing.txt')               # no such member
    elif base.startswith('COPY-SYM'):
        def fill(tf):
            add(tf, 'a.txt', b'A')
            add(tf, 'sub/c.txt', b'C')
            link(tf, 'sub/s.txt', '../a.txt', tarfile.SYMTYPE)  # not listed, as before
    elif base.startswith('COPY') or base.startswith('VIEW'):
        def fill(tf):
            add(tf, 'a.txt', b'A')
            add(tf, 'sub/c.txt', b'C')
            link(tf, 'sub/b.txt', 'a.txt')
            link(tf, './sub/d.txt', './a.txt')                 # GNU tar's "./" spelling
    else:
        raise SystemExit('unknown row ' + row)
    raw = make(fill)
    if row.endswith('-GZ'):
        raw = gzip.compress(raw, mtime=0)
    with open(out, 'wb') as f:
        f.write(raw)


main()
