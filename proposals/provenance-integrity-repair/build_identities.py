#!/usr/bin/env python3
"""Build the PROPOSED gate/provenance/artifact-identities.json. No proof run.

Every expected value must agree across independent existing records:

* the Stage 7 post-check hash record of all 579 kernel-loaded objects;
* the actual object bytes collected read-only from the stopped Stage 7 container;
* the historical Stage 7 receipt files and its raw kernel log;
* the implementation-lock and policy digests of the locked repository inputs;
* the base image config fetched by content digest.

Disagreement exits 1. The output is a reference proposal, not proof evidence.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
ATTEMPT = '/work/.forge-stage7/own-proof/attempt-0001'
STAGE7 = ROOT / 'results/stage7/own-proof/attempt-0001/linux'
RECORD = ROOT / 'results/stage7/commands/own-compiled-dependency-identities'
FIXED = ['gcd-selftest.elf', 'gcd_selftest.c',
         'source/Execution.v', 'source/Images.v', 'source/Proof.v', 'source/Statements.v',
         'source/Witness.v', 'source/WitnessSpec.v', 'source/images/Program.v',
         'source/images/Program_seg_000.hex', 'source/images/Program_seg_001.hex',
         'wrap/WitnessWrapper.v', 'wrap/Wrapper.v']
OWN = ['source/Execution.vo', 'source/Images.vo', 'source/Proof.vo', 'source/Statements.vo',
       'source/Witness.vo', 'source/WitnessSpec.vo', 'source/images/Program.vo',
       'wrap/WitnessWrapper.vo', 'wrap/Wrapper.vo']
SUMMARY = ['* Theory: Set is predicative', '* Theory: Rewrite rules are not allowed',
           '* Constants/Inductives relying on type-in-type: <none>',
           '* Constants/Inductives relying on unsafe (co)fixpoints: <none>',
           '* Inductives whose positivity is assumed: <none>']


def sha(data):
    return hashlib.sha256(data).hexdigest()


def digest(path):
    return sha(Path(path).read_bytes())


def check(ok, reason, failures):
    if not ok:
        failures.append(reason)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference-work', type=Path, required=True)
    parser.add_argument('--base-identity', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--report', type=Path, required=True)
    args = parser.parse_args()
    failures = []
    policy = json.loads((ROOT / 'policy/provenance.json').read_text())
    lock = json.loads((ROOT / 'spec/provenance/spec.lock').read_text())
    implementation = json.loads((ROOT / 'gate/provenance/implementation.lock').read_text())
    report = json.loads((STAGE7 / 'report.json').read_text())
    kernel = (STAGE7 / 'independent-kernel.log').read_text()
    check(digest(STAGE7 / 'independent-kernel.log') == report['independent_kernel_log_sha256'],
          'historical kernel log digest', failures)

    # Kernel-loaded closure: the raw rocqchk log, not the producer report.
    loaded = re.findall(r'^\[intern (.+\.vo) \.\.\.$', kernel, re.M)
    check(len(loaded) == len(set(loaded)) == 579, 'unique kernel-loaded objects', failures)
    check(re.findall(r'^Checking library: (.+)$', kernel, re.M) == lock['checked_modules'],
          'checked module list', failures)

    # Stage 7 contemporaneous post-check record.
    stage7_result = json.loads((RECORD / 'result.json').read_text())
    check(stage7_result['exit_code'] == 0 and digest(RECORD / 'output.log') == stage7_result['output_sha256'],
          'Stage 7 dependency record identity', failures)
    stage7 = {row['path']: row['sha256'] for row in json.loads((RECORD / 'output.log').read_text())['files']}
    check(set(stage7) == set(loaded), 'Stage 7 record membership', failures)

    # Bytes collected read-only from the stopped Stage 7 container.
    collected = {name: digest(args.reference_work / name.lstrip('/')) for name in sorted(loaded)}
    check(collected == stage7, 'collected bytes equal Stage 7 record', failures)
    for rel in OWN:
        name = ATTEMPT + '/' + rel
        check(digest(STAGE7 / rel) == collected.get(name), 'own object archive identity:' + rel, failures)

    fixed = {'linux/' + rel: digest(STAGE7 / rel) for rel in FIXED}
    check(fixed['linux/gcd-selftest.elf'] == policy['release_artifact']['sha256']
          == implementation['files']['results/stage7/accepted/own/gcd-selftest.elf'], 'ELF identity', failures)
    for name in ['Execution.v', 'Images.v', 'Proof.v', 'Statements.v', 'Witness.v', 'WitnessSpec.v']:
        check(fixed['linux/source/' + name] == implementation['files']['examples/binary/' + name],
              'locked proof source:' + name, failures)
    check(fixed['linux/gcd_selftest.c'] == implementation['files']['examples/binary/gcd_selftest.c'],
          'locked C source', failures)
    for name, value in report['generated_input_sha256'].items():
        check(fixed['linux/source/' + name] == value, 'generated input:' + name, failures)
    check(report['binding_wrapper_sha256'] == fixed['linux/wrap/Wrapper.v']
          and report['witness_binding_wrapper_sha256'] == fixed['linux/wrap/WitnessWrapper.v'],
          'generated binding wrappers', failures)
    own = {'linux/' + rel: collected[ATTEMPT + '/' + rel] for rel in OWN}

    command = report['rocqchk_commands'][0]['command']
    check(report['rocqchk_commands'][0]['exit_code'] == 0 and len(report['rocqchk_commands']) == 1,
          'historical kernel exit', failures)
    axioms = re.search(r'^\* Axioms:\n((?:    .+\n)+)', kernel, re.M)
    check(axioms is not None and sorted(line.strip() for line in axioms.group(1).splitlines())
          == sorted(lock['independent_closure_assumptions']), 'raw kernel axiom summary', failures)
    for line in SUMMARY:
        check(kernel.splitlines().count(line) == 1, 'raw kernel summary line:' + line, failures)

    base = json.loads((args.base_identity / 'result.json').read_text())
    config = (args.base_identity / 'config.json').read_bytes()
    check('sha256:' + sha(config) == base['config'], 'base config digest', failures)
    check(json.loads(config)['rootfs']['diff_ids'] == base['rootfs_diff_ids'], 'base diff IDs', failures)
    check(base['platform_manifest'] == policy['deployment']['platform_manifest']
          and policy['deployment']['base_image'].endswith('@' + base['index']), 'base pins', failures)
    dockerfile = (ROOT / 'gate/provenance/Dockerfile').read_text()
    check('COPY --chown=1000:1000 --chmod=0444 gcd-selftest.elf /opt/forge/gcd-selftest.elf' in dockerfile
          and 'USER 1000:1000' in dockerfile
          and 'ENTRYPOINT ["python3", "-c", "import signal; signal.pause()"]' in dockerfile,
          'Dockerfile package settings', failures)

    identities = {
        'format_version': 1, 'end_to_end': False,
        'scope': 'independent expected identities for Stage 9 proof receipts and packages; not proof evidence',
        'receipt': {
            'attempt': 'attempt-0001', 'attempt_root': ATTEMPT,
            'fixed_artifacts': {**fixed, **own},
            'closure_sha256': collected,
            'checked_artifact_suffixes': ['.c', '.elf', '.hex', '.v', '.vo'],
            'kernel_command': command,
            'kernel_summary_lines': SUMMARY},
        'package': {
            'base_config': base['config'], 'base_rootfs_diff_ids': base['rootfs_diff_ids'],
            'elf_path': 'opt/forge/gcd-selftest.elf', 'elf_mode': 0o444, 'elf_uid': 1000, 'elf_gid': 1000,
            'user': '1000:1000', 'entrypoint': ['python3', '-c', 'import signal; signal.pause()'],
            'maximum_added_layer_bytes': 16777216},
        'reference': {
            'stage7_dependency_record_sha256': stage7_result['output_sha256'],
            'stage7_kernel_log_sha256': report['independent_kernel_log_sha256'],
            'base_index': base['index'], 'base_platform_manifest': base['platform_manifest']}}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(identities, sort_keys=True, indent=1) + '\n')
    summary = {'failures': failures, 'fixed_artifacts': len(identities['receipt']['fixed_artifacts']),
               'closure_objects': len(collected), 'base_layers': len(base['rootfs_diff_ids']),
               'output_sha256': digest(args.output), 'proof_execution': 'not_run', 'end_to_end': False}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(summary, sort_keys=True, indent=1) + '\n')
    print(json.dumps(summary, sort_keys=True))
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
