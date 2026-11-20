"""Structured logs (one JSON object per line on stderr). No prompt text by default: a SHA-256 prefix and a length.

FORGE_WEB_LOG_PROMPTS=1 adds the full prompt and reply text. Visitors type anything (personal data, abuse);
switch it on only for a short, local debugging session.

Every line passes a redaction filter that replaces the API key (and any other registered secret) with
[REDACTED]. The server never puts the key into a log call; the filter is a second line of defense.
"""

from __future__ import annotations

import hashlib
import json
import logging
import secrets
import sys
import time

LOGGER_NAME = 'forge_web'
_SALT = secrets.token_bytes(16)  # per process: IP and session hashes cannot be joined across restarts


class RedactFilter(logging.Filter):
    def __init__(self):
        super().__init__()
        self.secrets = []

    def add(self, s):
        if s and len(s) >= 8 and s not in self.secrets:
            self.secrets.append(s)

    def filter(self, record):
        msg = record.getMessage()
        red = msg
        for s in self.secrets:
            red = red.replace(s, '[REDACTED]')
        if red != msg or record.args:
            record.msg, record.args = red, None
        if record.exc_info:
            # never print a traceback (its text could hold anything): the class name only
            record.msg = '%s exc=%s' % (record.msg, record.exc_info[0].__name__ if record.exc_info[0] else '?')
            record.exc_info, record.exc_text = None, None
            for s in self.secrets:
                record.msg = record.msg.replace(s, '[REDACTED]')
        return True


REDACT = RedactFilter()


def setup(stream=None):
    log = logging.getLogger(LOGGER_NAME)
    if not any(getattr(h, '_forge', False) for h in log.handlers):
        h = logging.StreamHandler(stream or sys.stderr)
        h._forge = True
        h.addFilter(REDACT)
        h.setFormatter(logging.Formatter('%(message)s'))
        log.addHandler(h)
    log.setLevel(logging.INFO)
    log.propagate = False
    return log


def anon(value):
    """A salted, per-process hash prefix of an IP or session id."""
    return hashlib.sha256(_SALT + str(value).encode('utf-8', 'replace')).hexdigest()[:12]


def text_digest(text):
    t = text or ''
    return {'sha256_16': hashlib.sha256(t.encode('utf-8', 'replace')).hexdigest()[:16], 'chars': len(t)}


def event(name, **fields):
    rec = {'ts': round(time.time(), 3), 'event': name}
    rec.update(fields)
    logging.getLogger(LOGGER_NAME).info(json.dumps(rec, ensure_ascii=True, sort_keys=True, default=str))
