#!/usr/bin/env python3
"""Dafny backend: preserved Stage 1 proof, audit, scope, and coverage checks."""

import json
import platform
from pathlib import Path
import shlex
import subprocess
import sys
import tempfile
import xml.etree.ElementTree as ET


from common import ROOT, Rejected, canonical, digest, relative


DAFNY = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
SPEC = ROOT / 'spec/LedgerSpec.dfy'
BINDING = ROOT / 'gate/ContractBinding.dfy'
AUDIT = ROOT / 'gate/expected-audit.md'
CLAIMS = {
    'C1': 'A transfer preserves total funds.',
    'C2': 'Every resulting account balance is non-negative.',
    'C3': 'An accepted identical retry returns Ok without repeating its effect.',
    'C4': 'A fresh valid transfer terminates and performs the exact debit and credit.',
    'C5': 'Every other request is rejected without changing either state map.',
}
FEE_SPEC_SHA = '2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940'


def claim_statements(spec_sha):
    claims = dict(CLAIMS)
    if spec_sha == FEE_SPEC_SHA:
        claims['C4'] = ('A fresh valid transfer terminates, debits amount plus one from the sender, '
                        'credits the recipient by amount, and credits fee account 0 by one.')
    return claims


OPTIONS = [
    '--solver-path', '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1',
    '--resource-limit', '1000000', '--verification-time-limit', '0',
    '--cores', '1', '--verify-included-files',
]
REQUIRED_RESULTS = {
    'Ledger.Apply (correctness)', 'Ledger.Apply (well-formedness)',
    'LedgerSpec.Apply (well-formedness)',
    'LedgerSpec.NonNegative (well-formedness)',
    'LedgerSpec.WellFormed (well-formedness)',
    'LedgerSpec.Total (well-formedness)',
    'LedgerSpec.IsRetry (well-formedness)',
    'LedgerSpec.IsFreshValid (well-formedness)',
}


def run(command, log):
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    log.write_text(result.stdout + result.stderr)
    return result


def claim_ranges(source):
    """Read the approved comment markers; do not interpret Dafny expressions."""
    starts = []
    for number, line in enumerate(source.splitlines(), 1):
        for claim in CLAIMS:
            if line.strip().startswith('// ' + claim + ':'):
                starts.append((number, claim))
    if [claim for _, claim in starts] != list(CLAIMS):
        raise Rejected('CLAIM_MARKERS: approved claim locations are missing')
    return {claim: (line + 1, starts[index + 1][0] - 1
                    if index + 1 < len(starts) else len(source.splitlines()))
            for index, (line, claim) in enumerate(starts)}


def failed_claims(output, ranges):
    """Map first-party diagnostic locations to the approved claim markers."""
    found = set()
    for line in output.splitlines():
        if not line.startswith('{'):
            continue
        item = json.loads(line)
        if item.get('type') != 'diagnostic':
            continue
        diagnostic = item['value']
        if diagnostic.get('severity') != 1:
            continue
        for location in [diagnostic.get('location', {})] + [
            related.get('location', {})
            for related in diagnostic.get('relatedInformation', [])
        ]:
            filename = location.get('filePath')
            if not filename or (ROOT / filename).resolve() != SPEC:
                continue
            # Dafny 4.11 JSON uses one-based lines, unlike LSP positions.
            number = location['range']['start']['line']
            for claim, (start, end) in ranges.items():
                if start <= number <= end:
                    found.add(claim)
    return sorted(found)


def prepare(impl_name, profile='local'):
    implementation = (ROOT / impl_name).resolve()
    impl_name = relative(implementation)
    if implementation.parent not in (ROOT / 'impl', ROOT / 'bugs'):
        raise Rejected('SOURCE_SCOPE: Stage 1 accepts one file in impl/ or bugs/')
    if implementation.suffix != '.dfy':
        raise Rejected('SOURCE_SCOPE: the implementation must be a Dafny source file')
    profiles = {'local': 'toolchain/pins.json', 'linux': 'toolchain/linux-pins.json'}
    if profile not in profiles:
        raise RuntimeError('TOOLCHAIN_ERROR: unknown Dafny profile')
    pin_path = ROOT / profiles[profile]
    pins = json.loads(pin_path.read_text())
    lock = json.loads((ROOT / 'spec.lock').read_text())
    spec_bytes = SPEC.read_bytes()
    implementation_bytes = implementation.read_bytes()
    if lock.get('spec_file') != 'spec/LedgerSpec.dfy' or digest(spec_bytes) != lock.get('spec_sha256'):
        raise Rejected('SPEC_LOCK: C1 C2 C3 C4 C5 not established; spec digest mismatch')
    if lock.get('dafny_version') != '4.11.0' or lock.get('dafny_build') != pins['dafny']['version_output']:
        raise Rejected('TOOLCHAIN_LOCK: Dafny version does not match the approved lock')
    if pins.get('verification_options') != OPTIONS:
        raise Rejected('TOOLCHAIN_LOCK: verification options differ from the fixed Stage 1 policy')
    if platform.python_version() != pins['python']['version']:
        raise RuntimeError('TOOLCHAIN_ERROR: Python version differs from the pin')
    if profile == 'linux':
        if platform.system() != 'Linux' or platform.machine() != 'x86_64':
            raise RuntimeError('TOOLCHAIN_ERROR: Linux profile requires Linux/x86_64')
        if digest(Path(sys.executable).read_bytes()) != pins['python']['executable_sha256']:
            raise RuntimeError('TOOLCHAIN_ERROR: Python executable differs from the Linux pin')

    # A deliberately narrow byte-level input policy closes the source file set.
    # Dafny's parser and auditor handle language semantics and forbidden constructs.
    preamble = (b'include "../spec/LedgerSpec.dfy"\n\n'
                b'module Ledger refines LedgerSpec {\n')
    if not implementation_bytes.startswith(preamble) or implementation_bytes.count(b'include') != 1:
        raise Rejected('SOURCE_SCOPE: requires the exact approved include and '
                       'module Ledger refines LedgerSpec preamble; no other includes')
    for executable, expected in [
        (DAFNY, pins['dafny']['executable_sha256']),
        (ROOT / pins['z3']['path'], pins['z3']['executable_sha256']),
    ]:
        if digest(executable.read_bytes()) != expected:
            raise RuntimeError('TOOLCHAIN_ERROR: executable digest differs from its pin')
    ranges = claim_ranges(spec_bytes.decode('utf-8'))
    input_paths = [implementation, SPEC, BINDING, AUDIT, Path(__file__).resolve(),
                   ROOT / 'spec.lock', pin_path]
    before = {relative(path): digest(path.read_bytes()) for path in input_paths}
    return {'implementation': implementation, 'impl_name': impl_name,
            'pins': pins, 'lock': lock, 'ranges': ranges,
            'input_paths': input_paths, 'before': before}


def identity(state):
    impl_name, before = state['impl_name'], state['before']
    manifest = [{'path': name, 'sha256': before[name]}
                for name in sorted([impl_name, 'spec/LedgerSpec.dfy'])]
    return {
        'artifact': {'kind': 'source', 'sha256': digest(canonical(manifest)), 'build_cmd': ''},
        'source_manifest': manifest,
        'claims': [
            {'id': claim, 'statement_plain_english': statement,
             'spec_ref': 'spec/LedgerSpec.dfy:' + str(state['ranges'][claim][0]),
             'spec_sha': state['lock']['spec_sha256']}
            for claim, statement in claim_statements(state['lock']['spec_sha256']).items()
        ],
    }


def describe(impl_name):
    state = prepare(impl_name)
    return identity(state), state['input_paths']


def verify(impl_name):
    state = prepare(impl_name)
    impl_name = state['impl_name']
    pins, lock, ranges = state['pins'], state['lock'], state['ranges']
    before, input_paths = state['before'], state['input_paths']
    (ROOT / 'build').mkdir(exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='gate-', dir=ROOT / 'build') as temporary:
        work = Path(temporary)
        version = run([str(DAFNY), '--version'], work / 'version.log')
        if version.returncode != 0 or version.stdout.strip() != pins['dafny']['version_output']:
            raise RuntimeError('TOOLCHAIN_ERROR: Dafny version command failed or mismatched')
        audit_report = work / 'expected-audit.md'
        audit_report.write_bytes(AUDIT.read_bytes())
        audit = run([
            str(DAFNY), 'audit', impl_name, 'gate/ContractBinding.dfy',
            '--report-format', 'md', '--report-file', str(audit_report),
            '--compare-report',
        ], work / 'audit.log')
        if audit.returncode != 0:
            print(audit.stdout + audit.stderr, file=sys.stderr)
            raise Rejected('AUDIT_REJECTED: C1 C2 C3 C4 C5 not established; '
                           'Dafny audit exit ' + str(audit.returncode)
                           + '; rejected program or unchecked assumptions/code')
        report = work / 'verification.trx'
        verification = run([
            str(DAFNY), 'verify', impl_name, 'gate/ContractBinding.dfy', *OPTIONS,
            '--json-output', '--log-format', 'trx;LogFileName=' + str(report),
        ], work / 'verification.log')
        if verification.returncode != 0:
            claims = failed_claims(verification.stdout, ranges)
            print(verification.stdout + verification.stderr, file=sys.stderr)
            raise Rejected('VERIFICATION_REJECTED: ' + ' '.join(claims or CLAIMS)
                           + ' not established; Dafny exit ' + str(verification.returncode))
        tree = ET.parse(report)
        results = [element for element in tree.iter()
                   if element.tag.endswith('UnitTestResult')]
        names = {element.get('testName') for element in results}
        if not REQUIRED_RESULTS <= names or any(element.get('outcome') != 'Passed' for element in results):
            raise Rejected('PROOF_COVERAGE: required obligations were absent or did not pass')
        after = {relative(path): digest(path.read_bytes()) for path in input_paths}
        if before != after:
            raise Rejected('INPUT_CHANGED: source or trusted inputs changed while checking')

        manifest = [{'path': name, 'sha256': before[name]}
                    for name in sorted([impl_name, 'spec/LedgerSpec.dfy'])]
        artifact_sha = digest(canonical(manifest))
        reproduce = 'python3 gate/gate.py --impl ' + shlex.quote(impl_name) + ' --evidence evidence.json'
        assumptions = [
            'The caller supplies a WellFormed state; external state history is not established.',
            'Operations are sequential over mathematical unbounded integers and finite maps.',
            'No claim covers concurrency, persistence, serialization, authentication, or deployment.',
        ]
        trusted_base = [
            'Dafny ' + pins['dafny']['version_output'], 'bundled Z3 4.12.1',
            'Dafny bundled Boogie and .NET runtime',
            'Python ' + pins['python']['version'] + ' and this gate adapter',
            'approved spec, local spec.lock, contract-binding harness, and empty audit baseline',
            'host operating system and hardware',
        ]
        evidence = {
            'end_to_end': False,
            'artifact': {'kind': 'source', 'sha256': artifact_sha, 'build_cmd': ''},
            'source_manifest': manifest,
            'claims': [
                {'id': claim, 'statement_plain_english': statement,
                 'spec_ref': 'spec/LedgerSpec.dfy:' + str(ranges[claim][0]),
                 'spec_sha': lock['spec_sha256']}
                for claim, statement in claim_statements(lock['spec_sha256']).items()
            ],
            'evidence': [
                {'claim_id': claim, 'artifact_sha': artifact_sha,
                 'method': 'source_proof', 'tool': 'Dafny',
                 'tool_version': pins['dafny']['version_output'], 'result': 'passed',
                 'assumptions': assumptions, 'trusted_base': trusted_base,
                 'reproduce_cmd': reproduce, 'producer': 'forge/local-dafny-gate'}
                for claim in CLAIMS
            ],
            'trusted_input_sha256': {name: before[name] for name in sorted(before)
                                     if name not in [impl_name, 'spec/LedgerSpec.dfy']},
            'backend_details': {
                'verification_options': OPTIONS, 'verified_obligations': sorted(names),
            },
        }
        return evidence
