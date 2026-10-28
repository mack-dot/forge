#!/usr/bin/env python3
"""Execute real Dafny witness and mutation diagnostics for Stage 5."""

import argparse
import json
from pathlib import Path
import shutil
import sys

from stage5_tools import (ROOT, Session, canonical, claim_failures, contract_locations, dafny,
                         diagnostics, digest, message, preserve, require)


def replace_once(text, old, new):
    require(text.count(old) == 1, 'Mutation target changed: ' + old)
    return text.replace(old, new, 1)


def reject_all(source):
    prefix, _ = source.split('  method Apply ... {', 1)
    return prefix + '  method Apply ... {\n    next := state;\n    outcome := Rejected;\n  }\n}\n'


def manifest(fixture):
    return {str(p.relative_to(fixture)): digest(p.read_bytes())
            for p in sorted(fixture.rglob('*.dfy'))}


def vacuity(session):
    approved = session.fixture('approved')
    audit = session.audit('approved-witness', approved, witness=True)
    require(audit.returncode == 0, 'Approved witness audit failed: ' + audit.stdout + audit.stderr)
    verified, coverage = session.verify('approved-witness', approved, witness=True)
    require(verified.returncode == 0, 'Approved successful-execution witness failed: ' + verified.stdout + verified.stderr)

    source = (ROOT / 'spec/LedgerSpec.dfy').read_text()
    source = replace_once(source, '    id in state.accepted && state.accepted[id] == request', '    false')
    old = '''    id !in state.accepted &&
    request.sender in state.balances &&
    request.recipient in state.balances &&
    request.sender != request.recipient &&
    0 in state.balances &&
    request.sender != 0 &&
    request.recipient != 0 &&
    0 < request.amount &&
    request.amount + 1 <= state.balances[request.sender]'''
    source = replace_once(source, old, '    false')
    vacuous = session.fixture('vacuous', reject_all((ROOT / 'impl/Ledger.dfy').read_text()), source)
    audit = session.audit('vacuous-implementation', vacuous)
    require(audit.returncode == 0, 'Vacuous fixture did not pass its real audit')
    # The real TRX omits well-formedness tasks for these constant-false predicates.
    # This applies only to the isolated diagnostic fixture, never the production gate.
    vacuous_tasks = dafny.REQUIRED_RESULTS - {
        'LedgerSpec.IsRetry (well-formedness)', 'LedgerSpec.IsFreshValid (well-formedness)'}
    accepted, bad_coverage = session.verify('vacuous-implementation', vacuous, required=vacuous_tasks)
    require(accepted.returncode == 0, 'Reject-all implementation did not verify against its vacuous fixture spec')
    audit = session.audit('vacuous-witness', vacuous, witness=True)
    require(audit.returncode == 0, 'Vacuous witness audit failed before the intended proof check')
    rejected, failed_coverage = session.verify('vacuous-witness', vacuous, witness=True)
    errors = [x for x in diagnostics(rejected.stdout) if x.get('severity') == 1]
    witness_failures = [x for x in errors if
                        x.get('location', {}).get('filePath', '').endswith('SuccessfulExecution.dfy')]
    require(rejected.returncode == 4 and witness_failures
            and any('assertion' in message(x).lower() for x in witness_failures),
            'The vacuous fixture was not flagged by a real witness assertion failure')
    return {'result': 'passed', 'vacuity_flagged': True,
            'witness': {'id': 'W1', 'method': 'source_proof', 'result': 'passed',
                        'statement': 'From balances {0:0,1:11,2:0} with an empty retry map, request 7 transfers 10 from 1 to 2, returns Ok, records the request, and produces balances {0:1,1:0,2:10}.',
                        'source': 'tests/stage5/SuccessfulExecution.dfy',
                        'source_sha256': digest((ROOT / 'tests/stage5/SuccessfulExecution.dfy').read_bytes()),
                        'spec_sha256': session.identity()['spec_sha256'],
                        'assumptions': ['Dafny, Boogie, Z3, the pinned runtime, host, and hardware are trusted.',
                                        'The witness establishes this source execution under the approved mathematical model.'],
                        'coverage': coverage, 'inputs': manifest(approved)},
            'negative_fixture': {'production_approval': False, 'inputs': manifest(vacuous),
                                 'reject_all_verifier_exit': accepted.returncode,
                                 'reject_all_coverage': bad_coverage,
                                 'witness_verifier_exit': rejected.returncode,
                                 'witness_coverage': failed_coverage,
                                 'witness_diagnostics': witness_failures},
            'limits': ['A rejected witness alone is not a general proof of impossibility.',
                       'This fixture additionally has a verified reject-all implementation and disabled validity predicates.',
                       'One successful witness does not establish complete intent coverage or freedom from all vacuity.']}


def mutants():
    original = (ROOT / 'impl/Ledger.dfy').read_text()
    items = [{'id': name, 'source': (ROOT / 'bugs' / (name + '.dfy')).read_text(),
              'description': description} for name, description in (
                  ('self_transfer', 'Create funds on a self-transfer.'),
                  ('off_by_one', 'Reject an exactly funded amount-plus-fee transfer.'),
                  ('retry_double', 'Repeat a transfer on an accepted retry.'))]
    items += [
        {'id': 'missing_fee_credit', 'source': replace_once(original, '        credited[0 := fee],', '        credited,'),
         'description': 'Debit the fee without crediting account 0.'},
        {'id': 'undercharge_fee', 'source': replace_once(original,
          'var debit := state.balances[request.sender] - request.amount - 1;',
          'var debit := state.balances[request.sender] - request.amount;'),
         'description': 'Credit the fee without charging it to the sender.'},
        {'id': 'discard_retry_record', 'source': replace_once(original,
          '        state.accepted[id := request]);', '        state.accepted);'),
         'description': 'Do not record a successful fresh request.'},
        {'id': 'reject_all', 'source': reject_all(original), 'description': 'Reject every request under the approved spec.'},
        {'id': 'mutate_rejection', 'source': replace_once(original,
          '    } else {\n      next := state;\n      outcome := Rejected;',
          '    } else {\n      next := LedgerState(map[], state.accepted);\n      outcome := Rejected;'),
         'description': 'Clear account balances on rejection.'},
        {'id': 'algebraic_rewrite', 'source': replace_once(original,
          'var debit := state.balances[request.sender] - request.amount - 1;',
          'var debit := state.balances[request.sender] - (request.amount + 1);'),
         'description': 'Algebraic rewrite control; survival is expected.'},
        {'id': 'print_effect', 'source': replace_once(original, '  method Apply ... {',
          '  method Apply ... {\n    print "unrequested diagnostic\\n";'),
         'description': 'Add a print statement; printed output is outside the declared ledger-state claims.'},
        {'id': 'sneaky_assume', 'source': (ROOT / 'bugs/sneaky_assume.dfy').read_text(),
         'description': 'Audit control with a forbidden assumption; exclude it from spec-proof kill rate.'},
        {'id': 'invalid_source', 'source': original.rstrip()[:-1] + '\n',
         'description': 'Invalid syntax control; exclude it from the kill-rate denominator.'},
    ]
    return items


def mutations(session):
    baseline = session.fixture('baseline')
    audit = session.audit('baseline', baseline)
    require(audit.returncode == 0, 'Baseline audit failed')
    child, _ = session.verify('baseline', baseline)
    require(child.returncode == 0, 'Correct baseline did not verify')
    rows = []
    output = ROOT / 'results/stage5/mutants'
    output.mkdir(parents=True, exist_ok=True)
    for mutation in mutants():
        name = mutation['id']
        fixture = session.fixture(name, implementation=mutation['source'])
        (output / (name + '.dfy')).write_text(mutation['source'])
        row = {key: mutation[key] for key in ('id', 'description')}
        row.update(source_sha256=digest(mutation['source'].encode()),
                   fixture_inputs=manifest(fixture), source='results/stage5/mutants/' + name + '.dfy')
        resolved = session.run(name + '-resolve', [str(dafny.DAFNY), 'resolve', *session.inputs(fixture), '--cores', '1'])
        row['resolve_exit_code'] = resolved.returncode
        if resolved.returncode:
            require(resolved.returncode == 2 and any(x in (resolved.stdout + resolved.stderr).lower()
                    for x in ('parse errors', 'resolution/type errors', 'resolution errors')),
                    'TOOLCHAIN_OR_INPUT_ERROR: unexpected resolve result: ' + resolved.stdout + resolved.stderr)
            row.update(classification='invalid', reason='Dafny rejected parsing or type resolution; no proof kill counted.')
        else:
            audit = session.audit(name, fixture)
            row['audit_exit_code'] = audit.returncode
            if audit.returncode:
                require(audit.returncode == 2 and name == 'sneaky_assume',
                        'Unexpected audit failure: ' + audit.stdout + audit.stderr)
                row.update(classification='audit_rejected', reason='Forbidden assumption; not a spec-proof kill.')
            else:
                verified, coverage = session.verify(name, fixture)
                row['verifier_exit_code'] = verified.returncode
                row['coverage'] = coverage
                if verified.returncode == 0:
                    row.update(classification='survived', violated_claims=[])
                elif verified.returncode == 4:
                    messages = '\n'.join(message(x) for x in diagnostics(verified.stdout)).lower()
                    if any(word in messages for word in ('out of resource', 'resource limit', 'timed out', 'timeout', 'inconclusive', 'out of memory')):
                        row.update(classification='inconclusive', reason='Checker resource or unknown result; no kill counted.')
                    else:
                        claims = claim_failures(verified.stdout, fixture / 'spec/LedgerSpec.dfy')
                        locations = contract_locations(verified.stdout, fixture / 'spec/LedgerSpec.dfy')
                        require(bool(locations), 'Unclassified verifier failure; inspect real diagnostics for ' + name)
                        row.update(classification='killed', violated_claims=claims,
                                   violated_contract_locations=locations)
                else:
                    raise RuntimeError('TOOLCHAIN_OR_INPUT_ERROR: unexpected verify exit ' + str(verified.returncode))
        rows.append(row)
        (session.folder / 'mutation-progress.json').write_bytes(canonical(rows))
    counts = {name: sum(x['classification'] == name for x in rows)
              for name in ('killed', 'survived', 'invalid', 'audit_rejected', 'inconclusive')}
    require(counts['killed'] > 0 and counts['survived'] > 0, 'Missing actual killed/surviving controls')
    require(next(x for x in rows if x['id'] == 'invalid_source')['classification'] == 'invalid', 'Invalid control misclassified')
    require(next(x for x in rows if x['id'] == 'sneaky_assume')['classification'] == 'audit_rejected', 'Audit control misclassified')
    denominator = counts['killed'] + counts['survived']
    rate = {'numerator': counts['killed'], 'denominator': denominator,
            'fraction': str(counts['killed']) + '/' + str(denominator),
            'percent': format(100 * counts['killed'] / denominator, '.2f'),
            'excluded': ['invalid', 'audit_rejected', 'inconclusive']}
    return {'result': 'passed', 'mutants': rows, 'counts': counts, 'spec_kill_rate': rate,
            'survivors': [x['id'] for x in rows if x['classification'] == 'survived'],
            'limits': ['This is a finite curated mutation set, not an estimate for arbitrary bugs.',
                       'The algebraic rewrite control is retained in the denominator and labeled explicitly.',
                       'Survival does not establish equivalence or complete intent coverage.',
                       'The driver invokes Dafny resolve/audit/verify; it accepts no production artifact.']}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', choices=('vacuity', 'mutations'), required=True)
    case = parser.parse_args().case
    folder = ROOT / 'build/stage5' / case
    preserve(folder)
    session = None
    report = {'stage': 5, 'case': case, 'stage_exit': True, 'end_to_end': False}
    try:
        session = Session(folder)
        report.update(session.identity())
        report.update(vacuity(session) if case == 'vacuity' else mutations(session))
        session.finish()
        report['exit_code'] = 0
    except (OSError, RuntimeError, ValueError, KeyError) as error:
        report.update(result='failed', exit_code=1, error=str(error))
        print(str(error), file=sys.stderr)
    if session:
        report['commands'] = session.commands
    report['runner_sha256'] = {name: digest((ROOT / name).read_bytes()) for name in
                               ('scripts/exit_stage_5.py', 'scripts/stage5_tools.py')}
    destination = ROOT / 'results/stage5'
    destination.mkdir(parents=True, exist_ok=True)
    (destination / (case + '.json')).write_bytes(canonical(report))
    print('STAGE_5_RESULT ' + json.dumps({k: report[k] for k in ('case', 'result', 'exit_code')}))
    return report['exit_code']


if __name__ == '__main__':
    sys.exit(main())
