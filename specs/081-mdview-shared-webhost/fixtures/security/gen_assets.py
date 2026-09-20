#!/usr/bin/env python3
# SPDX-FileCopyrightText: 2026 Pavel Stupka
# SPDX-License-Identifier: GPL-2.0-or-later
"""Generates the image assets of the 081 security fixture corpus.

Stdlib only (zlib + struct), so the corpus can be regenerated on any machine
with Python 3 and no third-party module -- the same rule the product's other
generators follow (tools/brand/gen_icons.py is the exception: it needs Pillow,
which is why nothing here depends on it).

Outputs:
  assets/dot.png        32x32 solid green  -- the local image of 10-legit-control.md
  assets/datauri.txt    base64 of a 32x32 solid magenta PNG, for the data: URI
"""
import base64
import pathlib
import struct
import zlib

HERE = pathlib.Path(__file__).resolve().parent


def solid_png(width: int, height: int, rgb: tuple[int, int, int]) -> bytes:
    """A minimal, valid 8-bit RGB PNG of one colour."""
    raw = b"".join(b"\x00" + bytes(rgb) * width for _ in range(height))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return (struct.pack(">I", len(data)) + tag + data +
                struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
            chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def main() -> None:
    assets = HERE / "assets"
    assets.mkdir(exist_ok=True)

    dot = solid_png(32, 32, (0x2E, 0xA0, 0x43))  # green
    (assets / "dot.png").write_bytes(dot)

    magenta = solid_png(32, 32, (0xC0, 0x2E, 0xA0))
    b64 = base64.b64encode(magenta).decode("ascii")
    (assets / "datauri.txt").write_text(
        "data:image/png;base64," + b64 + "\n", encoding="utf-8")

    print(f"dot.png      {len(dot)} bytes (32x32 green)")
    print(f"datauri.txt  {len(b64)} base64 chars (32x32 magenta)")


if __name__ == "__main__":
    main()
