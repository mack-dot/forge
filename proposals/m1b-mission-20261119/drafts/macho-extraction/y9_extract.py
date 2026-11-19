#!/usr/bin/env python3 -I
"""Y9: locate the CakeML code and bitmap slices by symbols, hash them, compare.

Usage: python3 -I y9_extract.py <macho> <refund.S> <parser_dir>
Prints a JSON result. Exit 0 only if every comparison is equal.
"""
import sys, hashlib, json, re, struct
sys.path.insert(0, sys.argv[3])
import y9_macho as M

EXPECT = {  # first-extraction values (recorded OUTPUTS only: unsure.md U389, image-0001 stdout, manifest draft)
    "file_sha256": "b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8",
    "file_size": 238776,
    "code": dict(offset=16592, length=130436,
                 sha256="3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb"),
    "bitmaps": dict(offset=180248, length=20248, words=2531,
                    sha256="68d3f080066fdaeb12ff1c061a875b1502172be0857a2af02f77f6f18f36fb76"),
    "stub": dict(offset=16384, length=108),
    "hol_samples": dict(code0=126, code4=222, data0=4, data1=16),
    "layout_lengths": [16384, 108, 100, 130436, 16812, 16408, 20248],
    "macho_fields": {0: (4, 4277009103), 12: (4, 2), 16: (4, 18), 24: (4, 2097285), 104: (4, 25),
                     128: (8, 4294967296), 136: (8, 163840), 144: (8, 0), 152: (8, 163840),
                     164: (4, 5), 648: (4, 25), 672: (8, 4295147520), 680: (8, 32768),
                     688: (8, 180224), 696: (8, 32768), 708: (4, 3), 1192: (4, 2147483688),
                     1200: (8, 152900)},
}


def sym(m, name):
    r = [s for s in m["symbols"] if s["name"] == name and not s["undef"]]
    assert len(r) == 1, (name, r)
    return r[0]["value"]


def locate(data):
    m = M.parse(data)
    segs = [c["segment"] for c in m["load_commands"] if "segment" in c]
    f = lambda a: M.vm_to_file(segs, a)
    code_lo, code_hi = sym(m, "cake_main"), sym(m, "_cake_codebuffer_begin")
    bm_lo, bm_hi = sym(m, "cake_bitmaps"), sym(m, "_cake_bitmaps_buffer_begin")
    stub_lo = sym(m, "_cml_main")
    return m, segs, dict(
        code=dict(offset=f(code_lo), length=code_hi - code_lo, vm=code_lo),
        bitmaps=dict(offset=f(bm_lo), length=bm_hi - bm_lo, vm=bm_lo),
        stub=dict(offset=f(stub_lo), length=sym(m, "cake_ffiopen_in") - stub_lo - 4, vm=stub_lo))


def parse_S(path):
    code, quads, mode = bytearray(), [], None
    for line in open(path, encoding="ascii", errors="replace"):
        t = line.strip()
        if t.startswith("cake_bitmaps:"):
            mode = "bm"
        elif t.startswith("cdecl(cake_bitmaps_buffer_begin)"):
            mode = None
        elif t.startswith("cake_main:"):
            mode = "code"
        elif t.startswith("cdecl(cake_codebuffer_begin)"):
            mode = None
        elif t.startswith(".quad") and mode == "bm":
            quads += [int(x, 0) for x in t[5:].split(",")]
        elif t.startswith(".byte") and mode == "code":
            code += bytes(int(x, 0) for x in t[5:].split(","))
    return bytes(code), quads


def compare(data, S):
    res, ok = {}, True
    m, segs, loc = locate(data)
    res["file"] = dict(size=len(data), sha256=hashlib.sha256(data).hexdigest())
    ok &= res["file"]["sha256"] == EXPECT["file_sha256"] and len(data) == EXPECT["file_size"]
    for k in ("code", "bitmaps"):
        L = loc[k]
        sl = data[L["offset"]:L["offset"] + L["length"]]
        L["sha256"] = hashlib.sha256(sl).hexdigest()
        e = EXPECT[k]
        L["eq_offset"] = L["offset"] == e["offset"]
        L["eq_length"] = L["length"] == e["length"]
        L["eq_sha256"] = L["sha256"] == e["sha256"]
        ok &= L["eq_offset"] and L["eq_length"] and L["eq_sha256"]
        res[k] = L
    bm = data[loc["bitmaps"]["offset"]:loc["bitmaps"]["offset"] + loc["bitmaps"]["length"]]
    words = list(struct.unpack("<%dQ" % (len(bm) // 8), bm))
    res["bitmaps"]["words"] = len(words)
    ok &= len(bm) % 8 == 0 and len(words) == EXPECT["bitmaps"]["words"]
    code = data[loc["code"]["offset"]:loc["code"]["offset"] + loc["code"]["length"]]
    hs = EXPECT["hol_samples"]
    res["hol_samples_eq"] = code[0] == hs["code0"] and code[4] == hs["code4"] and \
        words[0] == hs["data0"] and words[1] == hs["data1"]
    ok &= res["hol_samples_eq"]
    res["stub"] = loc["stub"]
    ok &= loc["stub"]["offset"] == EXPECT["stub"]["offset"] and loc["stub"]["length"] == EXPECT["stub"]["length"]
    # macho field values recorded in refund_macho_fields
    mf = {}
    for o, (n, v) in EXPECT["macho_fields"].items():
        mine = int.from_bytes(data[o:o + n], "little")
        mf[o] = mine == v
    res["macho_fields_all_eq"] = all(mf.values())
    ok &= res["macho_fields_all_eq"]
    # layout lengths: P STUB Q code T2 M bitmaps E
    text_end = segs[1]["fileoff"] + segs[1]["filesize"]
    mine_layout = [loc["stub"]["offset"], loc["stub"]["length"],
                   loc["code"]["offset"] - (loc["stub"]["offset"] + loc["stub"]["length"]),
                   loc["code"]["length"], text_end - (loc["code"]["offset"] + loc["code"]["length"]),
                   loc["bitmaps"]["offset"] - text_end, loc["bitmaps"]["length"]]
    res["layout_lengths"] = mine_layout
    res["layout_eq"] = mine_layout == EXPECT["layout_lengths"]
    ok &= res["layout_eq"]
    # refund.S as a third source (compiler text output)
    if S:
        scode, squads = parse_S(S)
        res["S"] = dict(code_len=len(scode), code_eq=scode == code, quads=len(squads), quads_eq=squads == words,
                        code_sha256=hashlib.sha256(scode).hexdigest())
        ok &= res["S"]["code_eq"] and res["S"]["quads_eq"]
    res["ALL_EQUAL"] = bool(ok)
    return res


if __name__ == "__main__":
    data = open(sys.argv[1], "rb").read()
    S = sys.argv[2] if len(sys.argv) > 2 and sys.argv[2] != "-" else None
    r = compare(data, S)
    print(json.dumps(r, indent=1))
    sys.exit(0 if r["ALL_EQUAL"] else 1)
