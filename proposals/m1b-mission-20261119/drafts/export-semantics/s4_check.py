#!/usr/bin/env python3
"""Y12 (M1-B, link S4). An independent reader. It is a TEST tool, not a proof.

It compares three texts of the flat contract, clause by clause:
  E  the exported S-expression (3,621 bytes, SHA-256 58154ddf...), read by its own S-expression reader;
  O  the Dafny source the export was made from (export-0003/input.dfy);
  L  the FlatCore.dfy that LinkedRefund.dfy includes (proofs/linked-refund/inputs/transport/FlatCore.dfy).
O and L are parsed by a small Dafny parser for this fragment ONLY. Each text becomes the same tree form:
  ('Var', name) | ('Int', n) | ('Str', s) | ('Bool', b) | ('Not', e) | (op, e0, e1)
with op in Eq Neq Le Lt Ge And Or Imp. Dafny `<==>` becomes Eq (the patched exporter does the same; this
checker records that it accepts that mapping only when both sides are bool). Chains `a <= b <= c` become
And(Le(a,b), Le(b,c)). It compares: the signature (names, types, order), requires, ensures (each
conjunct of each ensures), reads, modifies, decreases and the method body.

Usage: s4_check.py EXPORT.sexp ORIGINAL.dfy LINKED.dfy   -> exit 0 if all three agree, 1 if any differ.
"""
import hashlib, re, sys

# ----------------------------------------------------------------------------- S-expression reader
def sexp_tokens(text):
    """Tokens: '(' ')' and atoms. A quoted atom keeps its content; '\\' escapes as in mlsexp
    (only \\\\ and \\" are accepted there; anything else is an error here too)."""
    i, out = 0, []
    while i < len(text):
        c = text[i]
        if c in ' \t\r\n':
            i += 1
        elif c in '()':
            out.append(c); i += 1
        elif c == '"':
            i += 1; buf = []
            while True:
                if i >= len(text): raise ValueError('unterminated string')
                c = text[i]
                if c == '\\':
                    if i + 1 < len(text) and text[i + 1] in '\\"':
                        buf.append(text[i + 1]); i += 2; continue
                    raise ValueError('unknown escape at %d' % i)
                if c == '"': i += 1; break
                buf.append(c); i += 1
            out.append(('ATOM', ''.join(buf)))
        else:
            j = i
            while j < len(text) and text[j] not in ' \t\r\n()"': j += 1
            out.append(('ATOM', text[i:j])); i = j
    return out

def sexp_parse(text):
    toks = sexp_tokens(text); pos = 0
    def one():
        nonlocal pos
        t = toks[pos]; pos += 1
        if t == '(':
            items = []
            while toks[pos] != ')': items.append(one())
            pos += 1
            return items
        if t == ')': raise ValueError('unexpected )')
        return t[1]
    tree = one()
    if pos != len(toks): raise ValueError('trailing tokens after the program')
    return tree

def sx_type(t):
    assert isinstance(t, list) and len(t) == 1, t
    return {'BoolT': 'bool', 'IntT': 'int', 'StrT': 'string'}[t[0]]

def sx_exp(t):
    head = t[0]
    if head == 'Var': return ('Var', t[1])
    if head == 'Lit':
        k, v = t[1][0], t[1][1]
        if k == 'IntL': return ('Int', int(v))
        if k == 'StrL': return ('Str', v)
        if k == 'BoolL': return ('Bool', {'True': True, 'False': False}[v])
        raise ValueError(k)
    if head == 'UnOp':
        assert t[1] == ['Not']; return ('Not', sx_exp(t[2]))
    if head == 'BinOp':
        (op,) = t[1]
        if op not in ('Eq', 'Neq', 'Le', 'Lt', 'Ge', 'And', 'Or', 'Imp'):
            raise ValueError('operator outside the fragment: ' + op)
        return (op, sx_exp(t[2]), sx_exp(t[3]))
    raise ValueError('expression outside the fragment: ' + head)

def sx_stmt(t):
    head = t[0]
    if head == 'Then': return sx_stmt(t[1]) + sx_stmt(t[2])
    if head == 'Assign':
        out = []
        for lhs, rhs in t[1]:
            assert lhs[0] == 'VarLhs' and rhs[0] == 'ExpRhs'
            out.append(('assign', lhs[1], sx_exp(rhs[1])))
        return out
    if head == 'If': return [('if', sx_exp(t[1]), sx_stmt(t[2]), sx_stmt(t[3]))]
    if head == 'Return': return [('return',)]
    raise ValueError('statement outside the fragment: ' + head)

def read_export(text):
    prog = sexp_parse(text)
    assert prog[0] == 'Program' and len(prog) == 2 and len(prog[1]) == 1, 'one member expected'
    m = prog[1][0]
    assert m[0] == 'Method' and len(m) == 10, 'Method has 9 fields'
    _, name, ins, req, ens, reads, decr, outs, mods, body = m
    return {'name': name,
            'ins': [(n, sx_type(ty)) for n, ty in ins],
            'outs': [(n, sx_type(ty)) for n, ty in outs],
            'requires': [sx_exp(e) for e in req], 'ensures': [sx_exp(e) for e in ens],
            'reads': [sx_exp(e) for e in reads], 'modifies': [sx_exp(e) for e in mods],
            'decreases': [sx_exp(e) for e in decr], 'body': sx_stmt(body)}

# ----------------------------------------------------------------------------- Dafny reader (fragment)
TOK = re.compile(r'\s*(?:(//[^\n]*|/\*(?:.|\n)*?\*/)|("(?:[^"\\]|\\.)*")|(<==>|==>|<==|&&|\|\||==|!=|<=|>=|:=|[<>!(){},:;])|'
                 r'([0-9]+)|([A-Za-z_][A-Za-z0-9_]*))')

def dfy_tokens(src):
    pos, out = 0, []
    while pos < len(src):
        if src[pos:].strip() == '': break
        m = TOK.match(src, pos)
        if not m: raise ValueError('cannot read Dafny text at %r' % src[pos:pos + 30])
        pos = m.end()
        com, s, sym, num, ident = m.groups()
        if com: continue
        if s is not None:
            if '\\' in s: raise ValueError('escapes not handled in this fragment reader')
            out.append(('STR', s[1:-1]))
        elif sym: out.append(('SYM', sym))
        elif num: out.append(('INT', int(num)))
        else: out.append(('ID', ident))
    return out

class DP:
    """Precedence as in the Dafny reference manual (section 9.2): <==> lowest; then ==> (right assoc)
    and <== ; then && / || (cannot be mixed without parentheses); then relations (chains of <=, <, ==);
    then unary !; then primaries."""
    def __init__(self, toks, types): self.t, self.i, self.types = toks, 0, types
    def peek(self, k=0): return self.t[self.i + k] if self.i + k < len(self.t) else ('EOF', None)
    def take(self, kind=None, val=None):
        tok = self.peek()
        if (kind and tok[0] != kind) or (val is not None and tok[1] != val):
            raise ValueError('expected %s %s, got %r' % (kind, val, tok))
        self.i += 1; return tok
    def at(self, val): return self.peek()[0] == 'SYM' and self.peek()[1] == val
    def typ(self, e):
        k = e[0]
        if k == 'Var': return self.types[e[1]]
        if k == 'Int': return 'int'
        if k == 'Str': return 'string'
        return 'bool'
    def equiv(self):
        e = self.implies()
        while self.at('<=='+'>'):
            self.take(); r = self.implies()
            assert self.typ(e) == 'bool' and self.typ(r) == 'bool'
            e = ('Eq', e, r)           # Iff on bool, recorded as Eq
        return e
    def implies(self):
        e = self.logic()
        if self.at('==>'):
            self.take(); return ('Imp', e, self.implies())
        return e
    def logic(self):
        e = self.rel(); op = None
        while self.at('&&') or self.at('||'):
            o = 'And' if self.take()[1] == '&&' else 'Or'
            if op and o != op: raise ValueError('mixed && and || without parentheses')
            op = o; e = (o, e, self.rel())
        return e
    def rel(self):
        first = self.unary(); parts = []; cur = first
        while self.peek()[0] == 'SYM' and self.peek()[1] in ('==', '!=', '<=', '<', '>='):
            sym = self.take()[1]; nxt = self.unary()
            op = {'==': 'Eq', '!=': 'Neq', '<=': 'Le', '<': 'Lt', '>=': 'Ge'}[sym]
            if op in ('Eq', 'Neq') and self.typ(cur) != self.typ(nxt):
                raise ValueError('ill-typed equality')
            parts.append((op, cur, nxt)); cur = nxt
        if not parts: return first
        if len(parts) > 2 or any(p[0] == 'Neq' for p in parts) and len(parts) > 1:
            raise ValueError('chain outside the fragment')
        e = parts[0]
        for p in parts[1:]: e = ('And', e, p)
        return e
    def unary(self):
        if self.at('!'):
            self.take(); return ('Not', self.unary())
        return self.prim()
    def prim(self):
        tok = self.take()
        if tok == ('SYM', '('):
            e = self.equiv(); self.take('SYM', ')'); return e
        if tok[0] == 'INT': return ('Int', tok[1])
        if tok[0] == 'STR': return ('Str', tok[1])
        if tok[0] == 'ID':
            if tok[1] in ('true', 'false'): return ('Bool', tok[1] == 'true')
            return ('Var', tok[1])
        raise ValueError('unexpected %r' % (tok,))

def read_dafny(src):
    toks = dfy_tokens(src); p = DP(toks, {})
    p.take('ID', 'module'); p.take('ID'); p.take('SYM', '{')
    p.take('ID', 'method'); name = p.take('ID')[1]
    def formals():
        p.take('SYM', '('); out = []
        while not p.at(')'):
            n = p.take('ID')[1]; p.take('SYM', ':'); ty = p.take('ID')[1]; out.append((n, ty))
            if p.at(','): p.take()
        p.take('SYM', ')'); return out
    ins = formals(); p.take('ID', 'returns'); outs = formals()
    p.types = dict(ins + outs)
    spec = {'requires': [], 'ensures': [], 'reads': [], 'modifies': [], 'decreases': None}
    while p.peek()[0] == 'ID' and p.peek()[1] in spec:
        kw = p.take()[1]
        if kw == 'modifies':
            p.take('SYM', '{'); p.take('SYM', '}')   # a literal empty set; the exporter drops it
            continue
        if kw == 'decreases':           # a comma-separated list (printed by --rprint)
            spec[kw] = [p.equiv()]
            while p.at(','): p.take(); spec[kw].append(p.equiv())
            continue
        spec[kw].append(p.equiv())
    def block():
        p.take('SYM', '{'); out = []
        while not p.at('}'):
            if p.peek() == ('ID', 'if'):
                p.take(); c = p.equiv(); th = block(); p.take('ID', 'else'); el = block()
                out.append(('if', c, th, el))
            else:
                v = p.take('ID')[1]; p.take('SYM', ':='); e = p.equiv(); p.take('SYM', ';')
                out.append(('assign', v, e))
        p.take('SYM', '}'); return out
    body = block(); p.take('SYM', '}')
    if p.peek()[0] != 'EOF': raise ValueError('text after the module')
    # Dafny's default decreases clause for a method is its in-parameters (reference manual 7.1.3).
    decr = spec['decreases'] if spec['decreases'] is not None else [('Var', n) for n, _ in ins]
    return {'name': name, 'ins': ins, 'outs': outs, 'requires': spec['requires'],
            'ensures': spec['ensures'], 'reads': [], 'modifies': spec['modifies'],
            'decreases': decr, 'body': body + [('return',)]}

# ----------------------------------------------------------------------------- printing and comparing
PREC = {'Eq': 3, 'Neq': 3, 'Le': 3, 'Lt': 3, 'Ge': 3}
SYMS = {'Eq': '==', 'Neq': '!=', 'Le': '<=', 'Lt': '<', 'Ge': '>=', 'And': '&&', 'Or': '||', 'Imp': '==>'}

def show(e):
    k = e[0]
    if k == 'Var': return e[1]
    if k == 'Int': return str(e[1])
    if k == 'Str': return '"%s"' % e[1]
    if k == 'Bool': return 'true' if e[1] else 'false'
    if k == 'Not': return '!' + show(e[1])
    return '(%s %s %s)' % (show(e[1]), SYMS[k], show(e[2]))

def conjuncts(e):
    return conjuncts(e[1]) + conjuncts(e[2]) if e[0] == 'And' else [e]

def clauses(m):
    """Named clauses: each signature item, each ensures split one level into its main parts."""
    out = [('name', m['name'])]
    out += [('in[%d]' % i, '%s: %s' % x) for i, x in enumerate(m['ins'])]
    out += [('out[%d]' % i, '%s: %s' % x) for i, x in enumerate(m['outs'])]
    for kw in ('requires', 'reads', 'modifies', 'decreases'):
        out.append((kw, [show(e) for e in m[kw]]))
    for j, e in enumerate(m['ensures']):
        out.append(('ensures[%d] top' % j, e[0] + ' of ' + show(e[1])))
        rhs = e[2]
        for c, x in enumerate(conjuncts(rhs)):
            out.append(('ensures[%d] rhs conjunct %d' % (j, c), show(x)))
        out.append(('ensures[%d] full tree' % j, show(e)))
    def walk(stmts, path):
        for s, st in enumerate(stmts):
            if st[0] == 'assign': out.append(('body%s[%d] %s :=' % (path, s, st[1]), show(st[2])))
            elif st[0] == 'if':
                out.append(('body%s[%d] if' % (path, s), show(st[1])))
                walk(st[2], path + '[%d].then' % s); walk(st[3], path + '[%d].else' % s)
            else: out.append(('body%s[%d]' % (path, s), st[0]))
    walk(m['body'], '')
    out.append(('ensures count', len(m['ensures'])))
    return out

def main(argv):
    exp_path, orig_path, link_path = argv[1:4]
    raw = open(exp_path, 'rb').read()
    print('export   bytes', len(raw), 'sha256', hashlib.sha256(raw).hexdigest())
    for p in (orig_path, link_path):
        b = open(p, 'rb').read(); print('dafny    bytes', len(b), 'sha256', hashlib.sha256(b).hexdigest(), p)
    E = clauses(read_export(raw.decode('ascii')))
    O = clauses(read_dafny(open(orig_path, encoding='utf-8').read()))
    L = clauses(read_dafny(open(link_path, encoding='utf-8').read()))
    keys = []
    for lst in (E, O, L):
        for k, _ in lst:
            if k not in keys: keys.append(k)
    dE, dO, dL = dict(E), dict(O), dict(L)
    diffs = 0
    print('\n| clause | E (export) | O = E? | L = E? |')
    print('|---|---|---|---|')
    for k in keys:
        e, o, l = dE.get(k, '<absent>'), dO.get(k, '<absent>'), dL.get(k, '<absent>')
        ok_o, ok_l = (o == e), (l == e)
        if not (ok_o and ok_l): diffs += 1
        if k.endswith('full tree'): shown = '(full tree, %d chars)' % len(str(e))
        else: shown = str(e)
        print('| %s | `%s` | %s | %s |' % (k, shown, 'same' if ok_o else 'DIFF: ' + str(o),
                                         'same' if ok_l else 'DIFF: ' + str(l)))
    print('\nclauses compared:', len(keys), ' differences:', diffs)
    return 0 if diffs == 0 else 1

if __name__ == '__main__':
    sys.exit(main(sys.argv))
