"""c14 (a)+(c): real executable vs an independent oracle, through the repository's consumer
(frame.strict_parse inside m1_fail_closed.decide_from_result). Exit 1 if ANY run gives a consumer verdict
that differs from the oracle (wrong authorization = (a); REFUSED for a well-typed request = (c)). Else 0.
usage: python3 -B -I fuzz_oracle.py SEED N   (N <= 2000; 4 worker threads, one process each)"""
import sys, random, json
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/Users/mackianni/forge/results/night-shift-20261119/orch-C/c14-parser')
from common import run, as_result, oracle, fc, frame, MAX, APPROVED  # noqa

seed, n = int(sys.argv[1]), min(int(sys.argv[2]), 2000)
R = random.Random(seed)
SPECIAL = [b'', b'\x00', b'\t', b'\n', b'\r', b'\x0b', b'\x0c', b' ', b'"', b'\\', b'(', b')', b'\xff', b'\x80',
           b'True', b'False', b'~1', b'refund-result-v1', b'""', b'\\0', b'\\r', b'a b', b'\xe2\x80\xa8', b';', b'#|']


def rid():
    k = R.random()
    if k < 0.3:
        return R.choice(SPECIAL) + R.choice(SPECIAL + [b'x'])
    if k < 0.6:
        return bytes(R.randrange(256) for _ in range(R.randrange(1, 12)))
    if k < 0.65:
        return bytes([R.randrange(256)]) * R.choice([2047, 2048, 2049, 4095, 4096, 4097, 65535, 65536, 65537])
    return bytes(R.choice(b'abcXYZ019_-') for _ in range(R.randrange(1, 40)))


def num(rem=None):
    pool = [0, 1, 2, 40, 100, MAX, MAX - 1, MAX + 1, 2 ** 64, 2 ** 64 + 40, -1, -MAX - 1, 10 ** 30, -(10 ** 30)]
    if rem is not None:
        pool += [rem, rem + 1, rem - 1, rem // 2, 0, 0]
    return R.choice(pool) if R.random() < 0.7 else R.randrange(-5, 10 ** R.randrange(1, 25))


def reason():
    k = R.random()
    if k < 0.7:
        return R.choice(APPROVED)
    a = R.choice(APPROVED)
    return R.choice([a + b' ', a.upper(), a + b'\x00', b'"' + a + b'"', a[:-1], a.replace(b'_', b'-'), b'', rid()])


def gen():
    orig = num(); rem = num(orig) if R.random() < 0.5 else R.randrange(0, max(1, min(abs(orig), MAX)) + 1)
    if R.random() < 0.6 and 0 <= rem <= MAX:
        orig = R.choice([rem, MAX, rem + R.randrange(0, 1000)])
    amt = num(rem)
    b = lambda: R.random() < 0.9  # noqa
    return {'charge': rid(), 'request': rid(), 'original': orig, 'remaining': rem, 'enabled': b(),
            'opened': b(), 'candidate': b(), 'amount': amt, 'reason': reason()}


cases = [gen() for _ in range(n)]


def one(f):
    rc, out, err = run(fc.wire(f))
    got = fc.decide_from_result(f, as_result(rc, out, err))
    exp = oracle(f)
    agree = got[0] == exp[0] and (got[0] != 'AUTHORIZED' or got[1:] == exp[1:])
    return f, rc, out, err, got, exp, agree


bad, stats = [], {'runs': 0, 'AUTHORIZED': 0, 'auth_zero': 0, 'auth_full': 0, 'auth_max': 0,
                  'NOT_AUTHORIZED': 0, 'REFUSED': 0, 'frames_strict_ok': 0, 'nonzero_rc': 0, 'stderr': 0}
with ThreadPoolExecutor(4) as ex:
    for f, rc, out, err, got, exp, agree in ex.map(one, cases):
        stats['runs'] += 1; stats[got[0]] += 1
        stats['frames_strict_ok'] += frame.strict_accepts(out) is not None
        stats['nonzero_rc'] += rc != 0; stats['stderr'] += err != b''
        if got[0] == 'AUTHORIZED':
            stats['auth_zero'] += got[1] == 0; stats['auth_full'] += got[1] == f['remaining'] > 0
            stats['auth_max'] += got[1] == MAX
        if not agree:
            bad.append({'fields': {k: (v.hex() if isinstance(v, bytes) else v) for k, v in f.items()},
                        'rc': rc, 'stdout_head': out[:200].decode('latin-1'), 'stderr': err[:200].decode('latin-1'),
                        'consumer': list(map(str, got)), 'oracle': list(map(str, exp))})
print(json.dumps(stats))
for b_ in bad[:10]:
    print('MISMATCH', json.dumps(b_))
print('mismatches', len(bad))
sys.exit(1 if bad else 0)
