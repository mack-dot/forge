"""Registry of the trusted gate commands whose results establish claims (CONTRACT.md §2).

Each obligation declares the paths it depends on. After a run, the declaration is
checked against the bundle the gate itself wrote (trusted_input_sha256 keys and the
source manifest); a difference is OBLIGATION_INPUTS_DRIFT and the run does not count.
Obligations run inside an immutable verification tree: a copy of the candidate whose
protected manifest equals the trusted base's, with the trusted toolchain linked in.
This module runs commands and compares records; it interprets no checker output.
"""

import concurrent.futures
import json
import os
from pathlib import Path
import shlex
import shutil
import signal
import subprocess
import sys
import time
import xml.etree.ElementTree as ET

from common import PIN_FILES, ROOT, Rejected, canonical, digest, host_profile, pin_file, read_json

FRAMEWORK = ('gate/gate.py', 'gate/common.py', 'gate/core.py', 'gate/dependencies.py',
             'gate/backends/__init__.py', 'schemas/evidence.schema.json', 'schemas/policy.schema.json',
             'policy/tiers.yaml', pin_file('validator'), 'toolchain/requirements-stage2.txt')
CORE = ('gate/common.py', 'gate/core.py', 'gate/dependencies.py', 'gate/backends/__init__.py',
        'schemas/evidence.schema.json', 'schemas/policy.schema.json', pin_file('validator'),
        'toolchain/requirements-stage2.txt')
DAFNY_INPUTS = ('gate/ContractBinding.dfy', 'gate/expected-audit.md', 'gate/backends/dafny.py',
                pin_file('dafny'), 'spec.lock')
JS_INPUTS = ('scripts/javascript_env.py', pin_file('javascript'), 'package.json',
             'package-lock.json', 'tsconfig.json')
DAFNY = '.toolchain/dafny-4.11.0/dafny/dafny'
DAFNY_OPTIONS = ['--solver-path', '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1',
                 '--resource-limit', '1000000', '--verification-time-limit', '0',
                 '--cores', '1', '--verify-included-files']

# name -> declaration. 'bundle' names the evidence file the gate writes under build/;
# 'inputs' are the paths the gate hashes (checked against the bundle after the run);
# 'subjects' are the inputs under test, which may differ from the trusted base. Every
# other input must equal the trusted base's bytes before and after the run (an
# obligation never executes candidate-authored harness code). 'checker' obligations
# have no bundle: their required TRX members and audit report are checked instead.
OBLIGATIONS = {
    'ledger-evidence': {
        'argv': ['gate/gate.py', '--check-evidence', 'evidence.json', '--evidence', 'build/obligations/ledger-evidence.json'],
        'bundle': 'build/obligations/ledger-evidence.json',
        'claims': {'C1': 'source_proof', 'C2': 'source_proof', 'C3': 'source_proof', 'C4': 'source_proof', 'C5': 'source_proof'},
        'inputs': FRAMEWORK + DAFNY_INPUTS + ('impl/Ledger.dfy', 'spec/LedgerSpec.dfy'),
        'subjects': ('impl/Ledger.dfy', 'spec/LedgerSpec.dfy', 'evidence.json'),
        # Command arguments the gate reads but does not list in its bundle.
        'argument_inputs': ('evidence.json',),
        # The committed bundle binds one host profile's pin files; on another profile it
        # cannot reproduce and the obligation is not established (not rejected).
        'evidence_profile_argument': 'evidence.json',
        'scope': 'committed root evidence.json reproduces from the candidate ledger source',
    },
    'ledger-model': {
        'argv': ['gate/gate.py', '--backend', 'typescript', '--impl', 'ts/ledger.ts', '--tier', 'standard',
                 '--evidence', 'build/obligations/ledger-model.json'],
        'bundle': 'build/obligations/ledger-model.json',
        'claims': {'C1': 'tested_against_proved_model', 'C2': 'tested_against_proved_model',
                   'C3': 'tested_against_proved_model', 'C4': 'tested_against_proved_model',
                   'C5': 'tested_against_proved_model'},
        'inputs': FRAMEWORK + DAFNY_INPUTS + JS_INPUTS + (
            'gate/backends/typescript.py', 'impl/Ledger.dfy', 'spec/LedgerSpec.dfy', 'ts/ledger.ts', 'ts/types.ts',
            'interop/export.cjs', 'interop/model.ts', 'scripts/build_model.py', 'tests/ledger.property.ts'),
        # The TypeScript subject is loaded into the harness process (tests/ledger.property.ts),
        # so a changed subject could rewrite the verdict from inside. Until the harness isolates
        # the subject in a child process, ts/ledger.ts and ts/types.ts are bound to the trusted
        # base: this obligation re-establishes the model claims only for a changed ledger.
        'subjects': (),
        'scope': 'ts/ledger.ts (trusted-base bytes) compared with the model compiled from the candidate ledger (finite tests)',
    },
    'booking': {
        'argv': ['gate/booking.py', '--evidence', 'build/obligations/booking.json', '--work', 'build/obligations/booking-work'],
        'bundle': 'build/obligations/booking.json',
        'claims': {'B1': 'source_proof', 'B2': 'source_proof', 'B3': 'source_proof', 'B4': 'source_proof'},
        'inputs': FRAMEWORK + DAFNY_INPUTS + (
            'gate/booking.py', 'gate/booking-coverage.json', 'policy/booking.yaml', 'proposals/booking-decision.md',
            'spec/booking/spec.lock', 'spec/booking/BookingSpec.dfy', 'impl/Booking.dfy', 'impl/Ledger.dfy',
            'spec/LedgerSpec.dfy', 'tests/booking/SuccessfulExecution.dfy'),
        'subjects': ('impl/Booking.dfy', 'impl/Ledger.dfy', 'spec/LedgerSpec.dfy', 'spec/booking/BookingSpec.dfy',
                     'tests/booking/SuccessfulExecution.dfy'),
        'scope': 'booking matcher source proof, including its reuse of the ledger lemmas',
    },
    'refund-proof': {
        'argv': ['gate/refund.py', '--tier', 'critical', '--evidence', 'build/obligations/refund-proof.json'],
        'bundle': 'build/obligations/refund-proof.json',
        'claims': {'R1': 'source_proof', 'R2': 'source_proof', 'R3': 'source_proof', 'R4': 'source_proof', 'R5': 'source_proof'},
        'inputs': CORE + ('gate/expected-audit.md', 'gate/backends/dafny.py', pin_file('dafny'),
                          'gate/refund.py', 'gate/refund/Bindings.dfy', 'gate/refund/hostile.ts', 'policy/refund.yaml',
                               'proposals/refund-decision.md', 'spec/refund/protocol.md', 'spec/refund/spec.lock',
                               'spec/refund/RefundSpec.dfy', 'impl/Refund.dfy'),
        'subjects': ('impl/Refund.dfy', 'spec/refund/RefundSpec.dfy'),
        'scope': 'refund boundary source proof',
        'mutex': 'refund-gate',  # gate/refund.py holds build/refund-gate.lock; its two tiers cannot overlap
    },
    'refund-tests': {
        'argv': ['gate/refund.py', '--tier', 'hostile-tests', '--evidence', 'build/obligations/refund-tests.json'],
        'bundle': 'build/obligations/refund-tests.json',
        'claims': {'T1': 'property_tested', 'T2': 'property_tested', 'T3': 'property_tested'},
        'inputs': CORE + JS_INPUTS + ('gate/expected-audit.md', 'gate/backends/dafny.py', pin_file('dafny'),
                                      'gate/refund.py', 'gate/refund/Bindings.dfy', 'gate/refund/hostile.ts',
                                           'policy/refund.yaml', 'proposals/refund-decision.md', 'spec/refund/protocol.md',
                                           'spec/refund/spec.lock', 'spec/refund/RefundSpec.dfy', 'impl/Refund.dfy',
                                           'ts/refund.ts'),
        # gate/refund/hostile.ts imports ts/refund.ts into its own process: bound, as above.
        'subjects': ('impl/Refund.dfy', 'spec/refund/RefundSpec.dfy'),
        'scope': 'refund wrapper (trusted-base bytes) hostile tests against the model compiled from the candidate refund source',
        'mutex': 'refund-gate',
    },
    'ledger-witness': {
        'checker': [
            {'argv': [DAFNY, 'audit', 'tests/stage5/SuccessfulExecution.dfy', '--report-format', 'md',
                      '--report-file', 'build/obligations/ledger-witness-audit.md', '--compare-report'],
             'expected_report': 'gate/expected-audit.md', 'report': 'build/obligations/ledger-witness-audit.md'},
            {'argv': [DAFNY, 'verify', 'tests/stage5/SuccessfulExecution.dfy'] + DAFNY_OPTIONS
                     + ['--log-format', 'trx;LogFileName={tree}/build/obligations/ledger-witness.trx'],
             'trx': 'build/obligations/ledger-witness.trx',
             'required_members': ('SuccessfulExecution.Witness (correctness)', 'Ledger.Apply (correctness)',
                                  'Ledger.Apply (well-formedness)', 'LedgerSpec.Apply (well-formedness)')},
        ],
        'claims': {'W': 'source_proof'},
        'inputs': ('tests/stage5/SuccessfulExecution.dfy', 'impl/Ledger.dfy', 'spec/LedgerSpec.dfy',
                   'gate/expected-audit.md', pin_file('dafny')),
        # The witness text is bound to the trusted base (a rewritten witness could be vacuous);
        # it is re-verified against the candidate ledger.
        'subjects': ('impl/Ledger.dfy', 'spec/LedgerSpec.dfy'),
        'scope': 'Stage 5 successful-execution witness (trusted-base bytes) re-verifies against the candidate ledger (audit + named members)',
    },
}
# The ledger snapshot proof is run by incremental.py itself; its inputs are listed so the
# graph is complete.
LEDGER_PROOF_INPUTS = FRAMEWORK + DAFNY_INPUTS + ('gate/incremental.py', 'gate/approval.py', 'gate/coverage.py',
                                                  'gate/obligations.py', 'impl/Ledger.dfy', 'spec/LedgerSpec.dfy')


def inputs_of(name):
    if name == 'ledger-proof':
        return set(LEDGER_PROOF_INPUTS)
    declaration = OBLIGATIONS[name]
    return set(declaration['inputs']) | set(declaration.get('argument_inputs', ()))


def all_inputs():
    """Every path some obligation depends on: the set of paths a change can be covered by."""
    covered = set(LEDGER_PROOF_INPUTS)
    for name in OBLIGATIONS:
        covered |= inputs_of(name)
    return covered


def affected(changed):
    """Obligations with at least one changed input, plus the ledger proof itself."""
    names = ['ledger-proof']
    names += [name for name in OBLIGATIONS if inputs_of(name) & set(changed)]
    return names


def subjects_of(name):
    return set(OBLIGATIONS[name].get('subjects', ()))


def cache_key(name, tree, entries, context):
    """Content address: obligation declaration, its inputs' entries, and the trusted context."""
    digests = {}
    for path in sorted(inputs_of(name)):
        if path not in entries:
            return None
        digests[path] = entries[path]
    declaration = OBLIGATIONS[name] if name in OBLIGATIONS else {'ledger-proof': LEDGER_PROOF_INPUTS}
    return digest(canonical({'obligation': name, 'declaration': declaration, 'inputs': digests, 'context': context}))


def binding_violations(name, tree, trusted_root, verified):
    """Hashed inputs that are not subjects and not verified elsewhere must equal the trusted base."""
    violations = []
    for path in sorted(bound_inputs(name, verified)):
        candidate, trusted = tree / path, trusted_root / path
        if (candidate.is_symlink() or not trusted.is_file() or not candidate.is_file()
                or digest(candidate.read_bytes()) != digest(trusted.read_bytes())):
            violations.append(path)
    return violations


def bound_inputs(name, verified):
    """Inputs that must equal the trusted base for this obligation to be re-established."""
    return set(OBLIGATIONS[name]['inputs']) - subjects_of(name) - set(verified)


def not_reestablishable(changed, verified):
    """Changed paths that are bound inputs of an affected obligation: no run can establish them."""
    blocked = {}
    for name in affected(changed):
        if name == 'ledger-proof':
            continue
        for path in sorted(set(changed) & bound_inputs(name, verified)):
            blocked.setdefault(path, []).append(name)
    return blocked


def execute(argv, tree, environment, timeout):
    """Run one command in its own session; whatever it forked is killed when it returns."""
    child = subprocess.Popen(argv, cwd=tree, env=environment, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                             start_new_session=True)
    try:
        output, _ = child.communicate(timeout=timeout)
        code = child.returncode
    except subprocess.TimeoutExpired:
        output, code = b'', None
    finally:
        try:
            os.killpg(child.pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
        if child.poll() is None:
            child.wait()
    return code, output.decode('utf-8', 'replace')


def trx_members(path):
    rows = {}
    for item in ET.parse(path).iter():
        if item.tag.endswith('UnitTestResult'):
            rows[item.get('testName')] = item.get('outcome')
    return rows


def bundle_inputs(bundle):
    return set(bundle['trusted_input_sha256']) | {entry['path'] for entry in bundle.get('source_manifest', [])}


def bundle_profile(bundle):
    """The host profile whose pin files a bundle binds, or None."""
    keys = set(bundle.get('trusted_input_sha256', {}))
    matches = [profile for profile, files in PIN_FILES.items() if files['dafny'] in keys or files['validator'] in keys]
    return matches[0] if len(matches) == 1 else None


def run_one(name, tree, trusted_root, verified, work, environment, timeout):
    declaration = OBLIGATIONS[name]
    record = {'obligation': name, 'scope': declaration['scope'], 'claims': declaration['claims'],
              'declared_inputs': sorted(inputs_of(name)), 'subjects': sorted(subjects_of(name)),
              'argument_inputs': sorted(declaration.get('argument_inputs', ())), 'commands': []}
    started = time.perf_counter_ns()
    if 'evidence_profile_argument' in declaration:
        try:
            committed = bundle_profile(read_json(tree / declaration['evidence_profile_argument']))
        except (OSError, ValueError, KeyError, TypeError, AttributeError, Rejected):
            committed = None
        if committed != host_profile():
            record.update(result='not_established',
                          reason='EVIDENCE_PROFILE: committed ' + declaration['evidence_profile_argument']
                          + ' is bound to the ' + str(committed) + ' toolchain profile; this host is ' + host_profile(),
                          wall_seconds=round((time.perf_counter_ns() - started) / 1e9, 3))
            return record
    violations = binding_violations(name, tree, trusted_root, verified)
    if violations:
        record.update(result='rejected', reason='TRUSTED_INPUT_CHANGED: ' + ', '.join(violations[:8]),
                      trusted_input_violations=violations,
                      wall_seconds=round((time.perf_counter_ns() - started) / 1e9, 3))
        return record
    steps = ([{'argv': [sys.executable] + declaration['argv']}] if 'argv' in declaration else declaration['checker'])
    for index, step in enumerate(steps):
        if 'expected_report' in step:
            report = tree / step['report']
            report.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(trusted_root / step['expected_report'], report)
        argv = [part.replace('{tree}', str(tree)) for part in step['argv']]
        code, output = execute(argv, tree, environment, timeout)
        log = work / (name + '-%d.log' % index)
        log.write_text(output)
        record['commands'].append({'argv': shlex.join(argv), 'exit_code': code, 'log': log.name,
                                   'last_line': (output.strip().splitlines() or [''])[-1][:300]})
        if code != 0:
            record['result'] = 'not_established' if code is None or code == 2 else 'rejected'
            record['reason'] = record['commands'][-1]['last_line']
            break
        if 'trx' in step:
            members = trx_members(tree / step['trx'])
            missing = [m for m in step['required_members'] if members.get(m) != 'Passed']
            failed = [m for m, outcome in members.items() if outcome != 'Passed']
            if missing or failed:
                record.update(result='rejected', reason='PROOF_COVERAGE: required witness members missing or not passed: '
                              + ', '.join((missing + failed)[:6]))
                break
            record['verified_members'] = sorted(members)
    else:
        if 'bundle' in declaration:
            bundle = read_json(tree / declaration['bundle'])
            reported = bundle_inputs(bundle)
            if reported != set(declaration['inputs']):
                record.update(result='not_established', reason='OBLIGATION_INPUTS_DRIFT',
                              missing_from_declaration=sorted(reported - set(declaration['inputs'])),
                              not_reported_by_gate=sorted(set(declaration['inputs']) - reported))
            else:
                methods = {e['claim_id']: e['method'] for e in bundle['evidence'] if e['result'] == 'passed'}
                unbound = [path for path, sha in bundle['trusted_input_sha256'].items()
                           if path not in verified and (not (trusted_root / path).is_file()
                                                        or digest((trusted_root / path).read_bytes()) != sha)]
                manifest_mismatch = [e['path'] for e in bundle.get('source_manifest', [])
                                     if digest((tree / e['path']).read_bytes()) != e['sha256']]
                if unbound or manifest_mismatch:
                    record.update(result='rejected', reason='TRUSTED_INPUT_CHANGED: bundle digests differ from the trusted base: '
                                  + ', '.join((unbound + manifest_mismatch)[:8]))
                elif methods != declaration['claims']:
                    record.update(result='not_established', reason='OBLIGATION_CLAIMS_DRIFT', reported=methods)
                else:
                    record.update(result='established', evidence_sha256=digest(canonical(bundle)),
                                  artifact_sha256=bundle['artifact']['sha256'], backend=bundle['backend'])
        else:
            record.update(result='established', self_reported_inputs=False,
                          subject_sha256={path: digest((tree / path).read_bytes()) for path in sorted(subjects_of(name))})
    record['wall_seconds'] = round((time.perf_counter_ns() - started) / 1e9, 3)
    return record


def run(names, tree, trusted_root, verified, entries, context, work, cache, timeout=1800, workers=4):
    """Run (or reuse) the named obligations inside the verification tree. Returns records by name.

    verified: paths that may differ from the trusted base because another obligation of this
    run establishes them (impl/Ledger.dfy; approved spec inputs). Records are not cached here;
    the caller stores them after the tree-integrity check (see store()).
    """
    work.mkdir(parents=True, exist_ok=True)
    (tree / 'build/obligations').mkdir(parents=True, exist_ok=True)
    pycache = work / 'pycache'
    pycache.mkdir(exist_ok=True)
    allowed = ('PATH', 'HOME', 'TMPDIR', 'LANG', 'LC_ALL', 'LD_LIBRARY_PATH', 'DOTNET_ROOT')
    environment = {key: os.environ[key] for key in allowed if key in os.environ}
    environment['PATH'] = str(Path(sys.executable).parent) + os.pathsep + environment.get('PATH', os.defpath)
    # The pinned validator packages may live in the user site (toolchain/validator-pins.json);
    # the gates check their bytes, so the site is inherited as the parent gate sees it.
    # Bytecode never comes from or goes to the candidate tree.
    environment['PYTHONDONTWRITEBYTECODE'] = '1'
    environment['PYTHONPYCACHEPREFIX'] = str(pycache)
    records, pending = {}, []
    for name in names:
        if name == 'ledger-proof':
            continue
        key = cache_key(name, tree, entries, context)
        cached = cache / (key + '.json') if key else None
        if cached is not None and cached.is_file():
            previous = read_json(cached)
            if previous.get('result') == 'established' and previous.get('cache_key') == key:
                records[name] = dict(previous, reused=True)
                continue
        pending.append((name, key))
    # Obligations that share a gate-level lock (a 'mutex') run one after another; others run concurrently.
    groups = {}
    for name, key in pending:
        groups.setdefault(OBLIGATIONS[name].get('mutex') or name, []).append((name, key))

    def run_group(members):
        return [(name, key, run_one(name, tree, trusted_root, verified, work, environment, timeout))
                for name, key in members]

    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        for future in concurrent.futures.as_completed([pool.submit(run_group, members) for members in groups.values()]):
            for name, key, result in future.result():
                records[name] = dict(result, reused=False, cache_key=key)
    return records


def store(records, cache):
    """Cache established, freshly run records. Call only after the verification tree re-hashed identically."""
    for record in records.values():
        if record.get('result') == 'established' and not record.get('reused') and record.get('cache_key'):
            cache.mkdir(parents=True, exist_ok=True)
            (cache / (record['cache_key'] + '.json')).write_bytes(canonical(record))
