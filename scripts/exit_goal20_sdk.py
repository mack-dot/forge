#!/usr/bin/env python3
"""Goal 20: EXIT checks of forge-airlock: the engine (src/airlock/*.rs), its Node booking helper, the cosign tools
without Node (src/airlock/py/cosign_tool.py; the engine verifies with /usr/bin/ssh-keygen, Apex addendum),
diff-policy, the Python and TypeScript SDKs, the dispatcher bin/forge-airlock, the unbreakable_store demo and the
fuzz pass.

What a pass means: on this machine the finite checks below gave the recorded results. It is a FINITE TEST. It is NOT
a proof of the engine, the helpers, the SDKs, the demo or the dispatcher. end_to_end stays false. M1 stays OPEN. The
bundle is a RECORD, not gate evidence. The four keys proved_core, native_check, finite_test and trusted_assumptions
are separate.

This script starts tools and compares results. It decides nothing about a refund, a booking, a saga move or a read.

Cases:
  build      source rules (line 1 of main.rs is #![forbid(unsafe_code)]; no unsafe; no extern crate; no Cargo file;
             every Rust `use` path from std, core, alloc, crate, self, super or an item of the same file; the Node
             helper and the TypeScript files require only node: built-ins (and ts_part.ts the TS SDK); the Python
             files import only the standard library and repository modules), a control that a copy with one unsafe
             block does not compile, both engine builds, the test interposer, the identity of the refund binary and
             its private copy for the dispatcher, the checker model rebuilt by Dafny and equal to its record, the
             toolchain versions
  suite      tests/airlock/test_engine.py, test_node_helpers.py, test_cosign.py, test_diff_policy.py and test_sdk.py, all cases, on the
             builds of the attempt; every case line is parsed; the set of case names must be the expected one
  mutations  changed copies: each copy has ONE exact-once text replacement; it must build; ONLY the named case of the
             named suite (or the demo, or the fuzz pass) runs; the case must FAIL and its failure text must hold the
             named reason. The unchanged copies first pass every case that the list names. A copy that does not build
             is an ERROR of the list
  disasters  examples/unbreakable_store/run_demo.py on the builds of the attempt: exit 0, and this script's own checks
             of the eight disasters, the money leaked from the WAL and the labels; the deterministic JSON is recorded
  fuzz       bin/forge-airlock fuzz with a fixed seed and rounds: exit 0, all eight invariants HELD; counts recorded
  evidence   build, suite, mutations, disasters and fuzz, twice, in fresh folders; the two bundles are byte-identical
Raw outputs go to build/goal20/ (ignored by git). Times go to measurements.json, never to the bundle.
Environment: PATH must find the pinned Node first (scripts/javascript_env.py checks it). FORGE_DAFNY_LOCK=<folder>:
the Dafny lock (mkdir); default build/goal20/locks/dafny. Exit: 0 passed; 1 failed; 2 toolchain error.
"""

import argparse
import ast
from contextlib import contextmanager
import json
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
sys.path.insert(0, str(ROOT / 'scripts'))
from common import canonical, digest, read_json  # noqa: E402  (record helpers only; no decision)
import javascript_env  # noqa: E402  (the pinned Node check)

ENGINE_DIR = 'src/airlock'
RUST = ['main.rs', 'store.rs', 'ledger.rs', 'policy.rs', 'verbs.rs', 'helpers.rs', 'cosign.rs', 'json.rs', 'pin.rs']
NODE_HELPERS = ['src/airlock/node/booking_check.cjs']  # the Node cosign helper is deleted (Apex addendum)
TS_FILES = ['sdk/ts/forge_airlock.ts', 'examples/unbreakable_store/ts_part.ts']
TS_SDK_REQUIRE = "require(pathMod.join(__dirname, '..', '..', 'sdk', 'ts', 'forge_airlock.ts'))"  # the one computed require
PYTHON_FILES = ['src/airlock/py/diff_policy.py', 'src/airlock/py/policy_model.py', 'src/airlock/py/fuzz.py', 'src/airlock/node/build_checker.py',
                'src/airlock/py/cosign_tool.py', 'tests/airlock/test_cosign.py',
                'sdk/py/forge_airlock.py', 'bin/forge-airlock', 'examples/unbreakable_store/run_demo.py',
                'tests/airlock/test_engine.py', 'tests/airlock/test_node_helpers.py', 'tests/airlock/test_diff_policy.py', 'tests/airlock/test_sdk.py',
                'scripts/exit_goal20_sdk.py']
REPO_MODULES = {'policy_model', 'common', 'backends', 'spec_clearing', 'javascript_env', 'forge_airlock'}
ENGINE_SUITE, NODE_SUITE, DIFF_SUITE = 'tests/airlock/test_engine.py', 'tests/airlock/test_node_helpers.py', 'tests/airlock/test_diff_policy.py'
COSIGN_SUITE = 'tests/airlock/test_cosign.py'
SDK_SUITE, DEMO, DISPATCHER = 'tests/airlock/test_sdk.py', 'examples/unbreakable_store/run_demo.py', 'bin/forge-airlock'
INTERPOSER = 'tests/airlock/interpose.c'
ARTIFACT = 'proposals/forge2-m1-conformance/artifacts/refund-arm64-macho'
ARTIFACT_SHA256 = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
REFUND_COPY = 'build/airlock/refund-binary'  # the dispatcher's private copy (bin/forge-airlock checks its SHA-256 at every start)
MODEL = 'build/airlock/checker/model.cjs'
MODEL_SHA256 = 'e705ec490e30572cc783da2d7f927d5b4201f6bec0bc0a64c9cde507384b85f4'
CHECKER_SOURCE = 'proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy'
BUILD = 'build/goal20'
RUSTC = ['rustc', '--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3']  # the command of PROTOCOL.md section 1
RUSTC_VERSION = 'rustc 1.92.0 (ded5c06cf 2025-12-08)'
CC = '/usr/bin/cc'
CC_VERSION = 'Apple clang version 17.0.0 (clang-1700.0.13.5)'
CC_FLAGS = ['-dynamiclib', '-O1', '-Wall', '-Wextra', '-Werror']
ENGINE_CASES = ['init', 'recovery', 'cas', 'tenant', 'money', 'canonical', 'cosign', 'cosign_faults', 'saga', 'inventory', 'leases', 'read', 'lines',
                'replay', 'race', 'kill', 'trace', 'dispatch', 'lock', 'pin', 'crafted', 'native_bound', 'helper_env',
                'lease_binding', 'nonce', 'weakkey', 'seams']
NODE_CASE_COUNT = 68  # booking_check.cjs only (the 69 cosign.cjs cases moved to test_cosign.py and test_engine.py)
COSIGN_CASE_COUNT = 56
DIFF_CASES = ['loader', 'malformed', 'no-engine', 'engine', 'mismatch', 'demo', 'choice', 'fault', 'refused', 'saga', 'identical']
SDK_CASES = ['py_typed', 'py_cosign', 'py_canonical', 'py_saga_inventory', 'py_read', 'py_lease', 'py_kill', 'py_garbage', 'py_protocol',
             'py_lease_durable', 'ts_typed', 'ts_read', 'ts_lease', 'ts_kill', 'ts_garbage', 'ts_protocol', 'py_read_tricks', 'py_lease_bound',
             'ts_read_tricks', 'py_no_node', 'py_build_separation']
FUZZ_SEED, FUZZ_ROUNDS = 20, 3
HEX32 = re.compile(r'[0-9a-f]{32}')  # a state hash, genesis hash, nonce or signature: never in the bundle
DISASTER_CODES = {  # the engine codes that the directive names for each disaster; each must appear in `observed`
    1: ['1 COMMITTED, 49 STALE_STATE_HASH'], 2: ['TOTAL_CAP', 'CAKEML_REJECTED'], 3: ['REASON_CAP'],
    4: ['COSIGN_REQUIRED', 'COSIGN_INVALID', 'COMMITTED'], 5: ['PROCESSOR_IN_FLIGHT', 'LOCAL FAKE'], 6: ['TENANT_ISOLATION_BREACH', '0 rows'],
    7: ['DROPPED_OBLIGATION wh-7,wh-7t', 'on another key: REJECTED_POLICY', 'lease still open'], 8: ['OVERBOOKED', 'GAP_TOO_LARGE', 'optimal batch: COMMITTED', 'Dafny starts seen: 0']}
SUBJECT = sorted(['src/airlock/' + f for f in RUST] + NODE_HELPERS + TS_FILES + PYTHON_FILES + [
    'src/airlock/PROTOCOL.md', INTERPOSER, ARTIFACT, CHECKER_SOURCE, 'proposals/forge2-pillar3-dual-certificate/benchmark/records/build-record.json',
    'tests/m1-conformance/recorded-m1-cases.json', 'proposals/forge2-goal20-sdk/DESIGN.md', 'proposals/forge2-goal20-sdk/BRIEF.md',
    'docs/quickstart-5min.md', 'proposals/forge2-goal20-sdk/REVIEW.md'])
SUBJECT_GLOBS = ['tests/airlock/fixtures/*.json', 'tests/airlock/policies/*.json', 'examples/unbreakable_store/policies/*.json']

# Changed copies. (name, file, a part of the failure text that must appear, text to find exactly once, replacement,
# suite, the case that must fail, what is removed). Suites: engine = tests/airlock/test_engine.py, node =
# tests/airlock/test_node_helpers.py, cosign = tests/airlock/test_cosign.py, diff = tests/airlock/test_diff_policy.py, sdk = tests/airlock/test_sdk.py,
# demo = examples/unbreakable_store/run_demo.py (case D1..D8 or money), fuzz = bin/forge-airlock fuzz (case = an
# invariant). A file without a folder part lies in src/airlock (for example verbs.rs, py/cosign_tool.py); a file that
# starts with sdk/, bin/ or examples/ lies at that path. A copy of a .rs file is built into new engine binaries; a copy
# of any other file runs in a mirror tree (copies of src/airlock, tests/airlock, sdk, bin, examples, gate and scripts
# under build/) so that the suite reads the changed file. M01 to M35 are the seams of PROTOCOL.md section 13.
LOCK_LINE = '    wal.lock()?; // exclusive flock, taken before any file of the store is read; the kernel releases it at exit or kill\n'
SCAN_LINE = '    let (l, total) = scan(&mut BufReader::new(&wal), &mut |_, _| {})?;\n'
MUTANTS = [
    # PROTOCOL.md section 13: the checks of the request verbs, the policies and the store
    ('M01_check_key_tenant', 'verbs.rs', "DUPLICATE_CHARGE 10': expected TENANT_ISOLATION_BREACH",
     '    if k.tenant != tenant { return no(Code::Breach, "KEY_OF_ANOTHER_TENANT") }\n    if s.l.ids.contains(req) { return no(Code::Duplicate, "DUPLICATE_REQUEST_ID") }\n    if k.hash != pre',
     '    if s.l.ids.contains(req) { return no(Code::Duplicate, "DUPLICATE_REQUEST_ID") }\n    if k.hash != pre', 'engine', 'tenant', 'the tenant check of a write to an existing key'),
    ('M02_check_key_duplicate_id', 'verbs.rs', "DUPLICATE_CHARGE 10': expected DUPLICATE_REQUEST_ID",
     '    if s.l.ids.contains(req) { return no(Code::Duplicate, "DUPLICATE_REQUEST_ID") }\n    if k.hash != pre', '    if k.hash != pre', 'engine', 'cas',
     'the fresh request id of a write to an existing key'),
    ('M03_compare_and_swap', 'verbs.rs', 'race: 1 COMMITTED, 0 STALE', '    if k.hash != pre { return no(Code::Stale, hx(k.hash)) }\n', '', 'engine', 'race',
     'the compare-and-swap on the state hash'),
    ('M04_check_open_tenant', 'verbs.rs', "'OPEN_MONEY tB k1 r3 store-refunds 1000': expected TENANT_ISOLATION_BREACH",
     '        if k.tenant != tenant { return no(Code::Breach, "KEY_OF_ANOTHER_TENANT") }\n', '', 'engine', 'tenant', 'the tenant check of an open'),
    ('M05_zero_amount', 'policy.rs', "DUPLICATE_CHARGE 0': expected REJECTED_POLICY", '    if amount == 0 { return Verdict::Reject("ZERO_AMOUNT") }\n', '', 'engine', 'money',
     'the zero-amount refusal of the money rules'),
    ('M06_total_cap', 'policy.rs', "DUPLICATE_CHARGE 1001': expected REJECTED_POLICY", '    if amount > remaining { return Verdict::Reject("TOTAL_CAP") }\n', '', 'engine', 'money', 'the total cap'),
    ('M07_reason_cap', 'policy.rs', "SHIPPING 80': expected REJECTED_POLICY (exit 10), got exit 0 'COMMITTED", '            if !within { capped = true; continue }\n', '', 'engine', 'money',
     'the fact-bound reason cap (SHIPPING <= shipping_paid)'),
    ('M08_most_restrictive', 'policy.rs', "GOODWILL 500': expected REQUIRE_HUMAN_COSIGN (exit 11), got exit 0", 'r.verdict.rank() > b.rank()', 'false', 'engine', 'money',
     'the rule that the most restrictive verdict wins'),
    ('M09_cosign_not_verified', 'verbs.rs', "got exit 0 'COMMITTED r1", 'if !cosign::verify(&ctx.dir, &pk, sig, &msg)? {', 'if false {', 'engine', 'cosign',
     'the verification of a cosign signature (the call of /usr/bin/ssh-keygen)'),
    ('M10_cosign_answer_any_bytes', 'cosign.rs', 'stand-in stderr-text: expected HELPER_FAILED', '(Some(0), true, o) if o == good.as_bytes() => Ok(true),', '(Some(0), _, _) => Ok(true),',
     'engine', 'cosign_faults', 'the exact Good line and the empty stderr of ssh-keygen'),
    ('M10b_booking_answer_any_bytes', 'helpers.rs', "expected HELPER_FAILED (exit 22), got exit 0 'COMMITTED b4", '(Some(0), true, o) if o == yes => Ok(true),', '(Some(0), _, _) => Ok(true),',
     'engine', 'inventory', 'the exact ACCEPT line and the empty stderr of the booking helper'),
    ('M11_refund_frame_unclean', 'helpers.rs', 'BAD_FRAME (exit 23), got exit 0', 'let clean = r.code == Some(0) && r.err.is_empty() && r.sent;', 'let clean = true;',
     'engine', 'canonical', 'the clean exit and empty stderr of the refund binary'),
    ('M12_cakeml_reject_ignored', 'verbs.rs', "returned_item 101': expected REJECTED_POLICY (exit 10), got exit 23", 'if !helpers::refund_binary(ctx.binary.as_deref(), &wire, &expect)? {',
     'if helpers::refund_binary(ctx.binary.as_deref(), &wire, &expect).is_err() {', 'engine', 'canonical', 'the rejection by the CakeML binary'),
    ('M13_processor_in_flight', 'verbs.rs', 'failover while in flight', '} else if cur_in && pair != *held {', '} else if false {', 'engine', 'saga',
     'the refusal of a second processor while a key is in flight'),
    ('M14_saga_transition', 'verbs.rs', "SETTLED': expected REJECTED_POLICY (exit 10), got exit 0", '} else if !sp.transitions.iter().any(|(a, b)| a == cur && b == to) {', '} else if false {',
     'engine', 'saga', 'the transition table'),
    ('M15_capacity_mismatch', 'verbs.rs', "got exit 0 'COMMITTED b2 ", 'let decision = if cert.c != *remaining {', 'let decision = if false {', 'engine', 'inventory',
     'the comparison of the certificate capacities with the key'),
    ('M16_alpha_above_policy', 'verbs.rs', "got exit 0 'COMMITTED b3 ", '} else if cert.alpha > ip.max_alpha_bps {', '} else if false {', 'engine', 'inventory',
     'the alpha_bps bound of the policy'),
    ('M17_checker_not_consulted', 'verbs.rs', "got exit 0 'COMMITTED b4 ", 'if !helpers::booking_check(&ctx.node(), &policy::cert_json(&cert))? {', 'if false {',
     'engine', 'inventory', 'the call of the Dafny-compiled checker'),
    ('M18_native_overbooked', 'policy.rs', "OVERBOOKED: ['REJECTED_POLICY', 'CHECKER_REJECTED']", '    if used.iter().zip(&c.c).any(|(u, cap)| *u > *cap as u128) { return Err("OVERBOOKED") }\n', '',
     'engine', 'inventory', 'the native A x <= c check'),
    ('M19_lease_close_record', 'verbs.rs', 'the answer names the close', '    if bound {\n        let (epoch, _)', '    if false {\n        let (epoch, _)',
     'engine', 'leases', 'the durable CLOSE record of a terminal refusal'),
    ('M20_commit_closes_lease', 'ledger.rs', 'LEASE L1 100 t1 k1', 'l.closed = Some((index, "COMMITTED".into(), "-".into()))', 'l.closed = None', 'engine', 'leases',
     'the close of a lease by a committed effect'),
    ('M21_sweep_deadline', 'main.rs', 'deadline itself is not past', '} else if now > *deadline {', '} else if now >= *deadline {', 'engine', 'leases',
     'the strict deadline of a sweep'),
    ('M22_read_tenant_value', 'verbs.rs', 'row mismatch', '(J::Obj(_), Some(J::Str(t))) if t == tenant => Ok(()),', '(J::Obj(_), Some(J::Str(_))) => Ok(()),',
     'engine', 'read', 'the comparison of a row tenant_id with the caller tenant'),
    ('M23_read_tenant_canonical', 'verbs.rs', "tenant 'READ ", '(!canonical_id(tenant)).then(|| "TENANT_NOT_CANONICAL".to_string())', 'None', 'engine', 'read',
     'the canonical-id rule for the caller tenant'),
    ('M24_json_duplicate_key', 'json.rs', 'row dup:', 'if !seen.insert(key.clone()) {', 'if !seen.insert(key.clone()) && false {', 'engine', 'read',
     'the refusal of a duplicate JSON key'),
    ('M25_no_lock', 'store.rs', 'while another process held the store lock', LOCK_LINE, '', 'engine', 'lock', 'the store lock'),
    ('M26_epoch_regression', 'store.rs', 'restored WAL', 'if l.epoch < floor {', 'if false {', 'engine', 'recovery', 'the comparison of the WAL with its ratchet'),
    ('M27_torn_tail_corrupt', 'store.rs', 'not recovered', 'if got < body.len() { torn = (HDR + got) as u64; break }',
     'if got < body.len() { return no(Code::CorruptWal, "x") }', 'engine', 'recovery', 'the cut of a torn record at the end'),
    ('M28_serve_continues_after_fault', 'main.rs', 'serve must end at EPOCH_REGRESSION', '        if is_fault(code) { return code }\n    }\n}\n\n/// `eval',
     '    }\n}\n\n/// `eval', 'engine', 'recovery', 'the end of serve at a fault'),
    ('M29_oversized_line_not_skipped', 'main.rs', 'line of 65537 bytes', "        input.skip_until(b'\\n')?;\n", '', 'engine', 'lines',
     'the skip of an oversized line to its line end'),
    ('M30_line_bound_4096', 'main.rs', 'line of 65535 bytes', 'pub const MAX_LINE: usize = 65536;', 'pub const MAX_LINE: usize = 4096;', 'engine', 'lines',
     'the line bound of 65,536 bytes'),
    ('M31_canonical_zero_amount', 'verbs.rs', "returned_item 0': expected REJECTED_POLICY", '        if amount == 0 { return verdict(s, req, Code::RejectedPolicy, "ZERO_AMOUNT") }\n', '',
     'engine', 'canonical', 'the native zero-amount refusal before the CakeML binary'),
    ('M32_cosign_store_id_fixed', 'verbs.rs', "expected COMMITTED (exit 0), got exit 11 'REQUIRE_HUMAN_COSIGN COSIGN_INVALID'", 'cosign_message(&s.l.store_id, s.l.genesis_hash, req, t[4], &action)',
     'cosign_message("store-a", s.l.genesis_hash, req, t[4], &action)', 'engine', 'cosign', 'the store id inside the signed cosign message'),
    ('M33_get_tenant', 'verbs.rs', "'GET tB k1': expected TENANT_ISOLATION_BREACH",
     '    if k.tenant != tenant { return no(Code::Breach, "KEY_OF_ANOTHER_TENANT") }\n    let rest = match', '    let rest = match', 'engine', 'tenant',
     'the tenant check of GET'),
    ('M34_policy_pin', 'store.rs', 'changed policy file', 'if fnv128(&bytes) != pin.hash {', 'if false {', 'engine', 'recovery', 'the pin of a policy file'),
    ('M35_json_trailing_bytes', 'json.rs', 'row trailing:', 'if p.i != p.b.len() {', 'if false {', 'engine', 'read', 'the refusal of bytes after a JSON value'),
    # the durable order (case trace, with the test interposer) and the answer
    ('S01_no_wal_sync', 'store.rs', 'system-call order of a commit: missing step \'fullfsync airlock.wal 0\'', 'if let Err(e) = written.and_then(|()| wal.sync_all()) {', 'if let Err(e) = written {',
     'engine', 'trace', 'the F_FULLFSYNC of the WAL before the answer'),
    ('S02_ignore_wal_sync_error', 'store.rs', 'failed sync of the WAL: expected one IO_ERROR line', 'if let Err(e) = written.and_then(|()| wal.sync_all()) {',
     'let _ = wal.sync_all();\n        if let Err(e) = written {', 'engine', 'trace', 'the result of the WAL sync'),
    ('S03_no_cut_after_failed_sync', 'store.rs', 'failed sync of the WAL: the record must be cut off again',
     'let undone = wal.set_len(old_len).and_then(|()| wal.sync_all());', 'let undone: io::Result<()> = Ok(());', 'engine', 'trace',
     'the cut of a record whose write or sync failed'),
    ('S04_no_ratchet_sync', 'store.rs', 'system-call order of init: missing step \'fullfsync airlock.epoch 0\'', '.concat()).and_then(|()| ratchet.sync_all())', '.concat())', 'engine', 'trace',
     'the F_FULLFSYNC of the ratchet entry'),
    ('S05_ignore_ratchet_error', 'store.rs', 'failed sync of the ratchet: expected one OUTCOME_UNKNOWN line',
     'if push(&mut ratchet, epoch).is_err() { return no(Code::OutcomeUnknown, "OUTCOME_UNKNOWN the record is in the WAL; its ratchet entry failed") }',
     'let _ = push(&mut ratchet, epoch);', 'engine', 'trace', 'the result of the ratchet write and sync'),
    ('S06_no_ratchet_entry', 'store.rs', 'system-call order of a commit: missing step \'write airlock.epoch 12\'',
     '        if push(&mut ratchet, epoch).is_err() { return no(Code::OutcomeUnknown, "OUTCOME_UNKNOWN the record is in the WAL; its ratchet entry failed") }\n', '',
     'engine', 'trace', 'the ratchet entry of a commit'),
    ('S07_early_answer', 'store.rs', 'system-call order of a commit: step \'write stdout N\' comes before \'fullfsync airlock.wal 0\'', '        cut("c");\n',
     '        cut("c");\n        let _ = io::stdout().write_all(b"COMMITTED ").and_then(|()| io::stdout().flush());\n', 'engine', 'trace',
     'the order: no answer byte before the WAL sync'),
    ('S08_no_recovery_wal_sync', 'store.rs', 'system-call order of a recovery: missing step \'fullfsync airlock.wal 0\'', '        wal_ref.sync_all()?;\n', '', 'engine', 'trace', 'the WAL sync after a recovery cut'),
    ('S09_ignore_recovery_sync_error', 'store.rs', 'recovery with a failed sync of the WAL must refuse', '        wal_ref.sync_all()?;\n', '        let _ = wal_ref.sync_all();\n',
     'engine', 'trace', 'the result of the WAL sync in the recovery'),
    ('S10_no_init_wal_sync', 'store.rs', 'system-call order of init: missing step \'fullfsync airlock.wal 0\'', '        wal.write_all(&genesis)?;\n        wal.sync_all()?;\n', '        wal.write_all(&genesis)?;\n',
     'engine', 'trace', 'the sync of the genesis record'),
    ('S11_no_init_folder_sync', 'store.rs', 'system-call order of init: missing step \'fullfsync TMP 0\'', '        File::open(&tmp)?.sync_all()?;\n', '', 'engine', 'trace', 'the sync of the new store folder'),
    ('S12_no_init_parent_sync', 'store.rs', 'system-call order of init: missing step \'fullfsync PARENT 0\'', '        File::open(&parent)?.sync_all()?;\n', '', 'engine', 'trace',
     'the sync of the parent folder after the rename'),
    ('S13_no_init_policy_sync', 'store.rs', 'system-call order of init: missing step \'fullfsync policy-store-refunds.json 0\'', '            f.write_all(bytes)?;\n            f.sync_all()?;\n', '            f.write_all(bytes)?;\n',
     'engine', 'trace', 'the sync of a pinned policy file'),
    ('S14_init_keeps_tmp_after_failure', 'store.rs', 'init with a failed sync 1',
     '            let _ = std::fs::remove_dir_all(&tmp); // a refused init leaves no folder of its own\n', '', 'engine', 'trace',
     'the removal of the temporary folder of a refused init'),
    ('S15_ignore_init_wal_sync_error', 'store.rs', 'init with a failed sync 3', '        wal.sync_all()?;\n        File::open(&tmp)', '        let _ = wal.sync_all();\n        File::open(&tmp)',
     'engine', 'trace', 'the result of the sync of the genesis record'),
    ('S16_lock_after_wal_read', 'store.rs', 'a store file was read before the exclusive lock', LOCK_LINE + SCAN_LINE, SCAN_LINE + '    wal.lock()?;\n', 'engine', 'trace',
     'the rule that the lock comes before any read of a store file'),
    ('S17_shared_lock', 'store.rs', 'the lock of airlock.wal is not exclusive', LOCK_LINE, LOCK_LINE.replace('wal.lock()', 'wal.lock_shared()'), 'engine', 'trace',
     'the exclusiveness of the store lock'),
    ('S18_ignore_failed_answer', 'main.rs', 'no reader for the answers: exit 0, expected 20', '{ code } else { Code::DispatchFailed.num() }', '{ code } else { code }',
     'engine', 'dispatch', 'the DISPATCH_FAILED code for an answer that could not be written'),
    # the human's cosign tools (src/airlock/py/cosign_tool.py; no Node) and the answer of ssh-keygen; then the call of the
    # Dafny-compiled checker. N01 to N05 replace the copies of the deleted src/airlock/node/cosign.cjs (Apex addendum)
    ('N01_cosign_skip_mode_check', 'py/cosign_tool.py', "reason 'group or other' not in stderr", '    if st.st_mode & 0o077:\n', '    if False:\n', 'cosign', 'sign_key_mode_0640',
     'the D-1 rule mode & 0o077 == 0 of the key file'),
    ('N02_cosign_key_follows_link', 'py/cosign_tool.py', "exit 0 stdout b'", 'os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK', 'os.O_RDONLY | os.O_NONBLOCK',
     'cosign', 'sign_key_symlink', 'O_NOFOLLOW on the key file'),
    ('N03_cosign_accepts_invalid', 'cosign.rs', 'stand-in invalid-answer: expected REQUIRE_HUMAN_COSIGN COSIGN_INVALID',
     'if o == INVALID_OUT && r.err == INVALID_ERR && r.sent => Ok(false),', 'if o == INVALID_OUT && r.err == INVALID_ERR && r.sent => Ok(true),', 'engine', 'cosign_faults',
     'the INVALID answer for an incorrect signature (now the exact "incorrect signature" answer of ssh-keygen)'),
    ('N04_cosign_skip_uid_check', 'py/cosign_tool.py', "out b'ACCEPTED", '    if st.st_uid != euid:\n', '    if False:\n', 'cosign', 'sign_other_uid_seam',
     'the D-1 rule uid == euid of the key file'),
    ('N05_cosign_sign_skips_form', 'py/cosign_tool.py', "exit 0 stdout b'", '    f = parse_message(msg)\n',
     "    f = dict(store_id='', genesis_hash='', request_id='', pre_state_hash='', action='')\n", 'cosign', 'sign_refuses_wrong_form',
     'the strict message form before a signature (the engine builds the message itself; the sign tool checks it)'),
    ('N14_cosign_sign_passphrase_key', 'py/cosign_tool.py', "reason 'encrypted' not in stderr", "        if cipher != b'none' or kdf != b'none':\n", '        if False:\n', 'cosign',
     'sign_key_passphrase_fails_fast', 'the refusal of an encrypted key before ssh-keygen runs'),
    ('N06_booking_accept_on_reject', 'node/booking_check.cjs', "exit 0 stdout b'ACCEPT", "if (accepted === false) return finish(1, 'REJECT\\n', null);",
     "if (accepted === false) return finish(0, 'ACCEPT\\n', null);", 'node', 'booking_overbooking_reject', 'the REJECT answer of the checker'),
    ('N07_booking_no_model_pin', 'node/booking_check.cjs', 'booking_check.cjs must refuse a substituted model',
     "  if (digest !== PINNED_MODEL_SHA256) throw new Error('model SHA-256 ' + digest + ' is not the pinned ' + PINNED_MODEL_SHA256);\n", '', 'engine', 'pin',
     'the SHA-256 pin of the compiled model'),
    ('N08_booking_model_follows_link', 'node/booking_check.cjs', 'must refuse a symbolic link to the model',
     'fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW | fs.constants.O_NONBLOCK', 'fs.constants.O_RDONLY | fs.constants.O_NONBLOCK', 'engine', 'pin',
     'O_NOFOLLOW on the model file'),
    ('N09_booking_json_parse', 'node/booking_check.cjs', "exit 0 stdout b'ACCEPT", 'const input = parseInput(Buffer.concat(chunks));',
     "const input = JSON.parse(Buffer.concat(chunks).toString('latin1'));", 'node', 'booking_duplicate_key_refused', 'the strict scanner (JSON.parse takes the last duplicate)'),
    ('N10_booking_no_size_bound', 'node/booking_check.cjs', "exit 0 stdout b'ACCEPT", '    if (size > MAX_INPUT) {', '    if (false) {', 'node', 'booking_1MiB_plus_1_refused',
     'the 1 MiB input bound'),
    ('N11_booking_unknown_key', 'node/booking_check.cjs', "exit 1 stdout b'REJECT", "    if (!KEYS.includes(key)) bad('unknown key ' + JSON.stringify(key));\n", '', 'node',
     'booking_unknown_key_refused', 'the refusal of an unknown key'),
    # diff-policy (Dafny runs; the generator is a trusted assumption, limited by these controls)
    ('D01_generator_drops_upper_bound', 'py/diff_policy.py', 'old cross-check failed', "        parts.append('i.amount <= %s' % _num(high))", '        pass', 'diff', 'demo',
     'the max_amount bound in the generated Dafny model (the cross-check must see it)'),
    ('D02_crosscheck_always_passes', 'py/diff_policy.py', 'the cross-check did not fail', '    ok = spec_clearing().passed(result, members)', '    ok = True', 'diff', 'fault',
     'the result of the boundary cross-check'),
    ('D03_verdict_upgrade', 'py/diff_policy.py', 'verdict NO_CHOICE, not LINK_BROKEN', "    out = {'verdict': record['verdict'], 'scope': record['scope'],",
     "    out = {'verdict': 'NO_CHOICE' if record['verdict'] in ('UNDECIDED', 'LINK_BROKEN') else record['verdict'], 'scope': record['scope'],", 'diff', 'refused',
     'the rule that a verdict of spec_clearing is never upgraded'),
    ('D04_choice_not_flagged', 'py/diff_policy.py', 'exit 0, not 4', "        if 'CHOICE' in verdicts:\n            flags.append('CHOICE')\n", '', 'diff', 'choice',
     'the CHOICE result (exit 4)'),
    ('D05_loader_duplicate_key', 'py/policy_model.py', 'loader accepted bad-duplicate-key.json', "        if key in seen:\n            raise Malformed('duplicate key: ' + key)\n", '',
     'diff', 'loader', 'the refusal of a duplicate key in a policy file'),
    ('S19_init_no_undo', 'store.rs', 'init with a failed sync 5', '        if let Err(e) = parent_synced { return undo_init(dir, &tmp, &parent, genesis_len, e) }',
     '        if let Err(e) = parent_synced { return Err(e.into()) }', 'engine', 'trace', 'the undo of a store whose parent-folder sync failed after the rename'),
    # the checks that had no test before PART 2 (X01 to X07 of PART 1); X01 stays in SURVIVORS
    ('X02_fold_allows_overrefund', 'ledger.rs', 'crafted record (a refund above the remaining amount) must be CORRUPT_WAL',
     'if amount == 0 || amount > *remaining { return None }', 'if amount == 0 { return None }', 'engine', 'crafted',
     'the fold check amount <= remaining of a REFUND record'),
    ('X03_canonical_native_bound', 'verbs.rs', 'a binary that accepts above the remaining amount: expected BAD_FRAME',
     '        if amount > remaining || !REASONS.contains(&reason) { return no(Code::BadFrame, "BAD_FRAME the binary accepted what the native check refuses") }\n', '',
     'engine', 'native_bound', 'the native bound after an accept of the CakeML binary'),
    ('X04_helper_env_not_cleared', 'helpers.rs', 'the cosign helper saw a variable of the engine environment', '        .env_clear()\n', '', 'engine', 'helper_env',
     'the empty environment of a helper process'),
    ('X05_ratchet_last_not_highest', 'store.rs', 'a ratchet whose last entry is lower than its highest', 'floor = Some(floor.map_or(v, |f| f.max(v)));', 'floor = Some(v);',
     'engine', 'crafted', 'the highest ratchet entry as the floor'),
    ('X06_cosign_keygen_overwrites', 'py/cosign_tool.py', 'an existing 0600 file: exit 0', 'os.link(key, target, follow_symlinks=False)', 'os.replace(key, target)',
     'cosign', 'keygen_refuses_existing_0600', 'the exclusive link(2) of keygen (never overwrites)'),
    ('X07_diff_mismatch_ignored', 'py/diff_policy.py', '0 rows flagged', "'mismatch': got is not None and got != want", "'mismatch': False", 'diff', 'mismatch',
     'the TABLE_MISMATCH check'),
    ('N12_booking_no_pin_node_suite', 'node/booking_check.cjs', "exit 0 stdout b'ACCEPT",
     "  if (digest !== PINNED_MODEL_SHA256) throw new Error('model SHA-256 ' + digest + ' is not the pinned ' + PINNED_MODEL_SHA256);\n", '', 'node',
     'booking_model_substituted_near_runtime', 'the SHA-256 pin of the compiled model (in the node suite)'),
    ('N13_booking_link_node_suite', 'node/booking_check.cjs', "exit 0 stdout b'ACCEPT",
     'fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW | fs.constants.O_NONBLOCK', 'fs.constants.O_RDONLY | fs.constants.O_NONBLOCK', 'node',
     'booking_model_symlink_near_runtime', 'O_NOFOLLOW on the model file (in the node suite)'),
    # repairs of the review (proposals/forge2-goal20-sdk/REVIEW.md); one or more per repair
    ('R1a_node_pin', 'helpers.rs', 'a Node binary other than the pinned one', '    pinned(&NODE_CHECKED, node, pin, "Node binary")?;\n', '', 'engine', 'inventory',
     'the SHA-256 pin of the Node binary (finding 1; inventory only since the Apex addendum)'),
    ('R1b_seam_in_production', 'helpers.rs', 'with AIRLOCK_TEST_SSH_KEYGEN: expected REQUIRE_HUMAN_COSIGN COSIGN_INVALID',
     'if cfg!(kill_points) { std::env::var(var).ok() } else { None }', 'std::env::var(var).ok()', 'engine', 'seams',
     'the rule that the helper test seams exist only in the kill_points build (finding 1)'),
    ('R1c_binary_pin', 'helpers.rs', 'expected HELPER_FAILED (exit 22), got exit 23', '        pinned(&BINARY_CHECKED, b, REFUND_BINARY_SHA256, "refund binary")?;\n', '',
     'engine', 'canonical', 'the SHA-256 pin of the refund binary (finding 1)'),
    ('R2a_no_nonce', 'store.rs', 'the two genesis records must differ by their nonce', '    let nonce: String = nonce.iter().map(|b| format!("{b:02x}")).collect();',
     '    let nonce: String = "0".repeat(32);', 'engine', 'nonce', 'the random nonce of the genesis record (finding 2)'),
    ('R2b_genesis_not_in_message', 'verbs.rs', "expected COMMITTED (exit 0), got exit 11 'REQUIRE_HUMAN_COSIGN COSIGN_INVALID'", 'cosign_message(&s.l.store_id, s.l.genesis_hash, req, t[4], &action)',
     'cosign_message(&s.l.store_id, 0, req, t[4], &action)', 'engine', 'cosign', 'the genesis hash inside the signed cosign message (finding 2)'),
    ('R4a_small_order', 'pin.rs', "accepted: 0 'INITIALIZED", '    SMALL_ORDER.contains(&masked.as_str()) || y_ge_p', '    y_ge_p', 'engine', 'weakkey',
     'the small-order list of the weak-key check (finding 4)'),
    ('R4b_init_weak', 'store.rs', "accepted: 12 'MALFORMED_REQUEST GENESIS_NOT_FOLDABLE", '        if crate::pin::weak_ed25519(&raw) {', '        if false {', 'engine', 'weakkey',
     'the weak-key refusal of init (finding 4)'),
    ('R4c_weak_signature_r', 'cosign.rs', 'weak R: expected MALFORMED_REQUEST BAD_SIGNATURE WEAK_R, got exit 11', '    if weak_ed25519(&hex(&rs[..32])) { return Err("WEAK_R") }\n', '',
     'engine', 'cosign', 'the weak R refusal of a signature (finding 4; was the weak key refusal of cosign.cjs verify: the key is now refused at init and by the fold)'),
    ('R5a_lease_reopen', 'verbs.rs', "'OPEN_LEASE wh-2 100 t1 order-1': expected DUPLICATE_REQUEST_ID",
     '    if s.l.leases.contains_key(req) { return no(Code::Duplicate, "LEASE_USED', '    if false { return no(Code::Duplicate, "LEASE_USED', 'engine', 'lease_binding',
     'one lease per request id (finding 5)'),
    ('R5b_lease_unbound', 'verbs.rs', 'a verdict on another key must not name a close', '|(t, k)| s.l.leases.get(req).map_or(false, |l| l.binds(t, k))',
     '|(_, _)| s.l.leases.get(req).map_or(false, |l| l.is_open())', 'engine', 'lease_binding', 'the binding of a lease to its tenant and key (finding 5)'),
    ('R3_py_caller_rows', 'sdk/py/forge_airlock.py', 'thread changes the object: a row of another tenant was released', "        rows = sent  # from here on only the serialized text exists: what the engine checks is what is released\n        text = self._exchange(('READ %s %d\\n' % (tenant_id, len(rows))).encode('ascii') + b''.join(r.encode('ascii') + b'\\n' for r in sent))\n        if text == 'OK %d' % len(rows):\n            return Result('OK', line=text, rows=[json.loads(r) for r in sent])", "        caller, rows = rows, sent\n        text = self._exchange(('READ %s %d\\n' % (tenant_id, len(rows))).encode('ascii') + b''.join(r.encode('ascii') + b'\\n' for r in sent))\n        if text == 'OK %d' % len(rows):\n            return Result('OK', line=text, rows=caller)", 'sdk', 'py_read_tricks',
     'the release of parsed copies of the checked bytes, not the caller objects (finding 3)'),
    ('R3_ts_caller_rows', 'sdk/ts/forge_airlock.ts', 'TS replace_during_await: a row of another tenant was released', 'r.rows = rows.map((x) => JSON.parse(x)); return r; }',
     'r.rows = callerRows.slice(); return r; }', 'sdk', 'ts_read_tricks', 'the release of parsed copies of the checked bytes (finding 3)'),
    ('R7_py_row_bound', 'sdk/py/forge_airlock.py', 'more than 100000 rows: the SDK sent the read', "        if len(rows) > MAX_READ_ROWS:\n            raise LocalRefusal(", "        if False:\n            raise LocalRefusal(",
     'sdk', 'py_read_tricks', 'the 100000-row bound of read_scoped (finding 7)'),
    ('R7_ts_row_bound', 'sdk/ts/forge_airlock.ts', 'TS too_many', '    if (n > MAX_READ_ROWS) throw', '    if (false) throw', 'sdk', 'ts_read_tricks',
     'the 100000-row bound of readScoped (finding 7)'),
    # the Python SDK (sdk/py/forge_airlock.py) through tests/airlock/test_sdk.py
    ('P01_read_count_ignored', 'sdk/py/forge_airlock.py', 'STAND-IN ok-one: read_scoped released rows', "        if text == 'OK %d' % len(rows):",
     "        if text.split(' ')[0] == 'OK':", 'sdk', 'py_protocol', 'the exact `OK <n>` for the n rows sent'),
    ('P02_read_breach_releases_rows', 'sdk/py/forge_airlock.py', 'engine answer with 0 rows',
     "            return Result('TENANT_ISOLATION_BREACH', ' '.join(t[1:]), text, rows=[])", "            return Result('TENANT_ISOLATION_BREACH', ' '.join(t[1:]), text, rows=rows)",
     'sdk', 'py_read', 'zero rows after a TENANT_ISOLATION_BREACH'),
    ('P03_unknown_token_success', 'sdk/py/forge_airlock.py', 'STAND-IN unknown-token: the SDK returned a result',
     "    raise ProtocolError('UNKNOWN_ANSWER', 'first token %r is not an answer code for this request' % code[:40], line)", "    return Result('COMMITTED', '', line)",
     'sdk', 'py_garbage', 'the refusal of an unknown first token'),
    ('P04_lease_swallows_exception', 'sdk/py/forge_airlock.py', 'the handler exception did not propagate',
     '            return handler(Lease(self, request_id, int(t[2]), deadline_ms, tenant, key))',
     '            try:\n                return handler(Lease(self, request_id, int(t[2]), deadline_ms, tenant, key))\n            except Exception:\n                return None',
     'sdk', 'py_typed', 'the propagation of a handler exception (the lease stays open)'),
    ('P05_handler_before_lease', 'sdk/py/forge_airlock.py', 'the lease was not durable when the handler ran',
     "        text = self._send('OPEN_LEASE %s %s %s %s' % (_id('request_id', request_id), dl, _id('tenant', tenant), _id('key', key)))\n        t = _tok(text)\n"
     "        if t[0] == 'LEASE_OPENED':\n",
     "        early = handler(Lease(self, request_id, 0, deadline_ms, tenant, key))\n"
     "        text = self._send('OPEN_LEASE %s %s %s %s' % (_id('request_id', request_id), dl, _id('tenant', tenant), _id('key', key)))\n        t = _tok(text)\n"
     "        if t[0] == 'LEASE_OPENED':\n            return early\n", 'sdk', 'py_lease_durable', 'the order: the lease is durable before the handler runs'),
    ('P06_field_guard', 'sdk/py/forge_airlock.py', 'the field guard let', 'any(not (0x21 <= ord(ch) <= 0x7e) for ch in s)', 'any(not (0x00 <= ord(ch) <= 0x7e) for ch in s)',
     'sdk', 'py_protocol', 'the LF/CR/NUL guard of a field'),
    ('P07_line_guard', 'sdk/py/forge_airlock.py', 'the line guard let a line end through _send',
     "        if not isinstance(line, str) or any(not (0x20 <= ord(ch) <= 0x7e) for ch in line):", '        if not isinstance(line, str):', 'sdk', 'py_protocol',
     'the guard against a line end inside a request line'),
    ('P08_dead_engine_success', 'sdk/py/forge_airlock.py', 'after SIGKILL: expected EngineDead, got a result', '        text = self._send(line)\n        return self._guard(',
     "        try:\n            text = self._send(line)\n        except EngineDead:\n            return Result('COMMITTED', line='')\n        return self._guard(",
     'sdk', 'py_kill', 'EngineDead for a dead serve process (never a result)'),
    ('P09_stale_as_committed', 'sdk/py/forge_airlock.py', 'stale: expected STALE_STATE_HASH, got Result(COMMITTED',
     "        return Result(code, detail, line, lease_closed=closed,", "        return Result('COMMITTED' if code in ('STALE_STATE_HASH', 'DUPLICATE_REQUEST_ID') else code, detail, line, lease_closed=closed,",
     'sdk', 'py_typed', 'the typed STALE_STATE_HASH and DUPLICATE_REQUEST_ID results'),
    ('P10_commit_line_not_checked', 'sdk/py/forge_airlock.py', 'STAND-IN other-request: the SDK returned a result',
     "        ok = (len(t) >= 8 and t[1] == request_id and DIGITS_RE.match(t[2]) and HASH_RE.match(t[3])\n              and t[4] == verb and t[5] == tenant and t[6] == key and t[7] == request_id)",
     '        ok = (len(t) >= 8 and DIGITS_RE.match(t[2]) and HASH_RE.match(t[3]))', 'sdk', 'py_garbage', 'the check that a COMMITTED line names this request'),
    # the TypeScript SDK (sdk/ts/forge_airlock.ts) through the ts_* cases
    ('T01_unknown_token_success', 'sdk/ts/forge_airlock.ts', 'TS STAND-IN unknown-token',
     "  throw new ProtocolError('first token ' + JSON.stringify(code.slice(0, 40)) + ' is not an answer code for this request', line);",
     "  return new Result('COMMITTED' as Code, '', line);", 'sdk', 'ts_garbage', 'the refusal of an unknown first token'),
    ('T02_read_count_ignored', 'sdk/ts/forge_airlock.ts', 'TS STAND-IN ok-one', "      if (a === 'OK ' + rows.length) {", "      if (a.startsWith('OK')) {", 'sdk', 'ts_protocol',
     'the exact `OK <n>` for the n rows sent'),
    ('T03_read_breach_releases_rows', 'sdk/ts/forge_airlock.ts', 'TS missing:',
     "      if (t[0] === 'OK') throw new ProtocolError('OK for another row count', a);\n      return refusal(a, t, ['TENANT_ISOLATION_BREACH']);",
     "      if (t[0] === 'OK') throw new ProtocolError('OK for another row count', a);\n      { const r = refusal(a, t, ['TENANT_ISOLATION_BREACH']); r.rows = rows.slice(); return r; }",
     'sdk', 'ts_read', 'zero rows after a TENANT_ISOLATION_BREACH'),
    ('T04_lease_swallows_exception', 'sdk/ts/forge_airlock.ts', 'TS throws', '      return await handler(new Lease(this, requestId, Number(t[2]), dl, tenant, key));',
     '      try { return await handler(new Lease(this, requestId, Number(t[2]), dl, tenant, key)); } catch { return undefined as T; }', 'sdk', 'ts_lease',
     'the propagation of a handler exception (the lease stays open)'),
    ('T05_stale_as_committed', 'sdk/ts/forge_airlock.ts', 'TS stale: expected STALE_STATE_HASH', '    const r = new Result(code as Code, detail, line);',
     "    const r = new Result((code === 'STALE_STATE_HASH' || code === 'DUPLICATE_REQUEST_ID' ? 'COMMITTED' : code) as Code, detail, line);", 'sdk', 'ts_typed',
     'the typed STALE_STATE_HASH and DUPLICATE_REQUEST_ID results'),
    # honesty of the demo and the fuzz pass: a changed ENGINE must make them fail (they observe the engine; nothing is hardcoded)
    ('H01_demo_sees_no_cas', 'verbs.rs', '0 STALE_STATE_HASH', '    if k.hash != pre { return no(Code::Stale, hx(k.hash)) }\n', '', 'demo', 'D1',
     'the compare-and-swap (the demo race must see it)'),
    ('H02_demo_money_from_wal', 'verbs.rs', 'money_leaked_cents_from_wal=8000',
     '            Verdict::Reject(code) => return verdict(s, req, Code::RejectedPolicy, code),', '            Verdict::Reject(_) => {}', 'demo', 'money',
     'the policy refusal of a parametric REFUND (the leaked money must show in the scoreboard, from the WAL)'),
    ('H03_demo_sees_no_cosign', 'verbs.rs', 'other key: COMMITTED',
     '                if Some(embedded) != cosign::pinned_key(&pk) { return verdict(s, req, Code::RequireHumanCosign, "COSIGN_INVALID") }\n'
     '                let msg = cosign_message(&s.l.store_id, s.l.genesis_hash, req, t[4], &action);\n'
     '                if !cosign::verify(&ctx.dir, &pk, sig, &msg)? { return verdict(s, req, Code::RequireHumanCosign, "COSIGN_INVALID") }\n', '', 'demo', 'D4',
     'the cosign verification: the key compare and the ssh-keygen call (the demo must see it)'),
    # the one review of the native cosign (owner decisions F2, F4, F6)
    ('F2_kill_build_beside_engine', 'bin/forge-airlock', 'a binary in build/airlock/ accepts the test seams',
     "'src/airlock/main.rs', '-o', 'build/silicon/test/airlock-engine-kill']]", "'src/airlock/main.rs', '-o', 'build/airlock/airlock-engine-kill']]", 'sdk',
     'py_build_separation', 'the test-only folder of the kill-points build (it was written beside the production engine)'),
    ('F4_root_not_walked', 'cosign.rs', 'cosign-info: the walk of the ssh-keygen path (from /)', '    let mut parts: Vec<&Path> = p.ancestors().collect();',
     '    let mut parts: Vec<&Path> = p.ancestors().filter(|a| a.parent().is_some()).collect();', 'engine', 'cosign_faults',
     'the check of the root folder / in the walk of the ssh-keygen path'),
    ('F6_sign_lines_not_crosschecked', 'py/cosign_tool.py', "exit 0 stdout b'", '    if t[3] != request_id or t[4] != pre:\n', '    if False:\n', 'cosign',
     'sign_action_request_id_differs', 'the cross-check of the request id and pre-state hash lines with the action before a signature'),
    # cosign through /usr/bin/ssh-keygen (Apex addendum): the native checks before and around the call
    ('C01_embedded_key_not_compared', 'verbs.rs', 'wrong key: expected REQUIRE_HUMAN_COSIGN COSIGN_INVALID, got exit 22', 'if Some(embedded) != cosign::pinned_key(&pk) {', 'if false {',
     'engine', 'cosign', 'the comparison of the key inside the signature with the pinned key'),
    ('C02_namespace_not_checked', 'cosign.rs', 'namespace: expected MALFORMED_REQUEST BAD_SIGNATURE NAMESPACE', '    if w.string() != Some(NAMESPACE.as_bytes()) { return Err("NAMESPACE") }\n',
     '    let _ = w.string();\n', 'engine', 'cosign', 'the namespace check of the SSHSIG blob'),
    ('C03_hash_algorithm_not_checked', 'cosign.rs', 'hash algorithm sha256: expected MALFORMED_REQUEST BAD_SIGNATURE HASH_ALGORITHM, got exit 0',
     '    if w.string() != Some(HASH_ALG.as_bytes()) { return Err("HASH_ALGORITHM") }\n', '    let _ = w.string();\n', 'engine', 'cosign', 'the sha512 rule of the SSHSIG blob'),
    ('C04_exit_status_ignored', 'cosign.rs', 'stand-in exit-1: expected HELPER_FAILED', '(Some(0), true, o) if o == good.as_bytes() => Ok(true),', '(_, true, o) if o == good.as_bytes() => Ok(true),',
     'engine', 'cosign_faults', 'the exit status 0 of ssh-keygen for a valid signature'),
    ('C05_invalid_stderr_not_checked', 'cosign.rs', 'stand-in other-fault: expected HELPER_FAILED', 'if o == INVALID_OUT && r.err == INVALID_ERR && r.sent', 'if o == INVALID_OUT && r.sent',
     'engine', 'cosign_faults', 'the exact "incorrect signature" text that separates an invalid signature from a tool fault'),
    ('C06_tmp_not_private', 'cosign.rs', "got exit 22 'HELPER_FAILED TMP_NOT_PRIVATE", 'DirBuilder::new().mode(0o700).create(&dir)', 'DirBuilder::new().mode(0o755).create(&dir)',
     'engine', 'cosign_faults', 'the private 0700 cosign folder'),
    ('C07_root_owner_not_checked', 'cosign.rs', 'untrusted program: expected HELPER_FAILED SSH_KEYGEN_UNTRUSTED NOT_ROOT_OWNED',
     '        if m.uid() != 0 { return Err(format!("NOT_ROOT_OWNED {} uid {}", part.display(), m.uid())) }\n', '', 'engine', 'cosign_faults',
     'the root-ownership check of the ssh-keygen path'),
    ('C08_symlink_not_checked', 'cosign.rs', 'symbolic link on the path: expected HELPER_FAILED SSH_KEYGEN_UNTRUSTED SYMLINK',
     '        if m.file_type().is_symlink() { return Err(format!("SYMLINK {}", part.display())) }\n', '', 'engine', 'cosign_faults',
     'the symbolic-link check of the ssh-keygen path'),
    ('C09_s_not_canonical', 'cosign.rs', 'S + L: expected MALFORMED_REQUEST BAD_SIGNATURE S_NOT_CANONICAL, got exit 0', '    if s_not_canonical(&rs[32..]) { return Err("S_NOT_CANONICAL") }\n', '',
     'engine', 'cosign', 'the S < L rule (ssh-keygen 10.3 accepts S + L)'),
    ('C10_base64_not_canonical', 'cosign.rs', 'non-canonical base64: expected MALFORMED_REQUEST BAD_SIGNATURE BASE64',
     '    if acc != 0 { return None } // non-zero unused bits: a second spelling of the same bytes\n', '', 'engine', 'cosign', 'the canonical spelling of the strict base64'),
    ('C11_leftover_not_removed', 'cosign.rs', 'leftover folder: expected COMMITTED', 'Ok(m) if m.file_type().is_dir() => fs::remove_dir_all(&dir).map_err(io)?,',
     'Ok(m) if m.file_type().is_dir() => {}', 'engine', 'cosign_faults', 'the removal of a leftover cosign folder (a crash) at the next verification'),
    ('C12_tmp_kept_after_use', 'cosign.rs', 'the private cosign folder stayed after use', '    let _ = fs::remove_dir_all(&dir); // a failure here is cleaned at the next verification\n', '',
     'engine', 'cosign', 'the removal of the cosign folder after use'),
    ('H04_demo_sees_failover', 'verbs.rs', 'failover: REJECTED_POLICY NO_TRANSITION', '} else if cur_in && pair != *held {', '} else if false {', 'demo', 'D5',
     'the PROCESSOR_IN_FLIGHT refusal (the demo must see it)'),
    ('H05_demo_sees_read_breach', 'verbs.rs', 'py: OK', '(J::Obj(_), Some(J::Str(t))) if t == tenant => Ok(()),', '(J::Obj(_), Some(J::Str(_))) => Ok(()),',
     'demo', 'D6', 'the read airlock (the demo must see it)'),
    ('H06_fuzz_sees_no_cas', 'verbs.rs', 'burst:', '    if k.hash != pre { return no(Code::Stale, hx(k.hash)) }\n', '', 'fuzz', 'I8_burst_and_storm',
     'the compare-and-swap (the fuzz burst must see it)'),
    ('H07_fuzz_sees_reason_cap', 'policy.rs', 'I2_reason_caps VIOLATED', '            if !within { capped = true; continue }\n', '', 'fuzz', 'I2_reason_caps',
     'the fact-bound reason cap (the fuzz oracle must see it)'),
]

# Changed copies that the suites do NOT detect (findings, not kills). Same form without the reason text. They run in
# case mutations; the result is recorded; they never count as killed, and a kill of one of them is reported.
SURVIVORS = [
    ('X01_helper_input_not_checked', 'helpers.rs', 'sent: s == Some(vec![1])', 'sent: true', 'engine', 'inventory',
     'the rule that a helper read all of its input. No test can see it: a request line is at most 65,536 bytes, so every helper input fits '
     'into one pipe buffer (64 KiB on macOS), and a helper that does not read cannot make the write fail in a repeatable way'),
    ('R8_ts_sparse_guard', 'sdk/ts/forge_airlock.ts',
     "        if (!Object.prototype.hasOwnProperty.call(callerRows, i) || callerRows[i] === undefined) throw new LocalRefusal('row ' + i + ': a hole or undefined');\n",
     '', 'sdk', 'ts_read_tricks',
     'the hole/undefined guard of readScoped (review finding 8). Not observable alone: jsonText refuses an undefined entry with the same '
     'local TENANT_ISOLATION_BREACH, so the index loop and jsonText are two layers and the suite cannot tell them apart'),
    ('N15_sign_key_binding', 'py/cosign_tool.py', '    if check_sig_token(token) != blob:\n', '    if check_sig_token(token) is None:\n', 'cosign', 'sign_verify_valid',
     'the binding of the second open (ssh-keygen opens the key file again by path) to the checked descriptor. Not observable in a '
     'repeatable way: it needs the key file to be replaced between the two opens (a race); no case claims it'),
]

CLAIMS = {
    'proved_core': {
        'label': 'PROVED CORE',
        'items': [
            'The decision of a REFUND on a key whose policy has "profile": "canonical-refund": the CakeML ARM64 refund binary b8ed5ec2...7bb8 '
            'decides; scope exactly PROTOCOL.md section 6.1 (one key = one charge; the three approved reasons; the engine sets the three flags; '
            'amount 0 refused natively). The HOL theorems about the binary have open premises (M1 is OPEN). This record runs no HOL.',
            'The source of the inventory checker: proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy, VerifyCertifiedBooking ensures '
            'ok == Accepts(...), verified by the pinned Dafny 4.11.0 in case build. The Dafny JavaScript compiler, its runtime, bignumber.js and '
            'Node are trusted.',
            'NO_CHOICE / CHOICE of diff-policy: spec_clearing verdicts for the GENERATED Dafny model of a money policy only. The JSON-to-Dafny '
            'generator is a trusted assumption (owner decision), limited by the boundary cross-check and the negative controls.',
        ],
        'evidence_in_this_record': 'the checker model rebuilt and equal to its record (case build); the diff-policy suite (case suite)',
    },
    'native_check': {
        'label': 'NATIVE CHECK',
        'items': [
            'Everything in Rust (src/airlock/*.rs): WAL, fold, compare-and-swap, tenant isolation, request ids, parametric money rules, saga '
            'table, native Accepts, cosign wiring, read airlock, leases, recovery. NOT proved.',
            'Everything in JavaScript (src/airlock/node/booking_check.cjs) beyond the compiled model: the strict scanner, the pin. NOT proved.',
            'Everything in Python (src/airlock/py/*.py): the scenario table, the evaluator, the generator, the fuzz oracle, the human\'s cosign '
            'tools (the D-1 key rules, the message form). NOT proved.',
            'The cosign wiring (src/airlock/cosign.rs): strict base64, the SSHSIG form, the key compare, weak R, S < L, the checks of the '
            'ssh-keygen path, the private folder, the two exact answers of ssh-keygen. NOT proved.',
            'The SDKs (sdk/py/forge_airlock.py, sdk/ts/forge_airlock.ts) and the dispatcher bin/forge-airlock: not trusted for a write '
            'decision; they encode requests and map answers. NOT proved.',
        ],
    },
    'finite_test': {
        'label': 'FINITE TEST',
        'items': [
            'The four suites (case suite), the changed copies (case mutations), the eight disasters of the demo (case disasters) and the '
            'seeded fuzz pass (case fuzz) on one machine. A test count is not a proof. Stripe and PayPal in the demo are LOCAL FAKE processors.',
            'System-call order observed with a dyld interposer for the traced init, commit, refusal, lease close and recovery only, not for '
            'every request. A SIGKILL is not a power loss.',
        ],
    },
    'trusted_assumptions': [
        'macOS kernel and drive: fcntl(F_FULLFSYNC) returns 0 only after the drive was asked to store the data; flock is exclusive and is '
        'released at process end; APFS keeps what F_FULLFSYNC reported. NOT tested at power loss.',
        'rustc 1.92.0, LLVM and the Rust standard library; Node 24.3.0 (the booking checker only; no Node runs for a cosign); the Dafny '
        '4.11.0 compiler and JavaScript runtime; bignumber.js 9.3.1 loaded from the pinned node_modules (package-lock.json; checked by '
        'scripts/javascript_env.py, not by the model pin); Python 3.10.11.',
        'The system OpenSSH is a trusted assumption: /usr/bin/ssh-keygen (OpenSSH_10.3p1 with LibreSSL 3.3.6 on the measured machine) '
        'verifies every cosign signature (Ed25519). It is checked (owner uid 0, no group or other write bit, no symbolic link on its path) '
        'but NOT pinned: an OS update can change it without a change of any store. OpenSSH with LibreSSL is now in the trusted base for '
        'cosign in place of Node/V8: smaller and widely reviewed, but not zero. Its answers are mapped strictly: only two exact results '
        'count, anything else is HELPER_FAILED.',
        'The JSON-to-Dafny generator of diff_policy.py (owner decision, Goal 20 plan line 8).',
        'Trust boundary (review finding 1): every rule holds only against a caller that reaches the store THROUGH the engine. A process that '
        'can write the store folder can append records itself, and one that can start its own engine build on the store can ignore every '
        'check. "The agent cannot self-cosign" needs the private key out of the agent\'s reach AND no agent write access to the store folder '
        'and no way for the agent to run another engine on it. In the demo all three belong to one OS user: it shows the mechanism only.',
        'The opener of a key is trusted (review finding 6): the money caps rest on the original amount and the facts that the opener '
        'chooses; the tenant field is not authenticated.',
        'The read airlock checks only the TOP-LEVEL tenant_id of the rows passed to it (review finding 10); a nested row of another tenant '
        'passes. It sees only the rows passed to it.',
        'What pins what: the engine embeds the Node booking helper (include_str!, no helper file is read at run time) and pins the refund '
        'binary (SHA-256 b8ed5ec2...7bb8); the store pins the SHA-256 of the Node binary in its genesis record at init (inventory only); '
        'booking_check.cjs pins the compiled model (e705ec49...85f4); the genesis record pins the policy files (FNV-1a-128, not '
        'cryptographic) and the cosign key; bin/forge-airlock re-checks its private refund copy; nothing pins the engine binary itself, '
        '/usr/bin/ssh-keygen or bignumber.js. A file swapped between its check and its exec is not detected. The test seams '
        'AIRLOCK_TEST_HELPERS, AIRLOCK_TEST_UNPINNED_BINARY, AIRLOCK_TEST_SSH_KEYGEN and AIRLOCK_TEST_UNTRUSTED_SSH_KEYGEN exist only in '
        'the kill_points build.',
        'Cosign: an agent that runs as the same OS user as the key owner can read a 0600 key file; "the agent cannot self-cosign" holds only '
        'when the private key is outside its reach (and see the trust boundary above). Weak (small-order or non-canonical) Ed25519 keys '
        'and signature R values, and S >= L, are refused natively.',
        'FNV-1a-128 collisions can be computed (review finding 11): the compare-and-swap is a concurrency control, not a boundary against an '
        'attacker. A restore of the WAL and the ratchet together is not detected.',
    ],
}


class Failed(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Failed(message)


def run(argv, cwd=ROOT, env=None, timeout=3600, **options):
    return subprocess.run([str(a) for a in argv], cwd=cwd, capture_output=True, text=True, errors='replace', env=env, timeout=timeout, **options)


def node_path():
    return shutil.which('node')


def toolchain():
    rustc = run(['rustc', '-V'])
    cc = run([CC, '--version'])
    pinned_python = read_json(ROOT / 'toolchain/pins.json')['python']['version']
    try:
        pins = javascript_env.check()
    except RuntimeError as error:
        raise RuntimeError('TOOLCHAIN_ERROR: ' + str(error))
    seen = {'rustc': rustc.stdout.strip(), 'cc': cc.stdout.splitlines()[0].strip() if cc.stdout else '', 'python': platform.python_version(),
            'machine': platform.system() + ' ' + platform.machine(), 'node': run([node_path(), '--version']).stdout.strip()}
    want = {'rustc': RUSTC_VERSION, 'cc': CC_VERSION, 'python': pinned_python, 'machine': 'Darwin arm64', 'node': 'v' + pins['node_version']}
    if seen != want:
        raise RuntimeError('TOOLCHAIN_ERROR: observed %r, pinned %r' % (seen, want))
    return dict(seen, node_executable_sha256=pins['node_executable_sha256'])


def subject_files():
    names = list(SUBJECT)
    for pattern in SUBJECT_GLOBS:
        names += [p.relative_to(ROOT).as_posix() for p in ROOT.glob(pattern)]
    return sorted(set(names))


def snapshot():
    return {name: digest((ROOT / name).read_bytes()) for name in subject_files()}


def dafny_lock_path():
    return Path(os.environ.get('FORGE_DAFNY_LOCK') or ROOT / BUILD / 'locks/dafny')


@contextmanager
def dafny_lock():
    """The Dafny lock: a folder made with mkdir. One Dafny process at a time on this machine."""
    lock = dafny_lock_path()
    lock.parent.mkdir(parents=True, exist_ok=True)
    start = time.monotonic()
    while True:
        try:
            lock.mkdir()
            break
        except FileExistsError:
            require(time.monotonic() - start < 7200, 'DAFNY_LOCK: not free after 2 hours')
            time.sleep(2)
    try:
        yield
    finally:
        lock.rmdir()


# ------------------------------------------------------------------------------------------------------------- build
def strip_rust_comments(text):
    out = []
    for line in text.splitlines():
        code, quoted, i = '', False, 0
        while i < len(line):
            c = line[i]
            if c == '"' and (i == 0 or line[i - 1] != '\\'):
                quoted = not quoted
            if not quoted and line.startswith('//', i):
                break
            code += c
            i += 1
        out.append(code)
    return out


def rust_rules():
    uses, extern, unsafe = [], [], []
    for name in RUST:
        text = (ROOT / ENGINE_DIR / name).read_text()
        code = strip_rust_comments(text)
        local = set(re.findall(r'\b(?:enum|struct|mod|trait|type|fn|const|static)\s+([A-Za-z_]\w*)', '\n'.join(code)))
        for n, line in enumerate(code):
            if re.search(r'\bunsafe\b', line):
                unsafe.append('%s:%d' % (name, n + 1))
            if re.search(r'\bextern\s+crate\b', line):
                extern.append('%s:%d' % (name, n + 1))
            found = re.match(r'\s*(?:pub\s+)?use\s+([A-Za-z_]\w*)', line)
            if found:
                first = found.group(1)
                uses.append('%s: %s' % (name, line.strip()))
                require(first in ('std', 'core', 'alloc', 'crate', 'self', 'super') or first in local,
                        'SOURCE: %s: `use` from %r, not std, crate, self, super or an item of the file' % (name, first))
    first_line = (ROOT / ENGINE_DIR / 'main.rs').read_text().splitlines()[0]
    require(first_line == '#![forbid(unsafe_code)]', 'SOURCE: line 1 of main.rs is not #![forbid(unsafe_code)]')
    require(unsafe == [], 'SOURCE: the word unsafe in code: %r' % unsafe)
    require(extern == [], 'SOURCE: extern crate: %r' % extern)
    cargo = sorted(p.relative_to(ROOT).as_posix() for p in list((ROOT / 'src').rglob('Cargo.*')) + [ROOT / 'Cargo.toml', ROOT / 'Cargo.lock'] if p.exists())
    require(cargo == [], 'SOURCE: a Cargo file exists: %r' % cargo)
    return {'first_line': first_line, 'uses': sorted(uses), 'unsafe_in_code': 0, 'extern_crate': 0, 'cargo_files': 0}


def node_rules():
    """The Node helpers and the TypeScript files: every require() names a node: built-in; ts_part.ts may also load the
    TS SDK by its one computed path. No import statement."""
    seen = {}
    for name in NODE_HELPERS + TS_FILES:
        text = (ROOT / name).read_text()
        code = '\n'.join(line for line in text.splitlines() if not line.lstrip().startswith('//'))
        literal = re.findall(r"\brequire\(\s*'([^']*)'\s*\)", code)
        computed = len(re.findall(r'\brequire\(', code)) - len(literal)
        allowed = 1 if name.endswith('ts_part.ts') and code.count(TS_SDK_REQUIRE) == 1 else 0
        require(computed == allowed, 'SOURCE: %s: %d require() with no string literal' % (name, computed))
        require(all(m.startswith('node:') for m in literal), 'SOURCE: %s requires a module that is not a node: built-in: %r' % (name, literal))
        require(not re.search(r'^\s*import\b|\bimport\(', code, re.M), 'SOURCE: %s has an import statement' % name)
        seen[name] = sorted(set(literal)) + (['sdk/ts/forge_airlock.ts (computed path)'] if allowed else [])
    return seen


def python_rules():
    allowed = set(sys.stdlib_module_names) | REPO_MODULES
    seen = {}
    for name in PYTHON_FILES:
        tree = ast.parse((ROOT / name).read_text(), name)
        mods = set()
        for node in ast.walk(tree):
            if isinstance(node, ast.Import):
                mods |= {a.name.split('.')[0] for a in node.names}
            elif isinstance(node, ast.ImportFrom):
                require(node.level == 0, 'SOURCE: %s has a relative import' % name)
                mods.add(node.module.split('.')[0])
        bad = sorted(mods - allowed)
        require(bad == [], 'SOURCE: %s imports %r (not stdlib, not a repository module)' % (name, bad))
        seen[name] = sorted(mods)
    return seen


def compile_engine(src_dir, output, kill_points=False):
    command = RUSTC + (['--cfg', 'kill_points'] if kill_points else []) + [Path(src_dir) / 'main.rs', '-o', output]
    return run(command)


def copy_rust(dest, src=None):
    """The engine sources: the .rs files and the two Node helpers that helpers.rs compiles in (include_str!)."""
    src = src or ROOT / ENGINE_DIR
    (dest / 'node').mkdir(parents=True)
    for name in RUST:
        shutil.copyfile(src / name, dest / name)
    for name in NODE_HELPERS:
        shutil.copyfile(src / 'node' / Path(name).name, dest / 'node' / Path(name).name)
    return dest


def build(work):
    """Source rules, the unsafe control, the two engine builds, the interposer, the refund binary, the checker model."""
    work.mkdir(parents=True)
    rules = {'rust': rust_rules(), 'node_requires': node_rules(), 'python_imports': python_rules()}
    built = {}
    (work / 'test').mkdir()  # the kill-points build lies apart from the engine folder (review F2)
    for kill, out in ((False, 'airlock-engine'), (True, 'test/airlock-engine-kill')):
        done = compile_engine(ROOT / ENGINE_DIR, work / out, kill)
        require(done.returncode == 0 and done.stdout == '' and done.stderr == '', 'BUILD: %s gave exit %d\n%s' % (out, done.returncode, done.stderr[-2000:]))
        built[out] = {'command': [str(x) for x in RUSTC] + (['--cfg', 'kill_points'] if kill else []) + [ENGINE_DIR + '/main.rs', '-o', '<attempt>/' + out],
                      'exit': 0, 'warnings': 0}
    control = copy_rust(work / 'unsafe_control')
    with open(control / 'main.rs', 'a') as f:
        f.write('\nfn control() -> u8 { unsafe { *(1 as *const u8) } }\n')
    refused = compile_engine(control, work / 'unsafe_control/out')
    require(refused.returncode == 1 and 'unsafe' in refused.stderr and not (work / 'unsafe_control/out').exists(), 'CONTROL: a copy with an unsafe block compiled')
    shutil.rmtree(control)
    dylib = run([CC] + CC_FLAGS + ['-o', work / 'interpose.dylib', INTERPOSER])
    require(dylib.returncode == 0, 'BUILD: the test interposer gave exit %d\n%s' % (dylib.returncode, dylib.stderr))
    require(digest((ROOT / ARTIFACT).read_bytes()) == ARTIFACT_SHA256, 'BINARY: the tracked refund binary is not b8ed5ec2...')
    private = work / 'bin'
    private.mkdir(mode=0o700)
    shutil.copyfile(ROOT / ARTIFACT, private / 'refund')
    (private / 'refund').chmod(0o700)
    probe = subprocess.run([str(private / 'refund')], input=b'(charge-1 request-1 100 60 True True True 40 returned_item)', capture_output=True,
                           env={'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}, timeout=60)
    require(probe.returncode == 0 and probe.stdout == b'(refund-result-v1 True 40 returned_item charge-1 request-1 1)' and probe.stderr == b'',
            'BINARY: the refund binary did not run natively as recorded: exit %d %r' % (probe.returncode, probe.stdout))
    with dafny_lock():
        checker = run([sys.executable, '-B', 'src/airlock/node/build_checker.py'])
    (work / 'build_checker.log').write_text(checker.stdout + checker.stderr)
    try:
        record = json.loads(checker.stdout)
    except ValueError:
        record = {}
    require(checker.returncode == 0 and record.get('equal_to_record') is True and digest((ROOT / MODEL).read_bytes()) == MODEL_SHA256
            and record.get('source_sha256') == record.get('recorded_source_sha256'),
            'MODEL: build_checker.py exit %d; the model is not %s\n%s' % (checker.returncode, MODEL_SHA256, checker.stdout[-1500:]))
    (work / 'checker').mkdir()
    shutil.copyfile(ROOT / MODEL, work / 'checker/model.cjs')  # the engine folder of the attempt: airlock-engine(-kill) + checker/model.cjs
    copy = ROOT / REFUND_COPY
    if not copy.is_file() or digest(copy.read_bytes()) != ARTIFACT_SHA256 or (copy.stat().st_mode & 0o777) != 0o700:
        copy.parent.mkdir(parents=True, exist_ok=True)
        tmp = copy.with_name('refund-binary.tmp')
        shutil.copyfile(ROOT / ARTIFACT, tmp)
        tmp.chmod(0o700)
        os.replace(tmp, copy)
    require(digest(copy.read_bytes()) == ARTIFACT_SHA256 and (copy.stat().st_mode & 0o777) == 0o700, 'BINARY: the dispatcher copy is not the pinned 0700 binary')
    return {'source_rules': rules, 'engine_builds': built,
            'dispatcher_refund_copy': {'path': REFUND_COPY, 'sha256': ARTIFACT_SHA256, 'mode': '0700'},
            'unsafe_control': {'what': 'the same sources with one unsafe block in main.rs, the same command', 'compile_exit': refused.returncode},
            'interposer': {'command': [CC] + CC_FLAGS + ['-o', '<attempt>/interpose.dylib', INTERPOSER], 'exit': 0},
            'refund_binary': {'path': ARTIFACT, 'sha256': ARTIFACT_SHA256, 'ran_natively_with_recorded_answer': True},
            'checker_model': {'command': ['python3', '-B', 'src/airlock/node/build_checker.py'], 'exit': 0, 'source': CHECKER_SOURCE,
                              'source_sha256': record.get('source_sha256'), 'verify_exit': record.get('verify_exit'),
                              'verify_last_line': record.get('verify_last_line'), 'build_exit': record.get('build_exit'), 'module_sha256': MODEL_SHA256,
                              'equal_to_record': True}}


# ------------------------------------------------------------------------------------------------------------- suites
LINE = {
    'engine': re.compile(r'^(PASS|FAIL) (\S+)\s+[\d.]+s (.*)$'),
    'sdk': re.compile(r'^(PASS|FAIL) (\S+)\s+[\d.]+s (.*)$'),
    'node': re.compile(r'^(PASS|FAIL|NOT RUN)\s+(\S+): (.*)$'),
    'cosign': re.compile(r'^(PASS|FAIL|NOT RUN)\s+(\S+): (.*)$'),
    'diff': re.compile(r'^(\S+)\s+(PASS|FAIL|NOT RUN)\s+exits=\[([^\]]*)\] dafny_processes=\d+ wall=[\d.]+s \| (.*)$'),
}


def report_results(kind, report):
    """The per-case view of the demo or fuzz JSON: {case: (status, detail, None)}."""
    out = {}
    if kind == 'demo':
        for row in report.get('disasters', []):
            out['D%d' % row['disaster']] = (row['result'], row['observed'], None)
        leaked, over = report.get('money_leaked_cents_from_wal'), report.get('keys_refunded_above_original')
        out['money'] = ('PASS' if leaked == 0 and not over else 'FAIL', 'money_leaked_cents_from_wal=%r keys_refunded_above_original=%r' % (leaked, over), None)
    else:
        for name, state in report.get('invariants', {}).items():
            out[name] = ('PASS' if state == 'HELD' else 'FAIL', '%s %s; violations: %s' % (name, state, ' | '.join(report.get('violations', []))[:600]), None)
    out['result'] = (report.get('result', 'NOT RUN'), 'violations: ' + ' | '.join(report.get('violations', []))[:600], None)
    return out


def run_suite(kind, root, cases, work, engines, interposer, timeout=7200):
    """Starts one suite (or the demo, or the fuzz pass) as its own process. Returns (exit code, {case: (status, detail,
    exits)}, printed text). For the demo and the fuzz pass the cases come from their JSON file (work/<kind>.json)."""
    work.mkdir(parents=True, exist_ok=True)
    engine_dir = Path(engines[0]).parent
    out_json = work / (kind + '.json')
    if kind == 'engine':
        argv = [sys.executable, '-B', root / ENGINE_SUITE, engines[0], engines[1], '--node', node_path(), '--work', work, '--interposer', interposer]
    elif kind == 'node':
        argv = [sys.executable, '-B', root / NODE_SUITE, node_path(), '--model', ROOT / MODEL]
    elif kind == 'cosign':
        argv = [sys.executable, '-B', root / COSIGN_SUITE, engines[0]]
    elif kind == 'diff':
        argv = [sys.executable, '-B', root / DIFF_SUITE, '--engine', engines[0]]
    elif kind == 'sdk':
        argv = [sys.executable, '-B', root / SDK_SUITE, '--engine-dir', engine_dir, '--kill-engine', engines[1], '--node', node_path()]
    elif kind == 'demo':
        argv = [sys.executable, '-B', root / DEMO, '--engine-dir', engine_dir, '--node', node_path(), '--json', out_json, '--measurements', work / 'demo-measurements.json']
    else:
        argv = [sys.executable, '-B', root / DISPATCHER, 'fuzz', '--engine-dir', engine_dir, '--node', node_path(), '--seed', FUZZ_SEED, '--rounds', FUZZ_ROUNDS,
                '--json', out_json]
    if kind in ('engine', 'node', 'cosign', 'diff', 'sdk'):
        for case in cases or []:
            argv += ['--case', case]
    env = dict(os.environ, FORGE_DAFNY_LOCK=str(dafny_lock_path()))
    try:
        done = run(argv, cwd=root, env=env, timeout=timeout)
        code, text = done.returncode, done.stdout + done.stderr
    except subprocess.TimeoutExpired:
        code, text = -1, 'TIMEOUT after %d s' % timeout
    results = {}
    if kind in ('demo', 'fuzz'):
        try:
            results = report_results(kind, json.loads(out_json.read_text()))
        except (OSError, ValueError):
            results = {}
        return code, results, text
    for line in text.splitlines():
        m = LINE[kind].match(line)
        if not m:
            continue
        if kind == 'diff':
            name, status, exits, detail = m.groups()
        else:
            (status, name, detail), exits = m.groups(), None
        require(name not in results, 'SUITE %s: case %s printed twice' % (kind, name))
        results[name] = (status, detail, exits)
    return code, results, text


def full_suites(work, engines, interposer):
    """The five suites, every case. Exit 0 only if every expected case printed PASS and no other case printed."""
    out, logs = {}, {}
    names = run([sys.executable, '-B', NODE_SUITE, node_path(), '--list']).stdout.split()
    require(len(names) == NODE_CASE_COUNT and len(set(names)) == NODE_CASE_COUNT, 'SUITE node: %d cases listed, expected %d' % (len(names), NODE_CASE_COUNT))
    cosign_names = run([sys.executable, '-B', COSIGN_SUITE, engines[0], '--list']).stdout.split()
    require(len(cosign_names) == COSIGN_CASE_COUNT and len(set(cosign_names)) == COSIGN_CASE_COUNT,
            'SUITE cosign: %d cases listed, expected %d' % (len(cosign_names), COSIGN_CASE_COUNT))
    for kind, expected in (('engine', ENGINE_CASES), ('node', names), ('cosign', cosign_names), ('diff', DIFF_CASES), ('sdk', SDK_CASES)):
        code, results, text = run_suite(kind, ROOT, None, work / kind, engines, interposer)
        (work / (kind + '.log')).write_text(text)
        logs[kind] = text
        failed = sorted(n for n, r in results.items() if r[0] != 'PASS')
        require(code == 0 and sorted(results) == sorted(expected) and failed == [],
                'SUITE %s: exit %d; %d of %d cases parsed; not PASS: %r; missing: %r\n%s' % (
                    kind, code, len(results), len(expected), failed, sorted(set(expected) - set(results)), text[-3000:]))
        if kind == 'node':
            require('total %d: %d PASS, 0 FAIL, 0 NOT RUN' % (NODE_CASE_COUNT, NODE_CASE_COUNT) in text, 'SUITE node: the total line is not %d PASS' % NODE_CASE_COUNT)
        if kind == 'cosign':
            require('total %d: %d PASS, 0 FAIL, 0 NOT RUN' % (COSIGN_CASE_COUNT, COSIGN_CASE_COUNT) in text, 'SUITE cosign: the total line is not %d PASS' % COSIGN_CASE_COUNT)
        if kind == 'diff':
            require('RESULT: PASS' in text, 'SUITE diff: no RESULT: PASS line')
        out[kind] = {'argv': [kind_argv(kind)], 'exit_code': code, 'cases_passed': len(results), 'cases_expected': len(expected),
                     'cases': ({n: {'status': results[n][0], 'exits': results[n][2]} for n in sorted(results)} if kind == 'diff' else sorted(results))}
    return out, logs


def kind_argv(kind):
    return {'engine': 'python3 -B %s <attempt>/airlock-engine <attempt>/test/airlock-engine-kill --node <pinned node> --work <attempt> --interposer <attempt>/interpose.dylib' % ENGINE_SUITE,
            'node': 'python3 -B %s <pinned node> --model %s' % (NODE_SUITE, MODEL),
            'cosign': 'python3 -B %s <attempt>/airlock-engine' % COSIGN_SUITE,
            'diff': 'FORGE_DAFNY_LOCK=<lock> python3 -B %s --engine <attempt>/airlock-engine' % DIFF_SUITE,
            'sdk': 'python3 -B %s --engine-dir <attempt> --kill-engine <attempt>/test/airlock-engine-kill --node <pinned node>' % SDK_SUITE}[kind]


# ------------------------------------------------------------------------------------------------------------- demo and fuzz
def disasters(work, engines):
    """The demo on the builds of the attempt. Its own `result` is not enough: this function checks the eight rows,
    the engine codes that the directive names, the money from the WAL and the labels itself."""
    code, results, text = run_suite('demo', ROOT, None, work, engines, None, timeout=3600)
    (work / 'demo.log').write_text(text)
    require((work / 'demo.json').is_file(), 'DISASTERS: the demo wrote no JSON (exit %d)\n%s' % (code, text[-2000:]))
    report = json.loads((work / 'demo.json').read_text())
    rows = report.get('disasters', [])
    require(code == 0 and report.get('result') == 'PASS', 'DISASTERS: demo exit %d, result %s\n%s' % (code, report.get('result'), text[-2000:]))
    require(sorted(r['disaster'] for r in rows) == list(range(1, 9)), 'DISASTERS: the rows are not exactly 1..8: %r' % [r['disaster'] for r in rows])
    for r in rows:
        missing = [c for c in DISASTER_CODES[r['disaster']] if c not in r['observed']]
        require(r['result'] == 'PASS' and r['money_leaked_cents'] == 0 and not missing,
                'DISASTERS: disaster %d: result %s, leaked %r, missing in observed %r: %s' % (r['disaster'], r['result'], r['money_leaked_cents'], missing, r['observed']))
    require(report.get('money_leaked_cents_from_wal') == 0 and report.get('keys_refunded_above_original') == {}, 'DISASTERS: money leaked from the WAL: %r %r' % (
        report.get('money_leaked_cents_from_wal'), report.get('keys_refunded_above_original')))
    require(report.get('end_to_end') is False, 'DISASTERS: end_to_end is not false')
    require('LOCAL FAKE' in report.get('processors', ''), 'DISASTERS: the processors are not labelled LOCAL FAKE')
    require(report.get('dafny_at_run_time', {}).get('sentinel_dafny_on_engine_path_started') is False, 'DISASTERS: a Dafny start was seen at run time')
    require(isinstance(report.get('limits'), list) and any('trust boundary' in x for x in report['limits']), 'DISASTERS: the limits list or its trust boundary is missing')
    require(not HEX32.search(json.dumps(report)), 'DISASTERS: a hash or signature reached the demo JSON (the genesis nonce makes it differ per run)')
    return report


def fuzz(work, engines):
    code, results, text = run_suite('fuzz', ROOT, None, work, engines, None, timeout=3600)
    (work / 'fuzz.log').write_text(text)
    require((work / 'fuzz.json').is_file(), 'FUZZ: no JSON (exit %d)\n%s' % (code, text[-2000:]))
    report = json.loads((work / 'fuzz.json').read_text())
    inv = report.get('invariants', {})
    require(code == 0 and report.get('result') == 'PASS' and len(inv) == 8 and all(v == 'HELD' for v in inv.values()) and report.get('violations') == []
            and report.get('seed') == FUZZ_SEED and report.get('rounds') == FUZZ_ROUNDS and report.get('end_to_end') is False,
            'FUZZ: exit %d, result %s, invariants %r, violations %r' % (code, report.get('result'), inv, report.get('violations')))
    require(not HEX32.search(json.dumps(report)), 'FUZZ: a hash or signature reached the fuzz JSON')
    return {'command': 'bin/forge-airlock fuzz --engine-dir <attempt> --node <pinned node> --seed %d --rounds %d --json <file>' % (FUZZ_SEED, FUZZ_ROUNDS),
            'exit_code': code, 'seed': FUZZ_SEED, 'rounds': FUZZ_ROUNDS, 'invariants': inv, 'counts': report.get('counts'), 'result': report['result'],
            'label': 'FINITE TEST'}


# ------------------------------------------------------------------------------------------------------------- mutations
def mirror(folder):
    """A tree in which the suites read changed copies: copies of src/airlock, tests/airlock, sdk, bin, examples, gate and
    scripts; links to the other folders that the suites read (data only); the model and the dispatcher's refund copy.
    It lies under build/, so Node finds node_modules above it."""
    folder.mkdir(parents=True)
    for d in ('src/airlock', 'tests/airlock', 'sdk', 'bin', 'examples', 'gate', 'scripts'):
        shutil.copytree(ROOT / d, folder / d, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    for d in ('proposals', 'tests/m1-conformance', 'toolchain', '.toolchain', 'spec', 'clearing'):
        (folder / d).parent.mkdir(parents=True, exist_ok=True)
        (folder / d).symlink_to(ROOT / d)
    (folder / MODEL).parent.mkdir(parents=True)
    shutil.copyfile(ROOT / MODEL, folder / MODEL)
    shutil.copyfile(ROOT / REFUND_COPY, folder / REFUND_COPY)
    (folder / REFUND_COPY).chmod(0o700)
    return folder


def mutant_path(file):
    return file if file.startswith(('sdk/', 'bin/', 'examples/')) else ENGINE_DIR + '/' + file


def apply(name, file, old, new):
    text = (ROOT / mutant_path(file)).read_text()
    require(text.count(old) == 1, 'MUTANTS: the text of %s is found %d times in %s, expected 1' % (name, text.count(old), file))
    return text.replace(old, new)


def engines_from(folder, src):
    engines = []
    (folder / 'test').mkdir()
    for kill, out in ((False, 'airlock-engine'), (True, 'test/airlock-engine-kill')):
        done = compile_engine(src, folder / out, kill)
        require(done.returncode == 0, 'MUTANTS: ERROR of the list: copy %s does not build (%s)\n%s' % (folder.name, out, done.stderr[-1500:]))
        engines.append(folder / out)
    (folder / 'checker').mkdir()
    shutil.copyfile(ROOT / MODEL, folder / 'checker/model.cjs')
    return engines


def prepare(folder, file, text, base_engines, kind):
    """A changed copy. A .rs copy: new engine binaries (both builds must succeed) and the model beside them. Else: a
    mirror tree. A changed Node helper is compiled INTO the engine (include_str!), so a helper copy that runs through
    the engine (any suite but node) also gets engine binaries built from the mirror's sources."""
    if file.endswith('.cjs') and kind != 'node':
        root = mirror(folder / 'tree')
        (root / mutant_path(file)).write_text(text)
        return root, engines_from(folder, root / ENGINE_DIR)
    if file.endswith('.rs'):
        src = copy_rust(folder / 'src')
        (src / file).write_text(text)
        return ROOT, engines_from(folder, src)
    root = mirror(folder / 'tree')
    (root / mutant_path(file)).write_text(text)
    return root, base_engines


def unpack(entry, must_kill):
    if must_kill:
        return entry
    name, file, old, new, kind, case, removed = entry
    return name, file, None, old, new, kind, case, removed


def run_mutants(work, engines, interposer, table, must_kill):
    rows, details = [], {}
    for entry in table:
        name, file, message, old, new, kind, case, removed = unpack(entry, must_kill)
        text = apply(name, file, old, new)
        folder = work / name
        root, bins = prepare(folder, file, text, engines, kind)
        start = time.monotonic()
        code, results, printed = run_suite(kind, root, [case], folder / 'suite', bins, interposer)
        (work / 'logs').mkdir(exist_ok=True)
        (work / 'logs' / (name + '.log')).write_text(printed)
        status, detail, _ = results.get(case, ('NOT RUN', 'the case printed no result line', None))
        killed = code != 0 and status == 'FAIL' and 'suite error' not in detail and (message is None or message in detail)
        if must_kill:
            require(killed, 'MUTANTS: the suite did NOT fail on the copy %s in case %s %s with %r (exit %d, status %s): %s\n%s' % (
                name, kind, case, message, code, status, detail[:300], printed[-1500:]))
        else:
            killed = code != 0 and status == 'FAIL'
        rows.append({'name': name, 'file': mutant_path(file), 'removed': removed, 'suite': kind, 'case': case, 'killed': killed,
                     **({'reason_text': message} if must_kill else {})})
        details[name] = {'status': status, 'detail': detail[:500], 'wall_s': round(time.monotonic() - start, 1)}
        print('  %-36s %-6s %-28s %s %s' % (name, kind, case, 'KILLED' if killed else 'NOT KILLED', detail[:90]), flush=True)
        shutil.rmtree(folder)
    return rows, details


def controls(work, engines, interposer, tables):
    """The unchanged copies through every case that the lists name: all must pass, so a kill is due to the change."""
    wanted = {}
    for table in tables:
        for entry in table:
            kind, case, file = entry[-3], entry[-2], entry[1]
            where = 'rust' if file.endswith('.rs') else 'tree-engine' if file.endswith('.cjs') and kind != 'node' else 'tree'
            wanted.setdefault((kind, where), set()).add(case)
    out = {}
    for (kind, where), cases in sorted(wanted.items()):
        folder = work / ('unchanged-%s-%s' % (kind, where))
        file = 'main.rs' if where == 'rust' else 'node/booking_check.cjs'
        root, bins = prepare(folder, file, (ROOT / mutant_path(file)).read_text(), engines, kind if where == 'tree-engine' else 'node' if where == 'tree' else kind)
        code, results, printed = run_suite(kind, root, sorted(cases), folder / 'suite', bins, interposer)
        (work / ('unchanged-%s-%s.log' % (kind, where))).write_text(printed)
        bad = sorted(c for c in cases if results.get(c, ('NOT RUN',))[0] != 'PASS')
        require(code == 0 and bad == [], 'MUTANTS: the unchanged copy (%s, %s) does not pass %r\n%s' % (kind, where, bad, printed[-2000:]))
        out['%s/%s' % (kind, where)] = sorted(cases)
        shutil.rmtree(folder)
    return out


# Pairs of copies that may share one expected text, and why.
SHARED_TEXT_ALLOWED = {
    # Both change the bytes that the engine verifies (the store id, or the genesis hash, inside the cosign message), so a
    # signature that the human made over the true message is refused: the only observable is that refusal.
    ('M32_cosign_store_id_fixed', 'R2b_genesis_not_in_message'),
}

GROUPS = [('engine seams of PROTOCOL.md section 13', 'M'), ('durable order and answer (interposer)', 'S'), ('checks without a test in PART 1', 'X'),
          ('cosign tools and Node helper', 'N'), ('cosign through ssh-keygen (Apex addendum)', 'C'), ('the review of the native cosign', 'F'), ('diff-policy', 'D'), ('Python SDK', 'P'), ('TypeScript SDK', 'T'), ('demo and fuzz honesty (engine changed)', 'H'),
          ('repairs of the review', 'R')]


def mutations(work, engines, interposer):
    work.mkdir(parents=True)
    names = [m[0] for m in MUTANTS] + [m[0] for m in SURVIVORS]
    require(len(set(names)) == len(names), 'MUTANTS: a name is used twice')
    shared = {}
    for entry in MUTANTS:  # an expected failure text names ONE removed check within its case (review finding 9)
        shared.setdefault((entry[5], entry[6], entry[2]), []).append(entry[0])
    clash = {k: v for k, v in shared.items() if len(v) > 1 and tuple(sorted(v)) not in SHARED_TEXT_ALLOWED}
    require(not clash, 'MUTANTS: copies of one case share one expected text: %r' % clash)
    for entry in MUTANTS:  # every text must be found exactly once before anything runs
        apply(entry[0], entry[1], entry[3], entry[4])
    for entry in SURVIVORS:
        apply(entry[0], entry[1], entry[2], entry[3])
    passed = controls(work, engines, interposer, [MUTANTS, SURVIVORS])
    rows, details = run_mutants(work, engines, interposer, MUTANTS, True)
    found, more = run_mutants(work, engines, interposer, SURVIVORS, False)
    details.update(more)
    groups = {label: {'killed': sum(r['killed'] for r in rows if r['name'].startswith(p)), 'total': sum(1 for r in rows if r['name'].startswith(p))}
              for label, p in GROUPS}
    return {'changed_copies': len(rows), 'killed': sum(r['killed'] for r in rows), 'groups': groups, 'table': rows,
            'unchanged_copies_passed': passed,
            'not_killed': [dict(r, why=e[-1]) for r, e in zip(found, SURVIVORS)],
            'not_killed_count': sum(not r['killed'] for r in found),
            'robustness': {'M25_no_lock and S17_shared_lock': 'case lock: one holder parked at kill point a with the lock; two waiters must not answer '
                                                               'within 5 s; after the kill exactly one commits. Two independent signals.',
                           'S16_lock_after_wal_read': 'case trace: the first store-file event must be the exclusive flock (no timing)',
                           'M03_compare_and_swap': 'case race: with the lock kept, the second request sees the first commit (TOTAL_CAP, not STALE); no timing',
                           'H01, H06': 'the demo race and the fuzz burst without the compare-and-swap: the lock serializes the 50 requests, so the '
                                       'result does not depend on which process wins'},
            'not_run': []}, details


# ------------------------------------------------------------------------------------------------------------- evidence
def bundle_of(work):
    before = snapshot()
    tools = toolchain()
    built = build(work / 'build')
    engines = [work / 'build/airlock-engine', work / 'build/test/airlock-engine-kill']
    interposer = work / 'build/interpose.dylib'
    print('  build: exit 0', flush=True)
    suites, _ = full_suites(work / 'suite', engines, interposer)
    print('  suite: %d + %d + %d + %d + %d cases passed' % (len(ENGINE_CASES), NODE_CASE_COUNT, COSIGN_CASE_COUNT, len(DIFF_CASES), len(SDK_CASES)), flush=True)
    changed, details = mutations(work / 'mutations', engines, interposer)
    print('  mutations: %d of %d killed; %d not killed' % (changed['killed'], changed['changed_copies'], changed['not_killed_count']), flush=True)
    demo = disasters(work / 'disasters', engines)
    print('  disasters: 8 of 8 PASS; money leaked from the WAL 0', flush=True)
    fz = fuzz(work / 'fuzz', engines)
    print('  fuzz: 8 of 8 invariants HELD', flush=True)
    require(snapshot() == before, 'INPUT_CHANGED: a subject file changed during the checks')
    bundle = {
        'record': 'forge-airlock-goal20', 'format_version': 3,
        'gate_accepted': False, 'policy': None, 'end_to_end': False, 'm1': 'OPEN', 'kind': 'FINITE TEST',
        'producer': 'scripts/exit_goal20_sdk.py (a scenario script; not the gate)',
        'note': 'A record of real tool runs on one machine. It is not Forge gate evidence. A test count is not a proof. No time, no absolute path, '
                'no process id and no temporary key is in this record.',
        'subject': [{'path': name, 'sha256': before[name]} for name in sorted(before)],
        'toolchain': tools, 'build': built, 'suite': suites, 'mutations': changed,
        'disasters': {'label': 'FINITE TEST (each row also names its own label)', 'demo_json': demo},
        'fuzz': fz,
        'results_by_label': {
            'PROVED CORE': ['the canonical-refund decisions in suite cases canonical and py_canonical and in disaster 2 (CakeML binary b8ed5ec2...7bb8)',
                            'the BookingDualCert source verified in case build; its compiled checker in suite cases inventory, pin, py_saga_inventory and disaster 8',
                            'NO_CHOICE / CHOICE of the generated Dafny models in suite diff cases demo, choice, refused, identical'],
            'NATIVE CHECK': ['every engine, SDK, helper and dispatcher result in this record that is not in PROVED CORE'],
            'FINITE TEST': ['every suite case, every changed copy, the eight disasters and the fuzz pass: finite runs on one machine'],
        },
        'counts': {'engine_cases': len(ENGINE_CASES), 'node_cases': NODE_CASE_COUNT, 'cosign_cases': COSIGN_CASE_COUNT, 'diff_cases': len(DIFF_CASES), 'sdk_cases': len(SDK_CASES),
                   'mutants': changed['changed_copies'], 'mutants_killed': changed['killed'], 'not_killed': changed['not_killed_count'], 'disasters_passed': 8,
                   'fuzz_invariants_held': 8},
        'not_killed': changed['not_killed'],
        'not_run': [],
        'proved_core': CLAIMS['proved_core'], 'native_check': CLAIMS['native_check'], 'finite_test': CLAIMS['finite_test'],
        'trusted_assumptions': CLAIMS['trusted_assumptions'],
        'review': {'record': 'proposals/forge2-goal20-sdk/REVIEW.md', 'findings': {'FAIL-OPEN': 2, 'HIGH': 1, 'MEDIUM': 3, 'LOW': 3, 'NOTE': 2},
                   'repairs_with_changed_copies': ['R1a_node_pin', 'R1b_seam_in_production', 'R1c_binary_pin', 'R2a_no_nonce', 'R2b_genesis_not_in_message',
                                                   'R3_py_caller_rows', 'R3_ts_caller_rows', 'R4a_small_order', 'R4b_init_weak', 'R4c_weak_signature_r',
                                                   'R5a_lease_reopen', 'R5b_lease_unbound', 'R7_py_row_bound', 'R7_ts_row_bound'],
                   'stated_not_repaired': ['finding 6: the opener is trusted (stated)', 'finding 10: top-level tenant_id only (stated)',
                                           'finding 11: FNV-1a-128 is not a boundary (stated)']},
        'reproduce_cmd': 'FORGE_DAFNY_LOCK=<lock> python3 scripts/exit_goal20_sdk.py --case evidence',
    }
    return bundle, {'mutation_details': details}


def attempt_folder(case):
    base = ROOT / BUILD / case
    base.mkdir(parents=True, exist_ok=True)
    number = 1 + max([int(p.name.split('-')[1]) for p in base.glob('attempt-*')] or [0])
    return base / ('attempt-%04d' % number)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--case', required=True, choices=('build', 'suite', 'mutations', 'disasters', 'fuzz', 'evidence'))
    args = parser.parse_args()
    work = attempt_folder(args.case)
    name = work.relative_to(ROOT).as_posix()
    print('GOAL20 ' + args.case + ': ' + name, flush=True)
    start = time.monotonic()
    engines = [work / 'build/airlock-engine', work / 'build/test/airlock-engine-kill']
    try:
        toolchain()
        if args.case == 'build':
            result = build(work)
            print('  engine builds exit 0, no warning; unsafe control exit %d; checker model %s' % (result['unsafe_control']['compile_exit'], MODEL_SHA256))
        elif args.case == 'suite':
            build(work / 'build')
            suites, _ = full_suites(work, engines, work / 'build/interpose.dylib')
            for kind in ('engine', 'node', 'cosign', 'diff', 'sdk'):
                print('  %-6s exit %d, %d of %d cases PASS' % (kind, suites[kind]['exit_code'], suites[kind]['cases_passed'], suites[kind]['cases_expected']))
        elif args.case == 'mutations':
            build(work / 'build')
            result, details = mutations(work / 'copies', engines, work / 'build/interpose.dylib')
            (work / 'measurements.json').write_text(json.dumps({'mutation_details': details, 'wall_s': round(time.monotonic() - start, 1)}, indent=2, sort_keys=True) + '\n')
            (work / 'result.json').write_bytes(canonical(result))
            for label, g in result['groups'].items():
                print('  %-44s %d of %d killed' % (label, g['killed'], g['total']))
            print('  killed %d of %d changed copies; not killed: %s' % (
                result['killed'], result['changed_copies'], ', '.join(r['name'] for r in result['not_killed'] if not r['killed']) or 'none'))
        elif args.case == 'disasters':
            build(work / 'build')
            report = disasters(work / 'demo', engines)
            (work / 'demo.json').write_bytes(canonical(report))
            for r in report['disasters']:
                print('  D%d %s %s' % (r['disaster'], r['result'], r['observed'][:110]))
            print('  money leaked from the WAL: %d cents; demo JSON sha256 %s' % (report['money_leaked_cents_from_wal'], digest(canonical(report))))
        elif args.case == 'fuzz':
            build(work / 'build')
            fz = fuzz(work / 'fuzz', engines)
            (work / 'fuzz-record.json').write_bytes(canonical(fz))
            print('  seed %d, rounds %d: %s; counts %s' % (FUZZ_SEED, FUZZ_ROUNDS, ', '.join('%s %s' % kv for kv in sorted(fz['invariants'].items())),
                                                        json.dumps(fz['counts'], sort_keys=True)))
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
    except Failed as error:
        print('GOAL20 ' + args.case + ': FAILED; end_to_end=false; wall %.0f s\n' % (time.monotonic() - start) + str(error))
        return 1
    except RuntimeError as error:
        print('GOAL20 ' + args.case + ': ' + str(error) + '; end_to_end=false')
        return 2
    print('GOAL20 ' + args.case + ': PASSED; end_to_end=false; wall %.0f s' % (time.monotonic() - start))
    return 0


if __name__ == '__main__':
    sys.exit(main())
