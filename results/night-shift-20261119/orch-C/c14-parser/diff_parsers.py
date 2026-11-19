"""c14 (d): differential fuzz of the repository's Python strict parser (frame.strict_parse) against c14's
hand transcription of HOL refund_strict_parse (hol_strict.py). No executable run (seed frames were printed
by the real executable in edges/fuzz runs and are re-created here with both renderers, which must agree).
Exit 1 if a frame is ACCEPTED by Python and REJECTED by HOL, or both accept with different fields
(dangerous direction). Python-rejects/HOL-accepts frames are counted and printed (claim gap / false rejection)
and also give exit 1 with --identity.  usage: python3 -B -I diff_parsers.py SEED N [--identity]"""
import sys, random
sys.path.insert(0, '/Users/mackianni/forge/results/night-shift-20261119/orch-C/c14-parser')
from common import frame  # noqa
import hol_strict as H  # noqa

seed, n = int(sys.argv[1]), int(sys.argv[2]); ident = '--identity' in sys.argv
R = random.Random(seed)
APP = [b'duplicate_charge', b'service_not_delivered', b'returned_item', b'', b'x y', b'a"b', b'\\', b'\r\x00\xff']


def rbytes():
    k = R.random()
    if k < 0.4: return R.choice(APP)
    return bytes(R.randrange(256) for _ in range(R.randrange(0, 6)))


def rfields(neg=False):
    ints = [0, 1, 40, 9223372036854775807, 2 ** 64 + 1] + ([-1, -40, -(2 ** 70)] if neg else [])
    return (R.random() < 0.5, R.choice(ints), rbytes(), rbytes(), rbytes(), R.choice(ints))


def mutate(s):
    s = bytearray(s); k = R.randrange(13)
    if k == 0 and s: i = R.randrange(len(s)); s[i] ^= 1 << R.randrange(8)
    elif k == 1: s = s[:R.randrange(len(s) + 1)]
    elif k == 2: s += R.choice([b'\n', b' ', b')', b'x', b'(', b'\x00', b'\r\n'])
    elif k == 3 and s: i = R.randrange(len(s) + 1); s[i:i] = bytes([R.choice(b' \t\n\r()"\\~+-0')])
    elif k == 4 and s: i = R.randrange(len(s)); del s[i]
    elif k == 5:  # numeric alternative forms
        for a, b in [(b' 40 ', b' 040 '), (b' 0 ', b' -0 '), (b' 0 ', b' ~0 '), (b' 1)', b' +1)'), (b' 1)', b' 01)'),
                     (b' 0)', b' -0)'), (b' 40 ', b' +40 '), (b' ~', b' -')]:
            if a in s: s = s.replace(a, b, 1); break
    elif k == 6:  # quote a bare atom / unquote
        w = bytes(s).split(b' ')
        if len(w) > 3: j = R.randrange(1, len(w) - 1); w[j] = b'"' + w[j] + b'"'; s = bytearray(b' '.join(w))
    elif k == 7:  # duplicate a field
        w = bytes(s).split(b' ')
        if len(w) > 3: j = R.randrange(1, len(w) - 1); w.insert(j, w[j]); s = bytearray(b' '.join(w))
    elif k == 8:  # swap two fields
        w = bytes(s).split(b' ')
        if len(w) > 4: j = R.randrange(1, len(w) - 2); w[j], w[j + 1] = w[j + 1], w[j]; s = bytearray(b' '.join(w))
    elif k == 9: s = bytearray(bytes(s).replace(b' ', R.choice([b'  ', b'\t', b'\n']), 1))
    elif k == 10: s = bytearray(bytes(s).replace(b'\\t', b'\t', 1).replace(b'\\n', b'\r', 1))
    elif k == 11: s = bytearray(bytes(s).replace(b'True', R.choice([b'true', b'T', b'"True"']), 1))
    elif k == 12: s = bytearray(b'(' + bytes(s) + b')') if R.random() < 0.5 else bytearray(bytes(s).replace(b'"', b'\\"', 1))
    return bytes(s)


stats = dict(frames=0, render_differs=0, both_accept=0, both_reject=0, py_only=0, hol_only=0, field_diff=0,
             hol_only_negative=0)
examples = []
for t in range(n):
    f = rfields(neg=R.random() < 0.15)
    base_py, base_h = frame.render_fields(*f), H.render(f)
    if base_py != base_h: stats['render_differs'] += 1; examples.append(('RENDER', base_py)); continue
    s = base_py
    for _ in range(R.choice([0, 1, 1, 2, 3])): s = mutate(s)
    p, h = frame.strict_accepts(s), H.refund_strict_parse(s)
    stats['frames'] += 1
    if p is not None and h is not None:
        stats['both_accept'] += 1
        if tuple(p) != tuple(h): stats['field_diff'] += 1; examples.append(('FIELDS', s))
    elif p is None and h is None: stats['both_reject'] += 1
    elif p is not None: stats['py_only'] += 1; examples.append(('PY_ONLY', s))
    else:
        stats['hol_only'] += 1
        if h[1] < 0 or h[5] < 0: stats['hol_only_negative'] += 1
        else: examples.append(('HOL_ONLY', s))
        if stats['hol_only'] <= 3: print('HOL_ONLY example', s[:100])
print(stats)
for e in examples[:10]: print(e[0], e[1][:120])
danger = stats['py_only'] + stats['field_diff'] + stats['render_differs']
sys.exit(1 if danger or (ident and stats['hol_only']) else 0)
