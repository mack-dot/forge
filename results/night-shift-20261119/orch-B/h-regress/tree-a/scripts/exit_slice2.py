#!/usr/bin/env python3
"""Slice 2 (master idea items F1.1 and F1.3, with F1.2): EXIT checks of spec clearing. Dispatch only.

This script starts scripts/spec_clearing.py's procedure, the pinned Dafny and the gates, and compares
their verdicts and exit codes with the expected ones. It decides no proof.

Its bundle is a RECORD. It is NOT gate evidence: no policy lists these claims and no gate
obligation lists these files. Raw outputs go to build/slice2/ (ignored by git). Nothing is written
under results/.

Cases:
  choice    the three approved specifications: NO_CHOICE, with an exact Post and a proved acceptance;
            two planted specifications: CHOICE; the planted vacuous one: no choice, and VACUOUS
  diff      rewritten refund variant: EQUIVALENT; cap variant and the real fee change: DIVERGES with examples
  effects   hidden-effect check of F1.2: the three gates accept; two printing implementations are rejected
  controls  thirteen broken clearing inputs: each must get its non-pass verdict, for its own reason
  evidence  all four, twice, in fresh folders; the two bundles are byte-identical; writes the unified report
"""

import argparse
from pathlib import Path
import platform
import subprocess
import sys
import traceback

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
sys.path.insert(0, str(ROOT / 'scripts'))
from common import canonical, digest, pin_file, read_json  # noqa: E402
from backends import dafny  # noqa: E402
import spec_clearing  # noqa: E402

# subject -> (verdict, acceptance, sources that MUST have given a verified example)
EXPECT_SPECS = {
    'ledger': ('NO_CHOICE', 'ACCEPTS', set()), 'booking': ('NO_CHOICE', 'ACCEPTS', set()),
    'refund': ('NO_CHOICE', 'ACCEPTS', set()),
    'refund-loose': ('CHOICE', 'NOT_SHOWN', {'solver', 'supplied'}),
    'ledger-noframe': ('CHOICE', 'NOT_SHOWN', {'supplied'}),
    'ledger-vacuous': ('NO_CHOICE', 'VACUOUS', set()),
}
EXPECT_PAIRS = {
    'refund-cap': ('DIVERGES', {'solver', 'supplied'}), 'refund-rewrite': ('EQUIVALENT', set()),
    'ledger-fee': ('DIVERGES', {'supplied'}),
}
EXPECT_CONTROLS = {
    'control-post-too-strong': 'LINK_BROKEN', 'control-post-too-weak': 'UNDECIDED',
    'control-lemma-without-body': 'LINK_BROKEN', 'control-axiom-lemma': 'LINK_BROKEN',
    'control-assume': 'LINK_BROKEN', 'control-member-missing': 'LINK_BROKEN',
    'control-choice-not-allowed': 'UNDECIDED', 'control-example-wrong': 'UNDECIDED',
    'control-false-equivalence': 'UNDECIDED',
    'control-axiom-in-included-file': 'LINK_BROKEN', 'control-forward-link-halts': 'LINK_BROKEN',
    'control-specification-leaves-a-definition-open': 'LINK_BROKEN',
    'control-equivalence-without-mapping-proof': 'LINK_BROKEN',
}
# The members on which each pass verdict of a shipped subject must rest. The subject list names them too; a wrong
# entry there (another lemma under the claim's name, a missing forward link) makes this script fail.
C = ' (correctness)'
EXPECT_MEMBERS = {
    'ledger': ('LedgerDeterminism.SpecIsDeterministic' + C,
               {'LedgerDeterminism.SpecIsDeterministic' + C, 'LedgerDeterminism.ApplyThenPost' + C, 'LedgerExact.PostIsExact' + C}),
    'booking': ('BookingDeterminism.SpecIsDeterministic' + C,
                {'BookingDeterminism.SpecIsDeterministic' + C, 'BookingDeterminism.ApplyThenPost' + C, 'BookingExact.PostIsExact' + C}),
    'refund': ('RefundDeterminism.SpecIsDeterministic' + C,
               {'RefundDeterminism.SpecIsDeterministic' + C, 'RefundDeterminism.AssessThenPost' + C, 'RefundExact.PostIsExact' + C}),
    'ledger-vacuous': ('LedgerVacuousClearing.SpecIsDeterministic' + C,
                       {'LedgerVacuousClearing.SpecIsDeterministic' + C, 'LedgerVacuousClearing.ApplyThenPost' + C,
                        'LedgerVacuousClearing.NeverAccepts' + C}),
    'refund-loose': ('RefundLooseClaim.SpecIsDeterministic' + C, set()),
    'ledger-noframe': ('NoFrameDeterminism.SpecIsDeterministic' + C, set()),
    'refund-cap': ('RefundCapAgree.Agree' + C, set()),
    'ledger-fee': ('FeeChangeAgree.Agree' + C, set()),
    'refund-rewrite': ('RefundRewriteAgree.Agree' + C,
                       {'RefundRewriteAgree.Agree' + C, 'RefundRewrite.OldAssessThenPost' + C, 'RefundRewrite.NewAssessThenPost' + C,
                        'RefundRewrite.OldDeterministic' + C, 'RefundRewrite.NewDeterministic' + C,
                        'RefundRewrite.OldPostSatisfiable' + C, 'RefundRewrite.NewPostSatisfiable' + C,
                        'RefundRewrite.MappingsAreOneToOneAndOnto' + C}),
}
# Witness members of the verified examples: source -> members that the check of that example must have required.
EXPECT_WITNESS = {
    'refund-loose': {'ChoiceA.Assess' + C, 'ChoiceB.Assess' + C, 'ChoiceWitness.TwoRefinementsDiffer' + C},
    'ledger-noframe': {'NoFrameHonest.Apply' + C, 'NoFrameTrojan.Apply' + C, 'NoFrameWitness.TwoAllowedResultsDiffer' + C},
    'refund-cap': {'DivergenceWitness.AtThisInput' + C, 'DivergenceWitness.BothAllowAResult' + C},
    'ledger-fee': {'FeeChangeDivergence.AtThisInput' + C, 'FeeChangeDivergence.BothAllowAResult' + C},
}
PRINT_STATEMENT = 'to use a print statement, the enclosing method must be marked with {:print}'
PRINT_CALL = 'to call a method with print effects, the enclosing method must be marked with {:print}'
PRINT_BUGS = {'bugs/print_effect.dfy': PRINT_STATEMENT, 'bugs/print_effect_marked.dfy': PRINT_CALL}
PACKET = 'proposals/forge2-pillar1-spec-determinism/'
SUBJECT = sorted(
    ['scripts/spec_clearing.py', 'scripts/exit_slice2.py', 'clearing/subjects.json']
    + [p.relative_to(ROOT).as_posix() for p in (ROOT / 'clearing').rglob('*') if p.is_file() and p.suffix in ('.dfy', '.template')])
REUSED = [PACKET + name for name in (
    'LedgerDeterminism.dfy', 'BookingDeterminism.dfy', 'RefundDeterminism.dfy', 'SpecDiffRefundCap.dfy',
    'SpecDiffFee.dfy', 'SpecDiffFeeWitnesses.dfy', 'fixtures/RefundSpecCapped.dfy', 'fixtures/LedgerSpecNoFee.dfy',
    'fixtures/LedgerSpecNoFrame.dfy', 'fixtures/NoFrameDeterminism.dfy', 'fixtures/NoFrameImpls.dfy')] + [
    'tests/stage5/SuccessfulExecution.dfy', 'tests/booking/SuccessfulExecution.dfy',
    'bugs/print_effect.dfy', 'bugs/print_effect_marked.dfy']
APPROVED = ['spec/LedgerSpec.dfy', 'spec.lock', 'spec/booking/BookingSpec.dfy', 'spec/booking/spec.lock',
            'spec/refund/RefundSpec.dfy', 'spec/refund/spec.lock', 'impl/Ledger.dfy', 'impl/Booking.dfy', 'impl/Refund.dfy']
TRUSTED = ['gate/gate.py', 'gate/refund.py', 'gate/booking.py', 'gate/backends/dafny.py', 'gate/common.py',
           'gate/ContractBinding.dfy', 'gate/expected-audit.md', pin_file('dafny')]
CLAIMS = [
    ('Q1', 'Each of the three approved specifications (ledger, booking, refund) allows at most one result for every '
           'input. Its Post predicate is exact, and one concrete accepted input is proved.'),
    ('Q2', 'Two planted specifications leave a choice: for one concrete input each, two modules that Dafny accepts as '
           'refinements return different results.'),
    ('Q3', 'The planted vacuous ledger specification leaves no choice and accepts no request at all.'),
    ('Q4', 'The approved refund specification and its planted rewritten variant allow the same result for every input.'),
    ('Q5', 'For the planted refund cap and for the real fee change, one concrete input is proved for which the result '
           'before the change and the result after it differ; both results are stated.'),
]
ASSUMPTIONS = [
    'Dafny mathematical integers, finite maps, sequences and strings; source level only. No statement about '
    'compiled code, a running program or a deployed artifact.',
    '"No choice" and "equivalent" are statements about results (next state, outcome; decision, plan). They do not show '
    'that a specification matches the intent of a person.',
    'Post is written by hand for each specification, with that specification\'s own predicates. The forward link (every '
    'result of the specified method satisfies Post) and, where the two-run lemma holds, exactness are proved by Dafny.',
    'Every verdict rests on a non-abstract instance that the tool writes, checked with an empty Dafny audit of every '
    'file that it reaches: an abstract module alone accepts a lemma without a body, and the audit reports only on the '
    'files of its command line.',
    'NO_CHOICE is a statement for each refinement of a specification taken alone. The compiler probe shows that the '
    'specification leaves no compiled function, predicate or method without a body except the specified method. A '
    'ghost definition without a body, a constant without a value or an opaque type in a specification is NOT detected.',
    'The tool does not check that a hand-written claim lemma states the right claim or that a forward link calls the '
    'specified method. This script pins the member names of the shipped subjects; a person must read the lemma texts.',
    'A concrete example is one point. It does not describe the whole region where two specifications differ.',
    'Planted variants are fixtures. They are not approved specifications and not proposed changes.',
]
TRUSTED_BASE = [
    'Pinned Dafny with bundled Boogie, .NET and Z3 4.12.1; no independent proof certificate kernel. The Dafny audit.',
    'scripts/spec_clearing.py and this script: they start Dafny, write instance modules and witness files from '
    'templates, and compare exit codes and member results. Not proved. One fresh-context review.',
    'The subject list clearing/subjects.json: it names the files, the bindings and the required members.',
    'The host operating system, runtime libraries and hardware.',
]


class Failed(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Failed(message)


def rel(path):
    return Path(path).resolve().relative_to(ROOT).as_posix()


def snapshot(names):
    return {name: digest((ROOT / name).read_bytes()) for name in names}


def toolchain(tool):
    pins = read_json(ROOT / pin_file('dafny'))
    require(pins['verification_options'] == dafny.OPTIONS and '--track-print-effects' in dafny.OPTIONS,
            'TOOLCHAIN: the pinned options are not the gate options with print-effect tracking')
    require(platform.python_version() == pins['python']['version'], 'TOOLCHAIN: Python version differs from the pin')
    for path, expected in {dafny.DAFNY: pins['dafny']['executable_sha256'],
                           ROOT / pins['z3']['path']: pins['z3']['executable_sha256'],
                           Path(sys.executable): pins['python']['executable_sha256']}.items():
        require(digest(Path(path).read_bytes()) == expected, 'TOOLCHAIN: executable digest differs: ' + str(path))
    version = tool.run([dafny.DAFNY, '--version'], 'dafny-version')
    require(version.returncode == 0 and version.stdout.decode().strip() == pins['dafny']['version_output'],
            'TOOLCHAIN: Dafny version differs from the pin')
    return {'dafny': pins['dafny']['version_output'], 'z3': pins['z3']['version_output'],
            'python': pins['python']['version']}


def run_subjects(tool, group, function, expected, generated):
    records = []
    listed = [subject['id'] for subject in spec_clearing.subjects()[group]]
    require(len(listed) == len(set(listed)) and set(listed) == set(expected),
            'the subject list and the expected list differ, or an id is there twice')
    for subject in spec_clearing.subjects()[group]:
        record = function(tool, subject, generated)
        print('  %s: %s%s%s' % (subject['id'], record['verdict'],
                                 '; ' + record['acceptance']['result'] if 'acceptance' in record else '',
                                 '; verified examples from: ' + ', '.join(e['source'] for e in record['examples'])
                                 if record['examples'] else ''), flush=True)
        records.append(record)
    for record in records:
        pinned(record)
    return records


def pinned(record):
    """The verdict of a shipped subject rests on the pinned members, not on whatever the subject list names."""
    claim, proof = EXPECT_MEMBERS[record['id']]
    require(record['claim']['member'] == claim, record['id'] + ': the claim member is not the pinned one')
    if record['verdict'] in ('NO_CHOICE', 'EQUIVALENT'):
        require(record['proof'] and proof and proof <= set(record['proof']['required_members']),
                record['id'] + ': a pinned proof member is not required')
        require(record['spec_probe'] and record['spec_probe']['passed'], record['id'] + ': no passed specification probe')
    if record['verdict'] in ('CHOICE', 'DIVERGES'):
        verified = [c for c in record['candidates'] if c['verified']]
        require(verified and all(EXPECT_WITNESS[record['id']] <= set(c['check']['required_members']) for c in verified),
                record['id'] + ': a verified example does not rest on the pinned witness members')
    if record['verdict'] == 'EQUIVALENT':
        require(record['proof'].get('mapping_members') == ['RefundRewrite.MappingsAreOneToOneAndOnto' + C],
                record['id'] + ': the mapping proof is not the pinned one')


def choice(work):
    tool = spec_clearing.Tool(work)
    tools = toolchain(tool)
    records = run_subjects(tool, 'specs', spec_clearing.clear_spec, EXPECT_SPECS, work / 'generated')
    for record in records:
        verdict, acceptance, sources = EXPECT_SPECS[record['id']]
        require(record['verdict'] == verdict, record['id'] + ': expected ' + verdict + ', observed ' + record['verdict'])
        require(record['acceptance']['result'] == acceptance,
                record['id'] + ': expected acceptance ' + acceptance + ', observed ' + record['acceptance']['result'])
        require(sources <= {e['source'] for e in record['examples']},
                record['id'] + ': no verified example from ' + ', '.join(sorted(sources)))
        if verdict == 'NO_CHOICE':
            require(record['proof'] and record['proof']['passed'] and record['proof']['audit_exit'] == 0,
                    record['id'] + ': NO_CHOICE without a passed instance check')
    return {'toolchain': tools, 'subjects': records}


def diff(work):
    tool = spec_clearing.Tool(work)
    toolchain(tool)
    records = run_subjects(tool, 'pairs', spec_clearing.clear_pair, EXPECT_PAIRS, work / 'generated')
    for record in records:
        verdict, sources = EXPECT_PAIRS[record['id']]
        require(record['verdict'] == verdict, record['id'] + ': expected ' + verdict + ', observed ' + record['verdict'])
        require(sources <= {e['source'] for e in record['examples']},
                record['id'] + ': no verified example from ' + ', '.join(sorted(sources)))
        if verdict == 'EQUIVALENT':
            require(record['proof'] and record['proof']['passed'], record['id'] + ': EQUIVALENT without a passed instance check')
        if verdict == 'DIVERGES':
            require(all('before' in e and 'after' in e for e in record['examples']), record['id'] + ': an example lacks before/after')
    return {'subjects': records}


def controls(work):
    tool = spec_clearing.Tool(work)
    toolchain(tool)
    records = []
    listed = [subject['id'] for subject in spec_clearing.subjects()['controls']]
    require(len(listed) == len(set(listed)) and set(listed) == set(EXPECT_CONTROLS),
            'the control list and the expected list differ, or an id is there twice')
    for subject in spec_clearing.subjects()['controls']:
        function = spec_clearing.clear_spec if subject['kind'] == 'spec' else spec_clearing.clear_pair
        record = function(tool, subject, work / 'generated')
        expected = EXPECT_CONTROLS[subject['id']]
        print('  %s: %s (expected %s)' % (subject['id'], record['verdict'], expected), flush=True)
        require(record['verdict'] == expected, subject['id'] + ': expected ' + expected + ', observed ' + record['verdict'])
        require(not record['examples'], subject['id'] + ': a control has a verified example')
        records.append(record)
    by_id = {r['id']: r for r in records}
    # Review F1: verify of the claim file passes; only the audit of the INCLUDED file reports the axiom.
    included = by_id['control-axiom-in-included-file']['claim']
    require(included['checker_exit'] == 0 and included['audit_exit'] != 0 and included['refused'] is None
            and included['audited_files'] >= 3, 'control-axiom-in-included-file: not stopped by the audit of the included file')
    # Review F2: verify and audit pass; only the refused word stops it.
    halts = by_id['control-forward-link-halts']['claim']
    require(halts['checker_exit'] == 0 and halts['audit_exit'] == 0 and halts['refused'] is not None,
            'control-forward-link-halts: not stopped by the refused word alone')
    # Review F3: claim and instance pass; only the specification probe stops it, and it names the open function.
    opened = by_id['control-specification-leaves-a-definition-open']
    require(opened['proof'] and opened['proof']['passed'] and opened['spec_probe'] and not opened['spec_probe']['passed']
            and 'ClearingSpecProbeOf_RefundSpecOpenLimit.Limit' in opened['spec_probe']['without_body'],
            'control-specification-leaves-a-definition-open: not stopped by the specification probe alone')
    # Review F4: claim and instance pass; only the missing mapping proof stops it.
    unmapped = by_id['control-equivalence-without-mapping-proof']
    require(unmapped['proof'] and unmapped['proof']['passed'] and unmapped['proof']['mapping_members'] == []
            and unmapped['spec_probe'] is None, 'control-equivalence-without-mapping-proof: not stopped by the missing mapping proof alone')
    # The control for the abstract-module hole: Dafny alone accepts the claim file; only the instance fails.
    hole = by_id['control-lemma-without-body']
    require(hole['claim']['audit_exit'] == 0 and hole['claim']['checker_exit'] == 0 and not hole['claim']['failed'],
            'control-lemma-without-body: the claim file alone did not pass (the control does not show the hole)')
    require(hole['proof'] and not hole['proof']['passed'] and hole['proof']['audit_exit'] != 0,
            'control-lemma-without-body: the instance check did not report the lemma without a body')
    # The weak-Post control: the solver gave a usable candidate, and Dafny rejected the witness made from it.
    weak = by_id['control-post-too-weak']['candidates']
    require(len(weak) == 1 and weak[0]['source'] == 'solver' and weak[0].get('usable', True)
            and weak[0]['verified'] is False and weak[0]['check']['checker_exit'] == 4,
            'control-post-too-weak: the solver candidate was not tried and rejected by Dafny')
    for name in ('control-choice-not-allowed', 'control-example-wrong'):
        tried = by_id[name]['candidates']
        require(len(tried) == 1 and tried[0]['verified'] is False and tried[0]['check']['checker_exit'] == 4,
                name + ': the supplied candidate was not rejected by Dafny')
    return {'subjects': records}


def effects(work):
    tool = spec_clearing.Tool(work)
    toolchain(tool)
    rows = []

    def gate(name, argv, expected):
        child = tool.run([sys.executable, *argv], name)
        last = (child.stdout + child.stderr).decode('utf-8', 'replace').strip().splitlines()[-1:] or ['']
        print('  %s: exit %d' % (name, child.returncode), flush=True)
        require(child.returncode == expected, name + ': expected gate exit ' + str(expected) + ', observed ' + str(child.returncode))
        rows.append({'check': name, 'argv': ['python3', *['<work>/' + Path(a).name if a.startswith('build/') else a for a in argv]],
                     'gate_exit': child.returncode, 'last_line': last[0][:200]})
        return last[0]

    out = rel(work)
    require(gate('gate-ledger', ['gate/gate.py', '--impl', 'impl/Ledger.dfy', '--evidence', out + '/ledger.json'], 0)
            .startswith('ACCEPTED: C1 C2 C3 C4 C5'), 'gate-ledger: not accepted')
    require(gate('gate-refund', ['gate/refund.py', '--tier', 'critical', '--evidence', out + '/refund.json'], 0)
            .startswith('ACCEPTED: R1 R2 R3 R4 R5'), 'gate-refund: not accepted')
    require(gate('gate-booking', ['gate/booking.py', '--evidence', out + '/booking.json', '--work', out + '/booking-work'], 0)
            .startswith('ACCEPTED'), 'gate-booking: not accepted')
    for number, (bug, reason) in enumerate(sorted(PRINT_BUGS.items()), 1):
        name = 'print-bug-%d' % number
        gate(name + '-gate', ['gate/gate.py', '--impl', bug, '--evidence', out + '/' + name + '.json'], 1)
        require(not (work / (name + '.json')).exists(), name + ': a rejected run left an evidence file')
        raw = tool.run([dafny.DAFNY, 'verify', bug, 'gate/ContractBinding.dfy', *dafny.OPTIONS], name + '-checker')
        output = (raw.stdout + raw.stderr).decode('utf-8', 'replace')
        errors = [line for line in output.splitlines() if ': Error: ' in line]
        print('  %s-checker: exit %d' % (name, raw.returncode), flush=True)
        require(raw.returncode == 2 and errors and all(reason in line for line in errors),
                name + ': the checker did not reject it for the print effect only')
        rows[-1].update(fixture=bug, checker_exit=raw.returncode, reason=reason, errors=len(errors))
    return {'option': '--track-print-effects', 'rows': rows}


def bundle_of(work):
    inputs = sorted(set(SUBJECT + REUSED + APPROVED + TRUSTED))
    before = snapshot(inputs)
    part_choice = choice(work / 'choice')
    part_diff = diff(work / 'diff')
    part_effects = effects(work / 'effects')
    part_controls = controls(work / 'controls')
    require(snapshot(inputs) == before, 'INPUT_CHANGED: a source or trusted input changed during the checks')
    version = part_choice['toolchain']['dafny']
    return {
        'record': 'forge-slice2-spec-clearing', 'format_version': 1,
        'gate_accepted': False, 'policy': None, 'end_to_end': False,
        'producer': 'scripts/exit_slice2.py (a scenario script; not the gate)',
        'note': 'A record of real tool runs. It is not Forge gate evidence: no policy lists these claims and no gate '
                'obligation lists these files. A rejected lemma is never counted as a result.',
        'master_idea_items': ['F1.1', 'F1.2', 'F1.3'],
        'source_manifest': [{'path': name, 'sha256': before[name]} for name in SUBJECT],
        'reused_inputs_sha256': {name: before[name] for name in REUSED},
        'approved_inputs_sha256': {name: before[name] for name in APPROVED},
        'trusted_input_sha256': {name: before[name] for name in TRUSTED},
        'toolchain': part_choice['toolchain'], 'verification_options': dafny.OPTIONS,
        'evidence': [{'claim_id': claim, 'statement_plain_english': statement, 'method': 'source_proof',
                      'result': 'passed', 'tool': 'Dafny', 'tool_version': version, 'assumptions': ASSUMPTIONS,
                      'reproduce_cmd': 'python3 scripts/exit_slice2.py --case evidence'} for claim, statement in CLAIMS],
        'choice': part_choice['subjects'], 'spec_diff': part_diff['subjects'],
        'hidden_effects': part_effects, 'controls': part_controls['subjects'],
        'trusted_base': TRUSTED_BASE,
    }


def report_of(bundle):
    """The unified clearing report, as Markdown, from the bundle. Text only; no new result."""
    lines = ['# Spec clearing report (Slice 2)', '',
             'Written by `scripts/exit_slice2.py` from its evidence record. Not gate evidence. `end_to_end=false`.',
             'Pinned Dafny `%s`, gate options with `--track-print-effects`.' % bundle['toolchain']['dafny'], '',
             '## 1. Choice left to an implementation', '',
             '| Subject | Verdict | Acceptance | Example |', '| --- | --- | --- | --- |']

    def examples(record, keys):
        return '<br>'.join('%s (%s): %s' % (e['source'], 'values in the verified witness' if e['example_text'] == spec_clearing.WRITTEN
                                            else 'description of a hand-written verified witness',
                                            '; '.join('%s `%s`' % (k.replace('_', ' '), e[k]) for k in keys))
                           for e in record['examples']) or '—'
    for r in bundle['choice']:
        lines.append('| %s%s | %s | %s | %s |' % (r['title'], '' if not r['planted'] else ' (fixture)', r['verdict'],
                                                 r['acceptance']['result'], examples(r, ('input', 'result_one', 'result_two'))))
    lines += ['', '## 2. Hidden effects (F1.2)', '', '| Check | Gate exit | Checker exit | Result |', '| --- | --- | --- | --- |']
    for row in bundle['hidden_effects']['rows']:
        lines.append('| `%s` | %d | %s | %s |' % (' '.join(row['argv']), row['gate_exit'], row.get('checker_exit', '—'),
                                               row.get('reason', row['last_line'])))
    lines += ['', '## 3. Before and after a specification change', '',
              '| Pair | Verdict | Example |', '| --- | --- | --- |']
    for r in bundle['spec_diff']:
        lines.append('| %s | %s | %s |' % (r['title'], r['verdict'], examples(r, ('input', 'before', 'after'))))
    lines += ['', '## 4. Controls: broken clearing inputs', '', '| Control | Verdict |', '| --- | --- |']
    for r in bundle['controls']:
        lines.append('| %s | %s |' % (r['title'], r['verdict']))
    lines += ['', '## 5. What a verdict means', '']
    for verdict in ('NO_CHOICE', 'CHOICE', 'EQUIVALENT', 'DIVERGES', 'UNDECIDED', 'LINK_BROKEN'):
        lines.append('- **%s.** %s' % (verdict, spec_clearing.SCOPE[verdict]))
    lines += ['', '## 6. Assumptions', ''] + ['- ' + text for text in ASSUMPTIONS] + ['']
    return '\n'.join(lines)


def attempt_folder(case):
    base = ROOT / 'build/slice2' / case
    base.mkdir(parents=True, exist_ok=True)
    number = 1 + max([int(p.name.split('-')[1]) for p in base.glob('attempt-*')] or [0])
    return base / ('attempt-%04d' % number)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--case', required=True, choices=('choice', 'diff', 'effects', 'controls', 'evidence'))
    args = parser.parse_args()
    work = attempt_folder(args.case)
    print('SLICE2 ' + args.case + ': ' + rel(work), flush=True)
    if args.case == 'evidence':
        work.mkdir(parents=True)
        bundles = []
        for number in (1, 2):
            print(' run ' + str(number), flush=True)
            run = work / ('run-%d' % number)
            run.mkdir()
            bundles.append(canonical(bundle_of(run)))
            (run / 'evidence.json').write_bytes(bundles[-1])
        require(bundles[0] == bundles[1], 'evidence: the two bundles differ')
        (work / 'evidence.json').write_bytes(bundles[0])
        (work / 'CLEARING_REPORT.md').write_text(report_of(read_json(work / 'evidence.json')))
        print('  bundle: ' + rel(work / 'evidence.json') + ' sha256 ' + digest(bundles[0]) + ' (two runs, byte-identical)')
    else:
        {'choice': choice, 'diff': diff, 'effects': effects, 'controls': controls}[args.case](work)
    print('SLICE2 ' + args.case + ': PASSED; end_to_end=false')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Failed as error:
        print('SLICE2 FAILED: ' + str(error), file=sys.stderr)
        sys.exit(1)
    except Exception:  # a missing tool or a crash is not a negative result
        traceback.print_exc()
        sys.exit(2)
