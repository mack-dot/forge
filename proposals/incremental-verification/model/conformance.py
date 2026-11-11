"""Bounded conformance check of recorded Stage 11 gate runs against Acceptance.dfy.

  python3 -I conformance.py OUTPUT_JSON OPERATION_JSON...

Facts are derived from each operation.json without reading its outcome; Decide is the
model's step order. Evidence over recorded traces, not a proof about the implementation.
"""
import json
from pathlib import Path
import sys

AUTH = ('UNAPPROVED_PROTECTED_CHANGE', 'APPROVAL_BINDING', 'PROTECTED_SYMLINK', 'CANDIDATE_SCOPE')
PROOF_REJECT = ('AUDIT_REJECTED', 'VERIFICATION_REJECTED', 'PROOF_COVERAGE', 'CACHE_ORIGIN', 'SOURCE_SCOPE',
                'SPEC_LOCK', 'TOOLCHAIN_LOCK', 'CLAIM_MARKERS', 'SOURCE_SYMLINK')
BIND_REJECT = ('INPUT_CHANGED', 'REPRODUCTION_INPUT', 'SCHEMA_REJECTED', 'ARTIFACT_MISMATCH', 'POLICY_BINDING',
               'TRUSTED_INPUTS', 'CLAIM_BINDING', 'MISSING_CLAIM', 'MISSING_EVIDENCE', 'METHOD_POLICY', 'OUTPUT_SCOPE',
               'COVERAGE_SCOPE', 'BACKEND_BINDING', 'ARTIFACT_KIND', 'LEGACY_BUNDLE', 'DOCUMENT_FORMAT', 'POLICY_TIER')
EXIT = {'VERIFIED': 0, 'REJECTED': 1, 'NOT_ESTABLISHED': 2, 'UNSUPPORTED': 3}


def decide(r):
    if not r['toolsOk']:
        return 'NOT_ESTABLISHED'
    if not r['authorizationOk']:
        return 'REJECTED'
    if not r['proofOk']:
        return 'REJECTED'
    if not r['pathsCovered']:
        return 'UNSUPPORTED'
    if not r['obligationsTooling']:
        return 'NOT_ESTABLISHED'
    if not r['obligationsOk']:
        return 'REJECTED'
    if not r['artifactBound']:
        return 'REJECTED'
    return 'VERIFIED' if r['dependenciesOk'] else 'UNSUPPORTED'


def facts(op):
    error = op.get('error', '') or ''
    prefix = error.split(':', 1)[0]
    known = AUTH + PROOF_REJECT + BIND_REJECT + ('OBLIGATION_REJECTED', 'OBLIGATION_NOT_ESTABLISHED', 'UNSUPPORTED')
    snapshots = op.get('snapshots')
    proof_complete = (isinstance(snapshots, list) and len(snapshots) == 2 and not snapshots[0]['reused']
                      and all(c['exit_code'] == 0 for c in op['commands']))
    records = op.get('obligations') or {}
    affected = [n for n in (op.get('affected_obligations') or []) if n != 'ledger-proof']
    coverage = op.get('coverage')
    return {
        'toolsOk': not (error and prefix not in known),
        'authorizationOk': prefix not in AUTH,
        'proofOk': proof_complete and prefix not in PROOF_REJECT,
        'obligationsTooling': prefix != 'OBLIGATION_NOT_ESTABLISHED'
                              and not any(records.get(n, {}).get('result') == 'not_established' for n in affected),
        'obligationsOk': all(records.get(n, {}).get('result') == 'established' for n in affected)
                         and prefix != 'OBLIGATION_REJECTED',
        'artifactBound': isinstance(coverage, dict) and prefix not in BIND_REJECT,
        # Covered when the record says so, or when obligations ran (they run only on covered changes).
        'pathsCovered': (isinstance(coverage, dict) and not any(f['reason'] in ('UNCOVERED_CHANGE', 'NOT_REESTABLISHABLE')
                                                               for f in coverage.get('findings', []))) or bool(records),
        'dependenciesOk': isinstance(coverage, dict) and coverage.get('covered') is True and coverage.get('findings') == [],
    }


def shape_ok(op, outcome):
    if outcome == 'VERIFIED':
        return bool(op.get('evidence_sha256')) and op.get('result') == 'verified'
    if outcome == 'UNSUPPORTED':
        return not op.get('evidence_sha256') and op['coverage']['findings'] and op.get('result') == 'unsupported'
    if outcome == 'REJECTED':
        return not op.get('evidence_sha256') and op.get('result') == 'rejected'
    return not op.get('evidence_sha256') and op.get('result') == 'not_established'


def main():
    out, paths = Path(sys.argv[1]), sys.argv[2:]
    rows = []
    for name in paths:
        op = json.loads(Path(name).read_text())
        run = facts(op)
        predicted, recorded = decide(run), op.get('outcome')
        rows.append({'record': name, 'facts': run, 'model_outcome': predicted, 'recorded_outcome': recorded,
                     'recorded_exit': op.get('exit_code'),
                     'conforms': predicted == recorded and EXIT.get(recorded) == op.get('exit_code') and shape_ok(op, recorded)})
    bad = [r for r in rows if not r['conforms']]
    out.write_text(json.dumps({'records': len(rows), 'nonconforming': len(bad), 'rows': rows,
                               'scope': 'bounded check over recorded traces; not a proof about the implementation',
                               'end_to_end': False}, indent=1, sort_keys=True) + '\n')
    for r in bad:
        print('NONCONFORMING', r['record'], r['model_outcome'], r['recorded_outcome'], r['recorded_exit'])
    print('records', len(rows), 'nonconforming', len(bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
