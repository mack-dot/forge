"""Shared harness of the video cut (Python stdlib only). end_to_end=false.

Rule of this folder: a verdict on screen is ALWAYS the answer line of a process that this run started (the
forge-airlock engine through the SDK, or a tool that a scenario names). A scenario states what it REQUIRES
(`want`), the harness prints what it OBSERVED, and a difference makes the take fail (exit 1). No scenario
may build an answer line itself. Every number on screen is measured in this run or read from a committed
record that is named by path.

Labels: the engine is a NATIVE CHECK (Rust, not proved). PROVED applies only to what a scenario names with
its proof record (for example the Dafny source of the booking checker).
"""

import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
POLICIES = HERE / 'policies'
DISPATCHER = ROOT / 'bin' / 'forge-airlock'
sys.path.insert(0, str(ROOT / 'sdk' / 'py'))
import forge_airlock as fa  # noqa: E402

LBL_NATIVE = 'NATIVE CHECK + FINITE TEST'
ALLOWED_CODES = ('COMMITTED', 'OK', 'ACCEPT')  # every other answer, and every raised AirlockError, is BLOCKED


class TakeFailed(Exception):
    """A required result was not observed, or a tool is missing. The take is not usable."""


class Shot:
    """One request to a real component and its observed answer."""

    def __init__(self, domain, headline, rule, request, want, observed, ms, label, klass=None):
        self.domain, self.headline, self.rule, self.request = domain, headline, rule, request
        self.want, self.observed, self.ms, self.label = want, observed, ms, label
        first = observed.split(' ')[0] if observed else ''
        # EVENT: a step that is neither an allowed effect nor a refusal (a kill point reached, an exception seen).
        if klass not in (None, 'ALLOWED', 'BLOCKED', 'EVENT'):
            raise TakeFailed('bad shot class %r' % (klass,))
        self.klass = klass or ('ALLOWED' if first in ALLOWED_CODES else 'BLOCKED')
        self.ok = observed == want or observed.startswith(want + ' ')

    def as_dict(self):
        return {'domain': self.domain, 'headline': self.headline, 'rule': self.rule, 'request': self.request,
                'required': self.want, 'observed': self.observed, 'class': self.klass, 'ms': round(self.ms, 3),
                'label': self.label, 'result': 'PASS' if self.ok else 'FAIL'}


def observed_of(res):
    """The observed text of an SDK Result: the engine's own answer line when there is one."""
    if isinstance(res, fa.Result):
        if res.line and '\n' not in res.line.strip():
            return res.line.strip()
        return ('%s %s' % (res.code, res.detail)).strip()
    raise TakeFailed('not an SDK result: %r' % (res,))


class Ctx:
    """One take: temp folder, stores, shots, notes, gaps. Scenario modules get one Ctx."""

    def __init__(self, node, engine_dir=None, fast=False, flood_mb=64, out=None):
        self.node = str(node)
        self.engine_dir = str(Path(engine_dir).resolve()) if engine_dir else str(ROOT / 'build' / 'airlock')
        self.fast, self.flood_mb = fast, flood_mb
        self.out = out or (lambda text='': print(text, flush=True))
        self.tmp = Path(tempfile.mkdtemp(prefix='video-cut-'))
        self.env = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C'}
        self.shots, self.notes, self.gaps, self._stores = [], [], [], []
        self.skipped = []  # parts that did not run: the runner makes the take PARTIAL (exit 3), never a full pass
        self._keys = None
        for need in ('airlock-engine',):
            if not (Path(self.engine_dir) / need).is_file():
                raise TakeFailed('%s/%s is missing: run `python3 bin/forge-airlock build --checker`' % (self.engine_dir, need))

    # -- processes
    def cli(self, args, stdin=b'', timeout=300):
        """Run the dispatcher. Returns (exit code, stdout text, stderr text)."""
        args = [str(x) for x in args]
        if args[0] in ('init', 'replay', 'leases', 'state', 'get', 'cosign-message'):
            args += ['--engine-dir', self.engine_dir]
        p = subprocess.run([sys.executable, str(DISPATCHER)] + args, input=stdin, capture_output=True, timeout=timeout, env=self.env)
        return p.returncode, p.stdout.decode('ascii', 'replace'), p.stderr.decode('utf-8', 'replace')

    def keys(self):
        """Two temporary Ed25519 key files: the human's and a stranger's. Made once per take, never printed."""
        if self._keys is None:
            d = self.tmp / 'keys'
            d.mkdir(mode=0o700)
            human, other = d / 'human.key', d / 'other.key'
            code, pub, err = self.cli(['cosign-keygen', human])  # no options: the cosign tools run ssh-keygen, no Node
            code2, _, err2 = self.cli(['cosign-keygen', other])
            if code or code2:
                raise TakeFailed('cosign keygen failed: %r %r' % (err[-300:], err2[-300:]))
            self._keys = (human, other, pub.strip())
        return self._keys

    def store_dir(self, name):
        return self.tmp / ('store-' + name)

    def store(self, name, policies, cosign=False, store_id=None):
        """init a fresh store with the named policy files (in demos/video_cut/policies or absolute) and open an SDK client."""
        d = self.store_dir(name)
        args = ['init', d, '--store-id', store_id or name, '--node', self.node]
        if cosign:
            args += ['--cosign-pubkey', self.keys()[2]]
        for p in policies:
            args += ['--policy', p if os.path.isabs(str(p)) else POLICIES / p]
        code, out, err = self.cli(args)
        if code != 0:
            raise TakeFailed('init of store %s: exit %d %r %r' % (name, code, out[:300], err[-300:]))
        return self.client(name)

    def client(self, name):
        st = fa.Store(self.store_dir(name), node=self.node, env=self.env, engine_dir=self.engine_dir)
        self._stores.append(st)
        st.state()  # the serve process is up before the first timed request
        return st

    def sign(self, st, action, stranger=False):
        """The human (or a stranger) signs the engine's own cosign message for `action`. Returns the one-line SSHSIG token that cosign-sign prints."""
        key = self.keys()[1 if stranger else 0]
        code, sig, err = self.cli(['cosign-sign', key], stdin=st.cosign_message(action))
        if code != 0:
            raise TakeFailed('cosign-sign failed: %r' % err[-300:])
        return sig.strip()

    # -- shots
    def shot(self, domain, headline, rule, request, want, fn, label=LBL_NATIVE, klass=None):
        """Run fn() (an SDK call that returns a Result), time it, record what the engine answered.

        `want` is the required start of the observed answer, for example 'COMMITTED' or 'REJECTED_POLICY RULE'.
        A raised AirlockError is recorded as 'RAISED <class> <code> <detail>' (never a commit).
        """
        t = time.perf_counter()
        try:
            res = fn()
            ms = (time.perf_counter() - t) * 1000
            observed = res if isinstance(res, str) else observed_of(res)
        except fa.AirlockError as e:
            ms = (time.perf_counter() - t) * 1000
            res, observed = e, ('RAISED %s %s %s' % (type(e).__name__, e.code, e.detail)).strip()
        s = Shot(domain, headline, rule, request, want, observed, ms, label, klass)
        self.shots.append(s)
        return s, res

    def record(self, domain, headline, rule, request, want, observed, ms, label, klass=None):
        """A shot whose answer came from a real process that is not an SDK call (the scenario started it and
        passes the tool's own output text as `observed`)."""
        s = Shot(domain, headline, rule, request, want, observed, ms, label, klass)
        self.shots.append(s)
        return s

    def note(self, domain, name, value, source):
        """A measured value or a value read from a committed record. `source` says which: 'measured live' or a path."""
        self.notes.append({'domain': domain, 'name': name, 'value': value, 'source': source})

    def gap(self, domain, text):
        """Something the directive names that the real engine cannot express, or a part that is not in the take."""
        self.gaps.append({'domain': domain, 'gap': text})

    def skip(self, domain, text):
        """A part of a scenario did NOT run (a tool is missing). It is printed as a gap, and the take is PARTIAL."""
        self.skipped.append('domain %s: %s' % (domain, text))
        self.gap(domain, text)

    # -- measurements
    @staticmethod
    def rss_kib(pid):
        """Resident memory of a live process in KiB, from /bin/ps. None if the process is gone."""
        p = subprocess.run(['/bin/ps', '-o', 'rss=', '-p', str(pid)], capture_output=True, text=True)
        text = p.stdout.strip()
        return int(text) if p.returncode == 0 and text.isdigit() else None

    def replay(self, name):
        """Effect records of a store from the engine's own replay: list of token lists."""
        code, out, err = self.cli(['replay', self.store_dir(name)])
        if code != 0 or not out.startswith('REPLAY '):
            raise TakeFailed('replay of %s failed: %d %r' % (name, code, out[:200]))
        return [ln.split(' ', 2)[2].split(' ') for ln in out.split('\n')[1:] if ln]

    def close(self, keep=False):
        for st in self._stores:
            try:
                st.close()
            except Exception:  # noqa: BLE001  (closing; the take's result is already decided)
                pass
        if not keep:
            shutil.rmtree(self.tmp, ignore_errors=True)


def find_node(explicit=None):
    cand = explicit or os.environ.get('FORGE_AIRLOCK_NODE') or ('/opt/homebrew/bin/node' if os.path.exists('/opt/homebrew/bin/node') else shutil.which('node'))
    if not cand:
        raise TakeFailed('no node found: give --node /path/to/node (Node 24.3.0)')
    out = subprocess.run([cand, '--version'], capture_output=True, text=True, timeout=30).stdout.strip()
    if out != 'v24.3.0':
        raise TakeFailed('node %s is %r; the repository pins v24.3.0' % (cand, out))
    return str(Path(cand).resolve()) if os.path.isabs(cand) else shutil.which(cand)


def dump(ctx):
    return json.dumps({'shots': [s.as_dict() for s in ctx.shots], 'notes': ctx.notes, 'gaps': ctx.gaps}, indent=1)


# ---------------------------------------------------------------------------------- heavy lock (additive helper)
LOCK_BASE = Path('/private/tmp/claude-501/forge-locks')
HEAVY_LOCK = LOCK_BASE / 'heavy.lock'


def swap_free_mib():
    """Free swap in MiB from `sysctl vm.swapusage`, or None if it cannot be read."""
    try:
        text = subprocess.run(['/usr/sbin/sysctl', 'vm.swapusage'], capture_output=True, text=True, timeout=10).stdout
        part = text.split('free = ')[1].split()[0]
        return float(part[:-1]) * {'M': 1.0, 'G': 1024.0, 'K': 1 / 1024.0}[part[-1]]
    except (OSError, IndexError, ValueError, KeyError, subprocess.SubprocessError):
        return None


class heavy_lock:
    """Context manager: the shared heavy-job lock (atomic mkdir of forge-locks/heavy.lock).

    It writes the files owner, cmd and start (UTC). It waits while another holder has the lock. It removes
    only its own lock, in every exit path. If the folder forge-locks does not exist, there is no lock
    (another machine). `self.held` says whether this object holds the lock.
    """

    def __init__(self, cmd, owner='VIDEO9', poll_s=20, out=None, max_wait_s=0):
        self.cmd, self.owner, self.poll_s, self.out, self.held = str(cmd), owner, poll_s, out, False
        self.max_wait_s = max_wait_s  # 0: wait without limit; else TakeFailed after this many seconds
        self.mark = '%s pid=%d nonce=%s' % (owner, os.getpid(), os.urandom(8).hex())  # the owner file: only OUR lock is removed

    def __enter__(self):
        if not LOCK_BASE.is_dir():
            return self
        told, began = 0.0, time.monotonic()
        while True:
            try:
                os.mkdir(HEAVY_LOCK)
                break
            except FileExistsError:
                if self.out and time.monotonic() - told > 300:
                    told = time.monotonic()
                    try:
                        who = (HEAVY_LOCK / 'owner').read_text().strip()
                    except OSError:
                        who = '?'
                    self.out('lock| waiting for %s (held by %s)' % (HEAVY_LOCK, who))
                if self.max_wait_s and time.monotonic() - began > self.max_wait_s:
                    raise TakeFailed('heavy.lock was not free after %d s: the heavy run did not start' % self.max_wait_s)
                time.sleep(self.poll_s)
        self.held = True
        try:
            (HEAVY_LOCK / 'owner').write_text(self.mark + '\n')
            (HEAVY_LOCK / 'cmd').write_text(self.cmd + '\n')
            (HEAVY_LOCK / 'start').write_text(time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime()) + '\n')
        except BaseException:
            self.__exit__(None, None, None)
            raise
        return self

    def __exit__(self, *exc):
        if self.held:
            self.held = False
            try:
                mine = (HEAVY_LOCK / 'owner').read_text().strip() == self.mark
            except FileNotFoundError:
                mine = HEAVY_LOCK.is_dir() and not any(HEAVY_LOCK.iterdir())  # we made it and wrote nothing yet
            except OSError:
                mine = False
            if mine:  # never remove a lock that another holder took after ours was removed
                shutil.rmtree(HEAVY_LOCK, ignore_errors=True)
        return False
