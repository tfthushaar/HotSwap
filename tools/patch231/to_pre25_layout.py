"""Rewrites a script cache built by the 2.5 compiler into the layout used before patch 2.5.

Since 2.5 the cache sets header flag 0x2, puts a 7th table header (12 bytes) right after the
104-byte header, and stores that 7th table (one 12-byte record per definition) after the strings
table, ahead of the definition bodies. Both are removed here and every absolute offset is moved back
by the bytes removed in front of it. The game's own header hash is kept, since redscript uses it to
tell an original cache from one it wrote. usage: to_pre25_layout.py <in> <out>
"""
import struct
import sys
import zlib

HEADER = 104
TABLES = ["data", "names", "tweakdb", "resources", "definitions", "strings"]
ENTRY = {"data": 1, "names": 4, "tweakdb": 4, "resources": 4, "definitions": 20, "strings": 4}

src = open(sys.argv[1], "rb").read()
magic, version, flags = struct.unpack_from("<III", src, 0)
assert magic == 0x53444552, "not a script cache"
assert flags & 0x2, "already in the pre-2.5 layout"

tables = {name: list(struct.unpack_from("<III", src, 32 + i * 12)) for i, name in enumerate(TABLES)}
extra_off, extra_count, extra_hash = struct.unpack_from("<III", src, HEADER)
extra_end = extra_off + extra_count * 12

# The stored hashes are CRC32s of each table's bytes; matching them confirms the entry sizes.
for name, (off, count, h) in tables.items():
    ok = (zlib.crc32(src[off:off + count * ENTRY[name]]) & 0xFFFFFFFF) == h
    print(f"  {name:12} offset {off:>9} count {count:>7} crc {'ok' if ok else 'DIFFERS'}")
    assert ok
assert (zlib.crc32(src[extra_off:extra_end]) & 0xFFFFFFFF) == extra_hash, "7th table crc"
s_off, s_count, _ = tables["strings"]
assert extra_off == s_off + s_count * ENTRY["strings"], "7th table expected right after strings"

cuts = [(HEADER, HEADER + 12), (extra_off, extra_end)]


def moved(offset):
    return offset - sum(end - start for start, end in cuts if end <= offset)


out = bytearray(src[:HEADER] + src[HEADER + 12:extra_off] + src[extra_end:])
struct.pack_into("<I", out, 8, flags & ~0x2)
for i, name in enumerate(TABLES):
    tables[name][0] = moved(tables[name][0])
    struct.pack_into("<I", out, 32 + i * 12, tables[name][0])

d_off, d_count, _ = tables["definitions"]
n = 0
for i in range(d_count):
    pos = d_off + i * ENTRY["definitions"] + 8
    body = struct.unpack_from("<I", out, pos)[0]
    if body:
        assert body >= extra_end, "a definition body sits before the 7th table"
        struct.pack_into("<I", out, pos, moved(body))
        n += 1

for i, name in enumerate(TABLES):
    off, count, _ = tables[name]
    struct.pack_into("<I", out, 32 + i * 12 + 8, zlib.crc32(out[off:off + count * ENTRY[name]]) & 0xFFFFFFFF)

open(sys.argv[2], "wb").write(out)
print(f"  {len(src)} -> {len(out)} bytes; {n} definition bodies moved; flags 0x{flags:X} -> 0x{flags & ~0x2:X}")
