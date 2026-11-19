#!/usr/bin/env python3
"""Z5 THIN consumer harness (graph links X15, X16). NOT product code. NOT proved. A finite test object.

It composes EXISTING components, unchanged:
  step 0  read the stored pre-state from the REAL sink (ts/refund-finality/sink.ts, by tsx, via sinkctl.ts);
          build ONE source record {state, request, opened, candidate}; derive BOTH inputs from it.
  step 1  the M1 executable through m1_fail_closed.decide (drafts/fail-closed, unchanged) on the nine fields.
  step 2  ONLY IF step 1 is AUTHORIZED: the REAL issuer (ts/refund-finality/minter.ts, RefundFinality.Check,
          Ed25519) on the same record (reached through the test driver's relay socket).
  step 3  ONLY IF both accept and the binding guards hold: the token text goes to the REAL sink commit.

Guards (this harness, not the repository):
  G1  before step 1: the nine M1 fields equal the M1 view of the issuer message (inverse mapping).
  G2  after step 2:  the nine M1 fields equal the M1 view of the SIGNED token body; M1's echoed amount and
      reason equal the token intent; the token's pre-state hash equals SHA-256 of the stored blob read in step 0.

Field mapping (one source record -> two inputs). See MAPPING in the report.
  M1 charge    = UTF-8(state.chargeId)        issuer pre.chargeId, intent.chargeId (Unicode text)
  M1 request   = UTF-8(request.requestId)     issuer transition.request.requestId, intent.requestId
  M1 reason    = UTF-8(request.reason)        issuer request.reason, intent.reason
  M1 original  = int(state.original)          issuer pre.original (decimal text, regex 0|[1-9][0-9]{0,18})
  M1 remaining = int(state.remaining)         issuer pre.remaining
  M1 amount    = int(request.amount)          issuer request.amount, intent.amount; post.remaining = rem - amount
  M1 enabled   = state.refundEnabled          issuer pre.refundEnabled
  M1 opened    = record.opened                NO issuer field: Check takes the request as open (ContextOf ... true)
  M1 candidate = record.candidate             NO issuer field: Check always builds R.Candidate(amount, reason)
  issuer-only: the pre-state hash (computed by the minter), post, intent (derived), the signature.

Variants (for negative controls; only 'correct' is the harness under test):
  correct      guards on; M1 AUTHORIZED is necessary; issuer ok is necessary.
  two-source   guards off (a harness that may give M1 and the issuer different values).
  m1-alone     guards off; M1 AUTHORIZED is treated as sufficient: if the issuer refuses, it asks again with
               the pre-state and transition of M1's view (the caller's statement).
  exit0-alone  guards on; step 1 accepts on process exit status 0 alone.
  lenient-int  correct, but integers are read with Python int() (accepts '040', '+40', ' 40').
  latin1       correct, but texts are encoded to bytes as Latin-1 for M1.
  *-noguard    the same with guards off (lenient-int-noguard, latin1-noguard).
"""
import sys
sys.dont_write_bytecode = True
import copy, hashlib, json, os, re, socket, subprocess, tempfile, time
from pathlib import Path

W = Path(__file__).resolve().parent
ROOT = Path('<HOME>/forge')
FC = ROOT / 'proposals/m1b-mission-20261119/drafts/fail-closed'
EXE = ROOT / 'proposals/forge2-m1-conformance/artifacts/refund-arm64-macho'
NODE = '/opt/homebrew/bin/node'
(W / 'tmp').mkdir(exist_ok=True)
tempfile.tempdir = str(W / 'tmp')          # the private copy of the executable goes here
sys.path.insert(0, str(FC))
import m1_fail_closed as M                  # noqa: E402  (unchanged repository draft)
import frame                                # noqa: E402

ENV = {'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'TMPDIR': str(W / 'tmp') + '/', 'HOME': os.environ.get('HOME', ''),
       'NODE_NO_WARNINGS': '1'}
MONEY = re.compile(r'(0|[1-9][0-9]{0,18})\Z')
STATE_KEYS = ['chargeId', 'original', 'remaining', 'refundEnabled']
REQUEST_KEYS = ['amount', 'reason', 'requestId']


class MappingError(Exception):
    pass


# ------------------------------------------------------------------------------------------- real sink
def sinkctl(op, db, cfg, arg=None):
    argv = [NODE, '--import', 'tsx', str(W / 'sinkctl.ts'), op, str(db), str(cfg)] + ([str(arg)] if arg is not None else [])
    c = subprocess.run(argv, cwd=ROOT, env=ENV, capture_output=True, timeout=120)
    if c.returncode != 0:
        raise RuntimeError('sinkctl %s exit %d: %s' % (op, c.returncode, c.stderr.decode()[-400:]))
    return json.loads(c.stdout.decode('utf-8'))


def canon(v):  # the sink's canonical text: sorted keys, no spaces, non-ASCII NOT escaped (as JSON.stringify)
    return json.dumps(v, sort_keys=True, separators=(',', ':'), ensure_ascii=False)


# ------------------------------------------------------------------------------------------- real issuer
def ask_issuer(sock, msg):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    s.connect(sock)
    s.sendall((json.dumps(msg) + '\n').encode())
    data = b''
    while not data.endswith(b'\n'):
        piece = s.recv(65536)
        if not piece:
            break
        data += piece
    s.close()
    return json.loads(data.decode('utf-8'))


# ------------------------------------------------------------------------------------------- mapping
def money(v):
    if type(v) is not str or not MONEY.match(v):
        raise MappingError('integer text is not canonical: %r' % (v,))
    return int(v)


def lenient_int(v):
    return int(v)


def utf8(v):
    if type(v) is not str:
        raise MappingError('text is not a str')
    try:
        return v.encode('utf-8')                      # strict: a lone surrogate raises
    except UnicodeEncodeError as e:
        raise MappingError('text has no UTF-8 form: %s' % e)


def latin1(v):
    return v.encode('latin-1')


def boolean(v):
    if type(v) is not bool:
        raise MappingError('not a bool')
    return v


def check_record(rec):
    if sorted(rec) != ['candidate', 'opened', 'request', 'state']:
        raise MappingError('record keys')
    if sorted(rec['state']) != sorted(STATE_KEYS) or sorted(rec['request']) != REQUEST_KEYS:
        raise MappingError('state or request keys')


def to_m1(rec, text=utf8, number=money):
    check_record(rec)
    st, rq = rec['state'], rec['request']
    return {'charge': text(st['chargeId']), 'request': text(rq['requestId']), 'reason': text(rq['reason']),
            'original': number(st['original']), 'remaining': number(st['remaining']), 'amount': number(rq['amount']),
            'enabled': boolean(st['refundEnabled']), 'opened': boolean(rec['opened']), 'candidate': boolean(rec['candidate'])}


def to_issuer(rec, number=money):
    check_record(rec)
    st, rq = rec['state'], rec['request']
    pre = {k: st[k] for k in STATE_KEYS}
    post = dict(pre, remaining=str(number(st['remaining']) - number(rq['amount'])))
    intent = {'chargeId': st['chargeId'], 'requestId': rq['requestId'], 'amount': rq['amount'], 'reason': rq['reason']}
    return {'pre': pre, 'transition': {'request': {k: rq[k] for k in REQUEST_KEYS}, 'post': post, 'intent': intent}}


def m1_view_of_issuer(msg):
    pre, rq = msg['pre'], msg['transition']['request']
    return to_m1({'state': pre, 'request': rq, 'opened': True, 'candidate': True})   # the issuer's fixed assumptions


def m1_view_of_token(body):
    post, it = body['post'], body['intent']
    if body['requestId'] != it['requestId']:
        raise MappingError('token request ids differ')
    return {'charge': utf8(it['chargeId']), 'request': utf8(it['requestId']), 'reason': utf8(it['reason']),
            'original': money(post['original']), 'remaining': money(post['remaining']) + money(it['amount']),
            'amount': money(it['amount']), 'enabled': post['refundEnabled'], 'opened': True, 'candidate': True}


# ------------------------------------------------------------------------------------------- M1 step
def composed_runner(transform=None):
    """Exactly the body of M.decide, but the process result is kept (and, for a test, transformed)."""
    def run(fields):
        M.check_request(fields)
        if M.sha256_file(str(EXE)) != M.PINNED_SHA256:
            return ('REFUSED', 'D0 executable SHA-256 is not the pinned one'), None
        result = M.run_process(str(EXE), M.wire(fields), M.output_bound(fields))
        if transform is not None:
            result = transform(fields, result)
        return M.decide_from_result(fields, result), result
    return run


def pause(point, at):
    if at == point:
        os.write(1, ('PAUSED %s\n' % point).encode())
        while True:
            time.sleep(1000)


def _n():
    _n.k = getattr(_n, 'k', 0) + 1
    return '%d-%d-%d' % (os.getpid(), int(time.time() * 1000), _n.k)


# ------------------------------------------------------------------------------------------- the harness
def consume(request, db, cfg, sock, variant='correct', opened=True, candidate=True, m1_side=None, iss_msg_side=None,
            m1_runner=None, pause_at=None, after_read=None, guards=None):
    """Returns a log dict. log['token'] is the token text if one was ISSUED; log['commit'] the sink answer if
    a token was PASSED to the sink."""
    if guards is None:
        guards = variant in ('correct', 'exit0-alone', 'lenient-int', 'latin1')
    text = latin1 if variant.startswith('latin1') else utf8              # 'latin1', 'latin1-noguard'
    number = lenient_int if variant.startswith('lenient-int') else money # 'lenient-int', 'lenient-int-noguard'
    log = {'variant': variant, 'issuer_asked': 0, 'token': None, 'commit': None}
    blob = sinkctl('state', db, cfg)                                  # step 0: stored pre-state
    log['stored_blob'] = blob
    if after_read:
        after_read()
    rec = {'state': json.loads(blob), 'request': request, 'opened': opened, 'candidate': candidate}
    rec_m1 = m1_side(copy.deepcopy(rec)) if m1_side else rec          # m1_side: fault injection (two sources)
    try:
        fields = to_m1(rec_m1, text, number)
        msg = to_issuer(rec, number)
    except (MappingError, ValueError, TypeError, KeyError) as e:
        log['stop'] = 'S0 mapping: %s' % e
        return log
    if iss_msg_side:
        msg = iss_msg_side(copy.deepcopy(msg))
    log['m1_fields'] = {k: (v.decode('latin-1') if isinstance(v, bytes) else v) for k, v in fields.items()}
    if guards:
        try:
            view = m1_view_of_issuer(msg)
        except MappingError as e:
            view = 'mapping error: %s' % e
        if view != fields:
            log['stop'] = 'G1 M1 fields differ from the M1 view of the issuer message'
            return log
    # step 1: M1
    if variant == 'exit0-alone' and m1_runner is None:
        m1_runner = composed_runner()
    if m1_runner is None:
        verdict, result = M.decide(fields, str(EXE)), None
    else:
        verdict, result = m1_runner(fields)
    log['m1'] = [x.decode('latin-1') if isinstance(x, bytes) else x for x in verdict]
    if result is not None:
        log['m1_process'] = {'exit_code': result.exit_code, 'signal': result.signal, 'stdout': result.stdout.decode('latin-1'),
                             'stderr_len': len(result.stderr)}
    pause('after-m1', pause_at)
    m1_ok = (result is not None and result.exit_code == 0) if variant == 'exit0-alone' else verdict[0] == 'AUTHORIZED'
    if not m1_ok:
        log['stop'] = 'step 1: M1 result is %s' % verdict[0]
        return log
    # step 2: the real issuer (RefundFinality.Check + signature)
    log['issuer_asked'] += 1
    ans = ask_issuer(sock, msg)
    log['issuer'] = {k: ans[k] for k in ans if k != 'token'}
    if not ans.get('ok') and variant == 'm1-alone':
        # M1's verdict as authority: re-ask with M1's own view of the state as the pre-state.
        alt = to_issuer({'state': {'chargeId': rec_m1['state']['chargeId'], 'original': rec_m1['state']['original'],
                                   'remaining': rec_m1['state']['remaining'], 'refundEnabled': rec_m1['state']['refundEnabled']},
                         'request': rec_m1['request'], 'opened': True, 'candidate': True})
        log['issuer_asked'] += 1
        ans = ask_issuer(sock, alt)
        log['issuer_retry'] = {k: ans[k] for k in ans if k != 'token'}
    if not ans.get('ok'):
        log['stop'] = 'step 2: issuer refused: %s' % ans.get('reason')
        return log
    token = ans['token']
    tok_text = canon(token)
    log['token'] = tok_text
    pause('after-sign', pause_at)
    if guards:
        body = token['body']
        try:
            tview = m1_view_of_token(body)
        except MappingError as e:
            tview = 'mapping error: %s' % e
        echo_ok = verdict[0] != 'AUTHORIZED' or (utf8(body['intent']['reason']) == verdict[2]
                                                  and money(body['intent']['amount']) == verdict[1])
        if (tview != fields or not echo_ok
                or body['preStateSha256'] != hashlib.sha256(blob.encode('utf-8')).hexdigest()):
            log['stop'] = 'G2 the signed token does not bind the values M1 checked'
            return log
    # step 3: the real sink
    f = W / 'tmp' / ('token-%s.txt' % _n())
    f.write_bytes(tok_text.encode('utf-8'))
    log['commit'] = sinkctl('commit', db, cfg, f)
    pause('after-commit', pause_at)
    log['stop'] = 'done'
    return log


def main():
    # CLI for the kill test: consumer.py run <db> <cfg> <sock> <request json> <pause point | none>
    _, op, db, cfg, sock, request, at = sys.argv
    assert op == 'run'
    log = consume(json.loads(request), db, cfg, sock, pause_at=None if at == 'none' else at)
    os.write(1, (json.dumps(log) + '\n').encode())
    return 0


if __name__ == '__main__':
    sys.exit(main())
