"""Research producer/controller. All signing is performed by pinned Cosign."""
import argparse
import copy
import os
from pathlib import Path
import re
import secrets
import shutil
import sqlite3

from common import (ROOT, HERE, Records, canonical, clean_environment, context, cosign_path,
                    digest, files, parse, read, require, sha, write)
from release import expected_canonical, validate_receipt


def runtime(records):
    pins = read(HERE / 'runtime.json')
    _, output, _ = records.run(['docker', 'version', '--format', '{{json .}}'], 'docker-version')
    value = parse(output)
    for side in ['Client', 'Server']:
        for key, expected in pins['docker'][side].items():
            require(value[side][key] == expected, 'DOCKER_VERSION:' + side + ':' + key)
    components = {c['Name']: c['Version'] for c in value['Server']['Components']}
    require(components == pins['docker_components'], 'DOCKER_COMPONENTS')
    require(value['Server']['KernelVersion'] == pins['kernel']
            and value['Server']['Platform']['Name'] == 'Docker Desktop ' + pins['docker_desktop'],
            'DOCKER_HOST_RUNTIME')
    _, output, _ = records.run(['docker', 'buildx', 'version'], 'buildx-version')
    require(output.decode().strip() == pins['buildx'], 'BUILDX_VERSION')
    _, output, _ = records.run(['docker', 'buildx', 'inspect', pins['builder']['name']], 'builder-inspect')
    text = output.decode()
    require(re.search(r'^Driver:\s+' + re.escape(pins['builder']['driver']) + r'\s*$', text, re.M)
            and re.search(r'^BuildKit version:\s+' + re.escape(pins['builder']['buildkit_version']) + r'\s*$', text, re.M),
            'BUILDER_VERSION')


def package(policy, out, records):
    runtime(records)
    base = policy['deployment']['base_image']
    records.run(['docker', 'pull', '--platform', 'linux/amd64', base], 'package-base-pull')
    _, info, _ = records.run(['docker', 'image', 'inspect', base], 'package-base-inspect')
    base_info = parse(info)[0]
    require(base in base_info['RepoDigests'], 'BASE_IMAGE_IDENTITY')
    require(base_info['Architecture'] == 'amd64' and base_info['Os'] == 'linux', 'BASE_PLATFORM')
    records.run(['docker', 'buildx', 'imagetools', 'inspect', '--raw', base], 'base-index')
    index = parse((records.directory / records.commands[-1]['stdout']).read_bytes())
    require(any(x['digest'] == policy['deployment']['platform_manifest']
                and x['platform']['architecture'] == 'amd64' and x['platform']['os'] == 'linux'
                for x in index['manifests']), 'BASE_PLATFORM_MANIFEST')
    build = out / 'package-context'
    build.mkdir()
    shutil.copyfile(HERE / 'Dockerfile', build / 'Dockerfile')
    shutil.copyfile(ROOT / policy['release_artifact']['path'], build / 'gcd-selftest.elf')
    os.chmod(build / 'gcd-selftest.elf', 0o444)
    os.utime(build / 'gcd-selftest.elf', (0, 0))
    os.utime(build / 'Dockerfile', (0, 0))
    iid = out / 'image-id.txt'
    records.run(['docker', 'buildx', 'build', '--builder', 'desktop-linux', '--load', '--platform', 'linux/amd64',
                 '--provenance=false', '--sbom=false', '--network=none',
                 '--build-arg', 'SOURCE_DATE_EPOCH=0', '--iidfile', str(iid), str(build)], 'package-build')
    image = iid.read_text().strip()
    require(re.fullmatch('sha256:[0-9a-f]{64}', image), 'IMAGE_ID')
    _, data, _ = records.run(['docker', 'image', 'inspect', image], 'package-inspect')
    info = parse(data)[0]
    require(info['Id'] == image and info['RootFS']['Type'] == 'layers', 'PACKAGE_IDENTITY')
    # Image config ID binds all uncompressed layer digests. It is not reported
    # as an OCI distribution-manifest digest, which a local build may not have.
    descriptor = {'identity_kind': 'docker_image_config', 'sha256': image.removeprefix('sha256:'),
                  'base': base, 'base_platform_manifest': policy['deployment']['platform_manifest'],
                  'platform': 'linux/amd64', 'rootfs_diff_ids': info['RootFS']['Layers'],
                  'recipe_sha256': digest(HERE / 'Dockerfile'),
                  'elf_path': policy['deployment']['path'],
                  'elf_sha256': policy['release_artifact']['sha256'],
                  'build_command': 'docker buildx build --builder desktop-linux --load --platform linux/amd64 --provenance=false '
                                   '--sbom=false --network=none --build-arg SOURCE_DATE_EPOCH=0',
                  'end_to_end': False}
    # Inspect bytes from a real container made from the built package.
    _, data, _ = records.run(['docker', 'create', '--platform', 'linux/amd64', image], 'package-container')
    container = data.decode().strip()
    records.run(['docker', 'cp', container + ':' + policy['deployment']['path'],
                 str(out / 'packaged.elf')], 'package-extract')
    require(digest(out / 'packaged.elf') == policy['release_artifact']['sha256'], 'PACKAGE_ELF_MISMATCH')
    write(out / 'package.json', descriptor)
    return descriptor


def replay(policy, lock, implementation, request, out, records):
    pins = read(ROOT / 'toolchain/stage7-pins.json')
    prepared = Path(os.environ['FORGE_STAGE7_ROOT']).resolve()
    require(prepared.is_dir(), 'PREPARED_STAGE7_ROOT')
    require(files(prepared / '.toolchain/stage7/pydeps') == implementation['python_container_dependencies'],
            'UPSTREAM_PYTHON_DEPENDENCIES')
    attempt = 'stage9-' + request['challenge']
    name = 'forge-' + attempt
    linux = '/work/.forge-stage7/own-proof/' + attempt
    records.run(['docker', 'pull', '--platform', pins['platform'], pins['checker_image']], 'checker-pull')
    command = ['docker', 'run', '--name', name, '--pull', 'never', '--platform', pins['platform'],
               '--network', 'none', '--read-only', '--user', '1000:1000',
               '--cpuset-cpus', '0', '--memory', '4g', '--memory-swap', '4g', '--pids-limit', '512',
               '--ulimit', 'stack=-1:-1', '--tmpfs', '/tmp:rw,nosuid,nodev,size=256m',
               '-e', 'HOME=/tmp', '-e', 'PYTHONPATH=/pydeps', '-e', 'PYTHONDONTWRITEBYTECODE=1',
               '-e', 'DUNE_CACHE=disabled',
               '--mount', 'type=volume,source=' + pins['linux_volume'] + ',target=/work',
               '--mount', f'type=bind,source={prepared}/.toolchain/stage7/upstream/.git,target=/git-source,readonly',
               '--mount', f'type=bind,source={prepared}/.toolchain/stage7/pydeps,target=/pydeps,readonly',
               '--mount', f'type=bind,source={ROOT}/scripts,target=/forge-scripts,readonly',
               '--mount', f'type=bind,source={ROOT}/examples/binary,target=/forge-program,readonly',
               '--mount', f'type=bind,source={ROOT}/toolchain/stage7-pins.json,target=/forge-pins.json,readonly',
               '--mount', f'type=bind,source={ROOT}/toolchain/stage7-own-pins.json,target=/forge-own-pins.json,readonly',
               '-w', '/work', pins['checker_image'], 'python3', '/forge-scripts/stage7_own_job.py',
               '--attempt', attempt]
    # This always creates a new attempt. The unchanged Stage 7 job compiles both
    # proofs/bindings and invokes upstream _rocqchk over the full closure.
    code, _, _ = records.run(command, 'fresh-proof', check=False)
    proof = out / 'proof'
    proof.mkdir()
    collect, _, _ = records.run(['docker', 'cp', name + ':' + linux, str(proof / 'linux')],
                               'proof-collect', check=False)
    _, state, _ = records.run(['docker', 'inspect', name], 'proof-container-state')
    require(code == 0 and collect == 0 and not parse(state)[0]['State']['OOMKilled'], 'FRESH_PROOF_FAILED')
    # Archive hashes of the actual .vo inputs named by real rocqchk output.
    collector = ['python3', '-c',
        'import pathlib,re,hashlib,json; '
        f'p=pathlib.Path({linux!r})/"independent-kernel.log"; '
        'paths=re.findall(r"^\\[intern (.+\\.vo) \\.\\.\\.$",p.read_text(),re.M); '
        'print(json.dumps({n:hashlib.sha256(pathlib.Path(n).read_bytes()).hexdigest() for n in paths},sort_keys=True))']
    command2 = command[:command.index('-w')]  # same immutable mounts and resource limits
    command2[command2.index('--name') + 1] = name + '-closure'
    command2 += ['-w', '/work', pins['checker_image']] + collector
    _, closure, _ = records.run(command2, 'closure-input-hashes')
    write(proof / 'closure-identities.json', parse(closure))
    manifest = {'challenge': request['challenge'], 'source_commit': request['expected_source_commit'],
                'files': files(proof), 'end_to_end': False}
    write(proof / 'receipt.json', manifest)
    validate_receipt(proof, policy, lock, request)


def statement(policy, request, evidence, receipt, *, purpose='release'):
    return {'_type': policy['signature']['statement_type'],
            'predicateType': policy['signature']['predicate_type'],
            'subject': [{'name': 'forge:gcd-selftest.elf', 'digest': {'sha256': policy['release_artifact']['sha256']}},
                        {'name': 'forge:docker-image-config', 'digest': {'sha256': request['package_sha256']}}],
            'predicate': {'purpose': purpose, 'request': request,
                          'canonical_evidence_sha256': sha(canonical(evidence)),
                          'proof_receipt_sha256': receipt}}


def workflow(request, *, negative=False):
    require(os.environ.get('GITHUB_REPOSITORY') == 'mack-dot/forge'
            and os.environ.get('GITHUB_EVENT_NAME') == 'workflow_dispatch'
            and os.environ.get('GITHUB_REF') == 'refs/heads/main'
            and os.environ.get('GITHUB_SHA') == request['expected_source_commit'], 'WORKFLOW_CONTEXT')
    filename = 'provenance-negative.yml' if negative else 'provenance.yml'
    require(os.environ.get('GITHUB_WORKFLOW_REF') == 'mack-dot/forge/.github/workflows/' + filename
            + '@refs/heads/main', 'WORKFLOW_IDENTITY')
    require(os.environ.get('GITHUB_RUN_ATTEMPT') == '1', 'WORKFLOW_RERUN_REQUIRES_NEW_REQUEST')


def request_create(args, policy, lock, implementation):
    require(re.fullmatch('[0-9a-f]{40}', args.commit), 'SOURCE_COMMIT')
    require(not args.controller.exists(), 'CONTROLLER_ALREADY_EXISTS')
    args.output.mkdir(parents=True, exist_ok=False)
    records = Records(args.output / 'commands')
    package_info = package(policy, args.output, records)
    request = {'expected_source_commit': args.commit,
               'artifact_sha256': policy['release_artifact']['sha256'],
               'package_sha256': package_info['sha256'], 'package': package_info,
               'policy_id': policy['id'], 'policy_version': policy['version'], 'policy_epoch': policy['epoch'],
               'policy_sha256': digest(ROOT / 'policy/provenance.json'),
               'implementation_lock_sha256': args.implementation_sha256, 'challenge': secrets.token_hex(32)}
    require(not args.controller.resolve().is_relative_to(args.output.resolve()), 'CONTROLLER_OUTSIDE_OUTPUT')
    args.controller.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(args.controller)
    connection.execute('CREATE TABLE requests (challenge TEXT PRIMARY KEY, request BLOB NOT NULL, state TEXT NOT NULL)')
    connection.execute('INSERT INTO requests VALUES (?,?,?)', (request['challenge'], canonical(request), 'pending'))
    connection.commit()
    connection.close()
    os.chmod(args.controller, 0o600)
    write(args.output / 'request.json', request)


def produce(args, policy, lock, implementation, request):
    workflow(request)
    args.output.mkdir(parents=True, exist_ok=True)
    require(not any((args.output / name).exists() for name in ['commands', 'proof', 'controls', 'evidence.json']),
            'PRODUCER_OUTPUT_ALREADY_EXISTS')
    records = Records(args.output / 'commands')
    package_info = package(policy, args.output, records)
    require(package_info == request['package'], 'INDEPENDENT_PACKAGE_REPRODUCTION')
    replay(policy, lock, implementation, request, args.output, records)
    evidence = expected_canonical(policy, lock, args.implementation_sha256, package_info)
    write(args.output / 'evidence.json', evidence)
    require((args.output / 'evidence.json').read_bytes() == canonical(
        expected_canonical(policy, lock, args.implementation_sha256, package_info)), 'CANONICAL_REPRODUCTION')
    receipt = digest(args.output / 'proof/receipt.json')
    write(args.output / 'statement.json', statement(policy, request, evidence, receipt))
    write(args.output / 'request.json', request)
    # Deliberately invalid fixtures are separate, explicitly marked artifacts.
    # They do not become accepted evidence, even if signed by this workload.
    controls = args.output / 'controls'
    controls.mkdir()
    for name in ['wrong-policy', 'wrong-method', 'stale-request', 'wrong-spec']:
        directory = controls / name
        directory.mkdir()
        changed = copy.deepcopy(evidence)
        changed_request = copy.deepcopy(request)
        if name == 'wrong-policy':
            changed['policy']['version'] = '0.0.0-unapproved'
        elif name == 'wrong-method':
            changed['evidence'][0]['method'] = 'unit_tested'
        elif name == 'stale-request':
            changed_request['challenge'] = '0' * 64
        else:
            changed['spec_lock_sha256'] = '0' * 64
        write(directory / 'evidence.json', changed)
        write(directory / 'statement.json', statement(policy, changed_request, changed, receipt,
                                                       purpose='security-control'))
    wrong = controls / 'wrong-digest'
    wrong.mkdir()
    (wrong / 'different.bin').write_bytes(b'Forge Stage 9 wrong artifact control\n')
    s = statement(policy, request, evidence, receipt, purpose='security-control')
    s['subject'][0]['digest']['sha256'] = digest(wrong / 'different.bin')
    write(wrong / 'statement.json', s)
    context(args.implementation_sha256)


def sign(args, policy, lock, implementation, request):
    workflow(request, negative=args.action == 'negative-sign')
    require(read(args.output / 'request.json') == request, 'SIGNING_REQUEST_BINDING')
    validate_receipt(args.output / 'proof', policy, lock, request)
    require(read(args.output / 'evidence.json') == expected_canonical(
        policy, lock, args.implementation_sha256, request['package']), 'SIGNING_EVIDENCE_BINDING')
    expected = statement(policy, request, read(args.output / 'evidence.json'),
                         digest(args.output / 'proof/receipt.json'))
    require(read(args.output / 'statement.json') == expected, 'SIGNING_STATEMENT_BINDING')
    records = Records(args.output / ('negative-signing' if args.action == 'negative-sign' else 'signing'))
    env = clean_environment()
    binary = cosign_path(policy)
    records.run([binary, 'initialize'], 'signing-tuf-refresh', env=env)
    shutil.copytree(Path(env['HOME']) / '.sigstore/root', records.directory / 'validated-tuf')
    signing_statement = args.output / 'statement.json'
    if args.action == 'negative-sign':
        expected['predicate']['purpose'] = 'security-control'
        signing_statement = args.output / 'wrong-signer.statement.json'
        require(not signing_statement.exists(), 'NEGATIVE_FIXTURE_ALREADY_EXISTS')
        write(signing_statement, expected)
    selected = [(signing_statement, args.output / (
        'wrong-signer.sigstore.json' if args.action == 'negative-sign' else 'release.sigstore.json'))]
    if args.action == 'sign':
        controls = sorted((args.output / 'controls').glob('*/statement.json'))
        require({p.parent.name for p in controls} == {'wrong-policy', 'wrong-method', 'stale-request',
                                                     'wrong-spec', 'wrong-digest'}, 'SIGNING_CONTROL_SET')
        for source in controls:
            name = source.parent.name
            changed = copy.deepcopy(read(args.output / 'evidence.json'))
            changed_request = copy.deepcopy(request)
            if name == 'wrong-policy':
                changed['policy']['version'] = '0.0.0-unapproved'
            elif name == 'wrong-method':
                changed['evidence'][0]['method'] = 'unit_tested'
            elif name == 'stale-request':
                changed_request['challenge'] = '0' * 64
            elif name == 'wrong-spec':
                changed['spec_lock_sha256'] = '0' * 64
            controlled = statement(policy, changed_request, changed,
                                   digest(args.output / 'proof/receipt.json'), purpose='security-control')
            if name == 'wrong-digest':
                require((source.parent / 'different.bin').read_bytes() == b'Forge Stage 9 wrong artifact control\n',
                        'WRONG_ARTIFACT_FIXTURE')
                controlled['subject'][0]['digest']['sha256'] = digest(source.parent / 'different.bin')
            else:
                require(read(source.parent / 'evidence.json') == changed, 'CONTROL_EVIDENCE')
            require(read(source) == controlled, 'CONTROL_STATEMENT')
            selected.append((source, source.parent / 'control.sigstore.json'))
    for number, (source, target) in enumerate(selected):
        # No arbitrary command, key, root, identity or statement path is accepted.
        require(source.is_file() and not target.exists(), 'SIGNING_INPUT')
        records.run([binary, 'attest-blob', '--yes', '--statement', source, '--bundle', target],
                    f'sign-{number:02d}', env=env)
    context(args.implementation_sha256)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--action', choices=['request', 'produce', 'sign', 'negative-sign'], required=True)
    parser.add_argument('--implementation-sha256', required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--controller', type=Path)
    parser.add_argument('--commit')
    args = parser.parse_args()
    policy, lock, implementation = context(args.implementation_sha256)
    if args.action == 'request':
        require(args.controller is not None and args.commit is not None, 'REQUEST_ARGUMENTS')
        request_create(args, policy, lock, implementation)
    else:
        request = parse(os.environ['FORGE_STAGE9_REQUEST'])
        require(re.fullmatch('[0-9a-f]{64}', request['challenge']), 'CHALLENGE_FORMAT')
        require(request['implementation_lock_sha256'] == args.implementation_sha256,
                'IMPLEMENTATION_REQUEST_BINDING')
        {'produce': produce, 'sign': sign, 'negative-sign': sign}[args.action](
            args, policy, lock, implementation, request)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
