#!/usr/bin/env python3
"""Run actual schema, policy, identity, and replay checks; preserve raw exits."""

import argparse
import copy
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent.parent
CASES = ('schema', 'artifact-mismatch', 'method-policy', 'round-trip', 'policy-controls')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', required=True, choices=CASES)
    case = parser.parse_args().case
    destination = ROOT / 'build/stage2' / case
    if (destination / 'report.json').exists():
        history = ROOT / 'build/stage2-history' / case
        history.mkdir(parents=True, exist_ok=True)
        attempt = 1
        while (history / str(attempt)).exists():
            attempt += 1
        shutil.copytree(destination, history / str(attempt))
    destination.mkdir(parents=True, exist_ok=True)
    records = []
    report = {'case': case, 'commands': records, 'result': 'incomplete'}

    def invoke(name, arguments):
        command = [sys.executable, 'gate/gate.py', *arguments]
        completed = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
        log = destination / (name + '.log')
        log.write_text(completed.stdout + completed.stderr)
        records.append({'name': name, 'command': command, 'exit_code': completed.returncode,
                        'log': log.relative_to(ROOT).as_posix()})
        return completed

    def require(condition, message):
        if not condition:
            raise AssertionError(message)

    def negative(name, edit, expected):
        candidate = copy.deepcopy(baseline)
        edit(candidate)
        path = destination / (name + '.input.json')
        path.write_text(json.dumps(candidate, sort_keys=True) + '\n')
        output = destination / (name + '.output.json')
        # A rejection must also clear stale success, not just return nonzero.
        output.write_bytes(baseline_bytes)
        result = invoke(name, ['--check-evidence', path.relative_to(ROOT).as_posix(),
                               '--evidence', output.relative_to(ROOT).as_posix()])
        require(result.returncode == 1 and expected in result.stderr,
                name + ': expected rejection ' + expected + '; got exit ' + str(result.returncode))
        require(not output.exists(), name + ': stale accepted output survived rejection')
        return result

    try:
        baseline_bytes = (ROOT / 'evidence.json').read_bytes()
        baseline = json.loads(baseline_bytes)
        report['evidence_sha256'] = hashlib.sha256(baseline_bytes).hexdigest()
        if case == 'schema':
            archive = ROOT / 'results/stage1/evidence.json'
            original = json.loads((ROOT / 'results/stage1.json').read_text())
            require(hashlib.sha256(archive.read_bytes()).hexdigest() == original['evidence_sha256'],
                    'Stage 1 evidence differs from its completed run record')
            for name, path in [('stage1-schema', 'results/stage1/evidence.json'),
                               ('stage2-schema', 'evidence.json')]:
                result = invoke(name, ['--schema-only', path])
                require(result.returncode == 0 and 'SCHEMA_VALID' in result.stdout,
                        name + ': real schema validator failed')
            negative('unknown-method', lambda e: e['evidence'][0].update(method='proved'),
                     'SCHEMA_REJECTED')
            negative('extra-timestamp', lambda e: e.update(timestamp='not-part-of-canonical-evidence'),
                     'SCHEMA_REJECTED')

        elif case == 'artifact-mismatch':
            negative('record-digest', lambda e: e['evidence'][0].update(artifact_sha='0' * 64),
                     'ARTIFACT_MISMATCH')

            def forged_artifact(e):
                e['artifact']['sha256'] = '0' * 64
                for record in e['evidence']:
                    record['artifact_sha'] = '0' * 64
            negative('coherent-forged-digest', forged_artifact, 'ARTIFACT_MISMATCH')
            negative('manifest-digest', lambda e: e['source_manifest'][0].update(sha256='0' * 64),
                     'ARTIFACT_MISMATCH')

        elif case == 'method-policy':
            # These are explicitly hand-edited rejection fixtures, not records
            # asserting that a different proof or test has actually run.
            for method in ('unit_tested', 'bounded_model_checked', 'kernel_checked_proof'):
                def change_method(e, value=method):
                    for record in e['evidence']:
                        record['method'] = value
                negative(method, change_method, 'METHOD_POLICY')

        elif case == 'round-trip':
            output = destination / 'replayed.json'
            result = invoke('fresh-checker-replay', ['--check-evidence', 'evidence.json',
                            '--evidence', output.relative_to(ROOT).as_posix()])
            require(result.returncode == 0 and 'ACCEPTED' in result.stdout,
                    'valid evidence did not reproduce through the actual backend')
            command = ['cmp', 'evidence.json', output.relative_to(ROOT).as_posix()]
            compared = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
            (destination / 'byte-comparison.log').write_text(compared.stdout + compared.stderr)
            records.append({'name': 'byte-comparison', 'command': command,
                            'exit_code': compared.returncode,
                            'log': (destination / 'byte-comparison.log').relative_to(ROOT).as_posix()})
            require(compared.returncode == 0, 'replayed evidence differs byte for byte')

        elif case == 'policy-controls':
            negative('policy-version', lambda e: e['policy'].update(version='unapproved'), 'POLICY_BINDING')
            negative('policy-tier', lambda e: e['policy'].update(tier='standard'), 'POLICY_BINDING')
            negative('policy-digest', lambda e: e['policy'].update(sha256='0' * 64), 'POLICY_BINDING')
            negative('trusted-input', lambda e: e['trusted_input_sha256'].update({'gate/core.py': '0' * 64}),
                     'TRUSTED_INPUTS')
            negative('claim-spec', lambda e: e['claims'][0].update(spec_sha='0' * 64), 'CLAIM_BINDING')
            negative('claim-statement', lambda e: e['claims'][0].update(statement_plain_english='Weakened claim'),
                     'CLAIM_BINDING')
            negative('missing-claim', lambda e: e['claims'].pop(), 'CLAIM_BINDING')
            negative('unknown-claim', lambda e: e['evidence'][0].update(claim_id='C999'), 'CLAIM_BINDING')
            negative('missing-result', lambda e: e['evidence'].pop(), 'MISSING_EVIDENCE')
            negative('unknown-result', lambda e: e['evidence'][0].update(result='unknown'), 'MISSING_EVIDENCE')
            negative('end-to-end', lambda e: e.update(end_to_end=True), 'COVERAGE_SCOPE')
            negative('backend', lambda e: e.update(backend='not-selected'), 'BACKEND_BINDING')
            negative('invented-producer', lambda e: e['evidence'][0].update(producer='forged-producer'),
                     'REPRODUCTION_MISMATCH')
            unknown = invoke('unknown-tier', ['--tier', 'missing', '--evidence',
                                             (destination / 'unknown-tier.json').relative_to(ROOT).as_posix()])
            require(unknown.returncode == 1 and 'POLICY_TIER' in unknown.stderr,
                    'unknown tier was not rejected')
            path = destination / 'duplicate-key.json'
            path.write_text('{"end_to_end":true,' + baseline_bytes.decode().lstrip()[1:])
            result = invoke('duplicate-json-key', ['--check-evidence', path.relative_to(ROOT).as_posix(),
                             '--evidence', (destination / 'duplicate-result.json').relative_to(ROOT).as_posix()])
            require(result.returncode == 1 and 'DOCUMENT_FORMAT' in result.stderr,
                    'duplicate JSON key was not rejected')

        require((ROOT / 'evidence.json').read_bytes() == baseline_bytes,
                'a scenario altered the accepted evidence input')
        report['result'] = 'passed'
        print(case + ': passed (actual commands and negative exits retained)')
        return 0
    except (AssertionError, OSError, ValueError) as error:
        report['result'] = 'failed'
        report['error'] = str(error)
        print(case + ': ' + str(error), file=sys.stderr)
        return 1
    finally:
        (destination / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')


if __name__ == '__main__':
    sys.exit(main())
