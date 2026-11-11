"""Release admission by approved lineage (proposal; the body below the marker is the
exact text proposed for gate/provenance/common.py, after run_identity).

Standalone use imports the installed common.py. Nothing here signs, merges or
writes to GitHub.
"""
import base64
import re

from common import Rejected, fetch, parse, require

# --- proposed for gate/provenance/common.py ---
RATIFICATIONS = 'governance/ratifications'


def ratified_baselines(get, commit):
    # Records live in the source tree, so the approvals checked below also cover them.
    try:
        listing = get('/contents/' + RATIFICATIONS + '?ref=' + commit)
    except Rejected as error:
        if error.reason != 'GITHUB_HTTP_STATUS:404':
            raise
        return {}
    require(isinstance(listing, list), 'RATIFICATION_ENTRY')
    baselines = {}
    for entry in listing:
        require(entry['type'] == 'file' and re.fullmatch(r'[0-9a-z-]+\.json', entry['name']), 'RATIFICATION_ENTRY')
        record = parse(base64.b64decode(get('/contents/' + entry['path'] + '?ref=' + commit)['content']))
        require(isinstance(record, dict) and set(record) == {'schema', 'baseline', 'covers', 'statement'}
                and record['schema'] == 'forge.ratification/1'
                and set(record['baseline']) == {'commit', 'tree', 'implementation_lock_sha256'}
                and all(re.fullmatch('[0-9a-f]{40}', record['baseline'][key]) for key in ('commit', 'tree')),
                'RATIFICATION_RECORD')
        tree = baselines.setdefault(record['baseline']['commit'], record['baseline']['tree'])
        require(tree == record['baseline']['tree'], 'RATIFICATION_CONFLICT')
    return baselines


def approved_merge(get, policy, sha):
    node = get('/commits/' + sha)
    pulls = [p for p in get('/commits/' + sha + '/pulls') if p.get('merge_commit_sha') == sha]
    require(len(pulls) == 1, 'UNAPPROVED_LINEAGE:NO_MERGED_PULL_REQUEST:' + sha)
    pull = get('/pulls/' + str(pulls[0]['number']))
    require(pull['merged'] and pull['merge_commit_sha'] == sha
            and 'refs/heads/' + pull['base']['ref'] == policy['signer']['ref']
            and pull['base']['repo']['id'] == policy['signer']['repository_id'],
            'UNAPPROVED_LINEAGE:PULL_REQUEST:' + sha)
    # The owner's latest decision before the merge must approve the exact merged head.
    head = pull['head']['sha']
    reviews = sorted((r for r in get('/pulls/' + str(pull['number']) + '/reviews?per_page=100')
                      if r['user']['id'] == policy['signer']['owner_id']
                      and r['state'] in ('APPROVED', 'CHANGES_REQUESTED', 'DISMISSED')
                      and r['submitted_at'] <= pull['merged_at']),
                     key=lambda r: (r['submitted_at'], r['id']))
    require(reviews and reviews[-1]['state'] == 'APPROVED' and reviews[-1]['commit_id'] == head,
            'UNAPPROVED_LINEAGE:NO_EXACT_HEAD_OWNER_APPROVAL:' + sha)
    require(node['commit']['tree']['sha'] == get('/commits/' + head)['commit']['tree']['sha'],
            'UNAPPROVED_LINEAGE:MERGED_TREE_DIFFERS_FROM_APPROVED_HEAD:' + sha)
    return node, {'commit': sha, 'pull': pull['number'], 'approved_head': head, 'review': reviews[-1]['id']}


def approved_lineage(policy, commit, records, *, limit=200):
    """Check with the GitHub API that the owner approved every main commit since a ratified baseline.

    The walk follows first parents from the source commit to the nearest commit
    that a ratification record in the source tree names. Every commit before it
    must be one pull request merged into main whose exact head the owner approved
    and whose tree the merge kept. Override merges keep their status; an approved
    record only accepts their result as a baseline. Trust assumption: only the
    owner uses the owner account.
    """
    repo = 'https://api.github.com/repos/' + policy['signer']['repository']
    calls = []

    def get(path):
        calls.append(path)
        return parse(fetch(repo + path, records, 'lineage-%04d' % len(calls),
                           token_name='FORGE_VERIFIER_GITHUB_TOKEN'))

    baselines = ratified_baselines(get, commit)
    approved, sha = [], commit
    while sha not in baselines:
        require(len(approved) < limit, 'UNAPPROVED_LINEAGE:NO_RATIFIED_BASELINE')
        node, record = approved_merge(get, policy, sha)
        approved.append(record)
        require(len(node['parents']) == 1, 'UNAPPROVED_LINEAGE:PARENTS:' + sha)
        sha = node['parents'][0]['sha']
    require(get('/commits/' + sha)['commit']['tree']['sha'] == baselines[sha], 'RATIFICATION_TREE:' + sha)
    return {'source_commit': commit, 'approved_merges': approved, 'ratified_baseline': sha}
