#!/usr/bin/env python3
"""Test packet-integrity rejection in disposable copies, never proof semantics."""
import argparse
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import shutil
import tempfile

BASE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--run', default='preflight-0001')
parser.add_argument('--output', required=True)
args = parser.parse_args()
spec = importlib.util.spec_from_file_location('fuse_benchmark', BASE / 'benchmark.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)
original_out = b.OUT
observations = []
with tempfile.TemporaryDirectory(prefix='fuse-readback-') as temp:
    root = Path(temp)
    b.BASE = root / 'package'
    b.BASE.mkdir()
    for name in ('FREEZE.json', 'FREEZE.sha256'):
        shutil.copyfile(BASE / name, b.BASE / name)
    shutil.copytree(BASE / 'anchors', b.BASE / 'anchors')
    b.OUT = root / 'results'
    shutil.copytree(original_out / args.run, b.OUT / args.run)
    record = b.OUT / args.run

    def check(name, expected=None):
        try:
            with contextlib.redirect_stdout(io.StringIO()):
                code = b.validate(args.run)
            observation = {'name': name, 'actual_exit': code, 'refusal': None}
            passed = expected is None and code == 0
        except ValueError as error:
            observation = {'name': name, 'actual_exit': None, 'refusal': str(error)}
            passed = expected is not None and str(error).startswith(expected)
        observation['expected_behavior_observed'] = passed
        observations.append(observation)
        if not passed:
            raise RuntimeError('Unexpected readback-control result: ' + repr(observation))

    check('intact')
    report = record / 'COMPARISON.md'
    original = report.read_bytes()
    report.write_bytes(original + b'false comparison claim\n')
    check('changed_comparison', 'REPORT_CHANGED')
    report.write_bytes(original)
    link = record / 'unexpected-broken-link'
    link.symlink_to(record / 'does-not-exist')
    check('broken_link', 'UNSAFE_RESULT_ENTRY')
    link.unlink()
    result = record / 'result.json'
    original = result.read_bytes()
    changed = json.loads(original)
    changed['scored_cells'] = 18
    result.write_bytes(b.canonical(changed))
    check('fabricated_trial_count', 'RESULT_CHANGED')
    result.write_bytes(original)
    check('restored')
    launch = root / 'launch-error'
    launch.mkdir()
    command, _ = b.run_command(launch, 'missing-command', [str(root / 'nonexistent-executable')])
    assert command['actual_exit'] is None and command['launch_error']['errno'] == 2
    observations.append({'name': 'launch_error', 'actual_exit': None,
                         'errno': 2, 'expected_behavior_observed': True})

out = Path(args.output)
out.parent.mkdir(parents=True, exist_ok=True)
with out.open('x') as stream:
    json.dump({'actual_exit': 0, 'scope': 'local packet readback only, not proof or admission',
               'controls': observations}, stream, indent=2)
    stream.write('\n')
print(json.dumps({'actual_exit': 0, 'controls': len(observations), 'scope': 'readback only'}))
