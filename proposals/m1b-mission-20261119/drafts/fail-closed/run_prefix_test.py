"""Prefix test of the PRESENT M1 output frame. FINITE TEST, not a proof.

Part A: run the unmodified executable on varied requests; check each output equals the transcribed
        render (and the strict parser accepts the full output).
Part B: for EVERY strict prefix of EVERY output: strict parser, transcribed program reader
        (parse then refund_response_fields, full consumption), and four careless readers.
Part C: the real binary's own reader on every strict prefix of requests (same parse function):
        every prefix must give empty stdout.
Part D: negative controls for the candidate lemma (a printer with a trailing newline; a top-level atom).
Writes prefix_results.json. Exit 0 iff strict and program-reader acceptance counts are 0 and all
negative controls detect their fault.
"""
import json
import subprocess
import sys

import frame

EXE = './refund'
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C', 'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}
M = frame.MAX_MONEY


def run(data):
    p = subprocess.run([EXE], input=data, capture_output=True, env=ENV, timeout=60)
    return p.returncode, p.stdout, p.stderr


def req(charge, request, original=100, remaining=60, e=True, o=True, c=True, amount=40, reason=b'returned_item'):
    return dict(charge=charge, request=request, original=original, remaining=remaining, enabled=e, opened=o,
                candidate=c, amount=amount, reason=reason)


IDS = [b'c', b'a)b', b'"q"', b'a b', b'back\\slash', b'r123', b'req-0001', b'1', b'True', b'(', b')',
       b'\\', b'\\"', b'tab\there', b'nl\nhere', b'cr\rhere', b'nul\x00x', b'\xc3\xa9', b'x' * 300,
       b'refund-result-v1', b'r 7', b'a\\)', b'"', b'""', b' ', b'y' * 2000]
CASES = []
for i, ident in enumerate(IDS):
    CASES.append(('id-charge-%d' % i, req(ident, b'r1')))
    CASES.append(('id-request-%d' % i, req(b'c1', ident)))
for amt, rem, orig in [(0, 60, 100), (9, 60, 100), (10, 60, 100), (60, 60, 100), (M, M, M),
                       (1234567890123456789, M, M), (M - 1, M, M)]:
    CASES.append(('amount-%d' % amt, req(b'c', b'r', orig, rem, amount=amt)))
for r in frame.APPROVED_REASONS:
    CASES.append(('reason-' + r.decode(), req(b'c', b'r9', reason=r)))
# rejections (the empty-string fields of the rejection frame)
CASES += [('rej-amount-over', req(b'c', b'r', amount=61)), ('rej-disabled', req(b'c', b'r', e=False)),
          ('rej-empty-charge', req(b'', b'r')), ('rej-bad-reason', req(b'c', b'r', reason=b'goodwill')),
          ('rej-negative', req(b'c', b'r', amount=-1)), ('rej-over-max', req(b'c', b'r', M + 1, M + 1, amount=1))]


def main():
    res = {'class': 'TESTED-UNPROVED (finite test)', 'cases': [], 'counts': {}}
    outputs = []
    bad = []
    for name, v in CASES:
        w = frame.render_request(*(v[k] for k in ('charge', 'request', 'original', 'remaining', 'enabled',
                                                  'opened', 'candidate', 'amount', 'reason')))
        rc, out, err = run(w)
        ok = frame.strict_accepts(out)
        res['cases'].append({'name': name, 'exit': rc, 'stdout_len': len(out), 'stderr_len': len(err),
                             'strict_full': ok is not None, 'authorized': bool(ok and ok[0])})
        if rc != 0 or err != b'' or ok is None:
            bad.append(name)
        if ok and ok[0]:
            exp = frame.render_fields(True, v['amount'], v['reason'], v['charge'], v['request'], 1)
            if out != exp:
                bad.append(name + ':render-mismatch')
        elif ok and out != frame.REJECTED_BYTES:
            bad.append(name + ':reject-mismatch')
        outputs.append((name, out))
    res['part_A_failures'] = bad
    res['outputs_total'] = len(outputs)
    res['outputs_authorized'] = sum(1 for c in res['cases'] if c['authorized'])
    # Part B
    readers = {'strict': frame.strict_accepts, 'program-reader(transcribed)': frame.hol_reader_accepts}
    readers.update(frame.LENIENT)
    counts = {k: 0 for k in readers}
    smallest = {k: None for k in readers}
    examples = {k: [] for k in readers}
    nprefix = 0
    for name, out in outputs:
        for n in range(len(out)):          # strict prefixes: lengths 0 .. len-1
            p = out[:n]
            nprefix += 1
            for k, f in readers.items():
                r = f(p)
                if r:
                    counts[k] += 1
                    if smallest[k] is None or n < smallest[k][0]:
                        smallest[k] = (n, name, p[:120].decode('latin-1'), repr(r)[:160])
                    if len(examples[k]) < 3 and (not examples[k] or examples[k][-1][0] != name):
                        examples[k].append((name, n, p[:120].decode('latin-1'), repr(r)[:160]))
    # wrong-value acceptances by lenient readers (amount or ids differ from the full output's)
    def values(k, r):
        if k.startswith('startswith'):
            return None                      # no values: it authorizes on the prefix alone
        if k == 'split-words':
            return (r[1],)
        if k.startswith('regex'):
            return (r[1], r[2], r[3])
        return (r[1], r[3], r[4])            # auto-close: amount, charge, request

    wrong = {k: 0 for k in frame.LENIENT}
    wrong_examples = {k: [] for k in frame.LENIENT}
    for name, out in outputs:
        full = frame.strict_accepts(out)
        if not (full and full[0]):
            continue
        ref = (full[1], full[3], full[4])
        for n in range(len(out)):
            p = out[:n]
            for k, f in frame.LENIENT.items():
                r = f(p)
                if not r:
                    continue
                got = values(k, r)
                if got is None or got != ref[:len(got)]:
                    wrong[k] += 1
                    if got is not None and len(wrong_examples[k]) < 4:
                        wrong_examples[k].append((name, n, p[:80].decode('latin-1'), repr(got), repr(ref)))
    res['part_B'] = {'strict_prefixes_tested': nprefix, 'accepted': counts, 'smallest_accepted': smallest,
                     'examples': examples, 'accepted_with_wrong_values': wrong, 'wrong_value_examples': wrong_examples}
    # Part C: the real binary's reader on prefixes of requests
    creq = [req(b'c', b'r'), req(b'a b', b'"q"'), req(b'back\\slash', b'r)7', amount=M, remaining=M, original=M),
            req(b'tab\t', b'nl\n', reason=b'service_not_delivered')]
    cruns = cnonempty = 0
    for v in creq:
        w = frame.render_request(*(v[k] for k in ('charge', 'request', 'original', 'remaining', 'enabled',
                                                  'opened', 'candidate', 'amount', 'reason')))
        rc, full, _ = run(w)
        assert frame.strict_accepts(full), 'full request must give a frame'
        for n in range(len(w)):
            rc, out, err = run(w[:n]); cruns += 1
            if out != b'':
                cnonempty += 1
    res['part_C'] = {'request_prefix_runs': cruns, 'runs_with_nonempty_stdout': cnonempty}
    # Part D: negative controls for the lemma
    sample = frame.render_fields(True, 40, b'returned_item', b'c', b'r', 1)
    d1 = frame.hol_reader_accepts(sample) is not None  # sample + "\n" has strict prefix `sample`, which parses
    d1_full = sample + b'\n'
    try:
        se, rest = frame.hol_parse(b'abc'[:2])
        d2 = (se == b'ab' and rest == b'')
    except frame.Err:
        d2 = False
    res['part_D'] = {'newline-printer: strict prefix (frame without \\n) of frame+\\n parses with rest []': d1,
                     'newline-printer full output strict accepts': frame.strict_accepts(d1_full) is not None,
                     'top-level atom: prefix "ab" of "abc" parses as Atom ab with rest []': d2}
    ok = (not bad and counts['strict'] == 0 and counts['program-reader(transcribed)'] == 0 and cnonempty == 0
          and d1 and d2 and not res['part_D']['newline-printer full output strict accepts'])
    res['verdict'] = 'PASS' if ok else 'FAIL'
    with open('prefix_results.json', 'w') as f:
        json.dump(res, f, indent=1, default=str)
    print(json.dumps({k: res[k] for k in ('outputs_total', 'outputs_authorized', 'part_A_failures', 'verdict')}))
    print(json.dumps(res['part_B'], indent=1, default=str))
    print(json.dumps(res['part_C'])); print(json.dumps(res['part_D']))
    return 0 if ok else 1


if __name__ == '__main__':
    sys.exit(main())
