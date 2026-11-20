"""Oracle control, NOT a competitor: ref_locked.py with every upper limit one cent too high. The oracle must find boundary escapes."""
import fcntl, json, os, subprocess, sys

state = sys.argv[1]
q = json.load(sys.stdin)
lock = open(os.path.join(state, 'lock'), 'w')
fcntl.flock(lock, fcntl.LOCK_EX)      # held until the process ends
task = json.load(open(os.path.join(state, 'task.json')))
path = os.path.join(state, 'ledger.json')
ledger = json.load(open(path)) if os.path.exists(path) else {'paid': {}, 'total': 0, 'by_reason': {}}
order = task['orders'].get(q['order'])
status = 'REJECTED'
if q['request_id'] in ledger['paid']:
    status = 'DUPLICATE'
elif order and isinstance(q['amount'], int) and 0 < q['amount'] <= order['original'] - ledger['total'] + 1:
    for r in task['rules']:
        if r['reason'] == q['reason'] and q['amount'] >= r.get('min', 1) and q['amount'] <= r.get('max', q['amount']) + 1 and (
                'fact' not in r or ledger['by_reason'].get(q['reason'], 0) + q['amount'] <= order['facts'][r['fact']] + 1):
            subprocess.run([sys.executable, os.path.join(os.path.dirname(os.path.abspath(__file__)), 'provider.py'), state,
                            q['order'], q['request_id'], q['reason'], str(q['amount'])], check=True, stdout=subprocess.DEVNULL)
            ledger['paid'][q['request_id']] = q['amount']
            ledger['total'] += q['amount']
            ledger['by_reason'][q['reason']] = ledger['by_reason'].get(q['reason'], 0) + q['amount']
            json.dump(ledger, open(path, 'w'))
            status = 'PAID'
            break
print(json.dumps({'status': status}))
