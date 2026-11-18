"""Run ONE recorded command of the Round 4 M1 replay and append its record to commands.json.

This is a dispatcher and a recorder. It is not a proof checker.

CLI: python3 -I -B runcmd.py --label L --cwd DIR [--env K=V]... [--kind K] [--note TEXT]
                             [--forbid-file F] [--theory T] [--step S] -- argv...

Rules that this file enforces:
- resource guard before the start: free disk >= 3 GiB, system memory free >= 25 percent,
  no other HOL or Poly/ML process. A refusal waits and tries again; it is never bypassed.
- the child runs under `caffeinate -i -s`.
- budget: no new command starts after the deadline in budget.json (21,600 s after the first command).
- every command gets a record with the real exit code. The home prefix is written as <HOME>.
"""
from pathlib import Path
import datetime, json, os, re, resource, signal, subprocess, sys, threading, time

HOME = str(Path.home())
OUT = Path(__file__).resolve().parent.parent
COMMANDS = OUT / 'commands.json'
BUDGET = OUT / 'budget.json'
LOGS = OUT / 'logs'
BUDGET_SECONDS = 21600
HOL_PATTERN = r'poly|bin/hol |bin/Holmake|cakeml-heap|arm8-heap|cake_compile_heap|basis-heap'


def utc():
    return datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def scrub(value):
    if isinstance(value, str):
        return value.replace(HOME, '<HOME>')
    if isinstance(value, list):
        return [scrub(v) for v in value]
    if isinstance(value, dict):
        return {k: scrub(v) for k, v in value.items()}
    return value


def load():
    if COMMANDS.exists():
        return json.loads(COMMANDS.read_text())
    return {'end_to_end': False, 'note': 'Records of commands. Replayed is not proved end to end.', 'commands': []}


def save(data):
    tmp = Path(str(COMMANDS) + '.tmp')
    tmp.write_text(json.dumps(scrub(data), indent=1) + '\n')
    os.replace(tmp, COMMANDS)


def guard_state():
    text = subprocess.run(['memory_pressure'], capture_output=True, text=True).stdout
    free = int(text.rsplit(':', 1)[1].strip().rstrip('%'))
    stat = os.statvfs('/System/Volumes/Data')
    disk = stat.f_bavail * stat.f_frsize / 2 ** 30
    ps = subprocess.run(['ps', '-axo', 'pid=,command='], capture_output=True, text=True).stdout.splitlines()
    other = []
    for line in ps:
        pid, _, cmd = line.strip().partition(' ')
        if not pid.isdigit() or int(pid) == os.getpid():
            continue
        head = cmd.split(' ')[0]
        if re.search(r'/(poly|hol|Holmake)$', head) or re.search(r'--holstate=|cake_compile_heap|arm8-heap|cakeml-heap|basis-heap', cmd) and 'python' not in head and 'zsh' not in head and 'grep' not in head:
            other.append(pid + ' ' + cmd[:120])
    return {'memory_free_percent': free, 'disk_free_gib': round(disk, 2), 'other_hol_processes': other}


def guard_ok(state):
    return state['memory_free_percent'] >= 25 and state['disk_free_gib'] >= 3 and not state['other_hol_processes']


def budget_state(start_if_missing):
    if BUDGET.exists():
        return json.loads(BUDGET.read_text())
    if not start_if_missing:
        return None
    b = {'budget_seconds': BUDGET_SECONDS, 't0_utc': utc(), 't0_epoch': time.time(), 'sleep_gap_seconds_credited': 0.0}
    BUDGET.write_text(json.dumps(b, indent=1) + '\n')
    return b


def seconds_used(b):
    return time.time() - b['t0_epoch'] - b.get('sleep_gap_seconds_credited', 0.0)


def run(label, argv, cwd, env_extra=None, kind='command', note=None, forbid=None, extra=None,
        guard_tries=40, guard_wait=30, counts_for_budget=True, wall_limit=None, cpu_limit=None):
    """Run argv under caffeinate. Return the record (dict). forbid: list of regex strings; a matching
    log line stops the command (used to stop a Holmake that starts to rebuild an existing theory)."""
    LOGS.mkdir(exist_ok=True)
    b = budget_state(start_if_missing=counts_for_budget)
    data = load()
    rec = {'label': label, 'kind': kind, 'argv': list(argv), 'cwd': str(cwd), 'env_changes': env_extra or {},
           'status': 'PENDING', 'actual_exit': None}
    if note:
        rec['note'] = note
    if extra:
        rec.update(extra)
    if b is not None and counts_for_budget and seconds_used(b) > b['budget_seconds']:
        rec.update({'status': 'NOT_STARTED_BUDGET_USED', 'checked_utc': utc(), 'budget_seconds_used': round(seconds_used(b), 1)})
        data['commands'].append(rec)
        save(data)
        return rec
    refusals = []
    state = guard_state()
    tries = 0
    while not guard_ok(state):
        refusals.append({'utc': utc(), **state})
        tries += 1
        if tries >= guard_tries:
            rec.update({'status': 'NOT_STARTED_GUARD_REFUSED', 'guard_refusals': refusals})
            data['commands'].append(rec)
            save(data)
            return rec
        time.sleep(guard_wait)
        state = guard_state()
    log_path = LOGS / (label + '.log')
    n = 2
    while log_path.exists():
        log_path = LOGS / (label + '.run' + str(n) + '.log')
        n += 1
    full = ['caffeinate', '-i', '-s'] + list(argv)
    env = dict(os.environ)
    env.update(env_extra or {})
    rec.update({'status': 'RUNNING', 'wrapper': ['caffeinate', '-i', '-s'], 'log': str(log_path), 'resource_guard': state,
                'guard_refusals_before_start': refusals, 'start_utc': utc()})
    data['commands'].append(rec)
    save(data)
    t_wall, t_mono = time.time(), time.monotonic()
    stopped = {'by_watch': None, 'by_wall_limit': False}
    with log_path.open('wb') as log:
        def limits():
            if cpu_limit:
                resource.setrlimit(resource.RLIMIT_CPU, (int(cpu_limit), int(cpu_limit)))
            resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        child = subprocess.Popen(full, cwd=str(cwd), env=env, stdout=log, stderr=subprocess.STDOUT, start_new_session=True,
                                 preexec_fn=limits)

        def watch():
            patterns = [re.compile(p) for p in (forbid or [])]
            pos = 0
            while child.poll() is None:
                time.sleep(2)
                if wall_limit and time.monotonic() - t_mono > wall_limit:
                    stopped['by_wall_limit'] = True
                    try:
                        os.killpg(child.pid, signal.SIGTERM)
                    except ProcessLookupError:
                        pass
                    return
                if not patterns:
                    continue
                try:
                    with log_path.open('rb') as handle:
                        handle.seek(pos)
                        chunk = handle.read()
                        pos += len(chunk)
                except OSError:
                    continue
                for line in chunk.decode(errors='replace').splitlines():
                    for p in patterns:
                        if p.search(line):
                            stopped['by_watch'] = line[:300]
                            try:
                                os.killpg(child.pid, signal.SIGTERM)
                            except ProcessLookupError:
                                pass
                            return
        watcher = threading.Thread(target=watch, daemon=True)
        watcher.start()
        child.wait()
        watcher.join(timeout=5)
    wall, awake = time.time() - t_wall, time.monotonic() - t_mono
    usage = resource.getrusage(resource.RUSAGE_CHILDREN)
    gap = max(0.0, wall - awake)
    rec.update({'status': 'FINISHED', 'actual_exit': child.returncode, 'end_utc': utc(),
                'wall_seconds': round(wall, 1), 'awake_seconds': round(awake, 1),
                'sleep_gap_seconds': round(gap, 1) if gap > 5 else 0.0,
                'children_max_rss_mib_so_far': usage.ru_maxrss // 2 ** 20,
                'log_bytes': log_path.stat().st_size})
    if stopped['by_watch']:
        rec.update({'status': 'STOPPED_BY_WATCH', 'watch_line': stopped['by_watch']})
    if stopped['by_wall_limit']:
        rec.update({'status': 'STOPPED_WALL_LIMIT'})
    if gap > 5 and b is not None:
        b = json.loads(BUDGET.read_text())
        b['sleep_gap_seconds_credited'] = round(b.get('sleep_gap_seconds_credited', 0.0) + gap, 1)
        BUDGET.write_text(json.dumps(b, indent=1) + '\n')
    if b is not None:
        rec['budget_seconds_used_after'] = round(seconds_used(json.loads(BUDGET.read_text())), 1)
    data = load()
    data['commands'][-1] = rec
    save(data)
    return rec


def update_last(fields):
    data = load()
    data['commands'][-1].update(fields)
    save(data)


if __name__ == '__main__':
    args = sys.argv[1:]
    split = args.index('--')
    opts, argv = args[:split], args[split + 1:]
    o = {'env': {}, 'forbid': []}
    i = 0
    while i < len(opts):
        key = opts[i]
        if key == '--env':
            k, _, v = opts[i + 1].partition('=')
            o['env'][k] = v
        elif key == '--forbid-file':
            o['forbid'] += [l for l in Path(opts[i + 1]).read_text().splitlines() if l.strip()]
        else:
            o[key.lstrip('-')] = opts[i + 1]
        i += 2
    extra = {k: o[k] for k in ('theory', 'step') if k in o}
    record = run(o['label'], argv, o['cwd'], env_extra=o['env'], kind=o.get('kind', 'command'), note=o.get('note'),
                 forbid=o['forbid'], extra=extra, counts_for_budget=o.get('budget', 'yes') == 'yes',
                 wall_limit=float(o['wall-limit']) if 'wall-limit' in o else None)
    print(json.dumps({k: v for k, v in scrub(record).items() if k not in ('resource_guard',)}, indent=1))
    code = record.get('actual_exit')
    raise SystemExit(code if isinstance(code, int) and code >= 0 else (3 if record['status'].startswith('NOT_STARTED') else 1))
