"""Runs ONLY the source-scope part of prepare() of a gate copy on submission files (no Dafny, no Node).
Usage: python3 -I scope_check.py GATE_REFUND_PY FILE.dfy...  Prints `name | PASS` or `name | <refusal>`.
The code is taken from the gate copy by text: the module-level helpers (LINE_END, CHAR, code_words) and the
lines of prepare() from `code = (ROOT / 'impl/Refund.dfy')` up to the binding check."""
import re
import sys


class Rejected(Exception):
    pass


src = open(sys.argv[1]).read()
helpers = ''
for name in ('LINE_END = ', 'CHAR = ', 'SOURCE_BYTES_MAX = ', 'NEST_MAX = '):
    if name not in src:
        continue
    i = src.index(name)
    helpers += src[i:src.index('\n', i) + 1]
if 'def code_words' in src:
    i = src.index('def code_words')
    helpers += src[i:src.index('\n\n\n', i)] + '\n'
k = src.index('def prepare(')
i = src.index("    prefix = b'include", k)
j = src.index("    if b'include' in (ROOT / BINDING)")
body = '    code = CODE\n' + src[i:j]
fn = 'def scope(CODE):\n' + body + '    return None\n'
env = {'re': re, 'Rejected': Rejected}
exec(helpers + fn, env)
for path in sys.argv[2:]:
    try:
        env['scope'](open(path, 'rb').read())
        print(path.rsplit('/', 1)[-1], '| PASS')
    except Rejected as e:
        print(path.rsplit('/', 1)[-1], '|', e)
