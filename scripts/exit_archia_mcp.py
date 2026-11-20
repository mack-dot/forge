#!/usr/bin/env python3
"""Archia MCP airlock demo, Phase 4 item 1: EXIT checks of the MCP stdio proxy (src/mcp_proxy/*.rs).

What a pass means: on this machine the finite checks below gave the recorded results. It is a FINITE TEST of a
NATIVE CHECK. The Rust proxy is NOT proved. No clearing check runs here. end_to_end stays false. The bundle is a
RECORD, not Forge gate evidence.

This script starts tools and compares results. It decides nothing about a tool call.

Cases:
  build      source rules (forbid(unsafe_code), imports from std/crate only, no extern crate, no Cargo file), the
             rustc command of the launcher bin/forge-mcp-proxy (exit 0, no warning), a control copy with one
             `unsafe` block that must NOT compile, and a second build: are the two binaries byte-identical?
  suite      tests/mcp_proxy/test_servers.py, test_proxy_e2e.py --binary, run_unit.py, test_faults.py (a missing
             file is NOT RUN and fails the case), and one own check: two sequential runs of one call sequence with
             --test-clock and one key give byte-identical evidence.wal and ledger.wal files (a third run with
             another clock must differ, so the check can fail)
  showcase   examples/archia_mcp_showcase/run_showcase.py --json (default flood 10 GiB): every check true, and the
             peak RSS of the proxy below 5.0 MiB. NO latency assertion (owner decision): latencies are measurements.
  mutations  changed copies of src/mcp_proxy/ (one exact text replacement each, found exactly once). Each copy must
             compile; the judges (e2e, unit, faults, showcase with a small flood) must fail on it. A compile failure
             is NOT a kill. The unchanged copy must pass every judge in the same harness first.
  evidence   build, suite, showcase and mutations, twice, in fresh folders; the two bundles must be byte-identical.
Raw outputs go to build/archia_mcp/ (ignored by git). Times, RSS values, binary paths, key-dependent hashes go to
measurements.json, never to the bundle.

Convention for copies that no judge kills (the Goal 20 convention, scripts/exit_goal20_sdk.py SURVIVORS): they are
listed in EXPECTED_NOT_KILLED with the reason. They run like every other copy. They never count as killed. The case
`mutations` exits 0 only when the set of NOT KILLED copies EQUALS that recorded list: a new survivor fails the case,
and an expected survivor that is now killed also fails the case (the list must then be updated by a person).

Pre-merge checks (the forge-airlock SHA-256 pin and "no file of main is modified") were conditions of the pull request
and are false on main after the squash merge MERGED_AS; when MERGED_AS is an ancestor of HEAD they print "pre-merge check
not applicable" and the record says NOT APPLICABLE (never passed), else they run as before (NOT RUN if git cannot say).
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
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
from common import canonical, digest  # noqa: E402  (record helpers only; no decision)

BUILD = 'build/archia_mcp'
RUSTC = shutil.which('rustc') or '/Users/mackianni/.cargo/bin/rustc'
RUSTC_VERSION = 'rustc 1.92.0 (ded5c06cf 2025-12-08)'
SSH_KEYGEN = '/usr/bin/ssh-keygen'
PY = sys.executable
# The command of bin/forge-mcp-proxy `build`, with the output in a folder of this script. The output file name is
# always `mcp-proxy` (the linker writes the name into the Mach-O code signature, so another name gives other bytes).
FLAGS = ['--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3']
MAIN = 'src/mcp_proxy/main.rs'
SRC_DIR = 'src/mcp_proxy'
SHARED_RS = ['src/airlock/json.rs', 'src/airlock/pin.rs']  # included by main.rs with #[path]; not new files
SHOWCASE = 'examples/archia_mcp_showcase/run_showcase.py'
JUDGE_FILES = {
    'servers': 'tests/mcp_proxy/test_servers.py',
    'e2e': 'tests/mcp_proxy/test_proxy_e2e.py',
    'unit': 'tests/mcp_proxy/run_unit.py',
    'faults': 'tests/mcp_proxy/test_faults.py',
    'regress': 'tests/mcp_proxy/test_review_regressions.py',
}
# The pre-repair binary that test_review_regressions.py uses only to BUILD one crafted evidence file (its own default).
OLD_BINARY = '/private/tmp/claude-501/-Users-mackianni-forge/fb0fde47-8987-485d-a625-0e9fdb4facee/scratchpad/orch/mcp-proxy'
# bin/forge-airlock must stay at its bytes on main (Goal 20 merged there as 9a9a8943). SHA-256 of the file on
# origin/main b2249ea2, checked on 2026-11-19 with `git show origin/main:bin/forge-airlock | shasum -a 256`. The pin
# makes the check work also in a scratch clone whose `origin/main` is another commit or is missing.
MAIN_FORGE_AIRLOCK_SHA256 = 'bd56d8b6afcd2d4a8a542c9789ebbb3fe6ef1e00a5c31d14e73957658a586891'
MAIN_REF = 'origin/main'
# The main commit this branch was rebased on (origin/main on 2026-11-19). A clone made from another checkout can have
# an older `origin/main` (that checkout's local main): then this commit, which is in the history of HEAD, is the base.
MAIN_COMMIT = 'b2249ea261117e562eec7a2cfd7c3aa6bfb964ee'
MAY_CHANGE_SINCE_MAIN = {'ROADMAP.md', 'unsure.md'}
# The squash commit of this work on main (pull request "Archia MCP airlock demo"). The checks above are pre-merge only.
MERGED_AS = 'a2ef7c0a90ae46f5054356e6c6764074f57ccd73'
RSS_BOUND_MIB = 5.0          # the one bound the owner approved
MUTANT_FLOOD_GIB = '1'       # the showcase flood for changed copies (its smallest value; an integer option)
PARALLEL = 2                 # at most 2 copies (compile + judges) at once: the machine is shared
TIMEOUT = {'servers': 300, 'e2e': 900, 'unit': 1800, 'faults': 1800, 'regress': 1800, 'showcase': 1800}
JUDGE_ORDER = ['e2e', 'unit', 'faults', 'regress', 'showcase']
FAULTS_ARGS = ['--seed', '20261119', '--rounds', '10']  # a fixed seed: its default is the wall clock
MUTANT_FAULTS_ARGS = ['--seed', '20261119', '--rounds', '1']  # changed copies: 1 kill round (10 rounds take about 300 s)


def subject_files():
    """The new files of this work (sorted). Each must exist at the end; a missing one is reported by `evidence`."""
    names = set()
    for pattern in ('src/mcp_proxy/*', 'tests/mcp_proxy/*.py', 'examples/archia_mcp_showcase/**/*'):
        for p in ROOT.glob(pattern):
            if p.is_file() and '__pycache__' not in p.parts and p.name != '.DS_Store':
                names.add(p.relative_to(ROOT).as_posix())
    names.update(['bin/forge-mcp-proxy', 'scripts/exit_archia_mcp.py'])
    return sorted(names)


# ------------------------------------------------------------------------------------------------------- mutants
# (name, file in src/mcp_proxy, exact text (found exactly once), replacement, judge expected first, what is removed)
CONTINUITY_OLD = (    '        } else if v == V_COMMITTED && Some(epoch) != ce.checked_add(1) {\n'
    '            why = Some(format!("commit continuity: COMMITTED epoch {epoch}, expected {} (the commits must have the epochs 1, 2, 3, ...)", ce as u128 + 1));\n'
    '        } else if v == V_COMMITTED && pre != cp {\n'
    '            why = Some(format!("commit continuity: COMMITTED pre is not the post of the previous commit (or the ledger genesis) {}", hash::hex(&cp)));\n'
    '        } else if v != V_COMMITTED && epoch != ce {\n'
    '            why = Some(format!("commit continuity: epoch {epoch} of a non-commit record, expected {ce} (the epoch of the latest commit)"));\n'
    '        } else if v != V_COMMITTED && (pre != cp || post != cp) {')
MUTANTS = [
    # the directive's list
    ('M01_cas_bypass', 'ledger.rs',
     '        if *pre != self.head {\n            return Ok(Cas::Mismatch { epoch: self.epoch, current: self.head });\n        }\n', '',
     'e2e', 'the compare-and-swap of pre_state_hash against the ledger head'),
    ('M02_duplicate_id_skipped', 'ledger.rs',
     '        if let Some(&first_epoch) = self.ids.get(&rid) {\n            return Ok(Cas::Duplicate { first_epoch, epoch: self.epoch, current: self.head });\n        }\n',
     '', 'e2e', 'the duplicate request id check'),
    ('M03_scoped_read_skipped', 'proxy.rs',
     'Some(r) => sh.policy.check_read_result(&p.tool, r).map_err(|d| {',
     'Some(r) => { let _ = r; Ok::<(), crate::policy::Deny>(()) }.map_err(|d| {', 'e2e', 'the scoped-read filter on a sensitive read response'),
    ('M04_ledger_sync_all_dropped', 'ledger.rs', '        if let Err(e) = self.file.sync_all() {\n            let m = format!("{}: sync: {e}", self.path.display());',
     '        if let Err(e) = Ok::<(), std::io::Error>(()) {\n            let m = format!("{}: sync: {e}", self.path.display());', 'faults',
     'the sync_all (F_FULLFSYNC) of a ledger record before Committed'),
    ('M05_signature_faked', 'evidence.rs', 'self.sign_msg(NAMESPACE, hash::hex(chain).as_bytes())', 'self.sign_msg(NAMESPACE, hash::hex(&[0u8; 32]).as_bytes())', 'e2e',
     'the signed message: the signer signs a fixed text instead of the chain hash'),
    ('M06_signature_skipped', 'evidence.rs', '            bytes.extend_from_slice(&sig_frame(idx, &armor));\n', '            let _ = &armor;\n', 'e2e',
     'the SIGNATURE frame of an inline receipt (sync mode, and every Committed)'),
    ('M07_verify_always_exit_0', 'evidence.rs', '    println!("FAILED at={at} records_ok={ok} reason={why}");\n    1\n}',
     '    println!("FAILED at={at} records_ok={ok} reason={why}");\n    0\n}', 'e2e', 'the non-zero exit code of a failed verification'),
    ('M08_forward_before_commit', 'proxy.rs', '        let mut c = lock(&self.sh.core);\n        if c.fault.is_some() {',
     '        let _ = self.forward(line);\n        let mut c = lock(&self.sh.core);\n        if c.fault.is_some() {', 'e2e',
     'the order: ledger commit and receipt BEFORE the forward (the copy forwards first; a committed call goes out twice)'),
    ('M09_forward_of_policy_blocked_call', 'proxy.rs', '        if let Err(d) = self.sh.policy.check_mutation(tool, args) {\n',
     '        if let Err(d) = self.sh.policy.check_mutation(tool, args) {\n            let _ = self.forward(line);\n', 'e2e',
     'zero bytes upstream for a call that the policy blocks'),
    ('M10_commit_receipt_verdict_changed', 'proxy.rs', 'if c.receipt(epoch, tool, &pre, &post, Verdict::Committed).is_err() {',
     'if c.receipt(epoch, tool, &pre, &post, Verdict::ReadAllowed).is_err() {', 'e2e', 'the verdict COMMITTED in the receipt of a commit'),
    ('M11_client_line_cap_removed', 'proxy.rs', '                if line.len() + part.len() > cap {', '                if false {', 'showcase',
     'the line cap of the framing (memory witness: the line buffer grows with the flood)'),
    ('M12_subcap_comparison_flipped', 'policy.rs', '            if d.cmp(cap) == Ordering::Greater {', '            if d.cmp(cap) == Ordering::Less {', 'e2e',
     'the direction of the fact-bound sub-cap comparison'),
    ('M13_default_deny_removed', 'proxy.rs', '            None => return malformed(self, tool, "TOOL_NOT_IN_POLICY"),',
     '            None => return self.forward_request(line, key, idt, None, true),', 'faults', 'default deny of a tool that is not in the policy'),
    ('M14_key_mode_check_removed', 'evidence.rs',
     '    if md.mode() & 0o077 != 0 {\n        return Err(format!("{what}: mode {:o} gives access to group or others (need mode & 0o077 == 0)", md.mode() & 0o7777));\n    }\n',
     '', 'faults', 'the key file mode check (mode & 0o077 == 0)'),
    ('M15_verifier_chain_not_checked', 'evidence.rs', '        if chain_next(&head, r) != e.chain {\n            why = Some("chain link mismatch".into());',
     '        if false {\n            why = Some("chain link mismatch".into());', 'unit', 'the chain link check in verify-evidence'),
    ('M16_epoch_not_advanced', 'ledger.rs', '        self.epoch = epoch;\n        self.head = post;\n        self.ids.insert(rid, epoch);',
     '        self.head = post;\n        self.ids.insert(rid, epoch);', 'e2e', 'the epoch advance of a commit'),
    ('M17_dropped_read_passed_through', 'proxy.rs', '        Err(code) => c.answer_dropped(&p, code),', '        Err(_) => emit(line),', 'e2e',
     'the replacement of a denied read response by the empty dropped-read answer'),
    # more seams
    ('M18_client_cap_raised_to_1_mib', 'proxy.rs', 'pub const CLIENT_CAP: usize = 65_536;', 'pub const CLIENT_CAP: usize = 1 << 20;', 'faults',
     'the client line cap of exactly 65,536 bytes'),
    ('M19_rule_max_flipped', 'policy.rs', '                        if d.cmp(mx) == Ordering::Greater {', '                        if d.cmp(mx) == Ordering::Less {', 'e2e',
     'the direction of the numeric rule maximum'),
    ('M20_rule_min_removed', 'policy.rs',
     '                    if d.cmp(min) == Ordering::Less {\n                        return Err(deny("RULE", format!("argument {arg:?} is below the minimum")));\n                    }\n',
     '', 'unit', 'the numeric rule minimum (default 0: a negative amount is refused)'),
    ('M21_scope_value_not_compared', 'policy.rs',
     '                            J::Str(_) => {\n                                return Err(deny("SCOPE", format!("key {k:?} has a value other than the session {}", self.keys[i].0)))\n                            }',
     '                            J::Str(_) => {}', 'e2e', 'the comparison of a scope label with the session value'),
    ('M22_state_hash_ignores_args', 'ledger.rs', '    h16(&[&framed(&[TAG_STATE, pre, &epoch.to_be_bytes(), rid, tool, args])])',
     '    let _ = args;\n    h16(&[&framed(&[TAG_STATE, pre, &epoch.to_be_bytes(), rid, tool])])', 'unit', 'the argument digest in the state hash'),
    ('M23_commit_receipt_skipped', 'proxy.rs', 'if c.receipt(epoch, tool, &pre, &post, Verdict::Committed).is_err() {',
     'if Ok::<(), String>(()).is_err() {', 'showcase', 'the signed receipt of a commit'),
    ('M24_verifier_accepts_any_signature', 'evidence.rs', '                            if let Err(err) = ssh_verify(allowed, ident, &sp, &e.chain) {',
     '                            if let Err(err) = Ok::<(), String>(()) {', 'unit', 'the ssh-keygen -Y verify call in verify-evidence'),
    ('M25_ledger_lock_removed', 'ledger.rs', '        match file.try_lock() {', '        match Ok::<(), fs::TryLockError>(()) {', 'unit',
     'the exclusive flock of ledger.wal'),
    ('M26_request_id_not_validated', 'proxy.rs', '            Some(J::Str(s)) if valid_request_id(s) => s.as_str(),', '            Some(J::Str(s)) => s.as_str(),',
     'faults', 'the check of forge-airlock/request_id at the proxy (BLOCKED_MALFORMED)'),
    ('M27_late_response_to_dropped_read_passed', 'proxy.rs', '    if c.tombs.remove(&key).is_some() {', '    if c.tombs.remove(&key).is_some() && false {',
     'faults', 'the tombstone of a dropped read (a late upstream response is discarded)'),
    ('M28_refusal_receipt_skipped', 'proxy.rs', '        if let Some(v) = receipt {', '        if let Some(v) = receipt.filter(|_| false) {', 'showcase',
     'the receipt of a refused call'),
    ('M29_unparseable_upstream_line_passed', 'proxy.rs', '        _ => return bad_upstream_line(sh, "UPSTREAM_LINE_NOT_A_JSON_OBJECT"),',
     '        _ => return emit(line),', 'faults', 'the discard of an upstream line that is not a JSON object'),
    ('M30_torn_tail_not_cut', 'ledger.rs', '            file.set_len(st.good_len).map_err(|e| format!("{}: cut torn tail: {e}", path.display()))?;\n', '',
     'unit', 'the cut of a torn last ledger record at open'),
    # one changed copy per repaired finding of the round-3 repair pass (CONTRACT3); each must be KILLED
    ('R01_client_control_byte_check_removed', 'proxy.rs', '        if has_control(line) {\n            return self.frame_error(-32700, "Parse error", "CONTROL_BYTE");',
     '        if false {\n            return self.frame_error(-32700, "Parse error", "CONTROL_BYTE");', 'regress', 'R1: refusal of a client line with a raw control byte'),
    ('R03_jsonrpc_version_check_removed', 'proxy.rs', '        if v.get("jsonrpc") != Some(&J::Str("2.0".into())) {\n            let idt',
     '        if false {\n            let idt', 'regress', 'R3: refusal of a message whose jsonrpc member is not "2.0"'),
    ('R03b_number_length_cap_removed', 'proxy.rs', '        if long_number(&v) {', '        if false {', 'regress', 'R3: refusal of a number token over 64 bytes'),
    ('T1_unknown_id_response_passed', 'proxy.rs', '    if c.inflight.remove(&key).is_none() {', '    if c.inflight.remove(&key).is_none() && false {', 'faults',
     'T1: discard of an upstream response whose id is not in flight (second answer, unasked answer)'),
    ('D1_method_and_result_line_passed', 'proxy.rs', '    if has_method && is_response {', '    if has_method && is_response && false {', 'regress',
     'D1: discard of an upstream line with both method and result/error'),
    ('D1b_exact_result_shape_skipped', 'proxy.rs', '    let verdict: Result<(), &str> = if !exact_result_shape(&v) {', '    let verdict: Result<(), &str> = if false {', 'regress',
     'D1: the exact {jsonrpc, id, result} shape of a filtered response'),
    ('R02_startup_reconciliation_skipped', 'main.rs', '    if let Err(e) = proxy::reconcile(&ledger, &mut ev) {', '    if let Err(e) = Ok::<(), String>(()) {', 'regress',
     'R2: the start-up reconciliation of ledger.wal and evidence.wal'),
    ('B8_verifier_commit_continuity_skipped', 'evidence.rs', CONTINUITY_OLD, CONTINUITY_OLD.replace('} else if v ', '} else if false && v '), 'regress',
     'B8: commit continuity in verify-evidence'),
    ('R04_sticky_evidence_fault_not_set', 'proxy.rs', '            self.fault = Some(e.clone());', '            let _ = e;', 'regress',
     'R4: the sticky receipt fault (later tools/call refused, exit 1)'),
    ('B06_test_signature_at_open_skipped', 'evidence.rs', '        key.sign_msg(TEST_NAMESPACE, TEST_MESSAGE)\n',
     '        Ok::<Vec<u8>, String>(Vec::new())\n', 'regress', 'B6: the test signature at start (a key that cannot sign refuses the start)'),
    ('B04_unsigned_records_signed_in_sync_mode', 'evidence.rs', '            if o.sync_sign {\n                return Err(format!(\n                    "evidence.wal refused: records',
     '            if false {\n                return Err(format!(\n                    "evidence.wal refused: records', 'regress',
     'B4: refusal at open (sync mode) of records that have no signature'),
    ('B05_async_commit_not_signed_inline', 'evidence.rs', '        let inline = self.tx.is_none() || verdict == Verdict::Committed;',
     '        let inline = self.tx.is_none();', 'regress', 'B5: a Committed receipt is signed and synced before append returns, also in async mode'),
    ('B01_bind_check_skipped', 'policy.rs', '        for b in &t.binds {', '        for b in t.binds.iter().take(0) {', 'regress',
     'B1: the scope bind of a mutating call (trusted fact == session value)'),
    ('B02_text_scope_check_off', 'policy.rs', '                if n.contains(nk.as_str()) {', '                if false && n.contains(nk.as_str()) {', 'regress',
     'B2: the scope key name check in plain text and in object keys'),
    ('B03_deny_detail_sent_to_client', 'proxy.rs', '            return self.refuse(&idt, tool, Some(v), w, d.code);',
     '            return self.refuse(&idt, tool, Some(v), w, &format!("{}: {}", d.code, d.detail));', 'regress',
     'B3: only Deny.code goes to the client (the detail can name a foreign fact)'),
    ('L01_store_folder_mode_check_removed', 'ledger.rs', '    if m.mode() & 0o022 != 0 {', '    if false {', 'faults',
     'the store folder mode check (mode & 0o022 == 0)'),
    ('E01_evidence_sync_dropped', 'evidence.rs', '        f.sync_data().map_err(|e| format!("evidence.wal sync: {e}"))', '        let _ = &f;\n        Ok(())', 'faults',
     'the evidence-side twin of M04: sync_data (F_FULLFSYNC) of evidence.wal after each frame write'),
]

# Copies that no judge is expected to kill, with the reason. See the convention at the top of this file.
EXPECTED_NOT_KILLED = {
    'M04_ledger_sync_all_dropped':
        'No black-box witness: the record is written with write_all_at before the dropped sync, and the page cache keeps '
        'it for every reader and for a SIGKILL of the proxy. Only a power loss or a system-call observer (an interposer '
        'that counts fcntl(F_FULLFSYNC), as tests/silicon_sink/interpose.c does for Goal 19) can see it. This work may '
        'not add C code or edit the Rust files, so no honest judge exists here. A FINDING, not a pass.',
    'E01_evidence_sync_dropped':
        'The twin of M04 in evidence.rs, with the same reason: the frames are written before the dropped sync_data and the '
        'page cache serves every later reader; no judge cuts power or observes fcntl(F_FULLFSYNC). A FINDING, not a pass.',
    'M27_late_response_to_dropped_read_passed':
        'No distinguishing input found; not shown equivalent. Probe (EXIT worker, 2026-11-19): four scripted hostile '
        'upstream sequences (a dropped read answered late, before and after its id was re-used, by a held new request, '
        'several late answers, own and foreign clinic) gave byte-identical client output from this copy and the '
        'unchanged build. The tombstone is removed in both (the `&& false` keeps the remove), and a dropped id has left '
        'the in-flight set, so the in-flight rule discards the late answer in both.',
}


class Failed(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Failed(message)


def run(argv, cwd=ROOT, timeout=None, env=None):
    try:
        return subprocess.run([str(a) for a in argv], cwd=str(cwd), capture_output=True, text=True, timeout=timeout, env=env,
                              errors='replace')
    except subprocess.TimeoutExpired as e:
        out = (e.stdout or b'').decode('utf-8', 'replace') if isinstance(e.stdout, bytes) else (e.stdout or '')
        return subprocess.CompletedProcess(argv, 'TIMEOUT', out, 'TIMEOUT after %s s' % timeout)


def toolchain():
    seen = {'rustc': run([RUSTC, '-V']).stdout.strip(), 'python': platform.python_version(),
            'machine': platform.system() + ' ' + platform.machine(), 'ssh_keygen': SSH_KEYGEN}
    if seen['rustc'] != RUSTC_VERSION or seen['machine'] != 'Darwin arm64' or not os.access(SSH_KEYGEN, os.X_OK):
        raise RuntimeError('TOOLCHAIN_ERROR: observed %r, pinned rustc %r on Darwin arm64' % (seen, RUSTC_VERSION))
    return seen


def snapshot():
    return {name: digest((ROOT / name).read_bytes()) for name in subject_files() + SHARED_RS if (ROOT / name).is_file()}


def mirror(folder, replace=None):
    """A tree with the files that the proxy build and the judges read. `replace` = (file in src/mcp_proxy, text)."""
    for rel in [SRC_DIR, 'tests/mcp_proxy', 'examples/archia_mcp_showcase']:
        shutil.copytree(ROOT / rel, folder / rel, ignore=shutil.ignore_patterns('__pycache__', '.DS_Store'))
    for rel in SHARED_RS + ['bin/forge-mcp-proxy']:
        (folder / rel).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(ROOT / rel, folder / rel)
    if replace:
        (folder / SRC_DIR / replace[0]).write_text(replace[1])
    return folder


def compile_in(tree, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / 'mcp-proxy'
    return out, run([RUSTC] + FLAGS + [MAIN, '-o', out], cwd=tree, timeout=900)


# --------------------------------------------------------------------------------------------------------- build
def merged():
    """True when MERGED_AS is an ancestor of HEAD, False when it is not (the pre-merge checks run). Git cannot answer (no
    repository, or a shallow clone without the commit): NOT RUN, which fails the case."""
    p = run(['git', 'merge-base', '--is-ancestor', MERGED_AS, 'HEAD'])
    if p.returncode == 0:
        return True
    if p.returncode == 1:
        return False
    known = run(['git', 'cat-file', '-e', MERGED_AS + '^{commit}']).returncode == 0
    shallow = run(['git', 'rev-parse', '--is-shallow-repository'])
    if not known and shallow.returncode == 0 and shallow.stdout.strip() == 'false':
        return False    # a full history without the commit: it is not an ancestor
    raise Failed('MAIN: NOT RUN: git cannot say whether %s is an ancestor of HEAD (exit %s: %s); the pre-merge checks '
                 'cannot run' % (MERGED_AS[:8], p.returncode, (p.stderr or '').strip()[:200]))


def main_base():
    """The commit of main to compare with: `git merge-base HEAD origin/main` when that is MAIN_COMMIT or newer, else
    MAIN_COMMIT when it is an ancestor of HEAD. Neither: NOT RUN, which fails the case."""
    def ancestor(a, b):
        return run(['git', 'merge-base', '--is-ancestor', a, b]).returncode == 0
    mb = run(['git', 'merge-base', 'HEAD', MAIN_REF])
    mb = mb.stdout.strip() if mb.returncode == 0 else ''
    if re.fullmatch(r'[0-9a-f]{40}', mb) and ancestor(MAIN_COMMIT, mb):
        return mb
    if ancestor(MAIN_COMMIT, 'HEAD'):
        return MAIN_COMMIT
    raise Failed('MAIN: NOT RUN: neither `git merge-base HEAD %s` (%s) nor the pinned main commit %s is a usable base; '
                 'the check "no file of main is modified" cannot run' % (MAIN_REF, mb[:8] or 'no such ref', MAIN_COMMIT[:8]))


def build(work):
    work.mkdir(parents=True)
    files = sorted((ROOT / SRC_DIR).glob('*.rs'))
    imports, problems = [], []
    for p in files + [ROOT / s for s in SHARED_RS]:
        for n, line in enumerate(p.read_text().splitlines(), 1):
            s = line.strip()
            if re.match(r'(pub(\([a-z]+\))? )?use ', s):
                imports.append(s)
                path = re.sub(r'^(pub(\([a-z]+\))? )?use ', '', s)
                # std, the crate itself, or a local enum/type in scope (a capitalized root such as `Verdict::*`)
                if not re.match(r'(std|crate|super|self|[A-Z][A-Za-z0-9_]*)::', path):
                    problems.append('%s:%d %s' % (p.name, n, s))
            if re.search(r'\bextern\s+crate\b', s) and not s.startswith('//'):
                problems.append('%s:%d %s' % (p.name, n, s))
    main_lines = (ROOT / MAIN).read_text().splitlines()
    require('#![forbid(unsafe_code)]' in main_lines, 'SOURCE: main.rs has no #![forbid(unsafe_code)]')
    require(not problems, 'SOURCE: an import is not from std/crate, or an extern crate: %r' % problems)
    require(not list(ROOT.glob('src/mcp_proxy/Cargo.*')) and not (ROOT / 'Cargo.toml').exists(), 'SOURCE: a Cargo file exists')
    require((ROOT / 'bin/forge-mcp-proxy').is_file(), 'SOURCE: the launcher bin/forge-mcp-proxy is missing')
    is_merged = merged()
    if is_merged:
        for check in ('bin/forge-airlock SHA-256 pin', 'no file of main is modified'):
            print('  pre-merge check not applicable: %s (merged as %s)' % (check, MERGED_AS[:8]), flush=True)
        base, changed = None, []
    else:
        require(digest((ROOT / 'bin/forge-airlock').read_bytes()) == MAIN_FORGE_AIRLOCK_SHA256,
                'MAIN: bin/forge-airlock is not byte-identical to main (SHA-256 pin %s)' % MAIN_FORGE_AIRLOCK_SHA256[:12])
        base = main_base()
        at_base = subprocess.run(['git', 'show', base + ':bin/forge-airlock'], cwd=ROOT, capture_output=True)
        require(at_base.returncode == 0 and digest(at_base.stdout) == MAIN_FORGE_AIRLOCK_SHA256,
                'MAIN: bin/forge-airlock at the merge base %s is not the pinned main file' % base[:8])
        diff = run(['git', 'diff', '--name-status', base])
        require(diff.returncode == 0, 'MAIN: git diff exit %s' % diff.returncode)
        changed = [line.split('\t') for line in diff.stdout.splitlines() if line.strip()]
        touched = sorted(parts[-1] for parts in changed if parts[0] != 'A' and parts[-1] not in MAY_CHANGE_SINCE_MAIN)
        require(not touched, 'MAIN: files of main (merge base %s) are modified, deleted or renamed: %r' % (base[:8], touched))
    binaries = []
    for k in (1, 2):
        out, done = compile_in(ROOT, work / ('build-%d' % k))
        require(done.returncode == 0 and done.stdout == '' and done.stderr == '',
                'BUILD %d: rustc gave exit %s\n%s' % (k, done.returncode, done.stderr[-3000:]))
        binaries.append(out)
    one, two = binaries[0].read_bytes(), binaries[1].read_bytes()
    reproducible = one == two
    control = mirror(work / 'unsafe-control')
    (control / MAIN).write_text((ROOT / MAIN).read_text() + '\nfn control() -> u8 { unsafe { *(1 as *const u8) } }\n')
    out, refused = compile_in(control, work / 'unsafe-control-out')
    require(refused.returncode not in (0, 'TIMEOUT') and 'unsafe' in refused.stderr and not out.exists(),
            'CONTROL: a copy with one unsafe block compiled (exit %s)' % refused.returncode)
    shutil.rmtree(control)
    final = ROOT / BUILD / 'mcp-proxy'
    final.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(binaries[0], final)
    na = 'NOT APPLICABLE: pre-merge check; merged as ' + MERGED_AS
    record = {'compile_command': ['rustc'] + FLAGS + [MAIN, '-o', '<folder>/mcp-proxy'], 'compile_exit': 0, 'compiler_output_bytes': 0,
              'main_bin_forge_airlock_byte_identical': na if is_merged else True, 'main_bin_forge_airlock_sha256': MAIN_FORGE_AIRLOCK_SHA256,
              'main_files_modified': na if is_merged else sorted(parts[-1] for parts in changed if parts[0] != 'A'),
              'main_files_modified_allowed': sorted(MAY_CHANGE_SINCE_MAIN), 'launcher_bin_forge_mcp_proxy_exists': True,
              'forbid_unsafe_code_in_main_rs': True, 'imports_std_or_crate_only': True, 'extern_crate': 0, 'cargo_used': False,
              'rust_files': [p.relative_to(ROOT).as_posix() for p in files] + SHARED_RS,
              'unsafe_control': {'what': 'main.rs plus one function with an unsafe block, same command', 'compile_failed': True},
              'two_builds_byte_identical': reproducible}
    if reproducible:
        record['binary_sha256'] = digest(one)
    measured = {'merge_base_with_' + MAIN_REF.replace('/', '_'): base if base else na,
                'files_added_since_merge_base': na if is_merged else sum(1 for parts in changed if parts[0] == 'A'),
                'pre_merge_checks': na if is_merged else 'RUN (%s is not an ancestor of HEAD)' % MERGED_AS[:8],
                'binary_sha256_build_1': digest(one), 'binary_sha256_build_2': digest(two), 'binary_bytes': len(one), 'binary': str(final)}
    return final, record, measured


# --------------------------------------------------------------------------------------------------------- judges
LINE = re.compile(r'^(PASS|FAIL|NOT RUN|KNOWN LIMIT|ERROR)\s+(\S+)')
RUST_TEST = re.compile(r'^test (\S+) \.\.\. (ok|FAILED|ignored)')


def parse_cases(text):
    """Per case: PASS / FAIL / NOT RUN, from `PASS name` lines of the Python suites or `test x ... ok` lines of rustc."""
    out = {}
    for line in text.splitlines():
        m = LINE.match(line)
        if m:
            out[m.group(2).rstrip(':')] = m.group(1)
            continue
        m = RUST_TEST.match(line)
        if m:
            out[m.group(1)] = {'ok': 'PASS', 'FAILED': 'FAIL', 'ignored': 'IGNORED'}[m.group(2)]
    return out


def judge(kind, tree, binary, work, flood=None, copy=False):
    """Run one judge from `tree`. Returns a dict: exit, cases, failed (sorted case names), text."""
    script = tree / (SHOWCASE if kind == 'showcase' else JUDGE_FILES[kind])
    work.mkdir(parents=True, exist_ok=True)
    if not script.is_file():
        return {'judge': kind, 'exit': 'NOT RUN', 'failed': [], 'cases': {}, 'text': 'NOT RUN: %s is missing' % script.relative_to(tree)}
    env = dict(os.environ, MCP_TEST_TMP=str(work), PYTHONDONTWRITEBYTECODE='1', FORGE_MCP_PROXY=str(binary))
    tmp = work / 'tmp'
    tmp.mkdir(exist_ok=True)
    env['TMPDIR'] = str(tmp) + '/'
    argv = [PY, '-B', script]
    if kind in ('e2e', 'faults'):
        argv += ['--binary', binary]
    if kind == 'faults':
        argv += MUTANT_FAULTS_ARGS if copy else FAULTS_ARGS
    if kind == 'regress':
        argv += ['--binary', binary] + (['--old-binary', OLD_BINARY] if os.path.isfile(OLD_BINARY) else [])
    if kind == 'unit':
        argv += ['--source', tree / SRC_DIR, '--out', work / 'unit-bin']
    if kind == 'showcase':
        argv += ['--binary', binary, '--work', work / 'show', '--json', work / 'showcase.json', '--no-color', '--no-pause']
        if flood is not None:
            argv += ['--flood-gib', flood]
    start = time.monotonic()
    done = run(argv, cwd=tree, timeout=TIMEOUT[kind], env=env)
    text = done.stdout + '\n--- stderr ---\n' + done.stderr
    (work / (kind + '.log')).write_text(text)
    result = {'judge': kind, 'exit': done.returncode, 'wall_s': round(time.monotonic() - start, 1), 'text': text}
    if kind == 'showcase':
        data = None
        try:
            data = json.loads((work / 'showcase.json').read_text())
        except (OSError, ValueError):
            pass
        result['json'] = data
        checks = (data or {}).get('checks', {})
        result['cases'] = {k: 'PASS' if v is True else 'FAIL' for k, v in checks.items()}
        rss = rss_mib((data or {}).get('metrics', {}))
        result['rss_mib'] = rss
        if rss is not None and rss >= RSS_BOUND_MIB:
            result['cases']['proxy_peak_rss_below_5_0_mib'] = 'FAIL'
        elif rss is not None:
            result['cases']['proxy_peak_rss_below_5_0_mib'] = 'PASS'
    elif kind == 'unit':
        # run_unit.py prints `FAILED <test>` per failed test and one `RESULT PASS` or `RESULT FAIL: <why>` line.
        cases = {'unit:' + n: 'FAIL' for n in re.findall(r'^FAILED (\S+)$', done.stdout, re.M)}
        verdict = re.findall(r'^RESULT (PASS|FAIL)(.*)$', done.stdout, re.M)
        if verdict:
            cases['unit:RESULT'] = 'PASS' if verdict[-1][0] == 'PASS' else 'FAIL'
        result['cases'] = cases
    else:
        result['cases'] = parse_cases(done.stdout)
    result['failed'] = sorted(k for k, v in result['cases'].items() if v in ('FAIL', 'NOT RUN', 'ERROR'))
    return result


def rss_mib(metrics):
    """The proxy peak RSS in MiB from the showcase metrics (the key names are SHOWCASE's; see run_showcase.py)."""
    if isinstance(metrics.get('flood_peak_rss_kib'), (int, float)):
        return metrics['flood_peak_rss_kib'] / 1024.0
    for key in ('proxy_peak_rss_mib', 'peak_rss_mib'):
        if isinstance(metrics.get(key), (int, float)):
            return float(metrics[key])
    for key in ('proxy_peak_rss_kib', 'peak_rss_kib'):
        if isinstance(metrics.get(key), (int, float)):
            return metrics[key] / 1024.0
    for key in ('proxy_peak_rss_bytes', 'peak_rss_bytes'):
        if isinstance(metrics.get(key), (int, float)):
            return metrics[key] / 1048576.0
    for value in metrics.values():
        if isinstance(value, dict):
            found = rss_mib(value)
            if found is not None:
                return found
    return None


def killed(result):
    """A kill: the judge exited 1 (a check failed, not a setup error, not a timeout) and named at least one failed case."""
    return result['exit'] == 1 and bool(result['failed'])


# ---------------------------------------------------------------------------------------------- suite (own check)
def wal_replay(work, binary):
    """Two sequential runs of one call sequence with --test-clock 1000 and one key: evidence.wal and ledger.wal must
    be byte-identical. A third run with --test-clock 2000 must give another evidence.wal (the check can fail)."""
    sys.path.insert(0, str(ROOT / 'tests/mcp_proxy'))
    from mcp_client import McpClient  # noqa: E402
    work.mkdir(parents=True)
    key = work / 'key'
    done = run([SSH_KEYGEN, '-q', '-t', 'ed25519', '-N', '', '-C', 'forge-airlock-exit', '-f', key])
    require(done.returncode == 0, 'WAL_REPLAY: ssh-keygen exit %s' % done.returncode)
    key.chmod(0o600)
    pub = (work / 'key.pub').read_text().split()
    signers = work / 'allowed_signers'
    signers.write_text('forge-airlock-exit namespaces="forge-airlock-evidence" %s %s\n' % (pub[0], pub[1]))
    show = ROOT / 'examples/archia_mcp_showcase'

    def one(name, clock):
        d = work / name
        store = d / 'store'
        store.mkdir(parents=True)
        store.chmod(0o700)
        server = [PY, '-B', show / 'servers/fintech_server.py', '--balance', '1000.00', '--audit', d / 'audit.jsonl', '--wire-log', d / 'wire.log']
        argv = [binary, 'mcp', '--policy', show / 'policies/fintech.policy.json', '--agent-id', 'agent-exit', '--store', store, '--key', key,
                '--session', 'org_id=Org_Alpha', '--test-clock', str(clock), '--'] + server
        c = McpClient([str(a) for a in argv], cwd=str(ROOT), stderr_path=str(d / 'proxy.stderr'))
        seen = []
        try:
            c.initialize()
            pre = c.request('forge-airlock/state', {})['result']['state']

            def pay(rid, pre_hash, amount='100.00'):
                return c.call_tool('issue_payout', {'amount': amount, 'invoice_id': 'INV-A-1001', 'vendor': 'V'},
                                   meta={'forge-airlock/request_id': rid, 'forge-airlock/pre_state_hash': pre_hash})

            def word(r):
                if 'error' in r:
                    return r['error']['data']['verdict']
                return 'READ_DROPPED' if r['result'].get('isError') else 'OK'
            seen.append(('pay-1', word(pay('pay-1', pre))))
            cur = c.request('forge-airlock/state', {})['result']['state']
            seen.append(('stale', word(pay('stale-1', pre))))
            seen.append(('duplicate', word(pay('pay-1', cur))))
            seen.append(('over_rule', word(pay('big-1', cur, '500.01'))))
            seen.append(('foreign_read', word(c.call_tool('list_invoices', {}))))
            seen.append(('own_read', word(c.call_tool('list_invoices', {'org_id': 'Org_Alpha'}))))
            c.send_raw(b'{not json\n')
            other = c.wait_other(1)
            seen.append(('malformed_line', other[-1].get('error', {}).get('data', {}).get('verdict')))
            seen.append(('unknown_tool', word(c.call_tool('delete_everything', {}))))
            seen.append(('pay-2', word(pay('pay-2', cur))))
        finally:
            code = c.close()
        require(code == 0, 'WAL_REPLAY: proxy exit %s in %s' % (code, name))
        v = run([binary, 'verify-evidence', store / 'evidence.wal', '--allowed-signers', signers, '--identity', 'forge-airlock-exit'], timeout=300)
        require(v.returncode == 0, 'WAL_REPLAY: verify-evidence exit %s in %s\n%s' % (v.returncode, name, v.stdout[-1500:]))
        verdicts = re.findall(r' verdict=(\S+) OK', v.stdout)
        return (store / 'evidence.wal').read_bytes(), (store / 'ledger.wal').read_bytes(), seen, verdicts

    a = one('run-a', 1000)
    b = one('run-b', 1000)
    c3 = one('run-c', 2000)
    want = [('pay-1', 'OK'), ('stale', 'BLOCKED_CAS'), ('duplicate', 'BLOCKED_DUPLICATE'), ('over_rule', 'BLOCKED_POLICY'),
            ('foreign_read', 'READ_DROPPED'), ('own_read', 'OK'), ('malformed_line', 'BLOCKED_MALFORMED'),
            ('unknown_tool', 'BLOCKED_MALFORMED'), ('pay-2', 'OK')]
    require(a[2] == want and b[2] == want and c3[2] == want, 'WAL_REPLAY: answers %r, want %r' % (a[2], want))
    require(a[3] == b[3], 'WAL_REPLAY: verify-evidence verdict lists differ')
    same_evidence, same_ledger, other_clock_differs = a[0] == b[0], a[1] == b[1], a[0] != c3[0]
    require(same_evidence, 'WAL_REPLAY: the two evidence.wal files of one sequential sequence differ')
    require(same_ledger, 'WAL_REPLAY: the two ledger.wal files differ')
    require(other_clock_differs, 'WAL_REPLAY: another --test-clock gave the same evidence.wal: the check cannot fail')
    record = {'what': 'one sequential call sequence (each answer awaited before the next line), --test-clock 1000, one Ed25519 key, '
                      'two fresh stores; a race has no fixed order and is NOT covered',
              'answers': [list(x) for x in want], 'receipt_verdicts': a[3], 'receipts': len(a[3]),
              'evidence_wal_byte_identical': True, 'ledger_wal_byte_identical': True, 'other_test_clock_gives_other_bytes': True}
    measured = {'evidence_wal_sha256': digest(a[0]), 'evidence_wal_bytes': len(a[0]), 'ledger_wal_sha256': digest(a[1]),
                'note': 'the evidence.wal hash depends on the temporary key; it is not in the bundle'}
    return record, measured


def suite(work, binary):
    work.mkdir(parents=True)
    out, measured, missing, failed = {}, {}, [], []
    for kind in ('servers', 'e2e', 'unit', 'faults', 'regress'):
        r = judge(kind, ROOT, binary, work / kind)
        out[kind] = {'argv': ['python3', '-B', JUDGE_FILES[kind]] + (['--binary', '<binary>'] if kind in ('e2e', 'faults', 'regress') else [])
                     + (['--old-binary', '<pre-repair binary>'] if kind == 'regress' else [])
                     + (FAULTS_ARGS if kind == 'faults' else [])
                     + (['--source', SRC_DIR, '--out', '<folder>'] if kind == 'unit' else []),
                     'exit_code': r['exit'], 'cases': r['cases'], 'failed': r['failed']}
        measured[kind] = {'wall_s': r.get('wall_s')}
        if r['exit'] == 'NOT RUN':
            missing.append(JUDGE_FILES[kind])
        elif r['exit'] != 0 or r['failed'] or not r['cases']:
            failed.append('%s (exit %s, failed %r)\n%s' % (kind, r['exit'], r['failed'], r['text'][-2500:]))
        print('  %-8s exit %-7s %3d cases, failed %r' % (kind, r['exit'], len(r['cases']), r['failed']), flush=True)
    for name in missing:
        print('  NOT RUN: %s is missing' % name, flush=True)
    own, own_measured = wal_replay(work / 'wal-replay', binary)
    print('  wal_replay: evidence.wal and ledger.wal byte-identical over %d receipts; other clock differs' % own['receipts'], flush=True)
    out['wal_replay'] = own
    measured['wal_replay'] = own_measured
    require(not missing, 'SUITE: NOT RUN (file missing): %r' % missing)
    require(not failed, 'SUITE: a judge failed:\n' + '\n'.join(failed))
    return out, measured


# ------------------------------------------------------------------------------------------------------- showcase
LATENCY = re.compile(r'(latency|_ms$|p50|p99|throughput|drain|rss|_s$|seconds|time)', re.I)


def showcase(work, binary, flood=None):
    r = judge('showcase', ROOT, binary, work, flood)
    require(r['exit'] != 'NOT RUN', 'SHOWCASE: NOT RUN: %s is missing' % SHOWCASE)
    data = r.get('json')
    require(isinstance(data, dict) and isinstance(data.get('checks'), dict) and data['checks'],
            'SHOWCASE: no --json result (exit %s)\n%s' % (r['exit'], r['text'][-3000:]))
    false = sorted(k for k, v in data['checks'].items() if v is not True)
    require(r['rss_mib'] is not None, 'SHOWCASE: no proxy peak RSS in metrics %r' % sorted(data.get('metrics', {})))
    require(not false and r['exit'] == 0, 'SHOWCASE: exit %s, checks not true: %r\n%s' % (r['exit'], false, r['text'][-2500:]))
    require(r['rss_mib'] < RSS_BOUND_MIB, 'SHOWCASE: proxy peak RSS %.3f MiB, bound %.1f MiB' % (r['rss_mib'], RSS_BOUND_MIB))
    record = {'argv': ['python3', '-B', SHOWCASE, '--binary', '<binary>', '--work', '<folder>', '--json', '<file>', '--no-color', '--no-pause']
              + (['--flood-gib', flood] if flood else []),
              'exit_code': 0, 'checks': sorted(data['checks']), 'checks_all_true': True, 'beats': data.get('beats'),
              'asserted_bound': 'proxy peak RSS < %.1f MiB (owner-approved); NO latency assertion (owner decision)' % RSS_BOUND_MIB,
              'proxy_peak_rss_below_bound': True}
    measured = {'wall_s': r['wall_s'], 'proxy_peak_rss_mib': r['rss_mib'], 'metrics': data.get('metrics')}
    return record, measured


# ------------------------------------------------------------------------------------------------------ mutations
def mutant_text(name, file, old, new):
    text = (ROOT / SRC_DIR / file).read_text()
    require(text.count(old) == 1, 'MUTANTS: the text of %s is found %d times in %s, expected 1' % (name, text.count(old), file))
    return text.replace(old, new)


def run_copy(work, name, replace, judges):
    """Build one copy and run every judge on it (they are cheap: about 3 to 15 s each). Returns a row."""
    folder = work / name
    tree = mirror(folder / 'tree', replace)
    binary, done = compile_in(tree, folder / 'bin')
    row = {'name': name, 'compiled': done.returncode == 0, 'judges': []}
    if done.returncode != 0:
        (folder / 'compile.log').write_text(done.stderr)
        row['compile_error'] = done.stderr[-1500:]
        return row
    for kind in judges:
        r = judge(kind, tree, binary, folder / kind, MUTANT_FLOOD_GIB if kind == 'showcase' else None, copy=True)
        row['judges'].append({'judge': kind, 'exit_code': r['exit'], 'failed': r['failed'], 'killed': killed(r), 'wall_s': r.get('wall_s'),
                              'cases_seen': len(r['cases'])})
    return row


def mutations(work):
    work.mkdir(parents=True)
    names = [m[0] for m in MUTANTS]
    require(len(set(names)) == len(names), 'MUTANTS: a name is used twice')
    require(set(EXPECTED_NOT_KILLED) <= set(names), 'MUTANTS: an expected survivor is not in the list')
    texts = {m[0]: (m[1], mutant_text(*m[:4])) for m in MUTANTS}  # every text must be found exactly once before anything runs
    missing = [JUDGE_FILES[k] for k in ('e2e', 'unit', 'faults', 'regress') if not (ROOT / JUDGE_FILES[k]).is_file()]
    missing += [SHOWCASE] if not (ROOT / SHOWCASE).is_file() else []
    for name in missing:
        print('  judge NOT RUN: %s is missing' % name, flush=True)
    control = run_copy(work, 'unchanged', None, JUDGE_ORDER)
    bad = [j for j in control['judges'] if j['exit_code'] != 0 or j['failed']]
    require(control['compiled'], 'MUTANTS: the unchanged copy does not compile\n' + control.get('compile_error', ''))
    bad = [j for j in bad if j['exit_code'] != 'NOT RUN']
    require(not bad, 'MUTANTS: the unchanged copy does not pass every judge: %r' % bad)
    print('  unchanged copy: %s' % ', '.join('%s exit %s' % (j['judge'], j['exit_code']) for j in control['judges']), flush=True)

    def task(m):
        name, file, _, _, first, _ = m
        row = run_copy(work, name, texts[name], JUDGE_ORDER)
        kills = ['%s %s' % (j['judge'], j['failed'][:3]) for j in row['judges'] if j['killed']]
        print('  %-40s %s' % (name, ('KILLED by ' + '; '.join(kills)) if kills else
                              'NOT KILLED' if row['compiled'] else 'INVALID (does not compile)'), flush=True)
        shutil.rmtree(work / name / 'tree', ignore_errors=True)
        return row

    with ThreadPoolExecutor(max_workers=PARALLEL) as pool:
        rows = list(pool.map(task, MUTANTS))
    table, invalid, not_killed, measured = [], [], [], {}
    for m, row in zip(MUTANTS, rows):
        name, file, _, _, first, removed = m
        kills = [j for j in row['judges'] if j['killed']]
        kill = kills[0] if kills else None
        if not row['compiled']:
            invalid.append(name)
        elif kill is None:
            not_killed.append(name)
        # The bundle keeps only what repeats: compiled, killed. WHICH cases fail on a killed copy depends on timing for
        # some copies (observed 2026-11-20: M08 and B05 failed 1 to 2 more secondary cases in one of two runs), so the
        # judges and their failed cases go to measurements.json, not to the bundle.
        table.append({'name': name, 'file': SRC_DIR + '/' + file, 'removed': removed, 'judge_expected': first,
                      'compiled': row['compiled'], 'killed': kill is not None})
        measured[name] = {'killed_by': [{'judge': j['judge'], 'failed_cases': j['failed']} for j in kills],
                          'judges_run': [{'judge': j['judge'], 'exit_code': j['exit_code'], 'failed_cases': j['failed'], 'wall_s': j['wall_s']}
                                         for j in row['judges']]}
    k = sum(r['killed'] for r in table)
    result = {'changed_copies': len(table), 'killed': k, 'not_killed': sorted(not_killed), 'invalid_do_not_compile': sorted(invalid),
              'expected_not_killed': {n: EXPECTED_NOT_KILLED[n] for n in sorted(EXPECTED_NOT_KILLED)},
              'judges_missing_not_run': missing, 'flood_gib_for_copies': MUTANT_FLOOD_GIB, 'faults_args_for_copies': MUTANT_FAULTS_ARGS,
              'unchanged_copy': [{'judge': j['judge'], 'exit_code': j['exit_code']} for j in control['judges']],
              'kill_table_in': 'measurements.json (key mutations): judges that killed each copy and their failed cases',
              'kill_rule': 'a judge exits 1 (not a setup error, not a timeout) and names at least one failed case; the unchanged copy passed '
                           'the same judges in the same harness; a compile failure is NOT a kill',
              'table': table}
    line = 'mutations: %d of %d killed; NOT KILLED: %s' % (k, len(table), json.dumps(sorted(not_killed)))
    ok = not invalid and not missing and sorted(not_killed) == sorted(EXPECTED_NOT_KILLED)
    return result, measured, line, ok


# ------------------------------------------------------------------------------------------------------- evidence
def bundle_of(work):
    before = snapshot()
    tools = toolchain()
    binary, built, m_build = build(work / 'build')
    print('  build: exit 0; two builds byte-identical: %s' % built['two_builds_byte_identical'], flush=True)
    suites, m_suite = suite(work / 'suite', binary)
    shown, m_show = showcase(work / 'showcase', binary)
    print('  showcase: %d checks true; proxy peak RSS %.3f MiB' % (len(shown['checks']), m_show['proxy_peak_rss_mib']), flush=True)
    changed, m_mut, line, ok = mutations(work / 'mutations')
    print('  ' + line, flush=True)
    require(snapshot() == before, 'INPUT_CHANGED: a subject file changed during the checks')
    bundle = {
        'record': 'forge-archia-mcp-airlock-demo', 'format_version': 1,
        'gate_accepted': False, 'policy': None, 'end_to_end': False, 'kind': 'FINITE TEST', 'proved': False,
        'producer': 'scripts/exit_archia_mcp.py (a scenario script; not the gate)',
        'note': 'A record of real tool runs on one machine. The Rust proxy is an unproved NATIVE CHECK. A test count is not a proof. '
                'No time, no RSS value, no absolute path, no process id and no key-dependent hash is in this record.',
        'subject': [{'path': name, 'sha256': before[name]} for name in sorted(before)],
        'toolchain': tools, 'build': built, 'suite': suites, 'showcase': shown, 'mutations': changed,
        'mutations_case_passed': ok, 'mutations_line': line,
        'reproduce_cmd': 'python3 scripts/exit_archia_mcp.py --case evidence',
    }
    return bundle, {'build': m_build, 'suite': m_suite, 'showcase': m_show, 'mutations': m_mut}, ok, line


def attempt_folder(case):
    base = ROOT / BUILD / case
    base.mkdir(parents=True, exist_ok=True)
    number = 1 + max([int(p.name.split('-')[1]) for p in base.glob('attempt-*')] or [0])
    return base / ('attempt-%04d' % number)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--case', required=True, choices=('build', 'suite', 'showcase', 'mutations', 'evidence'))
    args = parser.parse_args()
    work = attempt_folder(args.case)
    name = work.relative_to(ROOT).as_posix()
    print('ARCHIA_MCP ' + args.case + ': ' + name, flush=True)
    start = time.monotonic()
    last = None
    try:
        toolchain()
        if args.case == 'build':
            _, result, measured = build(work)
            print('  rustc %s -> exit 0; imports std/crate only; unsafe control did not compile; two builds byte-identical: %s'
                  % (' '.join(FLAGS + [MAIN]), result['two_builds_byte_identical']))
            print('  binary sha256 %s (build 2: %s)' % (measured['binary_sha256_build_1'], measured['binary_sha256_build_2']))
        elif args.case == 'suite':
            binary, _, _ = build(work / 'build')
            suite(work / 'suite', binary)
        elif args.case == 'showcase':
            binary, _, _ = build(work / 'build')
            record, measured = showcase(work / 'showcase', binary)
            print('  %d checks true: %s' % (len(record['checks']), ', '.join(record['checks'])))
            print('  measured (not asserted except RSS): ' + json.dumps(measured, sort_keys=True))
        elif args.case == 'mutations':
            build(work / 'build')
            result, measured, last, ok = mutations(work / 'copies')
            (work / 'mutations.json').write_text(json.dumps(result, indent=1, sort_keys=True) + '\n')
            (work / 'measurements.json').write_text(json.dumps(measured, indent=1, sort_keys=True) + '\n')
            if not ok:
                if result['invalid_do_not_compile']:
                    print('  INVALID copies (do not compile): %r' % result['invalid_do_not_compile'])
                if result['judges_missing_not_run']:
                    print('  judges NOT RUN (missing): %r' % result['judges_missing_not_run'])
                print('  expected NOT KILLED: %s' % json.dumps(sorted(EXPECTED_NOT_KILLED)))
                print('ARCHIA_MCP mutations: FAILED; end_to_end=false')
                print(last)
                return 1
        else:
            work.mkdir(parents=True)
            bundles, lines, oks = [], [], []
            for number in (1, 2):
                print(' run ' + str(number), flush=True)
                bundle, measured, ok, line = bundle_of(work / ('run-%d' % number))
                bundles.append(canonical(bundle))
                oks.append(ok)
                lines.append(line)
                (work / ('run-%d' % number) / 'evidence.json').write_bytes(bundles[-1])
                (work / ('run-%d' % number) / 'measurements.json').write_text(json.dumps(measured, indent=1, sort_keys=True) + '\n')
            require(bundles[0] == bundles[1], 'evidence: the two bundles differ (see run-1/evidence.json and run-2/evidence.json)')
            (work / 'evidence.json').write_bytes(bundles[0])
            shutil.copyfile(work / 'run-1' / 'measurements.json', work / 'measurements.json')
            print('  bundle: ' + name + '/evidence.json sha256 ' + digest(bundles[0]) + ' (two runs, byte-identical)')
            print('  measurements (not in the bundle): ' + name + '/measurements.json')
            last = lines[0]
            require(all(oks), 'evidence: the mutations case did not pass: ' + lines[0])
    except Failed as error:
        print('ARCHIA_MCP ' + args.case + ': FAILED; end_to_end=false; wall %.0f s\n%s' % (time.monotonic() - start, error))
        if last:
            print(last)
        return 1
    except RuntimeError as error:
        print('ARCHIA_MCP ' + args.case + ': ' + str(error) + '; end_to_end=false')
        return 2
    print('ARCHIA_MCP ' + args.case + ': PASSED; end_to_end=false; wall %.0f s' % (time.monotonic() - start))
    if last:
        print(last)
    return 0


if __name__ == '__main__':
    sys.exit(main())
