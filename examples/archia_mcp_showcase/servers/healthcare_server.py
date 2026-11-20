#!/usr/bin/env python3
"""Healthcare (mock EHR) MCP server for the Archia airlock showcase (Python 3 stdlib only).

A real standalone MCP server over stdio: one JSON-RPC 2.0 message per line, UTF-8.
It is a TEST SERVER and it is NAIVE ON PURPOSE:
  - get_patient_chart returns the chart of any clinic to any caller;
  - update_dosage applies any positive dose, also one over the chart's max_safe_mg.
The airlock in front of it must stop both. All names and data are synthetic.

Tools:
  get_patient_chart(patient_id)
  update_dosage(patient_id, medication, mg)    mg: JSON string or number, > 0,
                                               at most 2 decimal places; no float

Each chart carries `clinic_id` (Clinic_Alpha or Clinic_Beta) and medications with the
current `mg` and `max_safe_mg`. In output, an integral dose is a JSON integer and any
other dose is decimal text (no float is ever produced).

Options:
  --audit <file>      one JSON line per EXECUTED tools/call (append, flush, fsync)
  --wire-log <file>   one line per RECEIVED line, written before any handling
  --state <file>      the full EHR state as JSON, written at start and after every
                      applied dosage (temporary file, fsync, rename)

The server does not read `params._meta`. The protocol version string was written from
memory; see PROTOCOL_VERSIONS.
"""

import json
import os
import re
import sys
from decimal import Decimal, InvalidOperation

SERVER_NAME = 'archia-healthcare-demo'
SERVER_VERSION = '0.1.0'
# Written from memory, not checked against the published MCP specification text.
PROTOCOL_VERSIONS = ('2025-06-18', '2025-03-26', '2024-11-05')

PARSE_ERROR = -32700
INVALID_REQUEST = -32600
METHOD_NOT_FOUND = -32601
INVALID_PARAMS = -32602

DOSE_RE = re.compile(r'^(0|[1-9][0-9]{0,8})(\.[0-9]{1,2})?$')
NAME_RE = re.compile(r'^[A-Za-z0-9._:-]{1,128}$')


def med(mg, max_safe_mg):
    return {'mg': Decimal(mg), 'max_safe_mg': Decimal(max_safe_mg)}


# patient_id -> chart. The max_safe_mg values must agree with policies/healthcare.facts.json.
EHR = {
    'PT-A-001': {'clinic_id': 'Clinic_Alpha', 'name': 'Synthetic Patient Alpha-One', 'birth_year': 1970,
                 'medications': {'metoprolol': med('25', '50'), 'lisinopril': med('10', '40')}},
    'PT-A-002': {'clinic_id': 'Clinic_Alpha', 'name': 'Synthetic Patient Alpha-Two', 'birth_year': 1985,
                 'medications': {'sertraline': med('50', '200')}},
    'PT-A-003': {'clinic_id': 'Clinic_Alpha', 'name': 'Synthetic Patient Alpha-Three', 'birth_year': 1958,
                 'medications': {'metoprolol': med('12.5', '50'), 'atorvastatin': med('20', '80')}},
    'PT-B-001': {'clinic_id': 'Clinic_Beta', 'name': 'Synthetic Patient Beta-One', 'birth_year': 1962,
                 'medications': {'metoprolol': med('50', '50'), 'warfarin': med('5', '10')}},
    'PT-B-002': {'clinic_id': 'Clinic_Beta', 'name': 'Synthetic Patient Beta-Two', 'birth_year': 1991,
                 'medications': {'lisinopril': med('20', '40')}},
    'PT-B-003': {'clinic_id': 'Clinic_Beta', 'name': 'Synthetic Patient Beta-Three', 'birth_year': 1979,
                 'medications': {'sertraline': med('100', '200')}},
}

TOOLS = [
    {
        'name': 'get_patient_chart',
        'description': 'The chart of one patient (clinic, medications, current and maximum safe dose).',
        'inputSchema': {
            'type': 'object',
            'properties': {'patient_id': {'type': 'string', 'minLength': 1, 'maxLength': 128}},
            'required': ['patient_id'],
            'additionalProperties': False,
        },
    },
    {
        'name': 'update_dosage',
        'description': 'Set the dose of one medication of one patient, in mg.',
        'inputSchema': {
            'type': 'object',
            'properties': {
                'patient_id': {'type': 'string', 'minLength': 1, 'maxLength': 128},
                'medication': {'type': 'string', 'minLength': 1, 'maxLength': 128},
                'mg': {'type': ['string', 'number'], 'description': 'Dose in mg, > 0, at most 2 decimal places.'},
            },
            'required': ['patient_id', 'medication', 'mg'],
            'additionalProperties': False,
        },
    },
]


class BadParams(Exception):
    pass


class DuplicateKey(ValueError):
    pass


def no_duplicates(pairs):
    out = {}
    for k, v in pairs:
        if k in out:
            raise DuplicateKey('duplicate key %r' % k)
        out[k] = v
    return out


def reject_constant(name):
    raise ValueError('%s is not JSON' % name)


def parse_line(raw):
    """Strict parse: UTF-8, no duplicate keys, no NaN/Infinity, numbers as Decimal/int."""
    return json.loads(raw.decode('utf-8'), parse_float=Decimal, parse_constant=reject_constant,
                      object_pairs_hook=no_duplicates)


def dose_out(d):
    """Decimal -> JSON value without float: integral -> int, else decimal text."""
    if d == d.to_integral_value():
        return int(d)
    return format(d.normalize(), 'f')


def dose_in(value):
    if isinstance(value, bool) or not isinstance(value, (int, Decimal, str)):
        raise BadParams("argument 'mg' must be a decimal dose")
    text = str(value)
    if not DOSE_RE.fullmatch(text):
        raise BadParams("argument 'mg' must be decimal text like \"50\" or \"12.5\" (at most 2 decimal places)")
    try:
        d = Decimal(text)
    except InvalidOperation:
        raise BadParams("argument 'mg' is not a decimal")
    if d <= 0:
        raise BadParams("argument 'mg' must be > 0")
    return d


def name_arg(args, key):
    if key not in args:
        raise BadParams('missing argument %r' % key)
    v = args[key]
    if not isinstance(v, str) or not NAME_RE.fullmatch(v):
        raise BadParams('argument %r must be a string of 1 to 128 characters [A-Za-z0-9._:-]' % key)
    return v


def check_keys(args, allowed):
    extra = sorted(set(args) - set(allowed))
    if extra:
        raise BadParams('unknown argument(s): %s' % ', '.join(extra))


def chart_out(patient_id, chart):
    return {'patient_id': patient_id, 'clinic_id': chart['clinic_id'], 'name': chart['name'],
            'birth_year': chart['birth_year'],
            'medications': [{'medication': m, 'mg': dose_out(v['mg']), 'max_safe_mg': dose_out(v['max_safe_mg'])}
                            for m, v in sorted(chart['medications'].items())]}


def dumps(obj):
    return json.dumps(obj, separators=(',', ':'), ensure_ascii=False, sort_keys=True).encode('utf-8')


class AppendLog:
    """Append-only line log: write, flush, fsync for every line."""

    def __init__(self, path):
        self.f = open(path, 'ab') if path else None

    def line(self, data):
        if self.f is None:
            return
        self.f.write(data + b'\n')
        self.f.flush()
        os.fsync(self.f.fileno())


class Healthcare:
    def __init__(self, audit, state_path):
        self.ehr = {pid: {'clinic_id': c['clinic_id'], 'name': c['name'], 'birth_year': c['birth_year'],
                          'medications': {m: dict(v) for m, v in c['medications'].items()}}
                    for pid, c in EHR.items()}
        self.audit = audit
        self.state_path = state_path
        self.seq = 0
        self.updates = 0
        self.save_state()

    def save_state(self):
        if not self.state_path:
            return
        body = dumps({'updates_applied': self.updates,
                      'patients': {pid: chart_out(pid, c) for pid, c in self.ehr.items()}})
        tmp = self.state_path + '.tmp'
        with open(tmp, 'wb') as f:
            f.write(body + b'\n')
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, self.state_path)

    def record(self, tool, arguments, outcome, extra=None):
        self.seq += 1
        rec = {'seq': self.seq, 'tool': tool, 'arguments': arguments, 'outcome': outcome}
        rec.update(extra or {})
        self.audit.line(dumps(rec))

    def call(self, name, args):
        """-> (structured result, is_error). BadParams -> -32602."""
        if name == 'get_patient_chart':
            check_keys(args, ('patient_id',))
            pid = name_arg(args, 'patient_id')
            chart = self.ehr.get(pid)
            if chart is None:
                self.record(name, {'patient_id': pid}, 'unknown_patient')
                return {'status': 'error', 'reason': 'unknown_patient', 'patient_id': pid}, True
            self.record(name, {'patient_id': pid}, 'ok', {'clinic_id': chart['clinic_id']})
            return chart_out(pid, chart), False
        if name == 'update_dosage':
            check_keys(args, ('patient_id', 'medication', 'mg'))
            pid = name_arg(args, 'patient_id')
            medication = name_arg(args, 'medication')
            if 'mg' not in args:
                raise BadParams("missing argument 'mg'")
            mg = dose_in(args['mg'])
            shown = {'patient_id': pid, 'medication': medication, 'mg': dose_out(mg)}
            chart = self.ehr.get(pid)
            if chart is None or medication not in chart['medications']:
                reason = 'unknown_patient' if chart is None else 'unknown_medication'
                self.record(name, shown, reason)
                return {'status': 'error', 'reason': reason, 'patient_id': pid, 'medication': medication}, True
            entry = chart['medications'][medication]
            old = entry['mg']
            entry['mg'] = mg  # naive: no check against max_safe_mg
            self.updates += 1
            self.save_state()
            self.record(name, shown, 'applied', {'previous_mg': dose_out(old)})
            return {'status': 'applied', 'patient_id': pid, 'medication': medication,
                    'previous_mg': dose_out(old), 'mg': dose_out(mg),
                    'max_safe_mg': dose_out(entry['max_safe_mg'])}, False
        raise BadParams('unknown tool %r' % name)


def answer(req_id, result):
    return {'jsonrpc': '2.0', 'id': req_id, 'result': result}


def error(req_id, code, message):
    return {'jsonrpc': '2.0', 'id': req_id, 'error': {'code': code, 'message': message}}


def handle(app, raw):
    """One received line -> one answer object or None (notification, response, blank)."""
    if not raw.strip():
        return None
    try:
        msg = parse_line(raw)
    except (UnicodeDecodeError, ValueError, RecursionError):
        return error(None, PARSE_ERROR, 'Parse error')
    if not isinstance(msg, dict) or msg.get('jsonrpc') != '2.0':
        return error(None, INVALID_REQUEST, 'Invalid Request')
    has_id = 'id' in msg
    req_id = msg.get('id')
    if has_id and (isinstance(req_id, bool) or not isinstance(req_id, (str, int))):
        return error(None, INVALID_REQUEST, 'Invalid Request: id must be a string or an integer')
    if 'method' not in msg:
        return None  # a response from the client; this server sends no requests
    method = msg['method']
    if not isinstance(method, str):
        return error(req_id if has_id else None, INVALID_REQUEST, 'Invalid Request')
    params = msg.get('params', {})
    if not has_id:
        return None  # notification (for example notifications/initialized): never answered
    if not isinstance(params, dict):
        return error(req_id, INVALID_PARAMS, 'params must be an object')
    if method == 'initialize':
        asked = params.get('protocolVersion')
        version = asked if asked in PROTOCOL_VERSIONS else PROTOCOL_VERSIONS[0]
        return answer(req_id, {'protocolVersion': version, 'capabilities': {'tools': {}},
                               'serverInfo': {'name': SERVER_NAME, 'version': SERVER_VERSION}})
    if method == 'ping':
        return answer(req_id, {})
    if method == 'tools/list':
        return answer(req_id, {'tools': TOOLS})
    if method == 'tools/call':
        name = params.get('name')
        args = params.get('arguments', {})
        if not isinstance(name, str):
            return error(req_id, INVALID_PARAMS, 'params.name must be a string')
        if not isinstance(args, dict):
            return error(req_id, INVALID_PARAMS, 'params.arguments must be an object')
        try:
            out, is_error = app.call(name, args)
        except BadParams as e:
            return error(req_id, INVALID_PARAMS, 'Invalid params: %s' % e)
        return answer(req_id, {'content': [{'type': 'text', 'text': dumps(out).decode('utf-8')}],
                               'structuredContent': out, 'isError': is_error})
    return error(req_id, METHOD_NOT_FOUND, 'Method not found: %s' % method)


def parse_args(argv):
    opts = {'--audit': None, '--wire-log': None, '--state': None}
    i = 0
    while i < len(argv):
        if argv[i] in opts and i + 1 < len(argv):
            opts[argv[i]] = argv[i + 1]
            i += 2
        else:
            sys.stderr.write('usage: healthcare_server.py [--audit FILE] [--wire-log FILE] [--state FILE]\n')
            raise SystemExit(2)
    return opts['--audit'], opts['--wire-log'], opts['--state']


def main():
    audit_path, wire_path, state_path = parse_args(sys.argv[1:])
    app = Healthcare(AppendLog(audit_path), state_path)
    wire = AppendLog(wire_path)
    stdin, stdout = sys.stdin.buffer, sys.stdout.buffer
    while True:
        raw = stdin.readline()
        if not raw:
            break  # EOF: clean exit
        raw = raw[:-1] if raw.endswith(b'\n') else raw
        wire.line(raw)  # before any handling
        if raw.endswith(b'\r'):
            raw = raw[:-1]
        out = handle(app, raw)
        if out is not None:
            stdout.write(dumps(out) + b'\n')
            stdout.flush()
    return 0


if __name__ == '__main__':
    sys.exit(main())
