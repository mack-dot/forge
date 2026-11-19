#!/usr/bin/env python3
"""e-expect harness. Extracts the PROPOSED rule verbatim from the patched COPY of gate/refund.py
(e-expect/p1/gate/refund.py) and applies (a) the new rule alone and (b) the source-scope checks of
prepare() (old byte rules + new rule) to bytes. Not the gate. Changes no repository file."""
import ast, re, sys
from pathlib import Path
sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent.parent
PATCHED = HERE / 'p1/gate/refund.py'


class Rejected(Exception):
    pass


def _load():
    src = PATCHED.read_text()
    tree = ast.parse(src)
    keep = [n for n in tree.body if (isinstance(n, ast.Assign) and getattr(n.targets[0], 'id', None) in ('LINE_END', 'CHAR'))
            or (isinstance(n, ast.FunctionDef) and n.name == 'code_words')]
    assert len(keep) == 3, len(keep)
    env = {'re': re, 'Rejected': Rejected}
    exec(compile(ast.Module(body=keep, type_ignores=[]), str(PATCHED), 'exec'), env)
    # Source-scope lines of prepare(), verbatim: from the prefix line to the end of the new rule.
    lines = src.splitlines()
    start = next(i for i, l in enumerate(lines) if l.strip().startswith("prefix = b'include"))
    end = next(i for i, l in enumerate(lines) if "run-time halt statement expect is not allowed" in l)
    body = '\n'.join(l[4:] for l in lines[start:end + 1])
    scope_src = 'def source_scope(code):\n' + '\n'.join('    ' + l for l in body.splitlines()) + '\n    return None\n'
    exec(compile(scope_src, str(PATCHED) + ':prepare-excerpt', 'exec'), env)
    return env['code_words'], env['source_scope'], scope_src


code_words, _source_scope, SCOPE_SRC = _load()


def new_rule(data):
    try:
        return 'REFUSE: run-time halt statement expect' if 'expect' in code_words(data) else None
    except Rejected as e:
        return 'REFUSE: ' + str(e)


def source_scope(data):
    try:
        _source_scope(data)
        return None
    except Rejected as e:
        return 'REFUSE: ' + str(e)


if __name__ == '__main__':
    print(SCOPE_SRC)
