#!/usr/bin/env python3
"""Goal 21 (Gate F1): EXIT checks of intent clearing: scripts/intent_clearing.py (the engine), scripts/intent_restate.py
(the blind restater), their suites, the planted specifications and the UNAPPLIED dispatcher diff
proposals/forge2-goal21-intent/forge-airlock-check-intent.diff.

What a pass means: on this machine the checks below gave the recorded results. Each table row, each PROVED EMPTY cell,
the seal, each NO and each witness is PROVED by Dafny for the GENERATED model only (the generator is a TRUSTED
ASSUMPTION). The suites, the changed copies and the dispatcher check are TESTED: finite runs, not proofs. Nothing says
that a specification is the intent. end_to_end stays false. M1 stays OPEN. The bundle is a RECORD, not gate evidence.

This script starts tools and compares results. It decides nothing about a specification. It records REAL exit codes.
A check that cannot run is recorded as NOT RUN, and its case then fails. No number is mocked or estimated.

Cases:
  suite       tests/intent/test_intent_clearing.py and tests/intent/test_intent_restate.py, all cases; exit 0 each; every
              case line is parsed; the counts come from their real output
  planted     for each pair (vip, shipping, boundary): check-intent on the clean and on the planted specification with
              the query file of the pair. Clean: exit 0, CLEAN, every query NO, the seal proved. Planted: exit 4,
              WARNINGS, the named query is a WARNING with a Dafny-verified witness, the table differs at the named
              boundary, the restatement bullets differ. Also the clean Goal 20 policy refunds-v2.json (no query file):
              exit 0. Every exit code and the SHA-256 of every JSON report are recorded
  mutations   the changed copies of the table MUTANTS below, each run in a tree where it replaces the original; each
              must FAIL its named check for its NAMED REASON. A kill for another reason is WRONG_REASON; a copy that is
              not killed is NOT_KILLED. Either fails the case (unless the copy is in NOT_KILLED_ALLOWED with a reason).
              At least 15 copies of intent_clearing.py must be killed for their named reason
  dispatcher  the tracked bin/forge-airlock is still the Goal 20 file (SHA-256 bd56d8b6...6891); the diff applies to
              exactly that file (git apply --check); a copy patched with patch(1) runs check-intent: boundary-clean exit
              0 with a RESULT line, boundary-planted-inclusive exit 4; the unpatched copy refuses check-intent (exit 2)
  evidence    suite, planted, mutations and dispatcher, twice, in fresh folders; the two canonical bundles are
              byte-identical; the digest is compared with the tracked record (--write-record writes it)
Raw outputs go to build/goal21/ (ignored by git). Times go to measurements.json, never to the bundle.
Environment: FORGE_DAFNY_LOCK, when set, reaches every child unchanged (this script makes no lock of its own).
Exit: 0 passed; 1 failed; 2 toolchain error.
"""

import argparse
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time
import hashlib

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
from common import canonical, digest, pin_file, read_json  # noqa: E402  (record helpers only; no decision)

BUILD = 'build/goal21'
CLEARING, RESTATE = 'scripts/intent_clearing.py', 'scripts/intent_restate.py'
SUITES = {'clearing': 'tests/intent/test_intent_clearing.py', 'restate': 'tests/intent/test_intent_restate.py'}
DESIGN = 'proposals/forge2-goal21-intent/DESIGN.md'
DIFF = 'proposals/forge2-goal21-intent/forge-airlock-check-intent.diff'
RECORD = 'proposals/forge2-goal21-intent/records/evidence.json'
DISPATCHER = 'bin/forge-airlock'
DISPATCHER_SHA256 = 'bd56d8b6afcd2d4a8a542c9789ebbb3fe6ef1e00a5c31d14e73957658a586891'  # the digest in the Goal 20 bundle
PATCHED_SHA256 = '6798fd70f3618aef748865f6f9ee5a2072fce9c6e4a9d6d8b590aa0118b27341'  # bin/forge-airlock with the diff applied
GOAL20_POLICY = 'examples/unbreakable_store/policies/refunds-v2.json'
DAFNY = ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'
SPECS, QUERIES = 'tests/intent/specs/', 'tests/intent/queries/'
# (pair, clean spec, planted spec, query file, the named queries that must be WARNINGs on the planted spec,
#  the named boundary: a table row that differs between clean and planted must name it)
PAIRS = [
    ('vip', SPECS + 'vip-clean.json', SPECS + 'vip-planted-swapped-flag.json', QUERIES + 'vip.json', ['VIP-1'],
     'the GOODWILL amount pins at 5000 with the vip fact'),
    ('shipping', SPECS + 'shipping-clean.json', SPECS + 'shipping-planted-coarse-cap.json', QUERIES + 'shipping.json', ['SHIP-1', 'SHIP-2'],
     'the SHIPPING rows with the shipping_paid fact (the cap)'),
    ('boundary', SPECS + 'boundary-clean.json', SPECS + 'boundary-planted-inclusive.json', QUERIES + 'boundary.json', ['EDGE-1'],
     'the GOODWILL amount pin 5000 (the cosign edge)'),
]
# The imported, unchanged code that the verdicts rest on is part of the subject (review finding F5).
IMPORTED = ['scripts/spec_clearing.py', 'src/airlock/py/diff_policy.py', 'src/airlock/py/policy_model.py', 'gate/common.py',
            'gate/backends/dafny.py', 'gate/expected-audit.md']
SUBJECT = sorted([CLEARING, RESTATE, SUITES['clearing'], SUITES['restate'], DESIGN, DIFF, 'scripts/exit_goal21_intent.py', GOAL20_POLICY] + IMPORTED)
SUBJECT_GLOBS = ['tests/intent/specs/*.json', 'tests/intent/queries/*.json']
TIMEOUT = 3600

# ------------------------------------------------------------------------------------------------------------- mutations
# Changed copies. Each entry: (name, file, text to find EXACTLY ONCE, replacement, check, named reason, what is removed).
#   check:  ('suite', 'clearing' | 'restate', case)  -> python3 -B tests/intent/test_intent_<x>.py --case <case>
#           ('intent', spec, queries or None)          -> python3 -B scripts/intent_clearing.py check-intent <spec>
#                                                         [--queries Q] --work <new folder>   (the TEXT report: its
#                                                         lines `UNDECIDED cell: ...`, `<query id>: <answer> |`,
#                                                         `seal: ...`, `LINK_BROKEN: ...`, `RESULT: ...` are the reasons)
#   named reason: (exit code or None, text or None). The copy is KILLED when the check gives that exit code (if given)
#           AND that text is in its stdout+stderr (if given) AND the outcome differs from the unchanged control. The
#           unchanged control must NOT already show the named reason (else the entry is an ERROR of the table).
# Each copy uses the SMALLEST check that kills it (one suite case or one check-intent run): each Dafny start costs ~2 s.
# The named reasons below were observed on the final engine (run of 2026-11-20, after the review repairs). A later
# change of the engine can move a text: the case then fails (text not found exactly once, or WRONG_REASON).
B_CLEAN = ('intent', SPECS + 'boundary-clean.json', QUERIES + 'boundary.json')
B_PLANTED = ('intent', SPECS + 'boundary-planted-inclusive.json', QUERIES + 'boundary.json')
S_CLEAN = ('intent', SPECS + 'shipping-clean.json', QUERIES + 'shipping.json')
MUTANTS = [
    # the proof bookkeeping: a member counts only when Dafny passed it
    ('C01_proved_always', CLEARING,
     "    return result['refused'] is None and result['audit_exit'] == 0 and result['members'].get(member) == 'Passed'\n",
     '    return True\n', B_CLEAN, (6, 'LINK_BROKEN: the generated model is vacuous'),
     'proved(): a lemma counts as PROVED only with an empty audit and the TRX outcome Passed'),
    ('C02_query_no_without_proof', CLEARING, "            if status['Query%03dD' % qi] and status['Query%03dU' % qi]:",
     '            if True:', B_PLANTED, (0, 'EDGE-1: NO |'), 'a query answer NO only after Dafny proved both probe lemmas'),
    ('C03_warning_not_flagged', CLEARING, "    if any(w.split(':')[0] in ('DEAD RULE', 'AMBIGUOUS', 'WARNING') for w in warnings):",
     '    if False:', B_PLANTED, (0, 'RESULT: CLEAN (exit 0)'), 'a verified WARNING makes the result WARNINGS (exit 4)'),
    ('C04_body_assume', CLEARING, "if fault == 'bodiless-lemma' else '{}'", "if fault == 'bodiless-lemma' else '{ assume false; }'", B_CLEAN, (6, 'LINK_BROKEN: Probe.dfy: refused=None audit_exit=2 '),
     'the lemma bodies are empty; an `assume` in a Dafny input fails the audit (exit 2): LINK_BROKEN'),
    # the generator (TRUSTED ASSUMPTION): a changed generated model must become visible
    ('C05_model_zero_amount', CLEARING, "'    if i.amount < 1 then v == RejectedZeroAmount',", "'    if i.amount < 0 then v == RejectedZeroAmount',",
     B_CLEAN, (5, 'UNDECIDED cell: ZERO_AMOUNT'), 'the ZERO_AMOUNT branch of the generated Allowed'),
    ('C06_model_total_cap', CLEARING, "'    else if i.amount > i.remaining then v == RejectedTotalCap',",
     "'    else if i.amount >= i.remaining then v == RejectedTotalCap',", B_CLEAN, (5, 'UNDECIDED cell: amount=remaining\n'),
     'the TOTAL_CAP branch of the generated Allowed'),
    ('C07_model_no_rule', CLEARING, "'    else v == RejectedNoRule', '  }', '',", "'    else v == RejectedReasonCap', '  }', '',",
     B_CLEAN, (5, 'UNDECIDED cell: reason OTHER'), 'the NO_RULE branch of the generated Allowed'),
    ('C08_model_reason_cap', CLEARING, "'    else if AnyCapped(i) then v == RejectedReasonCap',", "'    else if AnyCapped(i) then v == RejectedNoRule',",
     S_CLEAN, (5, 'UNDECIDED cell: REASON_CAP of rule 0'), 'the REASON_CAP branch of the generated Allowed'),
    ('C09_model_rule_bounds', CLEARING, "            bounds = self.faulty(n, rule['bounds'])\n", "            bounds = self.faulty(n, rule['bounds'])[:0]\n",
     B_CLEAN, (5, 'BUILTIN-1: WARNING |'), 'the amount and when atoms of each generated Rule predicate'),
    ('C10_format_a_max_amount', CLEARING, "+ ([['<=', r['max_amount']]] if", "+ ([['<', r['max_amount']]] if", S_CLEAN,
     (8, 'GENERATOR_MISMATCH'), 'the format-A mapping max_amount -> ["<=", n] (cross-check with policy_model.py)'),
    ('C11_cap_strict', CLEARING, "cap = ('cmp', ('total_after', 0), '<=', ('fact:' + r['cap_fact'], 0)) if r['cap_fact'] else None",
     "cap = ('cmp', ('total_after', 0), '<', ('fact:' + r['cap_fact'], 0)) if r['cap_fact'] else None", S_CLEAN,
     (8, 'GENERATOR_MISMATCH'), 'the cap atom total_after <= fact (cross-check with policy_model.py)'),
    ('C12_fact_guard', CLEARING, "            guards = ['%s.has%d' % (var, self.fx[f]) for f in atom_facts(atom)]\n", '            guards = []\n',
     S_CLEAN, (5, 'BUILTIN-CAP-1-MISSING: UNDECIDED |'),
     'fail closed: a missing fact never satisfies an atom (has guard); the honest evaluator gives no witness, so the answer is UNDECIDED'),
    # the seal
    ('C13_same_ignores_reason', CLEARING, "'    else !(j.amount < 1) && !(j.amount > j.remaining) && i.reason == j.reason' +",
     "'    else !(j.amount < 1) && !(j.amount > j.remaining)' +", B_CLEAN, (5, 'seal: SameCell NOT PROVED'),
     'the seal cell Same compares the reason'),
    ('C14_coverage_one_row', CLEARING, "        ensures = ' || '.join('Same(i, %s)' % m.literal(inp) for inp, _ in reps) or 'false'",
     "        ensures = ' || '.join('Same(i, %s)' % m.literal(inp) for inp, _ in reps[:1]) or 'false'", B_CLEAN,
     (5, 'seal: Coverage UNDECIDED'), 'the Coverage lemma names every representative row'),
    # the queries
    ('C15_query_verdict_ignored', CLEARING, "    return '(%s)' % ' || '.join('%s == %s' % (var, CONSTRUCTOR[v]) for v in q['verdicts'])",
     "    return 'true'", B_CLEAN, (5, 'EDGE-1: UNDECIDED |'),
     'the verdict list of a query (the witness lemma still names the verdict, so no witness verifies: UNDECIDED)'),
    ('C16_query_where_ignored', CLEARING,
     "                        ['requires %s ValidInput(i) && %s && %s' % (bind, allowed, m.cond_text(atoms)), 'ensures false'],",
     "                        ['requires %s ValidInput(i) && %s && %s' % (bind, allowed, m.cond_text([])), 'ensures false'],", B_CLEAN,
     (5, 'EDGE-1: UNDECIDED |'), 'the where atoms of a query in its probe lemma (a guess never becomes an answer)'),
    ('C17_vacuity_guard_zero_cell', CLEARING, "[('cmp', ('amount', 0), '<', (None, 1))])", "[('cmp', ('amount', 0), '<', (None, 0))])", B_CLEAN,
     (6, 'LINK_BROKEN: the generated model is vacuous'), 'the ZERO_AMOUNT cell amount < 1 (a PROVED EMPTY built-in is LINK_BROKEN)'),
    # guards named by the review (finding F6)
    ('C19_row_without_not_allowed', CLEARING, "        claims += [('' if v in want else '!') + 'Allowed(i, %s)' % CONSTRUCTOR[v] for v in VERDICTS]",
     "        claims += ['Allowed(i, %s)' % CONSTRUCTOR[v] for v in VERDICTS if v in want]", ('suite', 'clearing', 'faults'),
     (1, 'faults        FAIL'), 'a row lemma pins the EXACT verdict set (the !Allowed half)'),
    ('C20_row_shown_unverified', CLEARING, "                    if ok[lemma]:\n                        c['row'] =", "                    if True:\n                        c['row'] =",
     ('suite', 'clearing', 'undecided'), (1, 'undecided     FAIL'), 'a row is shown only when Dafny passed its lemma'),
    # the restater child (from intent_clearing.py)
    ('C18_restater_input_cut', CLEARING, 'input=ast_bytes,', 'input=ast_bytes[:-2],', B_CLEAN, (3, 'RESTATER_FAILED: the restater exited 2'),
     'the restater gets the whole canonical AST bytes; its failure is RESTATER_FAILED'),
    # scripts/intent_restate.py through its suite
    ('R01_interval_strict_less', RESTATE, '            high = min(high, n - 1)\n', '            high = min(high, n)\n', ('suite', 'restate', 'intervals'),
     (1, 'intervals        FAIL'), 'the closed form of `amount < n` (n - 1)'),
    ('R02_blind_arguments', RESTATE, '    if len(sys.argv) != 1:', '    if len(sys.argv) > 9:', ('suite', 'restate', 'blind'),
     (1, 'blind            FAIL'), 'the refusal of any argument (the child reads no argument)'),
    ('R03_cap_fact_words', RESTATE, "        words.append('the running total of this reason plus the amount is at most the fact %s '",
     "        words.append('the running total of this reason plus the amount is at most %s '", ('suite', 'restate', 'fixtures'),
     (1, 'fixtures         FAIL'), 'the cap bullet names the cap fact'),
]

# Changed copies that are not killed and are accepted, each with its reason (name -> why). Starts EMPTY.
NOT_KILLED_ALLOWED = {
}
MIN_KILLED_CLEARING = 15


class Failed(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Failed(message)


def child_env():
    """The environment of every child: this one, unchanged (FORGE_DAFNY_LOCK, when set, passes through)."""
    env = dict(os.environ)
    env['PYTHONDONTWRITEBYTECODE'] = '1'
    return env


def run(argv, cwd=ROOT, timeout=TIMEOUT, **options):
    """Starts a child. Returns (exit code, stdout, stderr). A timeout gives exit None and the text TIMEOUT."""
    try:
        done = subprocess.run([str(a) for a in argv], cwd=str(cwd), capture_output=True, text=True, errors='replace', env=child_env(),
                              timeout=timeout, **options)
        return done.returncode, done.stdout, done.stderr
    except subprocess.TimeoutExpired:
        return None, '', 'TIMEOUT after %d s' % timeout
    except OSError as error:
        return None, '', 'NOT RUN: cannot start: %s' % error


def scrub(text, *folders):
    """Path-free text: the attempt folders, the repository folder and the home folder are replaced."""
    for folder, mark in [(f, '<attempt>') for f in folders] + [(ROOT, '<root>'), (Path.home(), '<home>')]:
        text = text.replace(str(folder), mark)
    return text


def toolchain():
    pins = read_json(ROOT / pin_file('dafny'))
    z3 = ROOT / pins['z3']['path']
    seen = {'python': platform.python_version(), 'machine': platform.system() + ' ' + platform.machine()}
    for path in (DAFNY, z3):
        if not path.is_file():
            raise RuntimeError('TOOLCHAIN_ERROR: %s is missing' % path.relative_to(ROOT).as_posix())
    seen['dafny_executable_sha256'] = digest(DAFNY.read_bytes())
    seen['z3_executable_sha256'] = digest(z3.read_bytes())
    code, out, err = run([DAFNY, '--version'], timeout=300)
    seen['dafny_version_exit'] = code
    seen['dafny'] = out.strip()
    want = {'python': pins['python']['version'], 'machine': 'Darwin arm64', 'dafny_executable_sha256': pins['dafny']['executable_sha256'],
            'z3_executable_sha256': pins['z3']['executable_sha256'], 'dafny_version_exit': 0, 'dafny': pins['dafny']['version_output']}
    if seen != want:
        raise RuntimeError('TOOLCHAIN_ERROR: observed %r, pinned %r' % (seen, want))
    return dict(seen, z3=pins['z3']['version_output'], z3_path=pins['z3']['path'], dafny_path='.toolchain/dafny-4.11.0/dafny/dafny')


def subject_files():
    names = list(SUBJECT)
    for pattern in SUBJECT_GLOBS:
        names += [p.relative_to(ROOT).as_posix() for p in ROOT.glob(pattern)]
    return sorted(set(names))


def snapshot():
    """name -> SHA-256, or 'MISSING' (a missing subject file is recorded, never skipped)."""
    return {name: digest((ROOT / name).read_bytes()) if (ROOT / name).is_file() else 'MISSING' for name in subject_files()}


# ------------------------------------------------------------------------------------------------------------- suite
# No ':' in a case name: the line `RESULT: PASS` is not a case (review finding F10).
CASE_LINE = [re.compile(r'^(PASS|FAIL|NOT RUN)\s+([A-Za-z0-9_./-]+)'), re.compile(r'^([A-Za-z0-9_./-]+)\s+(PASS|FAIL|NOT RUN)\b')]
TIME = re.compile(r'\s*\b\d+(?:\.\d+)?\s*(?:s|ms)\b')


def parse_cases(text):
    """{case: status} from the case lines of a suite. A case printed twice is an error of the suite."""
    cases = {}
    for line in text.splitlines():
        for number, pattern in enumerate(CASE_LINE):
            m = pattern.match(line.strip())
            if m:
                status, name = (m.group(1), m.group(2)) if number == 0 else (m.group(2), m.group(1))
                require(name not in cases, 'SUITE: case %s printed twice' % name)
                cases[name] = status
                break
    return cases


def suite_case(work):
    work.mkdir(parents=True)
    out, failures = {}, []
    for kind in ('clearing', 'restate'):
        path = SUITES[kind]
        if not (ROOT / path).is_file():
            out[kind] = {'argv': 'python3 -B ' + path, 'exit_code': 'NOT RUN', 'why': 'the file is missing'}
            failures.append('%s: NOT RUN (the file is missing)' % path)
            continue
        code, stdout, stderr = run([sys.executable, '-B', path])
        text = stdout + stderr
        (work / (kind + '.log')).write_text(text)
        cases = parse_cases(text)
        counts = {s: sum(1 for v in cases.values() if v == s) for s in ('PASS', 'FAIL', 'NOT RUN')}
        out[kind] = {'argv': 'python3 -B ' + path, 'exit_code': code if code is not None else 'NOT RUN', 'cases': dict(sorted(cases.items())),
                     'counts': counts, 'total_lines': [TIME.sub('', l).strip() for l in text.splitlines() if re.match(r'^\s*(total|RESULT)\b', l, re.I)]}
        if code != 0 or not cases or counts['FAIL'] or counts['NOT RUN']:
            failures.append('%s: exit %r, %d cases parsed, %d FAIL, %d NOT RUN\n%s' % (path, code, len(cases), counts['FAIL'], counts['NOT RUN'], text[-2000:]))
    out['failures'] = [f.split('\n')[0] for f in failures]
    require(not failures, 'SUITE: ' + '\n'.join(failures))
    return out


# ------------------------------------------------------------------------------------------------------------- planted
def check_intent(spec, queries, work, root=ROOT, as_json=True):
    """One check-intent run (--json by default). Returns (exit code, report or None, stdout, stderr). The work folder
    is new and lies under <root>/build (the engine refuses any other)."""
    argv = [sys.executable, '-B', root / CLEARING, 'check-intent', spec] + (['--queries', queries] if queries else []) + (
        ['--json'] if as_json else []) + ['--work', work]
    code, stdout, stderr = run(argv, cwd=root)
    try:
        report = json.loads(stdout)
    except ValueError:
        report = None
    return code, report, stdout, stderr


def queries_of(report):
    """{query id: answer object} of a report. Built-in queries are kept under their own ids."""
    out = {}
    for q in (report or {}).get('queries') or []:
        if isinstance(q, dict) and 'id' in q:
            out[q['id']] = q
    return out


def answer(q):
    return q.get('answer') or q.get('result') or q.get('status')


def witness_verified(q):
    """A WARNING carries a witness that Dafny verified. The engine sets `witness` only after the pinned Dafny passed
    the witness lemma (DESIGN.md section 7); this script checks that the object is there and complete. Whether the
    engine sets it only then is what the changed copies of case mutations test (it is not proved)."""
    w = q.get('witness')
    return (q.get('answer') == 'WARNING' and isinstance(w, dict) and isinstance(w.get('input'), str) and bool(w.get('input'))
            and isinstance(w.get('verdicts'), list) and bool(w.get('verdicts')) and w.get('source') in ('solver-counterexample', 'python-candidate'))


def seal_proved(report):
    seal = ((report or {}).get('table') or {}).get('seal')
    return isinstance(seal, dict) and seal.get('same_cell') == 'PROVED' and seal.get('coverage') == 'PROVED'


def rows_of(report):
    return ((report or {}).get('table') or {}).get('rows') or []


def bullets_of(report):
    return ((report or {}).get('restatement') or {}).get('bullets')


def row_key(row):
    return canonical(row)


def boundary_rows(pair, rows):
    """The rows at the named boundary of the pair (by its plain fields; the row text is canonical JSON)."""
    out = []
    for row in rows:
        facts = row.get('facts') if isinstance(row.get('facts'), dict) else {}
        if pair == 'vip':
            hit = row.get('reason') == 'GOODWILL' and row.get('amount') in (5000, 5001) and facts.get('vip') is not None
        elif pair == 'shipping':
            hit = row.get('reason') == 'SHIPPING' and 'shipping_paid' in facts
        else:
            hit = row.get('reason') == 'GOODWILL' and row.get('amount') in (4999, 5000, 5001)
        if hit:
            out.append(row)
    return out


def planted_case(work):
    work.mkdir(parents=True)
    out, failures, number = {'pairs': {}}, [], [0]
    missing = [p for p in [CLEARING, RESTATE] if not (ROOT / p).is_file()]
    if missing:
        out['not_run'] = ['check-intent: %s missing' % ', '.join(missing)]
        require(False, 'PLANTED: NOT RUN: %s missing' % ', '.join(missing))

    def one(label, spec, queries):
        number[0] += 1
        folder = work / ('run-%02d-%s' % (number[0], label))
        code, report, stdout, stderr = check_intent(spec, queries, folder)
        (work / ('%s.stdout' % label)).write_text(stdout)
        (work / ('%s.stderr' % label)).write_text(stderr)
        row = {'spec': spec, 'queries': queries, 'argv': 'python3 scripts/intent_clearing.py check-intent %s%s --json --work <new folder>' % (
               spec, ' --queries ' + queries if queries else ''), 'exit_code': code if code is not None else 'NOT RUN',
               'report_sha256': digest(stdout.encode()) if report is not None else None,
               'result': (report or {}).get('result'), 'json_exit': (report or {}).get('exit'), 'end_to_end': (report or {}).get('end_to_end')}
        return code, report, row, stdout + stderr

    for pair, clean, planted, queries, named, boundary in PAIRS:
        c_code, c_rep, c_row, c_text = one(pair + '-clean', clean, queries)
        p_code, p_rep, p_row, p_text = one(pair + '-planted', planted, queries)
        problems = []
        cq, pq = queries_of(c_rep), queries_of(p_rep)
        if c_code != 0 or c_rep is None or c_rep.get('result') != 'CLEAN' or c_rep.get('exit') != 0:
            problems.append('clean: exit %r, result %r' % (c_code, (c_rep or {}).get('result')))
        if not cq or any(answer(q) != 'NO' for q in cq.values()):
            problems.append('clean: not every query answer is NO: %r' % {k: answer(v) for k, v in cq.items()})
        if not seal_proved(c_rep):
            problems.append('clean: the seal is not PROVED: %r' % (((c_rep or {}).get('table') or {}).get('seal'),))
        if (c_rep or {}).get('end_to_end') is not False or (p_rep or {}).get('end_to_end') is not False:
            problems.append('end_to_end is not false in a report')
        if p_code != 4 or p_rep is None or p_rep.get('result') != 'WARNINGS' or p_rep.get('exit') != 4:
            problems.append('planted: exit %r, result %r' % (p_code, (p_rep or {}).get('result')))
        named_rows = {}
        for qid in named:
            q = pq.get(qid)
            ok = q is not None and answer(q) == 'WARNING' and witness_verified(q)
            named_rows[qid] = {'answer': answer(q) if q else 'ABSENT', 'witness_verified': bool(q and witness_verified(q)),
                               'witness': q.get('witness') if q else None}
            if not ok:
                problems.append('planted: query %s is not a WARNING with a Dafny-verified witness: %r' % (qid, q))
        c_rows, p_rows = rows_of(c_rep), rows_of(p_rep)
        c_keys, p_keys = {row_key(r) for r in c_rows}, {row_key(r) for r in p_rows}
        changed = [r for r in p_rows if row_key(r) not in c_keys] + [r for r in c_rows if row_key(r) not in p_keys]
        at_boundary = boundary_rows(pair, changed)
        if not c_rows or not p_rows or not at_boundary:
            problems.append('table: no row differs at the named boundary (%s): %d clean rows, %d planted rows, %d differ' % (
                boundary, len(c_rows), len(p_rows), len(changed)))
        c_b, p_b = bullets_of(c_rep), bullets_of(p_rep)
        if not isinstance(c_b, list) or not isinstance(p_b, list) or not c_b or c_b == p_b:
            problems.append('restatement: the bullets of the pair do not differ (or are missing)')
        out['pairs'][pair] = {'clean': c_row, 'planted': p_row, 'named_queries': named_rows, 'boundary': boundary,
                              'rows_clean': len(c_rows), 'rows_planted': len(p_rows), 'rows_differing': len(changed),
                              'rows_differing_at_boundary': len(at_boundary),
                              'bullets_clean_sha256': digest(canonical(c_b)) if c_b is not None else None,
                              'bullets_planted_sha256': digest(canonical(p_b)) if p_b is not None else None,
                              'bullets_differ': isinstance(c_b, list) and isinstance(p_b, list) and c_b != p_b,
                              'problems': problems}
        failures += ['%s: %s' % (pair, p) for p in problems]
        print('  %-9s clean exit %r %s; planted exit %r %s; %d rows differ at the boundary; %s' % (
            pair, c_code, c_row['result'], p_code, p_row['result'], len(at_boundary), 'OK' if not problems else 'PROBLEMS'), flush=True)
    g_code, g_rep, g_row, g_text = one('goal20-refunds-v2', GOAL20_POLICY, None)
    out['goal20_policy'] = g_row
    if g_code != 0 or (g_rep or {}).get('result') != 'CLEAN':
        failures.append('goal20 policy %s: exit %r, result %r\n%s' % (GOAL20_POLICY, g_code, (g_rep or {}).get('result'), g_text[-1500:]))
    print('  %-9s exit %r %s' % ('refunds-v2', g_code, g_row['result']), flush=True)
    out['failures'] = [f.split('\n')[0] for f in failures]
    require(not failures, 'PLANTED: ' + '\n'.join(failures))
    return out


# ------------------------------------------------------------------------------------------------------------- mutations
def build_tree(folder, changed=None, text=None):
    """A tree in which a changed copy runs in place of the original: real folders scripts/ (copies) and
    tests/intent/ (copies of the .py files, links to the fixture folders); links to every other top-level entry and
    every other entry of tests/; an empty build/. ROOT of a copied script resolves to this tree."""
    folder.mkdir(parents=True)
    for entry in sorted(ROOT.iterdir()):
        if entry.name in ('scripts', 'tests', 'build', '.git'):
            continue
        (folder / entry.name).symlink_to(entry)
    shutil.copytree(ROOT / 'scripts', folder / 'scripts', ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    (folder / 'tests').mkdir()
    for entry in sorted((ROOT / 'tests').iterdir()):
        if entry.name != 'intent':
            (folder / 'tests' / entry.name).symlink_to(entry)
    (folder / 'tests/intent').mkdir()
    for entry in sorted((ROOT / 'tests/intent').iterdir()):
        if entry.is_file() and entry.suffix == '.py':
            shutil.copyfile(entry, folder / 'tests/intent' / entry.name)
        elif entry.name != '__pycache__':
            (folder / 'tests/intent' / entry.name).symlink_to(entry)
    (folder / 'build').mkdir()
    if changed is not None:
        (folder / changed).write_text(text)
    return folder


def run_check(check, tree, work):
    """Runs one check of the table in a tree. Returns (exit code, text)."""
    if check[0] == 'suite':
        code, stdout, stderr = run([sys.executable, '-B', tree / SUITES[check[1]], '--case', check[2]], cwd=tree)
        return code, stdout + stderr
    _, spec, queries = check
    code, _, stdout, stderr = check_intent(spec, queries, tree / 'build/intent/check', root=tree, as_json=False)  # --work must lie under <tree>/build
    return code, stdout + stderr


def reason_holds(reason, code, text):
    want_exit, want_text = reason
    return (want_exit is None or code == want_exit) and (want_text is None or want_text in text)


def check_label(check):
    return check[0] + ':' + ':'.join(str(c) for c in check[1:] if c)


def validate_table():
    names = [m[0] for m in MUTANTS]
    require(len(set(names)) == len(names), 'MUTANTS: a name is used twice')
    require(set(NOT_KILLED_ALLOWED) <= set(names), 'MUTANTS: NOT_KILLED_ALLOWED names a copy that is not in the table')
    for name, file, old, new, check, reason, removed in MUTANTS:
        require(file in (CLEARING, RESTATE), 'MUTANTS: %s changes %s, not one of the two scripts' % (name, file))
        require((ROOT / file).is_file(), 'MUTANTS: NOT RUN: %s is missing' % file)
        count = (ROOT / file).read_text().count(old)
        require(count == 1, 'MUTANTS: the text of %s is found %d times in %s, expected 1' % (name, count, file))
        require(old != new and reason != (None, None), 'MUTANTS: %s changes nothing or has no named reason' % name)
        require(check[0] in ('suite', 'intent') and (check[0] != 'suite' or check[1] in SUITES), 'MUTANTS: %s has an unknown check %r' % (name, check))


def mutations_case(work, only=()):
    """only: names of copies to run (a PARTIAL run: the minimum is not checked; it is never part of a bundle)."""
    work.mkdir(parents=True)
    validate_table()
    unknown = sorted(set(only) - {m[0] for m in MUTANTS})
    require(not unknown, 'MUTANTS: no such copy: %r' % unknown)
    table = [m for m in MUTANTS if not only or m[0] in only]
    clearing_entries = sum(1 for m in MUTANTS if m[1] == CLEARING)
    # The unchanged controls: each distinct check once, in an unchanged tree. The named reason must NOT hold there.
    controls = {}
    for check in sorted({m[4] for m in table}, key=check_label):
        folder = work / ('control-%02d' % (len(controls) + 1))
        tree = build_tree(folder / 'tree')
        code, text = run_check(check, tree, folder)
        (work / ('control-%02d.log' % (len(controls) + 1))).write_text(scrub(text, folder))
        good = code == 0 if check[0] == 'suite' else code in (0, 4)
        controls[check] = {'check': check_label(check), 'exit_code': code if code is not None else 'NOT RUN', 'passes': good}
        require(good, 'MUTANTS: the unchanged control %s gives exit %r\n%s' % (check_label(check), code, text[-1500:]))
        controls[check]['text'] = text
        shutil.rmtree(folder)
    for name, file, old, new, check, reason, removed in table:
        require(not reason_holds(reason, controls[check]['exit_code'], scrub(controls[check]['text'])),
                'MUTANTS: ERROR of the table: the named reason of %s already holds on the unchanged control' % name)
    rows, details = [], {}
    for name, file, old, new, check, reason, removed in table:
        text = (ROOT / file).read_text().replace(old, new)
        folder = work / name
        tree = build_tree(folder / 'tree', file, text)
        start = time.monotonic()
        code, printed = run_check(check, tree, folder)
        printed = scrub(printed, folder)
        (work / 'logs').mkdir(exist_ok=True)
        (work / 'logs' / (name + '.log')).write_text(printed)
        control = controls[check]
        differs = code != control['exit_code'] or printed != scrub(control['text'])
        if check[0] == 'suite':
            differs = code != 0
        if differs and reason_holds(reason, code, printed):
            verdict = 'KILLED'
        elif differs:
            verdict = 'WRONG_REASON'
        else:
            verdict = 'NOT_KILLED'
        rows.append({'name': name, 'file': file, 'removed': removed, 'check': check_label(check), 'named_reason': {'exit': reason[0], 'text': reason[1]},
                     'exit_code': code if code is not None else 'NOT RUN', 'result': verdict,
                     'allowed_not_killed': NOT_KILLED_ALLOWED.get(name) if verdict != 'KILLED' else None})
        details[name] = {'wall_s': round(time.monotonic() - start, 1), 'tail': printed[-400:]}
        print('  %-40s %-34s exit %-4r %s' % (name, check_label(check)[:34], code, verdict), flush=True)
        shutil.rmtree(folder)
    killed_clearing = sum(1 for r in rows if r['result'] == 'KILLED' and r['file'] == CLEARING)
    bad = [r['name'] + ' ' + r['result'] for r in rows if r['result'] != 'KILLED' and (r['result'] == 'WRONG_REASON' or r['name'] not in NOT_KILLED_ALLOWED)]
    out = {'changed_copies': len(rows), 'killed': sum(r['result'] == 'KILLED' for r in rows), 'killed_intent_clearing': killed_clearing,
           'entries_intent_clearing': clearing_entries, 'entries_intent_restate': len(rows) - clearing_entries,
           'wrong_reason': sorted(r['name'] for r in rows if r['result'] == 'WRONG_REASON'),
           'not_killed': sorted(r['name'] for r in rows if r['result'] == 'NOT_KILLED'),
           'not_killed_allowed': dict(sorted(NOT_KILLED_ALLOWED.items())), 'minimum_killed_intent_clearing': MIN_KILLED_CLEARING,
           'controls': sorted(({k: v for k, v in c.items() if k != 'text'} for c in controls.values()), key=lambda c: c['check']),
           'table': rows}
    require(not bad, 'MUTANTS: not killed for the named reason: %s' % ', '.join(bad))
    if only:
        out['partial'] = sorted(only)
        return out, details
    require(killed_clearing >= MIN_KILLED_CLEARING, 'MUTANTS: %d copies of %s killed for their named reason; at least %d are needed%s' % (
        killed_clearing, CLEARING, MIN_KILLED_CLEARING, ' (the table is not complete: TODO-ORCHESTRATOR)' if clearing_entries < MIN_KILLED_CLEARING else ''))
    return out, details


# ------------------------------------------------------------------------------------------------------------- dispatcher
def diff_targets(text):
    return re.findall(r'^diff --git a/(\S+) b/(\S+)$', text, re.M)


def diff_preimage(text):
    m = re.search(r'^index ([0-9a-f]{40})\.\.([0-9a-f]{40})', text, re.M)
    return m.group(1) if m else None


def git_blob(data):
    return hashlib.sha1(b'blob %d\0' % len(data) + data).hexdigest()


def dispatcher_case(work):
    work.mkdir(parents=True)
    out = {}
    data = (ROOT / DISPATCHER).read_bytes()
    out['tracked_sha256'] = digest(data)
    require(out['tracked_sha256'] == DISPATCHER_SHA256, 'DISPATCHER: the tracked %s is not the Goal 20 file %s (it is %s)' % (
        DISPATCHER, DISPATCHER_SHA256, out['tracked_sha256']))
    require((ROOT / DIFF).is_file(), 'DISPATCHER: NOT RUN: %s is missing' % DIFF)
    diff = (ROOT / DIFF).read_text()
    targets = diff_targets(diff)
    out['diff_sha256'] = digest(diff.encode())
    out['diff_targets'] = sorted({t for pair in targets for t in pair})
    out['diff_preimage_blob'] = diff_preimage(diff)
    out['tracked_blob'] = git_blob(data)
    require(targets == [(DISPATCHER, DISPATCHER)], 'DISPATCHER: the diff does not change exactly %s: %r' % (DISPATCHER, targets))
    require(out['diff_preimage_blob'] == out['tracked_blob'], 'DISPATCHER: the preimage of the diff is not the tracked file')
    added = [l[1:] for l in diff.splitlines() if l.startswith('+') and not l.startswith('+++')]
    removed = [l[1:] for l in diff.splitlines() if l.startswith('-') and not l.startswith('---')]
    out['lines_added'], out['lines_removed'] = added, removed
    require(removed == [] and added == ['  forge-airlock check-intent <spec.json> [intent_clearing.py options]',
                                        "    if sub == 'check-intent':",
                                        "        return cmd_python('scripts/intent_clearing.py', ['check-intent'] + rest)"],
            'DISPATCHER: the diff is not the one usage line and the one dispatch branch: +%r -%r' % (added, removed))
    code, stdout, stderr = run(['git', 'apply', '--check', '-v', DIFF], cwd=ROOT, timeout=120)
    out['git_apply_check'] = {'argv': 'git apply --check -v ' + DIFF, 'exit_code': code if code is not None else 'NOT RUN'}
    require(code == 0, 'DISPATCHER: git apply --check gave exit %r: %s' % (code, (stdout + stderr)[-800:]))
    # The copies: <attempt>/root (patched) and <attempt>/unpatched; links to every other top-level entry.
    roots = {}
    for label in ('root', 'unpatched'):
        tree = work / label
        tree.mkdir()
        for entry in sorted(ROOT.iterdir()):
            if entry.name not in ('bin', 'build', '.git'):
                (tree / entry.name).symlink_to(entry)
        (tree / 'bin').mkdir()
        shutil.copy2(ROOT / DISPATCHER, tree / DISPATCHER)
        roots[label] = tree
    code, stdout, stderr = run(['patch', '-p1', '--forward', '--batch', '-d', roots['root'], '-i', ROOT / DIFF], timeout=120)
    patched = roots['root'] / DISPATCHER
    out['patch'] = {'argv': 'patch -p1 --forward --batch -d <attempt>/root -i ' + DIFF, 'exit_code': code if code is not None else 'NOT RUN',
                    'patched_sha256': digest(patched.read_bytes()), 'executable': os.access(patched, os.X_OK),
                    'stray_files': sorted(p.name for p in (roots['root'] / 'bin').iterdir() if p.name != 'forge-airlock')}
    require(code == 0 and out['patch']['patched_sha256'] == PATCHED_SHA256 and out['patch']['executable'] and out['patch']['stray_files'] == [],
            'DISPATCHER: patch: %r\n%s' % (out['patch'], (stdout + stderr)[-800:]))
    require((roots['root'] / CLEARING).is_file(), 'DISPATCHER: NOT RUN: %s does not resolve in the patched tree' % CLEARING)
    runs = []
    for label, tree, spec, want in (('patched clean', roots['root'], SPECS + 'boundary-clean.json', 0),
                                    ('patched planted', roots['root'], SPECS + 'boundary-planted-inclusive.json', 4),
                                    ('unpatched (control)', roots['unpatched'], SPECS + 'boundary-clean.json', 2)):
        argv = [tree / DISPATCHER, 'check-intent', spec, '--queries', QUERIES + 'boundary.json']
        code, stdout, stderr = run(argv, cwd=ROOT)
        text = scrub(stdout + stderr, work)
        (work / (label.split(' ')[0] + '-' + label.split(' ')[1] + '.log')).write_text(text)
        result_lines = [l.strip() for l in stdout.splitlines() if l.strip().startswith('RESULT')]
        row = {'run': label, 'argv': '<attempt>/%s/bin/forge-airlock check-intent %s --queries %sboundary.json' % (tree.name, spec, QUERIES),
               'exit_code': code if code is not None else 'NOT RUN', 'expected_exit': want, 'result_lines': result_lines}
        runs.append(row)
        print('  %-20s exit %r %s' % (label, code, result_lines[:1]), flush=True)
        if want == 2:
            require(code == 2 and "unknown subcommand 'check-intent'" in stderr, 'DISPATCHER: the unpatched copy did not refuse check-intent: exit %r %s' % (
                code, text[-600:]))
        else:
            require(code == want and len(result_lines) >= 1, 'DISPATCHER: %s: exit %r (want %d), RESULT lines %r\n%s' % (label, code, want, result_lines, text[-1500:]))
    out['runs'] = runs
    out['label'] = 'TESTED (the diff is UNAPPLIED in the repository; bin/forge-airlock is unchanged)'
    return out


# ------------------------------------------------------------------------------------------------------------- evidence
def bundle_of(work):
    before = snapshot()
    tools = toolchain()
    print('  suite', flush=True)
    suites = suite_case(work / 'suite')
    print('  planted', flush=True)
    planted = planted_case(work / 'planted')
    print('  mutations', flush=True)
    changed, details = mutations_case(work / 'mutations')
    print('  dispatcher', flush=True)
    dispatcher = dispatcher_case(work / 'dispatcher')
    after = snapshot()
    require(after == before, 'INPUT_CHANGED: a subject file changed during the checks')
    require('MISSING' not in before.values(), 'SUBJECT: a subject file is missing: %r' % sorted(k for k, v in before.items() if v == 'MISSING'))
    bundle = {
        'record': 'forge-intent-goal21', 'format_version': 1,
        'gate_accepted': False, 'end_to_end': False, 'm1': 'OPEN', 'kind': 'PROVED (generated model) + TESTED + TRUSTED ASSUMPTION; a RECORD, not gate evidence',
        'producer': 'scripts/exit_goal21_intent.py (a scenario script; not the gate)',
        'note': 'A record of real tool runs on one machine. No time, no absolute path, no process id and no temporary name is in this record.',
        'subject': [{'path': name, 'sha256': before[name]} for name in sorted(before)],
        'toolchain': tools,
        'suite': suites, 'planted': planted, 'mutations': changed, 'dispatcher': dispatcher,
        'results_by_label': {
            'PROVED (for the generated model only)': [
                'each verified table row (its exact verdict set), each PROVED EMPTY cell, the seal (SameCell and Coverage), each NO answer and '
                'each WARNING witness in case planted (pinned Dafny 4.11.0, gate options, empty audit)'],
            'TESTED': [
                'the two suites (case suite), the changed copies (case mutations), the restatement bullets, the Python evaluator, the text '
                'output, the dispatcher diff on a patched copy (case dispatcher): finite runs on one machine'],
            'TRUSTED ASSUMPTION': [
                'the generator (JSON to Dafny) of scripts/intent_clearing.py', 'Dafny 4.11.0 and its bundled Z3 4.12.1 (pinned digests in toolchain)',
                'the loader (policy_model.parse_json / load_policy and the intent-spec-v1 loader)', 'Python %s' % tools['python']],
        },
        'not_claimed': [
            'that any specification is the intent of its author (CLEAN says only that the questions asked have the answer NO)',
            'anything about the Rust engine (no --engine run in this record)',
            'that the restater is correct (it is tested, not proved)',
            'that bin/forge-airlock has a check-intent subcommand: the diff is UNAPPLIED; the tracked file is the Goal 20 file',
            'anything end to end; anything about M1 (OPEN)'],
        'reproduce_cmd': 'FORGE_DAFNY_LOCK=<lock> python3 scripts/exit_goal21_intent.py --case evidence',
    }
    return bundle, {'mutation_details': details}


def attempt_folder(case):
    base = ROOT / BUILD / case
    base.mkdir(parents=True, exist_ok=True)
    number = 1 + max([int(p.name.split('-')[1]) for p in base.glob('attempt-*')] or [0])
    return base / ('attempt-%04d' % number)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--case', required=True, choices=('suite', 'planted', 'mutations', 'dispatcher', 'evidence'))
    parser.add_argument('--write-record', action='store_true', help='case evidence: write the bundle to ' + RECORD)
    parser.add_argument('--mutant', action='append', default=[], help='case mutations: run only this copy (PARTIAL; repeatable)')
    args = parser.parse_args()
    if args.write_record and args.case != 'evidence':
        parser.error('--write-record is only for --case evidence')
    if args.mutant and args.case != 'mutations':
        parser.error('--mutant is only for --case mutations')
    work = attempt_folder(args.case)
    name = work.relative_to(ROOT).as_posix()
    print('GOAL21 ' + args.case + ': ' + name, flush=True)
    start = time.monotonic()
    try:
        if args.case != 'evidence':
            toolchain()  # case evidence checks it inside each run and records it
        if args.case == 'suite':
            result = suite_case(work)
            for kind in ('clearing', 'restate'):
                print('  %-8s exit %s, counts %s' % (kind, result[kind]['exit_code'], json.dumps(result[kind].get('counts'), sort_keys=True)))
        elif args.case == 'planted':
            result = planted_case(work)
            (work / 'result.json').write_bytes(canonical(result))
        elif args.case == 'mutations':
            result, details = mutations_case(work, args.mutant)
            (work / 'result.json').write_bytes(canonical(result))
            (work / 'measurements.json').write_text(json.dumps({'mutation_details': details, 'wall_s': round(time.monotonic() - start, 1)}, indent=2, sort_keys=True) + '\n')
            print('  killed %d of %d (intent_clearing.py: %d); wrong reason: %s; not killed: %s' % (
                result['killed'], result['changed_copies'], result['killed_intent_clearing'], result['wrong_reason'] or 'none', result['not_killed'] or 'none'))
        elif args.case == 'dispatcher':
            result = dispatcher_case(work)
            (work / 'result.json').write_bytes(canonical(result))
        else:
            work.mkdir(parents=True)
            bundles = []
            for number in (1, 2):
                print(' run ' + str(number), flush=True)
                t0 = time.monotonic()
                bundle, measured = bundle_of(work / ('run-%d' % number))
                measured['wall_s'] = round(time.monotonic() - t0, 1)
                bundles.append(canonical(bundle))
                (work / ('run-%d' % number) / 'evidence.json').write_bytes(bundles[-1])
                (work / ('run-%d' % number) / 'measurements.json').write_text(json.dumps(measured, indent=2, sort_keys=True) + '\n')
                print('  run %d bundle sha256 %s' % (number, digest(bundles[-1])), flush=True)
            require(bundles[0] == bundles[1], 'evidence: the two bundles differ')
            (work / 'evidence.json').write_bytes(bundles[0])
            print('  bundle: ' + name + '/evidence.json sha256 ' + digest(bundles[0]) + ' (two runs, byte-identical)')
            record = ROOT / RECORD
            if args.write_record:
                record.parent.mkdir(parents=True, exist_ok=True)
                record.write_bytes(bundles[0])
                print('  tracked record: WRITTEN ' + RECORD)
            elif not record.is_file():
                print('  tracked record: ABSENT (' + RECORD + ')')
                require(False, 'evidence: the tracked record is absent (review finding F4); --write-record writes it')
            else:
                same = record.read_bytes() == bundles[0]
                print('  tracked record: %s %s sha256 %s' % ('EQUAL' if same else 'DIFFERS', RECORD, digest(record.read_bytes())))
                require(same, 'evidence: the bundle differs from the tracked record ' + RECORD)
    except Failed as error:
        print('GOAL21 ' + args.case + ': FAILED; end_to_end=false; wall %.0f s\n' % (time.monotonic() - start) + str(error))
        return 1
    except RuntimeError as error:
        print('GOAL21 ' + args.case + ': ' + str(error) + '; end_to_end=false')
        return 2
    print('GOAL21 ' + args.case + ': PASSED; end_to_end=false; wall %.0f s' % (time.monotonic() - start))
    return 0


if __name__ == '__main__':
    sys.exit(main())
