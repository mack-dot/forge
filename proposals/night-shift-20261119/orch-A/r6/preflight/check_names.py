import sys, re, os
sigs = {}
for p in open(sys.argv[1]).read().split():
    sigs[os.path.basename(p)[:-len('Theory.sig')]] = p
for p in sys.argv[3:]:
    sigs[os.path.basename(p)[:-len('Theory.sig')]] = p
cache = {}
def names(t):
    if t not in cache:
        txt = open(sigs[t], errors='replace').read()
        cache[t] = set(re.findall(r"val\s+([A-Za-z0-9_']+)\s*:", txt))
    return cache[t]
bad = 0
for line in open(sys.argv[2]):
    line = line.strip()
    if not line: continue
    if ' ' in line:
        thy, nm = line.split()
    else:
        a, nm = line.split('.', 1); thy = a[:-len('Theory')]
    if thy not in sigs: print('NO_SIG', thy, nm); bad += 1; continue
    ok = nm in names(thy)
    if not ok: bad += 1
    print('OK  ' if ok else 'MISSING', thy, nm)
print('BAD', bad)
