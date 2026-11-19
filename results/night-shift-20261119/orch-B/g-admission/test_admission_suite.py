#!/usr/bin/env python3
"""Negative and positive tests for the UNAPPLIED admission proposal (task g-admission, 2026-11-19).

Usage: python3 -B test_admission_suite.py ADMISSION_PY [--only-ids FILE] [--json OUT]
No network. No credential. The GitHub API of admission.main() is replaced by a recorder.
GitHub's ruleset behaviour is a LOCAL MODEL written from documentation (ASSUMPTION, not GitHub).
Exit 0 only when every test passes. Each line: PASS|FAIL <id> <group> <text>.
"""

import copy
import importlib.util
import io
import json
import os
from pathlib import Path
import sys
import tempfile
import contextlib

FORGE = Path('<REPO>')
ENF = FORGE / 'proposals/m1b-mission-20261119/drafts/enforcement'
sys.dont_write_bytecode = True
sys.path.insert(0, str(FORGE / 'gate'))

REPO = 'mack-dot/forge'
BASE, HEAD, OTHER = 'b' * 40, 'a' * 40, 'c' * 40
RUN = 4242
ACTIONS_APP = 15368          # GitHub Actions app id per GitHub documentation (not checked live)


def load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# ---------------------------------------------------------------- receipts and records
def cov(paths, findings=None, affected=('ledger-proof',), covered=False):
    return {'changed': [{'path': p, 'change': 'modified'} for p in paths],
            'findings': findings if findings is not None else
            [{'path': p, 'reason': 'UNCOVERED_CHANGE', 'detail': 'x'} for p in paths],
            'affected_obligations': list(affected), 'covered': covered}


DOCS = cov(['ROADMAP.md', 'proposals/m1b/x.md', 'results/a/b.txt'])
VERIFIED = {'changed': [{'path': 'impl/Ledger.dfy', 'change': 'modified', 'covered_by': ['ledger-proof']}],
            'findings': [], 'affected_obligations': ['ledger-proof'], 'covered': True}


def receipt(code, coverage, **over):
    r = {'format_version': 1, 'repository': REPO, 'pr_number': 7, 'base_sha': BASE, 'head_sha': HEAD,
         'run_id': RUN, 'exit_code': code, 'coverage': coverage, 'end_to_end': False}
    r.update(over)
    return r


def event(**over):
    pr = {'number': 7, 'base': {'ref': 'main', 'sha': BASE}, 'head': {'sha': HEAD}}
    pr.update(over)
    return {'pull_request': pr}


def run_main(m, rec, ev=None, live_head=HEAD, live_base=BASE, repository=REPO, run_id=RUN):
    """Run admission.main() in a temp ROOT with a recording API. Return (exit, posted statuses)."""
    posted = []

    def api(method, path, body=None):
        if method == 'GET':
            return {'head': {'sha': live_head}, 'base': {'sha': live_base}}
        posted.append((path, body))
        return {'id': 1}
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp)
        (root / 'build/report').mkdir(parents=True)
        if rec is not None:
            text = rec if isinstance(rec, str) else json.dumps(rec)
            (root / 'build/report/receipt.json').write_text(text)
        (root / 'event.json').write_text(json.dumps(ev if ev is not None else event()))
        saved = {k: os.environ.get(k) for k in ('GITHUB_EVENT_PATH', 'GITHUB_REPOSITORY', 'GITHUB_RUN_ID')}
        os.environ.update({'GITHUB_EVENT_PATH': str(root / 'event.json'), 'GITHUB_REPOSITORY': repository,
                           'GITHUB_RUN_ID': str(run_id)})
        old_api, old_root = m.api, m.ROOT
        m.api, m.ROOT = api, root
        code = None
        try:
            with contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
                try:
                    code = m.main()
                except (OSError, RuntimeError, ValueError, KeyError):
                    code = 2                     # the __main__ wrapper maps these to exit 2
                except Exception:                # e.g. common.Rejected: uncaught -> traceback, exit 1
                    code = 1
        finally:
            m.api, m.ROOT = old_api, old_root
            for k, v in saved.items():
                if v is None:
                    os.environ.pop(k, None)
                else:
                    os.environ[k] = v
    return code, posted


def admitted_status(posted):
    """True only when a success status for forge/admission on HEAD was posted."""
    return any(path.endswith('/statuses/' + HEAD) and body.get('context') == 'forge/admission'
               and body.get('state') == 'success' for path, body in posted)


# ---------------------------------------------------------------- GitHub ruleset model (ASSUMPTION)
def applies(rs, ref):
    inc = rs['conditions']['ref_name']['include']
    if rs['target'] == 'branch':
        return ref.startswith('refs/heads/') and (('~DEFAULT_BRANCH' in inc and ref == 'refs/heads/main')
                                                  or ref in inc or '~ALL' in inc)
    return ref.startswith('refs/tags/') and ('~ALL' in inc or ref in inc)


def rule(rs, kind):
    return [r for r in rs['rules'] if r['type'] == kind]


def bypass(rs, actor):
    return any(a.get('actor_id') == actor.get('id') or (a.get('actor_type') == 'RepositoryRole'
                                                        and actor.get('admin')) for a in rs['bypass_actors'])


def gh_allows(rulesets, op):
    """op: {'kind': push|force_push|delete|create|merge, 'ref', 'actor', ...}. Model of documented semantics."""
    for rs in rulesets:
        if rs['enforcement'] != 'active' or not applies(rs, op['ref']) or bypass(rs, op['actor']):
            continue
        k = op['kind']
        if k == 'delete' and rule(rs, 'deletion'):
            return False
        if k == 'create' and rule(rs, 'creation'):
            return False
        if k in ('push', 'force_push') and rule(rs, 'update'):
            return False
        if k == 'force_push' and rule(rs, 'non_fast_forward'):
            return False
        if k in ('push', 'force_push') and rule(rs, 'pull_request'):
            return False                         # direct push to a PR-only branch
        if k in ('push', 'force_push', 'merge') and rule(rs, 'required_signatures') and not op.get('signed', True):
            return False
        if k == 'merge':
            for r in rule(rs, 'pull_request'):
                p = r['parameters']
                if op.get('method') not in p.get('allowed_merge_methods', ['merge', 'squash', 'rebase']):
                    return False
                good = [v for v in op.get('reviews', []) if v['state'] == 'APPROVED' and v['sha'] == op['head']
                        and v['login'] != op['author'] and (not p['require_code_owner_review']
                                                             or v['login'] in op['codeowners'])]
                if len(good) < p['required_approving_review_count']:
                    return False
            for r in rule(rs, 'required_status_checks'):
                p = r['parameters']
                if p['strict_required_status_checks_policy'] and not op.get('up_to_date', True):
                    return False
                for check in p['required_status_checks']:
                    rows = [s for s in op.get('statuses', []) if s['sha'] == op['head']
                            and s['context'] == check['context']
                            and ('integration_id' not in check or s.get('app_id') == check['integration_id'])]
                    if not rows or rows[-1]['state'] != 'success':
                        return False
    return True


# ---------------------------------------------------------------- tests
def build_tests(m):
    A = m.admission
    T = []

    def t(tid, group, text, fn):
        T.append((tid, group, text, fn))

    no = lambda code, c: (lambda: A(code, c)[0] is False)
    yes = lambda code, c: (lambda: A(code, c)[0] is True)

    # Group N: decision function, every non-pass must be NOT ADMITTED
    t('N01', 'decide-neg', 'exit 1 REJECTED, docs only', no(1, DOCS))
    t('N02', 'decide-neg', 'exit 2 NOT_ESTABLISHED, docs only', no(2, DOCS))
    t('N03', 'decide-neg', 'exit 4 (unknown code)', no(4, DOCS))
    t('N04', 'decide-neg', 'exit 124 (timeout)', no(124, DOCS))
    t('N05', 'decide-neg', 'exit -9 (killed)', no(-9, DOCS))
    t('N06', 'decide-neg', 'exit None (missing)', no(None, DOCS))
    t('N07', 'decide-neg', 'exit "0" (string)', no('0', VERIFIED))
    t('N08', 'decide-neg', 'exit False (bool equals 0 in Python)', no(False, VERIFIED))
    t('N09', 'decide-neg', 'exit 0.0 (float equals 0)', no(0.0, VERIFIED))
    t('N10', 'decide-neg', 'exit 3, no coverage', no(3, None))
    t('N11', 'decide-neg', 'exit 3, code file', no(3, cov(['README.md', 'impl/Refund.dfy'])))
    t('N12', 'decide-neg', 'exit 3, .py under proposals', no(3, cov(['proposals/x/run.py'])))
    t('N13', 'decide-neg', 'exit 3, .sh under results', no(3, cov(['results/x/go.sh'])))
    t('N14', 'decide-neg', 'exit 3, .sml draft', no(3, cov(['proposals/x/Thm.sml'])))
    t('N15', 'decide-neg', 'exit 3, workflow file', no(3, cov(['.github/workflows/x.yml'])))
    t('N16', 'decide-neg', 'exit 3, .md under .github', no(3, cov(['.github/workflows/x.md'])))
    t('N17', 'decide-neg', 'exit 3, gate/approvals record', no(3, cov(['gate/approvals/0002.json'])))
    t('N18', 'decide-neg', 'exit 3, forged approval .md under gate', no(3, cov(['gate/approvals/owner-ok.md'])))
    t('N19', 'decide-neg', 'exit 3, governance record .md', no(3, cov(['governance/gate-ratifications/x.md'])))
    t('N20', 'decide-neg', 'exit 3, upper-case GATE/x.md', no(3, cov(['GATE/x.md'])))
    t('N21', 'decide-neg', 'exit 3, dot-dot escape', no(3, cov(['proposals/../gate/x.md'])))
    t('N22', 'decide-neg', 'exit 3, double slash', no(3, cov(['proposals//x.md'])))
    t('N23', 'decide-neg', 'exit 3, suffix trick a.md.sh', no(3, cov(['proposals/a.md.sh'])))
    t('N24', 'decide-neg', 'exit 3, upper .MD', no(3, cov(['NOTES.MD'])))
    t('N25', 'decide-neg', 'exit 3, json result', no(3, cov(['results/x.json'])))
    t('N26', 'decide-neg', 'exit 3, UNKNOWN_DEPENDENCY', no(3, cov(['README.md'], [{'path': 'README.md', 'reason': 'UNKNOWN_DEPENDENCY'}])))
    t('N27', 'decide-neg', 'exit 3, OBLIGATION_NOT_ESTABLISHED', no(3, cov(['README.md'], [{'path': 'README.md', 'reason': 'OBLIGATION_NOT_ESTABLISHED'}])))
    t('N28', 'decide-neg', 'exit 3, extra affected obligation', no(3, cov(['proposals/refund-decision.md'], affected=['ledger-proof', 'refund'])))
    t('N29', 'decide-neg', 'exit 3, affected obligations empty', no(3, cov(['README.md'], affected=[])))
    t('N30', 'decide-neg', 'exit 3, empty change list', no(3, cov([])))
    t('N31', 'decide-neg', 'exit 3, empty finding list', no(3, cov(['README.md'], [])))
    t('N32', 'decide-neg', 'exit 3, finding on another path', no(3, cov(['README.md'], [{'path': 'impl/x.dfy', 'reason': 'UNCOVERED_CHANGE'}])))
    t('N33', 'decide-neg', 'exit 3, row not a dict', no(3, {**cov(['README.md']), 'changed': ['README.md']}))
    t('N34', 'decide-neg', 'exit 3, path not a string', no(3, {**cov(['README.md']), 'changed': [{'path': 5}]}))
    t('N35', 'decide-neg', 'exit 3, coverage is a list', no(3, [DOCS]))
    t('N36', 'decide-neg', 'exit 3, protected top-level AGENTS.md', no(3, cov(['AGENTS.md'])))
    t('N37', 'decide-neg', 'exit 3, clearing/ .md (never put a file there)', no(3, cov(['clearing/x.md'])))
    t('N38', 'decide-neg', 'exit 3, backslash path', no(3, cov(['proposals\\..\\gate\\x.md'])))
    t('N39', 'decide-neg', 'exit 3, non-ASCII look-alike', no(3, cov(['proposals/x.mԁ'])))

    # Group P: positive controls (a reject-all function must fail here)
    t('P01', 'decide-pos', 'exit 0 verified', yes(0, VERIFIED))
    t('P02', 'decide-pos', 'exit 3 docs only', yes(3, DOCS))
    t('P03', 'decide-pos', 'exit 3 single top-level README.md', yes(3, cov(['README.md'])))
    t('P04', 'decide-pos', 'exit 3 results .txt', yes(3, cov(['results/night/x.txt'])))
    t('P05', 'decide-pos', 'exit 3 docs/ .md', yes(3, cov(['docs/guide.md'])))

    # Group B: binding in admission.main() (recording API; no network)
    def b_neg(rec, **kw):
        def f():
            code, posted = run_main(m, rec, **kw)
            return not admitted_status(posted)
        return f

    def b_pos(rec, **kw):
        def f():
            code, posted = run_main(m, rec, **kw)
            return code == 0 and admitted_status(posted)
        return f

    def b_fail_posted(rec):
        def f():
            code, posted = run_main(m, rec)
            return code == 0 and any(b.get('context') == 'forge/admission' and b.get('state') == 'failure'
                                     for _, b in posted) and not admitted_status(posted)
        return f
    t('B01', 'bind-neg', 'missing receipt (gate timed out or crashed)', b_neg(None))
    t('B02', 'bind-neg', 'receipt not JSON', b_neg('{not json'))
    t('B03', 'bind-neg', 'receipt with duplicate key', b_neg('{"exit_code":0,"exit_code":0}'))
    t('B04', 'bind-neg', 'stale head: PR head moved after the run', b_neg(receipt(0, VERIFIED), live_head=OTHER))
    t('B05', 'bind-neg', 'stale base: main moved after the run', b_neg(receipt(0, VERIFIED), live_base=OTHER))
    t('B06', 'bind-neg', 'receipt for another commit', b_neg(receipt(0, VERIFIED, head_sha=OTHER)))
    t('B07', 'bind-neg', 'receipt for another base', b_neg(receipt(0, VERIFIED, base_sha=OTHER)))
    t('B08', 'bind-neg', 'receipt from another run', b_neg(receipt(0, VERIFIED, run_id=RUN + 1)))
    t('B09', 'bind-neg', 'receipt for another PR', b_neg(receipt(0, VERIFIED, pr_number=8)))
    t('B10', 'bind-neg', 'receipt for another repository', b_neg(receipt(0, VERIFIED, repository='evil/forge')))
    t('B11', 'bind-neg', 'run in a fork repository', b_neg(receipt(0, VERIFIED, repository='evil/forge'), repository='evil/forge'))
    t('B12', 'bind-neg', 'PR base is not main', b_neg(receipt(0, VERIFIED), ev=event(base={'ref': 'dev', 'sha': BASE})))
    t('B13', 'bind-neg', 'exit code is a bool', b_neg(receipt(False, VERIFIED)))
    t('B14', 'bind-neg', 'end_to_end missing', b_neg({k: v for k, v in receipt(0, VERIFIED).items() if k != 'end_to_end'}))
    t('B15', 'bind-neg', 'exit 0 without established coverage', b_neg(receipt(0, cov(['impl/x.dfy']))))
    t('B16', 'bind-neg', 'exit 0 with coverage missing', b_neg(receipt(0, None)))
    t('B17', 'bind-neg', 'exit 3 code change posts failure', b_fail_posted(receipt(3, cov(['impl/x.dfy']))))
    t('B18', 'bind-neg', 'exit 1 posts failure', b_fail_posted(receipt(1, DOCS)))
    t('B19', 'bind-neg', 'exit 2 posts failure', b_fail_posted(receipt(2, DOCS)))
    t('B20', 'bind-neg', 'exit 4 posts failure', b_fail_posted(receipt(4, DOCS)))
    def b_no_success_anywhere(rec, **kw):
        def f():
            code, posted = run_main(m, rec, **kw)
            return not any(b.get('state') == 'success' for _, b in posted)
        return f
    t('B23', 'bind-neg', 'receipt for another commit that is now the live head (event head differs)',
      b_no_success_anywhere(receipt(0, VERIFIED, head_sha=OTHER), live_head=OTHER))
    t('B21', 'bind-pos', 'exit 0 bound receipt posts success on HEAD', b_pos(receipt(0, VERIFIED)))
    t('B22', 'bind-pos', 'exit 3 docs bound receipt posts success on HEAD', b_pos(receipt(3, DOCS)))

    # Group R: ruleset drafts (JSON) under the local GitHub model
    main_rs = json.loads((ENF / 'ruleset-main-admission.json').read_text())
    interim = json.loads((ENF / 'ruleset-main-interim.json').read_text())
    tags = json.loads((ENF / 'ruleset-tags.json').read_text())
    agent = {'id': 2, 'login': 'agent-app', 'admin': False}
    owner = {'id': 1, 'login': 'mack-dot', 'admin': True}
    ok_status = {'sha': HEAD, 'context': 'forge/admission', 'state': 'success', 'app_id': ACTIONS_APP}
    good_merge = {'kind': 'merge', 'ref': 'refs/heads/main', 'actor': owner, 'method': 'squash', 'head': HEAD,
                  'author': 'agent-app', 'codeowners': ['mack-dot'], 'up_to_date': True,
                  'reviews': [{'login': 'mack-dot', 'state': 'APPROVED', 'sha': HEAD}], 'statuses': [ok_status]}

    def merge(**over):
        op = copy.deepcopy(good_merge)
        op.update(over)
        return op
    blocks = lambda rsl, op: (lambda: gh_allows(rsl, op) is False)
    allows = lambda rsl, op: (lambda: gh_allows(rsl, op) is True)
    R = [main_rs, tags]
    t('R01', 'rules-neg', 'direct push to main (agent)', blocks(R, {'kind': 'push', 'ref': 'refs/heads/main', 'actor': agent}))
    t('R02', 'rules-neg', 'direct push to main (owner admin)', blocks(R, {'kind': 'push', 'ref': 'refs/heads/main', 'actor': owner}))
    t('R03', 'rules-neg', 'force-push main', blocks(R, {'kind': 'force_push', 'ref': 'refs/heads/main', 'actor': owner}))
    t('R04', 'rules-neg', 'delete main', blocks(R, {'kind': 'delete', 'ref': 'refs/heads/main', 'actor': owner}))
    t('R05', 'rules-neg', 'admin merge with forge/admission failure', blocks(R, merge(statuses=[{**ok_status, 'state': 'failure'}])))
    t('R06', 'rules-neg', 'merge with the check missing', blocks(R, merge(statuses=[])))
    t('R07', 'rules-neg', 'merge with check pending', blocks(R, merge(statuses=[{**ok_status, 'state': 'pending'}])))
    t('R08', 'rules-neg', 'success on an old head only (stale SHA)', blocks(R, merge(statuses=[{**ok_status, 'sha': OTHER}])))
    t('R09', 'rules-neg', 'success posted by a PAT (no app)', blocks(R, merge(statuses=[{**ok_status, 'app_id': None}])))
    t('R10', 'rules-neg', 'success posted by another App', blocks(R, merge(statuses=[{**ok_status, 'app_id': 999}])))
    t('R11', 'rules-neg', 'success then later failure', blocks(R, merge(statuses=[ok_status, {**ok_status, 'state': 'failure'}])))
    t('R12', 'rules-neg', 'branch behind main (strict)', blocks(R, merge(up_to_date=False)))
    t('R13', 'rules-neg', 'no approving review', blocks(R, merge(reviews=[])))
    t('R14', 'rules-neg', 'self-approval by the PR author', blocks(R, merge(author='mack-dot')))
    t('R15', 'rules-neg', 'approval on an older head (stale review)', blocks(R, merge(reviews=[{'login': 'mack-dot', 'state': 'APPROVED', 'sha': OTHER}])))
    t('R16', 'rules-neg', 'approval by a non-code-owner', blocks(R, merge(reviews=[{'login': 'mackiannii', 'state': 'APPROVED', 'sha': HEAD}])))
    t('R17', 'rules-neg', 'merge-commit method', blocks(R, merge(method='merge')))
    t('R18', 'rules-neg', 'create a tag', blocks(R, {'kind': 'create', 'ref': 'refs/tags/v1', 'actor': owner}))
    t('R19', 'rules-neg', 'move a tag', blocks(R, {'kind': 'force_push', 'ref': 'refs/tags/v1', 'actor': owner}))
    t('R20', 'rules-neg', 'delete a tag', blocks(R, {'kind': 'delete', 'ref': 'refs/tags/v1', 'actor': owner}))
    t('R21', 'rules-neg', 'success from ANOTHER workflow of the same Actions app',
      blocks(R, merge(statuses=[{**ok_status, 'workflow': '.github/workflows/evil.yml'}])))
    t('R22', 'rules-neg', 'interim ruleset: merge with red gate is blocked',
      blocks([interim, tags], merge(statuses=[{**ok_status, 'state': 'failure'}])))
    t('R23', 'rules-pos', 'owner-approved, admitted, squash, up to date', allows(R, good_merge))
    t('R24', 'rules-pos', 'agent may push its own feature branch', allows(R, {'kind': 'push', 'ref': 'refs/heads/agent/x', 'actor': agent}))
    t('R25', 'rules-struct', 'no bypass actor in any draft', lambda: all(rs['bypass_actors'] == [] for rs in (main_rs, interim, tags)))
    t('R26', 'rules-struct', 'required check is forge/admission pinned to an integration', lambda: rule(main_rs, 'required_status_checks')[0]['parameters']['required_status_checks'] == [{'context': 'forge/admission', 'integration_id': ACTIONS_APP}])

    # Group A: approval binding in the trusted gate (gate/approval.py, read-only import)
    approval = load(FORGE / 'gate/approval.py', 'approval_under_test')
    from common import Rejected, digest

    def approval_case(record_in_trusted):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'gate/approvals').mkdir(parents=True)
            (root / 'proposals').mkdir()
            (root / 'proposals/p.md').write_text('forged')
            old = {'spec/LedgerSpec.dfy': 'a' * 64, 'spec.lock': 'b' * 64}
            new = {'spec/LedgerSpec.dfy': 'c' * 64, 'spec.lock': 'd' * 64}
            rec = {'decision': 'approved_as_written', 'base_inputs': old, 'approved_inputs': new,
                   'proposal': 'proposals/p.md', 'proposal_sha256': digest(b'forged'), 'proposal_revision': 'x'}
            trusted = dict(old)
            proposed = dict(new)
            if record_in_trusted:
                (root / 'gate/approvals/9999.json').write_text(json.dumps(rec))
            else:       # record only in the candidate: it changes the protected manifest
                proposed['gate/approvals/9999.json'] = digest(json.dumps(rec).encode())
            try:
                return approval.authorize(root, trusted, proposed)
            except Rejected as error:
                return 'Rejected: ' + str(error).split(':')[0]
    t('A01', 'approval-neg', 'forged approval added in the same PR is ignored',
      lambda: approval_case(False) == 'Rejected: UNAPPROVED_PROTECTED_CHANGE')
    t('A02', 'approval-neg', 'an unsigned record that reached main is NOT accepted without an owner signature',
      lambda: not isinstance(approval_case(True), dict))
    return T


def main():
    target = Path(sys.argv[1])
    m = load(target, 'admission_under_test')
    results = []
    for tid, group, text, fn in build_tests(m):
        try:
            ok = bool(fn())
        except Exception as error:      # a crash is a failure of that test
            ok = False
            text += ' [crash ' + type(error).__name__ + ']'
        results.append({'id': tid, 'group': group, 'pass': ok, 'text': text})
        print(('PASS ' if ok else 'FAIL ') + tid + ' ' + group + ' ' + text)
    fails = [r['id'] for r in results if not r['pass']]
    print('TOTAL %d PASS %d FAIL %d' % (len(results), len(results) - len(fails), len(fails)))
    if '--json' in sys.argv:
        Path(sys.argv[sys.argv.index('--json') + 1]).write_text(json.dumps(results, indent=1))
    return 1 if fails else 0


if __name__ == '__main__':
    sys.exit(main())
