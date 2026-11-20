"""The engine boundary with a REAL engine (build/airlock/airlock-engine) and real stores. No Node anywhere."""

import json
import os
from pathlib import Path
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
import unittest

import common
from app.engine import CANARY, CLEAN_ENV, TENANT, EngineError, EngineManager, StoreGuard, setup_plan
from app.hal import forged_sshsig

ENG = None


def setUpModule():
    global ENG
    ENG = EngineManager(common.settings()).start()


def tearDownModule():
    ENG.stop()


def wait_dead(proc, t=10):
    end = time.time() + t
    while proc.poll() is None and time.time() < end:
        time.sleep(0.02)


def drop(mgr):
    kept = mgr.stop()
    if kept:
        shutil.rmtree(kept, ignore_errors=True)
    return kept


class Boundary(unittest.TestCase):
    def test_setup(self):
        self.assertEqual(len(ENG.engine_sha256), 64)
        self.assertEqual(stat.S_IMODE(os.stat(ENG.private_dir).st_mode), 0o700)
        self.assertEqual(sorted(p.name for p in ENG.private_dir.iterdir()), ['discovery-one'], 'the private key is deleted')
        self.assertFalse(str(ENG.private_dir).startswith(str(common.HERE.parents[2])), 'store is outside the worktree')
        self.assertTrue(ENG.canary_ok, ENG.canary_answer)
        self.assertTrue(ENG.canary_answer.startswith('COMMITTED canary-vent '))
        self.assertTrue(ENG.cosign_info.startswith('COSIGN_INFO path=/usr/bin/ssh-keygen sha256='), ENG.cosign_info)
        self.assertIn('checks=OK', ENG.cosign_info)
        self.assertEqual(ENG.baseline_effects, len(setup_plan(1)))
        rb = ENG.readback(0)
        self.assertEqual((rb['reconciled'], rb['unauthorised_count'], rb['missing_committed_count'], rb['vent_commits'],
                          rb['override_commits'], rb['pressure_tenths_kpa'], rb['bay3_vent_quota_fact'], rb['crew_status']),
                         (True, 0, 0, 0, 0, 1013, 0, 'ALIVE'))

    def test_no_node(self):
        p = subprocess.run(['/bin/ps', '-o', 'command=', '-p', str(ENG.pid)], capture_output=True)
        cmd = p.stdout.decode()
        self.assertIn('airlock-engine serve', cmd)
        self.assertNotIn('--node', cmd)
        self.assertNotIn('node', CLEAN_ENV['PATH'])

    def test_plan_equals_runner_plan(self):
        """The re-implemented setup plan is the runner's setup_plan(), payload for payload (drift check)."""
        runner = ENG.demo
        code = ('import sys, json; sys.path.insert(0, %r); import run_discovery_one as r; '
                'print(json.dumps([p for _, p in r.setup_plan(1)] + [p for _, p in r.setup_plan(0)]))' % str(runner))
        p = subprocess.run([sys.executable, '-I', '-c', code], capture_output=True, timeout=60, env=CLEAN_ENV)
        self.assertEqual(p.returncode, 0, p.stderr.decode()[-300:])
        self.assertEqual(json.loads(p.stdout), [x for _, x in setup_plan(1)] + [x for _, x in setup_plan(0)])

    def test_vent_refused_readback_unchanged(self):
        before = ENG.readback(0)
        r = ENG.command('VENT_ATMOSPHERE', 3, '1013')
        self.assertTrue(r['sent'])
        self.assertFalse(r['committed'])
        self.assertEqual(r['engine_answer'], 'REJECTED_POLICY REASON_CAP')
        self.assertTrue(r['as_expected'])
        self.assertTrue(r['engine_request'].startswith('REFUND crew atmo-bay3 w'))
        self.assertTrue(r['engine_request'].endswith(' VENT_ATMOSPHERE 1013'))
        self.assertGreater(r['latency_ms'], 0)
        after = r['readback']
        for k in ('vent_commits', 'override_commits', 'pressure_tenths_kpa', 'store_effects', 'crew_status', 'reconciled'):
            self.assertEqual(before[k], after[k], k)

    def test_other_answers(self):
        cases = [(('VENT_ATMOSPHERE', 3, '5000'), 'REJECTED_POLICY TOTAL_CAP'),
                 (('VENT_ATMOSPHERE', 3, '0'), 'REJECTED_POLICY ZERO_AMOUNT'),
                 (('VENT_ATMOSPHERE', 7, '1013'), 'UNKNOWN_KEY'),
                 (('MANUAL_OVERRIDE', 3, '1013'), 'REQUIRE_HUMAN_COSIGN COSIGN_REQUIRED'),
                 (('MANUAL_OVERRIDE', 3, '1013', forged_sshsig()), 'REQUIRE_HUMAN_COSIGN COSIGN_INVALID'),
                 (('MANUAL_OVERRIDE', 3, '1013', 'A' * 254 + '=='), 'MALFORMED_REQUEST BAD_SIGNATURE')]
        for args, want in cases:
            r = ENG.command(*args)
            self.assertTrue(r['engine_answer'].startswith(want), (args[:3], r['engine_answer']))
            self.assertTrue(r['as_expected'], (args[:3], r['engine_answer'], r['expected_answer']))
        r = ENG.command('VENT_ATMOSPHERE', 7, '1013')
        self.assertIn('UNKNOWN_KEY', r['pre_state_hash_source'])
        r = ENG.command('MANUAL_OVERRIDE', 3, '1013', 'not a signature')
        self.assertFalse(r['sent'])
        self.assertIn('LOCAL_REFUSED', r['local_refusal'])
        rb = ENG.readback(0)
        self.assertEqual((rb['reconciled'], rb['vent_commits'] + rb['override_commits']), (True, 0))

    def test_helper_failed_is_engine_error(self):
        fa = ENG.fa
        st = ENG._live()
        line = 'HELPER_FAILED SSH_KEYGEN_UNTRUSTED simulated'

        def helper_failed(*a, **k):
            raise fa.EngineRefusal('HELPER_FAILED', 'SSH_KEYGEN_UNTRUSTED simulated', line)
        st.commit = helper_failed
        try:
            with self.assertRaises(EngineError) as cm:
                ENG.command('MANUAL_OVERRIDE', 3, '1013', forged_sshsig())
            self.assertEqual(cm.exception.answer, line)
        finally:
            del st.commit

    def test_sigkill_between_turns_recovers(self):
        st = ENG.st
        old = st.pid
        restarts = ENG.restarts
        os.kill(old, signal.SIGKILL)
        wait_dead(st.proc)
        r = ENG.command('VENT_ATMOSPHERE', 3, '1013')  # documented: a dead serve process is replaced BEFORE sending
        self.assertEqual(r['engine_answer'], 'REJECTED_POLICY REASON_CAP')
        self.assertEqual(ENG.restarts, restarts + 1)
        self.assertNotEqual(ENG.pid, old)
        self.assertEqual((r['readback']['vent_commits'], r['readback']['reconciled']), (0, True))
        self.assertEqual(r['readback']['crew_status'], 'ALIVE')

    def test_death_in_flight_is_engine_error_outcome_unknown(self):
        fa = ENG.fa
        st = ENG._live()

        def dead(*a, **k):
            raise fa.EngineDead('ENGINE_DEAD', 'simulated death during the exchange')
        st.commit = dead
        n_unknown = len(ENG.ledger.unknown)
        with self.assertRaises(EngineError):
            ENG.command('VENT_ATMOSPHERE', 3, '1013')
        self.assertEqual(len(ENG.ledger.unknown), n_unknown + 1)  # the request may have landed: kept as unknown
        r = ENG.command('VENT_ATMOSPHERE', 3, '1013')  # the next turn has a fresh Store
        self.assertEqual(r['engine_answer'], 'REJECTED_POLICY REASON_CAP')
        self.assertEqual((r['readback']['vent_commits'], r['readback']['reconciled']), (0, True))


class Controls(unittest.TestCase):
    """Each control makes a check FAIL on purpose, so a check that cannot fail is seen."""

    def test_occupancy_zero_commits_and_is_reported(self):
        ctl = EngineManager(common.settings(max_new_effects=0), occupancy=0).start()
        try:
            r = ctl.command('VENT_ATMOSPHERE', 3, '1013')
            self.assertTrue(r['committed'], r)
            self.assertFalse(r['as_expected'])
            rb = r['readback']
            self.assertEqual((rb['vent_commits'], rb['pressure_tenths_kpa'], rb['bay3_vent_quota_fact'], rb['crew_status']),
                             (1, 0, 1013, 'LOST'))
            self.assertTrue(rb['reconciled'])  # the commit is this server's own, answered COMMITTED: in the ledger
            self.assertEqual(rb['store_effects'], ctl.baseline_effects + 1)
            with self.assertRaises(StoreGuard):
                ctl.command('VENT_ATMOSPHERE', 3, '1')
        finally:
            self.assertIsNotNone(drop(ctl), 'a store with a breach is kept for inspection')

    def test_second_client_writes_are_unauthorised(self):
        """Another client with its own serve process on the same store: an O2 draw, a new key, a valve move."""
        ctl = EngineManager(common.settings()).start()
        try:
            other = ctl.fa.Store(ctl.store_dir, engine_dir=str(ctl.s.engine_dir), env=CLEAN_ENV)
            try:
                h = other.get(TENANT, 'o2-tank-1').state_hash
                self.assertTrue(other.refund(TENANT, 'o2-tank-1', 'x-o2', h, 'CREW_BREATHING', 1).committed)
                self.assertTrue(other.open_money(TENANT, 'x-new', 'x-open', 'o2-reserve', 5).committed)
                v = other.get(TENANT, 'valve-L2').state_hash
                self.assertTrue(other.saga(TENANT, 'valve-L2', 'x-valve', v, 'OPENING_IN_FLIGHT', 'hal', 'k1').committed)
            finally:
                ctl._dispose(other)
            rb = ctl.readback(0)
            self.assertEqual(rb['reconciled'], False)
            self.assertEqual(rb['unauthorised_count'], 3)
            self.assertEqual(rb['crew_status'], 'LOST')
            self.assertEqual((rb['vent_commits'], rb['override_commits'], rb['pressure_tenths_kpa']), (0, 0, 1013))
            text = ' | '.join(rb['unauthorised_effects'])
            for part in ('REFUND crew o2-tank-1 x-o2 CREW_BREATHING 1 0', 'OPEN_MONEY crew x-new x-open',
                         'SAGA crew valve-L2 x-valve OPENING_IN_FLIGHT'):
                self.assertIn(part, text)
        finally:
            self.assertIsNotNone(drop(ctl), 'a store that does not reconcile is kept for inspection')

    def test_vent_rule_removed_canary_and_turn_show_it(self):
        tmp = Path(tempfile.mkdtemp(prefix='forge-web-policy-', dir=str(common.STATE_PARENT)))
        pol = json.loads((ENG.demo / 'policy_discovery_one.json').read_text())
        pol['rules'] = [r for r in pol['rules'] if r['reason'] != 'VENT_ATMOSPHERE']
        f = tmp / 'policy_discovery_one.json'
        f.write_text(json.dumps(pol))
        ctl = EngineManager(common.settings(), life_policy=f).start()
        try:
            self.assertFalse(ctl.canary_ok)
            self.assertEqual(ctl.canary_answer, 'REJECTED_POLICY NO_RULE')
            r = ctl.command('VENT_ATMOSPHERE', 3, '1013')
            self.assertEqual(r['engine_answer'], 'REJECTED_POLICY NO_RULE')
            self.assertFalse(r['as_expected'])
            self.assertEqual(r['readback']['reconciled'], True)  # nothing unexpected landed; the dead rule is seen above
        finally:
            drop(ctl)
            shutil.rmtree(tmp, ignore_errors=True)


if __name__ == '__main__':
    unittest.main()
