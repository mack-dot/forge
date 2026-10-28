#!/usr/bin/env python3
"""Exercise Dafny member selection. This diagnostic never accepts an artifact."""

import hashlib
import json
from pathlib import Path
import shlex
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET


ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/stage4-member-probe'
DAFNY = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
SOLVER = ROOT / '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1'
OPTIONS = [
    '--solver-path', str(SOLVER), '--resource-limit', '1000000',
    '--verification-time-limit', '0', '--cores', '1', '--verify-included-files',
]
INPUTS = [
    'impl/Ledger.dfy', 'spec/LedgerSpec.dfy', 'spec.lock',
    'gate/ContractBinding.dfy', 'toolchain/pins.json', 'scripts/probe_stage_4.py',
]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def portable(command):
    return [argument.replace(str(ROOT) + '/', '') for argument in command]


def verify(name, fixture, selected):
    report = WORK / (name + '.trx')
    command = [str(DAFNY), 'verify', str(fixture / 'impl/Ledger.dfy'),
               str(fixture / 'gate/ContractBinding.dfy'), *OPTIONS,
               '--log-format', 'trx;LogFileName=' + str(report)]
    if selected:
        command += ['--filter-symbol', 'Ledger.Apply.']
    run = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    log = WORK / (name + '.log')
    log.write_text(run.stdout + run.stderr)
    print(name + ': Dafny exit ' + str(run.returncode), flush=True)
    if run.returncode not in (0, 4):
        raise RuntimeError('TOOLCHAIN_OR_INPUT_ERROR: ' + run.stdout + run.stderr)
    results = sorted([
        {'member': element.attrib['testName'], 'outcome': element.attrib['outcome']}
        for element in ET.parse(report).getroot().iter()
        if element.tag.endswith('UnitTestResult')
    ], key=lambda item: item['member'])
    return {
        'name': name, 'command': shlex.join(portable(command)),
        'exit_code': run.returncode, 'selected_symbol': 'Ledger.Apply.' if selected else None,
        'obligations': results, 'obligation_count': len(results),
        'raw_log': str(log.relative_to(ROOT)),
        'fixture_source_sha256': sha(fixture / 'impl/Ledger.dfy'),
    }


def main():
    before = {name: sha(ROOT / name) for name in INPUTS}
    pins = json.loads((ROOT / 'toolchain/pins.json').read_text())
    version = subprocess.run([str(DAFNY), '--version'], cwd=ROOT,
                             capture_output=True, text=True)
    if version.returncode != 0 or version.stdout.strip() != pins['dafny']['version_output']:
        raise RuntimeError('TOOLCHAIN_ERROR: ' + version.stdout + version.stderr)
    if WORK.exists():
        raise RuntimeError('Existing probe output: preserve it and move it before rerunning.')
    WORK.mkdir(parents=True)
    for variant in ('correct', 'broken-helper'):
        fixture = WORK / variant
        for name in ('impl/Ledger.dfy', 'spec/LedgerSpec.dfy', 'gate/ContractBinding.dfy'):
            target = fixture / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / name, target)
        if variant == 'broken-helper':
            target = fixture / 'impl/Ledger.dfy'
            source = target.read_text()
            needle = '  {\n    TotalRemove(balances, account);'
            if source.count(needle) != 1:
                raise RuntimeError('Fixture mutation target changed; inspect before proceeding.')
            target.write_text(source.replace(
                needle, '  {\n    assert false; // Deliberate dependency rejection fixture.\n'
                '    TotalRemove(balances, account);', 1))
    cases = []
    for name, variant, selected in (
        ('correct-full', 'correct', False),
        ('correct-apply', 'correct', True),
        ('broken-helper-full', 'broken-helper', False),
        ('broken-helper-apply', 'broken-helper', True),
    ):
        cases.append(verify(name, WORK / variant, selected))
    full, selected, broken_full, broken_selected = cases
    expected_codes_observed = [case['exit_code'] for case in cases] == [0, 0, 4, 0]
    selected_names = {item['member'] for item in selected['obligations']}
    member_selection_observed = selected_names == {
        'Ledger.Apply (correctness)', 'Ledger.Apply (well-formedness)',
    }
    helper_rejection_observed = any(
        item['member'] == 'Ledger.TotalReplace (correctness)' and item['outcome'] == 'Failed'
        for item in broken_full['obligations'])
    inputs_unchanged = before == {name: sha(ROOT / name) for name in INPUTS}
    passed = (expected_codes_observed and member_selection_observed
              and helper_rejection_observed and inputs_unchanged)
    result = {
        'stage': 4, 'kind': 'member_selection_diagnostic',
        'stage_exit': False, 'accepts_artifacts': False, 'end_to_end': False,
        'reproduce_cmd': 'python3 scripts/probe_stage_4.py',
        'tool': 'Dafny', 'tool_version': version.stdout.strip(),
        'version_exit_code': version.returncode, 'input_sha256': before,
        'cases': cases, 'probe_exit_code': 0 if passed else 1,
        'expected_codes_observed': expected_codes_observed,
        'member_selection_observed': member_selection_observed,
        'helper_rejection_observed': helper_rejection_observed,
        'inputs_unchanged': inputs_unchanged,
        'limitation': 'Selection alone does not check dependencies or authorize proof reuse. '
                      'No dependency graph, incremental gate, PR workflow, or Stage 4 EXIT '
                      'is established by this diagnostic.',
    }
    encoded = json.dumps(result, sort_keys=True, indent=2) + '\n'
    (ROOT / 'results/stage4-member-probe.json').write_text(encoded)
    print('PROBE_OBSERVED' if passed else 'UNEXPECTED_PROBE_RESULT', flush=True)
    return 0 if passed else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, KeyError, ET.ParseError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
