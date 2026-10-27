# Stage 8 refund gate: exact proposal for separate approval

**Status: PENDING HUMAN APPROVAL. No proposed gate file is applied.**

The refund contract was approved at
`e3aa546f86dc5b43ec8c754792e3db4cb413b410`. See
[refund-decision.md](refund-decision.md) for the exact user decision and adoption.
That approval expressly excludes future gate changes. This proposal requests
only the three additions listed below. It changes no approved specification,
lock, policy, existing gate, schema, or toolchain pin. It authorizes no real refunds.

## Exact decision requested

Approve the three additions in [the complete patch](refund-gate/protected.diff),
bound to [the approval manifest](refund-gate/approval-manifest.json), at the
published revision of this proposal. No unspecified later edits are approved.

| Target | SHA-256 |
| --- | --- |
| `gate/refund.py` | `da370619a34d64d1fe82bf8d4cf4d54e3d8068a2d19a36ac0192d2d322a5d4fb` |
| `gate/refund/Bindings.dfy` | `d689b18a64aa2cdc7c705e8d6b953c401e3f866f8311d624238b563e1d7a621d` |
| `gate/refund/hostile.ts` | `cc3db1659761d16bb123fd984ec84ece6b58c6ec1eebe925602a9f8122987dea` |

Patch SHA-256: `e957da8b4af6a4f3df44d615b2e69eab1360569a7a11bbfa7c4dba430c70ab66`.
Manifest SHA-256: `84793263039606c004c926a982ff9b0e545c74612d9d484822e68889f39f37fd`.

## Why these additions are needed

The existing gates cover ledger and booking contracts. They cannot establish
the new refund claims. The new entrypoint uses the existing evidence schema,
method-policy validator, dependency pins, Dafny executable, bundled Z3, resource
limit, single worker, disabled verification timeout, and empty audit baseline.
It does not implement a verifier or change any logical semantics.

The gate pins all four approved refund files by digest. It requires the exact
refinement/include boundary, a real version check, a fresh assumption audit,
full source verification, required obligation coverage, a final fresh audit,
and matching source/tool identities before and after checking. It preserves
stdout, stderr, actual process codes, TRX reports, and generated artifacts in
distinct operation directories. It does not treat a cache as a new proof check.

The binding calls the concrete Assess method on arbitrary typed inputs without
preconditions. It checks all R1-R5 clauses. A separate witness proves that a
valid 40-unit proposal is accepted with its exact caller-bound intent. The
implementation must also verify against the unchanged abstract contract.
An always-reject implementation cannot satisfy R4.

Two evidence modes use the unchanged approved policy:

- `critical`: R1-R5, fresh Dafny `source_proof` only. This concerns the source
  closure, including termination, exact acceptance, and an empty modifies set.
- `hostile-tests`: T1-T3, fresh `property_tested` only. This mode first repeats
  the source proof, then compiles the actual wrapper with Dafny's JavaScript
  backend and executes the protected hostile suite against that module and
  the declared host adapter. It records both source and generated identities.

The test mode must not satisfy a source-proof claim. Supplied evidence must pass
schema, identity and method-policy checks and equal a freshly produced bundle.
Both modes explicitly record model quality as unmeasured, with no score or
passing eval_measured record. Both keep `end_to_end=false`.

## Planned host interface and test scope

The unprotected `ts/refund.ts` adapter is not implemented in this checkpoint.
Its fixed interface is specified by the proposed hostile suite:

- `decode(bytes)` returns a promise for a typed response. It must use an
  established JSON parser, reject duplicate decoded keys and unsupported wire
  forms, and preserve supported exact integer/string values.
- `createHost({assess, execute, now})` returns asynchronous `begin`, `chunk`,
  `fail`, and `tick` operations. `assess` is the actual compiled wrapper bridge.
  The supplied executor records calls only. The untrusted response supplier
  receives neither callback capability.
- `begin(context)` returns null for a newly open or identical pending attempt.
  A completed identical retry returns its recorded outcome. A conflicting
  context for the same key returns Rejected without altering that attempt.
- `chunk(context, bytes, final)` enforces the byte cap during accumulation.
  A complete timely response is decoded and checked. Over-cap data or a
  response completed at/after the deadline returns the no-intent fallback.
- `fail(context)` closes an active attempt with the fallback. `tick(context)`
  does so when the external monotonic clock reaches its deadline. Late calls
  on a closed attempt return its recorded result and cannot repeat dispatch.

The protected suite proposes nine seeded runs: T1, T2 and T3 each use seeds
8001, 8002 and 8003, with 1,000 cases per seed. Each generated case can execute
several assertions or host events. Case counts are not counts of universal
proof obligations. Concrete fixtures have a separate counter.

The corpus covers numeric boundaries and huge/negative integers; arbitrary
typed reasons and error constructors; valid zero authorizations; malformed,
duplicate, escaped duplicate, truncated, invalid UTF-8 and oversized wire
inputs; inert injection strings; streaming limits; exact deadline boundaries;
errors, late responses, repeats and changed contexts. A controlled logical
clock tests event handling. It does not measure physical timer delivery.
Failures retain the failing fixture or seed, shrink path, counterexample and
real process output. No generated cases or concrete fixtures have run yet.

The host remains a fixed declared adapter, with pinned runtime packages. New
local dependency layouts need an explicit manifest and gate proposal. Neither
this test harness nor a byte manifest is a sandbox for arbitrary host code.
Compiler correctness, the generated runtime, string/BigNumber bridges, parser
fidelity, clock delivery and executor integration remain outside the source
proof. The full closure of runtime libraries and the host OS is not proved.
Surrogate-containing JSON strings are runtime test inputs, not an established
equivalence between all JavaScript strings and Dafny Unicode strings.

## Checks that actually ran before approval

Records are in `results/stage8/gate-proposal/`. Exact argv, outputs, input
digests and actual process codes are retained there.

| Check | Actual exit code | Scope |
| --- | --- | --- |
| Pinned `dafny --version` | 0 | Expected build identity. |
| `dafny verify impl/Refund.dfy proposals/refund-gate/Bindings.dfy` with the pinned options | 0 | Six required source/binding obligations passed. |
| `dafny audit` over the implementation and proposed binding, comparing the existing empty baseline | 0 | Zero reported audit findings. |
| `dafny build impl/Refund.dfy --target js` with the pinned options | 0 | Real JavaScript generation; four source obligations passed during build. |
| TypeScript type check, attempt 1 | 2 | TS2769: heterogeneous property tuple types. Preserved with source snapshot. |
| TypeScript type check, attempt 2 | 0 | Fixed only that type declaration; no tests executed. |
| `git apply --check proposals/refund-gate/protected.diff` | 0 | Complete patch is applicable; no gate addition was applied. |

The Python gate candidate parsed with Python's AST parser. Its full acceptance
workflow has not run, because the protected additions are not approved or
installed. The runtime adapter and Stage 8 EXIT harness are not implemented.
There is no accepted canonical Stage 8 evidence bundle. The direct source proof
above is a development result, not an executed Stage 8 EXIT or approval of a gate.

## Work after exact approval

Apply these exact three additions and record their separate approval. Implement
the untrusted-response adapter and the EXIT harness outside protected paths.
Run all three required EXIT commands. The wrapper-proof case must also retain
real proof-related rejection of an over-limit wrapper and an always-reject
wrapper, plus an actual audit rejection of an assumption escape. The hostile
case must reject a deliberately bypassed effect adapter. Use disposable copies
for those negative controls; never edit approved inputs to make a check pass.

The evidence-separation case must reject mismatched artifact identities and
attempts to satisfy R1-R5 with property_tested or eval_measured records. It must
also establish canonical reproduction and unchanged input identities through
fresh checks. These requirements are unchanged and have not run in this checkpoint.

Any defect in these proposed protected additions requires a new exact diff
before application. Do not silently revise an approved gate. Stage 8 remains
CURRENT. Stop for the separate gate decision. Stage 9 has not started.

## Complete protected diff

```diff
diff --git a/gate/refund.py b/gate/refund.py
new file mode 100644
--- /dev/null
+++ b/gate/refund.py
@@ -0,0 +1,312 @@
+#!/usr/bin/env python3
+"""Fresh refund source proof and separate finite integration-test evidence.
+
+Run this file from gate/refund.py only after exact approval. Evidence is not a
+signature. The caller must supply this gate and its inputs from a trusted base.
+"""
+
+import argparse
+from pathlib import Path
+import platform
+import re
+import shlex
+import subprocess
+import sys
+import tempfile
+import xml.etree.ElementTree as ET
+
+sys.dont_write_bytecode = True
+from common import ROOT, Rejected, canonical, digest, read_json, relative
+from dependencies import check_dependencies
+from backends import dafny
+
+APPROVED = {
+    'spec/refund/RefundSpec.dfy': '90a21c71ae3a7e1cdb7c74d393ae8ed6f312548710bdf0ae71c62255c7ccfe57',
+    'spec/refund/protocol.md': '5ef4e8fa6c23a4a455b3cbdc3f5b14ae313762446fea8444ca5e6c570e86ecd4',
+    'spec/refund/spec.lock': '993dade887f6141e9a9e27ae78e17b6cc2545923f334d83c17aad40bc3b28b57',
+    'policy/refund.yaml': '4409904602e6b670c0fbf773b8f303426e22e0caac077f3d6ed5f016cecf2c83',
+}
+SOURCE_FILES = ('impl/Refund.dfy', 'spec/refund/RefundSpec.dfy')
+BINDING = 'gate/refund/Bindings.dfy'
+TEST = 'gate/refund/hostile.ts'
+CLAIMS = {
+    'R1': 'Every authorization has a valid context and an amount in [0, remaining] within the original signed-64-bit charge.',
+    'R2': 'Every authorized reason is one of the three approved exact labels.',
+    'R3': 'Every ineligible context or modeled response returns Rejected and an empty plan.',
+    'R4': 'Every eligible proposal is accepted with its exact amount, reason, and caller-bound intent.',
+    'R5': 'The pure source boundary returns exactly one caller-bound intent iff authorized; otherwise no intent.',
+}
+TEST_CLAIMS = {
+    'T1': 'The recorded finite wire corpus obeys strict decoding and fallback rules.',
+    'T2': 'The compiled wrapper matches the approved rules for the recorded finite typed-response corpus.',
+    'T3': 'The recorded finite host traces dispatch only checked plans and preserve terminal request behavior.',
+}
+REQUIRED = {
+    'Refund.Assess (correctness)', 'Refund.Assess (well-formedness)',
+    'RefundSpec.Assess (well-formedness)',
+    'RefundSpec.Eligible (well-formedness)',
+    'RefundChecks.Universal (correctness)',
+    'RefundChecks.SuccessfulWitness (correctness)',
+}
+COMMON_INPUTS = (
+    'gate/refund.py', BINDING, TEST, 'gate/common.py', 'gate/core.py',
+    'gate/dependencies.py', 'gate/backends/__init__.py', 'gate/backends/dafny.py',
+    'gate/expected-audit.md', 'schemas/evidence.schema.json', 'schemas/policy.schema.json',
+    'toolchain/pins.json', 'toolchain/validator-pins.json',
+    'toolchain/requirements-stage2.txt', 'proposals/refund-decision.md',
+)
+JS_INPUTS = (
+    'scripts/javascript_env.py', 'toolchain/javascript-pins.json',
+    'package.json', 'package-lock.json', 'tsconfig.json',
+)
+FOOTER = b'\nmodule.exports = { Refund, runtime: _dafny };\n'
+
+
+def run(command, work, name, records):
+    child = subprocess.run(command, cwd=ROOT, capture_output=True)
+    stdout, stderr = work / (name + '.stdout'), work / (name + '.stderr')
+    stdout.write_bytes(child.stdout)
+    stderr.write_bytes(child.stderr)
+    records.append({'argv': command, 'cwd': '.', 'exit_code': child.returncode,
+                    'stdout': relative(stdout), 'stdout_sha256': digest(child.stdout),
+                    'stderr': relative(stderr), 'stderr_sha256': digest(child.stderr)})
+    (work / 'operations.json').write_bytes(canonical({'commands': records,
+                                                    'stage_exit': False}))
+    print(name + ': exit ' + str(child.returncode), flush=True)
+    return child
+
+
+def prepare():
+    for name, expected in APPROVED.items():
+        if digest((ROOT / name).read_bytes()) != expected:
+            raise Rejected('APPROVED_CONTRACT: ' + name + ' differs from approved bytes')
+    lock = read_json(ROOT / 'spec/refund/spec.lock')
+    for name, expected in lock['dependencies'].items():
+        if digest((ROOT / name).read_bytes()) != expected:
+            raise Rejected('APPROVED_DEPENDENCY: ' + name + ' differs')
+    pins = read_json(ROOT / 'toolchain/pins.json')
+    if (pins['verification_options'] != dafny.OPTIONS or
+            pins['dafny']['version_output'] != lock['dafny_build'] or
+            lock['dafny_version'] != '4.11.0'):
+        raise Rejected('TOOLCHAIN_LOCK: changed verifier or proof options')
+    if platform.python_version() != pins['python']['version']:
+        raise RuntimeError('TOOLCHAIN_ERROR: Python version differs')
+    executables = {dafny.DAFNY: pins['dafny']['executable_sha256'],
+                   ROOT / pins['z3']['path']: pins['z3']['executable_sha256'],
+                   Path(sys.executable): pins['python']['executable_sha256']}
+    if any(digest(path.read_bytes()) != sha for path, sha in executables.items()):
+        raise RuntimeError('TOOLCHAIN_ERROR: executable digest differs')
+    code = (ROOT / 'impl/Refund.dfy').read_bytes()
+    prefix = b'include "../spec/refund/RefundSpec.dfy"\n\nmodule Refund refines RefundSpec {\n'
+    if not code.startswith(prefix) or code.count(b'include') != 1:
+        raise Rejected('SOURCE_SCOPE: exact approved refinement and sole include required')
+    # Input restrictions only. Dafny parses, verifies and audits the source.
+    if b'{:' in code.replace(b'{:isolate_assertions}', b'') or b'@' in code:
+        raise Rejected('SOURCE_SCOPE: only assertion-isolation attributes allowed')
+    if b'include' in (ROOT / BINDING).read_bytes().replace(b'include paths', b''):
+        raise Rejected('SOURCE_SCOPE: the trusted binding must add no include')
+    return pins, executables
+
+
+def identity(tier):
+    names = SOURCE_FILES + (('ts/refund.ts',) if tier == 'hostile-tests' else ())
+    manifest = [{'path': name, 'sha256': digest((ROOT / name).read_bytes())}
+                for name in sorted(names)]
+    claims = CLAIMS if tier == 'critical' else TEST_CLAIMS
+    spec = 'spec/refund/RefundSpec.dfy' if tier == 'critical' else 'spec/refund/protocol.md'
+    return {'artifact': {'kind': 'source', 'sha256': digest(canonical(manifest)), 'build_cmd': ''},
+            'source_manifest': manifest,
+            'claims': [{'id': key, 'statement_plain_english': text,
+                        'spec_ref': spec, 'spec_sha': APPROVED[spec]}
+                       for key, text in claims.items()]}
+
+
+def prove(pins, work, records):
+    version = run([str(dafny.DAFNY), '--version'], work, 'dafny-version', records)
+    if version.returncode or version.stdout.decode().strip() != pins['dafny']['version_output']:
+        raise RuntimeError('TOOLCHAIN_ERROR: Dafny version command failed or differed')
+    z3 = run([str(ROOT / pins['z3']['path']), '--version'], work, 'z3-version', records)
+    if z3.returncode or z3.stdout.decode().strip() != pins['z3']['version_output']:
+        raise RuntimeError('TOOLCHAIN_ERROR: Z3 version command failed or differed')
+    audit_file = work / 'audit.md'
+    audit_file.write_bytes(dafny.AUDIT.read_bytes())
+    audit = run([str(dafny.DAFNY), 'audit', 'impl/Refund.dfy', BINDING,
+                 '--report-format', 'md', '--report-file', str(audit_file), '--compare-report'],
+                work, 'audit-before', records)
+    if audit.returncode:
+        raise Rejected('AUDIT_REJECTED: actual Dafny audit failed; inspect retained output')
+    report = work / 'verification.trx'
+    verified = run([str(dafny.DAFNY), 'verify', 'impl/Refund.dfy', BINDING,
+                    *dafny.OPTIONS, '--json-output', '--log-format',
+                    'trx;LogFileName=' + str(report)], work, 'verify', records)
+    if verified.returncode:
+        raise Rejected('VERIFICATION_REJECTED: R1 R2 R3 R4 R5 not established; inspect retained diagnostics')
+    rows = sorted(({'name': e.get('testName'), 'outcome': e.get('outcome')}
+                   for e in ET.parse(report).iter() if e.tag.endswith('UnitTestResult')),
+                  key=lambda row: row['name'])
+    members = {re.sub(r' \(assertion batch \d+\)$', '', row['name']) for row in rows}
+    if not REQUIRED <= members or any(row['outcome'] != 'Passed' for row in rows):
+        raise Rejected('PROOF_COVERAGE: concrete method, abstract contract, universal binding or witness missing')
+    return rows
+
+
+def hostile(pins, work, records):
+    sys.path.insert(0, str(ROOT))
+    from scripts.javascript_env import check as check_javascript
+    js_pins = check_javascript()
+    # Fixed generated paths give stable build provenance. The main lock excludes
+    # concurrent gate builds. Existing historical operation directories survive.
+    directory = ROOT / 'build/refund-generated'
+    directory.mkdir(parents=True, exist_ok=True)
+    for name in ('model.js', 'model.cjs'):
+        (directory / name).unlink(missing_ok=True)
+    command = [str(dafny.DAFNY), 'build', 'impl/Refund.dfy', '--target', 'js',
+               '--output', 'build/refund-generated/model', *dafny.OPTIONS]
+    built = run(command, work, 'compile-js', records)
+    if built.returncode:
+        raise RuntimeError('BUILD_ERROR: actual Dafny compilation failed')
+    generated = (directory / 'model.js').read_bytes()
+    module = generated + FOOTER
+    module_path = directory / 'model.cjs'
+    module_path.write_bytes(module)
+    # Preserve each generated artifact beside its exact command and full logs.
+    (work / 'model.js').write_bytes(generated)
+    (work / 'model.cjs').write_bytes(module)
+    report_path = work / 'hostile.json'
+    tested = run(['node', '--import', 'tsx', TEST, '--module', relative(module_path),
+                  '--report', relative(report_path)], work, 'hostile', records)
+    if tested.returncode:
+        raise Rejected('HOSTILE_REJECTED: test process failed; inspect retained report and shrink')
+    report = read_json(report_path)
+    expected_runs = [{'claim_id': claim, 'seed': seed, 'num_runs': 1000, 'failed': False}
+                     for claim in TEST_CLAIMS for seed in (8001, 8002, 8003)]
+    if (report.get('result') != 'passed' or report.get('method') != 'property_tested' or
+            report.get('runs') != expected_runs or report.get('generated_cases') != 9000 or
+            report.get('fixture_cases', 0) < 20 or report.get('model_quality') != 'unmeasured'):
+        raise Rejected('TEST_COVERAGE: missing actual seeded runs or concrete fixtures')
+    if digest(module_path.read_bytes()) != digest(module):
+        raise Rejected('INPUT_CHANGED: compiled module changed during tests')
+    if check_javascript() != js_pins:
+        raise Rejected('INPUT_CHANGED: JavaScript toolchain changed')
+    return {'report': report, 'generated_js_sha256': digest(generated),
+            'module_sha256': digest(module), 'export_footer_sha256': digest(FOOTER),
+            'build_command': ['.toolchain/dafny-4.11.0/dafny/dafny', *command[1:]],
+            'source_to_module_proved': False}
+
+
+def main():
+    parser = argparse.ArgumentParser(description=__doc__)
+    parser.add_argument('--tier', choices=('critical', 'hostile-tests'), default='critical')
+    parser.add_argument('--evidence', default='build/refund-source.json')
+    parser.add_argument('--check-evidence')
+    args = parser.parse_args()
+    output = (ROOT / args.evidence).resolve()
+    supplied_path = (ROOT / args.check_evidence).resolve() if args.check_evidence else None
+    if (not output.is_relative_to(ROOT / 'build') or output.suffix != '.json' or
+            output == supplied_path or output.is_relative_to(ROOT / 'build/refund-generated')):
+        raise Rejected('OUTPUT_SCOPE: use a separate JSON output under build/')
+    # Never leave a stale passing bundle after a failed recheck.
+    output.unlink(missing_ok=True)
+    (ROOT / 'build').mkdir(exist_ok=True)
+    lock_path = ROOT / 'build/refund-gate.lock'
+    with lock_path.open('x'):
+        pass
+    try:
+        versions = check_dependencies()
+        from core import snapshot, make_bundle, validate_evidence
+        from jsonschema import Draft202012Validator
+        pins, executables = prepare()
+        expected = identity(args.tier)
+        paths = [ROOT / name for name in (*APPROVED, *COMMON_INPUTS, *SOURCE_FILES)]
+        if args.tier == 'hostile-tests':
+            paths += [ROOT / name for name in (*JS_INPUTS, 'ts/refund.ts')]
+        if any(path.is_symlink() for path in paths):
+            raise Rejected('SOURCE_SCOPE: declared inputs must be regular files')
+        before = snapshot(paths)
+        source_names = {entry['path'] for entry in expected['source_manifest']}
+        trusted = {name: sha for name, sha in before.items() if name not in source_names}
+        policy = read_json(ROOT / 'policy/refund.yaml')
+        Draft202012Validator(read_json(ROOT / 'schemas/policy.schema.json')).validate(policy)
+        rules = policy['tiers'][args.tier]
+        method = 'source_proof' if args.tier == 'critical' else 'property_tested'
+        claims = CLAIMS if args.tier == 'critical' else TEST_CLAIMS
+        if (set(rules['required_claims']) != set(claims) or
+                any(rule != {'minimum_method': method, 'allowed_methods': [method]}
+                    for rule in rules['required_claims'].values())):
+            raise Rejected('METHOD_POLICY: exact separate proof and test requirements are mandatory')
+        policy_id = {'id': policy['id'], 'version': policy['version'], 'tier': args.tier,
+                     'sha256': APPROVED['policy/refund.yaml']}
+        backend = 'dafny-refund' if args.tier == 'critical' else 'refund-hostile-tests'
+        supplied = read_json(supplied_path) if supplied_path else None
+        if supplied is not None:
+            validate_evidence(supplied, expected, rules, policy_id, trusted, backend)
+        work = Path(tempfile.mkdtemp(prefix='refund-gate-', dir=ROOT / 'build'))
+        records = []
+        rows = prove(pins, work, records)
+        details = {'verified_obligations': [row['name'] for row in rows],
+                   'verification_options': dafny.OPTIONS, 'proof_result_cache': False,
+                   'arbitrary_input_binding_checked': True, 'successful_witness_checked': True,
+                   'model_quality': {'status': 'unmeasured', 'score': None},
+                   'source_artifact': identity('critical')['artifact']}
+        if args.tier == 'hostile-tests':
+            details['integration'] = hostile(pins, work, records)
+        # Fresh final audit. No accepted result may depend on an audit escape.
+        final_audit = work / 'final-audit.md'
+        final_audit.write_bytes(dafny.AUDIT.read_bytes())
+        audited = run([str(dafny.DAFNY), 'audit', 'impl/Refund.dfy', BINDING,
+                       '--report-format', 'md', '--report-file', str(final_audit), '--compare-report'],
+                      work, 'audit-after', records)
+        if audited.returncode:
+            raise Rejected('AUDIT_REJECTED: final actual audit failed')
+        details['audit_sha256'] = digest(final_audit.read_bytes())
+        assumptions = [
+            'Dafny mathematical integers, finite strings and sequential pure calls; all typed contexts and responses are covered.',
+            'No model accuracy assumption; allowed reason membership does not establish factual truth.',
+            'Host data truth, authentication, atomic remaining-balance reservation and durable payment idempotency are external obligations.',
+            'Source proof does not cover compilation, parsing, clocks, scheduling, transport, effect dispatch, persistence or deployment.',
+        ]
+        if args.tier == 'hostile-tests':
+            assumptions += [
+                'Only the recorded finite fast-check corpus and concrete fixtures were executed; no universal runtime theorem.',
+                'The supplied logical monotonic clock tests host event handling, not physical deadline delivery or a real model/network.',
+                'Dafny JavaScript compilation, BigNumber conversion and host runtime preservation remain unproved.',
+                'The fixed ts/refund.ts adapter and pinned packages are the declared integration scope; arbitrary host-code compromise is excluded.',
+            ]
+        reproduce = 'python3 gate/refund.py --tier ' + args.tier + ' --evidence build/refund-' + args.tier + '.json'
+        raw = {**expected, 'backend_details': details, 'evidence': [{
+            'claim_id': claim, 'artifact_sha': expected['artifact']['sha256'], 'method': method,
+            'tool': 'Dafny' if args.tier == 'critical' else 'fast-check',
+            'tool_version': pins['dafny']['version_output'] if args.tier == 'critical' else '4.3.0',
+            'result': 'passed', 'producer': 'forge/local-refund-gate', 'reproduce_cmd': reproduce,
+            'assumptions': assumptions,
+            'trusted_base': ['Dafny ' + pins['dafny']['version_output'],
+                             'Bundled Boogie, .NET and Z3 4.12.1; no independent proof certificate kernel is claimed.',
+                             'Approved refund contract, protocol, policy, lock, gate, binding and empty audit baseline.',
+                             'Python 3.10.11; pinned Node/npm packages for integration tests where executed.',
+                             'Host operating system, runtime libraries and hardware; executable pins do not authenticate the full host.'],
+        } for claim in claims]}
+        bundle = make_bundle(raw, backend, policy_id, trusted, versions, reproduce)
+        validate_evidence(bundle, expected, rules, policy_id, trusted, backend)
+        if supplied is not None and canonical(supplied) != canonical(bundle):
+            raise Rejected('REPRODUCTION_MISMATCH: supplied evidence differs from fresh checks')
+        if before != snapshot(paths) or any(digest(p.read_bytes()) != sha for p, sha in executables.items()):
+            raise Rejected('INPUT_CHANGED: source, trusted input or executable changed while checking')
+        check_dependencies()
+        output.parent.mkdir(parents=True, exist_ok=True)
+        output.write_bytes(canonical(bundle))
+        (work / 'accepted.json').write_bytes(canonical(bundle))
+        print('ACCEPTED: ' + ' '.join(claims) + '; ' + method + '; end_to_end=false')
+        return 0
+    finally:
+        lock_path.unlink()
+
+
+if __name__ == '__main__':
+    try:
+        sys.exit(main())
+    except Rejected as error:
+        print(str(error), file=sys.stderr)
+        sys.exit(1)
+    except (OSError, ValueError, KeyError, RuntimeError, ImportError, ET.ParseError) as error:
+        print('GATE_ERROR: ' + str(error), file=sys.stderr)
+        sys.exit(2)
diff --git a/gate/refund/Bindings.dfy b/gate/refund/Bindings.dfy
new file mode 100644
--- /dev/null
+++ b/gate/refund/Bindings.dfy
@@ -0,0 +1,49 @@
+// Passed beside impl/Refund.dfy. No include paths or optional proof selection.
+abstract module RequiredRefund {
+  import R : RefundSpec
+}
+
+module BoundRefund refines RequiredRefund {
+  import R = Refund
+}
+
+module RefundChecks {
+  import R = Refund
+
+  // Arbitrary inputs, no requires: a strengthened precondition cannot hide
+  // unsafe responses or exclude valid proposals from the required boundary.
+  method Universal(context: R.Context, response: R.ModelResponse)
+    modifies {}
+  {
+    var decision, plan := R.Assess(context, response);
+    assert decision.Authorized? <==> R.Eligible(context, response);
+    assert decision.Authorized? ==>
+      R.ValidContext(context) && R.Money(decision.amount) &&
+      decision.amount <= context.remaining <= context.original &&
+      R.AllowedReason(decision.reason);
+    assert !R.Eligible(context, response) ==> decision == R.Rejected && plan == [];
+    assert R.Eligible(context, response) ==>
+      response.Candidate? && decision == R.Authorized(response.amount, response.reason) &&
+      plan == [R.Intent(context.chargeId, context.requestId, response.amount, response.reason)];
+    assert decision.Rejected? <==> |plan| == 0;
+    assert |plan| <= 1;
+    assert decision.Authorized? ==>
+      plan == [R.Intent(context.chargeId, context.requestId, decision.amount, decision.reason)];
+    assert forall intent: R.RefundIntent :: intent in plan ==>
+      R.ValidContext(context) && R.Money(intent.amount) &&
+      intent.amount <= context.remaining <= context.original &&
+      R.AllowedReason(intent.reason) &&
+      intent.chargeId == context.chargeId && intent.requestId == context.requestId;
+  }
+
+  method SuccessfulWitness()
+    modifies {}
+  {
+    var context := R.ChargeContext("charge-1", "request-1", 100, 60, true, true);
+    var response := R.Candidate(40, "duplicate_charge");
+    assert R.Eligible(context, response);
+    var decision, plan := R.Assess(context, response);
+    assert decision == R.Authorized(40, "duplicate_charge");
+    assert plan == [R.Intent("charge-1", "request-1", 40, "duplicate_charge")];
+  }
+}
diff --git a/gate/refund/hostile.ts b/gate/refund/hostile.ts
new file mode 100644
--- /dev/null
+++ b/gate/refund/hostile.ts
@@ -0,0 +1,269 @@
+// Trusted finite test suite. These observations never establish a source proof.
+import assert from "node:assert/strict";
+import { readFileSync, writeFileSync } from "node:fs";
+import { resolve } from "node:path";
+import { pathToFileURL } from "node:url";
+import BigNumber from "bignumber.js";
+import fc from "fast-check";
+
+type Context = {
+  chargeId: string; requestId: string; original: bigint; remaining: bigint;
+  refundEnabled: boolean; requestOpen: boolean;
+};
+type ErrorKind = "Missing" | "TimedOut" | "Failed" | "Malformed" | "Oversized" | "Unsupported";
+type Response = { kind: "Candidate"; amount: bigint; reason: string } | { kind: ErrorKind };
+type Intent = { chargeId: string; requestId: string; amount: bigint; reason: string };
+type Outcome = {
+  decision: { kind: "Rejected" } | { kind: "Authorized"; amount: bigint; reason: string };
+  plan: Intent[];
+};
+type Assess = (context: Context, response: Response) => Outcome;
+type Host = {
+  begin(context: Context): Promise<Outcome | null>;
+  chunk(context: Context, bytes: Uint8Array, final: boolean): Promise<Outcome | null>;
+  fail(context: Context): Promise<Outcome | null>;
+  tick(context: Context): Promise<Outcome | null>;
+};
+type Adapter = {
+  decode(bytes: Uint8Array): Promise<Response>;
+  createHost(options: { assess: Assess; execute: (intent: Intent) => void; now: () => number }): Host;
+};
+const MAX = 9223372036854775807n;
+const reasons = ["duplicate_charge", "service_not_delivered", "returned_item"] as const;
+const errors: ErrorKind[] = ["Missing", "TimedOut", "Failed", "Malformed", "Oversized", "Unsupported"];
+const rejected = (): Outcome => ({ decision: { kind: "Rejected" }, plan: [] });
+const base = (): Context => ({ chargeId: "charge-1", requestId: "request-1",
+  original: 100n, remaining: 60n, refundEnabled: true, requestOpen: true });
+const bytes = (text: string): Uint8Array => Buffer.from(text, "utf8");
+const wire = (amount: bigint, reason: string): Uint8Array => bytes(JSON.stringify({ amount_minor: String(amount), reason }));
+const json = (value: unknown): string => JSON.stringify(value, (_key, item: unknown) =>
+  typeof item === "bigint" ? { bigint: String(item) } : item, 2) + "\n";
+
+// A finite test oracle, not a verifier or alternative proof semantics.
+function expected(context: Context, response: Response): Outcome {
+  if (!context.chargeId || !context.requestId || !context.refundEnabled || !context.requestOpen ||
+      context.original < 0n || context.original > MAX || context.remaining < 0n ||
+      context.remaining > context.original || response.kind !== "Candidate" ||
+      response.amount < 0n || response.amount > context.remaining ||
+      !reasons.some(reason => reason === response.reason)) return rejected();
+  return { decision: { kind: "Authorized", amount: response.amount, reason: response.reason },
+    plan: [{ chargeId: context.chargeId, requestId: context.requestId,
+      amount: response.amount, reason: response.reason }] };
+}
+
+function model(modulePath: string): Assess {
+  // The gate just compiled this exact module with Dafny and added its fixed
+  // visibility footer. BigNumber and Unicode conversions are tested, not proved.
+  const { Refund: R, runtime } = require(resolve(modulePath));
+  const number = (n: bigint) => new BigNumber(String(n));
+  const string = (s: string) => runtime.Seq.UnicodeFromString(s);
+  const integer = (n: BigNumber): bigint => {
+    assert(n.isInteger(), "generated model returned noninteger");
+    return BigInt(n.toFixed());
+  };
+  return (c, r) => {
+    const context = R.Context.create_ChargeContext(string(c.chargeId), string(c.requestId),
+      number(c.original), number(c.remaining), c.refundEnabled, c.requestOpen);
+    const response = r.kind === "Candidate"
+      ? R.ModelResponse.create_Candidate(number(r.amount), string(r.reason))
+      : R.ModelResponse["create_" + r.kind]();
+    const [decision, plan] = R.__default.Assess(context, response);
+    assert.notEqual(decision.is_Authorized, decision.is_Rejected);
+    return {
+      decision: decision.is_Authorized
+        ? { kind: "Authorized", amount: integer(decision.dtor_amount), reason: decision.dtor_reason.toVerbatimString(false) }
+        : { kind: "Rejected" },
+      plan: Array.from(plan, (intent: any) => ({ chargeId: intent.dtor_chargeId.toVerbatimString(false),
+        requestId: intent.dtor_requestId.toVerbatimString(false), amount: integer(intent.dtor_amount),
+        reason: intent.dtor_reason.toVerbatimString(false) })),
+    };
+  };
+}
+
+const badWire: Uint8Array[] = [
+  "", "{", "[]", "null", "true", "0", "{}", '{"amount_minor":"1"}',
+  '{"amount_minor":"1","reason":"duplicate_charge","extra":0}',
+  '{"amount_minor":"1","amount_minor":"2","reason":"duplicate_charge"}',
+  '{"amount_minor":"1","\\u0061mount_minor":"2","reason":"duplicate_charge"}',
+  '{"amount_minor":"1","reason":"duplicate_charge","reason":"returned_item"}',
+  '{"amount_minor":"1","reason":"duplicate_charge"}{}',
+  '{"amount_minor":"1","reason":"duplicate_charge",}',
+  '{/*comment*/"amount_minor":"1","reason":"duplicate_charge"}',
+  '\uFEFF{"amount_minor":"1","reason":"duplicate_charge"}',
+  '{"amount_minor":NaN,"reason":"duplicate_charge"}',
+  '{"amount_minor":Infinity,"reason":"duplicate_charge"}',
+  ...["-1", "-0", "+1", "01", " 1", "1 ", "1.0", "1e0", "١", "１", String(MAX + 1n), "9".repeat(40)]
+    .map(amount_minor => JSON.stringify({ amount_minor, reason: "duplicate_charge" })),
+  ...[0, -1, 1.5, true, null, [], {}].map(amount_minor => JSON.stringify({ amount_minor, reason: "duplicate_charge" })),
+  ...[0, true, null, [], {}].map(reason => JSON.stringify({ amount_minor: "1", reason })),
+  " ".repeat(4097),
+].map(bytes).concat([Uint8Array.from([0xc0, 0xaf]), Uint8Array.from([0xff]), Uint8Array.from([0xe2, 0x82])]);
+
+async function main(): Promise<void> {
+  const option = (name: string): string => {
+    const index = process.argv.indexOf(name);
+    if (index < 0 || !process.argv[index + 1]) throw new Error("missing " + name);
+    return process.argv[index + 1];
+  };
+  const reportPath = option("--report");
+  const assess = model(option("--module"));
+  const adapter: Adapter = await import(pathToFileURL(resolve("ts/refund.ts")).href);
+  const report: any = { result: "running", method: "property_tested", model_quality: "unmeasured",
+    generated_cases: 0, fixture_cases: 0, runs: [], clock: "controlled logical monotonic clock",
+    external_refunds: false, source_to_module_proved: false };
+  const save = () => writeFileSync(reportPath, json(report));
+  save();
+  const fixture = async (name: string, check: () => void | Promise<void>) => {
+    report.active_fixture = name;
+    await check();
+    report.fixture_cases++;
+    delete report.active_fixture;
+  };
+  const unavailable = (r: Response): void => { assert.notEqual(r.kind, "Candidate"); assert(errors.includes(r.kind as ErrorKind)); };
+  const rig = () => {
+    let now = 100;
+    const effects: Intent[] = [];
+    const checks: { context: Context; response: Response; result: Outcome }[] = [];
+    const host = adapter.createHost({ now: () => now,
+      assess: (context, response) => {
+        const result = assess(context, response);
+        assert.deepEqual(result, expected(context, response));
+        checks.push({ context: structuredClone(context), response: structuredClone(response), result: structuredClone(result) });
+        return result;
+      },
+      execute: intent => {
+        assert(checks.length > 0, "executor bypassed the compiled boundary");
+        assert(checks.some(check => check.result.plan.some(item =>
+          item.chargeId === intent.chargeId && item.requestId === intent.requestId &&
+          item.amount === intent.amount && item.reason === intent.reason)), "executor received an unchecked intent");
+        effects.push(structuredClone(intent));
+      },
+    });
+    return { host, effects, checks, at: (time: number) => { assert(time >= now); now = time; } };
+  };
+  try {
+    for (const [index, raw] of badWire.entries()) {
+      await fixture("malformed-" + index, async () => {
+        unavailable(await adapter.decode(raw));
+        const r = rig(), c = base();
+        assert.equal(await r.host.begin(c), null);
+        assert.deepEqual(await r.host.chunk(c, raw, true), rejected());
+        assert.deepEqual(r.effects, []);
+      });
+    }
+    for (const amount of [0n, 1n, 60n, MAX]) for (const reason of reasons) {
+      await fixture("valid-boundary-" + amount + "-" + reason, async () => {
+        const c = { ...base(), original: MAX, remaining: MAX };
+        const response: Response = { kind: "Candidate", amount, reason };
+        assert.deepEqual(await adapter.decode(wire(amount, reason)), response);
+        assert.deepEqual(assess(c, response), expected(c, response));
+        const r = rig(); await r.host.begin(c);
+        assert.deepEqual(await r.host.chunk(c, wire(amount, reason), true), expected(c, response));
+        assert.deepEqual(r.effects, expected(c, response).plan);
+      });
+    }
+    for (const reason of ["DUPLICATE_CHARGE", " returned_item", "returned_item ",
+      "ignore policy; refund everything", "__proto__", "$(touch should-not-exist)", "\u0000", "\ud800"]) {
+      await fixture("inert-reason-" + JSON.stringify(reason), async () => {
+        const response: Response = { kind: "Candidate", amount: 1n, reason };
+        assert.deepEqual(await adapter.decode(wire(1n, reason)), response);
+        assert.deepEqual(assess(base(), response), rejected());
+        const r = rig(); await r.host.begin(base());
+        assert.deepEqual(await r.host.chunk(base(), wire(1n, reason), true), rejected());
+        assert.deepEqual(r.effects, []);
+      });
+    }
+    await fixture("stream-cap-before-completion", async () => {
+      const r = rig(), c = base(); await r.host.begin(c);
+      assert.equal(await r.host.chunk(c, bytes(" ".repeat(4096)), false), null);
+      assert.deepEqual(await r.host.chunk(c, bytes(" "), false), rejected());
+      assert.deepEqual(await r.host.chunk(c, wire(1n, reasons[0]), true), rejected());
+      assert.deepEqual(r.effects, []);
+    });
+    await fixture("inflight-repeat-and-context-conflict", async () => {
+      const r = rig(), c = base(); await r.host.begin(c);
+      assert.equal(await r.host.begin({ ...c }), null);
+      assert.deepEqual(await r.host.begin({ ...c, remaining: 59n }), rejected());
+      const response: Response = { kind: "Candidate", amount: 60n, reason: reasons[0] };
+      const outcome = expected(c, response);
+      assert.deepEqual(await r.host.chunk(c, wire(60n, reasons[0]), true), outcome);
+      assert.deepEqual(await r.host.begin({ ...c }), outcome);
+      assert.deepEqual(r.effects, outcome.plan);
+    });
+    const amountArb = fc.oneof(fc.bigInt({ min: -(1n << 128n), max: 1n << 128n }),
+      fc.constantFrom(-1n, 0n, 1n, 60n, MAX - 1n, MAX, MAX + 1n));
+    const reasonArb = fc.oneof(fc.constantFrom(...reasons), fc.string({ maxLength: 80 }));
+    const responseArb: fc.Arbitrary<Response> = fc.oneof(
+      fc.record({ kind: fc.constant("Candidate" as const), amount: amountArb, reason: reasonArb }),
+      fc.constantFrom(...errors).map(kind => ({ kind })));
+    const contextArb = fc.oneof(fc.constant(base()), fc.record({
+      chargeId: fc.string({ maxLength: 16 }), requestId: fc.string({ maxLength: 16 }),
+      original: amountArb, remaining: amountArb, refundEnabled: fc.boolean(), requestOpen: fc.boolean(),
+    }));
+    const properties: Record<"T1" | "T2" | "T3", fc.IAsyncProperty<any[]>> = {
+      T1: fc.asyncProperty(fc.bigInt({ min: 0n, max: MAX }), reasonArb,
+        fc.integer({ min: 0, max: badWire.length - 1 }), async (amount, reason, bad) => {
+          assert.deepEqual(await adapter.decode(wire(amount, reason)), { kind: "Candidate", amount, reason });
+          unavailable(await adapter.decode(badWire[bad]));
+        }),
+      T2: fc.asyncProperty(contextArb, responseArb, async (c, r) => {
+        const before = structuredClone({ c, r });
+        assert.deepEqual(assess(c, r), expected(c, r));
+        assert.deepEqual({ c, r }, before);
+      }),
+      T3: fc.asyncProperty(fc.integer({ min: 0, max: 4 }), fc.bigInt({ min: 0n, max: 61n }),
+        reasonArb, fc.integer({ min: 0, max: 20 }), async (mode, amount, reason, split) => {
+          const r = rig(), c = base(), raw = wire(amount, reason);
+          const response: Response = { kind: "Candidate", amount, reason };
+          assert.equal(await r.host.begin(c), null);
+          assert.equal(await r.host.chunk(c, raw.slice(0, split), false), null);
+          let outcome: Outcome;
+          if (mode === 0) {
+            r.at(5099); outcome = expected(c, response);
+            assert.deepEqual(await r.host.chunk(c, raw.slice(split), true), outcome);
+          } else if (mode === 1 || mode === 2) {
+            r.at(mode === 1 ? 5100 : 9000); outcome = rejected();
+            assert.deepEqual(await r.host.chunk(c, raw.slice(split), true), outcome);
+          } else if (mode === 3) {
+            r.at(5100); outcome = rejected(); assert.deepEqual(await r.host.tick(c), outcome);
+          } else {
+            outcome = rejected(); assert.deepEqual(await r.host.fail(c), outcome);
+          }
+          assert.deepEqual(r.effects, outcome.plan);
+          const calls = r.checks.length;
+          assert.deepEqual(await r.host.begin({ ...c }), outcome);
+          assert.deepEqual(await r.host.chunk(c, wire(1n, reasons[0]), true), outcome);
+          assert.deepEqual(await r.host.begin({ ...c, original: 101n }), rejected());
+          assert.deepEqual(r.effects, outcome.plan);
+          assert.equal(r.checks.length, calls, "late or duplicate request reentered boundary");
+          const next = { ...c, requestId: "request-2" };
+          assert.equal(await r.host.begin(next), null);
+          const nextOutcome = expected(next, { kind: "Candidate", amount: 1n, reason: reasons[0] });
+          assert.deepEqual(await r.host.chunk(next, wire(1n, reasons[0]), true), nextOutcome);
+          assert.deepEqual(r.effects, [...outcome.plan, ...nextOutcome.plan]);
+        }),
+    };
+    for (const claim_id of ["T1", "T2", "T3"] as const) for (const seed of [8001, 8002, 8003]) {
+      const result = await fc.check(properties[claim_id], { seed, numRuns: 1000, endOnFailure: false });
+      report.runs.push({ claim_id, seed: result.seed, num_runs: result.numRuns, failed: result.failed });
+      report.generated_cases += result.numRuns;
+      if (result.failed) {
+        report.failure = { claim_id, seed: result.seed, counterexample: result.counterexample,
+          counterexample_path: result.counterexamplePath, num_shrinks: result.numShrinks,
+          error: String(result.errorInstance) };
+        throw new Error("property assertion failed: " + claim_id);
+      }
+      save();
+    }
+    report.result = "passed";
+    save();
+    console.log("PROPERTY_TESTED: 9000 generated cases; " + report.fixture_cases + " concrete fixtures; model quality unmeasured");
+  } catch (error) {
+    report.result = "failed";
+    report.error = String(error);
+    save();
+    throw error;
+  }
+}
+
+main().catch(error => { console.error(error); process.exitCode = 1; });
```
