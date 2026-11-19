#!/usr/bin/env python3
# b-export-bridge controls on the export BYTES (not on the table). Writes into mutants/.
#  D1-byte-flip.sexp : one byte changed ("Le" -> "Lt" in the first Le); the digest check must refuse it.
#  RA-reject-all.sexp: clause 1 replaced by (UnOp (Not) (Var "authorized")), i.e. "authorized is always false".
import sys
src, outdir = sys.argv[1], sys.argv[2]
data = open(src, "rb").read()
i = data.index(b"(Le)")
open(outdir + "/D1-byte-flip.sexp", "wb").write(data[:i] + b"(Lt)" + data[i + 4:])
start = data.index(b"((BinOp (Eq) (Var \"authorized\")") + 1
depth, j = 0, start
while True:
    c = data[j:j + 1]
    if c == b"(":
        depth += 1
    elif c == b")":
        depth -= 1
        if depth == 0:
            break
    j += 1
ra = data[:start] + b"(UnOp (Not) (Var \"authorized\"))" + data[j + 1:]
open(outdir + "/RA-reject-all.sexp", "wb").write(ra)
print("ok", len(data), i, start, j)
