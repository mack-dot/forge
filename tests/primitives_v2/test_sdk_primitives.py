#!/usr/bin/env python3
"""FINITE TEST of sdk/py/forge_primitives.py over the REAL primitives engine (black box). It proves nothing.

Usage: python3 tests/primitives_v2/test_sdk_primitives.py <engine> [--case NAME]... [--work DIR] [--keep]

<engine> is the production build (build/primitives_v2/primitives-engine). Each case drives the engine only through
the SDK (one `serve` process per client) and checks the happy path and each refusal class of one primitive, and that
the refusal's .code and .repair alone are enough to repair the next proposal. Case `faults` uses two tiny fake
engines (shell scripts) to check that the SDK raises, and never returns a result, for an answer that breaks the
grammar, a COMMITTED line that does not match the request, and an engine that dies.
One printed line per case. A case that cannot run FAILS with NOT RUN. Times are indicative (shared machine).
Exit 0: every selected case passed. 1: at least one failed. 2: the suite could not start.
"""

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'sdk' / 'py'))
import forge_primitives as fp  # noqa: E402

ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}


class Failed(Exception):
    pass


def require(cond, msg):
    if not cond:
        raise Failed(msg)


def is_ref(r, code, why=None):
    return isinstance(r, fp.Refusal) and r.code == code and (why is None or r.repair.get('why') == why)


def expect(r, code, what, why=None):
    if code == 'COMMITTED':
        require(isinstance(r, fp.Committed), '%s: expected Committed, got %r' % (what, getattr(r, 'line', r)))
    elif code.startswith('OK:'):
        require(isinstance(r, fp.Verdict) and r.verdict == code[3:], '%s: expected verdict %s, got %r' % (what, code[3:], getattr(r, 'line', r)))
    else:
        require(is_ref(r, code, why), '%s: expected %s%s, got %r' % (what, code, ' why=' + why if why else '', getattr(r, 'line', r)))
    return r


def raises(exc, fn, what):
    try:
        r = fn()
    except exc as e:
        return e
    except Exception as e:  # noqa: BLE001
        raise Failed('%s: expected %s, got %s: %s' % (what, exc.__name__, type(e).__name__, e))
    raise Failed('%s: expected %s, got a result %r' % (what, exc.__name__, r))


class Suite:
    def __init__(self, engine, work):
        self.engine, self.work, self.n = engine, Path(work), 0

    def folder(self, name):
        self.n += 1
        d = self.work / ('%s-%d' % (name, self.n))
        d.mkdir(mode=0o700)
        return d

    def store(self, name, policies):
        """policies: {file name: JSON text}. Returns the store folder."""
        d = self.folder(name)
        args = [str(self.engine), 'init', str(d / 'st')]
        for fname, text in policies.items():
            (d / fname).write_text(text)
            args += ['--policy', str(d / fname)]
        p = subprocess.run(args, capture_output=True, text=True, env=ENV)
        require(p.returncode == 0 and p.stdout.startswith('INITIALIZED'), 'NOT RUN: init failed: %r' % (p.stdout + p.stderr))
        return d / 'st'

    def client(self, st):
        return fp.Primitives(st, engine=self.engine)


def rate_pol(name, **kw):
    body = {'max_ops_per_window': '2', 'max_volume_per_window': '100', 'window_ms': '3600000', 'cooldown_after': '0', 'cooldown_ms': '0'}
    body.update({k: str(v) for k, v in kw.items()})
    return '{"primitive": "rate_window", "version": 1, "name": "%s", %s}' % (name, ', '.join('"%s": "%s"' % kv for kv in body.items()))


def lg_pol(name, **kw):
    return '{"primitive": "ledger_graph", "version": 1, "name": "%s", %s}' % (name, ', '.join('"%s": "%s"' % kv for kv in kw.items()))


# ---- cases --------------------------------------------------------------------------------------------------------
def case_rate(s):
    st = s.store('rate', {'api.json': rate_pol('api'), 'cool.json': rate_pol('cool', max_ops_per_window=1, cooldown_after=1, cooldown_ms=3600000),
                          'other.json': rate_pol('other')})
    with s.client(st) as c:
        a = expect(c.acquire('t1', 'k', 'api', 40), 'COMMITTED', 'first acquire')
        require(set(a.hashes) == {'k'} and a.effect == 'A api 40', 'Committed fields: %r' % a.line)
        expect(c.acquire('t1', 'k', 'api', 60, pre=a.hashes['k']), 'COMMITTED', 'acquire with the exact hash')
        r = expect(c.acquire('t1', 'k', 'api', 1), 'RATE_LIMIT_EXCEEDED', 'third op in a window of 2')
        require(int(r.repair['retry_after_ms']) > 0 and not r.durable and 'now_ms' not in r.repair and r.now_ms, 'rate repair: %r' % r.line)
        r = expect(c.acquire('t1', 'k2', 'api', 101), 'VOLUME_ABOVE_CAP', 'volume over the cap')
        cap = int(r.repair['max_volume_per_window'])
        expect(c.acquire('t1', 'k2', 'api', cap), 'COMMITTED', 'repaired from max_volume_per_window alone')
        expect(c.acquire('t1', 'k2', 'other', 1), 'POLICY_MISMATCH', 'another policy on a bound key')
        expect(c.acquire('t1', 'k3', 'nope', 1), 'UNKNOWN_POLICY', 'unknown policy')
        r = expect(c.acquire('t1', 'k', 'api', 1, pre='0' * 64), 'STALE_STATE_HASH', 'stale hash')
        require(r.repair['stale'] == '1' and r.hashes['k'] == c.get('t1', 'k').hash, 'stale repair gives the present hash: %r' % r.line)
        # cooldown: one rejection (durable) starts it
        expect(c.acquire('t1', 'q', 'cool', 1), 'COMMITTED', 'cool commit')
        r = expect(c.acquire('t1', 'q', 'cool', 1, request_id='coolrej1'), 'RATE_LIMIT_EXCEEDED', 'cool rejection')
        require(r.durable and r.request_id == 'coolrej1' and set(r.hashes) == {'q'} and r.seq, 'a counted rejection is durable: %r' % r.line)
        r = expect(c.acquire('t1', 'q', 'cool', 1), 'COOLDOWN_ACTIVE', 'cooldown')
        require(int(r.repair['retry_after_ms']) > 0, 'cooldown repair: %r' % r.line)
        expect(c.acquire('t1', 'k9', 'api', 1, request_id='coolrej1'), 'DUPLICATE_REQUEST_ID', 'id used up by the durable refusal')
    return 'COMMITTED; RATE_LIMIT_EXCEEDED/COOLDOWN_ACTIVE retry_after_ms; VOLUME_ABOVE_CAP repaired from its field; durable refusal; stale; ids'


def case_engine(s):
    st = s.store('engine', {'api.json': rate_pol('api')})
    with s.client(st) as c:
        r = expect(c.acquire('t2', 'reg:t1', 'api', 1), 'MALFORMED_REQUEST', 'squat of a registry handle', why='RESERVED_KEY')
        require(r.repair.get('owner') == 'ledger_graph' and r.repair.get('prefix') == 'reg:' and r.repair.get('key') == 'reg:t1', 'reserved repair: %r' % r.line)
        expect(c.acquire('t1', 'k', 'api', 1), 'COMMITTED', 'owner commit')
        r = expect(c.acquire('t2', 'k', 'api', 1), 'TENANT_ISOLATION_BREACH', "another tenant's key")
        require(r.repair.get('key') == 'k', 'tenant repair: %r' % r.line)
        expect(c.get('t2', 'k'), 'TENANT_ISOLATION_BREACH', "GET of another tenant's key")
        g = c.get('t1', 'k')
        require(isinstance(g, fp.KeyState) and g.exists and g.primitive == 'rate_window' and g.fields.get('ops') == '1', 'GET: %r' % g.line)
        require(not c.get('t1', 'fresh').exists, 'GET of a new key')
        raises(fp.LocalRefusal, lambda: c.acquire('t 1', 'k', 'api', 1), 'a tenant with a space')
        raises(fp.LocalRefusal, lambda: c.acquire('t1', 'k', 'api', -1), 'a negative volume')
        raises(fp.LocalRefusal, lambda: c.transfer('t1', 'L', 'a', 'b', 1, pre='*'), '* where CAS is required')
        st_ = c.state()
        require(st_['store_id'] == 'store' and st_['seq'] == '1', 'STATE: %r' % st_)
    return 'RESERVED_KEY owner/prefix; TENANT_ISOLATION_BREACH key=; GET; local refusals before sending; STATE'


def case_ledger(s):
    st = s.store('ledger', {'L1.json': lg_pol('L1', kind='ledger', issuance='fixed', max_balance='1000', max_legs='4'),
                            'L2.json': lg_pol('L2', kind='ledger', issuance='mint_burn', max_balance='500', max_legs='4')})
    with s.client(st) as c:
        expect(c.open_accounts('t1', 'L1', {'a0': 600, 'a1': 300, 'a2': 100}), 'COMMITTED', 'open')
        r = expect(c.transfer('t1', 'L1', 'a2', 'a0', 150), 'INSUFFICIENT_FUNDS', 'overdraft')
        expect(c.transfer('t1', 'L1', 'a2', 'a0', int(r.repair['balance'])), 'COMMITTED', 'repaired from balance=')
        r = expect(c.post('t1', 'L1', {'a0': -100, 'a1': 60, 'a2': 50}), 'CONSERVATION_BREACH', 'unbalanced posting')
        debit, credit = int(r.repair['debit_total']), int(r.repair['credit_total'])
        expect(c.post('t1', 'L1', {'a0': -100, 'a1': 60, 'a2': 50 - (credit - debit)}), 'COMMITTED', 'repaired from the totals')
        old = c.read_hashes('t1', ['a0', 'a1'])
        expect(c.transfer('t1', 'L1', 'a0', 'a1', 1), 'COMMITTED', 'transfer (pre=read)')
        r = expect(c.transfer('t1', 'L1', 'a0', 'a1', 1, pre=old), 'STALE_STATE_HASH', 'stale multi-key')
        require(r.repair['stale'] == '2' and set(r.hashes) == {'a0', 'a1'}, 'stale repair: %r' % r.line)
        expect(c.transfer('t1', 'L1', 'a0', 'a1', 1, pre=r.hashes), 'COMMITTED', 'repaired from the present hashes')
        expect(c.mint('t1', 'L1', 'a0', 5), 'ISSUANCE_DISABLED', 'mint in a fixed ledger')
        expect(c.open_accounts('t1', 'L2', {'m0': 10}), 'COMMITTED', 'open L2')
        expect(c.mint('t1', 'L2', 'm0', 5), 'COMMITTED', 'mint')
        expect(c.burn('t1', 'L2', 'm0', 15), 'COMMITTED', 'burn')
        r = expect(c.transfer('t1', 'L1', 'a0', 'm0', 1), 'CROSS_LEDGER', 'cross ledger')
        require(r.repair.get('ledger') == 'L2', 'cross-ledger repair: %r' % r.line)
        expect(c.open_accounts('t2', 'L1', {'b0': 10}), 'COMMITTED', 't2 open')
        expect(c.transfer('t1', 'L1', 'a0', 'b0', 1), 'TENANT_ISOLATION_BREACH', 'cross-tenant transfer (pre=read: the GET refuses)')
        total = sum(int(c.get('t1', k).fields['balance']) for k in ('a0', 'a1', 'a2'))
        require(total == 1000, 'conservation: sum of L1 balances of t1 is %d, expected 1000' % total)
    return 'open/transfer/post/mint/burn COMMITTED; INSUFFICIENT_FUNDS, CONSERVATION_BREACH, STALE repaired from fields; sum == 1000'


def case_registry(s):
    st = s.store('registry', {'names.json': lg_pol('names', kind='registry', case='ascii_fold', max_name_bytes='24')})
    with s.client(st) as c:
        expect(c.claim('t1', 'names', 'Alice@Example.com'), 'COMMITTED', 'claim')
        r = expect(c.claim('t2', 'names', 'alice@example.COM'), 'DUPLICATE_KEY', 'claim of a held name by another tenant')
        require(set(r.repair) == {'registry'} and 't1' not in r.line and 'alice' not in r.line.lower(), 'DUPLICATE_KEY names the holder or the name: %r' % r.line)
        expect(c.claim('t2', 'names', 'alice2@example.com'), 'COMMITTED', 'repaired by another name')
        expect(c.release('t2', 'names', 'alice@example.com'), 'NOT_HOLDER', 'release by a non-holder')
        expect(c.release('t1', 'names', 'ALICE@example.com'), 'COMMITTED', 'release by the holder')
        expect(c.claim('t2', 'names', 'alice@example.com'), 'COMMITTED', 'claim after release')
        expect(c.claim('t1', 'nope', 'x'), 'UNKNOWN_POLICY', 'unknown registry')
    return 'claim/release COMMITTED; DUPLICATE_KEY registry= only (no holder, no name); NOT_HOLDER; UNKNOWN_POLICY'


def case_graph(s):
    st = s.store('graph', {'gp.json': lg_pol('gp', kind='graph', max_nodes='6', max_edges='8')})
    with s.client(st) as c:
        expect(c.add_edges('t1', 'g1', 'gp', [('a', 'b'), ('b', 'c'), ('c', 'd')]), 'COMMITTED', 'a chain')
        r = expect(c.add_edges('t1', 'g1', 'gp', [('c', 'e'), ('d', 'a')]), 'DAG_CYCLE_DETECTED', 'closing edge')
        require(r.repair.get('edge') == 'd->a' and r.repair.get('cycle_len') == '4' and r.repair.get('index') == '1', 'cycle repair: %r' % r.line)
        edges = [('c', 'e'), ('d', 'a')]
        del edges[int(r.repair['index'])]
        expect(c.add_edges('t1', 'g1', 'gp', edges), 'COMMITTED', 'repaired by dropping the named edge')
        expect(c.add_edges('t1', 'g1', 'gp', [('a', 'b')]), 'EDGE_EXISTS', 'existing edge')
        expect(c.remove_edge('t1', 'g1', 'gp', 'a', 'd'), 'NO_SUCH_EDGE', 'remove a missing edge')
        expect(c.remove_edge('t1', 'g1', 'gp', 'a', 'b'), 'COMMITTED', 'remove')
        r = expect(c.add_edges('t1', 'g1', 'gp', [('x', 'y'), ('y', 'z')]), 'GRAPH_FULL', 'node limit')
        require(r.repair.get('limit') == 'max_nodes', 'graph full repair: %r' % r.line)
    return 'add_edge/remove_edge COMMITTED; DAG_CYCLE_DETECTED edge= cycle_len= index= repaired; EDGE_EXISTS; NO_SUCH_EDGE; GRAPH_FULL'


TAINT_POL = ('{"primitive": "taint_egress", "version": 1, "name": "out", "mode": "detect", "labels": [], '
             '"fields": [{"path": "ssn", "labels": ["PII"]}, {"path": "$.patient.diagnosis", "labels": ["PHI"]}], '
             '"destinations": {"PUBLIC_HTTP": [], "LLM_STDOUT": ["PII"]}}')


def case_taint(s):
    st = s.store('taint', {'out.json': TAINT_POL})
    secret = 'Zq7SecretDiagnosis'
    with s.client(st) as c:
        doc = {'patient': {'name': 'n', 'diagnosis': secret, 'visits': [{'ssn': '123-45-6789'}]}}
        r = expect(c.taint_check('t1', 'out', 'PUBLIC_HTTP', doc), 'TAINT_EGRESS_BLOCKED', 'nested PHI to PUBLIC_HTTP')
        require(r.repair.get('json_path') == '$.patient.diagnosis' and r.repair.get('label') == 'PHI' and r.repair.get('more') == '1', 'taint repair: %r' % r.line)
        require(secret not in r.line and '6789' not in r.line, 'a refusal echoed a secret: %r' % r.line)
        del doc['patient']['diagnosis']
        r = expect(c.taint_check('t1', 'out', 'PUBLIC_HTTP', doc), 'TAINT_EGRESS_BLOCKED', 'nested PII in an array')
        require(r.repair.get('json_path') == '$.patient.~1[0].ssn' and r.repair.get('label') == 'PII', 'array path: %r' % r.line)
        del doc['patient']['visits']
        v = expect(c.taint_check('t1', 'out', 'PUBLIC_HTTP', doc), 'OK:ALLOW', 'repaired document')
        require(v.document == '{"patient":{"name":"n"}}' and v.fields['sha256'] == hashlib.sha256(v.document.encode()).hexdigest(), 'ALLOW binds the bytes: %r' % v.line)
        expect(c.taint_check('t1', 'out', 'LLM_STDOUT', '{"ssn": "1"}'), 'OK:ALLOW', 'PII allowed to LLM_STDOUT (text sent as is)')
        expect(c.taint_check('t1', 'out', 'NOWHERE', '{}'), 'UNKNOWN_DESTINATION', 'unknown destination')
        expect(c.taint_check('t1', 'nope', 'PUBLIC_HTTP', '{}'), 'UNKNOWN_POLICY', 'unknown policy')
        expect(c.taint_check('t1', 'out', 'PUBLIC_HTTP', '{"a":1,}'), 'MALFORMED_REQUEST', 'bad JSON', why='BAD_JSON')
    return 'TAINT_EGRESS_BLOCKED json_path= label= (no secret echoed), repaired to ALLOW; sha256 bound; destination/policy/JSON refusals'


def case_farkas(s):
    st = s.store('farkas', {})
    with s.client(st) as c:
        A, b = [[1], [-1]], [1, 0]  # x >= 1 and -x >= 0: no x >= 0
        v = expect(c.farkas_check('t1', A, b, [1, 1]), 'OK:INFEASIBILITY_PROVED', 'a valid certificate')
        require(v.fields.get('scope') == 'nonneg_integer_x', 'scope: %r' % v.line)
        r = expect(c.farkas_check('t1', A, b, [1, 0]), 'CERT_REJECTED', 'y^T A > 0')
        require(r.repair.get('reason') == 'YTA_POSITIVE' and r.repair.get('col') == '0', 'reject repair: %r' % r.line)
        r = expect(c.farkas_check('t1', A, b, [-1, 1]), 'CERT_REJECTED', 'negative y')
        require(r.repair.get('reason') == 'Y_NEGATIVE' and r.repair.get('row') == '0', 'negative repair: %r' % r.line)
        r = expect(c.farkas_check('t1', [[-1], [-1]], [0, -1], [0, 1]), 'CERT_REJECTED', 'y^T b <= 0')
        require(r.repair.get('reason') == 'YTB_NOT_POSITIVE', 'ytb repair: %r' % r.line)
        expect(c.farkas_check('t1', A, [1], [1, 1]), 'SHAPE', 'b shorter than A')
        r = expect(c.farkas_check('t1', [[-(1 << 63)]] * 64, [1] * 64, [(1 << 63) - 1] * 64), 'OVERFLOW', 'a sum beyond i128')
        require(r.repair.get('claim') == 'INFEASIBILITY_NOT_PROVED', 'overflow is never a proof: %r' % r.line)
    return 'INFEASIBILITY_PROVED (digests checked by the SDK); CERT_REJECTED reason=Y_NEGATIVE/YTA_POSITIVE/YTB_NOT_POSITIVE; SHAPE; OVERFLOW'


FAKE_GARBAGE = '#!/bin/sh\nread l\necho "this is not an answer"\n'
FAKE_WRONG_ID = '#!/bin/sh\nread l\necho "COMMITTED request_id=other seq=1 now_ms=1 skew_ms=0 hash.k=%s effect=x"\n' % ('a' * 64)
FAKE_DEAD = '#!/bin/sh\nread l\nexit 0\n'
FAKE_OK_FOR_KEYED = '#!/bin/sh\nread l\necho "OK verdict=ALLOW now_ms=1 skew_ms=0"\n'


def case_faults(s):
    d = s.folder('faults')
    out = []
    for name, script, exc in [('garbage', FAKE_GARBAGE, fp.ProtocolError), ('wrong_id', FAKE_WRONG_ID, fp.ProtocolError),
                              ('dead', FAKE_DEAD, fp.EngineDead), ('ok_for_keyed', FAKE_OK_FOR_KEYED, fp.ProtocolError)]:
        p = d / name
        p.write_text(script)
        os.chmod(p, 0o700)
        c = fp.Primitives(d, engine=p)
        e = raises(exc, lambda: c.acquire('t1', 'k', 'api', 1, request_id='mine'), 'fake engine %s' % name)
        require(e.outcome_known is False, '%s: outcome must be unknown' % name)
        raises(fp.EngineDead, lambda: c.state(), 'a closed client after %s' % name)
        c.close()
        out.append(name)
    # a real CORRUPT_WAL: EngineFault, and the client is closed
    st = s.store('corrupt', {'api.json': rate_pol('api')})
    with s.client(st) as c:
        expect(c.acquire('t1', 'k', 'api', 1), 'COMMITTED', 'commit before the damage')
    data = bytearray((st / 'primitives.wal').read_bytes())
    data[-3] ^= 0xff
    (st / 'primitives.wal').write_bytes(bytes(data))
    c = s.client(st)
    e = raises(fp.EngineFault, lambda: c.acquire('t1', 'k', 'api', 1), 'a damaged WAL')
    require(e.code == 'CORRUPT_WAL' and e.fields.get('why'), 'fault fields: %r' % e.line)
    raises(fp.EngineDead, lambda: c.state(), 'client after a fault')
    c.close()
    return 'fake engines (%s) raise, never a result; CORRUPT_WAL raises EngineFault and closes the client' % ', '.join(out)


CASES = [('rate', case_rate), ('engine', case_engine), ('ledger', case_ledger), ('registry', case_registry), ('graph', case_graph),
         ('taint', case_taint), ('farkas', case_farkas), ('faults', case_faults)]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('engine')
    ap.add_argument('--case', action='append', choices=[n for n, _ in CASES])
    ap.add_argument('--work', default=None)
    ap.add_argument('--keep', action='store_true')
    args = ap.parse_args()
    if not os.access(args.engine, os.X_OK):
        print('cannot start: %s is missing' % args.engine)
        return 2
    work = Path(tempfile.mkdtemp(prefix='pv2-sdk-', dir=args.work))
    os.chmod(work, 0o700)
    suite = Suite(Path(args.engine).resolve(), work)
    failed = 0
    for name, fn in CASES:
        if args.case and name not in args.case:
            continue
        t = time.time()
        try:
            detail = fn(suite)
            print('PASS %-9s %6.1fs %s' % (name, time.time() - t, detail), flush=True)
        except Failed as e:
            failed += 1
            print('FAIL %-9s %6.1fs %s' % (name, time.time() - t, str(e).replace('\n', ' ')[:600]), flush=True)
        except Exception as e:  # noqa: BLE001  (a crash of the suite or an unexpected SDK exception is a failure)
            failed += 1
            print('FAIL %-9s %6.1fs suite error %s: %s' % (name, time.time() - t, type(e).__name__, str(e)[:400]), flush=True)
    if not args.keep:
        shutil.rmtree(work, ignore_errors=True)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
