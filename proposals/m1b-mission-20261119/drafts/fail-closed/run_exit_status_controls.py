"""Controls for the exit-status finding (report D4, U475). FINITE TEST, not a proof. The executable is NOT run.

The real exit routine tests the low 32 bits of x0 and the process status is the low 8 bits, while the
model tests all 64 bits. So a resource stop in the model could show as exit status 0, with or without a
stderr line. Whether such an x0 value is REACHABLE is not known (no theorem either way). These planted
process results check that the caller never authorizes on the exit status: for every (status, stderr)
pair it authorizes ONLY the one complete expected frame, and with status 0 and empty stderr it refuses
every strict prefix. Exit 0 iff every row is as expected.
"""
import json
import sys

import m1_fail_closed as fc
from run_fail_closed_controls import base, ok_result

F = base()
R = fc.expected_accept(F)
LINE = b'Program exited with nonzero exit code.\n'
rows, bad = [], 0


def row(name, result, want_verdict, want_step=None):
    global bad
    got = fc.decide_from_result(F, result)
    good = got[0] == want_verdict and (want_step is None or str(got[1]).startswith(want_step))
    bad += not good
    rows.append({'case': name, 'expected': [want_verdict, want_step], 'actual': list(map(str, got)), 'as_expected': good})


# positive control: without it "refuse everything" would pass
row('P0 status 0, empty stderr, the complete expected frame', ok_result(R), 'AUTHORIZED')
# x0 = 2^32 in the model: status 0, EMPTY stderr; output any prefix
prefixes = [R[:n] for n in range(len(R))]
refused = sum(fc.decide_from_result(F, ok_result(p))[0] == 'REFUSED' for p in prefixes)
rows.append({'case': 'x0 = 2^32 shape: status 0, empty stderr, each of the %d strict prefixes' % len(prefixes),
             'expected': len(prefixes), 'actual': refused, 'as_expected': refused == len(prefixes)})
bad += refused != len(prefixes)
row('x0 = 2^32 shape, empty output', ok_result(b''), 'REFUSED', 'D6')
# x0 = 256 in the model: status 0 WITH the stderr line; output complete or cut
row('x0 = 256 shape: status 0, stderr line, COMPLETE output', ok_result(R, stderr=LINE), 'REFUSED', 'D4')
row('x0 = 256 shape: status 0, stderr line, cut output', ok_result(R[:-1], stderr=LINE), 'REFUSED', 'D4')
# resource stop after the last write: non-zero status with the COMPLETE output
for code in (1, 2, 3, 255):
    row('status %d, stderr line, COMPLETE output' % code, ok_result(R, exit_code=code, stderr=LINE), 'REFUSED', 'D3')
    row('status %d, EMPTY stderr, COMPLETE output' % code, ok_result(R, exit_code=code), 'REFUSED', 'D3')
# no status
row('signal, COMPLETE output', ok_result(R, exit_code=None, signal=9), 'REFUSED', 'D2')
row('time limit, COMPLETE output', ok_result(R, timed_out=True), 'REFUSED', 'D1')
# the frame of ANOTHER request with status 0: the exit status says nothing about binding
other = fc.expected_accept(base(request=b'req 0041'))
row('status 0, complete frame of another request', ok_result(other), 'REFUSED', 'D')
row('status 0, complete frame twice', ok_result(R + R), 'REFUSED', 'D')
row('status 0, complete frame + newline', ok_result(R + b'\n'), 'REFUSED', 'D')

json.dump({'what': 'exit-status controls on planted process results; finite test; the executable is not run',
           'rows': rows, 'not_as_expected': bad}, open('exit_status_controls_results.json', 'w'), indent=1)
print('%d rows, %d not as expected' % (len(rows), bad))
sys.exit(1 if bad else 0)
