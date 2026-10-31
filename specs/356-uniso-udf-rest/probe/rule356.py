"""Feature 356: a Python mirror of CISOImage::UdfRestMarks (isoimage.cpp) and salisotrack.h's UDF rule, run
over image files - prints KEEP (listing kept: a whole unpack deletes the image) or MARK per file.

usage: python -I rule356.py <image> ...

Only a cross-check of the measured images before the GUI probe; the product's code is the C++ one.
"""
import struct
import sys

S = 2048


def le32(b, o):
    return struct.unpack_from('<I', b, o)[0]


def tag_valid(sec, tid, loc):
    if len(sec) < 16 or struct.unpack_from('<H', sec, 0)[0] != tid:
        return False
    if (sum(sec[0:4]) + sum(sec[5:16])) & 0xFF != sec[4]:
        return False
    return le32(sec, 12) == loc


def anchor(sec, at):
    if len(sec) < 32 or not tag_valid(sec, 2, at):
        return None
    return (le32(sec, 16), le32(sec, 20), le32(sec, 24), le32(sec, 28))


def ext_end(loc, ln):
    return loc + (ln + S - 1) // S


def lvd_virtual(sec, at):
    if len(sec) < 440 or not tag_valid(sec, 6, at):
        return False
    count = le32(sec, 268)
    end = min(len(sec), 440 + le32(sec, 264))
    off = 440
    i = 0
    while i < count and off + 2 <= end:
        ml = sec[off + 1]
        if ml < 2 or off + ml > end:
            break
        if sec[off] == 2 and 5 + 22 <= ml and sec[off + 5:off + 27] == b'*UDF Virtual Partition':
            return True
        off += ml
        i += 1
    return False


def decide(data):
    size = len(data)
    whole = size // S

    def rd(n):
        return data[n * S:(n + 1) * S] if n < whole else b''

    a = anchor(rd(256), 256)
    if a is None:
        return 'MARK', 'no anchor at 256'
    mlen, mloc, rlen, rloc = a
    dend = max(257, ext_end(mloc, mlen), ext_end(rloc, rlen))
    part = None
    virt = False
    count = min(ext_end(mloc, mlen) - mloc, 64)
    for i in range(count):
        at = mloc + i
        sec = rd(at)
        if len(sec) != S:
            break
        if tag_valid(sec, 5, at):
            st, ln = le32(sec, 188), le32(sec, 192)
            if part is None:
                part = st
            dend = max(dend, st + ln)
        elif lvd_virtual(sec, at):
            virt = True
        elif tag_valid(sec, 8, at):
            break
    if part is None:
        return 'MARK', 'no partition'
    closed = False
    if whole > 257:
        last = whole - 1
        s = rd(last)
        closed = anchor(s, last) == a or (virt and last >= part and (tag_valid(s, 261, last - part) or tag_valid(s, 266, last - part)))
    if closed:
        return 'KEEP', f'closed at end (descriptors end {dend})'
    if whole < dend:
        return 'MARK', f'file ends within the volume ({whole} < {dend})'
    if whole - dend <= 16:
        return 'KEEP', f'{whole - dend} sectors past {dend}'
    rest = size - dend * S
    if rest > 512 * S:
        return 'MARK', f'{whole - dend} sectors past {dend}, more than 512'
    pos = dend * S
    while pos < size:
        sec = data[pos:pos + S]
        n = pos // S
        if any(sec) and not (len(sec) == S and anchor(sec, n) == a):
            return 'MARK', f'sector {n} past {dend} not empty'
        pos += S
    return 'KEEP', f'{whole - dend} empty sectors past {dend}'


for p in sys.argv[1:]:
    d, why = decide(open(p, 'rb').read())
    print(f'{d}  {p}: {why}')
