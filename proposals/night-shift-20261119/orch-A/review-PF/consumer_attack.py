# A13 attack on the link "frame.strict_parse accepts s => HOL refund_strict_parse s = SOME (same value)".
# Pure Python; frame.py is loaded read-only. hol_render is a THIRD transcription written by A13 directly from
# mlstringScript.sml 1513-1534 (char_escape_seq, char_escaped, escape_str), mlsexpScript.sml 352-365
# (is_safe_char, make_str_safe), forge_refund_ioScript.sml 121-126 (refund_response), sexp_print_eqs (PF-0004 stdout).
import sys, random, importlib.util
spec = importlib.util.spec_from_file_location("frame", sys.argv[1]); F = importlib.util.module_from_spec(spec); spec.loader.exec_module(F)
def isSpace(c): return c == 32 or 9 <= c <= 13
def safe(c): return c not in (40, 41, 34, 0) and not isSpace(c)
def esc(c): return {9: b'\\t', 10: b'\\n', 92: b'\\\\', 34: b'\\"'}.get(c, bytes([c]))
def mss(s): return b'""' if s == b'' else (s if all(safe(c) for c in s) else b'"' + b''.join(esc(c) for c in s) + b'"')
def tostr(i): return (b'~' + str(-i).encode()) if i < 0 else str(i).encode()
def hol_render(ok, a, r, c, q, n):
    return b'(' + b' '.join([b'refund-result-v1', b'True' if ok else b'False', tostr(a), mss(r), mss(c), mss(q), tostr(n)]) + b')'
bad = []
# 1. targeted inputs: non-canonical spellings the HOL reader (mlint fromString, to_bool) might accept
base = [b'(refund-result-v1 True %s returned_item c r 1)' % x for x in
        [b'+1', b'-0', b'01', b'00', b'1_0', b' 1', b'\xd9\xa3', b'~1', b'-1', b'99999999999999999999999999999999999']]
base += [b'(refund-result-v1 true 1 a b c 1)', b'(refund-result-v1 TRUE 1 a b c 1)', b'(refund-result-v1  True 1 a b c 1)',
         b'(refund-result-v1 True 1 "a" b c 1)', b'(refund-result-v1 True 1 "a\\rb" b c 1)', b'(refund-result-v1 True 1 "a\rb" b c 1)',
         b'(refund-result-v1 True 1 "a\\0b" b c 1)', b'(refund-result-v1 True 1 "a\x00b" b c 1)', b'(refund-result-v1 True 1 "a\x0bb" b c 1)',
         b'(refund-result-v1 True 1 "" b c 1)', b'(refund-result-v1 True 1 \xff b c 1)', b'(refund-result-v1 True 1 a b c 1)\n',
         b'(refund-result-v1 True 1 a b c 1) ', b'(refund-result-v1\tTrue 1 a b c 1)', b'(refund-result-v1 True 1 "a b" c d 1)']
acc = 0
for s in base:
    v = F.strict_accepts(s)
    if v is not None:
        acc += 1
        if hol_render(*v) != s: bad.append(("targeted", s, v))
print("targeted inputs", len(base), "consumer-accepted", acc)
# 2. random fields over the full byte alphabet; renders and every strict prefix and single-byte edits
rng = random.Random(1119); n_acc = n_tot = 0
alpha = [bytes([b]) for b in range(256)]
for _ in range(4000):
    f = (rng.random() < .5, rng.choice([0, 1, 9, 10, 40, 2**63 - 1, 10**30, rng.randrange(10**6)]),
         b''.join(rng.choice(alpha) for _ in range(rng.randrange(5))), b''.join(rng.choice(alpha) for _ in range(rng.randrange(4))),
         b''.join(rng.choice(alpha) for _ in range(rng.randrange(4))), rng.randrange(1000))
    R = hol_render(*f)
    if F.render_fields(*f) != R: bad.append(("render-differs", f))
    if F.strict_accepts(R) != f: bad.append(("P0-consumer", f))
    for k in range(len(R)):
        n_tot += 1
        if F.strict_accepts(R[:k]) is not None: bad.append(("prefix-accepted", R[:k]))
    for _ in range(30):
        i = rng.randrange(len(R) + 1); s = R[:i] + rng.choice(alpha) + R[i + rng.randrange(2):]
        n_tot += 1; v = F.strict_accepts(s)
        if v is not None:
            n_acc += 1
            if hol_render(*v) != s: bad.append(("edit", s, v))
print("random cases", n_tot, "consumer-accepted edits", n_acc, "violations", len(bad))
for b in bad[:5]: print("VIOLATION", b)
sys.exit(1 if bad else 0)
