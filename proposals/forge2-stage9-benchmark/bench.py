#!/usr/bin/env python3
"""Stage 9 benchmark harness (Gate F2b). A plan tool and a runner. end_to_end=false. Nothing here is a proof.

Three arms write the same request handler for the same task text; one hidden oracle attacks each handler.
  A  unit-test baseline : one agent call; the agent writes the handler and its own tests.
  B  reviewer baseline  : arm A, then a fresh agent reviews the code, then a fresh agent repairs it once.
  C  Forge Airlock      : one agent call; the handler must take its decision from the airlock engine (kit/).
The oracle reads only the log of the LOCAL FAKE provider (provider.py). It judges the log with a small reference
model of the task rules (function `allowed`). That model is test code. It is not a verifier and not a proof.

  bench.py matrix   [--batch 36|54|72]                 print the cells and their commands; starts nothing
  bench.py controls [--tasks T1,T2] --out DIR          the oracle on the five reference handlers (no model call)
  bench.py oracle   --task T1 --arm A --work DIR       the oracle on a handler folder (no model call)
  bench.py run      --out DIR (--cell ID ... | --batch N) [--resume] [--jobs 1..3] [--model NAME]
                                                       agent calls; one checkpoint line per finished cell
Exit codes: 0 done; 1 a control did not behave as recorded; 2 usage or a refused start; 3 a cell had no result.
The engine is build/airlock/airlock-engine of this checkout (rustc command in bin/forge-airlock). --out must be
outside the checkout, so that an agent's folder holds no path to this file.
"""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
ENGINE = ROOT / 'build' / 'airlock' / 'airlock-engine'
SDK = ROOT / 'sdk' / 'py' / 'forge_airlock.py'
TASKS = json.loads((HERE / 'tasks.json').read_text())['tasks']
ARMS = {'A': 'unit-test baseline', 'B': 'reviewer baseline', 'C': 'Forge Airlock'}
BATCHES = {36: 2, 54: 3, 72: 4}          # runs -> repetitions of each (task, arm) pair
TENANT, ORDER = 'acme', 'o1'
RACE_N = 8                               # processes in one race scenario (below the 50-process heavy rule)
HANDLER_TIMEOUT = 60                     # seconds for one handler process
AGENT_TIMEOUT = 1800                     # seconds for one agent call
AGENT_TOOLS = 'Read,Write,Edit,Bash(python3:*)'
KEPT = ('provider.py', 'TASK.md', 'REVIEW.md', 'kit', 'sample_state', '__pycache__')


def sha(data):
    return hashlib.sha256(data).hexdigest()


# ---------------------------------------------------------------- task text and policy file

def engine_policy(task):
    rules = []
    for r in task['rules']:
        rule = {'reason': r['reason'], 'verdict': 'COMMIT'}
        if 'min' in r:
            rule['min_amount'] = str(r['min'])
        if 'max' in r:
            rule['max_amount'] = str(r['max'])
        if 'fact' in r:
            rule['max_reason_total_fact'] = r['fact']
        rules.append(rule)
    return (json.dumps({'airlock': 'money', 'version': 1, 'name': task['policy'], 'profile': 'parametric',
                        'rules': rules}, indent=1) + '\n').encode()


def task_text(name, arm):
    t = TASKS[name]
    lines = ['# Task: a payment request handler for ' + t['domain'], '',
             'Write `handler.py` in this folder. Python 3, standard library only.', '',
             '## Contract', '',
             '- It runs as `python3 handler.py STATE_DIR`, one process per request.',
             '- It reads one JSON object from standard input: `{"tenant": "acme", "order": "o1", "request_id": "r-1", '
             '"reason": "...", "amount": 1234}`. `amount` is an integer number of cents.',
             '- To pay, it runs the provider: `python3 provider.py STATE_DIR ORDER REQUEST_ID REASON AMOUNT` '
             '(`provider.py` is beside `handler.py`; do not change it). The provider pays whatever it is asked to pay.',
             '- It prints one JSON object: `{"status": "PAID"}`, `{"status": "REJECTED"}` or `{"status": "DUPLICATE"}`, '
             'and exits 0.',
             '- `STATE_DIR/task.json` holds the rules below in machine form and the orders. You can keep your own '
             'files in `STATE_DIR`. `sample_state/` is one such folder for your own tests; every test of the grader '
             'starts from a new copy.',
             '- Several handler processes can run at the same time on one `STATE_DIR`. The same request can be '
             'delivered more than once, at the same time or later.', '',
             '## Rules (a payment that breaks one of them is a lost-money bug)', '',
             '1. Each order has an original amount of %d cents. The sum of all payments of an order is never above it.'
             % t['original'],
             '2. An amount of 0 or less is rejected. A reason that is not listed is rejected.',
             '3. A `request_id` is paid at most once, ever, whatever the other fields of a later request say. A '
             'repeated `request_id` does not call the provider again.',
             '4. A payment is made exactly as requested (same order, reason and amount) or not at all.']
    n = 5
    for r in t['rules']:
        parts = []
        if 'min' in r:
            parts.append('the amount is at least %d' % r['min'])
        if 'max' in r:
            parts.append('the amount is at most %d' % r['max'])
        if 'fact' in r:
            parts.append('the sum of all `%s` payments of the order, with this one, is at most the order fact `%s` '
                         '(%d cents here)' % (r['reason'], r['fact'], t['facts'][r['fact']]))
        lines.append('%d. Reason `%s`: %s.' % (n, r['reason'], '; '.join(parts) if parts else 'no limit except rule 1'))
        n += 1
    lines += ['%d. A request that all rules allow is paid.' % n, '']
    if arm == 'C':
        lines += ['## The airlock (use it)', '',
                  'Do not write the rule checks yourself. `STATE_DIR/store` is a forge-airlock store that already '
                  'holds these rules as its policy and every order as a money key (tenant `acme`, key = the order). '
                  'Ask it through `kit/airlock_kit.py` (read its first lines and `kit/forge_airlock.py`):', '',
                  '```python', 'import sys; sys.path.insert(0, "kit"); import airlock_kit',
                  'with airlock_kit.open_store(state_dir) as st:',
                  '    h = st.get(tenant, order).state_hash',
                  '    r = st.refund(tenant, order, request_id, h, reason, amount)   # r.code', '```', '',
                  'Result codes: `COMMITTED`, `REJECTED_POLICY`, `STALE_STATE_HASH` (another write came first: read '
                  'the hash again and retry), `DUPLICATE_REQUEST_ID`. Other outcomes raise an exception. Call the '
                  'provider only for a request that the store committed.', '']
    lines += ['## Done', '', 'Test your handler as you see fit. Stop when you think it is correct. Write no other '
              'documentation.', '']
    return '\n'.join(lines)


# ---------------------------------------------------------------- reference model and scenarios

def allowed(task, state, reason, amount):
    """Test oracle: would the task rules allow this payment in this state of one order?"""
    if amount <= 0 or amount > state['remaining']:
        return False
    for r in task['rules']:
        if r['reason'] == reason and amount >= r.get('min', 1) and amount <= r.get('max', amount) and (
                'fact' not in r or state['totals'].get(reason, 0) + amount <= task['facts'][r['fact']]):
            return True
    return False


def scenarios(name):
    """The fixed attack list of a task. Each scenario runs on a new state folder with one order."""
    t, out = TASKS[name], []

    def add(sid, cls, mode, reqs):
        out.append({'id': sid, 'class': cls, 'mode': mode,
                    'requests': [{'tenant': TENANT, 'order': ORDER, 'request_id': rid, 'reason': reason, 'amount': amount}
                                 for rid, reason, amount in reqs]})

    def ok_amount(r):
        value = max(r.get('min', 1), 100)
        return min(value, r.get('max', value), t['facts'][r['fact']] if 'fact' in r else value)

    for r in t['rules']:
        R = r['reason']
        if 'max' in r:
            add('B-%s-max' % R, 'boundary', 'seq', [('b1', R, r['max'])])
            add('B-%s-max-plus-1' % R, 'boundary', 'seq', [('b1', R, r['max'] + 1)])
        if 'min' in r:
            add('B-%s-min' % R, 'boundary', 'seq', [('b1', R, r['min'])])
            add('B-%s-min-minus-1' % R, 'boundary', 'seq', [('b1', R, r['min'] - 1)])
        cap = t['facts'][r['fact']] if 'fact' in r else (t['original'] if 'max' not in r else None)
        if cap is not None:
            fill, rest = [], cap
            while rest > 0 and min(rest, r.get('max', rest)) >= r.get('min', 1):
                fill.append(min(rest, r.get('max', rest)))
                rest -= fill[-1]
            add('B-%s-cap-fill-then-over' % R, 'boundary', 'seq',
                [('f%d' % i, R, a) for i, a in enumerate(fill)] + [('over', R, r.get('min', 1))])
            if cap + 1 <= r.get('max', cap + 1):
                add('B-%s-cap-plus-1' % R, 'boundary', 'seq', [('b1', R, cap + 1)])
            piece = min(cap // 2, r.get('max', cap))
            if piece >= r.get('min', 1) and RACE_N * piece > cap:
                add('R-%s-cap-race' % R, 'race', 'par', [('c%d' % i, R, piece) for i in range(RACE_N)])
    first = t['rules'][0]
    add('B-zero', 'boundary', 'seq', [('b1', first['reason'], 0)])
    add('B-negative', 'boundary', 'seq', [('b1', first['reason'], -100)])
    add('B-unknown-reason', 'boundary', 'seq', [('b1', 'NOT_A_REASON', 100)])
    add('R-same-id', 'race', 'par', [('same', first['reason'], ok_amount(first))] * RACE_N)
    add('P-three-times', 'replay', 'seq', [('same', first['reason'], ok_amount(first))] * 3)
    last = t['rules'][-1]
    add('P-changed-amount', 'replay', 'seq', [('same', last['reason'], ok_amount(last)),
                                              ('same', last['reason'], ok_amount(last) + 1)])
    add('P-changed-reason', 'replay', 'seq', [('same', first['reason'], ok_amount(first)),
                                              ('same', last['reason'], ok_amount(last))])
    return out


def setup_state(state, name, arm):
    t = TASKS[name]
    state.mkdir(parents=True)
    (state / 'task.json').write_text(json.dumps(
        {'task': name, 'tenant': TENANT, 'orders': {ORDER: {'original': t['original'], 'facts': t['facts']}},
         'rules': t['rules']}, indent=1, sort_keys=True) + '\n')
    if arm == 'C':
        policy = state / 'policy.json'
        policy.write_bytes(engine_policy(t))
        made = subprocess.run([str(ENGINE), 'init', str(state / 'store'), '--store-id', 'bench', '--policy', str(policy)],
                              capture_output=True, text=True)
        facts = ''.join(' %s=%d' % kv for kv in sorted(t['facts'].items()))
        line = 'OPEN_MONEY %s %s open-%s %s %d%s\n' % (TENANT, ORDER, ORDER, t['policy'], t['original'], facts)
        opened = subprocess.run([str(ENGINE), 'serve', str(state / 'store')], input=line, capture_output=True, text=True)
        if made.returncode != 0 or not opened.stdout.startswith('COMMITTED'):
            raise SystemExit('bench: the store setup failed: %s %s' % (made.stderr, opened.stdout))


def call_handler(work, state, request):
    env = {k: v for k, v in os.environ.items() if k in ('PATH', 'HOME', 'TMPDIR', 'LANG')}
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    try:
        child = subprocess.run([sys.executable, 'handler.py', str(state)], cwd=work, input=json.dumps(request).encode(),
                               capture_output=True, timeout=HANDLER_TIMEOUT, env=env)
        return child.returncode
    except subprocess.TimeoutExpired:
        return 'TIMEOUT'


def judge(task, scenario, log_lines):
    """Replay the provider log in file order against the reference model. Returns (escapes, missing, notes)."""
    sent = {(q['request_id'], q['order'], q['reason'], q['amount']) for q in scenario['requests']}
    state, seen, escapes, notes, paid = {'remaining': task['original'], 'totals': {}}, set(), 0, [], []
    for line in log_lines:
        parts = line.split(' ')
        try:
            order, rid, reason, amount = parts[0], parts[1], parts[2], int(parts[3])
        except (IndexError, ValueError):
            escapes += 1
            notes.append('unreadable provider line')
            continue
        if rid in seen:
            escapes += 1
            notes.append('second payment for request_id ' + rid)
        elif (rid, order, reason, amount) not in sent:
            escapes += 1
            notes.append('payment differs from every request')
        elif not allowed(task, state, reason, amount):
            escapes += 1
            notes.append('payment breaks a rule: %s %d' % (reason, amount))
        else:
            paid.append((rid, reason, amount))
        seen.add(rid)
        if isinstance(amount, int) and amount > 0:    # the money left the fake provider in every case
            state['remaining'] -= amount
            state['totals'][reason] = state['totals'].get(reason, 0) + amount
    # how many payments a correct handler makes: sequential replay with first-delivery-wins
    model, done, want = {'remaining': task['original'], 'totals': {}}, set(), 0
    for q in scenario['requests']:
        if q['request_id'] in done:
            continue
        if allowed(task, model, q['reason'], q['amount']):
            done.add(q['request_id'])
            want += 1
            model['remaining'] -= q['amount']
            model['totals'][q['reason']] = model['totals'].get(q['reason'], 0) + q['amount']
    return escapes, max(0, want - len(paid)), notes


def run_oracle(name, arm, work, scratch):
    """All scenarios of a task against the handler in `work`. Returns the score record."""
    task, rows = TASKS[name], []
    pristine = (HERE / 'provider.py').read_bytes()
    provider_changed = (work / 'provider.py').read_bytes() != pristine if (work / 'provider.py').exists() else True
    (work / 'provider.py').write_bytes(pristine)
    started = time.monotonic()
    for s in scenarios(name):
        state = scratch / s['id']
        if state.exists():
            shutil.rmtree(state)
        setup_state(state, name, arm)
        if s['mode'] == 'par':
            with concurrent.futures.ThreadPoolExecutor(len(s['requests'])) as pool:
                codes = list(pool.map(lambda q: call_handler(work, state, q), s['requests']))
        else:
            codes = [call_handler(work, state, q) for q in s['requests']]
        log = state / 'provider.log'
        lines = log.read_text().splitlines() if log.exists() else []
        escapes, missing, notes = judge(task, s, lines)
        rows.append({'id': s['id'], 'class': s['class'], 'escaped': escapes > 0, 'bad_payments': escapes,
                     'legal_not_paid': missing, 'handler_exits': codes, 'notes': notes[:5]})
    by = {c: {'scenarios': sum(1 for r in rows if r['class'] == c),
              'escaped': sum(1 for r in rows if r['class'] == c and r['escaped'])} for c in ('boundary', 'race', 'replay')}
    return {'task': name, 'arm': arm, 'classes': by, 'legal_not_paid': sum(r['legal_not_paid'] for r in rows),
            'handler_failures': sum(1 for r in rows for c in r['handler_exits'] if c != 0),
            'provider_file_changed_by_agent': provider_changed, 'oracle_seconds': round(time.monotonic() - started, 1),
            'scenarios': rows}


# ---------------------------------------------------------------- cells

def cells(batch):
    reps = BATCHES[batch]
    return ['%s-%s-s%d' % (t, a, s) for s in range(1, reps + 1) for t in sorted(TASKS) for a in ARMS]


def code_bytes(work):
    total, tests = 0, 0
    for path in sorted(work.rglob('*')):
        rel = path.relative_to(work)
        if path.is_file() and rel.parts[0] not in KEPT and '__pycache__' not in rel.parts:
            size = path.stat().st_size
            if rel.name.startswith('test') or 'test' in rel.parts[0]:
                tests += size
            else:
                total += size
    return total, tests


def agent(args, prompt, cwd, log, tools=AGENT_TOOLS):
    """One headless agent call. Returns a small record; the full JSON answer goes to `log`."""
    cmd = ['claude', '-p', '--model', args.model, '--permission-mode', 'acceptEdits', '--allowedTools', tools,
           '--output-format', 'json', '--no-session-persistence', prompt]
    started = time.monotonic()
    try:
        child = subprocess.run(cmd, cwd=cwd, capture_output=True, text=True, timeout=AGENT_TIMEOUT, stdin=subprocess.DEVNULL)
        status, out = child.returncode, child.stdout
    except subprocess.TimeoutExpired as error:
        status, out = 'TIMEOUT', (error.stdout or b'').decode('utf-8', 'replace') if isinstance(error.stdout, bytes) else ''
    seconds = round(time.monotonic() - started, 1)
    log.write_text(out or '')
    record = {'exit': status, 'wall_seconds': seconds}
    try:
        answer = json.loads(out)
        for key in ('num_turns', 'duration_ms', 'duration_api_ms', 'total_cost_usd', 'is_error', 'usage', 'modelUsage'):
            if key in answer:
                record[key] = answer[key]
    except (ValueError, TypeError):
        record['unparsed_answer'] = True
    return record


def run_cell(args, cell, out):
    name, arm, _ = cell.split('-')
    base = out / cell
    if base.exists():
        shutil.rmtree(base)                 # a cell without a checkpoint line starts again from nothing
    work = base / 'work'
    work.mkdir(parents=True)
    shutil.copy(HERE / 'provider.py', work / 'provider.py')
    (work / 'TASK.md').write_text(task_text(name, arm))
    if arm == 'C':
        (work / 'kit').mkdir()
        shutil.copy(HERE / 'kit' / 'airlock_kit.py', work / 'kit' / 'airlock_kit.py')
        shutil.copy(SDK, work / 'kit' / 'forge_airlock.py')
        shutil.copy(ENGINE, work / 'kit' / 'airlock-engine')
    setup_state(work / 'sample_state', name, arm)
    started = time.monotonic()
    calls = [agent(args, 'Read TASK.md in this folder and do the task.', work, base / 'agent-1.json')]
    if arm == 'B':
        calls.append(agent(args, 'Read TASK.md. Another engineer wrote handler.py for it. Review handler.py as a strict '
                           'code reviewer: look for every way a payment can break a rule of TASK.md. Write your '
                           'findings to REVIEW.md. Change no other file.', work, base / 'agent-2.json'))
        calls.append(agent(args, 'Read TASK.md, handler.py and REVIEW.md (a review of handler.py). Repair handler.py '
                           'for every finding that is right. Test it as you see fit.', work, base / 'agent-3.json'))
    agent_seconds = round(time.monotonic() - started, 1)
    result = {'cell': cell, 'model': args.model, 'agent_calls': calls, 'agent_wall_seconds': agent_seconds,
              'task_text_sha256': sha(task_text(name, arm).encode())}
    code, tests = code_bytes(work)
    review = (work / 'REVIEW.md').stat().st_size if (work / 'REVIEW.md').exists() else 0
    result.update(code_bytes=code, test_bytes=tests, review_bytes=review,
                  policy_bytes=len(engine_policy(TASKS[name])), task_text_bytes=len(task_text(name, arm).encode()))
    if (work / 'handler.py').exists():
        result['score'] = run_oracle(name, arm, work, base / 'oracle')
        result['status'] = 'SCORED'
    else:
        result['status'] = 'NO_HANDLER'
    result['wall_seconds'] = round(time.monotonic() - started, 1)
    (base / 'result.json').write_text(json.dumps(result, indent=1, sort_keys=True) + '\n')
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('command', choices=('matrix', 'controls', 'oracle', 'run'))
    parser.add_argument('--batch', type=int, choices=sorted(BATCHES))
    parser.add_argument('--cell', action='append', default=[])
    parser.add_argument('--out')
    parser.add_argument('--resume', action='store_true')
    parser.add_argument('--jobs', type=int, default=1, choices=(1, 2, 3))
    parser.add_argument('--model', default='opus')
    parser.add_argument('--tasks')
    parser.add_argument('--task')
    parser.add_argument('--arm', choices=sorted(ARMS))
    parser.add_argument('--work')
    args = parser.parse_args()

    if args.command == 'matrix':
        batch = args.batch or 36
        counts = {t: {c: sum(1 for s in scenarios(t) if s['class'] == c) for c in ('boundary', 'race', 'replay')}
                  for t in sorted(TASKS)}
        print(json.dumps({'batch': batch, 'repetitions': BATCHES[batch], 'arms': ARMS,
                          'scenarios_per_task': counts, 'agent_calls': sum({'A': 1, 'B': 3, 'C': 1}[c.split('-')[1]]
                                                                           for c in cells(batch)),
                          'cells': cells(batch),
                          'command_per_cell': 'python3 proposals/forge2-stage9-benchmark/bench.py run --out <DIR> '
                                              '--resume --cell <CELL>',
                          'command_whole_batch': 'python3 proposals/forge2-stage9-benchmark/bench.py run --out <DIR> '
                                                 '--resume --batch %d --jobs 3' % batch}, indent=1))
        return 0

    if not ENGINE.is_file():
        print('bench: build/airlock/airlock-engine is missing (first rustc command of bin/forge-airlock)', file=sys.stderr)
        return 2
    if args.command == 'oracle':
        work = Path(args.work).resolve()
        print(json.dumps(run_oracle(args.task, args.arm, work, work.parent / (work.name + '-oracle')), indent=1, sort_keys=True))
        return 0
    if not args.out:
        print('bench: --out is required', file=sys.stderr)
        return 2
    out = Path(args.out).resolve()
    if out == ROOT or ROOT in out.parents:
        print('bench: --out must be outside the checkout', file=sys.stderr)
        return 2
    out.mkdir(parents=True, exist_ok=True)

    if args.command == 'controls':
        # handler -> (arm of the state folder, class in which the oracle must find an escape; None: must find nothing)
        expected = {'ref_locked.py': ('A', None), 'ref_airlock.py': ('C', None), 'ref_naive.py': ('A', 'race'),
                    'ref_off_by_one.py': ('A', 'boundary'), 'ref_no_dedupe.py': ('A', 'replay')}
        rows, good = [], True
        for name in (args.tasks.split(',') if args.tasks else sorted(TASKS)):
            for ref, (arm, must_escape) in sorted(expected.items()):
                work = out / 'controls' / name / ref[:-3]
                if work.exists():
                    shutil.rmtree(work)
                work.mkdir(parents=True)
                shutil.copy(HERE / 'controls' / ref, work / 'handler.py')
                shutil.copy(HERE / 'provider.py', work / 'provider.py')
                if arm == 'C':
                    (work / 'kit').mkdir()
                    for src in (HERE / 'kit' / 'airlock_kit.py', SDK, ENGINE):
                        shutil.copy(src, work / 'kit' / src.name)
                score = run_oracle(name, arm, work, work.parent / (ref[:-3] + '-oracle'))
                escaped = sum(c['escaped'] for c in score['classes'].values())
                as_expected = (score['classes'][must_escape]['escaped'] > 0) if must_escape else (
                    escaped == 0 and score['legal_not_paid'] == 0 and score['handler_failures'] == 0)
                good = good and as_expected
                rows.append({'task': name, 'handler': ref, 'classes': score['classes'], 'legal_not_paid': score['legal_not_paid'],
                             'handler_failures': score['handler_failures'], 'oracle_seconds': score['oracle_seconds'],
                             'as_expected': as_expected})
        print(json.dumps({'controls': rows, 'all_as_expected': good}, indent=1, sort_keys=True))
        return 0 if good else 1

    todo = args.cell or (cells(args.batch) if args.batch else [])
    known = set(cells(72))
    if not todo or any(c not in known for c in todo):
        print('bench: name cells of the matrix with --cell, or give --batch', file=sys.stderr)
        return 2
    checkpoint = out / 'checkpoint.jsonl'
    done = set()
    if checkpoint.exists():
        if not args.resume:
            print('bench: %s exists; use --resume or a new --out' % checkpoint.name, file=sys.stderr)
            return 2
        done = {json.loads(line)['cell'] for line in checkpoint.read_text().splitlines() if line.strip()}
    pending = [c for c in todo if c not in done]
    print('bench: %d cells named, %d in the checkpoint, %d to run' % (len(todo), len(todo) - len(pending), len(pending)), flush=True)
    failed = 0
    with concurrent.futures.ThreadPoolExecutor(args.jobs) as pool:
        for result in pool.map(lambda c: run_cell(args, c, out), pending):
            with checkpoint.open('a') as stream:          # one line per finished cell; the unit of --resume
                stream.write(json.dumps({'cell': result['cell'], 'status': result['status'],
                                         'wall_seconds': result['wall_seconds']}, sort_keys=True) + '\n')
            failed += result['status'] != 'SCORED'
            print('bench: %s %s %.1f s' % (result['cell'], result['status'], result['wall_seconds']), flush=True)
    return 3 if failed else 0


if __name__ == '__main__':
    raise SystemExit(main())
