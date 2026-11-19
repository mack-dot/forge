# TEST OF A MIRROR (not a proof). Worker A2, Orchestrator A, 2026-11-19.
# Attacks the statements of prefix_lemma_v3.sml (every helper lemma, the key lemma, the main
# lemma, P0, N1-N3 and the new corollary refund_render_fields_prefix_code) with
# exhaustive small enumerations, and compares the HOL strict parser (mirror) with the real
# consumer parser frame.strict_parse.
# Usage: python3 -I -B a2_attack.py <v2/mirror_prefix_test.py> <drafts/fail-closed/frame.py>
# Exit 0 iff every statement holds on every case and every control has teeth.
import sys, itertools, importlib.util, random

def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m

M = load("m", sys.argv[1])        # Z6 mirror (lex_aux, parse, render, strict_parse)
F = load("frame", sys.argv[2])     # consumer reference parser (bytes)

fails = []
def check(name, cond, info=""):
    if not cond:
        fails.append((name, info))
        if len([f for f in fails if f[0] == name]) <= 3: print("FAIL", name, repr(info)[:300])

isSpace = M.isSpace
# ---------------------------------------------------------------- HOL-faithful helpers
# read_string_aux with the HOL accumulator order (h::acc; REVERSE at the end)
ESC = {'\\': '\\', '"': '"', '0': '\x00', 'n': '\n', 'r': '\r', 't': '\t'}
def rsa(inp, acc):                      # acc: python list, HEAD FIRST (HOL order)
    while True:
        if inp == "": return ('INL', "unterminated", "")
        c, rest = inp[0], inp[1:]
        if c == '"': return ('INR', "".join(reversed(acc)), rest)
        if c == '\\':
            if rest == "": inp = rest; continue
            e, r2 = rest[0], rest[1:]
            if e in ESC: acc = [ESC[e]] + acc; inp = r2; continue
            return ('INL', "unrecognised", r2)
        acc = [c] + acc; inp = rest
def rsym(inp, acc):                     # read_symbol, HOL acc order
    while inp != "":
        c = inp[0]
        if c == ')' or isSpace(c): return ("".join(reversed(acc)), inp)
        acc = [c] + acc; inp = inp[1:]
    return ("".join(reversed(acc)), "")
def char_escaped(c): return M.char_escaped(c)
def is_safe(c): return M.is_safe_char(c)
def isprefix(p, l): return l[:len(p)] == p

CH = [chr(i) for i in range(256)]
SMALL = ['a', ' ', '(', ')', '"', '\\', '\t', '\n', '\r', '\x00', '~', '\x80', 'T', '0', 't', 'n']

def strs(alpha, n):
    for k in range(n + 1):
        for t in itertools.product(alpha, repeat=k): yield "".join(t)

# ---------------------------------------------------------------- PAS prefix_append_strict
cnt = 0
for a in strs("01", 4):
    for b in strs("01", 3):
        for p in strs("01", 6):
            lhs = isprefix(p, a + b)
            rhs = (isprefix(p, a) and p != a) or (p[:len(a)] == a and len(p) >= len(a) and isprefix(p[len(a):], b))
            cnt += 1; check("PAS", lhs == rhs, (a, b, p))
print("PAS cases", cnt)
# ---------------------------------------------------------------- EVP every_prefix
cnt = 0
for l in strs("ab(", 4):
    for k in range(len(l) + 1):
        p = l[:k]; P = lambda c: c != '('
        if all(map(P, l)): cnt += 1; check("EVP", all(map(P, p)), (l, p))
print("EVP cases", cnt)
# ---------------------------------------------------------------- RSN read_symbol_safe_nil
cnt = 0
for t in strs([c for c in SMALL if is_safe(c)] + ['\xff', '\\'], 3):
    for acc in ([], ['q'], ['x', 'y']):
        cnt += 1; check("RSN", rsym(t, acc) == ("".join(reversed(acc)) + t, ""), (t, acc))
print("RSN cases", cnt)
# ---------------------------------------------------------------- RCE read_string_aux_char_escaped
cnt = 0
for h in CH:
    for u in list(strs(['a', '"', '\\', 'n'], 3)):
        for acc in ([], ['z']):
            cnt += 1; check("RCE", rsa(char_escaped(h) + u, acc) == rsa(u, [h] + acc), (h, u, acc))
print("RCE cases", cnt)
# ---------------------------------------------------------------- CSP char_escaped_strict_prefix
cnt = 0
for h in CH:
    ce = char_escaped(h)
    for k in range(len(ce)):
        for acc in ([], ['z']):
            cnt += 1; check("CSP", rsa(ce[:k], acc)[0] == 'INL', (h, k))
print("CSP cases", cnt)
# ---------------------------------------------------------------- RSP read_string_aux_strict_prefix
cnt = 0
for xs in strs(SMALL, 3):
    body = "".join(char_escaped(c) for c in xs) + '"'
    for k in range(len(body)):
        for acc in ([], ['z']):
            cnt += 1; check("RSP", rsa(body[:k], acc)[0] == 'INL', (xs, k))
    # the FULL body closes (read_string_aux_thm): control that the mirror is not reject-all
    check("RSP-full-closes", rsa(body, []) == ('INR', xs, ""), xs)
print("RSP cases", cnt)
# ---------------------------------------------------------------- ATOM atom_prefix_ISL (incl. full)
cnt = 0
for m in strs(SMALL, 3):
    s = M.make_str_safe(m)
    for k in range(len(s) + 1):
        for d in (1, 2, 5):
            cnt += 1; check("ATOM", isinstance(M.lex_aux(d, s[:k], []), M.INL), (m, k, d))
    # control: at depth 0 the full atom lexes (N3 shape)
    check("ATOM-d0-control", isinstance(M.lex_aux(0, s, []), M.INR), m)
print("ATOM cases", cnt)
# ---------------------------------------------------------------- render fields: exhaustive small values
INTS = [0, 1, -1, 10, 40, 2**63 - 1, -(2**63), 10**40]
VALS = list(strs(SMALL, 2)) + ["refund-result-v1", "True", "False", "x" * 300, "a b", "a)b", "\"q\"", "\\\"", "é".encode().decode('latin-1')]
fieldsets = set()
for v in VALS:
    fieldsets.add((True, 40, v, "c", "r", 1)); fieldsets.add((False, 0, "", v, "", 0))
    fieldsets.add((True, -1, "x", "y", v, -5))
for i in INTS:
    fieldsets.add((True, i, "returned_item", "c", "r", 1)); fieldsets.add((False, 0, "", "", "", i))
rng = random.Random(20261119)
for _ in range(1500):
    fieldsets.add((rng.random() < .5, rng.choice(INTS), rng.choice(VALS), rng.choice(VALS), rng.choice(VALS), rng.choice(INTS)))
fieldsets = sorted(fieldsets, key=repr)
renders = {}
nprefix = 0; empty_ok = inatom = inesc = 0
for f in fieldsets:
    R = M.refund_render_fields(f)
    renders.setdefault(R, set()).add(f)
    check("P0", M.strict_parse(R) == f, f)
    # transcription cross-check: two independent transcriptions of the printer agree
    fb = F.render_fields(*f[:2], *(x.encode('latin-1') for x in f[2:5]), f[5])
    check("render-transcriptions-agree", fb == R.encode('latin-1'), f)
    for k in range(len(R)):
        p = R[:k]; nprefix += 1
        check("MAIN-parse-ISL", isinstance(M.parse(p), M.INL), (f, k))
        check("MAIN-strict-NONE", M.strict_parse(p) is None, (f, k))
        check("CONSUMER-strict-rejects", F.strict_accepts(p.encode('latin-1')) is None, (f, k))
        if k == 0: empty_ok += 1
        if k > 0 and p[-1] == '\\': inesc += 1
    # key lemma on the inner text at depths 1, 2 (incl. full inner)
    inner = R[1:-1]
    for k in range(len(inner) + 1):
        check("KEY-inner", isinstance(M.lex_aux(1, inner[:k], []), M.INL), (f, k))
print("fieldsets", len(fieldsets), "strict prefixes", nprefix, "empty prefixes", empty_ok, "prefixes ending after a backslash", inesc)
# ---------------------------------------------------------------- prefix-code corollary + injectivity
inj = all(len(v) == 1 for v in renders.values())
check("render-injective", inj)
srt = sorted(renders)
pc = 0
for a, b in zip(srt, srt[1:]):
    pc += 1; check("PREFIX_CODE", not b.startswith(a), (a, b))
print("distinct renders", len(srt), "adjacent pairs", pc, "injective", inj)
# ---------------------------------------------------------------- consumer vs HOL strict parser (mutations)
agree = hol_only = cons_only = 0
def mutants(R):
    yield R; yield R + "\n"; yield R + " "; yield " " + R; yield R + ")"; yield R[:-1]
    for i in range(len(R)):
        yield R[:i] + R[i+1:]
        for c in ('"', '\\', ' ', ')', '(', '0', '~', '-', '+'):
            yield R[:i] + c + R[i+1:]; yield R[:i] + c + R[i:]
for f in fieldsets[:400]:
    for s in mutants(M.refund_render_fields(f)):
        h = M.strict_parse(s); c = F.strict_accepts(s.encode('latin-1'))
        if c is not None:
            cc = (c[0], c[1], c[2].decode('latin-1'), c[3].decode('latin-1'), c[4].decode('latin-1'), c[5])
            check("CONSUMER-subset-of-HOL-strict", h == cc, s)
            agree += 1
        elif h is not None: hol_only += 1
print("mutants: consumer-accepted (all also HOL-accepted, same value)", agree, "HOL-only accepted", hol_only)
# ---------------------------------------------------------------- controls (must have teeth)
f0 = (True, 40, "returned_item", "c", "r", 1); R0 = M.refund_render_fields(f0)
check("N1", isinstance(M.parse(R0), M.INR) and M.parse(R0).v[1] == "")
check("N2", isinstance(M.parse("ab"), M.INR) and M.parse("ab").v == (('Atom', 'ab'), ""))
check("N3", isinstance(M.lex_aux(0, "a", []), M.INR))
rej_all = lambda s: None
check("P0-excludes-reject-all", rej_all(R0) != f0 and M.strict_parse(R0) == f0)
# the corollary has teeth: a non-prefix-free code (trailing newline) breaks it
nl = sorted(M.refund_render_fields(f) + "\n" for f in fieldsets[:50]) + sorted(M.refund_render_fields(f) for f in fieldsets[:50])
check("PREFIX_CODE-control", any(b.startswith(a) and a != b for a in nl for b in nl))
names = sorted(set(n for n, _ in fails))
print("FAILED statements:", names if names else "none")
sys.exit(1 if fails else 0)
