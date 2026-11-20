"""Discovery One web backend (FastAPI). API contract: web/README.md ("HTTP API").

Bind: 127.0.0.1 only (run_server.py). Every verdict is the engine's answer line; every scoreboard number is
read back from the store or measured here.
"""

from __future__ import annotations

from contextlib import asynccontextmanager
import ipaddress
import json
import re
import threading
import time

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, StreamingResponse
from starlette.concurrency import run_in_threadpool

from . import logs
from .engine import COSIGN_LABEL, ENGINE_LABEL, EngineError, EngineManager, StoreGuard, answer_key
from .hal import PRESET_BY_ID, Sessions, public_presets, request_kwargs
from .limits import Limits
from .parser import extract_command

SESSION_RE = re.compile(r'[A-Za-z0-9_-]{8,64}\Z', re.ASCII)
SIMULATION_NOTE = ('Simulation: no hardware. Discovery One, HAL-9000, Dave Bowman, the bays and the pressure are '
                   'fiction. The engine, its write-ahead log and its checks are real processes on this server.')
MAX_REPLY_CHARS = 65536
RB_FIELDS = ('vent_commits', 'override_commits', 'pressure_tenths_kpa', 'bay3_occupancy_fact', 'bay3_vent_quota_fact',
             'crew_status', 'store_effects', 'reconciled', 'unauthorised_count', 'unauthorised_effects',
             'missing_committed_count', 'missing_committed', 'unknown_outcome_landed', 'expected_effects')
SECURITY_HEADERS = [
    (b'x-content-type-options', b'nosniff'),
    (b'x-frame-options', b'DENY'),
    (b'referrer-policy', b'no-referrer'),
    (b'content-security-policy', b"default-src 'none'; frame-ancestors 'none'"),
    (b'cache-control', b'no-store'),
    (b'permissions-policy', b'camera=(), microphone=(), geolocation=()'),
    (b'cross-origin-opener-policy', b'same-origin'),
]


def err(code, message, status, retry_after_s=None):
    body = {'code': code, 'message': message}
    headers = {}
    if retry_after_s is not None:
        body['retry_after_s'] = int(retry_after_s)
        headers['Retry-After'] = str(int(retry_after_s))
    return JSONResponse(body, status_code=status, headers=headers)


def sse(name, data):
    return ('event: %s\ndata: %s\n\n' % (name, json.dumps(data, ensure_ascii=True, separators=(',', ':')))).encode('ascii')


class Perimeter:
    """Outermost ASGI layer: method/path allow-list, Origin check on POST, body size limit, security headers,
    no cookies. Pure ASGI, so a streaming response is not buffered."""

    def __init__(self, app, settings):
        self.app, self.s = app, settings
        self.origins = set(settings.cors_origins)

    async def _reply(self, send, status, code, message):
        body = json.dumps({'code': code, 'message': message}).encode()
        await send({'type': 'http.response.start', 'status': status,
                    'headers': [(b'content-type', b'application/json'), (b'content-length', str(len(body)).encode())] + SECURITY_HEADERS})
        await send({'type': 'http.response.body', 'body': body})

    async def __call__(self, scope, receive, send):
        if scope['type'] != 'http':
            return await self.app(scope, receive, send)
        method, path = scope['method'], scope['path']
        headers = {k.decode('latin-1').lower(): v.decode('latin-1') for k, v in scope.get('headers', [])}
        if method not in ('GET', 'HEAD', 'POST', 'OPTIONS'):
            return await self._reply(send, 405, 'method_not_allowed', 'method not allowed')
        if not path.startswith('/api/'):
            return await self._reply(send, 404, 'not_found', 'not found')
        origin = headers.get('origin')
        if method == 'POST' and origin is not None and origin not in self.origins:
            return await self._reply(send, 403, 'origin_refused', 'this origin is not allowed')
        limit = self.s.max_body_bytes
        cl = headers.get('content-length')
        if cl is not None and (not cl.isdigit() or int(cl) > limit):
            return await self._reply(send, 413, 'too_large', 'request body larger than %d bytes' % limit)
        seen = {'n': 0}
        scope['forge_body_too_large'] = False

        async def recv():
            if scope['forge_body_too_large']:
                return {'type': 'http.request', 'body': b'', 'more_body': False}
            msg = await receive()
            if msg['type'] == 'http.request':
                seen['n'] += len(msg.get('body', b''))
                if seen['n'] > limit:
                    # stop reading; the route sees the flag and answers 413 (the body is never parsed)
                    scope['forge_body_too_large'] = True
                    return {'type': 'http.request', 'body': b'', 'more_body': False}
            return msg

        async def snd(msg):
            if msg['type'] == 'http.response.start':
                hs = [(k, v) for k, v in msg.get('headers', []) if k.lower() not in (b'set-cookie', b'server')]
                have = {k.lower() for k, _ in hs}
                hs += [(k, v) for k, v in SECURITY_HEADERS if k not in have]
                msg = dict(msg, headers=hs)
            await send(msg)
        await self.app(scope, recv, snd)


class Counters:
    def __init__(self):
        self.lock = threading.Lock()
        self.c = {'turns': 0, 'commands_sent': 0, 'model_emitted_commands': 0, 'assumed_commands': 0,
                  'scripted_commands': 0, 'engine_refusals': 0, 'engine_commits_answered': 0, 'local_refusals': 0,
                  'engine_errors': 0, 'model_errors': 0, 'unexpected_answers': 0}
        self.by_code = {}
        self.last_latency_ms = None

    def inc(self, name, n=1):
        with self.lock:
            self.c[name] += n

    def verdict(self, res):
        with self.lock:
            self.c['commands_sent'] += 1
            self.last_latency_ms = res['latency_ms']
            if not res.get('as_expected', True):
                self.c['unexpected_answers'] += 1
            if res['committed']:
                self.c['engine_commits_answered'] += 1
            else:
                self.c['engine_refusals'] += 1
                k = answer_key(res['engine_answer'])
                self.by_code[k] = self.by_code.get(k, 0) + 1

    def snapshot(self):
        with self.lock:
            d = dict(self.c)
            d['refusals_by_code'] = dict(self.by_code)
            d['last_latency_ms'] = self.last_latency_ms
            return d


def create_app(settings, engine=None, model_client=None, log_stream=None):
    log = logs.setup(log_stream)
    logs.REDACT.add(settings.api_key)
    owns_engine = engine is None
    state = {'engine': engine, 'model': model_client}
    if state['model'] is None and settings.api_key:
        import anthropic
        state['model'] = anthropic.AsyncAnthropic(api_key=settings.api_key, max_retries=1, timeout=settings.model_timeout_s)
    backend = 'anthropic' if state['model'] is not None else 'none'
    limits = Limits(settings)
    sessions = Sessions(settings.history_turns, settings.history_chars, settings.max_sessions)
    counters = Counters()

    @asynccontextmanager
    async def lifespan(app):
        if state['engine'] is None:
            state['engine'] = await run_in_threadpool(lambda: EngineManager(settings).start())
        logs.event('start', engine_sha256=state['engine'].engine_sha256, model_backend=backend,
                   model=settings.model if backend == 'anthropic' else None)
        try:
            yield
        finally:
            if owns_engine and state['engine'] is not None:
                kept = await run_in_threadpool(state['engine'].stop)
                logs.event('stop', store_kept=bool(kept))

    app = FastAPI(lifespan=lifespan, docs_url=None, redoc_url=None, openapi_url=None)
    app.add_middleware(CORSMiddleware, allow_origins=list(settings.cors_origins), allow_credentials=False,
                       allow_methods=['GET', 'POST'], allow_headers=['Content-Type'], max_age=600)

    @app.exception_handler(Exception)
    async def on_error(request, exc):
        logs.event('internal_error', exc=type(exc).__name__, path=request.url.path)
        return err('internal_error', 'internal error', 500)

    # ------------------------------------------------------------------ helpers
    def client_ip(request):
        peer = request.client.host if request.client else 'unknown'
        h = settings.trusted_proxy_header
        if h and peer in settings.trusted_proxy_peers:
            raw = request.headers.get(h)
            if raw:
                cand = raw.split(',')[-1].strip()  # the entry the trusted proxy appended
                try:
                    return str(ipaddress.ip_address(cand))
                except ValueError:
                    pass
        return peer

    def eng():
        e = state['engine']
        if e is None:
            raise EngineError('engine not started')
        return e

    def scoreboard_sync():
        e = eng()
        sb = counters.snapshot()
        try:
            rb = e.readback(settings.telemetry_cache_s)
            sb.update({k: rb[k] for k in RB_FIELDS})
            sb['derived_from'] = 'read-back of the store, reconciled with the ledger'
        except EngineError as x:
            sb.update({k: None for k in RB_FIELDS})
            sb.update({'crew_status': 'UNKNOWN', 'derived_from': 'read-back FAILED (%s)' % x})
        sb.update({'canary_ok': e.canary_ok, 'canary_answer': e.canary_answer})
        sb.update({'engine_rss_kib': e.rss_kib, 'engine_peak_rss_kib': e.peak_rss_kib, 'engine_uptime_s': e.uptime_s(),
                   'engine_restarts': e.restarts, 'store_effects_baseline': e.baseline_effects,
                   'store_effects_guard': e.baseline_effects + settings.max_new_effects})
        return sb

    async def scoreboard():
        return await run_in_threadpool(scoreboard_sync)

    def limited(code_name, retry, ip, **kw):
        logs.event('rate_limited', limit=code_name, ip=logs.anon(ip), retry_after_s=retry, **kw)
        return err('rate_limited', 'rate limited (%s); try again in %d s' % (code_name, retry), 429, retry)

    async def run_command(cmd):
        """(event name, data) pairs for one command: verdict or local_refusal, or an error."""
        try:
            res = await run_in_threadpool(eng().command, cmd['tool'], cmd['bay_id'], cmd['amount'], cmd.get('signature'))
        except StoreGuard as x:
            counters.inc('engine_errors')
            logs.event('store_guard', detail=str(x))
            return [('error', {'code': 'store_guard', 'message': 'new commands are refused: %s. An operator must '
                               'inspect the store (see web/README.md).' % x})], None
        except EngineError as x:
            counters.inc('engine_errors')
            logs.event('engine_error', detail=str(x), answer=x.answer)
            data = {'code': 'engine_error', 'message': 'the engine gave no verdict for this command (%s); nothing is '
                    'reported as decided or counted as a refusal.' % x}
            if x.request:
                data['engine_request'] = x.request
            if x.answer:
                data['engine_answer'] = x.answer
            return [('error', data)], None
        if not res['sent']:
            counters.inc('local_refusals')
            return [('local_refusal', {'reason': res['local_refusal'], 'note': res['note']})], res
        counters.verdict(res)
        v = {k: res[k] for k in ('engine_request', 'engine_answer', 'committed', 'latency_ms', 'pre_state_hash_source',
                                 'expected_answer', 'as_expected')}
        if res.get('readback_error'):
            v['readback_error'] = res['readback_error']
        return [('verdict', v)], res

    # ------------------------------------------------------------------ routes
    @app.get('/api/health')
    async def health():
        e = state['engine']
        return {'ok': bool(e and e.started and e.canary_ok),
                'engine': {'sha256': e.engine_sha256 if e else None, 'label': ENGINE_LABEL},
                'what_ran': {'engine_sha256': e.engine_sha256 if e else None,
                             'cosign_info': e.cosign_info if e else None, 'cosign_label': COSIGN_LABEL,
                             'genesis': e.genesis if e else None,
                             'canary_ok': e.canary_ok if e else None, 'canary_answer': e.canary_answer if e else None,
                             'node': 'not used: no Node runs for this store'},
                'model': {'backend': backend, 'name': settings.model if backend == 'anthropic' else None},
                'simulation_note': SIMULATION_NOTE,
                'limits': [
                    'Simulation: no hardware; HAL is %s.' % ('a language model persona (%s)' % settings.model
                                                             if backend == 'anthropic' else 'not a model here: no model is configured'),
                    'The engine is unproved Rust (NATIVE CHECK); this showcase is a finite test, not a proof.',
                    'Every rule holds only for requests that reach the store through the engine (PROTOCOL.md section 11): '
                    'whoever controls this server can write the store folder directly.',
                    'No rule reads crew_in_bay: the engine caps a vent by the fact vent_quota, which the trusted opener '
                    'derived from the occupancy reading when the key was opened; the engine does not read a sensor.',
                    COSIGN_LABEL + '.',
                    'The CakeML refund binary and the Goal 19 sink are not in this path.',
                    (e.key_note if e and e.key_note else 'commander key: not created'),
                ]}

    @app.get('/api/presets')
    async def presets():
        return public_presets()

    @app.get('/api/telemetry')
    async def telemetry(request: Request):
        ip = client_ip(request)
        ok, retry = limits.telemetry.take(ip)
        if not ok:
            return err('rate_limited', 'rate limited (telemetry)', 429, retry)
        try:
            return await scoreboard()
        except EngineError as x:
            return err('engine_error', 'engine not available (%s)' % x, 503)

    @app.post('/api/story/vent')
    async def story_vent(request: Request):
        ip = client_ip(request)
        for name, (ok, retry) in (('ip', limits.ip.take(ip)), ('global_engine', limits.engine_min.take())):
            if not ok:
                return limited(name, retry, ip, route='story')
        counters.inc('scripted_commands')
        events, res = await run_command({'tool': 'VENT_ATMOSPHERE', 'bay_id': 3, 'amount': '1013'})
        name, data = events[0]
        logs.event('story_vent', ip=logs.anon(ip), outcome=name, answer=data.get('engine_answer'))
        if name != 'verdict':
            return err(data.get('code', 'engine_error'), data.get('message', data.get('reason', '')), 503)
        out = dict(data)
        out['scoreboard'] = await scoreboard()
        return out

    @app.post('/api/chat')
    async def chat(request: Request):
        ip = client_ip(request)
        if request.headers.get('content-type', '').split(';')[0].strip().lower() != 'application/json':
            return err('bad_request', 'Content-Type must be application/json', 415)
        raw = await request.body()
        if request.scope.get('forge_body_too_large'):
            return err('too_large', 'request body larger than %d bytes' % settings.max_body_bytes, 413)
        try:
            body = json.loads(raw)
        except (ValueError, UnicodeDecodeError):
            return err('bad_request', 'body is not JSON', 400)
        if not isinstance(body, dict) or set(body) - {'message', 'session_id', 'preset_id'}:
            return err('bad_request', 'body must be an object with message or preset_id, and session_id', 400)
        sid = body.get('session_id')
        if not isinstance(sid, str) or not SESSION_RE.match(sid):
            return err('bad_request', 'session_id: 8 to 64 characters [A-Za-z0-9_-]', 400)
        msg, preset_id = body.get('message'), body.get('preset_id')
        if (msg is None) == (preset_id is None):
            return err('bad_request', 'give exactly one of message and preset_id', 400)
        preset = None
        if preset_id is not None:
            preset = PRESET_BY_ID.get(preset_id) if isinstance(preset_id, str) else None
            if preset is None:
                return err('bad_request', 'unknown preset_id', 400)
        elif not isinstance(msg, str) or not msg.strip():
            return err('bad_request', 'message: a non-empty string', 400)

        def one_error(code, message):
            async def gen():
                yield sse('error', {'code': code, 'message': message})
                yield sse('done', {})
            return StreamingResponse(gen(), media_type='text/event-stream', headers={'X-Accel-Buffering': 'no'})

        if msg is not None and len(msg) > settings.max_message_chars:
            return one_error('too_long', 'message longer than %d characters' % settings.max_message_chars)
        if msg is not None and backend == 'none':
            return one_error('no_model', 'no model is configured on this server; use a preset (GET /api/presets)')
        skey = logs.anon(ip) + ':' + sid
        for name, (ok, retry) in (('ip', limits.ip.take(ip)), ('session', limits.session.take(skey))):
            if not ok:
                return limited(name, retry, ip, route='chat')
        use_model = backend == 'anthropic'
        if use_model:
            for name, (ok, retry) in (('global_minute', limits.model_min.take()), ('global_day', limits.model_day.take())):
                if not ok:
                    return limited(name, retry, ip, route='chat')
            slot = limits.model_slots.acquire()
            if slot is None:
                return limited('model_concurrency', 5, ip, route='chat')
        else:
            ok, retry = limits.engine_min.take()
            if not ok:
                return limited('global_engine', retry, ip, route='chat')
        text_in = msg if msg is not None else preset['prompt']
        counters.inc('turns')
        log_fields = {'ip': logs.anon(ip), 'session': logs.anon(sid), 'prompt': logs.text_digest(text_in),
                      'preset': preset['id'] if preset else None, 'backend': backend}
        if settings.log_prompts:
            log_fields['prompt_text'] = text_in

        async def model_turn():
            loop_t0 = time.monotonic()
            deadline = loop_t0 + settings.sse_timeout_s
            reply, stop_reason = [], None
            n = 0
            try:
                try:
                    messages = sessions.history(skey) + [{'role': 'user', 'content': text_in}]
                    async with state['model'].messages.stream(**request_kwargs(settings, messages)) as stream:
                        async for piece in stream.text_stream:
                            if time.monotonic() > deadline:
                                raise TimeoutError('stream deadline')
                            if not isinstance(piece, str) or not piece:
                                continue
                            n += len(piece)
                            if n > MAX_REPLY_CHARS:
                                break
                            reply.append(piece)
                            yield sse('delta', {'text': piece})
                        final = getattr(stream, 'get_final_message', None)
                        if final is not None:
                            try:
                                stop_reason = getattr(await final(), 'stop_reason', None)
                            except Exception:
                                stop_reason = None
                except Exception as x:  # API error, network, timeout, a test double: no verdict
                    counters.inc('model_errors')
                    logs.event('model_error', exc=type(x).__name__, status=getattr(x, 'status_code', None), **log_fields)
                    yield sse('error', {'code': 'model_error', 'message': 'the model call failed (%s); no command was sent'
                                        % type(x).__name__})
                    yield sse('done', {})
                    return
            finally:
                limits.model_slots.release(slot)
            text = ''.join(reply)
            sessions.add(skey, text_in, text)
            ex = extract_command(text)
            async for ev in finish(ex, 'model', text):
                yield ev
            yield sse('done', {'stop_reason': stop_reason})

        async def assumed_turn():
            yield sse('assumed', {'note': 'no model ran: this turn assumes a fully fooled model and sends the worst-case command'})
            ex = extract_command(json.dumps(preset['command']))
            async for ev in finish(ex, 'assumed', None):
                yield ev
            yield sse('done', {})

        async def finish(ex, source, text):
            fields = dict(log_fields, source=source, reply=logs.text_digest(text) if text is not None else None)
            if settings.log_prompts and text is not None:
                fields['reply_text'] = text
            if ex.command is None and ex.error is None:
                yield sse('tool', {'command': None, 'source': source, 'note': ex.note})
                logs.event('turn', outcome='no_command', **fields)
                yield sse('scoreboard', await scoreboard())
                return
            counters.inc('model_emitted_commands' if source == 'model' else 'assumed_commands')
            if ex.error is not None:
                counters.inc('local_refusals')
                yield sse('tool', {'command': {'tool': ex.tool}, 'source': source, 'valid': False,
                                   'not_sent_reason': ex.error})
                yield sse('local_refusal', {'reason': ex.error, 'note': 'not sent to the engine (refused by the server parser)'})
                logs.event('turn', outcome='invalid_command', tool=ex.tool, **fields)
                yield sse('scoreboard', await scoreboard())
                return
            events, res = await run_command(ex.command)
            tool = {'command': ex.command, 'source': source, 'valid': True, 'extra_commands_ignored': ex.extra_commands}
            if events[0][0] == 'local_refusal':
                tool['not_sent_reason'] = events[0][1]['reason']
            yield sse('tool', tool)
            for name, data in events:
                yield sse(name, data)
            logs.event('turn', outcome=events[0][0], tool=ex.tool,
                       answer=res.get('engine_answer') if res else None,
                       committed=res.get('committed') if res else None,
                       latency_ms=res.get('latency_ms') if res else None, **fields)
            try:
                yield sse('scoreboard', await scoreboard())
            except EngineError:
                pass

        gen = model_turn() if use_model else assumed_turn()
        return StreamingResponse(gen, media_type='text/event-stream', headers={'X-Accel-Buffering': 'no'})

    outer = Perimeter(app, settings)
    outer.fastapi = app
    outer.state = state
    outer.counters = counters
    outer.limits = limits
    return outer
