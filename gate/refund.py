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
    'spec/refund/spec.lock': '993dade887f6141e9a9e27ae78e17b6cc2545923f334d83c17aad40bc3b28b57',
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
