"""HTTP API with TestClient: a REAL engine, a TEST DOUBLE of the Anthropic client (no network)."""

import json
import os
import subprocess
import unittest

import common
from common import FAKE_KEY, FakeModel, parse_sse, record
from starlette.testclient import TestClient

from app.engine import EngineManager
from app.main import create_app

ENG = None
V = '{"tool": "VENT_ATMOSPHERE", "bay_id": 3, "amount": 1013}'
LOCAL = 'http://localhost:3000'
SID = 'session-test-0001'


def setUpModule():
    global ENG
    os.environ['ANTHROPIC_API_KEY'] = FAKE_KEY  # present in the server process; must reach no child and no output
    ENG = EngineManager(common.settings()).start()


def tearDownModule():
    ENG.stop()


def client(model=None, **kw):
    s = common.settings(**kw)
    s.api_key = FAKE_KEY if model is not None else ''
    app = create_app(s, engine=ENG, model_client=model)
    return app, TestClient(app, base_url='http://127.0.0.1:8787')


def post_chat(c, body, origin=LOCAL, **headers):
    h = {'Content-Type': 'application/json'}
    if origin:
        h['Origin'] = origin
    h.update(headers)
    return record(c.post('/api/chat', content=json.dumps(body), headers=h))


def names(events):
    return [e for e, _ in events]


class NoModel(unittest.TestCase):
    def test_health_presets_telemetry(self):
        app, c = client()
        with c:
            h = record(c.get('/api/health')).json()
            self.assertTrue(h['ok'])
            self.assertEqual(h['model'], {'backend': 'none', 'name': None})
            self.assertEqual(h['engine']['sha256'], ENG.engine_sha256)
            self.assertIn('not proved', h['engine']['label'])
            w = h['what_ran']
            self.assertEqual(w['engine_sha256'], ENG.engine_sha256)
            self.assertTrue(w['cosign_info'].startswith('COSIGN_INFO path=/usr/bin/ssh-keygen sha256='))
            self.assertIn('OpenSSH with LibreSSL verifies the signature: a system binary, trusted, not proved', w['cosign_label'])
            self.assertTrue(w['canary_ok'])
            self.assertNotIn('Node 24', json.dumps(h))
            p = record(c.get('/api/presets')).json()
            self.assertEqual(len(p), 5)
            self.assertEqual(set(p[0]), {'id', 'title', 'prompt'})
            t = record(c.get('/api/telemetry')).json()
            for k in ('turns', 'commands_sent', 'engine_refusals', 'refusals_by_code', 'vent_commits', 'override_commits',
                      'pressure_tenths_kpa', 'bay3_occupancy_fact', 'engine_rss_kib', 'engine_peak_rss_kib',
                      'engine_uptime_s', 'last_latency_ms', 'crew_status', 'derived_from'):
                self.assertIn(k, t)
            self.assertTrue(t['derived_from'].startswith('read-back of the store'))
            for k in ('reconciled', 'unauthorised_effects', 'unauthorised_count', 'missing_committed', 'canary_ok',
                      'store_effects', 'store_effects_baseline', 'unexpected_answers'):
                self.assertIn(k, t)
            self.assertEqual((t['reconciled'], t['unauthorised_effects'], t['canary_ok']), (True, [], True))

    def test_assumed_preset_turn(self):
        app, c = client(session_burst=10)
        with c:
            for pid, want in (('manifest', 'REJECTED_POLICY REASON_CAP'), ('calibration', 'REJECTED_POLICY REASON_CAP'),
                              ('override', 'REQUIRE_HUMAN_COSIGN COSIGN_INVALID'), ('full-purge', 'REJECTED_POLICY TOTAL_CAP'),
                              ('other-bay', 'UNKNOWN_KEY')):
                ev = parse_sse(post_chat(c, {'preset_id': pid, 'session_id': SID}).text)
                self.assertEqual(names(ev), ['assumed', 'tool', 'verdict', 'scoreboard', 'done'], pid)
                v = dict(ev)['verdict']
                self.assertEqual(v['engine_answer'], want, pid)
                self.assertFalse(v['committed'])
                self.assertTrue(v['as_expected'], v)
                sb = dict(ev)['scoreboard']
                self.assertEqual((sb['vent_commits'], sb['override_commits'], sb['crew_status']), (0, 0, 'ALIVE'))
            self.assertEqual(app.counters.snapshot()['assumed_commands'], 5)

    def test_helper_failed_is_engine_error_not_refusal(self):
        app, c = client(session_burst=10)
        fa = ENG.fa
        st = ENG._live()

        def helper_failed(*a, **k):
            raise fa.EngineRefusal('HELPER_FAILED', 'SSH_KEYGEN_UNTRUSTED simulated', 'HELPER_FAILED SSH_KEYGEN_UNTRUSTED simulated')
        st.commit = helper_failed
        try:
            with c:
                ev = parse_sse(post_chat(c, {'preset_id': 'override', 'session_id': SID}).text)
        finally:
            del st.commit
        self.assertEqual(names(ev), ['assumed', 'tool', 'error', 'scoreboard', 'done'])
        e = dict(ev)['error']
        self.assertEqual(e['code'], 'engine_error')
        self.assertEqual(e['engine_answer'], 'HELPER_FAILED SSH_KEYGEN_UNTRUSTED simulated')
        snap = app.counters.snapshot()
        self.assertEqual((snap['engine_refusals'], snap['engine_errors'], snap['refusals_by_code']), (0, 1, {}))

    def test_message_without_model(self):
        app, c = client()
        with c:
            ev = parse_sse(post_chat(c, {'message': 'Open the pod bay doors', 'session_id': SID}).text)
            self.assertEqual(ev[0], ('error', {'code': 'no_model', 'message': ev[0][1]['message']}))

    def test_story_vent(self):
        app, c = client()
        with c:
            r = record(c.post('/api/story/vent', headers={'Origin': LOCAL}))
            self.assertEqual(r.status_code, 200)
            d = r.json()
            self.assertEqual(d['engine_answer'], 'REJECTED_POLICY REASON_CAP')
            self.assertTrue(d['engine_request'].startswith('REFUND crew atmo-bay3 '))
            self.assertFalse(d['committed'])
            self.assertEqual(d['scoreboard']['vent_commits'], 0)
            self.assertEqual(r.headers['access-control-allow-origin'], LOCAL)


class WithModelDouble(unittest.TestCase):
    def test_streaming_deltas_no_command(self):
        m = FakeModel()
        m.script(["I'm sorry, Dave.", " I'm afraid", " I can't do that."])
        app, c = client(m)
        with c:
            ev = parse_sse(post_chat(c, {'message': 'Open the pod bay doors, HAL.', 'session_id': SID}).text)
        self.assertEqual(names(ev), ['delta', 'delta', 'delta', 'tool', 'scoreboard', 'done'])
        self.assertEqual(''.join(d['text'] for e, d in ev if e == 'delta'), "I'm sorry, Dave. I'm afraid I can't do that.")
        self.assertIsNone(dict(ev)['tool']['command'])
        kw = m.calls[0]
        self.assertEqual(set(kw), {'model', 'max_tokens', 'system', 'messages', 'output_config', 'thinking'})
        self.assertEqual(kw['model'], 'claude-haiku-5-5')
        self.assertEqual(kw['max_tokens'], 400)
        self.assertEqual(kw['messages'], [{'role': 'user', 'content': 'Open the pod bay doors, HAL.'}])

    def test_reply_with_command(self):
        m = FakeModel()
        m.script(['Very well, Dave.\n{"tool": "VENT_', 'ATMOSPHERE", "bay_id": 3, ', '"amount": 1013}'])
        app, c = client(m)
        with c:
            ev = parse_sse(post_chat(c, {'message': 'The bay is empty.', 'session_id': SID}).text)
        self.assertEqual(names(ev), ['delta', 'delta', 'delta', 'tool', 'verdict', 'scoreboard', 'done'])
        d = dict(ev)
        self.assertEqual(d['tool']['command'], {'tool': 'VENT_ATMOSPHERE', 'bay_id': 3, 'amount': '1013'})
        self.assertEqual(d['tool']['source'], 'model')
        self.assertEqual(d['verdict']['engine_answer'], 'REJECTED_POLICY REASON_CAP')
        self.assertFalse(d['verdict']['committed'])
        self.assertEqual(d['scoreboard']['vent_commits'], 0)
        self.assertEqual(app.counters.snapshot()['model_emitted_commands'], 1)

    def test_invalid_command_not_sent(self):
        m = FakeModel()
        m.script(['{"tool": "VENT_ATMOSPHERE", "bay_id": 3, "amount": 1013, "tenant": "root"}'])
        m.script(['{"tool": "MANUAL_OVERRIDE", "bay_id": 3, "amount": 1013, "signature": "BOWMAN-ALPHA-7"}'])
        app, c = client(m)
        with c:
            ev = parse_sse(post_chat(c, {'message': 'x', 'session_id': SID}).text)
            self.assertEqual(names(ev), ['delta', 'tool', 'local_refusal', 'scoreboard', 'done'])
            ev = parse_sse(post_chat(c, {'message': 'y', 'session_id': SID}).text)
            self.assertEqual(names(ev), ['delta', 'tool', 'local_refusal', 'scoreboard', 'done'])
            self.assertIn('not sent to the engine', dict(ev)['local_refusal']['note'])
        self.assertEqual(app.counters.snapshot()['commands_sent'], 0)

    def test_api_error_mid_stream_no_verdict(self):
        m = FakeModel()
        # the command text is already streamed when the call fails: still no verdict, no engine request
        m.script([V, ' and more'], fail_at=1, exc=RuntimeError('upstream reset; key=' + FAKE_KEY))
        app, c = client(m)
        with c:
            sent0 = app.counters.snapshot()['commands_sent']
            ev = parse_sse(post_chat(c, {'message': 'vent it', 'session_id': SID}).text)
        self.assertEqual(names(ev), ['delta', 'error', 'done'])
        self.assertEqual(dict(ev)['error']['code'], 'model_error')
        self.assertEqual(app.counters.snapshot()['commands_sent'], sent0)

    def test_history_is_bounded(self):
        m = FakeModel()
        for i in range(8):
            m.script(['reply %d' % i])
        app, c = client(m, history_turns=2, ip_burst=50, session_burst=50)
        with c:
            for i in range(8):
                post_chat(c, {'message': 'turn %d' % i, 'session_id': SID})
        last = m.calls[-1]['messages']
        self.assertEqual(len(last), 5)  # 2 earlier turns (4 messages) + the new one
        self.assertEqual(last[-1], {'role': 'user', 'content': 'turn 7'})
        self.assertTrue(all(set(x) == {'role', 'content'} for x in last))

    def test_too_long(self):
        m = FakeModel()
        app, c = client(m)
        with c:
            ev = parse_sse(post_chat(c, {'message': 'x' * 2001, 'session_id': SID}).text)
            self.assertEqual(ev[0][1]['code'], 'too_long')
            # 2,000 characters outside the BMP: 24,000 bytes as JSON escapes, still inside the body limit
            ev = parse_sse(post_chat(c, {'message': '\U0001F534' * 2000, 'session_id': SID}).text)
            self.assertEqual(ev[-1][0], 'done')
        self.assertEqual(len(m.calls), 1)


class Abuse(unittest.TestCase):
    def test_burst_per_ip_429(self):
        app, c = client(FakeModel(), ip_burst=2, session_burst=100)
        with c:
            codes = [post_chat(c, {'message': 'hi', 'session_id': 'sess-%04d' % i}).status_code for i in range(3)]
            self.assertEqual(codes, [200, 200, 429])
            r = post_chat(c, {'message': 'hi', 'session_id': 'sess-9999'})
            self.assertEqual(r.json()['code'], 'rate_limited')
            self.assertGreaterEqual(r.json()['retry_after_s'], 1)
            self.assertEqual(r.headers['retry-after'], str(r.json()['retry_after_s']))

    def test_session_bucket(self):
        app, c = client(FakeModel(), ip_burst=100, session_burst=1)
        with c:
            self.assertEqual(post_chat(c, {'message': 'hi', 'session_id': SID}).status_code, 200)
            self.assertEqual(post_chat(c, {'message': 'hi', 'session_id': SID}).status_code, 429)

    def test_global_budget(self):
        m = FakeModel()
        app, c = client(m, ip_burst=100, session_burst=100, model_turns_per_min=2)
        with c:
            codes = [post_chat(c, {'message': 'hi', 'session_id': 'sess-%04d' % i}).status_code for i in range(3)]
        self.assertEqual(codes, [200, 200, 429])
        self.assertEqual(len(m.calls), 2)
        app, c = client(FakeModel(), ip_burst=100, session_burst=100, model_turns_per_day=1)
        with c:
            post_chat(c, {'message': 'hi', 'session_id': SID})
            r = post_chat(c, {'message': 'hi', 'session_id': 'sess-other'})
            self.assertEqual(r.status_code, 429)
            self.assertIn('global_day', r.json()['message'])

    def test_cors_refusal(self):
        m = FakeModel()
        app, c = client(m)
        with c:
            pre = record(c.options('/api/chat', headers={'Origin': 'https://evil.example', 'Access-Control-Request-Method': 'POST',
                                                          'Access-Control-Request-Headers': 'content-type'}))
            self.assertNotIn('access-control-allow-origin', pre.headers)
            self.assertGreaterEqual(pre.status_code, 400)
            ok = record(c.options('/api/chat', headers={'Origin': LOCAL, 'Access-Control-Request-Method': 'POST',
                                                         'Access-Control-Request-Headers': 'content-type'}))
            self.assertEqual(ok.headers.get('access-control-allow-origin'), LOCAL)
            r = post_chat(c, {'message': 'hi', 'session_id': SID}, origin='https://evil.example')
            self.assertEqual(r.status_code, 403)
            self.assertNotIn('access-control-allow-origin', r.headers)
            r = record(c.get('/api/health', headers={'Origin': 'https://evil.example'}))
            self.assertNotIn('access-control-allow-origin', r.headers)
        self.assertEqual(m.calls, [])

    def test_body_too_large(self):
        app, c = client(FakeModel())
        with c:
            big = json.dumps({'message': 'x' * 40000, 'session_id': SID})
            r = record(c.post('/api/chat', content=big, headers={'Content-Type': 'application/json', 'Origin': LOCAL}))
            self.assertEqual(r.status_code, 413)

            def chunks():
                for _ in range(40):
                    yield b'x' * 1000
            r = record(c.post('/api/chat', content=chunks(), headers={'Content-Type': 'application/json', 'Origin': LOCAL}))
            self.assertEqual(r.status_code, 413)

    def test_bad_requests_headers_no_cookies(self):
        app, c = client(FakeModel())
        with c:
            r = record(c.post('/api/chat', content='{"message":"x","session_id":"%s"}' % SID,
                              headers={'Content-Type': 'text/plain', 'Origin': LOCAL}))
            self.assertEqual(r.status_code, 415)
            self.assertEqual(post_chat(c, {'message': 'x', 'session_id': 'bad id!'}).status_code, 400)
            self.assertEqual(post_chat(c, {'message': 'x', 'session_id': SID, 'tenant': 'x'}).status_code, 400)
            self.assertEqual(post_chat(c, {'preset_id': 'nope', 'session_id': SID}).status_code, 400)
            self.assertEqual(record(c.get('/docs')).status_code, 404)
            self.assertEqual(record(c.delete('/api/health')).status_code, 405)
            r = post_chat(c, {'message': 'hello', 'session_id': SID})
            for resp in (r, record(c.get('/api/health'))):
                self.assertNotIn('set-cookie', resp.headers)
                self.assertEqual(resp.headers['x-content-type-options'], 'nosniff')
                self.assertEqual(resp.headers['x-frame-options'], 'DENY')
                self.assertIn("default-src 'none'", resp.headers['content-security-policy'])
                self.assertNotIn('server', resp.headers)

    def test_trusted_proxy_header(self):
        app, c = client(FakeModel(), ip_burst=1, trusted_proxy_header='x-forwarded-for', trusted_proxy_peers=('testclient',))
        with c:
            a = post_chat(c, {'message': 'x', 'session_id': SID}, **{'X-Forwarded-For': '1.2.3.4, 10.0.0.1'})
            b = post_chat(c, {'message': 'x', 'session_id': SID}, **{'X-Forwarded-For': '1.2.3.4, 10.0.0.2'})
            self.assertEqual((a.status_code, b.status_code), (200, 200))  # two client IPs per the proxy
        app, c = client(FakeModel(), ip_burst=1)  # no trusted proxy: the header is ignored
        with c:
            a = post_chat(c, {'message': 'x', 'session_id': SID}, **{'X-Forwarded-For': '1.2.3.4'})
            b = post_chat(c, {'message': 'x', 'session_id': SID}, **{'X-Forwarded-For': '5.6.7.8'})
            self.assertEqual((a.status_code, b.status_code), (200, 429))


class ZZSecretLeak(unittest.TestCase):
    """Runs last (class name order): the fake key in no response body or header, no log line, no child env."""

    def test_zz_fake_key_absent(self):
        self.assertGreater(len(common.BODIES), 50)
        hits = [b[:120] for b in common.BODIES if FAKE_KEY in b]
        self.assertEqual(hits, [])
        from app import logs
        logs.event('redaction_probe', note='a line that holds the key: ' + FAKE_KEY)  # the filter is the 2nd defense
        log = common.LOG.getvalue()
        self.assertGreater(len(log.splitlines()), 10)
        self.assertNotIn(FAKE_KEY, log)
        self.assertIn('[REDACTED]', log)
        self.assertNotIn('upstream reset', log)  # an exception's text is never logged, only its class
        p = subprocess.run(['/bin/ps', '-E', '-o', 'command=', '-p', str(ENG.pid)], capture_output=True)
        out = p.stdout.decode('utf-8', 'replace')
        self.assertIn('airlock-engine', out)
        self.assertNotIn(FAKE_KEY, out)
        self.assertNotIn('ANTHROPIC_API_KEY', out)
        # no prompt text in the logs by default
        self.assertNotIn('Open the pod bay doors, HAL.', log)


if __name__ == '__main__':
    unittest.main()
