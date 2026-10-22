# Feature 308 probe fixture: writes one PAX tar (or .deb) per probe row with Python's tarfile.
# Usage: python -I mkunp308.py <ROW> <out>. Pure ASCII; CJK names are built with chr().
import gzip
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


def add_dir(tf, name):
    ti = tarfile.TarInfo(name)
    ti.type = tarfile.DIRTYPE
    ti.mode = 0o755
    ti.mtime = 1000000000
    tf.addfile(ti)


# ten folders of 29 letters: a folder part of 10 * 29 + 9 = 299 bytes (the listing holds 255)
DEEP = '/'.join(chr(ord('a') + i) * 29 for i in range(10))


def deep_tree(tf):
    add(tf, 'a' * 29 + '/top.txt', b'T')            # makes the top folder visible in the listing
    for i in range(1, 31):
        add(tf, '%s/f%02d.txt' % (DEEP, i), b'F%02d' % i)
    add(tf, cjk(90) + '/c.txt', b'C')               # folder part 270 bytes
    add_dir(tf, cjk(255))                           # a folder name of 765 bytes
    add(tf, cjk(255) + '/in.txt', b'I')
    add(tf, 'ok.txt', b'K')


def ar_member(name, data):
    h = name.encode('ascii').ljust(16) + b'1000000000'.ljust(12) + b'0'.ljust(6) + b'0'.ljust(6) + \
        b'100644'.ljust(8) + str(len(data)).encode().ljust(10) + b'`\n'
    return h + data + (b'\n' if len(data) % 2 else b'')


def pax_tar(fill):
    buf = io.BytesIO()
    with tarfile.open(fileobj=buf, mode='w', format=tarfile.PAX_FORMAT) as tf:
        fill(tf)
    return buf.getvalue()


def main():
    row, out = sys.argv[1], sys.argv[2]
    if row.startswith('UNP-DEB'):
        ctrl = gzip.compress(pax_tar(lambda tf: add(tf, 'control', b'Package: x\n')), mtime=0)

        def data(tf):
            add(tf, 'a.txt', b'A')
            add(tf, 'a' * 125 + '/' + 'b' * 125 + '/f.txt', b'F')   # 251 bytes + the listing's "data\"
            add(tf, DEEP + '/d.txt', b'D')
            add(tf, 'ok.txt', b'K')
        raw = b'!<arch>\n' + ar_member('debian-binary', b'2.0\n') + ar_member('control.tar.gz', ctrl) + \
            ar_member('data.tar.gz', gzip.compress(pax_tar(data), mtime=0))
    elif row.startswith('UNP-DEEP') or row.startswith('COPY-DEEP'):
        raw = pax_tar(deep_tree)
    elif row.startswith('COPY-TOOLONG'):
        def fill(tf):
            add(tf, 'a' * 29 + '/top.txt', b'T')
            add(tf, 'a' * 29 + '/' + cjk(300) + '.txt', b'X')   # inside the folder the user copies
            add(tf, 'ok.txt', b'K')
        raw = pax_tar(fill)
    elif row.startswith('UNP-TOOLONG'):
        def fill(tf):
            add(tf, cjk(300) + '.txt', b'X')      # 300 UTF-16 units: no file system takes it
            add(tf, 'ok.txt', b'K')
        raw = pax_tar(fill)
    else:
        raise SystemExit('unknown row ' + row)
    with open(out, 'wb') as f:
        f.write(raw)


main()
