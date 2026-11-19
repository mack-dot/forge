import sys,json,collections
# summ.py results-*.jsonl : per module outcome counts; must-be-zero counts; liveness (all 14 runs match the spec).
c=collections.defaultdict(collections.Counter); unsafe=alive=over=0; runs=0; allmatch=collections.defaultdict(lambda: True)
for f in sys.argv[1:]:
  for l in open(f):
    d=json.loads(l); runs+=1; k=d['set']+'/'+d['mod']
    c[k][str(d['exit'])]+=1; unsafe+=d['unsafe']; alive+=d['pg_alive']; over+=(d['wall_ms']>4000)
    allmatch[k]&=d['match']
verbose='-v' in sys.argv[0:1] or True
for k,v in sorted(c.items()): print(k, dict(v), 'CONFORMANT' if allmatch[k] else '')
print('runs',runs,'modules',len(c),'unsafe_authorized',unsafe,'pg_alive',alive,'wall_over_4s',over,'conformant_modules',sum(allmatch.values()))
