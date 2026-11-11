"""Integration status check. This is not proof verification or release admission."""
import argparse
import json
from pathlib import Path


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--local-results', type=Path, required=True)
    p.add_argument('--readiness', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    a = p.parse_args()
    checks = {}
    try:
        rows = json.loads((a.local_results / 'results.json').read_text())
        cross = json.loads((a.local_results / 'cross-process/results.json').read_text())
        cases = {r['scenario']: r for r in rows + cross}
        required = {'A-cold': 0, 'B-warm': 0, 'C-invalidation': 0, 'B-restored-valid': 0,
                    'D-receipt': 1, 'D-artifact': 1, 'D-coherent-rewrite': 1,
                    'D-stale-identity': 1, 'D-harness': 1, 'cross-process': 1,
                    'D-missing-anchor': 1, 'D-invalid-anchor': 1, 'D-uncovered': 3}
        checks['local_adversarial_matrix'] = all(
            name in cases and cases[name]['acceptance_passed'] is True
            and cases[name]['actual_exit'] == code for name, code in required.items())
        checks['observed_safe_local_reuse'] = (
            cases['B-warm']['booking_process_launch_count'] == 0
            and cases['B-warm']['cache_hit'] is True
            and cases['A-cold']['booking_process_launch_count'] == 1
            and cases['C-invalidation']['booking_process_launch_count'] == 1
            and cases['A-cold']['evidence_sha256'] == cases['B-warm']['evidence_sha256'])
    except (OSError, ValueError, KeyError, TypeError):
        checks['local_adversarial_matrix'] = False
        checks['observed_safe_local_reuse'] = False
    readiness = json.loads(a.readiness.read_text())
    # A missing observation is a blocker. Local results cannot fill hosted fields.
    for key in ('pr30_independent_approval', 'pr30_explicit_merge_authorization',
                'repair_approved_and_merged', 'protections_verified', 'off_machine_backup_confirmed',
                'hosted_cold_verified', 'hosted_safe_warm_reuse', 'hosted_invalidation',
                'hosted_adversarial_rejections', 'hosted_reproducibility_and_provenance',
                'hosted_runtime_and_job_minutes_recorded'):
        checks[key] = readiness.get(key) is True
    result = {'integration_exit': 'PASS' if all(checks.values()) else 'NOT_ESTABLISHED',
              'checks': checks, 'blockers': [k for k, v in checks.items() if not v],
              'stage_transition_authorized': False, 'release_admission': False,
              'end_to_end': False}
    a.output.write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(result['integration_exit'])
    return 0 if all(checks.values()) else 1


if __name__ == '__main__':
    raise SystemExit(main())
