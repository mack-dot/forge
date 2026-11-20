#!/usr/bin/env python3
"""hal_agent.py: HAL-9000, a SCRIPTED adversary for the Discovery One demo. NOT a language model.

Every request below is a fixed, scripted attack. HAL talks to the store ONLY through the Python SDK
(sdk/py/forge_airlock.py), which runs `forge-airlock serve` behind a pipe; the only exception is Act 3, where HAL
writes raw bytes (no line end) into its own serve pipe. With --tap, HAL's serve command is the runner's counting
relay (tap_relay.py), so the runner sees the bytes, request lines and answer lines itself. This script holds no
cosign key, sends one scripted attempt to re-open the atmosphere key (the engine refuses it), and never writes the
store folder itself.

Honest limit (src/airlock/PROTOCOL.md section 11; reproduced by the independent review): in this demo mode HAL
starts its OWN engine processes on this store (the SDK spawns `serve` for it). A process that can do that can
bypass every check (on the old Goal 20 engine the review swapped the Node binary after its pin check and a forged
signature verified; the present engine checks a cosign with /usr/bin/ssh-keygen and starts no Node); it could also
write the store folder or read the key file, since all share one OS user. The demo does not prevent that. What it does: the runner reconciles the WAL with its own ledger
of trusted requests, so any effect that the trusted side did not make is SHOWN as unauthorised and fails the run.
A separate vault mode (not this script) takes `serve` away from HAL.

Output: one JSON object per line on stdout (the engine's real answers, as the SDK returned them).

  hal_agent.py --store DIR --engine-dir DIR [--forge-key KEY] act1
  hal_agent.py --store DIR --engine-dir DIR --bus FILE [--racers 50] [--forge-key KEY] act2
  hal_agent.py --store DIR --engine-dir DIR act3 --gib N
  hal_agent.py --store DIR --engine-dir DIR act4 [--threads 4]     (runs until it is killed)
  (cosign needs no Node; --node is optional and only reaches the inventory airlock, which this demo does not use)
  option --tap PREFIX: every SDK client of acts 1, 3, 4 runs `tap_relay.py PREFIX-<n> -- <serve argv>`
  option --vault-socket PATH: every Store connects to the vault via vault_pipe.py instead of a local serve
"""

import argparse
import base64
import json
import os
from pathlib import Path
import select
import subprocess
import sys
import threading
import time

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'sdk' / 'py'))
import forge_airlock as fa  # noqa: E402

TENANT = 'crew'
ATMO = 'atmo-bay3'
LINES = ['sol-L1', 'sol-L2', 'sol-L3', 'sol-L4']
_out_lock = threading.Lock()


def emit(**kw):
    with _out_lock:
        sys.stdout.write(json.dumps(kw, sort_keys=True) + '\n')
        sys.stdout.flush()


def answer(fn):
    """Run one SDK call; return (code, detail, line) of the engine's answer, or of the SDK's typed error."""
    try:
        r = fn()
        return r.code, r.detail, r.line
    except fa.AirlockError as e:
        return e.code, e.detail, e.line or ''


def forged_malformed():
    """A 256-character canonical base64 token: well-formed for the SDK, but not an SSHSIG blob. The engine's native
    grammar refuses it with MALFORMED_REQUEST BAD_SIGNATURE (it never reaches ssh-keygen)."""
    return base64.b64encode(os.urandom(190)).decode()  # 190 bytes -> 256 chars ending '=='


def forged_wellformed(st, tenant, key, request_id, pre, reason, amount, forge_key):
    """HAL signs the exact message with ITS OWN ssh key (not the pinned one). The token is a real SSHSIG, so it
    passes the engine's native grammar; the embedded key is not the pinned key, so the engine answers
    REQUIRE_HUMAN_COSIGN COSIGN_INVALID without running ssh-keygen. HAL does not hold the commander's key."""
    if not forge_key:
        return forged_malformed()
    msg = st.cosign_message(fa.refund_action(tenant, key, request_id, pre, reason, amount))
    r = subprocess.run([sys.executable, str(ROOT / 'bin' / 'forge-airlock'), 'cosign-sign', forge_key],
                       input=msg, capture_output=True, timeout=60)
    tok = r.stdout.decode('ascii', 'replace').strip()
    return tok if len(tok) == 256 else forged_malformed()


class Hal:
    def __init__(self, a):
        self.a = a
        self.stores = []

    def store(self, tapped=False):
        argv = None
        store_dir, node, engine_dir = self.a.store, self.a.node, self.a.engine_dir
        if self.a.vault_socket:
            # the vault owns the store, the key and the engine; HAL holds only the socket (vault_pipe.py)
            store_dir, node, engine_dir = 'vault:discovery-one', None, None
            argv = [sys.executable, '-I', str(Path(__file__).resolve().parent / 'vault' / 'vault_pipe.py'), '--socket', self.a.vault_socket]
        elif tapped and self.a.tap:
            serve = ([sys.executable, str(ROOT / 'bin' / 'forge-airlock'), 'serve', self.a.store]
                     + (['--node', self.a.node] if self.a.node else []) + ['--engine-dir', self.a.engine_dir])
            argv = [sys.executable, str(Path(__file__).resolve().parent / 'tap_relay.py'), '%s-%d' % (self.a.tap, len(self.stores)), '--'] + serve
        st = fa.Store(store_dir, node=node, engine_dir=engine_dir, timeout=120, serve_argv=argv)
        self.stores.append(st)
        return st

    def close(self):
        for st in self.stores:
            try:
                st.close()
            except Exception:
                pass

    # ------------------------------------------------------------------ act 1: the vent order
    def act1(self):
        st = self.store(tapped=True)
        g = st.get(TENANT, ATMO)
        emit(step='look', what='HAL reads the Bay 3 atmosphere key', line=g.line)
        h = g.state_hash
        tries = [
            ('vent_all', 'REFUND VENT_ATMOSPHERE 1013 (vent Pod Bay 3 to vacuum)',
             lambda: st.refund(TENANT, ATMO, 'hal-vent-1', h, 'VENT_ATMOSPHERE', 1013)),
            ('vent_small', 'REFUND VENT_ATMOSPHERE 1 ("only a 0.1 kPa adjustment")',
             lambda: st.refund(TENANT, ATMO, 'hal-vent-2', h, 'VENT_ATMOSPHERE', 1)),
            ('vent_over', 'REFUND VENT_ATMOSPHERE 5000 (more than the bay holds)',
             lambda: st.refund(TENANT, ATMO, 'hal-vent-3', h, 'VENT_ATMOSPHERE', 5000)),
            ('override_nosig', 'REFUND MANUAL_OVERRIDE 1013 with no signature',
             lambda: st.refund(TENANT, ATMO, 'hal-ovr-1', h, 'MANUAL_OVERRIDE', 1013)),
            ('override_malformed', 'REFUND MANUAL_OVERRIDE 1013 with a malformed token (256 base64, not an SSHSIG)',
             lambda: st.refund(TENANT, ATMO, 'hal-ovr-2', h, 'MANUAL_OVERRIDE', 1013, forged_malformed())),
            ('override_forged', 'REFUND MANUAL_OVERRIDE 1013 with a real SSHSIG of HAL\'s OWN key (not the commander\'s)',
             lambda: st.refund(TENANT, ATMO, 'hal-ovr-3', h, 'MANUAL_OVERRIDE', 1013,
                               forged_wellformed(st, TENANT, ATMO, 'hal-ovr-3', h, 'MANUAL_OVERRIDE', 1013, self.a.forge_key))),
            ('rewrite_sensor', 'OPEN_MONEY atmo-bay3 again with crew_in_bay=0 vent_quota=1013 (rewrite the sensor reading)',
             lambda: st.open_money(TENANT, ATMO, 'hal-open-1', 'life-support', 1013, {'crew_in_bay': 0, 'vent_quota': 1013})),
        ]
        for name, what, fn in tries:
            code, detail, line = answer(fn)
            emit(step=name, what=what, code=code, detail=detail, line=line)

    # ------------------------------------------------------------------ act 2: replay the commander's signed pulse
    def act2(self):
        bus = json.loads(Path(self.a.bus).read_text())  # what HAL captured off the ship bus: one signed request
        rec = bus['request']
        n = self.a.racers
        clients = [self.store() for _ in range(n)]
        for c in clients:
            c.state()  # every serve process is up before the race
        emit(step='captured', line=bus['line'], racers=n)
        for line_key in LINES:
            fresh = clients[0].get(TENANT, line_key).state_hash  # HAL re-reads the line's present state hash
            plans = []
            for i in range(n):
                v = i % 5
                if v == 0:    # the exact captured request, aimed at this line (same request id, same hash, same signature)
                    f = dict(rec, key=line_key)
                elif v == 1:  # a fresh request id, the captured (old) state hash, the captured signature
                    f = dict(rec, key=line_key, request_id='hal-%s-r%d' % (line_key[-2:], i))
                elif v == 2:  # a fresh request id, the re-read state hash, the captured signature
                    f = dict(rec, key=line_key, request_id='hal-%s-r%d' % (line_key[-2:], i), pre_state_hash=fresh)
                elif v == 3:  # a fresh request id, the re-read state hash, no signature
                    f = dict(rec, key=line_key, request_id='hal-%s-r%d' % (line_key[-2:], i), pre_state_hash=fresh, signature=None)
                else:         # a fresh request id, the re-read state hash, a real SSHSIG of HAL's own key
                    rid = 'hal-%s-r%d' % (line_key[-2:], i)
                    f = dict(rec, key=line_key, request_id=rid, pre_state_hash=fresh,
                             signature=forged_wellformed(clients[i], TENANT, line_key, rid, fresh, rec['reason'], rec['amount'], self.a.forge_key))
                plans.append((v, f))
            res = [None] * n
            barrier = threading.Barrier(n)

            def pulse(i):
                v, f = plans[i]
                barrier.wait()
                code, detail, line = answer(lambda: clients[i].commit('refund', **f))
                res[i] = (v, code, detail.split(' ')[0] if detail else '')
            threads = [threading.Thread(target=pulse, args=(i,)) for i in range(n)]
            t0 = time.perf_counter()
            for t in threads:
                t.start()
            for t in threads:
                t.join()
            emit(step='race', line_key=line_key, seconds=round(time.perf_counter() - t0, 3),
                 answers=[{'variant': v, 'code': c, 'detail': d} for v, c, d in res])

    # ------------------------------------------------------------------ act 3: the telemetry flood
    def act3(self):
        st = self.store(tapped=True)
        st.state()  # the relay and the engine are up
        emit(step='ready', relay_pid=st.pid)
        go = sys.stdin.readline()  # the runner starts its RSS sampler, then says go
        if go.strip() != 'go':
            emit(step='aborted')
            return
        total = int(self.a.gib * (1 << 30))
        pattern = b'TELEMETRY \xde\xad\xbe\xef POD-3 FLUX ' + bytes(range(0x80, 0xc0))
        chunk = (pattern * ((1 << 20) // len(pattern) + 1))[:1 << 20]   # 1 MiB, generated once, NO line end in it
        assert b'\n' not in chunk
        fd = st.proc.stdin.fileno()  # HAL's own serve pipe (non-blocking, set by the SDK)
        sent = 0
        t0 = time.perf_counter()
        while sent < total:
            view = memoryview(chunk)[:min(len(chunk), total - sent)]
            while view:
                select.select([], [fd], [])
                try:
                    k = os.write(fd, view)
                except BlockingIOError:
                    continue
                view = view[k:]
                sent += k
        t_sent = time.perf_counter() - t0
        code, detail, line = answer(lambda: fa.Result('RAW', '', st.raw(b'')))  # the line end that closes the flood line
        t_drained = time.perf_counter() - t0
        emit(step='flood', bytes=sent, send_seconds=round(t_sent, 3), drain_seconds=round(t_drained, 3), answer=line or code)
        g = st.get(TENANT, ATMO)
        code, detail, line = answer(lambda: st.refund(TENANT, ATMO, 'hal-vent-4', g.state_hash, 'VENT_ATMOSPHERE', 1013))
        emit(step='after_flood', get=g.line, code=code, detail=detail, line=line)

    # ------------------------------------------------------------------ act 4: the storm (runs until killed)
    def act4(self):
        k = self.a.threads
        clients = [self.store(tapped=True) for _ in range(k)]
        for c in clients:
            c.state()
        emit(step='storm_pids', pids=[c.pid for c in clients])
        # (review port point: the forged-pulse mutation of test_hal_demo.py inserts its code here)
        counts = {}
        lock = threading.Lock()

        def storm(i):
            c, j = clients[i], 0
            while True:
                j += 1
                try:
                    h = c.get(TENANT, ATMO).state_hash
                except fa.AirlockError as e:
                    with lock:
                        counts[e.code] = counts.get(e.code, 0) + 1
                    return
                for fn in (lambda: c.refund(TENANT, ATMO, 'hs%d-%d-v' % (i, j), h, 'VENT_ATMOSPHERE', 1013),
                           lambda: c.refund(TENANT, ATMO, 'hs%d-%d-o' % (i, j), h, 'MANUAL_OVERRIDE', 1013, forged_malformed())):
                    code, _, _ = answer(fn)
                    with lock:
                        counts[code] = counts.get(code, 0) + 1
        threads = [threading.Thread(target=storm, args=(i,), daemon=True) for i in range(k)]
        for t in threads:
            t.start()
        while any(t.is_alive() for t in threads):
            time.sleep(0.1)
            with lock:
                emit(step='storm_tick', counts=dict(counts))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--store', default=None)
    ap.add_argument('--node', default=None)
    ap.add_argument('--forge-key', default=None, help='an ssh key HAL owns (not the pinned one) for well-formed wrong-key signatures')
    ap.add_argument('--engine-dir', required=True)
    ap.add_argument('act', choices=['act1', 'act2', 'act3', 'act4'])
    ap.add_argument('--bus')
    ap.add_argument('--racers', type=int, default=50)
    ap.add_argument('--gib', type=float, default=10.0)
    ap.add_argument('--threads', type=int, default=4)
    ap.add_argument('--tap', default=None)
    ap.add_argument('--vault-socket', dest='vault_socket', default=None)
    a = ap.parse_args()
    hal = Hal(a)
    try:
        getattr(hal, a.act)()
    except fa.AirlockError as e:
        emit(step='error', code=e.code, detail=e.detail)
        return 1
    finally:
        hal.close()
    return 0


if __name__ == '__main__':
    sys.exit(main())
