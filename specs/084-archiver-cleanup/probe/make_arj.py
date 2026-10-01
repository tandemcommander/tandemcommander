"""Generate a small stored-method ARJ archive for feature 084 fixtures.

ARJ cannot be created by 7-Zip and libarchive has no ARJ test data, so this
writes the format directly (ARJ technical note: main header, file headers,
method 0 = stored, CRC-32 over each basic header and over the file data).
Names are stored in the OEM code page 852 the way an MS-DOS ARJ would.

Usage: python make_arj.py <output.arj>
"""

import struct
import sys
import zlib

SIG = b"\x60\xea"


def dos_datetime(y, mo, d, h, mi, s):
    date = ((y - 1980) << 9) | (mo << 5) | d
    time = (h << 11) | (mi << 5) | (s // 2)
    return (date << 16) | time


def block(file_type, name, data=b"", attr=0x20, stamp=None):
    stamp = stamp if stamp is not None else dos_datetime(2026, 10, 1, 12, 0, 0)
    crc = zlib.crc32(data) & 0xFFFFFFFF
    first = struct.pack(
        "<BBBBBBBBIIIIHHH",
        30,  # first_hdr_size
        11,  # archiver version
        1,  # minimum version to extract
        0,  # host OS: MS-DOS
        0,  # ARJ flags
        0,  # method: stored
        file_type,
        0,  # reserved
        stamp,
        len(data),  # compressed size
        len(data),  # original size
        crc,
        0,  # filespec position in filename
        attr,  # file access mode
        0,  # host data
    )
    assert len(first) == 30
    basic = first + name + b"\x00" + b"\x00"  # filename, empty comment
    hdr = SIG + struct.pack("<H", len(basic)) + basic
    hdr += struct.pack("<I", zlib.crc32(basic) & 0xFFFFFFFF)
    hdr += struct.pack("<H", 0)  # no extended header
    return hdr + data


def main(out):
    entries = [
        (b"readme.txt", b"Plain ASCII file inside an ARJ archive.\r\n"),
        ("Příliš žluťoučký kůň.txt".encode("cp852"), "Czech name, OEM 852.\r\n".encode("ascii")),
        (b"sub dir\\inner.txt", b"File in a sub-directory with a space.\r\n"),
        (b"empty.txt", b""),
    ]
    blob = block(2, b"sample.arj")  # main header (file type 2)
    for name, data in entries:
        blob += block(0, name, data)
    blob += SIG + b"\x00\x00"  # end of archive
    with open(out, "wb") as f:
        f.write(blob)


if __name__ == "__main__":
    main(sys.argv[1])
