"""Controller-side checks of a no-signing v3.4 rehearsal run, with tamper controls.

Copy of proposals/provenance-hosted-v33/verify_rehearsal.py. Added: approved
lineage of the source commit with the installed v3.4 code, a lineage control,
and a fetch that keeps raw records and rejects every GitHub error (5xx too).

  python3 -I -S -B verify_rehearsal.py CONTROLLER_CLONE REHEARSAL_DIR RUN_ID OUTPUT

Runs the installed code from CONTROLLER_CLONE (a fresh clone of main). The
GitHub run record is read through `gh api` with the operator's read access; the
verifier's own token path is not exercised. Exit 0 when every check passes and
every control is rejected with its intended reason.
"""
import hashlib
import json
import os
import re
from pathlib import Path
import shutil
import sqlite3
import stat
import subprocess
import sys

CLONE, REH, RUN, OUT = Path(sys.argv[1]), Path(sys.argv[2]), sys.argv[3], Path(sys.argv[4])
sys.path.insert(0, str(CLONE / 'gate/provenance'))
import common  # noqa: E402
from common import Rejected, canonical, context, read, sha, write  # noqa: E402
import producer  # noqa: E402
import release  # noqa: E402


def gh_fetch(url, records, label, *, token_name=None):
    child = subprocess.run(['gh', 'api', url.replace('https://api.github.com/', '')], capture_output=True)
    if child.returncode:
        # Any API failure, including 5xx, is a rejection: never accepted metadata.
        found = re.search(r'HTTP (\d{3})', child.stderr.decode(errors='replace'))
        raise Rejected('GITHUB_HTTP_STATUS:' + (found.group(1) if found else 'gh-api-error'))
    (records.directory / (label + '.bytes')).write_bytes(child.stdout)
    write(records.directory / (label + '.http.json'), {'url': url, 'http_status': 200, 'sha256': sha(child.stdout)})
    return child.stdout


common.fetch = gh_fetch
LOCK = sha((CLONE / 'gate/provenance/implementation.lock').read_bytes())
policy, lock, _ = context(LOCK)
X = REH / 'artifact/x'
OUT.mkdir(parents=True, exist_ok=False)
request = read(REH / 'request/request.json')
row = sqlite3.connect(REH / 'controller/controller.sqlite').execute(
    'SELECT request, state FROM requests WHERE challenge=?', (request['challenge'],)).fetchone()
artifact = json.loads(subprocess.run(['gh', 'api', f'repos/{policy["signer"]["repository"]}/actions/runs/{RUN}/artifacts'],
                                     capture_output=True, check=True).stdout)['artifacts'][0]
results = []


def lineage_refused(req):
    try:
        common.approved_lineage(policy, req['expected_source_commit'], common.Records(OUT / 'lineage-control'))
    except Rejected as error:
        return error.reason.startswith('UNAPPROVED_LINEAGE:NO_EXACT_HEAD_OWNER_APPROVAL:19c4896b')
    return False


def check(name, claim, fn):
    try:
        verdict = 'PASS' if fn() is not False else 'FAIL'
        detail = ''
    except Rejected as error:
        verdict, detail = 'REJECTED', error.reason
    results.append({'check': name, 'claim': claim, 'verdict': verdict, 'detail': detail})
    print(name, '|', verdict, '|', detail, flush=True)


receipt = read(X / 'proof/receipt.json')
check('artifact-digest', 'downloaded zip = digest GitHub recorded for this run', lambda:
      'sha256:' + hashlib.sha256((REH / 'artifact/artifact.zip').read_bytes()).hexdigest() == artifact['digest'])
check('request-matches-controller', 'the run used the exact pending controller request', lambda:
      canonical(read(X / 'request.json')) == canonical(request) == row[0] and row[1] == 'pending')
check('package-binding', 'hosted package = controller package; ELF bytes = policy ELF', lambda:
      release.validate_package(policy, request, X) or True)
check('receipt-binding', 'receipt bound to challenge, commit, run record format and file digests', lambda:
      release.validate_receipt(X / 'proof', policy, lock, request) or True)
check('receipt-names-this-run', 'the receipt records this run, attempt 1', lambda:
      receipt['execution'] == {'run_id': RUN, 'run_attempt': '1'})
check('run-identity', 'GitHub run record: workflow, branch, commit, event, attempt, title = challenge, success', lambda:
      common.run_identity(policy, request, receipt['execution'], common.Records(OUT / 'run-identity')) or True)
evidence = read(X / 'evidence.json')
check('evidence-expected', 'evidence = controller-computed canonical evidence', lambda:
      canonical(evidence) == canonical(producer.expected_canonical(policy, lock, LOCK, request['package'])))
check('approved-lineage', 'owner-approved lineage from the source commit to a ratified baseline (installed v3.4)', lambda:
      print(json.dumps(common.approved_lineage(policy, request['expected_source_commit'], common.Records(OUT / 'lineage')))) or True)
check('lineage-control-override-source', 'a request naming override commit 19c4896b is refused by lineage', lambda:
      lineage_refused(dict(request, expected_source_commit='19c4896ba78cc9e41bbadaf8c804b8e74af20125')))
check('statement-binding', 'unsigned statement binds ELF, package, request, evidence and receipt digests', lambda:
      canonical(read(X / 'statement.json')) == canonical(producer.statement(
          policy, request, evidence, sha((X / 'proof/receipt.json').read_bytes()))))


def control(name, mutate, fn, expect):
    target = OUT / 'controls' / name
    shutil.copytree(X / 'proof', target / 'proof')
    for root, _, names in os.walk(target):
        for item in names:
            os.chmod(Path(root) / item, stat.S_IRUSR | stat.S_IWUSR)
    mutate(target)
    try:
        fn(target)
        got = 'ACCEPTED'
    except Rejected as error:
        got = error.reason
    results.append({'check': 'control:' + name, 'expected': expect, 'observed': got,
                    'verdict': 'PASS' if got.startswith(expect) else 'FAIL'})
    print('control', name, '| expected', expect, '| observed', got, flush=True)
    shutil.rmtree(target)


def relabel(**fields):
    def mutate(target):
        manifest = read(target / 'proof/receipt.json')
        manifest.update(fields)
        common.write(target / 'proof/receipt.json', manifest)
    return mutate


def admit(req):
    def fn(target):
        release.validate_receipt(target / 'proof', policy, lock, req)
        common.run_identity(policy, req, read(target / 'proof/receipt.json')['execution'],
                            common.Records(target / 'records'))
    return fn


other = dict(request, challenge='ab' * 32)
control('relabelled-to-a-new-challenge', relabel(challenge=other['challenge']), admit(other), 'PROOF_RUN_IDENTITY')
control('receipt-names-the-v32-rehearsal-run', relabel(execution={'run_id': '40810179164', 'run_attempt': '1'}),
        admit(request), 'PROOF_RUN_IDENTITY')
control('receipt-claims-a-rerun', relabel(execution={'run_id': RUN, 'run_attempt': '2'}), admit(request),
        'PROOF_RECEIPT_EXECUTION')
control('receipt-from-a-different-request', lambda t: None, admit(other), 'STALE_PROOF_RECEIPT')
control('receipt-byte-flip', lambda t: (t / 'proof' / sorted(receipt['files'])[0]).write_bytes(
    bytes([(t / 'proof' / sorted(receipt['files'])[0]).read_bytes()[0] ^ 1])
    + (t / 'proof' / sorted(receipt['files'])[0]).read_bytes()[1:]), admit(request), 'PROOF_RECEIPT_BYTES')
(OUT / 'verification.json').write_text(json.dumps({'run': RUN, 'lock': LOCK, 'artifact': artifact['digest'],
                                                   'receipt_files': len(receipt['files']), 'results': results,
                                                   'end_to_end': False}, indent=2) + '\n')
bad = [r for r in results if r['verdict'] != 'PASS']
print('checks', len(results), 'not passing', len(bad))
sys.exit(1 if bad else 0)
