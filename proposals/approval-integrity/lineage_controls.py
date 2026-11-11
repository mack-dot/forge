"""Controls for the approved-lineage admission check, on the real GitHub history.

  python3 -I lineage_controls.py FORGE_ROOT OUTPUT [CANDIDATE_DIR]

With CANDIDATE_DIR (build_admission.py output), the controls run the check from
the candidate common.py instead of lineage.py.

GitHub records are read with `gh api` (the operator's read access; the verifier
token path is not exercised). A control marked simulated changes one API
response in memory only; nothing is written to GitHub. Exit 0 when every control
gets its expected outcome.
"""
import base64
import json
from pathlib import Path
import subprocess
import sys

ROOT, OUT = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
CANDIDATE = sys.argv[3:]
sys.path.insert(0, str(Path(CANDIDATE[0]).resolve() if CANDIDATE else ROOT / 'gate/provenance'))
sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402
lineage = common if CANDIDATE else __import__('lineage')

API = 'https://api.github.com/repos/mack-dot/forge'
MERGE = 'aac837a00db4fd5b126a3819449d098d4fcda7ae'      # PR #21, the approved merge
BASE = '19c4896ba78cc9e41bbadaf8c804b8e74af20125'       # PR #20, override; proposed baseline
INSTALL = '241a9def'                                    # PR #19, override (prefix; resolved below)
BRANCH_B = '52cbf8cb917ef27532bdc808389ed6ac9b6d447a'   # control commit, never on main
HEAD_A = '88ad9c72904be116f4616d87ee68e90d34796f38'
HEAD_C = '2e3587f8a17305b5a7f246735ba24596c9d4ed3c'
AGENT_ID = 143109898
CACHE, PATCH = {}, {}


def gh_fetch(url, records, label, *, token_name=None):
    path = url.removeprefix(API)
    if path not in CACHE:
        child = subprocess.run(['gh', 'api', 'repos/mack-dot/forge' + path], capture_output=True)
        CACHE[path] = None if b'HTTP 404' in child.stderr else child.stdout
        if child.returncode and CACHE[path] is not None:
            raise common.Rejected('GITHUB_HTTP_STATUS:gh-api-error')
    data, simulated = CACHE[path], path in PATCH
    if simulated:
        data = PATCH[path](data)
    if data is None:
        raise common.Rejected('GITHUB_HTTP_STATUS:404')
    (records.directory / (label + '.bytes')).write_bytes(data)
    common.write(records.directory / (label + '.http.json'),
                 {'url': url, 'sha256': common.sha(data), 'simulated': simulated})
    return data


lineage.fetch = gh_fetch
policy = common.read(ROOT / 'policy/provenance.json')


def full(prefix):
    return json.loads(subprocess.run(['gh', 'api', 'repos/mack-dot/forge/commits/' + prefix],
                                     capture_output=True, check=True).stdout)['sha']


INSTALL, DIRECT_PUSH = full(INSTALL), full('993bee7b')
OUT.mkdir(parents=True, exist_ok=False)
results = []


def as_json(fn):
    return lambda data: json.dumps(fn(json.loads(data))).encode()


def records_dir(commit, files):
    """Simulated ratification records in the tree of `commit`: {name: bytes}."""
    listing = '/contents/' + lineage.RATIFICATIONS + '?ref=' + commit
    PATCH[listing] = lambda _: json.dumps([{'type': 'file', 'name': name,
                                            'path': lineage.RATIFICATIONS + '/' + name} for name in files]).encode()
    for name, data in files.items():
        PATCH['/contents/' + lineage.RATIFICATIONS + '/' + name + '?ref=' + commit] = (
            lambda _, data=data: json.dumps({'content': base64.b64encode(data).decode()}).encode())


def tree(commit):
    return json.loads(CACHE.get('/commits/' + commit) or subprocess.run(
        ['gh', 'api', 'repos/mack-dot/forge/commits/' + commit], capture_output=True, check=True).stdout)['commit']['tree']['sha']


DRAFT = (Path(__file__).resolve().parent / 'ratification-0001.json').read_bytes()


def record(commit, tree_sha, **extra):
    value = json.loads(DRAFT)
    value['baseline'].update(commit=commit, tree=tree_sha)
    value.update(extra)
    return json.dumps(value).encode()


def control(name, source, expect, *, simulated, setup=lambda: None):
    PATCH.clear()
    setup()
    target = OUT / name
    try:
        got = lineage.approved_lineage(policy, source, common.Records(target))
        observed = 'ACCEPTED'
    except common.Rejected as error:
        got, observed = None, error.reason
    verdict = 'PASS' if observed.startswith(expect) else 'FAIL'
    results.append({'control': name, 'source': source, 'simulated': simulated, 'expected': expect,
                    'observed': observed, 'lineage': got, 'verdict': verdict})
    print(verdict, '|', name, '| expected', expect, '| observed', observed, flush=True)


def reviews_21(fn):
    PATCH['/pulls/21/reviews?per_page=100'] = as_json(fn)


control('main-today-without-ratification', MERGE, 'UNAPPROVED_LINEAGE:NO_EXACT_HEAD_OWNER_APPROVAL:' + BASE,
        simulated=False)
control('direct-push-commit', DIRECT_PUSH, 'UNAPPROVED_LINEAGE:NO_MERGED_PULL_REQUEST', simulated=False)
control('draft-ratification-of-19c4896b-accepts-main', MERGE, 'ACCEPTED', simulated=True,
        setup=lambda: records_dir(MERGE, {'0001-baseline-19c4896b.json': DRAFT}))
control('ratification-names-the-wrong-tree', MERGE, 'RATIFICATION_TREE:' + BASE, simulated=True,
        setup=lambda: records_dir(MERGE, {'0001.json': record(BASE, tree(MERGE))}))
control('ratifying-an-older-override-does-not-cover-a-later-one', MERGE,
        'UNAPPROVED_LINEAGE:NO_EXACT_HEAD_OWNER_APPROVAL:' + BASE, simulated=True,
        setup=lambda: records_dir(MERGE, {'0001.json': record(INSTALL, tree(INSTALL))}))
control('ratifying-a-commit-that-is-not-on-main', MERGE, 'UNAPPROVED_LINEAGE:NO_EXACT_HEAD_OWNER_APPROVAL:' + BASE,
        simulated=True, setup=lambda: records_dir(MERGE, {'0001.json': record(BRANCH_B, tree(BRANCH_B))}))
control('source-is-an-override-merge', BASE, 'UNAPPROVED_LINEAGE:NO_EXACT_HEAD_OWNER_APPROVAL:' + BASE,
        simulated=True, setup=lambda: records_dir(BASE, {'0001.json': record(INSTALL, tree(INSTALL))}))
control('record-has-a-duplicate-key', MERGE, 'DUPLICATE_JSON_KEY', simulated=True,
        setup=lambda: records_dir(MERGE, {'0001.json': DRAFT[:1] + b'"schema": "x",' + DRAFT[1:]}))
control('record-has-an-extra-field', MERGE, 'RATIFICATION_RECORD', simulated=True,
        setup=lambda: records_dir(MERGE, {'0001.json': record(BASE, tree(BASE), override=True)}))
control('two-records-disagree-on-the-tree', MERGE, 'RATIFICATION_CONFLICT', simulated=True,
        setup=lambda: records_dir(MERGE, {'0001.json': DRAFT, '0002.json': record(BASE, tree(MERGE))}))


def with_draft(fn):
    def setup():
        records_dir(MERGE, {'0001.json': DRAFT})
        fn()
    return setup


owner_reviews = 'UNAPPROVED_LINEAGE:NO_EXACT_HEAD_OWNER_APPROVAL:' + MERGE
control('owner-approval-of-the-merged-head-removed', MERGE, owner_reviews, simulated=True,
        setup=with_draft(lambda: reviews_21(lambda rs: [r for r in rs if r['commit_id'] != HEAD_C])))
control('stale-approval-of-an-earlier-head-only', MERGE, owner_reviews, simulated=True,
        setup=with_draft(lambda: reviews_21(lambda rs: [dict(r, state='APPROVED') for r in rs
                                                         if r['commit_id'] == HEAD_A])))
control('approval-by-the-agent-account', MERGE, owner_reviews, simulated=True,
        setup=with_draft(lambda: reviews_21(lambda rs: [dict(r, user=dict(r['user'], id=AGENT_ID)) for r in rs])))
control('approval-submitted-after-the-merge', MERGE, owner_reviews, simulated=True,
        setup=with_draft(lambda: reviews_21(lambda rs: [dict(r, submitted_at='2026-10-29T23:59:59Z')
                                                         if r['commit_id'] == HEAD_C else r for r in rs])))
control('owner-requested-changes-after-approving', MERGE, owner_reviews, simulated=True,
        setup=with_draft(lambda: reviews_21(lambda rs: rs + [dict(rs[-1], id=rs[-1]['id'] + 1, state='CHANGES_REQUESTED',
                                                                  submitted_at='2026-10-29T14:09:20Z')])))
control('merged-tree-differs-from-the-approved-head', MERGE,
        'UNAPPROVED_LINEAGE:MERGED_TREE_DIFFERS_FROM_APPROVED_HEAD:' + MERGE, simulated=True,
        setup=with_draft(lambda: PATCH.update({'/commits/' + HEAD_C: as_json(
            lambda c: dict(c, commit=dict(c['commit'], tree=dict(c['commit']['tree'], sha='0' * 40))))})))
control('pull-request-merged-into-another-branch', MERGE, 'UNAPPROVED_LINEAGE:PULL_REQUEST:' + MERGE, simulated=True,
        setup=with_draft(lambda: PATCH.update({'/pulls/21': as_json(
            lambda p: dict(p, base=dict(p['base'], ref='governance/codeowners')))})))
(OUT / 'results.json').write_text(json.dumps({'results': results, 'end_to_end': False}, indent=2) + '\n')
bad = [r for r in results if r['verdict'] != 'PASS']
print('controls', len(results), 'not passing', len(bad))
sys.exit(1 if bad else 0)
