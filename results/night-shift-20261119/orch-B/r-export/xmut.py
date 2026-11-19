#!/usr/bin/env python3
# r-export (adversarial review of b-export-bridge). Semantic mutants of the EXPORT BYTES (not of the table).
# Each mutant: list of (old, new, scope) with scope "ens" (inside the ensures list only, first occurrence),
# "decl" (inside the input/output declaration lists only) or "all" (every occurrence in the file).
# Usage: xmut.py EXPORT OUTDIR
import sys, hashlib
src, outdir = sys.argv[1], sys.argv[2]
data = open(src, "rb").read().decode("ascii")
ENS_START = data.index('(StrT))) () (') + len('(StrT))) () (')
ENS_END = data.index(') () ((Var "chargeId")')
DECL_IN_END = ENS_START
OUT_START = data.index('(("authorized" (BoolT))')
OUT_END = data.index(') () (Then')

def ens(old, new):
    return [("ens", old, new)]

M = {
 "X01-Le-to-Lt-token": ens('(BinOp (Le) (Lit (IntL 0)) (Var "original"))', '(BinOp (Lt) (Lit (IntL 0)) (Var "original"))'),
 "X02-0le-original-to-0lt": ens('(BinOp (Le) (Lit (IntL 0)) (Var "original"))',
                                '(UnOp (Not) (BinOp (Le) (Var "original") (Lit (IntL 0))))'),
 "X03-maxint-minus1": ens('(IntL 9223372036854775807)', '(IntL 9223372036854775806)'),
 "X04-reason-literal": ens('(StrL "returned_item")', '(StrL "returned_items")'),
 "X05-swap-le-operands": ens('(BinOp (Le) (Var "remaining") (Var "original"))', '(BinOp (Le) (Var "original") (Var "remaining"))'),
 "X06-drop-0le-amount": ens('(BinOp (And) (BinOp (Le) (Lit (IntL 0)) (Var "amount")) (BinOp (Le) (Var "amount") (Var "remaining")))',
                            '(BinOp (Le) (Var "amount") (Var "remaining"))'),
 "X07-drop-request-nonempty": ens('(BinOp (And) (BinOp (Neq) (Var "chargeId") (Lit (StrL ""))) (BinOp (Neq) (Var "requestId") (Lit (StrL ""))))',
                                  '(BinOp (Neq) (Var "chargeId") (Lit (StrL "")))'),
 "X08-rename-intentCount-everywhere": [("all", '"intentCount"', '"intentCnt"')],
 "X08b-rename-intentCount-decl-only": [("decl", '"intentCount"', '"intentCnt"')],
 "X09-decl-swap-out-charge-request": [("decl", '("outputCharge" (StrT)) ("outputRequest" (StrT))', '("outputRequest" (StrT)) ("outputCharge" (StrT))')],
 "X10-decl-swap-in-charge-request": [("decl", '(("chargeId" (StrT)) ("requestId" (StrT))', '(("requestId" (StrT)) ("chargeId" (StrT))')],
 "X11-decl-double-swap": [("decl", '(("chargeId" (StrT)) ("requestId" (StrT))', '(("requestId" (StrT)) ("chargeId" (StrT))'),
                          ("decl", '("outputCharge" (StrT)) ("outputRequest" (StrT))', '("outputRequest" (StrT)) ("outputCharge" (StrT))')],
 "X12-count-1-to-2": ens('(BinOp (Eq) (Var "intentCount") (Lit (IntL 1)))', '(BinOp (Eq) (Var "intentCount") (Lit (IntL 2)))'),
 "X13-outputCharge-eq-requestId": ens('(BinOp (Eq) (Var "outputCharge") (Var "chargeId"))', '(BinOp (Eq) (Var "outputCharge") (Var "requestId"))'),
 "X14-clause3-tautology": [("clause3", None, '(BinOp (Imp) (Var "authorized") (Var "authorized"))')],
 "X15-neg-literal": ens('(BinOp (Eq) (Var "outputAmount") (Lit (IntL 0)))', '(BinOp (Eq) (Var "outputAmount") (Lit (IntL -1)))'),
 "X15b-tilde-literal": ens('(BinOp (Eq) (Var "outputAmount") (Lit (IntL 0)))', '(BinOp (Eq) (Var "outputAmount") (Lit (IntL ~1)))'),
 "X16-eq-to-neq-count0": ens('(BinOp (Eq) (Var "intentCount") (Lit (IntL 0)))', '(BinOp (Neq) (Var "intentCount") (Lit (IntL 0)))'),
 "X17-huge-literal": ens('(IntL 9223372036854775807)', '(IntL 92233720368547758070000000000)'),
 "X18-escape-in-string": ens('(StrL "returned_item")', '(StrL "returned\\_item")'),
 "X19-nonascii-string": ens('(StrL "returned_item")', '(StrL "returned_itém")'),
 "X20-imp-to-reverse": ens('(BinOp (Imp) (Var "authorized") (BinOp (And)', '(BinOp (Imp) (UnOp (Not) (Var "authorized")) (BinOp (And)'),
 "N1-neutral-eq-commuted": ens('(BinOp (Eq) (Var "reason") (Lit (StrL "duplicate_charge")))', '(BinOp (Eq) (Lit (StrL "duplicate_charge")) (Var "reason"))'),
 "N2-neutral-double-negation": ens('(Var "candidate")', '(UnOp (Not) (UnOp (Not) (Var "candidate")))'),
}

def apply(d, scope, old, new):
    if scope == "clause3":
        k = d.index('(BinOp (Imp) (UnOp (Not) (Var "authorized"))', ENS_START)
        return d[:k] + new + d[ENS_END:]
    spans = {"ens": [(ENS_START, ENS_END)], "decl": [(0, DECL_IN_END), (OUT_START, OUT_END)], "all": [(0, len(d))]}[scope]
    for a, b in spans:
        seg = d[a:b]
        if old in seg:
            if scope == "all":
                return d[:a] + seg.replace(old, new) + d[b:]
            k = seg.index(old)
            return d[:a + k] + new + d[a + k + len(old):]
    raise SystemExit("pattern not found: " + old)

for name, edits in M.items():
    d = data
    for scope, old, new in edits:
        d2 = apply(d, scope, old, new)
        # keep span offsets valid for multi-edit mutants: recompute from the edited text
        d = d2
    b = d.encode("utf-8")
    open("%s/%s.sexp" % (outdir, name), "wb").write(b)
    print(name, len(b), hashlib.sha256(b).hexdigest()[:16])
