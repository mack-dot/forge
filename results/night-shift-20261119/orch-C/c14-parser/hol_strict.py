"""Hand transcription (c14, NOT proved) of HOL refund_strict_parse (PF-0004/proof.sml:418-426) over
mlsexp lex_aux/read_string_aux/read_symbol/parse_aux/parse (cakeml basis/pure/mlsexpScript.sml:31-201),
refund_response_fields (forge_refund_ioScript.sml:128-139), mlint fromString/fromChars/toString,
mlsexp make_str_safe/sexp_to_string, mlstring char_escape_seq. Written without frame.py.
Strings are byte strings (one CakeML char = one byte)."""


def isSpace(c): return c == 32 or 9 <= c <= 13


def read_string_aux(s, i, acc):
    while True:
        if i >= len(s): return ('INL',)
        c = s[i]
        if c == 0x22: return ('INR', bytes(acc), i + 1)
        if c == 0x5C:
            if i + 1 >= len(s): return ('INL',)
            e = s[i + 1]
            m = {0x5C: 0x5C, 0x22: 0x22, 0x30: 0, 0x6E: 10, 0x72: 13, 0x74: 9}
            if e not in m: return ('INL',)
            acc.append(m[e]); i += 2; continue
        acc.append(c); i += 1


def read_symbol(s, i, acc):
    while i < len(s) and not (s[i] == 0x29 or isSpace(s[i])):
        acc.append(s[i]); i += 1
    return bytes(acc), i


def lex_aux(depth, s, i, acc):
    while True:
        if i >= len(s): return ('INR', acc, len(s)) if depth == 0 else ('INL',)
        c = s[i]
        if isSpace(c): i += 1
        elif c == 0x28: depth += 1; acc = ['OPEN'] + acc; i += 1
        elif c == 0x29:
            if depth == 0: return ('INL',)
            if depth == 1: return ('INR', ['CLOSE'] + acc, i + 1)
            depth -= 1; acc = ['CLOSE'] + acc; i += 1
        elif c == 0x22:
            r = read_string_aux(s, i + 1, bytearray())
            if r[0] == 'INL': return ('INL',)
            sym, i = r[1], r[2]
            if depth == 0: return ('INR', [('SYM', sym)], i)
            acc = [('SYM', sym)] + acc
        else:
            sym, i = read_symbol(s, i + 1, bytearray([c]))
            if depth == 0: return ('INR', [('SYM', sym)], i)
            acc = [('SYM', sym)] + acc


def parse_aux(toks, xs, st):
    # literal: parse_aux [] xs s = xs; CLOSE -> parse_aux rest [] (xs::s);
    # OPEN -> case s of [] => parse_aux rest xs s | y::ys => parse_aux rest ((Expr xs)::y) ys; SYMBOL -> Atom::xs
    for t in toks:
        if t == 'CLOSE': st = [xs] + st; xs = []
        elif t == 'OPEN':
            if st: xs = [('Expr', xs)] + st[0]; st = st[1:]
        else: xs = [('Atom', t[1])] + xs
    return xs


def parse(s):
    r = lex_aux(0, s, 0, [])
    if r[0] == 'INL': return None
    vs = parse_aux(r[1], [], [])
    if not vs: return None
    return vs[0], s[r[2]:]


def fromString(a):
    if len(a) == 0: return None
    sign, body = 1, a
    if a[0] in (0x7E, 0x2D): sign, body = -1, a[1:]
    elif a[0] == 0x2B: body = a[1:]
    if len(body) == 0 or any(not (0x30 <= b <= 0x39) for b in body): return None  # fromChars 0 = NONE
    return sign * int(body)


def response_fields(se):
    if se[0] != 'Expr': return None
    xs = se[1]
    if len(xs) != 7: return None
    if any(x[0] != 'Atom' for x in xs[:1]): return None
    tag = xs[0][1]
    if tag != b'refund-result-v1': return None
    a, b, c, d, e, f = xs[1:]
    if a[0] != 'Atom' or a[1] not in (b'True', b'False'): return None
    ok = a[1] == b'True'
    if b[0] != 'Atom': return None
    amt = fromString(b[1])
    if amt is None: return None
    for x in (c, d, e):
        if x[0] != 'Atom': return None
    if f[0] != 'Atom': return None
    n = fromString(f[1])
    if n is None: return None
    return (ok, amt, c[1], d[1], e[1], n)


def is_safe_char(c): return c not in (0x28, 0x29, 0x22, 0) and not isSpace(c)


def make_str_safe(s):
    if s == b'': return b'""'
    if all(is_safe_char(c) for c in s): return s
    esc = {9: b'\\t', 10: b'\\n', 0x5C: b'\\\\', 0x22: b'\\"'}
    return b'"' + b''.join(esc.get(c, bytes([c])) for c in s) + b'"'


def toString(i): return (b'~' if i < 0 else b'') + str(abs(i)).encode()


def render(f):
    ok, a, r, c, q, n = f
    return b'(' + b' '.join([b'refund-result-v1', b'True' if ok else b'False', toString(a), make_str_safe(r),
                              make_str_safe(c), make_str_safe(q), toString(n)]) + b')'


def refund_strict_parse(s):
    p = parse(s)
    if p is None: return None
    se, rest = p
    if rest != b'': return None
    f = response_fields(se)
    if f is None: return None
    return f if render(f) == s else None
