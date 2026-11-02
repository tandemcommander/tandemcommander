# Probe fixture: a newc / crc cpio (or rpm) per probe row in which the member carrying the data of a
# hard-linked file has a name that normalizes to nothing ("", ".", "./"). Writers from
# specs/393-cpio-long-name/probe/mkcpio393.py (newc gains the crc "070702" variant with its checksum).
# Usage: python -I mkcpioempty.py <ROW> <out>. Pure ASCII.
import gzip
import struct
import sys

S_IFREG = 0o100000
S_IFDIR = 0o040000
MTIME = 1000000000


def pad(n, a):
    return (a - n % a) % a


class Newc:
    def __init__(self, crc=False, badsum=False):
        self.out = bytearray()
        self.ino = 100
        self.crc = crc
        self.badsum = badsum

    def member(self, name, mode, data=b'', ino=None, nlink=1, dev=(8, 1)):
        if ino is None:
            self.ino += 1
            ino = self.ino
        nb = name.encode('utf-8') + b'\0'
        check = 0
        if self.crc:
            check = sum(data) & 0xFFFFFFFF
            if self.badsum and len(data) > 0 and name in ('', '.', './'):
                check = (check + 1) & 0xFFFFFFFF
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


def reg(a, name, data, **kw):
    a.member(name, S_IFREG | 0o644, data, **kw)


def rpm_wrap(cpio):
    # the payload of an rpm is a newc cpio read through the same reader (310's minimal rpm)
    lead = b'\xed\xab\xee\xdb' + bytes([3, 0]) + struct.pack('>hh', 0, 1) + b'tc394-1.0-1'.ljust(66, b'\0') + \
        struct.pack('>hh', 1, 5) + b'\0' * 16
    assert len(lead) == 96
    hdr = b'\x8e\xad\xe8\x01' + b'\0' * 4 + struct.pack('>II', 0, 0)
    return lead + hdr + hdr + gzip.compress(cpio, compresslevel=0, mtime=0)


CARRIER = {'DOT': '.', 'DOTSLASH': './', 'NUL': ''}


def main():
    row, out = sys.argv[1], sys.argv[2]
    a = Newc(crc='-CRC-' in row, badsum='-BADSUM' in row)
    carrier = None
    for key, name in CARRIER.items():
        if ('-EMPTY-' + key) in row:
            carrier = name
    if row.startswith('UNP-DOTDIR') or row.startswith('COPY-DOTDIR'):
        # control: GNU cpio's "." folder member (find . | cpio -o) stays without effect
        a.member('.', S_IFDIR | 0o755, nlink=3)
        reg(a, 'ok.txt', b'K')
    elif carrier is not None and '-FIRST' in row:
        # the data-first layout: the empty-named carrier comes before the other name
        reg(a, carrier, b'AAA', ino=5, nlink=2)
        reg(a, 'a.txt', b'', ino=5, nlink=2)
        reg(a, 'ok.txt', b'K')
    elif carrier is not None:
        # one file with two names (GNU cpio order: the data with the last name); the name carrying the
        # data normalizes to nothing
        reg(a, 'a.txt', b'', ino=5, nlink=2)
        reg(a, carrier, b'AAA', ino=5, nlink=2)
        if not row.startswith('VIEW-'):  # F3 views the last listed item: a.txt alone
            reg(a, 'ok.txt', b'K')
    else:
        raise SystemExit('unknown row ' + row)
    data = a.finish()
    if '-RPM-' in row:
        data = rpm_wrap(data)
    with open(out, 'wb') as f:
        f.write(data)


main()
