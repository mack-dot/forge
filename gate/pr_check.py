#!/usr/bin/env python3
"""Run the trusted gate for an exact PR revision; emit an operational receipt."""

import argparse
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys

from common import ROOT, canonical, digest, read_json


def git_head(directory):
    child = subprocess.run(['git', '-C', str(directory), 'rev-parse', '--verify', 'HEAD'],
                           capture_output=True, text=True)
    if child.returncode:
        raise RuntimeError('REVISION_ERROR: ' + child.stderr)
    return child.stdout.strip()


def require_clean_tracked_files(directory):
    child = subprocess.run(['git', '-C', str(directory), 'diff', '--quiet',
                            '--exit-code', 'HEAD', '--'], capture_output=True, text=True)
    if child.returncode:
        raise RuntimeError('REVISION_ERROR: tracked files differ from the checked revision: '
                           + str(directory) + '\n' + child.stderr)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    args = parser.parse_args()
    candidate = args.candidate.resolve()
    event = read_json(Path(os.environ['GITHUB_EVENT_PATH']))
    pr = event['pull_request']
    repository = os.environ['GITHUB_REPOSITORY']
    base_sha, head_sha = pr['base']['sha'], pr['head']['sha']
    if (repository != 'mack-dot/forge' or event['repository']['full_name'] != repository
            or pr['base']['repo']['full_name'] != repository or pr['base']['ref'] != 'main'
            or not all(re.fullmatch('[0-9a-f]{40}', value) for value in (base_sha, head_sha))):
        raise RuntimeError('REVISION_ERROR: unexpected repository, base branch, or revision')
    if git_head(ROOT) != base_sha or git_head(candidate) != head_sha:
        raise RuntimeError('REVISION_ERROR: checked-out revisions differ from the GitHub event')
    for directory in (ROOT, candidate):
        require_clean_tracked_files(directory)
    run_id = int(os.environ['GITHUB_RUN_ID'])
    number = int(pr['number'])
    if run_id <= 0 or number <= 0:
        raise RuntimeError('REVISION_ERROR: invalid run or PR number')
    folder = ROOT / 'build/pr'
    folder.mkdir(parents=True, exist_ok=True)
    evidence = folder / 'evidence.json'
    work = folder / 'check'
    command = [sys.executable, 'gate/incremental.py', '--profile', 'linux',
               '--candidate', str(candidate), '--evidence', str(evidence.relative_to(ROOT)),
               '--work', str(work.relative_to(ROOT))]
    allowed = ('PATH', 'HOME', 'TMPDIR', 'LANG', 'LC_ALL', 'LD_LIBRARY_PATH', 'DOTNET_ROOT')
    environment = {name: os.environ[name] for name in allowed if name in os.environ}
    environment['PATH'] = str(Path(sys.executable).parent) + os.pathsep + environment.get('PATH', os.defpath)
    environment['PYTHONNOUSERSITE'] = '1'
    child = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, env=environment)
    (folder / 'gate.log').write_text(child.stdout + child.stderr)
    print(child.stdout + child.stderr, end='', flush=True)
    if child.returncode not in (0, 1, 2, 3):
        raise RuntimeError('CHECKER_PROCESS_ERROR: unexpected exit ' + str(child.returncode))
    operation = read_json(work / 'operation.json')
    if operation['exit_code'] != child.returncode:
        raise RuntimeError('RESULT_ERROR: gate exit and operational receipt differ')
    bundle = read_json(evidence) if child.returncode == 0 else None
    if (child.returncode != 0 and evidence.exists()) or (bundle and bundle['end_to_end']):
        raise RuntimeError('RESULT_ERROR: stale evidence or unsupported coverage')
    outcomes = {0: 'VERIFIED', 1: 'REJECTED', 2: 'NOT_ESTABLISHED', 3: 'UNSUPPORTED'}
    if operation.get('outcome') != outcomes[child.returncode]:
        raise RuntimeError('RESULT_ERROR: gate outcome and exit code differ')
    if child.returncode == 0 and not operation.get('coverage', {}).get('covered'):
        raise RuntimeError('RESULT_ERROR: exit 0 without an established coverage record')
    replay = None
    if bundle:
        # Execute the exact saved command under the same trusted environment.
        replay_cmd = bundle['evidence'][0]['reproduce_cmd']
        replay_run = subprocess.run(shlex.split(replay_cmd), cwd=ROOT, capture_output=True,
                                    text=True, env=environment)
        (folder / 'replay.log').write_text(replay_run.stdout + replay_run.stderr)
        replay = {'command': replay_cmd, 'exit_code': replay_run.returncode,
                  'byte_identical': replay_run.returncode == 0 and
                  (ROOT / 'build/change-evidence.json').read_bytes() == evidence.read_bytes()}
        if not replay['byte_identical']:
            raise RuntimeError('REPRODUCTION_ERROR: the actual replay did not reproduce identical evidence')
    for directory in (ROOT, candidate):
        require_clean_tracked_files(directory)
    receipt = {
        'format_version': 1, 'repository': repository, 'pr_number': number,
        'base_sha': base_sha, 'head_sha': head_sha, 'run_id': run_id,
        'run_url': 'https://github.com/' + repository + '/actions/runs/' + str(run_id),
        'command': shlex.join(command), 'exit_code': child.returncode,
        'result': operation['result'], 'outcome': operation['outcome'],
        'coverage': operation.get('coverage'), 'operation': operation, 'replay': replay,
        'evidence_sha256': digest(evidence.read_bytes()) if bundle else None,
        'evidence': bundle, 'end_to_end': False,
    }
    (folder / 'receipt.json').write_bytes(canonical(receipt))
    print('FORGE_PR_RESULT ' + json.dumps({key: receipt[key] for key in
          ('pr_number', 'base_sha', 'head_sha', 'exit_code', 'outcome', 'evidence_sha256')}), flush=True)
    # These bounded chunks retain the real receipt when a connector cannot open ZIP artifacts.
    encoded = json.dumps(receipt, sort_keys=True, separators=(',', ':'))
    for start in range(0, len(encoded), 12000):
        print('FORGE_PR_RECEIPT_CHUNK ' + json.dumps({'offset': start, 'text': encoded[start:start + 12000]}), flush=True)
    with open(os.environ['GITHUB_OUTPUT'], 'a') as stream:
        stream.write('report_ready=true\n')
    return child.returncode


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
