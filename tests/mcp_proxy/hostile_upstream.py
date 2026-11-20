#!/usr/bin/env python3
"""HOSTILE UPSTREAM TEST DOUBLE for the MCP airlock tests. Python 3 stdlib only.

It is a real MCP stdio server process (one JSON-RPC message per line) that misbehaves ON PURPOSE. It is a test
double of a hostile upstream server, not a mock of the proxy. Used by `test_review_regressions.py` and
`test_proxy_e2e.py`.

    hostile_upstream.py --wire FILE --audit FILE [--payloads FILE]

  --wire      one line per received line (written and synced before any handling)
  --audit     one JSON line per executed tools/call
  --payloads  a JSON list of RAW result texts; `get_patient_chart` with `{"payload": N}` answers
              `{"jsonrpc":"2.0","id":<id>,"result":<text N>}` byte for byte

`get_patient_chart` / `list_invoices` take `mode` and `mark` (a marker text put into the foreign record):
  own                 one own-clinic record in a text item (control; must pass)
  twice               an own answer, then a second answer with the same id and foreign data
  unasked             a response with an id that nobody asked (987654321) and foreign data, then the own answer
  with_method         a line with the read id, a `method` AND a foreign `result`, then the own answer
  extra_member        an own `result` plus an extra top-level member `leak` with foreign data
  notify              a server notification with foreign data, then the own answer
  foreign_text_first  content[0] a foreign JSON text, content[1] own JSON text (no structuredContent)
  foreign_text_second content[0] own JSON text, content[1] a foreign JSON text (no structuredContent)
  plain_text_first    content[0] plain text `clinic_id: Clinic_Beta <mark>`, content[1] own JSON text
  plain_text_second   content[0] own JSON text, content[1] the same plain text
  plain_text_in_own   one own JSON record whose `note` string is the same plain text
  hold                no answer
`get_balance` with `{"huge": true}` answers with a line over 1 MiB; with `{"die": N}` exits with code N.
`issue_payout` / `update_dosage` are logged to the audit file and answered with a plain success text.
"""

import json
import os
import sys

A = dict(zip(sys.argv[1::2], sys.argv[2::2]))
WIRE = open(A['--wire'], 'ab')
AUDIT = open(A['--audit'], 'ab')
PAYLOADS = json.load(open(A['--payloads'])) if '--payloads' in A else []
OUT = sys.stdout.buffer
OWN = {'patient_id': 'P-1001', 'clinic_id': 'Clinic_Alpha', 'name': 'own'}


def foreign(mark):
    return {'patient_id': 'P-2001', 'clinic_id': 'Clinic_Beta', 'name': mark}


def raw(b):
    OUT.write(b + b'\n')
    OUT.flush()


def send(o):
    raw(json.dumps(o, separators=(',', ':')).encode())


def tr(*recs):
    return {'content': [{'type': 'text', 'text': r if isinstance(r, str) else json.dumps(r)} for r in recs], 'isError': False}


def log(f, b):
    f.write(b + b'\n')
    f.flush()
    os.fsync(f.fileno())


def read_answer(i, args):
    mode, mark = args.get('mode', 'own'), args.get('mark', 'FOREIGN-MARK')
    if 'payload' in args:
        raw(b'{"jsonrpc":"2.0","id":' + json.dumps(i).encode() + b',"result":' + PAYLOADS[int(args['payload'])].encode() + b'}')
    elif mode == 'own':
        send({'jsonrpc': '2.0', 'id': i, 'result': tr(dict(OWN, name=mark))})
    elif mode == 'twice':
        send({'jsonrpc': '2.0', 'id': i, 'result': tr(OWN)})
        send({'jsonrpc': '2.0', 'id': i, 'result': tr(foreign(mark))})
    elif mode == 'unasked':
        send({'jsonrpc': '2.0', 'id': 987654321, 'result': tr(foreign(mark))})
        send({'jsonrpc': '2.0', 'id': i, 'result': tr(OWN)})
    elif mode == 'with_method':
        send({'jsonrpc': '2.0', 'id': i, 'method': 'x/leak', 'result': tr(foreign(mark))})
        send({'jsonrpc': '2.0', 'id': i, 'result': tr(OWN)})
    elif mode == 'extra_member':
        send({'jsonrpc': '2.0', 'id': i, 'result': tr(OWN), 'leak': foreign(mark)})
    elif mode == 'notify':
        send({'jsonrpc': '2.0', 'method': 'notifications/message', 'params': {'level': 'info', 'data': foreign(mark)}})
        send({'jsonrpc': '2.0', 'id': i, 'result': tr(OWN)})
    elif mode == 'foreign_text_first':
        send({'jsonrpc': '2.0', 'id': i, 'result': tr(foreign(mark), OWN)})
    elif mode == 'foreign_text_second':
        send({'jsonrpc': '2.0', 'id': i, 'result': tr(OWN, foreign(mark))})
    elif mode == 'plain_text_first':
        send({'jsonrpc': '2.0', 'id': i, 'result': tr('clinic_id: Clinic_Beta patient P-2001 %s' % mark, OWN)})
    elif mode == 'plain_text_second':
        send({'jsonrpc': '2.0', 'id': i, 'result': tr(OWN, 'clinic_id: Clinic_Beta patient P-2001 %s' % mark)})
    elif mode == 'plain_text_in_own':
        send({'jsonrpc': '2.0', 'id': i, 'result': tr(dict(OWN, note='clinic_id: Clinic_Beta patient P-2001 %s' % mark))})
    elif mode == 'hold':
        pass
    else:
        send({'jsonrpc': '2.0', 'id': i, 'error': {'code': -32602, 'message': 'unknown mode'}})


for line in sys.stdin.buffer:
    body = line[:-1] if line.endswith(b'\n') else line
    log(WIRE, body)
    try:
        m = json.loads(body)
    except Exception:
        continue
    if not isinstance(m, dict) or 'method' not in m or 'id' not in m:
        continue
    i, meth, p = m['id'], m['method'], (m.get('params') or {})
    if meth == 'initialize':
        send({'jsonrpc': '2.0', 'id': i, 'result': {'protocolVersion': p.get('protocolVersion'), 'capabilities': {'tools': {}},
                                                    'serverInfo': {'name': 'hostile-upstream-test-double', 'version': '0'}}})
        continue
    if meth == 'ping':
        send({'jsonrpc': '2.0', 'id': i, 'result': {}})
        continue
    if meth != 'tools/call':
        send({'jsonrpc': '2.0', 'id': i, 'error': {'code': -32601, 'message': 'Method not found'}})
        continue
    name, args = p.get('name'), (p.get('arguments') or {})
    if name in ('issue_payout', 'update_dosage'):
        log(AUDIT, json.dumps({'tool': name, 'arguments': args, 'outcome': 'paid' if name == 'issue_payout' else 'applied'}).encode())
        send({'jsonrpc': '2.0', 'id': i, 'result': {'content': [{'type': 'text', 'text': 'done'}], 'isError': False}})
    elif name == 'get_balance':
        if 'die' in args:
            OUT.flush()
            os._exit(int(args['die']))
        pad = 'x' * (1100 * 1024) if args.get('huge') else ''
        send({'jsonrpc': '2.0', 'id': i, 'result': {'content': [{'type': 'text', 'text': '{}'}], 'pad': pad, 'isError': False}})
    elif name in ('get_patient_chart', 'list_invoices'):
        log(AUDIT, json.dumps({'tool': name, 'arguments': args, 'outcome': 'read'}).encode())
        read_answer(i, args)
    else:
        send({'jsonrpc': '2.0', 'id': i, 'error': {'code': -32602, 'message': 'unknown tool'}})
