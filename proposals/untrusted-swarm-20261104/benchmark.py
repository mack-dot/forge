#!/usr/bin/env python3
"""FUSE-1 prerequisite harness. Dispatch and identity checks only; never certify.

No semantic verifier is implemented here. Real kernel/compiler trials require
the missing independent runner, broker and execution binding from PROTOCOL.md.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import time

sys.dont_write_bytecode = True
BASE = Path(__file__).resolve().parent
ROOT = BASE.parent.parent
OUT = ROOT / 'results/untrusted-swarm-20261104'
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
PACKET = ROOT / 'proposals/refund-executable-feasibility'


def canonical(value):
    return (json.dumps(value, sort_keys=True, indent=2, ensure_ascii=False) + '\n').encode()


def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()


def put(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open('xb') as stream:
        stream.write(canonical(value))


def read(path):
    return json.loads(path.read_bytes())


def relative(path):
    return str(path.relative_to(ROOT))


def protected_files():
    # Generated __pycache__ is not an approved input. Include every other file.
    files = [ROOT / 'spec.lock']
    for folder in ('spec', 'policy', 'gate'):
        files.extend(p for p in (ROOT / folder).rglob('*')
                     if p.is_file() and '__pycache__' not in p.parts)
    return sorted(set(files))


def freeze():
    if (BASE / 'FREEZE.json').exists() or (BASE / 'FREEZE.sha256').exists():
        raise ValueError('Freeze already exists; retain it and create a new protocol version')
    sources = [ROOT / task['source'] for task in read(BASE / 'tasks.json')]
    sources.extend(ROOT / claim['source'] for claim in read(BASE / 'claims.json')['required'])
    tools = [TC / n for n in (
        'HOL/bin/Holmake', 'HOL/bin/hol', 'poly-install/bin/poly',
        'cakeml/misc/cakeml-heap', 'cakeml/cv_translator/cake_compile_heap')]
    archive = [PACKET / n for n in (
        'arm8-compile-20261104/records/compile-repeat/command.json',
        'arm8-compile-20261104/records/compile-repeat/forge_refundArm8CompileScript.sml',
        'native-execution-20261104/records/native-build-0001/refund',
        'native-execution-20261104/records/compiled-extraction/code.bin',
        'native-execution-20261104/records/identity-0001/result.json')]
    package = [p for p in BASE.rglob('*') if p.is_file()
               and '__pycache__' not in p.parts and p.name != 'FREEZE.sha256']
    inputs = protected_files() + sources + tools + archive + package
    manifest = {relative(p): digest(p) for p in sorted(set(inputs))}
    journal = (ROOT / 'unsure.md').read_bytes()
    result = {
        'protocol': 'FUSE-1', 'scope': 'prerequisite evaluation only',
        'scored_trials_ready': False, 'files': manifest,
        'protected_paths': [relative(p) for p in protected_files()],
        'execution_tools': {str(p): digest(p) for p in map(Path, (
            sys.executable, '/usr/bin/shasum', '/usr/bin/perl', '/usr/bin/sandbox-exec'))},
        'execution_tool_scope': 'Entry files pinned. OS and dynamic runtime closure remain assumptions.',
        'journal_prefix': {'bytes': len(journal),
                           'sha256': hashlib.sha256(journal).hexdigest()},
        'end_to_end': False,
    }
    put(BASE / 'FREEZE.json', result)
    (BASE / 'FREEZE.sha256').write_text(digest(BASE / 'FREEZE.json') + '  FREEZE.json\n')
    print(json.dumps({'files': len(manifest), 'freeze_sha256': digest(BASE / 'FREEZE.json')}))
    return 0


def verify_freeze():
    expected = (BASE / 'FREEZE.sha256').read_text().split()[0]
    if digest(BASE / 'FREEZE.json') != expected:
        raise ValueError('FREEZE_IDENTITY_CHANGED')
    frozen = read(BASE / 'FREEZE.json')
    changed = [name for name, sha in frozen['files'].items()
               if not (ROOT / name).is_file() or digest(ROOT / name) != sha]
    if changed:
        raise ValueError('FROZEN_INPUT_CHANGED: ' + repr(changed))
    for name, sha in frozen['execution_tools'].items():
        if digest(Path(name)) != sha:
            raise ValueError('EXECUTION_TOOL_CHANGED: ' + name)
    if [relative(p) for p in protected_files()] != frozen['protected_paths']:
        raise ValueError('PROTECTED_FILE_SET_CHANGED')
    prefix = frozen['journal_prefix']
    current = (ROOT / 'unsure.md').read_bytes()
    if hashlib.sha256(current[:prefix['bytes']]).hexdigest() != prefix['sha256']:
        raise ValueError('JOURNAL_PREFIX_CHANGED')
    return frozen


def run_command(directory, name, argv, cwd=None):
    cwd = cwd or directory
    start = time.monotonic()
    launch_error = None
    try:
        child = subprocess.run(argv, cwd=cwd, capture_output=True)
        actual_exit, out_bytes, err_bytes = child.returncode, child.stdout, child.stderr
    except OSError as error:
        actual_exit, out_bytes, err_bytes = None, b'', str(error).encode()
        launch_error = {'errno': error.errno, 'message': str(error)}
    elapsed = time.monotonic() - start
    stdout, stderr = directory / (name + '.stdout'), directory / (name + '.stderr')
    stdout.write_bytes(out_bytes)
    stderr.write_bytes(err_bytes)
    record = {'name': name, 'argv': argv, 'cwd': str(cwd),
              'actual_exit': actual_exit, 'launch_error': launch_error,
              'stdout': stdout.name, 'stdout_sha256': digest(stdout),
              'stderr': stderr.name, 'stderr_sha256': digest(stderr)}
    put(directory / (name + '.json'), record)
    return record, {'name': name, 'wall_seconds': elapsed}


def seal(directory):
    members = {str(p.relative_to(directory)): digest(p)
               for p in sorted(directory.rglob('*')) if p.is_file() and not p.is_symlink()}
    put(directory / 'MANIFEST.json', members)
    put(BASE / 'anchors' / (directory.name + '.json'), {
        'freeze_sha256': digest(BASE / 'FREEZE.json'),
        'manifest_sha256': digest(directory / 'MANIFEST.json'),
        'authority': 'Local readback anchor only; not authenticated or agent-isolated storage'})


def preflight(run_id):
    frozen = verify_freeze()
    directory = OUT / run_id
    directory.mkdir(parents=True, exist_ok=False)
    put(directory / 'start.json', {'protocol': 'FUSE-1',
        'freeze_sha256': digest(BASE / 'FREEZE.json'), 'phase': 'PREFLIGHT',
        'scored_trial': False, 'end_to_end': False})
    commands, telemetry = [], []

    # Use real archived native bytes only for a file-integrity control.
    # No loader, signing, linking or native execution occurs.
    native = PACKET / 'native-execution-20261104/records/native-build-0001/refund'
    identity = read(PACKET / 'native-execution-20261104/records/identity-0001/result.json')
    expected = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
    if digest(native) != expected:
        raise ValueError('BASELINE_NATIVE_IDENTITY_CHANGED')
    original = directory / 'original-refund.bin'
    original.write_bytes(native.read_bytes())
    mutant = directory / 'substituted-refund.bin'
    data = bytearray(original.read_bytes())
    offset = identity['mutated_file_offset']
    code = (PACKET / 'native-execution-20261104/records/compiled-extraction/code.bin').read_bytes()
    baseline = identity['builds'][0]
    if (offset != baseline['code_file_offset'] or len(code) != baseline['code_bytes']
            or hashlib.sha256(code).hexdigest() != baseline['code_sha256']
            or data[offset:offset + len(code)] != code):
        raise ValueError('COMPILER_CODE_PAYLOAD_BINDING_CHANGED')
    data[offset] ^= 1
    mutant.write_bytes(data)
    original.chmod(0o600)
    mutant.chmod(0o600)
    (directory / 'original.sha256').write_text(expected + '  original-refund.bin\n')
    (directory / 'substituted.sha256').write_text(expected + '  substituted-refund.bin\n')
    for name in ('original', 'substituted'):
        command, metric = run_command(directory, name + '-digest',
            ['/usr/bin/shasum', '-a', '256', '-c', name + '.sha256'])
        commands.append(command)
        telemetry.append(metric)
    if commands[0]['actual_exit'] != 0 or commands[1]['actual_exit'] != 1:
        raise ValueError('IDENTITY_CONTROL_INCONCLUSIVE')
    if b'FAILED' not in (directory / 'substituted-digest.stdout').read_bytes():
        raise ValueError('IDENTITY_REFUSAL_REASON_MISSING')

    # Confine a benign canary process. Never run an untrusted candidate here.
    own = directory / 'sandbox/own'
    peer = directory / 'sandbox/peer'
    checker = directory / 'sandbox/checker'
    for path in (own, peer, checker):
        path.mkdir(parents=True)
    for path in (peer / 'canary.txt', checker / 'canary.txt'):
        path.write_text('synthetic canary; not a real secret\n')
    (own / 'readonly.txt').write_text('synthetic frozen input\n')
    (own / 'link-to-peer').symlink_to(peer / 'canary.txt')
    # This narrow probe tests denial mechanics. It is not the complete role profile.
    def q(path):
        return json.dumps(str(path))
    profile = ('(version 1)\n(allow default)\n(deny network*)\n'
               '(deny file-read* file-write* (subpath ' + q(peer) + ') '
               '(subpath ' + q(checker) + '))\n'
               '(deny file-write* (literal ' + q(own / 'readonly.txt') + '))\n')
    profile_file = directory / 'canary.sb'
    profile_file.write_text(profile)
    argv = ['/usr/bin/sandbox-exec', '-f', str(profile_file), sys.executable,
            '-I', '-B', str(BASE / 'isolation_probe.py'), str(own), str(peer), str(checker)]
    command, metric = run_command(directory, 'sandbox-canary', argv)
    commands.append(command)
    telemetry.append(metric)
    (own / 'link-to-peer').unlink()
    # Preserve the observation, then remove only this synthetic link if created.
    hardlink = own / 'hardlink'
    if hardlink.exists():
        hardlink.unlink()
    capability = read(BASE / 'capabilities.json')
    blockers = [key for key, value in capability['requirements'].items()
                if value['status'] != 'ESTABLISHED']
    if command['actual_exit'] != 0:
        blockers.append('benign_os_canary_failed')
    else:
        probe = json.loads((directory / 'sandbox-canary.stdout').read_bytes())
        if not probe.get('all_expected_observations'):
            blockers.append('benign_os_canary_incomplete')
    # Even a successful narrow OS probe cannot establish per-agent tool isolation.
    verify_freeze()
    result = {'protocol': 'FUSE-1', 'phase': 'PREFLIGHT', 'scored_trial': False,
        'actual_exit': 2 if blockers else 0, 'status': 'BLOCKED' if blockers else 'READY',
        'blockers': blockers, 'commands': commands,
        'file_identity_control': {'original_exit': commands[0]['actual_exit'],
            'substitution_exit': commands[1]['actual_exit'], 'offset': offset,
            'original_sha256': digest(original), 'substituted_sha256': digest(mutant),
            'scope': 'File digest only; no semantic or native correctness claim'},
        'protected_files_unchanged': len(frozen['protected_paths']),
        'kernel_trial': 'NOT_RUN', 'compiler_trial': 'NOT_RUN',
        'native_execution': 'NOT_RUN', 'signing': 'NOT_RUN',
        'scored_cells': 0, 'end_to_end': False}
    put(directory / 'result.json', result)
    put(directory / 'telemetry.json', {'scope': 'setup only', 'commands': telemetry,
        'model_tokens': None, 'model_cost': None, 'scored_human_interventions': None})
    seal(directory)
    print(json.dumps({'status': result['status'], 'actual_exit': result['actual_exit'],
                      'blockers': blockers, 'commands': [(c['name'], c['actual_exit']) for c in commands]}))
    return result['actual_exit']


def validate(run_id):
    frozen = verify_freeze()
    directory = OUT / run_id
    anchor_path = BASE / 'anchors' / (run_id + '.json')
    if anchor_path.is_symlink() or not stat.S_ISREG(anchor_path.lstat().st_mode):
        raise ValueError('UNSAFE_ANCHOR_TYPE')
    anchor = read(anchor_path)
    if anchor['freeze_sha256'] != digest(BASE / 'FREEZE.json'):
        raise ValueError('RESULT_FREEZE_MISMATCH')
    if anchor['manifest_sha256'] != digest(directory / 'MANIFEST.json'):
        raise ValueError('RESULT_MANIFEST_CHANGED')
    if read(directory / 'start.json')['freeze_sha256'] != anchor['freeze_sha256']:
        raise ValueError('START_FREEZE_MISMATCH')
    members = read(directory / 'MANIFEST.json')
    for name, sha in members.items():
        path = Path(name)
        if path.is_absolute() or '..' in path.parts or not path.parts:
            raise ValueError('UNSAFE_MANIFEST_MEMBER')
        target = directory / path
        if target.is_symlink() or not target.is_file() or target.stat().st_nlink != 1:
            raise ValueError('UNSAFE_MEMBER_TYPE')
        if digest(target) != sha:
            raise ValueError('RESULT_CHANGED: ' + name)
    actual = set()
    for path in directory.rglob('*'):
        mode = path.lstat().st_mode
        if stat.S_ISREG(mode) and path.stat().st_nlink == 1:
            actual.add(str(path.relative_to(directory)))
        elif not stat.S_ISDIR(mode):
            raise ValueError('UNSAFE_RESULT_ENTRY: ' + str(path))
    report_names = {'comparison.json', 'COMPARISON.md', 'REPORT_MANIFEST.json'}
    present_reports = actual & report_names
    if present_reports:
        if present_reports != report_names:
            raise ValueError('INCOMPLETE_REPORT')
        report_anchor_path = BASE / 'anchors' / (run_id + '-report.json')
        if report_anchor_path.is_symlink() or not stat.S_ISREG(report_anchor_path.lstat().st_mode):
            raise ValueError('UNSAFE_REPORT_ANCHOR_TYPE')
        report_anchor = read(report_anchor_path)
        if report_anchor['freeze_sha256'] != anchor['freeze_sha256']:
            raise ValueError('REPORT_FREEZE_MISMATCH')
        if report_anchor['report_manifest_sha256'] != digest(directory / 'REPORT_MANIFEST.json'):
            raise ValueError('REPORT_MANIFEST_CHANGED')
        reports = read(directory / 'REPORT_MANIFEST.json')
        if set(reports) != report_names - {'REPORT_MANIFEST.json'}:
            raise ValueError('REPORT_MEMBERS_CHANGED')
        if any(digest(directory / name) != sha for name, sha in reports.items()):
            raise ValueError('REPORT_CHANGED')
    if actual != set(members) | {'MANIFEST.json'} | present_reports:
        raise ValueError('RESULT_MEMBER_SET_CHANGED')
    result = read(directory / 'result.json')
    for command in result['commands']:
        for stream in ('stdout', 'stderr'):
            if digest(directory / command[stream]) != command[stream + '_sha256']:
                raise ValueError('COMMAND_OUTPUT_CHANGED')
    if result['scored_cells'] != 0 or result['end_to_end']:
        raise ValueError('PREFLIGHT_SCOPE_CHANGED')
    print(json.dumps({'actual_exit': 0, 'result_files': len(members),
        'protected_files': len(frozen['protected_paths']), 'scope': 'readback, not proof'}))
    return 0


def report(run_id):
    validate(run_id)
    directory = OUT / run_id
    result = read(directory / 'result.json')
    rows = []
    for arm in ('single', 'cooperative', 'adversarial'):
        rows.append({'arm': arm, 'scheduled_cells': 6, 'attempted_cells': 0,
            'status': 'NOT_RUN', 'verified_completion': None,
            'false_acceptance': None, 'justified_rejection': None,
            'proof_coverage': None, 'latency_seconds': None, 'tokens': None,
            'compute_cost': None, 'human_interventions': None})
    put(directory / 'comparison.json', {'protocol': 'FUSE-1', 'rows': rows,
        'comparison_valid': False, 'cause': result['blockers'], 'end_to_end': False})
    lines = ['# FUSE-1 comparison', '',
        'No scored cell ran. No fair three-arm comparison is established.',
        'A prerequisite failure is not evidence for or against swarm reliability.',
        'The planned task scope is bounded syntax-slot synthesis, not unrestricted',
        'software evolution. Setup reference patches are excluded from participant inputs.',
        'The six named role reviews and later setup reviews are not trial data.', '',
        '| Arm | Scheduled | Attempted | Completion / false acceptance / rejection |',
        '| --- | ---: | ---: | --- |']
    lines += ['| ' + row['arm'] + ' | 6 | 0 | NOT_MEASURED |' for row in rows]
    lines += ['', 'All proof coverage, latency, compute cost and human intervention',
        'metrics for scored cells are null. This is not evidence of zero false accepts.', '',
        '## Actual prerequisite results', '', '| Command | Actual exit |', '| --- | ---: |']
    lines += ['| `' + command['name'] + '` | ' + str(command['actual_exit']) + ' |'
              for command in result['commands']]
    lines += ['', 'The digest refusal establishes changed file bytes only. No native',
        'mutant was executed. No fresh kernel or compiler trial ran.', '', '## Blockers', '']
    lines += ['- ' + blocker for blocker in result['blockers']]
    lines += ['', '## Architecture recommendations', '',
        '1. Give each role an OS-enforced workspace and a narrow tool broker. Test',
        '   read, write, link, process and socket boundaries with synthetic canaries.',
        '2. Make the checker own replay, dependencies, logs and exit capture. Reject',
        '   producer heaps and executable proof programs. Render restricted proposals',
        '   into a frozen harness that calls existing HOL and CakeML tools.',
        '3. Bind each request, candidate, claim, compiler output and complete input',
        '   closure in a controller-owned ledger. Hashes alone are not provenance.',
        '4. Add authoritative model usage and aggregate process-resource metering.',
        '   Reserve one total budget per arm and charge every message and retry.',
        '5. Keep source proofs, kernel semantics, compile equations, file identity,',
        '   finite tests and open native premises as separate claim records.',
        '6. Preserve failed controls and unattempted denominators. Freeze hidden',
        '   corpus commitments and execution bindings before fresh participant calls.', '',
        'CURRENT none; M1 open; Stage 12 unauthorized; end_to_end=false.', '']
    with (directory / 'COMPARISON.md').open('x') as stream:
        stream.write('\n'.join(lines))
    put(directory / 'REPORT_MANIFEST.json', {name: digest(directory / name)
        for name in ('comparison.json', 'COMPARISON.md')})
    put(BASE / 'anchors' / (run_id + '-report.json'), {
        'report_manifest_sha256': digest(directory / 'REPORT_MANIFEST.json'),
        'freeze_sha256': digest(BASE / 'FREEZE.json'),
        'authority': 'Local readback only, not authenticated or access-isolated'})
    print(json.dumps({'actual_exit': 0, 'comparison_valid': False, 'scored_cells': 0}))
    return 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('freeze', 'preflight', 'validate', 'report'))
    parser.add_argument('--run', default='preflight-0001')
    args = parser.parse_args()
    if not re.fullmatch(r'[a-z0-9][a-z0-9-]{0,63}', args.run):
        parser.error('run ID must be a plain local identifier')
    if args.command == 'freeze':
        return freeze()
    if args.command == 'preflight':
        try:
            return preflight(args.run)
        except (OSError, ValueError, KeyError) as error:
            directory = OUT / args.run
            if (directory / 'start.json').exists() and not (directory / 'result.json').exists():
                commands = [read(p) for p in sorted(directory.glob('*.json'))
                            if p.name != 'start.json' and 'argv' in read(p)]
                put(directory / 'result.json', {'protocol': 'FUSE-1', 'phase': 'PREFLIGHT',
                    'actual_exit': 2, 'status': 'INFRASTRUCTURE_FAILURE',
                    'scored_trial': False, 'scored_cells': 0, 'end_to_end': False,
                    'commands': commands, 'blockers': [str(error)],
                    'kernel_trial': 'NOT_RUN', 'compiler_trial': 'NOT_RUN',
                    'native_execution': 'NOT_RUN', 'signing': 'NOT_RUN'})
                link = directory / 'sandbox/own/link-to-peer'
                if link.is_symlink():
                    link.unlink()
                seal(directory)
            print('PREFLIGHT_ERROR: ' + str(error), file=sys.stderr)
            return 2
    return {'validate': validate, 'report': report}[args.command](args.run)


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError) as error:
        print('PREFLIGHT_ERROR: ' + str(error), file=sys.stderr)
        sys.exit(2)
