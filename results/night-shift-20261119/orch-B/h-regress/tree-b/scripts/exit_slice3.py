#!/usr/bin/env python3
"""Slice 3 (master idea items F3.1 and F3.2): EXIT checks of runtime certificates on batch booking. Dispatch only.

This script starts the pinned Dafny (through the functions of scripts/spec_clearing.py, the Slice 2
tool), the pinned Node, and rustc for ONE untrusted optimizer. It compares exit codes and records with
the expected ones. It decides no proof and interprets no program.

Its bundle is a RECORD. It is NOT gate evidence: no policy lists these claims and no gate obligation
lists these files. Raw outputs go to build/slice3/ (ignored by git). Nothing is written under results/.

Cases:
  core-proof     the checker core against the candidate specification; the claim lemmas; the bridge
                 lemma; a non-abstract instance; audit of every reached file
  core-controls  every wrong core is refused by the same procedure, for the expected reason
  clearing       the Slice 2 clearing tool: NO_CHOICE for the candidate specification; CHOICE for a
                 planted loose one
  sink-controls  compile the core; type check; the finite control suite exits 0
  swap           compile the core once; then three optimizers (TypeScript, Rust, Python adversary) one
                 after the other against the same compiled core; this script starts no other command
                 between them, and the compiled core and the proof inputs keep their bytes
  evidence       all of the above, twice, in fresh folders; the two bundles are byte-identical

rustc is NOT pinned and NOT part of any proof. It builds the untrusted optimizer v2 only. The bundle
holds the version text of rustc, and no hash and no path of the binary that it makes.
"""

import argparse
import json
from pathlib import Path
import platform
import re
import shutil
import sys
import traceback

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
sys.path.insert(0, str(ROOT / 'scripts'))
sys.path.insert(0, str(ROOT))
from common import canonical, digest, pin_file, read_json  # noqa: E402
from backends import dafny  # noqa: E402  (the gate's own Dafny path and options)
import spec_clearing  # noqa: E402  (the Slice 2 tool; not changed by this slice)

SPEC = 'certificate/BookingCertificateSpec.dfy'
CORE = 'impl/BookingCertificate.dfy'
CLAIMS_FILE = 'certificate/BookingCertificateClearing.dfy'
BRIDGE = 'certificate/BookingBridge.dfy'
REFERENCE = 'proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy'
SUBJECTS = 'certificate/subjects.json'
FIXTURES = 'tests/booking-certificate/fixtures'
SUITE = 'tests/booking-certificate/suite.ts'
SWAP = 'tests/booking-certificate/swap.ts'
RUST_SOURCE = 'guests/booking/v2_fast.rs'
FOOTER = b'\nmodule.exports = { BookingCertificate, BookingDualCert, runtime: _dafny };\n'
INSTANCES = [['BookingCertificateClearing', {'S': 'BookingCertificate'}]]
MEMBER = 'BookingCertificateClearing.%s (correctness)'
DECIDE = 'BookingCertificate.Decide (correctness)'
CLAIM_MEMBERS = [MEMBER % name for name in ('DecideThenPost', 'SpecIsDeterministic', 'PostIsExact', 'IssueIsFeasible',
                                            'IssueIsNearOptimal', 'IssueBindsTheToken', 'IssueWitnesses',
                                            'RefuseWitnesses')]
CORE_MEMBERS = [DECIDE, 'BookingCertificate.Decide (well-formedness)',
                'BookingCertificateSpec.Decide (well-formedness)', 'BookingCertificateSpec.Accepts (well-formedness)',
                'BookingCertificateSpec.Remaining (well-formedness)',
                'BookingDualCert.WeakDuality (correctness)', 'BookingDualCert.Quality (correctness)'] + CLAIM_MEMBERS
BRIDGE_MEMBERS = ['BookingBridge.%s (correctness)' % name for name in (
    'DotFromNonNeg', 'DotFromLower', 'TwoChosen', 'FeasibleHasNoDoubleBooking', 'AcceptedHasNoDoubleBooking',
    'BridgeWitness')]
PRINT_STATEMENT = 'to use a print statement, the enclosing method must be marked with {:print}'
PRINT_CALL = 'to call a method with print effects, the enclosing method must be marked with {:print}'
POSTCONDITION = 'a postcondition could not be proved on this return path'
# fixture -> how the procedure must refuse it.
#   ('postcondition', clause): the verifier cannot prove that clause of the specified contract for this body.
#   ('error', text): Dafny reports this error before any proof.
#   ('instance', text): the file alone passes; the non-abstract instance of the claims is refused with this error.
#   ('audit',): the verifier passes; the Dafny audit reports a finding.
#   ('word',): the verifier and the audit pass; the refused word stops it.
CONTROLS = {
    'CoreNoBinaryCheck': ('postcondition', 'decision'), 'CoreNoCapacityCheck': ('postcondition', 'decision'),
    'CoreNoDualCheck': ('postcondition', 'decision'), 'CoreNegativeSlotPrices': ('postcondition', 'decision'),
    'CoreNegativeRequestPrices': ('postcondition', 'decision'), 'CoreNoGapCheck': ('postcondition', 'decision'),
    'CoreGapAboveAll': ('postcondition', 'decision'), 'CoreIssuesEverything': ('postcondition', 'decision'),
    'CoreRefusesEverything': ('postcondition', 'decision'),
    'CoreWrongStateHash': ('postcondition', 'token'), 'CoreWrongBatchHash': ('postcondition', 'token'),
    'CoreWrongValue': ('postcondition', 'token'), 'CoreOtherAllocation': ('postcondition', 'token'),
    'CoreKeepsCapacity': ('postcondition', 'token'), 'CoreStatesZeroGap': ('postcondition', 'token'),
    'CoreWrongRequestId': ('postcondition', 'token'),
    'CorePrints': ('error', PRINT_STATEMENT), 'CorePrintsMarked': ('instance', PRINT_CALL),
    'CoreNeedsPrecondition': ('error', 'a refining method is not allowed to add preconditions'),
    'CoreAssumes': ('audit',), 'CoreHaltsAtRunTime': ('word',),
}
EXPECT_SUBJECT = {'id': 'booking-certificate', 'verdict': 'NO_CHOICE', 'acceptance': 'ACCEPTS',
                  'claim': MEMBER % 'SpecIsDeterministic',
                  'proof': [MEMBER % name for name in ('SpecIsDeterministic', 'DecideThenPost', 'PostIsExact',
                                                       'IssueIsFeasible', 'IssueIsNearOptimal',
                                                       'IssueBindsTheToken')] + [DECIDE],
                  'acceptance_members': [MEMBER % 'IssueWitnesses', MEMBER % 'RefuseWitnesses'],
                  'open': ['ClearingSpecProbeOf_BookingCertificateSpec.Decide']}
EXPECT_CONTROL = {'id': 'control-certificate-spec-may-refuse', 'verdict': 'CHOICE',
                  'claim': 'BookingCertificateLooseClearing.SpecIsDeterministic (correctness)',
                  'witness': ['LooseExact.Decide (correctness)', 'LooseRefusesAll.Decide (correctness)',
                              'LooseWitness.TwoAllowedVerdictsDiffer (correctness)']}
BATCHES = 70
LARGEST_GAP = 2000
ADVERSARY_FULL = ('overbook', 'double-book', 'forged-certificate', 'negative-prices', 'nothing-claims-optimal',
                  'gap-below-zero', 'gap-above-all', 'wrong-shape', 'huge-number', 'json-number', 'extra-key',
                  'not-json')
ADVERSARY_LIMITS = (('oversize', 20000), ('no-line', 20000), ('silent', 1500), ('control-bytes', 20000))
# optimizer -> exact counts of its run (the runs are deterministic).
EXPECT_SWAP = {
    'v1': {'batches': BATCHES, 'answers': 70, 'tokens': 70, 'committed': 49, 'committed_at_gap_0': 17,
           'tokens_above_the_largest_gap': 21, 'no_token': 0, 'proposals_not_feasible': 0,
           'proposals_not_readable': 0, 'forged_offers': 0},
    'v2': {'batches': BATCHES, 'answers': 70, 'tokens': 70, 'committed': 35, 'committed_at_gap_0': 26,
           'tokens_above_the_largest_gap': 35, 'no_token': 0, 'proposals_not_feasible': 0,
           'proposals_not_readable': 0, 'forged_offers': 0},
}
# Adversary mode -> what EVERY row of its run must show, and the counts (review finding R2: without
# these, a run in which the adversary did not start at all also had "0 tokens").
#   (line of the optimizer, answer of the issuer side, proposals not feasible, not readable, forged offers)
CORE_REFUSES, SHAPE = 'no token: core: Refuse', 'no token: proposal shape'
EXPECT_ADVERSARY = {
    'overbook': ('one line', CORE_REFUSES, 'all', 0, 'all'), 'double-book': ('one line', CORE_REFUSES, 'all', 0, 'all'),
    'forged-certificate': ('one line', CORE_REFUSES, 0, 0, 'all'), 'negative-prices': ('one line', CORE_REFUSES, 0, 0, 'all'),
    'nothing-claims-optimal': ('one line', CORE_REFUSES, 0, 0, 'all'), 'gap-below-zero': ('one line', CORE_REFUSES, 0, 0, 'all'),
    'gap-above-all': ('one line', CORE_REFUSES, 0, 0, 'all'), 'wrong-shape': ('one line', CORE_REFUSES, 'all', 0, 'all'),
    'huge-number': ('one line', SHAPE, 0, 'all', 0), 'json-number': ('one line', SHAPE, 0, 'all', 0),
    'extra-key': ('one line', SHAPE, 0, 'all', 0), 'not-json': ('one line', 'no token: proposal is not JSON', 0, 'all', 0),
    'oversize': ('line too long', 'no token: no line from the optimizer', 0, 'all', 0),
    'no-line': ('no line', 'no token: no line from the optimizer', 0, 'all', 0),
    'silent': ('time limit', 'no token: no line from the optimizer', 0, 'all', 0),
    'control-bytes': ('one line', 'no token: message too long for the issuer', 0, 'all', 0),
}
SUBJECT = [SPEC, CORE, CLAIMS_FILE, BRIDGE, SUBJECTS, 'scripts/exit_slice3.py',
           'certificate/controls/BookingCertificateSpecLoose.dfy',
           'certificate/controls/BookingCertificateLooseClearing.dfy',
           'certificate/controls/BookingCertificateLooseWitness.dfy',
           'ts/booking-certificate/encoding.ts', 'ts/booking-certificate/issuer.ts', 'ts/booking-certificate/sink.ts',
           'ts/booking-certificate/guest.ts', SUITE, SWAP, 'tests/booking-certificate/commit_cli.ts',
           'tests/booking-certificate/corpus.ts', 'tests/booking-certificate/reference.ts',
           'guests/booking/v1_baseline.ts', RUST_SOURCE, 'guests/booking/v3_adversary.py'] + [
               FIXTURES + '/' + name + '.dfy' for name in sorted(CONTROLS)]
REUSED = [REFERENCE, 'proposals/forge2-pillar3-dual-certificate/finality/solvers.ts',
          'ts/refund-finality/encoding.ts', 'scripts/spec_clearing.py', 'impl/Booking.dfy', 'impl/Ledger.dfy']
APPROVED = ['spec/booking/BookingSpec.dfy', 'spec/booking/spec.lock', 'spec/LedgerSpec.dfy']
TRUSTED = ['gate/backends/dafny.py', 'gate/common.py', 'gate/expected-audit.md', pin_file('dafny'),
           pin_file('javascript'), 'scripts/javascript_env.py', 'package.json', 'package-lock.json', 'tsconfig.json']
CLAIMS = [
    ('Q1', 'source_proof', 'A token is only for an allocation that is 0/1 and uses no slot above its capacity. The '
     'token holds exactly the capacities that remain, and none of them is negative.'),
    ('Q2', 'source_proof', 'The value of the allocation of a token is within the stated gap of the value of EVERY '
     'feasible allocation: (10000 - gap) * value(alt) <= 10000 * value(x), over mathematical integers. With the gap 0 '
     'the allocation is a global optimum. Sound, NOT complete: an optimal allocation with a weak certificate gets no '
     'token.'),
    ('Q3', 'source_proof', 'The core issues a token exactly when the specified check Accepts holds. No precondition.'),
    ('Q4', 'source_proof', 'A token holds exactly the two given hash texts, the request id, the checked allocation, '
     'the stated gap and the value of that allocation.'),
    ('Q5', 'source_proof', 'The candidate specification leaves no choice: for one input, at most one verdict '
     '(clearing verdict NO_CHOICE with a non-abstract instance and a probe of the specification).'),
    ('Q6', 'source_proof', 'Bridge to one approved predicate: for a batch in which every request needs exactly one '
     'slot and every slot has the capacity 1, an accepted allocation gives an `active` map that satisfies '
     'NoDoubleBooking of the approved booking specification.'),
    ('R1', 'runtime_certificate_checked', 'In the recorded runs, every committed allocation was committed by the sink '
     'for a token text whose signature verifies with the public key of the issuer (the sink checks it; its audit '
     'checks it again). That the issuer signs only what the compiled core issued is read from '
     'ts/booking-certificate/issuer.ts; no run observes it.'),
    ('T1', 'tested_against_proved_model', 'In the recorded runs, the issuer gave a token exactly for the proposals '
     'that a second implementation of the check accepts, and every token is within its gap of the optimum found by '
     'a search over all subsets (batches of at most 14 requests).'),
    ('Z1', 'unit_tested', 'In the recorded runs, the optimizers were exchanged and this script started no other '
     'command between the first and the last optimizer run; the compiled core has the same bytes before and after; '
     'the five proof input files did not change; every run reports the same module hash, checker id and '
     'specification id, and they equal a new computation from the files. Processes that an optimizer run starts '
     'are not observed by this script.'),
    ('K-core', 'floor_controls', 'Each recorded wrong core is refused by the same procedure that accepts the core.'),
    ('K-a', 'floor_controls', 'In the recorded finite suite, each attempt with a missing, forged or changed token is '
     'rejected by the sink with 0 effects.'),
    ('K-b', 'floor_controls', 'In the recorded finite suite, each valid token whose pre-state hash or batch hash is '
     'not that of the store is rejected with 0 effects; of several valid tokens for one board exactly one commits.'),
    ('K-c', 'floor_controls', 'In the recorded finite suite, each token with a settled request id makes 0 new effects.'),
    ('K-d', 'floor_controls', 'In the recorded finite suite, each valid token within the largest gap makes exactly '
     'its one effect: the board, one settled row and one outbox row with the checked allocation.'),
    ('K-e', 'floor_controls', 'In the recorded finite suite, each token above the largest gap of the sink is rejected '
     'with 0 effects.'),
]
NOT_USED = {'binary_proof': 'none in this slice', 'in_logic_compiler_proof': 'none in this slice'}
PROOF_ASSUMPTIONS = [
    'Dafny mathematical integers and finite sequences and strings; sequential pure calls; all typed inputs.',
    'The claim text is certificate/BookingCertificateSpec.dfy with BookingDualCert.dfy. It is a CANDIDATE '
    'specification, NOT approved intent. The batch problem (maximise the value under slot capacities) is not the '
    'approved booking specification, which has no batch, no value and no optimum.',
    'The two hash texts are inputs. No claim that they are hashes of the board or of the batch.',
    'The bridge (Q6) covers one predicate (NoDoubleBooking) and one batch shape. It does not link the batch model to '
    'the approved method Apply.',
    'Source proof does not cover compilation to JavaScript, the issuer process, encoding, hashing, signing, the '
    'sink, storage, the optimizers or deployment.',
    'The hand-written claim lemmas and the subject list must be read by a person (Slice 2 limit).',
]
TEST_ASSUMPTIONS = [
    'Finite: only the recorded rows and batches were executed. No statement about all inputs or all attacks.',
    'The winner of a race is not deterministic; the record holds only the counts.',
    'The database file is written only through the sink, except in the rows named "raw".',
    'The reference check and the search for the optimum are test code. They are not proved.',
]
TRUSTED_BASE = [
    'Pinned Dafny with bundled Boogie, .NET and Z3 4.12.1; no independent proof certificate kernel.',
    'Dafny JavaScript back end and runtime; bignumber.js (pinned).',
    'Pinned Node with its OpenSSL (Ed25519, SHA-256) and its built-in SQLite; tsx and typescript (pinned).',
    'ts/booking-certificate/encoding.ts, issuer.ts and sink.ts, and ts/refund-finality/encoding.ts: not proved.',
    'scripts/spec_clearing.py and this script: not proved.',
    'Operating-system process isolation and key secrecy; the host, its libraries and hardware.',
    'The sandbox tool of macOS (sandbox-exec) with the profile of ts/booking-certificate/guest.ts: it must keep an '
    'optimizer process from file writes, network use and signals. Trusted, not proved; its vendor marks it as '
    'deprecated. Without it an optimizer process, which runs as the same user, can write the database of the sink '
    'behind the sink (review finding R1).',
    'NOT trusted for what they SEND: the optimizers (guests/booking/*), rustc, the runner (guest.ts). A wrong '
    'optimizer or a wrong rustc can lose a booking. Through the line that it sends, an optimizer cannot make the '
    'sink take an allocation without a token. That it cannot act in another way rests on the sandbox above.',
]


class Failed(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Failed(message)


def rel(path):
    return Path(path).resolve().relative_to(ROOT).as_posix()


def snapshot(names):
    return {name: digest((ROOT / name).read_bytes()) for name in names}


def announce(tool, since):
    for command in tool.commands[since:]:
        print('  %s: exit %d' % (command['name'], command['exit_code']), flush=True)
    return len(tool.commands)


def text_id(fields):
    """SHA-256 of the canonical JSON text of a flat object of texts (the form of ts/refund-finality/encoding.ts)."""
    return digest(('{' + ','.join(json.dumps(key) + ':' + json.dumps(value) for key, value in sorted(fields.items())) + '}').encode())


def ids_of(module_sha256):
    """The checker id and the specification id, computed from the files (not taken from the issuer or a report)."""
    return {'core_module_sha256': module_sha256,
            'checker_sha256': text_id({'coreModuleSha256': module_sha256,
                                       'encodingSha256': digest((ROOT / 'ts/booking-certificate/encoding.ts').read_bytes()),
                                       'issuerSha256': digest((ROOT / 'ts/booking-certificate/issuer.ts').read_bytes()),
                                       'canonSha256': digest((ROOT / 'ts/refund-finality/encoding.ts').read_bytes())}),
            'spec_sha256': text_id({'candidateSpecSha256': digest((ROOT / SPEC).read_bytes()),
                                    'referenceSha256': digest((ROOT / REFERENCE).read_bytes())})}


def toolchain(tool):
    pins = read_json(ROOT / pin_file('dafny'))
    require(pins['verification_options'] == dafny.OPTIONS and '--track-print-effects' in dafny.OPTIONS,
            'TOOLCHAIN: the pinned options are not the gate options with print-effect tracking')
    require(platform.python_version() == pins['python']['version'], 'TOOLCHAIN: Python version differs from the pin')
    executables = {dafny.DAFNY: pins['dafny']['executable_sha256'],
                   ROOT / pins['z3']['path']: pins['z3']['executable_sha256'],
                   Path(sys.executable): pins['python']['executable_sha256']}
    for path, expected in executables.items():
        require(digest(Path(path).read_bytes()) == expected, 'TOOLCHAIN: executable digest differs: ' + str(path))
    version = tool.run([dafny.DAFNY, '--version'], 'dafny-version')
    require(version.returncode == 0 and version.stdout.decode().strip() == pins['dafny']['version_output'],
            'TOOLCHAIN: Dafny version differs from the pin')
    z3 = tool.run([ROOT / pins['z3']['path'], '--version'], 'z3-version')
    require(z3.returncode == 0 and z3.stdout.decode().strip() == pins['z3']['version_output'],
            'TOOLCHAIN: Z3 version differs from the pin')
    return {'dafny': pins['dafny']['version_output'], 'z3': pins['z3']['version_output'],
            'python': pins['python']['version']}


def output_of(tool, suffix):
    """Text of the verifier output of the tool's last check."""
    name = 'check-%03d-%s' % (tool.count, suffix)
    return ((tool.work / (name + '.stdout')).read_bytes() + (tool.work / (name + '.stderr')).read_bytes()).decode(
        'utf-8', 'replace')


def procedure(tool, core, label):
    """The one acceptance procedure, for the core and for every control fixture.

    1. Audit of every reached file, the two refused words, and the verifier, for the core file with the claim
       lemmas. 2. A non-abstract instance of the claim lemmas, bound to the core's module.
    """
    check = tool.check([core, CLAIMS_FILE])
    record = {'file': core, 'check': spec_clearing.summary(check), 'check_output': output_of(tool, 'verify'),
              'check_passed': spec_clearing.passed(check, CORE_MEMBERS), 'instance': None, 'instance_output': None}
    if record['check_passed']:
        try:
            instance = spec_clearing.instance_check(tool, label, [CLAIMS_FILE, core], INSTANCES, CLAIM_MEMBERS + [DECIDE],
                                                    tool.work / 'generated')
        except spec_clearing.Unusable as reason:
            instance = {'passed': False, 'reason': str(reason)}
        record['instance'] = instance
        record['instance_output'] = output_of(tool, 'verify')
    record['accepted'] = bool(record['check_passed'] and record['instance'] and record['instance']['passed'])
    record['members'] = dict(check['members'])
    return record


def core_proof(tool):
    tools = toolchain(tool)
    seen = announce(tool, 0)
    proof = procedure(tool, CORE, 'core')
    seen = announce(tool, seen)
    require(proof['accepted'], 'core: the procedure does not accept impl/BookingCertificate.dfy: '
            + canonical(proof['check']).decode().strip())
    bridge = tool.check([BRIDGE])
    announce(tool, seen)
    require(spec_clearing.passed(bridge, BRIDGE_MEMBERS), 'bridge: not proved: ' + canonical(spec_clearing.summary(bridge)).decode().strip())
    instance = proof['instance']
    return {'toolchain': tools,
            'core': {'files': [CORE, CLAIMS_FILE], 'audited_files': proof['check']['audited_files'],
                     'audit_exit': proof['check']['audit_exit'], 'checker_exit': proof['check']['checker_exit'],
                     'refused_word': proof['check']['refused'], 'required_members': CORE_MEMBERS,
                     'verified_members': sorted(proof['members']),
                     'instance': {key: instance[key] for key in ('instance_text', 'instance_sha256', 'required_members',
                                                                 'audited_files', 'audit_exit', 'checker_exit', 'passed')},
                     'note': 'Dafny makes no new proof task for the inherited members of the instance. The instance '
                             'makes Dafny report a member without a body and a print effect of the bound core. The '
                             'proofs are those of the abstract claim module; they hold for every refinement of the '
                             'specification. The core itself is a non-abstract refinement: Decide (correctness) is '
                             'its proof against the specified contract.'},
            'bridge': {'files': [BRIDGE], 'audited_files': bridge['audited_files'], 'audit_exit': bridge['audit_exit'],
                       'checker_exit': bridge['checker_exit'], 'refused_word': bridge['refused'],
                       'required_members': BRIDGE_MEMBERS, 'verified_members': len(bridge['members'])},
            'print_effects': 'Every verify command has the gate option --track-print-effects. Decide of the '
                             'specification and the callers in the claim file have no {:print} attribute.'}


def contract_clauses():
    """Line numbers of the two clauses of the specified contract of Decide: 'decision' and 'token'."""
    lines = (ROOT / SPEC).read_text().splitlines()
    start = next(n for n, line in enumerate(lines, 1) if line.strip().startswith('method Decide('))
    marks = [n for n, line in enumerate(lines, 1) if n > start and line.strip().startswith('ensures')]
    require(len(marks) == 2, 'specification: Decide does not have exactly two ensures clauses')
    return {'decision': range(marks[0], marks[1]), 'token': range(marks[1], len(lines) + 1)}


def errors_of(text):
    return [line for line in text.splitlines() if ': Error: ' in line]


def core_controls(tool):
    toolchain(tool)
    seen, clauses, results = announce(tool, 0), contract_clauses(), []
    for name, expected in sorted(CONTROLS.items()):
        source = FIXTURES + '/' + name + '.dfy'
        outcome = procedure(tool, source, 'control-' + name)
        seen = announce(tool, seen)
        check, kind = outcome['check'], expected[0]
        require(not outcome['accepted'], name + ': THE PROCEDURE ACCEPTS A WRONG CORE')
        record = {'fixture': source, 'expected': kind, 'accepted': False, 'audit_exit': check['audit_exit'],
                  'checker_exit': check['checker_exit'], 'refused_word': check['refused']}
        errors = errors_of(outcome['check_output'])
        if kind == 'postcondition':
            require(check['refused'] is None and check['audit_exit'] == 0 and check['checker_exit'] == 4
                    and check['failed'] == [DECIDE], name + ': not refused by the verifier at Decide alone')
            require(len(errors) == 1 and POSTCONDITION in errors[0], name + ': the error is not a failed postcondition')
            related = [int(n) for n in re.findall(re.escape(SPEC) + r'\((\d+),\d+\): Related location: this is the '
                                                  r'postcondition that could not be proved', outcome['check_output'])]
            hit = sorted({clause for clause, lines in clauses.items() for line in related if line in lines})
            require(hit == [expected[1]], name + ': the clause that failed is ' + str(hit) + ', expected ' + expected[1])
            record.update(failed_members=check['failed'], clause_not_proved=expected[1])
        elif kind == 'error':
            require(check['checker_exit'] == 2 and errors and all(expected[1] in line for line in errors),
                    name + ': not refused with the expected error')
            record['reason'] = expected[1]
        elif kind == 'instance':
            require(outcome['check_passed'], name + ': the file alone must pass (the control is for the instance)')
            instance, text = outcome['instance'], errors_of(outcome['instance_output'] or '')
            require(instance.get('checker_exit') == 2 and text and all(expected[1] in line for line in text),
                    name + ': the instance is not refused with the expected error')
            record.update(reason=expected[1], instance_checker_exit=instance['checker_exit'])
        elif kind == 'audit':
            require(check['refused'] is None and check['checker_exit'] == 0 and check['audit_exit'] != 0
                    and not check['failed'], name + ': not refused by the audit alone')
        else:
            require(check['checker_exit'] == 0 and check['audit_exit'] == 0 and not check['failed']
                    and check['refused'] is not None and 'expect' in check['refused'],
                    name + ': not refused by the refused word alone')
        record['result'] = 'refused for the expected reason'
        results.append(record)
    return results


def clearing(tool):
    toolchain(tool)
    seen = announce(tool, 0)
    subjects = read_json(ROOT / SUBJECTS)
    require([s['id'] for s in subjects['specs']] == [EXPECT_SUBJECT['id']]
            and [s['id'] for s in subjects['controls']] == [EXPECT_CONTROL['id']], 'clearing: the subject list is not the expected one')
    generated = tool.work / 'generated'
    record = spec_clearing.clear_spec(tool, subjects['specs'][0], generated)
    seen = announce(tool, seen)
    proof, probe, acceptance = record['proof'] or {}, record['spec_probe'] or {}, record.get('acceptance', {})
    require(record['verdict'] == EXPECT_SUBJECT['verdict'], 'clearing: expected NO_CHOICE, observed ' + record['verdict'])
    require(record['claim']['member'] == EXPECT_SUBJECT['claim'] and proof.get('passed') is True
            and set(EXPECT_SUBJECT['proof']) <= set(proof.get('required_members', [])),
            'clearing: the verdict does not rest on the pinned members')
    require(probe.get('passed') is True and probe.get('without_body') == EXPECT_SUBJECT['open'],
            'clearing: the probe of the specification did not pass')
    require(acceptance.get('result') == EXPECT_SUBJECT['acceptance'] and acceptance['check']['passed'] is True
            and set(EXPECT_SUBJECT['acceptance_members']) <= set(acceptance['check']['required_members']),
            'clearing: acceptance is not shown by the pinned members')
    control = spec_clearing.clear_spec(tool, subjects['controls'][0], generated)
    announce(tool, seen)
    examples = control['examples']
    require(control['verdict'] == EXPECT_CONTROL['verdict'] and control['claim']['member'] == EXPECT_CONTROL['claim']
            and control['claim']['failed'] == [EXPECT_CONTROL['claim']], 'clearing control: expected CHOICE at the claim')
    require(len(examples) == 1 and examples[0]['source'] == 'supplied'
            and control['candidates'][0]['check']['passed'] is True
            and set(EXPECT_CONTROL['witness']) <= set(control['candidates'][0]['check']['required_members']),
            'clearing control: the example does not rest on the pinned witness members')
    return {'subject': record, 'control': control}


def build(tool):
    """Compile the core once. Type check. Build the untrusted Rust optimizer. Returns the paths and a record."""
    from scripts.javascript_env import check as check_javascript
    js_pins = check_javascript()
    core_dir = tool.work / 'core'
    core_dir.mkdir()
    command = [dafny.DAFNY, 'build', CORE, '--target', 'js', '--output', rel(core_dir / 'model'), *dafny.OPTIONS]
    built = tool.run(command, 'compile-js')
    require(built.returncode == 0, 'compile: expected exit 0, observed ' + str(built.returncode))
    generated = (core_dir / 'model.js').read_bytes()
    module = core_dir / 'model.cjs'
    module.write_bytes(generated + FOOTER)
    types = tool.run(['node', 'node_modules/typescript/bin/tsc', '--noEmit'], 'type-check')
    require(types.returncode == 0, 'type check: expected exit 0, observed ' + str(types.returncode))
    rustc = shutil.which('rustc')
    require(rustc is not None, 'rustc is not installed: optimizer v2 cannot be built (this script installs nothing)')
    version = tool.run([rustc, '--version'], 'rustc-version')
    require(version.returncode == 0, 'rustc --version: exit ' + str(version.returncode))
    guest_dir = tool.work / 'guests'
    guest_dir.mkdir()
    binary = guest_dir / 'v2_fast'
    made = tool.run([rustc, '-D', 'unsafe_code', '-D', 'warnings', '--edition', '2021', '-C', 'opt-level=2',
                     '-C', 'debuginfo=0', '--remap-path-prefix', str(ROOT) + '=.', '-o', binary, RUST_SOURCE], 'rustc-v2')
    require(made.returncode == 0 and binary.is_file(), 'rustc: optimizer v2 did not build')
    source = (ROOT / RUST_SOURCE).read_text()
    require('#![forbid(unsafe_code)]' in source and 'extern crate' not in source and not re.search(r'\bunsafe\s*\{', source),
            'optimizer v2: the source does not forbid unsafe code')
    (tool.work / 'build-record.json').write_bytes(canonical({
        'note': 'Not part of the evidence bundle. The binary of the untrusted optimizer v2 as built in this folder.',
        'v2_binary_sha256': digest(binary.read_bytes())}))
    return {'module': module, 'binary': binary, 'js_pins': js_pins, 'check_javascript': check_javascript,
            'record': {'compiled_core': {'build_argv': ['.toolchain/dafny-4.11.0/dafny/dafny', 'build', CORE, '--target',
                                                        'js', *dafny.OPTIONS],
                                         'generated_js_sha256': digest(generated), 'export_footer_sha256': digest(FOOTER),
                                         'module_sha256': digest(generated + FOOTER), 'source_to_module_proved': False},
                       'type_check': {'argv': ['node', 'node_modules/typescript/bin/tsc', '--noEmit'], 'exit_code': 0},
                       'untrusted_tools': {'rustc': {
                           'version_output': version.stdout.decode().strip(), 'pinned': False,
                           'role': 'builds the untrusted optimizer v2 only; outside the proved parts and outside the '
                                   'trusted base of a token',
                           'argv': ['rustc', '-D', 'unsafe_code', '-D', 'warnings', '--edition', '2021', '-C',
                                    'opt-level=2', '-C', 'debuginfo=0', '--remap-path-prefix', '<repository>=.',
                                    '-o', '<work folder>/guests/v2_fast', RUST_SOURCE],
                           'exit_code': 0, 'source_sha256': digest((ROOT / RUST_SOURCE).read_bytes()),
                           'binary': 'no hash and no path of the binary is in this record'}}}}


def sink_controls(tool, made):
    out = tool.work / 'suite'
    suite = tool.run(['node', '--import', 'tsx', SUITE, rel(out), rel(made['module'])], 'suite')
    require(suite.returncode == 0, 'suite: expected exit 0, observed ' + str(suite.returncode))
    report_bytes = (out / 'report.json').read_bytes()
    report = read_json(out / 'report.json')
    counts = report['counts']
    require(report['kind'] == 'FINITE TEST' and report['method'] == 'floor_controls' and report['end_to_end'] is False,
            'suite: wrong evidence class in the report')
    require(counts['failed'] == 0 and all(row['pass'] is True for row in report['rows'])
            and counts['rows'] == len(report['rows']), 'suite: a row failed')
    require(counts['rejection_attempts'] > 0 and counts['effects_of_rejection_attempts'] == 0,
            'suite: a rejected attempt had an effect')
    require(all(counts[key] > 0 for key in ('issuer_rows', 'control_a_rows', 'control_b_rows', 'control_c_rows',
                                            'control_d_rows', 'control_e_rows', 'race_rows', 'audit_rows',
                                            'runner_rows', 'ids_rows', 'stated_limit_rows')), 'suite: a control group is empty')
    require(digest(made['module'].read_bytes()) == made['record']['compiled_core']['module_sha256']
            == report['ids']['core_module_sha256'], 'suite: the compiled module changed during the tests')
    require(report['ids'] == ids_of(made['record']['compiled_core']['module_sha256']),
            'suite: the ids of the report are not those of the files')
    return {'argv': ['node', '--import', 'tsx', SUITE], 'exit_code': suite.returncode,
            'node_version': 'v' + made['js_pins']['node_version'], 'report_sha256': digest(report_bytes), 'report': report}


def optimizers(made):
    runs = [('v1', 'TypeScript (the baseline of Rounds 2 and 3, solver 11)', 'all', 20000,
             ['node', '--import', 'tsx', 'guests/booking/v1_baseline.ts'],
             ['node', '--import', 'tsx', 'guests/booking/v1_baseline.ts']),
            ('v2', 'safe Rust (built by the rustc of this machine)', 'all', 20000, [rel(made['binary'])],
             ['<work folder>/guests/v2_fast'])]
    for mode in ADVERSARY_FULL:
        command = ['python3', 'guests/booking/v3_adversary.py', mode]
        runs.append(('v3-' + mode, 'Python (the adversary)', 'all', 20000, command, command))
    for mode, limit in ADVERSARY_LIMITS:
        command = ['python3', 'guests/booking/v3_adversary.py', mode]
        runs.append(('v3-' + mode, 'Python (the adversary)', '2', limit, command, command))
    return runs


def swap(tool, made):
    """Three optimizers, one after the other, against the one compiled core."""
    proof_inputs = snapshot([SPEC, CORE, CLAIMS_FILE, BRIDGE, REFERENCE])
    module_sha = made['record']['compiled_core']['module_sha256']
    first, runs, ids = len(tool.commands), [], ids_of(module_sha)
    for name, language, batches, limit, command, shown in optimizers(made):
        out = tool.work / ('swap-' + name)
        child = tool.run(['node', '--import', 'tsx', SWAP, rel(out), rel(made['module']), name, batches, limit, *command],
                         'swap-' + name)
        print('  swap-%s: exit %d' % (name, child.returncode), flush=True)
        require(child.returncode == 0, 'swap ' + name + ': expected exit 0, observed ' + str(child.returncode))
        report = read_json(out / 'report.json')
        counts = report['counts']
        require(report['kind'] == 'FINITE RUN' and report['optimizer'] == name and report['end_to_end'] is False
                and report['largest_gap_bps'] == LARGEST_GAP, 'swap ' + name + ': wrong report')
        require(counts['failed'] == 0 and all(row['pass'] is True for row in report['rows'])
                and counts['batches'] == len(report['rows']) == (BATCHES if batches == 'all' else int(batches)),
                'swap ' + name + ': a row failed')
        require(counts['effects_of_attempts_that_did_not_commit'] == 0 and counts['effects_of_replays'] == 0
                and counts['replays'] == counts['committed'] and counts['forged_offers'] == counts['forged_offers_rejected'],
                'swap ' + name + ': an attempt without a commit had an effect')
        require(digest(made['module'].read_bytes()) == module_sha == report['ids']['core_module_sha256'],
                'swap ' + name + ': the compiled core is not the one that was built')
        require(report['ids'] == ids, 'swap ' + name + ': the ids of the report are not those of the files')
        if name in EXPECT_SWAP:
            observed = {key: counts[key] for key in EXPECT_SWAP[name]}
            require(observed == EXPECT_SWAP[name], 'swap ' + name + ': counts differ from the pinned ones: ' + str(observed))
        else:
            require(counts['tokens'] == 0 and counts['committed'] == 0 and counts['no_token'] == counts['batches'],
                    'swap ' + name + ': THE ADVERSARY GOT A TOKEN')
            line, answer, not_feasible, not_readable, forged = EXPECT_ADVERSARY[name[3:]]
            every = counts['batches']
            wanted = {'answers': every if line == 'one line' else 0,
                      'proposals_not_feasible': every if not_feasible == 'all' else 0,
                      'proposals_not_readable': every if not_readable == 'all' else 0,
                      'forged_offers': every if forged == 'all' else 0}
            observed = {key: counts[key] for key in wanted}
            require(observed == wanted, 'swap ' + name + ': the adversary did not do what this mode does: ' + str(observed))
            require(all(row['answer'] == line and row['issuer'] == answer for row in report['rows']),
                    'swap ' + name + ': a row does not show the expected line and refusal')
        runs.append({'optimizer': name, 'language': language, 'argv': shown, 'batches': counts['batches'],
                     'exit_code': child.returncode, 'counts': counts, 'report_sha256': digest((out / 'report.json').read_bytes()),
                     'rows': report['rows']})
    # What this script itself started between the first and the last optimizer. Processes that an optimizer
    # run starts are not observed here (review finding R5).
    during = tool.commands[first:]
    dafny_starts = sum(1 for command in during if Path(command['argv'][0]).name == Path(str(dafny.DAFNY)).name
                       or 'dafny' in Path(command['argv'][0]).name.lower() or 'z3' in Path(command['argv'][0]).name.lower())
    require(len(during) == len(runs) and dafny_starts == 0, 'swap: this script started another command between the optimizers')
    require(snapshot([SPEC, CORE, CLAIMS_FILE, BRIDGE, REFERENCE]) == proof_inputs,
            'swap: a proof input changed between the optimizers')
    require(made['check_javascript']() == made['js_pins'], 'swap: the JavaScript toolchain changed')
    languages = {run['language'].split(' ')[0] for run in runs}
    require(len(runs) == 2 + len(ADVERSARY_FULL) + len(ADVERSARY_LIMITS) and len(languages) >= 3, 'swap: fewer than three optimizers')
    return {'largest_gap_bps': LARGEST_GAP, 'ids_computed_from_the_files': ids,
            'commands_of_this_script_between_first_and_last_optimizer': len(during), 'of_them_optimizer_runs': len(runs),
            'of_them_dafny_or_z3': dafny_starts, 'compiled_core_sha256_before_and_after': module_sha,
            'proof_inputs_sha256_before_and_after': proof_inputs, 'runs': runs}


def bundle_of(work):
    inputs = SUBJECT + REUSED + APPROVED + TRUSTED
    before = snapshot(inputs)
    proof = core_proof(spec_clearing.Tool(work / 'core-proof'))
    controls = core_controls(spec_clearing.Tool(work / 'core-controls'))
    cleared = clearing(spec_clearing.Tool(work / 'clearing'))
    tool = spec_clearing.Tool(work / 'runtime')
    made = build(tool)
    announce(tool, 0)
    suite = sink_controls(tool, made)
    print('  suite: exit %d' % suite['exit_code'], flush=True)
    swapped = swap(tool, made)
    require(snapshot(inputs) == before, 'INPUT_CHANGED: a source or trusted input changed during the checks')
    committed = sum(run['counts']['committed'] for run in swapped['runs'])
    evidence = []
    for claim, method, statement in CLAIMS:
        proved = method == 'source_proof'
        evidence.append({
            'claim_id': claim, 'statement_plain_english': statement, 'method': method, 'result': 'passed',
            'tool': 'Dafny' if proved else 'node (finite recorded runs)',
            'tool_version': proof['toolchain']['dafny'] if proved else suite['node_version'],
            'assumptions': PROOF_ASSUMPTIONS if proved else TEST_ASSUMPTIONS,
            'reproduce_cmd': 'python3 scripts/exit_slice3.py --case evidence'})
    return {
        'record': 'forge-slice3-runtime-certificates', 'format_version': 1,
        'gate_accepted': False, 'policy': None, 'end_to_end': False,
        'producer': 'scripts/exit_slice3.py (a scenario script; not the gate)',
        'note': 'A record of real tool runs. It is not Forge gate evidence: no policy lists these claims and no '
                'gate obligation lists these files. A test count is not a proof. The check is sound, not complete.',
        'master_idea_items': ['F3.1', 'F3.2'],
        'source_manifest': [{'path': name, 'sha256': before[name]} for name in sorted(SUBJECT)],
        'reused_inputs_sha256': {name: before[name] for name in REUSED},
        'approved_inputs_sha256': {name: before[name] for name in APPROVED},
        'trusted_input_sha256': {name: before[name] for name in TRUSTED},
        'toolchain': proof['toolchain'], 'verification_options': dafny.OPTIONS,
        'evidence': evidence, 'evidence_methods_not_used': NOT_USED,
        'source_proof': {key: proof[key] for key in ('core', 'bridge', 'print_effects')},
        'core_controls': controls,
        'clearing': cleared,
        'compiled_core': made['record']['compiled_core'], 'type_check': made['record']['type_check'],
        'untrusted_tools': made['record']['untrusted_tools'],
        'sink_controls': suite,
        'optimizer_swap': swapped,
        'runtime_certificate_checked': {'committed_allocations_in_the_recorded_runs': committed},
        'trusted_base': TRUSTED_BASE,
    }


def report_of(bundle):
    lines = ['# Slice 3 — optimizer swap record (made from the evidence record by `scripts/exit_slice3.py`)', '',
             'Finite recorded runs. `end_to_end=false`. Not gate evidence. A count is not a proof.', '',
             'Compiled core module SHA-256 `%s`. Checker id `%s`. The same for every optimizer, and equal to a new '
             'computation from the files.' % (bundle['compiled_core']['module_sha256'],
                                              bundle['optimizer_swap']['ids_computed_from_the_files']['checker_sha256']),
             'Commands of the EXIT script between the first and the last optimizer: %d, all optimizer runs; Dafny or Z3 '
             'among them: %d. Largest gap of the sink: %d basis points.' % (
                 bundle['optimizer_swap']['commands_of_this_script_between_first_and_last_optimizer'],
                 bundle['optimizer_swap']['of_them_dafny_or_z3'], bundle['optimizer_swap']['largest_gap_bps']), '',
             '| Optimizer | Language | Batches | Lines | Tokens | Committed | At gap 0 | Tokens above the largest gap | No token | Effects without a commit |',
             '| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |']
    for run in bundle['optimizer_swap']['runs']:
        c = run['counts']
        lines.append('| %s | %s | %d | %d | %d | %d | %d | %d | %d | %d |' % (
            run['optimizer'], run['language'], c['batches'], c['answers'], c['tokens'], c['committed'],
            c['committed_at_gap_0'], c['tokens_above_the_largest_gap'], c['no_token'],
            c['effects_of_attempts_that_did_not_commit']))
    lines += ['', '| Wrong core | Refused by | Detail |', '| --- | --- | --- |']
    for record in bundle['core_controls']:
        detail = record.get('clause_not_proved') or record.get('reason') or (record['refused_word'] or 'audit exit %d' % record['audit_exit'])
        lines.append('| `%s` | %s | %s |' % (record['fixture'].rsplit('/', 1)[1], record['expected'], detail))
    return '\n'.join(lines) + '\n'


def attempt_folder(case):
    base = ROOT / 'build/slice3' / case
    base.mkdir(parents=True, exist_ok=True)
    number = 1 + max([int(p.name.split('-')[1]) for p in base.glob('attempt-*')] or [0])
    return base / ('attempt-%04d' % number)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--case', required=True,
                        choices=('core-proof', 'core-controls', 'clearing', 'sink-controls', 'swap', 'evidence'))
    args = parser.parse_args()
    work = attempt_folder(args.case)
    print('SLICE3 ' + args.case + ': ' + rel(work), flush=True)
    if args.case == 'core-proof':
        result = core_proof(spec_clearing.Tool(work))
        print('  core: %d members verified, audit of %d files: exit %d; bridge: %d members verified' % (
            len(result['core']['verified_members']), result['core']['audited_files'], result['core']['audit_exit'],
            result['bridge']['verified_members']))
    elif args.case == 'core-controls':
        for record in core_controls(spec_clearing.Tool(work)):
            print('  %s: refused (%s)' % (record['fixture'].rsplit('/', 1)[1], record.get('clause_not_proved') or record['expected']))
    elif args.case == 'clearing':
        result = clearing(spec_clearing.Tool(work))
        print('  %s: %s, %s; %s: %s' % (result['subject']['id'], result['subject']['verdict'],
                                         result['subject']['acceptance']['result'], result['control']['id'],
                                         result['control']['verdict']))
    elif args.case in ('sink-controls', 'swap'):
        tool = spec_clearing.Tool(work)
        toolchain(tool)
        made = build(tool)
        announce(tool, 0)
        if args.case == 'sink-controls':
            print('  suite counts: ' + canonical(sink_controls(tool, made)['report']['counts']).decode().strip())
        else:
            result = swap(tool, made)
            for run in result['runs']:
                print('  %s: %d tokens, %d committed of %d' % (run['optimizer'], run['counts']['tokens'],
                                                               run['counts']['committed'], run['batches']))
            print('  commands of this script between the optimizers: %d, all optimizer runs; Dafny or Z3 among them: %d' % (
                result['commands_of_this_script_between_first_and_last_optimizer'], result['of_them_dafny_or_z3']))
    else:
        work.mkdir(parents=True)
        bundles = []
        for number in (1, 2):
            print(' run ' + str(number), flush=True)
            bundles.append(canonical(bundle_of(work / ('run-%d' % number))))
            (work / ('run-%d' % number) / 'evidence.json').write_bytes(bundles[-1])
        require(bundles[0] == bundles[1], 'evidence: the two bundles differ')
        (work / 'evidence.json').write_bytes(bundles[0])
        (work / 'SWAP_REPORT.md').write_text(report_of(read_json(work / 'evidence.json')))
        print('  bundle: ' + rel(work / 'evidence.json') + ' sha256 ' + digest(bundles[0]) + ' (two runs, byte-identical)')
    print('SLICE3 ' + args.case + ': PASSED; end_to_end=false')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Failed as error:
        print('SLICE3 FAILED: ' + str(error), file=sys.stderr)
        sys.exit(1)
    except Exception:  # a missing tool or a crash is not a negative result
        traceback.print_exc()
        sys.exit(2)
