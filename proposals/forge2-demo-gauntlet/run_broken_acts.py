"""Wave Gate 3: the demo must FAIL when a component that it shows is broken.

For each mutation this runner changes ONE component file inside a scratch clone (a text replacement),
runs the UNCHANGED scripts/demo_gauntlet.py there, records the real exit code and the last line, and
puts the file back. The demo must exit 1 with a message of the act that the mutation breaks. The
unchanged clone must exit 0 before and after.

The mutations break the system under demonstration (a sink without a check, an issuer without its
line limit, a wrong checker core, a planted spec that is not equivalent). They do not change the
demo script. Use a scratch clone with the links .toolchain and node_modules, not the owner's tree.

Usage: python3 proposals/forge2-demo-gauntlet/run_broken_acts.py <clone> <record.json>
Environment: the pinned Node first in PATH; rustc in PATH. No other Dafny job on the machine (Act 3
of the unchanged runs requires that no Dafny process is seen).
"""
import json, subprocess, sys
from pathlib import Path

clone, record_path = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
FLOOD = '600'
WRONG_CORE = (clone / 'tests/refund-finality/fixtures/CoreIssuesEverything.dfy').read_text().replace(
    'include "../../../impl/Refund.dfy"', 'include "Refund.dfy"')
# (name, act that must fail, file, old text (must occur once) or None for a whole-file replacement, new text, text that the failure line must hold)
MUTATIONS = [
    ('clearing: the "rewritten" planted spec loses one approved reason (not equivalent any more)', 1,
     'clearing/planted/RefundSpecRewritten.dfy',
     'reason == "returned_item" || reason == "duplicate_charge" || reason == "service_not_delivered"',
     'reason == "returned_item" || reason == "duplicate_charge"', 'act 1'),
    ('refund sink without the signature check', 2, 'ts/refund-finality/sink.ts',
     '    if (!this.verified(token)) return { status: "rejected", reason: "signature does not verify" };\n', '', 'act 2a'),
    ('refund sink without the pre-state hash check', 2, 'ts/refund-finality/sink.ts',
     'if (sha256hex(stored) !== token.body.preStateSha256) {', 'if (false) {', 'act 2b'),
    ('refund sink without the settled-request check', 2, 'ts/refund-finality/sink.ts',
     'if (prior !== undefined) {', 'if (false) {', 'act 2'),
    ('issuer without the line limit', 2, 'ts/refund-finality/minter.ts',
     'const MAX_LINE_BYTES = 65536;', 'const MAX_LINE_BYTES = 2 ** 40;', 'act 2'),
    ('wrong checker core (it issues a token for everything) in place of impl/RefundFinality.dfy', 2,
     'impl/RefundFinality.dfy', None, WRONG_CORE, 'CORE_MODULE'),
    ('booking sink without the signature check', 3, 'ts/booking-certificate/sink.ts',
     '    if (!this.verified(token)) return { status: "rejected", reason: "signature does not verify" };\n', '', 'act 3'),
]
rows = []


def demo(label):
    child = subprocess.run(['python3', 'scripts/demo_gauntlet.py', '--flood-mb', FLOOD], cwd=clone, capture_output=True, text=True)
    lines = (child.stdout + child.stderr).replace(str(clone), '<clone>').strip().splitlines()
    last = (lines[-1] if lines else '')[:300]
    print('%s: exit %d: %s' % (label, child.returncode, last), flush=True)
    return child.returncode, last


before = demo('unchanged clone')
for name, act, path, old, new, marker in MUTATIONS:
    target = clone / path
    original = target.read_text()
    if old is not None and original.count(old) != 1:
        raise SystemExit('text not found exactly once in ' + path)
    target.write_text(new if old is None else original.replace(old, new))
    try:
        code, last = demo(name)
    finally:
        target.write_text(original)
    rows.append({'mutation': name, 'file': path, 'act_that_must_fail': act, 'exit_code': code, 'last_line': last,
                 'failure_names_the_act': last.startswith('GAUNTLET FAILED') and marker in last})
after = demo('unchanged clone, again')
good = sum(row['exit_code'] == 1 and row['failure_names_the_act'] for row in rows)
record = {'what': 'Wave Gate 3: scripts/demo_gauntlet.py (unchanged) in a scratch clone with one component broken per run',
          'flood_mib': int(FLOOD), 'unchanged_clone_exit_codes': [before[0], after[0]], 'mutations': len(rows),
          'mutations_with_exit_1_at_the_expected_act': good, 'rows': rows, 'end_to_end': False}
record_path.write_text(json.dumps(record, indent=1, sort_keys=True) + '\n')
print(json.dumps({key: record[key] for key in ('unchanged_clone_exit_codes', 'mutations', 'mutations_with_exit_1_at_the_expected_act')}))
raise SystemExit(0 if before[0] == 0 and after[0] == 0 and good == len(rows) else 1)
