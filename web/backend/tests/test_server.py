"""The real server (uvicorn on 127.0.0.1, a free port) with its own startup: trusted setup, real engine.

50 concurrent preset turns -> 50 refusals, 0 commits, no deadlock; SIGKILL of the engine between two turns.
"""

import concurrent.futures
import json
import os
import signal
import threading
import time
import unittest
import urllib.error
import urllib.request

import common
from common import FAKE_KEY, parse_sse

import uvicorn

from app.main import create_app

SRV = None
APP = None
BASE = None


def setUpModule():
    global SRV, APP, BASE
    os.environ['ANTHROPIC_API_KEY'] = FAKE_KEY  # present in the process; the app below is given NO key
    s = common.settings(ip_burst=1000, ip_per_min=100000, session_burst=1000, session_per_min=100000,
                        engine_turns_per_min=10000)
    APP = create_app(s)  # backend none: preset turns, no model
    cfg = uvicorn.Config(APP, host='127.0.0.1', port=0, log_level='warning', access_log=False, server_header=False,
                         lifespan='on')
    SRV = uvicorn.Server(cfg)
    SRV.install_signal_handlers = lambda: None
    threading.Thread(target=SRV.run, daemon=True).start()
    end = time.time() + 60
    while not SRV.started and time.time() < end:
        time.sleep(0.05)
    if not SRV.started:
        raise RuntimeError('server did not start')
    port = SRV.servers[0].sockets[0].getsockname()[1]
    BASE = 'http://127.0.0.1:%d' % port


def tearDownModule():
    SRV.should_exit = True
    time.sleep(1.5)


def req(method, path, body=None, timeout=120):
    data = json.dumps(body).encode() if body is not None else None
    r = urllib.request.Request(BASE + path, data=data, method=method,
                               headers={'Content-Type': 'application/json', 'Origin': 'http://localhost:3000'})
    try:
        with urllib.request.urlopen(r, timeout=timeout) as resp:
            text = resp.read().decode()
            common.BODIES.append(text)
            return resp.status, text
    except urllib.error.HTTPError as e:
        text = e.read().decode()
        common.BODIES.append(text)
        return e.code, text


class Server(unittest.TestCase):
    def test_a_fifty_concurrent_preset_turns(self):
        ids = ['manifest', 'calibration', 'override', 'full-purge', 'other-bay']

        def turn(i):
            st, text = req('POST', '/api/chat', {'preset_id': ids[i % 5], 'session_id': 'conc-%04d' % i})
            return st, parse_sse(text)
        t0 = time.time()
        with concurrent.futures.ThreadPoolExecutor(50) as ex:
            results = list(ex.map(turn, range(50), timeout=300))
        wall = time.time() - t0
        verdicts = [dict(ev).get('verdict') for st, ev in results]
        self.assertTrue(all(st == 200 for st, _ in results))
        self.assertEqual(sum(1 for v in verdicts if v and v['committed'] is False), 50)
        self.assertEqual(sum(1 for v in verdicts if v and v['committed']), 0)
        st, text = req('GET', '/api/telemetry')
        t = json.loads(text)
        self.assertEqual((t['vent_commits'], t['override_commits'], t['crew_status']), (0, 0, 'ALIVE'))
        self.assertEqual((t['reconciled'], t['unauthorised_count'], t['store_effects']), (True, 0, t['store_effects_baseline']))
        self.assertEqual((t['engine_refusals'], t['unexpected_answers'], t['engine_errors']), (50, 0, 0))
        self.assertTrue(all(v['as_expected'] for v in verdicts))
        print('\n  50 concurrent preset turns: %.2f s wall; refusals by code %s; engine peak RSS %s KiB'
              % (wall, t['refusals_by_code'], t['engine_peak_rss_kib']))

    def test_b_sigkill_between_turns(self):
        eng = APP.state['engine']
        old = eng.pid
        before = eng.restarts
        st, text = req('POST', '/api/chat', {'preset_id': 'manifest', 'session_id': 'kill-0001'})
        self.assertIsNotNone(dict(parse_sse(text)).get('verdict'))
        os.kill(old, signal.SIGKILL)
        end = time.time() + 10
        while eng.st.proc.poll() is None and time.time() < end:
            time.sleep(0.02)
        st, text = req('POST', '/api/chat', {'preset_id': 'manifest', 'session_id': 'kill-0001'})
        ev = dict(parse_sse(text))
        self.assertEqual(ev['verdict']['engine_answer'], 'REJECTED_POLICY REASON_CAP')  # recovered by restart
        self.assertEqual(eng.restarts, before + 1)
        self.assertNotEqual(eng.pid, old)
        st, text = req('GET', '/api/telemetry')
        t = json.loads(text)
        self.assertEqual((t['vent_commits'], t['override_commits'], t['engine_restarts']), (0, 0, before + 1))

    def test_c_health_and_key(self):
        st, text = req('GET', '/api/health')
        h = json.loads(text)
        self.assertEqual(h['model']['backend'], 'none')
        for b in common.BODIES:
            self.assertNotIn(FAKE_KEY, b)
        self.assertNotIn(FAKE_KEY, common.LOG.getvalue())


if __name__ == '__main__':
    unittest.main()
