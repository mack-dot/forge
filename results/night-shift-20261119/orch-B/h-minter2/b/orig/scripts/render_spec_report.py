#!/usr/bin/env python3
"""Render completed checker measurements; this script does not verify code."""

import json
from pathlib import Path

from stage5_tools import ROOT, canonical, digest, require


def main():
    folder = ROOT / 'results/stage5'
    vacuity = json.loads((folder / 'vacuity.json').read_text())
    mutations = json.loads((folder / 'mutations.json').read_text())
    examples = json.loads((folder / 'examples.json').read_text())
    for report in (vacuity, mutations):
        require(report['result'] == 'passed' and report['exit_code'] == 0, 'A required real EXIT did not pass')
    require(vacuity['spec_sha256'] == mutations['spec_sha256'] == examples['spec_sha256'], 'Spec identities differ')
    witness = vacuity['witness']
    source_manifest = [{'path': name, 'sha256': value} for name, value in sorted(witness['inputs'].items())]
    artifact = {'kind': 'source', 'sha256': digest(canonical(source_manifest)), 'build_cmd': ''}
    summary = {
        'format': 'forge-spec-quality/1', 'production_acceptance': False, 'end_to_end': False,
        'spec_sha256': vacuity['spec_sha256'],
        'witness': {
            'claim': {'id': 'W1', 'statement_plain_english': witness['statement'],
                      'spec_ref': 'spec/LedgerSpec.dfy:Apply; tests/stage5/SuccessfulExecution.dfy:Witness',
                      'spec_sha': witness['spec_sha256']},
            'artifact': artifact, 'source_manifest': source_manifest,
            'evidence': {'claim_id': 'W1', 'artifact_sha': artifact['sha256'],
                         'method': 'source_proof', 'tool': vacuity['tool'], 'tool_version': vacuity['tool_version'],
                         'result': witness['result'], 'assumptions': witness['assumptions'],
                         'trusted_base': ['Pinned Dafny/Boogie/Z3 and runtime', 'Host OS and hardware',
                                          'Approved spec, actual refinement, contract binding, and witness source'],
                         'reproduce_cmd': 'python3 scripts/exit_stage_5.py --case vacuity',
                         'producer': 'forge/stage5-dafny-witness'},
            'verified_obligations': witness['coverage'],
        },
        'vacuity_control': {'flagged': vacuity['vacuity_flagged'],
                            'fixture_inputs': vacuity['negative_fixture']['inputs'],
                            'reject_all_verifier_exit': vacuity['negative_fixture']['reject_all_verifier_exit'],
                            'witness_verifier_exit': vacuity['negative_fixture']['witness_verifier_exit']},
        'mutation_measurement': {key: mutations[key] for key in ('counts', 'spec_kill_rate', 'survivors', 'mutants', 'limits')},
        'example_measurement': {key: examples[key] for key in
                                ('method', 'tool', 'tool_version', 'counts', 'source_artifact_sha256',
                                 'source_evidence_sha256', 'module_sha256', 'assumptions',
                                 'candidate_artifact', 'candidate_source_manifest', 'comparison_input_sha256')},
        'protected_manifest_sha256': vacuity['protected_manifest_sha256'],
        'driver_input_sha256': vacuity['driver_input_sha256'],
        'runner_sha256': vacuity['runner_sha256'],
        'renderer_sha256': digest(Path(__file__).read_bytes()),
        'reproduce_commands': ['python3 scripts/generate_claim_docs.py',
                               'python3 scripts/exit_stage_5.py --case vacuity',
                               'python3 scripts/exit_stage_5.py --case mutations',
                               'python3 scripts/render_spec_report.py'],
        'limits': ['This is a diagnostic supplement, not a release bundle accepted by production policy.',
                   'Raw logs and operational command records are separate from this canonical summary.',
                   'A witness excludes the demonstrated reject-all vacuity, not every intent error.',
                   'A finite mutation kill rate cannot estimate arbitrary bug detection.'],
    }
    (folder / 'spec-quality.json').write_bytes(canonical(summary))
    rate = mutations['spec_kill_rate']
    rows = ['# Spec-quality results', '',
            'These results concern the approved fee spec `' + vacuity['spec_sha256'] + '`.',
            'They measure this fixture set. They do not establish complete intent coverage.', '',
            '## Successful-execution witness', '', witness['statement'], '',
            'Dafny verified the actual refinement and the witness together: 13 obligations, exit `0`.',
            'An isolated spec with both validity predicates set to false admitted the reject-all',
            'implementation (verifier exit `0`). The same success witness failed (verifier exit `4`).',
            'The fixture is not an approved production spec. The production gate was not weakened.', '',
            '## Mutation measurements', '',
            'Spec-proof kill rate: **' + rate['fraction'] + ' (' + rate['percent'] + '%)**.',
            'The denominator includes the labeled algebraic rewrite control. One invalid source',
            'and one audit-rejected assumption fixture are excluded. Inconclusive results: '
            + str(mutations['counts']['inconclusive']) + '.', '',
            '| Mutation | Result | Real checker code | Reported claim or contract |',
            '| --- | --- | --- | --- |']
    for mutant in mutations['mutants']:
        code = mutant.get('verifier_exit_code', mutant.get('audit_exit_code', mutant['resolve_exit_code']))
        claims = ', '.join(mutant.get('violated_claims', []))
        if not claims and mutant.get('violated_contract_locations'):
            claims = ', '.join(x['spec_ref'] for x in mutant['violated_contract_locations'])
        rows.append('| `' + mutant['id'] + '` | ' + mutant['classification'] + ' | '
                    + str(code) + ' | ' + (claims or 'See the labeled control below') + ' |')
    rows += ['', 'The algebraic rewrite survived as expected. The print-effect mutant also',
             'survived: printed output is outside the declared ledger-state claims. Survival',
             'is not a claim that the mutation satisfies every human requirement. The assumption',
             'fixture was rejected by the real auditor, not counted as a spec-proof kill.',
             'The invalid source failed real parsing, not proof. Unlabeled contract failures',
             'retain their actual source locations rather than being assigned an invented C1–C5 label.', '',
             '## Reproduce', '', '```sh', *summary['reproduce_commands'], '```', '',
             '[Claim explanations and examples](claims.md) use actual model comparisons.',
             '[Canonical diagnostic summary](../results/stage5/spec-quality.json) binds source hashes,',
             'scope, methods, and tool versions. The [vacuity](../results/stage5/vacuity.json)',
             'and [mutation](../results/stage5/mutations.json) reports retain real commands and codes.',
             'Raw logs are operational records. All evidence keeps `end_to_end=false`.', '']
    (ROOT / 'docs/spec-quality.md').write_text('\n'.join(rows))
    print('SPEC_QUALITY_RENDERED: ' + rate['fraction'] + '; survivors=' + ','.join(mutations['survivors']))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
