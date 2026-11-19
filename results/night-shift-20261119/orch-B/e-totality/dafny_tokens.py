r"""Conservative Dafny 4.11 lexer for one purpose: find identifier/keyword tokens outside comments and literals.

Lexical rules mirrored (Dafny reference manual, section "Lexical": comments, strings, chars, identifiers):
  - `// ...` to end of line (ended at the EARLIEST of CR, LF, VT, FF, NEL, LS, PS: fail closed);  `/* ... */` NESTED (Dafny nests block comments; checked by experiment N1);
  - "..." with backslash escapes;  @"..." verbatim with "" as the quote escape;
  - '...' character literal: one char or one escape (\x, \uXXXX, \U{...});
  - identifiers: [A-Za-z_] then [A-Za-z0-9_?'] (maximal munch; `Candidate?` and `x'` are one token).
    The caller also splits each token at `?` and `'` (fail closed: `x'expect` counts as containing `expect`).
Fail closed: an unterminated comment, string or character literal, a newline in a string, or a NUL byte raises
LexError (the caller refuses). Non-UTF-8 input raises LexError.
"""
import re

IDSTART = re.compile(r"[A-Za-z_]")
LINE_END = re.compile("[\\r\\n\\x0b\\x0c\\x85\\u2028\\u2029]")
IDCHARS = re.compile(r"[A-Za-z0-9_?']*")


class LexError(Exception):
    pass


def identifiers(data):
    """Yield (offset, token) for each identifier or keyword token outside comments and literals."""
    try:
        s = data.decode('utf-8') if isinstance(data, bytes) else data
    except UnicodeDecodeError:
        raise LexError('not UTF-8')
    if '\0' in s:
        raise LexError('NUL byte')
    i, n = 0, len(s)
    while i < n:
        c = s[i]
        if s.startswith('//', i):
            # Fail closed: end the comment at the EARLIEST possible line break, so that text which Dafny
            # might treat as code is always scanned (experiment S1/S3/S4 records what Dafny does).
            m = LINE_END.search(s, i)
            i = n if m is None else m.start()
        elif s.startswith('/*', i):
            depth, i = 1, i + 2
            while depth:
                if i >= n:
                    raise LexError('unterminated block comment')
                if s.startswith('/*', i):
                    depth, i = depth + 1, i + 2
                elif s.startswith('*/', i):
                    depth, i = depth - 1, i + 2
                else:
                    i += 1
        elif s.startswith('@"', i):
            i += 2
            while True:
                if i >= n:
                    raise LexError('unterminated verbatim string')
                if s[i] == '"':
                    if s.startswith('""', i):
                        i += 2
                        continue
                    i += 1
                    break
                i += 1
        elif c == '"':
            i += 1
            while True:
                if i >= n or s[i] in '\r\n':
                    raise LexError('unterminated string')
                if s[i] == '\\':
                    i += 2
                    continue
                if s[i] == '"':
                    i += 1
                    break
                i += 1
        elif c == "'":
            m = re.compile(r"'(\\U\{[0-9A-Fa-f_]{1,8}\}|\\u[0-9A-Fa-f]{4}|\\[^\r\n]|[^'\\\r\n])'").match(s, i)
            if not m:
                raise LexError('bad character literal at %d' % i)
            i = m.end()
        elif IDSTART.match(c):
            m = IDCHARS.match(s, i + 1)
            yield i, s[i:m.end()]
            i = m.end()
        else:
            i += 1
