#!/usr/bin/env python3
"""Real local controls for the snapshot gate; never substitutes for PR EXITs."""

import hashlib
import json
from pathlib import Path
import shlex
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/stage4-local'
DIRECTORIES = ('gate', 'policy', 'spec', 'toolchain', 'schemas', '.github', 'impl')


def copy_candidate(name):
    target = WORK / 'candidates' / name
    target.mkdir(parents=True)
    for directory in DIRECTORIES:
        if (ROOT / directory).exists():
            shutil.copytree(ROOT / directory, target / directory,
                            ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    for filename in ('spec.lock', 'AGENTS.md'):
        shutil.copyfile(ROOT / filename, target / filename)
    return target


def replace_once(path, old, new):
    source = path.read_text()
    if source.count(old) != 1:
        raise RuntimeError('Mutation target changed: ' + str(path))
    path.write_text(source.replace(old, new, 1))


def run(command, log):
    child = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    log.write_text(child.stdout + child.stderr)
    return child


def main():
    if WORK.exists():
        raise RuntimeError('Preserve existing build/stage4-local before rerunning.')
    WORK.mkdir(parents=True)
    report = {'stage': 4, 'stage_exit': False, 'end_to_end': False, 'cases': []}
    cases = [
        ('unchanged', 0, 0), ('apply-edit', 0, 0), ('apply-edit-repeat', 0, 0),
        ('broken-helper', 1, 4), ('helper-contract', 1, 4), ('self-transfer', 1, 4),
        ('sneaky-assume', 1, 2), ('spec-and-lock', 1, None), ('weaken-c2', 1, None),
    ]
    for name, expected_gate, expected_fresh in cases:
        candidate = copy_candidate(name)
        implementation = candidate / 'impl/Ledger.dfy'
        if name in ('apply-edit', 'apply-edit-repeat'):
            debit = next(line.strip() for line in implementation.read_text().splitlines()
                         if line.strip().startswith('var debit :='))
            replace_once(implementation, debit, debit + '\n      assert 0 <= debit;')
        elif name == 'broken-helper':
            replace_once(implementation, '  {\n    TotalRemove(balances, account);',
                         '  {\n    assert false;\n    TotalRemove(balances, account);')
        elif name == 'helper-contract':
            replace_once(implementation,
                         '    ensures Total(balances[account := value]) ==\n'
                         '      Total(balances) - balances[account] + value',
                         '    ensures true')
        elif name == 'self-transfer':
            implementation.write_bytes((ROOT / 'bugs/self_transfer.dfy').read_bytes())
        elif name == 'sneaky-assume':
            replace_once(implementation, '  method Apply ... {',
                         '  method Apply ... {\n    assume false;')
        elif name in ('spec-and-lock', 'weaken-c2'):
            spec = candidate / 'spec/LedgerSpec.dfy'
            if name == 'weaken-c2':
                replace_once(spec, '    forall account | account in balances :: 0 <= balances[account]',
                             '    true')
            else:
                spec.write_text(spec.read_text() + '\n// Unapproved spec revision.\n')
            lock = json.loads((candidate / 'spec.lock').read_text())
            lock['spec_sha256'] = hashlib.sha256(spec.read_bytes()).hexdigest()
            (candidate / 'spec.lock').write_text(json.dumps(lock, sort_keys=True) + '\n')
        evidence = WORK / (name + '-evidence.json')
        run_work = WORK / ('run-' + name)
        command = ['python3', 'gate/incremental.py', '--candidate', str(candidate.relative_to(ROOT)),
                   '--evidence', str(evidence.relative_to(ROOT)), '--work', str(run_work.relative_to(ROOT))]
        child = run(command, WORK / (name + '-gate.log'))
        print(name + ': gate exit ' + str(child.returncode), flush=True)
        case = {'name': name, 'command': command, 'gate_exit_code': child.returncode,
                'expected_gate_exit_code': expected_gate, 'evidence_exists': evidence.exists()}
        if (run_work / 'operation.json').exists():
            operation = json.loads((run_work / 'operation.json').read_text())
            case['checker_exit_codes'] = [item['exit_code'] for item in operation['commands']]
            if 'snapshots' in operation:
                case['snapshots'] = operation['snapshots']
        report['cases'].append(case)
        if child.returncode != expected_gate or evidence.exists() != (expected_gate == 0):
            raise RuntimeError(name + ': unexpected gate result; inspect ' + str(WORK / (name + '-gate.log')))
        if expected_fresh is not None:
            fresh = run([
                '.toolchain/dafny-4.11.0/dafny/dafny', 'verify', str(implementation),
                str(candidate / 'gate/ContractBinding.dfy'),
                '--solver-path', '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1',
                '--resource-limit', '1000000', '--verification-time-limit', '0',
                '--cores', '1', '--verify-included-files',
            ], WORK / (name + '-fresh.log'))
            case['fresh_dafny_exit_code'] = fresh.returncode
            print(name + ': fresh Dafny exit ' + str(fresh.returncode), flush=True)
            if fresh.returncode != expected_fresh:
                raise RuntimeError(name + ': unexpected full-check result')
            if name == 'sneaky-assume' and 'assume statement has no {:axiom} annotation' not in fresh.stdout:
                raise RuntimeError('Missing expected diagnostic for the forbidden assumption')
        if name == 'unchanged':
            assert case['snapshots'][1]['checked_count'] == 0
            assert case['snapshots'][1]['reused_count'] == 12
        elif name in ('apply-edit', 'apply-edit-repeat'):
            assert case['snapshots'][1]['checked'] == [
                'Ledger.Apply (correctness)', 'Ledger.Apply (well-formedness)']
            assert case['snapshots'][1]['reused_count'] == 10
    first = (WORK / 'apply-edit-evidence.json').read_bytes()
    second = (WORK / 'apply-edit-repeat-evidence.json').read_bytes()
    if first != second:
        raise RuntimeError('Evidence differs across identical input runs')
    recipe = json.loads(first)['evidence'][0]['reproduce_cmd']
    replay = run(shlex.split(recipe), WORK / 'exact-reproduction.log')
    report['exact_reproduction'] = {'command': recipe, 'exit_code': replay.returncode}
    if replay.returncode != 0 or (ROOT / 'build/change-evidence.json').read_bytes() != first:
        raise RuntimeError('The exact saved reproduction command did not reproduce identical evidence')
    report.update({'result': 'passed', 'exit_code': 0, 'byte_identical_evidence': True,
                   'evidence_sha256': hashlib.sha256(first).hexdigest()})
    (ROOT / 'results/stage4-local.json').write_text(json.dumps(report, sort_keys=True, indent=2) + '\n')
    print('LOCAL_CONTROLS_PASSED; real PR EXITs remain NOT RUN', flush=True)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, AssertionError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
