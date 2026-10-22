# Feature 307 probe fixture: writes one archive per probe row.
# Usage: python -I mktar307.py <ROW> <out> [<7z.exe>]. Pure ASCII; CJK names are built with chr().
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


def main():
    row, out = sys.argv[1], sys.argv[2]
    if row == 'ZIP-TOOLONG':
        zip_arc(out)
    elif row == '7Z-TOOLONG':
        exe = sys.argv[3] if len(sys.argv) > 3 else ''
        if not exe or not os.path.isfile(exe):
            raise SystemExit('7z.exe not found')
        seven_zip(out, exe)
    else:
        gnu_tar(row, out)


main()
