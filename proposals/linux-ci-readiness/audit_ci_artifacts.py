"""Read real GitHub artifact data after authenticated download; never grant admission.

Requires independently fetched GitHub run/artifact metadata and exact expected
head/base. Missing proof or replay observations fail this acceptance observation.
"""
import argparse
import hashlib
import json
from pathlib import Path
import sys
import zipfile


def require(condition, reason):
    if not condition:
        raise ValueError(reason)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--zip', type=Path, required=True)
    p.add_argument('--artifact-json', type=Path, required=True)
    p.add_argument('--run-json', type=Path, required=True)
    p.add_argument('--expected-head', required=True)
    p.add_argument('--expected-base', required=True)
    p.add_argument('--case', choices=['A', 'C'], required=True)
    args = p.parse_args()
    artifact = json.loads(args.artifact_json.read_text())
    run = json.loads(args.run_json.read_text())
    require(artifact['name'] == 'forge-proof-report', 'Wrong artifact name')
    require(artifact['digest'] == 'sha256:' + hashlib.sha256(args.zip.read_bytes()).hexdigest(), 'Artifact digest differs from GitHub metadata')
    require(artifact['workflow_run']['id'] == run['id'], 'Artifact belongs to another run')
    require(run['repository']['full_name'] == 'mack-dot/forge' and run['event'] == 'pull_request_target', 'Wrong repository or trigger')
    require(run['path'] == '.github/workflows/proof-gate.yml' and run['head_sha'] == args.expected_head, 'Wrong workflow or head')
    require(run['conclusion'] == 'success', 'CI run did not succeed')
    with zipfile.ZipFile(args.zip) as stream:
        names = stream.namelist()
        require(len(names) == len(set(names)), 'Duplicate ZIP entries')
        receipts = [n for n in names if n == 'receipt.json' or n.endswith('/receipt.json')]
        require(len(receipts) == 1, 'Exactly one main receipt required')
        receipt_name = receipts[0]
        prefix = receipt_name[:-len('receipt.json')]
        receipt = json.loads(stream.read(receipt_name))
        require(receipt['repository'] == 'mack-dot/forge' and receipt['run_id'] == run['id'], 'Receipt run binding differs')
        require(receipt['head_sha'] == args.expected_head and receipt['base_sha'] == args.expected_base, 'Receipt revision binding differs')
        require(receipt['exit_code'] == 0 and receipt['outcome'] == 'VERIFIED' and receipt['end_to_end'] is False, 'No verified scoped result')
        require(receipt['coverage']['covered'] is True and receipt['coverage']['findings'] == [], 'Missing coverage')
        data = stream.read(prefix + 'evidence.json')
        require(hashlib.sha256(data).hexdigest() == receipt['evidence_sha256'] and json.loads(data) == receipt['evidence'], 'Evidence binding differs')
        require(receipt['operation']['affected_obligations'] == ['ledger-proof','booking'], 'Unexpected obligation set')
        record = receipt['operation']['obligations']['booking']
        require(record['result'] == 'established' and record['reused'] is False and record['commands'], 'No fresh booking execution')
        require(all(x['exit_code'] == 0 for x in record['commands']), 'Booking checker failed')
        require(receipt['replay']['exit_code'] == 0 and receipt['replay']['byte_identical'] is True, 'Replay differs')
        if args.case == 'C':
            # Current workflow does not retain this. Missing data must not pass.
            replay_name = prefix + 'observations/replay-operation.json'
            require(replay_name in names, 'NOT_ESTABLISHED: current workflow omits replay operation; separately reviewed retention is required')
            replay = json.loads(stream.read(replay_name))
            reused = replay['obligations']['booking']
            require(replay['exit_code'] == 0 and replay['outcome'] == 'VERIFIED' and
                    replay['coverage']['covered'] is True and replay['coverage']['findings'] == [], 'Replay not covered')
            require(reused['reused'] is True and reused['result'] == 'established', 'No observed reuse')
            require(reused['cache_key'] == record['cache_key'] and reused['evidence_sha256'] == record['evidence_sha256'], 'Reuse identity differs')
        print(json.dumps({'case': args.case, 'run_id': run['id'], 'head': args.expected_head,
            'observation_checks_passed': True, 'release_admission': False,
            'note': 'Trusts authenticated GitHub metadata and the approved workflow. This is not a signature or approval.'}))


if __name__ == '__main__':
    try:
        main()
    except Exception as error:
        print(type(error).__name__ + ': ' + str(error), file=sys.stderr)
        sys.exit(1)
