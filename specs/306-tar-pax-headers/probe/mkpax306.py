# Feature 306 probe fixture: writes one tar archive per probe row with Python's tarfile.
# Usage: python -I mkpax306.py <ROW> <out.tar>. Pure ASCII; CJK names are built with chr().
import gzip
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


def ar_member(name, data):
    h = name.encode('ascii').ljust(16) + b'1000000000'.ljust(12) + b'0'.ljust(6) + b'0'.ljust(6) + \
        b'100644'.ljust(8) + str(len(data)).encode().ljust(10) + b'`\n'
    return h + data + (b'\n' if len(data) % 2 else b'')


def pax_tar(entries):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode='w', format=tarfile.PAX_FORMAT) as tf:
        for name, data in entries:
            add(tf, name, data)
    return buf.getvalue()


def make_deb(out):
    # review 2 of feature 306 (fixture B-DEB): a .deb lists data.tar under "data\" - a folder part of
    # 251 bytes fits a plain tar's listing but not with the 5-byte prefix
    ctrl = gzip.compress(pax_tar([('control', b'Package: x\n')]), mtime=0)
    data = gzip.compress(pax_tar([('a.txt', b'A'), ('a' * 125 + '/' + 'b' * 125 + '/f.txt', b'F'), ('ok.txt', b'K')]),
                         mtime=0)
    with open(out, 'wb') as f:
        f.write(b'!<arch>\n' + ar_member('debian-binary', b'2.0\n') + ar_member('control.tar.gz', ctrl) +
                ar_member('data.tar.gz', data))


def main():
    row, out = sys.argv[1], sys.argv[2]
    if row == 'PAX-DEB':
        make_deb(out)
        return
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
        elif row == 'PAX-PATHPART':
            # review 1 of feature 306: folder parts over the listing's 255 bytes (fine on a file system)
            add(tf, 'a.txt', b'a')
            add(tf, cjk(90) + '/f.txt', b'F')  # folder part 270 bytes
            add(tf, 'a' * 130 + '/' + 'b' * 130 + '/g.txt', b'G')  # folder part 261 bytes, ASCII
            add(tf, 'ok.txt', b'K')
        elif row == 'PAX-255DIR':
            # a folder member named with 255 CJK letters (765 bytes) and a file inside it
            ti = tarfile.TarInfo(cjk(255))
            ti.type = tarfile.DIRTYPE
            ti.mode = 0o755
            ti.mtime = 1000000000
            tf.addfile(ti)
            add(tf, cjk(255) + '/in.txt', b'I')
            add(tf, 'ok.txt', b'K')
        elif row == 'PAX-LIMIT':
            add(tf, 'p' * 255 + '/f.txt', b'P')  # folder part exactly 255 bytes: listed and extracted
        elif row in ('PAX-TOOLONG', 'GNU-TOOLONG'):
            add(tf, cjk(300) + '.txt', b'X')
            if row == 'PAX-TOOLONG':
                add(tf, 'ok.txt', b'K')  # the rest of the archive stays usable
        else:
            raise SystemExit('unknown row ' + row)
    raw = buf.getvalue()
    if row == 'PAX-SIZE':
        raw = patch_size_zero(raw, 's.txt')
    with open(out, 'wb') as f:
        f.write(raw)


main()
