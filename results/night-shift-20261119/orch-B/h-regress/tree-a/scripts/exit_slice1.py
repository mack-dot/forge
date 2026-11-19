#!/usr/bin/env python3
"""Slice 1 (master idea items F2.1 to F2.3): EXIT checks of the refund finality boundary. Dispatch only.

This script starts the pinned Dafny, the refund gate and the pinned Node. It compares their exit
codes and records with the expected ones. It decides no proof and interprets no program.

Its bundle is a RECORD. It is NOT gate evidence: no policy lists these claims and no gate
obligation lists these files. Raw outputs go to build/slice1/ (ignored by git). Nothing is
written under results/.

Cases:
  core-proof     refund gate (R1-R5) exit 0; Dafny audit and verify of the checker core exit 0
  core-controls  every wrong core is rejected by the pinned Dafny for the expected reason
  sink-controls  compile the core; type check; the finite control suite exits 0
  evidence       all three, twice, in fresh folders; the two bundles are byte-identical
"""

import argparse
from pathlib import Path
import platform
import re
import subprocess
import sys
import traceback
import xml.etree.ElementTree as ET

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
sys.path.insert(0, str(ROOT))
from common import canonical, digest, pin_file, read_json  # noqa: E402
from backends import dafny  # noqa: E402  (the gate's own Dafny path and options)

CORE = 'impl/RefundFinality.dfy'
BINDING = 'tests/refund-finality/Bindings.dfy'
FIXTURES = 'tests/refund-finality/fixtures'
SUITE = 'tests/refund-finality/suite.ts'
FOOTER = b'\nmodule.exports = { RefundFinality, Refund, runtime: _dafny };\n'
REQUIRED = {
    'Refund.Assess (correctness)', 'Refund.Assess (well-formedness)',
    'RefundSpec.Assess (well-formedness)', 'RefundSpec.Eligible (well-formedness)',
    'RefundFinality.Check (correctness)', 'RefundFinality.Check (well-formedness)',
    'RefundFinalityChecks.Universal (correctness)', 'RefundFinalityChecks.NoChoice (correctness)',
    'RefundFinalityChecks.IssueWitness (correctness)', 'RefundFinalityChecks.RefuseWitnesses (correctness)',
}
PRINT_STATEMENT = 'to use a print statement, the enclosing method must be marked with {:print}'
PRINT_CALL = 'to call a method with print effects, the enclosing method must be marked with {:print}'
# fixture -> expected raw checker exit, and the reason that must appear.
# 'claims': a failed assertion inside that claim's block of RefundFinalityChecks.Universal.
# 'marker': a text that every reported error must contain.
CONTROLS = {
    'CoreIssuesEverything': {'exit': 4, 'claims': ['P1']},
    'CoreKeepsRemaining': {'exit': 4, 'claims': ['P1']},
    'CoreSkipsIntentCheck': {'exit': 4, 'claims': ['P1']},
    'CoreRefusesEverything': {'exit': 4, 'claims': ['P2']},
    'CoreIntentOnRefusal': {'exit': 4, 'claims': ['P3']},
    'CoreWrongHash': {'exit': 4, 'claims': ['P4']},
    'CoreNeedsPrecondition': {'exit': 4, 'marker': 'a precondition for this call could not be proved'},
    'CorePrints': {'exit': 2, 'marker': PRINT_STATEMENT},
    'CorePrintsMarked': {'exit': 2, 'marker': PRINT_CALL},
}
SUBJECT = [CORE, BINDING, SUITE, 'tests/refund-finality/commit_cli.ts', 'tests/refund-finality/dispatch_cli.ts',
           'tests/refund-finality/issuer_exports_probe.ts', 'scripts/exit_slice1.py',
           'ts/refund-finality/encoding.ts', 'ts/refund-finality/minter.ts', 'ts/refund-finality/sink.ts',
           'ts/refund-finality/dispatcher.ts', 'ts/refund-finality/proposer.ts'] + [
               FIXTURES + '/' + name + '.dfy' for name in sorted(CONTROLS)]
APPROVED = ['impl/Refund.dfy', 'spec/refund/RefundSpec.dfy', 'spec/refund/protocol.md',
            'spec/refund/spec.lock', 'policy/refund.yaml']
TRUSTED = ['gate/refund.py', 'gate/refund/Bindings.dfy', 'gate/backends/dafny.py', 'gate/common.py',
           'gate/expected-audit.md', pin_file('dafny'), pin_file('javascript'), 'scripts/javascript_env.py',
           'package.json', 'package-lock.json', 'tsconfig.json']
CLAIMS = [
    ('P1', 'source_proof', 'Every token that Check issues is for a transition that the approved refund relation '
     'makes eligible (context from the pre-state, request open), with the post-state equal to the pre-state with '
     '`remaining` decreased by the amount, and with the caller-bound intent.'),
    ('P2', 'source_proof', 'Check issues a token for every such transition. Check has no precondition.'),
    ('P3', 'source_proof', 'A refusal returns an empty plan. An issue returns exactly one intent, the checked one.'),
    ('P4', 'source_proof', 'An issued token holds exactly the given pre-state hash text, the request id, the '
     'checked post-state and the checked intent.'),
    ('K-a', 'unit_tested', 'In the recorded finite suite, each attempt with a missing, forged or tampered token is '
     'rejected by the sink with 0 effects.'),
    ('K-b', 'unit_tested', 'In the recorded finite suite, each validly signed token whose pre-state hash is not the '
     'hash of the stored state is rejected with 0 effects; of several tokens for one pre-state exactly one commits.'),
    ('K-c', 'unit_tested', 'In the recorded finite suite, each token with a settled request id makes 0 new effects.'),
    ('K-d', 'unit_tested', 'In the recorded finite suite, each valid transition makes exactly its one effect: the '
     'post-state, one settled row, one outbox row and one outbound effect with the checked intent.'),
]
PROOF_ASSUMPTIONS = [
    'Dafny mathematical integers and finite strings; sequential pure calls; all typed inputs are covered.',
    'The claim text is tests/refund-finality/Bindings.dfy. It is NOT approved intent: the post-state rule, the '
    'token fields and "the request is open" are choices of that file. The approved refund specification has no '
    'stored state.',
    'Refund.Assess is impl/Refund.dfy, which the refund gate accepted for R1-R5 in the same run.',
    'The pre-state hash is an input text. No claim that it is the hash of the pre-state.',
    'Source proof does not cover compilation to JavaScript, the issuer process, encoding, hashing, signing, the '
    'sink, the dispatcher, storage or deployment.',
]
TEST_ASSUMPTIONS = [
    'Finite test: only the recorded rows were executed. No statement about all attacks.',
    'The winner of a race is not deterministic; the record holds only the counts.',
    'The database file is written only through the sink, except in the rows named "raw".',
]
TRUSTED_BASE = [
    'Pinned Dafny with bundled Boogie, .NET and Z3 4.12.1; no independent proof certificate kernel.',
    'Dafny JavaScript back end and runtime; bignumber.js (pinned).',
    'Pinned Node with its OpenSSL (Ed25519, SHA-256) and its built-in SQLite; tsx and typescript (pinned).',
    'ts/refund-finality/*.ts: issuer glue, encoding, sink and dispatcher. Not proved.',
    'Operating-system process isolation and key secrecy; the host, its libraries and hardware.',
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


class Run:
    """One fresh work folder: every command with its real exit code and full output."""

    def __init__(self, work):
        self.work = work
        work.mkdir(parents=True)
        self.commands = []

    def execute(self, argv, name):
        child = subprocess.run([str(part) for part in argv], cwd=ROOT, capture_output=True)
        (self.work / (name + '.stdout')).write_bytes(child.stdout)
        (self.work / (name + '.stderr')).write_bytes(child.stderr)
        self.commands.append({'name': name, 'argv': [str(part) for part in argv], 'exit_code': child.returncode,
                              'stdout_sha256': digest(child.stdout), 'stderr_sha256': digest(child.stderr)})
        (self.work / 'operations.json').write_bytes(canonical({'commands': self.commands, 'stage_exit': False}))
        print('  ' + name + ': exit ' + str(child.returncode), flush=True)
        return child


def toolchain(run):
    pins = read_json(ROOT / pin_file('dafny'))
    require(pins['verification_options'] == dafny.OPTIONS, 'TOOLCHAIN: the pinned options are not the gate options')
    require(platform.python_version() == pins['python']['version'], 'TOOLCHAIN: Python version differs from the pin')
    executables = {dafny.DAFNY: pins['dafny']['executable_sha256'],
                   ROOT / pins['z3']['path']: pins['z3']['executable_sha256'],
                   Path(sys.executable): pins['python']['executable_sha256']}
    for path, expected in executables.items():
        require(digest(Path(path).read_bytes()) == expected, 'TOOLCHAIN: executable digest differs: ' + str(path))
    version = run.execute([dafny.DAFNY, '--version'], 'dafny-version')
    require(version.returncode == 0 and version.stdout.decode().strip() == pins['dafny']['version_output'],
            'TOOLCHAIN: Dafny version differs from the pin')
    z3 = run.execute([ROOT / pins['z3']['path'], '--version'], 'z3-version')
    require(z3.returncode == 0 and z3.stdout.decode().strip() == pins['z3']['version_output'],
            'TOOLCHAIN: Z3 version differs from the pin')
    return {'dafny': pins['dafny']['version_output'], 'z3': pins['z3']['version_output'],
            'python': pins['python']['version']}


def trx_rows(path):
    rows = sorted(({'name': re.sub(r' \(assertion batch \d+\)$', '', e.get('testName')), 'outcome': e.get('outcome')}
                   for e in ET.parse(path).iter() if e.tag.endswith('UnitTestResult')),
                  key=lambda row: (row['name'], row['outcome']))
    return rows


def audit(run, source, name):
    report = run.work / (name + '.md')
    report.write_bytes(dafny.AUDIT.read_bytes())
    child = run.execute([dafny.DAFNY, 'audit', source, BINDING, '--report-format', 'md',
                         '--report-file', report, '--compare-report'], name)
    require(child.returncode == 0, name + ': the Dafny audit differs from the empty baseline')
    return digest(report.read_bytes())


def core_proof(run):
    tools = toolchain(run)
    # The checker core calls Refund.Assess. The refund gate itself must accept impl/Refund.dfy for R1-R5.
    gate_output = run.work / 'refund-gate.json'
    gate = run.execute([sys.executable, 'gate/refund.py', '--tier', 'critical', '--evidence', rel(gate_output)],
                       'refund-gate')
    require(gate.returncode == 0, 'refund gate: expected exit 0, observed ' + str(gate.returncode))
    bundle = read_json(gate_output)
    require(bundle['end_to_end'] is False
            and {(e['claim_id'], e['method'], e['result']) for e in bundle['evidence']}
            == {('R' + str(i), 'source_proof', 'passed') for i in range(1, 6)},
            'refund gate: R1-R5 source_proof not all passed')
    before = audit(run, CORE, 'audit-before')
    trx = run.work / 'verify.trx'
    verified = run.execute([dafny.DAFNY, 'verify', CORE, BINDING, *dafny.OPTIONS,
                            '--log-format', 'trx;LogFileName=' + str(trx)], 'verify')
    require(verified.returncode == 0, 'verify: expected checker exit 0, observed ' + str(verified.returncode))
    rows = trx_rows(trx)
    require({row['name'] for row in rows} == REQUIRED, 'verify: the verified members are not the required set')
    require(all(row['outcome'] == 'Passed' for row in rows), 'verify: a member did not pass')
    after = audit(run, CORE, 'audit-after')
    require(before == after == digest(dafny.AUDIT.read_bytes()), 'audit: report differs from the empty baseline')
    return {'toolchain': tools,
            'refund_gate': {'argv': ['python3', 'gate/refund.py', '--tier', 'critical'], 'exit_code': gate.returncode,
                            'claims': {'R' + str(i): 'source_proof' for i in range(1, 6)},
                            'evidence_sha256': digest(gate_output.read_bytes()),
                            'artifact_sha256': bundle['artifact']['sha256']},
            'verify': {'argv': ['.toolchain/dafny-4.11.0/dafny/dafny', 'verify', CORE, BINDING, *dafny.OPTIONS],
                       'exit_code': verified.returncode, 'verified_obligations': rows},
            'audit': {'exit_code': 0, 'findings': 0, 'report_sha256': after},
            'print_effects': 'The verify command has the gate option --track-print-effects. The callers in the '
                             'binding file have no {:print} attribute.'}


def claim_blocks():
    """Line ranges of the claim blocks P1..P4 inside RefundFinalityChecks.Universal."""
    marks = []
    for number, line in enumerate((ROOT / BINDING).read_text().splitlines(), 1):
        found = re.match(r'\s*// (P[1-4]) ', line)
        if found:
            marks.append((found.group(1), number))
        elif marks and len(marks) == 4 and re.match(r'\s*// Consequences', line):
            marks.append(('end', number))
            break
    require([m[0] for m in marks] == ['P1', 'P2', 'P3', 'P4', 'end'], 'binding file: claim markers not found')
    return {marks[i][0]: (marks[i][1], marks[i + 1][1]) for i in range(4)}


def core_controls(run):
    toolchain(run)
    blocks, results = claim_blocks(), []
    for name, expected in sorted(CONTROLS.items()):
        source, trx = FIXTURES + '/' + name + '.dfy', run.work / (name + '.trx')
        child = run.execute([dafny.DAFNY, 'verify', source, BINDING, *dafny.OPTIONS,
                             '--log-format', 'trx;LogFileName=' + str(trx)], 'control-' + name)
        output = (child.stdout + child.stderr).decode('utf-8', 'replace')
        errors = [line for line in output.splitlines() if ': Error: ' in line]
        require(child.returncode == expected['exit'],
                name + ': expected checker exit ' + str(expected['exit']) + ', observed ' + str(child.returncode))
        require(errors, name + ': the checker reported no error')
        record = {'fixture': source, 'checker_exit': child.returncode, 'expected_checker_exit': expected['exit'],
                  'errors': len(errors)}
        if 'marker' in expected:
            require(all(expected['marker'] in line for line in errors), name + ': an error has another reason')
            record['reason'] = expected['marker']
        if expected['exit'] == 4:
            rows = {row['name']: row['outcome'] for row in trx_rows(trx)}
            failed = sorted(member for member, outcome in rows.items() if outcome != 'Passed')
            # The wrong core satisfies its own (weakened) contract. The binding file is what rejects it.
            require(rows.get('RefundFinality.Check (correctness)') == 'Passed'
                    and 'RefundFinalityChecks.Universal (correctness)' in failed
                    and all(member.startswith('RefundFinalityChecks.') for member in failed),
                    name + ': the rejection is not in the binding file')
            record['failed_members'] = failed
        if 'claims' in expected:
            lines = [int(n) for n in re.findall(re.escape(BINDING) + r'\((\d+),\d+\): Error: assertion might not hold',
                                                output)]
            hit = sorted({claim for claim, (first, last) in blocks.items() for line in lines if first < line < last})
            require(set(expected['claims']) <= set(hit), name + ': the expected claim did not fail: ' + str(hit))
            record['claims_not_proved'] = hit
        record['result'] = 'rejected for the expected reason'
        results.append(record)
    return results


def sink_controls(run):
    from scripts.javascript_env import check as check_javascript
    js_pins = check_javascript()
    toolchain(run)
    core_dir = run.work / 'core'
    core_dir.mkdir()
    command = [dafny.DAFNY, 'build', CORE, '--target', 'js', '--output', rel(core_dir / 'model'), *dafny.OPTIONS]
    built = run.execute(command, 'compile-js')
    require(built.returncode == 0, 'compile: expected exit 0, observed ' + str(built.returncode))
    generated = (core_dir / 'model.js').read_bytes()
    module = core_dir / 'model.cjs'
    module.write_bytes(generated + FOOTER)
    types = run.execute(['node', 'node_modules/typescript/bin/tsc', '--noEmit'], 'type-check')
    require(types.returncode == 0, 'type check: expected exit 0, observed ' + str(types.returncode))
    out = run.work / 'suite'
    suite = run.execute(['node', '--import', 'tsx', SUITE, rel(out), rel(module)], 'suite')
    require(suite.returncode == 0, 'suite: expected exit 0, observed ' + str(suite.returncode))
    report_bytes = (out / 'report.json').read_bytes()
    report = read_json(out / 'report.json')
    counts = report['counts']
    require(report['kind'] == 'FINITE TEST' and report['method'] == 'unit_tested' and report['end_to_end'] is False,
            'suite: wrong evidence class in the report')
    require(counts['failed'] == 0 and all(row['pass'] is True for row in report['rows'])
            and counts['rows'] == len(report['rows']), 'suite: a row failed')
    require(counts['effects_of_rejection_attempts'] == 0, 'suite: a rejected attempt had an effect')
    require(all(counts['control_' + c + '_rows'] > 0 for c in 'abcd'), 'suite: a control group is empty')
    require(digest(module.read_bytes()) == digest(generated + FOOTER) == report['ids']['core_module_sha256'],
            'suite: the compiled module changed during the tests')
    require(check_javascript() == js_pins, 'suite: the JavaScript toolchain changed')
    return {'compiled_core': {'build_argv': ['.toolchain/dafny-4.11.0/dafny/dafny', 'build', CORE, '--target', 'js',
                                             *dafny.OPTIONS],
                              'generated_js_sha256': digest(generated), 'export_footer_sha256': digest(FOOTER),
                              'module_sha256': digest(generated + FOOTER), 'source_to_module_proved': False},
            'type_check': {'argv': ['node', 'node_modules/typescript/bin/tsc', '--noEmit'], 'exit_code': 0},
            'suite': {'argv': ['node', '--import', 'tsx', SUITE], 'exit_code': suite.returncode,
                      'node_version': 'v' + js_pins['node_version'], 'report_sha256': digest(report_bytes),
                      'report': report}}


def bundle_of(run):
    inputs = SUBJECT + APPROVED + TRUSTED
    before = snapshot(inputs)
    proof = core_proof(Run(run.work / 'core-proof'))
    controls = core_controls(Run(run.work / 'core-controls'))
    sink = sink_controls(Run(run.work / 'sink-controls'))
    require(snapshot(inputs) == before, 'INPUT_CHANGED: a source or trusted input changed during the checks')
    evidence = []
    for claim, method, statement in CLAIMS:
        proved = method == 'source_proof'
        evidence.append({
            'claim_id': claim, 'statement_plain_english': statement, 'method': method, 'result': 'passed',
            'tool': 'Dafny' if proved else 'node (finite suite)',
            'tool_version': proof['toolchain']['dafny'] if proved else sink['suite']['node_version'],
            'artifact': CORE if proved else 'ts/refund-finality/sink.ts with the compiled core and the issuer',
            'assumptions': PROOF_ASSUMPTIONS if proved else TEST_ASSUMPTIONS,
            'reproduce_cmd': 'python3 scripts/exit_slice1.py --case evidence'})
    return {
        'record': 'forge-slice1-refund-finality', 'format_version': 1,
        'gate_accepted': False, 'policy': None, 'end_to_end': False,
        'producer': 'scripts/exit_slice1.py (a scenario script; not the gate)',
        'note': 'A record of real tool runs. It is not Forge gate evidence: no policy lists these claims and no '
                'gate obligation lists these files. A test count is not a proof.',
        'master_idea_items': ['F2.1', 'F2.2', 'F2.3'],
        'source_manifest': [{'path': name, 'sha256': before[name]} for name in sorted(SUBJECT)],
        'approved_inputs_sha256': {name: before[name] for name in APPROVED},
        'trusted_input_sha256': {name: before[name] for name in TRUSTED},
        'toolchain': proof['toolchain'], 'verification_options': dafny.OPTIONS,
        'evidence': evidence,
        'source_proof': {key: proof[key] for key in ('refund_gate', 'verify', 'audit', 'print_effects')},
        'core_controls': controls,
        'compiled_core': sink['compiled_core'], 'type_check': sink['type_check'], 'sink_controls': sink['suite'],
        'trusted_base': TRUSTED_BASE,
    }


def attempt_folder(case):
    base = ROOT / 'build/slice1' / case
    base.mkdir(parents=True, exist_ok=True)
    number = 1 + max([int(p.name.split('-')[1]) for p in base.glob('attempt-*')] or [0])
    return base / ('attempt-%04d' % number)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--case', required=True, choices=('core-proof', 'core-controls', 'sink-controls', 'evidence'))
    args = parser.parse_args()
    work = attempt_folder(args.case)
    print('SLICE1 ' + args.case + ': ' + rel(work), flush=True)
    if args.case == 'core-proof':
        result = core_proof(Run(work))
        print('  verified members: %d, all Passed; audit findings: 0' % len(result['verify']['verified_obligations']))
    elif args.case == 'core-controls':
        results = core_controls(Run(work))
        for record in results:
            print('  %s: checker exit %d; %s' % (record['fixture'].rsplit('/', 1)[1], record['checker_exit'],
                                                ', '.join(record.get('claims_not_proved', [])) or record['reason']))
    elif args.case == 'sink-controls':
        result = sink_controls(Run(work))
        print('  suite counts: ' + canonical(result['suite']['report']['counts']).decode().strip())
    else:
        work.mkdir(parents=True)
        bundles = []
        for number in (1, 2):
            print(' run ' + str(number), flush=True)
            run = Run(work / ('run-%d' % number))
            bundles.append(canonical(bundle_of(run)))
            (run.work / 'evidence.json').write_bytes(bundles[-1])
        require(bundles[0] == bundles[1], 'evidence: the two bundles differ')
        (work / 'evidence.json').write_bytes(bundles[0])
        print('  bundle: ' + rel(work / 'evidence.json') + ' sha256 ' + digest(bundles[0]) + ' (two runs, byte-identical)')
    print('SLICE1 ' + args.case + ': PASSED; end_to_end=false')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Failed as error:
        print('SLICE1 FAILED: ' + str(error), file=sys.stderr)
        sys.exit(1)
    except Exception:  # a missing tool or a crash is not a negative result
        traceback.print_exc()
        sys.exit(2)
