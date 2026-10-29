#!/usr/bin/env python3
"""Serialize completed Stage 7 records; never run or replace a proof checker.

The real EXIT remains the acceptance command. These unsigned records require
trusted execution/replay, just as earlier Forge evidence does.
"""
import argparse
import hashlib
import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def write(path, data):
    path.write_text(json.dumps(data, sort_keys=True, indent=2) + '\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--attempt', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    attempt = args.attempt.resolve()
    raw = attempt / 'linux'
    outer, report = read(attempt / 'report.json'), read(raw / 'report.json')
    pins = read(ROOT / 'toolchain/stage7-pins.json')
    own = read(ROOT / 'toolchain/stage7-own-pins.json')
    assert outer['result'] == report['result'] == 'passed'
    assert report['pins'] == pins and report['own_pins'] == own
    assert report['independent_rocqchk'] is True and report['end_to_end'] is False
    assert report['rocqchk_commands'][0]['exit_code'] == 0
    assert {'ForgeChecked.Wrapper', 'ForgeChecked.WitnessWrapper',
            'Forge.Binary.Proof', 'Forge.Binary.Witness',
            'Forge.Binary.images.Program'} <= set(report['checked_modules'])
    assert all(c['exit_code'] == 0 for c in report['commands'])
    assert sha(raw / 'independent-kernel.log') == report['independent_kernel_log_sha256']
    assert sha(raw / 'gcd-selftest.elf') == own['binary_sha256'] == report['artifact_sha']
    assert (raw / 'gcd-selftest.elf').stat().st_size == own['binary_bytes']
    before, after = read(raw / 'before/identity.json'), read(raw / 'after/identity.json')
    assert before['tracked_sha256_manifest'] == after['tracked_sha256_manifest']
    manifest = []
    for name, expected in sorted(own['proof_source_sha256'].items()):
        path = ROOT / 'examples/binary' / name
        assert sha(path) == sha(raw / 'source' / name) == expected
        manifest.append({'path': 'examples/binary/' + name, 'sha256': expected})
    assert sha(ROOT / own['source']) == sha(raw / 'gcd_selftest.c') == own['source_sha256']
    manifest.append({'path': own['source'], 'sha256': own['source_sha256']})
    for name, expected in sorted(report['generated_input_sha256'].items()):
        assert sha(raw / 'source' / name) == expected, 'GENERATED_SOURCE_CHANGED'
        manifest.append({'path': 'generated/' + name, 'sha256': expected})
    for key in ('upstream_prerequisite', 'negative_prerequisite'):
        ref = outer[key]
        assert sha(ROOT / ref['report']) == ref['sha256']
        assert read(ROOT / ref['report'])['result'] == 'passed'
    allowed = ROOT / '.toolchain/stage7/upstream/toolchain/allowed-axioms.txt'
    trusted = {name: sha(ROOT / name) for name in [
        'toolchain/stage7-pins.json', 'toolchain/stage7-own-pins.json',
        'scripts/exit_stage_7.py', 'scripts/stage7_own_job.py', 'scripts/stage7_identity.py',
        'scripts/stage7_build_own.py']}
    frozen = ROOT / 'results/stage7/development' / ('own-proof-' + attempt.name + '-runner')
    for name in ['exit_stage_7.py', 'stage7_own_job.py', 'stage7_identity.py',
                 'stage7-pins.json', 'stage7-own-pins.json']:
        live = ROOT / ('toolchain' if name.endswith('.json') else 'scripts') / name
        assert sha(live) == sha(frozen / name), 'ACCEPTANCE_RUNNER_CHANGED'
    trusted['upstream/tracked-sha256-manifest'] = before['tracked_sha256_manifest']
    trusted['upstream/toolchain/allowed-axioms.txt'] = sha(allowed)
    lps = read(ROOT / 'results/stage7/commands/recovery-semantics-source/output.log')
    assert lps['matches'] is True
    trusted['lps/source-tree-sha256'] = lps['source_tree_sha256']
    claims = [
        {'id': 'S7-OWN-TERMINATION', 'spec_ref': 'examples/binary/Statements.v#selftest_halts',
         'spec_sha': own['statement_sha256'],
         'statement_plain_english': 'Every valid input and entry of this exact fixed-input ELF terminates normally with status 0 under the pinned LPS may_fail model.'},
        {'id': 'S7-OWN-VALID-EXECUTION', 'spec_ref': 'examples/binary/WitnessSpec.v#selftest_has_valid_execution',
         'spec_sha': own['proof_source_sha256']['WitnessSpec.v'],
         'statement_plain_english': 'A valid modeled input and entry exist for this exact ELF, and every execution from that entry on that input terminates normally with status 0.'}]
    trusted_base = [
        'Rocq 9.2.0 independent kernel and primitive implementations; OCaml 4.14.3 runtime.',
        'Published elf-snapshot ELF-to-image translation and pinned rocq-read-file data import; no compiler-correctness theorem is claimed.',
        'Pinned LPS model fidelity to its stated Linux/RISC-V scope, valid-input restrictions and execution assumptions.',
        'Pinned container publisher/build provenance, Docker, AMD64 execution support, host OS and hardware.',
        'Forge orchestration, artifact hashing, recorded commands and unsigned local evidence provenance.']
    model_assumptions = [
        'The exact static RISC-V ELF is represented by the pinned published ELF snapshot loader.',
        'Execution is within LPS f1006fe8178338a499b5e5c41be83006c4edd058 and valid_input/valid_entry, including Sv48, restricted signals/files, single-thread scope and no external interference.',
        'The may_fail environment and source_alloc_limit (16 GiB) are those of the published model; this theorem has no budget-refusal exemption.']
    records = []
    for claim, axioms in zip(claims, [report['theorem_assumptions'], report['witness_assumptions']]):
        records.append({'claim_id': claim['id'], 'artifact_sha': own['binary_sha256'],
            'method': 'kernel_checked_proof', 'tool': 'Theorem published LPS / Rocq / rocqchk',
            'tool_version': pins['rocq_core'], 'result': 'passed',
            'assumptions': sorted(axioms) + model_assumptions,
            'trusted_base': trusted_base,
            'reproduce_cmd': 'python3 scripts/exit_stage_7.py --case own-proof',
            'producer': 'Forge Stage 7 actual local checker execution; unsigned'})
    bundle = {'format_version': 1, 'end_to_end': False,
        'artifact': {'kind': 'binary', 'sha256': own['binary_sha256'],
                     'build_cmd': 'python3 scripts/stage7_build_own.py'},
        'source_manifest': sorted(manifest, key=lambda x: x['path']),
        'claims': claims, 'evidence': records, 'trusted_input_sha256': trusted,
        'verification_options': ['rocqchk -o -bytecode-compiler no; complete recursive dependency closure',
            'unchanged upstream WRAPPER template for termination and valid-execution witness',
            'unchanged upstream assumption allowlist and audit implementation',
            'one CPU; 4 GiB memory; 512 processes; unlimited stack; no proof timeout',
            'published exits_c soundness theorem with certificate fuel 128'],
        'verified_obligations': [report['theorem'], report['valid_execution_witness'],
                                 'Forge.Binary.Images.program_wf']}
    audit = {'end_to_end': False, 'artifact_sha256': own['binary_sha256'],
        'toolchain': pins, 'build_provenance': own,
        'theorem_assumptions': report['theorem_assumptions'],
        'witness_assumptions': report['witness_assumptions'],
        'independent_closure_assumptions': report['independent_closure_assumptions'],
        'checked_modules': report['checked_modules'],
        'checked_module_count': len(report['checked_modules']),
        'rocqchk_exit_code': report['rocqchk_commands'][0]['exit_code'],
        'upstream_source_identity_before_and_after': before['tracked_sha256_manifest'],
        'own_source_identity_before_and_after': sorted(manifest, key=lambda x: x['path']),
        'unproved': ['general-input GCD correctness', 'C source semantics/compiler correctness',
                    'model-to-real-hardware fidelity', 'release/deployment identity',
                    'ledger/booking binary claims', 'whole-service correctness']}
    args.output.mkdir(parents=True, exist_ok=False)
    write(args.output / 'evidence.json', bundle)
    write(args.output / 'assumption-audit.json', audit)
    shutil.copyfile(raw / 'gcd-selftest.elf', args.output / 'gcd-selftest.elf')
    print('SERIALIZED_COMPLETED_RECORDS: no new proof or independent checker execution')


if __name__ == '__main__':
    main()
