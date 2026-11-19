#!/usr/bin/env python3
"""Run the published checker without modifying its functions or verdicts."""
import argparse
import hashlib
import json
import os
import subprocess
import sys
from pathlib import Path


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--case', choices=['upstream-replay'], required=True)
    p.add_argument('--attempt', required=True)
    a = p.parse_args()
    pins = json.loads(Path('/forge-pins.json').read_text())
    dest = Path('/work/.forge-stage7') / a.case / a.attempt
    dest.mkdir(parents=True, exist_ok=False)
    (dest / 'tmp').mkdir()
    os.environ['TMPDIR'] = str(dest / 'tmp')
    report = {'case': a.case, 'result': 'not_established', 'end_to_end': False,
              'commands': [], 'uid': os.getuid(), 'gid': os.getgid(), 'pins': pins}

    def save():
        (dest / 'report.json').write_text(json.dumps(report, indent=2, sort_keys=True) + '\n')

    def run(command, label):
        with (dest / (label + '.log')).open('wb') as stream:
            r = subprocess.run(command, stdout=stream, stderr=subprocess.STDOUT)
        record = {'command': command, 'cwd': '/work', 'exit_code': r.returncode,
                  'output_sha256': hashlib.sha256((dest / (label + '.log')).read_bytes()).hexdigest()}
        report['commands'].append(record)
        save()
        print(json.dumps(record), flush=True)
        return r.returncode

    assert os.getuid() == pins['container_uid'] and os.getgid() == pins['container_gid']
    identity = ['python3', '/forge-scripts/stage7_identity.py', '--commit', pins['upstream_commit']]
    if run(identity + ['--output', str(dest / 'before')], 'identity-before') != 0:
        return 1
    before = json.loads((dest / 'before/identity.json').read_text())
    assert before['binary_sha256'] == pins['upstream_binary_sha256'], 'BINARY_DIGEST_MISMATCH'
    versions = [(['rocq', '--version'], 'rocq-version'),
                (['rocqchk', '--version'], 'rocqchk-version'),
                (['dune', '--version'], 'dune-version'),
                (['python3', '--version'], 'python-version'),
                (['git', '--version'], 'git-version'),
                (['opam', 'list', '--root=/home/opam/.opam', '--switch=4.14', '--installed',
                  '--columns=name,version', '--short'], 'opam-packages'),
                (['python3', '-c', 'import yaml,idna; print(yaml.__version__); print(idna.__version__)'], 'python-packages')]
    for command, label in versions:
        if run(command, label) != 0:
            return 1
    expected = {'rocq-version': 'version 9.2', 'rocqchk-version': '9.2',
                'dune-version': pins['dune'], 'python-version': pins['python_container'],
                'git-version': pins['git_container']}
    for label, version in expected.items():
        assert version in (dest / (label + '.log')).read_text(), 'TOOL_VERSION_MISMATCH: ' + label
    assert (dest / 'python-packages.log').read_text().splitlines() == [pins['pyyaml'], pins['idna']]
    command = ['python3', '/forge-scripts/stage7_trace_processes.py', str(dest / 'checker-processes.jsonl'),
               'check', pins['upstream_replay'], '--parts', 'statements,proofs', '--rocqchk']
    code = run(command, 'checker')
    if code != 0:
        print((dest / 'checker.log').read_text()[-6000:], flush=True)
        return 1
    processes = [json.loads(x) for x in (dest / 'checker-processes.jsonl').read_text().splitlines()]
    kernels = [x for x in processes if x['command'][0] == 'rocqchk']
    proof_compiles = [x for x in processes if x['command'][:2] == ['rocq', 'compile']]
    assert len(kernels) == 2 and all(x['exit_code'] == 0 for x in kernels), 'INDEPENDENT_CHECK_MISSING'
    assert len(proof_compiles) >= 2 and all(x['exit_code'] == 0 for x in proof_compiles), 'PROOF_COMPILE_MISSING'
    text = (dest / 'checker.log').read_text()
    assert ('proves ' + pins['upstream_statement'] + '; assumptions:') in text
    assert 'oft check: 2 step(s) passed, 0 failed;' in text
    if run(identity + ['--output', str(dest / 'after')], 'identity-after') != 0:
        return 1
    after = json.loads((dest / 'after/identity.json').read_text())
    assert before['tracked_sha256_manifest'] == after['tracked_sha256_manifest'], 'SOURCE_CHANGED'
    assert before['binary_sha256'] == after['binary_sha256'], 'BINARY_CHANGED'
    report.update(result='passed', method='binary_proof', artifact_sha=before['binary_sha256'],
                  independent_rocqchk=True, rocqchk_commands=kernels,
                  scope='Pinned upstream zlib binary and its published LPS halts statement only.')
    save()
    print('UPSTREAM_REPLAY_PASSED_WITH_INDEPENDENT_CHECK', flush=True)
    return 0


if __name__ == '__main__':
    sys.exit(main())
