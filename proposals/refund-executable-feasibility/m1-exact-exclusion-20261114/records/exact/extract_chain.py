"""Extract from the published lab_to_targetProofScript.sml the non-exported items that the
initial-state and compile-level regions (lines 10180-10562 and 11060-11213) needs, in file order. Read-only on the published file."""
import re, sys, json, hashlib
ROOT='/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/backend/proofs/'
src=open(ROOT+'lab_to_targetProofScript.sml').read().split('\n')
sig=open(ROOT+'.hol/objs/lab_to_targetProofTheory.sig').read()
exported=set(re.findall(r'val (\w+) : thm',sig))
START=re.compile(r"^(Theorem|Triviality|Definition|Datatype|Overload|Type|Resume|Finalise|val|fun|Theory|Ancestors|Libs)\b")
blocks=[]; cur=None
for i,l in enumerate(src[:11059],1):
    if START.match(l):
        cur={'start':i,'lines':[l]}; blocks.append(cur)
    elif cur is not None: cur['lines'].append(l)
def info(b):
    l=b['lines'][0]
    m=re.match(r"(Theorem|Triviality|Definition|Resume)\s+([\w']+)(\[[^\]]*\])?",l)
    if m: return m.group(1),m.group(2),m.group(3) or ''
    m=re.match(r"(val|fun)\s+([\w']+|_)",l)
    if m: return m.group(1),m.group(2),''
    return l.split()[0],'',''
byname={}
for b in blocks:
    k,n,a=info(b); b['kind'],b['name'],b['attr']=k,n,a
    b['text']='\n'.join(b['lines'])
    if k in('Theorem','Triviality') and n not in exported: byname[n]=b
    if k in('val','fun') and n!='_' and n not in exported: byname.setdefault(n,b)
region='\n'.join(src[10179:10562]+src[11059:11213])
need=set(); todo=[n for n in set(re.findall(r"[A-Za-z_][\w']*",region)) if n in byname]
while todo:
    n=todo.pop()
    if n in need: continue
    need.add(n)
    for m in set(re.findall(r"[A-Za-z_][\w']*",byname[n]['text'])):
        if m in byname and m not in need: todo.append(m)
keep=[b for b in blocks if not (7675<=b['start']<=9392 and 'simp' not in b['attr']) and not (10180<=b['start']<=10562) and (b['name'] in need and b['name'] not in ('tm','th') and b['kind'] in ('Theorem','Triviality','val','fun'))
      or (b['kind']=='val' and b['name']=='_' and b['start']<100)
      or b['kind']=='Overload'
      or (b['kind'] in('Theorem','Triviality') and 'simp' in b['attr'] and b['name'] not in exported)]
out=[]
for b in keep:
    t=b['text'].rstrip()
    t=re.sub(r"\n\(\*(?:(?!\*\)).|\n)*$","",t)   # drop a trailing unterminated comment opener
    out.append('(* published line %d *)\n%s\n'%(b['start'],t))
open('chain-locals.sml','w').write('\n'.join(out))
print(json.dumps({'kept':[(b['start'],b['kind'],b['name'],b['attr']) for b in keep]}))
