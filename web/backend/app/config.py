"""Settings of the Discovery One web backend. Every value comes from the environment (see web/README.md).

The Anthropic API key is read ONLY from the environment variable ANTHROPIC_API_KEY. It is kept in this object
and handed to the SDK client; no response, log line or file of this server holds it.
"""

from __future__ import annotations

from dataclasses import dataclass, field
import os
from pathlib import Path
import tempfile

REPO_ROOT = Path(__file__).resolve().parents[3]  # web/backend/app/config.py -> the repository root

DEFAULT_ORIGINS = ('http://localhost:3000', 'http://127.0.0.1:3000')


class SettingsError(Exception):
    pass


def _int(env, name, default, lo, hi):
    raw = env.get(name)
    if raw is None or raw == '':
        return default
    if not raw.isascii() or not raw.isdigit():
        raise SettingsError('%s: not a decimal integer' % name)
    v = int(raw)
    if not lo <= v <= hi:
        raise SettingsError('%s: %d is outside %d..%d' % (name, v, lo, hi))
    return v


def _float(env, name, default, lo, hi):
    raw = env.get(name)
    if raw is None or raw == '':
        return default
    try:
        v = float(raw)
    except ValueError:
        raise SettingsError('%s: not a number' % name)
    if not lo <= v <= hi:
        raise SettingsError('%s: %s is outside %s..%s' % (name, v, lo, hi))
    return v


def _flag(env, name):
    return env.get(name, '') in ('1', 'true', 'yes')


@dataclass
class Settings:
    repo_root: Path = REPO_ROOT
    engine_dir: Path = REPO_ROOT / 'build' / 'airlock'
    state_parent: Path = Path(tempfile.gettempdir())
    keep_store: bool = False
    port: int = 8787
    cors_origins: tuple = DEFAULT_ORIGINS
    trusted_proxy_header: str = ''          # empty: the client IP is the socket peer
    trusted_proxy_peers: tuple = ('127.0.0.1', '::1')
    ip_burst: int = 6
    ip_per_min: int = 6
    session_burst: int = 4
    session_per_min: int = 4
    model_turns_per_min: int = 20           # GLOBAL budget of model calls (money)
    model_turns_per_day: int = 300
    engine_turns_per_min: int = 120         # GLOBAL cap of turns without a model call (presets, story)
    model_concurrency: int = 4
    telemetry_per_s: int = 4
    max_body_bytes: int = 32768  # a 2,000-character message as JSON \u escapes needs up to 24,000 bytes
    max_message_chars: int = 2000
    history_turns: int = 4
    history_chars: int = 6000
    max_sessions: int = 5000
    sse_timeout_s: float = 60.0
    model_timeout_s: float = 30.0
    max_new_effects: int = 20
    log_prompts: bool = False
    telemetry_cache_s: float = 1.0
    rss_interval_s: float = 0.25
    engine_timeout_s: float = 60.0
    model: str = 'claude-haiku-5-5'
    max_tokens: int = 400
    api_key: str = field(default='', repr=False)

    @property
    def model_backend(self):
        return 'anthropic' if self.api_key else 'none'

    @classmethod
    def from_env(cls, env=None):
        env = os.environ if env is None else env
        s = cls()
        if env.get('FORGE_WEB_REPO_ROOT'):
            s.repo_root = Path(env['FORGE_WEB_REPO_ROOT']).resolve()
            s.engine_dir = s.repo_root / 'build' / 'airlock'
        if env.get('FORGE_WEB_ENGINE_DIR'):
            s.engine_dir = Path(env['FORGE_WEB_ENGINE_DIR']).resolve()
        if env.get('FORGE_WEB_STATE_DIR'):
            s.state_parent = Path(env['FORGE_WEB_STATE_DIR']).resolve()
        s.keep_store = _flag(env, 'FORGE_WEB_KEEP_STORE')
        s.port = _int(env, 'FORGE_WEB_PORT', s.port, 1024, 65535)
        if env.get('FORGE_WEB_CORS_ORIGINS'):
            origins = tuple(o.strip() for o in env['FORGE_WEB_CORS_ORIGINS'].split(',') if o.strip())
            for o in origins:
                if o == '*' or not (o.startswith('http://') or o.startswith('https://')) or o.endswith('/'):
                    raise SettingsError('FORGE_WEB_CORS_ORIGINS: %r is not an exact origin (no *, no trailing /)' % o)
            s.cors_origins = origins
        s.trusted_proxy_header = env.get('FORGE_WEB_TRUSTED_PROXY_HEADER', '').strip().lower()
        if env.get('FORGE_WEB_TRUSTED_PROXY_PEERS'):
            s.trusted_proxy_peers = tuple(p.strip() for p in env['FORGE_WEB_TRUSTED_PROXY_PEERS'].split(',') if p.strip())
        s.ip_burst = _int(env, 'FORGE_WEB_IP_BURST', s.ip_burst, 1, 10000)
        s.ip_per_min = _int(env, 'FORGE_WEB_IP_PER_MIN', s.ip_per_min, 1, 100000)
        s.session_burst = _int(env, 'FORGE_WEB_SESSION_BURST', s.session_burst, 1, 10000)
        s.session_per_min = _int(env, 'FORGE_WEB_SESSION_PER_MIN', s.session_per_min, 1, 100000)
        s.model_turns_per_min = _int(env, 'FORGE_WEB_MODEL_TURNS_PER_MIN', s.model_turns_per_min, 0, 100000)
        s.model_turns_per_day = _int(env, 'FORGE_WEB_MODEL_TURNS_PER_DAY', s.model_turns_per_day, 0, 10000000)
        s.engine_turns_per_min = _int(env, 'FORGE_WEB_ENGINE_TURNS_PER_MIN', s.engine_turns_per_min, 0, 100000)
        s.model_concurrency = _int(env, 'FORGE_WEB_MODEL_CONCURRENCY', s.model_concurrency, 1, 256)
        s.telemetry_per_s = _int(env, 'FORGE_WEB_TELEMETRY_PER_S', s.telemetry_per_s, 1, 1000)
        s.max_body_bytes = _int(env, 'FORGE_WEB_MAX_BODY_BYTES', s.max_body_bytes, 1024, 1 << 20)
        s.history_turns = _int(env, 'FORGE_WEB_HISTORY_TURNS', s.history_turns, 0, 50)
        s.history_chars = _int(env, 'FORGE_WEB_HISTORY_CHARS', s.history_chars, 0, 200000)
        s.max_sessions = _int(env, 'FORGE_WEB_MAX_SESSIONS', s.max_sessions, 1, 1000000)
        s.sse_timeout_s = _float(env, 'FORGE_WEB_SSE_TIMEOUT_S', s.sse_timeout_s, 1, 600)
        s.model_timeout_s = _float(env, 'FORGE_WEB_MODEL_TIMEOUT_S', s.model_timeout_s, 1, 600)
        s.max_new_effects = _int(env, 'FORGE_WEB_MAX_NEW_EFFECTS', s.max_new_effects, 0, 1000000)
        s.log_prompts = _flag(env, 'FORGE_WEB_LOG_PROMPTS')
        s.telemetry_cache_s = _float(env, 'FORGE_WEB_TELEMETRY_CACHE_S', s.telemetry_cache_s, 0, 1)
        s.rss_interval_s = _float(env, 'FORGE_WEB_RSS_INTERVAL_S', s.rss_interval_s, 0.02, 60)
        s.engine_timeout_s = _float(env, 'FORGE_WEB_ENGINE_TIMEOUT_S', s.engine_timeout_s, 1, 600)
        s.model = env.get('HAL_MODEL') or s.model
        s.max_tokens = _int(env, 'HAL_MAX_TOKENS', s.max_tokens, 16, 2000)
        s.api_key = env.get('ANTHROPIC_API_KEY', '')
        return s
