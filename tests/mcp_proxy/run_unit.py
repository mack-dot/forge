#!/usr/bin/env python3
"""Build and run the Rust unit tests of the MCP airlock (Python 3 stdlib only).

FINITE TEST of a NATIVE CHECK. Nothing here is a proof.

    python3 tests/mcp_proxy/run_unit.py [--source DIR] [--out DIR] [--parallel]

It builds `<source>/main.rs` with `rustc --edition 2021 -D unsafe_code --test` into a temporary folder (or
`--out DIR`), runs the test binary, prints the counts, and exits:
  0  every test passed, no test failed, and the counts are at least the recorded minimums below;
  1  a test failed, or a count is under its minimum (for example a silently emptied test file);
  2  a setup error (bad option, rustc missing, build failed, output not readable).

--source DIR   test another copy of `src/mcp_proxy` (worker EXIT uses it for changed copies). Default:
               `src/mcp_proxy` of this repository. `main.rs` includes `../airlock/json.rs` and
               `../airlock/pin.rs` by RELATIVE path, so DIR must sit next to an `airlock` folder:
                   <parent>/mcp_proxy-copy/   main.rs proxy.rs policy.rs ledger.rs evidence.rs hash.rs jsonw.rs
                                              policy_tests.rs evidence_tests.rs
                   <parent>/airlock/          json.rs pin.rs
               (the folder name of DIR is free; only its sibling `airlock` matters). The script refuses (exit 2)
               when `DIR/../airlock/json.rs` or `DIR/../airlock/pin.rs` is missing.
--out DIR      put the test binary here (kept). Default: a new temporary folder, removed at the end.
--parallel     use the default parallel test runner (see THREADS below).

THREADS. By default the test binary runs with `--test-threads=1`. Reason (measured on macOS, 2026-11-19): under
the parallel runner, the ledger tests that open, drop and open the same `ledger.wal` again sometimes see
"locked by another process" while the evidence tests start `ssh-keygen` child processes at the same time. With
`--skip evidence_tests` the parallel run passed 4 of 4 times; with all tests it failed 5 of 5 times (1 to 3
ledger tests). Our reading (NOT proved): a child process created at that moment briefly shares the open
`ledger.wal` file description and with it the `flock`, until its `exec` closes it. This is a test-interaction
effect: a running proxy holds its store lock for its whole life and does not reopen it.

Temporary files: the tests write under `$MCP_TEST_TMP`. This script sets it to a new private folder and removes
that folder at the end.
"""

import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DEFAULT_SOURCE = ROOT / 'src' / 'mcp_proxy'

# Recorded minimums (2026-11-19). Raise them when tests are added; never lower them to make a run pass.
MIN_PASSED = 146            # 102 tests in total, 1 ignored (ledger::tests::bench_commit_median_of_200)
MIN_PER_MODULE = {
    'policy_tests::': 78,   # round 1 POLICY test root, every case
    'evidence_tests::': 41, # round 1 EVIDENCE test root (30) + the driver mix case (1)
    'ledger::tests::': 16,
    'proxy::tests::': 4,
    'jsonw::tests::': 3,
    'hash::tests::': 2,
    'tests::': 2,           # main.rs (matched as a name that starts with `tests::`)
}

USAGE = __doc__


def rustc():
    r = os.environ.get('RUSTC') or shutil.which('rustc')
    if r:
        return r
    fallback = os.path.expanduser('~/.cargo/bin/rustc')
    return fallback if os.path.isfile(fallback) else None


def parse_args(argv):
    opts = {'source': str(DEFAULT_SOURCE), 'out': None, 'parallel': False}
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ('--source', '--out') and i + 1 < len(argv):
            opts[a[2:]] = argv[i + 1]
            i += 2
        elif a == '--parallel':
            opts['parallel'] = True
            i += 1
        elif a in ('-h', '--help'):
            print(USAGE)
            sys.exit(0)
        else:
            sys.stderr.write('run_unit.py: unknown or incomplete option %r\n' % a)
            sys.exit(2)
    return opts


def main():
    o = parse_args(sys.argv[1:])
    src = Path(o['source']).resolve()
    main_rs = src / 'main.rs'
    for need in (main_rs, src.parent / 'airlock' / 'json.rs', src.parent / 'airlock' / 'pin.rs'):
        if not need.is_file():
            sys.stderr.write('run_unit.py: missing %s (see --source in --help for the folder layout)\n' % need)
            return 2
    rc = rustc()
    if not rc:
        sys.stderr.write('run_unit.py: rustc not found (set $RUSTC)\n')
        return 2
    work = Path(tempfile.mkdtemp(prefix='mcp-unit-', dir=os.environ.get('MCP_TEST_TMP'))).resolve()
    try:
        out_dir = Path(o['out']).resolve() if o['out'] else work
        out_dir.mkdir(parents=True, exist_ok=True)
        binary = out_dir / 'mcp-proxy-unit'
        argv = [rc, '--edition', '2021', '-D', 'unsafe_code', '--test', str(main_rs), '-o', str(binary)]
        print('$ ' + ' '.join(argv), flush=True)
        b = subprocess.run(argv, capture_output=True)
        if b.returncode != 0:
            sys.stderr.write(b.stderr.decode('utf-8', 'replace')[-4000:])
            print('BUILD FAILED rustc exit %d' % b.returncode)
            return 2
        tmp = work / 'tmp'
        tmp.mkdir(mode=0o700)
        env = dict(os.environ, MCP_TEST_TMP=str(tmp), LEDGER_TEST_DIR=str(tmp))
        targs = [str(binary)] + ([] if o['parallel'] else ['--test-threads=1'])
        print('$ ' + ' '.join(targs) + '   (MCP_TEST_TMP=%s)' % tmp, flush=True)
        t = subprocess.run(targs, capture_output=True, env=env, cwd=str(work))
        text = t.stdout.decode('utf-8', 'replace')
        err = t.stderr.decode('utf-8', 'replace')
        ok_names = re.findall(r'^test (\S+) \.\.\. ok$', text, re.M)
        failed_names = re.findall(r'^test (\S+) \.\.\. FAILED$', text, re.M)
        summary = re.findall(r'^test result: (\w+)\. (\d+) passed; (\d+) failed; (\d+) ignored', text, re.M)
        if not summary:
            sys.stdout.write(text[-4000:])
            sys.stderr.write(err[-4000:])
            print('NO TEST SUMMARY (test binary exit %d)' % t.returncode)
            return 2
        _, passed, failed, ignored = summary[-1]
        passed, failed, ignored = int(passed), int(failed), int(ignored)
        for n in failed_names:
            print('FAILED %s' % n)
        if failed:
            # Print the failure section of the harness output.
            k = text.find('\nfailures:\n')
            sys.stdout.write(text[k:][-6000:] if k >= 0 else text[-6000:])
        print('unit tests: %d passed, %d failed, %d ignored (test binary exit %d; threads: %s)'
              % (passed, failed, ignored, t.returncode, 'default parallel' if o['parallel'] else '1'))
        bad = []
        if failed or t.returncode != 0:
            bad.append('%d failed, exit %d' % (failed, t.returncode))
        if passed != len(ok_names):
            bad.append('summary says %d passed, %d ok lines seen' % (passed, len(ok_names)))
        if passed < MIN_PASSED:
            bad.append('%d passed < recorded minimum %d' % (passed, MIN_PASSED))
        for prefix, need in MIN_PER_MODULE.items():
            got = sum(1 for n in ok_names if n.startswith(prefix))
            print('  %-18s %3d passed (minimum %d)' % (prefix, got, need))
            if got < need:
                bad.append('%s: %d passed < minimum %d' % (prefix, got, need))
        if bad:
            print('RESULT FAIL: ' + '; '.join(bad))
            return 1
        print('RESULT PASS')
        return 0
    finally:
        shutil.rmtree(work, ignore_errors=True)


if __name__ == '__main__':
    sys.exit(main())
