"""Independent provenance admission: Cosign authenticates; policy binds bytes."""
import argparse
import base64
import gzip
import io
from pathlib import Path, PurePosixPath
import re
import sqlite3
import tarfile

from common import (ROOT, HERE, Rejected, Records, approved_lineage, canonical, context, digest, files,
                    parse, read, repository_identity, require, run_identity, sha, signature, write)

# Bound by the separately approved implementation lock. Expected identities
# never come from the receipt, the package or their signature.
IDENTITIES = Path(__file__).with_name('artifact-identities.json')
HEX64 = re.compile('[0-9a-f]{64}')
BLOB = re.compile('blobs/sha256/[0-9a-f]{64}')
ELF_MAGIC = b'\x7fELF'
ZSTD_MAGIC = b'\x28\xb5\x2f\xfd'


def hex64(value):
    return isinstance(value, str) and HEX64.fullmatch(value) is not None


def fail_closed(check, reason, *args):
    try:
        return check(*args)
    except Rejected:
        raise
    except Exception as error:
        raise Rejected(reason + ':' + type(error).__name__) from error


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
    return fail_closed(checked_receipt, 'PROOF_RECEIPT_MALFORMED', receipt_dir, policy, lock, request)


def checked_receipt(receipt_dir, policy, lock, request):
    expected = read(IDENTITIES)['receipt']
    manifest = read(receipt_dir / 'receipt.json')
    require(set(manifest) == {'challenge', 'source_commit', 'execution', 'files', 'end_to_end'}
            and manifest['end_to_end'] is False and isinstance(manifest['files'], dict), 'PROOF_RECEIPT_FIELDS')
    # The run that made this receipt; verify() checks it with the GitHub API (V4).
    execution = manifest['execution']
    require(isinstance(execution, dict) and set(execution) == {'run_id', 'run_attempt'}
            and re.fullmatch('[1-9][0-9]{0,19}', execution['run_id']) and execution['run_attempt'] == '1',
            'PROOF_RECEIPT_EXECUTION')
    require(hex64(request['challenge']) and re.fullmatch('[0-9a-f]{40}', request['expected_source_commit']),
            'REQUEST_FORMAT')
    require(manifest['challenge'] == request['challenge']
            and manifest['source_commit'] == request['expected_source_commit'], 'STALE_PROOF_RECEIPT')
    present = manifest['files']
    for path, h in present.items():
        require(not Path(path).is_absolute() and '..' not in Path(path).parts, 'RECEIPT_PATH')
        require(hex64(h), 'RECEIPT_DIGEST_FORMAT')
        require((receipt_dir / path).is_file(), 'PROOF_RECEIPT_FILE_MISSING:' + path)
        require(digest(receipt_dir / path) == h, 'PROOF_RECEIPT_BYTES')
    require(files(receipt_dir) == {**present, 'receipt.json': digest(receipt_dir / 'receipt.json')},
            'PROOF_RECEIPT_FILE_SET')
    # Every listed digest now equals actual bytes. Bind those bytes to fixed identities.
    fixed = expected['fixed_artifacts']
    require(fixed['linux/gcd-selftest.elf'] == policy['release_artifact']['sha256']
            == digest(ROOT / policy['release_artifact']['path']), 'RECEIPT_REFERENCE_ELF')
    for path, h in sorted(fixed.items()):
        require(path in present, 'PROOF_REQUIRED_ARTIFACT_MISSING:' + path)
        require(present[path] == h, 'PROOF_ARTIFACT_BYTES:' + path)
    closure = read(receipt_dir / 'closure-identities.json')
    require(isinstance(closure, dict) and all(hex64(v) for v in closure.values()), 'DEPENDENCY_DIGEST_FORMAT')
    require(set(closure) == set(expected['closure_sha256']), 'DEPENDENCY_CLOSURE_MEMBERSHIP')
    require(closure == expected['closure_sha256'], 'DEPENDENCY_DIGEST_MISMATCH')
    copies = {'dependencies/' + name.lstrip('/'): h for name, h in expected['closure_sha256'].items()}
    for path, h in sorted(copies.items()):
        require(path in present, 'DEPENDENCY_BYTES_MISSING:' + path)
        require(present[path] == h, 'DEPENDENCY_BYTES:' + path)
    require({p for p in present if p.startswith('dependencies/')} == set(copies), 'DEPENDENCY_EXTRA_FILE')
    suffixes = tuple(expected['checked_artifact_suffixes'])
    for path in sorted(present):
        require(path in fixed or path in copies or not path.endswith(suffixes), 'PROOF_UNEXPECTED_ARTIFACT:' + path)
        with (receipt_dir / path).open('rb') as stream:
            magic = stream.read(len(ELF_MAGIC))
        require(magic != ELF_MAGIC or path == 'linux/gcd-selftest.elf', 'PROOF_UNEXPECTED_EXECUTABLE:' + path)
    report = read(receipt_dir / 'linux/report.json')
    require(report['result'] == 'passed' and report['independent_rocqchk'] is True
            and report['end_to_end'] is False, 'PROOF_NOT_ESTABLISHED')
    require(report['artifact_sha'] == policy['release_artifact']['sha256'], 'PROOF_ARTIFACT')
    for field in ['theorem_assumptions', 'witness_assumptions', 'independent_closure_assumptions', 'checked_modules']:
        require(report[field] == lock[field], 'PROOF_AUDIT:' + field)
    kernel_commands = report['rocqchk_commands']
    require(isinstance(kernel_commands, list) and len(kernel_commands) == 1
            and kernel_commands[0]['exit_code'] == 0, 'INDEPENDENT_KERNEL_EXIT')
    require(kernel_commands[0]['command'][:4] == ['rocqchk', '-o', '-bytecode-compiler', 'no'],
            'INDEPENDENT_KERNEL_FLAGS')
    require(kernel_commands[0]['command'] == expected['kernel_command'], 'KERNEL_COMMAND_BINDING')
    require(report['valid_execution_witness'] == 'Forge.Binary.Witness.selftest_has_valid_execution_holds'
            and report['theorem'] == 'Forge.Binary.Statements.selftest_halts', 'THEOREM_BINDING')
    compile_names = {Path(c['command'][-1]).name for c in report['commands']
                     if c['command'][:2] == ['rocq', 'compile'] and c['exit_code'] == 0}
    require({'Images.v', 'Statements.v', 'Execution.v', 'Proof.v', 'WitnessSpec.v', 'Witness.v',
             'Wrapper.v', 'WitnessWrapper.v'} <= compile_names, 'FRESH_COMPILATION_MISSING')
    require(all(c['exit_code'] == 0 for c in report['commands']), 'PROOF_COMMAND_FAILED')
    kernel = receipt_dir / 'linux/independent-kernel.log'
    require(kernel.is_file(), 'KERNEL_LOG_MISSING')
    require(digest(kernel) == report['independent_kernel_log_sha256'], 'KERNEL_LOG_IDENTITY')
    # Check the raw rocqchk output itself, not only the producer's summary of it.
    text = kernel.read_text()
    loaded = re.findall(r'^\[intern (.+\.vo) \.\.\.$', text, re.M)
    require(len(loaded) == len(set(loaded)) and set(loaded) == set(expected['closure_sha256']),
            'KERNEL_DEPENDENCY_MEMBERSHIP')
    require(re.findall(r'^Checking library: (.+)$', text, re.M) == lock['checked_modules'],
            'KERNEL_MODULE_MEMBERSHIP')
    axioms = re.search(r'^\* Axioms:\n((?:    .+\n)+)', text, re.M)
    require(axioms is not None and sorted(line.strip() for line in axioms.group(1).splitlines())
            == sorted(lock['independent_closure_assumptions']), 'KERNEL_ASSUMPTION_SUMMARY')
    lines = text.splitlines()
    require(all(lines.count(line) == 1 for line in expected['kernel_summary_lines']), 'KERNEL_SUMMARY')
    before = read(receipt_dir / 'linux/before/identity.json')
    after = read(receipt_dir / 'linux/after/identity.json')
    require(before['tracked_sha256_manifest'] == after['tracked_sha256_manifest']
            == lock['upstream_input_identities']['upstream/tracked-sha256-manifest'], 'UPSTREAM_IDENTITY')
    return digest(receipt_dir / 'receipt.json')


def validate_package(policy, request, root):
    return fail_closed(checked_package, 'PACKAGE_MALFORMED', policy, request, root)


def checked_package(policy, request, root):
    identity = read(IDENTITIES)['package']
    elf = (ROOT / policy['release_artifact']['path']).read_bytes()
    require(sha(elf) == policy['release_artifact']['sha256'] == request['artifact_sha256'], 'RELEASE_ELF_IDENTITY')
    packaged = root / 'packaged.elf'
    require(packaged.is_file() and not packaged.is_symlink(), 'PACKAGED_ELF_MISSING')
    require(packaged.read_bytes() == elf, 'PACKAGED_ELF_BYTES')
    package = request['package']
    require(read(root / 'package.json') == package, 'PACKAGE_DESCRIPTOR_BINDING')
    require(package['identity_kind'] == 'docker_image_config' and hex64(package['sha256'])
            and package['sha256'] == request['package_sha256'] and package['elf_sha256'] == sha(elf)
            and package['elf_path'] == policy['deployment']['path'] == '/' + identity['elf_path']
            and package['base'] == policy['deployment']['base_image']
            and package['base_platform_manifest'] == policy['deployment']['platform_manifest']
            and package['platform'] == policy['deployment']['platform']
            and package['recipe_sha256'] == digest(HERE / 'Dockerfile'), 'PACKAGE_DESCRIPTOR_FIELDS')
    image_identity(root / 'package-identity', package, identity, elf)


def image_identity(directory, package, identity, elf):
    """Rehash a Docker image config and its added layers; resolve the ELF path."""
    present = files(directory)
    manifest = read(directory / 'manifest.json')
    require(isinstance(manifest, list) and len(manifest) == 1, 'PACKAGE_MANIFEST')
    config_path, layers = manifest[0]['Config'], manifest[0]['Layers']
    base, diff_ids = identity['base_rootfs_diff_ids'], package['rootfs_diff_ids']
    require(config_path == 'blobs/sha256/' + package['sha256'], 'PACKAGE_CONFIG_IDENTITY')
    require(isinstance(layers, list) and isinstance(diff_ids, list) and len(layers) == len(diff_ids) > len(base)
            and all(isinstance(p, str) and BLOB.fullmatch(p) for p in layers), 'PACKAGE_LAYER_LIST')
    added = list(zip(layers[len(base):], diff_ids[len(base):]))
    require(set(present) == {'manifest.json', config_path, *[p for p, _ in added]}, 'PACKAGE_IDENTITY_FILE_SET')
    for path, h in present.items():
        require(path == 'manifest.json' or path == 'blobs/sha256/' + h, 'PACKAGE_BLOB_DIGEST:' + path)
    config = read(directory / config_path)
    require(config['rootfs'] == {'type': 'layers', 'diff_ids': diff_ids}, 'PACKAGE_ROOTFS_BINDING')
    require(diff_ids[:len(base)] == base, 'PACKAGE_BASE_LAYERS')
    require(config['os'] == 'linux' and config['architecture'] == 'amd64'
            and config['config']['User'] == identity['user']
            and config['config']['Entrypoint'] == identity['entrypoint'], 'PACKAGE_RUNTIME_CONFIG')
    state = 'absent'
    for path, diff_id in added:
        data = layer_bytes(directory / path, identity['maximum_added_layer_bytes'])
        require('sha256:' + sha(data) == diff_id, 'PACKAGE_LAYER_DIFF_ID:' + path)
        state = layer_effect(data, state, identity, elf)
    require(state == 'expected', 'PACKAGE_FILESYSTEM_ELF:' + state)


def layer_bytes(path, limit):
    with path.open('rb') as stream:
        magic = stream.read(len(ZSTD_MAGIC))
    require(magic != ZSTD_MAGIC, 'PACKAGE_LAYER_COMPRESSION')
    opener = gzip.open if magic[:2] == b'\x1f\x8b' else open
    with opener(path, 'rb') as stream:
        data = stream.read(limit + 1)
    require(len(data) <= limit, 'PACKAGE_LAYER_SIZE')
    return data


def layer_effect(data, state, identity, elf):
    # Conservative OCI whiteout handling for the one target path only. Any
    # ambiguity rejects; the started-container observation stays authoritative.
    target = PurePosixPath(identity['elf_path'])
    chain = [PurePosixPath(*target.parts[:i]) for i in range(1, len(target.parts) + 1)]
    hidden = {str(p.parent / ('.wh.' + p.name)) for p in chain} | {str(p.parent / '.wh..wh..opq') for p in chain}
    with tarfile.open(fileobj=io.BytesIO(data), mode='r:') as tar:
        members = tar.getmembers()
        names = [PurePosixPath(m.name) for m in members]
        require(all(not n.is_absolute() and '..' not in n.parts for n in names), 'PACKAGE_LAYER_ENTRY')
        entries = {str(n): m for n, m in zip(names, members)}
        require(len(entries) == len(members), 'PACKAGE_LAYER_DUPLICATE')
        if hidden & set(entries):
            state = 'ambiguous' if str(target) in entries else 'removed'
        if any(str(p) in entries and not entries[str(p)].isdir() for p in chain[:-1]):
            state = 'obscured'
        if str(target) in entries and state != 'ambiguous':
            member = entries[str(target)]
            ok = (member.isreg() and all(str(p) in entries and entries[str(p)].isdir() for p in chain[:-1])
                  and member.mode & 0o7777 == identity['elf_mode']
                  and member.uid == identity['elf_uid'] and member.gid == identity['elf_gid'])
            state = 'expected' if ok and tar.extractfile(member).read() == elf else 'substituted'
    return state


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
    require(predicate['proof_receipt_sha256'] == digest(root / 'proof/receipt.json'), 'PROOF_RECEIPT_BINDING')
    validate_receipt(root / 'proof', policy, lock, request)
    validate_package(policy, request, root)
    require(predicate['purpose'] == 'release', 'SECURITY_CONTROL_NOT_ADMISSIBLE')
    repository_identity(policy, implementation, request['expected_source_commit'], records)
    run_identity(policy, request, read(root / 'proof/receipt.json')['execution'], records)
    lineage = approved_lineage(policy, request['expected_source_commit'], records)
    require(files(root) == before, 'CANDIDATE_CHANGED_DURING_VERIFICATION')
    context(expected_lock)
    return {'signature_exit_code': code, 'result': 'authenticated_provenance',
            'kernel_execution_here': False, 'producer_receipt_labels_consistent': True,
            'proof_run_identity_checked_with_github_api': True,
            'freshness_trust_assumption': 'GitHub executed the locked workflow in the recorded run',
            'approved_lineage': lineage,
            'approval_trust_assumption': 'only the owner uses the owner account',
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
    except Exception as error:
        # Every verifier exception is a rejection; none can become admission.
        write(args.records / 'result.json', {'result': 'rejected', 'reason': str(error),
                                           'end_to_end': False, 'admitted': False})
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
