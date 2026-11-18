"""Build plan.json for the Round 4 M1 replay from the committed packets. Read-only on packets.

Usage: python3 -I -B make_plan.py
This is a planning tool. It runs no HOL process and proves nothing.
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


def sha(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def rel(p):
    return str(p).replace(H, '')


def mp(p):
    """Path map: the old S3 run folder is read-only; its cases replay in a copy."""
    return rel(p).replace(S3OLD, S3NEW)


# sha index of small packet files
by_sha = {}
for p in PK.rglob('*'):
    if p.is_file() and p.stat().st_size < 8 * 2 ** 20 and '/objects/' not in str(p):
        by_sha.setdefault(sha(p), []).append(rel(p))
for p in (ROOT / 'proposals/round3-20261117/m1').rglob('*'):
    if p.is_file():
        by_sha.setdefault(sha(p), []).append(rel(p))

# command records keyed by case directory
records = {}
for base in (PK,):
    for p in sorted(base.rglob('command.json')):
        try:
            d = json.loads(p.read_text())
        except Exception:
            continue
        if isinstance(d, dict) and d.get('argv') and isinstance(d['argv'][-1], str) and d['argv'][-1].startswith(H + 'results/'):
            records.setdefault(rel(Path(d['argv'][-1]).parent), []).append((rel(p), d))

HEAPHDR = 'ifdef POLY\nHOLHEAP = $(CAKEMLDIR)/misc/cakeml-heap\nendif\n'
TRUNK = [
    # name, packet record dir (relative to PK), Holmakefile text, origin of the Holmakefile text
    ('forge_refund', 'verified-backend-20261104/refund_kernel/attempt-repeat-0001', HEAPHDR, 'verified-backend-20261104/run_kernel.py line 29'),
    ('forge_refund_compile', 'compiler-relation-20261104/proof-repeat', HEAPHDR, 'compiler-relation-20261104/run.py line 13'),
    ('forge_refund_call', 'caller-20261104/proof-repeat', HEAPHDR, 'caller-20261104/run.py line 13'),
    ('forge_refund_io', 'io-schema-20261104/proof-repeat', HEAPHDR, 'io-schema-20261104/run.py line 13'),
    ('forge_refundCertifiedProg', 'certified-library-20261104/records/proof-repeat', 'INCLUDES = ../forge_refundProg_experiment\n' + HEAPHDR, 'certified-library-20261104/records/run.py lines 24-26'),
    ('forge_refundWireProg', 'stdio-contract-20261104/records/proof-wire-repeat', 'INCLUDES = ../forge_refundCertifiedProg_experiment\n' + HEAPHDR, 'stdio-contract-20261104/records/run_wire.py lines 24-26'),
    ('forge_refundStdioProg', 'stdio-contract-20261104/records/proof-stdio-repeat', 'INCLUDES = ../forge_refundWireProg_experiment\n' + HEAPHDR, 'stdio-contract-20261104/records/run_stdio.py lines 24-26'),
    ('forge_refundWholeProg', 'whole-program-20261104/records/proof-whole-repeat', 'INCLUDES = ../forge_refundStdioProg_experiment\n' + HEAPHDR, 'whole-program-20261104/records/run_whole.py'),
    ('forge_refundArm8Compile', 'arm8-compile-20261104/records/compile-repeat',
     'INCLUDES = ../forge_refundWholeProg_experiment ../../../cv_translator\nifdef POLY\nHOLHEAP = $(CAKEMLDIR)/cv_translator/cake_compile_heap\nendif\n',
     'arm8-compile-20261104/records/compile-repeat/Holmakefile'),
]
TRUNK_PARENTS = {
    'forge_refund': [], 'forge_refund_compile': ['forge_refund'], 'forge_refund_call': ['forge_refund', 'forge_refund_compile'],
    'forge_refund_io': ['forge_refund_call'], 'forge_refundCertifiedProg': ['forge_refund', 'forge_refund_call', 'forge_refund_io'],
    'forge_refundWireProg': ['forge_refund', 'forge_refund_io', 'forge_refundCertifiedProg'],
    'forge_refundStdioProg': ['forge_refundWireProg'], 'forge_refundWholeProg': ['forge_refundStdioProg', 'forge_refundWireProg'],
    'forge_refundArm8Compile': ['forge_refundWholeProg'],
}
steps, problems, restore, generated = [], [], {}, {}
PRELOAD3 = PK / 'm1-compile-correct-20261114/records/cc/preload.sml'
PRELOAD2_SHA = 'c3cbcccccd8a8e90540b36284b24ab358aa0534f90f280ca9be1632fd489de5e'
assert hashlib.sha256(''.join(PRELOAD3.read_text().splitlines(True)[:2]).encode()).hexdigest() == PRELOAD2_SHA


def add_restore(dest, source, why):
    """dest, source: paths relative to the Forge root. Never an old built output."""
    assert not re.search(r'Theory\.(sig|sml|dat|ui|uo)$|\.hol/|heap$', dest), dest
    if dest in restore and restore[dest]['source_sha256'] != sha(ROOT / source):
        problems.append('restore conflict: ' + dest + ' from ' + source + ' and ' + restore[dest]['source'])
        return
    restore.setdefault(dest, {'source': source, 'source_sha256': sha(ROOT / source), 'why': why})


order = 0
for name, recdir, hmf, hmf_origin in TRUNK:
    order += 1
    rd = PK / recdir
    cmd = json.loads((rd / 'command.json').read_text())
    src = rd / (name + 'Script.sml')
    folder = DAFNY + name + '_experiment'
    assert src.is_file(), src
    canon = PK / 'exception-compiler-20261105/records/replay-sources' / (name + '.sml')
    add_restore(folder + '/' + name + 'Script.sml', rel(src), 'trunk theory source')
    steps.append({
        'order': order, 'id': 'T%02d-%s' % (order, name), 'theory': name, 'kind': 'holmake',
        'source_packet': recdir.split('/')[0], 'source_file': rel(src), 'source_sha256': sha(src),
        'source_equals_replay_sources_copy': canon.is_file() and sha(canon) == sha(src),
        'source_equals_recorded_sha': cmd.get('source_sha256') in (None, sha(src)),
        'cwd': folder, 'holmakefile_text': hmf, 'holmakefile_origin': hmf_origin,
        'recorded_argv': [a.replace(H, '') for a in cmd['argv']],
        'argv': ['nice', '-n', '15', TCREL + '/HOL/bin/Holmake', '--no-cache', '-j1', name + 'Theory.uo'],
        'argv_changes': ['-j 2 -> -j1 (one HOL process at a time)', 'nice -n 15 added', 'a dry run with -n runs first'],
        'heap': 'cakeml/cv_translator/cake_compile_heap' if name == 'forge_refundArm8Compile' else 'cakeml/misc/cakeml-heap',
        'parents': TRUNK_PARENTS[name],
        'recorded': {'record': rel(rd / 'command.json'), 'actual_exit': cmd.get('actual_exit'),
                     'wall_seconds': round(cmd.get('wall_seconds') or 0, 1), 'objects': cmd.get('object_sha256') or {}},
        'expected_wall_seconds': round(cmd.get('wall_seconds') or 0, 1),
        'outputs': [folder + '/.hol/objs/' + name + 'Theory.' + s for s in ('sig', 'sml', 'dat')],
    })

deps = [l.strip().replace(H, '') for l in (ROOT / S3OLD / 'deps-e4.txt').read_text().splitlines() if l.strip()]
chain = [l.rsplit('/', 1) for l in deps if l.endswith('Theory.sig')]
chain = [(cd, f[:-len('Theory.sig')]) for cd, f in chain]
chain += [(S3OLD + '/e4-0001', 'forge_refundSlideProfileA'), (S3OLD + '/imp4-0001', None)]
produced = {}  # theory -> mapped case dir
ENVOUT = {}
for casedir, theory in chain:
    order += 1
    recs = records.get(casedir)
    if not recs:
        problems.append('no record for ' + casedir)
        continue
    # prefer the record whose packet also holds the run folder files
    recpath, cmd = recs[0]
    rd = ROOT / Path(recpath).parent
    pf = rd.parent
    arm8 = 'arm8/step' in cmd['cwd']
    run_folder = mp(Path(casedir).parent)
    case = Path(casedir).name
    heap = [a for a in cmd['argv'] if a.startswith('--holstate=')][0].split(TCREL + '/')[1]
    # source
    srcname = cmd.get('source')
    cands = []
    if srcname and (pf / srcname).is_file():
        cands.append(pf / srcname)
    if (rd / 'proof.sml').is_file():
        cands.append(rd / 'proof.sml')
    cands += [ROOT / p for p in by_sha.get(cmd.get('source_sha256'), [])]
    src = next((c for c in cands if sha(c) == cmd.get('source_sha256')), None)
    if src is None:
        problems.append('BLOCKED_NO_SOURCE ' + str(theory) + ' ' + casedir)
        continue
    srcname = srcname or (case + '.sml')
    add_restore(run_folder + '/' + srcname, rel(src), 'proof source of case ' + case)
    extras = [a.replace(H, '') for a in cmd['argv'][3:-1]]
    parents, support = [], []
    in_sha = {k.replace(H, ''): v for k, v in (cmd.get('input_sha256') or {}).items()}
    for e in extras:
        if e.endswith('Theory.sml'):
            continue
        if e.endswith('Theory.sig'):
            t = Path(e).name[:-len('Theory.sig')]
            parents.append(t)
            if produced.get(t) != os.path.normpath(mp(Path(e).parent)):
                problems.append('parent path mismatch: step %s needs %s at %s; produced at %s' % (case, t, mp(Path(e).parent), produced.get(t)))
            continue
        # support file (preload)
        want = in_sha.get(e)
        local = [pf / Path(e).name] if (pf / Path(e).name).is_file() else []
        found = None
        if arm8 and 'inspect-arm8-steps/preload.sml' in e:
            found = PK / 'native-error-instructions-20261105/records/inspect-arm8-steps/preload.sml'
        else:
            for c in local + [ROOT / p for p in by_sha.get(want, [])]:
                if want is None or sha(c) == want:
                    found = c
                    break
        if found is None and want == PRELOAD2_SHA:
            generated[mp(e)] = {'from': rel(PRELOAD3), 'first_lines': 2, 'sha256': PRELOAD2_SHA,
                                'why': 'no packet holds this preload file; its first-two-lines reconstruction from the stored three-line preload has exactly the recorded SHA-256'}
            support.append({'path': mp(e), 'from': 'generated: first 2 lines of ' + rel(PRELOAD3), 'sha256': PRELOAD2_SHA, 'recorded_sha256': want})
            continue
        if found is None:
            problems.append('support file not found: ' + e + ' for ' + case)
            continue
        support.append({'path': mp(e), 'from': rel(found), 'sha256': sha(found), 'recorded_sha256': want})
        add_restore(mp(e), rel(found), 'support file named by the recorded argv of case ' + case)
    runner = None
    if not arm8 and (pf / 'run_case.py').is_file():
        runner = run_folder + '/run_case.py'
    # top-level packet files (runners, deps lists, wrappers, preloads, generators): restore beside the source
    for f in sorted(pf.iterdir()):
        if f.is_file() and (f.suffix in ('.py', '.sh', '.txt') or f.name.startswith('preload')):
            add_restore(run_folder + '/' + f.name, rel(f), 'runner, wrapper, dependency list or preload of the packet folder')
    text = src.read_text(errors='replace')
    envout = sorted(set(re.findall(r'getEnv\s*"(FORGE_[A-Z0-9_]*OUT)"', text)))
    cwd = cmd['cwd'].replace(H, '')
    step = {
        'order': order, 'id': 'C%02d-%s' % (order, case), 'theory': theory, 'kind': 'hol-run-arm8' if arm8 else 'hol-run-cake',
        'source_packet': recpath.split('/')[2], 'source_file': rel(src), 'source_sha256': sha(src),
        'run_folder': run_folder, 'case': case, 'source_name': srcname,
        'runner': runner, 'mode': 'recorded-runner' if runner else 'direct',
        'cwd': cwd, 'heap': heap, 'extras': [mp(e) for e in extras], 'support_files': support,
        'env_out_variables': envout, 'cpu_seconds_limit': cmd.get('cpu_seconds_limit') or cmd.get('cpu_seconds_per_process'),
        'parents': parents,
        'recorded': {'record': recpath, 'actual_exit': cmd.get('actual_exit'), 'wall_seconds': round(cmd.get('wall_seconds') or 0, 1),
                     'markers': cmd.get('markers'), 'objects': cmd.get('objects') or {},
                     'rss_mib': (cmd.get('child_max_rss_bytes') or 0) // 2 ** 20},
        'expected_wall_seconds': round(cmd.get('wall_seconds') or 0, 1),
        'outputs': [run_folder + '/' + case + '/.hol/objs/' + theory + 'Theory.' + s for s in ('sig', 'sml', 'dat')] if theory else [],
        'path_changes': (['run folder ' + S3OLD + ' -> ' + S3NEW] if S3NEW in run_folder else []) +
                        (['argv paths under ' + S3OLD + ' -> ' + S3NEW] if any(S3OLD in e for e in extras) else []),
    }
    if arm8:
        step['mode_reason'] = ('run_arm8_case.py compares 15 tool files with SHA-256 values of 2026-11-05; the rebuilt hol binary and '
                               'heaps differ, so that identity check cannot pass. The driver runs the same argv, cwd and environment.')
    if not runner and not arm8:
        step['mode_reason'] = 'the packet holds no runner script for this case; the driver runs the recorded argv, cwd and environment.'
    if theory:
        produced[theory] = run_folder + '/' + case
    steps.append(step)

# cases whose packet folder holds no runner but whose run folder gets one from another packet
for s in steps:
    if s.get('mode') == 'direct' and s['kind'] == 'hol-run-cake' and (s['run_folder'] + '/run_case.py') in restore:
        s['runner'] = s['run_folder'] + '/run_case.py'
        s['mode'] = 'recorded-runner'
        s.pop('mode_reason', None)

# fixed extra restores
add_restore('results/refund-target-install-bridge-2026-11-05/attempt-0001/bridge-0005/command.json',
            'proposals/refund-executable-feasibility/target-install-bridge-20261105/records/bridge-0005/command.json',
            'OLD record of 2026-11-05, restored only because every run_case.py reads argv[0] (and the install-handler runner the cwd) from it. It is not a record of this replay.')
add_restore('results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund',
            'proposals/refund-executable-feasibility/native-execution-20261104/records/native-build-0001/refund',
            'tracked executable; run_case.py asserts SHA-256 b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8')
# S3 copy: sources of the fs work and lists from the S4-S6 packet
for f in sorted((PK / 'm1-slide-s4-s6-20261117/records').iterdir()):
    if f.is_file() and f.suffix in ('.sml', '.sh', '.txt'):
        add_restore(S3NEW + '/' + f.name, rel(f), 'S4-S6 packet file')
fsdir = PK / 'm1-slide-s4-s6-20261117/records/fs'
if fsdir.is_dir():
    for f in sorted(fsdir.rglob('*')):
        if f.is_file() and f.suffix in ('.sml', '.sh', '.txt', '.py'):
            add_restore('results/round4-m1-replay-20261118/fs/packet/' + str(f.relative_to(fsdir)), rel(f), 'fs packet file (reference copy)')

mapped_text = {}
for dest, r in restore.items():
    if dest.startswith(S3NEW) and dest.endswith('.txt'):
        mapped_text[dest] = 'every line: ' + S3OLD + ' -> ' + S3NEW

total = sum(s['expected_wall_seconds'] for s in steps)
plan = {
    'title': 'Round 4 M1 chain replay plan (2026-11-18)', 'end_to_end': False,
    'claim': 'No M1 theorem is claimed. A replayed theory is a fresh HOL run of a committed script; it is not an end-to-end proof.',
    'budget_seconds': 21600, 'budget_starts': 'first command in commands.json (the upstream dry run)',
    'tool_tree': TCREL,
    'theories_planned': len([s for s in steps if s['theory']]), 'other_steps': [s['id'] for s in steps if not s['theory']] + ['fs joint-premise run (see fs section)'],
    'expected_wall_seconds_from_old_records': round(total, 1),
    'upstream_builds_allowed_by_coordinator': {
        'reason': 'The tool tree lacks objects that the chain imports. rebuild.py never listed them. The coordinator allowed these builds: recorded or obvious Holmake target, -n dry run first, -j1, new files only, stop if an existing built file would be rebuilt.',
        'listing_before': 'results/round4-m1-replay-20261118/tooltree-listing-before.json',
        'commands': [
            {'label': 'up-dafny-proofs', 'cwd': TCREL + '/cakeml/compiler/dafny/proofs', 'target': 'dafny_to_cakemlProofTheory.uo', 'recorded_in': 'verified-backend-20261104/upstream-compiler-proof-command.json'},
            {'label': 'up-sexp-to-dafny', 'cwd': TCREL + '/cakeml/compiler/dafny', 'target': 'sexp_to_dafnyTheory.uo', 'recorded_in': 'none; ancestor of forge_refund_io'},
            {'label': 'up-arm8-config-proof', 'cwd': TCREL + '/cakeml/compiler/backend/arm8/proofs', 'target': 'arm8_configProofTheory.uo', 'recorded_in': 'none; loaded by preload files'},
            {'label': 'up-arm8-steplib', 'cwd': TCREL + '/HOL/examples/l3-machine-code/arm8/step', 'target': 'arm8_stepLib.uo', 'recorded_in': 'none; loaded by the ARMv8 preload'},
        ]},
    'path_and_environment_changes': [
        'Holmake -j 2 -> -j1; nice -n 15; every long command under caffeinate -i -s',
        'S3/e4/imp4/fs cases run in ' + S3NEW + ' (the old folder ' + S3OLD + ' is read-only and holds old outputs); dependency lists there are path-mapped',
        'ARMv8-step cases and bridge-0005 run in direct mode (same argv, cwd, environment; see mode_reason)',
        'restored as new folders under original names: results/refund-native-audit-2026-11-04, results/refund-target-install-bridge-2026-11-05 (accepted by the coordinator)',
        'new Forge folder forge_refundArm8Proof_experiment holds only its recorded Holmakefile; it is the recorded cwd of two cases',
    ],
    'restore_rule': 'Only sources, runner scripts, wrappers, dependency lists, preload files, one old command record and the tracked executable are copied. No *Theory.sig, *Theory.sml, .dat, .uo, .ui, heap or .hol/objs file is copied.',
    'restore': restore, 'restore_generated': generated, 'restore_text_maps': mapped_text,
    'extra_new_files': {DAFNY + 'forge_refundArm8Proof_experiment/Holmakefile': 'INCLUDES = ../forge_refundArm8Compile_experiment ../../backend/arm8/proofs\n'},
    'steps': steps, 'problems': problems,
    'fs': {'work_folder': 'results/round4-m1-replay-20261118/fs', 'rule': 'proof-script repair in a copy; at most five attempts; every attempt recorded',
           'sources': ['proposals/refund-executable-feasibility/m1-slide-s4-s6-20261117/records (fs-0001.sml, fs-0002.sml)', 'proposals/round3-20261117/m1/fs3-0001.sml']},
}
tmp = OUT / 'plan.json.tmp'
tmp.write_text(json.dumps(plan, indent=1) + '\n')
os.replace(tmp, OUT / 'plan.json')
print('theories', plan['theories_planned'], 'steps', len(steps), 'expected wall', plan['expected_wall_seconds_from_old_records'], 'restore files', len(restore))
print('problems', len(problems))
for p in problems:
    print('  ', p)
