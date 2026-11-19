#!/usr/bin/env python3
"""Render checked claim records and actual finite model-comparison examples."""

import json
from pathlib import Path
import shutil
import sys

from stage5_tools import ROOT, Session, canonical, digest, preserve, require


def main():
    folder = ROOT / 'build/stage5/docs'
    preserve(folder)
    session = Session(folder)
    commands = [
        ('source-proof', ['python3', 'gate/gate.py', '--impl', 'impl/Ledger.dfy',
                          '--evidence', 'build/stage5/docs/source-evidence.json']),
        ('model-build', ['python3', 'scripts/build_model.py']),
        ('examples', ['node', '--import', 'tsx', 'scripts/generate_examples.ts', 'build/stage5/docs/examples.json']),
    ]
    for name, command in commands:
        child = session.run(name, command)
        require(child.returncode == 0, name + ' failed: ' + child.stdout + child.stderr)
    bundle = json.loads((folder / 'source-evidence.json').read_text())
    examples = json.loads((folder / 'examples.json').read_text())
    build = json.loads((ROOT / 'build/js/build.json').read_text())
    require(examples['result'] == 'passed' and examples['counts']['accepted'] > 0
            and examples['counts']['rejected'] > 0, 'Missing actual accept/reject examples')
    require({x['id'] for x in bundle['claims']} == {'C1', 'C2', 'C3', 'C4', 'C5'}, 'Missing claim')
    session.finish()
    candidate_manifest = [{'path': name, 'sha256': session.source_before[name]}
                          for name in ('ts/ledger.ts', 'ts/types.ts')]
    destination = ROOT / 'results/stage5'
    destination.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(folder / 'source-evidence.json', destination / 'source-evidence.json')
    examples.update({'spec_sha256': session.identity()['spec_sha256'],
                     'candidate_artifact': {'kind': 'source', 'sha256': digest(canonical(candidate_manifest)), 'build_cmd': ''},
                     'candidate_source_manifest': candidate_manifest,
                     'comparison_input_sha256': session.source_before,
                     'source_artifact_sha256': bundle['artifact']['sha256'],
                     'source_evidence_sha256': digest((folder / 'source-evidence.json').read_bytes()),
                     'module_sha256': build['artifact']['sha256'],
                     'source_to_module_proved': False,
                     'assumptions': ['The compiler, generated runtime, and bigint bridge preserve the proved source model.',
                                     'Finite examples do not cover every request or state.']})
    (destination / 'examples.json').write_bytes(canonical(examples))
    rows = ['# Ledger claims and generated behavior examples', '',
            'Generated from real source-proof evidence and observed model comparisons.',
            'Run `python3 scripts/generate_claim_docs.py` with the pinned toolchain.', '',
            'Spec SHA-256: `' + session.identity()['spec_sha256'] + '`.', '',
            '| Claim | Established behavior | Spec location |', '| --- | --- | --- |']
    for claim in bundle['claims']:
        rows.append('| ' + claim['id'] + ' | ' + claim['statement_plain_english'] + ' | `'
                    + claim['spec_ref'] + '` |')
    rows += ['', 'These source proofs assume a WellFormed input state and sequential operations',
             'over mathematical integers. The fee account is `0`. A fresh transfer needs',
             'a distinct sender and recipient, neither equal to `0`, and funds for amount',
             'plus one. Retries and rejected requests leave state unchanged.', '',
             '## Generated examples', '',
             str(examples['counts']['total']) + ' actual comparisons: '
             + str(examples['counts']['accepted']) + ' returned `Ok`; '
             + str(examples['counts']['rejected']) + ' returned `Rejected`.',
             'Every row matched the handwritten TypeScript implementation against the compiled',
             'Dafny model. This is `tested_against_proved_model`, not a TypeScript proof.', '',
             '| ID | Input balances | Request ID; sender → recipient; amount | Outcome | Next balances |',
             '| --- | --- | --- | --- | --- |']
    selected = [item for item in examples['examples'] if not item['name'].startswith('enumerated')]
    for predicate in (
        lambda x: x['request'] == {'sender': '1', 'recipient': '2', 'amount': '11'} and len(x['input']['balances']) == 3,
        lambda x: x['request'] == {'sender': '1', 'recipient': '1', 'amount': '1'} and len(x['input']['balances']) == 3,
        lambda x: x['request'] == {'sender': '1', 'recipient': '2', 'amount': '1'} and len(x['input']['balances']) == 2,
        lambda x: x['request'] == {'sender': '1', 'recipient': '0', 'amount': '1'} and len(x['input']['balances']) == 3,
    ):
        selected.append(next(item for item in examples['examples'] if predicate(item)))
    for item in selected:
        request = item['request']
        show = lambda pairs: '{' + ', '.join(key + ': ' + value for key, value in pairs) + '}'
        rows.append('| ' + item['id'] + ' | `' + show(item['input']['balances']) + '` | `'
                    + item['request_id'] + '; ' + request['sender'] + ' → ' + request['recipient']
                    + '; ' + request['amount'] + '` | ' + item['outcome'] + ' | `'
                    + show(item['next']['balances']) + '` |')
    rows += ['', 'The full [example records](../results/stage5/examples.json) include accepted-request maps.',
             'They are finite observations. The source-to-module compiler/runtime/bridge link is',
             'an assumption. Compiler, binary, concurrency, persistence, and deployment behavior',
             'remain outside these proofs. `end_to_end=false`.', '',
             'A successful-execution witness and a mutation report provide separate spec-quality',
             'diagnostics. Neither establishes that the specification captures all human intent.', '']
    (ROOT / 'docs/claims.md').write_text('\n'.join(rows))
    session.finish()
    (destination / 'docs-generation.json').write_bytes(canonical({
        **session.identity(), 'commands': session.commands, 'result': 'passed', 'exit_code': 0,
        'examples_sha256': digest((destination / 'examples.json').read_bytes()),
        'claims_markdown_sha256': digest((ROOT / 'docs/claims.md').read_bytes()),
        'generator_sha256': {name: digest((ROOT / name).read_bytes()) for name in
                             ('scripts/generate_claim_docs.py', 'scripts/generate_examples.ts', 'scripts/stage5_tools.py')},
    }))
    print('CLAIMS_AND_EXAMPLES_GENERATED: ' + str(examples['counts']))
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, RuntimeError, ValueError, KeyError, StopIteration) as error:
        print(str(error), file=sys.stderr)
        sys.exit(2)
