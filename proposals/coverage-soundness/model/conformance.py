"""Bounded conformance check: recorded gate runs against the Acceptance.dfy model.

  python3 -I conformance.py OUTPUT_JSON OPERATION_JSON...

For every operation.json the gate wrote, derive the model's observable facts from
the record itself (never from the outcome) and check that the recorded outcome and
exit code equal Decide(run) under the model's step order, and that the terminal
record has the shape the contract requires. This is evidence over recorded traces,
not a proof about the implementation.
"""
import json
from pathlib import Path
import sys

REJECTED_PREFIXES = ('UNAPPROVED_PROTECTED_CHANGE', 'APPROVAL_BINDING', 'PROTECTED_SYMLINK', 'SOURCE_SYMLINK',
                     'SOURCE_SCOPE', 'SPEC_LOCK', 'TOOLCHAIN_LOCK', 'AUDIT_REJECTED', 'VERIFICATION_REJECTED',
                     'PROOF_COVERAGE', 'CACHE_ORIGIN', 'INPUT_CHANGED', 'REPRODUCTION_INPUT', 'CLAIM_MARKERS',
                     'SCHEMA_REJECTED', 'ARTIFACT_MISMATCH', 'POLICY_BINDING', 'TRUSTED_INPUTS', 'CLAIM_BINDING',
                     'MISSING_CLAIM', 'MISSING_EVIDENCE', 'METHOD_POLICY', 'OUTPUT_SCOPE', 'COVERAGE_SCOPE',
                     'BACKEND_BINDING', 'ARTIFACT_KIND', 'LEGACY_BUNDLE', 'DOCUMENT_FORMAT', 'POLICY_TIER')
AUTH_PREFIXES = ('UNAPPROVED_PROTECTED_CHANGE', 'APPROVAL_BINDING', 'PROTECTED_SYMLINK')
EXIT = {'VERIFIED': 0, 'REJECTED': 1, 'NOT_ESTABLISHED': 2, 'UNSUPPORTED': 3}


def decide(run):
    """Acceptance.Decide, transcribed from Acceptance.dfy."""
    if not run['toolsOk']:
        return 'NOT_ESTABLISHED'
    if not run['authorizationOk']:
        return 'REJECTED'
    if not run['proofOk']:
        return 'REJECTED'
    if not run['artifactBound']:
        return 'REJECTED'
    return 'VERIFIED' if run['coverageOk'] else 'UNSUPPORTED'


def facts(op):
    """Observable facts from the record. Each is derived from evidence other than the outcome."""
    error = op.get('error', '') or ''
    prefix = error.split(':', 1)[0]
    rejected = prefix in REJECTED_PREFIXES
    snapshots = op.get('snapshots')
    proof_complete = (isinstance(snapshots, list) and len(snapshots) == 2 and not snapshots[0]['reused']
                      and all(c['exit_code'] == 0 for c in op['commands']))
    coverage = op.get('coverage')
    return {
        # A tool/infrastructure failure leaves an error that is not a policy rejection, or no commands.
        # UNSUPPORTED is a coverage verdict recorded in the same field, not a tool error.
        'toolsOk': not (error and not rejected and prefix != 'UNSUPPORTED'),
        'authorizationOk': prefix not in AUTH_PREFIXES,
        'proofOk': proof_complete and prefix not in ('AUDIT_REJECTED', 'VERIFICATION_REJECTED', 'PROOF_COVERAGE',
                                                     'CACHE_ORIGIN', 'SOURCE_SCOPE', 'SPEC_LOCK', 'TOOLCHAIN_LOCK',
                                                     'CLAIM_MARKERS'),
        # Evidence validated and inputs re-hashed: the gate reached the coverage decision.
        'artifactBound': isinstance(coverage, dict) and prefix not in ('INPUT_CHANGED', 'REPRODUCTION_INPUT'),
        'coverageOk': isinstance(coverage, dict) and coverage.get('covered') is True and coverage.get('findings') == [],
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
        predicted = decide(run)
        recorded = op.get('outcome')
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
