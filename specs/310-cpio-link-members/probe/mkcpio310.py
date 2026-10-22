# Cpio probe fixture: writes one cpio archive per probe row (newc "070701", crc "070702" or odc
# "070707"), laid out the way GNU cpio / rpm write them.
# rpm rows wrap the cpio in a minimal rpm (lead, empty signature and header, gzip payload).
# Usage: python -I mkcpio310.py <ROW> <out>. Pure ASCII.
import gzip
import struct
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


def rpm_wrap(cpio):
    # review 1 of feature 310: the payload of an rpm is a newc cpio read through the same reader
    lead = b'\xed\xab\xee\xdb' + bytes([3, 0]) + struct.pack('>hh', 0, 1) + b'tc310-1.0-1'.ljust(66, b'\0') + \
        struct.pack('>hh', 1, 5) + b'\0' * 16
    assert len(lead) == 96
    hdr = b'\x8e\xad\xe8\x01' + b'\0' * 4 + struct.pack('>II', 0, 0)
    return lead + hdr + hdr + gzip.compress(cpio, compresslevel=0, mtime=0)


def main():
    row, out = sys.argv[1], sys.argv[2]
    if row.startswith('CPIO-CRC'):
        a = Newc(crc=True)
    elif row.startswith('CPIO-ODC'):
        a = Odc()
    else:
        a = Newc()
    if '-SYM-ALIGN' in row:                                       # review 1: the padding after a target
        reg(a, 'a.txt', b'A', ino=2)
        a.member('s.txt', S_IFLNK | 0o777, b'abcdefg', ino=3)      # 7 bytes
        reg(a, 'z.txt', b'ZZ', ino=4)
    elif row.startswith('CPIO-SYM-LONG'):
        reg(a, 'a.txt', b'A', ino=2)
        a.member('s.txt', S_IFLNK | 0o777, b'x' * 5001, ino=3)     # over 4096 bytes: not read
        reg(a, 'z.txt', b'ZZ', ino=4)
    elif row.startswith('CPIO-SYM-4096'):
        reg(a, 'a.txt', b'A', ino=2)
        a.member('s.txt', S_IFLNK | 0o777, b'y' * 4095 + b'q', ino=3)  # exactly 4096: shown whole
        reg(a, 'z.txt', b'ZZ', ino=4)
    elif row.startswith('CPIO-SYM') or row.startswith('RPM-SYM'):
        reg(a, 'a.txt', b'A', ino=2)
        a.member('s.txt', S_IFLNK | 0o777, b'a.txt', ino=3)        # the target is the data
        a.member('t.txt', S_IFLNK | 0o777, b'a.txt', ino=4)        # a second one: still one box
    elif row.startswith('CPIO-HARD-FIRST') or row.startswith('VIEW-CPIO-FIRST') or row.startswith('COPY-FIRST-LATER'):
        reg(a, 'a.txt', b'F', ino=7, nlink=2)                      # data with the first name
        reg(a, 'b.txt', b'', ino=7, nlink=2)
    elif row.startswith('CPIO-HARD-CASEFIRST'):                   # review 1: names that are one file on Windows
        reg(a, 'a.txt', b'D', ino=5, nlink=2)
        reg(a, 'A.txt', b'', ino=5, nlink=2)
    elif row.startswith('CPIO-HARD-CASE'):
        reg(a, 'A.txt', b'', ino=5, nlink=2)
        reg(a, 'a.txt', b'D', ino=5, nlink=2)
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
    elif row.startswith('COPY-CPIO-ONE') or row.startswith('VIEW-CPIO-ONE'):
        reg(a, 'a.txt', b'', ino=5, nlink=2)                       # listed with size 0
        a.member('sub', S_IFDIR | 0o755, b'', ino=6, nlink=2)
        reg(a, 'sub/b.txt', b'AAA', ino=5, nlink=2)                # the data, not asked for
    elif row.startswith('VIEW-CPIO-PLAIN'):
        reg(a, 'p.txt', b'P', ino=3)                               # control: no link at all
    elif row.startswith('CPIO-ODC-HARD'):
        reg(a, 'a.txt', b'O', ino=5, nlink=2)                      # odc repeats the data per name
        reg(a, 'b.txt', b'O', ino=5, nlink=2)
    else:  # CPIO-HARD-DEL, CPIO-CRC-HARD-DEL, COPY-CPIO-ALL, RPM-HARD-DEL, CPIO-HARD-SKIPDATA / YES / SKIPCOPY: GNU cpio / rpm order (data with the last name)
        reg(a, 'c.txt', b'C', ino=4)
        a.member('sub', S_IFDIR | 0o755, b'', ino=6, nlink=2)
        reg(a, 'a.txt', b'', ino=5, nlink=3)
        reg(a, 'sub/b.txt', b'', ino=5, nlink=3)
        reg(a, 'sub/d.txt', b'AAA', ino=5, nlink=3)
    data = a.finish()
    if row.startswith('RPM'):
        data = rpm_wrap(data)
    with open(out, 'wb') as f:
        f.write(data)


main()
