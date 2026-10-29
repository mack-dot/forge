"""Prepare a fresh GitHub-hosted runner for the Stage 9 proof job.

Install the pinned Docker packages and build the Stage 7 prerequisites from
pinned sources. This never signs, never judges a proof and never deletes a
prior attempt. Every command and its exit code is recorded.
"""
import os
from pathlib import Path
import shutil
import sys
import tempfile

from common import ROOT, HERE, Records, context, digest, files, read, require, write

UPSTREAM = '.toolchain/stage7/upstream'


def docker(pins, records):
    apt = pins['docker_apt']
    work = Path(tempfile.mkdtemp())
    key = work / 'docker.asc'
    records.run(['curl', '-fsSL', apt['key_url'], '-o', key], 'docker-key-fetch')
    _, output, _ = records.run(['gpg', '--show-keys', '--with-colons', key], 'docker-key-show')
    fingerprints = [line.split(':')[9] for line in output.decode().splitlines() if line.startswith('fpr:')]
    # The exact key file, not only its first fingerprint (U104, F4).
    require(digest(key) == apt['key_sha256'] and fingerprints[:1] == [apt['key_fingerprint']],
            'DOCKER_APT_KEY')
    source = work / 'forge-docker.list'
    source.write_text(apt['source'] + '\n')
    records.run(['sudo', 'install', '-m', '0644', key, '/etc/apt/keyrings/forge-docker.asc'], 'docker-key-install')
    records.run(['sudo', 'install', '-m', '0644', source, '/etc/apt/sources.list.d/forge-docker.list'],
                'docker-source-install')
    records.run(['sudo', 'apt-get', 'update', '-q'], 'apt-update')
    records.run(['sudo', 'apt-get', 'install', '-y', '-q', '--allow-downgrades']
                + [name + '=' + version for name, version in sorted(apt['packages'].items())], 'docker-install')
    _, output, _ = records.run(['dpkg-query', '-W', '-f', '${Package}=${Version}\\n'] + sorted(apt['packages']),
                               'docker-packages')
    require(dict(line.split('=', 1) for line in output.decode().split()) == apt['packages'], 'DOCKER_PACKAGES')


def seed(root, stage7, own, implementation, pins, records):
    require(not root.exists(), 'SEED_ALREADY_EXISTS')
    upstream = root / UPSTREAM
    commit = stage7['upstream_commit']
    records.run(['git', 'init', '-q', upstream], 'upstream-init')
    records.run(['git', '-C', upstream, 'fetch', '-q', '--depth', '1', stage7['upstream_repository'] + '.git', commit],
                'upstream-fetch')
    records.run(['git', '-C', upstream, 'checkout', '-q', '--detach', commit], 'upstream-checkout')
    _, head, _ = records.run(['git', '-C', upstream, 'rev-parse', 'HEAD'], 'upstream-head')
    require(head.decode().strip() == commit, 'UPSTREAM_COMMIT')
    pip = pins['pip']
    requirement = Path(tempfile.mkdtemp()) / 'pip.txt'
    requirement.write_text(f"pip=={pip['version']} --hash=sha256:{pip['sha256']}\n")
    records.run([sys.executable, '-m', 'pip', 'install', '--disable-pip-version-check', '--require-hashes',
                 '-r', requirement], 'pip-pin')
    # The approved dependency lock was made on macOS, and pip writes the
    # interpreter path into bin/idna. Run the recorded command through that path.
    link = Path(pins['pydeps_python_path'])
    records.run(['sudo', 'mkdir', '-p', link.parent], 'pydeps-python-directory')
    records.run(['sudo', 'ln', '-s', sys.executable, link], 'pydeps-python-link')
    records.run([link, '-m', 'pip', 'install', '--require-hashes', '--only-binary=:all:', '--platform',
                 'manylinux2014_x86_64', '--python-version', '3.12', '--implementation', 'cp', '--abi', 'cp312',
                 '--target', '.toolchain/stage7/pydeps', '--no-compile', '--disable-pip-version-check',
                 '--no-input', '--no-deps', '-r', UPSTREAM + '/tools/oft/requirements.txt'],
                'python-dependencies', cwd=root)
    require(files(root / '.toolchain/stage7/pydeps') == implementation['python_container_dependencies'],
            'UPSTREAM_PYTHON_DEPENDENCIES')
    uid, gid = stage7['container_uid'], stage7['container_gid']
    # A Linux bind mount keeps host ownership; the container user must own it (U089).
    records.run(['sudo', 'chown', '-R', f'{uid}:{gid}', upstream / '.git'], 'seed-git-owner')
    # Private-repository runners may have less disk; fail explicitly (U109).
    places = [root.parent] + [Path(p) for p in ['/var/lib/docker'] if Path(p).exists()]
    free = min(shutil.disk_usage(p).free for p in places)
    write(records.directory / 'disk.json', {'free_bytes_before_pulls': free,
                                           'required_bytes': pins['min_free_disk_bytes']})
    require(free >= pins['min_free_disk_bytes'], 'DISK_SPACE')
    for image in [stage7['checker_image'], own['builder_image']]:
        records.run(['docker', 'pull', '--platform', stage7['platform'], image], 'image-pull')
    code, _, _ = records.run(['docker', 'volume', 'inspect', stage7['linux_volume']], 'volume-absent', check=False)
    require(code != 0, 'VOLUME_ALREADY_EXISTS')
    records.run(['docker', 'volume', 'create', stage7['linux_volume']], 'volume-create')
    base = ['docker', 'run', '--rm', '--pull', 'never', '--platform', stage7['platform'], '--network', 'none',
            '--user', f'{uid}:{gid}', '--cpuset-cpus', stage7['cpuset'], '--memory', stage7['memory'],
            '--memory-swap', stage7['memory_swap'], '--pids-limit', str(stage7['pids_limit']),
            '--mount', 'type=volume,source=' + stage7['linux_volume'] + ',target=/work',
            '--mount', f'type=bind,source={upstream}/.git,target=/git-source,readonly',
            '-w', '/work', stage7['checker_image']]
    records.run(base + ['git', '-c', 'safe.directory=/git-source', 'clone', '--shared', '--no-checkout',
                        '/git-source', '.'], 'volume-clone')
    records.run(base + ['git', 'checkout', '--detach', commit], 'volume-checkout')
    # The unchanged build script numbers attempts from its own root. A staging
    # root without prior records builds attempt-0001 in the fresh volume.
    staging = Path(tempfile.mkdtemp())
    for path in ['scripts/stage7_build_own.py', 'toolchain/stage7-pins.json', 'toolchain/stage7-own-pins.json',
                 own['source']]:
        (staging / path).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(ROOT / path, staging / path)
    records.run([sys.executable, staging / 'scripts/stage7_build_own.py'], 'own-build')
    shutil.copytree(staging / 'results/stage7/own-build', records.directory / 'own-build')


def main():
    _, _, implementation = context(os.environ['FORGE_STAGE9_IMPLEMENTATION'])
    require(os.environ.get('GITHUB_JOB') == 'proof', 'APPROVED_JOB')
    pins = read(HERE / 'runtime.json')['profiles']['producer']
    require(os.environ.get('RUNNER_ENVIRONMENT') == pins['runner_environment']
            and os.environ.get('ImageOS') == pins['image_os'], 'HOSTED_RUNNER')
    records = Records(ROOT / 'results/stage9/producer-output/hosted-setup')
    docker(pins, records)
    seed(Path(os.environ['FORGE_STAGE7_ROOT']).resolve(), read(ROOT / 'toolchain/stage7-pins.json'),
         read(ROOT / 'toolchain/stage7-own-pins.json'), implementation, pins, records)
    write(records.directory / 'result.json', {'result': 'prepared', 'end_to_end': False})
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
