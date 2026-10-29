#!/usr/bin/env python3
"""Adversarial receipt-parser audit only; NEVER a proof or signing result.

Use real historical Stage 7 logs as untrusted inputs, with deliberately false
dependency hashes and a different request nonce. The expected result is rejection.
No checker is mocked, no signature is made and no kernel is executed.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'gate/provenance'))
from common import Rejected, context, digest, files, read, write
from release import validate_receipt


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    args.work.mkdir(parents=True, exist_ok=False)
    policy, lock, _ = context('6b43c19370742b02eb05c66b9a9091a6c47431998ef045a09018fa6671459daa')
    historical = ROOT / 'results/stage7/own-proof/attempt-0001/linux'
    names = ['report.json', 'independent-kernel.log', 'before/identity.json',
             'after/identity.json', 'gcd-selftest.elf']
    inputs = {str((historical / name).relative_to(ROOT)): digest(historical / name) for name in names}
    paths = re.findall(r'^\[intern (.+\.vo) \.\.\.$', (historical / 'independent-kernel.log').read_text(), re.M)
    assert len(set(paths)) == len(lock['checked_modules']) == 579
    request = {'challenge': 'a' * 64, 'expected_source_commit': '06b40caa6bf5fb6963756b39646413559f84c61d'}
    outcomes = []
    for name in ['invalid-dependency-hashes', 'substituted-checked-elf',
                 'missing-checked-elf', 'nonce-mismatch', 'unmanifested-mutation']:
        fixture = args.work / name
        fixture.mkdir()
        for original in names:
            target = fixture / 'linux' / original
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(historical / original, target)
        # Deliberately NOT hashes. They must never become accepted proof evidence.
        write(fixture / 'closure-identities.json', {path: '!' * 64 for path in paths})
        write(fixture / 'fixture-notice.json', {'security_control': True, 'accepted_evidence': False,
                                              'origin': 'historical Stage 7 logs; no fresh execution'})
        if name == 'substituted-checked-elf':
            (fixture / 'linux/gcd-selftest.elf').write_bytes(b'Wrong ELF: receipt audit security control\n')
        elif name == 'missing-checked-elf':
            (fixture / 'linux/gcd-selftest.elf').unlink()
        manifest = {'challenge': request['challenge'], 'source_commit': request['expected_source_commit'],
                    'files': files(fixture), 'end_to_end': False}
        if name == 'nonce-mismatch':
            manifest['challenge'] = 'b' * 64
        write(fixture / 'receipt.json', manifest)
        if name == 'unmanifested-mutation':
            with (fixture / 'linux/gcd-selftest.elf').open('ab') as f:
                f.write(b'changed after manifest')
        record = {'case': name, 'expected': 'reject', 'fixture_receipt_sha256': digest(fixture / 'receipt.json'),
                  'fixture_file_sha256': files(fixture), 'expected_elf_sha256': policy['release_artifact']['sha256'],
                  'observed_elf_sha256': digest(fixture / 'linux/gcd-selftest.elf')
                    if (fixture / 'linux/gcd-selftest.elf').exists() else None}
        try:
            returned = validate_receipt(fixture, policy, lock, request)
            record.update(observed='returned_without_rejection', returned_receipt_sha256=returned)
        except Rejected as error:
            record.update(observed='rejected', reason=str(error))
        outcomes.append(record)
        # Preserve exact generated manifests and mutations; shared raw logs are
        # retained at their original input paths and bound by inputs.json below.
        copy_to = args.output / name
        copy_to.mkdir()
        for generated in ['receipt.json', 'closure-identities.json', 'fixture-notice.json']:
            shutil.copyfile(fixture / generated, copy_to / generated)
        if name == 'substituted-checked-elf':
            shutil.copyfile(fixture / 'linux/gcd-selftest.elf', copy_to / 'substituted.elf')
        write(copy_to / 'observation.json', record)
        print(json.dumps({'case': name, 'observed': record['observed'], 'reason': record.get('reason')}), flush=True)
    assert inputs == {p: digest(ROOT / p) for p in inputs}, 'Historical evidence changed'
    write(args.output / 'inputs.json', {'historical_input_sha256': inputs, 'request_fixture': request,
                                      'implementation_lock_sha256': digest(ROOT / 'gate/provenance/implementation.lock'),
                                      'reproduce_cmd': 'python3 scripts/audit_stage9_receipts.py --output NEW_OUTPUT --work NEW_WORK'})
    unexpected = [o['case'] for o in outcomes if o['observed'] != 'rejected']
    report = {'scope': 'receipt_json_validator_only', 'accepted_proof_evidence': False,
              'signature_execution': 'not_run', 'kernel_execution': 'not_run', 'workflow_execution': 'not_run',
              'result': 'blocked' if unexpected else 'controls_rejected', 'unexpected_acceptances': unexpected,
              'outcomes': outcomes, 'exit_code': 1 if unexpected else 0, 'end_to_end': False}
    write(args.output / 'result.json', report)
    return report['exit_code']


if __name__ == '__main__':
    raise SystemExit(main())
