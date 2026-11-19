#!/usr/bin/env python3
"""Dispatch Stage 7 to a non-root, case-sensitive Linux checkout."""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PINS = json.loads((ROOT / 'toolchain/stage7-pins.json').read_text())


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=['upstream-replay', 'invalid-proof', 'own-proof'], required=True)
    args = parser.parse_args()
    prerequisite = None
    if args.case in ('invalid-proof', 'own-proof'):
        for path in sorted((ROOT / 'results/stage7/upstream-replay').glob('attempt-*/linux/report.json')):
            result = json.loads(path.read_text())
            outer = json.loads((path.parent.parent / 'report.json').read_text())
            if (result.get('result') == 'passed' and outer.get('result') == 'passed'
                    and result.get('independent_rocqchk') is True
                    and result.get('pins') == PINS
                    and result.get('artifact_sha') == PINS['upstream_binary_sha256']):
                prerequisite = {'report': str(path.relative_to(ROOT)),
                                'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        if prerequisite is None:
            parser.error('a complete upstream replay with these exact pins must pass first')
    negative = None
    if args.case == 'own-proof':
        own = json.loads((ROOT / 'toolchain/stage7-own-pins.json').read_text())
        for path in sorted((ROOT / 'results/stage7/invalid-proof').glob('attempt-*/linux/report.json')):
            result = json.loads(path.read_text())
            outer = json.loads((path.parent.parent / 'report.json').read_text())
            if (result.get('result') == 'passed' and outer.get('result') == 'passed'
                    and result.get('pins') == PINS and result.get('checker_exit_code') == 1
                    and result.get('true_certificate_exit_code') == 0):
                negative = {'report': str(path.relative_to(ROOT)),
                            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
        if negative is None:
            parser.error('the intended negative binding control must pass with these exact pins first')
    parent = ROOT / 'results/stage7' / args.case
    parent.mkdir(parents=True, exist_ok=True)
    number = 1
    while (parent / f'attempt-{number:04d}').exists():
        number += 1
    if number > 5:
        parser.error('five attempts retained; inspect the blocker')
    attempt = f'attempt-{number:04d}'
    dest = parent / attempt
    dest.mkdir()
    name = f'forge-stage7-{args.case}-{number:04d}'
    report = {'case': args.case, 'result': 'not_established', 'end_to_end': False, 'commands': []}
    if prerequisite is not None:
        report['upstream_prerequisite'] = prerequisite
    if negative is not None:
        report['negative_prerequisite'] = negative

    def run(command, label):
        (dest / (label + '-invocation.json')).write_text(json.dumps(command, indent=2) + '\n')
        with (dest / (label + '.log')).open('wb') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        report['commands'].append({'command': command, 'exit_code': result.returncode,
            'output_sha256': hashlib.sha256((dest / (label + '.log')).read_bytes()).hexdigest()})
        (dest / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
        return result.returncode

    command = ['docker', 'run', '--name', name, '--pull', 'never', '--platform', PINS['platform'],
               '--network', 'none', '--user', f"{PINS['container_uid']}:{PINS['container_gid']}",
               '--cpuset-cpus', PINS['cpuset'], '--memory', PINS['memory'],
               '--memory-swap', PINS['memory_swap'], '--pids-limit', str(PINS['pids_limit']),
               '--ulimit', 'stack=-1:-1', '-e', 'HOME=/tmp', '-e', 'PYTHONPATH=/pydeps',
               '-e', 'PYTHONDONTWRITEBYTECODE=1', '-e', 'DUNE_CACHE=disabled',
               '--mount', f"type=volume,source={PINS['linux_volume']},target=/work",
               '--mount', f"type=bind,source={ROOT / '.toolchain/stage7/upstream/.git'},target=/git-source,readonly",
               '--mount', f"type=bind,source={ROOT / '.toolchain/stage7/pydeps'},target=/pydeps,readonly",
               '--mount', f'type=bind,source={ROOT / "scripts"},target=/forge-scripts,readonly',
               '--mount', f'type=bind,source={ROOT / "tests/binary"},target=/forge-fixtures,readonly',
               '--mount', f'type=bind,source={ROOT / "toolchain/stage7-pins.json"},target=/forge-pins.json,readonly',
               '-w', '/work']
    if args.case == 'own-proof':
        command += ['--read-only', '--tmpfs', '/tmp:rw,nosuid,nodev,size=256m',
            '--mount', f'type=bind,source={ROOT / "examples/binary"},target=/forge-program,readonly',
            '--mount', f'type=bind,source={ROOT / "toolchain/stage7-own-pins.json"},target=/forge-own-pins.json,readonly']
    command += [PINS['checker_image'], 'python3']
    if args.case == 'upstream-replay':
        command += ['/forge-scripts/stage7_job.py', '--case', args.case]
    elif args.case == 'invalid-proof':
        command += ['/forge-scripts/stage7_negative.py']
    else:
        command += ['/forge-scripts/stage7_own_job.py']
    command += ['--attempt', attempt]
    print(f'Running {args.case}; logs in {dest.relative_to(ROOT)}', flush=True)
    code = run(command, 'container')
    inspect = run(['docker', 'inspect', '--format', '{{json .State}}', name], 'container-state')
    copied = run(['docker', 'cp', f'{name}:/work/.forge-stage7/{args.case}/{attempt}', str(dest / 'linux')], 'collect')
    if code != 0 or inspect != 0 or copied != 0:
        print((dest / 'container.log').read_text()[-5000:], flush=True)
        print(f'STAGE7_NOT_ESTABLISHED: container={code}, inspect={inspect}, collect={copied}', flush=True)
        return 1
    state = json.loads((dest / 'container-state.log').read_text())
    outcome = json.loads((dest / 'linux/report.json').read_text())
    assert not state['OOMKilled'] and state['ExitCode'] == 0 and outcome['result'] == 'passed'
    if args.case == 'own-proof':
        assert outcome['artifact_sha'] == own['binary_sha256']
        assert outcome['independent_rocqchk'] is True and outcome['valid_execution_witness']
    report.update(result='passed', independent_rocqchk=outcome['independent_rocqchk'],
                  artifact_sha=outcome['artifact_sha'])
    if 'checker_exit_code' in outcome:
        report['checker_exit_code'] = outcome['checker_exit_code']
    (dest / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')
    print(f'STAGE7_{args.case.upper().replace("-", "_")}_PASSED; see the recorded results for stage status.', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
