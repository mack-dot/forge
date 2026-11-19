#!/usr/bin/env python3
"""Unit controls for both lexer copies (dafny_tokens.py rule and the proposed gate code_words). Z1 scratch."""
import sys
sys.dont_write_bytecode = True
from expect_rule import rule, load_proposed
proposed = load_proposed()
CASES = [  # (source fragment, True if it must be REFUSED)
    ('expect false;', True), (':- expect F();', True), ('expect\tx;', True), ('{expect x;}', True),
    ('// expect\n', False), ('/* expect */', False), ('/* /* */ expect */', False), ('/* */ expect x;', True),
    ('// a\rexpect x;', True), ('// a\x0cexpect x;', True), ('// a expect x;', True),
    ('"expect"', False), ('"a\\"expect"', False), ('"a\\\\" expect', True), ("'\\'' expect", True),
    ("'e' + 'x'", False), ("x'expect := 1;", True), ('Candidate?expect', True), ('expected := 1;', False),
    ('expect_ok', False), ('_expect', False), ('1expect', True), ('@"a""expect"""', False), ('@"a"" " expect', True),
    ('"unterminated', True), ('/* unterminated', True), ("'ab'", True), ('éexpect', True), (' expect', True),
]
bad = 0
for src, must in CASES:
    data = ('include "x"\n' + src + '\n').encode()
    a, b = rule(data) is not None, proposed(data) is not None
    ok = a == must and b == must
    bad += not ok
    print('%-4s %-26r must_refuse=%-5s rule=%-5s gate_copy=%-5s' % ('ok' if ok else 'FAIL', src, must, a, b))
print('failures:', bad)
sys.exit(1 if bad else 0)
