#!/usr/bin/env python3
"""Publish a bounded report from a separate job that never reads PR source."""

import json
import os
from pathlib import Path
import sys
import urllib.request

from common import ROOT, digest, read_json
from backends.dafny import CLAIMS, claim_statements


def api(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request('https://api.github.com' + path, data=data, method=method,
        headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
                 'Accept': 'application/vnd.github+json', 'Content-Type': 'application/json',
                 'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'forge-proof-gate'})
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def safe(value, limit=120):
    """Render untrusted text (candidate paths) as a JSON string literal in a code span."""
    text = json.dumps(str(value)[:limit], ensure_ascii=True)
    return '`' + text.replace('`', '\\u0060') + '`'


def main():
    event = read_json(Path(os.environ['GITHUB_EVENT_PATH']))
    expected = event['pull_request']
    repository = os.environ['GITHUB_REPOSITORY']
    if repository != 'mack-dot/forge' or expected['base']['ref'] != 'main':
        raise RuntimeError('REPORT_SCOPE: unexpected repository or base branch')
    receipt = read_json(ROOT / 'build/report/receipt.json')
    number, run_id = expected['number'], int(os.environ['GITHUB_RUN_ID'])
    for name, value in {'repository': repository, 'pr_number': number, 'run_id': run_id,
                        'base_sha': expected['base']['sha'], 'head_sha': expected['head']['sha']}.items():
        if receipt.get(name) != value:
            raise RuntimeError('REPORT_BINDING: mismatched ' + name)
    current = api('GET', '/repos/' + repository + '/pulls/' + str(number))
    if current['head']['sha'] != receipt['head_sha'] or current['base']['sha'] != receipt['base_sha']:
        raise RuntimeError('REPORT_STALE: PR head or base changed; a fresh check is required')
    code = receipt['exit_code']
    if type(code) is not int or code not in (0, 1, 2, 3) or receipt['end_to_end'] is not False:
        raise RuntimeError('REPORT_FORMAT: unsupported result')
    outcome = {0: 'VERIFIED', 1: 'REJECTED', 2: 'NOT_ESTABLISHED', 3: 'UNSUPPORTED'}[code]
    result = {0: 'verified', 1: 'rejected', 2: 'not_established', 3: 'unsupported'}[code]
    if (receipt['result'] != result or receipt['outcome'] != outcome
            or receipt['operation']['exit_code'] != code or receipt['operation']['outcome'] != outcome):
        raise RuntimeError('REPORT_FORMAT: inconsistent result')
    coverage = receipt.get('coverage')
    if code == 0 and not (isinstance(coverage, dict) and coverage.get('covered') is True
                          and coverage.get('findings') == []):
        raise RuntimeError('REPORT_FORMAT: verified without an established coverage record')
    if code == 3 and not (isinstance(coverage, dict) and coverage.get('covered') is False
                          and isinstance(coverage.get('findings'), list) and coverage['findings']):
        raise RuntimeError('REPORT_FORMAT: unsupported without coverage findings')
    run_url = 'https://github.com/' + repository + '/actions/runs/' + str(run_id)
    rows = ['<!-- forge-proof-gate -->', '**Forge: ' + outcome + '**', '',
            'Revision: `' + receipt['head_sha'] + '`. Gate exit: `' + str(code) + '`.', '',
            '| Claim | Required behavior | Result | Apply proof |', '| --- | --- | --- | --- |']
    if code == 0:
        evidence = ROOT / 'build/report/evidence.json'
        if digest(evidence.read_bytes()) != receipt['evidence_sha256']:
            raise RuntimeError('REPORT_BINDING: evidence digest mismatch')
        if read_json(evidence) != receipt['evidence'] or receipt['replay']['byte_identical'] is not True:
            raise RuntimeError('REPORT_BINDING: evidence or replay mismatch')
        statuses = receipt['operation']['claim_apply_status']
        if set(statuses) != set(CLAIMS) or any(x not in ('checked', 'reused') for x in statuses.values()):
            raise RuntimeError('REPORT_FORMAT: missing or invalid claim status')
        for claim in sorted(CLAIMS):
            statements = claim_statements(receipt['evidence']['claims'][0]['spec_sha'])
            rows.append('| ' + claim + ' | ' + statements[claim] + ' | source_proof | ' + statuses[claim] + ' |')
        candidate = receipt['operation']['snapshots'][1]
        checked, reused = candidate['checked_count'], candidate['reused_count']
        if any(type(x) is not int or not 0 <= x <= 10000 for x in (checked, reused)):
            raise RuntimeError('REPORT_FORMAT: invalid obligation counts')
        changed = coverage['changed']
        if type(changed) is not list:
            raise RuntimeError('REPORT_FORMAT: invalid change list')
        rows += ['', 'Candidate member obligations: **' + str(checked) + ' checked, ' + str(reused) + ' reused**.',
                 'The baseline was fully verified first. C1–C5 share the Apply obligation.',
                 'The exact saved reproduction command returned identical evidence.',
                 'Artifact SHA-256: `' + receipt['evidence']['artifact']['sha256'] + '`.',
                 'Coverage: ' + str(len(changed)) + ' changed path(s), all within the established ledger scope: '
                 + (', '.join(safe(c['path']) for c in changed[:20]) + ('; …' if len(changed) > 20 else '')
                    if changed else 'no change relative to the trusted base') + '.']
    elif code == 3:
        rows += ['| ' + claim + ' | ' + CLAIMS[claim] + ' | source_proof (ledger only) | — |' for claim in sorted(CLAIMS)]
        findings = coverage['findings']
        if type(findings) is not list:
            raise RuntimeError('REPORT_FORMAT: invalid finding list')
        rows += ['', 'The ledger claims hold, but this change is **not covered** by any established claim:']
        rows += ['- ' + safe(f.get('reason'), 40) + ' ' + safe(f.get('path')) + ': ' + safe(f.get('detail'), 200)
                 for f in findings[:25]]
        if len(findings) > 25:
            rows.append('- … and ' + str(len(findings) - 25) + ' more; see the coverage record in the checker artifact.')
        rows.append('No acceptance was emitted. This is a statement about evidence, not a defect finding.')
    else:
        rows += ['| ' + claim + ' | ' + CLAIMS[claim] + ' | not established | — |' for claim in sorted(CLAIMS)]
        if receipt['operation'].get('error', '').startswith('UNAPPROVED_PROTECTED_CHANGE:'):
            rows += ['', 'The candidate changes protected inputs without approval bound to their exact content.']
        else:
            rows += ['', 'See the checker logs for the failure. No accepted evidence was emitted.']
    rows += ['', '**Scope:** sequential Dafny ledger source only; `end_to_end=false`.',
             'Snapshot reuse trusts Dafny/Boogie dependency tracking and assumes no internal cache-checksum collision.',
             '[Reproduction evidence and checker logs](' + run_url + ').']
    comment = api('POST', '/repos/' + repository + '/issues/' + str(number) + '/comments',
                  {'body': '\n'.join(rows)})
    descriptions = {0: 'Verified: ledger claims established; every change covered',
                    1: 'Rejected: a verification or policy obligation failed',
                    2: 'Not established: the check could not finish',
                    3: 'Unsupported: changes outside every established claim'}
    status = api('POST', '/repos/' + repository + '/statuses/' + receipt['head_sha'],
                 {'state': 'success' if code == 0 else 'failure', 'context': 'forge/proof-gate',
                  'target_url': run_url, 'description': descriptions[code]})
    print(json.dumps({'comment_url': comment['html_url'], 'status_id': status['id'],
                      'head_sha': receipt['head_sha'], 'outcome': outcome}), flush=True)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
