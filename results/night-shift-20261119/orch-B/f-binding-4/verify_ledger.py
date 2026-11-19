#!/usr/bin/env python3
"""Verify ASSURANCE_LEDGER.json against the files (night shift 2026-11-19, Orchestrator B, task f-binding;
extended by task f-binding-2: every earlier check is kept unchanged; the checks marked [f2] are new; extended by task
f-binding-3: every earlier check is kept unchanged; the checks marked [f3] are new or stricter; extended by task
f-binding-4: every earlier check is kept unchanged; the checks marked [f4] are new).

Python 3 standard library only. Without --rerun it runs NO prover: it checks identity and record consistency.
Its first output line says so. Checks (each failure prints a code; any failure refuses, exit 1):
  SCHEMA, BAD_CLASS, DUPLICATE_EDGE, MANDATORY_MISSING, COUNTS_MISMATCH         ledger shape; zero-edge ledger refuses
  NODE_MISSING, DIGEST_MISMATCH, APPROVED_SPEC_STALE, PATH_OUTSIDE              every node recomputed from its file
  UNKNOWN_ASSUMPTION, ASSUMPTION_BACKREF, ASSUMPTION_EMPTY                      assumptions are first-class
  MC_WITHOUT_RUN, MC_DOWNGRADED, LOG_MISSING, LOG_DIGEST, NO_EXIT_LINE,
  EXIT_NOT_ZERO, CMD_FILE_MISMATCH, COMMAND_ROOT_MISMATCH, VERSION_MISMATCH,
  CLOSURE_MISMATCH, F_RECORDS_MISMATCH, CSV_MISSING, CSV_DIGEST, CSV_LEMMA,
  APPROVED_NOT_BOUND, HOL_SOURCE_MISMATCH                                        every MACHINE-CHECKED edge
  [f2] RETIRED_ASSUMPTION_USED, SUPERSEDED_BAD, BAD_ABOUT                        retired assumptions; edge scope label
  [f2] HOL_RUNJSON, HOL_RUNJSON_EXIT, HOL_CMD_MISMATCH, HOL_THEOREM_MISSING,
       HOL_CONTROL_MISMATCH                                                     every MACHINE-CHECKED HOL edge, per run
  [f3] CMD_ROOTS_MISMATCH      the `.dfy` set of each `# cmd:` line equals the run's closure roots (two-root commands)
  [f3] HOL_EXPLORE_RUN         a HOL run log or run record carrying EXPLORE_COMPLETE never supports an edge
  [f3] SUPERSEDED_BAD          also: any `superseded_by` must name a MACHINE-CHECKED edge (not only with retired hypotheses)
  [f4] REVIEW_STATE            every edge has `reviewed` in {true, false, "pending"}; pending <=> review_pending listed
  [f4] REVIEW_NOT_REPORTED     a `reviewed: true` edge names review directories, each REPORTED (REPORT.md in it, or a
                               "<folder> REPORTED" line in orch-B/STATE.md)
  [f4] SUPERSEDED_SOLE_SUPPORT an edge whose `rests_on` (or, without it, whose sub-edges) are all superseded
  [f4] UNKNOWN_EDGE_REF        `rests_on` or `sub_of` names an absent edge
Exit: 0 = consistent; 1 = refused; 2 = usage or unreadable ledger.

  python3 verify_ledger.py [--ledger FILE] [--repo DIR] [--overlay DIR]
  python3 verify_ledger.py --rerun [--execute]   plan (or, with --execute, run) the Dafny edges again through the
                                                 lock script; the orchestrator decides; not executed on 2026-11-19
"""
import argparse, json, os, shutil, subprocess, sys, tempfile, datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import ledger_lib as L

TOP = ['schema', 'what_a_pass_means', 'mandatory_edges', 'counts', 'nodes', 'assumptions', 'edges', 'checker_versions']
REALIZABLE = {'yes', 'no', 'unknown'}
ABOUT = {'DEPLOYED', 'MODEL', 'DRAFT', 'GOVERNANCE'}   # [f2]
STATUS = {'active', 'retired'}                      # [f2]


class V:
    def __init__(self, led, tree, fr, tmp):
        self.led, self.tree, self.fr, self.tmp = led, tree, fr, tmp
        self.problems = []

    def bad(self, code, msg):
        self.problems.append((code, msg))
        print('FAIL %s: %s' % (code, msg))

    def run(self):
        led = self.led
        for k in TOP:
            if k not in led:
                self.bad('SCHEMA', 'top-level key %s absent' % k)
        if self.problems:
            return
        edges = led['edges']
        ids = [e.get('id') for e in edges]
        for i in sorted(set(x for x in ids if ids.count(x) > 1)):
            self.bad('DUPLICATE_EDGE', i)
        for m in led['mandatory_edges']:
            if m not in ids:
                self.bad('MANDATORY_MISSING', 'mandatory edge %s absent' % m)
        if not led['mandatory_edges']:
            self.bad('MANDATORY_MISSING', 'the ledger names no mandatory edge')
        counts = {c: sum(1 for e in edges if e.get('class') == c) for c in L.CLASSES}
        for e in edges:
            if e.get('class') not in L.CLASSES:
                self.bad('BAD_CLASS', '%s: %r' % (e.get('id'), e.get('class')))
        if counts != led['counts']:
            self.bad('COUNTS_MISMATCH', 'stated %s, recomputed %s' % (led['counts'], counts))
        self.counts = counts
        # nodes
        self.nodes = {}
        approved = {}
        for n in led['nodes']:
            p = n.get('path')
            self.nodes[p] = n
            if self.tree.safe_rel(p) is None:
                self.bad('PATH_OUTSIDE', 'node %r' % p); continue
            if not self.tree.exists(p):
                self.bad('NODE_MISSING', p); continue
            h = self.tree.sha(p)
            if h != n.get('sha256'):
                code = 'APPROVED_SPEC_STALE' if n.get('kind') == 'approved spec' else 'DIGEST_MISMATCH'
                self.bad(code, '%s: ledger %s, file %s' % (p, str(n.get('sha256'))[:16], h[:16]))
            if n.get('kind') == 'approved spec':
                approved[p] = n.get('sha256')
                if n.get('slice1_recorded_sha256') and n['slice1_recorded_sha256'] != h:
                    self.bad('APPROVED_SPEC_STALE', '%s differs from the Slice 1 approved record' % p)
        for a in ['spec/refund/protocol.md', 'spec/refund/RefundSpec.dfy', 'spec/refund/spec.lock']:
            if a not in approved:
                self.bad('APPROVED_SPEC_STALE', 'approved spec node %s absent' % a)
        self.approved = approved
        # assumptions
        aids = {}
        for a in led['assumptions']:
            aids[a['id']] = a
            if a.get('realizable') not in REALIZABLE or not a.get('text') or not a.get('real_world'):
                self.bad('SCHEMA', 'assumption %s incomplete' % a.get('id'))
            # [f2] a retired assumption keeps its entry, states why, and is used by no edge
            if a.get('status', 'active') not in STATUS:
                self.bad('SCHEMA', 'assumption %s status %r' % (a.get('id'), a.get('status')))
            if a.get('status') == 'retired':
                if not a.get('retired_reason'):
                    self.bad('SCHEMA', 'retired assumption %s gives no retired_reason' % a.get('id'))
                if a.get('used_by'):
                    self.bad('RETIRED_ASSUMPTION_USED', 'retired %s lists used_by %s' % (a.get('id'), a.get('used_by')))
        for e in edges:
            if e.get('about') not in ABOUT:   # [f2]
                self.bad('BAD_ABOUT', '%s: about=%r' % (e.get('id'), e.get('about')))
            for a in e.get('assumptions', []):
                if a in aids and aids[a].get('status') == 'retired':   # [f2]
                    self.bad('RETIRED_ASSUMPTION_USED', '%s names retired assumption %s' % (e.get('id'), a))
            # [f2] a theorem proved under a hypothesis that is now retired may only be listed as superseded
            rh = e.get('retired_hypotheses') or []
            if e.get('superseded_by') and not rh:   # [f3]
                sup = [x for x in edges if x.get('id') == e.get('superseded_by')]
                if not sup or sup[0].get('class') != 'MACHINE-CHECKED':
                    self.bad('SUPERSEDED_BAD', '%s: superseded_by %r is not a MACHINE-CHECKED edge' % (e.get('id'), e.get('superseded_by')))
            if rh:
                sup = [x for x in edges if x.get('id') == e.get('superseded_by')]
                if not sup or sup[0].get('class') != 'MACHINE-CHECKED':
                    self.bad('SUPERSEDED_BAD', '%s lists retired hypotheses but superseded_by %r is not a MACHINE-CHECKED edge' % (e.get('id'), e.get('superseded_by')))
                for a in rh:
                    if a not in aids or aids[a].get('status') != 'retired':
                        self.bad('SUPERSEDED_BAD', '%s: retired_hypotheses names %s, which is not a retired assumption' % (e.get('id'), a))
            for a in e.get('assumptions', []):
                if a not in aids:
                    self.bad('UNKNOWN_ASSUMPTION', '%s names %s' % (e.get('id'), a))
                elif e.get('id') not in aids[a].get('used_by', []):
                    self.bad('ASSUMPTION_BACKREF', '%s does not list %s in used_by' % (a, e.get('id')))
            if e.get('class') == 'ASSUMPTION' and not e.get('assumptions'):
                self.bad('ASSUMPTION_EMPTY', '%s is an ASSUMPTION edge with no named assumption' % e.get('id'))
        for a in aids.values():
            for u in a.get('used_by', []):
                if u not in ids:
                    self.bad('ASSUMPTION_BACKREF', '%s used_by names absent edge %s' % (a['id'], u))
        # [f4] review state as data; superseded edges may not be the only support of another edge
        for e in edges:
            if 'reviewed' not in e:
                self.bad('REVIEW_STATE', '%s has no reviewed field' % e.get('id')); continue
            for pr in L.review_problems(self.tree, e):
                code = 'REVIEW_NOT_REPORTED' if (e.get('reviewed') is True and not pr.startswith('reviewed=true but review_pending')) else 'REVIEW_STATE'
                self.bad(code, '%s: %s' % (e.get('id'), pr))
            if e.get('sub_of') and e['sub_of'] not in ids:
                self.bad('UNKNOWN_EDGE_REF', '%s sub_of absent edge %s' % (e.get('id'), e['sub_of']))
        for code, msg in L.superseded_support_problems(edges):
            self.bad(code, msg)
        for e in edges:
            if e.get('class') == 'MACHINE-CHECKED':
                self.mc(e)

    def mc(self, e):
        eid = e.get('id')
        if e.get('downgrade_reason'):
            self.bad('MC_DOWNGRADED', '%s is MACHINE-CHECKED but carries a downgrade reason' % eid)
        runs = e.get('runs') or []
        if not runs:
            self.bad('MC_WITHOUT_RUN', '%s has no supporting run with a log' % eid); return
        clo = e.get('closure') or {}
        dafny = str((e.get('checker') or {}).get('name', '')).startswith('Dafny')
        hol = str((e.get('checker') or {}).get('name', '')).startswith('HOL4')
        if not (dafny or hol):
            self.bad('MC_WITHOUT_RUN', '%s: checker %r is neither Dafny nor HOL4' % (eid, e.get('checker'))); return
        for r in runs:
            log = r.get('log')
            if self.tree.safe_rel(log) is None:
                self.bad('PATH_OUTSIDE', '%s: log %r is outside the repository tree' % (eid, log)); continue
            if not self.tree.exists(log):
                self.bad('LOG_MISSING', '%s: %s' % (eid, log)); continue
            if self.tree.sha(log) != r.get('log_sha256'):
                self.bad('LOG_DIGEST', '%s: %s' % (eid, log))
            text = self.tree.text(log)
            form, ex = L.parse_exit(text)
            if ex is None:
                self.bad('NO_EXIT_LINE', '%s: %s' % (eid, log))
            elif ex != 0:
                self.bad('EXIT_NOT_ZERO', '%s: %s ends with exit %d' % (eid, log, ex))
            if dafny:
                cmd = L.header(text, 'cmd')
                entry = Path(r.get('entry') or '').name
                if entry not in L.cmd_dfy_files(cmd):
                    self.bad('CMD_FILE_MISMATCH', '%s: %s `# cmd:` names %s, the run entry is %s' % (eid, log, L.cmd_dfy_files(cmd), entry))
                rp = L.cmd_roots_problem(cmd, r)   # [f3]
                if rp:
                    self.bad('CMD_ROOTS_MISMATCH', '%s: %s: %s' % (eid, log, rp))
                if r is runs[0] and sorted(L.run_entries(r)) != sorted(L.run_entries(clo)):
                    self.bad('CMD_ROOTS_MISMATCH', '%s: primary run roots %s, closure roots %s' % (eid, L.run_entries(r), L.run_entries(clo)))
                if L.header(text, 'dafny') != self.led['checker_versions']['dafny']:
                    self.bad('VERSION_MISMATCH', '%s: %s has dafny %r' % (eid, log, L.header(text, 'dafny')))
                same = r.get('root') == clo.get('root')
                try:
                    rows, missing = L.closure_of(self.tree, self.fr, r['root'], L.entry_arg(r), clo.get('overlay') if same else None,
                                                 clo.get('derive') if same else None, tmpbase=self.tmp)
                except Exception as x:
                    self.bad('CLOSURE_MISMATCH', '%s: closure of %s failed: %s' % (eid, log, x)); continue
                if missing:
                    self.bad('CLOSURE_MISMATCH', '%s: closure missing %s' % (eid, missing))
                if L.set_digest(rows) != clo.get('digest') or r.get('closure_digest') != clo.get('digest'):
                    self.bad('CLOSURE_MISMATCH', '%s: run %s closure now %s, ledger %s' % (eid, log, L.set_digest(rows)[:12], str(clo.get('digest'))[:12]))
                if r is runs[0]:
                    listed = sorted((f['path'], f['sha256']) for f in clo.get('files', []))
                    if listed != rows:
                        diff = sorted(set(rows) ^ set(listed))[:4]
                        self.bad('CLOSURE_MISMATCH', '%s: listed closure files differ from the recomputed closure: %s' % (eid, diff))
                    if L.set_digest(listed) != clo.get('digest') or clo.get('count') != len(listed):
                        self.bad('CLOSURE_MISMATCH', '%s: listed files do not give the stated digest or count' % eid)
                    if e.get('binds_approved_spec') and self.approved.get('spec/refund/RefundSpec.dfy') not in [h for _, h in rows]:
                        self.bad('APPROVED_NOT_BOUND', '%s: closure holds no file byte-equal to the approved RefundSpec.dfy' % eid)
                if r.get('csv'):
                    if not self.tree.exists(r['csv']):
                        self.bad('CSV_MISSING', '%s: %s' % (eid, r['csv']))
                    else:
                        if self.tree.sha(r['csv']) != r.get('csv_sha256'):
                            self.bad('CSV_DIGEST', '%s: %s' % (eid, r['csv']))
                        for b in L.check_required(self.tree.path(r['csv']), e.get('required_lemmas', [])):
                            self.bad('CSV_LEMMA', '%s: %s: %s' % (eid, r['csv'], b))
                elif r is runs[0]:
                    self.bad('CSV_MISSING', '%s: the primary run has no CSV' % eid)
            if hol:
                for f in clo.get('files', []):
                    if not self.tree.exists(f['path']) or self.tree.sha(f['path']) != f['sha256']:
                        self.bad('CLOSURE_MISMATCH', '%s: %s' % (eid, f['path']))
                src = [f for f in clo.get('files', []) if f['path'].endswith('.sml')]
                if not src or r.get('source_sha256_in_run_json') != src[0]['sha256']:
                    self.bad('HOL_SOURCE_MISMATCH', '%s: run.json source digest is not the source file digest' % eid)
                self.hol_run(eid, e, r, text, src[0] if src else None)
        if hol:
            self.hol_controls(eid, e)
        if dafny:
            cmd = e.get('command') or ''
            if Path(clo.get('entry') or '').name not in L.cmd_dfy_files(cmd):
                self.bad('COMMAND_ROOT_MISMATCH', '%s: command names %s, closure entry is %s' % (eid, L.cmd_dfy_files(cmd), clo.get('entry')))
            rp = L.cmd_roots_problem(cmd, clo)   # [f3] the edge command names exactly the closure roots
            if rp:
                self.bad('COMMAND_ROOT_MISMATCH', '%s: edge command: %s' % (eid, rp))
            if clo.get('f_records_proof'):
                recs = json.loads(self.tree.text(L.F_RECORDS + '/PROOF_RECORDS.json'))
                if recs['proofs'][clo['f_records_proof']]['closure_digest'] != clo.get('digest'):
                    self.bad('F_RECORDS_MISMATCH', '%s: PROOF_RECORDS closure differs' % eid)


def _hol_run(self, eid, e, r, text, src):
    """[f2] Per HOL run: re-read the run record (not only the ledger's copy of its fields), its exit, its case id and
    source name; the COMMAND line of a link log; the required theorem names and lines in the log itself."""
    rj = r.get('run_json')
    if L.is_explore(text):   # [f3]
        self.bad('HOL_EXPLORE_RUN', '%s: %s carries %s (exploration run; proves nothing)' % (eid, r.get('log'), L.EXPLORE_MARK))
    if not rj or self.tree.safe_rel(rj) is None or not self.tree.exists(rj):
        self.bad('HOL_RUNJSON', '%s: run record %r absent' % (eid, rj)); return
    if L.is_explore(self.tree.text(rj)):   # [f3]
        self.bad('HOL_EXPLORE_RUN', '%s: run record %s carries %s' % (eid, rj, L.EXPLORE_MARK))
    if self.tree.sha(rj) != r.get('run_json_sha256'):
        self.bad('HOL_RUNJSON', '%s: %s digest differs from the ledger' % (eid, rj))
    try:
        d = json.loads(self.tree.text(rj))
    except Exception as x:
        self.bad('HOL_RUNJSON', '%s: %s unreadable: %s' % (eid, rj, x)); return
    if d.get('actual_exit') != 0:
        self.bad('HOL_RUNJSON_EXIT', '%s: %s actual_exit %r' % (eid, rj, d.get('actual_exit')))
    if d.get('inputs_unchanged_after') is not True:
        self.bad('HOL_SOURCE_MISMATCH', '%s: %s inputs_unchanged_after %r' % (eid, rj, d.get('inputs_unchanged_after')))
    if src is None or d.get('source_sha256') != src['sha256']:
        self.bad('HOL_SOURCE_MISMATCH', '%s: %s source_sha256 is not the closure source digest' % (eid, rj))
    if d.get('case') != r.get('run_id'):
        self.bad('HOL_CMD_MISMATCH', '%s: %s case %r, ledger run id %r' % (eid, rj, d.get('case'), r.get('run_id')))
    if src is None or Path(str(d.get('source'))).name != Path(src['path']).name:
        self.bad('HOL_CMD_MISMATCH', '%s: %s source %r is not the closure source %s' % (eid, rj, d.get('source'), src and src['path']))
    cl = L.hol_command(text)
    if cl is not None and (' %s ' % r.get('run_id') not in cl + ' ' or ' %s' % d.get('source') not in cl):
        self.bad('HOL_CMD_MISMATCH', '%s: COMMAND line does not name run %r and source %r' % (eid, r.get('run_id'), d.get('source')))
    for b in L.hol_check_names(text, e.get('required_theorems', []), e.get('required_lines', [])):
        self.bad('HOL_THEOREM_MISSING', '%s: %s: %s' % (eid, r.get('log'), b))


def _hol_controls(self, eid, e):
    """[f2] Each listed control log exists, has the recorded digest and ends with its expected exit line."""
    for c in e.get('controls', []):
        log = c.get('log')
        if self.tree.safe_rel(log) is None or not self.tree.exists(log):
            self.bad('HOL_CONTROL_MISMATCH', '%s: control %s log %r absent' % (eid, c.get('id'), log)); continue
        if self.tree.sha(log) != c.get('log_sha256'):
            self.bad('HOL_CONTROL_MISMATCH', '%s: control %s log digest differs' % (eid, c.get('id')))
        form, ex = L.parse_exit(self.tree.text(log))
        if form != 'hol-go-wrapper' or ex != c.get('expected_exit'):
            self.bad('HOL_CONTROL_MISMATCH', '%s: control %s ends %r %r, expected go exit %r' % (eid, c.get('id'), form, ex, c.get('expected_exit')))


V.hol_run = _hol_run
V.hol_controls = _hol_controls


def rerun(led, repo, execute):
    """Plan (and with --execute, run) the Dafny edges again. f-records edges: the f-records runner; others: the lock script."""
    here = Path(__file__).resolve().parent
    out = here / ('rerun-' + datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ'))
    lock = repo / L.NIGHT / 'orch-B/tools/dafny_locked.sh'
    dafny = repo / '.toolchain/dafny-4.11.0/dafny/dafny'
    z3 = repo / '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1'
    gate = ['--solver-path', str(z3), '--resource-limit', '1000000', '--verification-time-limit', '0', '--cores', '1',
            '--verify-included-files', '--track-print-effects']
    plan, seen = [], set()
    for e in led['edges']:
        if e.get('class') != 'MACHINE-CHECKED' or not str(e.get('checker', {}).get('name', '')).startswith('Dafny'):
            continue
        clo = e['closure']
        if clo.get('f_records_proof'):
            if clo['f_records_proof'] in seen:
                continue
            seen.add(clo['f_records_proof'])
            plan.append((e['id'], None, ['python3', str(repo / L.F_RECORDS / 'reproduce_dafny_proofs.py'), '--proofs', clo['f_records_proof'],
                                         '--dafny', str(dafny), '--z3', str(z3), '--lock', str(lock), '--out', str(out / 'f-records')]))
        else:
            work = out / e['id'] / 'root'
            sub = 'build' if e['runs'][0].get('role') == 'build' else 'verify'
            extra = ['--target', 'js', '--output', str(out / e['id'] / 'build.js')] if sub == 'build' else []
            log = out / e['id'] / 'rerun.log'
            plan.append((e['id'], (clo['root'], work), ['bash', str(lock), 'f-binding-rerun', str(work / Path(clo['entry']).parent), str(log), '90', sub]
                         + extra + gate + ['--log-format', 'csv;LogFileName=%s' % (out / e['id'] / 'rerun.csv')] + [Path(x).name for x in L.run_entries(clo)]))
    for eid, cp, argv in plan:
        print('PLAN %s: %s' % (eid, L.relativize(' '.join(argv), repo)))
    if not execute:
        print('NOT EXECUTED: add --execute to run these %d commands (the orchestrator decides)' % len(plan))
        return 0
    rc_all = 0
    for eid, cp, argv in plan:
        if cp:
            shutil.copytree(repo / cp[0], cp[1])
        rc = subprocess.run(argv).returncode
        print('RERUN %s exit %d' % (eid, rc))
        rc_all = rc_all or rc
    return 1 if rc_all else 0


def main():
    ap = argparse.ArgumentParser()
    here = Path(__file__).resolve().parent
    ap.add_argument('--ledger', default=str(here / 'ASSURANCE_LEDGER.json'))
    ap.add_argument('--repo', default=str(L.DEFAULT_REPO))
    ap.add_argument('--overlay', default=None, help='a folder whose files shadow repository files (controls)')
    ap.add_argument('--rerun', action='store_true')
    ap.add_argument('--execute', action='store_true')
    a = ap.parse_args()
    if a.rerun:
        print('RERUN MODE — proofs are re-run only with --execute; the identity checks below still run')
    else:
        print(L.BANNER_IDENTITY)
    try:
        led = json.loads(Path(a.ledger).read_text())
    except Exception as x:
        print('REFUSED: unreadable ledger: %s' % x)
        return 2
    repo = Path(a.repo).resolve()
    tree = L.Tree(repo, a.overlay)
    fr = L.load_frecords(repo)
    tmp = here / 'tmp'
    tmp.mkdir(exist_ok=True)
    v = V(led, tree, fr, tmp)
    v.run()
    c = getattr(v, 'counts', {})
    print('edges per class: ' + ', '.join('%s=%d' % (k, c.get(k, 0)) for k in L.CLASSES) + '; total=%d' % len(led.get('edges', [])))
    print('nodes=%d assumptions=%d mandatory=%d' % (len(led.get('nodes', [])), len(led.get('assumptions', [])), len(led.get('mandatory_edges', []))))
    rc = 0
    if v.problems:
        codes = sorted(set(p[0] for p in v.problems))
        print('REFUSED: %d problems; codes %s; proofs NOT re-run' % (len(v.problems), ','.join(codes)))
        rc = 1
    else:
        print('CONSISTENT: identity and record consistency verified; proofs NOT re-run; theorem correctness NOT checked')
    if a.rerun:
        r2 = rerun(led, repo, a.execute)
        rc = rc or r2
    return rc


if __name__ == '__main__':
    sys.exit(main())
