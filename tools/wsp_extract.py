"""Extract a Synchrony .wsp / .necromod package (format "WSP1").

Layout (worked out from the small dlc/*.necromod files):
  "WSP1" | u32 count | u8 flags | count x (u16 len, name) | count x u64 record offset
  record: u16 len, name | u8 unknown | u8 method | u32 stored size | [u32 raw size if method != 0] | data
  method 0 = stored, 1 = zlib, other methods are reported and dumped raw.

Usage: python tools/wsp_extract.py PACKAGE OUTDIR [--list]
"""
import os
import struct
import sys
import zlib


def read_package(path):
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"WSP1":
        raise ValueError(f"{path}: not a WSP1 package")
    count = struct.unpack_from("<I", data, 4)[0]
    pos = 9
    names = []
    for _ in range(count):
        n = struct.unpack_from("<H", data, pos)[0]
        names.append(data[pos + 2:pos + 2 + n].decode("utf-8"))
        pos += 2 + n
    offsets = struct.unpack_from(f"<{count}Q", data, pos)
    for name, off in zip(names, offsets):
        n = struct.unpack_from("<H", data, off)[0]
        rname = data[off + 2:off + 2 + n].decode("utf-8")
        p = off + 2 + n
        unk, method = data[p], data[p + 1]
        size = struct.unpack_from("<I", data, p + 2)[0]
        p += 6
        raw = None
        if method != 0:
            raw = struct.unpack_from("<I", data, p)[0]
            p += 4
        blob = data[p:p + size]
        yield rname, unk, method, size, raw, blob
        if rname != name:
            print(f"warning: directory name {name!r} != record name {rname!r}", file=sys.stderr)


def main():
    pkg, out = sys.argv[1], sys.argv[2]
    list_only = "--list" in sys.argv
    methods = {}
    for name, unk, method, size, raw, blob in read_package(pkg):
        methods[method] = methods.get(method, 0) + 1
        if list_only:
            print(f"{method} {unk} {size:>9} {raw or size:>9} {name}")
            continue
        if method == 0:
            content = blob
        elif method == 1:
            content = zlib.decompress(blob)
        else:
            content = blob
            name += f".method{method}"
        dest = os.path.join(out, *name.split("/"))
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        with open(dest, "wb") as f:
            f.write(content)
    print("methods:", methods, file=sys.stderr)


if __name__ == "__main__":
    main()
