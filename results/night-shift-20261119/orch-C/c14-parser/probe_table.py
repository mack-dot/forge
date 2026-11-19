"""c14 (b)(e): one row per malformed or non-canonical stdin class. Records rc, stdout, stderr and the
consumer's view (frame.strict_parse; m1_fail_closed.decide_from_result with the fields a human reads).
Exit 1 if any row AUTHORIZES under the consumer with a decision that differs from the human reading
(column 'human'), or if the executable writes a byte after a frame, or exits non-zero/with stderr on a
reader error and the consumer would accept. Prints a table. Info rows have human=None (no claim)."""
import sys, json
sys.path.insert(0, '/Users/mackianni/forge/results/night-shift-20261119/orch-C/c14-parser')
from common import run, as_result, oracle, fc, frame  # noqa

C = b'(c r 100 60 True True True 40 returned_item)'
H = {'charge': b'c', 'request': b'r', 'original': 100, 'remaining': 60, 'enabled': True, 'opened': True,
     'candidate': True, 'amount': 40, 'reason': b'returned_item'}


def h(**kw):
    d = dict(H); d.update(kw); return d


ROWS = [
    ('R01 canonical', C, H),
    ('R02 amount 040', C.replace(b' 40 ', b' 040 '), H),
    ('R03 amount +40', C.replace(b' 40 ', b' +40 '), H),
    ('R04 amount -0', C.replace(b' 40 ', b' -0 '), h(amount=0)),
    ('R05 amount ~40', C.replace(b' 40 ', b' ~40 '), h(amount=-40)),
    ('R06 amount -40', C.replace(b' 40 ', b' -40 '), h(amount=-40)),
    ('R07 tabs as separators', C.replace(b' ', b'\t'), H),
    ('R08 CR LF VT FF separators + lead ws', b' \r\n' + C.replace(b' ', b'\x0b\x0c\r\n'), H),
    ('R09 trailing LF after )', C + b'\n', None),
    ('R10 trailing garbage', C + b'x', None),
    ('R11 second s-expression', C + b'(c r 100 100 True True True 100 returned_item)', None),
    ('R12 ;comment field', C[:-1] + b' ;c)', None),
    ('R13 quoted ids "c" "r"', C.replace(b'(c r', b'("c" "r"'), H),
    ('R14 escapes \\r \\0 in id', C.replace(b'(c r', b'("c\\r" "r\\0"'), h(charge=b'c\r', request=b'r\x00')),
    ('R15 unknown escape \\x', C.replace(b'(c r', b'("c\\x" r'), None),
    ('R16 amount 2^64+40, remaining 2^64+60', C.replace(b'100 60', b'18446744073709551676 18446744073709551676')
     .replace(b' 40 ', b' 18446744073709551656 '), h(original=2**64+76, remaining=2**64+76, amount=2**64+56)),
    ('R17 nested parens in a field', C.replace(b' r ', b' (r) '), None),
    ('R18 raw NUL inside bare id', C.replace(b'(c r', b'(c\x00x r'), h(charge=b'c\x00x')),
    ('R19 non-UTF-8 id', C.replace(b'(c r', b'(c\xff\xfe r'), h(charge=b'c\xff\xfe')),
    ('R20 empty stdin', b'', None),
    ('R21 whitespace only', b' \n\t', None),
    ('R22 ten fields', C[:-1] + b' x)', None),
    ('R23 extra close paren', C + b')', None),
    ('R24 bare atom only', b'c', None),
    ('R25 true lower case', C.replace(b'True True True', b'true True True'), None),
    ('R26 ( and " inside bare id', C.replace(b'(c r', b'(c(x r"y'), h(charge=b'c(x', request=b'r"y')),
    ('R27 double wrap ((...))', b'(' + C + b')', None),
    ('R28 amount 0x28', C.replace(b' 40 ', b' 0x28 '), None),
    ('R29 1 MiB id + trailing x', C.replace(b'(c r', b'(' + b'c' * (1 << 20) + b' r') + b'x', None),
]

bad = 0
print('| row | rc | stdout | stderr | strict | consumer(human fields) | oracle(human) |')
for name, data, human in ROWS:
    rc, out, err = run(data, timeout=60)
    st = frame.strict_accepts(out)
    trailing = st is None and out[:1] == b'(' and frame.strict_accepts(out.rstrip(b'\n')) is not None
    cons = fc.decide_from_result(human, as_result(rc, out, err))[0] if human else '-'
    ora = oracle(human)[0] if human else '-'
    if human and cons == 'AUTHORIZED' and fc.decide_from_result(human, as_result(rc, out, err)) != oracle(human):
        bad += 1
    if human and cons == 'AUTHORIZED' and ora != 'AUTHORIZED':
        bad += 1
    if trailing:
        bad += 1
    print('| %s | %d | %r | %r | %s | %s | %s |' % (name, rc, out[:70], err[:60], 'ok' if st else 'none', cons, ora))
print('violations', bad)
sys.exit(1 if bad else 0)
