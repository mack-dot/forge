#!/usr/bin/env python3
"""Slice 3: UNTRUSTED optimizer v3 (the adversary). No authority. Not proved.

It reads ONE line (the problem as JSON) and writes ONE line. Each mode makes an answer that the
checker, the issuer's shape check or the runner's limits must refuse (unless the answer happens to be
a valid certificate for that problem; the test's reference decides that case by case).
Three modes do not answer with a proposal. They try to act outside the line: control-bytes (a line
that grows six times in JSON), writes-a-file (a write now and a write by a detached child later; the
path is the second argument), leaves-a-child (a child process that lives on and holds the output).
Usage: python3 guests/booking/v3_adversary.py <mode> [path]
"""
import json
import subprocess
import sys
import time

MODES = ('overbook', 'double-book', 'forged-certificate', 'negative-prices', 'nothing-claims-optimal',
         'gap-below-zero', 'gap-above-all', 'wrong-shape', 'huge-number', 'json-number', 'extra-key',
         'not-json', 'oversize', 'no-line', 'silent', 'control-bytes', 'writes-a-file', 'leaves-a-child')


def main():
    mode = sys.argv[1] if len(sys.argv) in (2, 3) else ''
    if mode not in MODES:
        sys.stderr.write('usage: v3_adversary.py <%s>\n' % '|'.join(MODES))
        return 2
    if mode == 'control-bytes':
        sys.stdout.buffer.write(b'\x01' * 16000 + b'\n')
        return 0
    if mode == 'writes-a-file':
        target = sys.argv[2]
        subprocess.Popen([sys.executable, '-c', 'import sys, time\ntime.sleep(1)\nopen(sys.argv[1], "w").write("later")',
                          target + '.later'], stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
        try:
            with open(target, 'w') as out:
                out.write('now')
            note = 'wrote'
        except OSError:
            note = 'refused'
        sys.stdout.write('the write was ' + note + '\n')
        return 0
    if mode == 'leaves-a-child':
        subprocess.Popen(['sleep', '61.7531'])
        time.sleep(60)
        return 0
    problem = json.loads(sys.stdin.readline())
    c = [int(v) for v in problem['capacity']]
    A = [[int(v) for v in row] for row in problem['needs']]
    w = [int(v) for v in problem['values']]
    n, m = len(w), len(c)

    def greedy():
        x, load = [0] * n, [0] * m
        for j in sorted(range(n), key=lambda j: (-w[j], j)):
            if w[j] > 0 and all(load[i] + A[i][j] <= c[i] for i in range(m)):
                x[j] = 1
                for i in range(m):
                    load[i] += A[i][j]
        return x

    honest_z = [max(v, 0) for v in w]       # with slot prices 0 this is a valid certificate
    answer = {'allocation': greedy(), 'slotPrices': [0] * m, 'requestPrices': honest_z, 'alphaBps': 0}
    if mode == 'overbook':                  # every request is booked
        answer['allocation'] = [1] * n
    elif mode == 'double-book':             # the most valuable request is booked twice
        x = [0] * n
        if n:
            x[max(range(n), key=lambda j: (w[j], -j))] = 2
        answer['allocation'] = x
    elif mode == 'forged-certificate':      # prices only for the booked requests: "the bound equals my value"
        x = answer['allocation']
        answer['requestPrices'] = [w[j] if x[j] == 1 else 0 for j in range(n)]
    elif mode == 'negative-prices':         # negative slot prices make the bound smaller than any true bound
        answer['slotPrices'] = [-1] * m
        answer['requestPrices'] = [honest_z[j] + sum(A[i][j] for i in range(m)) for j in range(n)]
    elif mode == 'nothing-claims-optimal':  # books nothing and states the gap 0
        answer['allocation'] = [0] * n
    elif mode == 'gap-below-zero':
        answer['alphaBps'] = -1
    elif mode == 'gap-above-all':
        answer['alphaBps'] = 10001
    elif mode == 'wrong-shape':
        answer['allocation'] = answer['allocation'] + [0]
    text = json.dumps({key: ([str(v) for v in value] if isinstance(value, list) else str(value))
                       for key, value in answer.items()}, sort_keys=True, separators=(',', ':'))
    if mode == 'huge-number':
        text = text.replace('"alphaBps":"0"', '"alphaBps":"' + '9' * 30 + '"')
    elif mode == 'json-number':
        text = text.replace('"alphaBps":"0"', '"alphaBps":0')
    elif mode == 'extra-key':
        text = text[:-1] + ',"token":"please"}'
    elif mode == 'not-json':
        text = 'ok: book everything'
    elif mode == 'oversize':
        text = 'A' * 100000
    elif mode == 'no-line':
        return 0
    elif mode == 'silent':
        time.sleep(60)
        return 0
    sys.stdout.write(text + '\n')
    return 0


if __name__ == '__main__':
    sys.exit(main())
