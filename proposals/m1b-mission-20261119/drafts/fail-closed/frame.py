"""Reference model of the PRESENT M1 output frame.

Contents (all plain Python, standard library, NOT proved):
  * render_*            transcription of sexp_to_string o refund_response (mlsexp, mlstring, mlint).
  * hol_parse           transcription of mlsexp lex_aux / parse_aux / parse (the program's own reader).
  * hol_response_fields transcription of refund_response_fields (dest_expr, dest7, to_bool, to_int,
                        to_mlstring, mlint fromString).  Note: mlint fromString accepts 040, +40, -40.
  * strict_parse        the STRICT reference parser of this work: exact grammar, full consumption,
                        exactly 7 fields, canonical integers, True/False, canonical atom spelling, and
                        render(parse(x)) == x.
  * lenient readers     deliberately careless readers, to show which prefixes they accept.

All strings here are byte strings. CakeML strings are sequences of 8-bit chars, so one byte = one char.
"""
import re

TAG = b'refund-result-v1'
REJECTED_BYTES = b'(refund-result-v1 False 0 "" "" "" 0)'
AUTHORIZED_PREFIX = b'(refund-result-v1 True '
MAX_MONEY = 9223372036854775807
APPROVED_REASONS = [b'duplicate_charge', b'service_not_delivered', b'returned_item']


# ----------------------------------------------------------------------------- printer (transcription)
def is_space(b):            # HOL isSpace: #" " or 9 <= ORD c <= 13
    return b == 32 or 9 <= b <= 13


def is_safe_char(b):        # mlsexp is_safe_char: not in "()\"\000" and not isSpace
    return b not in b'()"\x00' and not is_space(b)


ESCAPES = {9: b'\\t', 10: b'\\n', 92: b'\\\\', 34: b'\\"'}   # mlstring char_escape_seq


def make_str_safe(s):
    if s == b'':
        return b'""'
    if all(is_safe_char(b) for b in s):
        return s
    return b'"' + b''.join(ESCAPES.get(b, bytes([b])) for b in s) + b'"'   # escape_str


def int_to_string(i):       # mlint toString: "~" for negative
    return (b'~' if i < 0 else b'') + str(abs(i)).encode()


def bool_atom(v):
    return b'True' if v else b'False'


def render_fields(ok, amount, reason, charge, request, count):
    """refund_render_fields (ok,a,r,c,q,n) = sexp_to_string (refund_response ok a r c q n)."""
    atoms = [TAG, bool_atom(ok), int_to_string(amount), make_str_safe(reason),
             make_str_safe(charge), make_str_safe(request), int_to_string(count)]
    return b'(' + b' '.join(atoms) + b')'


def render_request(charge, request, original, remaining, enabled, opened, candidate, amount, reason):
    atoms = [make_str_safe(charge), make_str_safe(request), int_to_string(original), int_to_string(remaining),
             bool_atom(enabled), bool_atom(opened), bool_atom(candidate), int_to_string(amount),
             make_str_safe(reason)]
    return b'(' + b' '.join(atoms) + b')'


# ----------------------------------------------------------------------------- the program's reader
class Err(Exception):
    pass


def read_string(s, i):
    acc = bytearray()
    while True:
        if i >= len(s):
            raise Err('unterminated string literal')
        c = s[i]
        if c == 34:
            return bytes(acc), i + 1
        if c == 92:
            if i + 1 >= len(s):
                raise Err('unterminated string literal')
            e = s[i + 1]
            m = {92: 92, 34: 34, 48: 0, 110: 10, 114: 13, 116: 9}
            if e not in m:
                raise Err('unrecognised escape')
            acc.append(m[e]); i += 2
            continue
        acc.append(c); i += 1


def read_symbol(s, i):
    j = i
    while j < len(s) and not (s[j] == 41 or is_space(s[j])):
        j += 1
    return s[i:j], j


def hol_lex(s):
    """lex = lex_aux 0 input []: tokens of at most one S-expression, and the rest."""
    depth, i, toks = 0, 0, []
    while True:
        if i >= len(s):
            if depth == 0:
                return toks, b''
            raise Err('missing closing parenthesis')
        c = s[i]
        if is_space(c):
            i += 1
        elif c == 40:
            depth += 1; toks.append('OPEN'); i += 1
        elif c == 41:
            if depth == 0:
                raise Err('too many closing parenthesis')
            toks.append('CLOSE'); i += 1
            if depth == 1:
                return toks, s[i:]
            depth -= 1
        elif c == 34:
            sym, i = read_string(s, i + 1)
            toks.append(('SYM', sym))
            if depth == 0:
                return toks, s[i:]
        else:
            sym, i = read_symbol(s, i + 1)
            sym = bytes([c]) + sym
            toks.append(('SYM', sym))
            if depth == 0:
                return toks, s[i:]


def hol_parse(s):
    """parse: returns (sexp, rest) or raises Err. sexp = bytes (Atom) | list (Expr)."""
    toks, rest = hol_lex(s)
    if not toks:
        raise Err('parse: empty input')
    # parse_aux on the token list in order (the HOL list is reversed; this is the same result).
    stack, cur = [], []
    for t in toks:
        if t == 'OPEN':
            stack.append(cur); cur = []
        elif t == 'CLOSE':
            # unreachable at depth 0 by construction of hol_lex
            done = cur; cur = stack.pop(); cur.append(done)
        else:
            cur.append(t[1])
    return cur[0], rest


def mlint_from_string(s):
    """mlint fromString: '~' or '-' or '+' prefix allowed; then fromChars (digits only)."""
    if s == b'':
        return None
    sign, body = 1, s
    if s[:1] in (b'~', b'-'):
        sign, body = -1, s[1:]
    elif s[:1] == b'+':
        body = s[1:]
    if body == b'' or not all(48 <= b <= 57 for b in body):
        return None
    return sign * int(body)


def hol_response_fields(se):
    if not isinstance(se, list):
        raise Err('dest_expr: Was not Expr')
    if len(se) != 7:
        raise Err('dest7')
    tag, a, b, c, d, e, f = se

    def atom(x):
        if not isinstance(x, bytes):
            raise Err('to_mlstring: Was not Atom')
        return x

    if atom(tag) != TAG:
        raise Err('wrong result tag')
    ok = {b'True': True, b'False': False}.get(atom(a))
    if ok is None:
        raise Err('to_bool')
    amount = mlint_from_string(atom(b))
    count = mlint_from_string(atom(f))
    if amount is None or count is None:
        raise Err('to_int')
    return ok, amount, atom(c), atom(d), atom(e), count


def hol_reader_accepts(s):
    """The program's own reader as a response reader: parse = INR (se, []) and fields = INR _."""
    try:
        se, rest = hol_parse(s)
        if rest != b'':
            return None
        return hol_response_fields(se)
    except Err:
        return None


# ----------------------------------------------------------------------------- strict reference parser
CANON_INT = re.compile(rb'(0|[1-9][0-9]*)\Z')


def _strict_atom(s, i):
    """One atom in canonical spelling. Returns (value, next index)."""
    if i < len(s) and s[i] == 34:
        j, val = i + 1, bytearray()
        while True:
            if j >= len(s):
                raise Err('strict: unterminated quoted atom')
            c = s[j]
            if c == 34:
                j += 1; break
            if c == 92:
                if j + 1 >= len(s) or s[j + 1] not in b'\\"tn':
                    raise Err('strict: escape not emitted by the printer')
                val.append({92: 92, 34: 34, 116: 9, 110: 10}[s[j + 1]]); j += 2; continue
            if c in (9, 10):
                raise Err('strict: raw tab or newline in quoted atom')
            val.append(c); j += 1
        val = bytes(val)
    else:
        j = i
        while j < len(s) and is_safe_char(s[j]):
            j += 1
        if j == i:
            raise Err('strict: empty bare atom')
        val = s[i:j]
    if make_str_safe(val) != s[i:j]:
        raise Err('strict: atom spelling is not canonical')
    return val, j


def strict_parse(s):
    """Exact grammar of section (a). Returns the 6-tuple or raises Err."""
    if not isinstance(s, (bytes, bytearray)):
        raise Err('strict: not bytes')
    s = bytes(s)
    if s[:1] != b'(':
        raise Err('strict: no opening parenthesis')
    i, vals = 1, []
    for k in range(7):
        v, i = _strict_atom(s, i)
        vals.append(v)
        sep = b' ' if k < 6 else b')'
        if s[i:i + 1] != sep:
            raise Err('strict: separator %r missing after field %d' % (sep, k + 1))
        i += 1
    if i != len(s):
        raise Err('strict: bytes after the frame')
    tag, okb, amb, reason, charge, request, cnb = vals
    if tag != TAG:
        raise Err('strict: wrong tag')
    if okb not in (b'True', b'False'):
        raise Err('strict: not a boolean')
    for x in (amb, cnb):
        if not CANON_INT.match(x):           # the program never prints a negative amount or count
            raise Err('strict: integer not canonical')
    out = (okb == b'True', int(amb), reason, charge, request, int(cnb))
    if render_fields(*out) != s:             # render(parse(x)) == x
        raise Err('strict: re-render differs')
    return out


def strict_accepts(s):
    try:
        return strict_parse(s)
    except Err:
        return None


# ----------------------------------------------------------------------------- careless readers
def lenient_startswith(s):
    """Copy of m1_class: AUTHORIZED when the output starts with the prefix."""
    return 'AUTHORIZED' if s.startswith(AUTHORIZED_PREFIX) else None


def lenient_split(s):
    """Split on spaces, strip parentheses, take the third word as the amount."""
    w = s.strip(b'()').split(b' ')
    if len(w) >= 3 and w[0] == TAG and w[1] == b'True' and w[2].isdigit():
        return ('AUTHORIZED', int(w[2]))
    return None


AUTH_RE = re.compile(rb'\(refund-result-v1 True (\d+) (\S+) (\S+) (\S+) (\d+)')


def lenient_regex(s):
    """re.match with no end anchor; \\S+ for the three text fields."""
    m = AUTH_RE.match(s)
    if not m:
        return None
    return ('AUTHORIZED', int(m.group(1)), m.group(3), m.group(4), int(m.group(5)))


def lenient_autoclose(s):
    """The program's reader, but at end of input it closes an open string and open parentheses."""
    t = s
    try:
        hol_lex(t)
    except Err as e:
        msg = str(e)
        if 'unterminated' in msg:
            t = t + b'"'
            try:
                hol_lex(t)
            except Err as e2:
                msg = str(e2)
        if 'missing closing' in msg:
            depth = 0
            # count depth outside strings
            i = 0
            while i < len(t):
                c = t[i]
                if c == 34:
                    try:
                        _, i = read_string(t, i + 1)
                    except Err:
                        return None
                    continue
                depth += (c == 40) - (c == 41); i += 1
            t = t + b')' * max(depth, 0)
    r = hol_reader_accepts(t)
    if r and r[0] is True:
        return ('AUTHORIZED',) + tuple(r[1:])
    return None


LENIENT = {'startswith(m1_class copy)': lenient_startswith, 'split-words': lenient_split,
           'regex-no-end-anchor': lenient_regex, 'auto-close-reader': lenient_autoclose}
