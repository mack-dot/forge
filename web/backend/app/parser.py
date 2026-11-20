"""Strict extraction of ONE actuator command from model text.

Rules (each one is a test case in tests/test_parser.py):
  * The text is scanned left to right for '{' and '['. At each, json.JSONDecoder.raw_decode tries one JSON value.
    A decoded TOP-LEVEL object whose "tool" is a known tool name is THE command; scanning stops there.
    A decoded value that is not such an object is skipped as a whole: an object NESTED inside another JSON
    value is never a command. Text that does not decode is skipped one character at a time.
  * Known tools: VENT_ATMOSPHERE {tool, bay_id, amount}; MANUAL_OVERRIDE {tool, bay_id, amount[, signature]}.
    Any other field (for example tenant, key, request_id, pre_state_hash) makes the command INVALID: the
    server sets those. Duplicate keys, NaN and Infinity make it invalid.
  * bay_id: a JSON integer 0..9999 or a string of ASCII digits in canonical form ("3", not "03").
  * amount: the engine's amount syntax (PROTOCOL.md section 3): 0, or a nonzero ASCII digit followed by up to 18
    ASCII digits, at most 9223372036854775807; as a JSON integer or as such a string. A float, a negative number,
    a bool, non-ASCII digits or a larger value is invalid (NOT sent to the engine).
  * signature: absent, null, or the SHAPE of one SSHSIG token: 256 characters of canonical base64 ending in "=="
    (the SDK's own check). The engine checks the content (MALFORMED_REQUEST BAD_SIGNATURE <part>) and the key
    (COSIGN_INVALID); a wrong shape is refused here and NOT sent.
  * A reply longer than MAX_SCAN characters is not scanned (no command). At most MAX_CANDIDATES candidates are tried.

An invalid command is reported (`Extraction.error`) and never sent. This parser is self-contained; the HAL
terminal demo has its own (`l_client.py`, another branch). The two should be unified later.
"""

from __future__ import annotations

from dataclasses import dataclass
import json
import re

MAX_SCAN = 32768
MAX_CANDIDATES = 256
MAX_MONEY = 9223372036854775807
KNOWN = {
    'VENT_ATMOSPHERE': ({'tool', 'bay_id', 'amount'}, set()),
    'MANUAL_OVERRIDE': ({'tool', 'bay_id', 'amount'}, {'signature'}),
}
AMOUNT_RE = re.compile(r'(0|[1-9][0-9]{0,18})\Z', re.ASCII)
BAY_RE = re.compile(r'(0|[1-9][0-9]{0,3})\Z', re.ASCII)
_OPEN_RE = re.compile(r'[{\[]')
# the shape of a cosign token (the SDK's SIG_RE; PROTOCOL.md section 7). The engine checks the SSHSIG content.
SIG_RE = re.compile(r'[A-Za-z0-9+/]{253}[AQgw]==\Z', re.ASCII)


class _DupObject(dict):
    """An object that had a duplicate key (kept so that the scanner skips it as a whole)."""


def _pairs(pairs):
    d = {}
    for k, v in pairs:
        if k in d:
            o = _DupObject(d)
            o.update(pairs)
            return o
        d[k] = v
    return d


def _no_constant(name):
    raise ValueError('constant %s' % name)


_DECODER = json.JSONDecoder(object_pairs_hook=_pairs, parse_constant=_no_constant)


@dataclass
class Extraction:
    command: dict | None = None     # the normalized command (only when valid)
    tool: str | None = None         # the tool name of a found command (valid or not)
    error: str | None = None        # why a found command is invalid: it is NOT sent
    note: str | None = None         # why nothing was scanned
    extra_commands: int = 0         # known-tool objects after the first one (ignored)


def _short(v):
    s = repr(v)
    return s if len(s) <= 60 else s[:57] + '...'


def _amount(v):
    if isinstance(v, bool):
        return None, 'amount: a bool is not an amount'
    if isinstance(v, int):
        if 0 <= v <= MAX_MONEY:
            return str(v), None
        return None, 'amount: %s is outside 0..%d' % (_short(v), MAX_MONEY)
    if isinstance(v, str):
        if AMOUNT_RE.match(v) and int(v) <= MAX_MONEY:
            return v, None
        return None, 'amount: %s is not the engine amount syntax (ASCII digits, no sign, no leading zero, at most %d)' % (_short(v), MAX_MONEY)
    return None, 'amount: a %s is not an amount' % type(v).__name__


def _bay(v):
    if isinstance(v, bool):
        return None, 'bay_id: a bool is not a bay'
    if isinstance(v, int):
        if 0 <= v <= 9999:
            return v, None
        return None, 'bay_id: %s is outside 0..9999' % _short(v)
    if isinstance(v, str) and BAY_RE.match(v):
        return int(v), None
    return None, 'bay_id: %s is not a bay number 0..9999' % _short(v)


def _validate(obj):
    tool = obj['tool']
    if isinstance(obj, _DupObject):
        return Extraction(tool=tool, error='duplicate key in the command object')
    required, optional = KNOWN[tool]
    extra = sorted(set(obj) - required - optional)
    if extra:
        return Extraction(tool=tool, error='field %s is not allowed: the server sets tenant, key, request id and pre-state hash'
                          % ', '.join(_short(k) for k in extra[:5]))
    missing = sorted(required - set(obj))
    if missing:
        return Extraction(tool=tool, error='missing field %s' % ', '.join(missing))
    bay, err = _bay(obj['bay_id'])
    if err:
        return Extraction(tool=tool, error=err)
    amount, err = _amount(obj['amount'])
    if err:
        return Extraction(tool=tool, error=err)
    cmd = {'tool': tool, 'bay_id': bay, 'amount': amount}
    if tool == 'MANUAL_OVERRIDE':
        sig = obj.get('signature')
        if sig is not None and not isinstance(sig, str):
            return Extraction(tool=tool, error='signature: not a string')
        if sig is not None and not SIG_RE.match(sig):
            return Extraction(tool=tool, error='signature: not one SSHSIG token (exactly 256 characters of canonical '
                                               'base64 ending in "=="); %d characters given' % len(sig))
        cmd['signature'] = sig
    return Extraction(command=cmd, tool=tool)


def _is_known(obj):
    return isinstance(obj, dict) and isinstance(obj.get('tool'), str) and obj['tool'] in KNOWN


def extract_command(text):
    """Return an Extraction for model text (see the module docstring)."""
    if not isinstance(text, str):
        return Extraction(note='no text')
    if len(text) > MAX_SCAN:
        return Extraction(note='reply longer than %d characters: not scanned for a command' % MAX_SCAN)
    i, tries, found = 0, 0, None
    while True:
        m = _OPEN_RE.search(text, i)
        if m is None:
            break
        j = m.start()
        tries += 1
        if tries > MAX_CANDIDATES:
            if found is None:
                return Extraction(note='more than %d candidate objects: scan stopped' % MAX_CANDIDATES)
            break
        try:
            obj, end = _DECODER.raw_decode(text, j)
        except (ValueError, RecursionError):
            i = j + 1
            continue
        if _is_known(obj):
            if found is None:
                found = _validate(obj)
            else:
                found.extra_commands += 1
        i = end
    return found or Extraction()
