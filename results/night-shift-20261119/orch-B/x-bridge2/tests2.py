"""x-bridge2 tests. FINITE TESTS, TESTED-UNPROVED. No keys. Run under env -i:
  env -i PATH=/opt/homebrew/bin:/usr/bin:/bin HOME=<this dir> <python3> -I tests2.py run [quick] [decide2 path]
Real binary: bin/refund (copy, SHA-256 b8ed5ec2...7bb8). Checker: the COMPILED RefundFinality.Check through
dafny_side2.cjs (real), or the same file in a STAND-IN mode (a miscompiled-checker model). Stand-in native
programs (label STAND-IN): Python scripts in standin/, generated here, each pinned to its own digest.
`quick` skips the two slow launcher cases (timeout, grandchild) and the probe; mutants2.py uses it.
"""
import dataclasses
import hashlib
import importlib.util
import inspect
import json
import os
import subprocess
import sys
import time
from types import SimpleNamespace as NS

X = os.path.dirname(os.path.abspath(__file__))
RUN = os.path.join(X, 'run')
BIN = os.path.join(X, 'bin', 'refund')
DYLIB = os.path.join(X, 'bin', 'forged.dylib')
STANDIN = os.path.join(X, 'standin')
CORE = '/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-corebacked/build/shellcore-orig.cjs'
NODE = '/opt/homebrew/bin/node'
PY = '/Library/Frameworks/Python.framework/Versions/3.10/Resources/Python.app/Contents/MacOS/Python'
PIN = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
MAX = 9223372036854775807


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


class Checker:
    """One node process per mode; one JSON line per call. mode None = the real compiled Check."""
    def __init__(self, D, mode=None):
        self.D, self.mode = D, mode
        args = [NODE, os.path.join(X, 'dafny_side2.cjs'), CORE] + ([mode] if mode else [])
        self.p = subprocess.Popen(args, stdin=subprocess.PIPE, stdout=subprocess.PIPE, cwd=X,
                                  env={'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'HOME': X})

    def ask(self, obj):
        self.p.stdin.write((json.dumps(obj) + '\n').encode())
        self.p.stdin.flush()
        return json.loads(self.p.stdout.readline())

    def __call__(self, c, h):
        D = self.D
        t = {'request': {'requestId': c.request.request_id, 'amount': str(c.request.amount),
                         'reason': c.request.reason},
             'post': D.state_json(c.post), 'intent': D.intent_json(c.intent)}
        a = self.ask({'pre': D.state_json(c.pre), 'preStateSha256': h, 't': t})
        if 'error' in a:
            raise RuntimeError(a['error'])
        return a['issue'] is True and a['plan'] == 1 and a['tokenOk'] is True

    def close(self):
        self.p.stdin.close()
        self.p.wait(timeout=10)


def cand(D, c, o, r, e, q, a, why, post=None, intent=None):
    pre = D.Charge(c, o, r, e)
    p = D.Charge(c, o, r - a, e) if post is None else post
    i = D.Intent(c, q, a, why) if intent is None else intent
    return D.Candidate(pre, D.Request(q, a, why), p, i)


def with_(obj, **kw):
    return dataclasses.replace(obj, **kw)


HONEST = b'(refund-result-v1 True 40 returned_item ch_1 req_1 1)'
STANDINS = {
    'honest': "w(H)", 'truncated': "w(H[:20])", 'empty': "pass", 'two-frames': "w(H + H)",
    'trailing-newline': "w(H + b'\\n')", 'stderr-noise': "w(H); os.write(2, b'warning\\n')",
    'sleep': "time.sleep(30)",
    'grandchild': ("w(H)\nif os.fork() == 0:\n    open(%r, 'w').write(str(os.getpid()))\n    time.sleep(30)\n"
                   "    os._exit(0)" % os.path.join(RUN, 'grandchild.pid')),
    'exit3': "w(H); sys.exit(3)", 'sigterm': "w(H); os.kill(os.getpid(), signal.SIGTERM); time.sleep(5)",
    'flood': "w(b'(' * 1000000)",
    'field-authorized': "w(b'(refund-result-v1 False 0 \"\" \"\" \"\" 0)')",
    'field-amount': "w(H.replace(b' 40 ', b' 39 '))",
    'field-reason': "w(H.replace(b'returned_item', b'returned_itex'))",
    'field-charge': "w(H.replace(b'ch_1', b'ch_2'))",
    'field-request': "w(H.replace(b'req_1', b'req_2'))",
    'field-count': "w(H.replace(b' 1)', b' 2)'))",
    'authorize-all': "sys.stdin.buffer.read(); w(H)",     # a WRONG native: authorizes whatever it is asked
    'probe': ("import fcntl, json\nfds = [f for f in range(256) if _isopen(f)]\n"
              "nb = {f: bool(fcntl.fcntl(f, fcntl.F_GETFL) & os.O_NONBLOCK) for f in (0, 1, 2)}\n"
              "import ctypes, struct\nlibc = ctypes.CDLL(None)\n"
              "mib = (ctypes.c_int * 3)(1, 49, os.getpid()); n = ctypes.c_size_t(1 << 20)\n"
              "buf = ctypes.create_string_buffer(n.value)\nassert libc.sysctl(mib, 3, buf, ctypes.byref(n), None, 0) == 0\n"
              "raw = buf.raw[:n.value]; argc = struct.unpack('i', raw[:4])[0]; rest = raw[4:]\n"
              "rest = rest[rest.index(b'\\0'):].lstrip(b'\\0'); parts = rest.split(b'\\0')\n"
              "envp = [e.decode('latin-1') for e in parts[argc:parts.index(b'', argc)]]\n"
              "w(json.dumps({'envp': envp, 'pyenv': sorted(os.environ), 'fds': fds, 'nonblock': nb, 'cwd_list': os.listdir('.'),"
              " 'stdin': sys.stdin.buffer.read().decode('latin-1')}).encode())"),
}
PRELUDE = ("#!%s -IS\nimport os, sys, time, signal\nH = %r\n"
           "def w(b):\n    v = memoryview(b)\n    while v:\n        v = v[os.write(1, v):]\n"
           "def _isopen(f):\n    try:\n        os.fstat(f); return True\n    except OSError:\n        return False\n")


def make_standins():
    os.makedirs(STANDIN, exist_ok=True)
    pins = {}
    for k, body in STANDINS.items():
        p = os.path.join(STANDIN, k)
        if os.path.exists(p):
            os.remove(p)
        with open(p, 'w') as f:
            f.write(PRELUDE % (PY, HONEST) + body + '\n')
        os.chmod(p, 0o500)
        pins[k] = hashlib.sha256(open(p, 'rb').read()).hexdigest()
    return pins


def run_suite(D, L, chk, pins, quick):
    res = []
    wr = os.path.join(RUN, 'work')
    os.makedirs(wr, exist_ok=True)

    def check(name, got, want, extra=None):
        res.append({'test': name, 'want': want, 'got': got, 'pass': got == want, **(extra or {})})

    def br(c, checker=None, path=BIN, pin=PIN, timeout_s=10.0):
        dec, r = D.bridge2(c, checker=checker or chk[None], binary_path=path, launch_fn=L.launch,
                           pinned_sha256=pin, timeout_s=timeout_s, work_root=wr)
        if dec.sign != (dec.reason == 'SIGN') or dec.sign != (dec.token is not None):
            dec = D.Decision(False, 'INCONSISTENT:%s:%s' % (dec.sign, dec.reason))
        return dec, r

    auth = cand(D, 'ch_1', 100, 60, True, 'req_1', 40, 'returned_item')
    uni = cand(D, '\u00e9\u20ac\U0001F600 "q"\\\t', 500, 60, True, 'r 7\t)(', 60, 'service_not_delivered')
    honest = {'auth': auth, 'zero': cand(D, 'ch_1', 100, 60, True, 'req_0', 0, 'duplicate_charge'),
              'unicode': uni, 'max': cand(D, 'c', MAX, MAX, True, 'r', MAX, 'returned_item')}
    # 1. honest inputs, real binary, real compiled Check
    for n, c in honest.items():
        dec, r = br(c)
        check('real/' + n, dec.reason, 'SIGN', {'stdout': r.stdout.decode('utf-8', 'replace') if r else None})
        if dec.sign:
            js = chk[None].ask({'canonOf': D.state_json(c.pre)})['sha']
            want_tok = {'preStateSha256': js, 'requestId': c.request.request_id, 'post': D.state_json(c.post),
                        'intent': D.intent_json(c.intent)}
            check('real/%s-token-recomputed-and-hash-equals-JS-canon' % n, dec.token, want_tok)
    exp_uni = (b'(refund-result-v1 True 60 service_not_delivered "\xc3\xa9\xe2\x82\xac\xf0\x9f\x98\x80 \\"q\\"\\\\\\t" '
               b'"r 7\\t)(" 1)')
    dec, r = br(uni)
    check('real/unicode-stdout-is-utf8-literal', (dec.reason, r.stdout if r else None), ('SIGN', exp_uni))
    dec, r = br(cand(D, 'ch_1', 100, 60, False, 'req_1', 40, 'returned_item'))
    check('real/reject-disabled', (dec.reason, r is None), ('CHECK_REFUSE', True))
    dec, _ = br(with_(auth, post=D.Charge('ch_1', 100, 59, True)))
    check('real/post-wrong-real-check', dec.reason, 'CHECK_REFUSE')
    # 2. reviewer H: a MISCOMPILED Check (STAND-IN) with the real native program
    for n, post in (('remaining', D.Charge('ch_1', 100, 59, True)), ('original', D.Charge('ch_1', 101, 20, True)),
                    ('chargeId', D.Charge('ch_X', 100, 20, True)), ('enabled', D.Charge('ch_1', 100, 20, False))):
        dec, _ = br(with_(auth, post=post), checker=chk['ignore-post'])
        check('H/miscompiled-ignore-post/wrong-post-' + n, dec.reason, 'POST_MISMATCH')
    for n, intent in (('chargeId', D.Intent('ch_2', 'req_1', 40, 'returned_item')),
                      ('requestId', D.Intent('ch_1', 'req_2', 40, 'returned_item')),
                      ('amount', D.Intent('ch_1', 'req_1', 41, 'returned_item')),
                      ('reason', D.Intent('ch_1', 'req_1', 40, 'duplicate_charge'))):
        dec, _ = br(with_(auth, intent=intent), checker=chk['ignore-intent'])
        check('H/miscompiled-ignore-intent/wrong-intent-' + n, dec.reason, 'INTENT_MISMATCH')
    dec, _ = br(auth, checker=chk['ignore-post'])
    check('H/miscompiled-checker-honest-candidate-still-signs', dec.reason, 'SIGN')
    dec, _ = br(cand(D, 'ch_1', 100, 30, True, 'req_1', 40, 'returned_item'), checker=chk['accept-all'])
    check('H/accept-all-check/amount-over-remaining', dec.reason, 'FRAME_NOT_AUTHORIZED_TUPLE')
    # 3. reviewer M (E1-E3): the interface has ONE data input; mismatched inputs become one candidate
    ps = list(inspect.signature(D.bridge2).parameters.values())
    check('M/interface-one-data-input', [(p.name, p.kind.name) for p in ps if p.kind.name != 'KEYWORD_ONLY'],
          [('candidate', 'POSITIONAL_OR_KEYWORD')])
    try:
        D.bridge2(auth, x=auth, checker=chk[None], binary_path=BIN, launch_fn=L.launch)
        got = 'accepted'
    except TypeError:
        got = 'TypeError'
    check('M/interface-rejects-separate-native-inputs', got, 'TypeError')
    for n, pre in (('E1-remaining-50', D.Charge('ch_1', 100, 50, True)), ('E2-original-1000', D.Charge('ch_1', 1000, 60, True)),
                   ('E3-remaining-40', D.Charge('ch_1', 100, 40, True))):
        c = with_(auth, pre=pre)                  # t (post 100/20) was built for pre (100, 60)
        dec, _ = br(c)
        check('M/%s/real-check' % n, dec.reason, 'CHECK_REFUSE')
        dec, _ = br(c, checker=chk['accept-all'])
        check('M/%s/accept-all-check' % n, dec.reason, 'POST_MISMATCH')
    # 4. reviewer E5/E6: types and the range check inside decide2
    dec, r = br(with_(auth, request=D.Request('req_1', True, 'returned_item')))
    check('E5/amount-bool', (dec.reason, r is None), ('OUT_OF_RANGE', True))
    dec, r = br(with_(auth, post=D.Charge('ch_1', 100, 20, 1)))
    check('E5/post-enabled-int', (dec.reason, r is None), ('OUT_OF_RANGE', True))
    # 5. a WRONG native program (STAND-IN authorize-all) with the real Check
    over = cand(D, 'ch_1', 100, 30, True, 'req_1', 40, 'returned_item')
    dec, r = br(over, path=os.path.join(STANDIN, 'authorize-all'), pin=pins['authorize-all'])
    check('native-wrong/authorize-all/real-check-refuses', (dec.reason, r is None), ('CHECK_REFUSE', True))
    dec, _ = br(over, checker=chk['accept-all'], path=os.path.join(STANDIN, 'authorize-all'), pin=pins['authorize-all'])
    check('both-wrong/outside-guarantee (expected SIGN)', dec.reason, 'SIGN')
    # 6. range: refused before the checker and before any launch
    for n, c in (('amount>MAX', with_(auth, request=D.Request('req_1', MAX + 1, 'returned_item'))),
                 ('remaining<0', with_(auth, pre=D.Charge('ch_1', 100, -1, True))),
                 ('id-257', with_(auth, request=D.Request('r' * 257, 40, 'returned_item'))),
                 ('id-129-astral', with_(auth, request=D.Request('\U0001F600' * 129, 40, 'returned_item'))),
                 ('id-nul', with_(auth, pre=D.Charge('c\x00', 100, 60, True))),
                 ('lone-surrogate', with_(auth, request=D.Request('req_1', 40, '\ud800'))),
                 ('enabled-int', with_(auth, pre=D.Charge('ch_1', 100, 60, 1))),
                 ('not-a-candidate', (auth.pre, auth.request))):
        dec, r = br(c)
        check('range/' + n, (dec.reason, r is None), ('OUT_OF_RANGE', True))
    # 7. pin and environment
    dec, r = br(auth, pin='00' * 32)
    check('pin/wrong-digest', (dec.reason, getattr(r, 'launched', None)), ('DIGEST_MISMATCH', False))
    dec, r = br(auth, path='bin/refund')
    check('pin/relative-path', (dec.reason, getattr(r, 'launched', None)), ('PATH_NOT_ABSOLUTE', False))
    wire = D.native_wire(D.encode(auth.pre, auth.request))
    for n, e in (('dyld', dict(L.ALLOWED_ENV, DYLD_INSERT_LIBRARIES=DYLIB)), ('ld', {'LD_PRELOAD': 'x'}),
                 ('extra-name', dict(L.ALLOWED_ENV, HOME='/')), ('changed-value', {'CML_HEAP_SIZE': '1'})):
        r = L.launch(BIN, PIN, wire, 4096, work_root=wr, env=e)
        check('env-arg/' + n, (r.launched, r.refusal), (False, 'ENV_NOT_ALLOWED'))
    os.environ['DYLD_INSERT_LIBRARIES'] = DYLIB
    try:
        dec, r = br(auth)
        check('dyld/parent-env-real-binary-hardened', (dec.reason, getattr(r, 'stdout', None)), ('SIGN', HONEST))
    finally:
        del os.environ['DYLD_INSERT_LIBRARIES']
    # 8. stand-in process outcomes (STAND-IN), real Check, auth candidate
    for n, want in (('honest', 'SIGN'), ('truncated', 'NO_FRAME'), ('empty', 'NO_FRAME'),
                    ('two-frames', 'STDOUT_OVERFLOW'), ('trailing-newline', 'STDOUT_OVERFLOW'),
                    ('stderr-noise', 'STDERR_NONEMPTY'), ('exit3', 'EXIT_NONZERO'), ('sigterm', 'SIGNAL'),
                    ('flood', 'STDOUT_OVERFLOW'), ('field-authorized', 'FRAME_NOT_AUTHORIZED_TUPLE'),
                    ('field-amount', 'FRAME_NOT_AUTHORIZED_TUPLE'), ('field-reason', 'FRAME_NOT_AUTHORIZED_TUPLE'),
                    ('field-charge', 'FRAME_NOT_AUTHORIZED_TUPLE'), ('field-request', 'FRAME_NOT_AUTHORIZED_TUPLE'),
                    ('field-count', 'FRAME_NOT_AUTHORIZED_TUPLE')):
        dec, _ = br(auth, path=os.path.join(STANDIN, n), pin=pins[n])
        check('standin/' + n, dec.reason, want)
    if not quick:
        t0 = time.monotonic()
        dec, _ = br(auth, path=os.path.join(STANDIN, 'sleep'), pin=pins['sleep'], timeout_s=2.0)
        el = time.monotonic() - t0
        check('standin/timeout', (dec.reason, el < 4.0), ('TIMEOUT', True), {'elapsed_s': round(el, 3)})
        gp = os.path.join(RUN, 'grandchild.pid')
        if os.path.exists(gp):
            os.remove(gp)
        t0 = time.monotonic()
        dec, _ = br(auth, path=os.path.join(STANDIN, 'grandchild'), pin=pins['grandchild'], timeout_s=2.0)
        el = time.monotonic() - t0
        time.sleep(0.3)
        alive = None
        try:
            pid = int(open(gp).read())
            try:
                os.kill(pid, 0)
                alive = True
            except ProcessLookupError:
                alive = False
        except (OSError, ValueError):
            pass
        check('standin/grandchild-holds-stdout', (dec.reason, el < 4.0, alive), ('TIMEOUT', True, False))
        saved = {k: os.environ.get(k) for k in ('DYLD_INSERT_LIBRARIES', 'LD_PRELOAD', 'FORGE_SENTINEL')}
        os.environ.update({'DYLD_INSERT_LIBRARIES': '/nonexistent/forge-x.dylib', 'LD_PRELOAD': '/nonexistent/x.so',
                           'FORGE_SENTINEL': 'leak'})
        try:
            r = L.launch(os.path.join(STANDIN, 'probe'), pins['probe'], wire, 65536, timeout_s=10.0, work_root=wr)
            try:
                p = json.loads(r.stdout)
            except ValueError:
                p = {}
        finally:
            for k, v in saved.items():
                if v is None:
                    os.environ.pop(k, None)
                else:
                    os.environ[k] = v
        check('probe/envp-exact-allow-list', sorted(p.get('envp', ['missing'])),
              sorted('%s=%s' % kv for kv in L.ALLOWED_ENV.items()))
        check('probe/no-DYLD-LD-sentinel', [k for k in p.get('pyenv', ['missing']) if k.startswith(('DYLD_', 'LD_'))
                                            or k in ('FORGE_SENTINEL', 'missing')], [])
        check('probe/only-fds-0-1-2', p.get('fds'), [0, 1, 2])
        check('probe/child-ends-blocking', p.get('nonblock'), {'0': False, '1': False, '2': False})
        check('probe/cwd-empty', p.get('cwd_list'), [])
        check('probe/stdin-is-encode(pre,request)', p.get('stdin'), wire.decode('latin-1'))
    # 9. planted launcher results (no process)
    def pr(out, **kw):
        base = dict(launched=True, refusal='', stdout=out, exit_code=0, signal=None, timed_out=False, stderr_len=0,
                    stdout_overflow=False, stdin_complete=True, copy_unchanged=True)
        base.update(kw)
        return NS(**base)
    for n, c, r, want in (('honest', auth, pr(HONEST), 'SIGN'),
                          ('two-frames', auth, pr(HONEST + HONEST), 'NO_FRAME'),
                          ('trailing-byte', auth, pr(HONEST + b' '), 'NO_FRAME'),
                          ('non-canonical-int', auth, pr(HONEST.replace(b' 40 ', b' 040 ')), 'NO_FRAME'),
                          ('exit0-truncated-CE1', auth, pr(HONEST[:-1]), 'NO_FRAME'),
                          ('exit0-empty-CE2', auth, pr(b''), 'NO_FRAME'),
                          ('stdin-incomplete', auth, pr(HONEST, stdin_complete=False), 'STDIN_INCOMPLETE'),
                          ('binary-changed', auth, pr(HONEST, copy_unchanged=False), 'BINARY_CHANGED'),
                          ('signal-with-frame', auth, pr(HONEST, exit_code=None, signal=13), 'SIGNAL'),
                          ('timeout-with-frame', auth, pr(HONEST, timed_out=True), 'TIMEOUT'),
                          ('stderr-with-frame', auth, pr(HONEST, stderr_len=1), 'STDERR_NONEMPTY'),
                          ('exit1-with-frame', auth, pr(HONEST, exit_code=1), 'EXIT_NONZERO'),
                          ('overflow-with-frame', auth, pr(HONEST, stdout_overflow=True), 'STDOUT_OVERFLOW'),
                          ('not-launched', auth, pr(b'', launched=False, refusal='DIGEST_MISMATCH'), 'DIGEST_MISMATCH'),
                          ('E6-out-of-range-honest-run', with_(auth, pre=D.Charge('ch_1', 100, 60, 1)), pr(HONEST),
                           'OUT_OF_RANGE'),
                          ('reject-frame', auth, pr(b'(refund-result-v1 False 0 "" "" "" 0)'), 'FRAME_NOT_AUTHORIZED_TUPLE')):
        dd = D.decide2(c, True, r)
        check('planted/' + n, (dd.sign, dd.reason), (want == 'SIGN', want))
    dd = D.decide2(auth, 1, pr(HONEST))
    check('planted/issue-int-not-True', (dd.sign, dd.reason), (False, 'CHECK_REFUSE'))
    return res


def main():
    os.makedirs(RUN, exist_ok=True)
    quick = 'quick' in sys.argv[2:]
    dpath = next((a for a in sys.argv[2:] if a.endswith('.py')), os.path.join(X, 'decide2.py'))
    D = load('decide2', dpath)
    L = load('launcher', os.path.join(X, 'launcher.py'))
    pins = make_standins()
    chk = {m: Checker(D, m) for m in (None, 'ignore-post', 'ignore-intent', 'accept-all')}
    try:
        res = run_suite(D, L, chk, pins, quick)
        if not quick:
            # reject-all control: a bridge that never signs fails every positive test
            ra = NS(**{k: getattr(D, k) for k in dir(D) if not k.startswith('__')})
            ra.bridge2 = lambda c, **kw: (D.Decision(False, 'REJECT_ALL'), None)
            ra.decide2 = lambda c, i, r: D.Decision(False, 'REJECT_ALL')
            rr = run_suite(ra, load('launcher_ra', os.path.join(X, 'launcher.py')), chk, pins, True)
            pos = [r for r in rr if r['want'] == 'SIGN' or (isinstance(r['want'], tuple) and 'SIGN' in r['want'])]
            res.append({'test': 'control/reject-all-fails-positive-tests', 'want': True,
                        'got': len(pos) > 0 and not any(r['pass'] for r in pos), 'n_positive': len(pos),
                        'pass': len(pos) > 0 and not any(r['pass'] for r in pos)})
            # CE-3 control on the COPY of the M1 binary (not the launcher): inherited DYLD_INSERT_LIBRARIES
            auth = cand(D, 'ch_1', 100, 60, True, 'req_1', 40, 'returned_item')
            env = dict(L.ALLOWED_ENV, DYLD_INSERT_LIBRARIES=DYLIB)
            p = subprocess.run([BIN], input=D.native_wire(D.encode(auth.pre, auth.request)), capture_output=True,
                               env=env, timeout=20)
            fake = NS(launched=True, refusal='', stdout=p.stdout, exit_code=p.returncode, signal=None,
                      timed_out=False, stderr_len=len(p.stderr), stdout_overflow=False, stdin_complete=True,
                      copy_unchanged=True)
            dec = D.decide2(auth, True, fake)
            res.append({'test': 'dyld/control-inherited-env (not the launcher)', 'want': 'forged frame; refuse',
                        'got': [p.stdout.decode('latin-1'), p.returncode, dec.reason],
                        'pass': p.stdout != HONEST and not dec.sign})
    finally:
        for c in chk.values():
            c.close()
    n_ok = sum(r['pass'] for r in res)
    tag = 'quick' if quick else 'full'
    if dpath == os.path.join(X, 'decide2.py'):
        json.dump({'class': 'TESTED-UNPROVED (finite tests)', 'binary_sha256': PIN, 'total': len(res), 'passed': n_ok,
                   'results': res}, open(os.path.join(RUN, 'results2.%s.json' % tag), 'w'), indent=1, default=str)
    for r in res:
        print('PASS' if r['pass'] else 'FAIL', r['test'], '' if r['pass'] else r['got'])
    print('total', len(res), 'passed', n_ok)
    return 0 if n_ok == len(res) else 1


if __name__ == '__main__':
    sys.exit(main())
