"""Finite fast-check comparisons with the real compiled, source-proved model."""

import json
from pathlib import Path
import subprocess
import sys
import tempfile

from common import ROOT, Rejected, canonical, digest, pin_file, read_json, relative
from . import dafny

sys.path.insert(0, str(ROOT))
from scripts.javascript_env import check as check_javascript


def describe(impl_name):
    implementation = (ROOT / impl_name).resolve()
    impl_name = relative(implementation)
    if impl_name not in ('ts/ledger.ts', 'bugs/self_transfer.ts'):
        raise Rejected('SOURCE_SCOPE: TypeScript adapter accepts the declared ledger or self-transfer fixture')
    check_javascript()
    model, model_inputs = dafny.describe('impl/Ledger.dfy')
    # This adapter covers the fixed ledger layout. New module layouts need an
    # explicit input manifest and adapter update; no general TS closure is claimed.
    sources = sorted(set([impl_name, 'ts/ledger.ts', 'ts/types.ts']))
    manifest = [{'path': name, 'sha256': digest((ROOT / name).read_bytes())} for name in sources]
    expected = {'artifact': {'kind': 'source', 'sha256': digest(canonical(manifest)), 'build_cmd': ''},
                'source_manifest': manifest, 'claims': model['claims']}
    inputs = model_inputs + [ROOT / name for name in sources] + [Path(__file__).resolve()]
    inputs += [ROOT / name for name in (
        'scripts/javascript_env.py', 'scripts/build_model.py', 'interop/export.cjs',
        'interop/model.ts', 'tests/ledger.property.ts', 'package.json', 'package-lock.json',
        'tsconfig.json', pin_file('javascript'),
    )]
    return expected, inputs


def invoke(command, log):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    log.write_text(result.stdout + result.stderr)
    return result


def verify(impl_name):
    expected, inputs = describe(impl_name)
    before = {relative(path): digest(path.read_bytes()) for path in inputs}
    (ROOT / 'build').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='ts-gate-', dir=ROOT / 'build') as temporary:
        work = Path(temporary)
        source_output = work / 'source-proof.json'
        source = invoke([sys.executable, 'gate/gate.py', '--backend', 'dafny', '--impl',
                         'impl/Ledger.dfy', '--evidence', relative(source_output)], work / 'source.log')
        if source.returncode:
            print(source.stdout + source.stderr, file=sys.stderr)
            raise Rejected('MODEL_SOURCE: real Dafny gate did not accept the model; gate exit ' + str(source.returncode))
        proved = read_json(source_output)
        build = invoke([sys.executable, 'scripts/build_model.py'], work / 'build.log')
        if build.returncode:
            raise RuntimeError('MODEL_BUILD: exit ' + str(build.returncode) + '\n' + build.stdout + build.stderr)
        build_record = read_json(ROOT / 'build/js/build.json')
        module_path = ROOT / 'build/js/ledger.cjs'
        module_sha = digest(module_path.read_bytes())
        if module_sha != build_record['artifact']['sha256']:
            raise Rejected('MODEL_BINDING: generated module differs from actual build record')
        report_path = work / 'property.json'
        checked = invoke(['node', '--import', 'tsx', 'tests/ledger.property.ts', '--impl', impl_name,
                          '--report', relative(report_path)], work / 'property.log')
        report = read_json(report_path) if report_path.exists() else None
        if checked.returncode:
            print(checked.stdout + checked.stderr, file=sys.stderr)
            if checked.returncode == 1 and report and report.get('failure_kind') == 'comparison_assertion':
                raise Rejected('PROPERTY_REJECTED: C1 C2 C3 C4 C5 not established; '
                               'fast-check exit 1; ' + str(report['failure_message']))
            raise RuntimeError('PROPERTY_ERROR: exit ' + str(checked.returncode))
        if not report or report['method'] != 'tested_against_proved_model' or report['result'] != 'passed':
            raise RuntimeError('PROPERTY_ERROR: missing passing real test report')
        if digest(module_path.read_bytes()) != module_sha or before != {
            relative(path): digest(path.read_bytes()) for path in inputs
        }:
            raise Rejected('INPUT_CHANGED: model, tests, or source inputs changed during comparison')
        check_javascript()
        artifact_sha = expected['artifact']['sha256']
        assumptions = [
            'The caller supplies a WellFormed ledger state; operations are sequential.',
            'Finite generated sequences and directed examples only, with the recorded seed, counts, and integer range.',
            'The fixed TypeScript ledger module layout and declared inputs are used; arbitrary dynamic dependencies are outside this adapter scope.',
            'The Dafny JavaScript compiler, generated runtime, export footer, and bigint/BigNumber bridge preserve the source model; that link is not proved.',
            'No claim covers concurrency, persistence, serialization, authentication, or deployment.',
        ]
        trusted = [
            'Dafny 4.11.0 with bundled Boogie/.NET and Z3 4.12.1 for the linked source proof',
            'Dafny JavaScript compiler and generated runtime; tracked CommonJS export footer',
            'Node 24.3.0, tsx 4.21.0, fast-check 4.3.0, and bignumber.js 9.3.1',
            'Pinned npm dependency lock and observed installed package content',
            'The property suite, model bridge, Python gate, host operating system, and hardware',
        ]
        return {**expected, 'evidence': [
            {'claim_id': claim['id'], 'artifact_sha': artifact_sha,
             'method': 'tested_against_proved_model', 'tool': 'fast-check', 'tool_version': '4.3.0',
             'result': 'passed', 'assumptions': assumptions, 'trusted_base': trusted,
             'reproduce_cmd': 'python3 gate/gate.py --backend typescript --impl ' + impl_name
                              + ' --tier standard --evidence evidence.json',
             'producer': 'forge/local-typescript-comparison'} for claim in expected['claims']],
            'backend_details': {
                'property_result': report,
                'model': {'source_artifact_sha': proved['artifact']['sha256'],
                          'source_evidence_sha256': digest(source_output.read_bytes()),
                          'source_method': 'source_proof', 'module': build_record['artifact'],
                          'generated_source_sha256': build_record['generated_source_sha256'],
                          'source_to_module_proved': False},
            }}
