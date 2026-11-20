#!/usr/bin/env python3
"""Goal 19: EXIT checks of the native silicon sink (src/silicon_sink/sink.rs).

The pipeline under test has no JavaScript, no Node and no SQLite:
  request line -> CakeML refund binary (the tracked ARM64 Mach-O file, SHA-256 b8ed5ec2...7bb8) over anonymous
  pipes -> exact decision frame -> checks under an exclusive flock -> 64-byte record in ledger.wal ->
  fcntl(F_FULLFSYNC) -> ratchet entry -> fcntl(F_FULLFSYNC) -> one COMMITTED line (the dispatch).

What a pass means: on this machine the finite checks below gave the recorded results. It is a FINITE TEST. It is
NOT a proof of sink.rs, NOT a compiler proof, and it adds nothing to M1. A SIGKILL is not a power loss.
end_to_end stays false. The bundle is a RECORD, not gate evidence. The four classes in_logic_compiler_proof,
source_proof, native_wal_crash_tested and os_kernel_assumption are separate keys of the record.

This script starts tools and compares results. It decides nothing about a refund.

Cases:
  build      source rules (forbid(unsafe_code) on line 1, std only, under 250 lines), the exact compile command of
             the directive, a control that `unsafe` is refused, the kill-point build, the test interposer, the
             identity of the refund binary
  suite      tests/silicon_sink/test_silicon_crash.py, all thirteen cases, full size (10 GiB flood; 120 kills at
             chosen points and 100 blind kills of a running process; races of 100 processes)
  mutations  changed copies of sink.rs: each must compile, and the suite must FAIL on each one in the case that is
             written beside it; the unchanged copy must pass every case of the same reduced suite
  evidence   build, suite and mutations, twice, in fresh folders; the two bundles are byte-identical
Raw outputs go to build/silicon/ (ignored by git). Times and sizes go to measurements.json, never to the bundle.
"""

import argparse
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
from common import canonical, digest, read_json  # noqa: E402  (record helpers only; no decision)

SOURCE = 'src/silicon_sink/sink.rs'
SUITE = 'tests/silicon_sink/test_silicon_crash.py'
INTERPOSER = 'tests/silicon_sink/interpose.c'
ARTIFACT = 'proposals/forge2-m1-conformance/artifacts/refund-arm64-macho'
ARTIFACT_SHA256 = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
RECORDED = 'tests/m1-conformance/recorded-m1-cases.json'
BUILD = 'build/silicon'
BUILD_COMMAND = ['rustc', '-D', 'unsafe_code', '-C', 'opt-level=3', SOURCE, '-o', BUILD + '/native_sink']  # the directive's command
RUSTC_VERSION = 'rustc 1.92.0 (ded5c06cf 2025-12-08)'
CC = '/usr/bin/cc'
CC_VERSION = 'Apple clang version 17.0.0 (clang-1700.0.13.5)'
MAX_LINES = 249  # "<250" in the directive; "up to 250" in the owner's decision: 249 meets both
MUTANT_FLOOD_BYTES = 268435456
SUITE_CASES = ['basic', 'conformance', 'frames', 'ids', 'recovery', 'rollback', 'trace', 'dispatch', 'lock', 'crash', 'race', 'flood', 'latency']
SUBJECT = [SOURCE, SUITE, INTERPOSER, 'scripts/exit_silicon_sink.py', ARTIFACT, RECORDED]
# The one link from this binary to the approved refund spec: a finite test (Wave Gate 1). It is pinned here, not run again.
CONFORMANCE_RECORD = 'proposals/forge2-m1-conformance/records/evidence.json'
# T19 (2026-11-20): the record changed with the hardened minter (bundle f55391da... before; every count equal).
CONFORMANCE_SHA256 = '91b49423d5377612a99751912e2fd916c0e662e6a088ebeda89dbdfbe2d9b1ce'

# Changed copies of sink.rs. (name, a part of the failure message that must appear, text to find exactly once, replacement,
# the suite case that must fail, what is removed)
MUTANTS = [
    # the durable order of a commit
    ('no_wal_sync', 'system-call order of a commit', 'written.and_then(|()| wal.sync_all())', 'written', 'trace', 'the sync of the WAL before the dispatch'),
    ('ignore_wal_sync_error', 'failed sync of the WAL', '    if let Err(e) = written.and_then(|()| wal.sync_all()) {', '    let _ = wal.sync_all();\n    if let Err(e) = written {', 'trace',
     'the result of the WAL sync'),
    ('no_undo_after_failed_sync', 'the record must be cut off again', 'let undone = wal.set_len(l.len as u64).and_then(|()| wal.sync_all());', 'let undone: io::Result<()> = Ok(());', 'trace',
     'the cut of a record whose sync failed'),
    ('no_ratchet_sync', 'system-call order of', '.concat()).and_then(|()| ratchet.sync_all())', '.concat())', 'trace', 'the sync of the ratchet file'),
    ('no_ratchet_entry', 'system-call order of a commit',
     '    if push(&mut ratchet, l.epoch + 1).is_err() { return no(OUTCOME_UNKNOWN, "OUTCOME_UNKNOWN: the record is in the WAL; its ratchet entry failed") }\n', '', 'trace',
     'the ratchet entry of a commit'),
    ('ignore_ratchet_error', 'failed sync of the ratchet',
     '    if push(&mut ratchet, l.epoch + 1).is_err() { return no(OUTCOME_UNKNOWN, "OUTCOME_UNKNOWN: the record is in the WAL; its ratchet entry failed") }\n',
     '    let _ = push(&mut ratchet, l.epoch + 1);\n', 'trace', 'the result of the ratchet write and sync'),
    ('lock_released_before_ratchet', 'system-call order of a commit', '    cut("r");\n', '    cut("r");\n    let wal = drop(wal);\n', 'trace', 'the lock during the ratchet entry'),
    ('early_dispatch', 'traced commit', '    cut("c");\n', '    cut("c");\n    println!("COMMITTED {} {:032x} {accepted}", l.epoch + 1, fnv128(&record));\n', 'trace',
     'the order: a dispatch line before the WAL sync'),
    ('no_recovery_wal_sync', 'system-call order of a recovery', '        wal.sync_all()?;\n        push(&mut ratchet, l.epoch)?;', '        push(&mut ratchet, l.epoch)?;', 'trace',
     'the sync of the WAL in the recovery'),
    ('ignore_recovery_sync_error', 'recovery with a failed sync of the WAL', '        wal.sync_all()?;\n        push(&mut ratchet, l.epoch)?;',
     '        let _ = wal.sync_all();\n        push(&mut ratchet, l.epoch)?;', 'trace', 'the result of the WAL sync in the recovery'),
    ('no_init_wal_sync', 'system-call order of init', 'w.write_all(&genesis).and_then(|()| w.sync_all())', 'w.write_all(&genesis)', 'trace', 'the sync of the genesis record'),
    ('no_init_folder_sync', 'system-call order of init', '.and_then(|()| File::open(dir)?.sync_all()); // and the two names', '; // and the two names', 'trace', 'the sync of the folder in init'),
    ('init_keeps_files_after_failure', 'init with a failed sync of the',
     '    if made.is_err() { let _ = (std::fs::remove_file(&wal_path), std::fs::remove_file(&epoch_path)); } // a refused init leaves no file of its own\n', '', 'trace',
     'the removal of the files of a refused init'),
    ('no_env_clear', 'loader variable in the environment of the sink', 'Command::new(binary).env_clear().env(', 'Command::new(binary).env(', 'trace', 'the empty environment of the binary'),
    # the checks under the lock, and the state
    ('no_state_hash_check', 'wrong state hash', '    if r.tail != l.tail || r.charge != l.charge', '    if r.charge != l.charge', 'basic', 'the compare-and-swap on the state hash'),
    ('no_state_value_check', 'claims one more than remains', '    if r.tail != l.tail || r.charge != l.charge || r.original != l.original || r.remaining != l.remaining {', '    if r.tail != l.tail {', 'basic',
     'the comparison of the claimed charge, original and remaining amounts with the ledger'),
    ('no_request_id_check', 'committed id again', '    if l.ids.contains(r.request) { return no(DUPLICATE_REQUEST_ID, "DUPLICATE_REQUEST_ID: this request id is committed already") }\n', '', 'basic',
     'the uniqueness of the request id'),
    ('remaining_not_reduced', 'state after commit', '            l.remaining -= amount;\n', '', 'basic', 'the subtraction of a committed amount'),
    ('ratchet_one_behind', 'after the commit the ratchet is', 'if push(&mut ratchet, l.epoch + 1).is_err()', 'if push(&mut ratchet, l.epoch).is_err()', 'basic',
     'the epoch of the ratchet entry of a commit'),
    ('kind_swapped', 'is not the request that was sent', "encode(b'1' + kind as u8,", "encode(b'3' - kind as u8,", 'basic', 'the reason code of a record'),
    ('reject_is_accept', 'short request with a reason that is not approved', '        (true, REJECT_FRAME) => no(CAKEML_REJECTED, "CAKEML_REJECTED: the binary rejected the request"),', '        (true, REJECT_FRAME) => Ok(()),', 'basic',
     'the meaning of the rejection frame'),
    ('short_rejection_not_read', 'short request', 'take(expect.len().max(REJECT_FRAME.len()) as u64 + 1)', 'take(expect.len() as u64 + 1)', 'basic', 'the read bound for a rejection of a short request'),
    ('init_no_existence_check', 'init beside a leftover',
     '    if std::fs::metadata(&wal_path).is_ok() || std::fs::metadata(&epoch_path).is_ok() { return no(IO_ERROR, "IO_ERROR: a ledger file exists already") }\n', '', 'basic',
     'the rule that init touches no existing ledger file'),
    ('amount_leading_zero', "'01' must be refused", "s == \"0\" || (!s.starts_with('0') && (1..=19)", 's == "0" || ((1..=19)', 'basic', 'the one spelling of an amount'),
    ('oversized_skip_eats_next_line', 'a line of 255 bytes', "if !whole && long && input.skip_until(b'\\n').is_err()", "if long && input.skip_until(b'\\n').is_err()", 'basic',
     'the rule that only a line with no line end inside the bound is skipped'),
    ('line_bound_4096', 'a line of 256 bytes', 'const MAX_LINE: usize = 255;', 'const MAX_LINE: usize = 4096;', 'basic', 'the bound of 255 bytes for a line'),
    # the decision frame
    ('prefix_frame', 'cut after 23 bytes', '        (true, o) if o == expect.as_bytes() => Ok(()),', '        (true, o) if o.starts_with(b"(refund-result-v1 True ") => Ok(()),', 'frames',
     'the exact comparison of the decision frame'),
    ('rejection_with_bad_exit_is_a_rejection', 'rejection frame, exit status 1', '        (true, REJECT_FRAME) => no(CAKEML_REJECTED,', '        (_, REJECT_FRAME) => no(CAKEML_REJECTED,', 'frames',
     'the clean-exit rule for a rejection'),
    ('ignore_exit_status', 'exact frame, exit status 1', 'child.wait()?.code() == Some(0) && err.is_empty()', 'child.wait().is_ok() && err.is_empty()', 'frames', 'the exit status of the binary'),
    ('ignore_stderr', 'text on stderr', 'child.wait()?.code() == Some(0) && err.is_empty()', 'child.wait()?.code() == Some(0)', 'frames', 'the empty-stderr rule'),
    ('amount_not_bounded', 'accepts more than remains', '    if r.amount > l.remaining { return no(BAD_FRAME, "BAD_FRAME: the accepted amount is above the remaining amount") }\n', '', 'frames',
     "the sink's own bound on the amount"),
    # ids
    ('id_any_byte', "request id b'rq\\x00'", "id.iter().all(|b| b.is_ascii_alphanumeric() || *b == b'_' || *b == b'-')", "id.iter().all(|b| *b != b' ')", 'ids', 'the character set of an id'),
    ('id_any_length', "request id b'xxxxxxxxxxxxxxxxxxxxxxxxx'", '!id.is_empty() && id.len() <= 24 && ', '!id.is_empty() && ', 'ids', 'the length bound of an id'),
    # the reading of the two files
    ('no_crc_check', 'record with a wrong CRC', '&r[..3] == b"FSW" && r[60..] == crc32(&r[..60]).to_le_bytes() && ', '&r[..3] == b"FSW" && ', 'recovery', 'the CRC check of a record'),
    ('no_chain_check', 'record with a wrong chain', '&& r[12..28] == l.tail.to_le_bytes() && canonical_id(id)', '&& canonical_id(id)', 'recovery', 'the hash chain of the records'),
    ('no_epoch_sequence_check', 'record with a wrong epoch', ' && r[4..12] == (i as u64).to_le_bytes()', '', 'recovery', 'the epoch sequence of the records'),
    ('no_padding_check', 'record with a byte after the id', ' && r[28 + id.len()..52].iter().all(|&b| b == 0)', '', 'recovery', 'the zero padding after an id'),
    ('no_stored_id_check', 'record with an id outside the character set', '&& canonical_id(id) && r[28 + id.len()..52]', '&& r[28 + id.len()..52]', 'recovery',
     'the character set of a stored id'),
    ('genesis_amount_unbounded', 'genesis record with an amount above MaxMoney', "r[3] == b'G' && amount <= MAX_MONEY {", "r[3] == b'G' {", 'recovery', 'the money bound of the genesis record'),
    ('no_torn_tail_cut', 'torn tail of 1 bytes', '        wal.set_len(l.len as u64)?; // a torn record\n', '', 'recovery', 'the cut of a torn record'),
    ('ratchet_last_not_highest', 'ratchet whose last entry is lower', '.expect("8 bytes"))).max() else {', '.expect("8 bytes"))).last() else {', 'recovery',
     'the highest entry of the ratchet as its value'),
    ('no_ratchet_check', 'with the present ratchet', '    if l.epoch < floor { return no(EPOCH_REGRESSION, "EPOCH_REGRESSION: the ledger is older than its ratchet (a restored file?)") }\n', '', 'rollback',
     'the comparison of the ledger with its ratchet'),
    # the answer
    ('ignore_failed_answer', 'no reader for the answers', '{ code } else { DISPATCH_FAILED }', '{ code } else { code }', 'dispatch', 'the code for an answer that could not be written'),
    ('stream_continues_after_fault', 'must read no further line', '        if code >= CORRUPT_WAL { return code } // a fault of the ledger, of the system or of the answer: no further line is read\n', '',
     'dispatch', 'the end of the stream at a fault'),
    # the lock, the line bound, the recovery of the ratchet
    ('no_lock', 'while another process held the ledger lock', '    wal.lock()?; // exclusive flock; the kernel releases it when this process ends or is killed\n', '', 'lock', 'the file lock'),
    ('shared_lock', 'while another process held the ledger lock', '    wal.lock()?; // exclusive flock', '    wal.lock_shared()?; // exclusive flock', 'lock', 'the exclusiveness of the file lock'),
    ('lock_after_the_reads', 'exactly one of the two waiting processes may commit',
     '    wal.lock()?; // exclusive flock; the kernel releases it when this process ends or is killed\n    let (mut bytes, mut entries) = (Vec::new(), Vec::new());\n'
     '    wal.read_to_end(&mut bytes)?;\n    let l = scan(&bytes)?;\n    let mut ratchet = OpenOptions::new().read(true).append(true).open(format!("{dir}/ledger.epoch"))?;\n'
     '    ratchet.read_to_end(&mut entries)?;\n',
     '    let (mut bytes, mut entries) = (Vec::new(), Vec::new());\n'
     '    wal.read_to_end(&mut bytes)?;\n    let l = scan(&bytes)?;\n    let mut ratchet = OpenOptions::new().read(true).append(true).open(format!("{dir}/ledger.epoch"))?;\n'
     '    ratchet.read_to_end(&mut entries)?;\n    wal.lock()?;\n', 'lock', 'the rule that the files are read under the lock'),
    ('unbounded_line', 'flood: first answer', 'input.by_ref().take(MAX_LINE as u64 + 1).read_until', 'input.by_ref().take(u64::MAX).read_until', 'flood', 'the bound on a request line'),
    ('written_then_killed_is_lost', 'ratchet', '    if entries.len() % 12 != 0 || l.len < bytes.len() || floor < l.epoch {', '    if entries.len() % 12 != 0 || l.len < bytes.len() {', 'crash',
     'the repair of the ratchet after a kill between the two syncs'),
]

CLAIMS = {
    'in_logic_compiler_proof': {
        'status': 'NOT_ESTABLISHED for the running executable; nothing is added here',
        'statement': 'The refund binary b8ed5ec2...7bb8 was produced by the CakeML compiler inside HOL4 on 2026-11-04. The HOL theorems about it are '
                     'machine-model theorems with open premises (M1 is open; ROADMAP: M1 and integration EXIT NOT_ESTABLISHED). This work runs no HOL, '
                     'proves no premise and uses no theorem. The sink treats the binary as a trusted program and believes exactly one output per request.',
        'evidence_in_this_record': 'none',
    },
    'source_proof': {
        'status': 'none',
        'statement': 'src/silicon_sink/sink.rs is NOT proved. The Dafny proofs of Slice 1 (RefundFinality.Check), of the finality protocol model and of the sink '
                     'core model are not connected to this program. The Ed25519 token of Slice 1 is not used: the sink and the binary are one trust domain.',
        'evidence_in_this_record': 'none',
    },
    'native_wal_crash_tested': {
        'status': 'finite tests passed on one machine',
        'statement': 'For the recorded requests, kills, damaged files, stand-in binaries and races: a record appeared only after the binary printed the '
                     'one accept frame of that request, at most once per request id, only on the present state hash and state values, and never below the '
                     'ratchet; every complete COMMITTED line had its record in the WAL after the recovery. The order lock, record, F_FULLFSYNC, ratchet entry, '
                     'F_FULLFSYNC, lock released, answer was OBSERVED with an interposer for one traced commit, one traced recovery and one traced init, not '
                     'for every commit. An answer with code 19 (OUTCOME_UNKNOWN) or 20 (DISPATCH_FAILED) can leave a committed record that was not '
                     'dispatched. See the keys suite and mutations.',
        'what_it_is_not': 'A SIGKILL keeps the page cache: no test here cuts power or stops the kernel. The system-call order is observed with a dyld interposer '
                          'inside the sink process; that the drive stores the data is not observed.',
    },
    'os_kernel_assumption': [
        'macOS Darwin kernel: flock is exclusive and is released when a process ends; a write of 64 bytes with O_APPEND goes to the end of the file; '
        'pipes carry the bytes that were written; fcntl(F_FULLFSYNC) returns 0 only after the drive was asked to store the data.',
        'APFS and the physical SSD firmware keep data that F_FULLFSYNC reported as stored, also at power loss. NOT tested.',
        'Mach-O loader and dyld start the refund binary and the sink as their files say; the CakeML basis C code (basis_ffi) and libSystem inside the refund '
        'binary do what the HOL model of the foreign functions says. NOT proved, NOT tested here beyond the recorded requests.',
        'rustc 1.92.0, LLVM and the Rust standard library compile and run sink.rs as written. They are unverified and in the trusted base.',
        'The two ledger files, the refund binary file and the environment of the sink are out of reach of an attacker. FNV-1a-128 and CRC-32 authenticate '
        'nothing. The sink does not hash the binary: this script does, before and after each run.',
        'A restore of BOTH ledger files (or of the volume) to an older state is not detected on one machine. Recorded as observed in case rollback.',
        'The consumer of the COMMITTED lines treats the request id as an idempotency key. Delivery is at most once per commit; replay prints effects again.',
    ],
}


class Failed(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Failed(message)


def run(argv, cwd=ROOT, **options):
    return subprocess.run([str(a) for a in argv], cwd=cwd, capture_output=True, text=True, **options)


def toolchain():
    rustc = run(['rustc', '-V'])
    cc = run([CC, '--version'])
    pinned_python = read_json(ROOT / 'toolchain/pins.json')['python']['version']
    seen = {'rustc': rustc.stdout.strip(), 'cc': cc.stdout.splitlines()[0].strip() if cc.stdout else '', 'python': platform.python_version(),
            'machine': platform.system() + ' ' + platform.machine()}
    want = {'rustc': RUSTC_VERSION, 'cc': CC_VERSION, 'python': pinned_python, 'machine': 'Darwin arm64'}
    if seen != want:
        raise RuntimeError('TOOLCHAIN_ERROR: observed %r, pinned %r' % (seen, want))
    return seen


def snapshot():
    return {name: digest((ROOT / name).read_bytes()) for name in SUBJECT}


def compile_sink(source, output, kill_points=False, cwd=ROOT):
    command = BUILD_COMMAND[:5] + (['--cfg', 'kill_points'] if kill_points else []) + [source, '-o', output]
    return command, run(command, cwd=cwd)


def build(work):
    """Source rules, the exact compile command, the control for `unsafe`, the other builds, the binary."""
    work.mkdir(parents=True)
    out = ROOT / BUILD
    text = (ROOT / SOURCE).read_text()
    lines = text.splitlines()
    uses = [line for line in lines if line.startswith('use ') or ' extern crate ' in ' ' + line]
    require(lines[0] == '#![forbid(unsafe_code)]', 'SOURCE: line 1 is not #![forbid(unsafe_code)]')
    require(uses and all(line.startswith('use std::') for line in uses), 'SOURCE: an import is not from std: %r' % uses)
    require(len(lines) <= MAX_LINES, 'SOURCE: %d lines, limit %d' % (len(lines), MAX_LINES))
    require(not list((ROOT / 'src/silicon_sink').glob('Cargo.*')) and not (ROOT / 'Cargo.toml').exists(), 'SOURCE: a Cargo file exists')
    built = run(BUILD_COMMAND)
    require(built.returncode == 0 and built.stdout == '' and built.stderr == '', 'BUILD: %r gave exit %d\n%s' % (BUILD_COMMAND, built.returncode, built.stderr))
    control = work / 'unsafe_control.rs'
    control.write_text(text + '\nfn control() -> u8 { unsafe { *(1 as *const u8) } }\n')
    _, refused = compile_sink(str(control), str(work / 'unsafe_control'))
    require(refused.returncode == 1 and 'unsafe' in refused.stderr and not (work / 'unsafe_control').exists(), 'CONTROL: a copy with an unsafe block compiled')
    kill_command, kill = compile_sink(SOURCE, BUILD + '/native_sink_kill', kill_points=True)
    require(kill.returncode == 0 and kill.stderr == '', 'BUILD: the kill-point build gave exit %d\n%s' % (kill.returncode, kill.stderr))
    interposer = run([CC, '-dynamiclib', '-O1', '-Wall', '-Wextra', '-Werror', '-o', BUILD + '/interpose.dylib', INTERPOSER])
    require(interposer.returncode == 0, 'BUILD: the test interposer gave exit %d\n%s' % (interposer.returncode, interposer.stderr))
    require(digest((ROOT / ARTIFACT).read_bytes()) == ARTIFACT_SHA256, 'BINARY: the tracked refund binary is not b8ed5ec2...')
    private = out / 'bin'
    shutil.rmtree(private, ignore_errors=True)
    private.mkdir(mode=0o700)
    shutil.copyfile(ROOT / ARTIFACT, private / 'refund')
    (private / 'refund').chmod(0o700)
    archs = run(['/usr/bin/lipo', '-archs', BUILD + '/bin/refund']).stdout.strip()
    require(archs == 'arm64' and platform.machine() == 'arm64', 'BINARY: architectures %r on machine %s' % (archs, platform.machine()))
    probe = subprocess.run([str(private / 'refund')], input=b'(charge-1 request-1 100 60 True True True 40 returned_item)', capture_output=True,
                           env={'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}, timeout=60)
    require(probe.returncode == 0 and probe.stdout == b'(refund-result-v1 True 40 returned_item charge-1 request-1 1)' and probe.stderr == b'',
            'BINARY: the refund binary did not run natively as recorded: exit %d %r' % (probe.returncode, probe.stdout))
    return {'compile_command': BUILD_COMMAND, 'compile_exit': 0, 'compiler_warnings': 0, 'kill_point_build_command': kill_command, 'source_lines': len(lines),
            'source_line_limit': MAX_LINES, 'first_line': lines[0], 'imports': sorted(uses), 'external_crates': 0, 'cargo_used': False,
            'unsafe_control': {'what': 'the same source with one unsafe block, the same command', 'compile_exit': refused.returncode},
            'refund_binary': {'path': ARTIFACT, 'sha256': ARTIFACT_SHA256, 'architectures': archs, 'ran_natively_with_recorded_answer': True},
            'test_interposer_command': [CC, '-dynamiclib', '-O1', '-Wall', '-Wextra', '-Werror', '-o', BUILD + '/interpose.dylib', INTERPOSER]}


def suite(work, sink, kill_sink, cases, quick, flood_bytes=None):
    """Starts the suite as its own process. Returns (exit code, results, measurements, printed text)."""
    work.mkdir(parents=True, exist_ok=True)
    command = [sys.executable, '-B', SUITE, '--sink', sink, '--kill-sink', kill_sink, '--binary', BUILD + '/bin/refund', '--interposer', BUILD + '/interpose.dylib',
               '--work', work / 'ledgers', '--cases', ','.join(cases), '--record', work / 'record.json', '--measurements', work / 'measurements.json']
    command += (['--quick'] if quick else []) + (['--flood-bytes', str(flood_bytes)] if flood_bytes else [])
    done = run(command)
    (work / 'suite.log').write_text(done.stdout + done.stderr)
    record = json.loads((work / 'record.json').read_text()) if (work / 'record.json').exists() else None
    measurements = json.loads((work / 'measurements.json').read_text()) if (work / 'measurements.json').exists() else {}
    return done.returncode, record, measurements, done.stdout + done.stderr


def full_suite(work):
    code, record, measurements, text = suite(work, BUILD + '/native_sink', BUILD + '/native_sink_kill', SUITE_CASES, quick=False)
    require(code == 0 and record is not None and record['failed'] == [] and sorted(record['cases']) == sorted(SUITE_CASES),
            'SUITE: exit %d\n%s' % (code, text[-3000:]))
    return record, measurements


def mutations(work):
    """Each changed copy must compile and must fail in its named case. The unchanged copy must pass every case."""
    work.mkdir(parents=True)
    text = (ROOT / SOURCE).read_text()
    require(len({name for name, *_ in MUTANTS}) == len(MUTANTS), 'MUTANTS: a name is used twice')

    def built(name, source_text):
        folder = work / name
        folder.mkdir()
        (folder / 'sink.rs').write_text(source_text)
        for kill_points, output in ((False, 'native_sink'), (True, 'native_sink_kill')):
            _, done = compile_sink('sink.rs', output, kill_points=kill_points, cwd=folder)
            require(done.returncode == 0, 'MUTANTS: copy %s does not compile\n%s' % (name, done.stderr[-2000:]))
        return folder

    folder = built('unchanged', text)
    code, record, _, printed = suite(folder / 'suite', folder / 'native_sink', folder / 'native_sink_kill', SUITE_CASES, quick=True, flood_bytes=MUTANT_FLOOD_BYTES)
    require(code == 0 and record['failed'] == [], 'MUTANTS: the unchanged copy does not pass the reduced suite\n' + printed[-3000:])
    results, details = [], {}
    for name, message, old, new, case, removed in MUTANTS:
        require(text.count(old) == 1, 'MUTANTS: the text of %s is found %d times in the source, expected 1' % (name, text.count(old)))
        folder = built(name, text.replace(old, new))
        code, record, _, printed = suite(folder / 'suite', folder / 'native_sink', folder / 'native_sink_kill', [case], quick=True, flood_bytes=MUTANT_FLOOD_BYTES)
        reason = (record or {}).get('cases', {}).get(case, {}).get('failed', '')
        require(code == 1 and message in reason and not reason.startswith('error in the suite'),
                'MUTANTS: the suite did NOT fail on the copy %s in case %s with %r (exit %d)\n%s' % (name, case, message, code, printed[-2000:]))
        results.append({'name': name, 'removed': removed, 'suite_exit': code, 'failed_case': case, 'failure_names': message})
        details[name] = reason
        print('  changed copy %-28s suite exit %d in case %-9s %s' % (name, code, case, reason[:110].replace('\n', ' ')), flush=True)
    return {'changed_copies': len(results), 'suite_failed_on': len(results), 'unchanged_copy_reduced_suite_exit': 0, 'copies': results}, details


def bundle_of(work):
    before = snapshot()
    tools = toolchain()
    require(digest((ROOT / CONFORMANCE_RECORD).read_bytes()) == CONFORMANCE_SHA256, 'LINKED_RECORD: the M1 conformance record is not the pinned one')
    built = build(work / 'build')
    print('  build: exit 0, %d lines, 0 crates' % built['source_lines'], flush=True)
    record, measurements = full_suite(work / 'suite')
    print('  suite: %d of %d cases passed' % (len(SUITE_CASES), len(SUITE_CASES)), flush=True)
    changed, details = mutations(work / 'mutations')
    require(snapshot() == before, 'INPUT_CHANGED: a source or the refund binary changed during the checks')
    require(digest((ROOT / BUILD / 'bin/refund').read_bytes()) == ARTIFACT_SHA256, 'BINARY: the private copy changed during the checks')
    bundle = {
        'record': 'forge-native-silicon-sink', 'format_version': 1,
        'gate_accepted': False, 'policy': None, 'end_to_end': False, 'kind': 'FINITE TEST',
        'producer': 'scripts/exit_silicon_sink.py (a scenario script; not the gate)',
        'note': 'A record of real tool runs on one machine. It is not Forge gate evidence. A test count is not a proof. No time and no size is in this record.',
        'source_manifest': [{'path': name, 'sha256': before[name]} for name in sorted(SUBJECT)],
        'linked_records': [{'path': CONFORMANCE_RECORD, 'sha256': CONFORMANCE_SHA256,
                            'what': 'Wave Gate 1: this binary and the Slice 1 Dafny refund checker gave equal answers on a finite corpus. It is the only '
                                    'link from the binary to the approved refund spec. A finite test; not run again here; not enforced by the sink.'}],
        'toolchain': tools, 'build': built,
        'suite': {'argv': ['python3', '-B', SUITE, '--sink', BUILD + '/native_sink', '--kill-sink', BUILD + '/native_sink_kill', '--binary', BUILD + '/bin/refund',
                           '--interposer', BUILD + '/interpose.dylib', '--work', '<new folder>', '--cases', ','.join(SUITE_CASES), '--record', '<file>',
                           '--measurements', '<file>'],
                  'exit_code': 0, 'seed': record['seed'], 'cases': record['cases']},
        'mutations': changed,
        'in_logic_compiler_proof': CLAIMS['in_logic_compiler_proof'],
        'source_proof': CLAIMS['source_proof'],
        'native_wal_crash_tested': CLAIMS['native_wal_crash_tested'],
        'os_kernel_assumption': CLAIMS['os_kernel_assumption'],
        'reproduce_cmd': 'python3 scripts/exit_silicon_sink.py --case evidence',
    }
    return bundle, {'suite': measurements, 'mutation_failures': details}


def attempt_folder(case):
    base = ROOT / BUILD / case
    base.mkdir(parents=True, exist_ok=True)
    number = 1 + max([int(p.name.split('-')[1]) for p in base.glob('attempt-*')] or [0])
    return base / ('attempt-%04d' % number)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--case', required=True, choices=('build', 'suite', 'mutations', 'evidence'))
    args = parser.parse_args()
    work = attempt_folder(args.case)
    name = work.relative_to(ROOT).as_posix()
    print('SILICON_SINK ' + args.case + ': ' + name, flush=True)
    try:
        toolchain()
        if args.case == 'build':
            result = build(work)
            print('  %s -> exit 0; %d lines; imports from std only; unsafe control exit %d' % (' '.join(BUILD_COMMAND), result['source_lines'], result['unsafe_control']['compile_exit']))
        elif args.case == 'suite':
            build(work / 'build')
            record, measurements = full_suite(work)
            for case in SUITE_CASES:
                print('  %-12s %s' % (case, json.dumps(record['cases'][case], sort_keys=True)))
            print('  measured: ' + json.dumps(measurements, sort_keys=True))
        elif args.case == 'mutations':
            build(work / 'build')
            result, _ = mutations(work / 'copies')
            print('  the suite failed on %d of %d changed copies; the unchanged copy passed the reduced suite' % (result['suite_failed_on'], result['changed_copies']))
        else:
            work.mkdir(parents=True)
            bundles = []
            for number in (1, 2):
                print(' run ' + str(number), flush=True)
                bundle, measured = bundle_of(work / ('run-%d' % number))
                bundles.append(canonical(bundle))
                (work / ('run-%d' % number) / 'evidence.json').write_bytes(bundles[-1])
                (work / ('run-%d' % number) / 'measurements.json').write_text(json.dumps(measured, indent=2, sort_keys=True) + '\n')
            require(bundles[0] == bundles[1], 'evidence: the two bundles differ')
            (work / 'evidence.json').write_bytes(bundles[0])
            shutil.copyfile(work / 'run-1' / 'measurements.json', work / 'measurements.json')
            print('  bundle: ' + name + '/evidence.json sha256 ' + digest(bundles[0]) + ' (two runs, byte-identical)')
            print('  measurements (not in the bundle): ' + name + '/measurements.json')
    except Failed as error:
        print('SILICON_SINK ' + args.case + ': FAILED; end_to_end=false\n' + str(error))
        return 1
    except RuntimeError as error:
        print('SILICON_SINK ' + args.case + ': ' + str(error) + '; end_to_end=false')
        return 2
    print('SILICON_SINK ' + args.case + ': PASSED; end_to_end=false')
    return 0


if __name__ == '__main__':
    sys.exit(main())
