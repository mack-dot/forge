"""Y12: read the HOL-printed term of source_ensures_def and source_body_def (stored theory doc of U294)
and compare with the trees of s4_check.read_export. A test of my reader against HOL's own parse output."""
import html, re, sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from s4_check import read_export, show
t = html.unescape(re.sub(r'<[^>]+>', '', open(sys.argv[1], encoding='utf-8').read()))
def term_of(name):
    i = t.index(name + '\n⊢ '); j = t.index('\n\n', i)
    return t[i:j].split('=', 1)[1]
TOK = re.compile(r'\s*(«[^»]*»|\(|\)|\[|\]|;|,|-?\d+|[A-Za-z_]+)')
def toks(s):
    out, p = [], 0
    while p < len(s):
        if s[p:].strip() == '': break
        m = TOK.match(s, p); assert m, s[p:p+20]; out.append(m.group(1)); p = m.end()
    return out
class P:
    def __init__(s, ts): s.t, s.i = ts, 0
    def nxt(s): s.i += 1; return s.t[s.i - 1]
    def atom(s):
        x = s.nxt()
        if x == '(':
            e = s.app(); assert s.nxt() == ')'; return e
        if x == '[':
            items = []
            while s.t[s.i] != ']':
                items.append(s.app())
                if s.t[s.i] == ';': s.i += 1
            s.i += 1; return items
        if x.startswith('«'): return ('S', x[1:-1])
        if re.fullmatch(r'-?\d+', x): return ('N', int(x))
        return ('C', x)
    def app(s):
        head = s.atom(); args = []
        while s.i < len(s.t) and s.t[s.i] not in (')', ']', ';', ','):
            args.append(s.atom())
        return (head, args) if args else head
def conv(e):
    (h, args) = e if isinstance(e, tuple) and len(e) == 2 and isinstance(e[1], list) else (e, [])
    name = h[1]
    if name == 'Var': return ('Var', args[0][1])
    if name == 'Lit':
        (lh, la) = args[0]
        return {'IntL': lambda: ('Int', la[0][1]), 'StrL': lambda: ('Str', la[0][1]),
                'BoolL': lambda: ('Bool', la[0][1] == 'T')}[lh[1]]()
    if name == 'UnOp': return ('Not', conv(args[1]))
    if name == 'BinOp': return (args[0][1], conv(args[1]), conv(args[2]))
    raise ValueError(name)
hol_ens = [conv(x) for x in P(toks(term_of('source_ensures_def'))).app()]
mine = read_export(open(sys.argv[2]).read())['ensures']
for k, (a, b) in enumerate(zip(hol_ens, mine)):
    print('ensures[%d]' % k, 'same' if a == b else 'DIFF\n  HOL : %s\n  mine: %s' % (show(a), show(b)))
ok = len(hol_ens) == len(mine) == 3 and hol_ens == mine
print('HOL-printed source_ensures equals my reading of the export:', ok)
sys.exit(0 if ok else 1)
