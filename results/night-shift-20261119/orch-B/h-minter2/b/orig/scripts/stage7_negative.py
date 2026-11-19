#!/usr/bin/env python3
"""Run a deliberately false proof against the pinned, checked statements.

Rocq decides whether the proof type-checks. This harness only checks that the
negative control reaches the intended type error, rather than a setup failure.
"""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--attempt', required=True)
    args = parser.parse_args()
    pins = json.loads(Path('/forge-pins.json').read_text())
    dest = Path('/work/.forge-stage7/invalid-proof') / args.attempt
    dest.mkdir(parents=True, exist_ok=False)
    report = {'case': 'invalid-proof', 'result': 'not_established',
              'end_to_end': False, 'commands': [], 'pins': pins,
              'uid': os.getuid(), 'gid': os.getgid()}

    def save():
        (dest / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')

    def run(command, label):
        log = dest / (label + '.log')
        with log.open('wb') as stream:
            result = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
        record = {'command': command, 'cwd': '/work', 'exit_code': result.returncode,
                  'output_sha256': hashlib.sha256(log.read_bytes()).hexdigest()}
        report['commands'].append(record)
        save()
        print(json.dumps(record), flush=True)
        return result.returncode

    assert (os.getuid(), os.getgid()) == (pins['container_uid'], pins['container_gid'])
    identity = ['python3', '/forge-scripts/stage7_identity.py', '--commit', pins['upstream_commit']]
    if run(identity + ['--output', str(dest / 'before')], 'identity-before') != 0:
        return 1
    before = json.loads((dest / 'before/identity.json').read_text())
    assert before['binary_sha256'] == pins['upstream_binary_sha256'], 'BINARY_DIGEST_MISMATCH'
    proof = dest / 'Proof.v'
    shutil.copyfile('/forge-fixtures/invalid-proof/Proof.v', proof)
    report['fixture_sha256'] = hashlib.sha256(proof.read_bytes()).hexdigest()
    loadpath = ['-Q', '/work/_build/default/theories', 'OssFuzzTheorems.Core',
                '-Q', '/work/_build/default/projects/zlib/checksum_fuzzer',
                'OssFuzzTheorems.zlib.checksum_fuzzer',
                '-Q', str(dest), 'ForgeNegative']
    if run(['rocq', '--version'], 'rocq-version') != 0:
        return 1
    assert 'version 9.2' in (dest / 'rocq-version.log').read_text()
    if run(['rocq', 'dep', '-sort'] + loadpath + [str(proof)], 'dependencies') != 0:
        return 1
    checker_code = run(['rocq', 'compile'] + loadpath + [str(proof)], 'invalid-proof')
    diagnostic = ' '.join((dest / 'invalid-proof.log').read_text().split())
    report['prepared_fixture_exit_code'] = checker_code
    report['prepared_rejection_reason'] = diagnostic
    save()
    expected = ('The term "I" has type "True"', 'while it is expected to have type', 'plain_halts')
    if checker_code != 1 or not all(part in diagnostic for part in expected):
        print('NEGATIVE_CONTROL_FAILED: missing intended proof type error', flush=True)
        print(diagnostic, flush=True)
        return 1
    assert not (dest / 'Proof.vo').exists(), 'INVALID_PROOF_PRODUCED_OBJECT'

    # A valid proof of True must also fail the exact published binding wrapper.
    # Import the template from the unchanged, identity-checked upstream source.
    sys.path.insert(0, '/work/tools')
    from oft.check import WRAPPER
    candidate = dest / 'TrueCertificate.v'
    shutil.copyfile('/forge-fixtures/invalid-proof/TrueCertificate.v', candidate)
    report['true_certificate_sha256'] = hashlib.sha256(candidate.read_bytes()).hexdigest()
    candidate_code = run(['rocq', 'compile'] + loadpath + [str(candidate)], 'true-certificate')
    report['true_certificate_exit_code'] = candidate_code
    if candidate_code != 0:
        return 1
    wrapper = dest / 'Wrapper.v'
    wrapper.write_text(WRAPPER.format(
        stmt_mod='OssFuzzTheorems.zlib.checksum_fuzzer.Statements',
        proof_mod='ForgeNegative.TrueCertificate', neg='', stmt='plain_halts',
        args='', theorem='plain_halts_holds'))
    report['binding_wrapper_sha256'] = hashlib.sha256(wrapper.read_bytes()).hexdigest()
    report['upstream_wrapper_template_sha256'] = hashlib.sha256(WRAPPER.encode()).hexdigest()
    binding_code = run(['rocq', 'compile'] + loadpath + [str(wrapper)], 'binding-wrapper')
    binding_error = ' '.join((dest / 'binding-wrapper.log').read_text().split())
    report['checker_exit_code'] = binding_code
    report['binding_rejection_reason'] = binding_error
    save()
    expected_binding = ('plain_halts_holds', 'has type "True"',
                        'while it is expected to have type', 'plain_halts')
    if binding_code != 1 or not all(part in binding_error for part in expected_binding):
        print('NEGATIVE_CONTROL_FAILED: missing intended binding type error', flush=True)
        print(binding_error, flush=True)
        return 1
    assert not (dest / 'Wrapper.vo').exists(), 'INVALID_BINDING_PRODUCED_OBJECT'
    if run(identity + ['--output', str(dest / 'after')], 'identity-after') != 0:
        return 1
    after = json.loads((dest / 'after/identity.json').read_text())
    assert before['tracked_sha256_manifest'] == after['tracked_sha256_manifest'], 'SOURCE_CHANGED'
    assert before['binary_sha256'] == after['binary_sha256'], 'BINARY_CHANGED'
    report.update(result='passed', scenario_exit_code=0, independent_rocqchk=False,
                  artifact_sha=before['binary_sha256'],
                  scope='Negative control only; Rocq rejected both I : True and a compiled True certificate as proofs of plain_halts.')
    save()
    print('INVALID_PROOF_REJECTED_FOR_TYPE_ERROR; checker=1, scenario=0', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
