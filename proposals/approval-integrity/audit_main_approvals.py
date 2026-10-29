"""Classify each commit on main by how it was authorized, from GitHub's own records.

Read-only. Sources of authority are GitHub's: the rule-suite record of the push
to main (pass, fail or bypass), the merged pull request, its reviews, and the
CODEOWNERS file of the base commit. Nothing here grants or records approval.

  APPROVED      rule suite passed; a code owner other than the PR author approved
                the exact merged head commit; the merge tree equals that head tree.
  OVERRIDE      the rule suite says bypass: an administrator merged past the rules.
  UNAPPROVED    no qualifying approval (or the rule suite failed).
  UNKNOWN       GitHub has no rule-suite record for the push (for example, outside
                the retention window). Never counted as approved.

  python3 audit_main_approvals.py OWNER/REPO COUNT [--rule-suites FILE]

Exit 0 only when every examined commit is APPROVED; 1 otherwise; 2 on usage or API error.
"""
import fnmatch
import json
import subprocess
import sys


def api(path):
    result = subprocess.run(['gh', 'api', '-H', 'Accept: application/vnd.github+json', path],
                            capture_output=True, text=True)
    if result.returncode != 0:
        raise RuntimeError('API ' + path + ': ' + result.stderr.strip())
    return json.loads(result.stdout)


def code_owners(repo, sha):
    try:
        text = subprocess.run(['gh', 'api', '-H', 'Accept: application/vnd.github.raw',
                               f'repos/{repo}/contents/.github/CODEOWNERS?ref={sha}'],
                              capture_output=True, text=True, check=True).stdout
    except subprocess.CalledProcessError:
        return None
    rules = []
    for line in text.splitlines():
        parts = line.split('#', 1)[0].split()
        if len(parts) >= 2:
            rules.append((parts[0], [o.lstrip('@').lower() for o in parts[1:]]))
    return rules


def owners_for(rules, path):
    # CODEOWNERS semantics: the last matching pattern wins.
    owners = None
    for pattern, names in rules:
        anchored = pattern.lstrip('/')
        if pattern.endswith('/'):
            anchored += '**'
        if fnmatch.fnmatch(path, anchored) or fnmatch.fnmatch(path, '*/' + anchored) or anchored == '*':
            owners = names
    return owners or []


def classify(repo, commit, suites):
    record = {'commit': commit['sha'], 'tree': commit['commit']['tree']['sha']}
    suite = suites.get(commit['sha'])
    record['rule_suite'] = suite and {'id': suite['id'], 'result': suite['result'], 'actor': suite['actor_name']}
    pulls = api(f'repos/{repo}/commits/{commit["sha"]}/pulls')
    merged = [p for p in pulls if p.get('merge_commit_sha') == commit['sha']]
    if not merged:
        record.update(status='UNAPPROVED', reason='NO_MERGED_PULL_REQUEST')
        return record
    pull = api(f'repos/{repo}/pulls/{merged[0]["number"]}')
    head, author = pull['head']['sha'], pull['user']['login'].lower()
    head_tree = api(f'repos/{repo}/commits/{head}')['commit']['tree']['sha']
    record.update(pull=pull['number'], author=author, head=head, head_tree=head_tree,
                  merged_by=(pull.get('merged_by') or {}).get('login'))
    files = [f['filename'] for f in api(f'repos/{repo}/pulls/{pull["number"]}/files?per_page=100')]
    rules = code_owners(repo, commit['parents'][0]['sha']) if commit['parents'] else None
    required = set()
    for path in files:
        required.update(owners_for(rules or [], path))
    # Latest review per reviewer before the merge; a later dismissal or change revokes it.
    latest = {}
    for review in api(f'repos/{repo}/pulls/{pull["number"]}/reviews?per_page=100'):
        if review.get('submitted_at') and review['submitted_at'] <= pull['merged_at']:
            latest[review['user']['login'].lower()] = review
    approvers = sorted(login for login, review in latest.items()
                       if review['state'] == 'APPROVED' and review['commit_id'] == head
                       and login != author and (login in required))
    record.update(code_owners_base=None if rules is None else sorted(required), exact_head_owner_approvals=approvers,
                  tree_equals_approved_head=record['tree'] == head_tree)
    if suite is None:
        record.update(status='UNKNOWN', reason='NO_RULE_SUITE_RECORD')
    elif suite['result'] == 'bypass':
        record.update(status='OVERRIDE', reason='RULESET_BYPASS')
    elif suite['result'] != 'pass':
        record.update(status='UNAPPROVED', reason='RULE_SUITE_' + suite['result'].upper())
    elif rules is None:
        record.update(status='UNAPPROVED', reason='NO_CODEOWNERS_AT_BASE')
    elif not approvers:
        record.update(status='UNAPPROVED', reason='NO_EXACT_HEAD_CODE_OWNER_APPROVAL')
    elif not record['tree_equals_approved_head']:
        record.update(status='UNAPPROVED', reason='MERGED_TREE_DIFFERS_FROM_APPROVED_HEAD')
    else:
        record.update(status='APPROVED', reason=None)
    return record


def main():
    if len(sys.argv) not in (3, 5) or (len(sys.argv) == 5 and sys.argv[3] != '--rule-suites'):
        print(__doc__)
        return 2
    repo, count = sys.argv[1], int(sys.argv[2])
    try:
        if len(sys.argv) == 5:
            listed = json.load(open(sys.argv[4]))
        else:
            listed = api(f'repos/{repo}/rulesets/rule-suites?ref=refs/heads/main&time_period=month'
                         '&rule_suite_result=all&per_page=100')
        suites = {s['after_sha']: s for s in listed}
        commits = api(f'repos/{repo}/commits?sha=main&per_page={count}')
        records = [classify(repo, commit, suites) for commit in commits]
    except (RuntimeError, KeyError, ValueError) as error:
        print('ERROR', error)
        return 2
    for record in records:
        print(json.dumps(record, sort_keys=True))
    return 0 if all(r['status'] == 'APPROVED' for r in records) else 1


if __name__ == '__main__':
    sys.exit(main())
