#!/usr/bin/env python3
"""Measure real Dafny runs; native Dafny/Boogie alone decides proof reuse."""

import argparse
from decimal import Decimal
import json
from pathlib import Path
import platform
import re
import shlex
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
sys.dont_write_bytecode = True
from common import canonical, digest
from backends import dafny
from incremental import SNAPSHOT_OPTIONS, protected_manifest

SOURCES = ('spec/LedgerSpec.dfy', 'spec/booking/BookingSpec.dfy',
           'impl/Ledger.dfy', 'impl/Booking.dfy')
CONDITIONS = ('cold', 'shared_files', 'dependency_graph')
CASES = ('unchanged', 'booking_body', 'helper_body', 'broken_helper', 'reject_all')
EXPECTED = {'unchanged': 0, 'booking_body': 0, 'helper_body': 0,
            'broken_helper': 4, 'reject_all': 4}
PREFIXES = {
    'spec/LedgerSpec.dfy': '',
    'spec/booking/BookingSpec.dfy': 'include "../../spec/LedgerSpec.dfy"\n',
    'impl/Ledger.dfy': 'include "../spec/LedgerSpec.dfy"\n',
    'impl/Booking.dfy': 'include "../spec/booking/BookingSpec.dfy"\ninclude "Ledger.dfy"\n',
}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def replace_once(source, before, after):
    require(source.count(before) == 1, 'Fixture edit target changed')
    return source.replace(before, after, 1)


def variants(original):
    result = {name: dict(original) for name in CASES}
    result['booking_body']['impl/Booking.dfy'] = replace_once(
        original['impl/Booking.dfy'], '      outcome := state.accepted[id].outcome;',
        '      outcome := state.accepted[id].outcome;\n      assert next == state;')
    needle = '    TotalRemove(balances, account);'
    result['helper_body']['impl/Ledger.dfy'] = replace_once(
        original['impl/Ledger.dfy'], needle,
        '    assert balances[account] < 0 || 0 <= balances[account];\n' + needle)
    result['broken_helper']['impl/Ledger.dfy'] = replace_once(
        original['impl/Ledger.dfy'], needle, '    assert false;\n' + needle)
    start = '  method {:isolate_assertions} Apply ... {'
    require(original['impl/Booking.dfy'].count(start) == 1, 'Apply fixture boundary changed')
    result['reject_all']['impl/Booking.dfy'] = original['impl/Booking.dfy'].split(start)[0] + (
        start + '\n    next := state;\n    outcome := Rejected;\n  }\n}\n')
    return result


def materialize(folder, sources, flattened):
    folder.mkdir(parents=True, exist_ok=False)
    if flattened:
        chunks = []
        for name in SOURCES:
            prefix = PREFIXES[name]
            require(sources[name].startswith(prefix), 'Exact include prefix changed: ' + name)
            chunks.append(sources[name][len(prefix):])
        entry = folder / 'All.dfy'
        entry.write_text('\n'.join(chunks))
        return entry
    for name, text in sources.items():
        target = folder / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(text)
    return folder / 'impl/Booking.dfy'


def trace_records(output):
    snapshots, rows = [], []
    for line in output.splitlines():
        checked = re.fullmatch(r'Verifying (.+) \.\.\.', line)
        cached = re.fullmatch(r'Retrieving cached verification result for implementation (.+)\.\.\.', line)
        if checked or cached:
            rows.append({'member': (checked or cached).group(1),
                         'work': 'checked' if checked else 'reused'})
        stat = re.fullmatch(r'\s*\[([\d.]+) s, solver resource count: (\d+), (\d+) proof obligations?\]\s+(.+)', line)
        if stat:
            require(bool(rows) and 'resource_count' not in rows[-1], 'Unbound/duplicate trace statistic')
            rows[-1].update({'reported_verifier_ns': int(Decimal(stat.group(1)) * 10**9),
                            'resource_count': int(stat.group(2)),
                            'assertions': int(stat.group(3)), 'checker_outcome': stat.group(4)})
        summary = re.fullmatch(r'Dafny program verifier finished with (\d+) verified, (\d+) errors?(.*)', line)
        if summary:
            require(len(rows) == len({r['member'] for r in rows}), 'Duplicate trace member')
            snapshots.append({'verified': int(summary.group(1)), 'errors': int(summary.group(2)),
                              'other_summary': summary.group(3), 'members': rows})
            rows = []
    require(not rows and snapshots, 'Incomplete native trace')
    return snapshots


def execute(command, folder, label, phase, commands):
    started = time.perf_counter_ns()
    child = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    elapsed = time.perf_counter_ns() - started
    output = child.stdout + child.stderr
    log = folder / (label + '.log')
    log.write_text(output)
    record = {'command': shlex.join(command), 'argv': command, 'phase': phase,
              'exit_code': child.returncode, 'elapsed_ns': elapsed,
              'log': log.relative_to(ROOT).as_posix(), 'log_sha256': digest(log.read_bytes())}
    commands.append(record)
    (folder / 'commands.json').write_bytes(canonical(commands))
    return record, output


def check_trace(snapshots, expected_code, reference_members):
    require(len(snapshots) == 2, 'Baseline and candidate summaries required')
    for i, snap in enumerate(snapshots):
        require({r['member'] for r in snap['members']} == reference_members,
                'Missing/extra member coverage in snapshot ' + str(i))
        require(all('resource_count' in r for r in snap['members']), 'Missing checker resource metrics')
        require(not snap['other_summary'], 'Unknown, timeout, or resource-exhausted result')
        require(snap['verified'] + snap['errors'] == len(reference_members), 'Summary coverage differs')
        if i == 0 or expected_code == 0:
            require(snap['errors'] == 0 and all(r['checker_outcome'] == 'verified' for r in snap['members']),
                    'Expected complete successful verification')
        else:
            require(snap['errors'] > 0, 'Expected invalid candidate was not rejected')
    require(all(r['work'] == 'checked' for r in snapshots[0]['members']), 'Baseline cache was not cold')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repetitions', type=int, default=5)
    parser.add_argument('--label', default='benchmark')
    args = parser.parse_args()
    require(args.repetitions in (1, 5), 'Use one preparation repeat or the five-repeat experiment')
    require(re.fullmatch('[a-z0-9-]+', args.label), 'Invalid report label')
    state = dafny.prepare('impl/Ledger.dfy')
    protected_before = protected_manifest(ROOT)
    original = {name: (ROOT / name).read_text() for name in SOURCES}
    source_before = {name: digest(text.encode()) for name, text in original.items()}
    runner_sha = digest(Path(__file__).read_bytes())
    candidates = variants(original)
    root = ROOT / 'results/stage6/runs'
    root.mkdir(parents=True, exist_ok=True)
    number = 1
    while (root / ('run-' + str(number).zfill(4))).exists():
        number += 1
    report_dir = root / ('run-' + str(number).zfill(4))
    report_dir.mkdir()
    work = ROOT / 'build/stage6' / report_dir.name
    work.mkdir(parents=True, exist_ok=False)
    reference = json.loads((ROOT / 'gate/booking-coverage.json').read_text())['members']
    reference_members = {name for name in reference if not name.startswith('BookingSuccessfulExecution.')}
    report = {
        'stage': 6, 'kind': 'verifier_reuse_measurement', 'label': args.label,
        'stage_exit': args.repetitions == 5 and args.label == 'benchmark',
        'end_to_end': False, 'production_acceptance': False, 'result': 'running',
        'exit_code': None, 'repetitions': args.repetitions, 'sample_count': 0,
        'conditions': list(CONDITIONS), 'cases': list(CASES), 'records': [],
        'expected_candidate_codes': EXPECTED, 'source_sha256': source_before,
        'runner_sha256': runner_sha, 'tool_version': state['pins']['dafny']['version_output'],
        'toolchain_pins_sha256': digest((ROOT / 'toolchain/pins.json').read_bytes()),
        'solver_resource_limit': 1000000, 'verification_time_limit': 0, 'workers': 1,
        'resource_limit_scope': 'Per assertion batch for isolated members; per member otherwise.',
        'native_snapshot_options': SNAPSHOT_OPTIONS,
        'hardware': {'platform': platform.platform(), 'machine': platform.machine(),
                     'python': platform.python_version()},
        'setup_commands': [], 'seed': None, 'seed_reason': 'No randomized workload or model calls.',
        'scope': 'Fixed-source verifier experiment. No LLM productivity or general-program extrapolation.',
        'cache_assumptions': ['Native Dafny/Boogie dependency collection and cache are trusted.',
                              'No collision in native internal MD5 checksums among these inputs.',
                              'Cache expiry can alter work counts. Cached trace times/resources are historical.'],
        'token_accounting': 'Verifier subprocesses make zero LLM calls; authoring/setup recorded separately.',
        'reference_members': sorted(reference_members),
    }
    destination = report_dir / 'report.json'
    def save():
        destination.write_bytes(canonical(report))
    save()
    try:
        rec, version = execute([str(dafny.DAFNY), '--version'], report_dir, 'version', 'setup', report['setup_commands'])
        require(rec['exit_code'] == 0 and version.strip() == report['tool_version'], 'TOOLCHAIN_ERROR: version failed/differed')
        rec, hardware = execute(['sysctl', '-n', 'machdep.cpu.brand_string', 'hw.physicalcpu',
                                  'hw.logicalcpu', 'hw.memsize'], report_dir, 'hardware', 'setup', report['setup_commands'])
        require(rec['exit_code'] == 0, 'Hardware inventory failed')
        report['hardware']['sysctl_output'] = hardware.strip().splitlines()
        for name, sources in candidates.items():
            folder = report_dir / 'fixtures' / name
            materialize(folder, sources, False)
        report['fixture_sha256'] = {name: {p: digest(s.encode()) for p, s in sources.items()}
                                     for name, sources in candidates.items()}
        save()
        base_options = [x for x in SNAPSHOT_OPTIONS if not x.startswith('/verifySnapshots:')]
        solver = '/proverOpt:PROVER_PATH=' + str(ROOT / state['pins']['z3']['path'])
        for repeat in range(args.repetitions):
            order = CONDITIONS[repeat % 3:] + CONDITIONS[:repeat % 3]
            for condition in order:
                for case in CASES:
                    name = str(repeat + 1) + '-' + condition + '-' + case
                    folder = report_dir / name
                    folder.mkdir()
                    command_records = []
                    case_started = time.perf_counter_ns()
                    setup_started = case_started
                    local = work / name
                    local.mkdir()
                    entries = [materialize(local / ('v' + str(i)), sources, condition == 'cold')
                               for i, sources in enumerate((original, candidates[case]))]
                    case_record = {'repeat': repeat + 1, 'condition': condition, 'case': case,
                                   'expected_candidate_code': EXPECTED[case], 'commands': command_records,
                                   'setup_elapsed_ns': time.perf_counter_ns() - setup_started,
                                   'result': 'running', 'snapshots': []}
                    report['records'].append(case_record)
                    save()
                    for i, entry in enumerate(entries):
                        audit = local / ('audit-' + str(i) + '.md')
                        audit.write_bytes(dafny.AUDIT.read_bytes())
                        rec, output = execute([str(dafny.DAFNY), 'audit', str(entry), '--report-format', 'md',
                                               '--report-file', str(audit), '--compare-report'],
                                              folder, 'audit-' + str(i), 'audit', command_records)
                        save()
                        require(rec['exit_code'] == 0, 'AUDIT_REJECTED: ' + output)
                    if condition == 'dependency_graph':
                        for i, entry in enumerate(entries):
                            (local / ('Snapshot.v' + str(i) + '.dfy')).write_text(
                                'include "' + entry.relative_to(local).as_posix() + '"\n')
                        (local / 'Snapshot.dfy').write_text('// Native Dafny snapshot discovery.\n')
                        rec, output = execute([str(dafny.DAFNY), *SNAPSHOT_OPTIONS, solver,
                                               str(local / 'Snapshot.dfy')], folder, 'verify-pair', 'verify', command_records)
                        save()
                        require(rec['exit_code'] == EXPECTED[case], 'Unexpected native checker exit: ' + str(rec['exit_code']))
                        case_record['snapshots'] = trace_records(output)
                    else:
                        output = ''
                        for i, entry in enumerate(entries):
                            rec, text = execute([str(dafny.DAFNY), *base_options, solver, str(entry)],
                                                folder, 'verify-' + str(i), 'verify', command_records)
                            save()
                            require(rec['exit_code'] == (0 if i == 0 else EXPECTED[case]),
                                    'Unexpected fresh checker exit: ' + str(rec['exit_code']))
                            case_record['snapshots'] += trace_records(text)
                            output += text
                        require(all(r['work'] == 'checked' for s in case_record['snapshots'] for r in s['members']),
                                'Fresh process unexpectedly reported proof reuse')
                    require(not re.search(r'out of resource|timed out|time out|result unknown', output, re.I),
                            'Inconclusive verification is not an expected rejection')
                    if case == 'broken_helper':
                        require('assertion might not hold' in output, 'Missing actual broken-helper diagnostic')
                    if case == 'reject_all':
                        require('postcondition' in output, 'Missing actual booking contract diagnostic')
                    check_trace(case_record['snapshots'], EXPECTED[case], reference_members)
                    require(protected_manifest(ROOT) == protected_before, 'Protected inputs changed during experiment')
                    require(all(digest((ROOT / p).read_bytes()) == h for p, h in source_before.items()),
                            'Implementation changed during experiment')
                    require(digest(Path(__file__).read_bytes()) == runner_sha, 'Runner changed during experiment')
                    case_record.update({'result': 'passed', 'case_elapsed_ns': time.perf_counter_ns() - case_started})
                    report['sample_count'] += 1
                    save()
                    print(name + ': expected checker result observed', flush=True)
        report.update({'result': 'passed', 'exit_code': 0})
        save()
        (ROOT / 'results/stage6' / (args.label + '.json')).write_bytes(canonical(report))
        print('REPORT ' + destination.relative_to(ROOT).as_posix(), flush=True)
        return 0
    except Exception as error:
        report.update({'result': 'failed', 'exit_code': 1, 'error': str(error)})
        save()
        print(str(error), file=sys.stderr)
        return 1


if __name__ == '__main__':
    sys.exit(main())
