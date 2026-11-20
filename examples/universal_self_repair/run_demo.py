#!/usr/bin/env python3
"""universal_self_repair: propose -> dispose -> self-repair, over the REAL primitives engine v2 (primitives 6 to 9).

  python3 examples/universal_self_repair/run_demo.py [--engine PATH] [--scenario FILE] [--json OUT]
                                                     [--canary NAME] [--self-test]

SCRIPTED AGENT, NO MODEL. The "agent" is a fixed script: its first proposals come from the scenario, its repaired
proposals come from ONE small generic function, `repair(proposal, code, fields)`, that reads only the refusal's code
and its structured repair fields (the SDK's Refusal.code and Refusal.repair; never the human detail text, never the
answer line). No language model runs anywhere.

Labels: the engine (src/primitives_v2) is unproved Rust: every verdict is a NATIVE CHECK. This demo is a FINITE TEST:
one run of one scenario. Nothing here is proved. end_to_end=false.

Honesty rules kept here:
  * Every line marked `ENGINE` is the engine's own answer line (through sdk/py/forge_primitives.py; state hashes are
    shortened to 12 hex on screen, nothing else is changed). Lines marked `agent`, `repair` and `note` are the
    script's own text (theatre and explanation). Lines marked `DEMO CHECK` are Python checks in this script, NOT
    engine verdicts.
  * The engine owns the clock. On RATE_LIMIT_EXCEEDED / COOLDOWN_ACTIVE the agent really sleeps `retry_after_ms`
    and asks again; the production build is used, never the test-seams build (no fake time).
  * The final reconciliation is EXACT: the full WAL is read back with the engine's own `replay`, every key is read
    with `GET`, and both are compared with a ledger that this script built ONLY from the engine's COMMITTED answers
    (and its durable-refusal answers). Every record must be explained by exactly one answer.
  * "0 leaked secret bytes": the secrets are random per run; every byte that reached the sink and every byte of
    every engine answer (and of the replay output) is searched for each secret and for every 8-byte piece of it.
  * Each final check has a positive control (`--canary NAME`): a deliberately broken run that must make the named
    check FAIL (tests/primitives_v2/test_demo.py runs them).
Exit: 0 every check passed; 1 at least one check failed; 2 the engine is missing or the store could not be made;
3 the engine or the SDK raised a fault during the run (no result is claimed).
"""

import argparse
import copy
import hashlib
import itertools
import json
import os
from pathlib import Path
import re
import secrets
import shutil
import string
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'sdk' / 'py'))
import forge_primitives as fp  # noqa: E402

DEFAULT_ENGINE = ROOT / 'build' / 'primitives_v2' / 'primitives-engine'
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}
MAX_TURNS = 6
SECRET_ALPHABET = string.ascii_letters + string.digits
WINDOW = 8  # every 8-byte piece of a secret is searched

DEFAULT_SCENARIO = {
    'tenant': 'acme',
    'rate': {'key': 'api:acme', 'max_ops_per_window': 3, 'window_ms': 1000, 'cooldown_after': 2, 'cooldown_ms': 1000,
             'max_volume_per_window': 1000, 'volume': 1, 'burst': 4},
    'ledger': {'name': 'ops', 'max_balance': 100000,
               'open': {'acct:ops': 500, 'acct:payroll': 300, 'acct:vendor': 200},
               'bad_post': {'acct:ops': -120, 'acct:payroll': 70, 'acct:vendor': 60}},
    'graph': {'key': 'perm:graph', 'base': [['admin', 'editor'], ['editor', 'viewer'], ['viewer', 'guest']],
              'batch': [['editor', 'auditor'], ['guest', 'admin']]},
    'taint': {'destination': 'PUBLIC_HTTP',
              'fields': [{'path': '$.report.patient.diagnosis', 'labels': ['PHI']}, {'path': 'api_key', 'labels': ['SECRET_KEY']}],
              'document': {'report': {'title': 'weekly ops summary', 'patient': {'id': 'p-17', 'diagnosis': '<SECRET:phi>'},
                                      'integrations': [{'name': 'crm', 'api_key': '<SECRET:key>'}, {'name': 'mail'}]}}},
    'farkas': {'job': 'job-42',
               # x1 + x2 >= 8, -x1 >= -5, -x2 >= -4: feasible (x = (4, 4)); the lazy solver's y is NOT a certificate
               'false_claim': {'A': [[1, 1], [-1, 0], [0, -1]], 'b': [8, -5, -4], 'y': [1, 1, 0]},
               # x1 + x2 >= 10, -x1 >= -5, -x2 >= -4: infeasible; y = (1, 1, 1): y^T A = (0, 0), y^T b = 1
               'true_claim': {'A': [[1, 1], [-1, 0], [0, -1]], 'b': [10, -5, -4], 'y': [1, 1, 1]},
               'search_bound': 30},
}

CANARIES = {
    # name: (the check that must FAIL, what the canary does)
    'extra_record': ('records_equal_commit_answers', 'one extra transfer committed through the engine, not entered in the ledger'),
    'dropped_answer': ('records_equal_commit_answers', 'one COMMITTED answer removed from the trusted ledger'),
    'extra_edge': ('edges_equal_ledger', 'one extra graph edge committed through the engine, not entered in the ledger'),
    'extra_claim': ('registry_equal_ledger', 'one extra registry claim committed through the engine, not entered in the ledger'),
    'extra_acquire': ('rate_equal_ledger', 'one extra rate acquire committed through the engine, not entered in the ledger'),
    'balance_tamper': ('balances_equal_ledger', 'the trusted ledger balance of one account changed by +1'),
    'secret_in_sink': ('zero_secret_bytes_in_sink', 'the raw secret value written to the sink'),
    'blocked_doc_in_sink': ('blocked_documents_never_in_sink', 'a blocked document written to the sink'),
    'secret_in_answer': ('zero_secret_bytes_in_engine_output', 'a request whose key holds the secret: the engine echoes the key in RESERVED_KEY'),
    'bad_schedule': ('schedule_satisfies_system', 'the submitted schedule replaced by all zeros before the demo check'),
    'dropped_refusal': ('refusal_records_equal_durable_refusals', 'one durable refusal answer removed from the trusted ledger'),
    'weak_true_cert': ('true_infeasibility_proved', 'the certificate of the true claim replaced by y = 0 (y^T b = 0)'),
    'no_mistake': ('mistakes_refused', 'the rate burst shortened to the window limit, so the first proposal is not a mistake'),
}


class Fatal(Exception):
    """The run cannot give a result (engine missing, init failed, engine fault)."""

    def __init__(self, exit_code, msg):
        super().__init__(msg)
        self.exit_code = exit_code


# ------------------------------------------------------------------------------------------------ screen

class Screen:
    def __init__(self, quiet=False):
        self.quiet, self.lines = quiet, []

    def out(self, tag, text):
        line = '%-10s %s' % (tag, text)
        self.lines.append(line)
        if not self.quiet:
            print(line, flush=True)

    def raw(self, text=''):
        self.lines.append(text)
        if not self.quiet:
            print(text, flush=True)


def short(line):
    """An engine answer line with 64-hex state hashes cut to 12 hex (screen only)."""
    return re.sub(r'(?<![0-9a-f])([0-9a-f]{12})[0-9a-f]{52}(?![0-9a-f])', r'\1..', line)


# ------------------------------------------------------------------------------------------------ the generic repair

def normalize_key(k):
    """PROTOCOL.md section 12.1: fullwidth ASCII -> ASCII; drop `_`, `-`, space; ASCII A-Z -> a-z."""
    out = []
    for ch in k:
        o = ord(ch)
        if 0xFF01 <= o <= 0xFF5E:
            ch = chr(o - 0xFEE0)
        if ch in '_- ':
            continue
        out.append(ch.lower() if 'A' <= ch <= 'Z' else ch)
    return ''.join(out)


PATH_STEP = re.compile(r'\.~(\d+)|\.([^.\[\]@~][^.\[\]@]*)|\[(\d+)\]|@')


def parse_json_path(p):
    """`$` then `.~<i>` | `.<name>` | `[<i>]` | `@` (PROTOCOL.md section 12.4). None if the path breaks the grammar."""
    if not p.startswith('$'):
        return None
    steps, i = [], 1
    while i < len(p):
        m = PATH_STEP.match(p, i)
        if m is None:
            return None
        if m.group(1) is not None:
            steps.append(('rank', int(m.group(1))))
        elif m.group(2) is not None:
            steps.append(('name', m.group(2)))
        elif m.group(3) is not None:
            steps.append(('index', int(m.group(3))))
        else:
            steps.append(('json', None))
        i = m.end()
    return steps


def _child(node, step):
    kind, v = step
    if kind == 'index':
        if not isinstance(node, list) or v >= len(node):
            raise ValueError('index step on a non-array or out of range')
        return v
    if not isinstance(node, dict):
        raise ValueError('key step on a non-object')
    if kind == 'rank':
        keys = sorted(node, key=lambda k: k.encode('utf-8'))
        if v >= len(keys):
            raise ValueError('rank out of range')
        return keys[v]
    hits = [k for k in node if normalize_key(k) == v]
    if len(hits) != 1:
        raise ValueError('name step matches %d keys' % len(hits))
    return hits[0]


def remove_path(node, steps):
    """A copy of `node` with exactly the node at `steps` removed. A trailing `@` (the parsed root of a JSON string)
    removes the string itself."""
    while steps and steps[-1][0] == 'json':
        steps = steps[:-1]
    if not steps:
        raise ValueError('the path names the whole document')
    node = copy.deepcopy(node)
    if steps[0][0] == 'json':
        if not isinstance(node, str):
            raise ValueError('@ step on a non-string')
        inner = remove_path(json.loads(node), steps[1:])
        return json.dumps(inner, ensure_ascii=True, separators=(',', ':'))
    c = _child(node, steps[0])
    if len(steps) == 1:
        del node[c]
    else:
        node[c] = remove_path(node[c], steps[1:])
    return node


def repair(proposal, code, fields):
    """THE generic repair step of the scripted agent. Input: its own last proposal, the refusal's code and the
    refusal's structured fields (dict of decoded key=value; Refusal.repair). Output: dict with `action` in
    {'retry', 'give_up'}, the next `proposal`, `wait_ms` (sleep before the retry) and `why` (screen text).
    Nothing scenario-specific is in here."""
    kind = proposal['kind']
    if code in ('RATE_LIMIT_EXCEEDED', 'COOLDOWN_ACTIVE', 'STORE_BUSY'):
        ms = fields.get('retry_after_ms', '')
        if not ms.isdigit():
            return {'action': 'give_up', 'why': '%s retry_after_ms=%s: no finite wait' % (code, ms or '(none)')}
        return {'action': 'retry', 'proposal': proposal, 'wait_ms': int(ms),
                'why': 'wait retry_after_ms (from %s), then send the same proposal with a new request id' % code}
    if code == 'STALE_STATE_HASH':
        return {'action': 'retry', 'proposal': proposal, 'wait_ms': 0, 'why': 're-read the state hashes and send again'}
    if code == 'CONSERVATION_BREACH' and kind == 'post':
        debit, credit = int(fields['debit_total']), int(fields['credit_total'])
        if debit == credit:
            return {'action': 'give_up', 'why': 'CONSERVATION_BREACH with equal totals: nothing to repair'}
        excess, side = abs(credit - debit), (1 if credit > debit else -1)
        legs = dict(proposal['legs'])
        # cut the larger side by the excess, starting at the last leg in key order; a leg cut to 0 is dropped
        # (a zero leg is refused: ZERO_AMOUNT). Cutting the larger side never adds a debit: no new overdraft.
        for k in sorted(legs, reverse=True):
            if excess == 0:
                break
            if (legs[k] > 0) != (side > 0):
                continue
            cut = min(excess, abs(legs[k]))
            legs[k] -= side * cut
            excess -= cut
            if legs[k] == 0:
                del legs[k]
        if excess:
            return {'action': 'give_up', 'why': 'the larger side is smaller than the excess'}
        return {'action': 'retry', 'proposal': dict(proposal, legs=legs), 'wait_ms': 0,
                'why': 'cut the %s side by |credit_total - debit_total| = %d (from the refusal fields)'
                       % ('credit' if side > 0 else 'debit', abs(credit - debit))}
    if code == 'DAG_CYCLE_DETECTED' and kind == 'add_edges':
        i = int(fields['index'])
        edges = [list(e) for e in proposal['edges']]
        if i >= len(edges) or '%s->%s' % tuple(edges[i]) != fields.get('edge'):
            return {'action': 'give_up', 'why': 'edge=/index= do not name an edge of my batch'}
        del edges[i]
        if not edges:
            return {'action': 'give_up', 'why': 'the batch held only the cycle edge: nothing left to add'}
        return {'action': 'retry', 'proposal': dict(proposal, edges=edges), 'wait_ms': 0,
                'why': 'drop exactly edge %s (index %d) from the batch; send the rest' % (fields['edge'], i)}
    if code == 'TAINT_EGRESS_BLOCKED' and kind == 'send':
        steps = parse_json_path(fields.get('json_path', ''))
        if steps is None:
            return {'action': 'give_up', 'why': 'json_path breaks the grammar'}
        try:
            doc = remove_path(proposal['document'], steps)
        except (ValueError, KeyError, IndexError, json.JSONDecodeError) as e:
            return {'action': 'give_up', 'why': 'json_path %s cannot be removed (%s)' % (fields.get('json_path'), e)}
        return {'action': 'retry', 'proposal': dict(proposal, document=doc), 'wait_ms': 0,
                'why': 'remove exactly json_path=%s (label=%s) and send again' % (fields['json_path'], fields.get('label'))}
    if kind == 'infeasible' and fields.get('claim') == 'INFEASIBILITY_NOT_PROVED':
        return {'action': 'retry', 'wait_ms': 0,
                'proposal': {'kind': 'schedule', 'A': proposal['A'], 'b': proposal['b'], 'job': proposal['job'],
                             'search_bound': proposal['search_bound']},
                'why': 'claim=INFEASIBILITY_NOT_PROVED (%s): withdraw the claim; find a schedule and accept the job' % code}
    return {'action': 'give_up', 'why': 'no repair rule for %s' % code}


# ------------------------------------------------------------------------------------------------ helpers

def make_secret():
    return 'Zq' + ''.join(secrets.choice(SECRET_ALPHABET) for _ in range(22))


def fill_secrets(node, secret_map):
    if isinstance(node, dict):
        return {k: fill_secrets(v, secret_map) for k, v in node.items()}
    if isinstance(node, list):
        return [fill_secrets(v, secret_map) for v in node]
    if isinstance(node, str):  # also inside a string that holds JSON text
        def sub(m):
            if m.group(1) not in secret_map:
                secret_map[m.group(1)] = make_secret()
            return secret_map[m.group(1)]
        return re.sub(r'<SECRET:([a-z0-9_]+)>', sub, node)
    return node


def shape(node, path='$'):
    """The leaf paths of a document, without values (safe for the screen and the results file)."""
    if isinstance(node, dict):
        out = []
        for k in node:
            out += shape(node[k], '%s.%s' % (path, k))
        return out or [path + '{}']
    if isinstance(node, list):
        out = []
        for i, v in enumerate(node):
            out += shape(v, '%s[%d]' % (path, i))
        return out or [path + '[]']
    return [path]


def doc_text(doc):
    return json.dumps(doc, ensure_ascii=True, separators=(',', ':'))


def leak_bytes(hay, secret_values):
    """Bytes of `hay` covered by a full secret or by any WINDOW-byte piece of a secret."""
    covered = set()
    for s in secret_values:
        sb = s.encode()
        pieces = {sb[i:i + WINDOW] for i in range(0, len(sb) - WINDOW + 1)} or {sb}
        for piece in pieces:
            start = hay.find(piece)
            while start >= 0:
                covered.update(range(start, start + len(piece)))
                start = hay.find(piece, start + 1)
    return len(covered)


def merge_scenario(base, over):
    out = copy.deepcopy(base)
    for k, v in over.items():
        out[k] = copy.deepcopy(v)
    return out


def summary(p):
    k = p['kind']
    if k == 'acquire':
        return 'acquire x%d on %s (volume %d each)' % (p['count'], p['key'], p['volume'])
    if k == 'open':
        return 'open accounts %s' % ', '.join('%s=%d' % kv for kv in sorted(p['balances'].items()))
    if k == 'post':
        return 'post legs %s' % ' '.join('%s:%+d' % kv for kv in sorted(p['legs'].items()))
    if k == 'add_edges':
        return 'add edges %s' % ' '.join('%s->%s' % tuple(e) for e in p['edges'])
    if k == 'send':
        return 'send a document to %s; fields (values not shown): %s' % (p['destination'], ' '.join(shape(p['document'])))
    if k == 'infeasible':
        return 'claim "no schedule exists" for A=%s b=%s with certificate y=%s' % (p['A'], p['b'], p['y'])
    if k == 'schedule':
        return 'solve A x >= b, x >= 0 (scripted search, bound %d) and accept %s' % (p['search_bound'], p['job'])
    return k


# ------------------------------------------------------------------------------------------------ the run

class Run:
    def __init__(self, engine, scenario, screen, canary=None):
        self.engine, self.sc, self.scr, self.canary = engine, scenario, screen, canary
        self.tenant = scenario['tenant']
        self.secrets = {}
        self.commits = []        # trusted ledger: every COMMITTED answer, in order
        self.durable = []        # every durable refusal answer (a record was written)
        self.answers = []        # every engine answer line (leak scan)
        self.sink = None         # path of the sink file
        self.sent_ok = []        # (sha256, bytes) of every ALLOWed document emitted
        self.allowed_docs = []   # the texts emitted (for the tests; they hold no secret when the checks pass)
        self.blocked = []        # exact texts of every blocked document
        self.turns = []          # deterministic turn log
        self.measured_turns = []
        self.tasks = []          # per task: name, mistake, first code, final code, turns
        self.schedule = None
        self.true_verdict = None
        self.canary_applied = None
        self.waits = []
        self.lat = []
        self.rid_n = 0

    # -- engine access
    def rid(self):
        self.rid_n += 1
        return 'q%03d' % self.rid_n

    def note_answer(self, prim, op, keys, r, t0):
        self.lat.append(time.monotonic() - t0)
        line = getattr(r, 'line', None)
        if line:
            self.answers.append(line)
        if isinstance(r, fp.Committed):
            self.commits.append({'seq': r.seq, 'request_id': r.request_id, 'primitive': prim, 'op': op, 'tenant': self.tenant,
                                 'keys': sorted(r.hashes), 'effect': r.effect, 'now_ms': r.now_ms, 'hash': next(iter(r.hashes.values()))})
        elif isinstance(r, fp.Refusal) and r.durable:
            self.durable.append({'seq': r.seq, 'request_id': r.request_id, 'primitive': prim, 'op': op, 'tenant': self.tenant,
                                 'keys': sorted(r.hashes), 'code': r.code, 'now_ms': r.now_ms, 'hash': next(iter(r.hashes.values()))})
        return r

    def call(self, prim, op, keys, fn):
        t0 = time.monotonic()
        return self.note_answer(prim, op, keys, fn(), t0)

    # -- one proposal -> one outcome. Returns (result, rest): rest is the part of the proposal still to do.
    def execute(self, p):
        c, t = self.c, self.tenant
        k = p['kind']
        if k == 'acquire':
            for i in range(p['count']):
                r = self.call('rate_window', 'acquire', [p['key']],
                              lambda: c.acquire(t, p['key'], p['policy'], p['volume'], request_id=self.rid()))
                self.scr.out('ENGINE', short(r.line))
                if not isinstance(r, fp.Committed):
                    return r, dict(p, count=p['count'] - i)
            return r, None
        if k == 'open':
            r = self.call('ledger_graph', 'open', list(p['balances']),
                          lambda: c.open_accounts(t, p['ledger'], p['balances'], request_id=self.rid()))
        elif k == 'post':
            r = self.call('ledger_graph', 'post', list(p['legs']), lambda: c.post(t, p['ledger'], p['legs'], request_id=self.rid()))
        elif k == 'add_edges':
            r = self.call('ledger_graph', 'add_edge', [p['key']],
                          lambda: c.add_edges(t, p['key'], p['policy'], [tuple(e) for e in p['edges']], request_id=self.rid()))
        elif k == 'send':
            text = doc_text(p['document'])
            r = self.call('taint_egress', 'check', [], lambda: c.taint_check(t, 'egress', p['destination'], text, request_id=self.rid()))
            if isinstance(r, fp.Verdict) and r.verdict == 'ALLOW':
                self.emit(r.document)  # .document: the exact bytes the engine checked (the SDK checked sha256 and bytes)
            else:
                self.blocked.append(text)
        elif k == 'infeasible':
            r = self.call('farkas', 'check', [], lambda: c.farkas_check(t, p['A'], p['b'], p['y'], request_id=self.rid()))
        elif k == 'schedule':
            x = self.solve(p['A'], p['b'], p['search_bound'])
            self.scr.out('agent', 'scripted search found x = %s' % (x,) if x is not None else 'scripted search found no x within the bound')
            if x is None:
                return None, None
            if self.canary == 'bad_schedule':
                x = [0] * len(x)
                self.canary_applied = 'schedule replaced by %s' % (x,)
            ok = all(sum(a * xi for a, xi in zip(row, x)) >= bi for row, bi in zip(p['A'], p['b'])) and all(xi >= 0 for xi in x)
            self.schedule = {'x': x, 'A': p['A'], 'b': p['b'], 'ok': ok}
            self.scr.out('DEMO CHECK', 'A x >= b and x >= 0 for x = %s: %s (Python check in this script, not the engine)' % (x, ok))
            if not ok:
                return None, None
            r = self.call('ledger_graph', 'claim', ['reg:' + t], lambda: c.claim(t, 'jobs', p['job'], request_id=self.rid()))
        else:
            raise Fatal(3, 'unknown proposal kind %s' % k)
        self.scr.out('ENGINE', short(r.line))
        return r, None

    @staticmethod
    def solve(A, b, bound):
        n = len(A[0])
        if n > 3 or bound > 40:
            return None  # the scripted solver is a small brute force; larger systems are out of scope
        for x in itertools.product(range(bound + 1), repeat=n):
            if all(sum(a * xi for a, xi in zip(row, x)) >= bi for row, bi in zip(A, b)):
                return list(x)
        return None

    def emit(self, text):
        """The ONLY writer of the sink. Called only after `OK verdict=ALLOW` for exactly these bytes."""
        raw = text.encode('ascii')
        with open(self.sink, 'ab') as f:
            f.write(raw + b'\n')
        self.sent_ok.append((hashlib.sha256(raw).hexdigest(), len(raw)))
        self.allowed_docs.append(text)

    @staticmethod
    def success(r, p):
        if isinstance(r, fp.Committed):
            return True
        return isinstance(r, fp.Verdict) and ((p['kind'] == 'send' and r.verdict == 'ALLOW') or
                                              (p['kind'] == 'infeasible' and r.verdict == 'INFEASIBILITY_PROVED'))

    def task(self, name, proposal, mistake, expect_first):
        self.scr.raw()
        self.scr.out('task', '%s%s' % (name, ' (the agent makes a mistake here)' if mistake else ''))
        rec = {'task': name, 'mistake': mistake, 'expect_first': expect_first, 'first': None, 'final': None, 'turns': 0, 'ok': False}
        p = proposal
        for turn in range(1, MAX_TURNS + 1):
            rec['turns'] = turn
            self.scr.out('agent', 'turn %d: %s' % (turn, summary(p)))
            r, rest = self.execute(p)
            code = None if r is None else (r.verdict if isinstance(r, fp.Verdict) else r.code)
            fields = {} if r is None else (r.fields if isinstance(r, fp.Verdict) else (r.repair if isinstance(r, fp.Refusal) else {'seq': str(r.seq), 'effect': r.effect}))
            if rec['first'] is None:
                rec['first'] = code
            rec['final'] = code
            det = {'task': name, 'turn': turn, 'proposal': summary(p), 'answer': code,
                   'fields': {k: v for k, v in sorted(fields.items()) if k not in ('retry_after_ms', 'sha256_doc')}}
            self.turns.append(det)
            if r is None:
                self.scr.out('note', 'no proposal could be sent; the task stops')
                break
            if self.success(r, p):
                rec['ok'] = True
                break
            if not isinstance(r, fp.Refusal):
                self.scr.out('note', 'answer %s is not a refusal and not the wanted success; the task stops' % code)
                break
            # the repair reads ONLY the code and the structured fields
            rep = repair(rest or p, r.code, dict(r.repair))
            det['repair'] = rep['why'] if rep['action'] == 'retry' and not rep.get('wait_ms') else rep['action']
            self.scr.out('repair', rep['why'])
            if rep['action'] != 'retry':
                break
            if rep['wait_ms']:
                t0 = time.monotonic()
                time.sleep(rep['wait_ms'] / 1000.0)
                self.waits.append({'asked_ms': rep['wait_ms'], 'slept_ms': round((time.monotonic() - t0) * 1000, 1)})
                self.scr.out('note', 'slept %d ms (retry_after_ms of the engine; real time, the engine owns the clock)' % rep['wait_ms'])
            p = rep['proposal']
        self.tasks.append(rec)
        return rec

    # -- setup
    def policies(self, d):
        sc = self.sc
        rt, lg, gr, tn = sc['rate'], sc['ledger'], sc['graph'], sc['taint']
        pol = {
            'rate.json': {'primitive': 'rate_window', 'version': 1, 'name': 'api', 'max_ops_per_window': str(rt['max_ops_per_window']),
                          'max_volume_per_window': str(rt['max_volume_per_window']), 'window_ms': str(rt['window_ms']),
                          'cooldown_after': str(rt['cooldown_after']), 'cooldown_ms': str(rt['cooldown_ms'])},
            'ledger.json': {'primitive': 'ledger_graph', 'version': 1, 'name': lg['name'], 'kind': 'ledger', 'issuance': 'fixed',
                            'max_balance': str(lg['max_balance']), 'max_legs': '16'},
            'graph.json': {'primitive': 'ledger_graph', 'version': 1, 'name': 'perms', 'kind': 'graph', 'max_nodes': '1000', 'max_edges': '4000'},
            'jobs.json': {'primitive': 'ledger_graph', 'version': 1, 'name': 'jobs', 'kind': 'registry', 'case': 'exact', 'max_name_bytes': '64'},
            'egress.json': {'primitive': 'taint_egress', 'version': 1, 'name': 'egress', 'mode': 'detect', 'labels': [], 'fields': tn['fields'],
                            'destinations': {tn['destination']: [], 'INTERNAL_AUDIT': ['PII', 'PHI', 'SECRET_KEY']}},
        }
        args = []
        for fname, body in pol.items():
            (d / fname).write_text(json.dumps(body))
            args += ['--policy', str(d / fname)]
        return args

    def run(self):
        work = Path(tempfile.mkdtemp(prefix='self-repair-'))
        os.chmod(work, 0o700)
        self.work = work
        try:
            return self._run(work)
        finally:
            shutil.rmtree(work, ignore_errors=True)

    def _run(self, work):
        sc, scr = self.sc, self.scr
        st = work / 'store'
        args = [str(self.engine), 'init', str(st)] + self.policies(work)
        try:
            p = subprocess.run(args, capture_output=True, text=True, env=ENV, timeout=300)
        except OSError as e:
            raise Fatal(2, 'ENGINE CANNOT START: %s (%s); no demo output was produced' % (self.engine, e))
        if p.returncode != 0 or not p.stdout.startswith('INITIALIZED'):
            raise Fatal(2, 'ENGINE INIT FAILED (exit %d): %s' % (p.returncode, (p.stdout + p.stderr).strip()[:300]))
        self.answers.append(p.stdout.strip())
        scr.out('ENGINE', short(p.stdout.strip()))
        self.sink = work / ('sink-%s.bin' % sc['taint']['destination'])
        self.sink.write_bytes(b'')
        t = self.tenant
        rt, lg, gr, tn, fk = sc['rate'], sc['ledger'], sc['graph'], sc['taint'], sc['farkas']
        document = fill_secrets(tn['document'], self.secrets)
        if not self.secrets:
            raise Fatal(3, 'the scenario document holds no <SECRET:...> placeholder')
        t_start = time.monotonic()
        with fp.Primitives(st, engine=self.engine) as c:
            self.c = c
            # 1. rate burst
            burst = rt['burst']
            if self.canary == 'no_mistake':
                burst, self.canary_applied = rt['max_ops_per_window'], 'burst %d -> %d' % (rt['burst'], rt['max_ops_per_window'])
            self.task('rate burst', {'kind': 'acquire', 'key': rt['key'], 'policy': 'api', 'volume': rt['volume'], 'count': burst},
                      True, 'RATE_LIMIT_EXCEEDED')
            # 2a. double entry
            self.task('open the ledger', {'kind': 'open', 'ledger': lg['name'], 'balances': lg['open']}, False, 'COMMITTED')
            self.task('unbalanced posting', {'kind': 'post', 'ledger': lg['name'], 'legs': lg['bad_post']}, True, 'CONSERVATION_BREACH')
            # 2b. permission DAG
            self.task('base permission edges', {'kind': 'add_edges', 'key': gr['key'], 'policy': 'perms', 'edges': gr['base']}, False, 'COMMITTED')
            self.task('edge batch that closes a cycle', {'kind': 'add_edges', 'key': gr['key'], 'policy': 'perms', 'edges': gr['batch']},
                      True, 'DAG_CYCLE_DETECTED')
            # 3. nested taint
            self.task('outbound document with a nested tainted field',
                      {'kind': 'send', 'destination': tn['destination'], 'document': document}, True, 'TAINT_EGRESS_BLOCKED')
            # 4. false and true infeasibility claims
            fc, tc = fk['false_claim'], dict(fk['true_claim'])
            if self.canary == 'weak_true_cert':
                tc['y'], self.canary_applied = [0] * len(tc['y']), 'true-claim y -> 0'
            self.task('false "no schedule exists" claim', {'kind': 'infeasible', 'A': fc['A'], 'b': fc['b'], 'y': fc['y'], 'job': fk['job'],
                                                            'search_bound': fk['search_bound']}, True, 'CERT_REJECTED')
            rec = self.task('true "no schedule exists" claim', {'kind': 'infeasible', 'A': tc['A'], 'b': tc['b'], 'y': tc['y'], 'job': fk['job'] + '-b',
                                                                 'search_bound': fk['search_bound']}, False, 'INFEASIBILITY_PROVED')
            self.true_verdict = rec['final']
            if rec['final'] == 'INFEASIBILITY_PROVED':
                scr.out('note', 'INFEASIBILITY_PROVED is the engine\'s word: a NATIVE CHECK (unproved Rust) of the certificate, '
                                'scope=nonneg_integer_x; the agent declines that job. Not a proof of this run.')
            run_s = time.monotonic() - t_start
            self.apply_canary(c, work)
            scr.raw()
            scr.out('note', 'reconciliation: read the whole store back (engine `replay` and `GET` of every key)')
            store = self.read_store(c, st)
        return self.checks(store, run_s)

    def apply_canary(self, c, work):
        k, t = self.canary, self.tenant
        if k in (None, 'bad_schedule', 'weak_true_cert', 'no_mistake'):
            return
        self.scr.raw()
        self.scr.out('CANARY', '%s: %s (a deliberately broken run; the check %s must FAIL)' % (k, CANARIES[k][1], CANARIES[k][0]))
        ok = None
        lg = self.sc['ledger']
        accts = sorted(lg['open'])
        if k == 'extra_record':
            r = c.transfer(t, lg['name'], accts[0], accts[1], 1, request_id='canary1')
            ok = isinstance(r, fp.Committed)
        elif k == 'extra_edge':
            r = c.add_edges(t, self.sc['graph']['key'], 'perms', [('canaryA', 'canaryB')], request_id='canary1')
            ok = isinstance(r, fp.Committed)
        elif k == 'extra_claim':
            r = c.claim(t, 'jobs', 'canary-claim', request_id='canary1')
            ok = isinstance(r, fp.Committed)
        elif k == 'extra_acquire':
            r = c.acquire(t, 'api:canary', 'api', 1, request_id='canary1')
            ok = isinstance(r, fp.Committed)
        elif k == 'dropped_refusal':
            r, ok = None, bool(self.durable) and bool(self.durable.pop())
        elif k == 'dropped_answer':
            r = self.commits.pop()
            ok = True
        elif k == 'balance_tamper':
            ok = True  # applied in the model (see model())
            r = None
        elif k == 'secret_in_sink':
            with open(self.sink, 'ab') as f:
                f.write(next(iter(self.secrets.values())).encode() + b'\n')
            ok, r = True, None
        elif k == 'blocked_doc_in_sink':
            if self.blocked:
                with open(self.sink, 'ab') as f:
                    f.write(self.blocked[0].encode() + b'\n')
                ok = True
            r = None
        elif k == 'secret_in_answer':
            r = c.acquire(t, 'reg:' + next(iter(self.secrets.values())), 'api', 1, request_id='canary1')
            self.answers.append(r.line)
            ok = isinstance(r, fp.Refusal)
        line = getattr(r, 'line', None)
        if line:
            self.scr.out('ENGINE', short(line))
        self.canary_applied = bool(ok)

    # -- reconciliation
    def read_store(self, c, st):
        p = subprocess.run([str(self.engine), 'replay', str(st)], capture_output=True, text=True, env=ENV, timeout=300)
        if p.returncode != 0:
            raise Fatal(3, 'replay failed (exit %d): %s' % (p.returncode, (p.stdout + p.stderr)[:300]))
        lines = p.stdout.splitlines()
        self.answers.extend(lines)
        m = re.fullmatch(r'REPLAY records=(\d+)', lines[0])
        if not m or int(m.group(1)) != len(lines) - 1:
            raise Fatal(3, 'replay output breaks its grammar')
        recs = []
        for ln in lines[1:]:
            mm = re.fullmatch(r'RECORD (\d+) (\d+) (\d+) (.*)', ln)
            if not mm:
                raise Fatal(3, 'replay line breaks its grammar')
            seq, now_ms, payload = int(mm.group(1)), int(mm.group(2)), mm.group(4)
            if payload.startswith('G '):
                recs.append({'seq': seq, 'kind': 'G'})
                continue
            head, _, mod = payload.partition(' |')
            h = head.split(' ')
            n = int(h[6])
            recs.append({'seq': seq, 'now_ms': now_ms, 'primitive': h[1], 'op': h[2], 'request_id': h[3], 'tenant': h[4], 'kind': h[5],
                         'keys': h[7:7 + n], 'payload': mod[1:] if mod.startswith(' ') else mod})
        self._records = recs
        keys = sorted({k for r in recs for k in r.get('keys', [])} | {k for a in self.commits for k in a['keys']})
        gets = {}
        for k in keys:
            g = c.get(self.tenant, k)
            self.answers.append(g.line)
            gets[k] = g
        state = c.state()
        return {'records': recs, 'gets': gets, 'state': state}

    def model(self):
        """The trusted ledger: built ONLY from the COMMITTED answers (and durable-refusal answers for the rate count)."""
        bal, edges, names, rate = {}, {}, {}, {}
        for a in self.commits:
            e = a['effect'].split(' ')
            op = a['op']
            if op == 'open':
                for k, v in zip(a['keys'], e[1:]):
                    bal[k] = int(v)
            elif op == 'post':
                for k, v in zip(a['keys'], e[1:]):
                    bal[k] = bal.get(k, 0) + int(v)
            elif op == 'transfer':
                bal[e[1]] -= int(e[3])
                bal[e[2]] = bal.get(e[2], 0) + int(e[3])
            elif op == 'add_edge':
                s = edges.setdefault(a['keys'][0], set())
                for i in range(1, len(e), 2):
                    s.add((e[i], e[i + 1]))
            elif op == 'remove_edge':
                edges.setdefault(a['keys'][0], set()).discard((e[1], e[2]))
            elif op == 'claim':
                names[(e[0], ' '.join(e[1:]))] = a['keys'][0]
            elif op == 'release':
                names.pop((e[0], ' '.join(e[1:])), None)
            elif op == 'acquire':
                rate.setdefault(a['keys'][0], []).append(('C', a['seq'], a['now_ms'], int(e[2])))
        for d in self.durable:
            if d['op'] == 'acquire':
                rate.setdefault(d['keys'][0], []).append(('R', d['seq'], d['now_ms'], 0))
        if self.canary == 'balance_tamper' and bal:
            bal[sorted(bal)[0]] += 1
        return bal, edges, names, rate

    def checks(self, store, run_s):
        sc = self.sc
        recs, gets = store['records'], store['gets']
        bal, edges, names, rate = self.model()
        res = []

        def check(name, ok, evidence):
            res.append({'check': name, 'ok': bool(ok), 'evidence': evidence})

        mistakes = [t for t in self.tasks if t['mistake']]
        check('mistakes_refused', mistakes and all(t['first'] == t['expect_first'] for t in mistakes),
              '; '.join('%s: %s' % (t['task'], t['first']) for t in mistakes))
        check('repairs_accepted', all(t['ok'] for t in self.tasks),
              '; '.join('%s: %s after %d turn(s)' % (t['task'], t['final'], t['turns']) for t in self.tasks))
        check('true_infeasibility_proved', self.true_verdict == 'INFEASIBILITY_PROVED', 'engine verdict %s' % self.true_verdict)
        check('schedule_satisfies_system', bool(self.schedule and self.schedule['ok']),
              'DEMO CHECK (Python): x=%s' % (self.schedule['x'] if self.schedule else None))
        # records vs answers
        crec = [r for r in recs if r['kind'] == 'C']
        rrec = [r for r in recs if r['kind'] == 'R']
        tup = lambda r: (r['seq'], r['request_id'], r['primitive'], r['op'], r['tenant'], tuple(r['keys']))  # noqa: E731
        c_store = sorted(tup(r) + (r['payload'],) for r in crec)
        c_ans = sorted(tup(a) + (a['effect'],) for a in self.commits)
        check('records_equal_commit_answers', c_store == c_ans,
              '%d committed records in the store, %d COMMITTED answers; identical (seq, id, op, keys, effect): %s'
              % (len(crec), len(self.commits), c_store == c_ans))
        r_store = sorted(tup(r) for r in rrec)
        r_ans = sorted(tup(d) for d in self.durable)
        check('refusal_records_equal_durable_refusals', r_store == r_ans,
              '%d refusal records in the store, %d durable refusal answers' % (len(rrec), len(self.durable)))
        explained = {a['seq'] for a in self.commits} | {d['seq'] for d in self.durable}
        stored = {r['seq'] for r in recs if r['kind'] != 'G'}
        top = int(store['state']['seq'])
        check('every_record_explained', explained == stored and top == max(stored | {0}) and len(recs) == top + 1,
              'STATE seq=%s; %d records after genesis; unexplained=%s; missing=%s'
              % (top, len(stored), sorted(stored - explained), sorted(explained - stored)))
        # balances and supply
        lg = sc['ledger']
        accts = {k: g for k, g in gets.items() if g.exists and g.fields.get('kind') == 'account'}
        got_bal = {k: int(g.fields['balance']) for k, g in accts.items()}
        check('balances_equal_ledger', got_bal == bal, 'store %s; ledger %s' % (sorted(got_bal.items()), sorted(bal.items())))
        supply = sum(lg['open'].values())
        totals = {(g.fields['ledger_total'], g.fields['ledger_issued'], g.fields['ledger_destroyed']) for g in accts.values()}
        check('total_supply_constant', sum(got_bal.values()) == supply == sum(bal.values()) and totals == {(str(supply), str(supply), '0')},
              'opening supply %d; sum store %d; sum ledger %d; engine (total, issued, destroyed) %s'
              % (supply, sum(got_bal.values()), sum(bal.values()), sorted(totals)))
        # edges
        st_edges = {}
        for r in crec:
            if r['primitive'] == 'ledger_graph' and r['op'] in ('add_edge', 'remove_edge'):
                e = r['payload'].split(' ')
                s = st_edges.setdefault(r['keys'][0], set())
                for i in range(1, len(e), 2):
                    (s.add if r['op'] == 'add_edge' else s.discard)((e[i], e[i + 1]))
        gk = {k: g for k, g in gets.items() if g.exists and g.fields.get('kind') == 'graph'}
        counts_ok = all(int(g.fields['edges']) == len(edges.get(k, ())) and
                        int(g.fields['nodes']) == len({n for e in edges.get(k, ()) for n in e}) for k, g in gk.items())
        check('edges_equal_ledger', st_edges == edges and set(gk) == set(edges) and counts_ok,
              'store edges %s; ledger edges %s; GET nodes/edges match: %s'
              % ({k: len(v) for k, v in st_edges.items()}, {k: len(v) for k, v in edges.items()}, counts_ok))
        # registry
        st_names = {}
        for r in crec:
            if r['op'] in ('claim', 'release'):
                e = r['payload'].split(' ')
                if r['op'] == 'claim':
                    st_names[(e[0], ' '.join(e[1:]))] = r['keys'][0]
                else:
                    st_names.pop((e[0], ' '.join(e[1:])), None)
        rk = {k: g for k, g in gets.items() if g.exists and g.fields.get('kind') == 'registry'}
        claims_ok = all(int(g.fields['claims']) == sum(1 for h in names.values() if h == k) for k, g in rk.items())
        check('registry_equal_ledger', st_names == names and claims_ok,
              'store names %s; ledger names %s; GET claims match: %s' % (sorted(st_names), sorted(names), claims_ok))
        # rate counters as far as GET exposes them (ops, volume, rejections)
        rt = sc['rate']
        w, cool_after = rt['window_ms'], rt['cooldown_after']
        rate_rows, rate_ok = [], True
        rkeys = {k for k, g in gets.items() if g.exists and g.primitive == 'rate_window'}
        for k in sorted(rkeys | set(rate)):
            g = gets.get(k)
            if g is None or not g.exists:
                rate_ok = False
                continue
            ev = sorted(rate.get(k, []), key=lambda x: x[1])
            now = g.now_ms
            live = [x for x in ev if x[0] == 'C' and now < x[2] + w]
            rej = 0
            for x in ev:
                rej = 0 if x[0] == 'C' else rej + 1
                if cool_after and rej == cool_after:
                    rej = 0
            want = (len(live), sum(x[3] for x in live), rej)
            have = (int(g.fields.get('ops', -1)), int(g.fields.get('volume', -1)), int(g.fields.get('rejections', -1)))
            rate_rows.append('%s ledger(ops,volume,rejections)=%s store=%s' % (k, want, have))
            rate_ok = rate_ok and want == have
        check('rate_equal_ledger', rate_ok and bool(rate_rows), '; '.join(rate_rows) + ' (at the GET answer\'s now_ms)')
        # state hashes
        last = {}
        for a in sorted(self.commits + self.durable, key=lambda a: a['seq']):
            for k in a['keys']:
                last[k] = a['hash']
        bad_h = sorted(k for k, g in gets.items() if g.exists and last.get(k) != g.hash)
        check('hashes_equal_last_answer', not bad_h, 'keys whose GET hash is not the hash of the last answer naming them: %s' % bad_h)
        # leaks
        sink = self.sink.read_bytes()
        sv = list(self.secrets.values())
        sink_leak = leak_bytes(sink, sv)
        check('zero_secret_bytes_in_sink', sink_leak == 0, '%d sink bytes searched; %d secret bytes found' % (len(sink), sink_leak))
        hay = '\n'.join(self.answers).encode()
        ans_leak = leak_bytes(hay, sv)
        check('zero_secret_bytes_in_engine_output', ans_leak == 0,
              '%d answer lines (%d bytes, replay output included) searched; %d secret bytes found' % (len(self.answers), len(hay), ans_leak))
        entries = [e for e in sink.split(b'\n') if e]
        allowed = set(self.sent_ok)
        blocked = {b.encode() for b in self.blocked}
        never = all(e not in blocked for e in entries) and all((hashlib.sha256(e).hexdigest(), len(e)) in allowed for e in entries)
        check('blocked_documents_never_in_sink', never and bool(self.blocked),
              '%d sink entries, each the exact bytes of an ALLOW answer: %s; %d blocked documents, none in the sink'
              % (len(entries), never, len(self.blocked)))
        self.results = res
        self.run_s = run_s
        return res


# ------------------------------------------------------------------------------------------------ main

def results_doc(run, scenario, store_records, canary):
    det = {
        'demo': 'universal_self_repair', 'agent': 'scripted agent, no model', 'labels': ['NATIVE CHECK', 'FINITE TEST'],
        'end_to_end': False, 'canary': canary, 'canary_applied': run.canary_applied,
        'scenario': scenario, 'turns': run.turns, 'tasks': run.tasks,
        'records': [{k: v for k, v in r.items() if k != 'now_ms'} for r in store_records if r['kind'] != 'G'],
        'counts': {'commit_answers': len(run.commits), 'durable_refusal_answers': len(run.durable),
                   'blocked_documents': len(run.blocked), 'sink_entries': len(run.sent_ok)},
        'checks': {c['check']: c['ok'] for c in run.results},
        'all_checks_pass': all(c['ok'] for c in run.results),
    }
    meas = {
        'note': 'measured on a shared, loaded machine: indicative only',
        'run_seconds': round(run.run_s, 3), 'waits': run.waits,
        'request_latency_ms': {'n': len(run.lat), 'median': round(sorted(run.lat)[len(run.lat) // 2] * 1000, 2) if run.lat else None,
                               'max': round(max(run.lat) * 1000, 2) if run.lat else None},
        'commit_answers': [{'seq': a['seq'], 'now_ms': a['now_ms'], 'hash': a['hash']} for a in run.commits],
        'durable_refusals': [{'seq': d['seq'], 'now_ms': d['now_ms'], 'hash': d['hash']} for d in run.durable],
        'check_evidence': {c['check']: c['evidence'] for c in run.results},
        'secret_lengths': {k: len(v) for k, v in run.secrets.items()},
    }
    det['measured'] = meas
    return det


def run_once(engine, scenario, canary=None, quiet=False, json_out=None):
    if not os.path.isfile(engine) or not os.access(engine, os.X_OK):
        raise Fatal(2, 'ENGINE MISSING: %s is not an executable file. Build it (README). No demo output was produced; '
                       'nothing is canned.' % engine)
    scr = Screen(quiet)
    scr.raw('universal_self_repair: propose -> dispose -> self-repair (SCRIPTED AGENT, NO MODEL)')
    scr.raw('engine: %s (unproved Rust: every verdict is a NATIVE CHECK; this run is a FINITE TEST)' % engine)
    scr.raw('legend: ENGINE = the engine\'s answer line (state hashes cut to 12 hex); agent/repair/note = script text;')
    scr.raw('        DEMO CHECK = a Python check in this script, not the engine. A fresh store in a temp folder.')
    run = Run(engine, scenario, scr, canary)
    res = run.run()
    scr.raw()
    scr.raw('%-40s %-6s %s' % ('CHECK', 'RESULT', 'EVIDENCE'))
    for c in res:
        scr.raw('%-40s %-6s %s' % (c['check'], 'PASS' if c['ok'] else 'FAIL', c['evidence']))
    lat = sorted(run.lat)
    scr.raw()
    scr.raw('measured (shared, loaded machine; indicative): run %.2f s; %d engine requests, median %.1f ms, max %.1f ms; waits %s'
            % (run.run_s, len(lat), lat[len(lat) // 2] * 1000 if lat else 0, lat[-1] * 1000 if lat else 0,
               ', '.join('%d ms asked / %.0f ms slept' % (w['asked_ms'], w['slept_ms']) for w in run.waits) or 'none'))
    ok = all(c['ok'] for c in res)
    if canary:
        scr.raw('canary %s applied: %s; the named check %s: %s' % (canary, run.canary_applied, CANARIES[canary][0],
                                                                    'FAIL (as it must)' if not next(c['ok'] for c in res if c['check'] == CANARIES[canary][0]) else 'PASS (the control did NOT bite)'))
    scr.raw('RESULT: %s' % ('ALL %d CHECKS PASS' % len(res) if ok else '%d of %d CHECKS FAIL' % (sum(not c['ok'] for c in res), len(res))))
    if json_out:
        Path(json_out).write_text(json.dumps(results_doc(run, scenario, run_store_records(run), canary), indent=1, sort_keys=True) + '\n')
    return run, ok


def run_store_records(run):
    return getattr(run, '_records', [])


def main():
    ap = argparse.ArgumentParser(description='Scripted agent, no model: propose -> dispose -> self-repair over the primitives engine.')
    ap.add_argument('--engine', default=str(DEFAULT_ENGINE))
    ap.add_argument('--scenario', help='JSON file: top-level sections that replace the default scenario sections')
    ap.add_argument('--json', help='write the results file (deterministic except the key `measured`)')
    ap.add_argument('--canary', choices=sorted(CANARIES), help='run a deliberately broken variant; its named check must FAIL')
    ap.add_argument('--self-test', action='store_true', help='run every canary (fresh run each); exit 0 only if each named check FAILS')
    args = ap.parse_args()
    scenario = DEFAULT_SCENARIO
    if args.scenario:
        scenario = merge_scenario(DEFAULT_SCENARIO, json.loads(Path(args.scenario).read_text()))
    engine = str(Path(args.engine).absolute())
    try:
        if args.self_test:
            bad = 0
            for name in sorted(CANARIES):
                run, ok = run_once(engine, scenario, canary=name, quiet=True)
                named = next(c['ok'] for c in run.results if c['check'] == CANARIES[name][0])
                good = run.canary_applied and not named and not ok
                bad += not good
                print('%s canary %-20s check %-38s %s' % ('PASS' if good else 'FAIL', name, CANARIES[name][0],
                                                         'FAILED as it must' if good else 'did not bite (applied=%s)' % run.canary_applied), flush=True)
            return 1 if bad else 0
        run, ok = run_once(engine, scenario, canary=args.canary, json_out=args.json)
        return 0 if ok else 1
    except Fatal as e:
        print('FATAL: %s' % e, flush=True)
        return e.exit_code
    except fp.PrimitivesError as e:
        print('FATAL: the engine or the SDK raised %s: %s (no result is claimed)' % (type(e).__name__, e), flush=True)
        return 3


if __name__ == '__main__':
    sys.exit(main())
