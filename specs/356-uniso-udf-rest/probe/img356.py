"""Feature 356: cooked UDF-only test images for iso356_probe.ps1.

usage: python -I img356.py <kind> <u1.iso> <u2.iso> <out>

u1 / u2 are UDF-only images of 2048-byte sectors written by Windows' IMAPI2FS (u1 holds a.txt "A1", u2 holds
b.txt "B2"). "The descriptors' end" below is the sector after the last of: the anchor at 256, the main and the
reserve volume descriptor sequence, the partition (IMAPI2FS: 310; its file holds anchors up to its end, 576).

  plain     u1 as it is
  two       u1 followed by u2 (two UDF volumes joined; u2's anchors carry their own, relative locations)
  twoabs    as two, u2's last sector an anchor of the later volume addressed as on a disc (its location the
            file's last sector, its extents moved by u1's length)
  rest16    u1 cut at the descriptors' end + 16 sectors of 0x5A
  rest17    u1 cut at the descriptors' end + 17 sectors of 0x5A
  zero100   u1 + 100 zero sectors (its last sector zero: the rest past the descriptors - u1's anchors and
            zero bytes, 366 sectors - is read)
  zero300   u1 + 300 zero sectors (566 sectors past the descriptors - more than are read)
  data100   u1 + 100 sectors of 0x5A (review 1: the sector 256 before the end is one of u1's anchors)
  data256   the first image (any, e.g. an mkudffs one) + 256 sectors of 0x5A (review 1: its closing anchor
            lies 256 before the end)
  two       with an ISO 9660 image as the second argument: a UDF volume followed by an ISO 9660 one
  anchorrest u1 cut at sector 450 + 1 zero sector (not closed; the rest is u1's own anchors and zero bytes)
  zero512   u1 cut at the descriptors' end + 512 zero sectors
  zero513   u1 cut at the descriptors' end + 513 zero sectors
  zerolate  u1 cut at the descriptors' end + 300 zero sectors, the file's last byte 1
  short     u1 cut 10 sectors before the descriptors' end (the file ends within the volume)
  noanchor  u1 with its sector 256 (the anchor) zeroed
  anchor600 u1 cut at the descriptors' end + 600 zero sectors + u1's anchor relocated to the file's last sector
"""
import struct
import sys

S = 2048


def sectors(data):
    return len(data) // S


def tag_checksum(sec):
    return (sum(sec[0:4]) + sum(sec[5:16])) & 0xFF


def set_anchor(sec, loc, shift=0):
    b = bytearray(sec)
    struct.pack_into('<I', b, 12, loc)
    mlen, mloc = struct.unpack_from('<II', b, 16)
    rlen, rloc = struct.unpack_from('<II', b, 24)
    struct.pack_into('<II', b, 16, mlen, mloc + shift)
    struct.pack_into('<II', b, 24, rlen, rloc + shift)
    b[4] = tag_checksum(b)
    return bytes(b)


def descriptors_end(data):
    a = data[256 * S:257 * S]
    if struct.unpack_from('<H', a, 0)[0] != 2:
        raise SystemExit('no anchor at 256')
    mlen, mloc = struct.unpack_from('<II', a, 16)
    rlen, rloc = struct.unpack_from('<II', a, 24)
    end = max(257, mloc + (mlen + S - 1) // S, rloc + (rlen + S - 1) // S)
    for b in range(mloc, mloc + (mlen + S - 1) // S):
        s = data[b * S:(b + 1) * S]
        tid = struct.unpack_from('<H', s, 0)[0]
        if tid == 5:
            start, length = struct.unpack_from('<II', s, 188)
            end = max(end, start + length)
        elif tid == 8:
            break
    return end


def main():
    kind, p1, p2, out = sys.argv[1:5]
    u1 = open(p1, 'rb').read()
    u2 = open(p2, 'rb').read()
    e = descriptors_end(u1)
    cut = u1[:e * S]
    if kind == 'plain':
        img = u1
    elif kind == 'two':
        img = u1 + u2
    elif kind == 'twoabs':
        n = sectors(u1) + sectors(u2)
        last = set_anchor(u2[-S:], n - 1, sectors(u1))
        img = u1 + u2[:-S] + last
    elif kind == 'rest16':
        img = cut + b'\x5a' * (16 * S)
    elif kind == 'rest17':
        img = cut + b'\x5a' * (17 * S)
    elif kind == 'zero100':
        img = u1 + bytes(100 * S)
    elif kind == 'data100':
        img = u1 + b'\x5a' * (100 * S)
    elif kind == 'data256':
        img = u1 + b'\x5a' * (256 * S)
    elif kind == 'zero300':
        img = u1 + bytes(300 * S)
    elif kind == 'anchorrest':
        img = u1[:450 * S] + bytes(S)
    elif kind == 'zero512':
        img = cut + bytes(512 * S)
    elif kind == 'zero513':
        img = cut + bytes(513 * S)
    elif kind == 'zerolate':
        img = cut + bytes(300 * S - 1) + b'\x01'
    elif kind == 'short':
        img = u1[:(e - 10) * S]
    elif kind == 'noanchor':
        img = u1[:256 * S] + bytes(S) + u1[257 * S:]
    elif kind == 'anchor600':
        n = e + 600 + 1
        img = cut + bytes(600 * S) + set_anchor(u1[256 * S:257 * S], n - 1)
    else:
        raise SystemExit('unknown kind ' + kind)
    open(out, 'wb').write(img)
    print(f'{kind}: {len(img)} bytes, {len(img) // S} sectors, descriptors end {e}')


main()
