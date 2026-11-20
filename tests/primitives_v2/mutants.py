#!/usr/bin/env python3
"""Controls for tests/primitives_v2/test_engine.py: changed copies of src/primitives_v2/*.rs that the suite must kill.
FINITE TEST. It shows that the named cases CAN fail; it proves nothing about the engine.

Usage: python3 tests/primitives_v2/mutants.py [--only NAME]... [--work DIR] [--rustc PATH]

Each entry replaces ONE exact text (it must occur exactly once in the file) in a copy of the engine sources
(src/primitives_v2/*.rs, plus the two read-only includes src/airlock/json.rs and src/airlock/pin.rs at the same
relative place), builds BOTH binaries of the copy with the commands of PROTOCOL.md section 1, runs ONE case of the
suite on them, and requires: suite exit 1, a `FAIL <case>` line that is not a suite error, and the named text in it.
First, the unchanged copy must pass every named case (the control). A copy that does not build is an ERROR of the
list. Exit 0: the control passed and every copy was killed for its named reason. 1: otherwise.
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
SUITE = ROOT / 'tests/primitives_v2/test_engine.py'
RUSTC = ['--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3']

# (name, file, exact text, replacement, case, text the FAIL line must hold, what the copy removes)
MUTANTS = [
    ('W1_window_off_by_one', 'rate.rs', 'expiry(t, p).map_or(true, |e| now < e)', 'expiry(t, p).map_or(true, |e| now <= e)',
     'boundary', 'retry_after_ms=0', 'an event stops counting AT t + window_ms'),
    ('W2_retry_after_plus_one', 'rate.rs', 'Some(e) => Err(Some(e - now)),', 'Some(e) => Err(Some(e - now + 1)),',
     'boundary', 'at T+999', 'retry_after_ms is the exact wait'),
    ('W3_volume_cap', 'rate.rs', 'if ops + 1 <= p.max_ops && volume + v as u128 <= p.max_volume as u128 {', 'if ops + 1 <= p.max_ops {',
     'volume', "expected RATE_LIMIT_EXCEEDED, got 'COMMITTED", 'max_volume_per_window'),
    ('C1_cooldown_not_durable', 'rate.rs', 'if p.cooldown_after > 0 { Decision::RefuseDurable(r, format!("X {name} {v}")) } else { Decision::Refuse(r) }',
     'Decision::Refuse(r)', 'cooldown', 'must be a durable record', 'the durable record of a counted rejection'),
    ('C2_cooldown_count', 'rate.rs', 'if ks.rejections >= p.cooldown_after {', 'if ks.rejections > p.cooldown_after {',
     'cooldown', "expected COOLDOWN_ACTIVE, got 'RATE_LIMIT_EXCEEDED", 'the cooldown after exactly N rejections'),
    ('C3_cooldown_not_checked', 'rate.rs', '            if now.now_ms < until {', '            if false {',
     'cooldown', "expected COOLDOWN_ACTIVE, got 'MODULE_FAULT", 'the cooldown check of decide'),
    ('T1_clock_from_request', 'rate.rs', '        let Some((name, v)) = parse_args(req.args) else {',
     '        let (args, now): (&str, Now) = match req.args.rsplit_once(\' \') { Some((a, t)) if a.contains(\' \') => (a, Now { now_ms: t.parse().unwrap_or(0), wall_ms: 0, skew_ms: 0 }), _ => (req.args, *now) };\n        let now = &now;\n        let Some((name, v)) = parse_args(args) else {',
     'clock_request', 'a request field was taken as a time', 'the rule that no request field is a time'),
    ('T2_raw_wall_clock', 'clock.rs', 'let now_ms = wall.max(last_ms).max(floor);', 'let now_ms = wall;',
     'clock_setback', 'clock set back 500 s', 'now = max(wall, newest record time, monotonic floor)'),
    ('T3_no_monotonic_floor', 'clock.rs', 'Some((at, m0)) => at.saturating_add(mono.saturating_sub(m0)),', 'Some(_) => 0,',
     'clock_setback', 'monotonic floor after 999 ms', 'the monotonic floor inside one process'),
    ('T4_clock_seam_in_production', 'clock.rs', 'let path = if cfg!(test_seams) { std::env::var("PRIMITIVES_TEST_CLOCK").ok() } else { None };',
     'let path = std::env::var("PRIMITIVES_TEST_CLOCK").ok();', 'seams', 'production init took the seam clock', 'the cfg gate of the clock seam'),
    ('T5_ttl_raw_wall', 'cosign_ttl.rs', 'if now.now_ms > not_after_ms {', 'if now.wall_ms > not_after_ms {',
     'cosign_ttl', "a clock set back revived a token", 'the TTL compare with the trusted Now'),
    ('K1_cas_skipped', 'engine.rs', 'if pre.is_some_and(|p| p != present) { stale.push((format!("hash.{k}"), hx(&present))) }',
     'if false { stale.push((format!("hash.{k}"), hx(&present))) }', 'race', 'CAS race of 50', 'the compare-and-swap'),
    ('K2_cas_first_key_only', 'engine.rs', '    for (k, pre) in &keys {\n        let present = s.f.key_hash(k);',
     '    for (k, pre) in keys.iter().take(1) {\n        let present = s.f.key_hash(k);', 'multikey',
     "expected STALE_STATE_HASH, got 'COMMITTED", 'the compare of EVERY key of a multi-key request'),
    ('K3_duplicate_id', 'engine.rs', '    if s.f.ids.contains(rid) { return Err(refusal("DUPLICATE_REQUEST_ID", vec![], "").into()) }\n', '',
     'race', 'duplicate-id race of 50', 'the one-time request id'),
    ('K4_tenant', 'engine.rs', '            if info.tenant != tenant { return Err(refusal("TENANT_ISOLATION_BREACH", vec![("why", "KEY_OF_ANOTHER_TENANT".into()), ("key", k.to_string())], "").into()) }\n',
     '', 'multikey', 'expected TENANT_ISOLATION_BREACH', 'the tenant check of a write'),
    ('S1_sync_skipped', 'store.rs', 'if let Err(e) = written.and_then(|()| self.wal.sync_all()) {', 'if let Err(e) = written {',
     'trace', 'no F_FULLFSYNC of the WAL before the answer', 'sync_all before COMMITTED'),
    ('S2_shared_lock', 'store.rs', 'match wal.try_lock() {', 'match wal.try_lock_shared() {',
     'lock', 'a second process answered while the first held the lock', 'the exclusive lock'),
    ('S3_no_header_check', 'store.rs', 'if &hdr[..4] != MAGIC || hdr[64..68] != crc32(&hdr[..64]).to_le_bytes() { return Err(corrupt(index, "HEADER")) }',
     'if &hdr[..4] != MAGIC { return Err(corrupt(index, "HEADER")) }', 'flip', 'was not refused', 'the header check (a damaged length is not a torn tail)'),
    ('S4_torn_tail_not_cut', 'store.rs', '        w.set_len(f.len)?; // the torn last record', '        // the torn last record',
     'torn', 'was not cut off exactly', 'the cut of a torn last record'),
    ('S5_time_may_go_back', 'store.rs', '            if now_ms < self.last_ms { return Err("TIME_WENT_BACK".into()) }\n', '',
     'splice', 'time goes back: not refused', 'the replay check that record times never go back'),
    ('S6_fold_no_recheck', 'rate.rs', '                if fits(&ks.events, p, now, v).is_err() { return Err("COMMIT_DID_NOT_FIT".into()) }\n', '',
     'splice', 'forged third commit', 'the replay re-check of each commit against the window'),
    ('S7_folder_mode', 'store.rs', 'if m.mode() & 0o077 != 0 { return Err(unsafe_store(format!("FOLDER_MODE', 'if false { return Err(unsafe_store(format!("FOLDER_MODE',
     'init', 'folder 0750', 'the folder mode check'),
    ('S8_build_marker', 'store.rs', 'if t[4] != BUILD {', 'if false {',
     'seams', 'production opened a test-seams store', 'the refusal of a store of the other build'),
    ('L1_oversized_not_skipped', 'main.rs', '        input.skip_until(b\'\\n\')?;\n', '',
     'lines', 'after an oversized line, the next line was not read as itself', 'the constant-memory skip of an oversized line'),
]


def build(src, out, seams):
    cmd = [ARGS.rustc] + RUSTC + (['--cfg', 'test_seams'] if seams else []) + [str(src / 'main.rs'), '-o', str(out)]
    return subprocess.run(cmd, capture_output=True, text=True)


def tree(folder, file=None, text=None):
    src = folder / 'src/primitives_v2'
    shutil.copytree(SRC, src, ignore=shutil.ignore_patterns('*.md'))
    (folder / 'src/airlock').mkdir(parents=True)
    for name in ('json.rs', 'pin.rs'):
        shutil.copyfile(ROOT / 'src/airlock' / name, folder / 'src/airlock' / name)
    if file:
        (src / file).write_text(text)
    bins = []
    for seams, name in ((False, 'primitives-engine'), (True, 'primitives-engine-seams')):
        out = folder / ('build-seams' if seams else 'build') / name
        out.parent.mkdir()
        done = build(src, out, seams)
        if done.returncode != 0:
            raise SystemExit('ERROR of the list: a copy does not build (%s, %s)\n%s' % (folder.name, name, done.stderr[-1500:]))
        bins.append(out)
    return bins


def run_case(bins, case, work):
    p = subprocess.run([sys.executable, str(SUITE), str(bins[0]), str(bins[1]), '--case', case, '--big-gib', '0.25', '--work', str(work)],
                       capture_output=True, text=True, timeout=3600)
    lines = [x for x in p.stdout.splitlines() if x.split(' ')[1:2] == [case] or x.startswith(('PASS ' + case, 'FAIL ' + case))]
    return p.returncode, (lines[0] if lines else 'no result line: ' + p.stdout[-300:] + p.stderr[-300:])


def main():
    global ARGS
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', action='append')
    ap.add_argument('--work', default=None)
    ap.add_argument('--rustc', default='/Users/mackianni/.cargo/bin/rustc')
    ARGS = ap.parse_args()
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
    work = Path(tempfile.mkdtemp(prefix='pv2-mut-', dir=ARGS.work))
    failed = 0
    base = tree(work / 'control')
    for case in sorted(set(m[4] for m in table)):
        code, line = run_case(base, case, work)
        ok = code == 0 and line.startswith('PASS')
        print('CONTROL %-26s %-13s %s %s' % ('unchanged', case, 'PASS' if ok else 'FAIL', line[:120]), flush=True)
        failed += 0 if ok else 1
    for name, file, old, new, case, reason, removed in table:
        t = time.time()
        folder = work / name
        bins = tree(folder, file, (SRC / file).read_text().replace(old, new))
        code, line = run_case(bins, case, work)
        killed = code == 1 and line.startswith('FAIL ') and 'suite error' not in line and reason in line
        failed += 0 if killed else 1
        print('%-28s %-13s %-10s %5.1fs removes: %s | %s' % (name, case, 'KILLED' if killed else 'NOT KILLED', time.time() - t, removed, line[:160]), flush=True)
        shutil.rmtree(folder, ignore_errors=True)
    shutil.rmtree(work, ignore_errors=True)
    print('%d copies, %d not killed or control failures' % (len(table), failed))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
