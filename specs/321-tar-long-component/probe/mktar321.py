# Feature 321 probe fixture (from the first run, 307): writes one archive per probe row.
# Usage: python -I mktar321.py <ROW> <out> [<7z.exe>]. Pure ASCII; CJK names are built with chr().
import io
import os
import subprocess
import sys
import tarfile
import zipfile


def cjk(n, start=0x4E00):
    return ''.join(chr(start + i) for i in range(n))


TOOLONG = cjk(300) + '.txt'  # 904 bytes, 304 UTF-16 units: no file system takes it


def add(tf, name, data, mtime=1000000000):
    ti = tarfile.TarInfo(name)
    ti.size = len(data)
    ti.mtime = mtime
    ti.mode = 0o644
    tf.addfile(ti, io.BytesIO(data))


def add_dir(tf, name):
    ti = tarfile.TarInfo(name)
    ti.type = tarfile.DIRTYPE
    ti.mode = 0o755
    ti.mtime = 1000000000
    tf.addfile(ti)


def gnu_tar(row, out):
    buf = io.BytesIO()
    # GNU format: a name over 100 bytes is written as a GNU long name ('L' header)
    with tarfile.open(fileobj=buf, mode='w', format=tarfile.GNU_FORMAT) as tf:
        if row == 'GNU-TOOLONG':
            add(tf, TOOLONG, b'X')
            add(tf, 'ok.txt', b'K')  # the rest of the archive stays usable
        elif row == 'GNU-DEEP':
            # review 1 of feature 306 (fixture R-GNU2K): 12 folders of 200 letters - every component
            # fits a file system, the folder part (2411 bytes) does not fit the listing
            add(tf, 'a.txt', b'a')
            add(tf, '/'.join([c * 200 for c in 'bcdefghijklm']) + '/f.txt', b'F')
            add(tf, 'ok.txt', b'K')
        elif row == 'GNU-255':
            add(tf, cjk(251) + '.txt', b'M')  # 255 UTF-16 units, 757 bytes: the boundary, listed
        elif row == 'GNU-255DIR':
            # a folder named with 255 CJK letters (765 bytes) and a file inside it
            add_dir(tf, cjk(255))
            add(tf, cjk(255) + '/in.txt', b'I')
            add(tf, 'ok.txt', b'K')
        elif row == 'GNU-DIR100':
            # review 1 of the first run (307) (SHOULD): an empty top-level folder of 100 CJK letters (300 bytes)
            # listed and extracted in 0.1.10 - a folder name over 255 bytes is no limit at the top level
            add_dir(tf, cjk(100))
            add(tf, 'ok.txt', b'K')
        elif row == 'GNU-LONG':
            add(tf, 'd' * 100 + '/' + 'e' * 100 + '/' + 'f' * 96 + '.txt', b'L')  # regression
        else:
            raise SystemExit('unknown row ' + row)
    with open(out, 'wb') as f:
        f.write(buf.getvalue())


def zip_arc(out):
    with zipfile.ZipFile(out, 'w') as zf:  # non-ASCII names get the UTF-8 flag
        zf.writestr(TOOLONG, b'X')
        zf.writestr('ok.txt', b'K')


def seven_zip(out, exe):
    # -si<name>: the member's name from the command line, its data from stdin - the name needs no
    # file on disk (none could exist)
    for name, data in ((TOOLONG, b'X'), ('ok.txt', b'K')):
        r = subprocess.run([exe, 'a', '-t7z', '-bd', out, '-si' + name], input=data, capture_output=True)
        if r.returncode != 0:
            raise SystemExit('7z failed: ' + r.stdout.decode('ascii', 'replace')[-300:])


def cpio_newc(out, members):
    # SVR4 "newc" cpio (opened by the TAR plug-in): a 110-byte ASCII header, the name with its NUL,
    # padded to 4 bytes, the data padded to 4 bytes; the archive ends with the member TRAILER!!!
    def pad(n):
        return b'\0' * ((4 - n % 4) % 4)
    raw = b''
    ino = 1
    for name, data in list(members) + [('TRAILER!!!', b'')]:
        nb = name.encode('utf-8') + b'\0'
        mode = 0o100644 if name != 'TRAILER!!!' else 0
        fields = [ino, mode, 0, 0, 1, 1000000000, len(data), 0, 0, 0, 0, len(nb), 0]
        hdr = b'070701' + b''.join(b'%08X' % f for f in fields)
        raw += hdr + nb + pad(len(hdr) + len(nb)) + data + pad(len(data))
        ino += 1
    with open(out, 'wb') as f:
        f.write(raw)


def main():
    row, out = sys.argv[1], sys.argv[2]
    if row == 'CPIO-778':
        # review 1 of the first run (307): 778 bytes fit the listing's bound (below 780) - with "simple icons in
        # archives" the extension (777 bytes) plus 4 zero bytes overflowed a 780-byte buffer
        cpio_newc(out, [('.' + 'a' * 777, b'X'), ('ok.txt', b'K')])
    elif row == 'CPIO-TOOLONG':
        cpio_newc(out, [(TOOLONG, b'X'), ('ok.txt', b'K')])
    elif row == 'ZIP-TOOLONG':
        zip_arc(out)
    elif row == '7Z-TOOLONG':
        exe = sys.argv[3] if len(sys.argv) > 3 else ''
        if not exe or not os.path.isfile(exe):
            raise SystemExit('7z.exe not found')
        seven_zip(out, exe)
    else:
        gnu_tar(row, out)


main()
