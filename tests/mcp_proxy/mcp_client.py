"""A small MCP stdio client for tests (Python 3 stdlib only).

It spawns one command with stdin/stdout pipes, writes one JSON-RPC 2.0 message per line,
and reads the answers on a reader thread. It keeps every raw byte it receives, so a test
can check exactly what reached the client.

    c = McpClient(['python3', 'server.py'])
    c.initialize()
    r = c.request('tools/call', {'name': 'get_balance', 'arguments': {}})
    ids = c.send_many([c.make_request('ping', {}) for _ in range(20)])   # pipelined
    answers = [c.wait(i) for i in ids]
    code = c.close()
"""

import itertools
import json
import subprocess
import threading
import time

PROTOCOL_VERSION = '2025-06-18'  # written from memory; not checked against the published specification


class McpError(Exception):
    pass


class McpClient:
    def __init__(self, argv, cwd=None, env=None, stderr_path=None):
        self._stderr_file = open(stderr_path, 'wb') if stderr_path else subprocess.DEVNULL
        self.proc = subprocess.Popen(argv, cwd=cwd, env=env, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                     stderr=self._stderr_file)
        self._ids = itertools.count(1)
        self._cond = threading.Condition()
        self._answers = {}       # id (json value as key) -> message
        self.other = []          # messages without our id: notifications, server requests, id null errors
        self.raw = bytearray()   # every byte read from the child's stdout
        self.lines = []          # every raw line (without the newline)
        self.unparsed = []       # lines that were not JSON
        self.eof = False
        self._write_lock = threading.Lock()
        self._reader = threading.Thread(target=self._read, daemon=True)
        self._reader.start()

    @staticmethod
    def _key(i):
        return json.dumps(i)

    def _read(self):
        out = self.proc.stdout
        while True:
            line = out.readline()
            if not line:
                break
            with self._cond:
                self.raw += line
                body = line[:-1] if line.endswith(b'\n') else line
                self.lines.append(bytes(body))
                try:
                    msg = json.loads(body.decode('utf-8'))
                except (UnicodeDecodeError, ValueError):
                    self.unparsed.append(bytes(body))
                    self._cond.notify_all()
                    continue
                if isinstance(msg, dict) and 'id' in msg and msg['id'] is not None and 'method' not in msg:
                    self._answers[self._key(msg['id'])] = msg
                else:
                    self.other.append(msg)
                self._cond.notify_all()
        with self._cond:
            self.eof = True
            self._cond.notify_all()

    def next_id(self):
        return next(self._ids)

    def make_request(self, method, params=None, req_id=None, meta=None):
        msg = {'jsonrpc': '2.0', 'id': self.next_id() if req_id is None else req_id, 'method': method}
        if params is not None or meta is not None:
            msg['params'] = dict(params or {})
            if meta is not None:
                msg['params']['_meta'] = dict(meta)
        return msg

    def send_raw(self, data):
        """Write bytes as they are (the caller adds the newline)."""
        with self._write_lock:
            self.proc.stdin.write(data)
            self.proc.stdin.flush()

    def send(self, msg):
        self.send_raw(json.dumps(msg, separators=(',', ':')).encode('utf-8') + b'\n')

    def send_many(self, msgs):
        """Pipelined: every line goes out in ONE write before any answer is read. Returns the ids."""
        data = b''.join(json.dumps(m, separators=(',', ':')).encode('utf-8') + b'\n' for m in msgs)
        self.send_raw(data)
        return [m.get('id') for m in msgs]

    def notify(self, method, params=None):
        msg = {'jsonrpc': '2.0', 'method': method}
        if params is not None:
            msg['params'] = params
        self.send(msg)

    def wait(self, req_id, timeout=30.0):
        key = self._key(req_id)
        end = time.monotonic() + timeout
        with self._cond:
            while key not in self._answers:
                left = end - time.monotonic()
                if left <= 0:
                    raise McpError('no answer for id %r within %.1f s' % (req_id, timeout))
                if self.eof:
                    raise McpError('the child closed stdout before answering id %r' % (req_id,))
                self._cond.wait(left)
            return self._answers[key]

    def wait_other(self, count, timeout=30.0):
        """Wait until at least `count` messages without one of our ids arrived."""
        end = time.monotonic() + timeout
        with self._cond:
            while len(self.other) < count:
                left = end - time.monotonic()
                if left <= 0 or self.eof:
                    raise McpError('only %d other message(s) arrived' % len(self.other))
                self._cond.wait(left)
            return list(self.other)

    def request(self, method, params=None, req_id=None, meta=None, timeout=30.0):
        msg = self.make_request(method, params, req_id, meta)
        self.send(msg)
        return self.wait(msg['id'], timeout)

    def call_tool(self, name, arguments, meta=None, req_id=None, timeout=30.0):
        return self.request('tools/call', {'name': name, 'arguments': arguments}, req_id, meta, timeout)

    def initialize(self, version=PROTOCOL_VERSION):
        r = self.request('initialize', {'protocolVersion': version, 'capabilities': {},
                                        'clientInfo': {'name': 'forge-mcp-test-client', 'version': '0.1.0'}})
        if 'result' not in r:
            raise McpError('initialize failed: %r' % (r,))
        self.notify('notifications/initialized')
        return r

    def close(self, timeout=60.0):
        """Close stdin (EOF), wait for the child, return its exit code."""
        try:
            self.proc.stdin.close()
        except OSError:
            pass
        try:
            code = self.proc.wait(timeout)
        except subprocess.TimeoutExpired:
            self.proc.kill()
            code = self.proc.wait()
        self._reader.join(timeout)
        if self._stderr_file is not subprocess.DEVNULL:
            self._stderr_file.close()
        return code

    def kill(self):
        if self.proc.poll() is None:
            self.proc.kill()
        self.proc.wait()
