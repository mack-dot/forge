#!/usr/bin/env python3
# b-export-bridge G4: a TEST of text correspondence, NOT a proof, NOT the exporter.
# Reads the three `ensures` clauses of FlatCore.dfy (source text), parses them with a small Dafny-expression
# parser for the fragment used (<==>, ==>, &&, ||, !, ==, !=, <=, <, chained <=, identifiers, int and string
# literals, parentheses), prints each in the export's S-expression syntax, and compares with the export clauses
# re-printed by the same printer from the export bytes (gen_exported.py's parser). Renaming: identity (the
# export keeps the source names).
# Normalization rules (documented): `<==>` on bools -> (BinOp (Eq) ..); `a <= b <= c` -> And(Le(a,b), Le(b,c));
# `&&`/`||` left-nested; `==>` right-nested; `!e` -> (UnOp (Not) e); parentheses dropped.
import hashlib, re, sys
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_exported as G

PINNED = G.PINNED_SHA256
TOK = re.compile(r'\s*(<==>|==>|&&|\|\||!=|==|<=|<|!|\(|\)|"[A-Za-z0-9_]*"|-?[0-9]+|[A-Za-z_][A-Za-z0-9_]*)')
BIN = {"<==>": "Eq", "==>": "Imp", "&&": "And", "||": "Or", "==": "Eq", "!=": "Neq", "<=": "Le", "<": "Lt"}


def lex(s):
    out, i = [], 0
    s = s.strip()
    while i < len(s):
        m = TOK.match(s, i)
        if not m:
            raise SystemExit("G4 lexer: cannot read at %r" % s[i:i + 20])
        out.append(m.group(1)); i = m.end()
        while i < len(s) and s[i].isspace():
            i += 1
    return out


class P:
    def __init__(self, t): self.t, self.i = t, 0
    def peek(self): return self.t[self.i] if self.i < len(self.t) else None
    def eat(self, x=None):
        v = self.peek()
        if x is not None and v != x:
            raise SystemExit("G4 parser: expected %s got %s" % (x, v))
        self.i += 1; return v
    def equiv(self):
        a = self.imp()
        while self.peek() == "<==>":
            self.eat(); a = ("Eq", a, self.imp())
        return a
    def imp(self):
        a = self.logic()
        if self.peek() == "==>":
            self.eat(); return ("Imp", a, self.imp())
        return a
    def logic(self):
        a = self.rel()
        op = None
        while self.peek() in ("&&", "||"):
            o = self.eat()
            if op and o != op:
                raise SystemExit("G4 parser: mixed && and || without parentheses")
            op = o; a = (BIN[o], a, self.rel())
        return a
    def rel(self):
        a = self.unary()
        parts = []
        while self.peek() in ("==", "!=", "<=", "<"):
            o = self.eat(); b = self.unary(); parts.append((BIN[o], a, b)); a = b
        if not parts:
            return a
        r = parts[0]
        for p in parts[1:]:
            if p[0] not in ("Le", "Lt") or r[0] not in ("Le", "Lt", "And"):
                raise SystemExit("G4 parser: chain of non-ordering relations")
            r = ("And", r, p)
        return r
    def unary(self):
        if self.peek() == "!":
            self.eat(); return ("Not", self.unary())
        if self.peek() == "(":
            self.eat(); e = self.equiv(); self.eat(")"); return e
        v = self.eat()
        if v.startswith('"'):
            return ("Str", v[1:-1])
        if re.match(r"-?[0-9]+$", v):
            return ("Int", int(v))
        return ("Var", v)


def show(e):
    k = e[0]
    if k == "Var": return '(Var "%s")' % e[1]
    if k == "Int": return "(Lit (IntL %d))" % e[1]
    if k == "Str": return '(Lit (StrL "%s"))' % e[1]
    if k == "Not": return "(UnOp (Not) %s)" % show(e[1])
    return "(BinOp (%s) %s %s)" % (k, show(e[1]), show(e[2]))


def from_export(e):
    h = G.atom(e[0], "A")
    if h == "Var": return ("Var", G.atom(e[1], "Q"))
    if h == "Lit":
        lk = G.atom(e[1][0], "A")
        return ("Int", int(G.atom(e[1][1], "A"))) if lk == "IntL" else ("Str", G.atom(e[1][1], "Q"))
    if h == "UnOp": return ("Not", from_export(e[2]))
    return (G.nullary(e[1]), from_export(e[2]), from_export(e[3]))


def main():
    src, exp = sys.argv[1], sys.argv[2]
    data = open(exp, "rb").read()
    if hashlib.sha256(data).hexdigest() != PINNED:
        print("REFUSED: export digest mismatch"); return 2
    text = open(src, encoding="utf-8").read()
    print("source sha256 %s" % hashlib.sha256(text.encode()).hexdigest())
    head = text[text.index("ensures"):text.index("{", text.index("ensures"))]
    clauses = [c.strip() for c in head.split("ensures")[1:]]
    tree = G.parse(G.tokenize(data.decode("ascii")))
    (members,) = G.con(tree, "Program", 1)
    ens = G.con(members[0], "Method", 9)[3]
    if len(clauses) != 3 or len(ens) != 3:
        print("DIFF: clause count source %d export %d" % (len(clauses), len(ens))); return 1
    diffs = 0
    for k, (c, e) in enumerate(zip(clauses, ens), 1):
        s = show(P(lex(c)).equiv())
        x = show(from_export(e))
        same = s == x
        diffs += 0 if same else 1
        print("clause %d: %s (source %d chars, normalized %d chars)" % (k, "SAME" if same else "DIFF", len(c), len(s)))
        if not same:
            print("  source: " + s); print("  export: " + x)
    print("differences: %d" % diffs)
    return 0 if diffs == 0 else 1


if __name__ == "__main__":
    sys.exit(main())
