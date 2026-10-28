#!/usr/bin/env python3
"""Build the own C executable twice with the pinned published compiler image."""
import hashlib
import json
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    pins = json.loads((ROOT / 'toolchain/stage7-pins.json').read_text())
    own = json.loads((ROOT / 'toolchain/stage7-own-pins.json').read_text())
    parent = ROOT / 'results/stage7/own-build'
    parent.mkdir(parents=True, exist_ok=True)
    number = 1
    while (parent / f'attempt-{number:04d}').exists():
        number += 1
    dest = parent / f'attempt-{number:04d}'
    dest.mkdir()
    linux = f'/work/.forge-stage7/own-build/attempt-{number:04d}'
    name = f'forge-stage7-own-build-{number:04d}'
    source = ROOT / own['source']
    assert hashlib.sha256(source.read_bytes()).hexdigest() == own['source_sha256']
    shutil.copyfile(source, dest / source.name)
    shutil.copyfile(ROOT / 'toolchain/stage7-own-pins.json', dest / 'pins.json')
    report = {'result': 'not_established', 'proof_verdict': 'not_assessed_by_builder',
              'end_to_end': False, 'commands': [], 'pins': own}

    def save():
        (dest / 'report.json').write_text(json.dumps(report, sort_keys=True, indent=2) + '\n')

    def run(command, label):
        save()
        (dest / (label + '-invocation.json')).write_text(json.dumps(command, indent=2) + '\n')
        with (dest / (label + '.log')).open('wb') as stream:
            result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        report['commands'].append({'command': command, 'exit_code': result.returncode,
                                  'output_sha256': hashlib.sha256((dest / (label + '.log')).read_bytes()).hexdigest()})
        save()
        if result.returncode:
            print((dest / (label + '.log')).read_text(errors='replace')[-5000:])
            raise RuntimeError(f'{label}: actual exit {result.returncode}')

    base = ['docker', 'run', '--pull', 'never', '--platform', pins['platform'],
            '--network', 'none', '--read-only', '--user', '1000:1000',
            '--cpuset-cpus', pins['cpuset'], '--memory', pins['memory'],
            '--memory-swap', pins['memory_swap'], '--pids-limit', str(pins['pids_limit']),
            '--tmpfs', '/tmp:rw,nosuid,nodev,mode=1777', '-e', 'HOME=/tmp', '-e', 'LC_ALL=C',
            '--mount', f'type=volume,source={pins["linux_volume"]},target=/work',
            '--mount', f'type=bind,source={source.parent},target=/forge-program,readonly']

    def docker(argv, retain=False):
        return base + (['--name', name] if retain else ['--rm']) + [own['builder_image']] + argv

    run(docker(['mkdir', '-p', '/work/.forge-stage7/own-build']), 'parent-directory')
    run(docker(['mkdir', linux]), 'build-directory')
    flags = own['compiler_flags']
    for output, label in [('gcd-selftest.elf', 'compile'), ('gcd-selftest.rebuild.elf', 'rebuild')]:
        run(docker(['clang'] + flags + ['/forge-program/' + source.name, '-o', linux + '/' + output]), label)
    run(docker(['llvm-readelf', '-h', '-l', linux + '/gcd-selftest.elf']), 'elf-headers')
    run(docker(['llvm-objdump', '-d', linux + '/gcd-selftest.elf'], retain=True), 'disassembly')
    run(['docker', 'cp', f'{name}:{linux}', str(dest / 'artifacts')], 'collect')
    a = (dest / 'artifacts/gcd-selftest.elf').read_bytes()
    b = (dest / 'artifacts/gcd-selftest.rebuild.elf').read_bytes()
    assert a == b, 'REBUILD_BYTES_DIFFER'
    digest = hashlib.sha256(a).hexdigest()
    assert hashlib.sha256(source.read_bytes()).hexdigest() == own['source_sha256'], 'SOURCE_CHANGED'
    if own.get('binary_sha256') is not None:
        assert digest == own['binary_sha256'], 'PINNED_BINARY_MISMATCH'
    report.update(result='built_reproducibly', artifact_sha=digest, artifact_bytes=len(a),
                  source_sha=own['source_sha256'], identical_rebuild=True)
    save()
    print(json.dumps({'result': report['result'], 'artifact_sha': digest, 'bytes': len(a),
                      'proof_verdict': report['proof_verdict'], 'records': str(dest.relative_to(ROOT))}))
    return 0


if __name__ == '__main__':
    sys.exit(main())
