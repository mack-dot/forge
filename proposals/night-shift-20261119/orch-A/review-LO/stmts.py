import re,sys,hashlib
# Extract statement quotation (first ``...`` after thm "NAME") and definition quotations (defn "NAME" `...`).
def ext(src):
    out={}
    for m in re.finditer(r'thm\s+"([A-Za-z0-9_]+)"', src):
        rest=src[m.end():]
        q=re.search(r'``(.*?)``', rest, re.S)
        if q: out['T:'+m.group(1)]=' '.join(q.group(1).split())
    for m in re.finditer(r'defn\s+"([A-Za-z0-9_]+)"\s*`(.*?)`;', src, re.S):
        out['D:'+m.group(1)]=' '.join(m.group(2).split())
    return out
files=sys.argv[1:]
data={f:ext(open(f).read()) for f in files}
names=sorted(set().union(*[set(d) for d in data.values()]))
base=data[files[0]]
for n in names:
    vals=[data[f].get(n) for f in files]
    tags=[]
    for v in vals:
        tags.append('-' if v is None else hashlib.sha256(v.encode()).hexdigest()[:6])
    print(n, ' '.join(tags))
