#!/usr/bin/env python3
"""Execute real Stage 1 checks and preserve their raw command exit codes."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


ROOT = Path(__file__).resolve().parent.parent
DAFNY = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
CASES = ('reproducibility', 'planted-bugs', 'spec-lock', 'contract-binding', 'audit-controls')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', required=True, choices=CASES)
    case = parser.parse_args().case
    destination = ROOT / 'build/stage1' / case
    if (destination / 'report.json').exists():
        history = ROOT / 'build/stage1-history' / case
        history.mkdir(parents=True, exist_ok=True)
        attempt = 1
        while (history / str(attempt)).exists():
            attempt += 1
        shutil.copytree(destination, history / str(attempt))
    destination.mkdir(parents=True, exist_ok=True)
    records = []
    report = {'case': case, 'commands': records, 'result': 'incomplete'}

    def invoke(name, command, cwd=ROOT):
        completed = subprocess.run(command, cwd=cwd, capture_output=True, text=True)
        log = destination / (name + '.log')
        log.write_text(completed.stdout + completed.stderr)
        records.append({'name': name, 'command': [str(arg) for arg in command],
                        'cwd': str(cwd), 'exit_code': completed.returncode,
                        'log': str(log.relative_to(ROOT))})
        return completed

    def require(condition, message):
        if not condition:
            raise AssertionError(message)

    def gate(name, implementation, evidence, cwd=ROOT):
        return invoke(name, [sys.executable, 'gate/gate.py', '--impl', implementation,
                             '--evidence', evidence], cwd)

    def sandbox():
        work = tempfile.TemporaryDirectory(prefix='stage1-fixture-', dir=ROOT / 'build')
        clone = Path(work.name)
        for folder in ('gate', 'spec', 'impl', 'toolchain', 'schemas', 'policy'):
            shutil.copytree(ROOT / folder, clone / folder,
                            ignore=shutil.ignore_patterns('__pycache__'))
        shutil.copyfile(ROOT / 'spec.lock', clone / 'spec.lock')
        (clone / '.toolchain').symlink_to(ROOT / '.toolchain', target_is_directory=True)
        (clone / 'bugs').mkdir()
        return work, clone

    try:
        if case == 'reproducibility':
            evidence = 'build/stage1/reproducibility/evidence.json'
            first = gate('gate-first', 'impl/Ledger.dfy', evidence)
            require(first.returncode == 0, 'first gate invocation failed')
            shutil.copyfile(ROOT / evidence, destination / 'first.json')
            second = gate('gate-second', 'impl/Ledger.dfy', evidence)
            require(second.returncode == 0, 'second gate invocation failed')
            compared = invoke('byte-comparison', ['cmp', str(destination / 'first.json'),
                                                 str(ROOT / evidence)])
            require(compared.returncode == 0, 'evidence files differ')
            report['evidence_sha256'] = hashlib.sha256((ROOT / evidence).read_bytes()).hexdigest()

        elif case == 'planted-bugs':
            expectations = {'self_transfer': 'C1', 'off_by_one': 'C4',
                            'retry_double': 'C3', 'sneaky_assume': 'AUDIT_REJECTED'}
            report['unit_method'] = 'unit_tested'
            report['unit_scope'] = ['one non-boundary valid transfer', 'one unknown recipient']
            for name, expected in expectations.items():
                unit_source = destination / name / 'Basic.dfy'
                unit_source.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / 'tests/Basic.dfy', unit_source)
                implementation = 'bugs/' + name + '.dfy'
                unit = invoke(name + '-units', [str(DAFNY), 'run', str(unit_source),
                                               '--input', implementation,
                                               '--target', 'py', '--no-verify'])
                require(unit.returncode == 0 and 'basic unit tests passed' in unit.stdout,
                        name + ': real unit tests failed')
                evidence = 'build/stage1/planted-bugs/' + name + '.evidence.json'
                rejected = gate(name + '-gate', implementation, evidence)
                require(rejected.returncode == 1, name + ': gate did not reject as expected')
                require(expected in rejected.stderr, name + ': expected claim/rule was not named')
                if name != 'sneaky_assume':
                    require('VERIFICATION_REJECTED' in rejected.stderr and 'Dafny exit 4' in rejected.stderr,
                            name + ': rejection was not the expected verifier result')
                require(not (ROOT / evidence).exists(), name + ': rejection left accepted evidence')

        elif case == 'spec-lock':
            temporary, clone = sandbox()
            with temporary:
                approved = (ROOT / 'spec/LedgerSpec.dfy').read_bytes()
                changed = clone / 'spec/LedgerSpec.dfy'
                changed.write_bytes(approved + b'\n// Deliberate stale-lock negative control.\n')
                rejected = gate('changed-spec-old-lock', 'impl/Ledger.dfy', 'evidence.json', clone)
                require(rejected.returncode == 1 and 'SPEC_LOCK' in rejected.stderr,
                        'changed spec was not rejected for its stale lock')
                require(not (clone / 'evidence.json').exists(), 'rejection emitted evidence')
                require((ROOT / 'spec/LedgerSpec.dfy').read_bytes() == approved,
                        'the approved baseline was modified')

        elif case == 'contract-binding':
            temporary, clone = sandbox()
            with temporary:
                declarations = (ROOT / 'spec/LedgerSpec.dfy').read_text().split('  method Apply(')[0]
                declarations = declarations.replace('abstract module LedgerSpec {', 'module Ledger {', 1)
                candidate = 'include "../spec/LedgerSpec.dfy"\n\n' + declarations + '''  method Apply(state: State, id: int, request: Request)
      returns (next: State, outcome: Outcome)
    requires WellFormed(state)
  {
    next := state;
    outcome := Ok;
  }
}
'''
                (clone / 'bugs/unbound.dfy').write_text(candidate)
                rejected = gate('missing-approved-contract', 'bugs/unbound.dfy', 'evidence.json', clone)
                require(rejected.returncode == 1, 'unbound implementation was not rejected')
                require('refin' in rejected.stderr.lower(),
                        'rejection did not identify the missing refinement relationship')
                require(not (clone / 'evidence.json').exists(), 'unbound code emitted evidence')

        elif case == 'audit-controls':
            additions = {
                'bodyless_lemma': '  lemma MissingProof() ensures false\n',
                'axiom_lemma': '  lemma {:axiom} Granted() ensures false\n',
                'verify_false': '  lemma {:verify false} Unchecked() ensures false {}\n',
            }
            for name, addition in additions.items():
                temporary, clone = sandbox()
                with temporary:
                    source = (ROOT / 'impl/Ledger.dfy').read_text().rstrip()
                    require(source.endswith('}'), 'unexpected fixture template')
                    (clone / 'bugs/control.dfy').write_text(source[:-1] + addition + '}\n')
                    checker = invoke(name + '-dafny-audit', [str(DAFNY), 'audit',
                                     'bugs/control.dfy', 'gate/ContractBinding.dfy',
                                     '--report-format', 'md', '--report-file',
                                     'gate/expected-audit.md', '--compare-report'], clone)
                    require(checker.returncode != 0,
                            name + ': direct Dafny audit comparison unexpectedly succeeded')
                    rejected = gate(name, 'bugs/control.dfy', 'evidence.json', clone)
                    require(rejected.returncode == 1 and 'AUDIT_REJECTED' in rejected.stderr,
                            name + ': forbidden construct was not rejected by the audit path')
                    require(not (clone / 'evidence.json').exists(), name + ': rejection emitted evidence')

        report['result'] = 'passed'
        print(case + ': passed (expected raw failures retained in report)')
        return 0
    except (AssertionError, OSError) as error:
        report['result'] = 'failed'
        report['error'] = str(error)
        print(case + ': ' + str(error), file=sys.stderr)
        return 1
    finally:
        (destination / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')


if __name__ == '__main__':
    sys.exit(main())
