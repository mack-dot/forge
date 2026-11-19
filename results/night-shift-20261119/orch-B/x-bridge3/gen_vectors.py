"""x-bridge3: the shared input vectors for the conformance of native_bridge.ts with the Python reference.
Inputs are ported from x-bridge2/tests2.py (run_suite) and r-repairs/b2py/rcases.py (23 cases).
Typed values: {"s": str} {"i": "dec"} {"f": float} {"b": bool}; records {"t": Charge|Request|Intent|Candidate|tuple, "f": [...]}.
Omitted on purpose: cases that load a library into a process (forged.dylib), the Python-only interface test (inspect).
"""
import json, os, sys, unicodedata
X = os.path.dirname(os.path.abspath(__file__))
MAX = 9223372036854775807
S = lambda v: {'s': v}
I = lambda v: {'i': str(v)}
B = lambda v: {'b': v}
def V(v):
    if type(v) is bool: return B(v)
    if type(v) is int: return I(v)
    if type(v) is float: return {'fl': v}
    if type(v) is str: return S(v)
    return v
def ch(c, o, r, e): return {'t': 'Charge', 'f': [V(c), V(o), V(r), V(e)]}
def rq(q, a, why): return {'t': 'Request', 'f': [V(q), V(a), V(why)]}
def it(c, q, a, why): return {'t': 'Intent', 'f': [V(c), V(q), V(a), V(why)]}
def cand(c, o, r, e, q, a, why, post=None, intent=None, iq=None, ic=None):
    p = ch(c, o, r - a, e) if post is None else post
    i = it(c if ic is None else ic, q if iq is None else iq, a, why) if intent is None else intent
    return {'t': 'Candidate', 'f': [ch(c, o, r, e), rq(q, a, why), p, i]}
def with_(cd, **kw):
    f = list(cd['f']); idx = {'pre': 0, 'request': 1, 'post': 2, 'intent': 3}
    for k, v in kw.items(): f[idx[k]] = v
    return {'t': 'Candidate', 'f': f}

vec = []
def bridge(name, c, checker=None, binary='real', pin='real', timeout_s=10.0, **extra):
    vec.append(dict(id=name, kind='bridge', cand=c, checker=checker, binary=binary, pin=pin, timeout_s=timeout_s, **extra))
def planted(name, c, out, issue=True, **kw):
    r = dict(launched=True, refusal='', stdout=out.hex(), exit_code=0, signal=None, timed_out=False, stderr_len=0,
             stdout_overflow=False, stdin_complete=True, copy_unchanged=True); r.update(kw)
    vec.append(dict(id=name, kind='planted', cand=c, issue=issue, result=r))

# ---------------------------------------------------------------- tests2.py run_suite
auth = cand('ch_1', 100, 60, True, 'req_1', 40, 'returned_item')
uni = cand('é€\U0001F600 "q"\\\t', 500, 60, True, 'r 7\t)(', 60, 'service_not_delivered')
honest = {'auth': auth, 'zero': cand('ch_1', 100, 60, True, 'req_0', 0, 'duplicate_charge'), 'unicode': uni,
          'max': cand('c', MAX, MAX, True, 'r', MAX, 'returned_item')}
for n, c in honest.items(): bridge('t2/real/' + n, c)
bridge('t2/real/reject-disabled', cand('ch_1', 100, 60, False, 'req_1', 40, 'returned_item'))
bridge('t2/real/post-wrong-real-check', with_(auth, post=ch('ch_1', 100, 59, True)))
for n, post in (('remaining', ch('ch_1', 100, 59, True)), ('original', ch('ch_1', 101, 20, True)),
                ('chargeId', ch('ch_X', 100, 20, True)), ('enabled', ch('ch_1', 100, 20, False))):
    bridge('t2/H/ignore-post/wrong-post-' + n, with_(auth, post=post), checker='ignore-post')
for n, i in (('chargeId', it('ch_2', 'req_1', 40, 'returned_item')), ('requestId', it('ch_1', 'req_2', 40, 'returned_item')),
             ('amount', it('ch_1', 'req_1', 41, 'returned_item')), ('reason', it('ch_1', 'req_1', 40, 'duplicate_charge'))):
    bridge('t2/H/ignore-intent/wrong-intent-' + n, with_(auth, intent=i), checker='ignore-intent')
bridge('t2/H/ignore-post/honest-signs', auth, checker='ignore-post')
bridge('t2/H/accept-all/amount-over-remaining', cand('ch_1', 100, 30, True, 'req_1', 40, 'returned_item'), checker='accept-all')
for n, pre in (('E1', ch('ch_1', 100, 50, True)), ('E2', ch('ch_1', 1000, 60, True)), ('E3', ch('ch_1', 100, 40, True))):
    bridge('t2/M/%s/real' % n, with_(auth, pre=pre))
    bridge('t2/M/%s/accept-all' % n, with_(auth, pre=pre), checker='accept-all')
bridge('t2/E5/amount-bool', with_(auth, request=rq('req_1', True, 'returned_item')))
bridge('t2/E5/post-enabled-int', with_(auth, post=ch('ch_1', 100, 20, 1)))
over = cand('ch_1', 100, 30, True, 'req_1', 40, 'returned_item')
bridge('t2/native-wrong/authorize-all/real-check', over, binary='standin:authorize-all', pin='standin')
bridge('t2/both-wrong/outside-guarantee', over, checker='accept-all', binary='standin:authorize-all', pin='standin')
bridge('t2/both-wrong/honest-request-authorize-all', auth, checker='accept-all', binary='standin:authorize-all', pin='standin')
for n, c in (('amount>MAX', with_(auth, request=rq('req_1', MAX + 1, 'returned_item'))),
             ('remaining<0', with_(auth, pre=ch('ch_1', 100, -1, True))),
             ('id-257', with_(auth, request=rq('r' * 257, 40, 'returned_item'))),
             ('id-256', with_(auth, request=rq('r' * 256, 40, 'returned_item'), intent=it('ch_1', 'r' * 256, 40, 'returned_item'))),
             ('id-129-astral', with_(auth, request=rq('\U0001F600' * 129, 40, 'returned_item'))),
             ('id-nul', with_(auth, pre=ch('c\x00', 100, 60, True))),
             ('lone-surrogate', with_(auth, request=rq('req_1', 40, '\ud800'))),
             ('enabled-int', with_(auth, pre=ch('ch_1', 100, 60, 1))),
             ('not-a-candidate', {'t': 'tuple', 'f': [auth['f'][0], auth['f'][1]]})):
    bridge('t2/range/' + n, c)
bridge('t2/pin/wrong-digest', auth, pin='zeros')
bridge('t2/pin/relative-path', auth, binary='rel:bin/refund')
bridge('t2/pin/absent-binary', auth, binary='abs:/nonexistent/forge/refund')
bridge('t2/pin/directory', auth, binary='abs:' + os.path.join(X, 'bin'))
for n, e in (('dyld', {'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256', 'DYLD_INSERT_LIBRARIES': '/nonexistent/x.dylib'}),
             ('ld', {'LD_PRELOAD': 'x'}), ('extra-name', {'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256', 'HOME': '/'}),
             ('changed-value', {'CML_HEAP_SIZE': '1'}), ('empty-env', {})):
    vec.append(dict(id='t2/env-arg/' + n, kind='launch_env', env=e))
bridge('t2/parent-env-nonexistent-dyld/real', auth, parent_env=True)
for n in ('honest', 'truncated', 'empty', 'two-frames', 'trailing-newline', 'stderr-noise', 'exit3', 'sigterm', 'flood',
          'field-authorized', 'field-amount', 'field-reason', 'field-charge', 'field-request', 'field-count'):
    bridge('t2/standin/' + n, auth, binary='standin:' + n, pin='standin')
bridge('t2/standin/timeout-sleep5', auth, binary='standin:sleep5', pin='standin', timeout_s=2.0)
bridge('t2/standin/grandchild-holds-stdout', auth, binary='standin:grandchild', pin='standin', timeout_s=2.0, grandchild=True)
vec.append(dict(id='t2/probe', kind='probe'))
HONEST = b'(refund-result-v1 True 40 returned_item ch_1 req_1 1)'
for n, c, out, kw in (('honest', auth, HONEST, {}), ('two-frames', auth, HONEST + HONEST, {}), ('trailing-byte', auth, HONEST + b' ', {}),
                      ('non-canonical-int', auth, HONEST.replace(b' 40 ', b' 040 '), {}), ('exit0-truncated-CE1', auth, HONEST[:-1], {}),
                      ('exit0-empty-CE2', auth, b'', {}), ('stdin-incomplete', auth, HONEST, dict(stdin_complete=False)),
                      ('binary-changed', auth, HONEST, dict(copy_unchanged=False)),
                      ('signal-with-frame', auth, HONEST, dict(exit_code=None, signal=13)),
                      ('timeout-with-frame', auth, HONEST, dict(timed_out=True)), ('stderr-with-frame', auth, HONEST, dict(stderr_len=1)),
                      ('exit1-with-frame', auth, HONEST, dict(exit_code=1)), ('overflow-with-frame', auth, HONEST, dict(stdout_overflow=True)),
                      ('not-launched', auth, b'', dict(launched=False, refusal='DIGEST_MISMATCH')),
                      ('not-launched-no-reason', auth, b'', dict(launched=False, refusal='')),
                      ('E6-out-of-range-honest-run', with_(auth, pre=ch('ch_1', 100, 60, 1)), HONEST, {}),
                      ('reject-frame', auth, b'(refund-result-v1 False 0 "" "" "" 0)', {}),
                      ('count-field-2', auth, HONEST.replace(b' 1)', b' 2)'), {}),
                      ('ok-field-False', auth, HONEST.replace(b'True', b'False'), {}),
                      ('quoted-escape-r', auth, HONEST.replace(b'req_1', b'"req\\r1"'), {}),
                      ('latin1-bytes-in-frame', auth, HONEST.replace(b'req_1', b're\xe9_1'), {})):
    planted('t2/planted/' + n, c, out, **kw)
planted('t2/planted/issue-int-not-True', auth, HONEST, issue=1)
planted('t2/planted/issue-false', auth, HONEST, issue=False)

# ---------------------------------------------------------------- rcases.py (23 cases; inputs ported)
nfc = unicodedata.normalize('NFC', 'café'); nfd = unicodedata.normalize('NFD', 'café')
base = cand('ch_1', 100, 60, True, 'req_1', 40, 'returned_item')
R = []
planted('rc/frame-amount-040', base, b'(refund-result-v1 True 040 returned_item ch_1 req_1 1)')
planted('rc/frame-amount-plus40', base, b'(refund-result-v1 True +40 returned_item ch_1 req_1 1)')
planted('rc/frame-count-01', base, b'(refund-result-v1 True 40 returned_item ch_1 req_1 01)')
planted('rc/frame-charge-case', base, b'(refund-result-v1 True 40 returned_item CH_1 req_1 1)')
planted('rc/frame-quoted-safe-atom', base, b'(refund-result-v1 True 40 "returned_item" ch_1 req_1 1)')
bridge('rc/amount-max-real', cand('c', MAX, MAX, True, 'r', MAX, 'returned_item'))
bridge('rc/amount-2^63-acc', cand('c', MAX, MAX, True, 'r', MAX + 1, 'returned_item'), checker='accept-all')
bridge('rc/nfc-req-nfd-intent-acc', cand('ch_1', 100, 60, True, nfc, 40, 'returned_item', iq=nfd), checker='accept-all')
bridge('rc/nfd-everywhere-real', cand('ch_1', 100, 60, True, nfd, 40, 'returned_item'))
bridge('rc/nfc-charge-nfd-intent-acc', cand(nfc, 100, 60, True, 'req_1', 40, 'returned_item', ic=nfd), checker='accept-all')
bridge('rc/trailing-space-intent-acc', cand('ch_1', 100, 60, True, 'req_1 ', 40, 'returned_item', iq='req_1'), checker='accept-all')
bridge('rc/trailing-space-everywhere-real', cand('ch_1', 100, 60, True, 'req_1 ', 40, 'returned_item'))
bridge('rc/reason-case-acc', cand('ch_1', 100, 60, True, 'req_1', 40, 'Returned_Item'), checker='accept-all')
bridge('rc/empty-request-acc', cand('ch_1', 100, 60, True, '', 40, 'returned_item'), checker='accept-all')
bridge('rc/pre-rem-gt-orig-acc', cand('ch_1', 50, 60, True, 'req_1', 10, 'returned_item'), checker='accept-all')
bridge('rc/post-float-acc', cand('ch_1', 100, 60, True, 'req_1', 40, 'returned_item', post=ch('ch_1', 100, 20.0, True)), checker='accept-all')
bridge('rc/intent-amount-bool-acc', cand('ch_1', 100, 60, True, 'req_1', 1, 'returned_item', intent=it('ch_1', 'req_1', True, 'returned_item')), checker='accept-all')
bridge('rc/reqid-digits-real', cand('ch_1', 100, 60, True, '40', 40, 'returned_item'))
bridge('rc/reqid-True-real', cand('ch_1', 100, 60, True, 'True', 40, 'returned_item'))
bridge('rc/chargeid-tilde5-real', cand('~5', 100, 60, True, 'req_1', 40, 'returned_item'))
bridge('rc/reqid-CR-VT-real', cand('ch_1', 100, 60, True, 'a\rb\x0bc\x0c', 40, 'returned_item'))
planted('rc/latin1-mutant-probe', cand('ch_1', 100, 60, True, 'req_1', 40, 'é', intent=it('ch_1', 'req_1', 40, 'Ã©')),
        b'(refund-result-v1 True 40 \xc3\xa9 ch_1 req_1 1)')
bridge('rc/zero-amount-real', cand('ch_1', 100, 0, True, 'req_0', 0, 'duplicate_charge'))
# the reviewer's test gap (both-wrong region): a wrong native AND a wrong checker on a NON-authorized input
bridge('gap/both-wrong-zero-remaining', cand('ch_1', 100, 0, True, 'req_1', 40, 'returned_item'), checker='accept-all',
       binary='standin:authorize-all', pin='standin')
json.dump(vec, open(os.path.join(X, 'vectors.json'), 'w'), indent=0)
print('vectors', len(vec), 'rc', sum(v['id'].startswith('rc/') for v in vec))
