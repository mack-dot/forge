#!/usr/bin/env python3
"""Spec clearing (master idea items F1.1 and F1.3). Dispatch only.

For one SUBJECT (a specification, or a pair of specifications) this tool starts the pinned Dafny with
the gate's options on the subject's Dafny files, and reads exit codes and per-member results. It
decides no proof, parses no specification and holds no rule of any specification.

A CLAIM is one Dafny lemma: "no choice" (two allowed results for one input are equal) or "agree" (two
specifications allow the same result for every input).

  claim proved by Dafny, the INSTANCE check passes,
  and the SPECIFICATION PROBE passes                  -> NO_CHOICE / EQUIVALENT
  claim rejected, and ONLY the claim                  -> not a result. Concrete CANDIDATES are tried:
      Dafny verifies a candidate's witness (INSTANCE) -> CHOICE / DIVERGES (one concrete, proved input)
      no candidate is verified                        -> UNDECIDED (never a pass)
  anything else                                       -> LINK_BROKEN

Every check of Dafny files in this tool is: `dafny verify` with the gate options, and `dafny audit`
against the empty baseline. The audit gets EVERY file that the checked files reach through `include`:
Dafny's audit reports only on the files of its command line (review finding F1). The word `expect` and
the attribute `{:options` are refused in all those files: an `expect` statement makes Dafny assume a
condition without a proof, and neither the verifier nor the audit reports it (review finding F2).

The INSTANCE check. The clearing modules are abstract Dafny modules (they import the abstract
specification). Inside an abstract module the pinned Dafny accepts a lemma that has NO BODY, and its
audit reports nothing: a claim could be "proved" by a call of such a lemma. So no verdict rests on an
abstract module alone. For every module that holds a required member, this tool WRITES a non-abstract
module that refines it (the subject only says which implementation each import is bound to). Dafny must
verify that file with exit 0 and an empty audit. In a non-abstract module a lemma without a body is
reported by the audit, and without {:axiom} also by the verifier.

The SPECIFICATION PROBE (review finding F3). The two-run lemma is proved for each refinement of a
specification taken alone. If the specification leaves a DEFINITION open (a function without a body),
two refinements can define it differently and return different results. The tool writes a non-abstract
module that refines the specification with nothing added, and asks the Dafny compiler which
declarations have no body. They must be exactly the specified methods that the subject names. NOT
detected by this probe: a GHOST function or predicate without a body, a constant without a value, an
opaque type. NO_CHOICE therefore means: no choice for each refinement taken alone, and no compiled
definition left open.

Candidates. 'solver': values read from the text that Dafny prints with --extract-counterexample for the
rejected claim. Dafny itself warns that this text can be invalid. 'supplied': values, or a whole witness
file, named in the subject. A candidate of either kind is a guess. It counts only when the pinned Dafny
verifies the witness made from it.

Text matching in this file (include lines, the two refused words, counterexample text, the compiler's
"has no body" lines) can lose a candidate or refuse an input. It cannot make a pass verdict: for that,
Dafny's exit codes on the files are necessary.

NOT checked by this tool: that a hand-written claim lemma states the right claim, and that a forward
link calls the specified method. A person must read those short Dafny files and the subject list.
"""

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
from common import canonical, digest  # noqa: E402
from backends import dafny  # noqa: E402  (the gate's own Dafny path and options)

SCOPE = {
    'NO_CHOICE': 'Universal: for every typed input in the Dafny model that satisfies the precondition of the specified '
                 'method (unbounded integers, finite maps, sequences and strings), each refinement of the specification '
                 'allows at most one result, and the specification leaves no compiled function, predicate or method '
                 'without a body except the specified method. Source level. No bounded search. Not checked: ghost '
                 'definitions without a body, constants without a value, opaque types.',
    'CHOICE': 'One concrete input, proved: two modules that the pinned Dafny accepts as refinements of the '
              'specification return different results for it. Nothing is said about other inputs.',
    'EQUIVALENT': 'Universal: for every typed input in the Dafny model, the two specifications allow the same result. '
                  'Inputs and results of the two sides are matched by mappings that Dafny proves to be one-to-one and '
                  'onto (the mapping members named in the subject). Source level. No bounded search.',
    'DIVERGES': 'One concrete input, proved: every result that the old specification allows and every result that '
                'the new one allows are the two stated results, and they differ. Nothing is said about other inputs.',
    'UNDECIDED': 'No statement. The claim was not proved and no candidate was verified.',
    'LINK_BROKEN': 'No statement. A clearing input itself did not pass (a link from Post to the specification, an '
                   'instance, the audit of a reached file, a refused word, the specification probe, or a mapping proof).',
}
INCLUDE = re.compile(r'include\s*"([^"\\\n]*)"')
REFUSED = (('the word `expect`', re.compile(r'\bexpect\b')), ('the attribute {:options', re.compile(r'\{:options')))
NO_BODY = re.compile(r'Error: (?:Method|Function|Predicate|Constructor|Iterator|Lemma) (\S+) has no body so it cannot be compiled')
NAME = re.compile(r'^[A-Za-z_][A-Za-z0-9_]*$')
PLAIN = re.compile(r'^[A-Za-z0-9_ ]*$')


class Unusable(Exception):
    """An input or a candidate that this tool refuses. Not a statement about the subject."""


def reached(files):
    """Every file that the given files reach through `include`, as paths relative to the repository root.

    Fails closed: the word `include` anywhere in a file must be a directive that names an existing file."""
    seen, todo = [], [(ROOT / name).resolve() for name in files]
    while todo:
        path = todo.pop()
        if path in seen:
            continue
        if not path.is_file():
            raise Unusable('a file that is reached does not exist: ' + path.name)
        seen.append(path)
        text = path.read_text()
        for found in re.finditer(r'\binclude\b', text):
            directive = INCLUDE.match(text, found.start())
            if not directive:
                raise Unusable('the word `include` in ' + path.name + ' is not a readable directive')
            todo.append((path.parent / directive.group(1)).resolve())
    return sorted(os.path.relpath(path, ROOT) for path in seen)


def refused(files):
    for name in files:
        text = (ROOT / name).read_text()
        for label, pattern in REFUSED:
            if pattern.search(text):
                return label + ' is in ' + name
    return None


class Tool:
    """Runs the pinned Dafny in one work folder. Every command is recorded with its real exit code."""

    def __init__(self, work):
        self.work = Path(work)
        self.work.mkdir(parents=True)
        self.commands, self.count = [], 0

    def run(self, argv, name):
        child = subprocess.run([str(part) for part in argv], cwd=ROOT, capture_output=True)
        (self.work / (name + '.stdout')).write_bytes(child.stdout)
        (self.work / (name + '.stderr')).write_bytes(child.stderr)
        self.commands.append({'name': name, 'argv': [str(part) for part in argv], 'exit_code': child.returncode})
        (self.work / 'operations.json').write_bytes(canonical({'commands': self.commands}))
        return child

    def check(self, files):
        """Audit of every reached file against the empty baseline, then verify with the gate options. No cache."""
        self.count += 1
        name = 'check-%03d' % self.count
        try:
            every = reached(files)
            problem = refused(every)
        except Unusable as reason:
            every, problem = list(files), str(reason)
        report = self.work / (name + '-audit.md')
        report.write_bytes(dafny.AUDIT.read_bytes())
        audit = self.run([dafny.DAFNY, 'audit', *every, '--report-format', 'md', '--report-file', report,
                          '--compare-report'], name + '-audit')
        trx = self.work / (name + '.trx')
        verify = self.run([dafny.DAFNY, 'verify', *files, *dafny.OPTIONS,
                           '--log-format', 'trx;LogFileName=' + str(trx)], name + '-verify')
        members = {}
        if trx.is_file():
            for item in ET.parse(trx).iter():
                if item.tag.endswith('UnitTestResult'):
                    member = re.sub(r' \(assertion batch \d+\)$', '', item.get('testName'))
                    if members.get(member, 'Passed') == 'Passed':
                        members[member] = item.get('outcome')
        return {'files': list(files), 'audited_files': len(every), 'refused': problem,
                'audit_exit': audit.returncode, 'checker_exit': verify.returncode,
                'members': dict(sorted(members.items())),
                'failed': sorted(m for m, outcome in members.items() if outcome != 'Passed')}

    def counterexample(self, files):
        self.count += 1
        child = self.run([dafny.DAFNY, 'verify', *files, *dafny.OPTIONS, '--extract-counterexample'],
                         'counterexample-%03d' % self.count)
        return (child.stdout + child.stderr).decode('utf-8', 'replace')


def passed(result, members=()):
    """Passed: nothing refused, empty audit, checker exit 0, every member passed, the named members present."""
    return (result['refused'] is None and result['audit_exit'] == 0 and result['checker_exit'] == 0
            and not result['failed'] and bool(result['members'])
            and all(result['members'].get(m) == 'Passed' for m in members))


def only_the_claim_failed(result, member):
    return (result['refused'] is None and result['audit_exit'] == 0 and result['checker_exit'] == 4
            and result['failed'] == [member])


def summary(result, files=True):
    short = {key: result[key] for key in ('audited_files', 'refused', 'audit_exit', 'checker_exit', 'failed')}
    short['members'] = len(result['members'])
    if files:
        short['files'] = result['files']
    return short


# ---------------------------------------------------------------------------------------------------
# Files that this tool writes: instances, probes, witnesses.
# ---------------------------------------------------------------------------------------------------
def module_lines(prefix, modules):
    words = [m for m, b in modules] + [w.lstrip('#') for _, b in modules for pair in b.items() for w in pair]
    if not all(NAME.fullmatch(word) for word in words):
        raise Unusable('a module name in the subject is not a plain name')
    lines = []
    for module, bindings in modules:
        lines.append('module %s%s refines %s {' % (prefix, module, module))
        for name, bound in bindings.items():
            lines.append('  import %s = %s' % (name, prefix + bound[1:] if bound.startswith('#') else bound))
        lines.append('}')
    return lines


def instance_check(tool, label, files, instances, members, generated):
    """Writes non-abstract instances of every module that holds a required member, and checks that file.

    instances: [[module, {import name: bound module}]]; '#M' is this tool's instance of module M. A module of a
    required member that is not listed gets an instance with no binding. If such a module has an abstract import,
    Dafny rejects the file: that fails closed.
    """
    modules = [(module, dict(bindings)) for module, bindings in instances]
    listed = {module for module, _ in modules}
    for member in members:
        module = member.split('.', 1)[0]
        if module not in listed:
            modules.append((module, {}))
            listed.add(module)
    target = generated / (label + '-instance.dfy')
    target.parent.mkdir(parents=True, exist_ok=True)
    lines = ['// GENERATED by scripts/spec_clearing.py. Non-abstract instances of the modules whose members are required.',
             '// In a non-abstract module Dafny reports a lemma that has no body. No proof is in this file.']
    lines += ['include "%s"' % os.path.relpath((ROOT / name).resolve(), target.parent) for name in files]
    lines += module_lines('ClearingInstanceOf_', modules)
    text = '\n'.join(lines) + '\n'
    target.write_text(text)
    result = tool.check([os.path.relpath(target, ROOT)])
    return {'instance_file': target.name, 'instance_sha256': digest(text.encode()), 'instance_text': text,
            'required_members': list(members), **summary(result, files=False), 'passed': passed(result, members)}


def spec_probe(tool, label, probe, generated):
    """The specification leaves no compiled declaration without a body, except the specified methods."""
    target = generated / (label + '-spec-probe.dfy')
    target.parent.mkdir(parents=True, exist_ok=True)
    lines = ['// GENERATED by scripts/spec_clearing.py. Non-abstract refinements of the specification with nothing added.',
             '// The Dafny compiler lists the declarations that have no body.']
    lines += ['include "%s"' % os.path.relpath((ROOT / name).resolve(), target.parent) for name in probe['files']]
    lines += module_lines('ClearingSpecProbeOf_', [(module, dict(bindings)) for module, bindings in probe['modules']])
    text = '\n'.join(lines) + '\n'
    target.write_text(text)
    tool.count += 1
    child = tool.run([dafny.DAFNY, 'build', os.path.relpath(target, ROOT), '--target', 'js', '--no-verify',
                      '--allow-warnings', '--output', tool.work / ('probe-%03d-out' % tool.count)],
                     'probe-%03d' % tool.count)
    output = (child.stdout + child.stderr).decode('utf-8', 'replace')
    errors = [line for line in output.splitlines() if ': Error: ' in line]
    found = sorted(match.group(1).replace('._default.', '.') for match in map(NO_BODY.search, errors) if match)
    expected = sorted('ClearingSpecProbeOf_' + name for name in probe['open'])
    good = (child.returncode != 0 and len(found) == len(errors) and found == expected and bool(expected))
    return {'probe_file': target.name, 'probe_sha256': digest(text.encode()), 'probe_text': text,
            'compiler_exit': child.returncode, 'errors': len(errors), 'without_body': found,
            'expected_without_body': expected, 'passed': good}


# ---------------------------------------------------------------------------------------------------
# Candidates for subjects of the refund shape (a flat record for the context, a response, decisions).
# ---------------------------------------------------------------------------------------------------
def facts_of(text):
    """The last `assume` line of a counterexample, as a list of (left, right) pairs of its equalities."""
    lines = [line.strip() for line in text.splitlines() if line.strip().startswith('assume ')]
    if not lines:
        raise Unusable('the output holds no counterexample')
    pairs = []
    for part in lines[-1][len('assume '):].rstrip(';').split(' && '):
        if ' == ' in part:
            left, right = part.split(' == ', 1)
            pairs.append((left.strip(), right.strip()))
    return pairs


def value_of(pairs, path):
    for left, right in pairs:
        if right == path:
            return left
        if left == path:
            return right
    return None


def split_arguments(text):
    parts, depth, current = [], 0, ''
    for char in text:
        if char in '([':
            depth += 1
        elif char in ')]':
            depth -= 1
        if char == ',' and depth == 0:
            parts.append(current.strip())
            current = ''
        else:
            current += char
    if current.strip():
        parts.append(current.strip())
    return parts


def text_of(term):
    """A Dafny character list such as ['a', 'b'] as a plain text, or None."""
    if not (term.startswith('[') and term.endswith(']')):
        return None
    chars = split_arguments(term[1:-1])
    if not all(re.fullmatch(r"'[A-Za-z0-9_ ]'", char) for char in chars):
        return None
    return ''.join(char[1] for char in chars)


def constructor(term):
    """('Name', [arguments]) of a constructor term. Module prefixes are dropped; argument ORDER is not trusted."""
    found = re.fullmatch(r'(?:[\w.]+\.)?(\w+)(?:\((.*)\))?', term)
    if not found:
        raise Unusable('not a constructor term: ' + term[:60])
    return found.group(1), split_arguments(found.group(2) or '')


def typed(arguments):
    """The one integer and the one text among the arguments (the order in counterexample text varies)."""
    integers = [a for a in arguments if re.fullmatch(r'-?\d+', a)]
    texts = [t for t in (text_of(a) for a in arguments) if t is not None]
    if len(integers) != 1 or len(texts) != 1:
        raise Unusable('arguments are not one integer and one text')
    return integers[0], texts[0]


def refund_values(text, variables):
    """Candidate values for the refund shape, from counterexample text. Raises Unusable if a part is missing."""
    pairs, context = facts_of(text), variables['context']

    def scalar(field):
        value = value_of(pairs, context + '.' + field)
        if value is None:
            raise Unusable('no value for ' + context + '.' + field)
        return value

    def name(field, default):
        value = value_of(pairs, context + '.' + field)
        if value is not None and text_of(value) is not None:
            return text_of(value)
        length = value_of(pairs, '|' + context + '.' + field + '|')
        return default * int(length) if length and length.isdigit() and 0 < int(length) <= 64 else default

    def decision(variable):
        term = value_of(pairs, variable)
        if term is None:
            raise Unusable('no value for ' + variable)
        kind, arguments = constructor(term)
        if kind == 'Rejected':
            return {'kind': 'Rejected'}
        if kind != 'Authorized':
            raise Unusable('unknown decision ' + kind)
        amount, reason = typed(arguments)
        return {'kind': 'Authorized', 'amount': amount, 'reason': reason}

    response_term = value_of(pairs, variables['response'])
    if response_term is None:
        raise Unusable('no value for ' + variables['response'])
    kind, arguments = constructor(response_term)
    response = {'kind': kind}
    if kind == 'Candidate':
        response['amount'], response['reason'] = typed(arguments)
    return {'context': {'chargeId': name('chargeId', 'c'), 'requestId': name('requestId', 'r'),
                        'original': scalar('original'), 'remaining': scalar('remaining'),
                        'refundEnabled': scalar('refundEnabled') == 'true',
                        'requestOpen': scalar('requestOpen') == 'true'},
            'response': response, 'results': [decision(v) for v in variables['results']]}


def refund_terms(values):
    """Dafny terms of the candidate values, for a module prefix. Refuses anything but plain values."""
    context, response = values['context'], values['response']
    for word in (context['chargeId'], context['requestId'], response.get('reason', ''),
                 *[r.get('reason', '') for r in values['results']]):
        if not PLAIN.fullmatch(word):
            raise Unusable('a text is not plain')
    for number in (context['original'], context['remaining'], response.get('amount', '0'),
                   *[r.get('amount', '0') for r in values['results']]):
        if not re.fullmatch(r'-?\d+', str(number)):
            raise Unusable('a number is not an integer')

    def boolean(value):
        return 'true' if value else 'false'

    def context_term(prefix):
        return '%sChargeContext("%s", "%s", %s, %s, %s, %s)' % (
            prefix, context['chargeId'], context['requestId'], context['original'], context['remaining'],
            boolean(context['refundEnabled']), boolean(context['requestOpen']))

    def response_term(prefix):
        if response['kind'] == 'Candidate':
            return '%sCandidate(%s, "%s")' % (prefix, response['amount'], response['reason'])
        return prefix + response['kind']

    def decision_term(prefix, result):
        if result['kind'] == 'Authorized':
            return '%sAuthorized(%s, "%s")' % (prefix, result['amount'], result['reason'])
        return prefix + 'Rejected'

    def plan_term(prefix, result):
        if result['kind'] != 'Authorized':
            return '[]'
        return '[%sIntent("%s", "%s", %s, "%s")]' % (prefix, context['chargeId'], context['requestId'],
                                                     result['amount'], result['reason'])
    return context_term, response_term, decision_term, plan_term


def render(template, values):
    text = (ROOT / template).read_text()
    for key, value in values.items():
        text = text.replace('@@' + key + '@@', value)
    if '@@' in text:
        raise Unusable('the template has an open place')
    return text


def refund_choice_witness(candidate, values, target):
    context, response, decision, plan = refund_terms(values)
    one, two = values['results']
    if one['kind'] != two['kind']:
        difference = 'decisionA.Authorized? != decisionB.Authorized?'
    elif one['kind'] == 'Authorized' and one['amount'] != two['amount']:
        difference = 'decisionA.Authorized? && decisionB.Authorized? && decisionA.amount != decisionB.amount'
    elif one['kind'] == 'Authorized' and one['reason'] != two['reason']:
        difference = 'decisionA.Authorized? && decisionB.Authorized? && decisionA.reason != decisionB.reason'
    else:
        raise Unusable('the two results of the candidate are equal')
    text = render(candidate['template'], {
        'SOURCE': candidate['source'], 'SPEC_MODULE': candidate['spec_module'],
        'SPEC_INCLUDE': os.path.relpath(ROOT / candidate['spec_include'], target.parent),
        'CONTEXT': context(''), 'RESPONSE': response(''),
        'DECISION_A': decision('', one), 'PLAN_A': plan('', one),
        'DECISION_B': decision('', two), 'PLAN_B': plan('', two),
        'A_CONTEXT': context('A.'), 'A_RESPONSE': response('A.'), 'B_CONTEXT': context('B.'),
        'B_RESPONSE': response('B.'), 'A_DECISION_A': decision('A.', one), 'B_DECISION_B': decision('B.', two),
        'DIFFERENCE': difference})
    members = ['ChoiceA.Assess (correctness)', 'ChoiceB.Assess (correctness)',
               'ChoiceWitness.TwoRefinementsDiffer (correctness)']
    example = {'input': context('') + ', ' + response(''), 'result_one': decision('', one), 'result_two': decision('', two)}
    return text, members, example


def refund_pair_witness(candidate, values, target):
    context, response, decision, _ = refund_terms(values)
    old, new = values['results']
    text = render(candidate['template'], {
        'SOURCE': candidate['source'], 'BASE_MODULE': candidate['base_module'],
        'BASE_INCLUDE': os.path.relpath(ROOT / candidate['base_include'], target.parent),
        'O_CONTEXT': context('D.O.'), 'O_RESPONSE': response('D.O.'),
        'O_DECISION': decision('D.O.', old), 'N_DECISION': decision('D.N.', new),
        'O_ELIGIBLE': 'true' if old['kind'] == 'Authorized' else 'false',
        'N_ELIGIBLE': 'true' if new['kind'] == 'Authorized' else 'false'})
    members = ['DivergenceWitness.AtThisInput (correctness)', 'DivergenceWitness.BothAllowAResult (correctness)']
    example = {'input': context('') + ', ' + response(''), 'before': decision('', old), 'after': decision('', new)}
    return text, members, example


SHAPES = {'refund-choice': refund_choice_witness, 'refund-pair': refund_pair_witness}
WRITTEN = 'the tool wrote these values into the witness file that Dafny verified'
DESCRIBED = ('a description by hand, from the subject list, of a hand-written witness file; Dafny verified the file, '
             'not this text')


def try_candidates(tool, subject, generated):
    """Tries EVERY candidate of the subject. Returns (records of every try, examples of the verified ones)."""
    tried, examples = [], []
    for number, candidate in enumerate(subject.get('candidates', []), 1):
        record = {'source': candidate['source']}
        tried.append(record)
        label = '%s-candidate-%d' % (subject['id'], number)
        try:
            if 'witness' in candidate:                  # a whole witness file, written by hand
                witness = candidate['witness']
                record.update(kind='witness file', witness_sha256={f: digest((ROOT / f).read_bytes()) for f in witness['files']})
                files, instances, members = witness['files'], witness['instances'], witness['members']
                example = {**witness['example'], 'example_text': DESCRIBED}
            else:
                if candidate['source'] == 'solver':
                    values = refund_values(tool.counterexample(subject['claim']['files']), candidate['variables'])
                else:
                    values = candidate['values']
                record.update(kind='values', values=values)
                target = generated / (label + '.dfy')
                text, members, example = SHAPES[candidate['shape']](candidate, values, target)
                example['example_text'] = WRITTEN
                target.parent.mkdir(parents=True, exist_ok=True)
                target.write_text(text)
                record.update(witness_file=target.name, witness_sha256=digest(text.encode()), witness_text=text)
                files = [os.path.relpath(target, ROOT)] + candidate['files']
                instances = candidate['instances']
            record['check'] = instance_check(tool, label, files, instances, members, generated)
            record['verified'] = record['check']['passed']
        except Unusable as reason:
            record.update(usable=False, reason=str(reason), verified=False)
            continue
        if record['verified']:
            examples.append({'source': candidate['source'], **example})
    return tried, examples


def clear(tool, subject, generated, proved_verdict, witness_verdict, probe_for_witness):
    """One subject. proved_verdict: the claim is proved. witness_verdict: the claim is rejected and a candidate is verified."""
    claim = tool.check(subject['claim']['files'])
    member = subject['claim']['member']
    record = {'id': subject['id'], 'title': subject['title'], 'planted': subject['planted'],
              'claim': {'member': member, **summary(claim)}, 'proof': None, 'spec_probe': None, 'candidates': [], 'examples': []}
    for key in ('spec', 'old', 'new', 'no_solver_candidate'):
        if key in subject:
            record[key] = subject[key]

    def probe_passes():
        if 'spec_probe' not in subject:
            return False
        try:
            record['spec_probe'] = spec_probe(tool, subject['id'], subject['spec_probe'], generated)
        except Unusable as reason:
            record['spec_probe'] = {'passed': False, 'reason': str(reason)}
        return record['spec_probe']['passed']

    verdict = 'LINK_BROKEN'
    if passed(claim, [member]):
        if 'proof' in subject:
            proof = subject['proof']
            try:
                record['proof'] = instance_check(tool, subject['id'] + '-proof', proof['files'], proof['instances'],
                                                 proof['members'], generated)
            except Unusable as reason:
                record['proof'] = {'passed': False, 'reason': str(reason)}
            mapped = True
            if proved_verdict == 'EQUIVALENT':      # the mappings between the two sides must be proved (finding F4)
                mappings = proof.get('mappings', [])
                record['proof']['mapping_members'] = mappings
                mapped = bool(mappings) and all(m in proof['members'] for m in mappings)
            if record['proof']['passed'] and member in proof['members'] and mapped and probe_passes():
                verdict = proved_verdict
    elif only_the_claim_failed(claim, member):
        record['candidates'], record['examples'] = try_candidates(tool, subject, generated)
        if not record['examples']:
            verdict = 'UNDECIDED'
        elif not probe_for_witness or probe_passes():
            verdict = witness_verdict
    record['verdict'], record['scope'] = verdict, SCOPE[verdict]
    return record


def clear_spec(tool, subject, generated):
    # A CHOICE witness is two refinements of the specification: it needs no probe of the specification.
    record = clear(tool, subject, generated, 'NO_CHOICE', 'CHOICE', probe_for_witness=False)
    proof = record['proof'] or {}
    if 'never_accepts' in subject:
        vacuous = bool(proof.get('passed')) and subject['never_accepts'] in proof.get('required_members', [])
        record['acceptance'] = {'result': 'VACUOUS' if vacuous else 'NOT_SHOWN', 'member': subject['never_accepts'],
                                'meaning': 'proved: every allowed result is a rejection' if vacuous else 'not proved'}
    elif 'acceptance' in subject:
        acceptance = subject['acceptance']
        try:
            check = instance_check(tool, subject['id'] + '-acceptance', acceptance['files'], acceptance['instances'],
                                   acceptance['members'], generated)
        except Unusable as reason:
            check = {'passed': False, 'reason': str(reason)}
        record['acceptance'] = {'result': 'ACCEPTS' if check['passed'] else 'NOT_SHOWN', 'purpose': acceptance['purpose'],
                                'check': check}
    else:
        record['acceptance'] = {'result': 'NOT_SHOWN'}
    return record


def clear_pair(tool, subject, generated):
    # A DIVERGES witness says "EVERY result that each side allows": it needs the probe of both specifications.
    return clear(tool, subject, generated, 'EQUIVALENT', 'DIVERGES', probe_for_witness=True)


def subjects():
    return json.loads((ROOT / 'clearing/subjects.json').read_text())


def main():
    if len(sys.argv) != 3:
        print('usage: spec_clearing.py <subject id> <new work folder under build/>', file=sys.stderr)
        return 2
    wanted, work = sys.argv[1], (ROOT / sys.argv[2]).resolve()
    if not work.is_relative_to(ROOT / 'build') or work.exists():
        print('the work folder must be a new folder under build/', file=sys.stderr)
        return 2
    data = subjects()
    every = [(s, clear_spec) for s in data['specs']] + [(s, clear_pair) for s in data['pairs']]
    every += [(s, clear_spec if s['kind'] == 'spec' else clear_pair) for s in data['controls']]
    matches = [(s, function) for s, function in every if s['id'] == wanted]
    if len(matches) != 1:
        print('no subject, or more than one subject, with that id', file=sys.stderr)
        return 2
    subject, function = matches[0]
    record = function(Tool(work), subject, work / 'generated')
    print(json.dumps({key: record[key] for key in ('id', 'verdict', 'scope', 'examples')}, indent=1))
    (work / 'record.json').write_bytes(canonical(record))
    return 0 if record['verdict'] not in ('UNDECIDED', 'LINK_BROKEN') else 1


if __name__ == '__main__':
    sys.exit(main())
