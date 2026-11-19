"""r-repairs: 16 adversarial cases against a COPY of decide2.py, the real binary copy, and the real compiled
Check (dafny_side2.cjs, no stand-in) or a forced accept-all checker (models a miscompiled Check)."""
import dataclasses, importlib.util, json, os, subprocess, sys, unicodedata
X = os.path.dirname(os.path.abspath(__file__))
CORE = '/Users/mackianni/forge/results/night-shift-20261119/orch-B/d-corebacked/build/shellcore-orig.cjs'
PIN = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
MAX = 9223372036854775807
def load(n, p):
    s = importlib.util.spec_from_file_location(n, p); m = importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
D = load('decide2', os.path.join(X, sys.argv[1] if len(sys.argv) > 1 else 'decide2.py'))
L = load('launcher', os.path.join(X, 'launcher.py'))
node = subprocess.Popen(['/opt/homebrew/bin/node', os.path.join(X, 'dafny_side2.cjs'), CORE], stdin=subprocess.PIPE,
                        stdout=subprocess.PIPE, cwd=X, env={'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'HOME': X})
def real(c, h):
    t = {'request': {'requestId': c.request.request_id, 'amount': str(c.request.amount), 'reason': c.request.reason},
         'post': D.state_json(c.post), 'intent': D.intent_json(c.intent)}
    node.stdin.write((json.dumps({'pre': D.state_json(c.pre), 'preStateSha256': h, 't': t}) + '\n').encode()); node.stdin.flush()
    a = json.loads(node.stdout.readline())
    if 'error' in a: raise RuntimeError(a['error'])
    return a['issue'] is True and a['plan'] == 1 and a['tokenOk'] is True
acc = lambda c, h: True
WR = os.path.join(X, 'run'); os.makedirs(WR, exist_ok=True)
def cand(c, o, r, e, q, a, why, post=None, intent=None, iq=None, ic=None):
    pre = D.Charge(c, o, r, e)
    p = D.Charge(c, o, r - a, e) if post is None else post
    i = D.Intent(c if ic is None else ic, q if iq is None else iq, a, why) if intent is None else intent
    return D.Candidate(pre, D.Request(q, a, why), p, i)
def br(c, chk):
    try:
        d, r = D.bridge2(c, checker=chk, binary_path=os.path.join(X, 'bin', 'refund'), launch_fn=L.launch,
                         pinned_sha256=PIN, work_root=WR)
    except Exception as e:
        return 'EXC:' + repr(e), None
    return d.reason, (r.stdout if r else None)
def synth(c, out):   # a native that prints `out` cleanly; accept-all checker
    r = L.LaunchResult(True, '', out, 0, None, False, 0, False, True, True, 0.0)
    return D.decide2(c, True, r).reason, out
nfc = unicodedata.normalize('NFC', 'café'); nfd = unicodedata.normalize('NFD', 'café')
base = cand('ch_1', 100, 60, True, 'req_1', 40, 'returned_item')
cases = [
 ('frame-amount-040', lambda: synth(base, b'(refund-result-v1 True 040 returned_item ch_1 req_1 1)'), 'NO_FRAME'),
 ('frame-amount-plus40', lambda: synth(base, b'(refund-result-v1 True +40 returned_item ch_1 req_1 1)'), 'NO_FRAME'),
 ('frame-count-01', lambda: synth(base, b'(refund-result-v1 True 40 returned_item ch_1 req_1 01)'), 'NO_FRAME'),
 ('frame-charge-case', lambda: synth(base, b'(refund-result-v1 True 40 returned_item CH_1 req_1 1)'), 'FRAME_NOT_AUTHORIZED_TUPLE'),
 ('frame-quoted-safe-atom', lambda: synth(base, b'(refund-result-v1 True 40 "returned_item" ch_1 req_1 1)'), 'NO_FRAME'),
 ('amount-max-real', lambda: br(cand('c', MAX, MAX, True, 'r', MAX, 'returned_item'), real), 'SIGN'),
 ('amount-2^63-acc', lambda: br(cand('c', MAX, MAX, True, 'r', MAX + 1, 'returned_item'), acc), 'OUT_OF_RANGE'),
 ('nfc-req-nfd-intent-acc', lambda: br(cand('ch_1', 100, 60, True, nfc, 40, 'returned_item', iq=nfd), acc), 'INTENT_MISMATCH'),
 ('nfd-everywhere-real', lambda: br(cand('ch_1', 100, 60, True, nfd, 40, 'returned_item'), real), 'SIGN'),
 ('nfc-charge-nfd-intent-acc', lambda: br(cand(nfc, 100, 60, True, 'req_1', 40, 'returned_item', ic=nfd), acc), 'INTENT_MISMATCH'),
 ('trailing-space-intent-acc', lambda: br(cand('ch_1', 100, 60, True, 'req_1 ', 40, 'returned_item', iq='req_1'), acc), 'INTENT_MISMATCH'),
 ('trailing-space-everywhere-real', lambda: br(cand('ch_1', 100, 60, True, 'req_1 ', 40, 'returned_item'), real), 'SIGN'),
 ('reason-case-acc', lambda: br(cand('ch_1', 100, 60, True, 'req_1', 40, 'Returned_Item'), acc), 'FRAME_NOT_AUTHORIZED_TUPLE'),
 ('empty-request-acc', lambda: br(cand('ch_1', 100, 60, True, '', 40, 'returned_item'), acc), 'FRAME_NOT_AUTHORIZED_TUPLE'),
 ('pre-rem-gt-orig-acc', lambda: br(cand('ch_1', 50, 60, True, 'req_1', 10, 'returned_item'), acc), 'FRAME_NOT_AUTHORIZED_TUPLE'),
 ('post-float-acc', lambda: br(cand('ch_1', 100, 60, True, 'req_1', 40, 'returned_item', post=D.Charge('ch_1', 100, 20.0, True)), acc), 'OUT_OF_RANGE'),
 ('intent-amount-bool-acc', lambda: br(cand('ch_1', 100, 60, True, 'req_1', 1, 'returned_item', intent=D.Intent('ch_1', 'req_1', True, 'returned_item')), acc), 'INTENT_MISMATCH'),
 ('reqid-digits-real', lambda: br(cand('ch_1', 100, 60, True, '40', 40, 'returned_item'), real), 'SIGN'),
 ('reqid-True-real', lambda: br(cand('ch_1', 100, 60, True, 'True', 40, 'returned_item'), real), 'SIGN'),
 ('chargeid-tilde5-real', lambda: br(cand('~5', 100, 60, True, 'req_1', 40, 'returned_item'), real), 'SIGN'),
 ('reqid-CR-VT-real', lambda: br(cand('ch_1', 100, 60, True, 'a\rb\x0bc\x0c', 40, 'returned_item'), real), 'SIGN'),
 ('latin1-mutant-probe (both wrong)', lambda: synth(cand('ch_1', 100, 60, True, 'req_1', 40, '\u00e9', intent=D.Intent('ch_1', 'req_1', 40, '\u00c3\u00a9')),
   D.frame.render_fields(True, 40, '\u00e9'.encode(), b'ch_1', b'req_1', 1)), 'INTENT_MISMATCH'),
 ('zero-amount-real', lambda: br(cand('ch_1', 100, 0, True, 'req_0', 0, 'duplicate_charge'), real), 'SIGN'),
]
npass = 0
for n, f, want in cases:
    got, out = f()
    ok = got == want; npass += ok
    print(('PASS' if ok else 'DIFF'), n, 'want', want, 'got', got, (out[:90] if out else ''))
print('total', len(cases), 'as-expected', npass)
node.stdin.close(); node.wait(timeout=10)
