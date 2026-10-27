#!/usr/bin/env python3
"""Apply the published ELF loader, Rocq pipeline, and audits to Forge's ELF."""
import argparse
import hashlib
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--attempt', required=True)
    args = parser.parse_args()
    pins = json.loads(Path('/forge-pins.json').read_text())
    own = json.loads(Path('/forge-own-pins.json').read_text())
    dest = Path('/work/.forge-stage7/own-proof') / args.attempt
    dest.mkdir(parents=True, exist_ok=False)
    src = dest / 'source'
    src.mkdir()
    (src / 'images').mkdir()
    (dest / 'wrap').mkdir()
    report = {'case': 'own-proof', 'result': 'not_established', 'end_to_end': False,
              'commands': [], 'pins': pins, 'own_pins': own,
              'uid': os.getuid(), 'gid': os.getgid()}

    def save():
        (dest / 'report.json').write_text(json.dumps(report, sort_keys=True, indent=2) + '\n')

    def run(command, label, cwd='/work'):
        with (dest / (label + '.log')).open('wb') as stream:
            result = subprocess.run(command, cwd=cwd, stdout=stream, stderr=subprocess.STDOUT)
        report['commands'].append({'command': command, 'cwd': str(cwd), 'exit_code': result.returncode,
                                  'output_sha256': digest(dest / (label + '.log'))})
        save()
        print(json.dumps(report['commands'][-1]), flush=True)
        if result.returncode:
            print((dest / (label + '.log')).read_text(errors='replace')[-6000:], flush=True)
            raise RuntimeError(f'{label}: actual exit {result.returncode}')

    assert (os.getuid(), os.getgid()) == (pins['container_uid'], pins['container_gid'])
    identity = ['python3', '/forge-scripts/stage7_identity.py', '--commit', pins['upstream_commit']]
    run(identity + ['--output', str(dest / 'before')], 'identity-before')
    assert digest(own['linux_binary']) == own['binary_sha256'], 'OWN_BINARY_MISMATCH'
    shutil.copyfile(own['linux_binary'], dest / 'gcd-selftest.elf')
    for name, expected in own['proof_source_sha256'].items():
        original = Path('/forge-program') / name
        assert digest(original) == expected, 'OWN_SOURCE_MISMATCH: ' + name
        shutil.copyfile(original, src / name)
    assert digest('/forge-program/gcd_selftest.c') == own['source_sha256']
    shutil.copyfile('/forge-program/gcd_selftest.c', dest / 'gcd_selftest.c')
    run(['rocq', '--version'], 'rocq-version')
    run(['rocqchk', '--version'], 'rocqchk-version')
    assert 'version 9.2' in (dest / 'rocq-version.log').read_text()
    assert '9.2' in (dest / 'rocqchk-version.log').read_text()
    run(['dune', 'build', '--root', '/work', '--display', 'short', '-j', '1',
         'theories/Images.vo', 'theories/Shapes.vo'], 'published-dependencies')
    run(['elf-snapshot', str(dest / 'gcd-selftest.elf'), str(src / 'images/Program.v'),
         '--prefix', 'Program', '--module-name', 'M', '--namespace', 'Forge.Binary.images'],
        'elf-snapshot', cwd=src / 'images')
    q = ['-Q', '/work/_build/default/theories', 'OssFuzzTheorems.Core',
         '-Q', str(src), 'Forge.Binary']
    generated = sorted((src / 'images').glob('*.v'))
    run(['rocq', 'dep', '-sort'] + q + [str(p) for p in generated], 'image-dependencies', cwd=src)
    order = (dest / 'image-dependencies.log').read_text().split()
    assert order and all(Path(p).is_file() and Path(p).parent == src / 'images' for p in order)
    for i, path in enumerate(order):
        run(['rocq', 'compile'] + q + [path], f'image-compile-{i:03d}', cwd=src)
    for name in ['Images', 'Statements', 'Execution', 'Proof']:
        run(['rocq', 'compile'] + q + [str(src / (name + '.v'))], 'compile-' + name, cwd=src)

    # These are the exact published template and audit implementations.
    sys.path.insert(0, '/work/tools')
    from oft.check import WRAPPER, allowed_axioms, wrapper_assumptions, _rocqchk
    allow = allowed_axioms('/work', 'toolchain/allowed-axioms.txt')
    wrapper = dest / 'wrap/Wrapper.v'
    wrapper.write_text(WRAPPER.format(stmt_mod='Forge.Binary.Statements', proof_mod='Forge.Binary.Proof',
                                    neg='', stmt='selftest_halts', args='', theorem='selftest_halts_holds'))
    wq = q + ['-Q', str(dest / 'wrap'), 'ForgeChecked']
    run(['rocq', 'compile'] + wq + [str(wrapper)], 'binding-wrapper', cwd=src)
    axioms = wrapper_assumptions((dest / 'binding-wrapper.log').read_text())
    assert not (axioms - allow), 'UNAPPROVED_THEOREM_ASSUMPTIONS'
    report['theorem_assumptions'] = sorted(axioms)
    report['binding_wrapper_sha256'] = digest(wrapper)
    save()

    # Observe the real subprocess return while the unchanged published audit runs.
    processes = []
    run_code = subprocess.run.__code__
    def trace(frame, event, arg):
        if frame.f_code is run_code and event == 'return' and isinstance(arg, subprocess.CompletedProcess):
            processes.append({'command': arg.args, 'exit_code': arg.returncode})
            (dest / 'independent-processes.json').write_text(json.dumps(processes, sort_keys=True, indent=2) + '\n')
        return trace
    sys.settrace(trace)
    try:
        count = _rocqchk('/work', wq, ['ForgeChecked.Wrapper'], allow, str(dest / 'independent-kernel.log'))
    finally:
        sys.settrace(None)
    kernels = [p for p in processes if p['command'][0] == 'rocqchk']
    assert len(kernels) == 1 and kernels[0]['exit_code'] == 0, 'INDEPENDENT_CHECK_MISSING'
    report['rocqchk_commands'] = kernels
    report['independent_closure_assumption_count'] = count
    save()
    run(identity + ['--output', str(dest / 'after')], 'identity-after')
    before = json.loads((dest / 'before/identity.json').read_text())
    after = json.loads((dest / 'after/identity.json').read_text())
    assert before['tracked_sha256_manifest'] == after['tracked_sha256_manifest'], 'UPSTREAM_SOURCE_CHANGED'
    assert digest(own['linux_binary']) == own['binary_sha256'], 'BUILD_BINARY_CHANGED'
    assert digest(dest / 'gcd-selftest.elf') == own['binary_sha256'], 'CHECKED_BINARY_CHANGED'
    for name, expected in own['proof_source_sha256'].items():
        assert digest(src / name) == expected and digest(Path('/forge-program') / name) == expected, 'OWN_SOURCE_CHANGED'
    report.update(result='passed', method='kernel_checked_proof', independent_rocqchk=True,
                  artifact_sha=own['binary_sha256'],
                  theorem='Forge.Binary.Statements.selftest_halts',
                  scope='The exact fixed-input C self-test exits normally with status 0 under the pinned LPS model.')
    save()
    print('OWN_BINARY_PROOF_PASSED_WITH_INDEPENDENT_CHECK', flush=True)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
