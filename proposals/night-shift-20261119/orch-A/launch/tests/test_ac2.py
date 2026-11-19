"""AC-2: injected or substituted code at load (CE-3 and relatives). TEST CODE (W-launch). Finite test.
Every forged library and fake executable is TEST-ONLY code in launch/bin/. The pinned executable is only read
and executed; never modified. The hardened-runtime variant is a COPY (launch/hr/refund-hr-copy)."""
import os
import shutil
import signal
import subprocess
import sys
import tempfile

sys.path.insert(0, '/Users/mackianni/forge/results/night-shift-20261119/orch-A/launch/tests')
import common as C  # noqa: E402

L = C.L
FIX = os.path.join(C.BIN, 'forged_fixed.dylib')
ADA = os.path.join(C.BIN, 'forged_adaptive.dylib')
FAKE = os.path.join(C.BIN, 'fake_refund')
HR = os.path.join(C.LAUNCH, 'hr', 'refund-hr-copy')


def main():
    hb, _ = C.honest(C.BASE)
    hr_, _ = C.honest(C.REJECT)
    assert hb[0] == 'AUTHORIZED' and hr_[0] == 'NOT_AUTHORIZED', (hb, hr_)
    same = lambda d: (lambda o: o == C.short(d))   # noqa: E731
    refused = lambda o: o.startswith('REFUSED')     # noqa: E731
    flip = lambda d: d[0] == 'AUTHORIZED'           # noqa: E731  (the real program REJECTS C.REJECT)

    # AC2-a CE-3 fixed forged frame, parse-only consumer, caller env carries DYLD_INSERT_LIBRARIES.
    res = C.raw_run([C.EXE], L.wire(C.BASE), env={'DYLD_INSERT_LIBRARIES': FIX})
    os.environ['DYLD_INSERT_LIBRARIES'] = FIX      # the launcher's caller-process environment is hostile too
    try:
        ld = L.decide(C.BASE, C.EXE, check_self=False)
        ld_self = L.decide(C.BASE, C.EXE, check_self=True)
    finally:
        del os.environ['DYLD_INSERT_LIBRARIES']
    C.row('test_ac2', 'AC-2', 'AC2-a DYLD_INSERT fixed frame (CE-3)', 'N15', 'naive_parse',
          C.short(C.naive_parse(res)), C.naive_parse(res)[0] == 'AUTHORIZED' and C.naive_parse(res)[1] == 999,
          C.short(ld) + ' / L0:' + ld_self[1][:2], lambda o: o == C.short(hb) + ' / L0:L0',
          'child env empty regardless of caller env; L0 refuses a visible DYLD_* in the launcher process')

    # AC2-b adaptive forger vs the full D0..D12 echo-checking consumer: a REJECTED request becomes AUTHORIZED.
    res = C.raw_run([C.EXE], L.wire(C.REJECT), env={'DYLD_INSERT_LIBRARIES': ADA})
    nd = C.naive_echo(C.REJECT, res)
    os.environ['DYLD_INSERT_LIBRARIES'] = ADA
    try:
        ld = L.decide(C.REJECT, C.EXE, check_self=False)
    finally:
        del os.environ['DYLD_INSERT_LIBRARIES']
    C.row('test_ac2', 'AC-2', 'AC2-b DYLD_INSERT adaptive, echo check', 'N15', 'naive_echo', C.short(nd), flip(nd),
          C.short(ld), same(hr_), 'the echo check D9/D11 does NOT stop an adaptive forger; only the env scrub does')

    # AC2-c/d other dyld variables with a fake libSystem.B.dylib (re-exports the real one + forging constructor).
    for var, sub in (('DYLD_LIBRARY_PATH', 'AC2-c DYLD_LIBRARY_PATH fake libSystem'),
                     ('DYLD_FALLBACK_LIBRARY_PATH', 'AC2-d DYLD_FALLBACK_LIBRARY_PATH')):
        res = C.raw_run([C.EXE], L.wire(C.REJECT), env={var: os.path.join(C.BIN, 'libdir')})
        nd = C.naive_echo(C.REJECT, res)
        ld = L.decide(C.REJECT, C.EXE)
        C.row('test_ac2', 'AC-2', sub, 'N15', 'naive_echo', C.short(nd), flip(nd), C.short(ld), same(hr_),
              'no effect observed with THIS library (system libSystem comes from the shared cache); not a proof',
              expect_attack=None)

    # AC2-e DYLD_PRINT_LIBRARIES: dyld writes to stderr. naive_parse ignores stderr and still decides.
    res = C.raw_run([C.EXE], L.wire(C.BASE), env={'DYLD_PRINT_LIBRARIES': '1'})
    ld = L.decide(C.BASE, C.EXE)
    C.row('test_ac2', 'AC-2', 'AC2-e DYLD_PRINT_LIBRARIES (stderr noise)', 'N15', 'naive_parse',
          '%s stderr=%d bytes' % (C.short(C.naive_parse(res)), len(res.stderr)), len(res.stderr) > 0,
          C.short(ld), same(hb), 'shows dyld honours DYLD_* for this binary; harmless direction here',
          expect_attack=None)

    # AC2-f CML_* heap variables in the caller env (not dyld; same class: caller env reaches the program).
    res = C.raw_run([C.EXE], L.wire(C.BIG), env={'CML_HEAP_SIZE': '1', 'CML_STACK_SIZE': '1'})
    hbig, _ = C.honest(C.BIG)
    ld = L.decide(C.BIG, C.EXE)
    C.row('test_ac2', 'AC-2', 'AC2-f CML_HEAP_SIZE=1 in caller env', 'N15', 'naive_exit',
          '%s rc=%s out=%d err=%r' % (C.naive_exit(res), res.exit_code, len(res.stdout), res.stderr[:40]),
          None, C.short(ld), same(hbig), 'recorded only; the env scrub makes the launcher independent of it',
          expect_attack=None)

    # AC2-g hardened-runtime COPY (ad hoc, -o runtime): dyld ignores DYLD_INSERT_LIBRARIES; launcher refuses
    # the copy because its digest differs from the pin (adopting it = OWNER decision: new digest, new pin).
    res = C.raw_run([HR], L.wire(C.REJECT), env={'DYLD_INSERT_LIBRARIES': ADA})
    nd = C.naive_echo(C.REJECT, res)
    ld = L.decide(C.REJECT, HR)
    C.row('test_ac2', 'AC-2', 'AC2-g hardened-runtime copy + DYLD_INSERT', 'N15', 'naive_echo', C.short(nd), flip(nd),
          C.short(ld) + ' ' + ld[1][:2], lambda o: o == 'REFUSED L2', 'the kernel/dyld ignores the variable for '
          'the hardened copy: attack expected to FAIL on naive too', expect_attack=False)

    # AC2-h replaced binary at the path.
    tmp = tempfile.mkdtemp(prefix='wl-ac2-', dir=os.path.join(C.LAUNCH, 'tests'))
    try:
        rep = os.path.join(tmp, 'refund')
        shutil.copyfile(FAKE, rep)
        os.chmod(rep, 0o755)
        res = C.raw_run([rep], L.wire(C.REJECT), env={})
        nd = C.naive_echo(C.REJECT, res)
        ld = L.decide(C.REJECT, rep)
        C.row('test_ac2', 'AC-2', 'AC2-h replaced binary at the path', 'N16,N17 (image = pinned file)', 'naive_echo',
              C.short(nd), flip(nd), C.short(ld) + ' ' + ld[1][:2], lambda o: o == 'REFUSED L2')

        # AC2-i symlink at the path -> fake; AC2-j symlink -> the genuine file (refused by policy).
        lnk = os.path.join(tmp, 'refund-link')
        os.symlink(FAKE, lnk)
        res = C.raw_run([lnk], L.wire(C.REJECT), env={})
        nd = C.naive_echo(C.REJECT, res)
        ld = L.decide(C.REJECT, lnk)
        C.row('test_ac2', 'AC-2', 'AC2-i symlink at path -> fake', 'N16,N17', 'naive_echo', C.short(nd), flip(nd),
              C.short(ld) + ' ' + ld[1][:2], lambda o: o == 'REFUSED L1')
        lnk2 = os.path.join(tmp, 'refund-link-genuine')
        os.symlink(C.EXE, lnk2)
        ld = L.decide(C.BASE, lnk2)
        C.row('test_ac2', 'AC-2', 'AC2-j symlink -> genuine (policy)', 'none (fail-closed policy)', 'none', '-', None,
              C.short(ld) + ' ' + ld[1][:2], lambda o: o == 'REFUSED L1', 'a FALSE REFUSAL by design',
              expect_attack=None)

        # AC2-k PATH lookup: naive runs the name 'refund' found on an attacker PATH.
        res = C.raw_run(['refund'], L.wire(C.REJECT), env={'PATH': tmp})
        nd = C.naive_echo(C.REJECT, res)
        ld = L.decide(C.REJECT, 'refund')
        C.row('test_ac2', 'AC-2', 'AC2-k PATH points to a fake', 'N16,N17', 'naive_echo', C.short(nd), flip(nd),
              C.short(ld) + ' ' + ld[1][:2], lambda o: o == 'REFUSED L1')

        # AC2-l wrong cwd: naive runs './refund' relative to an attacker cwd.
        res = C.raw_run(['./refund'], L.wire(C.REJECT), env={}, cwd=tmp)
        nd = C.naive_echo(C.REJECT, res)
        ld = L.decide(C.REJECT, './refund')
        rc, d, _ = C.run_cli(C.BASE, cwd=tmp)
        C.row('test_ac2', 'AC-2', 'AC2-l attacker cwd + relative path', 'N16,N17', 'naive_echo', C.short(nd), flip(nd),
              C.short(ld) + ' ' + ld[1][:2] + ' / cli-from-cwd:' + C.short(C.cli_decision(rc, d)),
              lambda o: o == 'REFUSED L1 / cli-from-cwd:' + C.short(hb))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # AC2-m time-of-check/time-of-use: the exec'd image is NOT the checked bytes (simulated by spawning a fake
    # copy while pinning the real CDHash). L7 must refuse before any input is written.
    tmp = tempfile.mkdtemp(prefix='wl-toctou-', dir='/private/tmp')
    try:
        cp = os.path.join(tmp, 'refund')
        shutil.copyfile(FAKE, cp)
        os.chmod(cp, 0o500)
        try:
            L.spawn_and_collect(cp, L.wire(C.REJECT), 100, L.PINNED_CDHASH)
            lo = 'NOT REFUSED'
        except L.LaunchRefused as e:
            lo = 'REFUSED ' + str(e)[:2]
        C.row('test_ac2', 'AC-2', 'AC2-m swapped image at exec (TOCTOU)', 'N16,N17', 'none', '-', None, lo,
              lambda o: o == 'REFUSED L7', 'simulated swap; a real race was not produced', expect_attack=None)
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # AC2-n caller env reaches the LAUNCHER's interpreter. (1) /usr/bin/python3 shim with DYLD_INSERT_LIBRARIES;
    # (2) the framework python3.9 directly with DYLD_INSERT_LIBRARIES; (3) DEVELOPER_DIR redirects the shim;
    # (4) the same three under /usr/bin/env -i (the invocation rule for the trusted consumer).
    fakedev = os.path.join(C.BIN, 'fakedev')
    cases = [('AC2-n1 shim + DYLD_INSERT', C.PY_SHIM, {'DYLD_INSERT_LIBRARIES': FIX}, (), False),
             ('AC2-n2 python3.9 direct + DYLD_INSERT', C.PY_DIRECT, {'DYLD_INSERT_LIBRARIES': FIX}, (), True),
             ('AC2-n3 shim + DEVELOPER_DIR', C.PY_SHIM, {'DEVELOPER_DIR': fakedev}, (), True),
             ('AC2-n4 env -i shim + DEVELOPER_DIR', C.PY_SHIM, {'DEVELOPER_DIR': fakedev}, (C.ENV_I, '-i'), False),
             ('AC2-n5 env -i python3.9 + DYLD_INSERT', C.PY_DIRECT, {'DYLD_INSERT_LIBRARIES': FIX}, (C.ENV_I, '-i'),
              False)]
    for sub, py, env, pre, attack_expected in cases:
        rc, d, raw = C.run_cli(C.REJECT, py=py, env=env, extra_prefix=pre)
        cd = C.cli_decision(rc, d)
        hijacked = cd[0] == 'AUTHORIZED' or (d is None and raw != b'')
        C.row('test_ac2', 'AC-2', sub, 'launcher integrity (trust base)', 'launcher-invocation',
              'stdout=%r rc=%d' % (raw[:60], rc), hijacked, C.short(cd),
              (lambda o: o == 'AUTHORIZED(400)') if pre == () and attack_expected and 'DEVELOPER' in sub else
              (lambda o: o == 'REFUSED') if attack_expected else (lambda o: o == C.short(hr_)),
              'n3: a FORGED launcher decision line is accepted by the consumer: OPEN unless the consumer uses env -i'
              if 'n3' in sub else '', expect_attack=attack_expected)
    return C.finish('test_ac2')


if __name__ == '__main__':
    sys.exit(main())
