#!/usr/bin/env python3
"""Real local controls for the snapshot gate; never substitutes for PR EXITs.

Each candidate is a complete copy of this checkout (minus untracked trees), so the
gate's coverage assessment sees the same change set a PR would carry. Outcomes:
0 VERIFIED, 1 REJECTED, 2 NOT_ESTABLISHED, 3 UNSUPPORTED. A ledger edit whose
committed evidence.json is not regenerated is REJECTED (the committed evidence no
longer reproduces); the same edit with regenerated evidence is VERIFIED after the
dependent obligations (booking, model, witness, evidence) are re-established. Results go to results/stage4/local-coverage-v2.json;
the historical results/stage4-local.json is never rewritten.
"""

import hashlib
import json
import os
from pathlib import Path
import shlex
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[1]
WORK = ROOT / 'build/stage4-local'
UNTRACKED = ('.git', '.toolchain', 'build', 'node_modules', 'TestResults')
REPORT = ROOT / 'results/stage4/local-coverage-v2.json'
OUTCOMES = {0: 'VERIFIED', 1: 'REJECTED', 2: 'NOT_ESTABLISHED', 3: 'UNSUPPORTED'}


def copy_tree(source, target):
    target.mkdir(parents=True)
    for entry in sorted(source.iterdir()):
        if entry.name in UNTRACKED or entry.name == '__pycache__':
            continue
        if sys.platform == 'darwin':
            subprocess.run(['/bin/cp', '-cRp', str(entry), str(target / entry.name)], check=True)
        elif entry.is_dir() and not entry.is_symlink():
            shutil.copytree(entry, target / entry.name, symlinks=True,
                            ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
        else:
            shutil.copy2(entry, target / entry.name, follow_symlinks=False)
    for pycache in target.rglob('__pycache__'):
        shutil.rmtree(pycache)


def regenerate_evidence(candidate):
    """Produce the candidate's committed evidence with the trusted gate, as a real PR would."""
    for link in ('.toolchain', 'node_modules'):
        if (ROOT / link).exists():
            (candidate / link).symlink_to(ROOT / link)
    child = subprocess.run(['python3', 'gate/gate.py', '--impl', 'impl/Ledger.dfy', '--evidence', 'evidence.json'],
                           cwd=candidate, capture_output=True, text=True,
                           env=dict(os.environ, PYTHONDONTWRITEBYTECODE='1'))
    if child.returncode:
        raise RuntimeError('evidence regeneration failed: ' + child.stdout + child.stderr)
    for link in ('.toolchain', 'node_modules'):
        if (candidate / link).is_symlink():
            (candidate / link).unlink()
    shutil.rmtree(candidate / 'build', ignore_errors=True)
    for pycache in list(candidate.rglob('__pycache__')):
        shutil.rmtree(pycache)


def copy_candidate(name):
    target = WORK / 'candidates' / name
    copy_tree(ROOT, target)
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
    if REPORT.exists():
        raise RuntimeError('Preserve existing ' + str(REPORT.relative_to(ROOT)) + ' before rerunning.')
    WORK.mkdir(parents=True)
    report = {'stage': 4, 'stage_exit': False, 'end_to_end': False, 'cases': []}
    # name, expected gate exit, expected fresh Dafny exit (None: not run)
    cases = [
        ('unchanged', 0, 0), ('unchanged-repeat', 0, 0),
        ('apply-edit', 1, 0), ('apply-edit-repeat', 1, 0), ('apply-edit-regen', 0, 0),
        ('uncovered-ts', 3, None), ('uncovered-docs', 3, None),
        ('broken-helper', 1, 4), ('helper-contract', 1, 4), ('self-transfer', 1, 4),
        ('sneaky-assume', 1, 2), ('spec-and-lock', 1, None), ('weaken-c2', 1, None),
    ]
    for name, expected_gate, expected_fresh in cases:
        candidate = copy_candidate(name)
        implementation = candidate / 'impl/Ledger.dfy'
        if name in ('apply-edit', 'apply-edit-repeat', 'apply-edit-regen'):
            debit = next(line.strip() for line in implementation.read_text().splitlines()
                         if line.strip().startswith('var debit :='))
            replace_once(implementation, debit, debit + '\n      assert 0 <= debit;')
            if name == 'apply-edit-regen':
                regenerate_evidence(candidate)
        elif name == 'uncovered-docs':
            (candidate / 'README.md').write_text((candidate / 'README.md').read_text() + '\nLocal control note.\n')
        elif name == 'uncovered-ts':
            replace_once(candidate / 'ts/ledger.ts',
                         'balances.set(request.sender, debit - request.amount - 1n);',
                         'balances.set(request.sender, debit - request.amount);')
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
        operation = {}
        if (run_work / 'operation.json').exists():
            operation = json.loads((run_work / 'operation.json').read_text())
            case['outcome'] = operation.get('outcome')
            case['checker_exit_codes'] = [item['exit_code'] for item in operation['commands']]
            if 'snapshots' in operation:
                case['snapshots'] = operation['snapshots']
            if 'coverage' in operation:
                case['coverage'] = operation['coverage']
        report['cases'].append(case)
        if child.returncode != expected_gate or evidence.exists() != (expected_gate == 0):
            raise RuntimeError(name + ': unexpected gate result; inspect ' + str(WORK / (name + '-gate.log')))
        if operation.get('outcome') != OUTCOMES[expected_gate]:
            raise RuntimeError(name + ': operation outcome differs from the exit code')
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
        if name in ('unchanged', 'unchanged-repeat'):
            assert case['snapshots'][1]['checked_count'] == 0
            assert case['snapshots'][1]['reused_count'] == 12
            assert case['coverage']['covered'] and case['coverage']['changed'] == []
        elif name in ('apply-edit', 'apply-edit-repeat'):
            assert case['snapshots'][1]['checked'] == [
                'Ledger.Apply (correctness)', 'Ledger.Apply (well-formedness)']
            assert case['snapshots'][1]['reused_count'] == 10
            assert operation['error'].startswith('OBLIGATION_REJECTED: ledger-evidence:')
            assert operation['obligations']['ledger-evidence']['result'] == 'rejected'
        elif name == 'apply-edit-regen':
            assert case['snapshots'][1]['checked'] == [
                'Ledger.Apply (correctness)', 'Ledger.Apply (well-formedness)']
            assert sorted(operation['affected_obligations']) == [
                'booking', 'ledger-evidence', 'ledger-model', 'ledger-proof', 'ledger-witness']
            assert all(r['result'] == 'established' for r in operation['obligations'].values())
            assert sorted(c['path'] for c in case['coverage']['changed']) == ['evidence.json', 'impl/Ledger.dfy']
        elif name == 'uncovered-ts':
            # ts/ledger.ts is loaded into the model harness's own process, so a changed copy cannot
            # be judged by that harness: the change is not re-establishable (UNSUPPORTED).
            assert case['snapshots'][1]['checked_count'] == 0
            assert [f['reason'] for f in case['coverage']['findings']] == ['NOT_REESTABLISHABLE']
            assert operation['obligations'] == {}
        elif name == 'uncovered-docs':
            assert [c['path'] for c in case['coverage']['changed']] == ['README.md']
            assert [f['reason'] for f in case['coverage']['findings']] == ['UNCOVERED_CHANGE']
    first = (WORK / 'unchanged-evidence.json').read_bytes()
    second = (WORK / 'unchanged-repeat-evidence.json').read_bytes()
    if first != second:
        raise RuntimeError('Evidence differs across identical input runs')
    edits = [json.loads((WORK / ('run-' + n) / 'operation.json').read_text())
             for n in ('apply-edit', 'apply-edit-repeat')]
    if [(e['outcome'], e['error'][:60], e['affected_obligations']) for e in edits][0] != \
            [(e['outcome'], e['error'][:60], e['affected_obligations']) for e in edits][1]:
        raise RuntimeError('Decisions differ across identical input runs')
    recipe = json.loads(first)['evidence'][0]['reproduce_cmd']
    replay = run(shlex.split(recipe), WORK / 'exact-reproduction.log')
    report['exact_reproduction'] = {'command': recipe, 'exit_code': replay.returncode}
    if replay.returncode != 0 or (ROOT / 'build/change-evidence.json').read_bytes() != first:
        raise RuntimeError('The exact saved reproduction command did not reproduce identical evidence')
    report.update({'result': 'passed', 'exit_code': 0, 'byte_identical_evidence': True,
                   'evidence_sha256': hashlib.sha256(first).hexdigest()})
    REPORT.parent.mkdir(parents=True, exist_ok=True)
    REPORT.write_text(json.dumps(report, sort_keys=True, indent=2) + '\n')
    print('LOCAL_CONTROLS_PASSED; real PR EXITs remain NOT RUN', flush=True)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, AssertionError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
