#!/usr/bin/env python3
"""WAL compatibility check of the review fixes (D3, D6, D7). Python stdlib only. A FINITE TEST; it proves nothing.

Usage: python3 -I -B compat_wal.py <old-engine> <new-engine> <work-folder> [--no-d6]

<old-engine> is the production engine built from the base commit e3322303 (unchanged sources); <new-engine> is the
engine of this branch. The script:
  1. writes a store with the OLD engine (money and saga keys, two tenants, refunds, a commit that closes a lease, a
     rejection that closes a lease, a REQUIRE_HUMAN_COSIGN verdict on a leased request, an open lease);
  2. runs `state`, `replay`, `leases --all`, `leases --sweep --now N` and `get` of every key with BOTH engines on
     separate copies of that store, and compares the answers. Expected: equal, except the one planned change of D6:
     a lease that the old engine closed with `CLOSE <id> REQUIRE_HUMAN_COSIGN <detail>` is PENDING_COSIGN for the new
     engine (the action is still pending), so it counts as open and the sweep reports it after its deadline;
  3. lets the NEW engine write records that only it writes (a CLOSE that names its tenant, a key name and a request id
     that another tenant uses, a COSIGN_PENDING record) and checks that the OLD engine then answers CORRUPT_WAL (it
     fails closed; it never reads such a WAL to another state).
Exit 0: every check held. 1: a check failed. 2: usage.
"""
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
FIX = ROOT / 'tests/airlock/fixtures'
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}
NOW = 10 ** 12


def run(engine, args, stdin=b''):
    p = subprocess.run([engine] + [str(a) for a in args], input=stdin, capture_output=True, env=ENV, timeout=120)
    return p.returncode, p.stdout.decode('ascii', 'replace')


def serve(engine, store, lines):
    code, out = run(engine, ['serve', store], ''.join(l + '\n' for l in lines).encode())
    return code, out.split('\n')[:-1]


def get_hash(engine, store, tenant, key):
    code, out = run(engine, ['get', store, tenant, key])
    assert code == 0, out
    return out.split(' ')[1]


def views(engine, store, keys):
    out = {}
    for name, args in (('state', ['state', store]), ('replay', ['replay', store]), ('leases-all', ['leases', store, '--all']),
                       ('sweep', ['leases', store, '--sweep', '--now', NOW])):
        out[name] = run(engine, args)
    for t, k in keys:
        out['get %s %s' % (t, k)] = run(engine, ['get', store, t, k])
    return out


def d6_transform(old):
    """The planned D6 change applied to the OLD engine's answers: legacy cosign closes become pending."""
    new = dict(old)
    code, text = old['leases-all']
    lines = text.split('\n')[:-1]
    pending = []
    for i, line in enumerate(lines[1:], 1):
        f = line.split(' ')
        if len(f) == 9 and f[5] == 'CLOSED' and f[7] == 'REQUIRE_HUMAN_COSIGN':
            lines[i] = ' '.join(f[:5] + ['PENDING_COSIGN', f[6], f[8]])
            pending.append(f)
    head = lines[0].split(' ')
    head[1] = str(int(head[1]) + len(pending))
    lines[0] = ' '.join(head)
    new['leases-all'] = (code, '\n'.join(lines) + '\n')
    code, text = old['state']
    t = text.rstrip('\n').split(' ')
    t[-1] = 'leases=%d' % (int(t[-1].split('=')[1]) + len(pending))
    new['state'] = (code, ' '.join(t) + '\n')
    code, text = old['sweep']
    lines = text.split('\n')[:-1]
    head = lines[0].split(' ')
    head[1] = str(int(head[1]) + len(pending))
    dropped = int(head[2]) + sum(1 for f in pending if NOW > int(f[2]))
    head[2] = str(dropped)
    # the sweep lists leases in WAL order (lease epoch): rebuild that order from leases --all
    all_lines = new['leases-all'][1].split('\n')[1:-1]
    body = ['DROPPED_OBLIGATION %s' % ' '.join(l.split(' ')[1:5]) for l in all_lines
            if (l.split(' ')[5] == 'OPEN' or l.split(' ')[5] == 'PENDING_COSIGN') and NOW > int(l.split(' ')[2])]
    new['sweep'] = (24 if dropped else 0, '\n'.join([' '.join(head)] + body) + '\n')
    return new


def main():
    if len(sys.argv) not in (4, 5):
        print(__doc__)
        return 2
    old, new, work = sys.argv[1], sys.argv[2], Path(sys.argv[3]).resolve()
    work.mkdir(parents=True, exist_ok=False)
    fails = []
    store = work / 'store-old'
    code, out = run(old, ['init', store, '--store-id', 'compat', '--policy', FIX / 'money-parametric.json', '--policy', FIX / 'saga-payout.json'])
    assert code == 0, out
    # 1. the old engine writes the store
    serve(old, store, ['OPEN_MONEY tA o1 r1 store-refunds 100000 shipping_paid=1000', 'OPEN_MONEY tB o2 r2 store-refunds 5000',
                       'OPEN_SAGA tA s1 r3 payout', 'OPEN_LEASE L1 100 tA o1', 'OPEN_LEASE L2 200 tA o1', 'OPEN_LEASE L3 300 tA o1',
                       'OPEN_LEASE L4 400 tB o2'])
    h = get_hash(old, store, 'tA', 'o1')
    _, a = serve(old, store, ['REFUND tA o1 L1 %s DUPLICATE_CHARGE 5' % h])               # commit closes L1
    h = get_hash(old, store, 'tA', 'o1')
    _, b = serve(old, store, ['REFUND tA o1 L2 %s SHIPPING 8000' % h])                    # REJECTED_POLICY closes L2
    _, c = serve(old, store, ['REFUND tA o1 L3 %s GOODWILL 5000' % h])                    # REQUIRE_HUMAN_COSIGN closes L3 (old rule)
    hs = get_hash(old, store, 'tA', 's1')
    serve(old, store, ['SAGA tA s1 r4 %s IN_FLIGHT stripe idem-1' % hs])
    print('old engine answers:', a[0][:60], '|', b[0][:60], '|', c[0][:60])
    if not (a[0].startswith('COMMITTED') and 'LEASE_CLOSED' in b[0] and c[0].startswith('REQUIRE_HUMAN_COSIGN') and 'LEASE_CLOSED' in c[0]):
        fails.append('the old engine did not write the planned store: %r %r %r' % (a, b, c))
    wal = (store / 'airlock.wal').read_bytes()
    print('old WAL: %d bytes' % len(wal))
    keys = [('tA', 'o1'), ('tB', 'o2'), ('tA', 's1')]  # a get across tenants is an answer change of D3, not a fold change
    # 2. both engines read copies of it
    copies = {}
    for label, engine in (('old', old), ('new', new)):
        copies[label] = work / ('copy-' + label)
        shutil.copytree(store, copies[label])
    vo, vn = views(old, copies['old'], keys), views(new, copies['new'], keys)
    want = d6_transform(vo) if '--no-d6' not in sys.argv else vo
    for name in vo:
        same = vn[name] == want[name]
        print('%-16s %s' % (name, 'EQUAL' if vn[name] == vo[name] else ('EQUAL AFTER THE D6 RULE' if same else 'DIFFERENT')))
        if not same:
            fails.append('%s: old %r, expected %r, new %r' % (name, vo[name], want[name], vn[name]))
    for label in ('old', 'new'):
        if (copies[label] / 'airlock.wal').read_bytes() != wal:
            fails.append('reading the store with the %s engine changed the WAL' % label)
    # 3. records that only the new engine writes: the old engine must fail closed
    for why, lines in (('a CLOSE that names its tenant', ['OPEN_LEASE L9 100 tA o1', 'REFUND tA o1 L9 %s SHIPPING 8000' % h]),
                       ('the same key name in another tenant', ['OPEN_MONEY tB o1 x1 store-refunds 5']),
                       ('the same request id in another tenant', ['OPEN_MONEY tB o3 r1 store-refunds 5']),
                       ('a COSIGN_PENDING record', ['OPEN_LEASE L8 100 tA o1', 'REFUND tA o1 L8 %s GOODWILL 5000' % h])):
        d = work / ('new-only-%d' % len(why))
        shutil.copytree(store, d)
        _, ans = serve(new, d, lines)
        code_new, _ = run(new, ['state', d])
        code_old, out_old = run(old, ['state', d])
        ok = code_new == 0 and code_old == 17 and out_old.startswith('CORRUPT_WAL')
        print('%-40s new: %r; new state exit %d; old state exit %d %s' % (why, ans[-1][:50], code_new, code_old, out_old.strip()[:50]))
        if not ok:
            fails.append('%s: new state %d, old state %d %r' % (why, code_new, code_old, out_old))
    for f in fails:
        print('FAIL', f)
    print('compat_wal: %s' % ('PASS' if not fails else 'FAIL (%d)' % len(fails)))
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
