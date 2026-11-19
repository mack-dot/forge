import sys, os, re
def resolve(p):
    if os.path.isfile(p): return p
    d, n = os.path.split(p); q = os.path.join(d, '.hol', 'objs', n)
    return q if os.path.isfile(q) else None
for f in sys.argv[1:]:
    lines = [l.rstrip('\n') for l in open(f)]
    print('==', f, len(lines), 'lines')
    pos = {}; byname = {}
    for i, l in enumerate(lines, 1):
        if not l.strip(): print('  EMPTY line', i); continue
        r = resolve(l)
        if r is None: print('  MISSING', i, l)
        base = os.path.basename(l)
        m = re.match(r'(.*)Theory\.(sig|sml)$', base)
        if m:
            byname.setdefault(base, []).append((i, l))
            pos.setdefault(m.group(1), i)
            # parents from generated .sml
            if base.endswith('.sml') and r:
                txt = open(r, errors='replace').read()
                mm = re.search(r'local open (.*?) in end', txt[:6000], re.S)
                ps = set(x[:-6] for x in (mm.group(1).split() if mm else []) if x.endswith('Theory'))
                pos.setdefault('__parents_' + m.group(1), ps)
    for b, occ in byname.items():
        if len(set(p for _, p in occ)) > 1: print('  DUP_DIFFERENT_PATH', b, occ)
        elif len(occ) > 1: print('  DUP_SAME', b, occ)
    for t in ['forge_refundRouteA2c', 'forge_refundR6Base', 'forge_refundR6Ffi', 'forge_refundR6Write']:
        if t not in pos: print('  ABSENT', t); continue
        ps = pos.get('__parents_' + t, set())
        for p in sorted(ps):
            if p in pos and not p.startswith('__'):
                print('  ', t, '@', pos[t], 'parent', p, '@', pos[p], 'OK' if pos[p] < pos[t] else 'ORDER_BAD')
