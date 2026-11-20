#!/usr/bin/env python3
"""Controls for tests/primitives_v2/test_ledger_graph.py: changed copies of src/primitives_v2/ledger_graph.rs that
the suite must kill. FINITE TEST. It shows that the named cases CAN fail; it proves nothing about the module.

Usage: python3 tests/primitives_v2/mutants_p7.py [--only NAME]... [--work DIR] [--rustc PATH]

Each entry applies one or more exact text replacements (each text must occur exactly once in the file) to a copy of
the engine sources (src/primitives_v2/*.rs plus the read-only includes src/airlock/json.rs and src/airlock/pin.rs),
builds the production binary of the copy (PROTOCOL.md section 1), runs ONE case of the suite on it, and requires:
suite exit 1, a `FAIL <case>` line that is not a suite error, and the named text in it. First, the unchanged copy
must pass every named case (the control). A copy that does not build is an ERROR of the list.
Exit 0: the control passed and every copy was killed for its named reason. 1: otherwise.
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
SUITE = ROOT / 'tests/primitives_v2/test_ledger_graph.py'
RUSTC = ['--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3']
F = 'ledger_graph.rs'

# (name, [(exact text, replacement)...], case, text the FAIL line must hold, what the copy removes)
MUTANTS = [
    ('P1_overdraft', [('if f.balance < *amt {', 'if false {')],
     'ledger', 'overdraft: expected INSUFFICIENT_FUNDS', 'the overdraft refusal of a transfer'),
    ('P2_unbalanced_posting', [('if debit != credit {', 'if false {')],
     'ledger', 'unbalanced posting: expected CONSERVATION_BREACH', 'sum of debits == sum of credits of a posting'),
    ('P3_fold_trusts_records', [('check(state, policies, rec.tenant, rec.keys, &op).map_err(|r| format!("RECHECK {}", r.code))?;\n', '')],
     'hostile', 'overdraft transfer: not refused at replay', 'the strict re-check of every record at replay'),
    ('P4_no_cycle_check', [('                if let Some(d) = hit {', '                if let Some(d) = None::<u64> {')],
     'graph', 'a 4-cycle: expected DAG_CYCLE_DETECTED', 'the cycle check of add_edge'),
    ('P5_search_depth_one', [('                order.push(m);\n                q.push_back((m, d + 1));', '                order.push(m);')],
     'chain', 'closing edge of a 100,000-node chain: expected DAG_CYCLE_DETECTED', 'the full breadth-first search'),
    ('P6_duplicate_claim', [('if holder.is_some() { return Err(refusal("DUPLICATE_KEY"', 'if false { return Err(refusal("DUPLICATE_KEY"')],
     'race_claim', 'claim race of 50 tenants', 'first claim wins (global uniqueness)'),
    ('P7_no_case_fold', [('if fold { name.to_ascii_lowercase() } else { name.to_string() }', 'name.to_string()')],
     'registry', 'claim of a held name by t1: expected DUPLICATE_KEY', 'the ascii_fold canonical form'),
    ('P8_release_by_anyone', [('} else if holder.map(|h| h.as_str()) != Some(tenant) {', '} else if holder.is_none() {')],
     'registry', 'release by a non-holder: expected NOT_HOLDER', 'release only by the holder'),
    ('P9_no_balance_limit', [('if t.balance.checked_add(*amt).map_or(true, |b| b > max_balance) {', 'if t.balance.checked_add(*amt).is_none() {')],
     'ledger', 'overflow above max_balance: expected BALANCE_LIMIT', 'max_balance of the credited account'),
    ('P10_supply_not_fixed', [('if fixed && st.ledgers.contains_key', 'if false && st.ledgers.contains_key')],
     'ledger', 'a second open with a nonzero balance in a fixed ledger', 'the fixed supply (sum == const)'),
    ('P11_cross_ledger', [('if a.ledger != ledger {', 'if false {')],
     'ledger', 'cross-ledger transfer: expected CROSS_LEDGER', 'the cross-ledger refusal'),
    ('P12_batch_on_original', [('if let Err(r) = graph_add(&mut g, edges, max_nodes, max_edges) { return Decision::Refuse(r) }',
                                'for e in edges { let mut g1 = g.clone(); if let Err(r) = graph_add(&mut g1, std::slice::from_ref(e), max_nodes, max_edges) { return Decision::Refuse(r) } }')],
     'graph', "a cycle inside one batch: expected DAG_CYCLE_DETECTED, got 'MODULE_FAULT", 'the earlier edges of the same batch in the decision'),
    ('P23_no_reorder', [('if let Some((mut bwd, mut fwd)) = moved {', 'if let Some((mut bwd, mut fwd)) = moved.filter(|_| false) {')],
     'graph', 'a cycle across a reorder: expected DAG_CYCLE_DETECTED', 'the reorder of the topological order (Pearce-Kelly)'),
    ('P24_no_backward_set', [('let bwd = backward(g, a, ob);', 'let bwd = vec![a.as_str()];')],
     'graph', 'a cycle after a reorder with a backward set: expected DAG_CYCLE_DETECTED', 'the backward set of the reorder'),
    ('P25_band_too_narrow', [('if g.ord.get(m.as_str()).is_some_and(|o| *o <= bound) && seen.insert(m) {', 'if g.ord.get(m.as_str()).is_some_and(|o| *o < bound - 1) && seen.insert(m) {')],
     'model', 'model DAG_CYCLE_DETECTED', 'the band of the forward search (it must reach ord[from])'),
    ('P13_graph_cas_optional', [('OpSpec { op: "add_edge", min_keys: 1, max_keys: 1, cas: Cas::Required }', 'OpSpec { op: "add_edge", min_keys: 1, max_keys: 1, cas: Cas::AnyAllowed }')],
     'graph', '* in add_edge: expected MALFORMED_REQUEST', 'the per-graph state hash on every edge change'),
    ('P14_transfer_cas_optional', [('OpSpec { op: "transfer", min_keys: 2, max_keys: 2, cas: Cas::Required }', 'OpSpec { op: "transfer", min_keys: 2, max_keys: 2, cas: Cas::AnyAllowed }')],
     'ledger', '* in a transfer: expected MALFORMED_REQUEST', 'the pre-state hash of each account of a transfer'),
    ('P15_refusal_names_holder', [('if holder.is_some() { return Err(refusal("DUPLICATE_KEY", vec![("registry", reg.clone())]',
                                   'if let Some(h) = holder { return Err(refusal("DUPLICATE_KEY", vec![("registry", reg.clone()), ("holder", h.clone())]')],
     'registry', 'a DUPLICATE_KEY refusal shows more than the registry', 'a refusal never names the holder'),
    ('P16_burn_total_bug', [('l.total = l.total.checked_sub(*amt as u128).ok_or("UNDERFLOW")?;\n', '')],
     'ledger', "expected COMMITTED, got 'MODULE_FAULT", 'the fold invariant total == issued - destroyed (with an apply bug)'),
    ('P17_burn_total_bug_no_invariant', [('l.total = l.total.checked_sub(*amt as u128).ok_or("UNDERFLOW")?;\n', ''),
                                         ('if Some(s.total) != s.issued.checked_sub(s.destroyed) {', 'if false {')],
     'ledger', 'conservation from outside', 'the outside conservation check (sum of GETs == total == issued - destroyed)'),
    ('P18_zero_transfer', [('if *amt == 0 { return Err(refusal("ZERO_AMOUNT", vec![("index", "0".into())], "")) }\n            accounts(st, tenant, ledger, keys)?;',
                            'accounts(st, tenant, ledger, keys)?;')],
     'ledger', 'zero transfer: expected ZERO_AMOUNT', 'the zero-amount refusal of a transfer'),
    ('P19_self_transfer', [('if from == to {', 'if false {')],
     'ledger', 'self transfer: expected SELF_TRANSFER', 'the self-transfer refusal'),
    ('P20_foreign_handle', [('if keys.len() != 1 || keys[0] != handle {', 'if keys.len() != 1 {')],
     'registry', 'claim with a foreign handle', "a claim names the caller's own handle reg:<tenant>"),
    ('P21_no_node_bound', [('if g.ord.len() as u64 + new > max_nodes {', 'if false {')],
     'graph', 'max_nodes 6: expected GRAPH_FULL', 'the max_nodes bound'),
    ('P22_posting_overdraft', [('if !*credit && a.balance < *amt {', 'if false {')],
     'ledger', 'posting overdraft: expected INSUFFICIENT_FUNDS', 'the overdraft refusal of a posting leg'),
]


def tree(folder, reps=None):
    src = folder / 'src/primitives_v2'
    shutil.copytree(SRC, src, ignore=shutil.ignore_patterns('*.md', 'dafny', 'py'))
    (folder / 'src/airlock').mkdir(parents=True)
    for name in ('json.rs', 'pin.rs'):
        shutil.copyfile(ROOT / 'src/airlock' / name, folder / 'src/airlock' / name)
    if reps:
        text = (src / F).read_text()
        for old, new in reps:
            text = text.replace(old, new)
        (src / F).write_text(text)
    out = folder / 'build' / 'primitives-engine'
    out.parent.mkdir()
    done = subprocess.run([ARGS.rustc] + RUSTC + [str(src / 'main.rs'), '-o', str(out)], capture_output=True, text=True)
    if done.returncode != 0:
        raise SystemExit('ERROR of the list: a copy does not build (%s)\n%s' % (folder.name, done.stderr[-1500:]))
    return out


def run_case(binary, case, work):
    p = subprocess.run([sys.executable, str(SUITE), str(binary), '--case', case, '--work', str(work)], capture_output=True, text=True, timeout=3600)
    lines = [x for x in p.stdout.splitlines() if x.startswith(('PASS ' + case + ' ', 'FAIL ' + case + ' '))]
    return p.returncode, (lines[0] if lines else 'no result line: ' + p.stdout[-300:] + p.stderr[-300:])


def main():
    global ARGS
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', action='append')
    ap.add_argument('--work', default=None)
    ap.add_argument('--rustc', default=os.environ.get('FORGE_RUSTC') or shutil.which('rustc'))   # --rustc, FORGE_RUSTC, PATH
    ARGS = ap.parse_args()
    if not ARGS.rustc:
        print('NOT RUN: no rustc: pass --rustc PATH or set FORGE_RUSTC (rustc is not on PATH)')
        return 2
    table = [m for m in MUTANTS if not ARGS.only or m[0] in ARGS.only]
    names = [m[0] for m in MUTANTS]
    if len(set(names)) != len(names):
        print('ERROR: a name is used twice')
        return 1
    seen = {}
    for m in MUTANTS:
        if (m[2], m[3]) in seen:
            print('ERROR: %s and %s share one case and one expected text' % (seen[(m[2], m[3])], m[0]))
            return 1
        seen[(m[2], m[3])] = m[0]
    text = (SRC / F).read_text()
    for name, reps, *_ in table:
        for old, _new in reps:
            if text.count(old) != 1:
                print('ERROR of the list: a text of %s is found %d times in %s, expected 1' % (name, text.count(old), F))
                return 1
    work = Path(tempfile.mkdtemp(prefix='pv2-p7mut-', dir=ARGS.work))
    failed = 0
    base = tree(work / 'control')
    for case in sorted(set(m[2] for m in table)):
        code, line = run_case(base, case, work)
        ok = code == 0 and line.startswith('PASS')
        print('CONTROL %-32s %-11s %s %s' % ('unchanged', case, 'PASS' if ok else 'FAIL', line[:120]), flush=True)
        failed += 0 if ok else 1
    for name, reps, case, reason, removed in table:
        t = time.time()
        folder = work / name
        binary = tree(folder, reps)
        code, line = run_case(binary, case, work)
        killed = code == 1 and line.startswith('FAIL ') and 'suite error' not in line and reason in line
        failed += 0 if killed else 1
        print('%-32s %-11s %-10s %5.1fs removes: %s | %s' % (name, case, 'KILLED' if killed else 'NOT KILLED', time.time() - t, removed, line[:160]), flush=True)
        shutil.rmtree(folder, ignore_errors=True)
    shutil.rmtree(work, ignore_errors=True)
    print('%d copies, %d not killed or control failures' % (len(table), failed))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
