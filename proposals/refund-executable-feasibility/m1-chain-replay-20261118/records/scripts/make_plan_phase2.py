"""Build plan-phase2.json: (B) Forge theories of the U345-U409 packets that phase 1 did not replay, with the
pre-U345 parent theories they need; (C) the list of recorded controls, repeat cases and import checks.
Read-only on packets. Planning tool: no HOL run, no proof.

Usage: python3 -I -B make_plan_phase2.py
"""
from pathlib import Path
import hashlib, json, os, re

ROOT = Path('<HOME>/forge')
OUT = Path(__file__).resolve().parent.parent
PK = ROOT / 'proposals/refund-executable-feasibility'
TCREL = '.toolchain/experiments/refund-cakeml-20261104'
H = str(ROOT) + '/'
S3OLD = 'results/refund-slide-s3-local-20261117/attempt-0001'
S3NEW = 'results/round4-m1-replay-20261118/slide-s3-copy/attempt-0001'
DAFNY = TCREL + '/cakeml/compiler/dafny/'
# The old runners copied parent theory files into "*-parent" folders. Here the recorded argv is mapped to the
# case folder of the fresh run of the parent, so no built file is copied.
PARENT_MAP = {
    'results/refund-initialization-static-2026-11-05/attempt-0001/static-0003/init-parent': 'results/refund-initialization-success-2026-11-05/attempt-0001/success-0002',
    'results/refund-initial-stack-code-2026-11-05/attempt-0001/code-0003/init-parent': 'results/refund-initialization-success-2026-11-05/attempt-0001/success-0002',
    'results/refund-initial-stack-code-2026-11-05/attempt-0001/code-0003/static-parent': 'results/refund-initialization-static-2026-11-05/attempt-0001/static-0003',
}


def sha(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def rel(p):
    return str(p).replace(H, '')


def mp(p):
    p = rel(p).replace(S3OLD, S3NEW)
    for old, new in PARENT_MAP.items():
        p = p.replace(old, new)
    return p


phase1 = json.loads((OUT / 'plan.json').read_text())
index = json.loads((OUT / 'phase2-index.json').read_text())
produced = {}
for s in phase1['steps']:
    if s['theory']:
        produced[s['theory']] = (s['cwd'] if s['kind'] == 'holmake' else s['run_folder'] + '/' + s['case'])
by_sha = {}
for p in PK.rglob('*'):
    if p.is_file() and p.stat().st_size < 2 * 2 ** 20 and p.suffix in ('.sml', '.py', '.sh', '.txt'):
        by_sha.setdefault(sha(p), []).append(rel(p))

# (theory, packet record folder, kind, unsure entries)
B = [
    ('forge_refundArm8Proof', 'compiled-behavior-20261104/records/behavior-0002', 'pre-U345 parent (U276)'),
    ('forge_refundReadBoundary', 'read-runtime-20261105/records/model-0007', 'pre-U345 parent'),
    ('forge_refundStdinDomain', 'stdin-domain-20261107/records/model-0004', 'pre-U345 parent'),
    ('forge_refundSuccessfulInitialization', 'initialization-success-checkpoint-20261105/records/success-0002', 'pre-U345 parent'),
    ('forge_refundInitializationStatic', 'initialization-static-validation-20261105/records/static-0003', 'pre-U345 parent'),
    ('forge_refundGenericReadError', 'generic-read-local-20261112/records/proof-0001', 'U345'),
    ('forge_refundInitialStackCode', 'initial-stack-code-local-20261112/records/code-0004', 'U347'),
    ('forge_refundNativeReadError', 'arm8-compose-local-20261112/records/compose-0001', 'U348'),
    ('forge_refundInitializerMachine', 'initializer-machine-local-20261112/records/machine-0001', 'U349'),
    ('forge_refundFfiOracle', 'm1-closure-20261112/records/ffi-oracle/oracle-0001', 'U351'),
    ('forge_refundFfiInstance', 'm1-replay-closure-20261112/records/ffi-instance/instance-0001', 'U352'),
    ('forge_refundInitializerAligned', 'm1-replay-closure-20261112/records/initializer-aligned/aligned-0001', 'U353-U356'),
    ('forge_refundInstallStub', 'm1-replay-closure-20261112/records/install-stub/stub-0002', 'U353-U356'),
    ('forge_refundInitializerInstalled', 'm1-installed-closure-20261112/records/initializer-installed/installed-0001', 'U357'),
    ('forge_refundInstallSite', 'm1-installed-closure-20261112/records/install-site/install-site-0001', 'U358-U359'),
    ('forge_refundInstallReach', 'm1-n1-reachability-20261113/records/n1/proof-0001', 'U364-U366'),
    ('forge_refundLabRunInit', 'm1-p2-lab-invariant-20261113/records/run/init-0002', 'U371-U373'),
    ('forge_refundLabExclusion', 'm1-lab-exclusion-20261113/records/exclusion/excl-0001', 'U374-U376'),
    ('forge_refundAllocBackend', 'm1-p3-prefix-20261113/records/prefix/statement-0002', 'U377-U379'),
    ('forge_refundCmlMainSat', 'm1-reject-startup-20261115/records/step/sat-0001', 'U388'),
    ('forge_refundWriteReachCheck', 'm1-write-reach-20261116/records/reach/check-0001', 'U399'),
    ('forge_refundWriteArgs', 'm1-write-args-20261116/records/args/args-0006', 'U400'),
    ('forge_refundWriteArgsCheck', 'm1-write-args-20261116/records/args/check-0002', 'U400'),
    ('forge_refundWriteWord', 'm1-closure-audit-20261116/records/word/word-0003', 'U401'),
]
steps, problems, restore = [], [], {}


def add_restore(dest, source, why):
    assert not re.search(r'Theory\.(sig|sml|dat|ui|uo)$|\.hol/|heap$', dest), dest
    if dest in restore and restore[dest]['source_sha256'] != sha(ROOT / source):
        problems.append('restore conflict: ' + dest)
        return
    restore.setdefault(dest, {'source': source, 'source_sha256': sha(ROOT / source), 'why': why})


order = 100
b_records = set()
for theory, recdir, entry in B:
    order += 1
    rd = PK / recdir
    cmd = json.loads((rd / 'command.json').read_text())
    b_records.add(rel(rd / 'command.json'))
    if theory == 'forge_refundArm8Proof':
        src = rd / 'forge_refundArm8ProofScript.sml'
        folder = DAFNY + 'forge_refundArm8Proof_experiment'
        add_restore(folder + '/forge_refundArm8ProofScript.sml', rel(src), 'pre-U345 parent theory source')
        steps.append({
            'order': order, 'id': 'B%02d-%s' % (order - 100, theory), 'theory': theory, 'entry': entry, 'kind': 'holmake',
            'source_packet': recdir.split('/')[0], 'source_file': rel(src), 'source_sha256': sha(src),
            'source_equals_recorded_sha': cmd.get('source_sha256') == sha(src), 'cwd': folder,
            'holmakefile_text': (rd / 'Holmakefile').read_text(), 'holmakefile_origin': rel(rd / 'Holmakefile'),
            'recorded_argv': [a.replace(H, '') for a in cmd['argv']],
            'argv': ['nice', '-n', '15', TCREL + '/HOL/bin/Holmake', '--no-cache', '-j1', theory + 'Theory.uo'],
            'argv_changes': ['-j 2 -> -j1', 'nice -n 15 added', 'a dry run with -n runs first'],
            'heap': 'cakeml/misc/cakeml-heap', 'parents': ['forge_refundWholeProg', 'forge_refundArm8Compile'],
            'recorded': {'record': rel(rd / 'command.json'), 'actual_exit': cmd.get('actual_exit'), 'wall_seconds': round(cmd.get('wall_seconds') or 0, 1),
                         'objects': cmd.get('object_sha256') or {}},
            'expected_wall_seconds': round(cmd.get('wall_seconds') or 0, 1),
            'outputs': [folder + '/.hol/objs/' + theory + 'Theory.' + s for s in ('sig', 'sml', 'dat')]})
        produced[theory] = folder
        continue
    argv = [a.replace(H, '') for a in cmd['argv']]
    casedir = str(Path(argv[-1]).parent)
    run_folder, case = mp(Path(casedir).parent), Path(casedir).name
    hs = next(i for i, a in enumerate(argv) if a.startswith('--holstate='))
    heap = argv[hs].split(TCREL + '/')[1]
    hol_options = argv[1:hs - 1]          # e.g. --maxheap 1400 before "run"
    arm8 = 'arm8/step' in cmd['cwd']
    pf = rd.parent
    srcname = cmd.get('source')
    cands = ([pf / srcname] if srcname and (pf / srcname).is_file() else []) + ([rd / 'proof.sml'] if (rd / 'proof.sml').is_file() else [])
    src = next((c for c in cands if cmd.get('source_sha256') in (None, sha(c))), None)
    if src is None:
        problems.append('BLOCKED_NO_SOURCE ' + theory)
        continue
    srcname = srcname or (case + '.sml')
    add_restore(run_folder + '/' + srcname, rel(src), 'proof source of case ' + case)
    extras = argv[hs + 1:-1]
    in_sha = {k.replace(H, ''): v for k, v in (cmd.get('input_sha256') or {}).items()}
    parents, support = [], []
    for e in extras:
        if e.endswith('Theory.sml'):
            continue
        if e.endswith('Theory.sig'):
            t = Path(e).name[:-len('Theory.sig')]
            parents.append(t)
            if produced.get(t) != os.path.normpath(mp(Path(e).parent)):
                problems.append('parent path mismatch: %s needs %s at %s; produced at %s' % (case, t, mp(Path(e).parent), produced.get(t)))
            continue
        want = in_sha.get(e)
        found = None
        if arm8 and 'inspect-arm8-steps/preload.sml' in e:
            found = PK / 'native-error-instructions-20261105/records/inspect-arm8-steps/preload.sml'
        else:
            name = Path(e).name
            local = [c for c in (pf / name, rd / name) if c.is_file()]
            # a preload that lived in another run folder: look for the packet folder that recorded that case
            other = [ROOT / Path(x['record']).parent / name for x in index if x['casedir'] == str(Path(e).parent)]
            allrecs = [p.parent / name for p in PK.rglob('command.json') if p.parent.name == Path(e).parent.name and (p.parent / name).is_file()]
            for c in local + [o for o in other if o.is_file()] + allrecs + [ROOT / p for p in by_sha.get(want, [])]:
                if want is None or sha(c) == want:
                    found = c
                    break
        if found is None:
            problems.append('support file not found: ' + e + ' for ' + case)
            continue
        support.append({'path': mp(e), 'from': rel(found), 'sha256': sha(found), 'recorded_sha256': want})
        add_restore(mp(e), rel(found), 'support file named by the recorded argv of case ' + case)
    m1_runner = (pf / 'run_case.py').is_file() and 'FORGE_CPU_SECONDS' in (pf / 'run_case.py').read_text() and not arm8
    runner = run_folder + '/run_case.py' if m1_runner else None
    if runner:
        for f in sorted(pf.iterdir()):
            if f.is_file() and (f.suffix in ('.py', '.sh', '.txt') or f.name.startswith('preload')):
                add_restore(run_folder + '/' + f.name, rel(f), 'runner, wrapper, dependency list or preload of the packet folder')
    text = src.read_text(errors='replace')
    objs = cmd.get('objects') or {}
    step = {
        'order': order, 'id': 'B%02d-%s' % (order - 100, case), 'theory': theory, 'entry': entry,
        'kind': 'hol-run-arm8' if arm8 else 'hol-run-cake', 'source_packet': recdir.split('/')[0], 'source_file': rel(src), 'source_sha256': sha(src),
        'run_folder': run_folder, 'case': case, 'source_name': srcname, 'runner': runner, 'mode': 'recorded-runner' if runner else 'direct',
        'cwd': cmd['cwd'].replace(H, ''), 'heap': heap, 'hol_options': hol_options, 'extras': [mp(e) for e in extras], 'support_files': support,
        'env_out_variables': sorted(set(re.findall(r'getEnv\s*"(FORGE_[A-Z0-9_]*OUT)"', text))),
        'cpu_seconds_limit': cmd.get('cpu_seconds_limit') or cmd.get('cpu_seconds_per_process') or 600, 'parents': parents,
        'recorded': {'record': rel(rd / 'command.json'), 'actual_exit': cmd.get('actual_exit'), 'wall_seconds': round(cmd.get('wall_seconds') or 0, 1),
                     'markers': cmd.get('markers'), 'objects': objs},
        'expected_wall_seconds': round(cmd.get('wall_seconds') or 60, 1),
        'outputs': [run_folder + '/' + case + '/.hol/objs/' + theory + 'Theory.' + s for s in ('sig', 'sml', 'dat')],
        'path_changes': [k + ' -> ' + v for k, v in PARENT_MAP.items() if any(k in e for e in extras)],
    }
    if not runner:
        step['mode_reason'] = ('ARMv8-step case: the recorded tool-identity check cannot pass after the rebuild.' if arm8 else
                               'The runner of this packet compares the hol binary and the heap with SHA-256 values recorded before the rebuild, or the packet holds no runner. The driver runs the recorded argv, cwd and environment.')
    produced[theory] = run_folder + '/' + case
    steps.append(step)

# ---- C: controls, repeat cases, import checks (list only; NOT run: deferred by the coordinator) ----
b_theories = {t for t, _, _ in B}


def classify(c):
    name = c['case'].lower()
    if c['phase1_step']:
        return 'main-phase1'
    if c['record'] in b_records:
        return 'main-phase2'
    if re.search(r'explore|diagnos|diag-|inspect|dump|instrumented|sat-diagnostic|generic-local', name):
        return 'exploration'
    if 'repeat' in name:
        return 'repeat'
    if re.search(r'import|^imp\d*-|^imp-|audit|^check-', name):
        return 'import-check'
    return 'control-or-earlier-attempt'


groups = {}
for c in index:
    groups.setdefault((c['packet'], c['folder'], re.sub(r'-\d{4}$', '', c['case'])), []).append(c)
clist, counts = [], {}
main_bases = {(c['packet'], c['folder'], re.sub(r'-\d{4}$', '', c['case'])) for c in index if c['phase1_step'] or c['record'] in b_records}
for c in index:
    kind = classify(c)
    base = (c['packet'], c['folder'], re.sub(r'-\d{4}$', '', c['case']))
    if kind == 'control-or-earlier-attempt':
        later = [x for x in groups[base] if x['case'] > c['case']]
        if base in main_bases:
            kind = 'earlier-attempt-of-a-main-case'
        elif later:
            kind = 'earlier-attempt-of-a-control'
        else:
            kind = 'control'
    if kind in ('repeat', 'import-check') and [x for x in groups[base] if x['case'] > c['case']]:
        kind = 'earlier-attempt-of-a-' + kind
    counts[kind] = counts.get(kind, 0) + 1
    deps = [Path(a).name[:-len('Theory.sig')] for a in c['argv'] if isinstance(a, str) and a.endswith('Theory.sig')]
    dep_dirs = [os.path.normpath(mp(Path(a).parent)) for a in c['argv'] if isinstance(a, str) and a.endswith('Theory.sig')]
    missing = sorted({d for d, p in zip(deps, dep_dirs) if produced.get(d) != p})
    if kind in ('control', 'repeat', 'import-check'):
        clist.append({'packet': c['packet'], 'entries': c['entries'], 'folder': c['folder'], 'case': c['case'], 'class': kind,
                      'record': c['record'], 'source': c['source'], 'recorded_exit': c['actual_exit'], 'recorded_markers': c['markers'],
                      'recorded_wall_seconds': c['wall_seconds'], 'recorded_wall_timeout': c['wall_timeout'],
                      'exports_theory': c['theories'], 'stdout_marker_lines': (c['stdout_marker_lines'] or [])[:40],
                      'stdout_marker_line_count': len(c['stdout_marker_lines'] or []), 'stderr_tail': c['stderr_tail'],
                      'parent_theories_not_produced_by_this_replay': missing,
                      'state': 'NOT RUN: deferred by the coordinator'})
packets_order = []
for c in index:
    if c['packet'] not in packets_order:
        packets_order.append(c['packet'])
per_packet = {p: {k: sum(1 for x in clist if x['packet'] == p and x['class'] == k) for k in ('control', 'repeat', 'import-check')} for p in packets_order}
total_b = sum(s['expected_wall_seconds'] for s in steps)
plan = {
    'title': 'Round 4 M1 replay, phase 2 plan (2026-11-18)', 'end_to_end': False,
    'claim': 'No M1 theorem is claimed. Replayed is not proved end to end.',
    'budget_seconds': 14566, 'budget_starts': 'first phase 2 command',
    'B': {'what': 'Forge theories exported by exit-0 cases of the U345-U409 packets that phase 1 did not replay, and the pre-U345 parent theories they load',
          'theories_U345_U409': len([s for s in steps if not s['entry'].startswith('pre-U345')]),
          'pre_U345_parents': len([s for s in steps if s['entry'].startswith('pre-U345')]),
          'expected_wall_seconds_from_old_records': round(total_b, 1),
          'note': 'forge_refundReadBoundary and forge_refundStdinDomain have no recorded wall time; 60 s each is assumed.',
          'path_and_environment_changes': [
              'Holmake -j 2 -> -j1, nice, caffeinate, dry run first (forge_refundArm8Proof)',
              'argv paths of the old "init-parent" and "static-parent" copies point to the case folder of the fresh parent run: ' + json.dumps(PARENT_MAP),
              'direct mode for the 2026-11-12 packets, the pre-U345 parents and ARMv8-step cases (their runners compare tool hashes recorded before the rebuild)',
              'new run folders under their original names, also names without "-local-" (refund-stdin-domain-20261107, refund-read-event-gap-20261107, refund-initialization-success-2026-11-05, refund-initialization-static-2026-11-05, refund-initial-stack-code-2026-11-05)'],
          'restore': restore, 'steps': steps, 'problems': problems},
    'C': {'state': 'NOT RUN: deferred by the coordinator (the machine is needed for another measured job)',
          'classification_rule': 'By case name, heuristic: "repeat" in the name = repeat; import, imp-, audit, check- = import check; explore, diagnose, inspect, dump = exploration (not listed); a numbered case with a later number of the same base name = earlier attempt (not listed); every other case that is not a main case = control. The packet reports were not read for this list.',
          'counts_all_recorded_cases_by_class': counts, 'listed_cases': len(clist), 'per_packet': per_packet,
          'full_marker_lines': 'results/round4-m1-replay-20261118/phase2-index.json (field stdout_marker_lines)',
          'cases': clist},
}
tmp = OUT / 'plan-phase2.json.tmp'
tmp.write_text(json.dumps(plan, indent=1) + '\n')
os.replace(tmp, OUT / 'plan-phase2.json')
print('B steps', len(steps), 'expected wall', round(total_b, 1), 'restore', len(restore), 'problems', len(problems))
for p in problems:
    print('  ', p)
print('all cases by class', counts)
print('C listed', len(clist), {k: sum(1 for x in clist if x['class'] == k) for k in ('control', 'repeat', 'import-check')})
print('C cases with a parent not produced by this replay:', sum(1 for x in clist if x['parent_theories_not_produced_by_this_replay']))
for s in steps:
    print(s['order'], s['id'], s['kind'], s.get('mode', ''), s['heap'].split('/')[-1], s['expected_wall_seconds'], 'par', s['parents'][-3:], 'sup', [x['from'].split('refund-executable-feasibility/')[-1][:60] for x in s.get('support_files', [])], s.get('env_out_variables', ''), s.get('hol_options', ''))
