# Feature 306 probe fixture: writes one tar archive per probe row with Python's tarfile.
# Usage: python -I mkpax306.py <ROW> <out.tar>. Pure ASCII; CJK names are built with chr().
import io
import sys
import tarfile


def cjk(n, start=0x4E00):
    return ''.join(chr(start + i) for i in range(n))


def add(tf, name, data, mtime=1000000000, pax=None):
    ti = tarfile.TarInfo(name)
    ti.size = len(data)
    ti.mtime = mtime
    ti.mode = 0o644
    if pax:
        ti.pax_headers = dict(pax)
    tf.addfile(ti, io.BytesIO(data))


def patch_size_zero(raw, name):
    # sets the ustar size field of the member 'name' to 0 and recomputes its checksum
    b = bytearray(raw)
    for off in range(0, len(b), 512):
        blk = b[off:off + 512]
        if blk[0:len(name) + 1] == name.encode('ascii') + b'\0' and blk[156:157] in (b'0', b'\0'):
            b[off + 124:off + 136] = b'00000000000\0'
            b[off + 148:off + 156] = b' ' * 8
            s = sum(b[off:off + 512])
            b[off + 148:off + 156] = ('%06o\0 ' % s).encode('ascii')
            return bytes(b)
    raise SystemExit('member not found: ' + name)


def main():
    row, out = sys.argv[1], sys.argv[2]
    buf = io.BytesIO()
    fmt = tarfile.GNU_FORMAT if row.startswith('GNU') else tarfile.PAX_FORMAT
    gpax = None
    if row == 'PAX-GLOBAL':
        gpax = {'mtime': '1500000000'}
    elif row == 'GIT-COMMENT':
        gpax = {'comment': '0123456789abcdef0123456789abcdef01234567'}
    kw = {'format': fmt}
    if gpax:
        kw['pax_headers'] = gpax
    with tarfile.open(fileobj=buf, mode='w', **kw) as tf:
        if row in ('PAX-LONG', 'GNU-LONG'):
            add(tf, 'd' * 100 + '/' + 'e' * 100 + '/' + 'f' * 96 + '.txt', b'L')
        elif row == 'PAX-CJK':
            add(tf, cjk(200) + '.txt', b'C')
        elif row == 'PAX-TWINS':
            add(tf, cjk(199) + chr(0x5000) + '.txt', b'A')
            add(tf, cjk(199) + chr(0x5001) + '.txt', b'B')
        elif row == 'PAX-DEEP':
            add(tf, 'sub/' + cjk(200) + '.txt', b'D')
        elif row == 'PAX-MTIME':
            add(tf, 't.txt', b'T', pax={'mtime': '1600000000.25'})
        elif row == 'PAX-SIZE':
            add(tf, 's.txt', b'SIZE5', pax={'size': '5'})
            add(tf, 'z.txt', b'Z')
        elif row == 'PAX-GLOBAL':
            add(tf, 'g.txt', b'G')
            add(tf, 'h.txt', b'H', pax={'mtime': '1400000000'})
        elif row == 'GIT-COMMENT':
            add(tf, 'a.txt', b'A')
        elif row in ('PAX-TOOLONG', 'GNU-TOOLONG'):
            add(tf, cjk(300) + '.txt', b'X')
        else:
            raise SystemExit('unknown row ' + row)
    raw = buf.getvalue()
    if row == 'PAX-SIZE':
        raw = patch_size_zero(raw, 's.txt')
    with open(out, 'wb') as f:
        f.write(raw)


main()
