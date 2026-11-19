#!/usr/bin/env python3
# Night shift 2026-11-19, Orchestrator B, task b-export-bridge. A DRAFT. NOT gate evidence.
# INDEPENDENT READER of the exported flat contract (export SHA-256 58154ddf...dd0d).
# Written from the export bytes and sexp_to_dafnyScript.sml (to_member_decl: Method has 9 fields
# name ins reqs ens reads decrs outs mods body). It does NOT reuse gen_mirror.py.
#
# Output 1 (--out-contract): Dafny module ExportedGen with ExportedClause1..3(x: FlatIn, o: FlatTuple) and
#   ExportedContract = Clause1 && Clause2 && Clause3, translated node by node with the FIXED table TABLE.
# Output 2 (--out-trees): Dafny module ReaderTreesGen with Tree1..3 as HolMirror.MExp terms (to compare
#   with the trees in the stored Mirror.dfy).
#
# Binding (BETA-ORDER): export input k -> FlatIn field k (field list parsed from SliceTheorem.dfy);
#   export output k -> tuple component o.k (types parsed from LinkedRefund.dfy FlatTuple). The reader checks
#   that the export types and the Dafny types agree position by position. It fails closed on anything else.
#
# Controls: --mutate-op OP=TEXT (change one table line), --mutate-bind NAME, --unpinned-control (skip the
#   digest check; output is stamped CONTROL). Without --unpinned-control a digest mismatch is a refusal (exit 2).
import argparse, hashlib, re, sys

PINNED_SHA256 = "58154ddffc3b54d875c51bcd9dd2f36a93334c5cc302c899987aec0d7333dd0d"

# THE FIXED TABLE. One line per export operator or literal form. Nothing else is accepted.
TABLE = {
    ("BinOp", "Eq"):  "==",    # same-type equality (bool, int, string)
    ("BinOp", "Neq"): "!=",    # same-type disequality
    ("BinOp", "And"): "&&",
    ("BinOp", "Or"):  "||",
    ("BinOp", "Imp"): "==>",
    ("BinOp", "Le"):  "<=",    # int only
    ("UnOp", "Not"):  "!",
    ("Lit", "IntL"):  "DEC",   # decimal integer literal, unbounded (Dafny int)
    ("Lit", "StrL"):  "STR",   # string literal; only chars [A-Za-z0-9_] accepted (all < 128)
}
MIRROR_OP = {"Eq": "Eq", "Neq": "Neq", "And": "And", "Or": "Or", "Imp": "Imp", "Le": "Le"}
TYPE_MAP = {"StrT": "string", "IntT": "int", "BoolT": "bool"}
STR_OK = re.compile(r"^[A-Za-z0-9_]*$")
INT_OK = re.compile(r"^-?[0-9]+$")


class Refuse(Exception):
    pass


def tokenize(text):
    toks, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if c in " \n\t\r":
            i += 1
        elif c in "()":
            toks.append(c); i += 1
        elif c == '"':
            j = i + 1
            while j < n and text[j] != '"':
                if text[j] == "\\" or not (32 <= ord(text[j]) < 127):
                    raise Refuse("escape or non-printable char in string atom at %d" % j)
                j += 1
            if j >= n:
                raise Refuse("unterminated string")
            toks.append(("Q", text[i + 1:j])); i = j + 1
        else:
            j = i
            while j < n and text[j] not in ' \n\t\r()"':
                j += 1
            toks.append(("A", text[i:j])); i = j
    return toks


def parse(toks):
    pos = 0

    def node():
        nonlocal pos
        if pos >= len(toks):
            raise Refuse("unexpected end")
        t = toks[pos]; pos += 1
        if t == "(":
            items = []
            while True:
                if pos >= len(toks):
                    raise Refuse("missing )")
                if toks[pos] == ")":
                    pos += 1
                    return items
                items.append(node())
        if t == ")":
            raise Refuse("unexpected )")
        return t
    tree = node()
    if pos != len(toks):
        raise Refuse("trailing tokens after the program")
    return tree


def atom(t, kind=None):
    if not isinstance(t, tuple) or (kind and t[0] != kind):
        raise Refuse("expected atom %s, got %r" % (kind, t))
    return t[1]


def con(t, name, arity):
    if not isinstance(t, list) or len(t) != arity + 1 or atom(t[0], "A") != name:
        raise Refuse(("expected (%s ...) with %d args, got %r" % (name, arity, t))[:200])
    return t[1:]


def nullary(t):
    if not isinstance(t, list) or len(t) != 1:
        raise Refuse("expected nullary constructor, got %r" % (t,))
    return atom(t[0], "A")


def typed_list(t):
    out = []
    for p in t:
        if not isinstance(p, list) or len(p) != 2:
            raise Refuse("bad typed name")
        ty = nullary(p[1])
        if ty not in TYPE_MAP:
            raise Refuse("type not in table: " + ty)
        out.append((atom(p[0], "Q"), ty))
    return out


def read_dafny_side(st_path, lr_path):
    st = open(st_path, encoding="utf-8").read()
    m = re.search(r"datatype FlatIn = FlatIn\(([^)]*)\)", st)
    if not m:
        raise Refuse("FlatIn declaration not found")
    fields = [tuple(s.strip() for s in f.split(":")) for f in m.group(1).replace("\n", " ").split(",")]
    lr = open(lr_path, encoding="utf-8").read()
    m2 = re.search(r"type FlatTuple = \(([^)]*)\)", lr)
    if not m2:
        raise Refuse("FlatTuple declaration not found")
    tup = [s.strip() for s in m2.group(1).split(",")]
    return fields, tup


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("export"); ap.add_argument("--slice", required=True); ap.add_argument("--linked", required=True)
    ap.add_argument("--out-contract", required=True); ap.add_argument("--out-trees")
    ap.add_argument("--mutate-op", action="append", default=[])
    ap.add_argument("--mutate-bind", default=None)
    ap.add_argument("--unpinned-control", action="store_true")
    a = ap.parse_args()
    data = open(a.export, "rb").read()
    digest = hashlib.sha256(data).hexdigest()
    print("export bytes %d sha256 %s" % (len(data), digest))
    if digest != PINNED_SHA256 and not a.unpinned_control:
        print("REFUSED: digest mismatch (pinned %s)" % PINNED_SHA256)
        return 2
    table = dict(TABLE)
    for mo in a.mutate_op:
        k, v = mo.split("=", 1)
        key = [kk for kk in table if kk[1] == k]
        if len(key) != 1:
            raise Refuse("unknown mutation key " + k)
        table[key[0]] = v
    text = data.decode("ascii")  # fail closed on non-ASCII
    tree = parse(tokenize(text))
    (members,) = con(tree, "Program", 1)
    if len(members) != 1:
        raise Refuse("expected exactly one member")
    name, ins, reqs, ens, reads, decrs, outs, mods, body = con(members[0], "Method", 9)
    if atom(name, "Q") != "AssessFlat" or reqs != [] or reads != [] or mods != []:
        raise Refuse("unexpected method header")
    if len(ens) != 3:
        raise Refuse("expected exactly 3 ensures")
    ins_l, outs_l = typed_list(ins), typed_list(outs)
    fields, tup = read_dafny_side(a.slice, a.linked)
    if len(ins_l) != len(fields) or len(outs_l) != len(tup):
        raise Refuse("arity mismatch")
    bind = {}
    for (n, ty), (f, fty) in zip(ins_l, fields):
        if TYPE_MAP[ty] != fty:
            raise Refuse("input type mismatch %s %s" % (n, f))
        bind[n] = "x." + f
    for k, ((n, ty), dty) in enumerate(zip(outs_l, tup)):
        if TYPE_MAP[ty] != dty:
            raise Refuse("output type mismatch %s" % n)
        bind[n] = "o.%d" % k
    if len(bind) != len(ins_l) + len(outs_l):
        raise Refuse("duplicate names")
    swaps = {"in-charge-request": [("chargeId", "requestId")],
             "out-charge-request": [("outputCharge", "outputRequest")],
             "double-charge-request": [("chargeId", "requestId"), ("outputCharge", "outputRequest")],
             "in-original-remaining": [("original", "remaining")]}
    if a.mutate_bind:
        for p, q in swaps[a.mutate_bind]:
            bind[p], bind[q] = bind[q], bind[p]
    used = set()

    def dfy(e):
        if not isinstance(e, list) or not e:
            raise Refuse("expression expected")
        h = atom(e[0], "A")
        if h == "Var":
            (v,) = con(e, "Var", 1); v = atom(v, "Q")
            if v not in bind:
                raise Refuse("unbound variable " + v)
            return bind[v]
        if h == "Lit":
            (l,) = con(e, "Lit", 1)
            lk = atom(l[0], "A"); used.add(("Lit", lk))
            if ("Lit", lk) not in table:
                raise Refuse("literal form not in table: " + lk)
            (v,) = con(l, lk, 1)
            if lk == "IntL":
                s = atom(v, "A")
                if not INT_OK.match(s):
                    raise Refuse("bad int literal " + s)
                n = int(s)
                if table[("Lit", "IntL")] == "DEC+1":
                    n += 1
                return "(%d)" % n
            s = atom(v, "Q")
            if not STR_OK.match(s):
                raise Refuse("string literal outside the accepted alphabet")
            return '"%s"' % s
        if h == "UnOp":
            u, x = con(e, "UnOp", 2); u = nullary(u); used.add(("UnOp", u))
            if ("UnOp", u) not in table:
                raise Refuse("unary operator not in table: " + u)
            return "(%s%s)" % (table[("UnOp", u)], dfy(x))
        if h == "BinOp":
            b, x, y = con(e, "BinOp", 3); b = nullary(b); used.add(("BinOp", b))
            if ("BinOp", b) not in table:
                raise Refuse("binary operator not in table: " + b)
            return "(%s %s %s)" % (dfy(x), table[("BinOp", b)], dfy(y))
        raise Refuse("expression form not in table: " + h)

    def mexp(e):
        h = atom(e[0], "A")
        if h == "Var":
            return 'HM.MVar("%s")' % atom(e[1], "Q")
        if h == "Lit":
            lk = atom(e[1][0], "A")
            if lk == "IntL":
                return "HM.MLit(HM.IntL(%d))" % int(atom(e[1][1], "A"))
            s = atom(e[1][1], "Q")
            return "HM.MLit(HM.StrL([%s]))" % ", ".join(str(ord(c)) for c in s)
        if h == "UnOp":
            return "HM.MUnOp(HM.%s, %s)" % (nullary(e[1]), mexp(e[2]))
        return "HM.MBinOp(HM.%s, %s, %s)" % (MIRROR_OP[nullary(e[1])], mexp(e[2]), mexp(e[3]))

    clauses = [dfy(e) for e in ens]
    stamp = "CONTROL (digest not pinned)" if a.unpinned_control else "pinned export"
    muts = ",".join(a.mutate_op + ([a.mutate_bind] if a.mutate_bind else [])) or "none"
    hdr = ("// GENERATED by gen_exported.py (b-export-bridge). Export sha256 %s (%s). Mutation: %s.\n"
           "// Do not edit. Binding: %s\n" % (digest, stamp, muts,
                                              ", ".join("%s->%s" % kv for kv in bind.items())))
    out = [hdr, 'include "../inputs/SliceTheorem.dfy"\n\nmodule ExportedGen {\n',
           "  import opened SliceTheorem\n  import L = LinkedRefund\n\n"]
    for k, c in enumerate(clauses, 1):
        out.append("  predicate ExportedClause%d(x: FlatIn, o: L.FlatTuple)\n  {\n    %s\n  }\n\n" % (k, c))
    out.append("  predicate ExportedContract(x: FlatIn, o: L.FlatTuple)\n  {\n"
               "    ExportedClause1(x, o) && ExportedClause2(x, o) && ExportedClause3(x, o)\n  }\n}\n")
    open(a.out_contract, "w").write("".join(out))
    if a.out_trees:
        t = [hdr, 'include "../mirror/Mirror.dfy"\n\nmodule ReaderTreesGen {\n  import HM = HolMirror\n\n']
        for k, e in enumerate(ens, 1):
            t.append("  const Tree%d: HM.MExp := %s\n\n" % (k, mexp(e)))
        t.append("}\n")
        open(a.out_trees, "w").write("".join(t))
    print("used forms: " + ", ".join("%s %s" % u for u in sorted(used)))
    unused = sorted(set(TABLE) - used)
    print("table lines not used: " + (", ".join("%s %s" % u for u in unused) or "none"))
    print("binding: " + ", ".join("%s->%s" % kv for kv in bind.items()))
    print("OK")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Refuse as r:
        print("REFUSED: %s" % r)
        sys.exit(3)
