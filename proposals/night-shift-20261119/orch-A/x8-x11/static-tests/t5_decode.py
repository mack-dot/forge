#!/usr/bin/env python3
"""T5 static decode of the proved CakeML code slice (read-only; never executes the file).

Usage: python3 -I t5_decode.py <executable copy> <llvm-objdump slice listing> <otool -tV listing> <out dir>
Method (ii): conservative 5-bit field scan (Rd[4:0], Rn[9:5], Ra/Rt2[14:10], Rm[20:16]) of every word,
then classification of flagged words with the two disassembler listings (method i).
"""
import hashlib, json, re, struct, sys
from collections import Counter

EXE, LLVM, OTOOL, OUT = sys.argv[1:5]
OFF, LEN, VM = 16592, 130436, 0x1000040D0
EXP_SLICE = "3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb"

data = open(EXE, "rb").read()
sl = data[OFF:OFF + LEN]
res = {"file_sha256": hashlib.sha256(data).hexdigest(), "slice_offset": OFF, "slice_length": LEN,
       "slice_vm_start": hex(VM), "slice_vm_end_excl": hex(VM + LEN)}
res["slice_sha256"] = hashlib.sha256(sl).hexdigest()
res["slice_sha256_ok"] = res["slice_sha256"] == EXP_SLICE
assert LEN % 4 == 0
words = struct.unpack("<%dI" % (LEN // 4), sl)
res["words"] = len(words)

# ---- method (i): parse the two disassembly listings -------------------------------------------
line_re = re.compile(r"^\s*([0-9a-f]+):\s+([0-9a-f]{8})\s+(.*)$")
llvm = {}
for ln in open(LLVM):
    m = line_re.match(ln)
    if m:
        a = int(m.group(1), 16)
        if VM <= a < VM + LEN:
            llvm[a] = (int(m.group(2), 16), m.group(3).split("//")[0].strip())
otre = re.compile(r"^([0-9a-f]{16})\s+([0-9a-f]{8})\s+(.*)$")
otl = {}
for ln in open(OTOOL):
    m = otre.match(ln)
    if m:
        a = int(m.group(1), 16)
        if VM <= a < VM + LEN:
            otl[a] = (int(m.group(2), 16), m.group(3).split(";")[0].strip())
res["llvm_lines_in_slice"] = len(llvm)
res["otool_lines_in_slice"] = len(otl)
mism_word = []
for i, w in enumerate(words):
    a = VM + 4 * i
    for name, d in (("llvm", llvm), ("otool", otl)):
        if a not in d:
            mism_word.append((name, hex(a), "missing"))
        elif d[a][0] != w:
            mism_word.append((name, hex(a), "word differs"))
res["listing_vs_file_mismatches"] = mism_word[:20]
res["listing_vs_file_mismatch_count"] = len(mism_word)

tok18 = re.compile(r"\b[xw]18\b")
def mnem(t): return t.split()[0] if t.split() else "<empty>"
def ops(t): return t[len(mnem(t)):].strip()
DATA_RE = re.compile(r"^(\.long|\.word|udf|<unknown>|invalid)", re.I)

# ---- method (ii): conservative field scan -----------------------------------------------------
fields = lambda w: {"Rd": w & 31, "Rn": (w >> 5) & 31, "Ra_Rt2": (w >> 10) & 31, "Rm": (w >> 16) & 31}
flagged, real18, notreg = [], [], []
for i, w in enumerate(words):
    a = VM + 4 * i
    f = fields(w)
    hit = [k for k, v in f.items() if v == 18]
    lt = llvm.get(a, (None, ""))[1]
    ot = otl.get(a, (None, ""))[1]
    names_l = bool(tok18.search(ops(lt)))
    names_o = bool(tok18.search(ops(ot)))
    if names_l or names_o:
        real18.append({"addr": hex(a), "word": "%08x" % w, "llvm": lt, "otool": ot, "fields18": hit})
    if hit:
        flagged.append(a)
        if not (names_l or names_o):
            notreg.append({"addr": hex(a), "word": "%08x" % w, "fields18": hit, "llvm": lt, "otool": ot})
res["conservative_flagged_words"] = len(flagged)
res["flagged_field_counts"] = dict(Counter(k for a in flagged for k, v in fields(words[(a - VM) // 4]).items() if v == 18))
res["words_really_naming_x18_w18"] = len(real18)
res["real_x18_list"] = real18
res["real_x18_not_flagged_by_field_scan"] = [r for r in real18 if not r["fields18"]]
res["flagged_but_not_register"] = len(notreg)
res["examples_flagged_not_register"] = notreg[:10]
res["examples_really_x18"] = real18[:10]

# ---- data words / histogram / special classes -------------------------------------------------
hist_l = Counter(mnem(llvm[a][1]) for a in llvm)
hist_o = Counter(mnem(otl[a][1]) for a in otl)
res["data_or_invalid_words_llvm"] = [{"addr": hex(a), "text": t} for a, (w, t) in sorted(llvm.items()) if DATA_RE.match(t)]
res["data_or_invalid_words_otool"] = [{"addr": hex(a), "text": t} for a, (w, t) in sorted(otl.items()) if DATA_RE.match(t)]
SPECIAL = re.compile(r"^(mrs|msr|svc|hvc|smc|eret|brk|hlt|udf|bti|pac\w*|aut\w*|xpac\w*|retaa|retab|bra\w*|blra\w*|"
                     r"ldxr\w*|stxr\w*|ldaxr\w*|stlxr\w*|ldar\w*|stlr\w*|cas\w*|ldadd\w*|swp\w*|dmb|dsb|isb|hint|"
                     r"sys|sysl|clrex|wfi|wfe|sev\w*|yield|ldp|stp|ldpsw)$")
res["special_mnemonics_llvm"] = {k: v for k, v in hist_l.items() if SPECIAL.match(k)}
res["special_mnemonics_otool"] = {k: v for k, v in hist_o.items() if SPECIAL.match(k)}
res["ret_variants_llvm"] = {k: v for k, v in hist_l.items() if k.startswith("ret")}
res["br_blr_llvm"] = {k: v for k, v in hist_l.items() if k in ("br", "blr")}
sp_re = re.compile(r"\b(w?sp)\b")
sp_words = [{"addr": hex(a), "word": "%08x" % w, "text": t} for a, (w, t) in sorted(llvm.items()) if sp_re.search(ops(t))]
res["sp_operand_words_llvm"] = len(sp_words)
res["sp_operand_examples"] = sp_words[:20]
sp_o = [a for a, (w, t) in otl.items() if sp_re.search(ops(t))]
res["sp_operand_words_otool"] = len(sp_o)
x31_hist = Counter()
res["mnemonic_kinds_llvm"] = len(hist_l)
res["mnemonic_kinds_otool"] = len(hist_o)
# text agreement between the two disassemblers (mnemonic level)
mn_diff = [hex(a) for a in llvm if a in otl and mnem(llvm[a][1]) != mnem(otl[a][1])]
res["mnemonic_disagreements_llvm_vs_otool"] = len(mn_diff)
res["mnemonic_disagreement_examples"] = [(a, llvm[int(a, 16)][1], otl[int(a, 16)][1]) for a in mn_diff[:10]]

with open(OUT + "/t5_mnemonic_histogram.txt", "w") as fh:
    fh.write("# mnemonic histogram of the code slice [0x%x,0x%x), llvm-objdump | otool -tV\n" % (VM, VM + LEN))
    for k in sorted(set(hist_l) | set(hist_o), key=lambda k: -hist_l.get(k, 0)):
        fh.write("%-10s %7d %7d\n" % (k, hist_l.get(k, 0), hist_o.get(k, 0)))
with open(OUT + "/t5_flagged_words.tsv", "w") as fh:
    fh.write("addr\tword\tfields_eq_18\tllvm\totool\n")
    for a in flagged:
        w = words[(a - VM) // 4]
        hit = ",".join(k for k, v in fields(w).items() if v == 18)
        fh.write("%x\t%08x\t%s\t%s\t%s\n" % (a, w, hit, llvm.get(a, (0, ""))[1], otl.get(a, (0, ""))[1]))
with open(OUT + "/t5_sp_words.tsv", "w") as fh:
    for r in sp_words:
        fh.write("%s\t%s\t%s\n" % (r["addr"], r["word"], r["text"]))
json.dump(res, open(OUT + "/t5_result.json", "w"), indent=1)
print(json.dumps({k: res[k] for k in ("slice_sha256_ok", "words", "llvm_lines_in_slice", "otool_lines_in_slice",
      "listing_vs_file_mismatch_count", "conservative_flagged_words", "flagged_field_counts",
      "words_really_naming_x18_w18", "flagged_but_not_register", "special_mnemonics_llvm",
      "special_mnemonics_otool", "ret_variants_llvm", "br_blr_llvm", "sp_operand_words_llvm",
      "sp_operand_words_otool", "mnemonic_disagreements_llvm_vs_otool")}, indent=1))
print("data_llvm", len(res["data_or_invalid_words_llvm"]), "data_otool", len(res["data_or_invalid_words_otool"]))
