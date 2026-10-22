# Cpio probe fixture: writes one cpio archive per probe row (newc "070701", crc "070702" or odc
# "070707"), laid out the way GNU cpio / rpm write them.
# Usage: python -I mkcpio.py <ROW> <out>. Pure ASCII.
import sys

S_IFREG = 0o100000
S_IFDIR = 0o040000
S_IFLNK = 0o120000
S_IFIFO = 0o010000
MTIME = 1000000000


def pad(n, a):
    return (a - n % a) % a


class Newc:
    def __init__(self, crc=False):
        self.crc = crc
        self.out = bytearray()

    def member(self, name, mode, data=b'', ino=1, nlink=1, dev=(8, 1)):
        nb = name.encode('utf-8') + b'\0'
        check = (sum(data) & 0xFFFFFFFF) if self.crc else 0
        fields = [ino, mode, 0, 0, nlink, MTIME, len(data), dev[0], dev[1], 0, 0, len(nb), check]
        hdr = (b'070702' if self.crc else b'070701') + b''.join(b'%08X' % f for f in fields)
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

    def member(self, name, mode, data=b'', ino=1, nlink=1, dev=(8, 1)):
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


def main():
    row, out = sys.argv[1], sys.argv[2]
    if row.startswith('CPIO-CRC'):
        a = Newc(crc=True)
    elif row.startswith('CPIO-ODC'):
        a = Odc()
    else:
        a = Newc()
    if row.startswith('CPIO-SYM'):
        reg(a, 'a.txt', b'A', ino=2)
        a.member('s.txt', S_IFLNK | 0o777, b'a.txt', ino=3)        # the target is the data
        a.member('t.txt', S_IFLNK | 0o777, b'a.txt', ino=4)        # a second one: still one box
    elif row.startswith('CPIO-HARD-FIRST'):
        reg(a, 'a.txt', b'F', ino=7, nlink=2)                      # data with the first name
        reg(a, 'b.txt', b'', ino=7, nlink=2)
    elif row.startswith('CPIO-HARD-EMPTY'):
        reg(a, 'e1.txt', b'', ino=9, nlink=2)                      # an empty file with two names
        reg(a, 'e2.txt', b'', ino=9, nlink=2)
        reg(a, 'ok.txt', b'K', ino=10)
    elif row.startswith('CPIO-HARD-DEV'):
        reg(a, 'a.txt', b'', ino=5, nlink=2, dev=(8, 1))           # same inode number, other device
        reg(a, 'b.txt', b'B', ino=5, nlink=2, dev=(8, 2))          # the data of a different file
        reg(a, 'c.txt', b'C', ino=5, nlink=2, dev=(8, 1))          # a.txt's data
    elif row.startswith('CPIO-FIFO'):
        a.member('p', S_IFIFO | 0o644, b'', ino=11)                # a named pipe: not a file's data
        reg(a, 'ok.txt', b'K', ino=12)
    elif row.startswith('COPY-CPIO-ONE'):
        reg(a, 'a.txt', b'', ino=5, nlink=2)                       # listed with size 0
        a.member('sub', S_IFDIR | 0o755, b'', ino=6, nlink=2)
        reg(a, 'sub/b.txt', b'AAA', ino=5, nlink=2)                # the data, not asked for
    elif row.startswith('CPIO-ODC-HARD'):
        reg(a, 'a.txt', b'O', ino=5, nlink=2)                      # odc repeats the data per name
        reg(a, 'b.txt', b'O', ino=5, nlink=2)
    else:  # CPIO-HARD-DEL, CPIO-CRC-HARD-DEL, COPY-CPIO-ALL: GNU cpio / rpm order (data with the last name)
        reg(a, 'c.txt', b'C', ino=4)
        a.member('sub', S_IFDIR | 0o755, b'', ino=6, nlink=2)
        reg(a, 'a.txt', b'', ino=5, nlink=3)
        reg(a, 'sub/b.txt', b'', ino=5, nlink=3)
        reg(a, 'sub/d.txt', b'AAA', ino=5, nlink=3)
    with open(out, 'wb') as f:
        f.write(a.finish())


main()
