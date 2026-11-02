# Probe fixture: a cpio (newc / crc / odc), an rpm or a tar per probe row in which a regular file's data
# is stored under a name that normalizes to nothing ("", ".", "./") and reaches no other name - a single
# name (nlink 1) or an orphan hard-link group (nlink 2, the other name absent). Writers from
# specs/394-cpio-empty-name-link/probe/mkcpioempty.py (newc / crc / rpm) and
# specs/393-cpio-long-name/probe/mkcpio393.py (odc); the ustar writer is new.
# Usage: python -I mkcpiosolo.py <ROW> <out>. Pure ASCII.
import gzip
import struct
import sys

S_IFREG = 0o100000
S_IFDIR = 0o040000
MTIME = 1000000000


def pad(n, a):
    return (a - n % a) % a


class Newc:
    def __init__(self, crc=False):
        self.out = bytearray()
        self.ino = 100
        self.crc = crc

    def member(self, name, mode, data=b'', ino=None, nlink=1, dev=(8, 1)):
        if ino is None:
            self.ino += 1
            ino = self.ino
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


class Ustar:
    def __init__(self):
        self.out = bytearray()

    def member(self, name, mode, data=b'', ino=None, nlink=1, dev=None, typeflag=b'0'):
        h = bytearray(512)
        nb = name.encode('utf-8')
        h[0:len(nb)] = nb
        h[100:108] = b'%07o\0' % (mode & 0o7777)
        h[108:116] = b'%07o\0' % 0
        h[116:124] = b'%07o\0' % 0
        h[124:136] = b'%011o\0' % len(data)
        h[136:148] = b'%011o\0' % MTIME
        h[148:156] = b' ' * 8
        h[156:157] = typeflag
        h[257:263] = b'ustar\0'
        h[263:265] = b'00'
        h[148:156] = b'%06o\0 ' % (sum(h) & 0o777777)
        self.out += h + data + b'\0' * pad(len(data), 512)

    def finish(self):
        self.out += b'\0' * 1024
        self.out += b'\0' * pad(len(self.out), 10240)
        return bytes(self.out)


def reg(a, name, data, **kw):
    a.member(name, S_IFREG | 0o644, data, **kw)


def rpm_wrap(cpio):
    # the payload of an rpm is a newc cpio read through the same reader (310's minimal rpm)
    lead = b'\xed\xab\xee\xdb' + bytes([3, 0]) + struct.pack('>hh', 0, 1) + b'tc395-1.0-1'.ljust(66, b'\0') + \
        struct.pack('>hh', 1, 5) + b'\0' * 16
    assert len(lead) == 96
    hdr = b'\x8e\xad\xe8\x01' + b'\0' * 4 + struct.pack('>II', 0, 0)
    return lead + hdr + hdr + gzip.compress(cpio, compresslevel=0, mtime=0)


CARRIER = {'DOTSLASH': './', 'DOT': '.', 'NUL': ''}


def main():
    row, out = sys.argv[1], sys.argv[2]
    if '-TAR-' in row:
        a = Ustar()
    elif '-ODC-' in row:
        a = Odc()
    else:
        a = Newc(crc='-CRC-' in row)
    carrier = None
    for key, name in CARRIER.items():
        if ('-' + key + '-') in row or row.endswith('-' + key):
            carrier = name
            break
    data = b'' if '-ZERO' in row else b'AAA'
    if '-DOTDIR' in row:
        # control: GNU cpio's "." folder member (find . | cpio -o), GNU tar's "./" folder
        if '-TAR-' in row:
            a.member('./', 0o755, typeflag=b'5')
        else:
            a.member('.', S_IFDIR | 0o755, nlink=3)
        reg(a, 'ok.txt', b'K')
    elif carrier is None:
        raise SystemExit('unknown row ' + row)
    elif '-ORPHAN' in row:
        # a hard-linked file (nlink 2) whose only stored name is the empty one
        reg(a, carrier, data, ino=5, nlink=2)
        reg(a, 'ok.txt', b'K')
    elif '-WAIT' in row:
        # control (feature 394): the data reaches the waiting name a.txt
        reg(a, 'a.txt', b'', ino=5, nlink=2)
        reg(a, carrier, data, ino=5, nlink=2)
        reg(a, 'ok.txt', b'K')
    else:
        # SOLO: a single-name file (nlink 1)
        reg(a, carrier, data)
        reg(a, 'ok.txt', b'K')
    data = a.finish()
    if '-RPM-' in row:
        data = rpm_wrap(data)
    with open(out, 'wb') as f:
        f.write(data)


main()
