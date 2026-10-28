#!/usr/bin/env python3
"""Build the unapplied hosted-runner candidate on the mack-dot/forge boundary.

Implementation only: the approved contract, policy and spec lock stay
unchanged, and so does contract_approval_commit. Reads installed bytes that
must match the approved lock 9b10a237..., applies exact counted edits, and
writes candidate files, a new implementation lock, a unified diff and an
approval manifest under this directory. It never writes under gate/, spec/,
policy/ or .github/.
"""
import difflib
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = HERE / 'candidate'
INSTALLED_LOCK = '9b10a2376c6b6de46661819a528f3b4e1251f27d76ac21e071b1cfb971224a76'
SETUP = HERE.parent / 'provenance-hosted/src/hosted_setup.py'
SETUP_SHA = 'e8d5f1f6bfcfd784807b011cbdefe620c4c6e90eb84ea0fbcab774c6b63da057'
BUILDER = {'buildkit_version': 'v0.25.1', 'driver': 'docker-container',
           'image': 'moby/buildkit:v0.25.1@sha256:79cc6476ab1a3371c9afd8b44e7c55610057c43e18d9b39b68e2b0c2475cc1b6',
           'name': 'forge-pinned'}
SETUP_PYTHON = ('      - name: Python 3.10.11 required by the gate\n'
                '        uses: actions/setup-python@6d4fd22b20465ccc0f7354476588e8df7c9ca0e0 # v7.1.0\n'
                '        with:\n'
                '          python-version: 3.10.11\n')
SEED_ENV = ('        env:\n'
            '          FORGE_STAGE7_ROOT: ${{ runner.temp }}/seed\n')


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def edit(text, pairs):
    for old, new in pairs:
        assert text.count(old) == 1, ('EDIT_ANCHOR', old[:60], text.count(old))
        text = text.replace(old, new)
    return text


def runtime(old):
    controller = {
        'builder': BUILDER, 'buildx': old['buildx'], 'docker': old['docker'],
        'docker_components': old['docker_components'],
        'docker_platform': 'Docker Desktop ' + old['docker_desktop'],
        'image_store_driver': 'overlay2', 'kernel': old['kernel'], 'machine': 'arm64'}
    producer = {
        'builder': BUILDER,
        'buildx': 'github.com/docker/buildx v0.38.1 0dbe87f36ed472fe36b6796c3f70b4210a731fc5',
        'docker': {side: {'ApiVersion': '1.51', 'Arch': 'amd64', 'GitCommit': commit, 'Os': 'linux',
                          'Version': '28.5.1'} for side, commit in [('Client', 'e180ab8'), ('Server', 'f8215cc')]},
        'docker_apt': {
            'key_fingerprint': '9DC858229FC7DD38854AE2D88D81803C0EBFCD88',
            'key_url': 'https://download.docker.com/linux/ubuntu/gpg',
            'packages': {'containerd.io': '2.4.2-3~ubuntu.24.04~noble',
                         'docker-buildx-plugin': '0.38.1-1~ubuntu.24.04~noble',
                         'docker-ce': '5:28.5.1-1~ubuntu.24.04~noble',
                         'docker-ce-cli': '5:28.5.1-1~ubuntu.24.04~noble'},
            'source': 'deb [arch=amd64 signed-by=/etc/apt/keyrings/forge-docker.asc] '
                      'https://download.docker.com/linux/ubuntu noble stable'},
        'docker_components': {'Engine': '28.5.1', 'containerd': 'v2.4.2', 'docker-init': '0.19.0', 'runc': '1.5.2'},
        'docker_platform': 'Docker Engine - Community',
        'image_os': 'ubuntu24', 'image_store_driver': 'overlay2', 'kernel': None, 'machine': 'x86_64',
        'pip': {'sha256': '2913a38a2abf4ea6b64ab507bd9e967f3b53dc1ede74b01b0931e1ce548751af', 'version': '25.1.1'},
        'pydeps_python_path': '/Library/Frameworks/Python.framework/Versions/3.10/bin/python3',
        'runner_environment': 'github-hosted'}
    return {'end_to_end': False, 'format_version': 2, 'python': old['python'],
            'profiles': {'controller': controller, 'producer': producer}}


NEW_RUNTIME = '''def runtime(records):
    # The controller (macOS, Docker Desktop) and the hosted producer (Linux) use
    # separate pinned profiles. Both must build the same image-config identity.
    pins = read(HERE / 'runtime.json')
    profile = pins['profiles'][{'Darwin': 'controller', 'Linux': 'producer'}[platform.system()]]
    require(platform.machine() == profile['machine'], 'HOST_PLATFORM')
    if 'runner_environment' in profile:
        require(os.environ.get('RUNNER_ENVIRONMENT') == profile['runner_environment']
                and os.environ.get('ImageOS') == profile['image_os'], 'HOSTED_RUNNER')
    _, output, _ = records.run(['docker', 'version', '--format', '{{json .}}'], 'docker-version')
    value = parse(output)
    for side in ['Client', 'Server']:
        for key, expected in profile['docker'][side].items():
            require(value[side][key] == expected, 'DOCKER_VERSION:' + side + ':' + key)
    components = {c['Name']: c['Version'] for c in value['Server']['Components']}
    require(components == profile['docker_components'], 'DOCKER_COMPONENTS')
    # Hosted kernels change between images; the producer profile records, not pins, them.
    require(value['Server']['Platform']['Name'] == profile['docker_platform']
            and profile['kernel'] in (None, value['Server']['KernelVersion']), 'DOCKER_HOST_RUNTIME')
    _, output, _ = records.run(['docker', 'info', '--format', '{{json .}}'], 'docker-info')
    info = parse(output)
    # The image-config identity needs the classic image store (U081, U082).
    require(info['Driver'] == profile['image_store_driver']
            and ['driver-type', 'io.containerd.snapshotter.v1'] not in info['DriverStatus'], 'IMAGE_STORE')
    _, output, _ = records.run(['docker', 'buildx', 'version'], 'buildx-version')
    require(output.decode().strip() == profile['buildx'], 'BUILDX_VERSION')
    # rewrite-timestamp needs BuildKit's own exporter, so both profiles use one
    # pinned docker-container builder; the Docker driver ignores it (U093).
    builder = profile['builder']
    code, _, _ = records.run(['docker', 'buildx', 'inspect', builder['name']], 'builder-present', check=False)
    if code != 0:
        records.run(['docker', 'buildx', 'create', '--name', builder['name'], '--driver', builder['driver'],
                     '--driver-opt', 'image=' + builder['image']], 'builder-create')
    _, output, _ = records.run(['docker', 'buildx', 'inspect', '--bootstrap', builder['name']], 'builder-inspect')
    text = output.decode()
    require(re.search(r'^Driver:\\s+' + re.escape(builder['driver']) + r'\\s*$', text, re.M)
            and re.search(r'^BuildKit version:\\s+' + re.escape(builder['buildkit_version']) + r'\\s*$', text, re.M)
            and re.search(r'^Driver Options:\\s+image="' + re.escape(builder['image']) + r'"\\s*$', text, re.M),
            'BUILDER_VERSION')
    return profile
'''


def producer(text):
    start = text.index('def runtime(records):\n')
    end = text.index("'BUILDER_VERSION')\n", start) + len("'BUILDER_VERSION')\n")
    text = text[:start] + NEW_RUNTIME + text[end:]
    return edit(text, [
        ('import os\nfrom pathlib import Path\nimport re\n', 'import os\nfrom pathlib import Path\nimport platform\nimport re\n'),
        ('def package(policy, out, records):\n    runtime(records)\n',
         'def package(policy, out, records):\n    profile = runtime(records)\n'),
        ("    records.run(['docker', 'buildx', 'build', '--builder', 'desktop-linux', '--load', '--platform', 'linux/amd64',\n",
         "    # Without rewrite-timestamp, directory mtimes make every build differ (U093).\n"
         "    records.run(['docker', 'buildx', 'build', '--builder', profile['builder']['name'],\n"
         "                 '--output', 'type=docker,rewrite-timestamp=true', '--platform', 'linux/amd64',\n"),
        ("                  'build_command': 'docker buildx build --builder desktop-linux --load --platform linux/amd64 --provenance=false '\n"
         "                                   '--sbom=false --network=none --build-arg SOURCE_DATE_EPOCH=0',\n",
         "                  'build_command': 'docker buildx build --output type=docker,rewrite-timestamp=true '\n"
         "                                   '--platform linux/amd64 --provenance=false --sbom=false --network=none '\n"
         "                                   '--build-arg SOURCE_DATE_EPOCH=0',\n"
         "                  'buildkit_image': profile['builder']['image'],\n"),
    ])


def preflight(text):
    return edit(text, [
        ("        require(platform.system() == 'Darwin' and platform.machine() == 'arm64', 'RUNNER_PLATFORM')\n"
         "        listener = Path(os.environ['RUNNER_WORKSPACE']).parents[1] / 'bin/Runner.Listener'\n"
         "        _, version, _ = records.run([listener, '--version'], 'runner-version')\n"
         "        pins = read(HERE / 'runtime.json')\n"
         "        require(version.decode().strip() == pins['actions_runner']['version'], 'RUNNER_VERSION')\n",
         "        pins = read(HERE / 'runtime.json')['profiles']['producer']\n"
         "        require(platform.system() == 'Linux' and platform.machine() == pins['machine']\n"
         "                and os.environ.get('RUNNER_ENVIRONMENT') == pins['runner_environment']\n"
         "                and os.environ.get('ImageOS') == pins['image_os'], 'RUNNER_PLATFORM')\n"
         "        # GitHub updates hosted images and kernels; record them, they are not pinned.\n"
         "        write(records.directory / 'runner.json', {'image_os': os.environ['ImageOS'],\n"
         "                                                 'image_version': os.environ.get('ImageVersion'),\n"
         "                                                 'kernel': platform.release(), 'end_to_end': False})\n"),
        ("['executable_sha256']['darwin-arm64']", "['executable_sha256']['linux-amd64']"),
        ('/v3.1.4/cosign-darwin-arm64', '/v3.1.4/cosign-linux-amd64'),
    ])


def workflow_main(text):
    return edit(text, [
        ("    if: github.repository == 'mack-dot/forge' && github.ref == 'refs/heads/main'\n"
         "    runs-on: [self-hosted, macOS, ARM64, forge-stage9]\n",
         "    if: github.repository == 'mack-dot/forge' && github.ref == 'refs/heads/main'\n"
         "    runs-on: ubuntu-24.04\n    timeout-minutes: 300\n"),
        ("    needs: proof\n    runs-on: [self-hosted, macOS, ARM64, forge-stage9]\n",
         "    needs: proof\n    runs-on: ubuntu-24.04\n"),
        ("          persist-credentials: false\n      - name: Check runner and installed tool pins\n"
         "        run: python3 gate/provenance/preflight.py",
         "          persist-credentials: false\n" + SETUP_PYTHON
         + "      - name: Install pinned Docker and build Stage 7 prerequisites\n" + SEED_ENV
         + "        run: python3 gate/provenance/hosted_setup.py\n"
         "      - name: Check runner and installed tool pins\n" + SEED_ENV
         + "        run: python3 gate/provenance/preflight.py"),
        ("      - name: Package and run fresh independent proof checks\n",
         "      - name: Package and run fresh independent proof checks\n" + SEED_ENV),
        ("          persist-credentials: false\n      - name: Retrieve this run's proof job output\n",
         "          persist-credentials: false\n" + SETUP_PYTHON + "      - name: Retrieve this run's proof job output\n"),
        ('        run: python3 gate/provenance/preflight.py --implementation-sha256 "$FORGE_STAGE9_IMPLEMENTATION"\n'
         '      - name: Sign exact release statement',
         SEED_ENV + '        run: python3 gate/provenance/preflight.py --implementation-sha256 "$FORGE_STAGE9_IMPLEMENTATION"\n'
         '      - name: Sign exact release statement'),
    ])


def workflow_negative(text):
    return edit(text, [
        ("    if: github.repository == 'mack-dot/forge' && github.ref == 'refs/heads/main'\n"
         "    runs-on: [self-hosted, macOS, ARM64, forge-stage9]\n",
         "    if: github.repository == 'mack-dot/forge' && github.ref == 'refs/heads/main'\n"
         "    runs-on: ubuntu-24.04\n"),
        ("          persist-credentials: false\n      - name: Check pins and authenticate producer run metadata\n",
         "          persist-credentials: false\n" + SETUP_PYTHON
         + "      - name: Check pins and authenticate producer run metadata\n" + SEED_ENV),
    ])


def unified(path, old, new):
    lines = list(difflib.unified_diff(old.decode().splitlines(True), new.decode().splitlines(True),
                                      'a/' + path if old else '/dev/null', 'b/' + path, n=3))
    header = [f'diff --git a/{path} b/{path}\n'] + (['new file mode 100644\n'] if not old else [])
    return ''.join(header + lines)


def main():
    lock_path = ROOT / 'gate/provenance/implementation.lock'
    assert sha(lock_path.read_bytes()) == INSTALLED_LOCK, 'INSTALLED_LOCK'
    lock = json.loads(lock_path.read_bytes())
    inputs = {path: (ROOT / path).read_bytes() for path in [
        'gate/provenance/runtime.json', 'gate/provenance/producer.py', 'gate/provenance/preflight.py',
        '.github/workflows/provenance.yml', '.github/workflows/provenance-negative.yml']}
    for path, data in inputs.items():
        assert sha(data) == lock['files'][path], ('INSTALLED_INPUT', path)
    setup = SETUP.read_bytes()
    assert sha(setup) == SETUP_SHA, 'SETUP_SOURCE'
    new = {
        'gate/provenance/runtime.json': dump(runtime(json.loads(inputs['gate/provenance/runtime.json']))),
        'gate/provenance/producer.py': producer(inputs['gate/provenance/producer.py'].decode()).encode(),
        'gate/provenance/preflight.py': preflight(inputs['gate/provenance/preflight.py'].decode()).encode(),
        '.github/workflows/provenance.yml': workflow_main(inputs['.github/workflows/provenance.yml'].decode()).encode(),
        '.github/workflows/provenance-negative.yml':
            workflow_negative(inputs['.github/workflows/provenance-negative.yml'].decode()).encode(),
        'gate/provenance/hosted_setup.py': setup,
    }
    for path, data in new.items():
        lock['files'][path] = sha(data)
    new['gate/provenance/implementation.lock'] = dump(lock)
    patch, manifest = [], {'base_lock_sha256': INSTALLED_LOCK, 'contract_unchanged': True,
                           'end_to_end': False, 'files': {}}
    for path in sorted(new):
        old = (ROOT / path).read_bytes() if (ROOT / path).exists() else b''
        target = OUT / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(new[path])
        patch.append(unified(path, old, new[path]))
        manifest['files'][path] = {'old_sha256': sha(old) if old else None, 'new_sha256': sha(new[path])}
    diff = ''.join(patch).encode()
    (HERE / 'proposed.diff').write_bytes(diff)
    manifest.update(diff_sha256=sha(diff), new_lock_sha256=sha(new['gate/provenance/implementation.lock']))
    (HERE / 'approval-manifest.json').write_bytes(dump(manifest))
    print(json.dumps({k: manifest[k] for k in ('diff_sha256', 'new_lock_sha256')}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
