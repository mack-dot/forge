"""c14 (c): deterministic edge requests through the real executable and the repository's consumer.
Every byte 0..255 in each id (bare, start, middle, end), every byte appended to an approved reason, amount 0,
amount == remaining, MaxMoney, ids at 2047..2049/4095..4097/65535..65537/1 MiB bytes.
Exit 1 if any consumer verdict differs from the oracle (false rejection or wrong authorization)."""
import sys, json
from concurrent.futures import ThreadPoolExecutor
sys.path.insert(0, '/Users/mackianni/forge/results/night-shift-20261119/orch-C/c14-parser')
from common import run, as_result, oracle, fc, MAX  # noqa


def F(c=b'c', q=b'r', o=100, r=60, e=True, op=True, ca=True, a=40, rs=b'returned_item'):
    return {'charge': c, 'request': q, 'original': o, 'remaining': r, 'enabled': e, 'opened': op,
            'candidate': ca, 'amount': a, 'reason': rs}


cases = []
for b in range(256):
    x = bytes([b])
    cases += [F(c=x), F(q=b'r' + x + b'x'), F(c=x + b'c', q=b'q' + x), F(c=x * 3, q=x * 2, a=0),
              F(rs=b'returned_item' + x)]
for (o, r, a) in [(MAX, MAX, MAX), (MAX, MAX, 0), (MAX, MAX, MAX - 1), (MAX, 0, 0), (0, 0, 0), (MAX, MAX, MAX + 1),
                  (MAX + 1, MAX, MAX), (MAX, MAX + 1, 0), (100, 60, 60), (100, 60, 61), (100, 100, 100),
                  (2 ** 64, 2 ** 64, 1), (1, 1, -0), (5, 3, -1), (5, -1, -1)]:
    for rs in (b'duplicate_charge', b'service_not_delivered', b'returned_item'):
        cases.append(F(o=o, r=r, a=a, rs=rs))
for size in (2047, 2048, 2049, 4095, 4096, 4097, 65535, 65536, 65537, 1 << 20):
    cases += [F(c=b'c' * size), F(q=b'"' * size, a=0), F(c=b'\\' * size, q=b'\n' * size, a=60)]
# total request length exactly at a boundary: pad the charge id so len(wire) hits the boundary
for L in (2047, 2048, 2049, 4095, 4096, 4097, 65535, 65536, 65537):
    base = len(fc.wire(F(c=b'')))
    cases.append(F(c=b"k" * (L - base + 2)))
    assert len(fc.wire(cases[-1])) == L


def one(f):
    rc, out, err = run(fc.wire(f), timeout=60)
    got = fc.decide_from_result(f, as_result(rc, out, err))
    return f, rc, out, err, got, oracle(f)


bad, auth, zero, full, mx = [], 0, 0, 0, 0
with ThreadPoolExecutor(4) as ex:
    for f, rc, out, err, got, exp in ex.map(one, cases):
        ok = got[0] == exp[0] and (got[0] != 'AUTHORIZED' or got[1:] == exp[1:])
        if got[0] == 'AUTHORIZED':
            auth += 1; zero += got[1] == 0; full += got[1] == f['remaining']; mx += got[1] == MAX
        if not ok:
            bad.append({'f': {k: (v[:40].hex() + '..len%d' % len(v) if isinstance(v, bytes) else v)
                              for k, v in f.items()}, 'rc': rc, 'out': out[:120].decode('latin-1'),
                        'err': err[:200].decode('latin-1'), 'got': got, 'exp': exp})
print('runs', len(cases), 'authorized', auth, 'zero', zero, 'amount==remaining', full, 'MaxMoney', mx)
for b_ in bad[:15]:
    print('MISMATCH', json.dumps(b_, default=str))
print('mismatches', len(bad))
sys.exit(1 if bad else 0)
