# TEST OF A MIRROR (not a proof). Worker Z6.
# Python mirror of the HOL definitions in
#   CK/basis/pure/mlsexpScript.sml lines 31-201, 352-389 (read_string_aux, read_symbol,
#   lex_aux, lex, parse_aux, parse, is_safe_char, str_every, make_str_safe,
#   sexp_to_app_list, sexp_to_string)
#   CK/basis/pure/mlstringScript.sml 1513-1534 (char_escape_seq, char_escaped, escape_str)
#   CK/basis/pure/mlintScript.sml 324-335, 364-489 (toString with "~", fromString)
#   HOL/src/string/stringScript.sml 117 (isSpace: ORD 32, or 9..13)
#   replay-sources/forge_refund_io.sml 121-139 (refund_response, refund_response_fields)
#   replay-sources/forge_refundWireProg.sml 10-14 (refund_render_fields)
#   CK/compiler/dafny/sexp_to_dafnyScript.sml 19-86 (to_mlstring, to_bool, to_int, dest_expr, dest7)
# Strings are Python str of code points 0..255 (HOL char = 0..255).
import random, sys

def isSpace(c): o = ord(c); return o == 32 or 9 <= o <= 13

class INL:
    def __init__(s, v): s.v = v
class INR:
    def __init__(s, v): s.v = v

def read_string_aux(inp, acc):
    # iterative mirror of the recursive definition (same clauses)
    i = 0
    while True:
        if i >= len(inp): return INL(("unterminated", ""))
        c = inp[i]; rest = inp[i+1:]
        if c == '"': return INR(("".join(acc), rest))
        if c == '\\':
            if rest == "": i += 1; continue          # read_string_aux [] acc
            e = rest[0]
            m = {'\\': '\\', '"': '"', '0': '\x00', 'n': '\n', 'r': '\r', 't': '\t'}
            if e in m: acc = acc + [m[e]]; i += 2; continue
            return INL(("unrecognised escape", rest[1:]))
        acc = acc + [c]; i += 1

def read_symbol(inp, acc):
    i = 0
    while i < len(inp):
        c = inp[i]
        if c == ')' or isSpace(c): return ("".join(acc), inp[i:])
        acc = acc + [c]; i += 1
    return ("".join(acc), "")

OPEN, CLOSE = ('OPEN',), ('CLOSE',)
def SYMBOL(s): return ('SYM', s)

def lex_aux(depth, inp, acc):
    while True:
        if inp == "":
            return INR((acc, "")) if depth == 0 else INL(("missing close", ""))
        c, cs = inp[0], inp[1:]
        if isSpace(c): inp = cs; continue
        if c == '(':
            depth += 1; inp = cs; acc = [OPEN] + acc; continue
        if c == ')':
            if depth == 0: return INL(("too many close", cs))
            if depth == 1: return INR(([CLOSE] + acc, cs))
            depth -= 1; inp = cs; acc = [CLOSE] + acc; continue
        if c == '"':
            r = read_string_aux(cs, [])
            if isinstance(r, INL): return INL(r.v)
            s, rest = r.v
            if depth == 0: return INR(([SYMBOL(s)], rest))
            inp = rest; acc = [SYMBOL(s)] + acc; continue
        s, rest = read_symbol(cs, [c])
        if depth == 0: return INR(([SYMBOL(s)], rest))
        inp = rest; acc = [SYMBOL(s)] + acc

def lex(inp): return lex_aux(0, inp, [])

def parse_aux(toks, xs, s):
    for t in toks:
        if t == CLOSE: s = [xs] + s; xs = []
        elif t == OPEN:
            if s == []: pass
            else: y, ys = s[0], s[1:]; xs = [('Expr', xs)] + y; s = ys
        else: xs = [('Atom', t[1])] + xs
    return xs

def parse(inp):
    r = lex(inp)
    if isinstance(r, INL): return r
    toks, rest = r.v
    v = parse_aux(toks, [], [])
    if v == []: return INL(("empty", rest))
    return INR((v[0], rest))

def is_safe_char(c): return c not in '()"\x00' and not isSpace(c)
def char_escaped(c):
    return {'\t': '\\t', '\n': '\\n', '\\': '\\\\', '"': '\\"'}.get(c, c)
def make_str_safe(s):
    if s == "": return '""'
    if all(is_safe_char(c) for c in s): return s
    return '"' + "".join(char_escaped(c) for c in s) + '"'

def sexp_to_string(x):
    if x[0] == 'Atom': return make_str_safe(x[1])
    return "(" + sexps_to_string(x[1]) + ")"
def sexps_to_string(l):
    if l == []: return ""
    if len(l) == 1: return sexp_to_string(l[0])
    return sexp_to_string(l[0]) + " " + sexps_to_string(l[1:])

def toString(i): return ("~" if i < 0 else "") + str(abs(i))
def fromString(s):
    if len(s) == 0: return None
    if s[0] in "~-":
        d = s[1:]; return -int(d) if d != "" and all(c in "0123456789" for c in d) else None
    if s[0] == '+':
        d = s[1:]; return int(d) if d != "" and all(c in "0123456789" for c in d) else None
    return int(s) if all(c in "0123456789" for c in s) else None

def refund_response(ok, amount, reason, charge, request, n):
    A = lambda s: ('Atom', s)
    return ('Expr', [A("refund-result-v1"), A("True" if ok else "False"), A(toString(amount)),
                     A(reason), A(charge), A(request), A(toString(n))])
def refund_render_fields(f): return sexp_to_string(refund_response(*f))

def refund_response_fields(se):
    if se[0] != 'Expr': return None
    xs = se[1]
    if len(xs) != 7 or any(x[0] != 'Atom' for x in xs): return None
    tag, a, b, c, d, e, f = [x[1] for x in xs]
    if tag != "refund-result-v1": return None
    if a not in ("True", "False"): return None
    amt = fromString(b); ic = fromString(f)
    if amt is None or ic is None: return None
    return (a == "True", amt, c, d, e, ic)

def strict_parse(s):
    r = parse(s)
    if isinstance(r, INL): return None
    se, rest = r.v
    if rest != "": return None
    f = refund_response_fields(se)
    if f is None: return None
    return f if refund_render_fields(f) == s else None

# ---------------- generators ----------------
rng = random.Random(20261119)
SPECIAL = ['', '"', '\\', ' ', '\t', '\n', '\r', '\x00', '(', ')', '~', '-', '+', '\\n', '\\"',
           'a b', '""', '\\\\', '~5', '-5', '+5', '05', '\x7f', '\xff', '\x0b', '\x0c', 'True', 'False',
           'refund-result-v1', ')(', '"(', '\\0', '\\x']
def rstr():
    k = rng.random()
    if k < 0.3: return rng.choice(SPECIAL)
    if k < 0.5: return "".join(rng.choice(SPECIAL) for _ in range(rng.randint(1, 4)))
    if k < 0.8: return "".join(chr(rng.randint(0, 255)) for _ in range(rng.randint(0, 12)))
    if k < 0.95: return "".join(rng.choice("abc_-0123456789") for _ in range(rng.randint(1, 20)))
    return "x" * rng.randint(200, 600)   # very long id
def rint():
    return rng.choice([0, 1, -1, 40, -40, 2**31, -2**63, 10**30, -(10**30), rng.randint(-10**6, 10**6)])

def fields():
    return (rng.random() < 0.5, rint(), rstr(), rstr(), rstr(), rint())

def main():
    N = int(sys.argv[1]) if len(sys.argv) > 1 else 600
    fixed = [(True, 40, "returned_item", "c", "r", 1), (False, 0, "", "", "", 0),
             (True, -1, '"', '\\', ' ', -5), (False, 10**40, "x" * 500, "\x00", "\n\t", 3),
             (True, 0, '\\"', ')(', '~1', 0)]
    cases = fixed + [fields() for _ in range(N)]
    nprefix = 0; bad_key = 0; bad_strict = 0; bad_P0 = 0; isl_ok = 0
    for f in cases:
        R = refund_render_fields(f)
        # P0 mirror
        if strict_parse(R) != f: bad_P0 += 1; print("P0 FAIL", repr(f)); continue
        for k in range(len(R)):          # every STRICT prefix, the empty one included
            p = R[:k]; nprefix += 1
            if not isinstance(parse(p), INL): bad_key += 1; print("PREFIX PARSES", repr(f), k)
            if strict_parse(p) is not None: bad_strict += 1
        # key lemma mirror at depth d != 0 on every prefix (incl. full) of the inner list text
        inner = R[1:-1]
        for k in range(len(inner) + 1):
            for d in (1, 2):
                if not isinstance(lex_aux(d, inner[:k], []), INL): print("KEY FAIL", repr(f), k, d); bad_key += 1
                else: isl_ok += 1
    # controls (each must behave as stated)
    f0 = (True, 40, "returned_item", "c", "r", 1); R0 = refund_render_fields(f0)
    N1 = isinstance(parse(R0), INR)                   # R0 is a strict prefix of R0+"\n" and parses
    N2 = isinstance(parse("ab"), INR) and sexp_to_string(('Atom', "abc")).startswith("ab")
    N3 = isinstance(lex_aux(0, "a", []), INR)
    print("cases", len(cases), "strict prefixes", nprefix, "key-lemma checks", isl_ok)
    print("prefix-parse violations", bad_key, "strict-parse violations", bad_strict, "P0 failures", bad_P0)
    print("controls N1 N2 N3 hold:", N1, N2, N3)
    return 0 if (bad_key == 0 and bad_strict == 0 and bad_P0 == 0 and N1 and N2 and N3) else 1

if __name__ == "__main__":
    sys.exit(main())
