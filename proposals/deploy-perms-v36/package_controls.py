"""Package-binding controls on v3.6 with the checkout's real release and producer code (no signing).

  python3 -I -B package_controls.py CODE_ROOT LOCK OUTPUT V36_PACKAGE_DIR V35_PACKAGE_DIR SUBSTITUTED_IMAGE

A package directory holds package.json, package-identity/ and packaged.elf, as
producer.package() writes them. Exit 0 when every case gets its expected outcome.
"""
import json
from pathlib import Path
import shutil
import subprocess
import sys

code, lock, OUT = sys.argv[1], sys.argv[2], Path(sys.argv[3]).resolve()
V36, V35, SUBST = Path(sys.argv[4]), Path(sys.argv[5]), sys.argv[6]
sys.path.insert(0, code + '/gate/provenance')
from common import Records, Rejected, context, read, write  # noqa: E402
import producer  # noqa: E402
import release  # noqa: E402

policy, _, _ = context(lock)
OUT.mkdir(parents=True, exist_ok=False)
results = []


def request_for(directory, **override):
    package = read(directory / 'package.json')
    return dict({'package': package, 'package_sha256': package['sha256'],
                 'artifact_sha256': policy['release_artifact']['sha256']}, **override)


def fixture(name, source):
    target = OUT / name
    for item in ['package.json', 'packaged.elf']:
        target.mkdir(exist_ok=True)
        shutil.copyfile(source / item, target / item)
    shutil.copytree(source / 'package-identity', target / 'package-identity')
    return target


def case(name, expected, fn):
    try:
        fn()
        observed = 'ACCEPTED'
    except Rejected as error:
        observed = error.reason
    ok = observed.startswith(expected)
    results.append({'case': name, 'expected': expected, 'observed': observed, 'pass': ok})
    print('PASS' if ok else 'FAIL', '|', name, '| expected', expected, '| observed', observed, flush=True)


case('v3.6 package accepted by the v3.6 package check', 'ACCEPTED',
     lambda: release.validate_package(policy, request_for(V36), V36))
case('v3.5 package refused by v3.6 (recipe is bound to the Dockerfile)', 'PACKAGE_DESCRIPTOR_FIELDS',
     lambda: release.validate_package(policy, request_for(V35), V35))


def flip_layer():
    target = fixture('tampered-layer', V36)
    manifest = read(target / 'package-identity/manifest.json')[0]
    blob = target / 'package-identity' / manifest['Layers'][-1]
    data = bytearray(blob.read_bytes())
    data[len(data) // 2] ^= 1
    blob.write_bytes(bytes(data))
    release.validate_package(policy, request_for(target), target)


case('added layer byte flipped', 'PACKAGE_BLOB_DIGEST', flip_layer)


def substitute_elf():
    target = fixture('substituted-packaged-elf', V36)
    data = bytearray((target / 'packaged.elf').read_bytes())
    data[-1] ^= 1
    (target / 'packaged.elf').write_bytes(bytes(data))
    release.validate_package(policy, request_for(target), target)


case('packaged.elf substituted', 'PACKAGED_ELF_BYTES', substitute_elf)
case('request names another package digest', 'PACKAGE_DESCRIPTOR_FIELDS',
     lambda: release.validate_package(policy, request_for(V36, package_sha256=read(V35 / 'package.json')['sha256']), V36))


def substituted_image():
    info = json.loads(subprocess.run(['docker', 'image', 'inspect', SUBST], capture_output=True, check=True).stdout)[0]
    descriptor = dict(read(V36 / 'package.json'), sha256=SUBST.removeprefix('sha256:'),
                      rootfs_diff_ids=info['RootFS']['Layers'])
    target = OUT / 'substituted-image'
    target.mkdir()
    producer.package_identity(policy, SUBST, descriptor, target, Records(target / 'records'))


case('image whose layer carries substituted ELF bytes (producer.package_identity)', 'PACKAGE_FILESYSTEM_ELF:substituted',
     substituted_image)
write(OUT / 'results.json', {'results': results, 'end_to_end': False})
bad = [r for r in results if not r['pass']]
print('cases', len(results), 'not passing', len(bad))
sys.exit(1 if bad else 0)
