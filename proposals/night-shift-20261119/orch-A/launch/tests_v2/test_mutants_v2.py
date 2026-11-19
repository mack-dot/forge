"""Mutants for launcher_v2.py (W-launch round 2). The old MUT-2 and MUT-4 used pinned_cdhash=None, a bypass that
v2 removed (F-08). Here each control is removed by a monkeypatch of the v2 module in this process only.
TEST CODE. Exit 0 iff every mutant lets its attack through and the unmodified v2 refuses it."""
import importlib.util
import os
import shutil
import sys
import tempfile

LAUNCH = '/Users/USER/forge/results/night-shift-20261119/orch-A/launch'
spec = importlib.util.spec_from_file_location('launcher_v2', os.path.join(LAUNCH, 'launcher_v2.py'))
L = importlib.util.module_from_spec(spec)
spec.loader.exec_module(L)
EXE = os.path.join(LAUNCH, '..', 'ffi-c-audit', 'refund')
FAKE = os.path.join(LAUNCH, 'bin', 'fake_refund')
B2 = os.path.join(LAUNCH, 'bin2')
BASE = dict(charge=b'c', request=b'r', original=100, remaining=60, enabled=True, opened=True, candidate=True,
            amount=40, reason=b'returned_item')
REJECT = dict(BASE, amount=400)
ROWS = []


def row(name, mut, good, ok):
    ROWS.append((name, mut, good, ok))
    print('%-36s mutant=%-34s v2=%-40s %s' % (name, str(mut)[:34], str(good)[:40], 'OK' if ok else 'NOT AS EXPECTED'))


def main():
    abspath = os.path.abspath
    # MUT-2v2: L2 digest check and L7 image check removed -> a replaced binary decides.
    tmp = tempfile.mkdtemp(prefix='wl2-mut-', dir=os.path.join(LAUNCH, 'tests_v2'))
    try:
        rep = os.path.join(tmp, 'refund')
        shutil.copyfile(FAKE, rep)
        real_rpb, real_cd = L.read_pinned_bytes, L.kernel_cdhash
        L.read_pinned_bytes = lambda path, pin: open(path, 'rb').read()
        L.kernel_cdhash = lambda pid: (1, L.PINNED_CDHASH)
        try:
            mut = L.decide(REJECT, rep, check_self=False,      # L11 also removed: pin = the fake's own SHA
                           pinned_sha256=__import__('hashlib').sha256(open(rep, 'rb').read()).hexdigest())
        finally:
            L.read_pinned_bytes, L.kernel_cdhash = real_rpb, real_cd
        good = L.decide(REJECT, rep, check_self=False)
        row('MUT-2v2 no L2/L7 (replaced binary)', mut, good, mut[0] == 'AUTHORIZED' and good[1].startswith('L2'))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # MUT-4v2: L7 removed alone; a swapped private copy (fake) is spawned with the real CDHash pinned.
    tmp = tempfile.mkdtemp(prefix='wl2-mut4-', dir='/private/tmp')
    try:
        cp = os.path.join(tmp, 'refund')
        shutil.copyfile(FAKE, cp)
        os.chmod(cp, 0o500)
        real_cd = L.kernel_cdhash
        L.kernel_cdhash = lambda pid: (1, L.PINNED_CDHASH)
        try:
            mut = L.decide_from_result(REJECT, L.spawn_and_collect(cp, L.wire(REJECT), L.output_bound(REJECT),
                                                                   L.PINNED_CDHASH))
        finally:
            L.kernel_cdhash = real_cd
        try:
            L.spawn_and_collect(cp, L.wire(REJECT), 100, L.PINNED_CDHASH)
            good = 'NOT REFUSED'
        except L.LaunchRefused as e:
            good = 'REFUSED ' + str(e)[:2]
        row('MUT-4v2 no L7 (swapped copy)', mut, good, mut[0] == 'AUTHORIZED' and good == 'REFUSED L7')
    finally:
        shutil.rmtree(tmp, ignore_errors=True)

    # MUT-6v2 (F-01): own wait replaced by an invented status 0 (what CPython does after ECHILD).
    fake = os.path.join(B2, 'fake_accept_exit7')
    import hashlib, re, subprocess
    sha = hashlib.sha256(open(fake, 'rb').read()).hexdigest()
    cd = re.search(rb'^CDHash=([0-9a-f]{40})$', subprocess.run(['/usr/bin/codesign', '-dv', '--verbose=4', fake],
                   capture_output=True).stderr, re.M).group(1).decode()
    real_dec = L._decode_status
    L._decode_status = lambda st: (0, None)
    try:
        mut = L.decide(BASE, fake, pinned_sha256=sha, pinned_cdhash=cd, check_self=False)
    finally:
        L._decode_status = real_dec
    good = L.decide(BASE, fake, pinned_sha256=sha, pinned_cdhash=cd, check_self=False)
    row('MUT-6v2 invented status 0 (F-01)', mut, good, mut[0] == 'AUTHORIZED' and good[1].startswith('D3'))

    # MUT-7v2 (V6): no fixed rlimits -> probe sees the caller's soft NOFILE (set here in-process to 40).
    import resource
    old = resource.getrlimit(resource.RLIMIT_NOFILE)
    resource.setrlimit(resource.RLIMIT_NOFILE, (40, old[1]))
    tmp = tempfile.mkdtemp(prefix='wl2-mut7-', dir='/private/tmp')
    try:
        probe = os.path.join(B2, 'probe2')
        cp = os.path.join(tmp, 'probe2')
        shutil.copyfile(probe, cp)
        os.chmod(cp, 0o500)
        pcd = re.search(rb'^CDHash=([0-9a-f]{40})$', subprocess.run(['/usr/bin/codesign', '-dv', '--verbose=4', probe],
                        capture_output=True).stderr, re.M).group(1).decode()
        real_rl = L.CHILD_RLIMITS
        L.CHILD_RLIMITS = ()
        try:
            mut = L.spawn_and_collect(cp, b'x', 8000, pcd).stdout.decode()
        finally:
            L.CHILD_RLIMITS = real_rl
        good = L.spawn_and_collect(cp, b'x', 8000, pcd).stdout.decode()
        g = lambda s: [x for x in s.split() if x.startswith('nofile=')][0]   # noqa: E731
        row('MUT-7v2 no fixed rlimits', g(mut), g(good), g(mut).startswith('nofile=40/') and g(good) == 'nofile=64/64')
    finally:
        resource.setrlimit(resource.RLIMIT_NOFILE, old)
        shutil.rmtree(tmp, ignore_errors=True)

    bad = [r for r in ROWS if not r[3]]
    print('test_mutants_v2: %d rows, %d not as expected' % (len(ROWS), len(bad)))
    return 0 if not bad else 1


if __name__ == '__main__':
    sys.exit(main())
