#!/usr/bin/env python3
"""Execute actual Stage 3 comparisons and evidence-boundary checks."""

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
CASES = ('correct-typescript', 'self-transfer', 'evidence-labels', 'reproducibility', 'loader-demo', 'cli-demo')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', required=True, choices=CASES)
    case = parser.parse_args().case
    destination = ROOT / 'build/stage3' / case
    if (destination / 'report.json').exists():
        history = ROOT / 'build/stage3-history' / case
        history.mkdir(parents=True, exist_ok=True)
        attempt = 1
        while (history / str(attempt)).exists():
            attempt += 1
        shutil.copytree(destination, history / str(attempt))
    destination.mkdir(parents=True, exist_ok=True)
    records = []
    report = {'case': case, 'commands': records, 'result': 'incomplete'}

    def invoke(name, command):
        completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        log = destination / (name + '.log')
        log.write_text(completed.stdout + completed.stderr)
        records.append({'name': name, 'command': command, 'exit_code': completed.returncode,
                        'log': log.relative_to(ROOT).as_posix()})
        return completed

    def require(condition, message):
        if not condition:
            raise AssertionError(message)

    def gate(name, impl='ts/ledger.ts', tier='standard', output=None):
        output = output or ('build/stage3/' + case + '/' + name + '.json')
        result = invoke(name, [sys.executable, 'gate/gate.py', '--backend', 'typescript',
                              '--impl', impl, '--tier', tier, '--evidence', output])
        return result, ROOT / output

    try:
        if case == 'correct-typescript':
            result, path = gate('correct')
            require(result.returncode == 0, 'correct TypeScript did not pass the real gate')
            evidence = json.loads(path.read_text())
            actual = evidence['backend_details']['property_result']
            require(actual['result'] == 'passed' and actual['num_runs'] == 300 and actual['num_skips'] == 0,
                    'the actual fixed-seed property run was incomplete')
            require(all(value > 0 for value in actual['counters'].values()), 'required test category was missed')
            report['property_result'] = actual

        elif case == 'self-transfer':
            built = invoke('build-model', [sys.executable, 'scripts/build_model.py'])
            require(built.returncode == 0, 'real model build failed')
            target = 'build/stage3/self-transfer/property.json'
            checker = invoke('fast-check-self-transfer', ['node', '--import', 'tsx',
                             'tests/ledger.property.ts', '--impl', 'bugs/self_transfer.ts', '--report', target])
            require(checker.returncode == 1, 'planted bug did not cause actual property-test failure')
            actual = json.loads((ROOT / target).read_text())
            require(actual['failure_kind'] == 'comparison_assertion' and actual['counterexample'] is not None,
                    'failure was not a real model-comparison counterexample')
            result, path = gate('self-transfer-gate', impl='bugs/self_transfer.ts')
            require(result.returncode == 1 and 'PROPERTY_REJECTED' in result.stderr and 'fast-check exit 1' in result.stderr,
                    'gate failed for a different reason than the intended property rejection')
            require(not path.exists(), 'rejected bug emitted accepted evidence')
            report['property_result'] = actual

        elif case == 'evidence-labels':
            source_path = 'build/stage3/evidence-labels/source.json'
            source_run = invoke('source-proof', [sys.executable, 'gate/gate.py', '--impl',
                                'impl/Ledger.dfy', '--evidence', source_path])
            require(source_run.returncode == 0, 'real source proof gate failed')
            tested_run, tested_path = gate('model-comparison')
            require(tested_run.returncode == 0, 'real model-comparison gate failed')
            source = json.loads((ROOT / source_path).read_text())
            tested = json.loads(tested_path.read_text())
            require(all(record['method'] == 'source_proof' for record in source['evidence']),
                    'Dafny evidence has the wrong method')
            require(all(record['method'] == 'tested_against_proved_model' for record in tested['evidence']),
                    'TypeScript evidence overclaims its method')
            require(source['artifact']['sha256'] != tested['artifact']['sha256'], 'distinct source artifacts share identity')
            model = tested['backend_details']['model']
            require(model['source_artifact_sha'] == source['artifact']['sha256'], 'wrong reference source artifact')
            require(model['source_evidence_sha256'] == hashlib.sha256((ROOT / source_path).read_bytes()).hexdigest(),
                    'reference evidence does not match the real source proof')
            require(model['module']['kind'] == 'module' and model['module']['sha256'] == hashlib.sha256((ROOT / 'build/js/ledger.cjs').read_bytes()).hexdigest(),
                    'generated module identity is not bound to current bytes')
            require(not source['end_to_end'] and not tested['end_to_end'] and not model['source_to_module_proved'],
                    'unsupported binary/deployment/compiler proof claim')
            critical, rejected_path = gate('critical-tier', tier='critical')
            require(critical.returncode == 1 and 'METHOD_POLICY' in critical.stderr,
                    'source-proof tier accepted model-comparison testing')
            require(not rejected_path.exists(), 'critical-tier rejection emitted evidence')
            report['source_artifact_sha256'] = source['artifact']['sha256']
            report['typescript_artifact_sha256'] = tested['artifact']['sha256']
            report['model_module_sha256'] = model['module']['sha256']

        elif case == 'reproducibility':
            first, one = gate('first')
            require(first.returncode == 0, 'first TypeScript gate failed')
            module = (ROOT / 'build/js/ledger.cjs').read_bytes()
            second, two = gate('second')
            require(second.returncode == 0, 'second TypeScript gate failed')
            require(module == (ROOT / 'build/js/ledger.cjs').read_bytes(), 'generated JS module differs across builds')
            compared = invoke('byte-comparison', ['cmp', one.relative_to(ROOT).as_posix(), two.relative_to(ROOT).as_posix()])
            require(compared.returncode == 0, 'TypeScript evidence is not byte-identical')
            report['evidence_sha256'] = hashlib.sha256(one.read_bytes()).hexdigest()
            report['model_module_sha256'] = hashlib.sha256(module).hexdigest()

        elif case == 'loader-demo':
            demo = invoke('loader-demo', ['node', '--import', 'tsx', 'app/main.ts'])
            require(demo.returncode == 0 and demo.stdout == 'Ok\nRejected\n' and not demo.stderr,
                    'loader demo did not print exactly Ok then Rejected')
            report['required_npx_exit_established'] = False

        elif case == 'cli-demo':
            demo = invoke('required-npx-demo', ['npx', 'tsx', 'app/main.ts'])
            if demo.returncode:
                print(demo.stdout + demo.stderr, file=sys.stderr, end='')
            require(demo.returncode == 0 and demo.stdout == 'Ok\nRejected\n' and not demo.stderr,
                    'required npx demo did not print exactly Ok then Rejected')
            report['required_npx_exit_established'] = True

        report['result'] = 'passed'
        print(case + ': passed (actual checker and gate codes retained)')
        return 0
    except (AssertionError, OSError, ValueError, KeyError) as error:
        report['result'] = 'failed'
        report['error'] = str(error)
        print(case + ': ' + str(error), file=sys.stderr)
        return 1
    finally:
        (destination / 'report.json').write_text(json.dumps(report, sort_keys=True, indent=2) + '\n')


if __name__ == '__main__':
    sys.exit(main())
