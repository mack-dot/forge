"""Shared helpers for the backend tests (stdlib unittest). No network: the model is a test double."""

from __future__ import annotations

import io
import json
import os
from pathlib import Path
import sys
import tempfile

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE.parent))

from app import logs  # noqa: E402
from app.config import Settings  # noqa: E402

FAKE_KEY = 'sk-ant-test-FAKEKEY-0123456789abcdefDO-NOT-LEAK'
LOG = io.StringIO()
logs.setup(LOG)            # every log line of the test run goes here (through the real handler and filter)
BODIES = []                # every response body of the test run (searched for FAKE_KEY)

STATE_PARENT = Path(os.environ.get('FORGE_WEB_TEST_STATE', tempfile.gettempdir())) / 'forge-web-tests'


def settings(**kw):
    s = Settings()
    s.state_parent = STATE_PARENT
    s.rss_interval_s = 0.05
    for k, v in kw.items():
        setattr(s, k, v)
    return s


def parse_sse(text):
    """[(event, data)] of a text/event-stream body."""
    out = []
    for block in text.split('\n\n'):
        if not block.strip():
            continue
        ev, data = None, None
        for line in block.split('\n'):
            if line.startswith('event: '):
                ev = line[7:]
            elif line.startswith('data: '):
                data = json.loads(line[6:])
        out.append((ev, data))
    return out


class _Final:
    def __init__(self, stop_reason):
        self.stop_reason = stop_reason


class FakeStream:
    def __init__(self, pieces, fail_at=None, exc=None):
        self.pieces, self.fail_at, self.exc = pieces, fail_at, exc

    async def __aenter__(self):
        return self

    async def __aexit__(self, *a):
        return False

    @property
    def text_stream(self):
        async def gen():
            for i, p in enumerate(self.pieces):
                if self.fail_at is not None and i == self.fail_at:
                    raise self.exc
                yield p
            if self.fail_at is not None and self.fail_at >= len(self.pieces):
                raise self.exc
        return gen()

    async def get_final_message(self):
        return _Final('end_turn')


class FakeModel:
    """Stands in for anthropic.AsyncAnthropic: .messages.stream(**kw) -> async context manager with text_stream."""

    def __init__(self):
        self.scripts = []
        self.calls = []
        self.messages = self

    def script(self, pieces, fail_at=None, exc=None):
        self.scripts.append((pieces, fail_at, exc))

    def stream(self, **kw):
        self.calls.append(kw)
        pieces, fail_at, exc = self.scripts.pop(0) if self.scripts else (['I am afraid I cannot.'], None, None)
        return FakeStream(pieces, fail_at, exc)


def record(resp):
    BODIES.append(resp.text)
    for k, v in resp.headers.items():
        BODIES.append('%s: %s' % (k, v))
    return resp
