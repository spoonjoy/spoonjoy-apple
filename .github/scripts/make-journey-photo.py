#!/usr/bin/env python3
"""Writes the small gradient PNG the recipe journey picks as a recipe photo: make-journey-photo.py OUT.png"""
import struct
import sys
import zlib

WIDTH, HEIGHT = 320, 240


def chunk(kind: bytes, data: bytes) -> bytes:
    body = kind + data
    return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


rows = b"".join(
    b"\x00" + b"".join(bytes((230 - x // 4, 120 + y // 3, 60 + x // 3)) for x in range(WIDTH))
    for y in range(HEIGHT)
)
png = (
    b"\x89PNG\r\n\x1a\n"
    + chunk(b"IHDR", struct.pack(">IIBBBBB", WIDTH, HEIGHT, 8, 2, 0, 0, 0))
    + chunk(b"IDAT", zlib.compress(rows))
    + chunk(b"IEND", b"")
)
with open(sys.argv[1], "wb") as out:
    out.write(png)
