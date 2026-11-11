"""Run prepared local HOL controls serially and require the recorded refusal reasons."""
from pathlib import Path
import json
import subprocess
import sys

OUT = Path(__file__).resolve().parent
ROOT = Path('/Users/mackianni/forge')
positive = json.loads((OUT / 'exact-import-0003/command.json').read_text())
assert positive['actual_exit'] == 0 and positive['import_complete']
first = json.loads((OUT / 'pointer-0003/command.json').read_text())
repeat = json.loads((OUT / 'pointer-repeat/command.json').read_text())
assert repeat['actual_exit'] == 0 and repeat['completion_marker']
assert first['source_sha256'] == repeat['source_sha256']
assert len(first['objects']) == 4 and first['objects'] == repeat['objects']
parents = ['space-parent:forge_installSpaceBarrier', 'trace-parent:forge_spaceInstallTrace',
           'word-parent:forge_compilerWordTrace', 'data-parent:forge_refundDataBehavior',
           'refund-parent:forge_refundWordPremises', 'init-parent:forge_refundWordInitialization',
           'epoch-parent:forge_refundInitializedEpoch', 'oracle-parent:forge_refundWordOracle',
           'stack-parent:forge_refundStackInitialization', 'pointer-0003:forge_refundPointerWitness']
cases = [('wrong-pointer', 'Exact statement mismatch: refund_fixed_syntax_pointer_witness'),
         ('missing-prefix', 'Exact statement mismatch: refund_pointer_fixed_point'),
         ('missing-space', 'unsolved goals')]
records = {}
for name, reason in cases:
    argv = [sys.executable, '-B', str(OUT / 'run_import.py'), name,
            str(OUT / (name + '-limits.sml')), *parents]
    with (OUT / (name + '-dispatch.stdout.log')).open('xb') as out, (OUT / (name + '-dispatch.stderr.log')).open('xb') as err:
        result = subprocess.run(argv, cwd=ROOT, stdout=out, stderr=err)
    actual = json.loads((OUT / name / 'command.json').read_text())
    log = ''.join((OUT / name / f).read_text() for f in ['stdout.log', 'stderr.log'])
    assert result.returncode == actual['actual_exit'] == 1, name
    assert len([x for x in log.splitlines() if x.startswith('IMPORTED ')]) == 4, name
    assert 'KERNEL_PREMISES_EQUIVALENT true' in log and 'AFTER_POSITIVE_AUDIT' in log, name
    assert reason in log and 'UNEXPECTED_CONTROL_ACCEPTANCE' not in log, name
    if name == 'missing-space':
        assert 'First unsolved sub-goal is' in log and 'data_lang_safe_for_space' in log
    records[name] = {'argv': argv, 'actual_exit': actual['actual_exit'],
                     'observed_refusal': reason, 'positive_audit_passed_first': True}
    print(json.dumps({'case': name, 'actual_exit': actual['actual_exit'], 'observed_refusal': reason}), flush=True)
destination = OUT / 'controls-readback.json'
assert not destination.exists()
destination.write_text(json.dumps({'actual_exit': 0, 'controls': records,
                                  'identical_exports': first['objects'], 'end_to_end': False}, indent=2) + '\n')
