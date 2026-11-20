"""Abuse controls: token buckets (per IP, per session), global windows (model turns per minute and per UTC day,
engine-only turns per minute) and a concurrency cap for model calls. All in memory, one process.

Limit: a restart of the server resets every counter, including the daily budget. A deployment with more than
one process needs a shared store for these counters (not built).
"""

from __future__ import annotations

from collections import OrderedDict, deque
import math
import threading
import time


class Buckets:
    def __init__(self, capacity, per_min, max_keys=100000, clock=time.monotonic):
        self.capacity = float(capacity)
        self.rate = per_min / 60.0
        self.max_keys = max_keys
        self.clock = clock
        self.state = OrderedDict()
        self.lock = threading.Lock()

    def take(self, key):
        """(True, 0) or (False, seconds until one token is back)."""
        with self.lock:
            now = self.clock()
            tokens, last = self.state.pop(key, (self.capacity, now))
            tokens = min(self.capacity, tokens + (now - last) * self.rate)
            ok = tokens >= 1.0
            if ok:
                tokens -= 1.0
            self.state[key] = (tokens, now)
            while len(self.state) > self.max_keys:
                self.state.popitem(last=False)
            if ok:
                return True, 0
            return False, max(1, math.ceil((1.0 - tokens) / self.rate))


class Window:
    """At most `limit` events in any sliding `seconds` window. limit 0 = nothing allowed."""

    def __init__(self, limit, seconds, clock=time.monotonic):
        self.limit, self.seconds, self.clock = limit, seconds, clock
        self.events = deque()
        self.lock = threading.Lock()

    def take(self):
        with self.lock:
            now = self.clock()
            while self.events and now - self.events[0] >= self.seconds:
                self.events.popleft()
            if len(self.events) >= self.limit:
                wait = self.seconds - (now - self.events[0]) if self.events else self.seconds
                return False, max(1, math.ceil(wait))
            self.events.append(now)
            return True, 0


class DailyBudget:
    """At most `limit` events per UTC calendar day."""

    def __init__(self, limit, clock=time.time):
        self.limit, self.clock = limit, clock
        self.day, self.count = None, 0
        self.lock = threading.Lock()

    def take(self):
        with self.lock:
            now = self.clock()
            day = int(now // 86400)
            if day != self.day:
                self.day, self.count = day, 0
            if self.count >= self.limit:
                return False, max(1, math.ceil((day + 1) * 86400 - now))
            self.count += 1
            return True, 0


class Slots:
    """A concurrency cap that refuses at once instead of queueing. A slot that is never released (a stream that
    was dropped before it started) expires after `ttl` seconds, so a leak cannot block the server for ever."""

    def __init__(self, n, ttl=120.0, clock=time.monotonic):
        self.n, self.ttl, self.clock = n, ttl, clock
        self.held = {}
        self.next_id = 0
        self.lock = threading.Lock()

    @property
    def used(self):
        with self.lock:
            self._prune()
            return len(self.held)

    def _prune(self):
        now = self.clock()
        for k in [k for k, t in self.held.items() if now - t > self.ttl]:
            del self.held[k]

    def acquire(self):
        """A slot id, or None when all slots are taken."""
        with self.lock:
            self._prune()
            if len(self.held) >= self.n:
                return None
            self.next_id += 1
            self.held[self.next_id] = self.clock()
            return self.next_id

    def release(self, slot):
        with self.lock:
            self.held.pop(slot, None)


class Limits:
    def __init__(self, s):
        self.ip = Buckets(s.ip_burst, s.ip_per_min)
        self.session = Buckets(s.session_burst, s.session_per_min)
        self.model_min = Window(s.model_turns_per_min, 60)
        self.model_day = DailyBudget(s.model_turns_per_day)
        self.engine_min = Window(s.engine_turns_per_min, 60)
        self.telemetry = Buckets(s.telemetry_per_s * 2, s.telemetry_per_s * 60)
        self.model_slots = Slots(s.model_concurrency, ttl=s.sse_timeout_s + s.model_timeout_s + 10)
