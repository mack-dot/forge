#!/usr/bin/env python3
"""Run real Stage 8 EXIT checks. Archive attempts; never edit protected inputs."""

import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import traceback

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
from common import canonical, digest, read_json

SOURCE_FILES = (
    'impl/Refund.dfy', 'ts/refund.ts', 'tests/refund.integration.ts', 'scripts/exit_stage_8.py',
    'tests/refund.snapshot-controls.ts',
    'gate/refund.py', 'gate/refund/Bindings.dfy', 'gate/refund/hostile.ts',
    'gate/common.py', 'gate/core.py', 'gate/dependencies.py',
    'gate/backends/__init__.py', 'gate/backends/dafny.py', 'gate/expected-audit.md',
    'spec/refund/RefundSpec.dfy', 'spec/refund/protocol.md', 'spec/refund/spec.lock',
    'policy/refund.yaml', 'schemas/evidence.schema.json', 'schemas/policy.schema.json',
    'toolchain/pins.json', 'toolchain/validator-pins.json', 'toolchain/requirements-stage2.txt',
    'scripts/javascript_env.py', 'toolchain/javascript-pins.json',
    'package.json', 'package-lock.json', 'tsconfig.json', 'proposals/refund-decision.md',
    'proposals/refund-gate-decision.md',
)
REQUIRED = {
    'Refund.Assess (correctness)', 'Refund.Assess (well-formedness)',
    'RefundSpec.Assess (well-formedness)', 'RefundSpec.Eligible (well-formedness)',
    'RefundChecks.Universal (correctness)', 'RefundChecks.SuccessfulWitness (correctness)',
}


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def protected():
    names = ['spec.lock'] + [str(p.relative_to(ROOT)) for directory in ('spec', 'policy', 'gate')
                            for p in (ROOT / directory).rglob('*') if p.is_file()]
    return {p: digest((ROOT / p).read_bytes()) for p in sorted(names)}


class Run:
    def __init__(self, case):
        self.case = case
        parent = ROOT / 'results/stage8' / case
        parent.mkdir(parents=True, exist_ok=True)
        number = 1
        while (parent / f'attempt-{number:04d}').exists():
            number += 1
        self.directory = parent / f'attempt-{number:04d}'
        self.directory.mkdir()
        self.work = ROOT / 'build/stage8' / case / self.directory.name
        self.work.mkdir(parents=True, exist_ok=False)
        self.before = protected()
        self.inputs = {name: digest((ROOT / name).read_bytes()) for name in SOURCE_FILES}
        for name in SOURCE_FILES:
            target = self.directory / 'inputs' / name
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / name).read_bytes())
        self.report = {'case': case, 'argv': ['python3', 'scripts/exit_stage_8.py', '--case', case],
                       'result': 'running', 'exit_code': None, 'end_to_end': False,
                       'input_sha256': self.inputs, 'protected_before': self.before,
                       'commands': [], 'checks': []}
        self.save()

    def save(self):
        (self.directory / 'report.json').write_bytes(canonical(self.report))

    def execute(self, command, name, cwd=ROOT):
        logdir = self.directory / name
        logdir.mkdir()
        before = set((cwd / 'build').glob('refund-gate-*'))
        process = subprocess.run(command, cwd=cwd, capture_output=True)
        (logdir / 'stdout.log').write_bytes(process.stdout)
        (logdir / 'stderr.log').write_bytes(process.stderr)
        operations = []
        for directory in sorted(set((cwd / 'build').glob('refund-gate-*')) - before):
            if not directory.is_dir():
                continue
            archive = logdir / 'operations' / directory.name
            shutil.copytree(directory, archive)
            record = read_json(archive / 'operations.json')
            operations += record['commands']
        record = {'argv': command, 'cwd': str(cwd.relative_to(ROOT)) or '.',
                  'exit_code': process.returncode,
                  'stdout': str((logdir / 'stdout.log').relative_to(ROOT)),
                  'stdout_sha256': digest(process.stdout),
                  'stderr': str((logdir / 'stderr.log').relative_to(ROOT)),
                  'stderr_sha256': digest(process.stderr), 'checker_commands': operations}
        self.report['commands'].append(record)
        self.save()
        print(name + ': exit ' + str(process.returncode), flush=True)
        return process, operations, logdir

    def gate(self, name, tier='critical', cwd=ROOT, supplied=None, expected=0, marker=None):
        output = 'build/' + name + '.json'
        command = ['python3', 'gate/refund.py', '--tier', tier, '--evidence', output]
        if supplied:
            command += ['--check-evidence', str(supplied)]
        process, operations, directory = self.execute(command, name, cwd)
        require(process.returncode == expected,
                name + ': expected harness exit ' + str(expected) + ', observed ' + str(process.returncode))
        if marker:
            require(marker.encode() in process.stdout + process.stderr, name + ': missing rejection reason ' + marker)
        if expected == 0:
            bundle = read_json(cwd / output)
            (directory / 'evidence.json').write_bytes((cwd / output).read_bytes())
            self.check_bundle(bundle, tier)
            return bundle, operations, directory
        require(not (cwd / output).exists(), name + ': rejected check left passing evidence')
        return None, operations, directory

    def check_bundle(self, bundle, tier):
        method, claims = ('source_proof', set('R' + str(i) for i in range(1, 6))) if tier == 'critical' else (
            'property_tested', {'T1', 'T2', 'T3'})
        require(bundle['end_to_end'] is False, 'overclaimed end-to-end coverage')
        require({r['claim_id'] for r in bundle['evidence']} == claims, 'wrong claim set')
        require(all(r['method'] == method and r['result'] == 'passed' for r in bundle['evidence']), 'wrong evidence method')
        require(REQUIRED <= set(bundle['backend_details']['verified_obligations']), 'incomplete source coverage')
        require(bundle['backend_details']['proof_result_cache'] is False, 'cached-only proof acceptance')
        require(bundle['backend_details']['model_quality'] == {'status': 'unmeasured', 'score': None}, 'invented model evaluation')
        require(all(r['artifact_sha'] == bundle['artifact']['sha256'] for r in bundle['evidence']), 'artifact mismatch')

    def fixture(self, name):
        fixture = self.work / name
        fixture.mkdir()
        for path in SOURCE_FILES:
            target = fixture / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / path).read_bytes())
        for path in ('.toolchain', 'node_modules'):
            (fixture / path).symlink_to(ROOT / path, target_is_directory=True)
        return fixture

    def save_mutant(self, fixture, path, name):
        target = self.directory / 'mutants' / name / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes((fixture / path).read_bytes())
        manifest = {p: digest((fixture / p).read_bytes()) for p in SOURCE_FILES}
        (self.directory / 'mutants' / name / 'inputs.json').write_bytes(canonical(manifest))

    def claim_rejected(self, directory, claim):
        # Map first-party diagnostic locations to the fixed approved comment
        # labels. This does not interpret, weaken or verify the Dafny theorem.
        lines = (ROOT / 'spec/refund/RefundSpec.dfy').read_text().splitlines()
        starts = {f'R{i}': next(n + 1 for n, line in enumerate(lines) if line.strip().startswith(f'// R{i}:'))
                  for i in range(1, 6)}
        start = starts[claim]
        end = starts.get('R' + str(int(claim[1]) + 1), len(lines) + 1)
        found = False
        for path in directory.glob('operations/*/verify.stdout'):
            for line in path.read_text().splitlines():
                if not line.startswith('{'):
                    continue
                item = json.loads(line)
                if item.get('type') != 'diagnostic' or item.get('value', {}).get('severity') != 1:
                    continue
                diagnostic = item['value']
                locations = [diagnostic.get('location', {})] + [r.get('location', {}) for r in diagnostic.get('relatedInformation', [])]
                for location in locations:
                    if str(location.get('filePath', '')).endswith('spec/refund/RefundSpec.dfy'):
                        found |= start < location.get('range', {}).get('start', {}).get('line', -1) < end
        require(found, 'No real proof diagnostic bound to ' + claim)

    def wrapper(self):
        _, operations, _ = self.gate('source-positive')
        require([c['exit_code'] for c in operations if c['argv'][1] == 'verify'] == [0], 'no fresh source proof')
        original = (ROOT / 'impl/Refund.dfy').read_text()
        prefix = original[:original.index('  {\n') + len('  {\n')]
        mutations = {
            'over-limit': (prefix + '    decision := Authorized(context.original + 1, "duplicate_charge");\n'
                          '    plan := [Intent(context.chargeId, context.requestId, context.original + 1, "duplicate_charge")];\n  }\n}\n', 'R1'),
            'reject-all': (prefix + '    decision := Rejected;\n    plan := [];\n  }\n}\n', 'R4'),
        }
        for name, (source, claim) in mutations.items():
            fixture = self.fixture(name)
            (fixture / 'impl/Refund.dfy').write_text(source)
            self.save_mutant(fixture, 'impl/Refund.dfy', name)
            _, commands, directory = self.gate(name, cwd=fixture, expected=1, marker='VERIFICATION_REJECTED')
            require([c['exit_code'] for c in commands if c['argv'][1] == 'verify'] == [4], 'negative control did not fail actual proof')
            require([c['exit_code'] for c in commands if c['argv'][1] == 'audit'] == [0], 'negative control failed before proof')
            self.claim_rejected(directory, claim)
            self.report['checks'].append({'control': name, 'required_claim': claim, 'gate_exit': 1, 'verifier_exit': 4})
        fixture = self.fixture('assumption-escape')
        (fixture / 'impl/Refund.dfy').write_text(original.replace('  {\n', '  {\n    assume false;\n', 1))
        self.save_mutant(fixture, 'impl/Refund.dfy', 'assumption-escape')
        _, commands, directory = self.gate('assumption-escape', cwd=fixture, expected=1, marker='AUDIT_REJECTED')
        audits = [c['exit_code'] for c in commands if c['argv'][1] == 'audit']
        require(len(audits) == 1 and audits[0] != 0, 'assumption control did not reach actual auditor')
        findings = '\n'.join(p.read_text() for p in directory.glob('operations/**/*')
                             if p.is_file() and p.suffix in ('.md', '.expect', '.stdout', '.stderr'))
        require('Refund.Assess' in findings and 'assum' in findings.lower(), 'missing assumption finding')
        require(not any(c['argv'][1] == 'verify' for c in commands), 'audited escape reached accepted proof')
        self.report['checks'].append({'control': 'assumption-escape', 'gate_exit': 1, 'auditor_exit': audits[0]})

    def hostile(self):
        bundle, _, _ = self.gate('hostile-positive', tier='hostile-tests')
        result = bundle['backend_details']['integration']['report']
        self.report['hostile_coverage'] = result
        process, _, directory = self.execute(['node', '--import', 'tsx', 'tests/refund.integration.ts',
            '--module', 'build/refund-generated/model.cjs', '--report', str(self.work / 'supplemental.json')], 'supplemental')
        if (self.work / 'supplemental.json').exists():
            shutil.copyfile(self.work / 'supplemental.json', directory / 'report.json')
        require(process.returncode == 0, 'supplemental runtime checks failed')
        self.report['supplemental_coverage'] = read_json(directory / 'report.json')
        snapshot_report = self.work / 'snapshot-controls.json'
        process, _, directory = self.execute(['node', '--import', 'tsx', 'tests/refund.snapshot-controls.ts',
            '--module', 'build/refund-generated/model.cjs', '--report', str(snapshot_report)], 'snapshot-controls')
        for path in self.work.glob('snapshot-controls.json*'):
            shutil.copyfile(path, directory / path.name)
        require(process.returncode == 0, 'snapshot mutation controls failed')
        snapshot = read_json(directory / 'snapshot-controls.json')
        require(snapshot['result'] == 'passed' and snapshot['unchanged_accepted'] == 4 and
                snapshot['mutations_rejected'] == 16, 'missing genuine field/prototype rejection controls')
        self.report['snapshot_controls'] = snapshot
        original = (ROOT / 'ts/refund.ts').read_text()
        mutations = {
            'effect-bypass': original.replace('    async chunk(context, bytes, final) {',
                '    async chunk(context, bytes, final) {\n      execute({ chargeId: context.chargeId, requestId: context.requestId, amount: context.original + 1n, reason: "duplicate_charge" });', 1),
            'duplicate-dispatch': original.replace('      if (attempt.outcome !== null) return result(attempt);',
                '      if (attempt.outcome !== null) {\n        for (const intent of attempt.outcome.plan) execute({ ...intent });\n        return result(attempt);\n      }', 1),
        }
        for name, source in mutations.items():
            require(source != original, 'negative mutation was not applied')
            fixture = self.fixture(name)
            (fixture / 'ts/refund.ts').write_text(source)
            self.save_mutant(fixture, 'ts/refund.ts', name)
            _, commands, directory = self.gate(name, tier='hostile-tests', cwd=fixture, expected=1, marker='HOSTILE_REJECTED')
            tests = [c for c in commands if 'gate/refund/hostile.ts' in c['argv']]
            require(len(tests) == 1 and tests[0]['exit_code'] == 1, 'negative control did not fail real tests')
            reports = list(directory.glob('operations/*/hostile.json'))
            require(len(reports) == 1, 'negative test report missing')
            report = read_json(reports[0])
            require(report['result'] == 'failed' and ('AssertionError' in str(report) or 'property assertion failed' in str(report)),
                    'negative control failed for an infrastructure reason')
            require(all(c['exit_code'] == 0 for c in commands if c not in tests), 'failure before hostile assertions')
            self.report['checks'].append({'control': name, 'gate_exit': 1, 'test_exit': tests[0]['exit_code'], 'failure': report})

    def separation(self):
        bundles = {}
        for tier in ('critical', 'hostile-tests'):
            first, _, directory = self.gate('repeat-first-' + tier, tier=tier)
            supplied = directory / 'evidence.json'
            second, _, second_dir = self.gate('repeat-second-' + tier, tier=tier, supplied=supplied)
            require(supplied.read_bytes() == (second_dir / 'evidence.json').read_bytes(), 'canonical evidence differs on fresh replay')
            bundles[tier] = first
            self.report['checks'].append({'tier': tier, 'fresh_runs': 2, 'byte_identical': True,
                                          'evidence_sha256': digest(canonical(first))})
        require(bundles['critical']['artifact'] == bundles['hostile-tests']['backend_details']['source_artifact'],
                'integration source link differs from independently accepted source artifact')
        for name, method in [('test-as-proof', 'property_tested'), ('eval-as-proof', 'eval_measured')]:
            candidate = json.loads(json.dumps(bundles['critical']))
            for record in candidate['evidence']:
                record['method'] = method
            path = self.directory / (name + '.json'); path.write_bytes(canonical(candidate))
            self.gate(name, supplied=path, expected=1, marker='METHOD_POLICY')
        candidate = json.loads(json.dumps(bundles['critical']))
        candidate['evidence'][0]['artifact_sha'] = '0' * 64
        path = self.directory / 'mismatched-artifact.json'; path.write_bytes(canonical(candidate))
        self.gate('mismatched-artifact', supplied=path, expected=1, marker='ARTIFACT_MISMATCH')
        candidate = json.loads(json.dumps(bundles['hostile-tests']))
        candidate['backend_details']['integration']['report']['generated_cases'] += 1
        path = self.directory / 'invented-count.json'; path.write_bytes(canonical(candidate))
        self.gate('invented-count', tier='hostile-tests', supplied=path, expected=1, marker='REPRODUCTION_MISMATCH')
        fixture = self.fixture('spec-tamper')
        path = fixture / 'spec/refund/RefundSpec.dfy'
        path.write_text(path.read_text() + '\n// Unapproved change, only in disposable negative fixture.\n')
        self.save_mutant(fixture, 'spec/refund/RefundSpec.dfy', 'spec-tamper')
        self.gate('spec-tamper', cwd=fixture, expected=1, marker='APPROVED_CONTRACT')

    def finish(self, code, error=None):
        after = protected()
        self.report['protected_after'] = after
        self.report['protected_unchanged'] = after == self.before
        self.report['input_after_sha256'] = {name: digest((ROOT / name).read_bytes()) for name in SOURCE_FILES}
        if after != self.before or self.inputs != self.report['input_after_sha256']:
            code, error = 1, 'source or protected input changed during EXIT execution'
        self.report['exit_code'] = code
        self.report['result'] = 'passed' if code == 0 else 'failed'
        if error:
            self.report['error'] = error
        self.save()
        print(self.case + ': ' + self.report['result'] + '; end_to_end=false', flush=True)
        return code


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', required=True, choices=('wrapper-proof', 'hostile-outputs', 'evidence-separation'))
    args = parser.parse_args()
    run = Run(args.case)
    try:
        {'wrapper-proof': run.wrapper, 'hostile-outputs': run.hostile, 'evidence-separation': run.separation}[args.case]()
        return run.finish(0)
    except Exception:
        error = traceback.format_exc()
        (run.directory / 'failure.log').write_text(error)
        print(error, file=sys.stderr)
        return run.finish(1, error)


if __name__ == '__main__':
    sys.exit(main())
