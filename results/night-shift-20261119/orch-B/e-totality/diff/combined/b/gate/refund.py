#!/usr/bin/env python3
"""Fresh refund source proof and separate finite integration-test evidence.

Run this file from gate/refund.py only after exact approval. Evidence is not a
signature. The caller must supply this gate and its inputs from a trusted base.
"""

import argparse
import os
from pathlib import Path
import platform
import re
import resource
import shlex
import signal
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
# Fail closed: a `//` comment ends at the earliest possible line break (Dafny 4.11 ends it at a lone CR).
LINE_END = re.compile('[\r\n\x0b\x0c\x85\u2028\u2029]')
CHAR = re.compile(r"'(\\U\{[0-9A-Fa-f_]{1,8}\}|\\u[0-9A-Fa-f]{4}|\\[^\r\n]|[^'\\\r\n])'")


def code_words(code):
    """Words of Dafny source outside comments and literals; block comments nest. Unsure input fails closed."""
    try:
        text = code.decode('utf-8')
    except UnicodeDecodeError:
        raise Rejected('SOURCE_SCOPE: implementation is not UTF-8')
    words, i, n = [], 0, len(text)
    while i < n:
        if text.startswith('//', i):
            end = LINE_END.search(text, i)
            i = n if end is None else end.start()
        elif text.startswith('/*', i):
            depth, i = 1, i + 2
            while depth:
                if i >= n:
                    raise Rejected('SOURCE_SCOPE: unterminated comment')
                step = 1 if text[i:i + 2] not in ('/*', '*/') else 2
                depth += {'/*': 1, '*/': -1}.get(text[i:i + 2], 0)
                i += step
        elif text[i] == '"' or text.startswith('@"', i):
            verbatim, i = text[i] == '@', i + (2 if text[i] == '@' else 1)
            while True:
                if i >= n or (not verbatim and text[i] in '\r\n'):
                    raise Rejected('SOURCE_SCOPE: unterminated string')
                if verbatim and text.startswith('""', i) or not verbatim and text[i] == '\\':
                    i += 2
                elif text[i] == '"':
                    i += 1
                    break
                else:
                    i += 1
        elif text[i] == "'":
            literal = CHAR.match(text, i)
            if not literal:
                raise Rejected('SOURCE_SCOPE: unrecognized character literal')
            i = literal.end()
        elif re.match('[A-Za-z_]', text[i]):
            word = re.compile(r"[A-Za-z0-9_?']*").match(text, i + 1).end()
            words += re.split(r"[?']", text[i:word])
            i = word
        else:
            i += 1
    return words


# Bounds on every child process. The gate never waits without a bound for a submission-dependent step.
# A step that reaches its wall-clock bound, ends by a signal, or writes more than OUTPUT_BYTES to stdout
# or stderr gives a refusal with the distinct reason RESOURCE_LIMIT. Its whole process group is killed.
STEP_SECONDS = {'dafny-version': 60, 'z3-version': 60, 'audit-before': 900, 'verify': 3600,
                'compile-js': 1800, 'hostile': 1800, 'audit-after': 900}
OUTPUT_BYTES = 64 * 1024 * 1024


def child_limits():
    # The kernel stops each file write of the child and its descendants after OUTPUT_BYTES + 1 bytes.
    resource.setrlimit(resource.RLIMIT_FSIZE, (OUTPUT_BYTES + 1, OUTPUT_BYTES + 1))


def run(command, work, name, records):
    stdout, stderr = work / (name + '.stdout'), work / (name + '.stderr')
    with stdout.open('wb') as out, stderr.open('wb') as err:
        child = subprocess.Popen(command, cwd=ROOT, stdin=subprocess.DEVNULL, stdout=out, stderr=err,
                                 start_new_session=True, preexec_fn=child_limits)
        try:
            code = child.wait(timeout=STEP_SECONDS[name])
        except subprocess.TimeoutExpired:
            code = None
        finally:
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except (ProcessLookupError, PermissionError):
                pass
            child.wait()
    output, errors = stdout.read_bytes(), stderr.read_bytes()
    records.append({'argv': command, 'cwd': '.', 'exit_code': code,
                    'stdout': relative(stdout), 'stdout_sha256': digest(output),
                    'stderr': relative(stderr), 'stderr_sha256': digest(errors)})
    (work / 'operations.json').write_bytes(canonical({'commands': records,
                                                    'stage_exit': False}))
    print(name + ': exit ' + str(code), flush=True)
    if code is None:
        raise Rejected('RESOURCE_LIMIT: ' + name + ' reached the wall-clock bound of '
                       + str(STEP_SECONDS[name]) + ' s; process group killed; no verdict')
    if code < 0:
        raise Rejected('RESOURCE_LIMIT: ' + name + ' ended by signal ' + str(-code) + '; no verdict')
    if max(len(output), len(errors)) > OUTPUT_BYTES:
        raise Rejected('RESOURCE_LIMIT: ' + name + ' wrote more than ' + str(OUTPUT_BYTES) + ' bytes; no verdict')
    return subprocess.CompletedProcess(command, code, output, errors)


# Bounded straight-line subset (SUBSET_*). A refund implementation must be a straight-line decision:
# no loops, no recursion, no comprehension or such-that, no growth operation without a literal bound.
# The rule works on tokens and fails closed: an unknown shape is a refusal with a reason code.
SUBSET_LINE_END = re.compile('[\r\n\x0b\x0c\x85  ]')
SUBSET_CHAR = re.compile(r"'(\\U\{[0-9A-Fa-f_]{1,8}\}|\\u[0-9A-Fa-f]{4}|\\[^\r\n]|[^'\\\r\n])'")
SUBSET_NUM = re.compile(r'0x[0-9A-Fa-f_]+|[0-9][0-9_]*(\.[0-9][0-9_]*)?')
SUBSET_ID = re.compile(r"[A-Za-z_][A-Za-z0-9_?']*")
SUBSET_OPS = ('<==>', '==>', '<==', '-->', ':=', ':|', ':-', '::', '==', '!=', '<=', '>=', '&&', '||',
              '..', '=>', '->', '~>', '!!', '{:')
SUBSET_GLOBAL = {'expect', 'assume', 'print', 'new', 'class', 'trait', 'iterator', 'import', 'export',
                 'opened', 'abstract', 'extern', 'axiom', 'codatatype', 'newtype', 'type', 'datatype',
                 'object', 'yield', 'modify', 'label', 'twostate', 'least', 'greatest', 'inductive',
                 'copredicate', 'colemma', 'constructor', 'iset', 'imap', 'ORDINAL'}
SUBSET_EXEC = {'while', 'for', 'forall', 'exists', 'set', 'multiset', 'map', 'by', 'break', 'continue',
               'old', 'fresh', 'unchanged', 'allocated', 'this', 'method', 'function', 'predicate', 'lemma',
               'const', 'static', 'requires', 'ensures', 'reads', 'invariant', 'decreases', 'modifies'}
SUBSET_EXPR_KEYWORDS = {'return', 'then', 'else', 'in', 'case', 'if', 'match', 'assert', 'var'}
SUBSET_RECORDS = {'Intent', 'Authorized', 'Candidate', 'ChargeContext'}
SUBSET_NULLARY = {'true', 'false', 'Rejected', 'Missing', 'TimedOut', 'Failed', 'Malformed', 'Oversized',
                  'Unsupported'}
SUBSET_SPEC = {'Eligible', 'ValidContext', 'Money', 'AllowedReason'}
SUBSET_SPEC_WEIGHT = 128     # upper bound on the unfolded tokens of one call of a pinned spec predicate
SUBSET_MAX_WEIGHT = 4096     # bound N on executed tokens of one Assess call (unfolded over calls)
SUBSET_MAX_BYTES = 65536
SUBSET_MAX_DISPLAY = 16


def subset_refuse(code, message):
    raise Rejected('SUBSET_' + code + ': ' + message)


def subset_tokens(text):
    """All tokens outside comments as (kind, text). Comments end at the earliest line break (fail closed)."""
    tokens, i, n = [], 0, len(text)
    while i < n:
        c = text[i]
        if text.startswith('//', i):
            end = SUBSET_LINE_END.search(text, i)
            i = n if end is None else end.start()
        elif text.startswith('/*', i):
            depth, i = 1, i + 2
            while depth:
                if i >= n:
                    subset_refuse('LEX', 'unterminated comment')
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
                    subset_refuse('LEX', 'unterminated string')
                if verbatim and text.startswith('""', i) or not verbatim and text[i] == '\\':
                    i += 2
                elif text[i] == '"':
                    i += 1
                    break
                else:
                    i += 1
            if i - start > 256:
                subset_refuse('LITERAL_SIZE', 'string literal longer than 256 characters')
            tokens.append(('str', text[start:i]))
        elif c == "'":
            literal = SUBSET_CHAR.match(text, i)
            if not literal:
                subset_refuse('LEX', 'unrecognized character literal')
            tokens.append(('char', literal.group(0)))
            i = literal.end()
        elif SUBSET_ID.match(text, i) and c.isascii():
            word = SUBSET_ID.match(text, i).group(0)
            tokens.append(('id', word))
            i += len(word)
        elif c.isdigit() and c.isascii():
            number = SUBSET_NUM.match(text, i).group(0)
            if len(number) > 40:
                subset_refuse('LITERAL_SIZE', 'numeric literal longer than 40 characters')
            tokens.append(('num', number))
            i += len(number)
        elif c.isascii() and c.isprintable():
            op = next((o for o in SUBSET_OPS if text.startswith(o, i)), c)
            tokens.append(('op', op))
            i += len(op)
        else:
            subset_refuse('LEX', 'character U+%04X outside comments and literals' % ord(c))
    return tokens


def subset_match(toks, k):
    """Index of the bracket that closes toks[k]."""
    pairs, depth = {'(': ')', '[': ']', '{': '}'}, 0
    opener, closer = toks[k][1], pairs[toks[k][1]]
    for j in range(k, len(toks)):
        depth += (toks[j][1] == opener) - (toks[j][1] == closer)
        if depth == 0:
            return j
    subset_refuse('SHAPE', 'unbalanced ' + opener)


def subset_literal_operand(toks, k, plus):
    """True if an operand of the operator at k is an integer literal, so the operation is integer arithmetic
    that adds at most a constant number of bits. For `+` (also sequence concatenation) a length |e| or a
    parenthesized `if` whose else branch is a literal also types the operand as an integer."""
    texts = [t for _, t in toks]
    right = toks[k + 1][0] == 'num' and texts[k + 2] not in ('(', '[', '.')
    left = toks[k - 1][0] == 'num' and texts[k - 2] not in ('.', '*', '/', '%')
    if right or left or not plus:
        return right or left
    if texts[k - 1] == '|' or texts[k + 1] == '|':
        return True
    if texts[k - 1] == ')' and toks[k - 2][0] == 'num' and texts[k - 3] == 'else':
        return True
    if texts[k + 1] == '(':
        close = subset_match(toks, k + 1)
        return texts[k + 2] == 'if' and toks[close - 1][0] == 'num' and texts[close - 2] == 'else'
    return False


def subset_flat_element(e, tuple_element):
    """An element whose value cannot hold a sequence or tuple built by the submission (bounded nesting).
    A tuple element may also be one sequence display; that display's own elements are checked separately."""
    texts = [t for _, t in e]
    whole = len(e) >= 3 and e[1][1] == '(' and subset_match(e, 1) == len(e) - 1
    depth, boolean = 0, False
    for t in texts:
        depth += (t in ('(', '[', '{')) - (t in (')', ']', '}'))
        boolean |= depth == 0 and t in ('<=', '>=', '==', '!=', '&&', '||', '==>', '<==>', 'in')
    return (len(e) == 1 and (e[0][0] in ('num', 'str', 'char') or texts[0] in SUBSET_NULLARY) or
            whole and texts[0] in SUBSET_RECORDS | SUBSET_SPEC or boolean or
            tuple_element and texts[:1] == ['['] and subset_match(e, 0) == len(e) - 1)


def subset_words(tok):
    return set(re.split(r"[?']", tok[1])) if tok[0] == 'id' else set()


def straight_line_subset(code):
    """Refuse unless impl/Refund.dfy is in the bounded straight-line subset. Returns the bound N."""
    try:
        return subset_check(code)
    except (IndexError, StopIteration, ValueError, KeyError) as error:
        raise Rejected('SUBSET_SHAPE: unrecognized structure (' + type(error).__name__ + ')')


def subset_check(code):
    if len(code) > SUBSET_MAX_BYTES:
        subset_refuse('SIZE', 'implementation larger than 65536 bytes')
    try:
        toks = subset_tokens(code.decode('utf-8'))
    except UnicodeDecodeError:
        subset_refuse('LEX', 'implementation is not UTF-8')
    texts = [t for _, t in toks]
    for k, tok in enumerate(toks):
        if subset_words(tok) & SUBSET_GLOBAL:
            subset_refuse('FORBIDDEN', '`' + tok[1] + '`')
        if tok[1] == '@' or tok[1] == '{' and texts[k + 1:k + 2] == [':']:
            subset_refuse('ATTRIBUTE', 'attribute syntax outside {:isolate_assertions}')
        if tok[1] == '{:' and texts[k + 1:k + 3] != ['isolate_assertions', '}']:
            subset_refuse('ATTRIBUTE', 'only {:isolate_assertions} is allowed')
        if tok[1] == ':-' or texts[k:k + 2] in (['by', 'method'], ['decreases', '*']):
            subset_refuse('FORBIDDEN', ' '.join(texts[k:k + 2]))
        if tok[0] == 'id' and (re.fullmatch(r'array[0-9]*\??|bv[0-9]+', tok[1])):
            subset_refuse('FORBIDDEN', '`' + tok[1] + '`')
    keep = [k for k in range(len(toks)) if not (texts[k] == '{:' or texts[k - 1:k + 1] == ['{:', 'isolate_assertions']
                                              or texts[k - 2:k + 1] == ['{:', 'isolate_assertions', '}'])]
    toks = [toks[k] for k in keep]
    texts = [texts[k] for k in keep]
    if (texts[:7] != ['include', '"../spec/refund/RefundSpec.dfy"', 'module', 'Refund', 'refines',
                      'RefundSpec', '{'] or subset_match(toks, 6) != len(toks) - 1 or
            texts.count('module') != 1 or texts.count('refines') != 1 or texts.count('include') != 1):
        subset_refuse('SHAPE', 'exactly one include and one module Refund refines RefundSpec, nothing else')
    modifiers, kinds = {'ghost', 'static', 'opaque'}, {'function', 'predicate', 'method', 'lemma', 'const'}
    members, k, end = [], 7, len(toks) - 1
    while k < end:
        start, mods = k, set()
        while texts[k] in modifiers:
            mods.add(texts[k])
            k += 1
        if texts[k] not in kinds:
            subset_refuse('DECLARATION', 'unsupported module member at `' + texts[k] + '`')
        kind, k = texts[k], k + 1
        if texts[k] == 'method':
            subset_refuse('DECLARATION', 'legacy function method')
        name, j = texts[k], k + 1
        while j < end and texts[j] not in modifiers | kinds:
            j = subset_match(toks, j) + 1 if texts[j] in '([{' else j + 1
        ghost = kind == 'lemma' or 'ghost' in mods
        members.append((kind, name, ghost, k + 1, j))
        k = j
    compiled = {m[1]: m for m in members if not m[2]}
    ghost_calls = {m[1] for m in members if m[2] and m[0] in ('lemma', 'method')}
    methods = {m[1] for m in members if not m[2] and m[0] == 'method'}
    if compiled.get('Assess', ('',))[0] != 'method':
        subset_refuse('SHAPE', 'no compiled method Assess')

    def ghost_statement(k, hi):
        j, word = k, texts[k]
        if word == 'ghost' and texts[k + 1] != 'var':
            subset_refuse('GHOST', 'ghost statement other than ghost var')
        while j < hi:
            if texts[j] == '{' and (word == 'calc' or texts[j - 1] == 'by'):
                j = subset_match(toks, j) + 1
                break
            if texts[j] in '([{':
                j = subset_match(toks, j)
            elif texts[j] == ';':
                j += 1
                break
            j += 1
        else:
            subset_refuse('GHOST', 'ghost statement without end')
        if {texts[x] for x in range(k, j)} & methods:
            subset_refuse('GHOST', 'a ghost statement names a compiled method')
        return j

    def executable(lo, hi):
        out, blocks, cases, k = [], set(), 0, lo
        while k < hi:
            kind, text = toks[k]
            prev = texts[k - 1]
            nxt = texts[k + 1:k + 3] + ['', '']
            if text in ('assert', 'reveal', 'hide', 'calc', 'ghost') or (
                    text in ghost_calls and nxt[0] == '('):
                k = ghost_statement(k, hi)
                continue
            if subset_words(toks[k]) & SUBSET_EXEC:
                subset_refuse('EXEC_FORBIDDEN', '`' + text + '` in compiled code')
            if text == 'seq' and nxt[0] == '(':
                subset_refuse('EXEC_FORBIDDEN', 'seq constructor in compiled code')
            if text in (':|', '::', '->', '~>', '-->', '!!'):
                subset_refuse('EXEC_FORBIDDEN', '`' + text + '` in compiled code')
            base = text.split('?')[0]
            if kind == 'id' and nxt[0] != '(' and (base in SUBSET_SPEC or base in compiled and
                                                     compiled[base][0] != 'const'):
                subset_refuse('FUNCTION_VALUE', 'function used as a value in compiled code: ' + text)
            if text == 'case':
                cases += 1
            if text == '=>':
                if not cases:
                    subset_refuse('LAMBDA', 'lambda in compiled code')
                cases -= 1
            if text in ('+', '*', '/', '%') and kind == 'op' and not subset_literal_operand(toks, k, text == '+'):
                subset_refuse('ARITHMETIC', '`' + text + '` needs an integer literal operand')
            if text in ('if', 'match'):
                j = k + 1
                while j < hi and texts[j] not in ('{', 'then', 'case'):
                    j = subset_match(toks, j) + 1 if texts[j] in '([' else j + 1
                if j < hi and texts[j] == '{':
                    blocks.add(j)
            if text == '{' and k not in blocks and prev not in ('{', '}', ';', '=>', 'else'):
                subset_refuse('BRACE', 'set or map display, or an unsupported block, in compiled code')
            callish = toks[k - 1][0] in ('id', 'str') and prev not in SUBSET_EXPR_KEYWORDS or prev in (')', ']')
            if text in ('(', '[') and not callish:
                close, j, elements = subset_match(toks, k), k + 1, []
                while j < close:
                    first = j
                    while j < close and texts[j] != ',':
                        j = subset_match(toks, j) + 1 if texts[j] in '([{' else j + 1
                    elements.append(toks[first:j])
                    j += 1
                if text == '[' and len(elements) > SUBSET_MAX_DISPLAY:
                    subset_refuse('DISPLAY', 'sequence display with more than 16 elements')
                if text == '[' or len(elements) > 1:
                    for e in elements:
                        if not subset_flat_element(e, text == '('):
                            subset_refuse('DISPLAY' if text == '[' else 'TUPLE', 'a display or tuple element '
                                          'must be a literal, a spec record, a boolean or a nullary constructor')
            out.append(k)
            k += 1
        return out

    weights, calls = {}, {}
    for kind, name, ghost, lo, hi in compiled.values():
        if kind == 'const':
            if ':=' not in texts[lo:hi]:
                subset_refuse('SHAPE', 'compiled const without initializer')
            region = (texts.index(':=', lo) + 1, hi)
        else:
            if texts[hi - 1] != '}':
                subset_refuse('SHAPE', 'compiled ' + kind + ' ' + name + ' without body')
            body = next(x for x in range(lo, hi) if texts[x] == '{' and subset_match(toks, x) == hi - 1)
            header = set(texts[lo:body])
            if header & {':=', '->', '~>', '-->'}:
                subset_refuse('HEADER', 'default value or function type in a compiled signature')
            region = (body + 1, hi - 1)
        out = executable(*region)
        words = [texts[x].split('?')[0] for x in out if toks[x][0] == 'id']
        calls[name] = [w for w in words if w in compiled]
        weights[name] = len(out) + SUBSET_SPEC_WEIGHT * sum(w in SUBSET_SPEC for w in words)
    for kind, name, ghost, lo, hi in members:
        if ghost and texts[hi - 1] != '}' and kind != 'const':
            subset_refuse('SHAPE', 'ghost ' + kind + ' ' + name + ' without body')
    total, state = {}, {}

    def unfold(name):
        if state.get(name) == 'open':
            subset_refuse('RECURSION', 'call cycle through ' + name)
        if name not in total:
            state[name] = 'open'
            total[name] = weights[name] + sum(unfold(callee) for callee in calls[name])
            state[name] = 'done'
        return total[name]

    for name in compiled:
        if unfold(name) > SUBSET_MAX_WEIGHT:
            subset_refuse('SIZE', name + ' unfolds to more than 4096 executed tokens')
    return total['Assess']


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
    # Dafny assumes an `expect` condition when it verifies and halts the program at run time when the
    # condition is false. A verified Assess with `expect` can halt instead of returning a decision. The
    # keyword covers `expect E;`, `expect E, m;` and `:- expect`. Other halts (resources) stay test-only.
    if 'expect' in code_words(code):
        raise Rejected('SOURCE_SCOPE: run-time halt statement expect is not allowed')
    # Termination by construction (SUBSET.md): a straight-line decision with no loop, recursion,
    # comprehension, such-that or unbounded growth in compiled code. Unsure shapes are refused.
    straight_line_subset(code)
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
