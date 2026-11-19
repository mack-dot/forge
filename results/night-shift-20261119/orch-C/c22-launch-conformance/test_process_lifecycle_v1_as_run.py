"""Defensive conformance tests for the refund launcher (orch-A/launch/launcher.py).

Written by Orchestrator C (red team), night shift 2026-11-19. These tests check that the launcher REFUSES a
result unless the process ended correctly. They do not change the launcher. A failing test shows a gap; the fix
is the launcher owner's work.

What each group checks:
  1. Decision rule (no process is started): stdout must be the complete expected frame (exact bytes, exact
     length); the exit status must be 0; a signal, a time-out, text on stderr, or too much output is refused.
  2. Process lifecycle with a harmless test child (a small /bin/sh script, NOT the refund program):
     the child gets an empty environment; a non-zero exit status is refused; a child that ends by SIGABRT
     (the way a C abort ends a process) is refused; a child that writes half a frame and exits 0 is refused;
     a child that does not end is stopped by the time limit and refused.
  3. The same lifecycle check when the caller started the launcher with SIGCHLD ignored: the launcher must
     still see that the child failed.

Run:  /usr/bin/python3 -B -I test_process_lifecycle.py     (exit 0 = every check holds; exit 1 = a gap is shown)
The image-identity check of the launcher (code signature hash) is switched off for the test child by passing
pinned_cdhash=None, because the test child is a shell script and not the pinned program.
"""
import importlib.util
import os
import signal
import stat
import sys
import tempfile
import unittest

LAUNCHER = '<REPO>/results/night-shift-20261119/orch-A/launch/launcher.py'
_spec = importlib.util.spec_from_file_location('launcher_under_test', LAUNCHER)
L = importlib.util.module_from_spec(_spec)
sys.dont_write_bytecode = True
_spec.loader.exec_module(L)

REQUEST = dict(charge=b'ch_1', request=b'rq_1', original=1000, remaining=1000, enabled=True, opened=True,
               candidate=True, amount=100, reason=b'duplicate_charge')
EXPECTED = L.expected_accept(REQUEST)
BOUND = L.output_bound(REQUEST)


def result(exit_code=0, sig=None, timed_out=False, stdout=EXPECTED, stderr=b'', overflow=False):
    return L.ProcessResult(exit_code=exit_code, signal=sig, timed_out=timed_out, stdout=stdout, stderr=stderr,
                           overflow=overflow)


class DecisionRule(unittest.TestCase):
    """Group 1: the decision rule alone. No process is started."""

    def test_complete_frame_with_exit_status_zero_is_authorized(self):
        self.assertEqual(L.decide_from_result(REQUEST, result())[0], 'AUTHORIZED')

    def test_zero_amount_request_is_authorized(self):
        zero = dict(REQUEST, amount=0)
        self.assertEqual(L.decide_from_result(zero, result(stdout=L.expected_accept(zero)))[0], 'AUTHORIZED')

    def test_every_incomplete_stdout_is_refused(self):
        for cut in range(len(EXPECTED)):
            verdict = L.decide_from_result(REQUEST, result(stdout=EXPECTED[:cut]))
            self.assertEqual(verdict[0], 'REFUSED', 'stdout cut to %d of %d bytes' % (cut, len(EXPECTED)))

    def test_stdout_with_one_extra_byte_is_refused(self):
        for extra in (b'\n', b' ', b')', b'\x00'):
            self.assertEqual(L.decide_from_result(REQUEST, result(stdout=EXPECTED + extra))[0], 'REFUSED')

    def test_nonzero_exit_status_is_refused_even_with_a_complete_frame(self):
        for code in (1, 2, 3, 127, 255):
            self.assertEqual(L.decide_from_result(REQUEST, result(exit_code=code))[0], 'REFUSED')

    def test_end_by_signal_is_refused_even_with_a_complete_frame(self):
        for sig in (signal.SIGABRT, signal.SIGKILL, signal.SIGSEGV, signal.SIGTERM):
            self.assertEqual(L.decide_from_result(REQUEST, result(exit_code=None, sig=int(sig)))[0], 'REFUSED')

    def test_time_out_is_refused_even_with_a_complete_frame(self):
        self.assertEqual(L.decide_from_result(REQUEST, result(timed_out=True))[0], 'REFUSED')

    def test_text_on_stderr_is_refused(self):
        self.assertEqual(L.decide_from_result(REQUEST, result(stderr=b'x'))[0], 'REFUSED')

    def test_too_much_output_is_refused(self):
        self.assertEqual(L.decide_from_result(REQUEST, result(overflow=True))[0], 'REFUSED')

    def test_frame_for_another_amount_or_request_is_refused(self):
        for other in (dict(REQUEST, amount=999), dict(REQUEST, request=b'rq_2'), dict(REQUEST, charge=b'ch_2')):
            verdict = L.decide_from_result(REQUEST, result(stdout=L.expected_accept(other)))
            self.assertEqual(verdict[0], 'REFUSED')

    def test_rejection_frame_gives_not_authorized_and_never_authorized(self):
        self.assertEqual(L.decide_from_result(REQUEST, result(stdout=L.REJECTED_BYTES))[0], 'NOT_AUTHORIZED')


class ProcessLifecycle(unittest.TestCase):
    """Group 2: the launcher's process handling, with a harmless /bin/sh test child."""

    def setUp(self):
        self.dir = tempfile.mkdtemp(prefix='c22-lifecycle-')
        with open(os.path.join(self.dir, 'frame.bin'), 'wb') as f:
            f.write(EXPECTED)
        with open(os.path.join(self.dir, 'half.bin'), 'wb') as f:
            f.write(EXPECTED[:len(EXPECTED) // 2])

    def tearDown(self):
        for name in os.listdir(self.dir):
            os.unlink(os.path.join(self.dir, name))
        os.rmdir(self.dir)

    def child(self, body):
        path = os.path.join(self.dir, 'child.sh')
        with open(path, 'w') as f:
            f.write('#!/bin/sh\n' + body + '\n')
        os.chmod(path, stat.S_IRWXU)
        return path

    def run_child(self, body, time_limit=5.0):
        return L.spawn_and_collect(self.child(body), b'x', BOUND, None, time_limit=time_limit)

    def test_child_environment_is_empty(self):
        """The launcher must not pass the caller's variables (loader variables such as DYLD_*, or any other)."""
        saved = dict(os.environ)
        os.environ['DYLD_LIBRARY_PATH'] = '/nonexistent-c22'
        os.environ['C22_MARKER'] = 'must-not-reach-the-child'
        try:
            r = L.spawn_and_collect(self.child('/usr/bin/env'), b'x', 65536, None)
        finally:
            os.environ.clear()
            os.environ.update(saved)
        names = sorted(line.split(b'=', 1)[0] for line in r.stdout.splitlines() if b'=' in line)
        allowed_from_shell = {b'PWD', b'SHLVL', b'_', b'OLDPWD'}   # /bin/sh sets these itself
        self.assertEqual([n for n in names if n not in allowed_from_shell], [], 'child saw: %r' % names)

    def test_complete_frame_and_exit_zero_is_authorized(self):
        r = self.run_child('/bin/cat frame.bin')
        self.assertEqual(L.decide_from_result(REQUEST, r)[0], 'AUTHORIZED', repr(r))

    def test_nonzero_exit_status_after_a_complete_frame_is_refused(self):
        r = self.run_child('/bin/cat frame.bin; exit 3')
        self.assertEqual(r.exit_code, 3, repr(r))
        self.assertEqual(L.decide_from_result(REQUEST, r)[0], 'REFUSED')

    def test_abort_after_a_complete_frame_is_refused(self):
        """A C abort ends the process by SIGABRT. The launcher must report the signal and refuse."""
        r = self.run_child('/bin/cat frame.bin; kill -ABRT $$')
        self.assertEqual(r.signal, int(signal.SIGABRT), repr(r))
        self.assertEqual(L.decide_from_result(REQUEST, r)[0], 'REFUSED')

    def test_half_a_frame_and_exit_zero_is_refused(self):
        r = self.run_child('/bin/cat half.bin')
        self.assertEqual(r.exit_code, 0, repr(r))
        self.assertEqual(L.decide_from_result(REQUEST, r)[0], 'REFUSED')

    def test_no_output_and_exit_zero_is_refused(self):
        r = self.run_child('exit 0')
        self.assertEqual(L.decide_from_result(REQUEST, r)[0], 'REFUSED')

    def test_child_that_does_not_end_is_stopped_and_refused(self):
        r = self.run_child('/bin/cat frame.bin; exec /bin/sleep 30', time_limit=1.0)
        self.assertTrue(r.timed_out, repr(r))
        self.assertEqual(L.decide_from_result(REQUEST, r)[0], 'REFUSED')


class ProcessLifecycleWhenCallerIgnoresSigchld(ProcessLifecycle):
    """Group 3: the same failure checks when the caller started the launcher with SIGCHLD ignored.
    With SIGCHLD ignored the kernel discards the child's exit status. The launcher must not read that as success."""

    def run_child(self, body, time_limit=5.0):
        previous = signal.signal(signal.SIGCHLD, signal.SIG_IGN)
        try:
            return L.spawn_and_collect(self.child(body), b'x', BOUND, None, time_limit=time_limit)
        finally:
            signal.signal(signal.SIGCHLD, previous)

    def test_nonzero_exit_status_after_a_complete_frame_is_refused(self):
        r = self.run_child('/bin/cat frame.bin; exit 3')
        self.assertEqual(L.decide_from_result(REQUEST, r)[0], 'REFUSED', 'launcher result: %r' % (r,))

    def test_abort_after_a_complete_frame_is_refused(self):
        r = self.run_child('/bin/cat frame.bin; kill -ABRT $$')
        self.assertEqual(L.decide_from_result(REQUEST, r)[0], 'REFUSED', 'launcher result: %r' % (r,))

    # The remaining inherited tests run unchanged under SIGCHLD ignored.
    test_child_environment_is_empty = None


if __name__ == '__main__':
    unittest.main(verbosity=2)
