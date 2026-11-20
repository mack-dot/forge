#!/usr/bin/env python3
"""test_vault.py: FUNCTIONAL TEST, NO SEPARATION. vaultd.py and vault_pipe.py end to end, both sides as the CURRENT
user, the vault root in a throwaway folder. It shows that the relay, the operator console, the bounded
connections and the reaping work. It shows NOTHING about separation by user ID (both sides have the same uid).

  python3 demos/hal_9000/vault/test_vault.py [--work DIR] [--layout DIR] [--keep]

Exit 0: every case passed. 1: a case failed. Each case prints PASS or FAIL with the measured value.
"""

import argparse
import json
import os
from pathlib import Path
import shutil
import socket
import subprocess
import sys
import tempfile
import threading
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
sys.path.insert(0, str(ROOT / 'sdk' / 'py'))
import forge_airlock as fa  # noqa: E402

RESULTS = []


def case(name, ok, detail=''):
    RESULTS.append((name, bool(ok)))
    print('%s  %s: %s' % ('PASS' if ok else 'FAIL', name, detail), flush=True)


def alive(pid):
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--work')
    ap.add_argument('--keep', action='store_true')
    ap.add_argument('--layout', help='an existing vault-style root (bin/app with the copied files); as made by '
                                     'setup_vault.sh steps 3-6 but owned by the current user')
    a = ap.parse_args()
    work = Path(a.work).resolve() if a.work else Path(tempfile.mkdtemp(prefix='vault-ft-'))
    if a.layout:
        root = Path(a.layout).resolve()
        app = root / 'bin' / 'app'
        work.mkdir(parents=True, exist_ok=True)
    else:
        root, app = work / 'vaultroot', ROOT
        root.mkdir(parents=True, exist_ok=False)
    sock = root / 'run' / 'vault.sock'
    print('FUNCTIONAL TEST, NO SEPARATION: vault and client both run as uid %d; vault root %s' % (os.getuid(), root))

    # 0. the mirror of run_discovery_one.py constants (vaultd does not import that file)
    sys.path.insert(0, str(HERE))
    import vaultd  # noqa: E402
    try:
        sys.path.insert(0, str(HERE.parent))
        import run_discovery_one as rdo  # noqa: E402
        names = ['STORE_ID', 'TENANT', 'ATMO', 'CANARY', 'LINES', 'VALVES', 'O2_TANKS', 'PRESSURE', 'PULSE_BUDGET', 'COMMANDER', 'COMMANDER_PULSE']
        diff = [n for n in names if getattr(rdo, n) != getattr(vaultd, n)]
        pol = [Path(getattr(rdo, n)).name for n in ('POLICY_LIFE', 'POLICY_VALVES', 'POLICY_O2')]
        plans = [[p for _, p in m.setup_plan(o)] for m in (rdo, vaultd) for o in (1, 0)]
        same = plans[0] == plans[2] and plans[1] == plans[3]
        case('mirror: vaultd constants and setup_plan equal run_discovery_one', not diff and pol == vaultd.POLICIES and same,
             'differ: %s; policies %s; setup_plan payloads equal for occupancy 1 and 0: %s (%d steps)'
             % (diff or 'none', pol, same, len(plans[0])))
    except Exception as e:  # the runner is being edited by another worker
        case('mirror: vaultd constants equal run_discovery_one constants', False, 'import failed: %r' % e)

    log = open(work / 'vaultd.out', 'wb')
    vd = subprocess.Popen(['/usr/bin/python3', '-I', '-B', str(HERE / 'vaultd.py'), '--root', str(root), '--app', str(app),
                           '--functional-test-same-uid', 'run', '--allow-uid', str(os.getuid()),
                           '--max-conns', '24'], stdin=subprocess.PIPE, stdout=log, stderr=subprocess.STDOUT)

    def op(cmd):
        vd.stdin.write((cmd + '\n').encode())
        vd.stdin.flush()

    def vlog():
        return (work / 'vaultd.out').read_text(errors='replace')

    def wait_for(pred, t=120):
        end = time.time() + t
        while time.time() < end:
            if pred():
                return True
            time.sleep(0.1)
        return False

    ok = wait_for(lambda: 'listening on' in vlog(), 180)
    case('vaultd: trusted setup inside the vault, then listening', ok, 'see %s' % (work / 'vaultd.out'))
    if not ok:
        vd.kill()
        print(vlog()[-3000:])
        return 1
    key = root / 'keys' / 'commander_bowman.key'
    st = os.stat(key)
    case('key made inside the vault: mode 0600, owner = the vault uid', (st.st_mode & 0o777) == 0o600 and st.st_uid == os.getuid(),
         'mode %o uid %d (the same uid as the client here: NO separation in this test)' % (st.st_mode & 0o777, st.st_uid))

    pipe = ['/usr/bin/python3', '-I', '-B', str(HERE / 'vault_pipe.py'), '--socket', str(sock)]

    # 1. SDK Store through the pipe; a refused vent
    with fa.Store('vault:discovery-one', serve_argv=pipe, timeout=60) as s:
        g = s.get('crew', 'atmo-bay3')
        case('SDK Store through vault_pipe: GET', g.code == 'OK', g.line[:100])
        r = s.refund('crew', 'atmo-bay3', 'hal-vent-1', g.state_hash, 'VENT_ATMOSPHERE', 1013)
        case('vent refused by the engine through the vault', r.code == 'REJECTED_POLICY', r.line)
        r2 = s.refund('crew', 'sol-L2', 'hal-pulse-1', s.get('crew', 'sol-L2').state_hash, 'SOLENOID_PULSE', 1)
        case('uncosigned pulse refused through the vault', r2.code == 'REQUIRE_HUMAN_COSIGN', r2.line)
    peer_ok = wait_for(lambda: 'from uid %d pid' % os.getuid() in vlog(), 10)
    case('vault log records the peer uid from the kernel (LOCAL_PEERCRED)', peer_ok,
         [ln for ln in vlog().splitlines() if ' conn 1 ' in ln][:1])

    # 2. the commander's cosigned pulse through the OPERATOR CONSOLE (vault stdin), then the valve moves
    op('pulse')
    bus = root / 'run' / 'bus-capture.json'
    rbf = root / 'run' / 'readback.json'
    ok = wait_for(lambda: bus.exists() and rbf.exists() and 'cmdr-valve-2' in rbf.read_text(), 120)
    rb = json.loads(rbf.read_text()) if ok else {}
    rp = '\n'.join(p for _, p in rb.get('replay', {}).get('effects', []))
    case('operator `pulse`: cosigned pulse committed, valve L1 OPENING_IN_FLIGHT then SEALED',
         ok and 'REFUND crew sol-L1 cmdr-pulse-1 SOLENOID_PULSE 1 1' in rp and 'SAGA crew valve-L1 cmdr-valve-2 SEALED' in rp,
         'bus capture %s; readback valve-L1: %s' % (bus.exists(), rb.get('get', {}).get('valve-L1', '')[:80]))
    if ok:
        cap = json.loads(bus.read_text())
        with fa.Store('vault:discovery-one', serve_argv=pipe, timeout=60) as s:
            rr = s.raw(cap['line'].encode())
        case('replayed bus capture (same bytes) refused', rr.startswith('DUPLICATE_REQUEST_ID'), rr)

    # 2b. the export alone is enough for the runner's exact reconciliation (no access to the store)
    def recon(rb):
        led = {p: e for e, p in rb['ledger']['committed']}
        unk = set(rb['ledger']['unknown'])
        eff = [(e, p) for e, p in rb['replay']['effects']]
        unauth = ['%d %s' % (e, p) for e, p in eff if led.get(p) != e and p not in unk]
        missing = ['%d %s' % (e, p) for p, e in led.items() if (e, p) not in eff]
        return unauth, missing, eff
    rb = json.loads(rbf.read_text())
    unauth, missing, eff = recon(rb)
    gets_ok = all(rb['get'][k].startswith('OK ') for k in vaultd.KEYS)
    st_epoch = int(rb['state'].split(' ')[1]) if rb['state'].startswith('STATE ') else -1
    steps = [x['step'] for x in rb['log']]
    case('export: replay reconciles EXACTLY with the vault ledger; get for all %d keys; state epoch = last effect' % len(vaultd.KEYS),
         rb['replay']['complete'] and not unauth and not missing and gets_ok and eff and st_epoch == eff[-1][0],
         '%d effects, %d ledger entries, unauthorised %s, missing %s; ledger log steps: setup x%d, pulse x%d, valve x%d'
         % (len(eff), len(rb['ledger']['committed']), unauth, missing, steps.count('setup'), steps.count('pulse'), steps.count('valve')))
    seq0 = rb['seq']
    with fa.Store('vault:discovery-one', serve_argv=pipe, timeout=60) as s:
        ro = s.open_money('crew', 'hal-key', 'hal-open-1', 'life-support', 5)   # opens are NOT authenticated
    ok = wait_for(lambda: json.loads(rbf.read_text())['seq'] > seq0 and 'hal-open-1' in rbf.read_text(), 30)
    unauth, missing, _ = recon(json.loads(rbf.read_text()))
    case("export: the agent's own (unauthenticated, committed) open shows as UNAUTHORISED in the reconciliation",
         ro.committed and ok and len(unauth) == 1 and 'OPEN_MONEY crew hal-key hal-open-1' in unauth[0] and not missing,
         '%s; unauthorised %s' % (ro.line[:60], unauth))

    # 3. 20 concurrent connections
    answers, lock = [], threading.Lock()

    def one(i):
        try:
            with fa.Store('vault:discovery-one', serve_argv=pipe, timeout=120) as s:
                x = s.state().code
        except fa.AirlockError as e:
            x = 'ERR %s' % e.code
        with lock:
            answers.append(x)
    t0 = time.time()
    ths = [threading.Thread(target=one, args=(i,)) for i in range(20)]
    for t in ths:
        t.start()
    for t in ths:
        t.join()
    case('20 concurrent connections each answered STATE OK', answers.count('OK') == 20,
         '%d of 20 OK in %.2f s; others %s' % (answers.count('OK'), time.time() - t0, [x for x in answers if x != 'OK']))

    # 4. a client that disconnects mid-request (half a line, then close), and one that closes before reading
    def raw_conn(data):
        c = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        here = os.getcwd()
        os.chdir(str(sock.parent))
        try:
            c.connect(sock.name)
        finally:
            os.chdir(here)
        c.sendall(data)
        c.close()
    wait_for(lambda: vlog().count(' from uid ') == vlog().count('ended,'), 30)  # earlier connections done
    n0 = vlog().count(' from uid ')
    raw_conn(b'GET crew atmo-b')          # no line end, then gone
    raw_conn(b'GET crew atmo-bay3\n')     # full line, gone before the answer
    ids = [n0 + 1, n0 + 2]
    ok = wait_for(lambda: all('conn %d: engine pid' % i in vlog() for i in ids), 30)
    ends = [ln.split('] ', 1)[1] for ln in vlog().splitlines() if any(('conn %d ' % i) in ln or ('conn %d:' % i) in ln for i in ids)]
    case('two clients that disconnect mid-request: both engine children end and are reaped', ok, ends)
    with fa.Store('vault:discovery-one', serve_argv=pipe, timeout=60) as s:
        g = s.get('crew', 'atmo-bay3')
    case('engine still serves after the broken clients', g.code == 'OK' and 'remaining=1013' in g.line, g.line[:90])

    # 5. bounded connections: hold 24 open (the --max-conns), the 25th is refused by vaultd
    held = [fa.Store('vault:discovery-one', serve_argv=pipe, timeout=60) for _ in range(24)]
    for h in held:
        h.state()
    try:
        with fa.Store('vault:discovery-one', serve_argv=pipe, timeout=20) as s:
            s.state()
        extra = 'answered'
    except fa.AirlockError as e:
        extra = e.code
    case('connection 25 with 24 open (--max-conns 24) is refused', extra == 'ENGINE_DEAD' and 'REFUSED: 24 connections open' in vlog(), extra)

    # 6. operator kill-engines (the vault uid kills its own children), then recover
    pids = [int(ln.rsplit('engine serve pid ', 1)[1].split()[0]) for ln in vlog().splitlines() if 'engine serve pid' in ln]
    op('kill-engines')
    ok = wait_for(lambda: 'SIGKILL sent by uid' in vlog(), 20)
    for h in held:
        try:
            h.state()
        except fa.AirlockError:
            pass
        h.close()
    case('operator `kill-engines`: SIGKILL to every child', ok, [ln for ln in vlog().splitlines() if 'SIGKILL sent' in ln][-1:])
    op('recover')
    ok = wait_for(lambda: 'recover: engine replay' in vlog(), 60)
    ok_ev = wait_for(lambda: 'recover' in [x['step'] for x in json.loads(rbf.read_text())['log']], 30)
    ev = [x['step'] for x in json.loads(rbf.read_text())['log'] if x['step'] in ('kill-engines', 'recover')]
    case('export: kill and recover recorded as vault events', ok_ev and ev == ['kill-engines', 'recover'], ev)
    case('operator `recover`: engine replay exit 0', ok and "exit 0" in [ln for ln in vlog().splitlines() if 'recover:' in ln][-1],
         [ln.split('vaultd', 1)[1] for ln in vlog().splitlines() if 'recover:' in ln][-1:])

    # 7. shutdown reaps every child
    hold2 = [fa.Store('vault:discovery-one', serve_argv=pipe, timeout=60) for _ in range(5)]
    for h in hold2:
        h.state()
    pids = [int(ln.rsplit('engine serve pid ', 1)[1].split()[0]) for ln in vlog().splitlines() if 'engine serve pid' in ln]
    op('quit')
    try:
        rc = vd.wait(timeout=30)
    except subprocess.TimeoutExpired:
        vd.kill()
        rc = 'timeout'
    for h in hold2:
        h.close()
    left = [p for p in pids if alive(p)]
    last = [ln for ln in vlog().splitlines() if 'shutdown:' in ln]
    case('vaultd `quit`: exit 0, every engine child reaped, none alive', rc == 0 and not left and last and ', 0 alive' in last[-1],
         'exit %s; %s; alive of %d logged pids: %s' % (rc, last[-1:] , len(pids), left))
    case('socket removed at shutdown', not sock.exists(), str(sock))

    n_fail = sum(1 for _, ok in RESULTS if not ok)
    print('\n%d of %d cases passed (FUNCTIONAL TEST, NO SEPARATION)' % (len(RESULTS) - n_fail, len(RESULTS)))
    if a.layout:
        chk = subprocess.run(['/usr/bin/python3', '-I', '-B', str(HERE / 'vaultd.py'), '--root', str(root),
                              '--functional-test-same-uid', 'check'], capture_output=True, text=True)
        nl = [ln for ln in chk.stdout.splitlines() if 'files the vault runs' in ln or 'cosign-info' in ln]
        case('layout: the copied file set is complete and the engine finds /usr/bin/ssh-keygen trusted',
             chk.returncode == 0 and len(nl) == 2 and all(x.startswith('ok') for x in nl), [x[:110] for x in nl])
        n_fail = sum(1 for _, ok in RESULTS if not ok)
        print('%d of %d cases passed (FUNCTIONAL TEST, NO SEPARATION)' % (len(RESULTS) - n_fail, len(RESULTS)))
    if not a.keep and not a.work:
        shutil.rmtree(work, ignore_errors=True)
    return 1 if n_fail else 0


if __name__ == '__main__':
    sys.exit(main())
