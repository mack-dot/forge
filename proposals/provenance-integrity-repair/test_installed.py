#!/usr/bin/env python3
"""Adversarial controls for the INSTALLED Stage 9 integrity repair (post-adoption).

Scope: local, isolated fixtures only. No Rocq kernel, Cosign, Docker, workflow,
runner, signature or deployment runs. Receipt fixtures copy genuine Stage 7
bytes as explicitly untrusted inputs. Package fixtures are synthetic. A
positive control shows only that the candidate byte/identity logic admits a
structurally complete input. It is never kernel-checked proof or release
evidence. 'repaired' is the installed gate/provenance code; 'pre_repair' is the
earlier approved baseline in proposals/provenance-implementation/.
"""
import argparse
import copy
import gzip
import importlib.util
import io
import json
import os
from pathlib import Path, PurePosixPath
import random
import shutil
import subprocess
import sys
import tarfile
import types

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'gate/provenance'))
from common import Rejected, canonical, context, digest, files, read, sha, write  # noqa: E402
import release as candidate_release  # noqa: E402  (installed repaired gate)
import producer as candidate_producer  # noqa: E402  (installed repaired gate)

GATE = ROOT / 'gate/provenance'
PRE = ROOT / 'proposals/provenance-implementation'
PRE_SHA = {'release.py': 'e9f61515ae14300c099f6d2179df0610fe23b5267f3f14361165e2993f039df8',
           'producer.py': 'f3bcc1dc754a4ca423a1746215e12b09c39a7882922b338861c6470c71dd617a'}
LOCK_SHA = '9b10a2376c6b6de46661819a528f3b4e1251f27d76ac21e071b1cfb971224a76'
STAGE7 = ROOT / 'results/stage7/own-proof/attempt-0001/linux'
REFERENCE = ROOT / 'build/stage9-receipt-reference-0002'
COMMIT = '9679265c326d8d630e54c728f307891e5d6422ab'
SEED = 90270001
NOTICE = {'security_control_fixture': True, 'accepted_evidence': False, 'kernel_checked_here': False,
          'origin': 'copied historical Stage 7 bytes or synthetic bytes; no Stage 9 execution'}


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


for _name, _expected in PRE_SHA.items():
    if digest(PRE / _name) != _expected:
        raise SystemExit('PRE_REPAIR_BASELINE_CHANGED:' + _name)
installed_release = load('pre_repair_release', PRE / 'release.py')
_saved = sys.modules['release']
sys.modules['release'] = installed_release
installed_producer = load('pre_repair_producer', PRE / 'producer.py')
sys.modules['release'] = _saved
IDENT = read(GATE / 'artifact-identities.json')


def outcome(function, *args):
    try:
        value = function(*args)
        return {'observed': 'accepted', 'returned': value if isinstance(value, str) else None}
    except Rejected as error:
        return {'observed': 'rejected', 'reason': error.reason}
    except Exception as error:  # recorded, never counted as a passing rejection
        return {'observed': 'exception', 'reason': type(error).__name__ + ':' + str(error)[:300]}


def clone(source, target):
    # APFS copy-on-write clone. Mutations never reach the historical inputs.
    subprocess.run(['cp', '-c', '-R', str(source), str(target)], check=True)
    return target


def replace(path, data):
    path = Path(path)
    if path.exists():
        path.unlink()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)


def seal(directory, request):
    receipt = directory / 'receipt.json'
    if receipt.exists():
        receipt.unlink()
    write(receipt, {'challenge': request['challenge'], 'source_commit': request['expected_source_commit'],
                    'files': files(directory), 'end_to_end': False})


def request_for(label):
    return {'challenge': sha(('forge-stage9-integrity-fixture:' + label).encode()),
            'expected_source_commit': COMMIT}


def build_receipt(work, request):
    base = work / 'receipt-base'
    shutil.copytree(STAGE7, base / 'linux')
    for name in IDENT['receipt']['closure_sha256']:
        target = base / 'dependencies' / name.lstrip('/')
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(REFERENCE / name.lstrip('/'), target)
    write(base / 'closure-identities.json',
          {name: digest(base / 'dependencies' / name.lstrip('/')) for name in IDENT['receipt']['closure_sha256']})
    write(base / 'fixture-notice.json', NOTICE)
    seal(base, request)
    return base


def edit_json(path, change):
    value = read(path)
    change(value)
    replace(path, json.dumps(value, sort_keys=True, indent=2).encode() + b'\n')


def update_kernel_digest(directory):
    edit_json(directory / 'linux/report.json', lambda r: r.update(
        independent_kernel_log_sha256=digest(directory / 'linux/independent-kernel.log')))


LIB = sorted(n for n in IDENT['receipt']['closure_sha256'] if n.startswith('/home/'))[0]
LIB_COPY = 'dependencies/' + LIB.lstrip('/')


def receipt_cases(policy):
    """name -> (mutation(directory, request) returning request to use, expected candidate reason)."""
    def closure(change, reseal=True):
        def apply(d, r):
            edit_json(d / 'closure-identities.json', change)
            if reseal:
                seal(d, r)
            return r
        return apply

    def mutate(path, data=None, delete=False, reseal=True, after=None):
        def apply(d, r):
            if delete:
                (d / path).unlink()
            else:
                replace(d / path, data)
            if after:
                after(d)
            if reseal:
                seal(d, r)
            return r
        return apply

    def other_request(d, r):
        return request_for('replayed-different-request')

    def wrong_commit(d, r):
        return {**r, 'expected_source_commit': '0' * 40}

    def stale(d, r):
        edit_json(d / 'receipt.json', lambda m: m.update(challenge='b' * 64))
        return r

    def report(change):
        def apply(d, r):
            edit_json(d / 'linux/report.json', change)
            seal(d, r)
            return r
        return apply

    def kernel(change):
        def apply(d, r):
            text = (d / 'linux/independent-kernel.log').read_text()
            replace(d / 'linux/independent-kernel.log', change(text).encode())
            update_kernel_digest(d)
            seal(d, r)
            return r
        return apply

    other = sorted(n for n in IDENT['receipt']['closure_sha256'] if n.startswith('/home/'))[1]
    evil_elf = b'\x7fELF' + b'\x02\x01\x01' + b'\x00' * 9 + b'Forge Stage 9 malicious ELF security control\n'
    first_intern = '[intern ' + LIB + ' ...\n'

    def swap_membership(m):
        value = m.pop(LIB)
        m['/home/opam/.opam/4.14/lib/coq/theories/Forge/Substituted.vo'] = value

    def add_dependency(d, r):
        replace(d / 'dependencies/home/opam/extra/Extra.vo', b'extra dependency control\n')
        edit_json(d / 'closure-identities.json', lambda m: m.update(
            {'/home/opam/extra/Extra.vo': sha(b'extra dependency control\n')}))
        seal(d, r)
        return r

    def substitute_consistently(d, r):
        replace(d / LIB_COPY, b'substituted dependency bytes control\n')
        edit_json(d / 'closure-identities.json', lambda m: m.update(
            {LIB: sha(b'substituted dependency bytes control\n')}))
        seal(d, r)
        return r

    def symlink(d, r):
        os.symlink('report.json', d / 'linux/link.json')
        return r

    def malformed_files(d, r):
        edit_json(d / 'receipt.json', lambda m: m.update(files=list(m['files'])))
        return r

    def bad_manifest_digest(d, r):
        edit_json(d / 'receipt.json', lambda m: m['files'].update({'fixture-notice.json': 'a' * 63}))
        return r

    return {
        'positive-historical-byte-control': (lambda d, r: r, 'accepted'),
        'invalid-sha256-syntax-all': (closure(lambda m: m.update({k: '!' * 64 for k in m})), 'DEPENDENCY_DIGEST_FORMAT'),
        'invalid-sha256-uppercase-one': (closure(lambda m: m.update({LIB: m[LIB].upper()})), 'DEPENDENCY_DIGEST_FORMAT'),
        'invalid-sha256-non-string': (closure(lambda m: m.update({LIB: 7})), 'DEPENDENCY_DIGEST_FORMAT'),
        'invalid-manifest-digest-syntax': (bad_manifest_digest, 'RECEIPT_DIGEST_FORMAT'),
        'incorrect-dependency-digest': (closure(lambda m: m.update({LIB: m[other]})), 'DEPENDENCY_DIGEST_MISMATCH'),
        'missing-dependency-entry': (closure(lambda m: m.pop(LIB)), 'DEPENDENCY_CLOSURE_MEMBERSHIP'),
        'missing-dependency-bytes': (mutate(LIB_COPY, delete=True), 'DEPENDENCY_BYTES_MISSING:' + LIB_COPY),
        'extra-dependency-entry-and-bytes': (add_dependency, 'DEPENDENCY_CLOSURE_MEMBERSHIP'),
        'extra-dependency-bytes-only': (mutate('dependencies/home/opam/extra/Extra.vo', b'extra\n'),
                                        'DEPENDENCY_EXTRA_FILE'),
        'substituted-dependency-bytes-consistent-closure': (substitute_consistently, 'DEPENDENCY_DIGEST_MISMATCH'),
        'substituted-dependency-bytes-manifest-only': (mutate(LIB_COPY, b'substituted\n'), 'DEPENDENCY_BYTES:' + LIB_COPY),
        'substituted-own-proof-object': (mutate('linux/source/Proof.vo', b'substituted proof object\n'),
                                         'PROOF_ARTIFACT_BYTES:linux/source/Proof.vo'),
        'wrong-dependency-closure-identity': (closure(swap_membership), 'DEPENDENCY_CLOSURE_MEMBERSHIP'),
        'wrong-kernel-loaded-closure': (kernel(lambda t: t.replace(
            first_intern, '[intern /home/opam/.opam/4.14/lib/coq/theories/Forge/Substituted.vo ...\n', 1)),
            'KERNEL_DEPENDENCY_MEMBERSHIP'),
        'missing-copied-elf': (mutate('linux/gcd-selftest.elf', delete=True),
                               'PROOF_REQUIRED_ARTIFACT_MISSING:linux/gcd-selftest.elf'),
        'modified-copied-elf': (mutate('linux/gcd-selftest.elf', evil_elf), 'PROOF_ARTIFACT_BYTES:linux/gcd-selftest.elf'),
        'correct-manifest-malicious-extra-executable': (mutate('linux/payload.bin', evil_elf),
                                                       'PROOF_UNEXPECTED_EXECUTABLE:linux/payload.bin'),
        'correct-manifest-unexpected-elf-name': (mutate('linux/second.elf', b'not listed\n'),
                                                'PROOF_UNEXPECTED_ARTIFACT:linux/second.elf'),
        'stale-nonce': (stale, 'STALE_PROOF_RECEIPT'),
        'wrong-source-commit': (wrong_commit, 'STALE_PROOF_RECEIPT'),
        'valid-receipt-replayed-different-request': (other_request, 'STALE_PROOF_RECEIPT'),
        'missing-kernel-log': (mutate('linux/independent-kernel.log', delete=True), 'KERNEL_LOG_MISSING'),
        'kernel-not-independent': (report(lambda v: v.update(independent_rocqchk=False)), 'PROOF_NOT_ESTABLISHED'),
        'kernel-command-absent': (report(lambda v: v.update(rocqchk_commands=[])), 'INDEPENDENT_KERNEL_EXIT'),
        'kernel-command-changed': (report(lambda v: v['rocqchk_commands'][0]['command'].pop()), 'KERNEL_COMMAND_BINDING'),
        'kernel-summary-truncated': (kernel(lambda t: t.split('CONTEXT SUMMARY')[0]), 'KERNEL_ASSUMPTION_SUMMARY'),
        'kernel-summary-type-in-type': (kernel(lambda t: t.replace(
            'relying on type-in-type: <none>', 'relying on type-in-type: Forge.Bad')), 'KERNEL_SUMMARY'),
        'unmanifested-mutation': (mutate('linux/gcd_selftest.c', b'changed\n', reseal=False), 'PROOF_RECEIPT_BYTES'),
        'malformed-manifest-files': (malformed_files, 'PROOF_RECEIPT_FIELDS'),
        'malformed-report-json': (mutate('linux/report.json', b'{"result": '), 'PROOF_RECEIPT_MALFORMED:JSONDecodeError'),
        'symlink-in-receipt': (symlink, 'SYMLINK_INPUT'),
    }


def original_audit_cases(work, policy):
    """Rebuild the exact five original audit fixtures and run them through both validators."""
    names = ['report.json', 'independent-kernel.log', 'before/identity.json', 'after/identity.json',
             'gcd-selftest.elf']
    import re
    paths = re.findall(r'^\[intern (.+\.vo) \.\.\.$', (STAGE7 / 'independent-kernel.log').read_text(), re.M)
    request = {'challenge': 'a' * 64, 'expected_source_commit': '06b40caa6bf5fb6963756b39646413559f84c61d'}
    results = {}
    for name in ['invalid-dependency-hashes', 'substituted-checked-elf', 'missing-checked-elf',
                 'nonce-mismatch', 'unmanifested-mutation']:
        fixture = work / ('original-audit-' + name)
        for original in names:
            (fixture / 'linux' / original).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(STAGE7 / original, fixture / 'linux' / original)
        write(fixture / 'closure-identities.json', {p: '!' * 64 for p in paths})
        write(fixture / 'fixture-notice.json', NOTICE)
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
            with (fixture / 'linux/gcd-selftest.elf').open('ab') as stream:
                stream.write(b'changed after manifest')
        results[name] = {'pre_repair': outcome(installed_release.validate_receipt, fixture, policy, LOCK, request),
                         'repaired': outcome(candidate_release.validate_receipt, fixture, policy, LOCK, request)}
    return results


# Synthetic packages: built here with tarfile/gzip, never by Docker.
ELF_PATH = 'opt/forge/gcd-selftest.elf'


def layer(entries, compress=None):
    buffer = io.BytesIO()
    with tarfile.open(fileobj=buffer, mode='w', format=tarfile.PAX_FORMAT) as tar:
        for entry in entries:
            info = tarfile.TarInfo(entry['name'])
            info.mode, info.uid, info.gid, info.mtime = entry.get('mode', 0o755), entry.get('uid', 1000), \
                entry.get('gid', 1000), 0
            kind = entry['kind']
            if kind == 'dir':
                info.type = tarfile.DIRTYPE
                tar.addfile(info)
            elif kind == 'file':
                info.size = len(entry['data'])
                tar.addfile(info, io.BytesIO(entry['data']))
            else:
                info.type = tarfile.SYMTYPE if kind == 'symlink' else tarfile.LNKTYPE
                info.linkname = entry['link']
                tar.addfile(info)
    raw = buffer.getvalue()
    if compress == 'gzip':
        return raw, gzip.compress(raw, mtime=0)
    if compress == 'zstd':
        return raw, b'\x28\xb5\x2f\xfd' + raw
    return raw, raw


def good_entries(elf, **file_overrides):
    return [{'name': 'opt', 'kind': 'dir'}, {'name': 'opt/forge', 'kind': 'dir'},
            {'name': ELF_PATH, 'kind': 'file', 'data': elf, 'mode': 0o444, **file_overrides}]


def build_package(root, policy, request_base, layers, *, config_change=None, base=None, descriptor_change=None):
    """Write packaged.elf, package.json and package-identity/. Return the matching request."""
    base = IDENT['package']['base_rootfs_diff_ids'] if base is None else base
    elf = (ROOT / policy['release_artifact']['path']).read_bytes()
    diff_ids = base + ['sha256:' + sha(raw) for raw, _ in layers]
    config = {'architecture': 'amd64', 'os': 'linux',
              'config': {'User': '1000:1000', 'Entrypoint': ['python3', '-c', 'import signal; signal.pause()'],
                         'WorkingDir': '/opt/forge'},
              'rootfs': {'type': 'layers', 'diff_ids': diff_ids}}
    if config_change:
        config_change(config)
    config_bytes = json.dumps(config, sort_keys=True).encode()
    config_sha = sha(config_bytes)
    identity = root / 'package-identity'
    (identity / 'blobs/sha256').mkdir(parents=True)
    (identity / 'blobs/sha256' / config_sha).write_bytes(config_bytes)
    names = []
    for _, blob in layers:
        (identity / 'blobs/sha256' / sha(blob)).write_bytes(blob)
        names.append('blobs/sha256/' + sha(blob))
    manifest = [{'Config': 'blobs/sha256/' + config_sha, 'RepoTags': None,
                 'Layers': ['blobs/sha256/' + d.removeprefix('sha256:') for d in base] + names}]
    (identity / 'manifest.json').write_bytes(json.dumps(manifest).encode())
    descriptor = {'identity_kind': 'docker_image_config', 'sha256': config_sha,
                  'base': policy['deployment']['base_image'],
                  'base_platform_manifest': policy['deployment']['platform_manifest'],
                  'platform': 'linux/amd64', 'rootfs_diff_ids': diff_ids,
                  'recipe_sha256': digest(ROOT / 'gate/provenance/Dockerfile'),
                  'elf_path': policy['deployment']['path'], 'elf_sha256': policy['release_artifact']['sha256'],
                  'build_command': 'docker buildx build --builder desktop-linux --load --platform linux/amd64 '
                                   '--provenance=false --sbom=false --network=none --build-arg SOURCE_DATE_EPOCH=0',
                  'end_to_end': False}
    if descriptor_change:
        descriptor_change(descriptor)
    write(root / 'package.json', descriptor)
    (root / 'packaged.elf').write_bytes(elf)
    write(root / 'fixture-notice.json', {**NOTICE, 'docker_build': 'not_run', 'synthetic_package': True})
    return {**request_base, 'artifact_sha256': policy['release_artifact']['sha256'],
            'package_sha256': config_sha, 'package': descriptor,
            'policy_id': policy['id'], 'policy_version': policy['version'], 'policy_epoch': policy['epoch'],
            'policy_sha256': digest(ROOT / 'policy/provenance.json'), 'implementation_lock_sha256': LOCK_SHA}


def package_cases(policy):
    elf = (ROOT / policy['release_artifact']['path']).read_bytes()
    wrong = b'\x7fELF' + b'\x00' * 12 + b'Forge Stage 9 wrong packaged executable\n'
    good = [layer(good_entries(elf))]

    def after(change):
        def apply(root, request):
            change(root, request)
            return request
        return apply

    def rewrite_descriptor(root, request):
        edit_json(root / 'package.json', lambda d: d.update(elf_sha256=sha(wrong)))

    def wrong_metadata(root, request):
        request['package']['elf_sha256'] = sha(wrong)
        (root / 'packaged.elf').write_bytes(wrong)
        write(root / 'package.json', request['package'])

    def extra_blob(root, request):
        (root / 'package-identity/blobs/sha256' / sha(b'x')).write_bytes(b'x')

    def tamper_layer(root, request):
        path = root / 'package-identity' / read(root / 'package-identity/manifest.json')[0]['Layers'][-1]
        path.write_bytes(path.read_bytes()[:-1] + b'\x01')

    def remove_identity(root, request):
        shutil.rmtree(root / 'package-identity')

    def wrong_identity_kind(root, request):
        request['package']['identity_kind'] = 'oci_image_manifest'
        write(root / 'package.json', request['package'])

    def manifest_digest_as_package(root, request):
        manifest = root / 'package-identity/manifest.json'
        fake = sha(manifest.read_bytes())
        request['package']['sha256'] = request['package_sha256'] = fake
        write(root / 'package.json', request['package'])

    base_changed = list(IDENT['package']['base_rootfs_diff_ids'])
    base_changed[0] = 'sha256:' + '0' * 64
    whiteout = [{'name': 'opt', 'kind': 'dir'}, {'name': 'opt/forge', 'kind': 'dir'},
                {'name': 'opt/forge/.wh.gcd-selftest.elf', 'kind': 'file', 'data': b''}]
    obscure = [{'name': 'opt', 'kind': 'dir'}, {'name': 'opt/forge', 'kind': 'symlink', 'link': '/tmp'}]
    bomb = gzip.compress(b'\x00' * (IDENT['package']['maximum_added_layer_bytes'] + 2), mtime=0)
    return {
        'positive-synthetic-package': ({'layers': good}, None, 'accepted'),
        'positive-synthetic-package-gzip-layer': ({'layers': [layer(good_entries(elf), 'gzip')]}, None, 'accepted'),
        'positive-synthetic-package-extra-metadata-layer': (
            {'layers': good + [layer([{'name': 'opt', 'kind': 'dir'}, {'name': 'opt/forge', 'kind': 'dir'}])]},
            None, 'accepted'),
        'missing-packaged-elf': ({'layers': good}, after(lambda r, q: (r / 'packaged.elf').unlink()),
                                 'PACKAGED_ELF_MISSING'),
        'substituted-packaged-elf': ({'layers': good}, after(lambda r, q: (r / 'packaged.elf').write_bytes(wrong)),
                                     'PACKAGED_ELF_BYTES'),
        'packaging-descriptor-rewritten': ({'layers': good}, after(rewrite_descriptor), 'PACKAGE_DESCRIPTOR_BINDING'),
        'packaging-metadata-matches-wrong-executable': ({'layers': good}, after(wrong_metadata),
                                                        'PACKAGED_ELF_BYTES'),
        'self-consistent-image-with-wrong-elf': ({'layers': [layer(good_entries(wrong))]}, None,
                                                 'PACKAGE_FILESYSTEM_ELF:substituted'),
        'image-without-elf': ({'layers': [layer([{'name': 'etc', 'kind': 'dir'}])]}, None,
                              'PACKAGE_FILESYSTEM_ELF:absent'),
        'later-layer-whiteout': ({'layers': good + [layer(whiteout)]}, None, 'PACKAGE_FILESYSTEM_ELF:removed'),
        'later-layer-symlink-ancestor': ({'layers': good + [layer(obscure)]}, None, 'PACKAGE_FILESYSTEM_ELF:obscured'),
        'elf-as-symlink': ({'layers': [layer(good_entries(elf)[:2] + [
            {'name': ELF_PATH, 'kind': 'symlink', 'link': '/etc/passwd'}])]}, None,
            'PACKAGE_FILESYSTEM_ELF:substituted'),
        'elf-wrong-mode': ({'layers': [layer(good_entries(elf, mode=0o755))]}, None,
                           'PACKAGE_FILESYSTEM_ELF:substituted'),
        'elf-wrong-owner': ({'layers': [layer(good_entries(elf, uid=0))]}, None, 'PACKAGE_FILESYSTEM_ELF:substituted'),
        'whiteout-and-file-same-layer': ({'layers': [layer(good_entries(elf) + [
            {'name': 'opt/forge/.wh..wh..opq', 'kind': 'file', 'data': b''}])]}, None,
            'PACKAGE_FILESYSTEM_ELF:ambiguous'),
        'duplicate-layer-entry': ({'layers': [layer(good_entries(elf) + [good_entries(wrong)[2]])]}, None,
                                  'PACKAGE_LAYER_DUPLICATE'),
        'tampered-added-layer': ({'layers': good}, after(tamper_layer), 'PACKAGE_BLOB_DIGEST:'),
        'extra-package-blob': ({'layers': good}, after(extra_blob), 'PACKAGE_IDENTITY_FILE_SET'),
        'changed-base-layer-identity': ({'layers': good, 'base': base_changed}, None, 'PACKAGE_BASE_LAYERS'),
        'root-user-config': ({'layers': good, 'config_change': lambda c: c['config'].update(User='0:0')}, None,
                             'PACKAGE_RUNTIME_CONFIG'),
        'zstd-layer': ({'layers': [layer(good_entries(elf), 'zstd')]}, None, 'PACKAGE_LAYER_COMPRESSION'),
        'oversized-gzip-layer': ({'layers': [(gzip.decompress(bomb), bomb)]}, None, 'PACKAGE_LAYER_SIZE'),
        'missing-package-identity': ({'layers': good}, after(remove_identity), 'PACKAGE_MALFORMED:FileNotFoundError'),
        'unsupported-identity-kind': ({'layers': good}, after(wrong_identity_kind), 'PACKAGE_DESCRIPTOR_FIELDS'),
        'package-digest-not-config-blob': ({'layers': good}, after(manifest_digest_as_package),
                                           'PACKAGE_CONFIG_IDENTITY'),
    }


def matches(observed, expected):
    if expected == 'accepted':
        return observed['observed'] == 'accepted'
    return observed['observed'] == 'rejected' and (
        observed['reason'] == expected or (expected.endswith(':') and observed['reason'].startswith(expected)))


# Bounded exhaustive comparison of the single-path layer tracker with an
# independently written whole-tree oracle. Finite enumeration, not a proof.
def oracle_apply(tree, entries):
    names = {str(PurePosixPath(e['name'])): e for e in entries}
    for name in names:
        path = PurePosixPath(name)
        if path.name == '.wh..wh..opq':
            parent = str(path.parent)
            for key in [k for k in tree if parent == '.' or k.startswith(parent + '/')]:
                del tree[key]
        elif path.name.startswith('.wh.'):
            victim = str(path.parent / path.name[4:])
            for key in [k for k in tree if k == victim or k.startswith(victim + '/')]:
                del tree[key]
    for name, entry in names.items():
        if PurePosixPath(name).name.startswith('.wh.'):
            continue
        if entry['kind'] != 'dir' or (name in tree and tree[name]['kind'] != 'dir'):
            for key in [k for k in tree if k.startswith(name + '/')]:
                del tree[key]
        tree[name] = entry
    return tree


def oracle_accepts(tree, elf):
    chain = ['opt', 'opt/forge']
    entry = tree.get(ELF_PATH)
    return (all(tree.get(p, {}).get('kind') == 'dir' for p in chain) and entry is not None
            and entry['kind'] == 'file' and entry['data'] == elf and entry.get('mode') == 0o444
            and entry.get('uid', 1000) == 1000 and entry.get('gid', 1000) == 1000)


def bounded_layer_model(elf):
    dirs = [{'name': 'opt', 'kind': 'dir'}, {'name': 'opt/forge', 'kind': 'dir'}]
    kinds = {
        'good': good_entries(elf), 'bytes': good_entries(b'other'), 'mode': good_entries(elf, mode=0o755),
        'whiteout-target': dirs + [{'name': 'opt/forge/.wh.gcd-selftest.elf', 'kind': 'file', 'data': b''}],
        'opaque-forge': dirs + [{'name': 'opt/forge/.wh..wh..opq', 'kind': 'file', 'data': b''}],
        'whiteout-opt': [{'name': '.wh.opt', 'kind': 'file', 'data': b''}],
        'symlink-forge': [{'name': 'opt', 'kind': 'dir'}, {'name': 'opt/forge', 'kind': 'symlink', 'link': '/tmp'}],
        'symlink-target': dirs + [{'name': ELF_PATH, 'kind': 'symlink', 'link': '/x'}],
        'hardlink-target': dirs + [{'name': ELF_PATH, 'kind': 'hardlink', 'link': 'etc/x'}],
        'unrelated': [{'name': 'etc', 'kind': 'dir'}, {'name': 'etc/x', 'kind': 'file', 'data': b'x'}],
        'file-without-parents': [{'name': ELF_PATH, 'kind': 'file', 'data': elf, 'mode': 0o444}],
        'ambiguous': good_entries(elf) + [{'name': 'opt/forge/.wh..wh..opq', 'kind': 'file', 'data': b''}],
    }
    raw = {name: layer(entries)[0] for name, entries in kinds.items()}
    bases = {'empty': {}, 'base-has-good-elf': {e['name']: e for e in good_entries(elf)},
             'base-symlink-opt': {'opt': {'name': 'opt', 'kind': 'symlink', 'link': '/tmp'}}}
    import itertools
    stacks = [s for n in (1, 2, 3) for s in itertools.product(kinds, repeat=n)]
    unsound, conservative, agreements = [], 0, 0
    for stack in stacks:
        state = 'absent'
        for name in stack:
            state = candidate_release.layer_effect(raw[name], state, IDENT['package'], elf)
        accepted = state == 'expected'
        for base_name, base in bases.items():
            tree = copy.deepcopy(base)
            for name in stack:
                oracle_apply(tree, kinds[name])
            truth = oracle_accepts(tree, elf)
            if accepted and not truth:
                unsound.append({'stack': list(stack), 'base': base_name})
            elif truth and not accepted:
                conservative += 1
            else:
                agreements += 1
    return {'stacks': len(stacks), 'base_variants': len(bases), 'layer_kinds': sorted(kinds),
            'candidate_accepts_oracle_rejects': unsound, 'conservative_rejections': conservative,
            'agreements': agreements, 'method': 'bounded exhaustive enumeration; not formal verification'}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--random-cases', type=int, default=40)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    args.work.mkdir(parents=True, exist_ok=False)
    if (ROOT / '.toolchain/stage9/cosign').exists():
        raise SystemExit('REFUSING: a Cosign executable exists; this suite must not reach a signing tool')
    global LOCK
    policy, LOCK, _ = context(LOCK_SHA)
    inputs_before = {'stage7': files(STAGE7), 'reference': files(REFERENCE),
                     'identities': digest(GATE / 'artifact-identities.json')}
    results = {'receipt': {}, 'package': {}, 'signing_path': {}, 'property': {}}
    unexpected = []

    request = request_for('base')
    base = build_receipt(args.work, request)
    for name, (mutation, expected) in receipt_cases(policy).items():
        fixture = clone(base, args.work / ('receipt-' + name))
        used = mutation(fixture, request)
        record = {'expected_candidate': expected,
                  'repaired': outcome(candidate_release.validate_receipt, fixture, policy, LOCK, used),
                  'pre_repair': outcome(installed_release.validate_receipt, fixture, policy, LOCK, used)}
        record['candidate_as_expected'] = matches(record['repaired'], expected)
        results['receipt'][name] = record
        if not record['candidate_as_expected']:
            unexpected.append('receipt:' + name)
        print(json.dumps({'case': 'receipt:' + name, 'repaired': record['repaired'],
                          'pre_repair': record['pre_repair']['observed']}), flush=True)
    results['original_audit'] = original_audit_cases(args.work, policy)
    for name, record in results['original_audit'].items():
        if record['repaired']['observed'] != 'rejected':
            unexpected.append('original-audit:' + name)

    for name, (spec, change, expected) in package_cases(policy).items():
        root = args.work / ('package-' + name)
        root.mkdir()
        used = build_package(root, policy, request_for('package'), spec['layers'],
                             config_change=spec.get('config_change'), base=spec.get('base'))
        if change:
            used = change(root, used)
        record = {'expected_candidate': expected,
                  'repaired': outcome(candidate_release.validate_package, policy, used, root)}
        record['candidate_as_expected'] = matches(record['repaired'], expected)
        results['package'][name] = record
        if not record['candidate_as_expected']:
            unexpected.append('package:' + name)
        print(json.dumps({'case': 'package:' + name, 'repaired': record['repaired']}), flush=True)

    # The signing function up to the point where it would load Cosign. The
    # absent Cosign executable makes COSIGN_PIN the furthest reachable step.
    for name, mutation, expected in [
            ('positive-reaches-cosign-pin-only', None, 'COSIGN_PIN'),
            ('missing-packaged-elf', lambda o: (o / 'packaged.elf').unlink(), 'PACKAGED_ELF_MISSING'),
            ('substituted-packaged-elf', lambda o: (o / 'packaged.elf').write_bytes(b'\x7fELF wrong\n'),
             'PACKAGED_ELF_BYTES'),
            ('substituted-image-layer', lambda o: tamper(o), 'PACKAGE_BLOB_DIGEST:'),
            ('invalid-dependency-digests', lambda o: (edit_json(o / 'proof/closure-identities.json',
                                                                lambda m: m.update({k: '!' * 64 for k in m})),
                                                      seal(o / 'proof', read(o / 'request.json'))),
             'DEPENDENCY_DIGEST_FORMAT')]:
        out = args.work / ('signing-' + name)
        out.mkdir()
        sign_request = build_package(out, policy, request_for('signing'), [layer(good_entries(
            (ROOT / policy['release_artifact']['path']).read_bytes()))])
        clone(base, out / 'proof')
        seal(out / 'proof', sign_request)
        evidence = installed_release.expected_canonical(policy, LOCK, LOCK_SHA, sign_request['package'])
        write(out / 'evidence.json', evidence)
        write(out / 'statement.json', installed_producer.statement(policy, sign_request, evidence,
                                                                   digest(out / 'proof/receipt.json')))
        write(out / 'request.json', sign_request)
        if mutation:
            mutation(out)
        env = {'GITHUB_REPOSITORY': 'mack-dot/forge', 'GITHUB_EVENT_NAME': 'workflow_dispatch',
               'GITHUB_REF': 'refs/heads/main', 'GITHUB_SHA': COMMIT, 'GITHUB_RUN_ATTEMPT': '1',
               'GITHUB_WORKFLOW_REF': 'mack-dot/forge/.github/workflows/provenance.yml@refs/heads/main'}
        saved = {k: os.environ.get(k) for k in env}
        os.environ.update(env)
        try:
            record = {'expected_candidate': expected}
            for label, module in [('repaired', candidate_producer), ('pre_repair', installed_producer)]:
                copy_out = clone(out, args.work / ('signing-' + name + '-' + label))
                arguments = types.SimpleNamespace(action='sign', output=copy_out, implementation_sha256=LOCK_SHA)
                record[label] = outcome(module.sign, arguments, policy, LOCK, None, sign_request)
                record[label]['signing_outputs'] = sorted(p.name for p in copy_out.glob('*.sigstore.json'))
        finally:
            for key, value in saved.items():
                if value is None:
                    os.environ.pop(key, None)
                else:
                    os.environ[key] = value
        record['candidate_as_expected'] = matches(record['repaired'], expected) \
            and not record['repaired']['signing_outputs']
        results['signing_path'][name] = record
        if not record['candidate_as_expected'] or record['pre_repair']['signing_outputs']:
            unexpected.append('signing:' + name)
        print(json.dumps({'case': 'signing:' + name, 'repaired': record['repaired'],
                          'pre_repair': record['pre_repair']}), flush=True)

    # Seeded random properties. Finite tests, not proof.
    rng = random.Random(SEED)
    elf = (ROOT / policy['release_artifact']['path']).read_bytes()
    alphabet = '0123456789abcdefABCDEF!g '
    digest_cases, flip_cases, package_flips = [], [], []
    for index in range(args.random_cases):
        fixture = clone(base, args.work / f'property-digest-{index:03d}')
        key = rng.choice(sorted(IDENT['receipt']['closure_sha256']))
        length = rng.choice([0, 1, 63, 64, 64, 64, 65])
        value = ''.join(rng.choice(alphabet) for _ in range(length))
        edit_json(fixture / 'closure-identities.json', lambda m: m.update({key: value}))
        seal(fixture, request)
        observed = outcome(candidate_release.validate_receipt, fixture, policy, LOCK, request)
        well_formed = len(value) == 64 and all(c in '0123456789abcdef' for c in value)
        want = 'DEPENDENCY_DIGEST_MISMATCH' if well_formed else 'DEPENDENCY_DIGEST_FORMAT'
        ok = value != IDENT['receipt']['closure_sha256'][key] and matches(observed, want)
        digest_cases.append({'key': key, 'value': value, 'repaired': observed, 'as_expected': ok})
        shutil.rmtree(fixture)
        fixture = clone(base, args.work / f'property-flip-{index:03d}')
        candidates = sorted(IDENT['receipt']['fixed_artifacts']) + sorted(
            'dependencies/' + n.lstrip('/') for n in IDENT['receipt']['closure_sha256'])
        target = rng.choice(candidates)
        data = bytearray((fixture / target).read_bytes())
        position = rng.randrange(len(data))
        data[position] ^= 1 << rng.randrange(8)
        replace(fixture / target, bytes(data))
        seal(fixture, request)
        observed = outcome(candidate_release.validate_receipt, fixture, policy, LOCK, request)
        want = ('PROOF_ARTIFACT_BYTES:' if target.startswith('linux/') else 'DEPENDENCY_BYTES:') + target
        flip_cases.append({'target': target, 'position': position, 'repaired': observed,
                           'as_expected': matches(observed, want)})
        shutil.rmtree(fixture)
        root = args.work / f'property-package-{index:03d}'
        root.mkdir()
        used = build_package(root, policy, request_for('package'), [layer(good_entries(elf))])
        data = bytearray(elf)
        position = rng.randrange(len(data))
        data[position] ^= 1 << rng.randrange(8)
        (root / 'packaged.elf').write_bytes(bytes(data))
        observed = outcome(candidate_release.validate_package, policy, used, root)
        package_flips.append({'position': position, 'repaired': observed,
                              'as_expected': matches(observed, 'PACKAGED_ELF_BYTES')})
    results['property'] = {'seed': SEED, 'cases_per_property': args.random_cases,
                           'dependency_digest_values': digest_cases, 'receipt_single_bit_flips': flip_cases,
                           'packaged_elf_single_bit_flips': package_flips}
    for label, cases in [('digest', digest_cases), ('flip', flip_cases), ('package', package_flips)]:
        unexpected += [f'property:{label}:{i}' for i, c in enumerate(cases) if not c['as_expected']]
    results['bounded_layer_model'] = bounded_layer_model(elf)
    if results['bounded_layer_model']['candidate_accepts_oracle_rejects']:
        unexpected.append('bounded-layer-model:unsound')

    inputs_after = {'stage7': files(STAGE7), 'reference': files(REFERENCE),
                    'identities': digest(GATE / 'artifact-identities.json')}
    if inputs_after != inputs_before:
        unexpected.append('historical-inputs-changed')
    summary = {'scope': 'local isolated validator controls; no kernel, Cosign, Docker, workflow or deployment',
               'accepted_proof_evidence': False, 'kernel_execution': 'not_run', 'signature_execution': 'not_run',
               'docker_execution': 'not_run', 'workflow_execution': 'not_run', 'end_to_end': False,
               'candidate_sha256': {name: digest(GATE / name) for name in
                                    ['release.py', 'producer.py', 'artifact-identities.json']},
               'installed_lock_sha256': LOCK_SHA, 'historical_inputs_unchanged': inputs_after == inputs_before,
               'unexpected': unexpected, 'exit_code': 1 if unexpected else 0}
    write(args.output / 'result.json', {**summary, 'results': results})
    print(json.dumps(summary, sort_keys=True))
    return summary['exit_code']


def tamper(out):
    path = out / 'package-identity' / read(out / 'package-identity/manifest.json')[0]['Layers'][-1]
    path.write_bytes(path.read_bytes()[:-1] + b'\x01')


if __name__ == '__main__':
    raise SystemExit(main())
