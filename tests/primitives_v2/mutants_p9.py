#!/usr/bin/env python3
"""Controls for primitive 9: changed copies that the P9 tests must kill. FINITE TEST. It shows that the named cases CAN
fail; it proves nothing.

Usage: python3 tests/primitives_v2/mutants_p9.py --dafny-py DIR --airlock-engine PATH [--only NAME]... [--work DIR]
       [--rustc PATH]

Two families, each entry ONE exact-once text replacement:
  part A (farkas.rs): a copy of the engine sources (src/primitives_v2/*.rs at HEAD for every file but farkas.rs, which
          is taken from the tree; plus src/airlock/json.rs and pin.rs) with the change, built with the production
          command, then ONE case of tests/primitives_v2/test_farkas.py (--dafny-py: the Dafny-compiled FarkasCert).
  part B (policy_to_dfy.py): a changed copy of the generator, then ONE case of tests/primitives_v2/test_policy_to_dfy.py
          with --generator <copy> (cases `verify` and `differential` run the pinned Dafny, one process at a time).
Required for a kill: suite exit 1, a `FAIL <case>` line that is not a suite error, and the named text in it. First the
unchanged sources pass every named case (the control). A copy that does not build is an ERROR of the list. Exit 0:
the control passed and every copy was killed for its named reason; 1 otherwise. A copy that nothing kills is printed
as NOT KILLED, never hidden.
"""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'src/primitives_v2'
GEN = ROOT / 'src/primitives_v2/py/policy_to_dfy.py'
FARKAS_SUITE = ROOT / 'tests/primitives_v2/test_farkas.py'
POLICY_SUITE = ROOT / 'tests/primitives_v2/test_policy_to_dfy.py'
RUSTC = ['--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3']
POL = ROOT / 'domains/compiled_policies/policies'

# (name, family, file, exact text, replacement, case, text the FAIL line must hold, what the copy removes, policy)
MUTANTS = [
    # ---- part A: farkas.rs -----------------------------------------------------------------------------------------
    ('F1_y_nonneg_unchecked', 'A', 'farkas.rs', '    if let Some(i) = y.iter().position(|v| *v < 0) { return Outcome::YNegative(i) }\n', '',
     'differential', 'Dafny Accepts=false but engine INFEASIBILITY_PROVED', 'the clause y >= 0', None),
    ('F2_first_column_only', 'A', 'farkas.rs', '    for j in 0..n {', '    for j in 0..n.min(1) {',
     'differential', 'Dafny Accepts=false but engine INFEASIBILITY_PROVED', 'y^T A <= 0 in EVERY column', None),
    ('F3_ytb_ge_zero', 'A', 'farkas.rs', '        Some(s) if s > 0 => Outcome::Proved,', '        Some(s) if s >= 0 => Outcome::Proved,',
     'witnesses', 'expected CERT_REJECTED', 'the strict y^T b > 0', None),
    ('F4_overflow_unchecked', 'A', 'farkas.rs', '        s = s.checked_add((p as i128).checked_mul(q as i128)?)?;',
     '        s = s.wrapping_add((p as i128).wrapping_mul(q as i128));', 'overflow', 'expected OVERFLOW', 'checked i128 arithmetic', None),
    ('F5_row_length_unchecked', 'A', 'farkas.rs',
     '    if let Some(i) = a.iter().position(|r| r.len() != n) { return Err(Bad::Shape("ROW_LEN", vec![("row", i.to_string())])) }\n', '',
     'grammar', 'expected SHAPE why=ROW_LEN', 'the equal length of every row', None),
    ('F6_b_length_unchecked', 'A', 'farkas.rs', '    if b.len() != m { return Err(Bad::Shape("B_LEN", vec![])) }\n', '',
     'grammar', 'expected SHAPE why=B_LEN', '|b| = number of rows', None),
    ('F7_digest_not_bound_to_b', 'A', 'farkas.rs', '        let sys = system_digest(&a, &b);', '        let sys = system_digest(&a, &[]);',
     'digest', 'not the SHA-256 of the canonical system', 'b in the system digest', None),
    ('F8_cert_digest_not_bound', 'A', 'farkas.rs', '                    ("cert_sha256", cert_digest(&y)),', '                    ("cert_sha256", cert_digest(&[])),',
     'digest', 'cert_sha256 is not the SHA-256 of y', 'y in the certificate digest', None),
    ('F9_entry_range_clamped', 'A', 'farkas.rs', '    Ok(t.parse::<i64>().ok())', '    Ok(Some(t.parse::<i64>().unwrap_or(i64::MAX)))',
     'grammar', 'expected SHAPE why=ENTRY_RANGE', 'the signed 64-bit range of every entry', None),
    ('F10_minus_zero', 'A', 'farkas.rs', ' && t != "-0";', ';',
     'grammar', 'expected MALFORMED_REQUEST why=FARKAS_NUMBER', 'the canonical integer form (no -0)', None),
    ('F11_column_sum_ge', 'A', 'farkas.rs', '            Some(s) if s > 0 => return Outcome::YtaPositive(j),', '            Some(s) if s >= 0 => return Outcome::YtaPositive(j),',
     'differential', 'Dafny Accepts=true but engine refused', 'y^T A <= 0 (zero allowed)', None),
    # ---- part B: the generator ---------------------------------------------------------------------------------------
    ('G1_cap_dropped_in_rules', 'B', 'policy_to_dfy.py', "opt(r['min_amount']), opt(r['max_amount']), fact",
     "opt(r['min_amount']), opt(None), fact", 'verify', 'dafny verify exit 4', 'max_amount in the rule list', 'money-refunds.json'),
    ('G2_lt_for_le_bound', 'B', 'policy_to_dfy.py', "'    (r.maxAmount.Some? ==> i.amount <= r.maxAmount.v)',",
     "'    (r.maxAmount.Some? ==> i.amount < r.maxAmount.v)',", 'differential', 'Dafny model', 'the inclusive max_amount', 'money-refunds.json'),
    ('G3_rule_skipped', 'B', 'policy_to_dfy.py', "    rules = policy['rules']\n    reasons", "    rules = policy['rules'][:-1]\n    reasons",
     'differential', "Dafny model 'REQUIRE_HUMAN_COSIGN', engine 'REJECTED_POLICY RULE'", 'every rule (the last one)', 'money-refunds.json'),
    ('G4_rejected_maps_to_no_rule', 'B', 'policy_to_dfy.py', "pm.REJECTED: 'RejectedRule'}", "pm.REJECTED: 'RejectedNoRule'}",
     'verify', 'dafny verify exit 4', 'the verdict of a REJECTED_POLICY rule', 'money-refunds.json'),
    ('G5_cosign_before_reject', 'B', 'policy_to_dfy.py',
     "          '    else if MatchWith(i, RejectedRule) then RejectedRule',\n          '    else if MatchWith(i, RequireHumanCosign) then RequireHumanCosign',",
     "          '    else if MatchWith(i, RequireHumanCosign) then RequireHumanCosign',\n          '    else if MatchWith(i, RejectedRule) then RejectedRule',",
     'verify', 'dafny verify exit 4', 'most restrictive wins', 'money-refunds.json'),
    ('G6_max_ops_plus_one', 'B', 'policy_to_dfy.py', "'  const MaxOps: int := %s' % num(policy['max_ops']),", "'  const MaxOps: int := %s' % num(policy['max_ops'] + 1),",
     'differential', "Dafny model ['COMMITTED']", 'max_ops_per_window', 'rate-api.json'),
    ('G7_max_ops_zero', 'B', 'policy_to_dfy.py', "'  const MaxOps: int := %s' % num(policy['max_ops']),", "'  const MaxOps: int := %s' % num(0),",
     'verify', 'dafny verify exit 4', 'max_ops_per_window >= 1 (else nothing ever fits)', 'rate-api.json'),
    ('G8_window_le_function_only', 'B', 'policy_to_dfy.py',
     "'    if |es| == 0 then 0 else LiveOps(es[..|es| - 1], now) + (if now < es[|es| - 1].t + WindowMs then 1 else 0)',",
     "'    if |es| == 0 then 0 else LiveOps(es[..|es| - 1], now) + (if now <= es[|es| - 1].t + WindowMs then 1 else 0)',",
     'verify', 'dafny verify exit 4', 'an event stops counting AT t + window_ms (function and its loop must agree)', 'rate-api.json'),
    ('G13_fits_lt_for_le', 'B', 'policy_to_dfy.py', "'    LiveOps(es, now) + 1 <= MaxOps && LiveVol(es, now) + v <= MaxVolume',",
     "'    LiveOps(es, now) + 1 < MaxOps && LiveVol(es, now) + v <= MaxVolume',",
     'differential', "Dafny model ['RATE_LIMIT_EXCEEDED'", 'the inclusive max_ops_per_window', 'rate-api.json'),
    ('G9_cooldown_count_gt', 'B', 'policy_to_dfy.py', "'      else if s.rejections + 1 >= CooldownAfter then State(s.events, 0, now + CooldownMs)',",
     "'      else if s.rejections + 1 > CooldownAfter then State(s.events, 0, now + CooldownMs)',",
     'verify', 'dafny verify exit 4', 'the cooldown after exactly cooldown_after rejections', 'rate-api.json'),
    ('G10_volume_cap_dropped', 'B', 'policy_to_dfy.py', "'  const MaxVolume: int := %s' % num(policy['max_volume']),",
     "'  const MaxVolume: int := %s' % num(policy['max_volume'] * 2),", 'differential', 'Dafny model', 'max_volume_per_window', 'rate-api.json'),
    ('G11_unsorted_reasons', 'B', 'policy_to_dfy.py', "'  const Reasons: set<string> := {%s}' % ', '.join(lit(r) for r in reasons),",
     "'  const Reasons: set<string> := {%s}' % ', '.join(lit(r) for r in {r['reason'] for r in rules}),",
     'determinism', 'two runs differ', 'a deterministic text (sorted reasons)', 'money-refunds.json'),
    ('G12_file_name_not_injective', 'B', 'policy_to_dfy.py', "    return '%s-%s.dfy' % (kind, policy['name'])", "    return '%s.dfy' % kind",
     'injectivity', 'two policy names give the file name', 'one file name per policy', 'rate-api.json'),
]


def tree_engine(folder, file=None, text=None):
    src = folder / 'src/primitives_v2'
    src.mkdir(parents=True)
    names = subprocess.run(['git', 'ls-tree', '--name-only', 'HEAD', 'src/primitives_v2/'], cwd=ROOT, capture_output=True, text=True).stdout.split()
    for name in names:
        if name.endswith('.rs'):
            data = subprocess.run(['git', 'show', 'HEAD:' + name], cwd=ROOT, capture_output=True).stdout
            (folder / name).write_bytes(data)
    shutil.copyfile(SRC / 'farkas.rs', src / 'farkas.rs')
    (folder / 'src/airlock').mkdir(parents=True)
    for name in ('json.rs', 'pin.rs'):
        data = subprocess.run(['git', 'show', 'HEAD:src/airlock/' + name], cwd=ROOT, capture_output=True).stdout
        (folder / 'src/airlock' / name).write_bytes(data)
    if file:
        (src / file).write_text(text)
    out = folder / 'primitives-engine'
    done = subprocess.run([ARGS.rustc] + RUSTC + [str(src / 'main.rs'), '-o', str(out)], capture_output=True, text=True)
    if done.returncode != 0:
        raise SystemExit('ERROR of the list: a copy does not build (%s)\n%s' % (folder.name, done.stderr[-1500:]))
    return out


def run_a(engine, case, work):
    p = subprocess.run([sys.executable, str(FARKAS_SUITE), str(engine), '--case', case, '--work', str(work), '--dafny-py', ARGS.dafny_py],
                       capture_output=True, text=True, timeout=7200)
    return p.returncode, line_of(p, case)


def run_b(gen, case, policy, work):
    argv = [sys.executable, str(POLICY_SUITE), '--generator', str(gen), '--case', case, '--work', str(work),
            '--airlock-engine', ARGS.airlock_engine, '--seams-engine', ARGS.seams_engine]
    if policy:
        argv += ['--policy', str(POL / policy)]
    p = subprocess.run(argv, capture_output=True, text=True, timeout=14400)
    return p.returncode, line_of(p, case)


def line_of(p, case):
    lines = [x for x in p.stdout.splitlines() if x.startswith(('PASS ' + case, 'FAIL ' + case))]
    return lines[0] if lines else 'no result line: ' + p.stdout[-300:] + p.stderr[-300:]


def main():
    global ARGS
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', action='append')
    ap.add_argument('--work')
    ap.add_argument('--rustc', default='/Users/mackianni/.cargo/bin/rustc')
    ap.add_argument('--dafny-py', required=True)
    ap.add_argument('--airlock-engine', required=True)
    ap.add_argument('--seams-engine', required=True)
    ARGS = ap.parse_args()
    names = [m[0] for m in MUTANTS]
    if len(set(names)) != len(names):
        print('ERROR: a name is used twice')
        return 1
    table = [m for m in MUTANTS if not ARGS.only or m[0] in ARGS.only]
    for name, fam, file, old, new, case, reason, removed, policy in table:
        path = SRC / file if fam == 'A' else GEN
        n = path.read_text().count(old)
        if n != 1:
            print('ERROR of the list: the text of %s is found %d times in %s, expected 1' % (name, n, file))
            return 1
    work = Path(tempfile.mkdtemp(prefix='p9-mut-', dir=ARGS.work))
    failed = 0
    base = tree_engine(work / 'control')
    for fam, case, policy in sorted({(m[1], m[5], m[8]) for m in table}, key=lambda x: (x[0], x[1], x[2] or '')):
        t = time.time()
        code, line = run_a(base, case, work) if fam == 'A' else run_b(GEN, case, policy, work)
        ok = code == 0 and line.startswith('PASS')
        print('CONTROL %-30s %s %-13s %-20s %s %5.1fs %s' % ('unchanged', fam, case, policy or '-', 'PASS' if ok else 'FAIL', time.time() - t, line[:140]), flush=True)
        failed += 0 if ok else 1
    for name, fam, file, old, new, case, reason, removed, policy in table:
        t = time.time()
        folder = work / name
        if fam == 'A':
            bins = tree_engine(folder, file, (SRC / file).read_text().replace(old, new))
            code, line = run_a(bins, case, work)
        else:
            # the copy sits at the same depth as the original, next to a link to the read-only src/airlock/py
            (folder / 'src/primitives_v2/py').mkdir(parents=True)
            (folder / 'src/airlock').mkdir(parents=True)
            os.symlink(ROOT / 'src/airlock/py', folder / 'src/airlock/py')
            gen = folder / 'src/primitives_v2/py/policy_to_dfy.py'
            gen.write_text(GEN.read_text().replace(old, new))
            code, line = run_b(gen, case, policy, work)
        killed = code == 1 and line.startswith('FAIL ') and 'suite error' not in line and reason in line
        failed += 0 if killed else 1
        print('%-30s %s %-13s %-10s %6.1fs removes: %s | %s' % (name, fam, case, 'KILLED' if killed else 'NOT KILLED', time.time() - t, removed, line[:220]), flush=True)
        shutil.rmtree(folder, ignore_errors=True)
    shutil.rmtree(work, ignore_errors=True)
    print('%d copies, %d not killed or control failures' % (len(table), failed))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
