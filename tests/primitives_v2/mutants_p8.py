#!/usr/bin/env python3
"""Controls for tests/primitives_v2/test_taint.py: changed copies of src/primitives_v2/taint.rs that the suite must
kill. FINITE TEST. It shows that the named cases CAN fail; it proves nothing about the module.

Usage: python3 tests/primitives_v2/mutants_p8.py [--only NAME]... [--work DIR] [--rustc PATH]

Each entry replaces ONE exact text (it must occur exactly once in taint.rs) in a copy of the engine sources
(src/primitives_v2/*.rs, plus the two read-only includes src/airlock/json.rs and src/airlock/pin.rs at the same
relative place), builds the PRODUCTION binary of the copy with the command of PROTOCOL.md section 1 (the module
needs no test seam, so the seams build is not made), runs ONE case of test_taint.py on it, and requires: suite exit
1, a `FAIL <case>` line that is not a suite error, and the named text in it. First, the unchanged copy must pass every
named case (the control). A copy that does not build is an ERROR of the list. Exit 0: the control passed and every
copy was killed for its named reason. 1: otherwise.
"""

import argparse
import os
from pathlib import Path
import shutil
import signal
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
SRC = ROOT / 'src/primitives_v2'
SUITE = ROOT / 'tests/primitives_v2/test_taint.py'
RUSTC = ['--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3']
F = 'taint.rs'

# (name, file, exact text, replacement, case, text the FAIL line must hold, what the copy removes)
MUTANTS = [
    ('P8_01_label_inheritance_dropped', F,
     'let inh = if fresh.is_empty() { f.inh.clone() } else { Rc::new(f.inh.iter().chain(own.iter()).cloned().collect()) };',
     'let inh = Rc::new(BTreeSet::new());', 'table', 't22 ', 'labels of an object are inherited below it (dedupe and the count)'),
    ('P8_02_coverage_inheritance_dropped', F, 'let covered = f.covered || matched;', 'let covered = matched;',
     'table', 't80 ', 'strict mode: a rule on an object covers everything below it'),
    ('P8_03_arrays_not_walked', F, 'J::Arr(a) => {\n                for (i, c) in a.iter().enumerate().rev() {',
     'J::Arr(a) if a.is_empty() => {\n                for (i, c) in a.iter().enumerate().rev() {', 'table', 't11 ', 'the walk into arrays'),
    ('P8_04_nested_json_not_walked', F, 'Ok(j) => found.push((addr(n), j, d)),', 'Ok(_) => {}',
     'table', 't13 ', 'the parse and walk of JSON inside strings'),
    ('P8_05_destination_tenant_not_compared', F, '(Some(t), Some(a)) => t == a,', '(Some(_), Some(_)) => true,',
     'table', 't32 ', 'TENANT:b is blocked for destination TENANT:a'),
    ('P8_06_strict_uncovered_leaf_allowed', F, '&& !(container && (lpath.is_empty() ||', '&& container && !((lpath.is_empty() ||',
     'table', 't81 ', 'strict mode refuses an uncovered leaf'),
    ('P8_07_key_echoed_in_path', F,
     'let sseg = if fault.is_none() && p.names.contains(n) { SSeg::Name(n.clone()) } else { SSeg::Hidden(rank) };',
     'let sseg = SSeg::Name(fs[i].0.clone());', 'leak', 'MARK_KEYNAME_sk_live_zz9 in', 'a key that is not a policy name is never echoed'),
    ('P8_08_value_echoed_in_refusal', F,
     '"a field carries a label that may not leave to this destination; the value is not shown");',
     '&format!("{:?}", node));', 'leak', 'MARK_SSN_078051120 in', 'a refusal never holds a value'),
    ('P8_09_depth_bound_passes', F, 'if ex.max_depth > MAX_DEPTH { return Err(', 'if false { return Err(',
     'limits', 'depth 33: expected TAINT_LIMIT', 'a document deeper than MAX_DEPTH is refused'),
    ('P8_10_node_bound_truncates', F, 'if ex.nodes > MAX_NODES { return Err(', 'if false { return Err(',
     'limits', 'nodes 16385: expected TAINT_LIMIT', 'a document over MAX_NODES is refused, never truncated and passed'),
    ('P8_11_nested_bound_passes', F, 'if level + 1 > MAX_NESTED {', 'if level + 1 > 99 {',
     'limits', 'nested levels 5: expected TAINT_LIMIT', 'more than MAX_NESTED levels of JSON in strings are refused'),
    ('P8_12_key_normalization_removed', F, 'pub fn normalize(k: &str) -> String {\n    let mut o',
     'pub fn normalize(k: &str) -> String {\n    if !k.is_empty() { return k.to_string() }\n    let mut o', 'table', 't04 ',
     'key normalization (case, _ and -, fullwidth)'),
    ('P8_13_ambiguous_keys_allowed', F, 'if !norms.iter().all(|n| seen.insert(n.as_str())) {',
     'if false && !norms.iter().all(|n| seen.insert(n.as_str())) {', 'table', 't46 ', 'two keys equal after normalization are refused'),
    ('P8_14_opaque_json_passes', F, 'Err(e) => { ex.map.insert(addr(n), Err(e)); }', 'Err(_) => {}',
     'table', 't48 ', 'a JSON-like string that fails the strict parse is refused'),
    ('P8_15_tenant_sibling_ignored', F, 'if n != "tenantid" { continue }', 'if !n.is_empty() { continue }',
     'differential', ' differ: ', 'a sibling tenant_id labels its object'),
    ('P8_16_key_order_not_sorted', F, 'order.sort_by(|a, b| fs[*a].0.as_bytes().cmp(fs[*b].0.as_bytes()));', '',
     'order', 'shuffled documents changed the answer', 'the canonical order (key bytes) of the walk and of the first path'),
    ('P8_17_ignorable_key_allowed', F, 'if k.chars().any(ignorable) { return Some("IGNORABLE") }', '',
     'table', 't49 ', 'a key with a zero-width or other ignorable code point is refused'),
    ('P8_18_json_like_key_allowed', F, 'if json_like(k) { return Some("JSON_LIKE") }', '',
     'table', 'r7 ', 'a key that looks like JSON is refused'),
    ('P8_19_unknown_label_ignored', F, '(J::Str(_), _, _) => unknown = true,', '(J::Str(_), _, _) => {}',
     'table', 't25 ', 'a carrier label that the policy does not know is refused'),
    ('P8_20_carrier_labels_ignored', F, '                        own.extend(labels);\n', '',
     'table', 't19 ', 'an in-document label carrier labels its value'),
]



def run_group(argv, timeout, **kw):
    """subprocess.run(argv, capture_output=True, text=True, timeout=timeout), with the suite in its own process group.
    On every exit path (pass, fail, timeout, interrupt) SIGKILL goes to the whole group, so no `serve` child of the
    suite outlives it (unsure.md U927). A timeout still raises TimeoutExpired, as before."""
    p = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, start_new_session=True, **kw)
    try:
        out, err = p.communicate(timeout=timeout)
    finally:
        try:
            os.killpg(p.pid, signal.SIGKILL)
        except OSError:
            pass
        p.wait()
    return subprocess.CompletedProcess(argv, p.returncode, out, err)

def build(src, out):
    cmd = [ARGS.rustc] + RUSTC + [str(src / 'main.rs'), '-o', str(out)]
    return subprocess.run(cmd, capture_output=True, text=True)


def tree(folder, file=None, text=None):
    src = folder / 'src/primitives_v2'
    shutil.copytree(SRC, src, ignore=shutil.ignore_patterns('*.md', 'dafny', 'py'))
    (folder / 'src/airlock').mkdir(parents=True)
    for name in ('json.rs', 'pin.rs'):
        shutil.copyfile(ROOT / 'src/airlock' / name, folder / 'src/airlock' / name)
    if file:
        (src / file).write_text(text)
    out = folder / 'build' / 'primitives-engine'
    out.parent.mkdir()
    done = build(src, out)
    if done.returncode != 0:
        raise SystemExit('ERROR of the list: a copy does not build (%s)\n%s' % (folder.name, done.stderr[-1500:]))
    return out


def run_case(binary, case, work):
    p = run_group([sys.executable, str(SUITE), str(binary), '--case', case, '--work', str(work)], timeout=3600)
    lines = [x for x in p.stdout.splitlines() if x.startswith(('PASS ' + case, 'FAIL ' + case))]
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
    texts = {}
    for m in MUTANTS:
        key = (m[4], m[5])
        if key in texts:
            print('ERROR: %s and %s share one case and one expected text' % (texts[key], m[0]))
            return 1
        texts[key] = m[0]
    for name, file, old, new, case, reason, removed in table:
        n = (SRC / file).read_text().count(old)
        if n != 1:
            print('ERROR of the list: the text of %s is found %d times in %s, expected 1' % (name, n, file))
            return 1
    work = Path(tempfile.mkdtemp(prefix='pv2-mut8-', dir=ARGS.work))
    failed = 0
    base = tree(work / 'control')
    for case in sorted(set(m[4] for m in table)):
        code, line = run_case(base, case, work)
        ok = code == 0 and line.startswith('PASS')
        print('CONTROL %-38s %-13s %s %s' % ('unchanged', case, 'PASS' if ok else 'FAIL', line[:120]), flush=True)
        failed += 0 if ok else 1
    for name, file, old, new, case, reason, removed in table:
        t = time.time()
        folder = work / name
        binary = tree(folder, file, (SRC / file).read_text().replace(old, new))
        code, line = run_case(binary, case, work)
        killed = code == 1 and line.startswith('FAIL ') and 'suite error' not in line and reason in line
        failed += 0 if killed else 1
        print('%-38s %-13s %-10s %5.1fs removes: %s | %s' % (name, case, 'KILLED' if killed else 'NOT KILLED', time.time() - t, removed, line[:160]), flush=True)
        shutil.rmtree(folder, ignore_errors=True)
    shutil.rmtree(work, ignore_errors=True)
    print('%d copies, %d not killed or control failures' % (len(table), failed))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
