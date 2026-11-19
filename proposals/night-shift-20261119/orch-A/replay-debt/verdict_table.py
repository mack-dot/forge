"""Read-only: summarize a copy of results.json. Usage: verdict_table.py <results-copy.json>"""
import json, sys, collections
r = json.load(open(sys.argv[1]))
cs = sorted(r['cases'].values(), key=lambda c: c['index'])
print('cases', len(cs))
for v, n in sorted(collections.Counter(c.get('verdict') for c in cs).items()): print(f'{v}\t{n}')
print('-- not AS_RECORDED:')
for c in cs:
    if c.get('verdict') != 'AS_RECORDED':
        print(c['index'], c['case_id'], c.get('verdict'), 'actual', c.get('actual_exit'), 'recorded', c.get('recorded_exit'), c.get('start_utc'))
    if 'rerun' in c:
        rr = c['rerun']; print('RERUN', c['case_id'], 'verdict', rr.get('verdict'), 'actual_exit', rr.get('actual_exit'), 'start', rr.get('start_utc'), 'note', str(rr.get('note'))[:120])
print('events tail', json.dumps(r['events'][-3:]))
