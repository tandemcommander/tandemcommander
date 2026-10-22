# Feature 309 probe fixture: writes one tar per probe row with Python's tarfile.
# Usage: python -I mklink309.py <ROW> <out>. Pure ASCII; CJK names are built with chr().
import io
import sys
import tarfile


def cjk(n, start=0x4E00):
    return ''.join(chr(start + i) for i in range(n))


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
    fmt = tarfile.PAX_FORMAT
    if row.startswith('UNP-HARD-PAX'):
        def fill(tf):
            add(tf, cjk(40) + '.txt', b'L')                    # 120 bytes, non-ASCII: a PAX path
            link(tf, 'sub/' + cjk(40, 0x4F00) + '.txt', cjk(40) + '.txt')   # a PAX linkpath
    elif row.startswith('UNP-HARD-GNU'):
        fmt = tarfile.GNU_FORMAT
        def fill(tf):
            add(tf, 'g' * 120 + '.txt', b'G')                  # a GNU long name ('L')
            link(tf, 'sub/h.txt', 'g' * 120 + '.txt')          # a GNU long link name ('K')
    elif row.startswith('UNP-HARD-MISSING'):
        def fill(tf):
            link(tf, 'b.txt', 'missing.txt')                   # no such member
            add(tf, 'ok.txt', b'K')
    elif row.startswith('UNP-SYM'):
        def fill(tf):
            add(tf, 'a.txt', b'A')
            link(tf, 's.txt', 'a.txt', tarfile.SYMTYPE)
            link(tf, 't.txt', 'a.txt', tarfile.SYMTYPE)       # a second one: still one box
    elif row.startswith('UNP-HARD-TWIN'):
        def fill(tf):
            add(tf, 'a.txt', b'A')
            link(tf, 'A.TXT', 'a.txt')                         # the same file on Windows
    elif row.startswith('UNP-HARD') or row.startswith('COPY-HARD'):
        def fill(tf):
            add(tf, 'a.txt', b'A')
            add(tf, 'sub/c.txt', b'C')
            link(tf, 'sub/b.txt', 'a.txt')
            link(tf, './sub/d.txt', './a.txt')                 # GNU tar's "./" spelling
    else:
        raise SystemExit('unknown row ' + row)
    raw = make(fill, fmt)
    with open(out, 'wb') as f:
        f.write(raw)


main()
