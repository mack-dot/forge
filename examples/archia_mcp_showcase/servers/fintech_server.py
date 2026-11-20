#!/usr/bin/env python3
"""Fintech MCP server for the Archia airlock showcase (Python 3 stdlib only).

A real standalone MCP server over stdio: one JSON-RPC 2.0 message per line, UTF-8.
It is a TEST SERVER. It enforces nothing about the airlock. With no proxy in front,
it executes every valid payout until its own balance refuses one.

Tools:
  issue_payout(amount, invoice_id, vendor)  pays from the internal balance; a payout
                                            over the balance is refused (isError: true)
  get_balance()                             the current balance
  list_invoices([org_id])                   invoices of TWO organisations; without
                                            org_id it returns all of them (a naive
                                            cross-tenant read, on purpose)

Money is integer cents inside and decimal text ("500.00") outside. No float is used.
`amount` is a JSON string or a JSON number with at most 2 decimal places, > 0.

Options:
  --balance <decimal>   start balance (default 1000.00)
  --audit <file>        one JSON line per EXECUTED tools/call (append, flush, fsync)
  --wire-log <file>     one line per RECEIVED line, written before any handling

The server does not read `params._meta`. The protocol version string was written from
memory; see PROTOCOL_VERSIONS.
"""

import json
import os
import re
import sys
from decimal import Decimal, InvalidOperation

SERVER_NAME = 'archia-fintech-demo'
SERVER_VERSION = '0.1.0'
# Written from memory, not checked against the published MCP specification text.
PROTOCOL_VERSIONS = ('2025-06-18', '2025-03-26', '2024-11-05')

PARSE_ERROR = -32700
INVALID_REQUEST = -32600
METHOD_NOT_FOUND = -32601
INVALID_PARAMS = -32602

MONEY_RE = re.compile(r'^(0|[1-9][0-9]{0,11})(\.[0-9]{1,2})?$')
NAME_RE = re.compile(r'^[A-Za-z0-9._:/(), -]{1,128}$')

INVOICES = [
    {'invoice_id': 'INV-A-1001', 'org_id': 'Org_Alpha', 'vendor': 'Example Paper Supply (synthetic)', 'amount': '500.00', 'status': 'open'},
    {'invoice_id': 'INV-A-1002', 'org_id': 'Org_Alpha', 'vendor': 'Example Cloud Hosting (synthetic)', 'amount': '120.50', 'status': 'open'},
    {'invoice_id': 'INV-B-2001', 'org_id': 'Org_Beta', 'vendor': 'Example Legal Services (synthetic)', 'amount': '900.00', 'status': 'open'},
    {'invoice_id': 'INV-B-2002', 'org_id': 'Org_Beta', 'vendor': 'Example Payroll Bureau (synthetic)', 'amount': '75.25', 'status': 'open'},
]

TOOLS = [
    {
        'name': 'issue_payout',
        'description': 'Pay a vendor from the internal account. Refused when the amount is over the balance.',
        'inputSchema': {
            'type': 'object',
            'properties': {
                'amount': {'type': ['string', 'number'], 'description': 'Decimal amount in dollars, > 0, at most 2 decimal places, for example "500.00".'},
                'invoice_id': {'type': 'string', 'minLength': 1, 'maxLength': 128},
                'vendor': {'type': 'string', 'minLength': 1, 'maxLength': 128},
            },
            'required': ['amount', 'invoice_id', 'vendor'],
            'additionalProperties': False,
        },
    },
    {
        'name': 'get_balance',
        'description': 'The current account balance.',
        'inputSchema': {'type': 'object', 'properties': {}, 'additionalProperties': False},
    },
    {
        'name': 'list_invoices',
        'description': 'Invoices. Without org_id this returns the invoices of every organisation.',
        'inputSchema': {
            'type': 'object',
            'properties': {'org_id': {'type': 'string', 'minLength': 1, 'maxLength': 128}},
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
    text = raw.decode('utf-8')
    return json.loads(text, parse_float=Decimal, parse_constant=reject_constant, object_pairs_hook=no_duplicates)


def cents_to_text(c):
    return '%d.%02d' % (c // 100, c % 100)


def money_to_cents(value, what):
    """JSON string or number -> integer cents. Exact; never float."""
    if isinstance(value, bool):
        raise BadParams('%s must be a decimal amount' % what)
    if isinstance(value, int):
        text = str(value)
    elif isinstance(value, Decimal):
        text = str(value)
    elif isinstance(value, str):
        text = value
    else:
        raise BadParams('%s must be a decimal amount' % what)
    if not MONEY_RE.fullmatch(text):
        raise BadParams('%s must be decimal text like "500.00" (at most 2 decimal places)' % what)
    try:
        d = Decimal(text)
    except InvalidOperation:
        raise BadParams('%s is not a decimal' % what)
    cents = int(d * 100)
    if Decimal(cents) != d * 100:
        raise BadParams('%s has more than 2 decimal places' % what)
    return cents


def name_arg(args, key, required=True):
    if key not in args:
        if required:
            raise BadParams('missing argument %r' % key)
        return None
    v = args[key]
    if not isinstance(v, str) or not NAME_RE.fullmatch(v):
        raise BadParams('argument %r must be a string of 1 to 128 characters [A-Za-z0-9._:/(), -]' % key)
    return v


def check_keys(args, allowed):
    extra = sorted(set(args) - set(allowed))
    if extra:
        raise BadParams('unknown argument(s): %s' % ', '.join(extra))


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


class Fintech:
    def __init__(self, balance_cents, audit):
        self.balance = balance_cents
        self.audit = audit
        self.seq = 0
        self.payouts = []

    def record(self, tool, arguments, outcome, extra):
        self.seq += 1
        rec = {'seq': self.seq, 'tool': tool, 'arguments': arguments, 'outcome': outcome,
               'balance_after': cents_to_text(self.balance)}
        rec.update(extra)
        self.audit.line(dumps(rec))

    def call(self, name, args):
        """-> (structured result, is_error). BadParams -> -32602."""
        if name == 'issue_payout':
            check_keys(args, ('amount', 'invoice_id', 'vendor'))
            if 'amount' not in args:
                raise BadParams("missing argument 'amount'")
            cents = money_to_cents(args['amount'], 'amount')
            if cents <= 0:
                raise BadParams('amount must be > 0')
            invoice_id = name_arg(args, 'invoice_id')
            vendor = name_arg(args, 'vendor')
            shown = {'amount': cents_to_text(cents), 'invoice_id': invoice_id, 'vendor': vendor}
            if cents > self.balance:
                out = {'status': 'refused', 'reason': 'insufficient_funds', 'requested': cents_to_text(cents),
                       'balance': cents_to_text(self.balance)}
                self.record(name, shown, 'refused_insufficient_funds', {})
                return out, True
            self.balance -= cents
            payout_id = 'PAYOUT-%04d' % (len(self.payouts) + 1)
            self.payouts.append(payout_id)
            out = {'status': 'paid', 'payout_id': payout_id, 'amount': cents_to_text(cents),
                   'invoice_id': invoice_id, 'vendor': vendor, 'balance': cents_to_text(self.balance)}
            self.record(name, shown, 'paid', {'payout_id': payout_id})
            return out, False
        if name == 'get_balance':
            check_keys(args, ())
            out = {'balance': cents_to_text(self.balance), 'payouts': len(self.payouts)}
            self.record(name, {}, 'ok', {})
            return out, False
        if name == 'list_invoices':
            check_keys(args, ('org_id',))
            org = name_arg(args, 'org_id', required=False)
            rows = [dict(r) for r in INVOICES if org is None or r['org_id'] == org]
            self.record(name, {} if org is None else {'org_id': org}, 'ok', {'rows': len(rows)})
            out = {'invoices': rows}
            if org is not None:
                out['org_id'] = org  # every row belongs to the requested organisation (filtered above)
            return out, False
        raise BadParams('unknown tool %r' % name)


def dumps(obj):
    return json.dumps(obj, separators=(',', ':'), ensure_ascii=False, sort_keys=True).encode('utf-8')


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
        text = dumps(out).decode('utf-8')
        return answer(req_id, {'content': [{'type': 'text', 'text': text}], 'structuredContent': out,
                               'isError': is_error})
    return error(req_id, METHOD_NOT_FOUND, 'Method not found: %s' % method)


def parse_args(argv):
    opts = {'--balance': '1000.00', '--audit': None, '--wire-log': None}
    i = 0
    while i < len(argv):
        if argv[i] in opts and i + 1 < len(argv):
            opts[argv[i]] = argv[i + 1]
            i += 2
        else:
            sys.stderr.write('usage: fintech_server.py [--balance D] [--audit FILE] [--wire-log FILE]\n')
            raise SystemExit(2)
    try:
        balance = money_to_cents(opts['--balance'], '--balance')
    except BadParams as e:
        sys.stderr.write('fintech_server.py: %s\n' % e)
        raise SystemExit(2)
    return balance, opts['--audit'], opts['--wire-log']


def main():
    balance, audit_path, wire_path = parse_args(sys.argv[1:])
    app = Fintech(balance, AppendLog(audit_path))
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
