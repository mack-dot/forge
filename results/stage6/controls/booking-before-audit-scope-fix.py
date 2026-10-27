#!/usr/bin/env python3
"""Bind real Dafny booking checks to the approved contract and existing schema."""

import argparse
import json
from pathlib import Path
import re
import shlex
import subprocess
import sys
import tempfile
import time
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
from common import ROOT, Rejected, canonical, digest, read_json, relative
from dependencies import check_dependencies
from backends import dafny

BACKEND = 'dafny-booking'
SPEC_SHA = '6d10e909fc685eb28fc1d582dcb37b61294bf5ac2466236b06447a82a60d2319'
LOCK_SHA = 'c6ff76b98ef844d08e4255938414477d21c2be2dcb7e83ae7d8165c05061b88e'
SOURCES = ('spec/LedgerSpec.dfy', 'impl/Ledger.dfy',
           'spec/booking/BookingSpec.dfy', 'impl/Booking.dfy',
           'tests/booking/SuccessfulExecution.dfy')
CLAIMS = {
    'B1': 'Distinct active bookings occupy distinct slots; state remains well formed.',
    'B2': 'A fresh booking gets the lowest allowed free slot with the exact state update.',
    'B3': 'A fresh valid cancellation removes exactly its booking and frees its slot.',
    'B4': 'An accepted identical retry replays its historical outcome without changing state.',
}
REPRODUCE = 'python3 gate/booking.py --evidence build/booking-evidence.json'


def members(rows):
    return {re.sub(r' \(assertion batch \d+\)$', '', row['name']) for row in rows}


def prepare():
    state = dafny.prepare('impl/Ledger.dfy')
    if digest((ROOT / 'spec/booking/BookingSpec.dfy').read_bytes()) != SPEC_SHA:
        raise Rejected('BOOKING_SPEC_LOCK: unapproved booking contract')
    if digest((ROOT / 'spec/booking/spec.lock').read_bytes()) != LOCK_SHA:
        raise Rejected('BOOKING_SPEC_LOCK: unapproved booking lock')
    lock = read_json(ROOT / 'spec/booking/spec.lock')
    for name, expected in lock['dependencies'].items():
        if digest((ROOT / name).read_bytes()) != expected:
            raise Rejected('BOOKING_DEPENDENCY: approved ledger dependency changed')
    if lock['dafny_build'] != state['pins']['dafny']['version_output']:
        raise Rejected('TOOLCHAIN_LOCK: booking Dafny pin differs')
    prefix = (b'include "../spec/booking/BookingSpec.dfy"\n'
              b'include "Ledger.dfy"\n\nmodule Booking refines BookingSpec {\n'
              b'  import Accounting = Ledger\n')
    code = (ROOT / 'impl/Booking.dfy').read_bytes()
    witness = (ROOT / 'tests/booking/SuccessfulExecution.dfy').read_bytes()
    if digest(witness) != read_json(ROOT / 'gate/booking-coverage.json')['witness_sha256']:
        raise Rejected('WITNESS_BINDING: successful trace differs from the trusted checked witness')
    if not code.startswith(prefix) or code.count(b'include') != 2:
        raise Rejected('SOURCE_SCOPE: exact booking refinement and dependency imports required')
    if not witness.startswith(b'include "../../impl/Booking.dfy"\n') or witness.count(b'include') != 1:
        raise Rejected('SOURCE_SCOPE: witness must use only the actual booking closure')
    for source in (code, witness, (ROOT / 'impl/Ledger.dfy').read_bytes()):
        # This is an input restriction, not a language parser. Dafny performs
        # resolution, proof, and the independent forbidden-assumption audit.
        remaining = source.replace(b'{:isolate_assertions}', b'')
        if b'{:' in remaining or b'@' in remaining:
            raise Rejected('SOURCE_SCOPE: only assertion-isolation attributes are allowed')
    return state


def identity():
    manifest = [{'path': name, 'sha256': digest((ROOT / name).read_bytes())}
                for name in sorted(SOURCES)]
    lines = (ROOT / 'spec/booking/BookingSpec.dfy').read_text().splitlines()
    refs = {claim: next(i + 2 for i, line in enumerate(lines)
                        if line.strip().startswith('// ' + claim + ':')) for claim in CLAIMS}
    return {'artifact': {'kind': 'source', 'sha256': digest(canonical(manifest)), 'build_cmd': ''},
            'source_manifest': manifest,
            'claims': [{'id': claim, 'statement_plain_english': text,
                        'spec_ref': 'spec/booking/BookingSpec.dfy:' + str(refs[claim]),
                        'spec_sha': SPEC_SHA} for claim, text in CLAIMS.items()]}


def run(command, work, name, records):
    start = time.perf_counter_ns()
    child = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    elapsed = time.perf_counter_ns() - start
    log = work / (name + '.log')
    log.write_text(child.stdout + child.stderr)
    records.append({'command': shlex.join(command), 'exit_code': child.returncode,
                    'elapsed_ns': elapsed, 'log': relative(log),
                    'log_sha256': digest(log.read_bytes())})
    (work / 'operation.json').write_bytes(canonical({'stage_exit': False, 'commands': records}))
    print(name + ': exit ' + str(child.returncode), flush=True)
    return child


def main():
    versions = check_dependencies()
    from jsonschema import Draft202012Validator
    from core import framework_paths, snapshot, make_bundle, validate_evidence
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--evidence', default='build/booking-evidence.json')
    parser.add_argument('--check-evidence')
    parser.add_argument('--work')
    args = parser.parse_args()
    output = (ROOT / args.evidence).resolve()
    if output.suffix != '.json' or not output.is_relative_to(ROOT / 'build'):
        raise Rejected('OUTPUT_SCOPE: booking evidence must be JSON under build/')
    supplied_path = (ROOT / args.check_evidence).resolve() if args.check_evidence else None
    if supplied_path == output:
        raise Rejected('OUTPUT_SCOPE: supplied record and output must differ')
    output.unlink(missing_ok=True)
    state = prepare()
    paths = framework_paths() + state['input_paths'] + [ROOT / name for name in SOURCES] + [
        ROOT / name for name in ('gate/booking.py', 'gate/booking-coverage.json',
                                 'spec/booking/spec.lock', 'policy/booking.yaml',
                                 'proposals/booking-decision.md')]
    before = snapshot(paths)
    expected = identity()
    trusted = {name: value for name, value in before.items() if name not in SOURCES}
    policy = read_json(ROOT / 'policy/booking.yaml')
    Draft202012Validator(read_json(ROOT / 'schemas/policy.schema.json')).validate(policy)
    rules = policy['tiers']['critical']
    policy_id = {'id': policy['id'], 'version': policy['version'], 'tier': 'critical',
                 'sha256': digest((ROOT / 'policy/booking.yaml').read_bytes())}
    if rules['artifact_kind'] != 'source' or set(rules['required_claims']) != set(CLAIMS):
        raise Rejected('BOOKING_POLICY: all four source claims are required')
    if any(rule != {'minimum_method': 'source_proof', 'allowed_methods': ['source_proof']}
           for rule in rules['required_claims'].values()):
        raise Rejected('BOOKING_POLICY: every claim requires source_proof')
    supplied = read_json(supplied_path) if supplied_path else None
    if supplied is not None:
        validate_evidence(supplied, expected, rules, policy_id, trusted, BACKEND)
    (ROOT / 'build').mkdir(exist_ok=True)
    if args.work:
        work = (ROOT / args.work).resolve()
        if not work.is_relative_to(ROOT / 'build'):
            raise Rejected('OUTPUT_SCOPE: operational logs must stay under build/')
        work.mkdir(parents=True, exist_ok=False)
    else:
        work = Path(tempfile.mkdtemp(prefix='booking-gate-', dir=ROOT / 'build'))
    records = []
    version = run([str(dafny.DAFNY), '--version'], work, 'version', records)
    if version.returncode or version.stdout.strip() != state['pins']['dafny']['version_output']:
        raise RuntimeError('TOOLCHAIN_ERROR: Dafny version failed or differed')
    audit_path = work / 'audit.md'
    audit_path.write_bytes(dafny.AUDIT.read_bytes())
    audit = run([str(dafny.DAFNY), 'audit', 'tests/booking/SuccessfulExecution.dfy',
                 '--report-format', 'md', '--report-file', str(audit_path), '--compare-report'],
                work, 'audit', records)
    if audit.returncode:
        raise Rejected('AUDIT_REJECTED: ' + audit.stdout + audit.stderr)
    report = work / 'verification.trx'
    checked = run([str(dafny.DAFNY), 'verify', 'tests/booking/SuccessfulExecution.dfy',
                   *dafny.OPTIONS, '--json-output', '--log-format', 'trx;LogFileName=' + str(report)],
                  work, 'verify', records)
    if checked.returncode:
        raise Rejected('VERIFICATION_REJECTED: ' + checked.stdout + checked.stderr)
    rows = sorted([{'name': e.get('testName'), 'outcome': e.get('outcome')}
                   for e in ET.parse(report).iter() if e.tag.endswith('UnitTestResult')],
                  key=lambda x: x['name'])
    required = set(read_json(ROOT / 'gate/booking-coverage.json')['members'])
    if not required <= members(rows) or any(row['outcome'] != 'Passed' for row in rows):
        raise Rejected('PROOF_COVERAGE: required booking, witness, or ledger obligation missing')
    raw = dict(expected, evidence=[{
        'claim_id': claim, 'artifact_sha': expected['artifact']['sha256'],
        'method': 'source_proof', 'tool': 'Dafny', 'tool_version': version.stdout.strip(),
        'result': 'passed', 'producer': 'forge/local-booking-gate', 'reproduce_cmd': REPRODUCE,
        'assumptions': [
            'The caller supplies a WellFormed state and is authorized to request cancellation.',
            'Operations are sequential over finite maps/sets and mathematical integers.',
            'Slot IDs denote independent indivisible capacity units; accepted receipts persist.',
            'Retry outcomes describe historical results, not current occupancy.',
            'No compiler, binary, deployment, concurrency, persistence, or external-effect claim.'],
        'trusted_base': ['Dafny ' + version.stdout.strip(), 'bundled Boogie 3.5.5, Z3 4.12.1, and .NET',
                         'Approved booking and ledger contracts, locks, and empty audit baseline',
                         'Python ' + state['pins']['python']['version'] + ', host OS, and hardware'],
    } for claim in CLAIMS], backend_details={
        'verification_options': dafny.OPTIONS, 'verified_obligations': [r['name'] for r in rows],
        'assertion_isolation': 'Each Apply/witness assertion batch receives the pinned resource limit.',
        'reused_source_lemmas': ['Ledger.TotalReplace', 'Ledger.TotalRemove'],
        'proof_result_cache': False, 'successful_trace_checked': True,
    })
    bundle = make_bundle(raw, BACKEND, policy_id, trusted, versions, REPRODUCE)
    validate_evidence(bundle, expected, rules, policy_id, trusted, BACKEND)
    if supplied is not None and canonical(supplied) != canonical(bundle):
        raise Rejected('REPRODUCTION_MISMATCH: supplied evidence differs from fresh checks')
    if before != snapshot(paths):
        raise Rejected('INPUT_CHANGED: source or trusted inputs changed during checking')
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_bytes(canonical(bundle))
    print('ACCEPTED: B1 B2 B3 B4; source_proof; end_to_end=false')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Rejected as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError, KeyError, RuntimeError, ImportError, ET.ParseError) as error:
        print('GATE_ERROR: ' + str(error), file=sys.stderr)
        sys.exit(2)
