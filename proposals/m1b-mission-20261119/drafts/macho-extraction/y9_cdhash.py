"""Y9: recompute the embedded CodeDirectory page hashes (format: cs_blobs.h layout, big-endian)."""
import struct, hashlib, sys
def check(data):
    off = None; o = 32
    ncmds = struct.unpack_from("<I", data, 16)[0]
    for _ in range(ncmds):
        cmd, sz = struct.unpack_from("<II", data, o)
        if cmd == 0x1d: off, size = struct.unpack_from("<II", data, o + 8)
        o += sz
    magic, length, count = struct.unpack_from(">III", data, off)
    assert magic == 0xfade0cc0
    for i in range(count):
        typ, boff = struct.unpack_from(">II", data, off + 12 + 8 * i)
        b = off + boff
        if struct.unpack_from(">I", data, b)[0] == 0xfade0c02:
            (mg, ln, ver, flags, hoff, ioff, nspecial, ncode, climit, hsize, htype, plat, pshift) = \
                struct.unpack_from(">IIIIIIIIIBBBB", data, b)
            ps = 1 << pshift; bad = []
            for p in range(ncode):
                pg = data[p * ps: min((p + 1) * ps, climit)]
                want = data[b + hoff + p * hsize: b + hoff + (p + 1) * hsize]
                if hashlib.sha256(pg).digest()[:hsize] != want: bad.append(p)
            return dict(version=hex(ver), flags=hex(flags), ncode=ncode, codeLimit=climit, pagesize=ps,
                        hashType=htype, sig_offset=off, bad_pages=bad, special_slots=nspecial)
if __name__ == "__main__":
    r = check(open(sys.argv[1], "rb").read()); print(r); sys.exit(0 if not r["bad_pages"] else 1)
