"""Collect real GitHub observations. Never grant approval, reuse, or admission."""
import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import subprocess
import zipfile


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--run-id', required=True)
    p.add_argument('--expected-source', required=True)
    p.add_argument('--expected-head', required=True)
    p.add_argument('--out', type=Path, required=True)
    args = p.parse_args()
    assert re.fullmatch('[1-9][0-9]*', args.run_id)
    assert all(re.fullmatch('[0-9a-f]{40}', v) for v in (args.expected_source, args.expected_head))
    args.out.mkdir(parents=True, exist_ok=False)
    prefix = 'repos/mack-dot/forge'
    commands = []

    def api(label, path, pages=False, optional=False, binary=False):
        argv = ['gh', 'api', path] + (['--paginate', '--slurp'] if pages else [])
        child = subprocess.run(argv, capture_output=True)
        (args.out / (label + ('.zip' if binary else '.json'))).write_bytes(child.stdout)
        (args.out / (label + '.stderr')).write_bytes(child.stderr)
        commands.append({'argv': argv, 'exit_code': child.returncode})
        (args.out / 'commands.json').write_text(json.dumps(commands, indent=2) + '\n')
        if child.returncode:
            if optional:
                return None
            raise RuntimeError('GitHub observation unavailable: ' + label)
        return child.stdout if binary else json.loads(child.stdout)

    run = api('run', prefix + '/actions/runs/' + args.run_id)
    assert str(run['id']) == args.run_id and run['repository']['id'] == 1434789853
    assert run['path'] == '.github/workflows/booking-reuse.yml' and run['event'] == 'workflow_dispatch'
    assert run['head_sha'] == args.expected_source and run['head_branch'] == 'main' and run['status'] == 'completed'
    pages = api('jobs', prefix + '/actions/runs/' + args.run_id + '/jobs?filter=all&per_page=100', pages=True)
    jobs = [j for page in pages for j in page['jobs']]
    assert len({j['id'] for j in jobs}) == len(jobs) and jobs
    parse_time = lambda value: datetime.fromisoformat(value.replace('Z', '+00:00'))
    minutes = 0.0
    for job in jobs:
        if job['started_at'] is None or job['completed_at'] is None:
            raise RuntimeError('Job interval incomplete; do not estimate runner use')
        minutes += (parse_time(job['completed_at']) - parse_time(job['started_at'])).total_seconds() / 60
    timing = api('reported-timing', prefix + '/actions/runs/' + args.run_id + '/timing', optional=True)
    artifacts = api('artifacts', prefix + '/actions/runs/' + args.run_id + '/artifacts?per_page=100', pages=True)
    expected_name = 'forge-booking-experiment-' + args.run_id + '-' + str(run['run_attempt'])
    found = [a for page in artifacts for a in page['artifacts'] if a['name'] == expected_name]
    assert len(found) == 1 and not found[0]['expired']
    artifact = found[0]
    assert artifact['workflow_run']['id'] == run['id'] and artifact['workflow_run']['head_sha'] == args.expected_source
    data = api('artifact', prefix + '/actions/artifacts/' + str(artifact['id']) + '/zip', binary=True)
    assert artifact['digest'] == 'sha256:' + hashlib.sha256(data).hexdigest()
    with zipfile.ZipFile(args.out / 'artifact.zip') as archive:
        names = archive.namelist()
        assert len(names) == len(set(names))
        def read(suffix):
            matches = [n for n in names if n == suffix or n.endswith('/' + suffix)]
            assert len(matches) == 1, suffix
            return json.loads(archive.read(matches[0]))
        identity = read('booking-observations/environment.json')
        assert identity['trusted_commit'] == args.expected_source and identity['pr_head'] == args.expected_head
        assert str(identity['run_id']) == args.run_id and str(identity['run_attempt']) == str(run['run_attempt'])
        rows = read('booking-observations/results.json')
        cross = read('booking-observations/cross-process/results.json')
        summary = read('booking-observations/summary.json')
    observations = []
    for row in rows + cross:
        observations.append({k: row[k] for k in ('scenario', 'candidate_commit', 'candidate_source_identity',
            'expected_exit', 'actual_exit', 'cache_hit', 'expensive_booking_verification_executed',
            'wall_seconds', 'evidence_sha256', 'acceptance_passed')})
        observations[-1].update(runner_interval_minutes=row['wall_seconds'] / 60,
                                billed_runner_minutes=None)
    result = {'run_id': args.run_id, 'attempt': run['run_attempt'], 'source': args.expected_source,
              'candidate': args.expected_head, 'run_conclusion': run['conclusion'],
              'artifact_id': artifact['id'], 'artifact_digest': artifact['digest'],
              'summed_job_elapsed_runner_minutes_all_attempts': minutes,
              'reported_billable_milliseconds_by_os': timing.get('billable') if timing else None,
              'actual_billed_runner_minutes': None,
              'actual_billing_note': 'Requires owner billing data; shared job cost has no exact per-case allocation.',
              'cases': observations, 'harness_summary': summary,
              'performance_improvement_claimed': False, 'release_admission': False}
    (args.out / 'measurements.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print('Collected observed timings and identities; no performance saving or admission claimed')


if __name__ == '__main__':
    main()
