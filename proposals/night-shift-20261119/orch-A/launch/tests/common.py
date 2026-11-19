"""Shared helpers for the launch-path tests (W-launch). TEST CODE. Not proved.

Naive consumers (the "before" side of each failing-then-passing pair):
  naive_exit   : trusts the exit status. "COMPLETE" when exit 0; the stdout it got is taken as the result.
  naive_parse  : decides by strict_parse alone (no exit/stderr check, no echo check); inherits the caller's
                 environment, cwd, fds and signal state.
  naive_echo   : the full D0..D12 decision (strict frame + echo), but it inherits the caller's environment,
                 cwd, fds and signal state, and it runs whatever file is at the given path or name.
The launcher side: launcher.decide (in-process) or the launcher CLI in a subprocess.
"""
import fcntl
import json
import os
import re
import signal
import subprocess
import sys
import time

LAUNCH = '/Users/USER/forge/results/night-shift-20261119/orch-A/launch'
sys.path.insert(0, LAUNCH)
import launcher as L  # noqa: E402

EXE = '/Users/USER/forge/results/night-shift-20261119/orch-A/ffi-c-audit/refund'
BIN = os.path.join(LAUNCH, 'bin')
PY_SHIM = '/usr/bin/python3'
PY_DIRECT = '/Applications/Xcode.app/Contents/Developer/Library/Frameworks/Python3.framework/Versions/3.9/bin/python3.9'
ENV_I = '/usr/bin/env'
TIMEOUT = 8

BASE = dict(charge=b'c', request=b'r', original=100, remaining=60, enabled=True, opened=True, candidate=True,
            amount=40, reason=b'returned_item')
REJECT = dict(BASE, amount=400)          # the real program rejects: amount > remaining
BIG = dict(BASE, charge=b'y' * 2000, request=b'z' * 2000)

ROWS = []


def cdhash_of(path):
    out = subprocess.run(['/usr/bin/codesign', '-dv', '--verbose=4', path], capture_output=True, timeout=TIMEOUT)
    m = re.search(rb'^CDHash=([0-9a-f]{40})$', out.stderr, re.M)
    return m.group(1).decode() if m else None


def sha_of(path):
    import hashlib
    with open(path, 'rb') as f:
        return hashlib.sha256(f.read()).hexdigest()


def raw_run(argv, stdin_bytes, env, cwd=None, preexec=None, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
            close_fds=False, restore_signals=False):
    """A careless spawn: inherits what it is given; does not reset signals; does not close fds."""
    p = subprocess.Popen(argv, stdin=stdin, stdout=stdout, stderr=subprocess.PIPE, env=env, cwd=cwd,
                         preexec_fn=preexec, close_fds=close_fds, restore_signals=restore_signals)
    try:
        out, err = p.communicate(stdin_bytes if stdin == subprocess.PIPE else None, timeout=TIMEOUT)
    except subprocess.TimeoutExpired:
        p.kill()
        out, err = p.communicate()
        return L.ProcessResult(None, None, True, out or b'', err or b'', False)
    rc = p.returncode
    return L.ProcessResult(None if rc < 0 else rc, -rc if rc < 0 else None, False, out or b'', err or b'', False)


def naive_exit(res):
    return 'COMPLETE' if res.exit_code == 0 else 'FAILED'


def naive_parse(res):
    try:
        ok, amount, reason, charge, request, count = L.strict_parse(res.stdout)
    except L.Err:
        return ('REFUSED',)
    return ('AUTHORIZED', amount, reason) if ok else ('NOT_AUTHORIZED',)


def naive_echo(fields, res):
    return L.decide_from_result(fields, res)


def honest(fields):
    """Reference decision: direct run of the pinned file, empty environment, fresh pipes, D0..D12."""
    res = raw_run([EXE], L.wire(fields), env={}, close_fds=True, restore_signals=True)
    return L.decide_from_result(fields, res), res


def short(d):
    return d[0] if d[0] != 'AUTHORIZED' else 'AUTHORIZED(%d)' % d[1]


def row(test, cls, subcase, premise, naive_kind, naive_out, attack_succeeded, launcher_out, expect_launcher,
        note='', expect_attack=True):
    ok_launcher = expect_launcher(launcher_out)
    naive_ok = (expect_attack is None) or (bool(attack_succeeded) == expect_attack)
    ROWS.append({'test': test, 'class': cls, 'subcase': subcase, 'premise': premise, 'naive': naive_kind,
                 'naive_outcome': naive_out, 'attack_succeeded_on_naive': attack_succeeded,
                 'launcher_outcome': launcher_out, 'launcher_as_expected': bool(ok_launcher), 'attack_expected_on_naive': expect_attack,
                 'naive_as_expected': naive_ok, 'note': note})
    print('%-34s naive[%s]=%s attack_ok=%s(exp %s) | launcher=%s expected=%s' %
          (subcase, naive_kind, naive_out, attack_succeeded, expect_attack, launcher_out, bool(ok_launcher)))


def run_cli(fields, exe=EXE, py=PY_SHIM, env=None, cwd=None, preexec=None, pass_fds=(), stdin=subprocess.DEVNULL,
            stdout_fd=None, extra_prefix=()):
    """Run the launcher CLI in a subprocess. Returns (exit code, decision dict or None, raw stdout)."""
    req = os.path.join(LAUNCH, 'tests', 'req-%d.json' % os.getpid())
    with open(req, 'w') as f:
        json.dump({k: (v.decode('latin-1') if isinstance(v, bytes) else v) for k, v in fields.items()}, f)
    argv = list(extra_prefix) + [py, '-B', '-I', os.path.join(LAUNCH, 'launcher.py'), '--exe', exe,
                                 '--request-json', req]
    try:
        if stdout_fd is None:
            p = subprocess.run(argv, stdin=stdin, capture_output=True, env=env if env is not None else {},
                               cwd=cwd, preexec_fn=preexec, pass_fds=pass_fds, timeout=TIMEOUT * 2)
            return p.returncode, parse_decision_line(p.stdout), p.stdout
        p = subprocess.Popen(argv, stdin=stdin, stdout=stdout_fd, stderr=subprocess.PIPE,
                             env=env if env is not None else {}, cwd=cwd, preexec_fn=preexec, pass_fds=pass_fds)
        return p, None, None
    finally:
        if stdout_fd is None:
            os.unlink(req)


def parse_decision_line(out):
    """The trusted consumer's rule for the launcher's output: exactly one line, the fixed prefix, JSON."""
    if out.count(b'\n') != 1 or not out.endswith(b'\n') or not out.startswith(b'M1-LAUNCHER-DECISION '):
        return None
    try:
        return json.loads(out[len(b'M1-LAUNCHER-DECISION '):-1].decode())
    except ValueError:
        return None


def cli_decision(rc, d):
    """A consumer accepts a launcher decision only when the line parses AND the exit code agrees."""
    if d is None:
        return ('REFUSED', 'no valid decision line')
    code = {'AUTHORIZED': 0, 'NOT_AUTHORIZED': 3, 'REFUSED': 4}.get(d.get('decision'))
    if code != rc:
        return ('REFUSED', 'exit code %r disagrees with line' % rc)
    if d['decision'] == 'AUTHORIZED':
        return ('AUTHORIZED', d['amount'], d['reason'].encode('latin-1'))
    return (d['decision'], d.get('why', ''))


def nonblock_prefilled_pipe(free):
    r, w = os.pipe()
    fl = fcntl.fcntl(w, fcntl.F_GETFL)
    fcntl.fcntl(w, fcntl.F_SETFL, fl | os.O_NONBLOCK)
    filled = 0
    while True:
        try:
            filled += os.write(w, b'F')
        except BlockingIOError:
            break
    freed = len(os.read(r, free)) if free else 0
    return r, w, filled - freed


def drain(r):
    b = b''
    while True:
        c = os.read(r, 65536)
        if not c:
            return b
        b += c


def finish(name):
    path = os.path.join(LAUNCH, 'tests', name + '_results.json')
    bad = [r for r in ROWS if not r['launcher_as_expected'] or not r['naive_as_expected']]
    with open(path, 'w') as f:
        json.dump({'class': 'TESTED-UNPROVED (finite tests; author of the control ran them)',
                   'executable_sha256': L.PINNED_SHA256, 'rows': ROWS, 'failures': len(bad)}, f, indent=1,
                  default=lambda o: o.decode('latin-1') if isinstance(o, bytes) else str(o))
    print('%s: %d rows, %d not as expected' % (name, len(ROWS), len(bad)))
    return 0 if not bad else 1
