#!/usr/bin/env python3
# Static SML hazard checker (worker W-pre). Reads files given on the command line. Reports per file:
# non-ASCII bytes, lines ending in an odd number of backslashes, backquotes outside strings/comments,
# unbalanced ( [ { and comments, let/local/struct/sig vs end, and val/fun inside a let body (between `in` and `end`).
# Exit 1 if any hazard is found.
import sys, re

KW_OPEN = {'let', 'local', 'struct', 'sig'}

def check(path):
    data = open(path, 'rb').read()
    issues = []
    for i, line in enumerate(data.split(b'\n'), 1):
        for j, b in enumerate(line):
            if b > 127:
                issues.append('NON_ASCII line %d col %d byte %d' % (i, j + 1, b)); break
        m = re.search(rb'(\\+)\s*$', line)
        if m and len(m.group(1)) % 2 == 1:
            issues.append('TRAILING_SINGLE_BACKSLASH line %d' % i)
    s = data.decode('latin-1')
    n = len(s); k = 0; line = 1
    brackets = []      # (char, line)
    blocks = []        # [kind, phase, line]  kind in let/local/struct/sig ; phase decl/body
    comment_depth = 0; comment_line = 0
    pairs = {')': '(', ']': '[', '}': '{'}
    while k < n:
        c = s[k]
        if c == '\n':
            line += 1; k += 1; continue
        if comment_depth:
            if s.startswith('(*', k): comment_depth += 1; k += 2; continue
            if s.startswith('*)', k): comment_depth -= 1; k += 2; continue
            k += 1; continue
        if s.startswith('(*', k):
            comment_depth = 1; comment_line = line; k += 2; continue
        if s.startswith('*)', k):
            issues.append('STRAY_COMMENT_CLOSE line %d' % line); k += 2; continue
        if c == '"' or (c == '#' and k + 1 < n and s[k + 1] == '"'):
            if c == '#': k += 1
            start = line; k += 1
            while k < n and s[k] != '"':
                if s[k] == '\\':
                    if k + 1 < n and s[k + 1] in ' \t\n\r':  # string gap \ ... \
                        k += 1
                        while k < n and s[k] in ' \t\n\r':
                            if s[k] == '\n': line += 1
                            k += 1
                        if k < n and s[k] == '\\': k += 1
                        else: issues.append('BAD_STRING_GAP line %d' % line)
                        continue
                    k += 2; continue
                if s[k] == '\n':
                    issues.append('NEWLINE_IN_STRING starting line %d' % start); line += 1
                k += 1
            if k >= n: issues.append('UNTERMINATED_STRING line %d' % start)
            k += 1; continue
        if c == '`':
            issues.append('BACKQUOTE line %d' % line); k += 1; continue
        if c in '([{':
            brackets.append((c, line)); k += 1; continue
        if c in ')]}':
            if not brackets or brackets[-1][0] != pairs[c]:
                issues.append('UNBALANCED %s line %d (open %s)' % (c, line, brackets[-1] if brackets else None))
            else:
                brackets.pop()
            k += 1; continue
        if c.isascii() and (c.isalpha() or c == '_'):
            m = re.match(r"[A-Za-z_][A-Za-z0-9_']*", s[k:])
            w = m.group(0)
            prev = s[k - 1] if k > 0 else ' '
            if prev != '.':
                if w in KW_OPEN:
                    blocks.append([w, 'decl', line, len(brackets)])
                elif w == 'in':
                    if blocks and blocks[-1][0] in ('let', 'local') and blocks[-1][1] == 'decl':
                        blocks[-1][1] = 'body'
                    else:
                        issues.append('STRAY_IN line %d' % line)
                elif w == 'end':
                    if not blocks: issues.append('STRAY_END line %d' % line)
                    else: blocks.pop()
                elif w in ('val', 'fun'):
                    if blocks and blocks[-1][0] == 'let' and blocks[-1][1] == 'body':
                        issues.append('VAL_IN_LET_BODY line %d (let at line %d)' % (line, blocks[-1][2]))
            k += len(w); continue
        k += 1
    if comment_depth: issues.append('UNCLOSED_COMMENT from line %d' % comment_line)
    for b in brackets: issues.append('UNCLOSED %s line %d' % b)
    for b in blocks: issues.append('UNCLOSED_BLOCK %s line %d' % (b[0], b[2]))
    return issues

bad = 0
for p in sys.argv[1:]:
    iss = check(p)
    print(('OK   ' if not iss else 'FAIL ') + p + ('' if not iss else ' ' + str(len(iss))))
    for x in iss[:30]: print('     ' + x)
    bad += bool(iss)
sys.exit(1 if bad else 0)
