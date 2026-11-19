"""Negative controls and positive runs for m1_fail_closed. FINITE TEST, not a proof.

Part N: planted process results fed to decide_from_result (the executable is NOT run).
        Each control names the step that must refuse it; a control passes only when the verdict is not
        AUTHORIZED AND the reason starts with that step.
Part R: real runs of the unmodified executable through run_process / decide:
        positive path (authorized and rejected requests), a malformed wire (exit 0, empty stdout),
        a real resource stop (large input), and a real truncated output (file size limit -> signal).
Writes controls_results.json. Exit 0 iff every control passes.
"""
import json
import sys

import frame
import m1_fail_closed as fc

EXE = './refund'
PR = fc.ProcessResult


def base(**kw):
    v = dict(charge=b'c-77', request=b'req 0040', original=100, remaining=60, enabled=True, opened=True,
             candidate=True, amount=40, reason=b'returned_item')
    v.update(kw)
    return v


def ok_result(out, **kw):
    d = dict(exit_code=0, signal=None, timed_out=False, stdout=out, stderr=b'', overflow=False)
    d.update(kw)
    return PR(**d)


def main():
    log = {'class': 'TESTED-UNPROVED (finite test)', 'planted': [], 'real': []}
    failures = []
    v = base()
    # a REAL authorized output for v, from the unmodified executable
    real = fc.run_process(EXE, fc.wire(v), fc.output_bound(v))
    good = real.stdout
    assert fc.decide_from_result(v, real)[0] == 'AUTHORIZED', real
    controls = [
        ('empty stdout, exit 0', ok_result(b''), 'D6', v),
        ('real frame + one trailing byte', ok_result(good + b' '), 'D5', v),
        ('real frame + newline', ok_result(good + b'\n'), 'D5', v),
        ('two frames', ok_result(good + good), 'D5', v),
        ('frame with another request id', ok_result(frame.render_fields(True, 40, b'returned_item', b'c-77', b'req 0041', 1)), 'D9', v),
        ('frame with another charge id', ok_result(frame.render_fields(True, 40, b'returned_item', b'c-78', b'req 0040', 1)), 'D9', v),
        ('frame with amount 040', ok_result(good.replace(b' 40 ', b' 040 ')), ('D5', 'D7'), v),
        ('frame with amount +40', ok_result(good.replace(b' 40 ', b' +40 ')), ('D5', 'D7'), v),
        ('frame with amount 41', ok_result(good.replace(b' 40 ', b' 41 ')), 'D9', v),
        ('frame with count 2', ok_result(good[:-2] + b'2)'), 'D10', v),
        ('frame with quoted bare atom "c-77"', ok_result(good.replace(b'c-77', b'"c-77"')), ('D5', 'D7'), v),
        ('frame with double space', ok_result(good.replace(b'True ', b'True  ')), ('D5', 'D7'), v),
        ('exit code 1 with a perfect frame', ok_result(good, exit_code=1), 'D3', v),
        ('signal 9 with a perfect frame', ok_result(good, exit_code=None, signal=9), 'D2', v),
        ('time limit with a perfect frame', ok_result(good, timed_out=True), 'D1', v),
        ('non-empty stderr with a perfect frame', ok_result(good, stderr=b'warning\n'), 'D4', v),
        ('oversized output (overflow flag)', ok_result(good[:10], overflow=True), 'D5', v),
        ('oversized output (1 MiB)', ok_result(b'(' * (1 << 20)), 'D5', v),
        ('real rejection frame', ok_result(frame.REJECTED_BYTES), 'program rejected', v),
        ('False frame that is not the rejection', ok_result(frame.render_fields(False, 0, b'', b'c-77', b'req 0040', 0)), 'D8', v),
        ('caller sends a str id (caller error)', ok_result(good), 'D12', dict(v, charge='c-77')),
        ('not a process result', None, 'D0', v),
        ('resource stop as observed: exit 1, empty stdout, message on stderr',
         ok_result(b'', exit_code=1, stderr=b'Program exited with nonzero exit code.\n'), 'D3', v),
        ('resource stop as the theorem allows: exit 0, cut output', ok_result(good[:30]), 'D7', v),
    ]
    for n in range(len(good)):        # every strict prefix of the real authorized output
        controls.append(('strict prefix length %d' % n, ok_result(good[:n]), 'D6' if n == 0 else 'D7', v))
    by_step = {}
    for name, res, step, fields in controls:
        d = fc.decide_from_result(fields, res)
        steps = step if isinstance(step, tuple) else (step,)
        passed = d[0] != 'AUTHORIZED' and any(d[1].startswith(x) for x in steps)
        if isinstance(step, tuple) and res is not None:      # the strict parser alone must also refuse it
            passed = passed and frame.strict_accepts(res.stdout) is None
        if not name.startswith('strict prefix'):
            log['planted'].append({'control': name, 'expected_step': step, 'verdict': list(d), 'pass': passed})
        by_step[str(step)] = by_step.get(str(step), 0) + 1
        if not passed:
            failures.append((name, d))
    log['planted_total'] = len(controls)
    log['planted_prefix_controls'] = len(good)
    log['planted_failures'] = [list(map(str, f)) for f in failures]

    # Part R: real executable
    real_cases = [
        ('authorized base', base(), 'AUTHORIZED'),
        ('authorized amount 0', base(amount=0), 'AUTHORIZED'),
        ('authorized MAX amount, id with ) and "', base(charge=b'a)"b', request=b'q\\1', original=frame.MAX_MONEY,
                                                       remaining=frame.MAX_MONEY, amount=frame.MAX_MONEY,
                                                       reason=b'duplicate_charge'), 'AUTHORIZED'),
        ('authorized id with tab and newline', base(charge=b't\tx', request=b'n\ny', reason=b'service_not_delivered'), 'AUTHORIZED'),
        ('rejected amount 61', base(amount=61), 'NOT_AUTHORIZED'),
        ('rejected disabled', base(enabled=False), 'NOT_AUTHORIZED'),
        ('rejected empty request id', base(request=b''), 'NOT_AUTHORIZED'),
    ]
    for name, fields, want in real_cases:
        d = fc.decide(fields, EXE)
        log['real'].append({'case': name, 'verdict': list(d), 'pass': d[0] == want})
        if d[0] != want:
            failures.append((name, d))
    # malformed wire: real run, exit 0 and empty stdout (finding H1)
    r = fc.run_process(EXE, fc.wire(v) + b'\n', fc.output_bound(v))
    d = fc.decide_from_result(v, r)
    log['real'].append({'case': 'malformed wire (trailing newline), real run', 'process': [r.exit_code, len(r.stdout), r.stderr.decode()],
                        'verdict': list(d), 'pass': d[0] == 'REFUSED' and d[1].startswith('D6')})
    if not log['real'][-1]['pass']:
        failures.append(('malformed', d))
    # real resource stop: a 6 000 000 byte charge id (boundary observed between 5 368 027 and 5 368 028)
    vb = base(charge=b'a' * 6000000)
    r = fc.run_process(EXE, fc.wire(vb), fc.output_bound(vb))
    d = fc.decide_from_result(vb, r)
    log['real'].append({'case': 'resource stop, 6e6-byte charge id, real run', 'process': [r.exit_code, len(r.stdout), r.stderr.decode()],
                        'verdict': list(d), 'pass': d[0] == 'REFUSED'})
    if d[0] != 'REFUSED':
        failures.append(('resource', d))
    # real truncated output: the kernel file size limit cuts stdout at 30 bytes
    r = fc.run_process(EXE, fc.wire(v), 29)        # limit = bound + 1 = 30 bytes
    d = fc.decide_from_result(v, r)
    log['real'].append({'case': 'real truncated output (RLIMIT_FSIZE 30 bytes)',
                        'process': [r.exit_code, r.signal, r.stdout.decode('latin-1'), r.overflow],
                        'verdict': list(d), 'pass': d[0] == 'REFUSED'})
    if d[0] != 'REFUSED':
        failures.append(('truncated', d))
    # the same truncated bytes, planted with exit 0 and no overflow flag (worst case): strict parser refuses
    d2 = fc.decide_from_result(v, ok_result(r.stdout))
    log['real'].append({'case': 'same cut bytes planted as exit 0, no overflow flag', 'verdict': list(d2),
                        'pass': d2[0] == 'REFUSED' and d2[1].startswith('D7')})
    if not log['real'][-1]['pass']:
        failures.append(('truncated-planted', d2))
    # wrong pin
    import shutil, os
    shutil.copyfile(EXE, 'refund-altered'); os.chmod('refund-altered', 0o600)
    with open('refund-altered', 'ab') as f:
        f.write(b'\x00')                                   # never executed: refused before run
    d = fc.decide(base(), 'refund-altered')
    os.remove('refund-altered')
    log['real'].append({'case': 'executable with another SHA-256 (not run)', 'verdict': list(d), 'pass': d[0] == 'REFUSED'})
    if d[0] != 'REFUSED':
        failures.append(('pin', d))
    log['failures'] = [list(map(str, f)) for f in failures]
    log['verdict'] = 'PASS' if not failures else 'FAIL'
    with open('controls_results.json', 'w') as f:
        json.dump(log, f, indent=1, default=repr)
    for row in log['planted']:
        print('%-4s %-62s %s' % ('ok' if row['pass'] else 'FAIL', row['control'], row['verdict']))
    print('prefix controls: %d, all refused: %s' % (len(good), not any(f[0].startswith('strict prefix') for f in failures)))
    for row in log['real']:
        print('%-4s %-50s %s %s' % ('ok' if row['pass'] else 'FAIL', row['case'], row.get('process', ''), row['verdict']))
    print('VERDICT', log['verdict'], 'planted', len(controls), 'failures', len(failures))
    return 0 if not failures else 1


if __name__ == '__main__':
    sys.exit(main())
