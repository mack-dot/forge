#!/usr/bin/env python3
"""Run real Stage 9 controls. Never treat setup errors as security rejections."""
import argparse
import base64
import copy
from pathlib import Path
import shutil
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate/provenance'))
from common import (Rejected, Records, canonical, context, digest, parse, read,
                    require, signature, write)
from release import expected_canonical


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=['valid-bundle', 'unsigned', 'wrong-signer',
                                          'wrong-digest', 'wrong-policy', 'deployed-identity'], required=True)
    args = parser.parse_args()
    parent = ROOT / 'results/stage9' / args.case
    parent.mkdir(parents=True, exist_ok=True)
    number = 1
    while (parent / f'attempt-{number:04d}').exists():
        number += 1
    require(number <= 5, 'FIVE_ATTEMPTS_RETAINED_STOP_FOR_DIAGNOSIS')
    attempt = parent / f'attempt-{number:04d}'
    attempt.mkdir()
    outer = Records(attempt / 'harness')
    outcomes = []
    try:
        config = read(ROOT / '.toolchain/stage9/controller.json')
        policy, lock, _ = context(config['implementation_sha256'])
        candidate = Path(config['candidate']).resolve()
        controller = Path(config['controller']).resolve()
        request = read(Path(config['request']).resolve())
        require(not controller.is_relative_to(candidate), 'CONTROLLER_LOCATION')
        require(request['challenge'] == config['challenge'], 'CONTROLLER_CHALLENGE')
        require(request['implementation_lock_sha256'] == config['implementation_sha256'], 'CONTROLLER_LOCK')

        def gate(path, name, expected_code, reason=None, *, observer=None, admit=False):
            result_dir = attempt / name
            script = 'observe.py' if observer else 'release.py'
            command = ['python3', str(ROOT / 'gate/provenance' / script), '--candidate', str(path),
                       '--controller', str(controller), '--challenge', config['challenge'],
                       '--implementation-sha256', config['implementation_sha256'], '--records', str(result_dir)]
            if observer:
                command += ['--case', observer]
            if admit:
                command += ['--admit']
            code, _, _ = outer.run(command, name, check=False)
            require(code == expected_code, 'UNEXPECTED_GATE_EXIT:' + name)
            result = read(result_dir / 'result.json')
            if reason:
                require(result['result'] == 'rejected' and result['reason'] == reason,
                        'WRONG_REJECTION_REASON:' + name)
            commands_path = result_dir / ('signature/commands.json' if observer else 'commands.json')
            commands = read(commands_path) if commands_path.exists() else []
            checks = [c for c in commands if 'verify-blob-attestation' in c['argv']]
            outcomes.append({'name': name, 'gate_exit_code': code, 'reason': result.get('reason'),
                             'actual_signature_exit_codes': [c['exit_code'] for c in checks],
                             'signature_execution': 'executed' if checks else 'not_run',
                             'end_to_end': False})
            return result_dir, checks

        def require_signature_success(checks):
            require(len(checks) == 1 and checks[0]['exit_code'] == 0, 'SIGNATURE_WAS_NOT_SUCCESSFUL')

        def fixture(name):
            path = attempt / ('candidate-' + name)
            shutil.copytree(candidate, path)
            return path

        def signed_control(name, reason):
            path = fixture(name)
            control = path / 'controls' / name
            shutil.copyfile(control / 'evidence.json', path / 'evidence.json')
            shutil.copyfile(control / 'control.sigstore.json', path / 'release.sigstore.json')
            _, checks = gate(path, name, 1, reason)
            require_signature_success(checks)

        if args.case == 'valid-bundle':
            for name in ['verified-first', 'verified-second']:
                _, checks = gate(candidate, name, 0)
                require_signature_success(checks)
            first = canonical(expected_canonical(policy, lock, config['implementation_sha256'], request['package']))
            second = canonical(expected_canonical(policy, lock, config['implementation_sha256'], request['package']))
            require(first == second == (candidate / 'evidence.json').read_bytes(), 'CANONICAL_REPRODUCTION_FAILED')
            (attempt / 'canonical-evidence.json').write_bytes(first)
            altered = fixture('altered-evidence')
            value = read(altered / 'evidence.json')
            value['end_to_end'] = True
            write(altered / 'evidence.json', value)
            _, checks = gate(altered, 'altered-evidence', 1, 'EVIDENCE_DIGEST')
            require_signature_success(checks)
            fabricated = fixture('fabricated-receipt')
            receipt = read(fabricated / 'proof/receipt.json')
            receipt['agent_reported_success'] = True
            write(fabricated / 'proof/receipt.json', receipt)
            _, checks = gate(fabricated, 'fabricated-receipt', 1, 'PROOF_RECEIPT_BINDING')
            require_signature_success(checks)
            signed_control('wrong-method', 'CLAIM_METHOD_BINDING')
        elif args.case in ['unsigned', 'wrong-signer', 'wrong-digest']:
            # A functioning positive check is required in this very attempt.
            _, checks = gate(candidate, 'positive-prerequisite', 0)
            require_signature_success(checks)
            path = fixture(args.case)
            if args.case == 'unsigned':
                bundle = read(path / 'release.sigstore.json')
                bundle['dsseEnvelope']['signatures'] = []
                unsigned = parse(base64.b64decode(bundle['dsseEnvelope']['payload'], validate=True))
                unsigned['predicate']['purpose'] = 'security-control'
                bundle['dsseEnvelope']['payload'] = base64.b64encode(canonical(unsigned)).decode()
                write(path / 'release.sigstore.json', bundle)
                markers = ['exactly one signature is required']
            elif args.case == 'wrong-signer':
                shutil.copyfile(path / 'wrong-signer.sigstore.json', path / 'release.sigstore.json')
                probe = Records(attempt / 'wrong-signer-own-identity')
                identity = policy['signer']['identity'].replace('provenance.yml', 'provenance-negative.yml')
                code, _, _ = signature(policy, path / 'release.sigstore.json',
                                        ROOT / policy['release_artifact']['path'], request['expected_source_commit'],
                                        probe, negative_identity=identity)
                require(code == 0, 'WRONG_SIGNER_FIXTURE_NOT_AUTHENTIC')
                markers = ['expected SAN value "' + policy['signer']['identity'] + '", got "' + identity + '"']
            else:
                control = path / 'controls/wrong-digest'
                shutil.copyfile(control / 'control.sigstore.json', path / 'release.sigstore.json')
                probe = Records(attempt / 'wrong-digest-own-artifact')
                code, _, _ = signature(policy, path / 'release.sigstore.json', control / 'different.bin',
                                        request['expected_source_commit'], probe)
                require(code == 0, 'WRONG_DIGEST_FIXTURE_NOT_AUTHENTIC')
                markers = ['provided artifact digests do not match digests in statement',
                           'provided artifact digests does not match digests in statement',
                           'provided artifact digest does not match any digest in statement']
            result_dir, checks = gate(path, 'negative', 1, 'SIGNATURE_REJECTED')
            require(len(checks) == 1 and checks[0]['exit_code'] != 0, 'CHECKER_REJECTION_NOT_EXECUTED')
            raw = (result_dir / checks[0]['stderr']).read_text() + (result_dir / checks[0]['stdout']).read_text()
            require(any(marker in raw for marker in markers), 'NOT_THE_INTENDED_SECURITY_REJECTION')
        elif args.case == 'wrong-policy':
            signed_control('wrong-policy', 'POLICY_BINDING')
            signed_control('stale-request', 'STALE_OR_SUBSTITUTED_REQUEST')
            signed_control('wrong-spec', 'EVIDENCE_BINDING')
            signed_control('wrong-method', 'CLAIM_METHOD_BINDING')
        else:
            _, checks = gate(candidate, 'accepted-deployment', 0, observer='accepted')
            require_signature_success(checks)
            _, checks = gate(candidate, 'substitution', 1, 'DEPLOYED_ARTIFACT_MISMATCH', observer='substitution')
            require_signature_success(checks)
            gate(candidate, 'duplicate-admission', 1, 'STALE_OR_CONSUMED_REQUEST', admit=True)
        write(attempt / 'result.json', {'case': args.case, 'result': 'passed', 'harness_exit_code': 0,
                                      'controls': outcomes, 'end_to_end': False})
        print('STAGE9_' + args.case.upper().replace('-', '_') + '_PASSED')
        return 0
    except Exception as error:
        write(attempt / 'result.json', {'case': args.case, 'result': 'not_established', 'harness_exit_code': 1,
                                      'reason': str(error), 'controls': outcomes, 'end_to_end': False})
        print('STAGE9_NOT_ESTABLISHED: ' + str(error))
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
