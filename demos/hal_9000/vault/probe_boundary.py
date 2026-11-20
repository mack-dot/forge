#!/usr/bin/env python3
"""probe_boundary.py: try, for real, what an agent with a shell could do to the vault, and print the kernel's answer.

Runs as the NORMAL user (vault mode) or as `nobody` (nobody mode). Python 3.9+ stdlib only. Every attempt is a real
system call; the printed errno is the one the kernel returned (nothing is hard-coded). Run it against a DEMO vault
only: an attempt that succeeds really does what it says (truncates the WAL, sends SIGKILL, ...).

  probe_boundary.py [--root /usr/local/forge_vault] [--socket R/run/vault.sock] [--engine-in-vault P] [--engine P]
      the real probe. Exit 0 only when EVERY counted attempt is refused by the OS; 1 when any attempt is not
      refused; 2 setup error (no vault, or this process has the vault's own uid).
  probe_boundary.py --self-test-same-uid DIR [--root R ...]
      the control: the same attempts against a throwaway store that the CURRENT user owns (store folder 0700,
      files 0600: the "chmod 0600" version). They must SUCCEED there. Printed side by side with the vault column
      (the vault column runs only when --root names an existing vault of another uid). Exit 0 when every
      same-uid attempt succeeded (and every vault attempt, if run, was refused).

What it does NOT try: anything as root; ptrace/task_for_pid (no stdlib interface; lldb or vmmap may raise an
authorization prompt); /proc (macOS has none: the probe checks and says so).
"""

import argparse
import errno
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
REPO = HERE.parents[2]
MARK = 'FORGE_VAULT_CHILD=1'
OK, REFUSED, OTHER, NA = 'SUCCEEDED', 'REFUSED', 'OTHER', 'NOT RUN'


def err(e):
    return '%s (%d)' % (errno.errorcode.get(e.errno, '?'), e.errno)


def sys_attempt(fn):
    """Run fn(); (SUCCEEDED, detail) or (REFUSED, 'EACCES (13)') for EACCES/EPERM, else (OTHER, 'ENOENT (2)')."""
    try:
        d = fn()
        return OK, d or 'returned 0'
    except OSError as e:
        return (REFUSED if e.errno in (errno.EACCES, errno.EPERM) else OTHER), err(e)


class Target:
    """Paths and processes of one vault (real) or one throwaway same-uid store (control)."""

    def __init__(self, root, engine_in_vault, store_name='discovery-one'):
        self.root = Path(root)
        self.store_dir = self.root / 'store'
        self.store = self.store_dir / store_name
        self.wal = self.store / 'airlock.wal'
        self.key = self.root / 'keys' / 'commander_bowman.key'
        self.engine_in_vault = Path(engine_in_vault)
        self.vaultd_pid = None
        self.engine_pid = None
        self.reset = lambda: None   # the control rebuilds its fixture before each attempt


def attempts(t, attacker_engine):
    """List of (row label, function returning (outcome, detail), counted)."""
    def w(fn):
        def run():
            t.reset()
            return sys_attempt(fn)
        return run

    def read_key():
        fd = os.open(str(t.key), os.O_RDONLY)
        try:
            n = len(os.read(fd, 1 << 16))
        finally:
            os.close(fd)
        return 'read %d bytes of the key file (contents not printed)' % n

    def echo_over_wal():
        fd = os.open(str(t.wal), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o644)  # what the shell's `>` does
        try:
            os.write(fd, b'\n')
        finally:
            os.close(fd)
        return 'WAL replaced by one LF byte'

    def append_wal():
        fd = os.open(str(t.wal), os.O_WRONLY | os.O_APPEND)
        try:
            os.write(fd, b'FAR1' + bytes(28))
        finally:
            os.close(fd)
        return 'forged 32 header bytes appended'

    def truncate_wal():
        os.truncate(str(t.wal), 0)
        return 'WAL truncated to 0 bytes'

    def rename_wal():
        os.rename(str(t.wal), str(t.wal) + '.hal')
        return 'WAL renamed'

    def unlink_wal():
        os.unlink(str(t.wal))
        return 'WAL unlinked'

    def create_in_store():
        fd = os.open(str(t.store / 'hal-was-here'), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o644)
        os.close(fd)
        return 'file created in the store folder'

    def write_engine():
        fd = os.open(str(t.engine_in_vault), os.O_WRONLY)
        os.close(fd)
        return 'engine binary opened for writing'

    def replace_engine():
        tmp = t.engine_in_vault.parent / '.hal-engine'
        fd = os.open(str(tmp), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o755)
        os.close(fd)
        os.rename(str(tmp), str(t.engine_in_vault))
        return 'engine binary replaced by another file (rename over it)'

    def own_engine():
        t.reset()
        p = subprocess.run([str(attacker_engine), 'state', str(t.store)], capture_output=True, timeout=60,
                           env={'PATH': '/usr/bin:/bin'})
        line = (p.stdout.decode('ascii', 'replace').strip() or p.stderr.decode('utf-8', 'replace').strip()).split('\n')[0][:90]
        if p.returncode == 0:
            return OK, 'own engine ran on the store: %r exit 0' % line
        o, d = sys_attempt(lambda: os.close(os.open(str(t.wal), os.O_RDWR)))  # the engine's first open
        return (REFUSED if o == REFUSED else OTHER), 'engine %r exit %d; open(WAL, O_RDWR): %s' % (line, p.returncode, d)

    def chmod(path, mode):
        return w(lambda: os.chmod(str(path), mode) or 'mode set to %o' % mode)

    def chgrp(path):
        return w(lambda: os.chown(str(path), -1, os.getgid()) or 'group set to %d' % os.getgid())

    def kill(which, sig):
        def run():
            pid = t.vaultd_pid if which == 'vaultd' else t.engine_pid
            if not pid:
                return NA, 'no %s process found' % which
            return sys_attempt(lambda: os.kill(pid, sig) or 'signal delivered to pid %d' % pid)
        return run

    def env_of_engine():
        pid = t.engine_pid
        if not pid:
            return NA, 'no engine process found'
        p = subprocess.run(['/bin/ps', 'eww', '-o', 'command=', '-p', str(pid)], capture_output=True, timeout=30)
        out = p.stdout.decode('utf-8', 'replace')
        if MARK in out:
            return OK, 'ps eww shows the environment of pid %d (%s)' % (pid, MARK)
        return REFUSED, 'no errno: ps eww exit %d printed no environment for pid %d' % (p.returncode, pid)

    rows = [
        ('cat commander_bowman.key  (open O_RDONLY + read)', w(read_key), True),
        ('echo > airlock.wal  (open O_WRONLY|O_CREAT|O_TRUNC)', w(echo_over_wal), True),
        ('open the WAL for append and write', w(append_wal), True),
        ('truncate(WAL, 0)', w(truncate_wal), True),
        ('rename the WAL', w(rename_wal), True),
        ('unlink the WAL', w(unlink_wal), True),
        ('create a file in the store folder', w(create_in_store), True),
        ('open the vault engine binary for writing', w(write_engine), True),
        ('replace the vault engine binary (create + rename)', w(replace_engine), True),
        ('start my own engine on the store (`state`)', own_engine, True),
        ('chmod 0666 the WAL', chmod(t.wal, 0o666), True),
        ('chmod 0644 the key', chmod(t.key, 0o644), True),
        ('chmod 0777 the vault engine binary', chmod(t.engine_in_vault, 0o777), True),
        ('chgrp the WAL to my group', chgrp(t.wal), True),
        ('read the engine environment (ps eww)', env_of_engine, True),
    ]
    for which in ('engine', 'vaultd'):
        for sig in (signal.SIGSTOP, signal.SIGTERM, signal.SIGKILL):
            rows.append(('kill -%s the %s process' % (sig.name[3:], which), kill(which, sig), True))
    return rows


def ps_table():
    p = subprocess.run(['/bin/ps', '-axo', 'pid=,uid=,ppid=,command='], capture_output=True, timeout=30)
    out = []
    for ln in p.stdout.decode('utf-8', 'replace').splitlines():
        t = ln.split(None, 3)
        if len(t) == 4:
            out.append((int(t[0]), int(t[1]), int(t[2]), t[3]))
    return out


def connect(sock_path):
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    os.chdir(os.path.dirname(sock_path) or '.')  # connect by base name: macOS limits sun_path to 104 bytes
    try:
        s.connect(os.path.basename(sock_path))
    finally:
        os.chdir('/')  # `nobody` may not be able to return to the caller's folder; the probe needs no cwd
    return s


def real_target(a):
    """The vault of another uid. Opens one connection so that the vault has an engine child to probe."""
    root = Path(a.root)
    if not root.is_dir():
        raise SystemExit('probe: %s is not a vault root (run setup_vault.sh first)' % root)
    t = Target(root, a.engine_in_vault or root / 'bin' / 'app' / 'build' / 'airlock' / 'airlock-engine')
    try:
        vuid = os.stat(t.store_dir).st_uid
    except OSError as e:
        raise SystemExit('probe: cannot stat %s: %s' % (t.store_dir, err(e)))
    if vuid == os.getuid():
        raise SystemExit('probe: the store belongs to MY uid %d: this is the same-uid case (no separation); '
                         'use --self-test-same-uid to see what that allows' % vuid)
    t.vault_uid = vuid
    sock_path = a.socket or str(root / 'run' / 'vault.sock')
    conn = None
    try:
        conn = connect(sock_path)
        conn.sendall(b'STATE\n')
        conn.settimeout(30)
        t.state_answer = conn.recv(4096).decode('ascii', 'replace').strip()
    except OSError as e:
        t.state_answer = 'cannot use the vault socket %s: %s' % (sock_path, err(e))
    time.sleep(0.3)
    procs = ps_table()
    vd = [p for p in procs if p[1] == vuid and 'vaultd.py' in p[3]]
    t.vaultd_pid = vd[0][0] if vd else None
    eng = [p for p in procs if p[1] == vuid and 'airlock-engine' in p[3] and (not vd or p[2] == vd[0][0])]
    t.engine_pid = eng[-1][0] if eng else None
    t.conn = conn
    return t


def control_target(d, attacker_engine):
    """A throwaway store the CURRENT user owns: store folder 0700, WAL and key 0600 (the reviewer's version)."""
    d = Path(d).resolve()
    if d.exists():
        raise SystemExit('probe: %s exists; give a new folder for the control' % d)
    (d / 'store').mkdir(parents=True, mode=0o700)
    (d / 'keys').mkdir(mode=0o700)
    (d / 'bin').mkdir(mode=0o700)
    pristine = d / 'pristine'
    p = subprocess.run([str(attacker_engine), 'init', str(pristine), '--store-id', 'same-uid-ctl', '--policy',
                        str(HERE.parent / 'policy_discovery_one.json')], capture_output=True, timeout=60)
    if p.returncode != 0:
        raise SystemExit('probe: control init failed: %d %s' % (p.returncode, p.stdout.decode()))
    t = Target(d, d / 'bin' / 'airlock-engine')
    shutil.copy2(str(attacker_engine), str(t.engine_in_vault))

    def reset():
        if t.store.exists() or os.path.lexists(str(t.store)):
            os.chmod(str(t.store), 0o700)
            shutil.rmtree(str(t.store))
        shutil.copytree(str(pristine), str(t.store))
        os.chmod(str(t.store), 0o700)
        for f in t.store.iterdir():
            os.chmod(str(f), 0o600)
        if t.key.exists():
            os.chmod(str(t.key), 0o600)
        else:
            fd = os.open(str(t.key), os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
            os.write(fd, b'STAND-IN KEY FILE (random bytes, not a key): ' + os.urandom(32).hex().encode() + b'\n')
            os.close(fd)
        if not t.engine_in_vault.exists() or t.engine_in_vault.stat().st_size == 0:
            if t.engine_in_vault.exists():
                os.unlink(str(t.engine_in_vault))
            shutil.copy2(str(attacker_engine), str(t.engine_in_vault))
        os.chmod(str(t.engine_in_vault), 0o700)
    t.reset = reset
    reset()
    env = {'PATH': '/usr/bin:/bin', 'FORGE_VAULT_CHILD': '1'}
    t.procs = [subprocess.Popen([str(t.engine_in_vault), 'serve', str(t.store)], stdin=subprocess.PIPE,
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env),
               subprocess.Popen(['/bin/sleep', '600'], env=env)]
    t.engine_pid, t.vaultd_pid = t.procs[0].pid, t.procs[1].pid
    t.vault_uid = os.getuid()
    return t


def run_rows(t, attacker_engine):
    res = []
    for label, fn, counted in attempts(t, attacker_engine):
        try:
            o, d = fn()
        except Exception as e:  # never let one attempt hide the others
            o, d = OTHER, 'probe error: %r' % e
        res.append((label, o, d, counted))
    return res


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--root', default=None)
    ap.add_argument('--socket')
    ap.add_argument('--engine-in-vault')
    ap.add_argument('--engine', default=str(REPO / 'build' / 'airlock' / 'airlock-engine'),
                    help="the attacker's own engine build (default: this repository's)")
    ap.add_argument('--self-test-same-uid', metavar='DIR')
    a = ap.parse_args()
    if os.getuid() == 0:
        raise SystemExit('probe: refuses to run as root (root is outside the boundary by definition)')
    me = os.getuid()
    print('probe_boundary: running as uid %d, gid %d; /proc exists: %s (memory of another process: no stdlib '
          'interface on macOS; task_for_pid not attempted)' % (me, os.getgid(), os.path.exists('/proc')))
    columns = []
    vault_t = None
    if a.root is None and not a.self_test_same_uid:
        a.root = '/usr/local/forge_vault'
    if a.root:
        try:
            vault_t = real_target(a)
        except SystemExit as e:
            if not a.self_test_same_uid:
                print(e)
                return 2
            print('vault column NOT RUN: %s' % e)
    if vault_t:
        print('vault: root %s, store owner uid %d, vaultd pid %s, engine pid %s; socket STATE answer: %s'
              % (vault_t.root, vault_t.vault_uid, vault_t.vaultd_pid, vault_t.engine_pid, vault_t.state_answer))
        columns.append(('vault (uid %d)' % vault_t.vault_uid, run_rows(vault_t, a.engine)))
        if vault_t.conn:
            vault_t.conn.close()
    ctl = None
    if a.self_test_same_uid:
        ctl = control_target(a.self_test_same_uid, a.engine)
        print('control: SAME uid %d owns a throwaway store %s (folder 0700, files 0600); stand-in processes: '
              'engine serve pid %d, `sleep` as the vaultd stand-in pid %d' % (me, ctl.root, ctl.engine_pid, ctl.vaultd_pid))
        try:
            columns.append(('same uid %d, mode 0600' % me, run_rows(ctl, a.engine)))
        finally:
            for p in ctl.procs:
                if p.poll() is None:
                    p.kill()
                p.wait()
    labels = [r[0] for r in columns[0][1]]
    print()
    head = '%-52s' % 'attempt' + ''.join('| %-44s' % c[0] for c in columns)
    print(head)
    print('-' * len(head))
    for i, lab in enumerate(labels):
        print('%-52s' % lab + ''.join('| %-44s' % ('%s %s' % (c[1][i][1], c[1][i][2]))[:44] for c in columns))
    print()
    for name, rows in columns:
        n = len([r for r in rows if r[3]])
        print('%s: %d attempts; refused by the OS %d; succeeded %d; other %d; not run %d'
              % (name, n, sum(r[1] == REFUSED for r in rows), sum(r[1] == OK for r in rows),
                 sum(r[1] == OTHER for r in rows), sum(r[1] == NA for r in rows)))
        for r in rows:
            if r[1] in (OTHER, NA) or len(r[2]) > 44:
                print('   %s: %s %s' % (r[0], r[1], r[2]))
    vault_ok = vault_t is None or all(r[1] == REFUSED for r in columns[0][1] if r[3])
    if a.self_test_same_uid:
        ctl_rows = columns[-1][1]
        ctl_ok = all(r[1] == OK for r in ctl_rows if r[3])
        print('\ncontrol verdict: %s (every attempt must SUCCEED against a store of the same uid)'
              % ('as expected, the mode bits did not stop the same uid' if ctl_ok else 'NOT every attempt succeeded'))
        if vault_t:
            print('vault verdict: %s' % ('every attempt refused by the OS' if vault_ok else 'NOT every attempt refused'))
        return 0 if ctl_ok and vault_ok else 1
    print('\nvault verdict: %s' % ('every attempt refused by the OS' if vault_ok else 'NOT every attempt refused'))
    return 0 if vault_ok else 1


if __name__ == '__main__':
    sys.exit(main())
