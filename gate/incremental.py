#!/usr/bin/env python3
"""Check a ledger candidate against this trusted checkout using Dafny snapshots.

Only Dafny/Boogie choose cached verification results. This gate checks input
identity, audit output, checker success, obligation coverage, and policy.
The caller must obtain this checkout from a trusted revision, outside the PR.
"""

import argparse
import json
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True

from common import ROOT, Rejected, canonical, digest, relative
from dependencies import check_dependencies
from backends import dafny


PROTECTED_DIRS = ('gate', 'policy', 'spec', 'toolchain', 'schemas', '.github')
PROTECTED_FILES = ('spec.lock', 'AGENTS.md')
SOURCE_FILES = ('impl/Ledger.dfy', 'spec/LedgerSpec.dfy', 'gate/ContractBinding.dfy')
OBLIGATIONS = dafny.REQUIRED_RESULTS | {
    'Ledger.TotalRemove (correctness)', 'Ledger.TotalRemove (well-formedness)',
    'Ledger.TotalReplace (correctness)', 'Ledger.TotalReplace (well-formedness)',
}
BACKEND = 'dafny-incremental'
SNAPSHOT_OPTIONS = [
    '/compile:0', '/verifySnapshots:1', '/trace', '/rlimit:1000000',
    '/timeLimit:0', '/vcsCores:1', '/verifyAllModules',
]


def protected_manifest(root):
    result = {}
    for directory in PROTECTED_DIRS:
        folder = root / directory
        if not folder.exists():
            continue
        if folder.is_symlink():
            raise Rejected('PROTECTED_SYMLINK: ' + directory)
        for path in sorted(folder.rglob('*')):
            if '__pycache__' in path.parts or path.suffix == '.pyc':
                continue
            name = path.relative_to(root).as_posix()
            if path.is_symlink():
                raise Rejected('PROTECTED_SYMLINK: ' + name)
            if path.is_file():
                result[name] = digest(path.read_bytes())
    for name in PROTECTED_FILES:
        path = root / name
        if path.is_symlink():
            raise Rejected('PROTECTED_SYMLINK: ' + name)
        if path.is_file():
            result[name] = digest(path.read_bytes())
    return result


def source_bytes(root):
    result = {}
    for name in SOURCE_FILES:
        path = root / name
        if path.is_symlink():
            raise Rejected('SOURCE_SYMLINK: ' + name)
        result[name] = path.read_bytes()
    implementation = result['impl/Ledger.dfy']
    preamble = (b'include "../spec/LedgerSpec.dfy"\n\n'
                b'module Ledger refines LedgerSpec {\n')
    if not implementation.startswith(preamble) or implementation.count(b'include') != 1:
        raise Rejected('SOURCE_SCOPE: exact approved include/refinement required; no other includes')
    # Initial incremental scope has no user-controlled tool or caching attributes.
    # This is a conservative byte restriction, not a Dafny parser or proof audit.
    if b'{:' in implementation:
        raise Rejected('SOURCE_SCOPE: user attributes are outside the incremental ledger scope')
    return result


def run(command, log, records):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    output = result.stdout + result.stderr
    log.write_text(output)
    records.append({'command': shlex.join(str(item) for item in command),
                    'exit_code': result.returncode, 'log': str(log.relative_to(ROOT))})
    return result.returncode, output


def trace_coverage(output):
    """Read the pinned checker's trace, without interpreting program semantics."""
    snapshots = []
    current = {'checked': [], 'reused': []}
    for line in output.splitlines():
        checked = re.fullmatch(r'Verifying (.+) \.\.\.', line)
        reused = re.fullmatch(r'Retrieving cached verification result for implementation (.+)\.\.\.', line)
        summary = re.fullmatch(r'Dafny program verifier finished with (\d+) verified, 0 errors', line)
        if checked:
            current['checked'].append(checked.group(1))
        elif reused:
            current['reused'].append(reused.group(1))
        elif summary:
            names = current['checked'] + current['reused']
            if (len(names) != len(set(names)) or len(names) != int(summary.group(1))
                    or not OBLIGATIONS <= set(names)):
                raise Rejected('PROOF_COVERAGE: missing, duplicate, or inconsistent obligations')
            for kind in ('checked', 'reused'):
                current[kind].sort()
                current[kind + '_count'] = len(current[kind])
            snapshots.append(current)
            current = {'checked': [], 'reused': []}
    if len(snapshots) != 2 or current['checked'] or current['reused']:
        raise Rejected('PROOF_COVERAGE: exactly two complete snapshots required')
    if snapshots[0]['reused']:
        raise Rejected('CACHE_ORIGIN: the initial snapshot must have a cold verification cache')
    return snapshots


def reproduction_input(baseline, proposed, protected):
    identity = digest(canonical({
        'baseline': {name: digest(content) for name, content in baseline.items()},
        'candidate': {name: digest(content) for name, content in proposed.items()},
        'protected': protected,
    }))
    parent = ROOT / 'build/change-inputs'
    parent.mkdir(parents=True, exist_ok=True)
    destination = parent / identity
    if not destination.exists():
        with tempfile.TemporaryDirectory(prefix='input-', dir=parent) as temporary:
            staged = Path(temporary) / 'candidate'
            staged.mkdir()
            for name, expected in protected.items():
                content = (ROOT / name).read_bytes()
                if digest(content) != expected:
                    raise Rejected('INPUT_CHANGED: protected input changed before reproduction capture')
                target = staged / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
            for name, content in proposed.items():
                target = staged / name
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_bytes(content)
            staged.rename(destination)
    if protected_manifest(destination) != protected or source_bytes(destination) != proposed:
        raise Rejected('REPRODUCTION_INPUT: saved input does not match the checked candidate')
    return destination.relative_to(ROOT).as_posix()


def check(candidate, output, work, operation):
    versions = check_dependencies()
    from core import framework_paths, load_policy, make_bundle, snapshot, validate_evidence

    state = dafny.prepare('impl/Ledger.dfy')
    trusted_before = protected_manifest(ROOT)
    proposed_before = protected_manifest(candidate)
    if proposed_before != trusted_before:
        changed = sorted(name for name in trusted_before.keys() | proposed_before.keys()
                         if trusted_before.get(name) != proposed_before.get(name))
        raise Rejected('UNAPPROVED_PROTECTED_CHANGE: ' + ', '.join(changed)
                       + '; approval of exact spec text is required; PR labels do not authorize it')
    baseline = source_bytes(ROOT)
    proposed = source_bytes(candidate)
    paths = framework_paths() + state['input_paths'] + [Path(__file__).resolve()]
    inputs_before = snapshot(paths)
    trusted = {name: value for name, value in inputs_before.items() if name not in SOURCE_FILES}
    trusted.update({'baseline/' + name: digest(value) for name, value in baseline.items()})
    # The complete protected manifest binds the trusted revision's acceptance inputs.
    trusted['protected-manifest.json'] = digest(canonical(trusted_before))
    expected_state = dict(state, before=dict(state['before']))
    expected_state['before']['impl/Ledger.dfy'] = digest(proposed['impl/Ledger.dfy'])
    expected = dafny.identity(expected_state)
    rules, policy_identity = load_policy('critical')

    code, version = run([str(dafny.DAFNY), '--version'], work / 'version.log', operation['commands'])
    if code != 0 or version.strip() != state['pins']['dafny']['version_output']:
        raise RuntimeError('TOOLCHAIN_ERROR: version mismatch or command failed: ' + version)

    for index, sources in enumerate((baseline, proposed)):
        fixture = work / ('v' + str(index))
        for name, content in sources.items():
            target = fixture / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(content)
        report = work / ('audit-' + str(index) + '.md')
        report.write_bytes(dafny.AUDIT.read_bytes())
        code, audit = run([
            str(dafny.DAFNY), 'audit', str(fixture / 'impl/Ledger.dfy'),
            str(fixture / 'gate/ContractBinding.dfy'), '--report-format', 'md',
            '--report-file', str(report), '--compare-report',
        ], work / ('audit-' + str(index) + '.log'), operation['commands'])
        if code != 0:
            raise Rejected('AUDIT_REJECTED: C1 C2 C3 C4 C5 not established; Dafny exit '
                           + str(code) + '\n' + audit)
        (work / ('Snapshot.v' + str(index) + '.dfy')).write_text(
            'include "v' + str(index) + '/impl/Ledger.dfy"\n'
            'include "v' + str(index) + '/gate/ContractBinding.dfy"\n')
    (work / 'Snapshot.dfy').write_text('// Dafny processes Snapshot.v0 and Snapshot.v1.\n')
    code, trace = run([
        str(dafny.DAFNY), *SNAPSHOT_OPTIONS,
        '/proverOpt:PROVER_PATH=' + str(ROOT / state['pins']['z3']['path']),
        str(work / 'Snapshot.dfy'),
    ], work / 'snapshots.log', operation['commands'])
    if code == 4:
        raise Rejected('VERIFICATION_REJECTED: C1 C2 C3 C4 C5 not established; Dafny exit 4')
    if code != 0:
        raise RuntimeError('TOOLCHAIN_OR_INPUT_ERROR: Dafny exit ' + str(code) + '\n' + trace)
    snapshots = trace_coverage(trace)
    operation['snapshots'] = snapshots
    names = sorted(snapshots[1]['checked'] + snapshots[1]['reused'])
    saved_input = reproduction_input(baseline, proposed, trusted_before)
    reproduce = ('python3 gate/incremental.py --candidate ' + shlex.quote(saved_input)
                 + ' --evidence build/change-evidence.json')
    assumptions = [
        'The caller supplies a WellFormed state; operations are sequential over mathematical integers.',
        'The executing checkout is a trusted baseline obtained outside the candidate change.',
        'Dafny/Boogie snapshot dependency tracking and internal checksums are trusted.',
        'Dafny 4.11.0 uses MD5 internally; no cache-checksum collision occurs among the inputs in this run.',
        'No claim covers compilation, concurrency, persistence, external services, or deployment.',
    ]
    raw = dict(expected, end_to_end=False, evidence=[
        {'claim_id': claim, 'artifact_sha': expected['artifact']['sha256'],
         'method': 'source_proof', 'tool': 'Dafny',
         'tool_version': state['pins']['dafny']['version_output'], 'result': 'passed',
         'assumptions': assumptions,
         'trusted_base': ['Dafny 4.11.0, bundled Boogie 3.5.5, Z3 4.12.1, and .NET runtime',
                          'Python ' + state['pins']['python']['version'] + ' and the trusted gate',
                          'Approved spec, policy, audit baseline, host OS, and hardware'],
         'reproduce_cmd': reproduce, 'producer': 'forge/dafny-snapshot-gate'}
        for claim in sorted(dafny.CLAIMS)
    ], backend_details={
        'verification_options': SNAPSHOT_OPTIONS,
        'solver_sha256': state['pins']['z3']['executable_sha256'],
        'verified_obligations': names,
        'dependency_method': 'Dafny/Boogie built-in snapshot cache, level 1',
        'baseline_source_manifest': [{'path': name, 'sha256': digest(baseline[name])}
                                     for name in sorted(baseline)],
        'claim_obligation': {claim: 'Ledger.Apply (correctness)' for claim in sorted(dafny.CLAIMS)},
        'cache_counts': 'Operational report only; cache expiry can change work counts.',
    })
    bundle = make_bundle(raw, BACKEND, policy_identity, trusted, versions, reproduce)
    validate_evidence(bundle, expected, rules, policy_identity, trusted, BACKEND)
    if (snapshot(paths) != inputs_before or protected_manifest(ROOT) != trusted_before
            or protected_manifest(candidate) != proposed_before or source_bytes(candidate) != proposed):
        raise Rejected('INPUT_CHANGED: a source or protected input changed during verification')
    staged_evidence = work / 'accepted-evidence.json'
    staged_evidence.write_bytes(canonical(bundle))
    staged_evidence.replace(output)
    apply_status = 'checked' if 'Ledger.Apply (correctness)' in snapshots[1]['checked'] else 'reused'
    operation.update({'result': 'accepted', 'artifact_sha256': expected['artifact']['sha256'],
                      'claim_apply_status': {claim: apply_status for claim in sorted(dafny.CLAIMS)},
                      'evidence_sha256': digest(output.read_bytes())})
    rows = ['| Claim | Established source behavior | Apply proof |', '| --- | --- | --- |']
    rows += ['| ' + claim + ' | ' + dafny.CLAIMS[claim] + ' | ' + apply_status + ' |'
             for claim in sorted(dafny.CLAIMS)]
    (work / 'claims.md').write_text('\n'.join(rows) + '\n\n'
        + 'Dafny source proof only. end_to_end=false.\n'
        + 'Candidate obligations: ' + str(snapshots[1]['checked_count']) + ' checked; '
        + str(snapshots[1]['reused_count']) + ' reused.\n'
        + 'The trusted baseline was fully checked first. All claims share Apply; '
          'these counts refer to member obligations, not independently isolated claims.\n')
    print('ACCEPTED: C1 C2 C3 C4 C5; checked=' + str(snapshots[1]['checked_count'])
          + '; reused=' + str(snapshots[1]['reused_count']) + '; end_to_end=false')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--candidate', type=Path, required=True)
    parser.add_argument('--evidence', type=Path, default=Path('build/change-evidence.json'))
    parser.add_argument('--work', type=Path, help='Fresh directory under build/; otherwise allocate one')
    args = parser.parse_args()
    candidate = args.candidate.resolve()
    output = (ROOT / args.evidence).resolve()
    if args.work is None:
        (ROOT / 'build').mkdir(exist_ok=True)
        work = Path(tempfile.mkdtemp(prefix='change-run-', dir=ROOT / 'build'))
    else:
        work = (ROOT / args.work).resolve()
    for path in (output, work):
        if path == ROOT / 'build' or not path.is_relative_to(ROOT / 'build'):
            raise Rejected('OUTPUT_SCOPE: output and work directory must be under build/')
    if (output.suffix != '.json' or (args.work is not None and work.exists())
            or candidate == work or candidate.is_relative_to(work)):
        raise Rejected('OUTPUT_SCOPE: use a fresh work directory and a JSON evidence file')
    if (output == candidate or output.is_relative_to(candidate)
            or work == candidate or work.is_relative_to(candidate)):
        raise Rejected('OUTPUT_SCOPE: do not write inside the candidate checkout')
    work.mkdir(parents=True, exist_ok=args.work is None)
    output.parent.mkdir(parents=True, exist_ok=True)
    output.unlink(missing_ok=True)
    operation = {'stage': 4, 'stage_exit': False, 'commands': [], 'end_to_end': False}
    code = 0
    try:
        check(candidate, output, work, operation)
    except Rejected as error:
        operation.update({'result': 'rejected', 'error': str(error)})
        print(str(error), file=sys.stderr)
        code = 1
    except (OSError, ValueError, KeyError, RuntimeError, ImportError) as error:
        operation.update({'result': 'error', 'error': str(error)})
        print(str(error), file=sys.stderr)
        code = 2
    operation['exit_code'] = code
    (work / 'operation.json').write_bytes(canonical(operation))
    return code


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (Rejected, OSError, ValueError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
