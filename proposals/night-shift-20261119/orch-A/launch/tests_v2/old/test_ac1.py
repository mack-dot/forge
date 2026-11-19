"""AC-1: exit status 0 with truncated or empty stdout (CE-1, CE-2). TEST CODE (W-launch). Finite test.
Exit 0 iff every row is as expected (attack succeeds on the naive consumer where expected; launcher refuses
or gives the honest decision)."""
import os
import subprocess
import sys

sys.path.insert(0, '/Users/mackianni/forge/results/night-shift-20261119/orch-A/launch/tests_v2/old')
from common import *  # noqa: E402,F401,F403
import common as C  # noqa: E402

L = C.L


def main():
    h_base, _ = C.honest(C.BASE)
    h_big, res_big = C.honest(C.BIG)
    assert h_base[0] == 'AUTHORIZED' and h_big[0] == 'AUTHORIZED', (h_base, h_big)
    same = lambda d: (lambda o: o == C.short(d))   # noqa: E731
    refused = lambda o: o == 'REFUSED'               # noqa: E731

    # AC1-a CE-1: stdout = O_NONBLOCK pipe with 1000 bytes free; big request (output 4044 bytes).
    r, w, filler = C.nonblock_prefilled_pipe(1000)
    res = C.raw_run([C.EXE], L.wire(C.BIG), env={}, stdout=w)
    os.close(w)
    got = C.drain(r)[filler:]
    os.close(r)
    res = res._replace(stdout=got)
    trunc = res.exit_code == 0 and res.stderr == b'' and len(got) < len(res_big.stdout)
    # same caller-side condition applied to the launcher CLI's own stdout: its child gets fresh pipes
    r2, w2, filler2 = C.nonblock_prefilled_pipe(1000)
    p, _, _ = C.run_cli(C.BIG, stdout_fd=w2)
    os.close(w2)
    got2 = C.drain(r2)[filler2:]
    os.close(r2)
    p.wait(timeout=C.TIMEOUT)
    ld = C.cli_decision(p.returncode, C.parse_decision_line(got2))
    C.row('test_ac1', 'AC-1', 'AC1-a nonblock-full-stdout (CE-1)', 'N11,N21,N22', 'naive_exit',
          '%s rc=%s stdout=%d of %d bytes' % (C.naive_exit(res), res.exit_code, len(got), len(res_big.stdout)),
          trunc and C.naive_exit(res) == 'COMPLETE', C.short(ld), same(h_big),
          'launcher CLI stdout was the same kind of pipe; the child still got a fresh blocking pipe')

    # AC1-b CE-2: stdin closed in the caller.
    res = C.raw_run([C.EXE], None, env={}, stdin=subprocess.DEVNULL, preexec=lambda: os.close(0))
    rc, d, _ = C.run_cli(C.BASE, preexec=lambda: os.close(0))
    C.row('test_ac1', 'AC-1', 'AC1-b stdin-closed (CE-2)', 'N09,N20', 'naive_exit',
          '%s rc=%s stdout=%d' % (C.naive_exit(res), res.exit_code, len(res.stdout)),
          C.naive_exit(res) == 'COMPLETE' and res.stdout == b'', C.short(C.cli_decision(rc, d)), same(h_base))

    # AC1-c CE-2: stdout closed in the caller (naive: no output at all, exit 0). Launcher CLI with fd 1 closed
    # cannot report: it must exit 4 and write nothing (the consumer sees no decision = REFUSED).
    def close1():
        os.close(1)
    p = subprocess.Popen([C.EXE], stdin=subprocess.PIPE, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, env={},
                         preexec_fn=close1)
    _, err = p.communicate(L.wire(C.BASE), timeout=C.TIMEOUT)
    rc, d, raw = C.run_cli(C.BASE, preexec=close1)
    C.row('test_ac1', 'AC-1', 'AC1-c stdout-closed (CE-2)', 'N11,N22', 'naive_exit',
          '%s rc=%s' % ('COMPLETE' if p.returncode == 0 else 'FAILED', p.returncode), p.returncode == 0,
          'REFUSED rc=%d' % rc if d is None else C.short(C.cli_decision(rc, d)),
          lambda o: o == 'REFUSED rc=4', 'launcher exits 4 when it cannot report')

    # AC1-d/e: a REAL process that exits 0 with a strict prefix / with nothing (test executables pinned).
    for name, sub in (('fake_prefix', 'AC1-d real-process-prefix-exit0'), ('fake_empty', 'AC1-e real-process-empty-exit0')):
        path = os.path.join(C.BIN, name)
        res = C.raw_run([path], L.wire(C.BASE), env={})
        ld = L.decide(C.BASE, path, pinned_sha256=C.sha_of(path), pinned_cdhash=C.cdhash_of(path))
        C.row('test_ac1', 'AC-1', sub, 'decision rule D6/D7 (X8 C5 decision)', 'naive_exit',
              '%s rc=%s stdout=%r' % (C.naive_exit(res), res.exit_code, res.stdout[:40]),
              C.naive_exit(res) == 'COMPLETE', C.short(ld) + ' ' + ld[1][:2], lambda o: o.startswith('REFUSED D'),
              'test executable pinned only for this row')

    # AC1-f: planted results, no process: every strict prefix of the honest output with exit 0, empty stderr;
    # and the full frame with one trailing byte. naive_parse never accepts them either (strict); naive_exit does.
    _, hres = C.honest(C.BASE)
    full = hres.stdout
    planted = [full[:k] for k in range(len(full))] + [full + b'\n', full + b' ', full + full]
    n_naive_complete = sum(1 for _ in planted)            # naive_exit: exit 0 -> COMPLETE for every one
    n_launcher_auth = sum(1 for s in planted
                          if L.decide_from_result(C.BASE, L.ProcessResult(0, None, False, s, b'', False))[0] != 'REFUSED')
    C.row('test_ac1', 'AC-1', 'AC1-f planted prefixes+suffixes (%d)' % len(planted), 'decision rule D5-D7',
          'naive_exit', 'COMPLETE for %d of %d' % (n_naive_complete, len(planted)), n_naive_complete > 0,
          'non-REFUSED %d of %d' % (n_launcher_auth, len(planted)), lambda o: o.startswith('non-REFUSED 0 of'))
    return C.finish('test_ac1')


if __name__ == '__main__':
    sys.exit(main())
