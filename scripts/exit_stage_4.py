#!/usr/bin/env python3
"""Check real GitHub PR runs and their published receipts; never verify code."""

import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import sys
import urllib.error
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = 'mack-dot/forge'
API = 'https://api.github.com/repos/' + REPOSITORY


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True,
                       allow_nan=False) + '\n').encode()


def sha(data):
    return hashlib.sha256(data).hexdigest()


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


def request(path):
    headers = {'Accept': 'application/vnd.github+json', 'User-Agent': 'forge-stage4-exit',
               'X-GitHub-Api-Version': '2022-11-28'}
    if os.environ.get('GH_TOKEN'):
        headers['Authorization'] = 'Bearer ' + os.environ['GH_TOKEN']
    query = urllib.request.Request(API + path, headers=headers)
    try:
        with urllib.request.build_opener(NoRedirect).open(query) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        if error.code != 302:
            raise
        location = error.headers['Location']
        require(location.startswith('https://'), 'Non-HTTPS log redirect')
        # GitHub job logs use signed URLs. Never forward the API credential.
        with urllib.request.urlopen(location) as response:
            return response.read()


def api(path):
    return json.loads(request(path))


def content(path, revision):
    item = api('/contents/' + path + '?ref=' + revision)
    require(item['encoding'] == 'base64' and item['type'] == 'file', 'Unexpected source response')
    return base64.b64decode(item['content'])


def receipt_from_logs(log):
    marker = 'FORGE_PR_RECEIPT_CHUNK '
    chunks = []
    for line in log.splitlines():
        if marker in line:
            chunks.append(json.loads(line.split(marker, 1)[1]))
    require(bool(chunks), 'No real checker receipt in job logs')
    encoded = ''
    for item in sorted(chunks, key=lambda x: x['offset']):
        require(item['offset'] == len(encoded), 'Missing or duplicate receipt chunk')
        encoded += item['text']
    return json.loads(encoded)


def check(record, variant):
    number, run_id = record['pr_number'], record['run_id']
    base, head = record['base_sha'], record['head_sha']
    run = api('/actions/runs/' + str(run_id))
    positive = variant == 'apply-edit'
    require(run['status'] == 'completed' and run['conclusion'] == ('success' if positive else 'failure'),
            'Run did not finish with the required result')
    require(run['event'] == 'pull_request_target' and run['path'] == '.github/workflows/proof-gate.yml'
            and run['repository']['full_name'] == REPOSITORY and run['head_sha'] == base,
            'Workflow origin or revision mismatch')
    jobs = api('/actions/runs/' + str(run_id) + '/jobs?filter=latest&per_page=100')['jobs']
    verify = [j for j in jobs if j['name'] == 'verify']
    reporting = [j for j in jobs if j['name'] == 'report']
    require(len(verify) == len(reporting) == 1 and reporting[0]['conclusion'] == 'success',
            'Missing successful trusted reporting job')
    require(verify[0]['conclusion'] == ('success' if positive else 'failure'), 'Wrong verification job result')
    steps = {step['name']: step for step in verify[0]['steps']}
    require(steps['Install and authenticate the recorded toolchain bytes']['conclusion'] == 'success',
            'Toolchain installation did not succeed')
    require(steps['Check exact PR revisions with trusted code']['conclusion'] == ('success' if positive else 'failure'),
            'Check step did not produce the expected result')
    receipt = receipt_from_logs(request('/actions/jobs/' + str(verify[0]['id']) + '/logs').decode())
    for key, value in dict(repository=REPOSITORY, pr_number=number, run_id=run_id,
                           base_sha=base, head_sha=head, end_to_end=False).items():
        require(receipt.get(key) == value, 'Receipt mismatch: ' + key)
    code = 0 if positive else 1
    require(receipt['exit_code'] == receipt['operation']['exit_code'] == code, 'Wrong real gate exit code')
    require(receipt['result'] == ('accepted' if positive else 'rejected'), 'Wrong gate result')
    artifacts = api('/actions/runs/' + str(run_id) + '/artifacts?per_page=100')['artifacts']
    artifacts = [a for a in artifacts if a['name'] == 'forge-proof-report' and not a['expired']]
    require(len(artifacts) == 1, 'Missing real report artifact')
    base_spec, head_spec = content('spec/LedgerSpec.dfy', base), content('spec/LedgerSpec.dfy', head)
    head_lock = json.loads(content('spec.lock', head))
    require(head_lock['spec_sha256'] == sha(head_spec), 'Candidate lock does not match its spec')
    if positive:
        require(base_spec == head_spec and content('spec.lock', base) == content('spec.lock', head),
                'Affected-claims PR changed its specification')
        original = content('impl/Ledger.dfy', base)
        target = b'var debit := state.balances[request.sender] - request.amount;'
        require(original.count(target) == 1 and content('impl/Ledger.dfy', head) ==
                original.replace(target, target + b'\n      assert 0 <= debit;', 1), 'Unexpected valid edit')
        snapshots = receipt['operation']['snapshots']
        require(len(snapshots) == 2 and snapshots[0]['checked_count'] == 12
                and snapshots[0]['reused_count'] == 0, 'Baseline was not fully checked')
        require(snapshots[1]['checked'] == ['Ledger.Apply (correctness)', 'Ledger.Apply (well-formedness)']
                and snapshots[1]['checked_count'] == 2 and snapshots[1]['reused_count'] == 10,
                'Affected member counts differ from the required demonstration')
        bundle = receipt['evidence']
        require(bundle['end_to_end'] is False and bundle['backend_details']['toolchain_profile'] == 'linux',
                'Evidence coverage or toolchain mismatch')
        require(sha(canonical(bundle)) == receipt['evidence_sha256'], 'Evidence bytes do not match receipt')
        manifest = [{'path': p, 'sha256': sha(content(p, head))}
                    for p in ('impl/Ledger.dfy', 'spec/LedgerSpec.dfy')]
        require(bundle['source_manifest'] == manifest and bundle['artifact']['sha256'] == sha(canonical(manifest)),
                'Artifact does not match actual GitHub source bytes')
        require({x['id'] for x in bundle['claims']} == {'C1', 'C2', 'C3', 'C4', 'C5'}
                and all(x['spec_sha'] == sha(head_spec) for x in bundle['claims']), 'Claim/spec binding mismatch')
        require(len(bundle['evidence']) == 5 and {x['claim_id'] for x in bundle['evidence']} == {'C1','C2','C3','C4','C5'}
                and all(x['method'] == 'source_proof' and x['result'] == 'passed'
                        and x['artifact_sha'] == bundle['artifact']['sha256'] for x in bundle['evidence']),
                'Missing or mislabeled source evidence')
        require(receipt['replay']['exit_code'] == 0 and receipt['replay']['byte_identical'] is True,
                'Literal reproduction did not succeed')
    else:
        expected = base_spec + b'\n// Unapproved spec revision.\n'
        if variant == 'weaken-c2':
            target = b'    forall account | account in balances :: 0 <= balances[account]'
            require(base_spec.count(target) == 1, 'C2 fixture target changed')
            expected = base_spec.replace(target, b'    true', 1)
        require(head_spec == expected, 'Wrong unapproved-spec mutation')
        require(receipt['evidence'] is None and receipt['evidence_sha256'] is None,
                'Rejected PR emitted accepted evidence')
        require(receipt['operation'].get('error', '').startswith('UNAPPROVED_PROTECTED_CHANGE:'),
                'Rejection did not concern unapproved protected inputs')
    comments = api('/issues/' + str(number) + '/comments?per_page=100')
    comments = [c for c in comments if c['user']['login'] == 'github-actions[bot]'
                and '<!-- forge-proof-gate -->' in c['body'] and head in c['body'] and receipt['run_url'] in c['body']]
    require(bool(comments) and all('| ' + c + ' |' in comments[-1]['body'] for c in ('C1','C2','C3','C4','C5')),
            'Missing plain-English claims table for the checked revision')
    statuses = api('/commits/' + head + '/statuses?per_page=100')
    statuses = [s for s in statuses if s['context'] == 'forge/proof-gate' and s['target_url'] == receipt['run_url']]
    require(bool(statuses) and statuses[0]['state'] == ('success' if positive else 'failure'), 'Missing matching commit status')
    return {'variant': variant, 'run_url': receipt['run_url'], 'pr_number': number,
            'gate_exit_code': code, 'receipt': receipt, 'verify_job_id': verify[0]['id'],
            'report_job_id': reporting[0]['id'], 'artifact_id': artifacts[0]['id'],
            'comment_url': comments[-1]['html_url'], 'status_id': statuses[0]['id']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', required=True, choices=('affected-claims', 'unapproved-spec', 'approved-spec'))
    case = parser.parse_args().case
    report = {'stage': 4, 'case': case, 'stage_exit': True, 'end_to_end': False, 'runs': []}
    destination = ROOT / 'build/stage4-exits' / (case + '.json')
    destination.parent.mkdir(parents=True, exist_ok=True)
    require(not destination.exists(), 'Preserve the prior EXIT report before running again')
    try:
        require(case != 'approved-spec', 'The exact fee proposal and human approval are still pending')
        records = json.loads((ROOT / 'results/stage4/pr-runs.json').read_text())
        variants = ['apply-edit'] if case == 'affected-claims' else ['spec-and-lock', 'weaken-c2']
        for variant in variants:
            report['runs'].append(check(records[variant], variant))
        report.update(result='passed', exit_code=0)
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        report.update(result='failed', exit_code=1, error=str(error))
    destination.write_bytes(canonical(report))
    print('FORGE_EXIT_RESULT ' + json.dumps({k: v for k, v in report.items() if k != 'runs'}), flush=True)
    encoded = json.dumps(report, sort_keys=True, separators=(',', ':'))
    for offset in range(0, len(encoded), 12000):
        print('FORGE_EXIT_CHUNK ' + json.dumps({'offset': offset, 'text': encoded[offset:offset+12000]}), flush=True)
    return report['exit_code']


if __name__ == '__main__':
    sys.exit(main())
