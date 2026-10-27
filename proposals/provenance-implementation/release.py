"""Independent provenance admission: Cosign authenticates; policy binds bytes."""
import argparse
import base64
from pathlib import Path
import sqlite3

from common import (ROOT, Rejected, Records, canonical, context, digest, files,
                    parse, read, repository_identity, require, sha, signature, write)


def statement_from_verified_bundle(bundle):
    # Only decode the standard DSSE payload AFTER real Cosign succeeds.
    # No signature bytes, certificate semantics or cryptography are implemented.
    envelope = read(bundle)['dsseEnvelope']
    require(envelope['payloadType'] == 'application/vnd.in-toto+json', 'PAYLOAD_TYPE')
    return parse(base64.b64decode(envelope['payload'], validate=True))


def expected_canonical(policy, lock, implementation_sha, package):
    evidence = read(ROOT / policy['proof']['accepted_evidence']['path'])
    return {'format_version': 1, 'end_to_end': False,
            'artifact': policy['release_artifact'], 'package': package,
            'policy': {'id': policy['id'], 'version': policy['version'], 'epoch': policy['epoch'],
                       'sha256': digest(ROOT / 'policy/provenance.json')},
            'contract_sha256': digest(ROOT / policy['contract']),
            'spec_lock_sha256': digest(ROOT / policy['lock']),
            'implementation_lock_sha256': implementation_sha,
            'claims': evidence['claims'], 'evidence': evidence['evidence'],
            'accepted_evidence': policy['proof']['accepted_evidence'],
            'assumption_audit': policy['proof']['assumption_audit'],
            'source_and_dependency_inputs': lock['locked_existing_files'],
            'supplementary_stage8': policy['supplementary_stage8'],
            'model_quality': 'unmeasured', 'deployment_correctness_proved': False}


def validate_receipt(receipt_dir, policy, lock, request):
    manifest = read(receipt_dir / 'receipt.json')
    require(manifest['challenge'] == request['challenge']
            and manifest['source_commit'] == request['expected_source_commit'], 'STALE_PROOF_RECEIPT')
    for path, h in manifest['files'].items():
        require(not Path(path).is_absolute() and '..' not in Path(path).parts, 'RECEIPT_PATH')
        require(digest(receipt_dir / path) == h, 'PROOF_RECEIPT_BYTES')
    require(files(receipt_dir) == {**manifest['files'], 'receipt.json': digest(receipt_dir / 'receipt.json')},
            'PROOF_RECEIPT_FILE_SET')
    report = read(receipt_dir / 'linux/report.json')
    require(report['result'] == 'passed' and report['independent_rocqchk'] is True
            and report['end_to_end'] is False, 'PROOF_NOT_ESTABLISHED')
    require(report['artifact_sha'] == policy['release_artifact']['sha256'], 'PROOF_ARTIFACT')
    for field in ['theorem_assumptions', 'witness_assumptions', 'independent_closure_assumptions', 'checked_modules']:
        require(report[field] == lock[field], 'PROOF_AUDIT:' + field)
    require(report['rocqchk_commands'][0]['exit_code'] == 0
            and len(report['rocqchk_commands']) == 1, 'INDEPENDENT_KERNEL_EXIT')
    require(report['rocqchk_commands'][0]['command'][:4] == ['rocqchk', '-o', '-bytecode-compiler', 'no'],
            'INDEPENDENT_KERNEL_FLAGS')
    require(report['valid_execution_witness'] == 'Forge.Binary.Witness.selftest_has_valid_execution_holds'
            and report['theorem'] == 'Forge.Binary.Statements.selftest_halts', 'THEOREM_BINDING')
    compile_names = {Path(c['command'][-1]).name for c in report['commands']
                     if c['command'][:2] == ['rocq', 'compile'] and c['exit_code'] == 0}
    require({'Images.v', 'Statements.v', 'Execution.v', 'Proof.v', 'WitnessSpec.v', 'Witness.v',
             'Wrapper.v', 'WitnessWrapper.v'} <= compile_names, 'FRESH_COMPILATION_MISSING')
    require(all(c['exit_code'] == 0 for c in report['commands']), 'PROOF_COMMAND_FAILED')
    kernel = receipt_dir / 'linux/independent-kernel.log'
    require(digest(kernel) == report['independent_kernel_log_sha256'], 'KERNEL_LOG_IDENTITY')
    before = read(receipt_dir / 'linux/before/identity.json')
    after = read(receipt_dir / 'linux/after/identity.json')
    require(before['tracked_sha256_manifest'] == after['tracked_sha256_manifest']
            == lock['upstream_input_identities']['upstream/tracked-sha256-manifest'], 'UPSTREAM_IDENTITY')
    closure = read(receipt_dir / 'closure-identities.json')
    require(len(closure) == len(lock['checked_modules']) and all(len(v) == 64 for v in closure.values()),
            'CHECKED_CLOSURE_IDENTITIES')
    return digest(receipt_dir / 'receipt.json')


def verify(root, request, expected_lock, records, *, signed='release.sigstore.json'):
    policy, lock, implementation = context(expected_lock)
    require(request['implementation_lock_sha256'] == expected_lock, 'REQUEST_IMPLEMENTATION')
    require(request['policy_id'] == policy['id'] and request['policy_version'] == policy['version']
            and request['policy_epoch'] == policy['epoch']
            and request['policy_sha256'] == digest(ROOT / 'policy/provenance.json'), 'STALE_POLICY_REQUEST')
    require(request['artifact_sha256'] == policy['release_artifact']['sha256']
            and request['package_sha256'] == request['package']['sha256'], 'REQUEST_ARTIFACT_BINDING')
    bundle = root / signed
    blob = ROOT / policy['release_artifact']['path']
    before = files(root)
    code, _, _ = signature(policy, bundle, blob, request['expected_source_commit'], records)
    require(code == 0, 'SIGNATURE_REJECTED')
    statement = statement_from_verified_bundle(bundle)
    require(set(statement) == {'_type', 'predicateType', 'subject', 'predicate'}, 'STATEMENT_FIELDS')
    require(statement['_type'] == policy['signature']['statement_type']
            and statement['predicateType'] == policy['signature']['predicate_type'], 'STATEMENT_TYPE')
    predicate = statement['predicate']
    require(set(predicate) == {'purpose', 'request', 'canonical_evidence_sha256', 'proof_receipt_sha256'},
            'PREDICATE_FIELDS')
    expected_subjects = [
        {'name': 'forge:gcd-selftest.elf', 'digest': {'sha256': policy['release_artifact']['sha256']}},
        {'name': 'forge:docker-image-config', 'digest': {'sha256': request['package_sha256']}}]
    require(statement['subject'] == expected_subjects, 'ARTIFACT_BINDING')
    canonical_file = root / 'evidence.json'
    evidence = read(canonical_file)
    require(canonical_file.read_bytes() == canonical(evidence), 'NONCANONICAL_EVIDENCE')
    require(predicate['canonical_evidence_sha256'] == digest(canonical_file), 'EVIDENCE_DIGEST')
    expected = expected_canonical(policy, lock, expected_lock, request['package'])
    require(canonical(evidence['policy']) == canonical(expected['policy']), 'POLICY_BINDING')
    require(canonical(evidence['claims']) == canonical(expected['claims'])
            and canonical(evidence['evidence']) == canonical(expected['evidence']), 'CLAIM_METHOD_BINDING')
    require(canonical(evidence) == canonical(expected), 'EVIDENCE_BINDING')
    require(canonical(predicate['request']) == canonical(request), 'STALE_OR_SUBSTITUTED_REQUEST')
    require(predicate['proof_receipt_sha256'] == validate_receipt(root / 'proof', policy, lock, request),
            'PROOF_RECEIPT_BINDING')
    require(predicate['purpose'] == 'release', 'SECURITY_CONTROL_NOT_ADMISSIBLE')
    repository_identity(policy, implementation, request['expected_source_commit'], records)
    require(files(root) == before, 'CANDIDATE_CHANGED_DURING_VERIFICATION')
    context(expected_lock)
    return {'signature_exit_code': code, 'result': 'authenticated_provenance',
            'kernel_execution_here': False, 'producer_fresh_kernel_receipt_verified': True,
            'end_to_end': False, 'statement_sha256': sha(canonical(statement))}


def pending(connection, challenge):
    row = connection.execute('SELECT request,state FROM requests WHERE challenge=?', (challenge,)).fetchone()
    require(row is not None and row[1] == 'pending', 'STALE_OR_CONSUMED_REQUEST')
    return parse(row[0])


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--candidate', type=Path, required=True)
    p.add_argument('--controller', type=Path, required=True)
    p.add_argument('--challenge', required=True)
    p.add_argument('--implementation-sha256', required=True)
    p.add_argument('--records', type=Path, required=True)
    p.add_argument('--admit', action='store_true')
    args = p.parse_args()
    records = Records(args.records)
    try:
        # The controller path is supplied by the operator, outside candidate data.
        require(not args.controller.resolve().is_relative_to(args.candidate.resolve()),
                'CONTROLLER_LOCATION')
        connection = sqlite3.connect('file:' + str(args.controller.resolve()) + '?mode=rw', uri=True)
        try:
            connection.execute('BEGIN IMMEDIATE')
            request = pending(connection, args.challenge)
            result = verify(args.candidate, request, args.implementation_sha256, records)
            if args.admit:
                cursor = connection.execute("UPDATE requests SET state='consumed' WHERE challenge=? AND state='pending'",
                                            (args.challenge,))
                require(cursor.rowcount == 1, 'ATOMIC_ADMISSION')
                connection.commit()
            else:
                connection.rollback()
            write(args.records / 'result.json', {**result, 'admitted': args.admit})
        finally:
            connection.close()
        return 0
    except (Rejected, OSError, ValueError, KeyError, sqlite3.Error) as error:
        write(args.records / 'result.json', {'result': 'rejected', 'reason': str(error),
                                           'end_to_end': False, 'admitted': False})
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
