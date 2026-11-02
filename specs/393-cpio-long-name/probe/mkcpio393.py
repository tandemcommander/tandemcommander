# Feature 393 probe fixture: writes one cpio (newc "070701" or odc "070707") or rpm per probe row.
# Writers from specs/310-cpio-link-members/probe/mkcpio310.py, the deep tree from
# specs/321-tar-long-component/probe/mkunp321.py.
# Usage: python -I mkcpio393.py <ROW> <out>. Pure ASCII; CJK names are built with chr().
import gzip
import struct
import sys

S_IFREG = 0o100000
S_IFDIR = 0o040000
MTIME = 1000000000


def cjk(n, start=0x4E00):
    return ''.join(chr(start + i) for i in range(n))


TOOLONG = cjk(300) + '.txt'  # 904 bytes, 304 UTF-16 units: no file system takes it
# ten folders of 29 letters: a folder part of 10 * 29 + 9 = 299 bytes (the listing holds 255)
DEEP = '/'.join(chr(ord('a') + i) * 29 for i in range(10))


def pad(n, a):
    return (a - n % a) % a


class Newc:
    def __init__(self):
        self.out = bytearray()
        self.ino = 100

    def member(self, name, mode, data=b'', ino=None, nlink=1, dev=(8, 1)):
        if ino is None:
            self.ino += 1
            ino = self.ino
        nb = name.encode('utf-8') + b'\0'
        fields = [ino, mode, 0, 0, nlink, MTIME, len(data), dev[0], dev[1], 0, 0, len(nb), 0]
        hdr = b'070701' + b''.join(b'%08X' % f for f in fields)
        self.out += hdr + nb
        self.out += b'\0' * pad(len(hdr) + len(nb), 4)
        self.out += data
        self.out += b'\0' * pad(len(data), 4)

    def finish(self):
        self.member('TRAILER!!!', 0, ino=0, nlink=1, dev=(0, 0))
        self.out += b'\0' * pad(len(self.out), 512)
        return bytes(self.out)


class Odc:
    def __init__(self):
        self.out = bytearray()
        self.ino = 100

    def member(self, name, mode, data=b'', ino=None, nlink=1, dev=(8, 1)):
        if ino is None:
            self.ino += 1
            ino = self.ino
        nb = name.encode('utf-8') + b'\0'
        hdr = b'070707' + (b'%06o' % (dev[0] * 256 + dev[1])) + (b'%06o' % ino) + (b'%06o' % mode) + \
            b'%06o' % 0 + b'%06o' % 0 + (b'%06o' % nlink) + b'%06o' % 0 + (b'%011o' % MTIME) + \
            (b'%06o' % len(nb)) + (b'%011o' % len(data))
        assert len(hdr) == 76
        self.out += hdr + nb + data

    def finish(self):
        self.member('TRAILER!!!', 0, ino=0, nlink=1, dev=(0, 0))
        self.out += b'\0' * pad(len(self.out), 512)
        return bytes(self.out)


def reg(a, name, data, **kw):
    a.member(name, S_IFREG | 0o644, data, **kw)


def folder(a, name):
    a.member(name, S_IFDIR | 0o755)  # GNU cpio writes folders without a trailing slash


def rpm_wrap(cpio):
    # the payload of an rpm is a newc cpio read through the same reader (310's minimal rpm)
    lead = b'\xed\xab\xee\xdb' + bytes([3, 0]) + struct.pack('>hh', 0, 1) + b'tc393-1.0-1'.ljust(66, b'\0') + \
        struct.pack('>hh', 1, 5) + b'\0' * 16
    assert len(lead) == 96
    hdr = b'\x8e\xad\xe8\x01' + b'\0' * 4 + struct.pack('>II', 0, 0)
    return lead + hdr + hdr + gzip.compress(cpio, compresslevel=0, mtime=0)


def deep_tree(a):
    reg(a, 'a' * 29 + '/top.txt', b'T')            # makes the top folder visible in the listing
    for i in range(1, 31):
        reg(a, '%s/f%02d.txt' % (DEEP, i), b'F%02d' % i)
    reg(a, cjk(90) + '/c.txt', b'C')               # folder part 270 bytes
    folder(a, cjk(255))                            # a top-level folder name of 765 bytes
    reg(a, cjk(255) + '/in.txt', b'I')
    reg(a, 'ok.txt', b'K')


def main():
    row, out = sys.argv[1], sys.argv[2]
    a = Odc() if '-ODC-' in row else Newc()
    if row.endswith('-TOOLONG') or row.endswith('-TOOLONG-DEL'):
        reg(a, TOOLONG, b'X')
        reg(a, 'ok.txt', b'K')                     # the rest of the archive stays usable
    elif row.startswith('COPY-DEEP') or row.startswith('UNP-DEEP'):
        deep_tree(a)
    elif row == 'COPY-255':
        reg(a, cjk(251) + '.txt', b'M')            # 255 UTF-16 units, 757 bytes: the boundary, listed
    elif row == 'COPY-DIR100':
        folder(a, cjk(100))                        # an empty top-level folder of 300 bytes: listed (321)
        reg(a, 'ok.txt', b'K')
    elif row == 'COPY-NESTDIR':
        folder(a, 'n')
        reg(a, 'n/top.txt', b'T')
        folder(a, 'n/' + cjk(100))                 # a folder name of 300 bytes inside a folder: refused
        reg(a, 'ok.txt', b'K')
    elif row.startswith('COPY-HARD-REFUSED') or row.startswith('UNP-HARD-REFUSED'):
        # one file with two names (GNU cpio order: the data with the last name); the name carrying
        # the data is one no file system takes
        reg(a, 'a.txt', b'', ino=5, nlink=2)
        reg(a, TOOLONG, b'AAA', ino=5, nlink=2)
        reg(a, 'ok.txt', b'K')
    elif row.startswith('COPY-HARD-FIRST') or row.startswith('UNP-HARD-FIRST'):
        # review 1: the data-first layout - the refused name carries the data and comes first
        reg(a, TOOLONG, b'AAA', ino=5, nlink=2)
        reg(a, 'a.txt', b'', ino=5, nlink=2)
        reg(a, 'ok.txt', b'K')
    elif row == 'COPY-SYMLINK-LONG':
        # review 1: a symbolic link with a refused name (never listed; now named at opening)
        a.member(TOOLONG, 0o120000 | 0o777, b'ok.txt')
        reg(a, 'ok.txt', b'K')
    else:
        raise SystemExit('unknown row ' + row)
    data = a.finish()
    if '-RPM-' in row:
        data = rpm_wrap(data)
    with open(out, 'wb') as f:
        f.write(data)


main()
