#!/usr/bin/env python3
"""Recompute the fixed experiment report from actual command records and logs."""

import argparse
from collections import Counter
import json
from pathlib import Path
import statistics
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
sys.dont_write_bytecode = True
from common import canonical, digest, read_json
from benchmark_reuse import CONDITIONS, CASES, EXPECTED, trace_records, check_trace, require


def verified_log(command):
    path = ROOT / command['log']
    require(path.is_file() and digest(path.read_bytes()) == command['log_sha256'],
            'Raw command log missing or changed: ' + command['log'])
    require(isinstance(command['exit_code'], int), 'Missing real command exit code')
    require(isinstance(command['elapsed_ns'], int) and command['elapsed_ns'] >= 0, 'Missing measured elapsed time')
    return path.read_text()


def measurements(records):
    checked = [member for row in records for snap in row['snapshots'] for member in snap['members']
               if member['work'] == 'checked']
    reused = [member for row in records for snap in row['snapshots'] for member in snap['members']
              if member['work'] == 'reused']
    wall = [sum(c['elapsed_ns'] for c in row['commands'] if c['phase'] == 'verify') for row in records]
    return {'pairs': len(records), 'verifier_process_ns': sum(wall),
            'verifier_process_median_ns': statistics.median(wall),
            'verifier_process_min_ns': min(wall), 'verifier_process_max_ns': max(wall),
            'audit_process_ns': sum(c['elapsed_ns'] for row in records for c in row['commands'] if c['phase'] == 'audit'),
            'fixture_setup_ns': sum(row['setup_elapsed_ns'] for row in records),
            'whole_pair_ns': sum(row['case_elapsed_ns'] for row in records),
            'checked_members_including_rejections': len(checked), 'reused_members': len(reused),
            'checked_solver_resources': sum(member['resource_count'] for member in checked),
            'checked_reported_verifier_ns': sum(member['reported_verifier_ns'] for member in checked),
            'cached_historical_metrics_excluded': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=['report'], required=True)
    parser.parse_args()
    from dependencies import check_dependencies
    check_dependencies()
    from core import validate_evidence
    from booking import identity, BACKEND
    benchmark = read_json(ROOT / 'results/stage6/benchmark.json')
    require(benchmark['stage_exit'] and benchmark['exit_code'] == 0 and benchmark['result'] == 'passed',
            'The actual five-repeat benchmark EXIT has not passed')
    require(benchmark['repetitions'] == 5 and benchmark['sample_count'] == 75, 'Wrong sample count')
    require(benchmark['runner_sha256'] == digest((ROOT / 'scripts/benchmark_reuse.py').read_bytes()),
            'Benchmark driver changed after measurement')
    require(benchmark['hardware_inventory_driver_sha256'] == digest((ROOT / 'scripts/inventory_hardware.py').read_bytes()),
            'Hardware inventory driver changed after measurement')
    require(all(digest((ROOT / name).read_bytes()) == sha for name, sha in benchmark['source_sha256'].items()),
            'Measured source changed')
    inputs = read_json(ROOT / 'results/stage6/input-identities.json')
    require(inputs['exit_code'] == 0 and inputs['all_match_frozen_fixture_bytes'] and
            inputs['checked_input_files'] == 450 and len(inputs['inputs']) == 450,
            'Materialized input identity check is missing')
    require(inputs['benchmark_sha256'] == digest((ROOT / 'results/stage6/benchmark.json').read_bytes()),
            'Input identity check names another experiment')
    expected_pairs = {(i, condition, case) for i in range(1, 6) for condition in CONDITIONS for case in CASES}
    observed = [(row['repeat'], row['condition'], row['case']) for row in benchmark['records']]
    require(len(observed) == len(set(observed)) and set(observed) == expected_pairs, 'Missing/duplicate experiment pairs')
    for command in benchmark['setup_commands']:
        verified_log(command)
        require(command['exit_code'] == 0, 'Benchmark setup failed')
    for row in benchmark['records']:
        require(row['result'] == 'passed', 'Unfinished experiment pair')
        parsed = []
        verify_commands = []
        audit_commands = []
        for command in row['commands']:
            output = verified_log(command)
            if command['phase'] == 'verify':
                verify_commands.append(command)
                parsed.extend(trace_records(output))
            elif command['phase'] == 'audit':
                audit_commands.append(command)
                require(command['exit_code'] == 0, 'Audit did not pass')
            else:
                raise RuntimeError('Unknown command phase')
        require(len(audit_commands) == 2, 'Both snapshots need real audits')
        codes = [c['exit_code'] for c in verify_commands]
        expected = [EXPECTED[row['case']]] if row['condition'] == 'dependency_graph' else [0, EXPECTED[row['case']]]
        require(codes == expected and parsed == row['snapshots'], 'Recorded checker result differs from raw log')
        check_trace(parsed, EXPECTED[row['case']], set(benchmark['reference_members']))
        if row['condition'] != 'dependency_graph':
            require(all(m['work'] == 'checked' for s in parsed for m in s['members']), 'Unexpected cold cache reuse')

    controls = read_json(ROOT / 'results/stage6/controls-final.json')
    require(controls['result'] == 'passed' and controls['exit_code'] == 0 and controls['byte_identical'],
            'Booking replay and rejection controls have not passed')
    for command in controls['commands']:
        verified_log(command)
    require(len(controls['negative_controls']) == 6, 'Missing booking negative controls')
    for operation in controls['checker_operations']:
        for command in operation['commands']:
            verified_log(command)
    control_history = []
    for path in sorted((ROOT / 'results/stage6').glob('controls*/report.json')):
        prior = read_json(path)
        if prior == controls:
            continue
        for command in prior['commands']:
            verified_log(command)
        for operation in prior['checker_operations']:
            for command in operation['commands']:
                verified_log(command)
        control_history.append({'report': path.relative_to(ROOT).as_posix(),
                                'sha256': digest(path.read_bytes()), 'result': prior['result'],
                                'exit_code': prior['exit_code'], 'commands': prior['commands'],
                                'checker_operations': prior['checker_operations']})
    evidence = read_json(ROOT / 'results/stage6/source-evidence.json')
    require(digest((ROOT / 'results/stage6/source-evidence.json').read_bytes()) == controls['source_evidence_sha256'],
            'Accepted source evidence changed')
    policy = read_json(ROOT / 'policy/booking.yaml')
    policy_id = {'id': policy['id'], 'version': policy['version'], 'tier': 'critical',
                 'sha256': digest((ROOT / 'policy/booking.yaml').read_bytes())}
    trusted = {name: digest((ROOT / name).read_bytes()) for name in evidence['trusted_input_sha256']}
    validate_evidence(evidence, identity(), policy['tiers']['critical'], policy_id, trusted, BACKEND)

    accounting = read_json(ROOT / 'results/stage6/accounting.json')
    token_totals = {key: sum(record['usage'][key] for record in accounting['records']) for key in accounting['totals']}
    require(token_totals == accounting['totals'], 'Token totals do not reproduce')
    require(token_totals == {key: accounting['ending_cumulative_tokens'][key] -
                            accounting['prior_phase_cumulative_tokens'][key] for key in token_totals},
            'Runtime cumulative usage does not match per-response sum')
    require(len(accounting['records']) == len({r['response_id_sha256'] for r in accounting['records']}),
            'Duplicate response usage record')
    require(accounting['human_intervention_count'] == len(accounting['human_interventions']), 'Intervention count differs')

    preparation = []
    for path in sorted((ROOT / 'results/stage6/runs').glob('run-*/report.json')):
        prior = read_json(path)
        if digest(path.read_bytes()) == digest((ROOT / 'results/stage6/benchmark.json').read_bytes()):
            continue
        commands = prior['setup_commands'] + [c for row in prior['records'] for c in row['commands']]
        for command in commands:
            verified_log(command)
        preparation.append({'report': path.relative_to(ROOT).as_posix(), 'sha256': digest(path.read_bytes()),
                            'category': ('prior_completed_experiment' if prior['stage_exit'] and prior['result'] == 'passed'
                                         else 'preparation'),
                            'result': prior['result'], 'exit_code': prior['exit_code'],
                            'completed_pairs': prior['sample_count'], 'command_count': len(commands),
                            'verifier_process_ns': sum(c['elapsed_ns'] for c in commands if c['phase'] == 'verify'),
                            'audit_process_ns': sum(c['elapsed_ns'] for c in commands if c['phase'] == 'audit'),
                            'setup_process_ns': sum(c['elapsed_ns'] for c in commands if c['phase'] == 'setup')})
    development = []
    for path in sorted((ROOT / 'results/stage6/development').glob('*/record.json')):
        prior = read_json(path)
        commands = prior.get('commands', [prior] if 'command' in prior else [])
        for command in commands:
            verified_log(command)
        development.append({'report': path.relative_to(ROOT).as_posix(), 'sha256': digest(path.read_bytes()),
                            'commands': commands})
    summary = {
        'stage': 6, 'kind': 'recomputed_reuse_report', 'exit_code': 0, 'result': 'passed',
        'end_to_end': False, 'production_acceptance': False, 'extrapolation': False,
        'measured_pairs': 75, 'conditions': {name: measurements([r for r in benchmark['records'] if r['condition'] == name])
                                          for name in CONDITIONS},
        'per_case': {case: {name: measurements([r for r in benchmark['records'] if r['condition'] == name and r['case'] == case])
                           for name in CONDITIONS} for case in CASES},
        'preparation_runs': preparation, 'development_checks': development,
        'benchmark_setup_process_ns': sum(c['elapsed_ns'] for c in benchmark['setup_commands']),
        'evidence_control_gate_operations': controls['checker_operations'],
        'prior_control_attempts': control_history,
        'token_totals': token_totals, 'token_coverage': accounting['coverage'],
        'token_cutoff_source_ordinal': accounting['last_source_ordinal'],
        'human_interventions': accounting['human_interventions'],
        'automatic_continuation_count': accounting['automatic_continuation_count'],
        'input_sha256': {p: digest((ROOT / p).read_bytes()) for p in (
            'results/stage6/benchmark.json', 'results/stage6/source-evidence.json',
            'results/stage6/controls-final.json', 'results/stage6/accounting.json',
            'results/stage6/input-identities.json',
            'scripts/exit_stage_6.py', 'scripts/benchmark_reuse.py', 'scripts/export_stage6_usage.py')},
        'limits': [
            'Five repeats of five fixed cases per condition on this recorded host; no wider inference.',
            'Cold and shared layouts contain the same declarations; shared files still receive full checks.',
            'Every baseline/warm-up is charged; cached historical statistics are not charged as new solver work.',
            'Negative controls are included in totals and are never accepted artifacts.',
            'The host was not isolated from all other OS/user activity. Timing reruns can differ.',
            'Authoring tokens are shared preparation, not three independent LLM authoring experiments.',
            'All available runtime usage categories in the stated interval are retained; post-cutoff activity is outside it.',
            'Private transcript content stays local; public event hashes do not reveal hidden instructions or reasoning.',
            'Early proposal resolution and one hardware inspection lack isolated subprocess timing; these are not proof runs.',
            'Source proof does not establish compiled, deployed, concurrent, durable, or authenticated behavior.',
        ],
    }
    (ROOT / 'results/stage6/report.json').write_bytes(canonical(summary))
    text = ['# Stage 6: booking proofs and measured reuse', '',
            'The approved booking source passes B1–B4 with Dafny 4.11.0. Its checked trace includes',
            'cancellation, slot reuse, historical retries, and ID conflicts. The source evidence',
            'replayed byte for byte. `end_to_end=false`.', '',
            '[Source evidence](../results/stage6/source-evidence.json) · [Actual measurements](../results/stage6/benchmark.json)',
            '· [Recomputed totals](../results/stage6/report.json) · [Rejection controls](../results/stage6/controls-final.json)',
            '', '## Exact experiment', '',
            'Five repetitions × five cases × three conditions produced 75 baseline/candidate pairs.',
            'Each pair charges both audits and the full baseline check. Fresh processes handle the',
            'cold and shared-file conditions. The dependency condition uses native Dafny/Boogie',
            'snapshot reuse after checking its baseline in the same process. No custom proof cache',
            'or dependency checker decides correctness.', '',
            '| Condition | Pairs | Verifier process seconds, including baseline | Checked members, including failures | Reused members | New solver resources |',
            '| --- | ---: | ---: | ---: | ---: | ---: |']
    for name, values in summary['conditions'].items():
        text.append('| ' + name + ' | ' + str(values['pairs']) + ' | ' + format(values['verifier_process_ns'] / 1e9, '.3f')
                    + ' | ' + str(values['checked_members_including_rejections']) + ' | ' + str(values['reused_members'])
                    + ' | ' + str(values['checked_solver_resources']) + ' |')
    text += ['', 'The table includes the deliberately invalid helper and reject-all controls. Rejected',
             'candidates do not produce accepted artifacts. Member counts differ from assertion-batch',
             'counts. Cached trace durations and resources are historical values, so the totals above',
             'exclude them from new solver work. Process times are actual outer verifier durations.',
             '', '## Median verifier process seconds by case', '',
             '| Case | Cold | Shared files | Dependency graph |', '| --- | ---: | ---: | ---: |']
    for case in CASES:
        text.append('| ' + case + ' | ' + ' | '.join(format(summary['per_case'][case][name]['verifier_process_median_ns'] / 1e9, '.3f')
                                                      for name in CONDITIONS) + ' |')
    text += ['', 'The one-file condition concatenates the exact approved declarations and implementation',
             'bodies after removing only their fixed include lines. The shared condition retains their',
             'file layout. Every condition checks the same 22 members and the same candidate changes.',
             'Full source fixtures and hashes accompany the raw logs.', '',
             '## Shared preparation and authoring', '',
             'Failed preparations and development checks remain in the recomputed report. They include',
             'the first two booking proof attempts, the first two trace proof attempts, the hardware',
             'inventory failure, and the report-count correction. Setup costs are not silently assigned',
             'to one condition or omitted from the preparation record.', '',
             '| Runtime token category, recorded interval | Count |', '| --- | ---: |']
    text += ['| ' + key + ' | ' + str(value) + ' |' for key, value in token_totals.items()]
    text += ['', 'The runtime total equals input plus output. Cached input and reasoning output are',
             'reported separately and are not added again. This is a shared authoring interval, not',
             'a comparison of three independent LLM runs or a final whole-project bill. The cutoff,',
             'prior-phase counters, event index, and all usage records are in',
             '[accounting.json](../results/stage6/accounting.json).', '',
             'Recorded human interventions: ' + str(len(accounting['human_interventions'])) +
             '. Automatic goal continuations: ' + str(accounting['automatic_continuation_count']) + '.', '',
             '## Reproduce and limits', '', '```sh', 'python3 scripts/benchmark_reuse.py',
             'python3 scripts/exit_stage_6.py --case report', '```', '',
             'The first command performs a fresh experiment and preserves earlier runs. New times',
             'can differ. The second recomputes totals from the selected recorded experiment and',
             'checks hashes, raw traces, source evidence, controls, and usage sums.', '']
    text += ['- ' + limit for limit in summary['limits']]
    text += ['', 'Native cache reuse retains the stated internal MD5 no-collision and dependency-tracking',
             'assumptions. The acceptance evidence uses fresh full verification without a result cache.',
             'No compiler, binary, deployment, LLM-productivity, or general engineering benefit is claimed.', '']
    (ROOT / 'docs/reuse-benchmark.md').write_text('\n'.join(text))
    print(json.dumps({'exit_code': 0, 'pairs_recomputed': 75, 'usage_records': len(accounting['records']),
                      'report': 'results/stage6/report.json', 'extrapolation': False}))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Exception as error:
        print('REPORT_REJECTED: ' + str(error), file=sys.stderr)
        sys.exit(1)
