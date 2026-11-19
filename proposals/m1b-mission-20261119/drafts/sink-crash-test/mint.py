#!/usr/bin/env python3
"""Y6: obtain valid tokens from the REAL Slice 1 issuer (ts/refund-finality/minter.ts, unchanged), started as
scripts/demo_gauntlet.py starts it: `node --import tsx <minter> <compiled core> spec/refund/spec.lock off`, cwd =
repository. The compiled core is a copy of a demo build whose SHA-256 equals the Slice 1 evidence record.
Writes cfg.json (sink config) and tokens.json into this folder."""
import hashlib, json, os, subprocess, sys
from pathlib import Path

ROOT = Path('<HOME>/forge')
W = Path(__file__).resolve().parent
RECORD = 'e6d5f5e54405f2767de59e054c329b86fc5d769c873c055c08780e89fbd906ce'
S0 = {'chargeId': 'ch_y6', 'original': '1000', 'remaining': '1000', 'refundEnabled': True}
CHAIN, STEP, RACE = 450, 2, 100


def canon(v):
    return json.dumps(v, sort_keys=True, separators=(',', ':'))


def transition(pre, rid, amount, reason='returned_item'):
    return {'request': {'requestId': rid, 'amount': str(amount), 'reason': reason},
            'post': dict(pre, remaining=str(int(pre['remaining']) - amount)),
            'intent': {'chargeId': pre['chargeId'], 'requestId': rid, 'amount': str(amount), 'reason': reason}}


def main():
    core = W / 'model.cjs'
    assert hashlib.sha256(core.read_bytes()).hexdigest() == RECORD, 'core module is not the recorded one'
    env = dict(os.environ, PATH='/opt/homebrew/bin:' + os.environ['PATH'], NODE_PATH=str(ROOT / 'node_modules'))
    p = subprocess.Popen(['node', '--import', 'tsx', 'ts/refund-finality/minter.ts', str(core), 'spec/refund/spec.lock', 'off'],
                         cwd=ROOT, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=open(W / 'logs' / 'issuer.stderr', 'wb'))
    ready = json.loads(p.stdout.readline())
    assert ready.get('ready') is True
    (W / 'cfg.json').write_text(json.dumps({k: ready[k] for k in ('publicKeyPem', 'specLockSha256', 'checkerSha256')}))
    n = [0]

    def ask(pre, t):
        n[0] += 1
        p.stdin.write((json.dumps({'id': n[0], 'pre': pre, 'transition': t}) + '\n').encode()); p.stdin.flush()
        a = json.loads(p.stdout.readline())
        assert a['id'] == n[0]
        return a

    def token(pre, t):
        a = ask(pre, t)
        assert a['ok'], a
        return canon(a['token'])

    out = {'S0': S0, 'chain': [], 'race': [], 'zero': {}, 'issuer_answers': {}}
    pre = S0
    for i in range(CHAIN):
        t = transition(pre, 'rq_chain_%03d' % i, STEP)
        out['chain'].append(token(pre, t))
        pre = t['post']
    out['race'] = [token(S0, transition(S0, 'rq_race_%03d' % i, 400)) for i in range(RACE)]
    # Zero-amount and repeated-request cases.
    z = out['zero']
    z['zero'] = [token(S0, transition(S0, 'rq_zero_%d' % i, 0)) for i in range(1, 6)]
    z['zero_same_again'] = token(S0, transition(S0, 'rq_zero_1', 0))                       # identical request again
    z['zero_same_id_other_reason'] = token(S0, transition(S0, 'rq_zero_1', 0, 'duplicate_charge'))
    after1 = dict(S0, remaining='998')                                                     # state after chain[0]
    z['zero_on_after1'] = token(after1, transition(after1, 'rq_zero_late', 0))
    z['same_request_again_chain0'] = token(S0, transition(S0, 'rq_chain_000', STEP))       # chain[0] asked again
    out['issuer_answers']['amount_1001'] = ask(S0, transition(S0, 'rq_over', 1001))
    p.stdin.close(); rest = p.stdout.read(); code = p.wait()
    out['issuer_exit'] = code
    out['deterministic'] = {'zero_same_again_equal': z['zero_same_again'] == z['zero'][0],
                            'chain0_again_equal': z['same_request_again_chain0'] == out['chain'][0]}
    (W / 'tokens.json').write_text(json.dumps(out))
    print(json.dumps({'issuer_exit': code, 'chain': len(out['chain']), 'race': len(out['race']), 'deterministic': out['deterministic'],
                      'amount_1001': out['issuer_answers']['amount_1001'], 'trailing_output': rest.decode()[:200]}))
    return 0 if code == 0 else 1


if __name__ == '__main__':
    sys.exit(main())
