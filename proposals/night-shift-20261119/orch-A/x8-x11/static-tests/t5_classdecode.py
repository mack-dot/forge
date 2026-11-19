#!/usr/bin/env python3
"""T5 method (ii-b): disassembler-free A64 class decoder for the code slice.

For every word: match the A64 encoding class from fixed opcode bits (ARM ARM C4.1 tables), list the
fields that are REGISTER fields for that class, and flag the word if one of them equals 18, or if a
base/destination register field equals 31 in a class where 31 means SP. Unknown classes are listed.
Usage: python3 -I t5_classdecode.py <executable copy> <out json>
"""
import hashlib, json, struct, sys
from collections import Counter

EXE, OUT = sys.argv[1:3]
OFF, LEN, VM = 16592, 130436, 0x1000040D0
data = open(EXE, "rb").read()
sl = data[OFF:OFF + LEN]
words = struct.unpack("<%dI" % (LEN // 4), sl)
Rd = lambda w: w & 31
Rn = lambda w: (w >> 5) & 31
Ra = lambda w: (w >> 10) & 31
Rm = lambda w: (w >> 16) & 31

# (name, mask, value, register-field getters, fields where 31 = SP)
CLASSES = [
    ("B/BL", 0x7C000000, 0x14000000, [], []),
    ("B.cond", 0xFF000010, 0x54000000, [], []),
    ("CBZ/CBNZ", 0x7E000000, 0x34000000, [Rd], []),
    ("TBZ/TBNZ", 0x7E000000, 0x36000000, [Rd], []),
    ("BR/BLR/RET(unpac)", 0xFF9FFC1F, 0xD61F0000, [Rn], []),
    ("ADR/ADRP", 0x1F000000, 0x10000000, [Rd], []),
    ("ADD/SUB imm", 0x1F000000, 0x11000000, [Rd, Rn], ["Rn", "Rd_unless_S"]),
    ("logical imm", 0x1F800000, 0x12000000, [Rd, Rn], ["Rd_unless_S"]),
    ("MOVN/MOVZ/MOVK", 0x1F800000, 0x12800000, [Rd], []),
    ("bitfield (LSL/LSR/ASR imm)", 0x1F800000, 0x13000000, [Rd, Rn], []),
    ("EXTR (ROR imm)", 0x1FA00000, 0x13800000, [Rd, Rn, Rm], []),
    ("logical shifted reg", 0x1F000000, 0x0A000000, [Rd, Rn, Rm], []),
    ("ADD/SUB shifted reg", 0x1F200000, 0x0B000000, [Rd, Rn, Rm], []),
    ("ADD/SUB extended reg", 0x1F200000, 0x0B200000, [Rd, Rn, Rm], ["Rn", "Rd_unless_S"]),
    ("ADC/SBC", 0x1FE0FC00, 0x1A000000, [Rd, Rn, Rm], []),
    ("cond compare reg", 0x1FE00C10, 0x1A400000, [Rn, Rm], []),
    ("cond compare imm", 0x1FE00C10, 0x1A400800, [Rn], []),
    ("cond select (CSET/CSINC)", 0x1FE00800, 0x1A800000, [Rd, Rn, Rm], []),
    ("data-proc 2 src (SDIV/LSLV..)", 0x5FE00000, 0x1AC00000, [Rd, Rn, Rm], []),
    ("data-proc 3 src (MUL/MSUB/SMULH)", 0x1F000000, 0x1B000000, [Rd, Rn, Rm, Ra], []),
    ("LD/ST unscaled imm (LDUR/STUR)", 0x3B200C00, 0x38000000, [Rd, Rn], ["Rn"]),
    ("LD/ST imm post-index", 0x3B200C00, 0x38000400, [Rd, Rn], ["Rn"]),
    ("LD/ST imm pre-index", 0x3B200C00, 0x38000C00, [Rd, Rn], ["Rn"]),
    ("LD/ST register offset", 0x3B200C00, 0x38200800, [Rd, Rn, Rm], ["Rn"]),
    ("LD/ST unsigned imm (LDR/STR)", 0x3B000000, 0x39000000, [Rd, Rn], ["Rn"]),
    ("LDR literal", 0x3B000000, 0x18000000, [Rd], []),
]
cls_count, unknown, hits18, sp_hits, multi = Counter(), [], [], [], []
for i, w in enumerate(words):
    a = VM + 4 * i
    m = [c for c in CLASSES if (w & c[1]) == c[2]]
    if len(m) != 1:
        (unknown if not m else multi).append({"addr": hex(a), "word": "%08x" % w, "classes": [c[0] for c in m]})
        if not m:
            continue
    name, _, _, regs, spf = m[0]
    if name.startswith("LD/ST") and (w >> 26) & 1:
        unknown.append({"addr": hex(a), "word": "%08x" % w, "classes": ["SIMD/FP load-store"]})
        continue
    cls_count[name] += 1
    vals = [g(w) for g in regs]
    if 18 in vals:
        hits18.append({"addr": hex(a), "word": "%08x" % w, "class": name})
    S = (w >> 29) & 1
    if ("Rn" in spf and Rn(w) == 31) or ("Rd_unless_S" in spf and S == 0 and Rd(w) == 31):
        sp_hits.append({"addr": hex(a), "word": "%08x" % w, "class": name})
res = {"slice_sha256": hashlib.sha256(sl).hexdigest(), "words": len(words),
       "class_counts": dict(cls_count.most_common()), "unknown_class_words": unknown,
       "ambiguous_class_words": multi, "register_field_eq_18": hits18, "sp_register_uses": sp_hits}
json.dump(res, open(OUT, "w"), indent=1)
print(json.dumps({"words": len(words), "classified": sum(cls_count.values()), "unknown": len(unknown),
                  "ambiguous": len(multi), "reg18": len(hits18), "sp": len(sp_hits),
                  "class_counts": res["class_counts"]}, indent=1))
