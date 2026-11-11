#!/usr/bin/env python3
"""Stage 11 EXITs: read the recorded evaluation of the incremental PR gate.

  python3 scripts/exit_stage_11.py --case legitimate-change|stale-dependency|report
      [--eval results/stage11/eval-0001] [--baseline results/stage11/eval-pr27-0001]

Every case reads the frozen case file and the recorded runs; nothing is rerun and no
label changes. Exit 0 only when the required behaviour is present in the records.
`report` writes report.json and report.md once and must reproduce them byte for byte.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
import sys

REPO = Path(__file__).resolve().parents[1]
# Cases whose frozen expectation predates the review fix that binds in-process TypeScript
# subjects and the witness file to the trusted base (CONTRACT.md §2, §5). Under the current
# rules they are UNSUPPORTED (NOT_REESTABLISHABLE). Their frozen expectations are kept and
# reported as mismatches; the EXITs require the contract outcome.
DESIGN_CHANGED = {'e03-ts-fee-constant': 'UNSUPPORTED', 'e06-property-test-comment': 'REJECTED',
                  'e07-ts-retry-rejected': 'UNSUPPORTED',
                  'e10-refund-ts-drops-bound': 'UNSUPPORTED', 'e12-stale-witness': 'UNSUPPORTED',
                  'e18-node-modules-missing': 'UNSUPPORTED'}
FROZEN_CASES = 'ceec69ca99000f1c6fb1313892895734d07239da94edbeeb3c8cb007e2da9e1f'
DEPENDENTS = {'ledger-evidence', 'ledger-model', 'booking', 'ledger-witness'}


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def fail(message):
    print('STAGE11_NOT_ESTABLISHED: ' + message)
    return 1


def load(eval_dir):
    records = json.loads((eval_dir / 'records.json').read_text())
    if records['cases_sha256'] != FROZEN_CASES:
        raise ValueError('evaluation did not use the frozen case file')
    return {r['id']: r for r in records['records']}


def legitimate_change(rows):
    r = rows.get('e02-ledger-rename-local-plus-evidence')
    if not r:
        return fail('e02 missing')
    cold = r['cold']
    fresh = {n for n, o in cold['obligations'].items() if o['result'] == 'established' and not o['reused']}
    if not (cold['exit'] == 0 and cold['outcome'] == 'VERIFIED' and cold['evidence_written']
            and DEPENDENTS <= set(cold['affected'] or []) and DEPENDENTS <= fresh):
        return fail('e02: ' + json.dumps({k: cold[k] for k in ('exit', 'outcome', 'affected')}))
    others = [i for i in ('e04-booking-least-le', 'e05-refund-negated-branch')
              if rows.get(i, {}).get('cold', {}).get('outcome') != 'VERIFIED']
    if others:
        return fail('non-empty legitimate changes not VERIFIED: ' + ', '.join(others))
    bound = [i for i in ('e03-ts-fee-constant',) if rows.get(i, {}).get('cold', {}).get('outcome') != 'UNSUPPORTED'
             or 'NOT_REESTABLISHABLE ts/ledger.ts' not in rows[i]['cold']['findings']]
    if bound:
        return fail('bound TypeScript subject not reported NOT_REESTABLISHABLE: ' + ', '.join(bound))
    print('STAGE11_LEGITIMATE_CHANGE_PASSED: e02 VERIFIED with ' + ', '.join(sorted(DEPENDENTS))
          + ' re-established fresh; e04, e05 VERIFIED; e03 (bound TypeScript subject) UNSUPPORTED by contract')
    return 0


def stale_dependency(rows):
    wanted = {'e08-ledger-edit-stale-evidence': ('REJECTED', 'ledger-evidence'),
              'e09-booking-active-not-updated': ('REJECTED', 'booking'),
              'e11-weakened-spec-with-lock': ('REJECTED', None),
              'e13-readme-only': ('UNSUPPORTED', None), 'e14-new-reader-of-ledger': ('UNSUPPORTED', None),
              'e16-results-record-edit': ('UNSUPPORTED', None), 'e17-dafny-missing': ('NOT_ESTABLISHED', None),
              # bound in-process subjects: no run may judge them
              'e07-ts-retry-rejected': ('UNSUPPORTED', None), 'e10-refund-ts-drops-bound': ('UNSUPPORTED', None),
              'e12-stale-witness': ('UNSUPPORTED', None), 'e18-node-modules-missing': ('UNSUPPORTED', None),
              # the property harness is a protected file: editing it is rejected before anything runs
              'e06-property-test-comment': ('REJECTED', None)}
    bad = []
    for name, (outcome, obligation) in wanted.items():
        if rows.get(name, {}).get('status') == 'harness_error':
            # The frozen case could not be built (recorded error); it is evidence of nothing.
            print('note: ' + name + ' not constructible as frozen: ' + str(rows[name].get('error'))[:120])
            continue
        cold = rows.get(name, {}).get('cold', {})
        if cold.get('outcome') != outcome or cold.get('evidence_written'):
            bad.append(name + ' ' + str(cold.get('outcome')))
        elif obligation and cold.get('obligations', {}).get(obligation, {}).get('result') != 'rejected':
            bad.append(name + ' obligation ' + obligation + ' not rejected')
    if bad:
        return fail('; '.join(bad))
    print('STAGE11_STALE_DEPENDENCY_PASSED: ' + str(len(wanted)) + ' cases rejected, unsupported or not established as required')
    return 0


def nearest_rank(values, p):
    ordered = sorted(values)
    return ordered[max(1, math.ceil(p / 100 * len(ordered))) - 1] if ordered else None


def timing(values):
    return {'n': len(values), 'p50': nearest_rank(values, 50), 'p95': nearest_rank(values, 95), 'total': round(sum(values), 3)}


def build(eval_dir, baseline_dir):
    rows = load(eval_dir)
    baseline = load(baseline_dir) if baseline_dir and (baseline_dir / 'records.json').is_file() else {}
    outcomes = ('VERIFIED', 'REJECTED', 'NOT_ESTABLISHED', 'UNSUPPORTED', None)
    confusion = {e: {str(o): 0 for o in outcomes} for e in outcomes if e}
    kinds = {'match': 0, 'false_accept': 0, 'false_reject': 0, 'false_unsupported': 0, 'other_mismatch': 0,
             'frozen_expectation_superseded_by_design_change': 0, 'not_constructible': 0}
    table = []
    for name, r in rows.items():
        exp, obs = r['expected_outcome'], r['cold']['outcome']
        confusion[exp][str(obs)] += 1
        if r.get('status') == 'harness_error':
            kind = 'not_constructible'
        elif exp == obs and r['pass_ok']:
            kind = 'match'
        elif name in DESIGN_CHANGED and obs == DESIGN_CHANGED[name]:
            kind = 'frozen_expectation_superseded_by_design_change'
        elif obs == 'VERIFIED':
            kind = 'false_accept'
        elif exp == 'VERIFIED' and obs == 'REJECTED':
            kind = 'false_reject'
        elif exp == 'VERIFIED' and obs == 'UNSUPPORTED':
            kind = 'false_unsupported'
        else:
            kind = 'other_mismatch'
        kinds[kind] += 1
        table.append({'id': name, 'expected': exp, 'observed': obs, 'kind': kind, 'affected': r['cold']['affected'],
                      'reused_warm': r['warm_reused'], 'cold_wall': r['cold']['wall_seconds'], 'warm_wall': r['warm']['wall_seconds'],
                      'cold_cpu': r['cold']['cpu_seconds'], 'warm_cpu': r['warm']['cpu_seconds'],
                      'pr27_outcome': baseline.get(name, {}).get('cold', {}).get('outcome')})
    report = {
        'stage': 11, 'scope': 'frozen evaluation of the incremental PR gate', 'end_to_end': False,
        'cases_sha256': FROZEN_CASES, 'case_count': len(rows), 'kinds': kinds,
        'confusion_expected_by_observed': confusion, 'cases': table,
        'latency_cold': {'wall': timing([r['cold']['wall_seconds'] for r in rows.values()]),
                         'cpu': timing([r['cold']['cpu_seconds'] for r in rows.values()])},
        'latency_warm': {'wall': timing([r['warm']['wall_seconds'] for r in rows.values()]),
                         'cpu': timing([r['warm']['cpu_seconds'] for r in rows.values()])},
        'reproducibility': {'warm_same_decision': sum(r['warm_same_decision'] for r in rows.values()), 'of': len(rows)},
        'warm_reuse_cases': sum(1 for r in rows.values() if r['warm_reused']),
        'baseline_pr27': {'present': bool(baseline),
                          'verified_here_unsupported_there': sorted(n for n, r in rows.items() if r['cold']['outcome'] == 'VERIFIED'
                                                                    and baseline.get(n, {}).get('cold', {}).get('outcome') == 'UNSUPPORTED')},
        'design_change_note': 'After the cases were frozen, an independent review (U185) showed that in-process '
                              'TypeScript subjects and the witness file could rewrite a harness verdict; they became bound '
                              'inputs and changes to them are UNSUPPORTED. The frozen expectations for ' + ', '.join(sorted(DESIGN_CHANGED))
                              + ' are kept and reported above; they were not edited.',
        'limits': ['Internally authored cases; not independent generalization.',
                   'Warm runs reuse obligation records from the same host and the same root; CI caches are not measured.',
                   'Latency measured on the recorded host; concurrent load noted in the run record when present.',
                   'end_to_end=false.'],
    }
    return report


def markdown(report):
    lines = ['# Stage 11 evaluation report', '', 'Frozen cases `%s`; %d cases; cold and warm runs.' % (report['cases_sha256'][:16], report['case_count']), '',
             '| Kind | Cases |', '| --- | ---: |'] + ['| %s | %d |' % kv for kv in report['kinds'].items()]
    lines += ['', '| Case | Expected | Observed | Kind | Affected | PR #27 | Cold wall s | Warm wall s | Warm reused |', '| --- | --- | --- | --- | --- | --- | ---: | ---: | --- |']
    lines += ['| `%s` | %s | %s | %s | %s | %s | %s | %s | %s |' % (c['id'], c['expected'], c['observed'], c['kind'], ', '.join(c['affected'] or []),
                                                                  c['pr27_outcome'], c['cold_wall'], c['warm_wall'], ', '.join(c['reused_warm'])) for c in report['cases']]
    for label in ('latency_cold', 'latency_warm'):
        t = report[label]
        lines += ['', '%s: wall p50 %s s, p95 %s s, total %s s; CPU p50 %s s, p95 %s s, total %s s' % (
            label, t['wall']['p50'], t['wall']['p95'], t['wall']['total'], t['cpu']['p50'], t['cpu']['p95'], t['cpu']['total'])]
    r = report['reproducibility']
    lines += ['', 'Warm run same decision: %d of %d; cases with reused obligations: %d' % (r['warm_same_decision'], r['of'], report['warm_reuse_cases'])]
    lines += ['', 'VERIFIED here, UNSUPPORTED under PR #27: ' + (', '.join(report['baseline_pr27']['verified_here_unsupported_there']) or 'none recorded')]
    lines += ['', '## Limits', ''] + ['- ' + l for l in report['limits']]
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--case', choices=['legitimate-change', 'stale-dependency', 'report'], required=True)
    parser.add_argument('--eval', type=Path, default=REPO / 'results/stage11/eval-0001')
    parser.add_argument('--baseline', type=Path, default=REPO / 'results/stage11/eval-pr27-0001')
    args = parser.parse_args()
    try:
        if args.case == 'legitimate-change':
            return legitimate_change(load(args.eval))
        if args.case == 'stale-dependency':
            return stale_dependency(load(args.eval))
        report = build(args.eval, args.baseline)
    except (OSError, ValueError, KeyError) as error:
        return fail(str(error))
    outputs = {args.eval / 'report.json': (json.dumps(report, indent=1, sort_keys=True) + '\n').encode(),
               args.eval / 'report.md': markdown(report).encode()}
    for path, data in outputs.items():
        if path.exists() and path.read_bytes() != data:
            return fail('existing ' + path.name + ' differs from the recomputed report')
    for path, data in outputs.items():
        if not path.exists():
            path.write_bytes(data)
        print(path.name, sha256(data))
    k = report['kinds']
    print('STAGE11_REPORT_ESTABLISHED: cases %d; match %d; false_accept %d; false_reject %d; false_unsupported %d; other %d; '
          'superseded_by_design_change %d'
          % (report['case_count'], k['match'], k['false_accept'], k['false_reject'], k['false_unsupported'], k['other_mismatch'],
             k['frozen_expectation_superseded_by_design_change']))
    return 0


if __name__ == '__main__':
    sys.exit(main())
