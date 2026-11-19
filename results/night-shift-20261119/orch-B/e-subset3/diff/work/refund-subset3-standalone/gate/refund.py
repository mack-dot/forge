#!/usr/bin/env python3
"""Fresh refund source proof and separate finite integration-test evidence.

Run this file from gate/refund.py only after exact approval. Evidence is not a
signature. The caller must supply this gate and its inputs from a trusted base.
"""

import argparse
from pathlib import Path
import platform
import re
import shlex
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
from common import ROOT, Rejected, canonical, digest, pin_file, read_json, relative
from dependencies import check_dependencies
from backends import dafny

APPROVED = {
    'spec/refund/RefundSpec.dfy': '90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57',
    'spec/refund/protocol.md': '5ef4e8fa6c23a4a455b3cbdc3f5b14ae313762446fea8444ca5e6c570e86ecd4',
    'spec/refund/spec.lock': '8b131ab82d3d5bb8f284086e207fa4207c3599ffcae887aa70b13d225ce9375b',
    'policy/refund.yaml': '4409904602e6b670c0fbf773b8f303426e22e0caac077f3d6ed5f016cecf2c83',
}
SOURCE_FILES = ('impl/Refund.dfy', 'spec/refund/RefundSpec.dfy')
BINDING = 'gate/refund/Bindings.dfy'
TEST = 'gate/refund/hostile.ts'
CLAIMS = {
    'R1': 'Every authorization has a valid context and an amount in [0, remaining] within the original signed-64-bit charge.',
    'R2': 'Every authorized reason is one of the three approved exact labels.',
    'R3': 'Every ineligible context or modeled response returns Rejected and an empty plan.',
    'R4': 'Every eligible proposal is accepted with its exact amount, reason, and caller-bound intent.',
    'R5': 'The pure source boundary returns exactly one caller-bound intent iff authorized; otherwise no intent.',
}
TEST_CLAIMS = {
    'T1': 'The recorded finite wire corpus obeys strict decoding and fallback rules.',
    'T2': 'The compiled wrapper matches the approved rules for the recorded finite typed-response corpus.',
    'T3': 'The recorded finite host traces dispatch only checked plans and preserve terminal request behavior.',
}
REQUIRED = {
    'Refund.Assess (correctness)', 'Refund.Assess (well-formedness)',
    'RefundSpec.Assess (well-formedness)',
    'RefundSpec.Eligible (well-formedness)',
    'RefundChecks.Universal (correctness)',
    'RefundChecks.SuccessfulWitness (correctness)',
}
COMMON_INPUTS = (
    'gate/refund.py', BINDING, TEST, 'gate/common.py', 'gate/core.py',
    'gate/dependencies.py', 'gate/backends/__init__.py', 'gate/backends/dafny.py',
    'gate/expected-audit.md', 'schemas/evidence.schema.json', 'schemas/policy.schema.json',
    pin_file('dafny'), pin_file('validator'),
    'toolchain/requirements-stage2.txt', 'proposals/refund-decision.md',
)
JS_INPUTS = (
    'scripts/javascript_env.py', pin_file('javascript'),
    'package.json', 'package-lock.json', 'tsconfig.json',
)
FOOTER = b'\nmodule.exports = { Refund, runtime: _dafny };\n'


def run(command, work, name, records):
    child = subprocess.run(command, cwd=ROOT, capture_output=True)
    stdout, stderr = work / (name + '.stdout'), work / (name + '.stderr')
    stdout.write_bytes(child.stdout)
    stderr.write_bytes(child.stderr)
    records.append({'argv': command, 'cwd': '.', 'exit_code': child.returncode,
                    'stdout': relative(stdout), 'stdout_sha256': digest(child.stdout),
                    'stderr': relative(stderr), 'stderr_sha256': digest(child.stderr)})
    (work / 'operations.json').write_bytes(canonical({'commands': records,
                                                    'stage_exit': False}))
    print(name + ': exit ' + str(child.returncode), flush=True)
    return child


# Strict core subset, rule 3 (SUBSET3_*). Allow-list recognizer: compiled code is straight-line code over
# if/match, typed by a small kind system; no loop, no recursion (the call graph must be acyclic), no product
# of two non-literals, no sequence/string/set growth operator, no extra module, no shadowing or name reuse.
# Cost claim (ARGUMENT, not machine-checked; DESIGN3.md): one Assess call executes at most W <= 4096 source
# tokens (W = compiled tokens unfolded over the acyclic call graph; 128 per pinned spec predicate call).
# Every value is a tree of at most 32 nodes whose leaves are literals (<= 256 characters, |int| < 10^19),
# input fields, or integers of at most I + 64*W bits (I = largest input integer). So each operation costs at
# most O(32^2 * (input size + 64*W)) and one run costs O(W * 32^2 * (input size + 64*W)).
# NOT covered: the Dafny-to-JavaScript compiler and runtime (TESTED-UNPROVED on samples only).
SUBSET3_LINE_END = re.compile('[\r\n]')
SUBSET3_CONTROL = re.compile('[\x00-\x08\x0e-\x1f\x7f-\x84\x86-\x9f]')
SUBSET3_CHAR = re.compile(r"'(\\U\{[0-9A-Fa-f_]{1,8}\}|\\u[0-9A-Fa-f]{4}|\\[^\r\n]|[^'\\\r\n])'")
SUBSET3_NUM = re.compile(r'0x[0-9A-Fa-f_]+|[0-9][0-9_]*(\.[0-9][0-9_]*)?')
SUBSET3_ID = re.compile(r"[A-Za-z_][A-Za-z0-9_?']*")
SUBSET3_OPS = ('<==>', '==>', '<==', '-->', ':=', ':|', ':-', '::', '==', '!=', '<=', '>=', '&&', '||',
               '..', '=>', '->', '~>', '!!', '{:')
SUBSET3_GLOBAL = {'expect', 'assume', 'print', 'new', 'class', 'trait', 'iterator', 'import', 'export',
                  'opened', 'abstract', 'extern', 'axiom', 'codatatype', 'newtype', 'type', 'datatype',
                  'object', 'yield', 'modify', 'label', 'twostate', 'least', 'greatest', 'inductive',
                  'copredicate', 'colemma', 'constructor', 'iset', 'imap', 'ORDINAL', 'module', 'refines',
                  'include', 'static', 'opaque', 'reveal', 'hide', 'old', 'fresh', 'unchanged', 'this'}
SUBSET3_ATTRIBUTES = (['{:', 'isolate_assertions', '}'], ['{:', 'induction', 'false', '}'])
SUBSET3_SCALAR = {'int': 1, 'nat': 1, 'bool': 1, 'string': 1, 'char': 1, 'Context': 7, 'ModelResponse': 3,
                  'Decision': 3, 'RefundIntent': 5}
SUBSET3_CTORS = {'Intent': ('RefundIntent', ('string', 'string', 'int', 'string')),
                 'Authorized': ('Decision', ('int', 'string')),
                 'Candidate': ('ModelResponse', ('int', 'string')),
                 'ChargeContext': ('Context', ('string', 'string', 'int', 'int', 'bool', 'bool')),
                 'Rejected': ('Decision', ()), 'Missing': ('ModelResponse', ()),
                 'TimedOut': ('ModelResponse', ()), 'Failed': ('ModelResponse', ()),
                 'Malformed': ('ModelResponse', ()), 'Oversized': ('ModelResponse', ()),
                 'Unsupported': ('ModelResponse', ())}
SUBSET3_FIELDS = {'Context': {'chargeId': 'string', 'requestId': 'string', 'original': 'int', 'remaining': 'int',
                              'refundEnabled': 'bool', 'requestOpen': 'bool', 'ChargeContext?': 'bool'},
                  'ModelResponse': {'amount': 'int', 'reason': 'string', 'Candidate?': 'bool', 'Missing?': 'bool',
                                    'TimedOut?': 'bool', 'Failed?': 'bool', 'Malformed?': 'bool',
                                    'Oversized?': 'bool', 'Unsupported?': 'bool'},
                  'Decision': {'amount': 'int', 'reason': 'string', 'Rejected?': 'bool', 'Authorized?': 'bool'},
                  'RefundIntent': {'chargeId': 'string', 'requestId': 'string', 'amount': 'int', 'reason': 'string',
                                   'Intent?': 'bool'}}
SUBSET3_SPEC = {'Eligible': (('Context', 'ModelResponse'), 'bool'), 'ValidContext': (('Context',), 'bool'),
                'Money': (('int',), 'bool'), 'AllowedReason': (('string',), 'bool')}
SUBSET3_SPEC_NAMES = set(SUBSET3_SCALAR) | set(SUBSET3_CTORS) | set(SUBSET3_SPEC) | {
    'RefundSpec', 'Refund', 'MaxMoney', 'Assess', 'seq', 'set', 'map', 'multiset', 'true', 'false', 'Main'}
SUBSET3_JS_DENY = {
    'break', 'case', 'catch', 'class', 'const', 'continue', 'debugger', 'default', 'delete', 'do', 'else', 'enum',
    'export', 'extends', 'false', 'finally', 'for', 'function', 'if', 'import', 'in', 'instanceof', 'new', 'null',
    'return', 'super', 'switch', 'this', 'throw', 'true', 'try', 'typeof', 'var', 'void', 'while', 'with', 'yield',
    'let', 'static', 'implements', 'interface', 'package', 'private', 'protected', 'public', 'await', 'async',
    'arguments', 'eval', 'undefined', 'NaN', 'Infinity', 'require', 'module', 'exports', 'BigNumber', 'Object',
    'Array', 'String', 'Number', 'Boolean', 'Math', 'JSON', 'Symbol', 'Function', 'Error', 'Promise', 'Reflect',
    'Proxy', 'globalThis', 'global', 'process', 'console', 'prototype', 'constructor', 'toString', 'valueOf',
    'hasOwnProperty', 'isPrototypeOf', 'propertyIsEnumerable', 'toLocaleString', 'length', 'name', 'caller',
    'callee', 'apply', 'call', 'bind', 'runtime', 'Main'}
SUBSET3_SPEC_WEIGHT = 128   # upper bound on the unfolded tokens of one call of a pinned spec predicate
SUBSET3_MAX_WEIGHT = 4096   # bound W on executed tokens of one Assess call (and of each compiled member)
SUBSET3_MAX_TREE = 32       # bound T on the node count of one value (sharing counted as copies)
SUBSET3_MAX_DISPLAY = 16
SUBSET3_MAX_BYTES = 65536


def subset3_refuse(code, message):
    raise Rejected('SUBSET3_' + code + ': ' + message)


def subset3_tokens(text):
    """All tokens outside comments as (kind, text). A `//` comment ends at CR or LF (as the pinned Dafny:
    controls L01-L06 of orch-B/e-subset2). Control characters fail closed. (Copy of the rule 2 lexer.)"""
    if SUBSET3_CONTROL.search(text):
        subset3_refuse('LEX', 'control character U+%04X' % ord(SUBSET3_CONTROL.search(text).group(0)))
    tokens, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith('//', i):
            end = SUBSET3_LINE_END.search(text, i)
            i = n if end is None else end.start()
        elif text.startswith('/*', i):
            depth, i = 1, i + 2
            while depth:
                if i >= n:
                    subset3_refuse('LEX', 'unterminated comment')
                pair = text[i:i + 2]
                depth += {'/*': 1, '*/': -1}.get(pair, 0)
                i += 2 if pair in ('/*', '*/') else 1
        elif c in ' \t\r\n':
            i += 1
        elif c == '"' or text.startswith('@"', i):
            verbatim, start = c == '@', i
            i += 2 if verbatim else 1
            while True:
                if i >= n or (not verbatim and text[i] in '\r\n'):
                    subset3_refuse('LEX', 'unterminated string')
                if not verbatim and text.startswith('\\', i) and text[i + 1:i + 2] in ('\r', '\n', ''):
                    subset3_refuse('LEX', 'backslash before a line break in a string literal')
                if verbatim and text.startswith('""', i) or not verbatim and text[i] == '\\':
                    i += 2
                elif text[i] == '"':
                    i += 1
                    break
                else:
                    i += 1
            if i - start > 256:
                subset3_refuse('LITERAL', 'string literal longer than 256 characters')
            tokens.append(('str', text[start:i]))
        elif c == "'":
            literal = SUBSET3_CHAR.match(text, i)
            if not literal:
                subset3_refuse('LEX', 'unrecognized character literal')
            tokens.append(('char', literal.group(0)))
            i = literal.end()
        elif SUBSET3_ID.match(text, i) and c.isascii():
            word = SUBSET3_ID.match(text, i).group(0)
            tokens.append(('id', word))
            i += len(word)
        elif c.isdigit() and c.isascii():
            number = SUBSET3_NUM.match(text, i).group(0)
            tokens.append(('num', number))
            i += len(number)
        elif c.isascii() and c.isprintable():
            op = next((o for o in SUBSET3_OPS if text.startswith(o, i)), c)
            tokens.append(('op', op))
            i += len(op)
        else:
            subset3_refuse('LEX', 'character U+%04X outside comments and literals' % ord(c))
    return tokens


def subset3_close(texts, k):
    """Index of the bracket that closes texts[k]."""
    pairs, depth = {'(': ')', '[': ']', '{': '}'}, 0
    opener, closer = texts[k], pairs[texts[k]]
    for j in range(k, len(texts)):
        depth += (texts[j] == opener) - (texts[j] == closer)
        if depth == 0:
            return j
    subset3_refuse('SHAPE', 'unbalanced ' + opener)


def subset3_fits(have, want):
    """Kind `have` can stand where kind `want` is expected (an empty display has element kind None)."""
    if have == want or have is None or want is None:
        return True
    if isinstance(have, tuple) and isinstance(want, tuple) and have[0] == want[0]:
        if have[0] == 'tuple':
            return len(have[1]) == len(want[1]) and all(subset3_fits(a, b) for a, b in zip(have[1], want[1]))
        return subset3_fits(have[1], want[1])
    return False


def subset3_name_ok(name, module_names):
    if (not re.fullmatch(r"[A-Za-z][A-Za-z0-9_']{0,63}", name) or '__' in name or name in SUBSET3_JS_DENY
            or name in module_names):
        subset3_refuse('NAME', 'declared name `' + name + '` is refused (shape, JavaScript name or shadowing)')


class Subset3Module:
    """Module-level table: members, kinds, analysed signatures, weights. Fails closed on any unknown form."""

    def __init__(self, texts):
        self.texts, self.info, self.active, self.max_tree = texts, {}, [], 1
        if (texts[:7] != ['include', '"../spec/refund/RefundSpec.dfy"', 'module', 'Refund', 'refines',
                          'RefundSpec', '{']):
            subset3_refuse('SHAPE', 'exactly one include and one module Refund refines RefundSpec first')
        close = subset3_close(texts, 6)
        if close != len(texts) - 1:
            subset3_refuse('MODULE', 'nothing may follow module Refund (no extra module)')
        self.members = {}
        k = 7
        while k < close:
            ghost = texts[k] == 'ghost'
            k += ghost
            kind = texts[k]
            if kind not in ('function', 'predicate', 'method', 'lemma', 'const'):
                subset3_refuse('DECLARATION', 'unsupported module member at `' + kind + '`')
            if texts[k + 1] == 'method':
                subset3_refuse('DECLARATION', 'legacy function method')
            name, j = texts[k + 1], k + 2
            while j < close and texts[j] not in ('ghost', 'function', 'predicate', 'method', 'lemma', 'const'):
                j = subset3_close(texts, j) + 1 if texts[j] in '([{' else j + 1
            if name in self.members:
                subset3_refuse('NAME', 'member `' + name + '` declared twice')
            self.members[name] = (kind, ghost or kind == 'lemma', k + 2, j)
            k = j
        self.names = SUBSET3_SPEC_NAMES | set(self.members)
        for name, (kind, ghost, lo, hi) in self.members.items():
            if name == 'Assess':
                if kind != 'method' or ghost:
                    subset3_refuse('SHAPE', 'Assess must be a compiled method')
                continue
            subset3_name_ok(name, SUBSET3_SPEC_NAMES)
            if ghost and kind != 'const' and texts[hi - 1] != '}':
                subset3_refuse('SHAPE', 'ghost ' + kind + ' ' + name + ' without body')
            if ghost and kind == 'const' and ':=' not in texts[lo:hi]:
                subset3_refuse('SHAPE', 'ghost const ' + name + ' without initializer')
        if 'Assess' not in self.members:
            subset3_refuse('SHAPE', 'no compiled method Assess')

    def ghost(self, name):
        return name in self.members and self.members[name][1]

    def analyse(self, name):
        """(kind-of-member, signature, weight) of a compiled member, analysed once; cycles are refused."""
        if name in self.info:
            return self.info[name]
        if name in self.active:
            subset3_refuse('RECURSION', 'call cycle ' + ' -> '.join(self.active + [name]))
        self.active.append(name)
        kind, ghost, lo, hi = self.members[name]
        info = Subset3Member(self, name, kind, lo, hi).run()
        self.active.pop()
        if info[2] > SUBSET3_MAX_WEIGHT:
            subset3_refuse('WEIGHT', name + ' unfolds to %d > %d tokens' % (info[2], SUBSET3_MAX_WEIGHT))
        self.info[name] = info
        return info


class Subset3Member:
    """Recognizer for one compiled member. Every consumed compiled token adds 1 to the weight."""

    def __init__(self, mod, name, kind, lo, hi):
        self.m, self.t, self.name, self.kind, self.k, self.hi = mod, mod.texts, name, kind, lo, hi
        self.env, self.outs, self.weight = {}, [], 0

    # ---- token helpers
    def peek(self, d=0):
        return self.t[self.k + d] if self.k + d < self.hi else None

    def take(self, want=None):
        tok = self.peek()
        if tok is None or want is not None and tok != want:
            subset3_refuse('SYNTAX', 'in %s expected `%s`, found `%s`' % (self.name, want, tok))
        self.k += 1
        self.weight += 1
        return tok

    def declare(self, name, kind, tree, ghost=False, assignable=True):
        subset3_name_ok(name, self.m.names)
        if name in self.env:
            subset3_refuse('NAME', 'name `%s` reused in %s' % (name, self.name))
        self.env[name] = [kind, tree, ghost, assignable]

    def type(self, fixed=False):
        tok = self.take()
        if tok in SUBSET3_SCALAR:
            return ('int' if tok == 'nat' else tok), SUBSET3_SCALAR[tok]
        if fixed:
            subset3_refuse('TYPE', 'helper parameter type `%s` is not a fixed-shape type' % tok)
        if tok == 'seq':
            self.take('<')
            elem = self.type()[0]
            self.take('>')
            return ('seq', elem), 0
        if tok == '(':
            parts = [self.type()[0]]
            while self.peek() == ',':
                self.take(',')
                parts.append(self.type()[0])
            self.take(')')
            if len(parts) < 2:
                subset3_refuse('TYPE', 'one-element tuple type')
            return ('tuple', tuple(parts)), 0
        subset3_refuse('TYPE', 'type `%s` is outside the allow-list' % tok)

    def params(self, fixed, out=False):
        self.take('(')
        names = []
        while self.peek() != ')':
            if names:
                self.take(',')
            pname = self.take()
            self.take(':')
            kind, tree = self.type(fixed)
            self.declare(pname, kind, tree if not out else 0, assignable=out)
            names.append((pname, kind))
        self.take(')')
        return names

    def spec_clauses(self, body_open):
        """Ghost specification between the signature and the body: skipped, never compiled."""
        if self.k < body_open and self.t[self.k] not in ('requires', 'ensures', 'decreases', 'reads', 'modifies'):
            subset3_refuse('SYNTAX', 'unexpected `%s` in the signature of %s' % (self.t[self.k], self.name))
        self.k = body_open

    def body_open(self):
        for x in range(self.k, self.hi):
            if self.t[x] == '{' and subset3_close(self.t, x) == self.hi - 1:
                return x
        subset3_refuse('SHAPE', self.name + ' has no body')

    # ---- members
    def run(self):
        if self.kind == 'const':
            kind = None
            if self.peek() == ':':
                self.take(':')
                kind = self.type()[0]
            self.take(':=')
            have, tree, _ = self.expr()
            if self.k != self.hi or not subset3_fits(have, kind):
                subset3_refuse('SYNTAX', 'const ' + self.name + ' is not one admitted expression')
            return ('const', (kind or have, tree), self.weight)
        if self.kind in ('function', 'predicate'):
            params = self.params(fixed=True)
            ret = 'bool'
            if self.kind == 'function':
                self.take(':')
                ret = self.type()[0]
            body = self.body_open()
            self.spec_clauses(body)
            self.take('{')
            have, tree, _ = self.expr()
            self.take('}')
            if self.k != self.hi or not subset3_fits(have, ret):
                subset3_refuse('SYNTAX', 'function ' + self.name + ' body is not one admitted expression')
            return ('function', ([p[1] for p in params], ret, tree), self.weight)
        if self.kind == 'method':
            if self.name == 'Assess':
                sig = self.t[self.k:self.k + 22]
                want = ['(', 'context', ':', 'Context', ',', 'response', ':', 'ModelResponse', ')', 'returns',
                        '(', 'decision', ':', 'Decision', ',', 'plan', ':', 'seq', '<', 'RefundIntent', '>', ')']
                if sig != want:
                    subset3_refuse('SHAPE', 'Assess signature differs from the approved one')
            params = self.params(fixed=True)
            if self.peek() == 'returns':
                self.take('returns')
                self.outs = self.params(fixed=False, out=True)
            body = self.body_open()
            self.spec_clauses(body)
            self.block()
            if self.k != self.hi:
                subset3_refuse('SYNTAX', 'text after the body of ' + self.name)
            return ('method', ([p[1] for p in params], [o[1] for o in self.outs],
                               [self.env[o[0]][1] for o in self.outs]), self.weight)
        subset3_refuse('DECLARATION', 'unsupported compiled member ' + self.name)

    # ---- statements
    def block(self):
        self.take('{')
        while self.peek() != '}':
            self.statement()
        self.take('}')

    def skip_until(self, stops):
        """Skip ghost tokens (bracket-balanced) up to the first depth-0 token in stops; never past the member."""
        while self.k < self.hi and self.t[self.k] not in stops:
            nxt = subset3_close(self.t, self.k) + 1 if self.t[self.k] in '([{' else self.k + 1
            for name in self.t[self.k:nxt]:
                if name in self.m.members and self.m.members[name][0] == 'method' and not self.m.ghost(name):
                    subset3_refuse('GHOST', 'compiled method `%s` named inside a ghost statement' % name)
            self.k = nxt
        if self.k >= self.hi:
            subset3_refuse('SYNTAX', 'unterminated ghost statement in ' + self.name)

    def skip_to_semicolon(self):
        self.skip_until((';',))
        self.k += 1

    def statement(self):
        tok = self.peek()
        if tok == '{':
            return self.block()
        if tok == 'assert':                       # ghost: erased by the compiler
            self.skip_until((';', 'by'))
            if self.t[self.k] == 'by':
                if self.t[self.k + 1] != '{':
                    subset3_refuse('SYNTAX', 'assert by without block')
                self.k = subset3_close(self.t, self.k + 1) + 1
            else:
                self.k += 1
            return
        if tok == 'ghost':                        # ghost var: erased; its names still enter the name table
            if self.peek(1) != 'var':
                subset3_refuse('SYNTAX', 'ghost statement other than ghost var')
            self.k += 2
            while True:
                self.declare(self.t[self.k], None, 0, ghost=True)
                self.k += 1
                if self.t[self.k] == ':':
                    self.skip_until((',', ':=', ':|', ';'))
                if self.t[self.k] != ',':
                    break
                self.k += 1
            return self.skip_to_semicolon()
        if tok == 'var':
            return self.var_statement()
        if tok == 'if':
            self.take('if')
            self.expect_kind(self.expr(no_brace=True), 'bool')
            self.block()
            if self.peek() == 'else':
                self.take('else')
                if self.peek() == 'if':
                    return self.statement()
                self.block()
            return
        if tok == 'match':
            self.take('match')
            scrutinee = self.expr(no_brace=True)
            self.take('{')
            if self.peek() != 'case':
                subset3_refuse('SYNTAX', 'match without case')
            while self.peek() == 'case':
                self.take('case')
                self.pattern(scrutinee[0], scrutinee[1])
                self.take('=>')
                while self.peek() not in ('case', '}'):
                    self.statement()
            self.take('}')
            return
        if tok == 'return':
            self.take('return')
            if self.peek() != ';':
                values = self.expr_list()
                if len(values) != len(self.outs):
                    subset3_refuse('SYNTAX', 'return arity')
                for (oname, okind), value in zip(self.outs, values):
                    self.assign(oname, value)
            self.take(';')
            return
        if tok in self.m.members and self.peek(1) == '(':
            kind, ghost = self.m.members[tok][0], self.m.members[tok][1]
            if ghost and kind in ('lemma', 'method'):   # lemma or ghost method call: erased
                self.k = subset3_close(self.t, self.k + 1) + 1
                if self.k >= self.hi or self.t[self.k] != ';':
                    subset3_refuse('SYNTAX', 'ghost call is not a statement')
                self.k += 1
                return
            if kind == 'method' and not ghost:
                info = self.call_method(self.take())
                if info[1]:
                    subset3_refuse('SYNTAX', 'method with results called as a statement')
                self.take(';')
                return
        if tok in self.env:
            targets = [self.take()]
            while self.peek() == ',':
                self.take(',')
                targets.append(self.take())
            self.take(':=')
            values = self.rhs(len(targets))
            for target, value in zip(targets, values):
                self.assign(target, value)
            self.take(';')
            return
        subset3_refuse('STATEMENT', 'statement `%s` is outside the allow-list (in %s)' % (tok, self.name))

    def assign(self, target, value):
        if target not in self.env or not self.env[target][3] or self.env[target][2]:
            subset3_refuse('SYNTAX', 'assignment to `%s` (not a compiled local or result)' % target)
        entry = self.env[target]
        if not subset3_fits(value[0], entry[0]):
            subset3_refuse('KIND', 'assignment kind mismatch for ' + target)
        if entry[0] is None or isinstance(entry[0], tuple) and entry[0][1] is None:
            entry[0] = value[0]
        entry[1] = max(entry[1], value[1])

    def rhs(self, count):
        tok = self.peek()
        if tok in self.m.members and self.m.members[tok][0] == 'method' and self.peek(1) == '(':
            if self.m.members[tok][1]:
                subset3_refuse('SYNTAX', 'ghost method on the right side')
            info = self.call_method(self.take())
            if len(info[1]) != count:
                subset3_refuse('SYNTAX', 'method result arity')
            return list(zip(info[1], info[2], [False] * count))
        values = self.expr_list()
        if len(values) != count:
            subset3_refuse('SYNTAX', 'assignment arity')
        return values

    def var_statement(self):
        self.take('var')
        if self.peek() == '(':                    # var (a, b) := tuple-valued expression
            self.take('(')
            names = [self.take()]
            while self.peek() == ',':
                self.take(',')
                names.append(self.take())
            self.take(')')
            self.take(':=')
            kind, tree, _ = self.expr()
            if not (isinstance(kind, tuple) and kind[0] == 'tuple' and len(kind[1]) == len(names)):
                subset3_refuse('KIND', 'tuple pattern arity')
            for name, part in zip(names, kind[1]):
                self.declare(name, part, tree)
            self.take(';')
            return
        decls = []
        while True:
            name = self.take()
            kind = None
            if self.peek() == ':':
                self.take(':')
                kind = self.type()[0]
            decls.append((name, kind))
            if self.peek() != ',':
                break
            self.take(',')
        if self.peek() == ';':
            for name, kind in decls:
                if kind is None:
                    subset3_refuse('SYNTAX', 'var without type or value')
                self.declare(name, kind, 0)
            self.take(';')
            return
        self.take(':=')
        values = self.rhs(len(decls))
        for (name, kind), value in zip(decls, values):
            if kind is not None and not subset3_fits(value[0], kind):
                subset3_refuse('KIND', 'var kind mismatch for ' + name)
            self.declare(name, kind or value[0], value[1])
        self.take(';')

    def call_method(self, name):
        info = self.m.analyse(name)
        args = self.args()
        self.check_args(name, info[1][0], args)
        self.weight += info[2]
        return ('method', info[1][1], info[1][2])

    def check_args(self, name, kinds, args):
        if len(kinds) != len(args) or not all(subset3_fits(a[0], k) for a, k in zip(args, kinds)):
            subset3_refuse('KIND', 'arguments of ' + name)

    def expect_kind(self, value, kind):
        if not subset3_fits(value[0], kind) or value[0] is None:
            subset3_refuse('KIND', 'expected %s, found %s' % (kind, value[0]))
        return value

    # ---- patterns
    def pattern(self, kind, tree):
        tok = self.peek()
        if tok == '_':
            self.take()
            return
        if tok == '(':
            if not (isinstance(kind, tuple) and kind[0] == 'tuple'):
                subset3_refuse('KIND', 'tuple pattern on a non-tuple')
            self.take('(')
            for x, part in enumerate(kind[1]):
                if x:
                    self.take(',')
                self.pattern(part, tree)
            self.take(')')
            return
        if tok in ('true', 'false'):
            self.take()
            return self.expect_kind((kind, 1, False), 'bool')
        if tok in SUBSET3_CTORS:
            ctor_kind, arg_kinds = SUBSET3_CTORS[self.take()]
            if not subset3_fits(kind, ctor_kind):
                subset3_refuse('KIND', 'constructor pattern ' + tok)
            if arg_kinds:
                self.take('(')
                for x, part in enumerate(arg_kinds):
                    if x:
                        self.take(',')
                    self.pattern(part, 1)
                self.take(')')
            return
        if tok == '-' or tok[:1].isdigit() or tok[:1] in '"\'' or tok[:2] == '@"':
            self.unary(False)
            return
        self.declare(self.take(), kind, tree, assignable=False)

    # ---- expressions: return (kind, tree, is_literal)
    def expr_list(self):
        values = [self.expr()]
        while self.peek() == ',':
            self.take(',')
            values.append(self.expr())
        return values

    def expr(self, no_brace=False):
        left = self.implies(no_brace)
        while self.peek() == '<==>':
            self.take()
            self.expect_kind(left, 'bool')
            left = ('bool', 1, False)
            self.expect_kind(self.implies(no_brace), 'bool')
        return left

    def implies(self, no_brace):
        left = self.logical(no_brace)
        if self.peek() == '==>':
            self.take()
            self.expect_kind(left, 'bool')
            self.expect_kind(self.implies(no_brace), 'bool')
            return ('bool', 1, False)
        while self.peek() == '<==':
            self.take()
            self.expect_kind(left, 'bool')
            self.expect_kind(self.logical(no_brace), 'bool')
            left = ('bool', 1, False)
        return left

    def logical(self, no_brace):
        left = self.relation(no_brace)
        while self.peek() in ('&&', '||'):
            self.take()
            self.expect_kind(left, 'bool')
            self.expect_kind(self.relation(no_brace), 'bool')
            left = ('bool', 1, False)
        return left

    def relation(self, no_brace):
        start = self.k
        left = self.additive(no_brace)
        operands, ops = [(left, start, self.k)], []
        while self.peek() in ('==', '!=', '<', '<=', '>', '>=', 'in') or self.peek() == '!' and self.peek(1) == 'in':
            op = self.take()
            if op == '!':
                op += self.take('in')
            begin = self.k
            operands.append((self.additive(no_brace), begin, self.k))
            ops.append(op)
        if not ops:
            return left
        if len(ops) > 1:   # chains: inner operands may be evaluated twice: no call, no member, counted twice
            for value, begin, end in operands[1:-1]:
                if any(x in ('(', 'if', 'match') or x in self.m.members for x in self.t[begin:end]):
                    subset3_refuse('CHAIN', 'inner operand of a comparison chain is not call-free')
                self.weight += end - begin
        for op, (a, _, _), (b, _, _) in zip(ops, operands, operands[1:]):
            if op in ('<', '<=', '>', '>='):
                self.expect_kind(a, 'int')
                self.expect_kind(b, 'int')
            elif op in ('in', '!in'):
                ok = (isinstance(b[0], tuple) and b[0][0] in ('seq', 'set') and subset3_fits(a[0], b[0][1])
                      or b[0] == 'string' and a[0] == 'char')
                if not ok or len(ops) > 1:
                    subset3_refuse('KIND', 'membership needs a display and is not chained')
            elif not subset3_fits(a[0], b[0]) or a[0] is None and b[0] is None:
                subset3_refuse('KIND', 'equality between different kinds')
        return ('bool', 1, False)

    def additive(self, no_brace):
        left = self.multiplicative(no_brace)
        while self.peek() in ('+', '-'):
            self.take()
            self.expect_kind(left, 'int')
            self.expect_kind(self.multiplicative(no_brace), 'int')
            left = ('int', 1, False)
        return left

    def multiplicative(self, no_brace):
        left = self.unary(no_brace)
        while self.peek() in ('*', '/', '%'):
            op = self.take()
            right = self.unary(no_brace)
            self.expect_kind(left, 'int')
            self.expect_kind(right, 'int')
            if op == '*' and not (left[2] or right[2]):
                subset3_refuse('PRODUCT', 'product of two non-literal operands')
            if op in ('/', '%') and not (right[2] and right[2] != 'zero'):
                subset3_refuse('PRODUCT', 'division by a non-literal or zero')
            left = ('int', 1, False)
        return left

    def unary(self, no_brace):
        if self.peek() == '!':
            self.take()
            self.expect_kind(self.unary(no_brace), 'bool')
            return ('bool', 1, False)
        if self.peek() == '-':
            self.take()
            value = self.expect_kind(self.unary(no_brace), 'int')
            return ('int', 1, value[2])
        return self.postfix(no_brace)

    def postfix(self, no_brace):
        value = self.primary(no_brace)
        while self.peek() == '.':
            self.take('.')
            sel = self.take()
            kind = value[0]
            if isinstance(kind, tuple) and kind[0] == 'tuple' and sel in ('0', '1', '2', '3')[:len(kind[1])]:
                value = (kind[1][int(sel)], value[1], False)
            elif kind in SUBSET3_FIELDS and sel in SUBSET3_FIELDS[kind]:
                value = (SUBSET3_FIELDS[kind][sel], 1, False)
            else:
                subset3_refuse('SELECT', 'selection `.%s` on %s' % (sel, kind))
        return value

    def args(self):
        self.take('(')
        values = []
        while self.peek() != ')':
            if values:
                self.take(',')
            values.append(self.expr())
        self.take(')')
        return values

    def tree(self, size):
        self.m.max_tree = max(self.m.max_tree, size)
        if size > SUBSET3_MAX_TREE:
            subset3_refuse('TREE', 'a value of more than %d nodes (sharing counted as copies)' % SUBSET3_MAX_TREE)
        return size

    def display(self, close):
        values = []
        while self.peek() != close:
            if values:
                self.take(',')
            values.append(self.expr())
        self.take(close)
        if len(values) > SUBSET3_MAX_DISPLAY:
            subset3_refuse('DISPLAY', 'display with more than %d elements' % SUBSET3_MAX_DISPLAY)
        elem = None
        for v in values:
            if not subset3_fits(v[0], elem):
                subset3_refuse('KIND', 'display elements of different kinds')
            elem = elem if v[0] is None else v[0]
        return elem, self.tree(1 + sum(v[1] for v in values))

    def primary(self, no_brace):
        tok = self.peek()
        if tok is None:
            subset3_refuse('SYNTAX', 'unexpected end of ' + self.name)
        if tok[:1].isdigit():
            self.take()
            if not re.fullmatch(r'[0-9]{1,19}', tok):
                subset3_refuse('LITERAL', 'numeric literal `%s` (decimal, at most 19 digits)' % tok[:24])
            return ('int', 1, 'zero' if int(tok) == 0 else True)
        if tok in ('true', 'false'):
            self.take()
            return ('bool', 1, False)
        if tok[:1] == '"' or tok[:2] == '@"':
            self.take()
            return ('string', 1, False)
        if tok[:1] == "'":
            self.take()
            return ('char', 1, False)
        if tok == '(':
            self.take('(')
            values = [self.expr()]
            while self.peek() == ',':
                self.take(',')
                values.append(self.expr())
            self.take(')')
            if len(values) == 1:
                return values[0]
            return (('tuple', tuple(v[0] for v in values)), self.tree(1 + sum(v[1] for v in values)), False)
        if tok == '[':
            self.take('[')
            elem, tree = self.display(']')
            return (('seq', elem), tree, False)
        if tok == '{':
            if no_brace:
                subset3_refuse('GUARD_BRACE', '`{` inside an if/match guard (parenthesize nothing: refused)')
            self.take('{')
            elem, tree = self.display('}')
            return (('set', elem), tree, False)
        if tok == '|':
            self.take('|')
            inner = self.postfix(no_brace)
            self.take('|')
            if not (isinstance(inner[0], tuple) and inner[0][0] in ('seq', 'set') or inner[0] == 'string'):
                subset3_refuse('KIND', 'cardinality of a non-collection')
            return ('int', 1, False)
        if tok == 'if':
            self.take('if')
            self.expect_kind(self.expr(no_brace), 'bool')
            self.take('then')
            a = self.expr(no_brace)
            self.take('else')
            b = self.expr(no_brace)
            if not subset3_fits(a[0], b[0]):
                subset3_refuse('KIND', 'if branches of different kinds')
            return (a[0] if a[0] is not None and not (isinstance(a[0], tuple) and a[0][1] is None) else b[0],
                    max(a[1], b[1]), False)
        if tok == 'match':
            self.take('match')
            scrutinee = self.expr(no_brace=True)
            braced = self.peek() == '{'
            if braced:
                self.take('{')
            result = None
            while self.peek() == 'case':
                self.take('case')
                self.pattern(scrutinee[0], scrutinee[1])
                self.take('=>')
                arm = self.expr(no_brace and not braced)
                if result is not None and not subset3_fits(arm[0], result[0]):
                    subset3_refuse('KIND', 'match arms of different kinds')
                result = arm if result is None else (result[0] if result[0] is not None else arm[0],
                                                     max(result[1], arm[1]), False)
            if result is None:
                subset3_refuse('SYNTAX', 'match expression without case')
            if braced:
                self.take('}')
            return result
        name = self.take()
        if self.peek() == '(' and name in SUBSET3_CTORS and SUBSET3_CTORS[name][1]:
            kind, kinds = SUBSET3_CTORS[name]
            args = self.args()
            self.check_args(name, kinds, args)
            return (kind, self.tree(1 + sum(a[1] for a in args)), False)
        if self.peek() == '(' and name in SUBSET3_SPEC:
            args = self.args()
            self.check_args(name, SUBSET3_SPEC[name][0], args)
            self.weight += SUBSET3_SPEC_WEIGHT
            return ('bool', 1, False)
        if self.peek() == '(' and name in self.m.members and self.m.members[name][0] in ('function', 'predicate'):
            if self.m.ghost(name):
                subset3_refuse('SYNTAX', 'ghost function in compiled code')
            info = self.m.analyse(name)
            args = self.args()
            self.check_args(name, info[1][0], args)
            self.weight += info[2]
            return (info[1][1], info[1][2], False)
        if self.peek() == '(':
            subset3_refuse('CALL', 'call of `%s` in an expression is outside the allow-list' % name)
        if name in self.env:
            entry = self.env[name]
            if entry[2]:
                subset3_refuse('SYNTAX', 'ghost local in compiled code')
            return (entry[0], max(entry[1], 1), False)
        if name in self.m.members and self.m.members[name][0] == 'const' and not self.m.ghost(name):
            info = self.m.analyse(name)
            self.weight += info[2]
            return (info[1][0], info[1][1], False)
        if name in SUBSET3_CTORS and not SUBSET3_CTORS[name][1]:
            return (SUBSET3_CTORS[name][0], 1, False)
        if name == 'MaxMoney':
            return ('int', 1, False)
        subset3_refuse('NAME', 'unknown or refused name `%s` in %s' % (name, self.name))


def bounded_subset3(code):
    """Refuse unless impl/Refund.dfy is in strict subset 3. Returns (W of Assess, largest display tree)."""
    try:
        if len(code) > SUBSET3_MAX_BYTES:
            subset3_refuse('SIZE', 'implementation larger than 65536 bytes')
        try:
            toks = subset3_tokens(code.decode('utf-8'))
        except UnicodeDecodeError:
            subset3_refuse('LEX', 'implementation is not UTF-8')
        texts = [t for _, t in toks]
        for k, (kind, text) in enumerate(toks):
            if kind == 'id' and set(re.split(r"[?']", text)) & SUBSET3_GLOBAL - {'module', 'refines', 'include'}:
                subset3_refuse('FORBIDDEN', '`' + text + '`')
            if text == '@' or text == '{' and texts[k + 1:k + 2] == [':']:
                subset3_refuse('ATTRIBUTE', 'attribute syntax outside the allowed attributes')
            if text == '{:' and not any(texts[k:k + len(a)] == a for a in SUBSET3_ATTRIBUTES):
                subset3_refuse('ATTRIBUTE', 'only {:isolate_assertions} and {:induction false} are allowed')
            if text == ':-' or texts[k:k + 2] in (['by', 'method'], ['decreases', '*']):
                subset3_refuse('FORBIDDEN', ' '.join(texts[k:k + 2]))
            if kind == 'id' and re.fullmatch(r'array[0-9]*\??|bv[0-9]+', text):
                subset3_refuse('FORBIDDEN', '`' + text + '`')
        if texts.count('module') != 1 or texts.count('include') != 1 or texts.count('refines') != 1:
            subset3_refuse('MODULE', 'exactly one module, one include, one refines')
        drop = set()
        for k in range(len(texts)):
            for a in SUBSET3_ATTRIBUTES:
                if texts[k:k + len(a)] == a:
                    drop.update(range(k, k + len(a)))
        texts = [texts[k] for k in range(len(texts)) if k not in drop]
        mod = Subset3Module(texts)
        total_const = 0
        for name, (kind, ghost, lo, hi) in mod.members.items():
            if not ghost:
                info = mod.analyse(name)
                if info[0] == 'const':
                    total_const += info[2]
        if total_const > SUBSET3_MAX_WEIGHT:
            subset3_refuse('WEIGHT', 'module constants unfold to more than %d tokens' % SUBSET3_MAX_WEIGHT)
        return mod.info['Assess'][2], mod.max_tree
    except (IndexError, StopIteration, ValueError, KeyError, TypeError, AttributeError, RecursionError) as error:
        raise Rejected('SUBSET3_SHAPE: unrecognized structure (' + type(error).__name__ + ')')


def prepare():
    for name, expected in APPROVED.items():
        if digest((ROOT / name).read_bytes()) != expected:
            raise Rejected('APPROVED_CONTRACT: ' + name + ' differs from approved bytes')
    lock = read_json(ROOT / 'spec/refund/spec.lock')
    for name, expected in lock['dependencies'].items():
        if digest((ROOT / name).read_bytes()) != expected:
            raise Rejected('APPROVED_DEPENDENCY: ' + name + ' differs')
    pins = read_json(ROOT / pin_file('dafny'))
    if (pins['verification_options'] != dafny.OPTIONS or
            pins['dafny']['version_output'] != lock['dafny_build'] or
            lock['dafny_version'] != '4.11.0'):
        raise Rejected('TOOLCHAIN_LOCK: changed verifier or proof options')
    if platform.python_version() != pins['python']['version']:
        raise RuntimeError('TOOLCHAIN_ERROR: Python version differs')
    executables = {dafny.DAFNY: pins['dafny']['executable_sha256'],
                   ROOT / pins['z3']['path']: pins['z3']['executable_sha256'],
                   Path(sys.executable): pins['python']['executable_sha256']}
    if any(digest(path.read_bytes()) != sha for path, sha in executables.items()):
        raise RuntimeError('TOOLCHAIN_ERROR: executable digest differs')
    code = (ROOT / 'impl/Refund.dfy').read_bytes()
    prefix = b'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
    if not code.startswith(prefix) or code.count(b'include') != 1:
        raise Rejected('SOURCE_SCOPE: exact approved refinement and sole include required')
    # Input restrictions only. Dafny parses, verifies and audits the source.
    if b'{:' in code.replace(b'{:isolate_assertions}', b'') or b'@' in code:
        raise Rejected('SOURCE_SCOPE: only assertion-isolation attributes allowed')
    # Strict core subset (rule 3; cost claim above bounded_subset3): straight-line compiled code over if/match,
    # no loop, no recursion, no growth operator, no extra module, no shadowing. Unknown forms are refused.
    bounded_subset3(code)
    if b'include' in (ROOT / BINDING).read_bytes().replace(b'include paths', b''):
        raise Rejected('SOURCE_SCOPE: the trusted binding must add no include')
    return pins, executables


def identity(tier):
    names = SOURCE_FILES + (('ts/refund.ts',) if tier == 'hostile-tests' else ())
    manifest = [{'path': name, 'sha256': digest((ROOT / name).read_bytes())}
                for name in sorted(names)]
    claims = CLAIMS if tier == 'critical' else TEST_CLAIMS
    spec = 'spec/refund/RefundSpec.dfy' if tier == 'critical' else 'spec/refund/protocol.md'
    return {'artifact': {'kind': 'source', 'sha256': digest(canonical(manifest)), 'build_cmd': ''},
            'source_manifest': manifest,
            'claims': [{'id': key, 'statement_plain_english': text,
                        'spec_ref': spec, 'spec_sha': APPROVED[spec]}
                       for key, text in claims.items()]}


def prove(pins, work, records):
    version = run([str(dafny.DAFNY), '--version'], work, 'dafny-version', records)
    if version.returncode or version.stdout.decode().strip() != pins['dafny']['version_output']:
        raise RuntimeError('TOOLCHAIN_ERROR: Dafny version command failed or differed')
    z3 = run([str(ROOT / pins['z3']['path']), '--version'], work, 'z3-version', records)
    if z3.returncode or z3.stdout.decode().strip() != pins['z3']['version_output']:
        raise RuntimeError('TOOLCHAIN_ERROR: Z3 version command failed or differed')
    audit_file = work / 'audit.md'
    audit_file.write_bytes(dafny.AUDIT.read_bytes())
    audit = run([str(dafny.DAFNY), 'audit', 'impl/Refund.dfy', BINDING,
                 '--report-format', 'md', '--report-file', str(audit_file), '--compare-report'],
                work, 'audit-before', records)
    if audit.returncode:
        raise Rejected('AUDIT_REJECTED: actual Dafny audit failed; inspect retained output')
    report = work / 'verification.trx'
    verified = run([str(dafny.DAFNY), 'verify', 'impl/Refund.dfy', BINDING,
                    *dafny.OPTIONS, '--json-output', '--log-format',
                    'trx;LogFileName=' + str(report)], work, 'verify', records)
    if verified.returncode:
        raise Rejected('VERIFICATION_REJECTED: R1 R2 R3 R4 R5 not established; inspect retained diagnostics')
    rows = sorted(({'name': e.get('testName'), 'outcome': e.get('outcome')}
                   for e in ET.parse(report).iter() if e.tag.endswith('UnitTestResult')),
                  key=lambda row: row['name'])
    members = {re.sub(r' \(assertion batch \d+\)$', '', row['name']) for row in rows}
    if not REQUIRED <= members or any(row['outcome'] != 'Passed' for row in rows):
        raise Rejected('PROOF_COVERAGE: concrete method, abstract contract, universal binding or witness missing')
    return rows


def hostile(pins, work, records):
    sys.path.insert(0, str(ROOT))
    from scripts.javascript_env import check as check_javascript
    js_pins = check_javascript()
    # Fixed generated paths give stable build provenance. The main lock excludes
    # concurrent gate builds. Existing historical operation directories survive.
    directory = ROOT / 'build/refund-generated'
    directory.mkdir(parents=True, exist_ok=True)
    for name in ('model.js', 'model.cjs'):
        (directory / name).unlink(missing_ok=True)
    command = [str(dafny.DAFNY), 'build', 'impl/Refund.dfy', '--target', 'js',
               '--output', 'build/refund-generated/model', *dafny.OPTIONS]
    built = run(command, work, 'compile-js', records)
    if built.returncode:
        raise RuntimeError('BUILD_ERROR: actual Dafny compilation failed')
    generated = (directory / 'model.js').read_bytes()
    module = generated + FOOTER
    module_path = directory / 'model.cjs'
    module_path.write_bytes(module)
    # Preserve each generated artifact beside its exact command and full logs.
    (work / 'model.js').write_bytes(generated)
    (work / 'model.cjs').write_bytes(module)
    report_path = work / 'hostile.json'
    tested = run(['node', '--import', 'tsx', TEST, '--module', relative(module_path),
                  '--report', relative(report_path)], work, 'hostile', records)
    if tested.returncode:
        raise Rejected('HOSTILE_REJECTED: test process failed; inspect retained report and shrink')
    report = read_json(report_path)
    expected_runs = [{'claim_id': claim, 'seed': seed, 'num_runs': 1000, 'failed': False}
                     for claim in TEST_CLAIMS for seed in (8001, 8002, 8003)]
    if (report.get('result') != 'passed' or report.get('method') != 'property_tested' or
            report.get('runs') != expected_runs or report.get('generated_cases') != 9000 or
            report.get('fixture_cases', 0) < 20 or report.get('model_quality') != 'unmeasured'):
        raise Rejected('TEST_COVERAGE: missing actual seeded runs or concrete fixtures')
    if digest(module_path.read_bytes()) != digest(module):
        raise Rejected('INPUT_CHANGED: compiled module changed during tests')
    if check_javascript() != js_pins:
        raise Rejected('INPUT_CHANGED: JavaScript toolchain changed')
    return {'report': report, 'generated_js_sha256': digest(generated),
            'module_sha256': digest(module), 'export_footer_sha256': digest(FOOTER),
            'build_command': ['.toolchain/dafny-4.11.0/dafny/dafny', *command[1:]],
            'source_to_module_proved': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--tier', choices=('critical', 'hostile-tests'), default='critical')
    parser.add_argument('--evidence', default='build/refund-source.json')
    parser.add_argument('--check-evidence')
    args = parser.parse_args()
    output = (ROOT / args.evidence).resolve()
    supplied_path = (ROOT / args.check_evidence).resolve() if args.check_evidence else None
    if (not output.is_relative_to(ROOT / 'build') or output.suffix != '.json' or
            output == supplied_path or output.is_relative_to(ROOT / 'build/refund-generated')):
        raise Rejected('OUTPUT_SCOPE: use a separate JSON output under build/')
    # Never leave a stale passing bundle after a failed recheck.
    output.unlink(missing_ok=True)
    (ROOT / 'build').mkdir(exist_ok=True)
    lock_path = ROOT / 'build/refund-gate.lock'
    with lock_path.open('x'):
        pass
    try:
        versions = check_dependencies()
        from core import snapshot, make_bundle, validate_evidence
        from jsonschema import Draft202012Validator
        pins, executables = prepare()
        expected = identity(args.tier)
        paths = [ROOT / name for name in (*APPROVED, *COMMON_INPUTS, *SOURCE_FILES)]
        if args.tier == 'hostile-tests':
            paths += [ROOT / name for name in (*JS_INPUTS, 'ts/refund.ts')]
        if any(path.is_symlink() for path in paths):
            raise Rejected('SOURCE_SCOPE: declared inputs must be regular files')
        before = snapshot(paths)
        source_names = {entry['path'] for entry in expected['source_manifest']}
        trusted = {name: sha for name, sha in before.items() if name not in source_names}
        policy = read_json(ROOT / 'policy/refund.yaml')
        Draft202012Validator(read_json(ROOT / 'schemas/policy.schema.json')).validate(policy)
        rules = policy['tiers'][args.tier]
        method = 'source_proof' if args.tier == 'critical' else 'property_tested'
        claims = CLAIMS if args.tier == 'critical' else TEST_CLAIMS
        if (set(rules['required_claims']) != set(claims) or
                any(rule != {'minimum_method': method, 'allowed_methods': [method]}
                    for rule in rules['required_claims'].values())):
            raise Rejected('METHOD_POLICY: exact separate proof and test requirements are mandatory')
        policy_id = {'id': policy['id'], 'version': policy['version'], 'tier': args.tier,
                     'sha256': APPROVED['policy/refund.yaml']}
        backend = 'dafny-refund' if args.tier == 'critical' else 'refund-hostile-tests'
        supplied = read_json(supplied_path) if supplied_path else None
        if supplied is not None:
            validate_evidence(supplied, expected, rules, policy_id, trusted, backend)
        work = Path(tempfile.mkdtemp(prefix='refund-gate-', dir=ROOT / 'build'))
        records = []
        rows = prove(pins, work, records)
        details = {'verified_obligations': [row['name'] for row in rows],
                   'verification_options': dafny.OPTIONS, 'proof_result_cache': False,
                   'arbitrary_input_binding_checked': True, 'successful_witness_checked': True,
                   'model_quality': {'status': 'unmeasured', 'score': None},
                   'source_artifact': identity('critical')['artifact']}
        if args.tier == 'hostile-tests':
            details['integration'] = hostile(pins, work, records)
        # Fresh final audit. No accepted result may depend on an audit escape.
        final_audit = work / 'final-audit.md'
        final_audit.write_bytes(dafny.AUDIT.read_bytes())
        audited = run([str(dafny.DAFNY), 'audit', 'impl/Refund.dfy', BINDING,
                       '--report-format', 'md', '--report-file', str(final_audit), '--compare-report'],
                      work, 'audit-after', records)
        if audited.returncode:
            raise Rejected('AUDIT_REJECTED: final actual audit failed')
        details['audit_sha256'] = digest(final_audit.read_bytes())
        assumptions = [
            'Dafny mathematical integers, finite strings and sequential pure calls; all typed contexts and responses are covered.',
            'No model accuracy assumption; allowed reason membership does not establish factual truth.',
            'Host data truth, authentication, atomic remaining-balance reservation and durable payment idempotency are external obligations.',
            'Source proof does not cover compilation, parsing, clocks, scheduling, transport, effect dispatch, persistence or deployment.',
        ]
        if args.tier == 'hostile-tests':
            assumptions += [
                'Only the recorded finite fast-check corpus and concrete fixtures were executed; no universal runtime theorem.',
                'The supplied logical monotonic clock tests host event handling, not physical deadline delivery or a real model/network.',
                'Dafny JavaScript compilation, BigNumber conversion and host runtime preservation remain unproved.',
                'The fixed ts/refund.ts adapter and pinned packages are the declared integration scope; arbitrary host-code compromise is excluded.',
            ]
        reproduce = 'python3 gate/refund.py --tier ' + args.tier + ' --evidence build/refund-' + args.tier + '.json'
        raw = {**expected, 'backend_details': details, 'evidence': [{
            'claim_id': claim, 'artifact_sha': expected['artifact']['sha256'], 'method': method,
            'tool': 'Dafny' if args.tier == 'critical' else 'fast-check',
            'tool_version': pins['dafny']['version_output'] if args.tier == 'critical' else '4.3.0',
            'result': 'passed', 'producer': 'forge/local-refund-gate', 'reproduce_cmd': reproduce,
            'assumptions': assumptions,
            'trusted_base': ['Dafny ' + pins['dafny']['version_output'],
                             'Bundled Boogie, .NET and Z3 4.12.1; no independent proof certificate kernel is claimed.',
                             'Approved refund contract, protocol, policy, lock, gate, binding and empty audit baseline.',
                             'Python 3.10.11; pinned Node/npm packages for integration tests where executed.',
                             'Host operating system, runtime libraries and hardware; executable pins do not authenticate the full host.'],
        } for claim in claims]}
        bundle = make_bundle(raw, backend, policy_id, trusted, versions, reproduce)
        validate_evidence(bundle, expected, rules, policy_id, trusted, backend)
        if supplied is not None and canonical(supplied) != canonical(bundle):
            raise Rejected('REPRODUCTION_MISMATCH: supplied evidence differs from fresh checks')
        if before != snapshot(paths) or any(digest(p.read_bytes()) != sha for p, sha in executables.items()):
            raise Rejected('INPUT_CHANGED: source, trusted input or executable changed while checking')
        check_dependencies()
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(canonical(bundle))
        (work / 'accepted.json').write_bytes(canonical(bundle))
        print('ACCEPTED: ' + ' '.join(claims) + '; ' + method + '; end_to_end=false')
        return 0
    finally:
        lock_path.unlink()


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Rejected as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError, KeyError, RuntimeError, ImportError, ET.ParseError) as error:
        print('GATE_ERROR: ' + str(error), file=sys.stderr)
        sys.exit(2)
