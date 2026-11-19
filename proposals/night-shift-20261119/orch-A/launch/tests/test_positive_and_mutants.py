"""Positive controls (honest requests: launcher decision == direct-run decision) and MUTANTS of the launcher
(each control removed in turn; the matching attack must then succeed: the failing side of failing-then-passing).
TEST CODE (W-launch). Finite test. Mutants are monkeypatches in this process only; launcher.py is unchanged."""
import os
import shutil
import subprocess
import sys
import tempfile

sys.path.insert(0, '/Users/USER/forge/results/night-shift-20261119/orch-A/launch/tests')
import common as C  # noqa: E402

L = C.L
ADA = os.path.join(C.BIN, 'forged_adaptive.dylib')
FAKE = os.path.join(C.BIN, 'fake_refund')
PREFIX = os.path.join(C.BIN, 'fake_prefix')

POSITIVE = [
    ('accept base', C.BASE),
    ('reject amount>remaining', C.REJECT),
    ('accept amount 0', dict(C.BASE, amount=0)),
    ('accept duplicate_charge', dict(C.BASE, reason=b'duplicate_charge')),
    ('reject disabled', dict(C.BASE, enabled=False)),
    ('quoted ids a)"b and q\\1', dict(C.BASE, charge=b'a)"b', request=b'q\\1')),
    ('ids with TAB and LF', dict(C.BASE, charge=b'c\td', request=b'r\ns')),
    ('big ids 2000+2000', C.BIG),
    ('reject unknown reason', dict(C.BASE, reason=b'other')),
    ('accept amount = remaining', dict(C.BASE, amount=60)),
]


def main():
    n_ok = 0
    for name, f in POSITIVE:
        h, _ = C.honest(f)
        ld = L.decide(f, C.EXE)
        rc, d, _ = C.run_cli(f)
        cd = C.cli_decision(rc, d)
        eq = C.short(ld) == C.short(h) == C.short(cd) and h[0] != 'REFUSED'
        n_ok += eq
        C.row('test_positive', 'POS', 'POS ' + name, '-', 'direct(env {})', C.short(h), None,
              '%s / cli %s' % (C.short(ld), C.short(cd)), lambda o, h=h: o == '%s / cli %s' % (C.short(h), C.short(h)),
              expect_attack=None)

    real_popen = subprocess.Popen

    # M1 env-scrub removed: the child inherits a caller env with DYLD_INSERT_LIBRARIES (adaptive forger).
    def popen_inherit(*a, **k):
        k['env'] = {'DYLD_INSERT_LIBRARIES': ADA}
        return real_popen(*a, **k)
    L.subprocess.Popen = popen_inherit
    try:
        mut = L.decide(C.REJECT, C.EXE)
    finally:
        L.subprocess.Popen = real_popen
    good = L.decide(C.REJECT, C.EXE)
    C.row('test_mutants', 'MUT', 'MUT-1 no env scrub (AC2-b)', 'N15', 'mutant launcher', C.short(mut),
          mut[0] == 'AUTHORIZED', C.short(good), lambda o: o == 'NOT_AUTHORIZED')

    # M2 digest + image checks removed: a replaced binary at the path is run.
    tmp = tempfile.mkdtemp(prefix='wl-mut-', dir=os.path.join(C.LAUNCH, 'tests'))
    try:
        rep = os.path.join(tmp, 'refund')
        shutil.copyfile(FAKE, rep)
        real_rpb = L.read_pinned_bytes
        L.read_pinned_bytes = lambda path, pin: open(path, 'rb').read()
        try:
            mut = L.decide(C.REJECT, rep, pinned_sha256=C.sha_of(rep), pinned_cdhash=None)
        finally:
            L.read_pinned_bytes = real_rpb
        good = L.decide(C.REJECT, rep)
        C.row('test_mutants', 'MUT', 'MUT-2 no digest/image pin (AC2-h)', 'N16,N17', 'mutant launcher',
              C.short(mut), mut[0] == 'AUTHORIZED', C.short(good) + ' ' + good[1][:2], lambda o: o == 'REFUSED L2')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # M3 decision rule replaced by "exit 0 and stdout starts with the True prefix" (m1_class + exit status).
    real_dfr = L.decide_from_result
    L.decide_from_result = lambda f, r: (('AUTHORIZED', -1, b'?') if r.exit_code == 0 and
                                         r.stdout.startswith(b'(refund-result-v1 True ') else ('REFUSED', 'x'))
    try:
        mut = L.decide(C.BASE, PREFIX, pinned_sha256=C.sha_of(PREFIX), pinned_cdhash=C.cdhash_of(PREFIX))
    finally:
        L.decide_from_result = real_dfr
    good = L.decide(C.BASE, PREFIX, pinned_sha256=C.sha_of(PREFIX), pinned_cdhash=C.cdhash_of(PREFIX))
    C.row('test_mutants', 'MUT', 'MUT-3 exit-status decision (AC1-d)', 'D6/D7', 'mutant launcher', C.short(mut),
          mut[0] == 'AUTHORIZED', C.short(good) + ' ' + good[1][:2], lambda o: o == 'REFUSED D7')

    # M4 image check L7 removed: a swapped image at exec is run and its forged frame is decided on.
    tmp = tempfile.mkdtemp(prefix='wl-mut4-', dir='/private/tmp')
    try:
        cp = os.path.join(tmp, 'refund')
        shutil.copyfile(FAKE, cp)
        os.chmod(cp, 0o500)
        res = L.spawn_and_collect(cp, L.wire(C.REJECT), L.output_bound(C.REJECT), None)
        mut = L.decide_from_result(C.REJECT, res)
        try:
            L.spawn_and_collect(cp, L.wire(C.REJECT), 100, L.PINNED_CDHASH)
            good = 'NOT REFUSED'
        except L.LaunchRefused as e:
            good = 'REFUSED ' + str(e)[:2]
        C.row('test_mutants', 'MUT', 'MUT-4 no L7 image check (AC2-m)', 'N16,N17', 'mutant launcher', C.short(mut),
              mut[0] == 'AUTHORIZED', good, lambda o: o == 'REFUSED L7')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # M5 child setup removed (no signal reset, no close_fds, inherited mask): the probe sees the hostile state.
    import signal
    PROBE = os.path.join(C.BIN, 'probe')
    tmp = tempfile.mkdtemp(prefix='wl-mut5-', dir='/private/tmp')
    old = signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGUSR1})
    try:
        cp = os.path.join(tmp, 'probe')
        shutil.copyfile(PROBE, cp)
        os.chmod(cp, 0o500)

        def popen_careless(*a, **k):
            k.update(preexec_fn=None, restore_signals=False, close_fds=False)
            return real_popen(*a, **k)
        L.subprocess.Popen = popen_careless
        try:
            mut = L.spawn_and_collect(cp, b'x', 4000, C.cdhash_of(PROBE)).stdout.decode().strip()
        finally:
            L.subprocess.Popen = real_popen
        good = L.spawn_and_collect(cp, b'x', 4000, C.cdhash_of(PROBE)).stdout.decode().strip()
        C.row('test_mutants', 'MUT', 'MUT-5 no child setup (AC3-a)', 'N14', 'mutant launcher', mut,
              'blocked=30' in mut and 'nondefault=13' in mut, good,
              lambda o: 'blocked= nondefault= ' in o)
    finally:
        signal.pthread_sigmask(signal.SIG_SETMASK, old)
        shutil.rmtree(tmp, ignore_errors=True)
    print('positive controls equal: %d of %d' % (n_ok, len(POSITIVE)))
    return C.finish('test_positive_and_mutants')


if __name__ == '__main__':
    sys.exit(main())
