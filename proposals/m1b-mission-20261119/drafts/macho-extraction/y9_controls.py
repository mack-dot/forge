import sys, hashlib, json
sys.path.insert(0, sys.argv[3])
import y9_extract as X, y9_cdhash as C
orig = open(sys.argv[1], "rb").read(); S = sys.argv[2]
cases = {"code+1000 (in code slice)": 16592 + 1000, "bitmaps+800 (in bitmap slice)": 180248 + 800,
         "GOT entry _write (outside)": 164016, "_main C code (outside)": 152900,
         "__data pad after bitmaps (outside)": 200500, "LINKEDIT string table (outside)": 225272 + 100,
         "code signature blob (outside)": 236800 + 2000 - 100, "cml_main stub (outside both slices, in HOL __TEXT)": 16384 + 8}
out = {}
for name, off in cases.items():
    d = bytearray(orig); d[off] ^= 0x01; d = bytes(d)
    open("copy.bin", "wb").write(d)  # a COPY in the scratch folder
    try:
        r = X.compare(d, S); slices = (r["code"]["eq_sha256"], r["bitmaps"]["eq_sha256"]); allc = r["ALL_EQUAL"]
    except Exception as e:
        slices, allc = ("parse error: %r" % e,), False
    cd = C.check(d)
    out[name] = dict(offset=off, code_slice_eq=slices[0], bitmap_slice_eq=slices[-1] if len(slices) > 1 else None,
                     all_y9_checks_eq=allc, file_sha_eq=hashlib.sha256(d).hexdigest() == X.EXPECT["file_sha256"],
                     cd_bad_pages=cd["bad_pages"])
print(json.dumps(out, indent=1))
