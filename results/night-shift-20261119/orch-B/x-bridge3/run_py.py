"""x-bridge3: run vectors.json through the PYTHON REFERENCE (copies in ref/: decide2.py, frame.py, launcher.py,
dafny_side2.cjs). Output: one JSON result per vector. Usage: python3 -I run_py.py <out.json>"""
import hashlib, importlib.util, json, os, subprocess, sys, time
X = os.path.dirname(os.path.abspath(__file__))
REF = os.path.join(X, 'ref')
CORE = '<REPO>/results/night-shift-20261119/orch-B/d-corebacked/build/shellcore-orig.cjs'
NODE = '/opt/homebrew/bin/node'
BIN = os.path.join(X, 'bin', 'refund')
PIN = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
WR = os.path.join(X, 'run', 'work-py')
os.makedirs(WR, exist_ok=True)

def load(n, p):
    s = importlib.util.spec_from_file_location(n, p); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
D = load('decide2', os.path.join(REF, 'decide2.py'))
L = load('launcher', os.path.join(REF, 'launcher.py'))

class Checker:
    def __init__(self, mode):
        self.p = subprocess.Popen([NODE, os.path.join(REF, 'dafny_side2.cjs'), CORE] + ([mode] if mode else []),
                                  stdin=subprocess.PIPE, stdout=subprocess.PIPE, cwd=X, env={'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'HOME': os.path.join(X, 'home')})
    def __call__(self, c, h):
        t = {'request': {'requestId': c.request.request_id, 'amount': str(c.request.amount), 'reason': c.request.reason},
             'post': D.state_json(c.post), 'intent': D.intent_json(c.intent)}
        self.p.stdin.write((json.dumps({'pre': D.state_json(c.pre), 'preStateSha256': h, 't': t}) + '\n').encode()); self.p.stdin.flush()
        a = json.loads(self.p.stdout.readline())
        if 'error' in a: raise RuntimeError(a['error'])
        return a['issue'] is True and a['plan'] == 1 and a['tokenOk'] is True
    def close(self):
        self.p.stdin.close(); self.p.wait(timeout=10)

def val(v):
    if 's' in v: return v['s']
    if 'i' in v: return int(v['i'])
    if 'fl' in v: return float(v['fl'])
    if 'b' in v: return bool(v['b'])
    f = [val(x) for x in v['f']]
    return {'Charge': D.Charge, 'Request': D.Request, 'Intent': D.Intent, 'Candidate': D.Candidate, 'tuple': lambda *a: tuple(a)}[v['t']](*f)

def pins():
    return {n: hashlib.sha256(open(os.path.join(X, 'standin', n), 'rb').read()).hexdigest() for n in os.listdir(os.path.join(X, 'standin'))}
PINS = pins()
SENT = {'DYLD_INSERT_LIBRARIES': '/nonexistent/forge-x.dylib', 'LD_PRELOAD': '/nonexistent/x.so', 'FORGE_SENTINEL': 'leak'}

def main():
    vec = json.load(open(os.path.join(X, 'vectors.json')))
    chk = {m: Checker(m) for m in (None, 'ignore-post', 'ignore-intent', 'accept-all')}
    out = []
    try:
        for v in vec:
            r = {'id': v['id']}
            if v['kind'] == 'bridge':
                c = val(v['cand'])
                b = v['binary']
                path = BIN if b == 'real' else os.path.join(X, 'standin', b[8:]) if b.startswith('standin:') else b[4:]
                pin = PIN if v['pin'] == 'real' else PINS[b[8:]] if v['pin'] == 'standin' else '00' * 32
                if v.get('parent_env'): os.environ.update(SENT)
                gp = os.path.join(X, 'run', 'grandchild.pid')
                if v.get('grandchild') and os.path.exists(gp): os.remove(gp)
                t0 = time.monotonic()
                try:
                    d, lr = D.bridge2(c, checker=chk[v['checker']], binary_path=path, launch_fn=L.launch, pinned_sha256=pin,
                                      timeout_s=v['timeout_s'], work_root=WR)
                finally:
                    for k in SENT: os.environ.pop(k, None)
                r.update(sign=d.sign, reason=d.reason, token=d.token, launched=None if lr is None else lr.launched,
                         stdout=None if lr is None else lr.stdout.hex(), elapsed_lt_4s=time.monotonic() - t0 < 4.0)
                if v.get('grandchild'):
                    time.sleep(0.3)
                    try:
                        pid = int(open(gp).read())
                        try: os.kill(pid, 0); r['grandchild_alive'] = True
                        except ProcessLookupError: r['grandchild_alive'] = False
                    except (OSError, ValueError): r['grandchild_alive'] = None
            elif v['kind'] == 'planted':
                lr = dict(v['result']); lr['stdout'] = bytes.fromhex(lr['stdout'])
                fake = L.LaunchResult(lr['launched'], lr['refusal'], lr['stdout'], lr['exit_code'], lr['signal'], lr['timed_out'],
                                      lr['stderr_len'], lr['stdout_overflow'], lr['stdin_complete'], lr['copy_unchanged'], 0.0)
                d = D.decide2(val(v['cand']), v['issue'] if type(v['issue']) is bool else int(v['issue']), fake)
                r.update(sign=d.sign, reason=d.reason, token=d.token)
            elif v['kind'] == 'launch_env':
                auth = D.Candidate(D.Charge('ch_1', 100, 60, True), D.Request('req_1', 40, 'returned_item'),
                                   D.Charge('ch_1', 100, 20, True), D.Intent('ch_1', 'req_1', 40, 'returned_item'))
                lr = L.launch(BIN, PIN, D.native_wire(D.encode(auth.pre, auth.request)), 4096, work_root=WR, env=v['env'])
                r.update(launched=lr.launched, refusal=lr.refusal, stdout=lr.stdout.hex())
            elif v['kind'] == 'probe':
                auth = D.Candidate(D.Charge('ch_1', 100, 60, True), D.Request('req_1', 40, 'returned_item'),
                                   D.Charge('ch_1', 100, 20, True), D.Intent('ch_1', 'req_1', 40, 'returned_item'))
                wire = D.native_wire(D.encode(auth.pre, auth.request))
                os.environ.update(SENT)
                try:
                    lr = L.launch(os.path.join(X, 'standin', 'probe'), PINS['probe'], wire, 65536, timeout_s=10.0, work_root=WR)
                finally:
                    for k in SENT: os.environ.pop(k, None)
                p = json.loads(lr.stdout)
                r.update(envp=sorted(p['envp']), pyenv_bad=[k for k in p['pyenv'] if k.startswith(('DYLD_', 'LD_')) or k == 'FORGE_SENTINEL'],
                         fds=p['fds'], nonblock=p['nonblock'], cwd_list=p['cwd_list'], stdin_is_wire=p['stdin'] == wire.decode('latin-1'))
            out.append(r)
    finally:
        for c in chk.values(): c.close()
    json.dump(out, open(sys.argv[1], 'w'), indent=0, sort_keys=True)
    print('python reference: vectors', len(out), 'sign', sum(1 for r in out if r.get('sign')))

main()
