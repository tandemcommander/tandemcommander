"""make_bigdict.py - feature 087, FR-015 / contract P5.

Writes copies of a RAR5 archive whose first file header declares a larger
dictionary (window) than the data was made with. The RAR5 handler asks the
memory callback only for a dictionary above 1 GiB (Rar5Handler.cpp:2974), so
the bound cannot be exercised with ordinary fixtures.

    python make_bigdict.py <source.rar5> <out-dir>

Output:
    dict2g.rar    algorithm 0 (RAR5), N=14 -> 2 GiB   (within the default bound)
    dict128g.rar  algorithm 1 (RAR7), N=20 -> 128 GiB (above any bound)

Only the compression-information field of the header is rewritten; the
header-size field and the header CRC32 are recomputed, the data area is
copied unchanged. Field layout: RAR 5.0 archive format, "File header".
"""
import os
import sys
import zlib

SIG = b"Rar!\x1a\x07\x01\x00"


def read_vint(b, i):
    v = 0
    shift = 0
    while True:
        c = b[i]
        i += 1
        v |= (c & 0x7F) << shift
        shift += 7
        if not c & 0x80:
            return v, i


def vint(v):
    out = bytearray()
    while True:
        c = v & 0x7F
        v >>= 7
        if v:
            out.append(c | 0x80)
        else:
            out.append(c)
            return bytes(out)


def rewrite(data, algo, n):
    assert data.startswith(SIG), "not a RAR5 archive"
    i = len(SIG)
    while i < len(data):
        start = i
        i += 4  # header CRC32
        size, body = read_vint(data, i)
        end = body + size
        htype, j = read_vint(data, body)
        hflags, j = read_vint(data, j)
        datasize = 0
        if hflags & 1:
            _, j = read_vint(data, j)  # extra area size
        if hflags & 2:
            datasize, j = read_vint(data, j)
        if htype == 2:  # file header
            fflags, j = read_vint(data, j)
            _, j = read_vint(data, j)  # unpacked size
            _, j = read_vint(data, j)  # attributes
            if fflags & 2:
                j += 4  # mtime
            if fflags & 4:
                j += 4  # data CRC32
            ci_pos = j
            ci, j = read_vint(data, j)
            method = (ci >> 7) & 7
            assert method != 0, "the first file is stored, not compressed"
            new_ci = (ci & ~0x3F & ~(0x1F << 10) & ~(0x1F << 15)) | algo | (n << 10)
            new_body = data[body:ci_pos] + vint(new_ci) + data[j:end]
            new_size = vint(len(new_body))
            crc = zlib.crc32(new_size + new_body) & 0xFFFFFFFF
            header = crc.to_bytes(4, "little") + new_size + new_body
            return data[:start] + header + data[end:]
        i = end + datasize
    raise SystemExit("no file header found")


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    src = open(sys.argv[1], "rb").read()
    os.makedirs(sys.argv[2], exist_ok=True)
    for name, algo, n in (("dict2g.rar", 0, 14), ("dict128g.rar", 1, 20)):
        with open(os.path.join(sys.argv[2], name), "wb") as f:
            f.write(rewrite(src, algo, n))
    return 0


if __name__ == "__main__":
    sys.exit(main())
