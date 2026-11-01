# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Writes a small uncompressed cabinet (MS-CAB, one folder, typeCompress 0)
whose entry names are stored byte for byte as given - the fixture of the
UnCAB WTF-8 name probe. Python's standard library has no CAB writer, and
makecab does not let the caller choose the stored name bytes.

Usage: python -I cab381.py <case> <out.cab>
  ok    flagged (_A_NAME_IS_UTF) valid UTF-8 name  "a<U+00E9>.txt" + plain "c.txt"
  wtf8  flagged name with a lone surrogate, WTF-8   "a<ED A0 80>b.txt" + plain "c.txt"
  wtf8l flagged name with a lone LOW surrogate      "a<ED B0 80>b.txt" + plain "c.txt"
  bad   flagged name that is not even WTF-8          "a<FF>b.txt" + plain "c.txt"
  over  flagged name with an overlong NUL C0 80      "a<C0 80>b.txt" + plain "c.txt"
Prints one line: the case, the size, every stored name in hex.
"""
import struct
import sys

A_ARCH = 0x20
A_NAME_IS_UTF = 0x80


def checksum(data, seed):
    # the MS-CAB CFDATA checksum (as libmspack's cabd_checksum computes it)
    ul = seed
    n = len(data) // 4
    for i in range(n):
        ul ^= struct.unpack_from('<I', data, i * 4)[0]
    rest = data[n * 4:]
    ul2 = 0
    if len(rest) == 3:
        ul2 = (rest[0] << 16) | (rest[1] << 8) | rest[2]
    elif len(rest) == 2:
        ul2 = (rest[0] << 8) | rest[1]
    elif len(rest) == 1:
        ul2 = rest[0]
    return (ul ^ ul2) & 0xFFFFFFFF


def build(entries):
    # entries: list of (name bytes, attribs, content bytes)
    hdr_len = 36
    folder_len = 8
    files = b''
    stream = b''
    for name, attr, data in entries:
        # date 2026-11-01, time 12:00:00 (DOS form)
        date = ((2026 - 1980) << 9) | (11 << 5) | 1
        time = (12 << 11)
        files += struct.pack('<IIHHHH', len(data), len(stream), 0, date, time, attr) + name + b'\0'
        stream += data
    coff_files = hdr_len + folder_len
    coff_data = coff_files + len(files)
    sizes = struct.pack('<HH', len(stream), len(stream))
    csum = checksum(sizes, checksum(stream, 0))
    cfdata = struct.pack('<I', csum) + sizes + stream
    total = coff_data + len(cfdata)
    header = b'MSCF' + struct.pack('<IIIIIBBHHHHH', 0, total, 0, coff_files, 0, 3, 1, 1, len(entries), 0, 0x3810, 0)
    folder = struct.pack('<IHH', coff_data, 1, 0)
    out = header + folder + files + cfdata
    assert len(out) == total and len(header) == hdr_len
    return out


CASES = {
    'ok': b'a\xc3\xa9.txt',
    'wtf8': b'a\xed\xa0\x80b.txt',
    'wtf8l': b'a\xed\xb0\x80b.txt',
    'bad': b'a\xffb.txt',
    'over': b'a\xc0\x80b.txt',
}


def main():
    if len(sys.argv) != 3 or sys.argv[1] not in CASES:
        print(__doc__)
        return 2
    case, out = sys.argv[1], sys.argv[2]
    entries = [(CASES[case], A_ARCH | A_NAME_IS_UTF, b'N1'), (b'c.txt', A_ARCH, b'C1')]
    data = build(entries)
    with open(out, 'wb') as f:
        f.write(data)
    print('%s: %d bytes, names %s' % (case, len(data), ', '.join(e[0].hex() for e in entries)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
