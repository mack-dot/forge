#!/usr/bin/env python3
"""Controls for tests/primitives_v2/test_sdk_primitives.py: changed copies of sdk/py/forge_primitives.py that the SDK
suite must kill (review findings L1 and L2). FINITE TEST. It shows that the named cases CAN fail; it proves nothing.

Usage: python3 tests/primitives_v2/mutants_sdk.py [--only NAME]... [--work DIR] [--rustc PATH]

The production engine is built once from src/primitives_v2 (PROTOCOL.md section 1). Each entry replaces ONE exact text
(it must occur exactly once) in a copy of the SDK. The copy and the suite go into a mirror tree
(<copy>/sdk/py/forge_primitives.py, <copy>/tests/primitives_v2/test_sdk_primitives.py), so the suite imports the
changed SDK. ONE case of the suite runs; a kill needs suite exit 1, a `FAIL <case>` line that is not a suite error, and
the named text in it. First, the unchanged SDK passes every named case (the control). Exit 0: the control passed and
every copy was killed for its named reason. 1: otherwise.
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
SDK = ROOT / 'sdk/py/forge_primitives.py'
SUITE = ROOT / 'tests/primitives_v2/test_sdk_primitives.py'
RUSTC = ['--edition', '2021', '-D', 'unsafe_code', '-C', 'opt-level=3']

# (name, exact text, replacement, case, text the FAIL line must hold, what the copy removes)
MUTANTS = [
    ('SDK1_decimal_fault_not_closing', '        except ProtocolError as e:\n            self._fail(e)\n',
     '        except ProtocolError:\n            raise\n', 'fake_answers', 'bad_seq_commit: the client was not closed after the ProtocolError',
     'review L1: a ProtocolError of a bad decimal field closes the client (_fail)'),
    ('SDK2_taint_any_ok_word', "            if r.verdict != 'ALLOW':", '            if False:', 'fake_answers',
     'taint_block (L2: taint OK verdict=BLOCK (sha256 and bytes right)): expected ProtocolError, got a result',
     'review L2: taint_check returns a document only for OK verdict=ALLOW'),
    ('SDK3_farkas_any_ok_word', "            if r.verdict != 'INFEASIBILITY_PROVED':", '            if False:', 'fake_answers',
     'farkas_feasible (L2: farkas OK verdict=FEASIBLE (digests right)): expected ProtocolError, got a result',
     'review L2: farkas_check accepts only OK verdict=INFEASIBILITY_PROVED'),
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

def tree(folder, text=None):
    (folder / 'sdk/py').mkdir(parents=True)
    (folder / 'tests/primitives_v2').mkdir(parents=True)
    (folder / 'sdk/py/forge_primitives.py').write_text(text if text is not None else SDK.read_text())
    shutil.copyfile(SUITE, folder / 'tests/primitives_v2/test_sdk_primitives.py')
    return folder / 'tests/primitives_v2/test_sdk_primitives.py'


def run_case(suite, engine, case, work):
    p = run_group([sys.executable, str(suite), str(engine), '--case', case, '--work', str(work)], timeout=3600)
    lines = [x for x in p.stdout.splitlines() if x.startswith(('PASS ' + case, 'FAIL ' + case))]
    return p.returncode, (lines[0] if lines else 'no result line: ' + p.stdout[-300:] + p.stderr[-300:])


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--only', action='append')
    ap.add_argument('--work', default=None)
    ap.add_argument('--rustc', default=os.environ.get('FORGE_RUSTC') or shutil.which('rustc'))   # --rustc, FORGE_RUSTC, PATH
    args = ap.parse_args()
    if not args.rustc:
        print('NOT RUN: no rustc: pass --rustc PATH or set FORGE_RUSTC (rustc is not on PATH)')
        return 2
    table = [m for m in MUTANTS if not args.only or m[0] in args.only]
    names = [m[0] for m in MUTANTS]
    if len(set(names)) != len(names):
        print('ERROR: a name is used twice')
        return 1
    source = SDK.read_text()
    for name, old, new, case, reason, removed in table:
        n = source.count(old)
        if n != 1:
            print('ERROR of the list: the text of %s is found %d times in forge_primitives.py, expected 1' % (name, n))
            return 1
    work = Path(tempfile.mkdtemp(prefix='pv2-mutsdk-', dir=args.work))
    engine = work / 'primitives-engine'
    done = subprocess.run([args.rustc] + RUSTC + [str(ROOT / 'src/primitives_v2/main.rs'), '-o', str(engine)], capture_output=True, text=True)
    if done.returncode != 0:
        print('ERROR: the engine does not build\n%s' % done.stderr[-1500:])
        return 1
    failed = 0
    base = tree(work / 'control')
    for case in sorted(set(m[3] for m in table)):
        code, line = run_case(base, engine, case, work)
        ok = code == 0 and line.startswith('PASS')
        print('CONTROL %-26s %-13s %s %s' % ('unchanged', case, 'PASS' if ok else 'FAIL', line[:120]), flush=True)
        failed += 0 if ok else 1
    for name, old, new, case, reason, removed in table:
        t = time.time()
        folder = work / name
        suite = tree(folder, source.replace(old, new))
        code, line = run_case(suite, engine, case, work)
        killed = code == 1 and line.startswith('FAIL ') and 'suite error' not in line and reason in line
        failed += 0 if killed else 1
        print('%-28s %-13s %-10s %5.1fs removes: %s | %s' % (name, case, 'KILLED' if killed else 'NOT KILLED', time.time() - t, removed, line[:200]), flush=True)
        shutil.rmtree(folder, ignore_errors=True)
    shutil.rmtree(work, ignore_errors=True)
    print('%d copies, %d not killed or control failures' % (len(table), failed))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
