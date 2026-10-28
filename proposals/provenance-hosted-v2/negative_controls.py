"""Negative controls for the v2 candidate's package identity (artifact boundary).

Run from a scratch copy with the v2 candidate applied. Uses real Docker,
BuildKit and the candidate's own gate functions. Signs nothing, publishes
nothing. Each attack must end in its expected rejection, and the positive
control must pass. Exit 0 only if every expectation holds.
"""
import argparse
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'gate/provenance'))

from common import Records, Rejected, context, parse, read, require, write  # noqa: E402
import producer  # noqa: E402

WRONG_BUILDKIT = ('moby/buildkit:v0.24.0@sha256:'
                  '6eceb8971ce4fceb3daca562832642706238b7eea72941fcf9896c93c3c4a53e')


def build(records, label, elf, builder, output):
    """Build the approved recipe around the given ELF bytes; return the image ID."""
    context_dir = Path(tempfile.mkdtemp())
    shutil.copyfile(producer.HERE / 'Dockerfile', context_dir / 'Dockerfile')
    (context_dir / 'gcd-selftest.elf').write_bytes(elf)
    os.chmod(context_dir / 'gcd-selftest.elf', 0o444)
    for name in ('Dockerfile', 'gcd-selftest.elf'):
        os.utime(context_dir / name, (0, 0))
    iid = context_dir / 'image-id.txt'
    records.run(['docker', 'buildx', 'build', '--builder', builder] + output
                + ['--platform', 'linux/amd64', '--provenance=false', '--sbom=false', '--network=none',
                   '--build-arg', 'SOURCE_DATE_EPOCH=0', '--iidfile', iid, context_dir], label)
    return iid.read_text().strip()


def expect(results, name, expected, action):
    try:
        action()
        observed = 'ACCEPTED'
    except Rejected as error:
        observed = error.reason
    passed = observed == 'ACCEPTED' if expected == 'ACCEPTED' else observed.startswith(expected)
    results.append({'control': name, 'expected': expected, 'observed': observed, 'pass': passed})
    print(json.dumps(results[-1]), flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--implementation-sha256', required=True)
    parser.add_argument('--controller-descriptor', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    policy, _, _ = context(args.implementation_sha256)
    approved = read(args.controller_descriptor)
    elf = (ROOT / policy['release_artifact']['path']).read_bytes()
    pinned = read(producer.HERE / 'runtime.json')['profiles']['controller']['builder']
    records = Records(args.output / 'commands')
    results = []

    # Positive control: the pinned builder reproduces the approved package.
    (args.output / 'positive').mkdir()
    def positive():
        require(producer.package(policy, args.output / 'positive', records) == approved, 'DESCRIPTOR_DIFFERS')
    expect(results, 'positive: pinned builder reproduces the approved package', 'ACCEPTED', positive)

    # Attack 1: swap the ELF after approval. The image is built correctly but
    # holds one extra byte; release-time identity must reject it.
    tampered = build(records, 'tampered-build', elf + b'\x00', pinned['name'],
                     ['--output', 'type=docker,rewrite-timestamp=true'])
    (args.output / 'attack-elf').mkdir()
    expect(results, 'attack: substituted ELF presented under the approved descriptor', 'PACKAGE_CONFIG_IDENTITY',
           lambda: producer.package_identity(policy, tampered, approved, args.output / 'attack-elf', records))
    (args.output / 'attack-elf-own').mkdir()
    own = dict(approved, sha256=tampered.removeprefix('sha256:'))
    expect(results, 'attack: substituted ELF under a descriptor naming its own config', 'PACKAGE_ROOTFS_BINDING',
           lambda: producer.package_identity(policy, tampered, own, args.output / 'attack-elf-own', records))
    # Strongest form: the descriptor matches the tampered image completely.
    _, data, _ = records.run(['docker', 'image', 'inspect', tampered], 'tampered-inspect')
    full = dict(own, rootfs_diff_ids=parse(data)[0]['RootFS']['Layers'])
    (args.output / 'attack-elf-full').mkdir()
    expect(results, 'attack: substituted ELF under a fully self-consistent descriptor', 'PACKAGE_FILESYSTEM_ELF',
           lambda: producer.package_identity(policy, tampered, full, args.output / 'attack-elf-full', records))

    # Attack 2: build the same recipe the old way (Docker driver, no timestamp
    # rewrite). Its layer differs, so it must not pass as the approved package.
    legacy = build(records, 'legacy-build', elf, 'desktop-linux', ['--load'])
    (args.output / 'attack-legacy').mkdir()
    expect(results, 'attack: unpinned build presented under the approved descriptor', 'PACKAGE_CONFIG_IDENTITY',
           lambda: producer.package_identity(policy, legacy, approved, args.output / 'attack-legacy', records))

    # Attack 3: replace the pinned builder with a different BuildKit image.
    records.run(['docker', 'buildx', 'rm', pinned['name']], 'builder-remove')
    records.run(['docker', 'buildx', 'create', '--name', pinned['name'], '--driver', 'docker-container',
                 '--driver-opt', 'image=' + WRONG_BUILDKIT], 'builder-substitute')
    expect(results, 'attack: substituted BuildKit image under the pinned builder name', 'BUILDER_VERSION',
           lambda: producer.runtime(records))
    records.run(['docker', 'buildx', 'rm', pinned['name']], 'builder-cleanup')

    write(args.output / 'results.json', {'controls': results, 'end_to_end': False,
                                          'not_run': ['containerd image store (needs a Docker Desktop setting change)']})
    return 0 if all(r['pass'] for r in results) else 1


if __name__ == '__main__':
    sys.exit(main())
