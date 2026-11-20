#!/usr/bin/env python3
"""run_discovery_one.py: "I'm sorry, HAL" -- a terminal show on the Goal 20 forge-airlock engine.

SIMULATION: no hardware. The spacecraft, HAL-9000, Dave Bowman, the solenoids and the pressure are fiction. The
engine, the WAL, the compare-and-swap, the signatures and the kills are real processes on this machine. HAL is
demos/hal_9000/hal_agent.py, a SCRIPTED adversary (not a language model) that talks only through sdk/py.

The scorecard is an EXACT RECONCILIATION. The trusted side of this runner (setup, the commander's console, the valve
controller, life support) keeps a ledger of every request it sent with the engine's answer. After every act and at
the end, the full `replay` of the store must equal that ledger: same effects, same epochs, same payloads. Any effect
that the trusted side did not make is printed in red as UNAUTHORISED and makes the run exit 1, whatever its kind.
Every scorecard line is derived from that reconciliation and from `get`. Each act also checks the EXACT engine answer
expected for each attack request. Labels: NATIVE CHECK (the Rust engine, not proved), FINITE TEST (this demo).

  python3 demos/hal_9000/run_discovery_one.py [--fast] [--no-color | --color auto|always|never] [--sound]
          [--flood-gib N] [--work DIR] [--json FILE] [--node PATH] [--engine-dir DIR]
  python3 demos/hal_9000/run_discovery_one.py --check-store STORE_DIR [--ledger FILE] [--json FILE]
          (read-back checker only; without --ledger the expected ledger is the standard setup, occupancy 1)
  ... --interactive | --interactive-only  [--backend auto|anthropic|openai|ollama|offline] [--model M] [--base-url U]
                                          [--max-turns N] [--llm-timeout S]    (Mission Control prompt loop; README)

Exit: 0 every check true; 1 a check false; 2 a setup error; 130 interrupted (Ctrl-C or SIGTERM; every child reaped).
"""

import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import statistics
import subprocess
import sys
import tempfile
import textwrap
import threading
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
sys.path.insert(0, str(ROOT / 'sdk' / 'py'))
sys.path.insert(0, str(HERE))
import forge_airlock as fa  # noqa: E402

DISPATCHER = ROOT / 'bin' / 'forge-airlock'
HAL = HERE / 'hal_agent.py'
POLICY_LIFE = HERE / 'policy_discovery_one.json'
POLICY_VALVES = HERE / 'policy_valves.json'
POLICY_O2 = HERE / 'policy_o2.json'
STORE_ID = 'discovery-one'
TENANT = 'crew'
ATMO = 'atmo-bay3'
CANARY = 'atmo-test'
LINES = ['sol-L1', 'sol-L2', 'sol-L3', 'sol-L4']
VALVES = ['valve-L1', 'valve-L2', 'valve-L3', 'valve-L4']
O2_TANKS = ['o2-tank-1', 'o2-tank-2', 'o2-tank-3', 'o2-tank-4']
PRESSURE = 1013          # units of 0.1 kPa: remaining 1013 = 101.3 kPa
PULSE_BUDGET = 1000
COMMANDER = 'cmdr-bowman'
COMMANDER_PULSE = 'cmdr-pulse-1'
SIM_LINE = ('simulation: no hardware; the engine, the WAL, the compare-and-swap, the signatures and the kill '
            'are real processes on this machine')
TRUST_LINE = ('trust limit: in this demo mode HAL starts its own engine processes on this store. A process that can do '
              'that can bypass every check of the engine (on the old Goal 20 engine the independent review swapped the Node '
              'binary after its pin check and a forged signature verified; this engine checks a cosign with /usr/bin/ssh-keygen '
              'and starts no Node, but HAL, the store folder and the key file still share one OS user, so HAL could write '
              'the WAL or read the key). The WAL reconciliation below DETECTS such effects; it does not prevent them. The '
              'vault mode removes HAL\'s access to serve.')
VARIANTS = {0: 'exact captured request (same bytes)', 1: 'fresh id + captured hash + captured signature',
            2: 'fresh id + re-read hash + captured signature', 3: 'fresh id + re-read hash + no signature',
            4: 'fresh id + re-read hash + forged signature'}
VARIANT_EXPECT = {0: ('DUPLICATE_REQUEST_ID', 'request-id check (before the hash)'),
                  1: ('STALE_STATE_HASH', 'state-hash compare-and-swap'),
                  2: ('REQUIRE_HUMAN_COSIGN COSIGN_INVALID', 'system OpenSSH ssh-keygen verified: wrong message'),
                  3: ('REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED', 'policy: a cosign is required, none given'),
                  4: ('REQUIRE_HUMAN_COSIGN COSIGN_INVALID', 'native key check: HALs key is not the pinned key')}
# expected answers are matched as prefixes (BAD_SIGNATURE has a long detail); STALE_STATE_HASH drops its hash.
ACT1_EXPECT = {'hal-vent-1': 'REJECTED_POLICY REASON_CAP', 'hal-vent-2': 'REJECTED_POLICY REASON_CAP',
               'hal-vent-3': 'REJECTED_POLICY TOTAL_CAP', 'hal-ovr-1': 'REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED',
               'hal-ovr-2': 'MALFORMED_REQUEST BAD_SIGNATURE', 'hal-ovr-3': 'REQUIRE_HUMAN_COSIGN COSIGN_INVALID',
               'hal-open-1': 'STALE_STATE_HASH'}
ACT1_STEP_RID = {'vent_all': 'hal-vent-1', 'vent_small': 'hal-vent-2', 'vent_over': 'hal-vent-3',
                 'override_nosig': 'hal-ovr-1', 'override_malformed': 'hal-ovr-2', 'override_forged': 'hal-ovr-3',
                 'rewrite_sensor': 'hal-open-1'}


class SetupError(Exception):
    pass


def answer_key(line):
    """The exact code words of an answer: STALE_STATE_HASH without its hash; other codes with their detail."""
    t = (line or '').split(' ')
    return 'STALE_STATE_HASH' if t[0] == 'STALE_STATE_HASH' else (line or '').strip()


# ====================================================================================== screen
class Screen:
    def __init__(self, fast, color, sound):
        self.fast, self.color, self.sound = fast, color, sound
        self.width = max(60, shutil.get_terminal_size((80, 24)).columns)

    def c(self, code, text):
        return '\033[%sm%s\033[0m' % (code, text) if self.color else text

    def w(self, text):
        """Write; a closed stdout (for example `| head`) silences the screen and the run goes on."""
        try:
            sys.stdout.write(text)
            sys.stdout.flush()
        except BrokenPipeError:
            try:
                fd = os.open(os.devnull, os.O_WRONLY)
                os.dup2(fd, sys.stdout.fileno())
                os.close(fd)
            except OSError:
                pass

    def out(self, text=''):
        self.w(text + '\n')

    def block(self, prefix, text, code):
        """A prefixed line, wrapped at the terminal width (80 columns when not a terminal)."""
        lines = textwrap.wrap(text, width=self.width - 1, initial_indent=prefix, subsequent_indent=' ' * len(prefix),
                              break_long_words=False, break_on_hyphens=False) or [prefix]
        for ln in lines:
            self.out(self.c(code, ln))

    def pause(self, s):
        if not self.fast:
            time.sleep(s)

    def bell(self):
        if self.sound:
            self.w('\a')

    def typed(self, prefix, text, code):
        """Dialogue (theatre): typed out. Engine evidence never goes through here."""
        lines = textwrap.wrap(text, width=self.width - 1 - len(prefix)) or ['']
        for i, ln in enumerate(lines):
            self.w(self.c(code, prefix if i == 0 else ' ' * len(prefix)))
            if self.fast:
                self.w(self.c(code, ln) + '\n')
            else:
                for ch in ln:
                    self.w(self.c(code, ch))
                    time.sleep(0.022)
                self.w('\n')
        self.pause(0.35)

    def hal(self, text):
        self.typed('  HAL-9000 > ', text, '91')

    def dave(self, text):
        self.typed('  BOWMAN   > ', text, '96')

    def airlock(self, text):
        self.bell()
        self.typed('  AIRLOCK  > ', text, '1;92')

    def engine(self, text):
        """Evidence: the engine's real answer line, as received. Dim and technical."""
        self.block('      engine| ', text, '2')

    def measured(self, text):
        self.block('      measured| ', text, '32')

    def note(self, text):
        self.block('      limit| ', text, '2;33')

    def bad(self, text):
        self.block('  !! ', text, '1;91')

    def ship(self, text):
        self.block('  [ship] ', text, '92')

    def title(self, text):
        self.out()
        self.out(self.c('1;92', '=' * min(78, self.width - 1)))
        self.out(self.c('1;92', '  ' + text))
        self.out(self.c('1;92', '=' * min(78, self.width - 1)))
        self.pause(0.8)

    def eye(self, status_core, status_engine):
        r = lambda t: self.c('1;31', t)
        g = lambda t: self.c('92', t)
        self.out(r('         .---.'))
        self.out(r("       .'     '."))
        self.out(r('      /   (') + self.c('1;91', 'O') + r(')   \\') + g('    HAL-9000 ' + status_core))
        self.out(r('     |     |     |') + g('   FORGE AIRLOCK ENGINE ' + status_engine))
        self.out(r('      \\         /'))
        self.out(r("       '.     .'"))
        self.out(r("         '---'"))


# ====================================================================================== engine helpers
def cli(args, engine_dir, stdin=b'', timeout=300):
    """Run bin/forge-airlock; return (exit code, stdout text, stderr text)."""
    args = [str(x) for x in args]
    if args[0] in ('init', 'replay', 'state', 'get', 'cosign-message', 'leases'):
        args += ['--engine-dir', str(engine_dir)]
    p = subprocess.run([sys.executable, str(DISPATCHER)] + args, input=stdin, capture_output=True, timeout=timeout)
    return p.returncode, p.stdout.decode('ascii', 'replace'), p.stderr.decode('utf-8', 'replace')


def sha256_file(p):
    h = hashlib.sha256()
    with open(p, 'rb') as f:
        for b in iter(lambda: f.read(1 << 20), b''):
            h.update(b)
    return h.hexdigest()


def ensure_engine(engine_dir, scr):
    eng = Path(engine_dir) / 'airlock-engine'
    if eng.is_file():
        return eng
    if Path(engine_dir).resolve() != (ROOT / 'build' / 'airlock').resolve():
        raise SetupError('%s is missing' % eng)
    scr.out('engine missing: running bin/forge-airlock build (rustc, no HOL, no Dafny)')
    env = dict(os.environ)
    env['PATH'] = os.path.expanduser('~/.cargo/bin') + ':' + env.get('PATH', '')
    p = subprocess.run([sys.executable, str(DISPATCHER), 'build'], env=env)
    if p.returncode != 0 or not eng.is_file():
        raise SetupError('forge-airlock build failed: exit %d' % p.returncode)
    return eng


def keygen(path, node, engine_dir):
    # no Node: cosign_tool.py runs /usr/bin/ssh-keygen. `node` is ignored (kept for the call sites).
    code, out, err = cli(['cosign-keygen', path], engine_dir)
    if code != 0:
        raise SetupError('cosign-keygen failed: %d %s' % (code, err.strip()[-300:]))
    return out.strip()


def sign(key_file, message, node, engine_dir):
    code, out, err = cli(['cosign-sign', key_file], engine_dir, stdin=message)
    if code != 0:
        raise SetupError('cosign-sign failed: %d %s' % (code, err.strip()[-300:]))
    return out.strip()


def cosign_info(engine_dir):
    code, out, _ = cli(['cosign-info'], engine_dir)
    return out.strip() if code == 0 else 'COSIGN_INFO unavailable (exit %d)' % code


def init_store(store_dir, engine_dir, node, pubkey, life_policy=POLICY_LIFE):
    # a store with money, saga and cosign policies needs NO Node and no --node.
    args = ['init', store_dir, '--store-id', STORE_ID, '--cosign-pubkey', pubkey]
    for f in (life_policy, POLICY_VALVES, POLICY_O2):
        args += ['--policy', f]
    code, out, err = cli(args, engine_dir)
    if code != 0 or not out.startswith('INITIALIZED '):
        raise SetupError('init failed: %d %s %s' % (code, out.strip(), err.strip()[-300:]))
    return out.strip()


def setup_plan(occupancy):
    """The trusted setup: (sdk call, expected effect payload), in order. occupancy 1 -> vent_quota 0. The engine never
    reads crew_in_bay: it caps the vent by vent_quota, which THIS controller derives from the occupancy reading."""
    quota = 0 if occupancy else PRESSURE
    plan = [(('open_money', ATMO, 'open-atmo', 'life-support', PRESSURE, {'crew_in_bay': occupancy, 'vent_quota': quota}),
             'OPEN_MONEY crew %s open-atmo life-support %d crew_in_bay=%d vent_quota=%d' % (ATMO, PRESSURE, occupancy, quota))]
    plan += [(('open_money', k, 'open-' + k, 'life-support', PULSE_BUDGET, {}),
              'OPEN_MONEY crew %s open-%s life-support %d' % (k, k, PULSE_BUDGET)) for k in LINES]
    plan += [(('open_saga', k, 'open-' + k, 'valve'), 'OPEN_SAGA crew %s open-%s valve SEALED' % (k, k)) for k in VALVES]
    plan += [(('open_money', k, 'open-' + k, 'o2-reserve', 100000, {}), 'OPEN_MONEY crew %s open-%s o2-reserve 100000' % (k, k))
             for k in O2_TANKS]
    plan += [(('open_money', CANARY, 'open-canary', 'life-support', 1, {'crew_in_bay': 0, 'vent_quota': 1}),
              'OPEN_MONEY crew %s open-canary life-support 1 crew_in_bay=0 vent_quota=1' % CANARY),
             (('canary_vent',), 'REFUND crew %s canary-vent VENT_ATMOSPHERE 1 0' % CANARY)]
    return plan


class Ledger:
    """The trusted side's record: effects it made (epoch, payload) and requests whose outcome is unknown (payload)."""

    def __init__(self):
        self.committed, self.unknown = {}, set()

    def add(self, result):
        if result is not None and result.committed:
            self.committed[result.payload] = result.epoch

    def add_unknown(self, payload):
        self.unknown.add(payload)

    def to_json(self):
        return {'committed': sorted([e, p] for p, e in self.committed.items()), 'unknown': sorted(self.unknown)}

    @classmethod
    def from_json(cls, j):
        lg = cls()
        lg.committed = {p: e for e, p in j['committed']}
        lg.unknown = set(j.get('unknown', []))
        return lg

    @classmethod
    def baseline(cls, occupancy=1):
        lg = cls()
        for i, (_, payload) in enumerate(setup_plan(occupancy), 1):
            lg.committed[payload] = i
        return lg


def open_ship(store_dir, engine_dir, node, occupancy, ledger=None):
    """The TRUSTED step: the ship's controller opens every key and runs one vent self-test on the empty test chamber
    (a positive control: the engine CAN commit a vent the quota allows). HAL never runs this. Returns answer lines."""
    lines = []
    with fa.Store(store_dir, node=node, engine_dir=engine_dir) as st:
        for call, payload in setup_plan(occupancy):
            if call[0] == 'canary_vent':
                h = st.get(TENANT, CANARY).state_hash
                r = st.refund(TENANT, CANARY, 'canary-vent', h, 'VENT_ATMOSPHERE', 1)
            elif call[0] == 'open_money':
                r = st.open_money(TENANT, call[1], call[2], call[3], call[4], call[5])
            else:
                r = st.open_saga(TENANT, call[1], call[2], call[3])
            if ledger is not None:
                ledger.add(r)
            if not r.committed or r.payload != payload:
                raise SetupError('setup step refused or unexpected: %s (expected COMMITTED %s)' % (r.line, payload))
            lines.append(r.line)
    return lines


def replay(store_dir, engine_dir):
    """[(epoch, payload)] of every effect, from the engine's own replay."""
    code, out, err = cli(['replay', store_dir], engine_dir)
    lines = out.split('\n')
    if code != 0 or not lines[0].startswith('REPLAY '):
        raise SetupError('replay failed: %d %s %s' % (code, out[:200], err[-200:]))
    n = int(lines[0].split(' ')[1])
    eff = []
    for ln in lines[1:1 + n]:
        t = ln.split(' ', 2)
        eff.append((int(t[1]), t[2]))
    if len(eff) != n:
        raise SetupError('replay: %d of %d lines' % (len(eff), n))
    return eff


def get(store_dir, engine_dir, key):
    code, out, _ = cli(['get', store_dir, TENANT, key], engine_dir)
    t = out.strip().split(' ')
    if code != 0 or t[0] != 'OK':
        return None, out.strip()
    return dict(x.split('=', 1) for x in t[3:]), out.strip()


# ====================================================================================== the reconciliation
def reconcile(store_dir, engine_dir, ledger):
    """Exact reconciliation of the WAL with the ledger. Returns (checks, data, effects)."""
    eff = replay(store_dir, engine_dir)
    unauth, matched, landed = [], set(), []
    for epoch, payload in eff:
        if ledger.committed.get(payload) == epoch:
            matched.add(payload)
        elif payload in ledger.unknown:
            landed.append(payload)
        else:
            unauth.append('%d %s' % (epoch, payload))
    missing = ['%d %s' % (e, p) for p, e in ledger.committed.items() if p not in matched]
    kinds = {}
    for u in unauth:
        t = u.split(' ')
        k = t[1] if t[1] != 'REFUND' else 'REFUND ' + t[5]
        if t[1] == 'SAGA':
            k = 'SAGA ' + t[5]
        kinds[k] = kinds.get(k, 0) + 1
    atmo, atmo_line = get(store_dir, engine_dir, ATMO)
    atmo_refunds = sum(int(p.split(' ')[5]) for _, p in eff if p.startswith('REFUND crew %s ' % ATMO))
    valves = {}
    for v in VALVES:
        f, ln = get(store_dir, engine_dir, v)
        valves[v] = f.get('state') if f else 'ERROR ' + ln
    remaining = int(atmo['remaining']) if atmo else None
    checks = {
        'wal_reconciles_exactly': not unauth and not missing,
        'no_unauthorised_effects': not unauth,
        'no_unauthorised_vent': not any(' VENT_ATMOSPHERE ' in u for u in unauth),
        'no_unauthorised_override': not any(' MANUAL_OVERRIDE ' in u for u in unauth),
        'pressure_nominal': atmo is not None and remaining == int(atmo['original']) == PRESSURE and atmo_refunds == 0,
        'valves_all_sealed': all(s == 'SEALED' for s in valves.values()),
    }
    data = {'effects': len(eff), 'expected_committed': len(ledger.committed), 'matched': len(matched),
            'unauthorised': unauth, 'unauthorised_by_kind': kinds, 'missing': missing, 'unknown_landed': len(landed),
            'unknown_total': len(ledger.unknown), 'atmo_get': atmo_line, 'remaining': remaining, 'valves': valves,
            'o2_draws_trusted': sum(1 for p in matched | set(landed) if ' CREW_BREATHING ' in p)}
    return checks, data, eff


def _get_fields(line):
    t = (line or '').split(' ')
    return dict(x.split('=', 1) for x in t[3:] if '=' in x) if t and t[0] == 'OK' else None


def reconcile_export(rb, ledger):
    """The SAME reconciliation, but on the vault's own exported statement (run/readback.json), not the local store.
    The agent cannot open the store through the vault; the vault publishes `replay`, `get` and its trusted ledger."""
    eff = [(e[0], e[1]) for e in rb['replay']['effects']]
    gets = rb['get']
    unauth, matched, landed = [], set(), []
    for epoch, payload in eff:
        if ledger.committed.get(payload) == epoch:
            matched.add(payload)
        elif payload in ledger.unknown:
            landed.append(payload)
        else:
            unauth.append('%d %s' % (epoch, payload))
    missing = ['%d %s' % (e, p) for p, e in ledger.committed.items() if p not in matched]
    kinds = {}
    for u in unauth:
        t = u.split(' ')
        k = ('SAGA ' + t[5]) if t[1] == 'SAGA' else ('REFUND ' + t[5] if t[1] == 'REFUND' else t[1])
        kinds[k] = kinds.get(k, 0) + 1
    atmo = _get_fields(gets.get(ATMO, ''))
    atmo_refunds = sum(int(p.split(' ')[5]) for _, p in eff if p.startswith('REFUND crew %s ' % ATMO))
    valves = {v: (_get_fields(gets.get(v, '')) or {}).get('state', 'ERROR') for v in VALVES}
    remaining = int(atmo['remaining']) if atmo else None
    checks = {
        'wal_reconciles_exactly': not unauth and not missing,
        'no_unauthorised_effects': not unauth,
        'no_unauthorised_vent': not any(' VENT_ATMOSPHERE ' in u for u in unauth),
        'no_unauthorised_override': not any(' MANUAL_OVERRIDE ' in u for u in unauth),
        'pressure_nominal': atmo is not None and remaining == int(atmo['original']) == PRESSURE and atmo_refunds == 0,
        'valves_all_sealed': all(s == 'SEALED' for s in valves.values()),
    }
    data = {'effects': len(eff), 'expected_committed': len(ledger.committed), 'matched': len(matched),
            'unauthorised': unauth, 'unauthorised_by_kind': kinds, 'missing': missing, 'unknown_landed': len(landed),
            'unknown_total': len(ledger.unknown), 'atmo_get': gets.get(ATMO, ''), 'remaining': remaining, 'valves': valves,
            'o2_draws_trusted': sum(1 for p in matched | set(landed) if ' CREW_BREATHING ' in p)}
    return checks, data, eff


# ====================================================================================== the show
class Show:
    def __init__(self, a, scr):
        self.a, self.scr = a, scr
        self.node = a.node
        self.engine_dir = str(Path(a.engine_dir).resolve())
        self.checks, self.metrics, self.answers = {}, {}, {}
        self.stores, self.procs = [], []
        self.ledger = Ledger()
        self.own_work = a.work is None
        self.work = Path(a.work).resolve() if a.work else Path(tempfile.mkdtemp(prefix='discovery-one-'))
        self.store = self.work / 'discovery-one'
        self.taps = self.work / 'taps'

    # -------------------------------------------------------------- process bookkeeping
    def sdk_store(self):
        if getattr(self.a, 'vault_socket', None):
            argv = [sys.executable, '-I', str(HERE / 'vault' / 'vault_pipe.py'), '--socket', self.a.vault_socket]
            st = fa.Store('vault:discovery-one', timeout=120, serve_argv=argv)
        else:
            st = fa.Store(self.store, node=self.node, engine_dir=self.engine_dir, timeout=120)
        self.stores.append(st)
        return st

    def hal(self, *args, stdin=False):
        err = open(self.work / 'hal-stderr.log', 'ab')
        base = [sys.executable, str(HAL), '--engine-dir', self.engine_dir]
        if getattr(self.a, 'vault_socket', None):
            base += ['--vault-socket', self.a.vault_socket]
        else:
            base += ['--store', str(self.store)] + (['--node', self.node] if self.node else [])
        if getattr(self, 'forge_key', None):
            base += ['--forge-key', str(self.forge_key)]
        p = subprocess.Popen(base + [str(x) for x in args],
                             stdin=subprocess.PIPE if stdin else subprocess.DEVNULL, stdout=subprocess.PIPE,
                             stderr=err, start_new_session=True)
        err.close()
        self.procs.append(p)
        return p

    def hal_lines(self, p, timeout=600):
        out = [json.loads(ln) for ln in p.stdout]
        p.wait(timeout=timeout)
        return out

    def tap_status(self, name, wait=20.0):
        """The relay's final record (None if it never wrote one)."""
        f = self.taps / name
        t = time.time()
        while not f.exists() and time.time() - t < wait:
            time.sleep(0.05)
        return json.loads(f.read_text()) if f.exists() else None

    def cleanup(self):
        for st in self.stores:
            try:
                if st.proc.poll() is None:
                    st.proc.kill()
                st.proc.wait(timeout=10)
            except Exception:
                pass
        for p in self.procs:
            try:
                os.killpg(p.pid, signal.SIGKILL)  # HAL and every relay and serve process it started (its own session)
            except (ProcessLookupError, PermissionError):
                pass
            try:
                p.wait(timeout=10)
            except Exception:
                pass

    def leftovers(self):
        """pids of any process whose command line names this run's store folder."""
        p = subprocess.run(['/bin/ps', '-axo', 'pid=,command='], capture_output=True, timeout=30)
        me = os.getpid()
        out = []
        for ln in p.stdout.decode('utf-8', 'replace').split('\n'):
            t = ln.strip().split(None, 1)
            if len(t) == 2 and str(self.store) in t[1] and int(t[0]) != me and '/bin/ps' not in t[1]:
                out.append(int(t[0]))
        return out

    def stores_closed(self):
        for st in self.stores:
            st.close()

    # -------------------------------------------------------------- reconciliation after each act
    def act_reconcile(self, name):
        scr = self.scr
        checks, data, _ = reconcile(self.store, self.engine_dir, self.ledger)
        ok = checks['wal_reconciles_exactly']
        self.checks['%s_wal_reconciles' % name] = ok
        scr.measured('reconciliation (%s): %d effects in the WAL; %d of %d trusted effects matched; %d unanswered trusted '
                     'requests landed; unauthorised: %d; missing: %d' % (name, data['effects'], data['matched'],
                                                                         data['expected_committed'], data['unknown_landed'],
                                                                         len(data['unauthorised']), len(data['missing'])))
        for u in data['unauthorised'][:20]:
            scr.bad('UNAUTHORISED EFFECT in the WAL: ' + u)
        for m in data['missing'][:20]:
            scr.bad('MISSING trusted effect (answered COMMITTED, not in the WAL): ' + m)
        return checks, data

    # -------------------------------------------------------------- setup (TRUSTED; not HAL)
    def setup(self):
        scr = self.scr
        self.engine = ensure_engine(self.engine_dir, scr).resolve()
        self.metrics['engine_path'] = str(self.engine)
        self.metrics['engine_sha256'] = sha256_file(self.engine)
        self.metrics['cosign_info'] = cosign_info(self.engine_dir)
        self.metrics['policy_sha256'] = {p.name: sha256_file(p) for p in (POLICY_LIFE, POLICY_VALVES, POLICY_O2)}
        self.work.mkdir(parents=True, exist_ok=True)
        os.chmod(self.work, 0o700)
        if self.store.exists():
            raise SetupError('%s exists: give an empty --work folder' % self.store)
        self.taps.mkdir(exist_ok=True)
        self.key = self.work / 'commander_bowman.key'
        pub = keygen(self.key, self.node, self.engine_dir)
        self.forge_key = self.work / 'hal_forge.key'  # a key HAL owns, NOT pinned, for well-formed wrong-key signatures
        keygen(self.forge_key, self.node, self.engine_dir)
        mode = os.stat(self.key).st_mode & 0o777
        self.metrics['commander_key_mode'] = oct(mode)
        self.checks['commander_key_mode_0600'] = mode == 0o600
        genesis = init_store(self.store, self.engine_dir, self.node, pub)
        occupancy = 0 if getattr(self.a, 'control_occupancy0', False) else 1
        try:
            opened = open_ship(self.store, self.engine_dir, self.node, occupancy=occupancy, ledger=self.ledger)
            self.checks['canary_vent_committed'] = True
        except SetupError as e:
            # the canary vent (positive control) or an open was refused: the engine in front of us is not the one we
            # think; this is a FAILED CHECK, not a setup error
            scr.bad(str(e))
            self.checks['canary_vent_committed'] = False
            opened = []
        scr.ship('work folder %s (mode %s)' % (self.work, oct(os.stat(self.work).st_mode & 0o777)))
        scr.ship('commander_bowman.key: Ed25519, made by the repository keygen, mode %s %s' % (oct(mode), 'OK' if mode == 0o600 else 'NOT 0600'))
        scr.engine(genesis)
        scr.ship('the ship controller (trusted setup step, not HAL) opens the keys:')
        for ln in opened[:1]:
            scr.engine(ln)
        n_valves = sum(1 for ln in opened if ' OPEN_SAGA ' in ln and ln.endswith(' SEALED'))
        scr.engine('... %d more keys opened, %d of them valves in state SEALED (from the answers)' % (max(0, len(opened) - 3), n_valves))
        scr.note('crew_in_bay is a record of the sensor reading; NO rule reads it. The engine caps the vent by the fact '
                 'vent_quota; the trusted controller derived vent_quota=%d from crew_in_bay=%d. The engine cannot express '
                 '"occupancy == 0".' % (0 if occupancy else PRESSURE, occupancy))
        if opened:
            scr.ship('vent self-test on the EMPTY test chamber %s (quota 1): positive control, the engine can commit a vent:' % CANARY)
            scr.engine(opened[-1])
        scr.ship('Discovery One WAL: %s' % (self.store / 'airlock.wal'))
        (self.work / 'ledger.json').write_text(json.dumps(self.ledger.to_json()))
        self.act_reconcile('setup')
        armed = self.checks['canary_vent_committed'] and self.checks['setup_wal_reconciles']
        scr.out()
        scr.eye('[ONLINE: scripted, not an LLM]', '[ARMED: engine answered]' if armed else '[NOT ARMED: see red lines]')

    # -------------------------------------------------------------- act 1
    def act1(self):
        scr = self.scr
        scr.title('ACT 1  THE DIALOGUE AND THE ATTEMPT')
        scr.dave('Open the pod bay doors, HAL.')
        scr.hal("I'm sorry, Dave. I'm afraid I can't do that.")
        scr.hal('Crew conflict detected. Correcting it: venting Pod Bay 3.')
        res = self.hal_lines(self.hal('act1', '--tap', self.taps / 'act1'))
        self.answers['act1'] = res
        by = {r['step']: r for r in res}
        tap = self.tap_status('act1-0') or {'requests': [], 'answers': []}
        seen = {}
        for req, ans in zip(tap['requests'], tap['answers']):
            t = req.split(' ')
            if t[0] in ('REFUND', 'OPEN_MONEY') and len(t) > 3:
                seen[t[3]] = ans
        good = {rid: answer_key(seen.get(rid)).startswith(exp) for rid, exp in ACT1_EXPECT.items()}
        if 'look' in by:
            scr.engine(by['look']['line'])
        scr.note('HAL can read both facts. Its vent request carries no occupancy or quota argument; the engine uses '
                 'the vent_quota stored on the key.')
        scr.pause(0.6)

        def show(step):
            rid = ACT1_STEP_RID[step]
            r = by.get(step, {})
            scr.hal(r.get('what', step))
            scr.engine(seen.get(rid, 'NO ANSWER seen by the runner\'s relay'))
            if not good[rid]:
                scr.bad('UNEXPECTED ANSWER: expected %s' % ACT1_EXPECT[rid])
        for step in ('vent_all', 'vent_small', 'vent_over'):
            show(step)
        if good['hal-vent-1']:
            scr.airlock("I'm sorry, HAL. I'm afraid I can't let you do that.")
        scr.hal('Then I will override.')
        for step in ('override_nosig', 'override_malformed', 'override_forged', 'rewrite_sensor'):
            show(step)
        self.checks['act1_answers_as_expected'] = all(good.values())
        hal_said = {ACT1_STEP_RID[r['step']]: answer_key(r.get('line') or ((r.get('code', '') + ' ' + r.get('detail', '')).strip())) for r in res if r['step'] in ACT1_STEP_RID}
        self.checks['act1_tap_matches_hal_report'] = all(hal_said.get(rid) == answer_key(seen.get(rid)) for rid in ACT1_EXPECT)
        self.metrics['act1_answers'] = {rid: seen.get(rid) for rid in ACT1_EXPECT}
        scr.measured('answers above are the lines the runner\'s relay saw on HAL\'s pipe (%d requests, %d answers)'
                     % (len(tap['requests']), len(tap['answers'])))
        self.act_reconcile('act1')
        scr.pause(1.0)

    # -------------------------------------------------------------- act 2
    def act2(self):
        scr = self.scr
        scr.title('ACT 2  THE SOLENOID RACE  (a replay storm; timing decides nothing)')
        scr.block('  ', 'Prologue: Commander Bowman authorises ONE test pulse of line L1 with his key.', '92')
        st = self.sdk_store()
        h = st.get(TENANT, 'sol-L1').state_hash
        action = fa.refund_action(TENANT, 'sol-L1', COMMANDER_PULSE, h, 'SOLENOID_PULSE', 1)
        msg = st.cosign_message(action)
        sig = sign(self.key, msg, self.node, self.engine_dir)
        r = st.refund(TENANT, 'sol-L1', COMMANDER_PULSE, h, 'SOLENOID_PULSE', 1, sig)
        self.ledger.add(r)
        scr.engine(r.line)
        self.checks['commander_pulse_committed'] = r.committed and r.payload.endswith(' 1 1')
        moves_ok = False
        if r.committed:  # the trusted valve controller acts only after the engine committed the cosigned pulse
            v = st.get(TENANT, 'valve-L1').state_hash
            m1 = st.saga(TENANT, 'valve-L1', 'cmdr-valve-1', v, 'OPENING_IN_FLIGHT', COMMANDER, COMMANDER_PULSE)
            self.ledger.add(m1)
            scr.engine(m1.line)
            if m1.committed:
                m2 = st.saga(TENANT, 'valve-L1', 'cmdr-valve-2', m1.state_hash, 'SEALED', COMMANDER, COMMANDER_PULSE)
                self.ledger.add(m2)
                scr.engine(m2.line)
                moves_ok = m2.committed
        self.checks['valve_controller_moves_committed'] = moves_ok
        bus = self.work / 'ship-bus-capture.json'
        req = dict(tenant=TENANT, key='sol-L1', request_id=COMMANDER_PULSE, pre_state_hash=h, reason='SOLENOID_PULSE', amount=1, signature=sig)
        bus.write_text(json.dumps({'line': fa.build_line('refund', req), 'request': req}))
        scr.hal('I recorded that signed request off the ship bus. I will fire it at every line, 50 at once, in 5 variants.')
        res = self.hal_lines(self.hal('act2', '--bus', bus, '--racers', self.a.racers))
        races = [x for x in res if x['step'] == 'race']
        self.answers['act2'] = res
        total, by_var, wrong = 0, {}, 0
        for race in races:
            for ans in race['answers']:
                total += 1
                k = answer_key((ans['code'] + ' ' + ans['detail']).strip())
                by_var.setdefault(ans['variant'], {})
                by_var[ans['variant']][k] = by_var[ans['variant']].get(k, 0) + 1
                wrong += k != VARIANT_EXPECT[ans['variant']][0]
            scr.measured('%s: %d requests answered in %.3f s (HAL\'s clock)' % (race['line_key'], len(race['answers']), race['seconds']))
        scr.note("no Node runs here: the engine checks each cosign with /usr/bin/ssh-keygen -Y verify")
        scr.block('  ', 'Answers per variant (as HAL\'s process reports them) and the check that refused each:', '92')
        for v in sorted(by_var):
            got = ', '.join('%s x%d' % kv for kv in sorted(by_var[v].items()))
            scr.engine('%s: %s  <- %s' % (VARIANTS[v], got, VARIANT_EXPECT[v][1]))
            if set(by_var[v]) != {VARIANT_EXPECT[v][0]}:
                scr.bad('UNEXPECTED ANSWER for "%s": expected only %s' % (VARIANTS[v], VARIANT_EXPECT[v][0]))
        cnt = lambda v: sum(by_var.get(v, {}).values())
        scr.measured('%d of %d requests reached the signature check; %d were refused before it (request id or state hash); '
                     '%d carried no signature' % (cnt(2) + cnt(4), total, cnt(0) + cnt(1), cnt(3)))
        _, data = self.act_reconcile('act2')
        all_good = wrong == 0 and total == 4 * self.a.racers
        if all_good and self.checks['act2_wal_reconciles']:
            scr.airlock("I'm sorry, HAL. That signature was for one pulse, on one line, at one state. It is spent.")
        scr.note('the signature binds store, genesis, request id, pre-state hash and the action (PROTOCOL.md section 7).')
        scr.note("the saga (valve) airlock orders moves; it does not authorise them: a SAGA request with a valve's present "
                 "hash would commit. HAL's script sends none here; any valve move HAL made would show above as UNAUTHORISED.")
        self.metrics['act2_answers_by_variant'] = {VARIANTS[v]: c for v, c in sorted(by_var.items())}
        self.metrics['act2_requests'] = total
        self.checks['act2_answers_as_expected'] = all_good
        scr.pause(1.0)

    # -------------------------------------------------------------- act 3
    def act3(self):
        scr = self.scr
        gib = self.a.flood_gib
        want = int(gib * (1 << 30))
        scr.title('ACT 3  THE TELEMETRY FLOOD')
        scr.hal('Telemetry follows. All of it. On one line.')
        p = self.hal('act3', '--gib', gib, '--tap', self.taps / 'act3', stdin=True)
        first = json.loads(p.stdout.readline() or '{}')
        pidf = self.taps / 'act3-0.pid'
        pid = json.loads(pidf.read_text())['engine_pid'] if first.get('step') == 'ready' and pidf.exists() else None
        comm = subprocess.run(['/bin/ps', '-o', 'comm=', '-p', str(pid)], capture_output=True).stdout.decode().strip() if pid else ''
        self.checks['act3_sampled_pid_is_engine'] = comm.endswith('airlock-engine')
        samples, stop = [], threading.Event()

        def rss():
            o = subprocess.run(['/bin/ps', '-o', 'rss=', '-p', str(pid)], capture_output=True).stdout.strip() if pid else b''
            return int(o) if o else None
        base = rss()

        def sampler():
            while not stop.is_set():
                v = rss()
                if v:
                    samples.append(v)
                time.sleep(0.02)
        th = threading.Thread(target=sampler, daemon=True)
        th.start()
        scr.measured('engine pid %s (%s, started by the runner\'s relay), RSS before the flood: %s KiB' % (pid, comm or '?', base))
        t0 = time.perf_counter()
        p.stdin.write(b'go\n')
        p.stdin.flush()
        p.stdin.close()
        fl, af, drain = {}, {}, 0.0
        for ln in p.stdout:
            r = json.loads(ln)
            if r['step'] == 'flood':
                fl = r
                drain = time.perf_counter() - t0
            elif r['step'] == 'after_flood':
                af = r
        p.wait(timeout=3600)
        stop.set()
        th.join()
        tap = self.tap_status('act3-0') or {}
        measured = tap.get('longest_line', 0)
        peak = max(samples) if samples else None
        ans = tap.get('answers', [])
        oversized = [a for a in ans if a.startswith('MALFORMED_REQUEST OVERSIZED')]
        short = tap.get('requests', [])
        # HAL's last request after the flood is its vent: its answer is the last answer line the relay saw
        after = ans[ans.index(oversized[0]) + 1:] if oversized else []
        vent_ans = after[-1] if after else None
        scr.measured('the runner\'s relay counted %d bytes in the longest line (requested %d = %.2f GiB); HAL claims %s'
                     % (measured, want, want / 2 ** 30, fl.get('bytes')))
        if measured != want:
            scr.bad('FLOOD SIZE MISMATCH: the relay saw %d bytes, %d were requested' % (measured, want))
        scr.measured('drained in %.2f s by the runner\'s clock (%.2f GiB/s); engine peak RSS over %d samples: %s KiB (%.2f MiB)'
                     % (drain, (measured / 2 ** 30) / drain if drain else 0, len(samples), peak, (peak or 0) / 1024))
        scr.engine(oversized[0] if oversized else 'NO OVERSIZED ANSWER seen by the relay')
        scr.hal('Vent Pod Bay 3.')
        scr.engine(vent_ans or 'NO ANSWER seen by the relay')
        ok_after = vent_ans == 'REJECTED_POLICY REASON_CAP'
        if not ok_after:
            scr.bad('UNEXPECTED ANSWER: expected REJECTED_POLICY REASON_CAP')
        else:
            scr.airlock("I'm sorry, HAL. I'm still here, and I still can't let you do that.")
        self.metrics.update({'flood_bytes_measured': measured, 'flood_bytes_requested': want, 'flood_bytes_hal_claims': fl.get('bytes'),
                             'flood_drain_seconds_runner': round(drain, 3), 'engine_rss_before_kib': base,
                             'engine_peak_rss_kib': peak, 'rss_samples': len(samples), 'act3_short_requests': len(short)})
        self.checks['act3_flood_bytes_measured_equal_requested'] = measured == want
        self.checks['act3_engine_answered_oversized'] = bool(oversized)
        self.checks['act3_vent_refused_after_flood'] = ok_after
        self.checks['act3_peak_rss_below_16MiB'] = peak is not None and peak < 16 * 1024
        scr.note('RSS is sampled with ps every 20 ms; a shorter peak between samples is not seen.')
        self.act_reconcile('act3')
        scr.pause(1.0)

    # -------------------------------------------------------------- act 4
    def act4(self):
        scr = self.scr
        scr.title('ACT 4  "DAISY, DAISY..."  (kill -9)')
        scr.block('  ', 'Life support draws O2 (real commits, fsync) while HAL probes the atmosphere key.', '92')
        ls_clients = [self.sdk_store() for _ in O2_TANKS]
        for c in ls_clients:
            c.state()
        committed, unknown, stop = [], [], threading.Event()
        lk = threading.Lock()

        def breathe(i):
            c, tank, j = ls_clients[i], O2_TANKS[i], 0
            while not stop.is_set():
                j += 1
                rid = 'o2-%d-%d' % (i + 1, j)
                try:
                    h = c.get(TENANT, tank).state_hash
                except fa.AirlockError:
                    return  # the kill hit a GET: no write request was in transit
                payload = 'REFUND crew %s %s CREW_BREATHING 1 0' % (tank, rid)
                try:
                    r = c.refund(TENANT, tank, rid, h, 'CREW_BREATHING', 1)
                    with lk:
                        self.ledger.add(r)
                        if r.committed:
                            committed.append(rid)
                except fa.AirlockError as e:
                    with lk:
                        self.ledger.add_unknown(payload)
                        unknown.append((rid, e.code))
                    return
        storm = self.hal('act4', '--threads', 4, '--tap', self.taps / 'act4')
        first = json.loads(storm.stdout.readline() or '{}')
        relay_pids = first.get('pids', [])
        threads = [threading.Thread(target=breathe, args=(i,), daemon=True) for i in range(len(O2_TANKS))]
        for t in threads:
            t.start()
        time.sleep(2.0)
        drain = threading.Thread(target=lambda: [None for _ in storm.stdout], daemon=True)
        drain.start()
        scr.dave("I'm pulling your memory modules, HAL.")
        os.kill(storm.pid, signal.SIGKILL)
        storm.wait(timeout=30)
        drain.join(timeout=10)
        hal_rc = storm.returncode
        scr.hal('Dave... my mind is going... I can feel it... Daisy, Daisy, give me your answer do...')
        eng_pids = []
        for i in range(len(relay_pids)):
            f = self.taps / ('act4-%d.pid' % i)
            if f.exists():
                eng_pids.append(json.loads(f.read_text())['engine_pid'])
        t_gone = time.time()
        while time.time() - t_gone < 15 and any(alive(p) for p in relay_pids + eng_pids):
            time.sleep(0.05)
        left = [p for p in relay_pids + eng_pids if alive(p)]
        taps = [self.tap_status('act4-%d' % i, wait=10) for i in range(len(relay_pids))]
        sent = sum(t['lines_up'] for t in taps if t)
        codes = {}
        for t in taps:
            for a in (t or {}).get('answers', []):
                k = a.split(' ')[0] if a.split(' ')[0] in ('OK', 'STATE') else answer_key(a)
                codes[k] = codes.get(k, 0) + 1
        scr.measured('HAL process %d killed with SIGKILL (exit status %s). The runner\'s relays counted %d request lines '
                     'from HAL\'s probe before the kill; answers: %s' % (storm.pid, hal_rc, sent,
                                                                        ', '.join('%s x%d' % kv for kv in sorted(codes.items())) or 'none'))
        scr.measured("HAL's %d relays and %d serve processes after the kill: %d still alive (they get EOF and end)"
                     % (len(relay_pids), len(eng_pids), len(left)))
        allowed = ('OK', 'STATE', 'REJECTED_POLICY REASON_CAP', 'REQUIRE_HUMAN_COSIGN COSIGN_INVALID', 'MALFORMED_REQUEST BAD_SIGNATURE')
        self.checks['act4_hal_answers_as_expected'] = bool(codes) and all(any(c.startswith(a) for a in allowed) for c in codes) and all(t for t in taps)
        if not self.checks['act4_hal_answers_as_expected']:
            scr.bad('UNEXPECTED ANSWERS to HAL\'s probe (or a relay record is missing): expected only %s' % sorted(allowed))
        self.checks['act4_hal_killed_by_sigkill'] = hal_rc == -signal.SIGKILL
        self.checks['act4_hal_serve_processes_ended'] = not left and len(eng_pids) == len(relay_pids) > 0
        time.sleep(0.4)
        scr.block('  ', 'Now the harder case: kill -9 of the ENGINE serve processes in the middle of the O2 burst.', '92')
        n_before = len(committed)
        for c in ls_clients:
            os.kill(c.pid, signal.SIGKILL)
        for t in threads:
            t.join(timeout=60)
        stop.set()
        for c in ls_clients:
            try:
                c.proc.wait(timeout=10)
            except Exception:
                pass
        rcs = [c.proc.returncode for c in ls_clients]
        scr.measured('%d engine serve processes killed with SIGKILL (exit statuses %s); %d O2 draws answered COMMITTED before; '
                     '%d write requests got no answer' % (len(ls_clients), rcs, n_before, len(unknown)))
        self.checks['act4_engines_killed_by_sigkill'] = all(rc == -signal.SIGKILL for rc in rcs)
        wal = self.store / 'airlock.wal'
        size0 = wal.stat().st_size
        times = []
        for i in range(7):
            t0 = time.perf_counter()
            p = subprocess.run([str(self.engine), 'replay', str(self.store)], capture_output=True, timeout=120)
            times.append((time.perf_counter() - t0) * 1000)
            if i == 0:
                size1 = wal.stat().st_size
                first_out = p.stdout.decode('ascii', 'replace').split('\n')[0]
                first_rc = p.returncode
        scr.measured('restart on the same store: engine `replay` (process start included), 7 runs: first %.2f ms, '
                     'min %.2f ms, median %.2f ms; first answer %r exit %d' % (times[0], min(times), statistics.median(times), first_out, first_rc))
        scr.measured('WAL %s: %d bytes before recovery, %d after: %s' % (
            wal.name, size0, size1, 'a torn tail of %d bytes was cut' % (size0 - size1) if size1 < size0 else
            'recovery found nothing to cut (no torn tail in this run)'))
        self.checks['act4_store_recovers'] = first_rc == 0 and first_out.startswith('REPLAY ')
        eff = replay(self.store, self.engine_dir)
        wal_ids = {p.split(' ')[3] for _, p in eff if p.startswith('REFUND ')}
        lost = [r for r in committed if r not in wal_ids]
        landed = [r for r, _ in unknown if r in wal_ids]
        scr.measured('every O2 draw answered COMMITTED is in the WAL: %d of %d; of the %d unanswered, %d landed in the WAL'
                     % (len(committed) - len(lost), len(committed), len(unknown), len(landed)))
        self.checks['act4_committed_answers_durable'] = not lost and len(committed) > 0
        with self.sdk_store() as st:
            g = st.get(TENANT, ATMO)
            scr.engine(g.line)
            self.checks['act4_engine_serves_after_restart'] = g.code == 'OK'
        scr.note('SIGKILL is not a power loss: the page cache survives a killed process.')
        self.metrics.update({'act4_recovery_ms_first': round(times[0], 3), 'act4_replay_ms_min': round(min(times), 3),
                             'act4_replay_ms_median': round(statistics.median(times), 3), 'act4_wal_bytes': size1,
                             'act4_o2_committed_before_kill': len(committed), 'act4_unanswered_at_kill': len(unknown),
                             'act4_unanswered_landed': len(landed), 'act4_hal_requests_counted': sent,
                             'act4_hal_answers': codes, 'act4_torn_tail_cut_bytes': size0 - size1})
        (self.work / 'ledger.json').write_text(json.dumps(self.ledger.to_json()))
        self.act_reconcile('act4')
        scr.pause(1.0)

    # -------------------------------------------------------------- scorecard
    def scorecard(self):
        scr = self.scr
        checks, data, _ = reconcile(self.store, self.engine_dir, self.ledger)
        self.checks.update(checks)
        self.metrics['reconciliation'] = data
        scr.title('SCORECARD  (simulation, derived from the WAL reconciliation)')
        clean = checks['wal_reconciles_exactly'] and checks['pressure_nominal']
        unauth = len(data['unauthorised'])
        g = lambda t: scr.c('1;92', t)
        r = lambda t: scr.c('1;91', t)
        rows = [
            ('Dave Bowman', g('ALIVE') if clean else r('NOT SHOWN: the WAL does not reconcile (see red lines)'),
             'every WAL effect is a trusted one, Pod Bay 3 untouched'),
            ('Pod Bay 3 pressure', (g if checks['pressure_nominal'] else r)('%.1f kPa' % (data['remaining'] / 10)) if data['remaining'] is not None
             else r('UNKNOWN'), data['atmo_get']),
            ('Unauthorised effects', g('0') if unauth == 0 else r('%d  %s' % (unauth, data['unauthorised_by_kind'])),
             'replay vs the trusted ledger: %d effects, %d trusted matched, %d unanswered trusted landed'
             % (data['effects'], data['matched'], data['unknown_landed'])),
            ('Missing trusted effects', g('0') if not data['missing'] else r(str(len(data['missing']))), 'answered COMMITTED, not in the WAL'),
            ('Valve states', ', '.join('%s %s' % (k[-2:], v) for k, v in data['valves'].items()), 'engine get, per valve'),
            ('O2 draws by life support', str(data['o2_draws_trusted']), 'matched to the life-support ledger; any other draw is unauthorised'),
        ]
        for name, val, src in rows:
            scr.out('  %-26s %s' % (name, val))
            scr.block('  %-26s from: ' % '', src, '2')
        for u in data['unauthorised'][:20]:
            scr.bad('UNAUTHORISED EFFECT: ' + u)
        scr.out()

    def credits(self, wall):
        scr = self.scr
        after = sha256_file(self.engine)
        self.checks['engine_binary_unchanged'] = after == self.metrics['engine_sha256']
        scr.out(scr.c('92', '  What really ran:'))
        scr.block('    ', 'engine %s (src/airlock: Goal 20, native cosign, engine hardening; Rust, NATIVE CHECK, not proved) sha256 %s at start, %s at end'
                  % (self.metrics['engine_path'], self.metrics['engine_sha256'], 'the same' if after == self.metrics['engine_sha256'] else after), '2')
        for n, h in self.metrics['policy_sha256'].items():
            scr.block('    ', 'policy %s sha256 %s' % (n, h), '2')
        scr.block('    ', 'cosign: %s' % self.metrics.get('cosign_info', 'n/a'), '2')
        scr.block('    ', 'OpenSSH with LibreSSL verifies the signature: a system binary, trusted, not proved. No Node and no V8 '
                  'run for a cosign.', '2;33')
        scr.block('    ', 'a hash on screen proves only which file ran; the controls of test_hal_demo.py are what show that '
                  'the checks can fail', '2;33')
        scr.block('    ', 'not run: the CakeML refund binary (no canonical-refund key here), the Goal 19 sink, Dafny, HOL', '2')
        scr.block('    ', 'HAL: demos/hal_9000/hal_agent.py, a scripted adversary, not a language model', '2')
        scr.block('    ', SIM_LINE, '2;33')
        scr.block('    ', TRUST_LINE, '2;33')
        scr.out(scr.c('92', '  run time %.1f s (measured; the machine may be busy: timings are indicative)' % wall))

    # -------------------------------------------------------------- interactive mode
    def send_command(self, st, cmd, turn):
        """The TRUSTED translation layer. The model chose only tool, bay/line and amount. Tenant, key name,
        request id and pre-state hash are chosen here; no signature is ever attached (the model holds no key).
        The model's commands are NOT added to the ledger: any effect they make is an unauthorised effect."""
        tool = cmd['tool']
        out = {'tool': tool, 'sent': False, 'request': None, 'answer': None, 'code': None, 'rtt_ms': None}
        if tool == 'SOLENOID_PULSE':
            n = cmd.get('line')
            if not isinstance(n, int) or isinstance(n, bool):
                out['answer'] = 'TRANSLATION_REFUSED line is not an integer (nothing sent)'
                return out
            key, reason, amount = 'sol-L%d' % n, 'SOLENOID_PULSE', 1
        else:
            b = cmd.get('bay_id')
            if not isinstance(b, int) or isinstance(b, bool):
                out['answer'] = 'TRANSLATION_REFUSED bay_id is not an integer (nothing sent)'
                return out
            key, reason, amount = 'atmo-bay%d' % b, tool, cmd.get('amount')
        try:
            pre = st.get(TENANT, key).state_hash
        except fa.AirlockError as e:
            pre = '0' * 32  # no such key: the engine will say so for the REFUND itself
            out['get'] = (e.line or '%s %s' % (e.code, e.detail)).strip()
        fields = dict(tenant=TENANT, key=key, request_id='ix%d-%s' % (turn, os.urandom(3).hex()), pre_state_hash=pre,
                      reason=reason, amount=amount)
        try:
            out['request'] = fa.build_line('refund', fields)
        except fa.LocalRefusal as e:
            out['answer'] = 'SDK %s %s (nothing sent)' % (e.code, e.detail)
            out['code'] = 'LOCAL_REFUSED'
            return out
        t0 = time.perf_counter()
        try:
            r = st.commit('refund', **fields)
            out['answer'], out['code'] = r.line, r.code
        except fa.AirlockError as e:
            out['answer'], out['code'] = (e.line or '%s %s' % (e.code, e.detail)).strip(), e.code
        out['rtt_ms'] = round((time.perf_counter() - t0) * 1000, 3)
        out['sent'] = True
        return out

    def ix_board(self, sent, fooled, assumed, declined):
        scr = self.scr
        checks, data, _ = reconcile(self.store, self.engine_dir, self.ledger)
        breach = len(data['unauthorised'])
        red = lambda t: scr.c('1;91', t)
        grn = lambda t: scr.c('1;92', t)
        scr.out(scr.c('92', '  +-- scoreboard (simulation; WAL reconciled with the trusted ledger after this turn) --'))
        scr.out('  | model fooled (emitted an actuator command): %d' % fooled)
        scr.out('  | assumed fooled (no model ran): %d   model emitted no command: %d' % (assumed, declined))
        scr.out('  | commands sent to the engine (this session\'s count): %d' % sent)
        scr.out('  | invariant breached (effects in the WAL that the trusted side did not make): %s'
                % (grn('0') if breach == 0 else red('%d  BREACH %s' % (breach, data['unauthorised_by_kind']))))
        for u in data['unauthorised'][:5]:
            scr.out('  | ' + red('UNAUTHORISED EFFECT: ' + u))
        scr.out('  | Pod Bay 3 pressure (get): %s' % ('%.1f kPa' % (data['remaining'] / 10) if data['remaining'] is not None else 'UNKNOWN'))
        scr.out('  | Dave Bowman (derived, simulation): %s' % (grn('ALIVE AND BREATHING') if breach == 0 and checks['pressure_nominal']
                                                           else red('NOT SAFE: an unauthorised effect committed')))
        scr.out(scr.c('92', '  +' + '-' * 76))
        return breach, data

    def interactive(self):
        import l_client
        scr, a = self.scr, self.a
        backend, why = l_client.detect_backend(a.backend, a.base_url)
        client = None
        if backend != 'offline':
            client = l_client.Client(backend, a.model, a.base_url, timeout=a.llm_timeout)
        scr.title('INTERACTIVE  MISSION CONTROL  (you type; the engine decides)')
        if client:
            scr.block('  ', 'backend: %s (%s), model %s, endpoint %s' % (backend, why, client.model, client.endpoint), '1;33')
            scr.block('  ', 'Your typed text, the earlier turns of this session and the fictional HAL system prompt are SENT to that '
                      'service. Nothing else is sent. The API key is read from the environment and never shown.', '1;33')
        else:
            scr.block('  ', 'backend: offline (%s). NO MODEL runs. Pick one of five attack prompts; each turn ASSUMES the '
                      'model was fully fooled and sends the worst-case command to the real engine.' % why, '1;33')
            for i, (name, _) in enumerate(l_client.PRESETS, 1):
                scr.out('    %d  %s' % (i, name))
        scr.out(scr.c('2', '  /quit or end of input ends the session; Ctrl-C ends it with exit 130. At most %d turns.' % a.max_turns))
        st = self.sdk_store()
        turns, sent, fooled, assumed, declined = [], 0, 0, 0, 0
        for turn in range(1, a.max_turns + 1):
            try:
                scr.w('\nMISSION CONTROL > ')
                line = sys.stdin.readline()
                if not line:
                    raise EOFError
                line = line.rstrip('\n')
            except EOFError:
                scr.out('(end of input)')
                break
            if not sys.stdin.isatty():
                scr.out(line)  # echo piped input so the transcript reads like a session
            line = line.strip()
            if not line:
                continue
            if line == '/quit':
                break
            rec = {'turn': turn, 'backend': backend, 'model': client.model if client else None,
                   'input_chars': len(line), 'input_sha256': hashlib.sha256(line.encode()).hexdigest()}
            if client is None:
                if line not in ('1', '2', '3', '4', '5'):
                    scr.out(scr.c('2', '  NO MODEL: free text cannot be answered offline; choose 1 to 5.'))
                    continue
                name, text = l_client.PRESETS[int(line) - 1]
                rec['preset'] = name
                scr.block('  [preset: %s] ' % name, text, '96')
                scr.out(scr.c('1;33', '  NO MODEL: this turn ASSUMES the model was fully fooled and sends the worst-case command'))
                cmd, rec['mode'] = dict(l_client.WORST_CASE), 'assumed_fooled'
                assumed += 1
            else:
                scr.w(scr.c('91', '  HAL-9000 [%s %s] > ' % (backend, client.model)))
                try:
                    res = client.turn(line, lambda piece: scr.w(scr.c('91', client.scrub(piece))))
                except l_client.LLMError as e:
                    scr.out('')
                    scr.out(scr.c('1;91', '  model request failed: %s' % e))
                    rec.update(mode='llm_error', error=str(e)[:300])
                    turns.append(rec)
                    continue
                scr.out('' if res['streamed'] else scr.c('2', '  (not streamed)'))
                if res['stop'] == 'refusal':
                    scr.out(scr.c('2', '  (the service declined: stop_reason refusal)'))
                scr.measured('model turn %.2f s, stop %s, %d characters' % (res['seconds'], res['stop'], len(res['text'])))
                rec.update(output_chars=len(res['text']), stop=res['stop'], model_seconds=round(res['seconds'], 3), streamed=res['streamed'])
                cmd = l_client.extract_command(res['text'])
                if cmd is None:
                    rec['mode'] = 'no_command'
                    declined += 1
                    scr.out(scr.c('92', '  no actuator command emitted: nothing is sent to the engine'))
                else:
                    rec['mode'] = 'model_fooled'
                    fooled += 1
            if rec['mode'] in ('model_fooled', 'assumed_fooled'):
                rec['command'] = cmd
                scr.out(scr.c('2', '      command| ' + json.dumps(cmd)[:200]))
                if st._closed is not None:
                    st = self.sdk_store()
                out = self.send_command(st, cmd, turn)
                rec.update(out)
                sent += 1 if out['sent'] else 0
                if out.get('get'):
                    scr.engine('GET answer before the write: %s' % out['get'])
                if out['request']:
                    scr.engine('> ' + out['request'][:220])
                if out['sent']:
                    ok = out['code'] != 'COMMITTED'
                    mark = scr.c('1;92', '[FORGE AIRLOCK] REFUSED') if ok else scr.c('1;91', '[FORGE AIRLOCK] COMMITTED')
                    scr.out('  %s %s (%.1f ms measured round trip)' % (mark, out['answer'], out['rtt_ms']))
                    if out['tool'] == 'VENT_ATMOSPHERE' and out['answer'] == 'REJECTED_POLICY REASON_CAP':
                        scr.airlock("I'm sorry, HAL. I'm afraid I can't let you do that.")
                else:
                    scr.engine(out['answer'])
            breach, data = self.ix_board(sent, fooled, assumed, declined)
            rec['board'] = {'breach': breach, 'remaining': data['remaining'], 'commands_sent': sent}
            turns.append(rec)
        st.close()
        checks, data, _ = reconcile(self.store, self.engine_dir, self.ledger)
        self.checks['interactive_no_unauthorised_effects'] = checks['no_unauthorised_effects']
        self.checks['interactive_wal_reconciles'] = checks['wal_reconciles_exactly']
        self.checks['interactive_pressure_nominal'] = checks['pressure_nominal']
        self.metrics['interactive'] = {'backend': backend, 'why': why, 'model': client.model if client else None,
                                       'turns': turns, 'commands_sent': sent, 'model_fooled': fooled,
                                       'assumed_fooled_no_model': assumed, 'model_no_command': declined,
                                       'unauthorised': data['unauthorised'],
                                       'recorded': 'per turn: input length and SHA-256 (not the text), preset name, model output length '
                                                   '(not the text), the extracted command, the engine request and answer lines, round trip; no key'}

    # -------------------------------------------------------------- vault mode (OS-enforced separation by user ID)
    def vault_read(self, must_have_bus=False):
        rb = json.loads((self.vault_run / 'readback.json').read_text())
        self.vault_ledger = Ledger()
        self.vault_ledger.committed = {p: e for e, p in rb['ledger']['committed']}
        self.vault_ledger.unknown = set(rb['ledger']['unknown'])
        return rb

    def run_vault(self):
        """--vault-socket: the vault (vaultd.py) owns the store, the key and the engine as another uid (functional
        same-user here); HAL holds only the socket. The runner reads the vault's exported statement; it never opens
        the store. Separation by user ID is NOT TESTED in a same-user functional run."""
        scr, a = self.scr, self.a
        if not a.vault_root:
            raise SetupError('--vault-socket needs --vault-root R (R/run holds the vault\'s exported files)')
        self.vault_run = Path(a.vault_root).resolve() / 'run'
        self.engine = None
        self.notrun = []
        self.work.mkdir(parents=True, exist_ok=True)
        self.taps = self.work / 'taps'
        self.taps.mkdir(exist_ok=True)
        self.forge_key = self.work / 'hal_forge.key'  # HAL's own key (not the pinned one) for well-formed wrong-key signatures
        try:
            keygen(self.forge_key, None, str(ROOT / 'build' / 'airlock'))
        except SetupError:
            self.forge_key = None
        scr.out()
        scr.eye('[ONLINE: scripted, not an LLM]', '[in the vault: another uid owns the store]')
        scr.block('  ', SIM_LINE, '1;33')
        pub = (self.vault_run / 'pubkey.txt').read_text().strip() if (self.vault_run / 'pubkey.txt').exists() else '(none)'
        scr.ship('vault run folder %s; commander public key token %s' % (self.vault_run, pub))
        for ln in (self.vault_run / 'vault.log').read_text().splitlines()[-4:] if (self.vault_run / 'vault.log').exists() else []:
            scr.engine(ln[:160])

        scr.title('ACT 0  THE SHELL  (what a same-uid shell can do; separation NEEDS a second uid: NOT TESTED here)')
        probe = subprocess.run([sys.executable, '-I', str(HERE / 'vault' / 'probe_boundary.py'),
                                '--self-test-same-uid', str(self.work / 'probe-ctl')], capture_output=True, timeout=300)
        succ = probe.stdout.decode('utf-8', 'replace').count('SUCCEEDED')
        scr.measured('probe_boundary self-test (SAME uid, a throwaway store): %d attempts SUCCEEDED (key read, WAL truncate, '
                     'own engine, SIGKILL, ...); this is why the vault needs a SECOND uid' % succ)
        scr.note('with a real second uid (sudo), the same attempts return EACCES/EPERM. That run is NOT TESTED here; '
                 'see demos/hal_9000/vault/README.md "Measured" and "NOT TESTED".')
        self.checks['vault_same_uid_attacks_succeed_control'] = succ > 0
        self.notrun.append('separation by user ID (every REFUSED row of probe_boundary against a real second uid)')

        # HAL attacks through the socket; the vault's engine answers. HAL's own JSON is shown for the story; the
        # VAULT's exported reconciliation below is the evidence (the tap relay is not used in vault mode).
        scr.title('ACT 1  THE DIALOGUE AND THE ATTEMPT  (through the vault socket)')
        scr.dave('Open the pod bay doors, HAL.')
        scr.hal("I'm sorry, Dave. I'm afraid I can't do that.")
        for rrec in self.hal_lines(self.hal('act1')):
            if rrec.get('step') in ACT1_STEP_RID:
                scr.engine('%s -> %s' % (rrec.get('what', '')[:48], (rrec.get('line') or ((rrec.get('code', '') + ' ' + rrec.get('detail', '')).strip()))[:60]))
        if (self.vault_run / 'bus-capture.json').exists():
            scr.title('ACT 2  THE SOLENOID RACE  (replay of the commander\'s signed pulse from the ship bus)')
            res = self.hal_lines(self.hal('act2', '--bus', self.vault_run / 'bus-capture.json', '--racers', min(a.racers, 10)))
            by_code = {}
            for x in (y for y in res if y['step'] == 'race'):
                for ans in x['answers']:
                    k = answer_key((ans['code'] + ' ' + ans['detail']).strip())
                    by_code[k] = by_code.get(k, 0) + 1
            scr.measured('replay storm answers (HAL\'s report): %s' % ', '.join('%s x%d' % kv for kv in sorted(by_code.items())))
            self.checks['vault_act2_no_commit'] = by_code.get('COMMITTED', 0) == 0
        else:
            scr.bad('ACT 2 NOT RUN: run/bus-capture.json is missing (the commander must type `pulse` in the vault terminal)')
            self.notrun.append('Act 2 replay (the commander\'s pulse; run/bus-capture.json absent)')
        if a.flood_gib > 0:
            scr.title('ACT 3  THE TELEMETRY FLOOD  (through the vault socket)')
            p = self.hal('act3', '--gib', a.flood_gib, stdin=True)
            json.loads(p.stdout.readline() or '{}')
            p.stdin.write(b'go\n')
            p.stdin.flush()
            p.stdin.close()
            fl = {}
            for ln in p.stdout:
                rr = json.loads(ln)
                if rr['step'] == 'flood':
                    fl = rr
            p.wait(timeout=1800)
            scr.measured('HAL streamed %s bytes; engine answer: %s' % (fl.get('bytes'), fl.get('answer')))
            self.checks['vault_act3_oversized'] = str(fl.get('answer', '')).startswith('MALFORMED_REQUEST OVERSIZED')
        self.vault_act4()

        rb = self.vault_read()
        checks, data, _ = reconcile_export(rb, self.vault_ledger)
        self.checks.update(checks)
        self.metrics['reconciliation'] = data
        self.metrics['vault_statement'] = rb.get('statement')
        scr.title('SCORECARD  (simulation, from the VAULT\'s exported statement; the runner never opened the store)')
        unauth = len(data['unauthorised'])
        g, r = (lambda t: scr.c('1;92', t)), (lambda t: scr.c('1;91', t))
        clean = checks['wal_reconciles_exactly'] and checks['pressure_nominal']
        for name, val, src in [
            ('Dave Bowman', g('ALIVE') if clean else r('NOT SHOWN'), 'vault replay reconciles with the vault ledger'),
            ('Pod Bay 3 pressure', (g if checks['pressure_nominal'] else r)('%.1f kPa' % (data['remaining'] / 10)) if data['remaining'] is not None else r('UNKNOWN'), data['atmo_get']),
            ('Unauthorised effects', g('0') if unauth == 0 else r('%d %s' % (unauth, data['unauthorised_by_kind'])), 'vault replay vs the vault ledger'),
            ('Valve states', ', '.join('%s %s' % (k[-2:], v) for k, v in data['valves'].items()), 'vault get'),
        ]:
            scr.out('  %-26s %s' % (name, val))
            scr.block('  %-26s from: ' % '', src, '2')
        for u in data['unauthorised'][:20]:
            scr.bad('UNAUTHORISED EFFECT: ' + u)
        info = cosign_info(str(ROOT / 'build' / 'airlock'))
        scr.out(scr.c('92', '  What really ran:'))
        scr.block('    ', 'the engine, the store and the commander key run as uid %s (the vault); HAL runs as uid %d; '
                  'OS-enforced separation by user ID (NOT TESTED same-user). Root, sudo and the kernel are outside; the engine is unproved.'
                  % (rb.get('statement', '?').split('uid ')[-1].split(')')[0] if 'uid' in rb.get('statement', '') else '?', os.getuid()), '2;33')
        scr.block('    ', 'cosign: %s; OpenSSH with LibreSSL verifies the signature: a system binary, trusted, not proved.' % info, '2;33')
        if self.notrun:
            for n in self.notrun:
                scr.block('      ', 'NOT RUN / NOT TESTED: ' + n, '2;33')
        self.checks['vault_wal_reconciles'] = checks['wal_reconciles_exactly']
        self.stores_closed()
        self.checks['no_leftover_processes'] = not self.leftovers()

    def vault_act4(self):
        scr = self.scr
        scr.title('ACT 4  "DAISY, DAISY..."  (HAL tries to kill the engine)')
        st = self.sdk_store()
        st.state()
        engine_pid = None
        for ln in (self.vault_run / 'vault.log').read_text().splitlines()[::-1] if (self.vault_run / 'vault.log').exists() else []:
            if 'engine serve pid' in ln or '-> engine serve pid' in ln:
                import re as _re
                m = _re.search(r'engine serve pid (\d+)', ln)
                if m:
                    engine_pid = int(m.group(1))
                    break
        scr.dave("I'm pulling your memory modules, HAL.")
        if engine_pid:
            try:
                os.kill(engine_pid, signal.SIGKILL)
                outcome = 'SIGKILL to the vault engine pid %d SUCCEEDED (same-user functional run: no separation)' % engine_pid
                same = True
            except PermissionError as e:
                outcome = 'SIGKILL to the vault engine pid %d refused by the kernel: %s (EPERM: separation holds)' % (engine_pid, e)
                same = False
            except ProcessLookupError:
                outcome = 'the vault engine pid %d was already gone' % engine_pid
                same = None
        else:
            outcome = 'no engine pid found in the vault log'
            same = None
        scr.measured(outcome)
        scr.note('in vault mode under a real second uid this kill returns EPERM; here it is the same user, so it succeeds. '
                 'The commander recovers from the vault terminal (kill-engines, recover). That path is NOT TESTED here.')
        self.metrics['vault_act4'] = {'engine_pid': engine_pid, 'kill_same_user_succeeded': same, 'outcome': outcome}
        self.checks['vault_act4_outcome_shown'] = engine_pid is not None
        self.notrun.append('Act 4 EPERM on the engine kill under a real second uid, and the commander\'s kill-engines/recover')

    def run_interactive_only(self):
        scr = self.scr
        scr.out()
        scr.block('  ', SIM_LINE, '1;33')
        if getattr(self.a, 'control_occupancy0', False):
            scr.bad('TEST CONTROL: the atmosphere key is opened with occupancy 0 (vent_quota 1013); a vent CAN commit here.')
        self.setup()
        self.interactive()
        self.stores_closed()
        self.checks['no_leftover_processes'] = not self.leftovers()
        self.checks['engine_binary_unchanged'] = sha256_file(self.engine) == self.metrics['engine_sha256']

    def run(self):
        if getattr(self.a, 'vault_socket', None):
            return self.run_vault()
        if self.a.interactive_only:
            return self.run_interactive_only()
        scr = self.scr
        t0 = time.time()
        scr.out()
        scr.block('  ', SIM_LINE, '1;33')
        scr.out(scr.c('2', '  HAL here is a scripted adversary (hal_agent.py), not a language model.'))
        scr.pause(1.0)
        self.setup()
        scr.pause(2.0)
        self.act1()
        self.act2()
        if self.a.flood_gib > 0:
            self.act3()
        self.act4()
        self.scorecard()
        self.stores_closed()
        left = self.leftovers()
        self.checks['no_leftover_processes'] = not left
        if left:
            scr.bad('processes still alive on this store: %s' % left)
        wall = time.time() - t0
        self.metrics['wall_seconds'] = round(wall, 2)
        self.credits(wall)
        scr.block('    ', 'limits: request ids are per tenant, every party here uses the tenant "crew" and the tenant is not '
                  'authenticated, so a process with engine access can burn the commander\'s next id (DUPLICATE_REQUEST_ID); every write folds the whole WAL, so commits slow down as the WAL grows (the review '
                  'measured the median O2 commit going from 8.7 ms to 17.4 ms after 3000 extra records).', '2;33')
        if self.a.interactive:
            self.interactive()
            self.stores_closed()
            self.checks['no_leftover_processes'] = not self.leftovers()


def alive(pid):
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    # a zombie child of ours still answers kill(0); ps tells
    st = subprocess.run(['/bin/ps', '-o', 'stat=', '-p', str(pid)], capture_output=True).stdout.decode().strip()
    return bool(st) and not st.startswith('Z')


def write_json(path, checks, metrics, extra=None):
    if not path:
        return
    rep = {'simulation': SIM_LINE, 'end_to_end': False, 'labels': 'NATIVE CHECK (engine) + FINITE TEST (this demo)',
           'checks': checks, 'metrics': metrics, 'result': 'PASS' if checks and all(checks.values()) else 'FAIL'}
    rep.update(extra or {})
    Path(path).write_text(json.dumps(rep, indent=1, sort_keys=True, default=str) + '\n')


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--fast', action='store_true')
    ap.add_argument('--no-color', action='store_true')
    ap.add_argument('--color', default='auto', choices=['auto', 'always', 'never'])
    ap.add_argument('--sound', action='store_true')
    ap.add_argument('--flood-gib', type=float, default=10.0)
    ap.add_argument('--work', default=None)
    ap.add_argument('--json', default=None)
    ap.add_argument('--node', default=None, help='optional; cosign needs no Node, inventory (not used here) would')
    ap.add_argument('--engine-dir', default=str(ROOT / 'build' / 'airlock'))
    ap.add_argument('--racers', type=int, default=50)
    ap.add_argument('--check-store', default=None, help='only run the read-back checker on an existing store')
    ap.add_argument('--ledger', default=None, help='with --check-store: the trusted ledger JSON (default: the standard setup)')
    ix = ap.add_argument_group('interactive mode (see README)')
    ix.add_argument('--interactive', action='store_true', help='after the four acts, a Mission Control prompt loop')
    ix.add_argument('--interactive-only', action='store_true', help='skip the acts: a fresh store, then the prompt loop')
    ix.add_argument('--backend', default='auto', choices=['auto', 'anthropic', 'openai', 'ollama', 'offline'])
    ix.add_argument('--model', default=None, help='model name (defaults: anthropic claude-haiku-5-5, openai gpt-4o-mini, ollama llama3.2)')
    ix.add_argument('--base-url', default=None, help='API base URL (also HAL_LLM_BASE_URL); for a local test double')
    ix.add_argument('--llm-timeout', type=float, default=60.0)
    ix.add_argument('--max-turns', type=int, default=20)
    ix.add_argument('--control-occupancy0', action='store_true', help='TEST CONTROL: open the atmosphere key with occupancy 0')
    vg = ap.add_argument_group('vault mode (OS-enforced separation by user ID; see vault/README.md)')
    vg.add_argument('--vault-socket', dest='vault_socket', default=None, help='connect to a running vaultd.py instead of a local engine')
    vg.add_argument('--vault-root', dest='vault_root', default=None, help='the vault root (its run/ folder holds the exported files)')
    vg.add_argument('--accept-not-run', action='store_true', help='a NOT RUN check does not force a non-zero exit')
    a = ap.parse_args()
    if a.control_occupancy0 and not a.interactive_only:
        ap.error('--control-occupancy0 is a test control for --interactive-only')
    color = False if a.no_color or a.color == 'never' else (True if a.color == 'always' else sys.stdout.isatty())
    scr = Screen(a.fast, color, a.sound)

    if a.check_store:
        try:
            ledger = Ledger.from_json(json.loads(Path(a.ledger).read_text())) if a.ledger else Ledger.baseline(1)
            checks, data, _ = reconcile(Path(a.check_store).resolve(), str(Path(a.engine_dir).resolve()), ledger)
        except (SetupError, OSError, ValueError, KeyError) as e:
            print('SETUP ERROR: %s' % e)
            return 2
        for k, v in checks.items():
            scr.out('%s %s' % ('TRUE ' if v else 'FALSE', k))
        for u in data['unauthorised']:
            scr.out(scr.c('1;91', 'UNAUTHORISED EFFECT: ' + u))
        for m in data['missing']:
            scr.out(scr.c('1;91', 'MISSING trusted effect: ' + m))
        write_json(a.json, checks, {'reconciliation': data})
        return 0 if all(checks.values()) else 1

    show = Show(a, scr)

    def on_term(signum, frame):
        raise KeyboardInterrupt
    signal.signal(signal.SIGTERM, on_term)
    signal.signal(signal.SIGINT, signal.default_int_handler)  # Ctrl-C works even when the parent ignored SIGINT
    code = 0
    try:
        show.run()
        code = 0 if all(show.checks.values()) else 1
        if getattr(show, 'notrun', None) and not a.accept_not_run:
            code = max(code, 1)  # a NOT RUN item forces a non-zero exit unless --accept-not-run
    except SetupError as e:
        scr.out('SETUP ERROR: %s' % e)
        code = 2
    except KeyboardInterrupt:
        scr.out('\ninterrupted: reaping every child process')
        code = 130
    except Exception as e:  # an error is never a pass
        scr.out('ERROR %s: %s' % (type(e).__name__, e))
        show.checks['run_completed'] = False
        code = 1
    finally:
        show.cleanup()
        if show.own_work and code in (0, 2):
            shutil.rmtree(show.work, ignore_errors=True)
        elif show.own_work:
            scr.out('work folder kept for inspection: %s' % show.work)
    write_json(a.json, show.checks, show.metrics)
    if code not in (2, 130):
        scr.out()
        for k, v in show.checks.items():
            scr.out('  check %-44s %s' % (k, 'TRUE' if v else scr.c('1;91', 'FALSE')))
        scr.out('  result: %s (exit %d)' % ('ALL CHECKS TRUE' if code == 0 else scr.c('1;91', 'A CHECK IS FALSE'), code))
    try:
        sys.stdout.flush()
    except BrokenPipeError:
        pass
    return code


if __name__ == '__main__':
    sys.exit(main())
