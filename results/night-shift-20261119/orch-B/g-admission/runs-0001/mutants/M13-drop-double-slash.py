#!/usr/bin/env python3
"""Post the forge/admission status from the bound gate receipt (UNAPPLIED PROPOSAL, worker Y8, 2026-11-19).

Runs in the report job of proof-gate.yml, after post_pr_report.py has bound the receipt to the event.
It reads only the trusted base checkout and the receipt artifact. It never reads PR source.
Exit 0 is ADMITTED. Exit 3 is ADMITTED only when every changed path is a document that no obligation reads.
Every other result, and every malformed input, is NOT ADMITTED. Admission does not approve: merge still needs
the owner's code-owner review under the ruleset.
"""

import json
import os
from pathlib import Path
import re
import sys
import urllib.request

from common import ROOT, read_json

DOCUMENT_PATH = re.compile(r'(?:[A-Za-z0-9_.-]+|(?:proposals|docs|results)/[A-Za-z0-9_./-]+)\.(?:md|txt)')
NEVER_DOCUMENT = ('.github/', 'gate/', 'toolchain/', 'spec/', 'impl/', 'governance/', 'clearing/', 'bugs/',
                  'policy/', 'scripts/', 'schemas/')


def admission(code, coverage):
    """Return (admitted, description) from the gate exit and the trusted coverage record only."""
    if code == 0:
        return True, 'Admitted: verified (exit 0)'
    if code != 3 or not isinstance(coverage, dict):
        return False, 'Not admitted: gate exit ' + str(code)
    rows, findings = coverage.get('changed'), coverage.get('findings')
    if (not isinstance(rows, list) or not rows or not isinstance(findings, list) or not findings
            or coverage.get('affected_obligations') != ['ledger-proof']):
        return False, 'Not admitted: exit 3 and an obligation input or no change record'
    paths = set()
    for row in rows:
        path = row.get('path') if isinstance(row, dict) else None
        if (not isinstance(path, str) or '..' in path.split('/')
                or path.lower().startswith(NEVER_DOCUMENT) or not DOCUMENT_PATH.fullmatch(path)):
            return False, 'Not admitted: exit 3 and a change that is not a document'
        paths.add(path)
    if any(not isinstance(item, dict) or item.get('reason') != 'UNCOVERED_CHANGE' or item.get('path') not in paths
           for item in findings):
        return False, 'Not admitted: exit 3 with a dependency or obligation finding'
    return True, 'Admitted as documents only (exit 3); owner review is still required'


def api(method, path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    request = urllib.request.Request('https://api.github.com' + path, data=data, method=method,
        headers={'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
                 'Accept': 'application/vnd.github+json', 'Content-Type': 'application/json',
                 'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'forge-admission'})
    with urllib.request.urlopen(request) as response:
        return json.load(response)


def main():
    event = read_json(Path(os.environ['GITHUB_EVENT_PATH']))
    expected = event['pull_request']
    repository = os.environ['GITHUB_REPOSITORY']
    if repository != 'mack-dot/forge' or expected['base']['ref'] != 'main':
        raise RuntimeError('ADMISSION_SCOPE: unexpected repository or base branch')
    receipt = read_json(ROOT / 'build/report/receipt.json')
    run_id = int(os.environ['GITHUB_RUN_ID'])
    for name, value in {'repository': repository, 'pr_number': expected['number'], 'run_id': run_id,
                        'base_sha': expected['base']['sha'], 'head_sha': expected['head']['sha']}.items():
        if receipt.get(name) != value:
            raise RuntimeError('ADMISSION_BINDING: mismatched ' + name)
    current = api('GET', '/repos/' + repository + '/pulls/' + str(expected['number']))
    if current['head']['sha'] != receipt['head_sha'] or current['base']['sha'] != receipt['base_sha']:
        raise RuntimeError('ADMISSION_STALE: PR head or base changed; a fresh check is required')
    code = receipt.get('exit_code')
    if type(code) is not int or receipt.get('end_to_end') is not False:
        raise RuntimeError('ADMISSION_FORMAT: unsupported receipt')
    admitted, reason = admission(code, receipt.get('coverage'))
    status = api('POST', '/repos/' + repository + '/statuses/' + receipt['head_sha'],
                 {'state': 'success' if admitted else 'failure', 'context': 'forge/admission',
                  'target_url': 'https://github.com/' + repository + '/actions/runs/' + str(run_id),
                  'description': reason})
    print(json.dumps({'status_id': status['id'], 'admitted': admitted, 'head_sha': receipt['head_sha'],
                      'exit_code': code}), flush=True)
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
