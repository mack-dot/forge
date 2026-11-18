"""Run steps of plan.json for the Round 4 M1 replay. A dispatcher and recorder, not a proof checker.

Usage:
  python3 -I -B driver.py run <first-order> <last-order>     run steps in order; stop at the first failure
  python3 -I -B driver.py one <step-id>                      run one step (moves a failed case folder of this run aside)
  python3 -I -B driver.py classify <step-id> <class> <note>  record the classification of a failure
  python3 -I -B driver.py table                              print the state table

Status words: REPLAYED (exit 0, outputs present and not tiny), FAILED_UNCLASSIFIED, MEMORY_FAILURE (retry, not a
proof attempt), NOT_RUN_PARENT (a parent theory is not replayed), STOPPED_WOULD_REBUILD, GUARD_REFUSED,
NOT_STARTED_BUDGET_USED. Statement comparison: equal, different, no stored statement.
"""
from pathlib import Path
import hashlib, json, os, re, shutil, subprocess, sys, time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import runcmd

ROOT = Path('<HOME>/forge')
OUT = Path(__file__).resolve().parent.parent
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
STATUS = OUT / 'status.json'
IMAGE = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004/native-build-0001/refund'
IMAGE_SHA = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
plan = json.loads((OUT / 'plan.json').read_text())
STEPS = plan['steps']
BY_ID = {s['id']: s for s in STEPS}
PRODUCER = {s['theory']: s['id'] for s in STEPS if s['theory']}
BASE_ENV = {'HOLDIR': str(TC / 'HOL'), 'CAKEMLDIR': str(TC / 'cakeml'),
            'PATH': str(TC / 'poly-install/bin') + os.pathsep + os.environ['PATH']}


def sha(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


def load_status():
    return json.loads(STATUS.read_text()) if STATUS.exists() else {'end_to_end': False, 'steps': {}}


def save_status(st):
    tmp = Path(str(STATUS) + '.tmp')
    tmp.write_text(json.dumps(st, indent=1) + '\n')
    os.replace(tmp, STATUS)


def set_status(step_id, fields, attempt=False):
    st = load_status()
    cur = st['steps'].setdefault(step_id, {'runs': 0, 'proof_attempts_failed': 0, 'history': []})
    if attempt:
        cur['runs'] += 1
    cur.update(fields)
    cur['history'].append({k: fields.get(k) for k in ('status', 'actual_exit', 'wall_seconds', 'label', 'utc') if k in fields})
    save_status(st)
    return cur


def tail(path, n=25):
    try:
        lines = Path(path).read_text(errors='replace').splitlines()
    except OSError:
        return []
    return [l[:300] for l in lines[-n:]]


def norm_lines(text):
    out = []
    for line in text.splitlines():
        line = re.sub(r'\x1b\[[0-9;]*m', '', line)
        if re.search(r'\b\d+(\.\d+)?\s?s\b|took|runtime|gctime|systime|wall|/Users/', line):
            continue
        out.append(line.rstrip())
    return out


def thm_count(sig_path):
    text = Path(sig_path).read_text(errors='replace')
    return len(re.findall(r'^\s*val\s+[A-Za-z0-9_\']+\s*:\s*thm\b', text, re.M))


def compare_outputs(step, objs_dir):
    """Compare fresh theory files with the SHA-256 values of the old record."""
    theory = step['theory']
    rec = step['recorded'].get('objects') or {}
    res = {}
    for suffix in ('sig', 'sml', 'dat'):
        name = theory + 'Theory.' + suffix
        fresh = objs_dir / name
        old = rec.get(name) or rec.get('.hol/objs/' + name)
        res[suffix] = {'fresh_sha256': sha(fresh) if fresh.is_file() else None, 'recorded_sha256': old,
                       'bytes': fresh.stat().st_size if fresh.is_file() else None}
        res[suffix]['equal'] = None if old is None or not fresh.is_file() else (res[suffix]['fresh_sha256'] == old)
    if res['sig']['recorded_sha256'] is None:
        comparison = 'no stored statement'
    elif res['sig']['equal']:
        comparison = 'equal'
    else:
        comparison = 'different'
    return comparison, res


def parents_missing(step):
    st = load_status()['steps']
    return [p for p in step['parents'] if st.get(PRODUCER.get(p), {}).get('status') != 'REPLAYED']


def memory_failure(rec, texts):
    if rec.get('awake_seconds', 999) > 25:
        return False
    blob = '\n'.join(texts)
    return 'Run out of store' in blob or 'Interrupt' in blob


def finish_theory(step, rec, objs_dir, stdout_text, extra):
    theory = step['theory']
    fields = {'label': rec['label'], 'actual_exit': rec.get('actual_exit'), 'wall_seconds': rec.get('wall_seconds'),
              'sleep_gap_seconds': rec.get('sleep_gap_seconds'), 'utc': rec.get('end_utc'), 'log': rec.get('log')}
    fields.update(extra)
    if rec['status'].startswith('NOT_STARTED'):
        fields['status'] = 'NOT_STARTED_BUDGET_USED' if 'BUDGET' in rec['status'] else 'GUARD_REFUSED'
        return set_status(step['id'], fields)
    if rec.get('actual_exit') != 0 or rec['status'] != 'FINISHED':
        fields['status'] = 'MEMORY_FAILURE' if memory_failure(rec, [stdout_text] + tail(rec['log'], 60)) else 'FAILED_UNCLASSIFIED'
        if rec['status'] != 'FINISHED':
            fields['runner_status'] = rec['status']
        fields['log_tail'] = tail(rec['log'], 12)
        return set_status(step['id'], fields, attempt=True)
    if theory:
        sig = objs_dir / (theory + 'Theory.sig')
        dat = objs_dir / (theory + 'Theory.dat')
        if not sig.is_file() or not dat.is_file() or dat.stat().st_size < 200:
            fields.update({'status': 'FAILED_UNCLASSIFIED', 'problem': 'exit 0 but theory files are missing or tiny'})
            return set_status(step['id'], fields, attempt=True)
        comparison, detail = compare_outputs(step, objs_dir)
        count = thm_count(sig)
        fields.update({'statement_comparison': comparison, 'files': detail, 'sig_thm_count': count})
        if count == 0:
            fields.update({'status': 'FAILED_UNCLASSIFIED', 'problem': 'exit 0 but the signature lists no theorem'})
            return set_status(step['id'], fields, attempt=True)
    want = step['recorded'].get('markers') or (['RUNTIME_PROOF_COMPLETE'] if step.get('case') == 'bridge-0005' else [])
    lines = set(stdout_text.splitlines())
    missing = [m for m in want if m not in lines]
    fields['markers_expected'] = want
    fields['markers_missing'] = missing
    if missing:
        fields.update({'status': 'FAILED_UNCLASSIFIED', 'problem': 'exit 0 but a recorded completion marker is missing'})
        return set_status(step['id'], fields, attempt=True)
    # old stdout of the packet, if stored: line comparison without timing lines
    old_stdout = ROOT / Path(step['recorded']['record']).parent / 'stdout.log'
    if step['kind'] != 'holmake' and old_stdout.is_file():
        a, b = norm_lines(old_stdout.read_text(errors='replace')), norm_lines(stdout_text)
        only_old, only_new = sorted(set(a) - set(b)), sorted(set(b) - set(a))
        fields['stdout_vs_packet'] = {'old_lines': len(a), 'new_lines': len(b), 'only_in_old': len(only_old), 'only_in_new': len(only_new),
                                      'sample_only_in_old': [l[:200] for l in only_old[:4]], 'sample_only_in_new': [l[:200] for l in only_new[:4]]}
        if not theory:
            fields['statement_comparison'] = 'equal' if not only_old and not only_new else 'different'
    fields['status'] = 'REPLAYED'
    return set_status(step['id'], fields, attempt=True)


def run_holmake(step):
    cwd = ROOT / step['cwd']
    theory = step['theory']
    base = [str(ROOT / a) if a.startswith('.toolchain') else a for a in step['argv']]
    target = base[-1]
    dry = runcmd.run(step['id'] + '-dryrun', base[:-1] + ['-n', target], cwd, env_extra=BASE_ENV, kind='chain-dry-run',
                     note='Dry run (-n) before the recorded Holmake command of ' + theory, extra={'step': step['id'], 'theory': theory})
    if dry.get('actual_exit') != 0:
        return finish_theory(step, dry, cwd / '.hol/objs', '', {'phase': 'dry run'})
    check_json = OUT / 'upstream' / (step['id'] + '-dryrun-check.json')
    forbid = OUT / 'upstream' / (step['id'] + '-forbid.txt')
    chk = subprocess.run(['python3', '-I', '-B', str(OUT / 'scripts/dryrun_check.py'), dry['log'], str(check_json), str(forbid)],
                         capture_output=True, text=True)
    info = json.loads(check_json.read_text())
    runcmd.update_last({'dry_run_check': info, 'dry_run_check_exit': chk.returncode})
    if chk.returncode != 0:
        return set_status(step['id'], {'status': 'STOPPED_WOULD_REBUILD', 'label': dry['label'],
                                       'planned_outputs_that_already_exist': info['planned_outputs_that_already_exist']})
    others = [t for t in info['planned_theories'] if t != theory]
    rec = runcmd.run(step['id'], base, cwd, env_extra=BASE_ENV, kind='chain-holmake',
                     note='Recorded command of ' + step['recorded']['record'] + '; changes: ' + '; '.join(step['argv_changes']),
                     forbid=[l for l in forbid.read_text().splitlines() if l.strip()],
                     extra={'step': step['id'], 'theory': theory, 'planned_theories': info['planned_theories'],
                            'missing_upstream_objects_built_by_this_command': others + info['planned_other_objects']})
    log_text = Path(rec['log']).read_text(errors='replace') if rec.get('log') and Path(rec['log']).exists() else ''
    theory_log = cwd / '.hol/logs' / (theory + 'Theory')
    extra = {'missing_upstream_objects_built_by_this_command': others + info['planned_other_objects']}
    if theory_log.is_file():
        copy = OUT / 'logs' / (step['id'] + '.theory.log')
        shutil.copyfile(theory_log, copy)
        extra['theory_log'] = str(copy).replace(str(Path.home()), '<HOME>')
        log_text += '\n' + theory_log.read_text(errors='replace')
    return finish_theory(step, rec, cwd / '.hol/objs', log_text, extra)


def run_case(step):
    run_folder = ROOT / step['run_folder']
    case_dir = run_folder / step['case']
    assert sha(IMAGE) == IMAGE_SHA, 'executable changed'
    restored_only = case_dir.is_dir() and set(os.listdir(case_dir)) <= {'command.json'} and step['mode'] == 'direct'
    if case_dir.exists() and not restored_only:
        st = load_status()['steps'].get(step['id'], {})
        n = st.get('runs', 0)
        moved = run_folder / (step['case'] + '.replay-run-%d-not-passed' % n)
        assert st.get('status') != 'REPLAYED', 'case already replayed'
        assert st, 'case folder exists but this run has no record of it: ' + str(case_dir)
        os.rename(case_dir, moved)
    extras = [str(ROOT / e) for e in step['extras']]
    heap = TC / step['heap']
    cpu = step.get('cpu_seconds_limit') or 600
    note = 'Recorded case of ' + step['recorded']['record']
    if step['mode'] == 'recorded-runner':
        argv = ['python3', '-I', '-B', str(ROOT / step['runner']), step['case'], step['source_name']] + extras
        env = dict(BASE_ENV)
        env.pop('PATH')
        env.update({'FORGE_HEAP': step['heap'], 'FORGE_CPU_SECONDS': str(cpu)})
        rec = runcmd.run(step['id'], argv, run_folder, env_extra=env, kind='chain-case-recorded-runner', note=note,
                         extra={'step': step['id'], 'theory': step['theory'], 'path_changes': step.get('path_changes', []),
                                'child_cwd': step['cwd'], 'heap': step['heap']})
    else:
        # bridge-0005 holds the restored OLD command.json that every run_case.py reads; all other case folders must be new
        case_dir.mkdir(exist_ok=restored_only)
        shutil.copyfile(run_folder / step['source_name'], case_dir / 'proof.sml')
        argv = [str(TC / 'HOL/bin/hol'), 'run', '--holstate=' + str(heap)] + extras + [str(case_dir / 'proof.sml')]
        env = dict(BASE_ENV)
        for var in step.get('env_out_variables') or []:
            env[var] = str(case_dir)
        if step['kind'] == 'hol-run-cake':
            env['FORGE_IMAGE'] = str(IMAGE)
        rec = runcmd.run(step['id'], argv, ROOT / step['cwd'], env_extra=env, kind='chain-case-direct', cpu_limit=cpu,
                         note=note + '; direct mode: ' + step.get('mode_reason', ''),
                         extra={'step': step['id'], 'theory': step['theory'], 'path_changes': step.get('path_changes', []),
                                'cpu_seconds_limit': cpu})
    stdout_text = ''
    extra = {}
    if step['mode'] == 'recorded-runner':
        for name in ('stdout.log', 'stderr.log'):
            f = case_dir / name
            if f.is_file():
                copy = OUT / 'logs' / (step['id'] + '.' + name)
                k = 2
                while copy.exists():
                    copy = OUT / 'logs' / (step['id'] + '.run%d.' % k + name)
                    k += 1
                shutil.copyfile(f, copy)
        if (case_dir / 'stdout.log').is_file():
            stdout_text = (case_dir / 'stdout.log').read_text(errors='replace')
        if (case_dir / 'stderr.log').is_file():
            extra['stderr_tail'] = tail(case_dir / 'stderr.log', 8)
        cj = case_dir / 'command.json'
        if cj.is_file():
            c = json.loads(cj.read_text())
            extra.update({'child_max_rss_mib': (c.get('child_max_rss_bytes') or 0) // 2 ** 20, 'child_wall_seconds': c.get('wall_seconds'),
                          'markers': c.get('markers'), 'child_cpu_seconds': c.get('child_user_cpu_seconds')})
        runner_out = Path(rec['log']).read_text(errors='replace') if rec.get('log') and Path(rec['log']).exists() else ''
        if rec.get('actual_exit') == 3 and 'resource_guard_refused' in runner_out:
            return set_status(step['id'], {'status': 'GUARD_REFUSED', 'label': rec['label'], 'log_tail': tail(rec['log'], 6)})
        if rec.get('actual_exit') not in (0, None) and not stdout_text:
            stdout_text = runner_out
    else:
        if rec.get('log') and Path(rec['log']).exists():
            stdout_text = Path(rec['log']).read_text(errors='replace')
            shutil.copyfile(rec['log'], case_dir / 'stdout-and-stderr.log')
        objs = {str(p.relative_to(case_dir)): sha(p) for p in sorted((case_dir / '.hol').rglob('*')) if p.is_file()} if (case_dir / '.hol').is_dir() else {}
        markers = [m for m in ('NATIVE_STEP_COMPLETE', 'RUNTIME_PROOF_COMPLETE', 'EXACT_COMPLETE') if m in stdout_text.splitlines()]
        fresh = json.dumps({
            'case': step['case'], 'argv': argv, 'cwd': str(ROOT / step['cwd']), 'source': step['source_name'],
            'source_sha256': sha(run_folder / step['source_name']), 'actual_exit': rec.get('actual_exit'),
            'wall_seconds': rec.get('wall_seconds'), 'markers': markers, 'objects': objs, 'end_to_end': False,
            'written_by': 'results/round4-m1-replay-20261118/scripts/driver.py (direct mode)'}, indent=1) + '\n'
        # real paths stay in this case-level record: the recorded runner scripts read argv[0] and cwd from it
        if (case_dir / 'command.json').exists():
            if rec.get('actual_exit') == 0:
                os.rename(case_dir / 'command.json', case_dir / 'command.packet-record-20261105.json')
                (case_dir / 'command.json').write_text(fresh)
            else:
                (case_dir / 'command.replay-not-passed.json').write_text(fresh)
        else:
            (case_dir / 'command.json').write_text(fresh)
        extra['markers'] = markers
    res = finish_theory(step, rec, case_dir / '.hol/objs', stdout_text, extra)
    return res


def run_step(step):
    missing = parents_missing(step)
    if missing:
        return set_status(step['id'], {'status': 'NOT_RUN_PARENT', 'parents_not_replayed': missing})
    if step['kind'] == 'holmake':
        return run_holmake(step)
    return run_case(step)


def table():
    st = load_status()['steps']
    for s in STEPS:
        r = st.get(s['id'], {})
        print('%2d %-28s %-30s %-22s exit=%-4s wall=%-7s cmp=%-20s thms=%s' % (
            s['order'], s['id'], s['theory'] or '(import check)', r.get('status', 'NOT_REACHED'), r.get('actual_exit'),
            r.get('wall_seconds'), r.get('statement_comparison'), r.get('sig_thm_count')))


if __name__ == '__main__':
    mode = sys.argv[1]
    if mode == 'table':
        table()
    elif mode == 'classify':
        st = load_status()
        st['steps'][sys.argv[2]].update({'classification': sys.argv[3], 'classification_note': sys.argv[4]})
        if sys.argv[3] == 'proof_failure':
            st['steps'][sys.argv[2]]['proof_attempts_failed'] += 1
        save_status(st)
    elif mode == 'fs':
        # fs joint-premise run: python3 driver.py fs <case> <source name in the S3 copy folder> [cpu seconds]
        base = BY_ID['C72-imp4-0001']
        step = {'order': 73, 'id': 'FS-' + sys.argv[2], 'theory': 'forge_refundInputSat', 'kind': 'hol-run-cake',
                'run_folder': base['run_folder'], 'case': sys.argv[2], 'source_name': sys.argv[3], 'runner': base['runner'],
                'mode': 'recorded-runner', 'cwd': base['cwd'], 'heap': base['heap'], 'extras': base['extras'],
                'env_out_variables': ['FORGE_P3_OUT'], 'cpu_seconds_limit': int(sys.argv[4]) if len(sys.argv) > 4 else 600,
                'parents': base['parents'], 'path_changes': base.get('path_changes', []),
                'recorded': {'record': 'proposals/refund-executable-feasibility/m1-slide-s4-s6-20261117/records/fs/fs-0001.run.json',
                             'markers': ['EXACT_COMPLETE'], 'objects': {}}}
        BY_ID[step['id']] = step
        r = run_step(step)
        print(json.dumps({k: v for k, v in r.items() if k not in ('history', 'files')}, indent=1))
    elif mode == 'check':
        # import check written in this replay: python3 driver.py check <case> <source name> <fs case that holds forge_refundInputSat>
        base = BY_ID['C72-imp4-0001']
        fs_status = load_status()['steps'].get('FS-' + sys.argv[4], {})
        assert fs_status.get('status') == 'REPLAYED', 'the fs case is not replayed'
        thy = base['run_folder'] + '/' + sys.argv[4] + '/forge_refundInputSatTheory'
        step = {'order': 74, 'id': 'CHK-' + sys.argv[2], 'theory': None, 'kind': 'hol-run-cake',
                'run_folder': base['run_folder'], 'case': sys.argv[2], 'source_name': sys.argv[3], 'runner': base['runner'],
                'mode': 'recorded-runner', 'cwd': base['cwd'], 'heap': base['heap'], 'extras': base['extras'] + [thy + '.sig', thy + '.sml'],
                'env_out_variables': ['FORGE_P3_OUT'], 'cpu_seconds_limit': 600,
                'parents': base['parents'], 'path_changes': base.get('path_changes', []),
                'recorded': {'record': 'results/round4-m1-replay-20261118/fs/no-old-record/none.json', 'markers': ['EXACT_COMPLETE'], 'objects': {}}}
        BY_ID[step['id']] = step
        r = run_step(step)
        print(json.dumps({k: v for k, v in r.items() if k not in ('history', 'files')}, indent=1))
    elif mode == 'one':
        r = run_step(BY_ID[sys.argv[2]])
        print(json.dumps({k: v for k, v in r.items() if k not in ('history', 'files')}, indent=1))
    elif mode == 'run':
        first, last = int(sys.argv[2]), int(sys.argv[3])
        for s in STEPS:
            if not first <= s['order'] <= last:
                continue
            cur = load_status()['steps'].get(s['id'], {})
            if cur.get('status') == 'REPLAYED':
                continue
            if (OUT / 'STOP').exists():
                print('STOP file found before', s['id'], flush=True)
                raise SystemExit(5)
            tries = 0
            while True:
                r = run_step(s)
                tries += 1
                if r['status'] in ('MEMORY_FAILURE', 'GUARD_REFUSED') and tries < 4:
                    time.sleep(60)
                    continue
                break
            print(s['order'], s['id'], r['status'], r.get('actual_exit'), r.get('wall_seconds'), r.get('statement_comparison'), flush=True)
            if r['status'] not in ('REPLAYED', 'NOT_RUN_PARENT'):
                print('STOP at', s['id'], json.dumps({k: v for k, v in r.items() if k in ('problem', 'log_tail', 'stderr_tail', 'markers_missing', 'log')}, indent=1))
                raise SystemExit(1)
        print('RANGE DONE')
