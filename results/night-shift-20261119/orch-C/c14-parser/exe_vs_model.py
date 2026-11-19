"""c14 (b): real executable's request reader vs c14's hand transcription of the HOL model
(refund_decode_wire = parse + rest=[] + dest9/to_int/to_bool/to_mlstring; refund_fields; refund_render_fields;
reader error -> Fail raised -> no output). Mutated request texts (non-canonical numbers, whitespace, quoting,
escapes, trailing bytes, NUL, non-UTF-8, nesting). Exit 1 if any stdout differs from the model's prediction
or rc != 0 or stderr non-empty.  usage: python3 -B -I exe_vs_model.py SEED N (N<=2000)"""
import sys, random
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/Users/mackianni/forge/results/night-shift-20261119/orch-C/c14-parser')
from common import run, MAX  # noqa
import hol_strict as H  # noqa

seed, n = int(sys.argv[1]), min(int(sys.argv[2]), 2000)
R = random.Random(seed)
APP = (b'duplicate_charge', b'service_not_delivered', b'returned_item')


def model(s):
    p = H.parse(s)
    if p is None or p[1] != b'': return b''
    se = p[0]
    if se[0] != 'Expr' or len(se[1]) != 9 or any(x[0] != 'Atom' for x in se[1]): return b''
    a = [x[1] for x in se[1]]
    ints = [H.fromString(a[i]) for i in (2, 3, 7)]
    bools = [{b'True': True, b'False': False}.get(a[i]) for i in (4, 5, 6)]
    if None in ints or None in bools: return b''
    c, q, rs = a[0], a[1], a[8]; o, r, am = ints; en, op, ca = bools
    ok = (c != b'' and q != b'' and en and op and 0 <= o <= MAX and 0 <= r <= o and ca and 0 <= am <= r and rs in APP)
    return H.render((ok, am if ok else 0, rs if ok else b'', c if ok else b'', q if ok else b'', 1 if ok else 0))


def atom():
    k = R.random()
    if k < 0.3: return R.choice([b'c', b'r', b'"c"', b'"\\r\\0"', b'c\x00', b'\xff', b'"a b"', b'c(x', b'r"y', b'""'])
    if k < 0.6: return R.choice([b'0', b'040', b'+40', b'-0', b'~0', b'40', b'60', b'100', b'-1', b'~1', b'+', b'-',
                                 b'9223372036854775807', b'9223372036854775808', b'00', b'1e2', b'4 0', b'"40"'])
    if k < 0.8: return R.choice([b'True', b'False', b'"True"', b'true', b'TRUE'])
    return R.choice([b'returned_item', b'"returned_item"', b'duplicate_charge', b'service_not_delivered',
                     b'"service_not_delivered"', b'returned_item\x00', b'(x)', b'()'])


def gen():
    base = [b'c', b'r', b'100', b'60', b'True', b'True', b'True', b'40', b'returned_item']
    for _ in range(R.randrange(0, 4)): base[R.randrange(9)] = atom()
    if R.random() < 0.1: base.insert(R.randrange(10), atom())
    if R.random() < 0.1: del base[R.randrange(len(base))]
    seps = [R.choice([b' ', b' ', b'\t', b'\n', b'\r', b'  ', b'\x0b']) for _ in base]
    s = R.choice([b'(', b'(', b' (', b'\n(']) + b''.join(a + sp for a, sp in zip(base, seps))[:-1] + b')'
    k = R.random()
    if k < 0.05: s += R.choice([b'\n', b' ', b'x', b'()', b')', b'\x00'])
    elif k < 0.08: s = s[:R.randrange(len(s))]
    elif k < 0.1: i = R.randrange(len(s)); s = s[:i] + bytes([s[i] ^ (1 << R.randrange(8))]) + s[i + 1:]
    return s


cases = [gen() for _ in range(n)]
bad, auth, outs = [], 0, 0
with ThreadPoolExecutor(4) as ex:
    for s, (rc, out, err) in zip(cases, ex.map(run, cases)):
        m = model(s)
        auth += out.startswith(b'(refund-result-v1 True'); outs += out != b''
        if out != m or rc != 0 or err != b'':
            bad.append((s, rc, out, err, m))
print('runs', n, 'with output', outs, 'authorized', auth, 'mismatches', len(bad))
for b in bad[:10]: print('MISMATCH', b)
sys.exit(1 if bad else 0)
