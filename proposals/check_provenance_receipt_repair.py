#!/usr/bin/env python3
"""Check an unapplied receipt repair against real historical bytes.

This is local identity validation, never fresh kernel or signature evidence.
"""
import argparse
import ast
import importlib.util
import json
from pathlib import Path
import shutil
import sys
import tarfile

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'gate/provenance'))
from common import Rejected, context, digest, files, read, write


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--reference-work', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--work', type=Path, required=True)
    a = p.parse_args()
    a.output.mkdir(parents=True, exist_ok=False)
    a.work.mkdir(parents=True, exist_ok=False)
    proposal = ROOT / 'proposals/provenance-receipt-repair'
    manifest = read(proposal / 'approval-manifest.json')
    policy, lock, _ = context(manifest['base_implementation_lock_sha256'])
    for change in manifest['changes']:
        candidate = ROOT / change['candidate']
        assert digest(candidate) == change['sha256']
        target = ROOT / change['target']
        if change['operation'] == 'add':
            assert not target.exists()
        else:
            assert digest(target) == change['before_sha256']
        if candidate.suffix == '.py':
            ast.parse(candidate.read_text())
            compile(candidate.read_text(), str(candidate), 'exec')
    assert digest(proposal / 'proposed.diff') == manifest['patch_sha256']
    expected = read(proposal / 'receipt-identities.json')
    assert len(expected['closure_sha256']) == len(expected['dependency_copies']) == 579
    assert len(expected['required_artifacts']) == 601
    for path, copy in expected['dependency_copies'].items():
        assert digest(a.reference_work / path.removeprefix('/')) == expected['closure_sha256'][path]
        assert expected['required_artifacts'][copy] == expected['closure_sha256'][path]
    index = read(ROOT / 'results/stage7/published/stage7-complete/records-index.json')
    archive = ROOT / index['archive']
    assert digest(archive) == index['archive_sha256']
    prefix = 'results/stage7/own-proof/attempt-0001/linux/'
    original = {e['path']:e for e in index['files'] if e['path'].startswith(prefix)}
    base = a.work / 'historical-complete-inputs'
    base.mkdir()
    with tarfile.open(archive, 'r:xz') as source:
        for path, entry in original.items():
            rel = Path(path.removeprefix(prefix))
            assert not rel.is_absolute() and '..' not in rel.parts
            target = base / 'linux' / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.extractfile(path).read())
            assert digest(target) == entry['sha256']
    for path, copy in expected['dependency_copies'].items():
        target = base / copy
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(a.reference_work / path.removeprefix('/'), target)
    write(base / 'closure-identities.json', expected['closure_sha256'])
    write(base / 'fixture-notice.json', {'scope':'historical_byte_validation_control',
          'fresh_kernel_execution':False,'release_authorized':False,'accepted_stage9_evidence':False})
    request = {'challenge':'a'*64,'expected_source_commit':manifest['base_commit']}
    module_spec = importlib.util.spec_from_file_location('unapproved_receipt_repair', proposal / 'release.py')
    candidate = importlib.util.module_from_spec(module_spec)
    module_spec.loader.exec_module(candidate)
    first = sorted(expected['closure_sha256'])[0]
    copied_dependency = expected['dependency_copies'][first]
    cases = [
        ('historical-positive', None),
        ('invalid-dependency-hashes', 'DEPENDENCY_DIGEST_FORMAT'),
        ('incorrect-hex-dependency-hash', 'DEPENDENCY_DIGEST_MISMATCH'),
        ('substituted-dependency-bytes', 'PROOF_ARTIFACT_BYTES:' + copied_dependency),
        ('missing-dependency-bytes', 'PROOF_REQUIRED_ARTIFACT_MISSING:' + copied_dependency),
        ('wrong-dependency-membership', 'DEPENDENCY_CLOSURE_MEMBERSHIP'),
        ('substituted-checked-elf', 'PROOF_ARTIFACT_BYTES:linux/gcd-selftest.elf'),
        ('missing-checked-elf', 'PROOF_REQUIRED_ARTIFACT_MISSING:linux/gcd-selftest.elf'),
        ('nonce-substitution', 'STALE_PROOF_RECEIPT'),
        ('unmanifested-mutation', 'PROOF_RECEIPT_BYTES'),
    ]
    results = []
    for name, reason in cases:
        fixture = a.work / name
        shutil.copytree(base, fixture)
        closure = dict(expected['closure_sha256'])
        if name == 'invalid-dependency-hashes':
            closure[first] = '!'*64
        elif name == 'incorrect-hex-dependency-hash':
            closure[first] = '0'*64
        elif name == 'wrong-dependency-membership':
            closure[first + '.unexpected'] = closure.pop(first)
        elif name == 'substituted-dependency-bytes':
            (fixture / copied_dependency).write_bytes(b'Incorrect dependency: negative control\n')
        elif name == 'missing-dependency-bytes':
            (fixture / copied_dependency).unlink()
        elif name == 'substituted-checked-elf':
            (fixture / 'linux/gcd-selftest.elf').write_bytes(b'Incorrect ELF: negative control\n')
        elif name == 'missing-checked-elf':
            (fixture / 'linux/gcd-selftest.elf').unlink()
        write(fixture / 'closure-identities.json', closure)
        receipt = {'challenge':request['challenge'], 'source_commit':request['expected_source_commit'],
                   'files':files(fixture),'end_to_end':False}
        if name == 'nonce-substitution':
            receipt['challenge'] = 'b'*64
        write(fixture / 'receipt.json', receipt)
        if name == 'unmanifested-mutation':
            with (fixture / 'linux/gcd-selftest.elf').open('ab') as stream:
                stream.write(b'Unmanifested mutation\n')
        observed = None
        try:
            candidate.validate_receipt(fixture, policy, lock, request)
        except Rejected as error:
            observed = str(error)
        record = {'case':name, 'expected_rejection':reason, 'observed_rejection':observed,
                  'matched':observed == reason,'receipt_sha256':digest(fixture/'receipt.json'),
                  'actual_files':files(fixture), 'fresh_kernel_execution':False,
                  'accepted_stage9_evidence':False, 'end_to_end':False}
        case_out = a.output / name
        case_out.mkdir()
        for generated in ['receipt.json','closure-identities.json','fixture-notice.json']:
            shutil.copyfile(fixture/generated,case_out/generated)
        for changed in ['linux/gcd-selftest.elf',copied_dependency]:
            if (fixture/changed).exists() and digest(fixture/changed) != expected['required_artifacts'][changed]:
                dest = case_out / changed
                dest.parent.mkdir(parents=True,exist_ok=True)
                shutil.copyfile(fixture/changed,dest)
        write(case_out/'result.json',record)
        results.append({k:v for k,v in record.items() if k != 'actual_files'})
        print(json.dumps({'case':name,'matched':record['matched'],'observed_rejection':observed}),flush=True)
    result = {'scope':'unapplied_candidate_identity_validation_only','cases':results,
              'historical_positive_accepted':results[0]['matched'],
              'fresh_legitimate_stage9_receipt':'not_run_requires_separate_execution_authorization',
              'kernel_exit_code':None,'signature_exit_code':None,'end_to_end':False,
              'exit_code':0 if all(r['matched'] for r in results) else 1}
    write(a.output/'result.json',result)
    return result['exit_code']


if __name__ == '__main__':
    raise SystemExit(main())
