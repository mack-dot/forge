"""r-drafts attack E (adversarial review of x-issuer-bridge). FINITE TESTS, TESTED-UNPROVED. Own cases (not tests.py).
Real binary (read-only copy x-issuer-bridge/bin/refund) on honest well-formed inputs only; new stand-ins are
small Python scripts in this directory, each pinned to its own digest. Run: python3 -I e_bridge.py <out.json>
"""
import hashlib, importlib.util, json, os, signal, sys, time

E = os.path.dirname(os.path.abspath(__file__))
R3 = os.path.join(os.path.dirname(E), 'r3')                    # byte-equal copies of decide.py, launcher.py, frame.py
XB = '/Users/mackianni/forge/results/night-shift-20261119/orch-B/x-issuer-bridge'
BIN = os.path.join(XB, 'bin', 'refund')
PIN = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
PY = '/Library/Frameworks/Python.framework/Versions/3.10/Resources/Python.app/Contents/MacOS/Python'
WORK = os.path.join(E, 'work'); os.makedirs(WORK, exist_ok=True)


def load(name, path):
    s = importlib.util.spec_from_file_location(name, path); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m


D = load('decide', os.path.join(R3, 'decide.py'))
L = load('launcher', os.path.join(R3, 'launcher.py'))
rows = {r['name']: r for r in json.load(open(os.path.join(XB, 'run', 'dafny_verdicts.json')))}
auth = rows['auth']
D_AUTH = D.DafnySide(True, int(auth['amount']), auth['reason'], auth['chargeId'], auth['requestId'], int(auth['count']))
# the Dafny row 'auth' was computed on pre (ch_1, original 100, remaining 60, enabled), request (req_1, 40, returned_item)
X_AUTH = D.CheckInputs('ch_1', 100, 60, True, 'req_1', 40, 'returned_item')

H = b'(refund-result-v1 True 40 returned_item ch_1 req_1 1)'
PRE = ("#!%s -IS\nimport os, sys, time\nH = %r\n"
       "def w(b):\n    v = memoryview(b)\n    while v:\n        v = v[os.write(1, v):]\n") % (PY, H)
STAND = {
    # closes stdout after half a frame, reopens fd 1 on /dev/null, writes the rest there, exits 0
    'reopen-stdout': "w(H[:25]); os.close(1); fd = os.open('/dev/null', os.O_WRONLY); assert fd == 1; w(H[25:])",
    # closes stdout first (parent sees EOF), then writes nothing, sleeps 1 s, exits 0
    'close-early': "os.close(1); time.sleep(1)",
    # a grandchild that leaves the process group (setsid) and closes its pipes: survives killpg
    'setsid-grandchild': ("w(H)\npid = os.fork()\nif pid == 0:\n    os.setsid(); os.close(0); os.close(1); os.close(2)\n"
                          "    open(%r, 'w').write(str(os.getpid())); time.sleep(4); os._exit(0)\ntime.sleep(0.3)")
                         % os.path.join(WORK, 'setsid.pid'),
    # writes the honest frame, then exits 0 while stdin is still unread (input not consumed)
    'ignore-stdin': "w(H)",
}


def make():
    pins = {}
    d = os.path.join(E, 'standin'); os.makedirs(d, exist_ok=True)
    for k, body in STAND.items():
        p = os.path.join(d, k)
        if os.path.exists(p): os.remove(p)
        open(p, 'w').write(PRE + body + '\n'); os.chmod(p, 0o500)
        pins[k] = hashlib.sha256(open(p, 'rb').read()).hexdigest()
    return d, pins


def main(out):
    sd, pins = make()
    res = []

    def br(name, x, d, path=BIN, pin=PIN, want=None, note=''):
        dec, r = D.bridge(x, d, path, L.launch, pinned_sha256=pin, timeout_s=10.0, work_root=WORK)
        got = 'SIGN' if dec.sign else dec.reason
        res.append({'case': name, 'want': want, 'got': got, 'pass': got == want, 'note': note,
                    'stdout': (r.stdout.decode('latin-1')[:80] if r else None), 'exit': (r.exit_code if r else None)})

    # E1-E3: the glue gap. d is the Dafny verdict for pre (100, 60); x (what the native binary runs on) is another pre.
    br('E1 glue: x.remaining=50, d from remaining=60', D.CheckInputs('ch_1', 100, 50, True, 'req_1', 40, 'returned_item'), D_AUTH,
       want='SIGN', note='FINDING if SIGN: native checked another pre-state than Dafny; decide() cannot see it')
    br('E2 glue: x.original=1000', D.CheckInputs('ch_1', 1000, 60, True, 'req_1', 40, 'returned_item'), D_AUTH, want='SIGN',
       note='FINDING if SIGN: original/remaining/enabled are not compared')
    br('E3 glue: x.remaining=40 (boundary), d from 60', D.CheckInputs('ch_1', 100, 40, True, 'req_1', 40, 'returned_item'), D_AUTH, want='SIGN')
    # E4: Dafny refuses, native authorizes
    br('E4 d=Refuse, native authorizes', X_AUTH, D.DafnySide(False), want='DAFNY_REFUSE_NATIVE_AUTHORIZE')
    # E5: a Dafny side with a bool amount (type confusion True == 1 in Python)
    br('E5 d.amount=True, x.amount=1', D.CheckInputs('ch_1', 100, 60, True, 'req_1', 1, 'returned_item'),
       D.DafnySide(True, True, 'returned_item', 'ch_1', 'req_1', 1), want='MISMATCH_BYTES',
       note='the field compare accepts True == 1; only the byte compare refuses')
    # E6: decide() alone on an out-of-range x (bridge() checks range; decide() does not)
    r = L.launch(BIN, PIN, D.native_wire(X_AUTH), D.stdout_cap(X_AUTH), timeout_s=10.0, work_root=WORK)
    xbad = D.CheckInputs('ch_1', 100, -1, True, 'req_1', 40, 'returned_item')
    dd = D.decide(xbad, D_AUTH, r)
    res.append({'case': 'E6 decide() with out-of-range x and an honest run', 'want': 'SIGN (decide has no range check)',
                'got': 'SIGN' if dd.sign else dd.reason, 'pass': dd.sign, 'note': 'Bridge.dfy puts inRange inside the decision; decide.py does not'})
    # E7-E11: launcher
    link = os.path.join(WORK, 'refund-link')
    if os.path.lexists(link): os.remove(link)
    os.symlink(BIN, link)
    br('E7 binary path is a symlink (last component)', X_AUTH, D_AUTH, path=link, want='BINARY_OPEN_FAILED')
    dlink = os.path.join(WORK, 'dirlink')
    if os.path.lexists(dlink): os.remove(dlink)
    os.symlink(os.path.dirname(BIN), dlink)
    br('E8 directory symlink in the path', X_AUTH, D_AUTH, path=os.path.join(dlink, 'refund'), want='SIGN',
       note='O_NOFOLLOW covers the last component only; content is hashed, so this is allowed')
    rr = L.launch(BIN, PIN, D.native_wire(X_AUTH), 4096, env={'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256', 'DYLD_INSERT_LIBRARIES': '/x'})
    res.append({'case': 'E9 env with DYLD_INSERT_LIBRARIES', 'want': 'ENV_NOT_ALLOWED', 'got': rr.refusal or 'LAUNCHED', 'pass': rr.refusal == 'ENV_NOT_ALLOWED'})
    rr = L.launch(BIN, PIN, D.native_wire(X_AUTH), 4096, env={'CML_HEAP_SIZE': '1'})
    res.append({'case': 'E10 env CML_HEAP_SIZE=1', 'want': 'ENV_NOT_ALLOWED', 'got': rr.refusal or 'LAUNCHED', 'pass': rr.refusal == 'ENV_NOT_ALLOWED'})
    rr = L.launch(BIN, PIN, D.native_wire(X_AUTH), 4096, env={})
    res.append({'case': 'E10b env empty (no CML_* names)', 'want': 'LAUNCHED', 'got': rr.refusal or 'LAUNCHED',
                'pass': rr.refusal == '', 'note': 'stdout=%r exit=%r' % (rr.stdout[:60], rr.exit_code)})
    br('E11 relative path', X_AUTH, D_AUTH, path='bin/refund', want='PATH_NOT_ABSOLUTE')
    # E12-E15: stand-ins (STAND-IN, not the binary)
    for k, want in (('reopen-stdout', 'FRAME_TRUNCATED'), ('close-early', 'STDOUT_EMPTY'), ('ignore-stdin', 'SIGN'),
                    ('setsid-grandchild', 'SIGN')):
        pidf = os.path.join(WORK, 'setsid.pid')
        if os.path.exists(pidf): os.remove(pidf)
        br('E-standin ' + k, X_AUTH, D_AUTH, path=os.path.join(sd, k), pin=pins[k], want=want)
        if k == 'setsid-grandchild':
            time.sleep(0.5)
            alive = None
            if os.path.exists(pidf):
                gp = int(open(pidf).read() or 0)
                try:
                    os.kill(gp, 0); alive = True
                    os.kill(gp, signal.SIGKILL)
                except ProcessLookupError:
                    alive = False
            res[-1]['grandchild_alive_after_launch_returned'] = alive
    json.dump({'python': sys.version.split()[0], 'results': res}, open(out, 'w'), indent=1)
    for x in res:
        print(('PASS ' if x['pass'] else 'DIFF ') + x['case'] + ' -> ' + str(x['got']) + ('  [' + x['note'] + ']' if x.get('note') else '')
              + ('  grandchild_alive=%s' % x['grandchild_alive_after_launch_returned'] if 'grandchild_alive_after_launch_returned' in x else ''))


main(sys.argv[1])
