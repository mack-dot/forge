#!/usr/bin/env python3
"""Goal 20: EXIT checks of forge-airlock (the engine src/airlock/, its Node helpers, diff-policy; PART 2 adds the SDKs,
the demo and the fuzz pass).

What a pass means: on this machine the finite checks below gave the recorded results. It is a FINITE TEST. It is NOT
a proof of the engine, the helpers, the SDKs or the dispatcher. end_to_end stays false. M1 stays OPEN. The bundle is a
RECORD, not gate evidence. The four keys proved_core, native_check, finite_test and trusted_assumptions are separate.

This script starts tools and compares results. It decides nothing about a refund, a booking, a saga move or a read.

Cases:
  build      source rules (line 1 of main.rs is #![forbid(unsafe_code)]; no unsafe; no extern crate; no Cargo file;
             every Rust `use` path from std, core, alloc, crate, self, super or an item of the same file; the Node
             helpers require only node: built-ins; the Python files import only the standard library and repository
             modules), a control that a copy with one unsafe block does not compile, both engine builds, the test
             interposer, the identity of the refund binary, the checker model rebuilt by Dafny and equal to its record,
             the toolchain versions
  suite      tests/airlock/test_engine.py, test_node_helpers.py and test_diff_policy.py, all cases, on the builds of
             the attempt; every case line is parsed; the set of case names must be the expected one
  mutations  changed copies: each copy has ONE exact-once text replacement; it must build; ONLY the named case of the
             named suite runs; the case must FAIL and its failure text must hold the named reason. The unchanged
             copies first pass every case that the list names. A copy that does not build is an ERROR of the list
  disasters  PART 2 (the demo). Until then: NOT RUN, and the case fails
  fuzz       PART 2 (forge-airlock fuzz). Until then: NOT RUN, and the case fails
  evidence   build, suite, mutations, disasters and fuzz, twice, in fresh folders; the two bundles are byte-identical.
             With --part1: disasters and fuzz are recorded as NOT RUN; the script prints PART 1 ONLY and exits 3
Raw outputs go to build/goal20/ (ignored by git). Times go to measurements.json, never to the bundle.
Environment: PATH must find the pinned Node first (scripts/javascript_env.py checks it). FORGE_DAFNY_LOCK=<folder>:
the Dafny lock (mkdir); default build/goal20/locks/dafny. Exit: 0 passed; 1 failed; 2 toolchain error; 3 PART 1 ONLY.
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
RUST = ['main.rs', 'store.rs', 'ledger.rs', 'policy.rs', 'verbs.rs', 'helpers.rs', 'json.rs']
NODE_HELPERS = ['src/airlock/node/cosign.cjs', 'src/airlock/node/booking_check.cjs']
PYTHON_FILES = ['src/airlock/py/diff_policy.py', 'src/airlock/py/policy_model.py', 'src/airlock/node/build_checker.py',
                'tests/airlock/test_engine.py', 'tests/airlock/test_node_helpers.py', 'tests/airlock/test_diff_policy.py',
                'scripts/exit_goal20_sdk.py']
REPO_MODULES = {'policy_model', 'common', 'backends', 'spec_clearing', 'javascript_env'}
ENGINE_SUITE, NODE_SUITE, DIFF_SUITE = 'tests/airlock/test_engine.py', 'tests/airlock/test_node_helpers.py', 'tests/airlock/test_diff_policy.py'
INTERPOSER = 'tests/airlock/interpose.c'
ARTIFACT = 'proposals/forge2-m1-conformance/artifacts/refund-arm64-macho'
ARTIFACT_SHA256 = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
MODEL = 'build/airlock/checker/model.cjs'
MODEL_SHA256 = 'e705ec490e30572cc783da2d7f927d5b4201f6bec0bc0a64c9cde507384b85f4'
CHECKER_SOURCE = 'proposals/forge2-pillar3-dual-certificate/BookingDualCert.dfy'
BUILD = 'build/goal20'
RUSTC = ['rustc', '--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3']  # the command of PROTOCOL.md section 1
RUSTC_VERSION = 'rustc 1.92.0 (ded5c06cf 2025-12-08)'
CC = '/usr/bin/cc'
CC_VERSION = 'Apple clang version 17.0.0 (clang-1700.0.13.5)'
CC_FLAGS = ['-dynamiclib', '-O1', '-Wall', '-Wextra', '-Werror']
ENGINE_CASES = ['init', 'recovery', 'cas', 'tenant', 'money', 'canonical', 'cosign', 'saga', 'inventory', 'leases', 'read', 'lines',
                'replay', 'race', 'kill', 'trace', 'dispatch', 'lock', 'pin']
NODE_CASE_COUNT = 125
DIFF_CASES = ['loader', 'malformed', 'no-engine', 'engine', 'demo', 'choice', 'fault', 'refused', 'saga', 'identical']
SUBJECT = sorted(['src/airlock/' + f for f in RUST] + NODE_HELPERS + PYTHON_FILES + [
    'src/airlock/PROTOCOL.md', INTERPOSER, ARTIFACT, CHECKER_SOURCE, 'proposals/forge2-pillar3-dual-certificate/benchmark/records/build-record.json',
    'tests/m1-conformance/recorded-m1-cases.json', 'proposals/forge2-goal20-sdk/DESIGN.md', 'proposals/forge2-goal20-sdk/BRIEF.md'])
SUBJECT_GLOBS = ['tests/airlock/fixtures/*.json', 'tests/airlock/policies/*.json']
PART2_CASES = ('disasters', 'fuzz')

# Changed copies. (name, file, a part of the failure text that must appear, text to find exactly once, replacement,
# suite, the case that must fail, what is removed). Suite engine = tests/airlock/test_engine.py, node =
# tests/airlock/test_node_helpers.py, diff = tests/airlock/test_diff_policy.py. A copy of a .rs file is built into
# new engine binaries; a copy of any other file runs in a mirror tree (copies of src/airlock, tests/airlock, gate and
# scripts under build/) so that the suite reads the changed file. M01 to M35 are the seams of PROTOCOL.md section 13.
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
    ('M09_cosign_not_verified', 'verbs.rs', "expected REQUIRE_HUMAN_COSIGN (exit 11), got exit 0 'COMMITTED r1", 'if !helpers::cosign_verify(&ctx.node(), &pk, sig, &msg)? {', 'if false {', 'engine', 'cosign',
     'the verification of a cosign signature'),
    ('M10_cosign_answer_any_bytes', 'helpers.rs', 'HELPER_FAILED (exit 22), got exit 0', '(Some(0), true, o) if o == yes => Ok(true),', '(Some(0), _, _) => Ok(true),',
     'engine', 'cosign', 'the exact VALID line and the empty stderr of the cosign helper'),
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
    ('M19_lease_close_record', 'verbs.rs', 'the answer names the close', '    if s.l.leases.contains_key(req) {\n        let (epoch, _)', '    if false {\n        let (epoch, _)',
     'engine', 'leases', 'the durable CLOSE record of a terminal refusal'),
    ('M20_commit_closes_lease', 'ledger.rs', 'list:', 'self.leases.remove(req);', '', 'engine', 'leases', 'the close of a lease by a committed effect'),
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
    ('M32_cosign_store_id_fixed', 'verbs.rs', "expected REQUIRE_HUMAN_COSIGN (exit 11), got exit 0 'COMMITTED r1", 'cosign_message(&s.l.store_id, req, t[4], &action)', 'cosign_message("store-a", req, t[4], &action)',
     'engine', 'cosign', 'the store id inside the signed cosign message'),
    ('M33_get_tenant', 'verbs.rs', "'GET tB k1': expected TENANT_ISOLATION_BREACH",
     '    if k.tenant != tenant { return no(Code::Breach, "KEY_OF_ANOTHER_TENANT") }\n    let rest = match', '    let rest = match', 'engine', 'tenant',
     'the tenant check of GET'),
    ('M34_policy_pin', 'store.rs', 'changed policy file', 'if fnv128(&bytes) != pin.hash {', 'if false {', 'engine', 'recovery', 'the pin of a policy file'),
    ('M35_json_trailing_bytes', 'json.rs', 'row trailing:', 'if p.i != p.b.len() {', 'if false {', 'engine', 'read', 'the refusal of bytes after a JSON value'),
    # the durable order (case trace, with the test interposer) and the answer
    ('S01_no_wal_sync', 'store.rs', 'system-call order of a commit', 'if let Err(e) = written.and_then(|()| wal.sync_all()) {', 'if let Err(e) = written {',
     'engine', 'trace', 'the F_FULLFSYNC of the WAL before the answer'),
    ('S02_ignore_wal_sync_error', 'store.rs', 'failed sync of the WAL: expected one IO_ERROR line', 'if let Err(e) = written.and_then(|()| wal.sync_all()) {',
     'let _ = wal.sync_all();\n        if let Err(e) = written {', 'engine', 'trace', 'the result of the WAL sync'),
    ('S03_no_cut_after_failed_sync', 'store.rs', 'failed sync of the WAL: the record must be cut off again',
     'let undone = wal.set_len(old_len).and_then(|()| wal.sync_all());', 'let undone: io::Result<()> = Ok(());', 'engine', 'trace',
     'the cut of a record whose write or sync failed'),
    ('S04_no_ratchet_sync', 'store.rs', 'system-call order of init', '.concat()).and_then(|()| ratchet.sync_all())', '.concat())', 'engine', 'trace',
     'the F_FULLFSYNC of the ratchet entry'),
    ('S05_ignore_ratchet_error', 'store.rs', 'failed sync of the ratchet: expected one OUTCOME_UNKNOWN line',
     'if push(&mut ratchet, epoch).is_err() { return no(Code::OutcomeUnknown, "OUTCOME_UNKNOWN the record is in the WAL; its ratchet entry failed") }',
     'let _ = push(&mut ratchet, epoch);', 'engine', 'trace', 'the result of the ratchet write and sync'),
    ('S06_no_ratchet_entry', 'store.rs', 'system-call order of a commit',
     '        if push(&mut ratchet, epoch).is_err() { return no(Code::OutcomeUnknown, "OUTCOME_UNKNOWN the record is in the WAL; its ratchet entry failed") }\n', '',
     'engine', 'trace', 'the ratchet entry of a commit'),
    ('S07_early_answer', 'store.rs', 'system-call order of a commit', '        cut("c");\n',
     '        cut("c");\n        let _ = io::stdout().write_all(b"COMMITTED ").and_then(|()| io::stdout().flush());\n', 'engine', 'trace',
     'the order: no answer byte before the WAL sync'),
    ('S08_no_recovery_wal_sync', 'store.rs', 'system-call order of a recovery', '        wal_ref.sync_all()?;\n', '', 'engine', 'trace', 'the WAL sync after a recovery cut'),
    ('S09_ignore_recovery_sync_error', 'store.rs', 'recovery with a failed sync of the WAL must refuse', '        wal_ref.sync_all()?;\n', '        let _ = wal_ref.sync_all();\n',
     'engine', 'trace', 'the result of the WAL sync in the recovery'),
    ('S10_no_init_wal_sync', 'store.rs', 'system-call order of init', '        wal.write_all(&genesis)?;\n        wal.sync_all()?;\n', '        wal.write_all(&genesis)?;\n',
     'engine', 'trace', 'the sync of the genesis record'),
    ('S11_no_init_folder_sync', 'store.rs', 'system-call order of init', '        File::open(&tmp)?.sync_all()?;\n', '', 'engine', 'trace', 'the sync of the new store folder'),
    ('S12_no_init_parent_sync', 'store.rs', 'system-call order of init', '        File::open(&parent)?.sync_all()?;\n', '', 'engine', 'trace',
     'the sync of the parent folder after the rename'),
    ('S13_no_init_policy_sync', 'store.rs', 'system-call order of init', '            f.write_all(bytes)?;\n            f.sync_all()?;\n', '            f.write_all(bytes)?;\n',
     'engine', 'trace', 'the sync of a pinned policy file'),
    ('S14_init_keeps_tmp_after_failure', 'store.rs', 'init with a failed sync 1',
     '            let _ = std::fs::remove_dir_all(&tmp); // a refused init leaves no folder of its own\n', '', 'engine', 'trace',
     'the removal of the temporary folder of a refused init'),
    ('S15_ignore_init_wal_sync_error', 'store.rs', 'init with a failed sync 3', '        wal.sync_all()?;\n        File::open(&tmp)', '        let _ = wal.sync_all();\n        File::open(&tmp)',
     'engine', 'trace', 'the result of the sync of the genesis record'),
    ('S16_lock_after_wal_read', 'store.rs', 'a store file was read before the exclusive lock', LOCK_LINE + SCAN_LINE, SCAN_LINE + '    wal.lock()?;\n', 'engine', 'trace',
     'the rule that the lock comes before any read of a store file'),
    ('S17_shared_lock', 'store.rs', 'while another process held the store lock', LOCK_LINE, LOCK_LINE.replace('wal.lock()', 'wal.lock_shared()'), 'engine', 'lock',
     'the exclusiveness of the store lock'),
    ('S18_ignore_failed_answer', 'main.rs', 'no reader for the answers: exit 0, expected 20', '{ code } else { Code::DispatchFailed.num() }', '{ code } else { code }',
     'engine', 'dispatch', 'the DISPATCH_FAILED code for an answer that could not be written'),
    # the Node helpers (the human's signing tool and the verify call; the call of the Dafny-compiled checker)
    ('N01_cosign_skip_mode_check', 'node/cosign.cjs', "exit 0 stdout b'",
     "  if ((st.mode & 0o077) !== 0) throw new Error('key file mode ' + (st.mode & 0o777).toString(8) + ' has group or other bits');\n", '', 'node', 'sign_key_mode_0640',
     'the D-1 rule mode & 0o077 == 0 of the key file'),
    ('N02_cosign_key_follows_link', 'node/cosign.cjs', "exit 0 stdout b'", 'fs.constants.O_RDONLY | fs.constants.O_NOFOLLOW | fs.constants.O_NONBLOCK',
     'fs.constants.O_RDONLY | fs.constants.O_NONBLOCK', 'node', 'sign_key_symlink', 'O_NOFOLLOW on the key file'),
    ('N03_cosign_accepts_invalid', 'node/cosign.cjs', "exit 0 stdout b'VALID", "if (ok === false) return finish(1, 'INVALID\\n', null);",
     "if (ok === false) return finish(0, 'VALID\\n', null);", 'node', 'verify_wrong_key', 'the INVALID answer for a wrong signature'),
    ('N04_cosign_skip_uid_check', 'node/cosign.cjs', "out b'ACCEPTED'", "  if (st.uid !== euid) throw new Error('key file owner uid ' + st.uid + ' is not the effective uid ' + euid);\n",
     '', 'node', 'sign_other_uid_seam', 'the D-1 rule uid == euid of the key file'),
    ('N05_cosign_verify_skips_form', 'node/cosign.cjs', "exit 1 stdout b'INVALID", '    parseMessage(msg);\n    const ok', '    const ok', 'node', 'verify_msg_bad_prefix',
     'the strict message form in verify'),
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
]

# Changed copies that the suites do NOT detect (findings, not kills). Same form. They run in case mutations; the
# result is recorded; they never count as killed, and a kill of one of them is reported, not hidden.
SURVIVORS = [
    ('X01_helper_input_not_checked', 'helpers.rs', 'sent: s == Some(vec![1])', 'sent: true', 'engine', 'inventory',
     'the rule that a helper read all of its input (PROTOCOL.md section 13: no test can see it with the present helpers)'),
    ('X02_fold_allows_overrefund', 'ledger.rs', 'if amount == 0 || amount > *remaining { return None }', 'if amount == 0 { return None }', 'engine', 'recovery',
     'the fold check amount <= remaining of a REFUND record (the writer checks first; only a crafted WAL reaches it)'),
    ('X03_canonical_native_bound', 'verbs.rs',
     '        if amount > remaining || !REASONS.contains(&reason) { return no(Code::BadFrame, "BAD_FRAME the binary accepted what the native check refuses") }\n', '',
     'engine', 'canonical', 'the native bound after an accept of the CakeML binary (no stand-in binary accepts above the remaining amount)'),
    ('X04_helper_env_not_cleared', 'helpers.rs', '        .env_clear()\n', '', 'engine', 'cosign',
     'the empty environment of a helper process (no test puts a variable that changes a helper into the engine environment)'),
    ('X05_ratchet_last_not_highest', 'store.rs', 'floor = Some(floor.map_or(v, |f| f.max(v)));', 'floor = Some(v);', 'engine', 'recovery',
     'the highest ratchet entry as the floor (no test writes a ratchet whose last entry is lower)'),
    ('X06_cosign_keygen_overwrites', 'node/cosign.cjs', 'fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_EXCL | fs.constants.O_NOFOLLOW',
     'fs.constants.O_WRONLY | fs.constants.O_CREAT | fs.constants.O_NOFOLLOW', 'node', 'keygen_refuses_existing',
     'O_EXCL of keygen (the existing file of the case has mode 0644, so the mode check refuses it first; a 0600 file is not tried)'),
    ('X07_diff_mismatch_ignored', 'py/diff_policy.py', "'mismatch': got is not None and got != want", "'mismatch': False", 'diff', 'engine',
     'the TABLE_MISMATCH check (no case gives the engine and the Python evaluator a difference)'),
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
            'Everything in JavaScript (src/airlock/node/*.cjs) beyond the compiled model: the strict scanner, the pin, the D-1 key rules, the '
            'cosign message form. NOT proved.',
            'Everything in Python (src/airlock/py/*.py): the scenario table, the evaluator, the generator. NOT proved.',
        ],
    },
    'finite_test': {
        'label': 'FINITE TEST',
        'items': [
            'The three suites (case suite) and the changed copies (case mutations) on one machine. A test count is not a proof.',
            'System-call order observed with a dyld interposer for the traced init, commit, refusal, lease close and recovery only, not for '
            'every request. A SIGKILL is not a power loss.',
        ],
    },
    'trusted_assumptions': [
        'macOS kernel and drive: fcntl(F_FULLFSYNC) returns 0 only after the drive was asked to store the data; flock is exclusive and is '
        'released at process end; APFS keeps what F_FULLFSYNC reported. NOT tested at power loss.',
        'rustc 1.92.0, LLVM and the Rust standard library; Node 24.3.0 and node:crypto (Ed25519); the Dafny 4.11.0 compiler and JavaScript '
        'runtime; bignumber.js 9.3.1; Python 3.10.11.',
        'The JSON-to-Dafny generator of diff_policy.py (owner decision, Goal 20 plan line 8).',
        'The launcher pins the refund binary, the helpers and the model; the engine hashes none of them. Whoever can write the store folder is '
        'trusted. FNV-1a-128 and CRC-32 authenticate nothing.',
        'Cosign: an agent that runs as the same OS user as the key owner can read a 0600 key file; "the agent cannot self-cosign" holds only '
        'when the private key is outside its reach.',
        'A restore of the WAL and the ratchet together is not detected.',
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
    seen = {}
    for name in NODE_HELPERS:
        text = (ROOT / name).read_text()
        literal = re.findall(r"\brequire\(\s*'([^']*)'\s*\)", text)
        require(len(re.findall(r'\brequire\(', text)) == len(literal), 'SOURCE: %s: a require() with no string literal' % name)
        require(all(m.startswith('node:') for m in literal), 'SOURCE: %s requires a module that is not a node: built-in: %r' % (name, literal))
        require(not re.search(r'^\s*import\b|\bimport\(', text, re.M), 'SOURCE: %s has an import statement' % name)
        seen[name] = sorted(set(literal))
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


def copy_rust(dest):
    dest.mkdir(parents=True)
    for name in RUST:
        shutil.copyfile(ROOT / ENGINE_DIR / name, dest / name)
    return dest


def build(work):
    """Source rules, the unsafe control, the two engine builds, the interposer, the refund binary, the checker model."""
    work.mkdir(parents=True)
    rules = {'rust': rust_rules(), 'node_requires': node_rules(), 'python_imports': python_rules()}
    built = {}
    for kill, out in ((False, 'airlock-engine'), (True, 'airlock-engine-kill')):
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
    return {'source_rules': rules, 'engine_builds': built,
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
    'node': re.compile(r'^(PASS|FAIL|NOT RUN)\s+(\S+): (.*)$'),
    'diff': re.compile(r'^(\S+)\s+(PASS|FAIL|NOT RUN)\s+exits=\[([^\]]*)\] dafny_processes=\d+ wall=[\d.]+s \| (.*)$'),
}


def run_suite(kind, root, cases, work, engines, interposer, timeout=7200):
    """Starts one suite as its own process. Returns (exit code, {case: (status, detail, exits)}, printed text)."""
    work.mkdir(parents=True, exist_ok=True)
    if kind == 'engine':
        argv = [sys.executable, '-B', root / ENGINE_SUITE, engines[0], engines[1], '--node', node_path(), '--work', work, '--interposer', interposer]
    elif kind == 'node':
        argv = [sys.executable, '-B', root / NODE_SUITE, node_path(), '--model', ROOT / MODEL]
    else:
        argv = [sys.executable, '-B', root / DIFF_SUITE, '--engine', engines[0]]
    for case in cases or []:
        argv += ['--case', case]
    env = dict(os.environ, FORGE_DAFNY_LOCK=str(dafny_lock_path()))
    try:
        done = run(argv, cwd=root, env=env, timeout=timeout)
        code, text = done.returncode, done.stdout + done.stderr
    except subprocess.TimeoutExpired:
        code, text = -1, 'TIMEOUT after %d s' % timeout
    results = {}
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
    """The three suites, every case. Exit 0 only if every expected case printed PASS and no other case printed."""
    out, logs = {}, {}
    names = run([sys.executable, '-B', NODE_SUITE, node_path(), '--list']).stdout.split()
    require(len(names) == NODE_CASE_COUNT and len(set(names)) == NODE_CASE_COUNT, 'SUITE node: %d cases listed, expected %d' % (len(names), NODE_CASE_COUNT))
    for kind, expected in (('engine', ENGINE_CASES), ('node', names), ('diff', DIFF_CASES)):
        code, results, text = run_suite(kind, ROOT, None, work / kind, engines, interposer)
        (work / (kind + '.log')).write_text(text)
        logs[kind] = text
        failed = sorted(n for n, r in results.items() if r[0] != 'PASS')
        require(code == 0 and sorted(results) == sorted(expected) and failed == [],
                'SUITE %s: exit %d; %d of %d cases parsed; not PASS: %r; missing: %r\n%s' % (
                    kind, code, len(results), len(expected), failed, sorted(set(expected) - set(results)), text[-3000:]))
        if kind == 'node':
            require('total %d: %d PASS, 0 FAIL, 0 NOT RUN' % (NODE_CASE_COUNT, NODE_CASE_COUNT) in text, 'SUITE node: the total line is not %d PASS' % NODE_CASE_COUNT)
        if kind == 'diff':
            require('RESULT: PASS' in text, 'SUITE diff: no RESULT: PASS line')
        out[kind] = {'argv': [kind_argv(kind)], 'exit_code': code, 'cases_passed': len(results), 'cases_expected': len(expected),
                     'cases': ({n: {'status': results[n][0], 'exits': results[n][2]} for n in sorted(results)} if kind == 'diff' else sorted(results))}
    return out, logs


def kind_argv(kind):
    return {'engine': 'python3 -B %s <attempt>/airlock-engine <attempt>/airlock-engine-kill --node <pinned node> --work <attempt> --interposer <attempt>/interpose.dylib' % ENGINE_SUITE,
            'node': 'python3 -B %s <pinned node> --model %s' % (NODE_SUITE, MODEL),
            'diff': 'FORGE_DAFNY_LOCK=<lock> python3 -B %s --engine <attempt>/airlock-engine' % DIFF_SUITE}[kind]


# ------------------------------------------------------------------------------------------------------------- mutations
def mirror(folder):
    """A tree in which the suites read changed copies: copies of src/airlock, tests/airlock, gate and scripts; links to the
    other folders that the suites read (data only). It lies under build/, so Node finds node_modules above it."""
    folder.mkdir(parents=True)
    for d in ('src/airlock', 'tests/airlock', 'gate', 'scripts'):
        shutil.copytree(ROOT / d, folder / d, ignore=shutil.ignore_patterns('__pycache__', '*.pyc'))
    for d in ('proposals', 'tests/m1-conformance', 'toolchain', '.toolchain', 'spec', 'clearing'):
        (folder / d).parent.mkdir(parents=True, exist_ok=True)
        (folder / d).symlink_to(ROOT / d)
    (folder / MODEL).parent.mkdir(parents=True)
    shutil.copyfile(ROOT / MODEL, folder / MODEL)
    return folder


def mutant_file(file):
    return ROOT / ENGINE_DIR / file


def apply(name, file, old, new):
    text = mutant_file(file).read_text()
    require(text.count(old) == 1, 'MUTANTS: the text of %s is found %d times in %s, expected 1' % (name, text.count(old), file))
    return text.replace(old, new)


def prepare(folder, file, text, base_engines):
    """A changed copy. A .rs copy: new engine binaries (both builds must succeed). Else: a mirror tree."""
    if file.endswith('.rs'):
        src = copy_rust(folder / 'src')
        (src / file).write_text(text)
        engines = []
        for kill, out in ((False, 'airlock-engine'), (True, 'airlock-engine-kill')):
            done = compile_engine(src, folder / out, kill)
            require(done.returncode == 0, 'MUTANTS: ERROR of the list: copy %s does not build (%s)\n%s' % (folder.name, out, done.stderr[-1500:]))
            engines.append(folder / out)
        return ROOT, engines
    root = mirror(folder / 'tree')
    (root / ENGINE_DIR / file).write_text(text)
    return root, base_engines


def run_mutants(work, engines, interposer, table, must_kill):
    rows, details = [], {}
    for entry in table:
        if must_kill:
            name, file, message, old, new, kind, case, removed = entry
        else:
            (name, file, old, new, kind, case, removed), message = entry, None
        text = apply(name, file, old, new)
        folder = work / name
        root, bins = prepare(folder, file, text, engines)
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
        rows.append({'name': name, 'file': ENGINE_DIR + '/' + file, 'removed': removed, 'suite': kind, 'case': case, 'killed': killed,
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
            where = 'rust' if file.endswith('.rs') else 'tree'
            wanted.setdefault((kind, where), set()).add(case)
    out = {}
    for (kind, where), cases in sorted(wanted.items()):
        folder = work / ('unchanged-%s-%s' % (kind, where))
        if where == 'rust':
            src = copy_rust(folder / 'src')
            bins = []
            for kill, name in ((False, 'airlock-engine'), (True, 'airlock-engine-kill')):
                require(compile_engine(src, folder / name, kill).returncode == 0, 'MUTANTS: the unchanged copy does not build')
                bins.append(folder / name)
            root = ROOT
        else:
            root, bins = mirror(folder / 'tree'), engines
        code, results, printed = run_suite(kind, root, sorted(cases), folder / 'suite', bins, interposer)
        (work / ('unchanged-%s-%s.log' % (kind, where))).write_text(printed)
        bad = sorted(c for c in cases if results.get(c, ('NOT RUN',))[0] != 'PASS')
        require(code == 0 and bad == [], 'MUTANTS: the unchanged copy (%s, %s) does not pass %r\n%s' % (kind, where, bad, printed[-2000:]))
        out['%s/%s' % (kind, where)] = sorted(cases)
        shutil.rmtree(folder)
    return out


def mutations(work, engines, interposer):
    work.mkdir(parents=True)
    names = [m[0] for m in MUTANTS] + [m[0] for m in SURVIVORS]
    require(len(set(names)) == len(names), 'MUTANTS: a name is used twice')
    for entry in MUTANTS + SURVIVORS:  # every text must be found exactly once before anything runs
        apply(entry[0], entry[1], entry[3] if len(entry) == 8 else entry[2], entry[4] if len(entry) == 8 else entry[3])
    passed = controls(work, engines, interposer, [MUTANTS, SURVIVORS])
    rows, details = run_mutants(work, engines, interposer, MUTANTS, True)
    found, more = run_mutants(work, engines, interposer, SURVIVORS, False)
    details.update(more)
    return {'changed_copies': len(rows), 'killed': sum(r['killed'] for r in rows), 'table': rows,
            'unchanged_copies_passed': passed,
            'not_killed_findings': found,
            'not_killed_count': sum(not r['killed'] for r in found),
            'robustness': {'M25_no_lock and S17_shared_lock': 'case lock: one holder parked at kill point a with the lock; two waiters must not answer '
                                                               'within 5 s; after the kill exactly one commits. Two independent signals.',
                           'S16_lock_after_wal_read': 'case trace: the first store-file event must be the exclusive flock (no timing)',
                           'M03_compare_and_swap': 'case race: with the lock kept, the second request sees the first commit (TOTAL_CAP, not STALE); no timing'},
            'not_run': []}, details


# ------------------------------------------------------------------------------------------------------------- evidence
def part2(case):
    raise Failed('%s: NOT RUN (PART 2: the SDK, the demo and the fuzz pass are not in this script yet)' % case)


def bundle_of(work, part1):
    not_run = []
    for case in PART2_CASES:  # first, so that a run without PART 2 fails before the long steps
        if part1:
            not_run.append({'case': case, 'status': 'NOT RUN', 'why': 'PART 2 is not in this script yet'})
        else:
            part2(case)
    before = snapshot()
    tools = toolchain()
    built = build(work / 'build')
    engines = [work / 'build/airlock-engine', work / 'build/airlock-engine-kill']
    interposer = work / 'build/interpose.dylib'
    print('  build: exit 0', flush=True)
    suites, _ = full_suites(work / 'suite', engines, interposer)
    print('  suite: %d + %d + %d cases passed' % (len(ENGINE_CASES), NODE_CASE_COUNT, len(DIFF_CASES)), flush=True)
    changed, details = mutations(work / 'mutations', engines, interposer)
    print('  mutations: %d of %d killed; %d findings not killed' % (changed['killed'], changed['changed_copies'], changed['not_killed_count']), flush=True)
    require(snapshot() == before, 'INPUT_CHANGED: a subject file changed during the checks')
    bundle = {
        'record': 'forge-airlock-goal20', 'format_version': 1, 'part': 'PART 1 ONLY' if part1 else 'COMPLETE',
        'gate_accepted': False, 'policy': None, 'end_to_end': False, 'm1': 'OPEN', 'kind': 'FINITE TEST',
        'producer': 'scripts/exit_goal20_sdk.py (a scenario script; not the gate)',
        'note': 'A record of real tool runs on one machine. It is not Forge gate evidence. A test count is not a proof. No time, no absolute path, '
                'no process id and no temporary key is in this record.',
        'subject': [{'path': name, 'sha256': before[name]} for name in sorted(before)],
        'toolchain': tools, 'build': built, 'suite': suites, 'mutations': changed,
        'counts': {'engine_cases': len(ENGINE_CASES), 'node_cases': NODE_CASE_COUNT, 'diff_cases': len(DIFF_CASES),
                   'mutants': changed['changed_copies'], 'mutants_killed': changed['killed'], 'findings_not_killed': changed['not_killed_count']},
        'not_run': not_run,
        'proved_core': CLAIMS['proved_core'], 'native_check': CLAIMS['native_check'], 'finite_test': CLAIMS['finite_test'],
        'trusted_assumptions': CLAIMS['trusted_assumptions'],
        'reproduce_cmd': 'FORGE_DAFNY_LOCK=<lock> python3 scripts/exit_goal20_sdk.py --case evidence' + (' --part1' if part1 else ''),
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
    parser.add_argument('--part1', action='store_true', help='evidence only: record disasters and fuzz as NOT RUN; prints PART 1 ONLY; exit 3')
    args = parser.parse_args()
    if args.part1 and args.case != 'evidence':
        parser.error('--part1 is valid only with --case evidence')
    work = attempt_folder(args.case)
    name = work.relative_to(ROOT).as_posix()
    print('GOAL20 ' + args.case + ': ' + name, flush=True)
    start = time.monotonic()
    try:
        toolchain()
        if args.case == 'build':
            result = build(work)
            print('  engine builds exit 0, no warning; unsafe control exit %d; checker model %s' % (result['unsafe_control']['compile_exit'], MODEL_SHA256))
        elif args.case == 'suite':
            build(work / 'build')
            suites, _ = full_suites(work, [work / 'build/airlock-engine', work / 'build/airlock-engine-kill'], work / 'build/interpose.dylib')
            for kind in ('engine', 'node', 'diff'):
                print('  %-6s exit %d, %d of %d cases PASS' % (kind, suites[kind]['exit_code'], suites[kind]['cases_passed'], suites[kind]['cases_expected']))
        elif args.case == 'mutations':
            build(work / 'build')
            result, details = mutations(work / 'copies', [work / 'build/airlock-engine', work / 'build/airlock-engine-kill'], work / 'build/interpose.dylib')
            (work / 'measurements.json').write_text(json.dumps({'mutation_details': details, 'wall_s': round(time.monotonic() - start, 1)}, indent=2, sort_keys=True) + '\n')
            (work / 'result.json').write_bytes(canonical(result))
            print('  killed %d of %d changed copies; %d findings not killed: %s' % (
                result['killed'], result['changed_copies'], result['not_killed_count'], ', '.join(r['name'] for r in result['not_killed_findings'] if not r['killed'])))
        elif args.case in PART2_CASES:
            part2(args.case)
        else:
            work.mkdir(parents=True)
            bundles = []
            for number in (1, 2):
                print(' run ' + str(number), flush=True)
                t0 = time.monotonic()
                bundle, measured = bundle_of(work / ('run-%d' % number), args.part1)
                measured['wall_s'] = round(time.monotonic() - t0, 1)
                bundles.append(canonical(bundle))
                (work / ('run-%d' % number) / 'evidence.json').write_bytes(bundles[-1])
                (work / ('run-%d' % number) / 'measurements.json').write_text(json.dumps(measured, indent=2, sort_keys=True) + '\n')
                print('  run %d bundle sha256 %s' % (number, digest(bundles[-1])), flush=True)
            require(bundles[0] == bundles[1], 'evidence: the two bundles differ')
            (work / 'evidence.json').write_bytes(bundles[0])
            print('  bundle: ' + name + '/evidence.json sha256 ' + digest(bundles[0]) + ' (two runs, byte-identical)')
            if args.part1:
                print('GOAL20 evidence: PART 1 ONLY (disasters and fuzz NOT RUN); end_to_end=false; wall %.0f s' % (time.monotonic() - start))
                return 3
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
