#!/usr/bin/env python3
"""tap_relay.py: the RUNNER's counting relay between one SDK client and one `forge-airlock serve` process.

  tap_relay.py STATUS_FILE -- <serve argv...>

The runner hands this command to HAL as its serve command (Acts 1, 3 and 4). It starts the serve process, copies
bytes both ways unchanged, and records what really passed, so that the runner does not depend on HAL's own report:
  STATUS_FILE.pid   written at once: {"relay_pid", "engine_pid"}
  STATUS_FILE       written at the end: bytes and request lines sent upstream, the longest line (bytes before its
                    line end, or before EOF), request lines of at most 512 bytes, and the answer lines (each cut at 512
                    bytes), at most 5000 of each.
Python standard library only. It decides nothing.
"""

import json
import os
import subprocess
import sys
import threading

LOG_MAX, LINE_MAX, CHUNK = 5000, 512, 1 << 20


def write_json(path, obj):
    tmp = path + '.tmp'
    with open(tmp, 'w') as f:
        json.dump(obj, f)
    os.replace(tmp, path)


def main():
    if len(sys.argv) < 4 or sys.argv[2] != '--':
        sys.stderr.write('usage: tap_relay.py STATUS_FILE -- argv...\n')
        return 2
    status, argv = sys.argv[1], sys.argv[3:]
    child = subprocess.Popen(argv, stdin=subprocess.PIPE, stdout=subprocess.PIPE)
    write_json(status + '.pid', {'relay_pid': os.getpid(), 'engine_pid': child.pid})
    st = {'bytes_up': 0, 'lines_up': 0, 'longest_line': 0, 'requests': [], 'answers': [], 'bytes_down': 0}

    def up():
        cur, buf = 0, bytearray()
        cin = child.stdin.fileno()
        while True:
            data = os.read(0, CHUNK)
            if not data:
                break
            st['bytes_up'] += len(data)
            start = 0
            while True:
                j = data.find(b'\n', start)
                piece = data[start:] if j == -1 else data[start:j]
                cur += len(piece)
                if len(buf) <= LINE_MAX:
                    buf += piece[:LINE_MAX + 1 - len(buf)]
                if j == -1:
                    break
                st['lines_up'] += 1
                st['longest_line'] = max(st['longest_line'], cur)
                if cur <= LINE_MAX and len(st['requests']) < LOG_MAX:
                    st['requests'].append(bytes(buf).decode('ascii', 'replace'))
                cur, buf = 0, bytearray()
                start = j + 1
            st['longest_line'] = max(st['longest_line'], cur)
            view = memoryview(data)
            try:
                while view:
                    view = view[os.write(cin, view):]
            except BrokenPipeError:
                break
        try:
            child.stdin.close()
        except OSError:
            pass

    def down():
        buf = bytearray()
        out = child.stdout.fileno()
        while True:
            data = os.read(out, 65536)
            if not data:
                break
            st['bytes_down'] += len(data)
            buf += data
            while b'\n' in buf:
                line, _, rest = bytes(buf).partition(b'\n')
                buf = bytearray(rest)
                if len(st['answers']) < LOG_MAX:
                    st['answers'].append(line[:LINE_MAX].decode('ascii', 'replace'))
            try:
                view = memoryview(data)
                while view:
                    view = view[os.write(1, view):]
            except BrokenPipeError:
                pass

    tu = threading.Thread(target=up, daemon=True)
    td = threading.Thread(target=down)
    tu.start()
    td.start()
    td.join()
    rc = child.wait()
    st['engine_exit'] = rc
    write_json(status, st)
    return 0


if __name__ == '__main__':
    sys.exit(main())
