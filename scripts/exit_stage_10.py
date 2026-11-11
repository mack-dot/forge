#!/usr/bin/env python3
"""Stage 10 EXIT: report the recorded gate benchmark run from its real records.

  python3 scripts/exit_stage_10.py --case report [--run results/stage10/run-0001]

Checks the frozen manifest and every bench file, requires each case to have run
once in every pass, and computes the outcome tables, latency, cost and pass-to-pass
agreement. The first call writes report.json and report.md; later calls must
reproduce them byte for byte. It never reruns a gate and never changes a label.
Exit 0: complete and reproduced. Exit 1: incomplete, changed or not reproduced.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

REPO = Path(__file__).resolve().parents[1]
CLASSES = ('accept', 'defect', 'missing_evidence', 'policy_reject', 'unsupported', 'tool_failure')
OBSERVED = CLASSES + ('unclassified', 'not_run')
LIMITS = [
    'Internally authored controlled evaluation: the owner and the agent wrote both Forge and these cases.',
    'Not independent generalization and not a real-PR shadow study; the shadow study stays a separate future milestone.',
    'Expected outcomes were frozen before any case ran; mismatches are reported, never relabelled.',
    'Ledger, booking and refund source-proof gates only; binary/ELF and Stage 9 provenance gates are not covered.',
    'Cost is local process CPU seconds on the recorded host; no cloud or human-time cost is included.',
    'end_to_end=false.',
]


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def fail(message):
    print('STAGE10_REPORT_NOT_ESTABLISHED: ' + message)
    return 1


def nearest_rank(values, p):
    ordered = sorted(values)
    return ordered[max(1, math.ceil(p / 100 * len(ordered))) - 1] if ordered else None


def outcome(record):
    if record.get('status') != 'ran':
        return 'not_run'
    expected, observed = record['expected_class'], record['observed_class']
    if expected != observed:
        if observed == 'accept':
            return 'false_accept'
        if expected == 'accept':
            return 'false_reject'
        return 'misclassified'
    wanted = record['expected_reason_prefix']
    return 'wrong_reason' if wanted and record['reason_prefix'] != wanted else 'match'


def timing(records):
    ran = [r for r in records if r.get('status') == 'ran']
    wall = [r['wall_seconds'] for r in ran]
    cpu = [round(r['cpu_user_seconds'] + r['cpu_system_seconds'], 3) for r in ran]
    return {'cases_timed': len(ran), 'wall_seconds_total': round(sum(wall), 3),
            'cpu_seconds_total': round(sum(cpu), 3),
            'wall_seconds_p50': nearest_rank(wall, 50), 'wall_seconds_p95': nearest_rank(wall, 95),
            'cpu_seconds_p50': nearest_rank(cpu, 50), 'cpu_seconds_p95': nearest_rank(cpu, 95)}


def build(run_dir):
    manifest_path = REPO / 'bench/manifest.json'
    manifest_raw = manifest_path.read_bytes()
    run = json.loads((run_dir / 'run.json').read_text())
    if run.get('dry_run') or run['manifest_sha256'] != sha256(manifest_raw):
        raise ValueError('run is a dry run or used another manifest')
    manifest = json.loads(manifest_raw)
    for name, expected in manifest['files'].items():
        if sha256((REPO / name).read_bytes()) != expected:
            raise ValueError('bench file changed after the run: ' + name)
    records = [json.loads(line) for line in (run_dir / 'records.jsonl').read_text().splitlines() if line]
    order = manifest['case_order']
    passes = {}
    for record in records:
        passes.setdefault(record['pass'], []).append(record)
    if sorted(passes) != list(range(1, manifest['passes'] + 1)):
        raise ValueError('passes recorded: ' + str(sorted(passes)))
    for number, rows in passes.items():
        if [r['id'] for r in rows] != order:
            raise ValueError('pass %d does not hold every case exactly once in order' % number)
    primary = passes[manifest['primary_pass']]
    for record in primary:
        record['outcome'] = outcome(record)
    confusion = {e: {o: 0 for o in OBSERVED} for e in CLASSES}
    for record in primary:
        observed = record['observed_class'] if record.get('status') == 'ran' else 'not_run'
        confusion[record['expected_class']][observed] += 1
    kinds = ('match', 'wrong_reason', 'false_accept', 'false_reject', 'misclassified', 'not_run')
    domains = {}
    for record in primary:
        row = domains.setdefault(record['domain'], {k: 0 for k in kinds})
        row[record['outcome']] += 1
    lists = {k: [{'id': r['id'], 'expected_class': r['expected_class'], 'observed_class': r.get('observed_class'),
                  'expected_reason_prefix': r['expected_reason_prefix'], 'reason_prefix': r.get('reason_prefix'),
                  'exit_code': r.get('exit_code'), 'status': r.get('status'), 'error': r.get('error')}
                 for r in primary if r['outcome'] == k]
             for k in kinds if k != 'match'}
    agreement = []
    others = [n for n in sorted(passes) if n != manifest['primary_pass']]
    for number in others:
        for first, second in zip(primary, passes[number]):
            keys = ('status', 'exit_code', 'reason_prefix', 'observed_class')
            agreement.append({'id': first['id'], 'pass': number,
                              'same_decision': all(first.get(k) == second.get(k) for k in keys),
                              'same_evidence_bytes': (first.get('evidence_sha256') == second.get('evidence_sha256')
                                                      if first.get('evidence_sha256') else None)})
    gates = {}
    for record in primary:
        gates.setdefault(record['gate'], []).append(record)
    adjudication_path = run_dir / 'adjudications.json'
    adjudications = json.loads(adjudication_path.read_text()) if adjudication_path.is_file() else []
    report = {
        'stage': 10, 'scope': 'controlled gate benchmark', 'end_to_end': False,
        'manifest_sha256': run['manifest_sha256'], 'base_commit': manifest['base_commit'],
        'host': run['host'], 'run_started_utc': run['started_utc'], 'run_finished_utc': run.get('finished_utc'),
        'case_count': len(order), 'passes': manifest['passes'], 'primary_pass': manifest['primary_pass'],
        'expected_class_counts': manifest['expected_class_counts'],
        'outcome_counts': {k: sum(r['outcome'] == k for r in primary) for k in kinds},
        'confusion_expected_by_observed': confusion,
        'by_domain': domains, 'outcome_lists': lists,
        'timing_primary_pass': timing(primary),
        'timing_by_gate_primary_pass': {g: timing(rows) for g, rows in sorted(gates.items())},
        'timing_all_passes': timing(records),
        'reproducibility': {
            'cases_compared': len(agreement),
            'same_decision': sum(a['same_decision'] for a in agreement),
            'evidence_compared': sum(a['same_evidence_bytes'] is not None for a in agreement),
            'same_evidence_bytes': sum(a['same_evidence_bytes'] is True for a in agreement),
            'differences': [a for a in agreement if not a['same_decision'] or a['same_evidence_bytes'] is False]},
        'adjudications': adjudications,
        'limits': LIMITS,
    }
    return report


def markdown(report):
    lines = ['# Stage 10 gate benchmark report', '',
             'Controlled, internally authored evaluation. Not independent generalization; not a real-PR shadow study.', '',
             '- Manifest: `%s`; base commit `%s`' % (report['manifest_sha256'], report['base_commit']),
             '- Host: %s, %s, %s logical CPUs' % (report['host']['model'], report['host']['cpu'], report['host']['logical_cpus']),
             '- Cases: %d; passes: %d; primary pass: %d' % (report['case_count'], report['passes'], report['primary_pass']),
             '', '## Outcomes (primary pass)', '', '| Outcome | Cases |', '| --- | ---: |']
    lines += ['| %s | %d |' % (k, v) for k, v in report['outcome_counts'].items()]
    lines += ['', '## Confusion (rows: expected; columns: observed)', '',
              '| Expected | ' + ' | '.join(OBSERVED) + ' |', '| --- |' + ' ---: |' * len(OBSERVED)]
    for expected, row in report['confusion_expected_by_observed'].items():
        lines.append('| %s | ' % expected + ' | '.join(str(row[o]) for o in OBSERVED) + ' |')
    lines += ['', '## By domain', '', '| Domain | ' + ' | '.join(report['outcome_counts']) + ' |',
              '| --- |' + ' ---: |' * len(report['outcome_counts'])]
    for domain, row in sorted(report['by_domain'].items()):
        lines.append('| %s | ' % domain + ' | '.join(str(row[k]) for k in report['outcome_counts']) + ' |')
    for kind, rows in report['outcome_lists'].items():
        lines += ['', '## %s (%d)' % (kind.replace('_', ' '), len(rows)), '']
        lines += ['- `%s`: expected %s (%s), observed %s (%s), exit %s' % (
            r['id'], r['expected_class'], r['expected_reason_prefix'], r['observed_class'], r['reason_prefix'],
            r['exit_code']) for r in rows] or ['None.']
    t = report['timing_primary_pass']
    lines += ['', '## Latency and cost', '',
              '| Scope | Cases | Wall p50 s | Wall p95 s | CPU p50 s | CPU p95 s | Wall total s | CPU total s |',
              '| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |']
    rows = [('primary pass', t)] + sorted(report['timing_by_gate_primary_pass'].items()) + [
        ('all passes', report['timing_all_passes'])]
    for name, v in rows:
        lines.append('| %s | %d | %s | %s | %s | %s | %s | %s |' % (
            name, v['cases_timed'], v['wall_seconds_p50'], v['wall_seconds_p95'], v['cpu_seconds_p50'],
            v['cpu_seconds_p95'], v['wall_seconds_total'], v['cpu_seconds_total']))
    r = report['reproducibility']
    lines += ['', '## Reproducibility', '',
              '- Same decision in the repeat pass: %d of %d' % (r['same_decision'], r['cases_compared']),
              '- Same evidence bytes: %d of %d accepted cases with evidence' % (r['same_evidence_bytes'], r['evidence_compared'])]
    lines += ['- Difference: `%s` (pass %d)' % (d['id'], d['pass']) for d in r['differences']]
    lines += ['', '## Adjudications', '']
    lines += ['- `%s`: %s. %s' % (a['id'], a['verdict'], a.get('note', '')) for a in report['adjudications']] or [
        'None recorded.']
    lines += ['', '## Limits', ''] + ['- ' + item for item in report['limits']]
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--case', choices=['report'], required=True)
    parser.add_argument('--run', type=Path, default=REPO / 'results/stage10/run-0001')
    args = parser.parse_args()
    run_dir = args.run.resolve()
    try:
        report = build(run_dir)
    except (OSError, ValueError, KeyError) as error:
        return fail(str(error))
    outputs = {run_dir / 'report.json': (json.dumps(report, indent=1, sort_keys=True) + '\n').encode(),
               run_dir / 'report.md': markdown(report).encode()}
    for path, data in outputs.items():
        if path.exists() and path.read_bytes() != data:
            return fail('existing ' + path.name + ' differs from the recomputed report')
    for path, data in outputs.items():
        if not path.exists():
            path.write_bytes(data)
        print(path.name, sha256(data))
    counts = report['outcome_counts']
    if counts['not_run']:
        return fail('%d cases did not run in the primary pass' % counts['not_run'])
    print('STAGE10_REPORT_ESTABLISHED: cases %d; match %d; wrong_reason %d; false_accept %d; false_reject %d; '
          'misclassified %d; end_to_end=false' % (report['case_count'], counts['match'], counts['wrong_reason'],
                                                 counts['false_accept'], counts['false_reject'], counts['misclassified']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
