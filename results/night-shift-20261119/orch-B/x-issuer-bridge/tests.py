"""x-issuer-bridge tests. FINITE TESTS, TESTED-UNPROVED. No keys. Run under env -i.

  python3 -I tests.py vectors   writes run/vectors.json (input of dafny_side.cjs)
  python3 -I tests.py run       runs the suite with decide.py and launcher.py; writes run/results.json

Real binary: bin/refund, a copy of proposals/forge2-m1-conformance/artifacts/refund-arm64-macho
(SHA-256 b8ed5ec2...7bb8). Stand-ins (label STAND-IN): Python scripts in standin/, generated here, each
pinned to its own digest. They exist only to produce process outcomes the real binary does not give.
Dafny side: run/dafny_verdicts.json from dafny_side.cjs (compiled RefundFinality.Check).
"""
import hashlib
import importlib.util
import json
import os
import signal
import subprocess
import sys
import time

X = os.path.dirname(os.path.abspath(__file__))
RUN = os.path.join(X, 'run')
BIN = os.path.join(X, 'bin', 'refund')
DYLIB = os.path.join(X, 'bin', 'forged.dylib')
STANDIN = os.path.join(X, 'standin')
PY = '/Library/Frameworks/Python.framework/Versions/3.10/Resources/Python.app/Contents/MacOS/Python'  # no re-exec stub
PIN = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


def vec(name, c, o, r, e, q, a, why, post_rem=None):
    pre = {'chargeId': c, 'original': str(o), 'remaining': str(r), 'refundEnabled': e}
    post = dict(pre, remaining=str(r - a if post_rem is None else post_rem))
    return {'name': name, 'pre': pre, 'transition': {
        'request': {'requestId': q, 'amount': str(a), 'reason': why}, 'post': post,
        'intent': {'chargeId': c, 'requestId': q, 'amount': str(a), 'reason': why}}}


MAX = 9223372036854775807
VECTORS = [
    vec('auth', 'ch_1', 100, 60, True, 'req_1', 40, 'returned_item'),
    vec('reject-disabled', 'ch_1', 100, 60, False, 'req_1', 40, 'returned_item'),
    vec('zero', 'ch_1', 100, 60, True, 'req_0', 0, 'duplicate_charge'),
    vec('unicode', '\u00e9\u20ac\U0001F600 "q"\\', 500, 60, True, 'r 7\t)(', 60, 'service_not_delivered'),
    vec('max', 'c', MAX, MAX, True, 'r', MAX, 'returned_item'),
    vec('post-wrong', 'ch_1', 100, 60, True, 'req_1', 40, 'returned_item', post_rem=59),
]


def inputs_of(D, v):
    p, t = v['pre'], v['transition']['request']
    return D.CheckInputs(p['chargeId'], int(p['original']), int(p['remaining']), p['refundEnabled'],
                         t['requestId'], int(t['amount']), t['reason'])


def dafny_of(D, rows, name, **change):
    r = rows[name]
    d = D.DafnySide(True, int(r['amount']), r['reason'], r['chargeId'], r['requestId'], int(r['count'])) \
        if r['issue'] else D.DafnySide(False)
    return D.DafnySide(**{**d.__dict__, **change}) if change else d


# ------------------------------------------------------------------ stand-ins (STAND-IN, not the binary)
HONEST = b'(refund-result-v1 True 40 returned_item ch_1 req_1 1)'
STANDINS = {
    'truncated': "w(H[:20])",
    'empty': "pass",
    'two-frames': "w(H + H)",
    'trailing-newline': "w(H + b'\\n')",
    'stderr-noise': "w(H); os.write(2, b'warning\\n')",
    'sleep': "time.sleep(30)",
    'grandchild': ("w(H)\nif os.fork() == 0:\n    open(%r, 'w').write(str(os.getpid()))\n    time.sleep(30)\n"
                   "    os._exit(0)" % os.path.join(RUN, 'grandchild.pid')),
    'exit3': "w(H); sys.exit(3)",
    'sigterm': "w(H); os.kill(os.getpid(), signal.SIGTERM); time.sleep(5)",
    'flood': "w(b'(' * 1000000)",
    'field-authorized': "w(b'(refund-result-v1 False 0 \"\" \"\" \"\" 0)')",
    'field-amount': "w(H.replace(b' 40 ', b' 41 '))",
    'field-reason': "w(H.replace(b'returned_item', b'duplicate_charge'))",
    'field-charge': "w(H.replace(b'ch_1', b'ch_2'))",
    'field-request': "w(H.replace(b'req_1', b'req_2'))",
    'field-count': "w(H.replace(b' 1)', b' 2)'))",
    'honest': "w(H)",
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


# ------------------------------------------------------------------ suite
def run_suite(D, L, rows, pins):
    res = []
    wr = os.path.join(RUN, 'work')
    os.makedirs(wr, exist_ok=True)

    def check(name, got, want, extra=None):
        ok = (got == want)
        res.append({'test': name, 'want': want, 'got': got, 'pass': ok, **(extra or {})})

    def br(x, d, path=BIN, pin=PIN, timeout_s=10.0):
        dec, r = D.bridge(x, d, path, L.launch, pinned_sha256=pin, timeout_s=timeout_s, work_root=wr)
        if dec.sign != (dec.reason == 'SIGN'):                  # the sign flag decides, not the label
            dec = D.Decision(False, 'INCONSISTENT:%s:%s' % (dec.sign, dec.reason))
        return dec, r

    V = {v['name']: v for v in VECTORS}
    xa = inputs_of(D, V['auth'])
    # real binary, honest
    for n, want in (('auth', 'SIGN'), ('reject-disabled', 'BOTH_REFUSE'), ('zero', 'SIGN'), ('unicode', 'SIGN'),
                    ('max', 'SIGN'), ('post-wrong', 'DAFNY_REFUSE_NATIVE_AUTHORIZE')):
        dec, r = br(inputs_of(D, V[n]), dafny_of(D, rows, n))
        check('real/' + n, dec.reason, want, {'stdout': r.stdout.decode('latin-1') if r else None})
    uni = V['unicode']
    exp_uni = (b'(refund-result-v1 True 60 service_not_delivered "\xc3\xa9\xe2\x82\xac\xf0\x9f\x98\x80 \\"q\\"\\\\" '
               b'"r 7\\t)(" 1)')
    dec, r = br(inputs_of(D, uni), dafny_of(D, rows, 'unicode'))
    check('real/unicode-stdout-is-utf8-literal', (dec.reason, r.stdout if r else None), ('SIGN', exp_uni))
    # real binary, Dafny side altered in one field (models a wrong Dafny compile)
    for f, ch in (('amount', {'amount': 41}), ('reason', {'reason': 'duplicate_charge'}),
                  ('charge', {'charge_id': 'ch_2'}), ('request', {'request_id': 'req_2'}), ('count', {'count': 2})):
        dec, _ = br(xa, dafny_of(D, rows, 'auth', **ch))
        check('real/dafny-differs-' + f, dec.reason, 'MISMATCH_' + f.upper())
    dec, _ = br(inputs_of(D, V['reject-disabled']), dafny_of(D, rows, 'auth'))
    check('real/dafny-differs-authorized', dec.reason, 'MISMATCH_AUTHORIZED')
    # out of range: refused before launch
    for n, x in (('amount>MAX', xa.__class__(**{**xa.__dict__, 'amount': MAX + 1})),
                 ('remaining<0', xa.__class__(**{**xa.__dict__, 'remaining': -1})),
                 ('id-257', xa.__class__(**{**xa.__dict__, 'request_id': 'r' * 257})),
                 ('id-129-astral', xa.__class__(**{**xa.__dict__, 'request_id': '\U0001F600' * 129})),
                 ('id-nul', xa.__class__(**{**xa.__dict__, 'charge_id': 'c\x00'})),
                 ('lone-surrogate', xa.__class__(**{**xa.__dict__, 'reason': '\ud800'})),
                 ('enabled-int', xa.__class__(**{**xa.__dict__, 'enabled': 1})),
                 ('amount-bool', xa.__class__(**{**xa.__dict__, 'amount': True}))):
        dec, r = br(x, dafny_of(D, rows, 'auth'))
        check('range/' + n, (dec.reason, r is None), ('OUT_OF_RANGE', True))
    # digest and path pinning
    dec, r = br(xa, dafny_of(D, rows, 'auth'), pin='00' * 32)
    check('pin/wrong-digest', (dec.reason, r.launched), ('DIGEST_MISMATCH', False))
    dec, r = br(xa, dafny_of(D, rows, 'auth'), path='bin/refund')
    check('pin/relative-path', (dec.reason, r.launched), ('PATH_NOT_ABSOLUTE', False))
    for n, e in (('dyld', dict(L.ALLOWED_ENV, DYLD_INSERT_LIBRARIES=DYLIB)), ('ld', {'LD_PRELOAD': 'x'}),
                 ('extra-name', dict(L.ALLOWED_ENV, HOME='/')), ('changed-value', {'CML_HEAP_SIZE': '1'})):
        r = L.launch(BIN, PIN, D.native_wire(xa), 4096, work_root=wr, env=e)
        check('env-arg/' + n, (r.launched, r.refusal), (False, 'ENV_NOT_ALLOWED'))
    # CE-3 on the real binary: DYLD_INSERT_LIBRARIES in the PARENT environment
    os.environ['DYLD_INSERT_LIBRARIES'] = DYLIB
    try:
        dec, r = br(xa, dafny_of(D, rows, 'auth'))
        check('dyld/real-hardened', (dec.reason, r.stdout), ('SIGN', HONEST))
    finally:
        del os.environ['DYLD_INSERT_LIBRARIES']
    # stand-ins (STAND-IN)
    d = dafny_of(D, rows, 'auth')
    for n, want in (('honest', 'SIGN'), ('truncated', 'FRAME_TRUNCATED'), ('empty', 'STDOUT_EMPTY'),
                    ('two-frames', 'STDOUT_OVERFLOW'), ('trailing-newline', 'STDOUT_OVERFLOW'),
                    ('stderr-noise', 'STDERR_NONEMPTY'), ('exit3', 'EXIT_NONZERO'), ('sigterm', 'SIGNAL'),
                    ('flood', 'STDOUT_OVERFLOW'), ('field-authorized', 'MISMATCH_AUTHORIZED'),
                    ('field-amount', 'MISMATCH_AMOUNT'), ('field-reason', 'STDOUT_OVERFLOW'),
                    ('field-charge', 'MISMATCH_CHARGE'), ('field-request', 'MISMATCH_REQUEST'),
                    ('field-count', 'MISMATCH_COUNT')):
        dec, _ = br(xa, d, path=os.path.join(STANDIN, n), pin=pins[n])
        check('standin/' + n, dec.reason, want)
    t0 = time.monotonic()
    dec, _ = br(xa, d, path=os.path.join(STANDIN, 'sleep'), pin=pins['sleep'], timeout_s=2.0)
    el = time.monotonic() - t0
    check('standin/timeout', (dec.reason, el < 4.0), ('TIMEOUT', True), {'elapsed_s': round(el, 3)})
    gp = os.path.join(RUN, 'grandchild.pid')
    if os.path.exists(gp):
        os.remove(gp)
    t0 = time.monotonic()
    dec, _ = br(xa, d, path=os.path.join(STANDIN, 'grandchild'), pin=pins['grandchild'], timeout_s=2.0)
    el = time.monotonic() - t0
    time.sleep(0.3)
    alive = None
    try:
        pid = int(open(gp).read())
        try:
            os.kill(pid, 0); alive = True
        except ProcessLookupError:
            alive = False
    except (OSError, ValueError):
        pass
    check('standin/grandchild-holds-stdout', (dec.reason, el < 4.0, alive), ('TIMEOUT', True, False))
    # environment, descriptors, cwd, stdin bytes (probe STAND-IN); parent has hostile variables
    extra_fd = os.open(os.devnull, os.O_RDONLY)
    os.set_inheritable(extra_fd, True)
    saved = {k: os.environ.get(k) for k in ('DYLD_INSERT_LIBRARIES', 'LD_PRELOAD', 'FORGE_SENTINEL')}
    os.environ.update({'DYLD_INSERT_LIBRARIES': '/nonexistent/forge-x.dylib', 'LD_PRELOAD': '/nonexistent/x.so',
                       'FORGE_SENTINEL': 'leak'})
    try:
        wire = D.native_wire(xa)
        r = L.launch(os.path.join(STANDIN, 'probe'), pins['probe'], wire, 65536, timeout_s=10.0, work_root=wr)
        try:
            p = json.loads(r.stdout)
        except ValueError:
            p = {}
    finally:
        os.close(extra_fd)
        for k, v in saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
    check('probe/envp-exact-allow-list', sorted(p.get('envp', ['missing'])), sorted('%s=%s' % kv for kv in L.ALLOWED_ENV.items()))
    check('probe/no-DYLD-LD-sentinel', [k for k in p.get('pyenv', ['missing']) if k.startswith(('DYLD_', 'LD_'))
                                        or k == 'FORGE_SENTINEL' or k == 'missing'], [])
    check('probe/only-fds-0-1-2', p.get('fds'), [0, 1, 2])
    check('probe/child-ends-blocking', p.get('nonblock'), {'0': False, '1': False, '2': False})
    check('probe/cwd-empty', p.get('cwd_list'), [])
    check('probe/stdin-exact-bytes', p.get('stdin'), wire.decode('latin-1'))
    # planted process results (no process): outcomes the cap or the real binary hide
    from types import SimpleNamespace as NS
    def pr(out, **kw):
        base = dict(launched=True, refusal='', stdout=out, exit_code=0, signal=None, timed_out=False, stderr_len=0,
                    stdout_overflow=False, stdin_complete=True, copy_unchanged=True)
        base.update(kw)
        return NS(**base)
    for n, r, want in (('honest', pr(HONEST), 'SIGN'),
                       ('two-frames', pr(HONEST + HONEST), 'FRAME_EXTRA_BYTES'),
                       ('trailing-byte', pr(HONEST + b' '), 'FRAME_EXTRA_BYTES'),
                       ('reason-differs', pr(HONEST.replace(b'returned_item', b'duplicate_charge')), 'MISMATCH_REASON'),
                       ('false-not-canonical', pr(b'(refund-result-v1 False 5 "" "" "" 0)'), 'REJECT_FRAME_NOT_CANONICAL'),
                       ('stdin-incomplete', pr(HONEST, stdin_complete=False), 'STDIN_INCOMPLETE'),
                       ('binary-changed', pr(HONEST, copy_unchanged=False), 'BINARY_CHANGED'),
                       ('non-canonical-int', pr(HONEST.replace(b' 40 ', b' 040 ')), 'FRAME_MALFORMED'),
                       ('exit0-truncated-CE1', pr(HONEST[:-1]), 'FRAME_TRUNCATED'),
                       ('exit0-empty-CE2', pr(b''), 'STDOUT_EMPTY'),
                       ('signal-with-frame', pr(HONEST, exit_code=None, signal=13), 'SIGNAL'),
                       ('timeout-with-frame', pr(HONEST, timed_out=True), 'TIMEOUT')):
        dd = D.decide(xa, d, r)
        check('planted/' + n, (dd.sign, dd.reason), (want == 'SIGN', want))
    return res


def main():
    os.makedirs(RUN, exist_ok=True)
    if sys.argv[1] == 'vectors':
        json.dump(VECTORS, open(os.path.join(RUN, 'vectors.json'), 'w'), indent=1)
        return 0
    D = load('decide', os.path.join(X, 'decide.py'))
    L = load('launcher', os.path.join(X, 'launcher.py'))
    rows = {r['name']: r for r in json.load(open(os.path.join(RUN, 'dafny_verdicts.json')))}
    pins = make_standins()
    res = run_suite(D, L, rows, pins)
    # CE-3 reproduction control (NOT the launcher): the same request with the parent environment inherited
    env = dict(L.ALLOWED_ENV, DYLD_INSERT_LIBRARIES=DYLIB)
    p = subprocess.run([BIN], input=D.native_wire(inputs_of(D, VECTORS[0])), capture_output=True, env=env,
                       timeout=20)
    from types import SimpleNamespace
    fake = SimpleNamespace(launched=True, refusal='', stdout=p.stdout, exit_code=p.returncode, signal=None,
                           timed_out=False, stderr_len=len(p.stderr), stdout_overflow=False, stdin_complete=True,
                           copy_unchanged=True)
    dec = D.decide(inputs_of(D, VECTORS[0]), dafny_of(D, rows, 'auth'), fake)
    res.append({'test': 'dyld/control-inherited-env (not the launcher)', 'want': 'forged frame seen; bridge refuses',
                'got': [p.stdout.decode('latin-1'), p.returncode, dec.reason],
                'pass': p.stdout != HONEST and not dec.sign})
    n_ok = sum(r['pass'] for r in res)
    json.dump({'class': 'TESTED-UNPROVED (finite tests)', 'binary_sha256': PIN, 'total': len(res), 'passed': n_ok,
               'results': res}, open(os.path.join(RUN, 'results.json'), 'w'), indent=1, default=str)
    for r in res:
        print('PASS' if r['pass'] else 'FAIL', r['test'], r['got'] if not r['pass'] else '')
    print('total', len(res), 'passed', n_ok)
    return 0 if n_ok == len(res) else 1


if __name__ == '__main__':
    sys.exit(main())
