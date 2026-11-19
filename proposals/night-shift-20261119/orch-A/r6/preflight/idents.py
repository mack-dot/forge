import sys, re
def strip(s):
    out=[];k=0;n=len(s);d=0
    while k<n:
        if s.startswith('(*',k): d+=1;k+=2;continue
        if d:
            if s.startswith('*)',k): d-=1;k+=2
            else: k+=1
            continue
        if s[k]=='"':
            k+=1
            while k<n and s[k]!='"': k+= 2 if s[k]=='\\' else 1
            k+=1; out.append(' "" '); continue
        out.append(s[k]);k+=1
    return ''.join(out)
def toks(p):
    s=strip(open(p,encoding='latin-1').read())
    return re.findall(r"(?<![A-Za-z0-9_'.])([A-Za-z_][A-Za-z0-9_']*)(?![A-Za-z0-9_']*\.)", s), s
KW=set("val fun fn let in end local open type datatype of case if then else andalso orelse handle raise structure struct sig op as true false nil ref not before o div mod".split())
target=sys.argv[1].split(','); ref=sys.argv[2].split(',')
defined=set()
for p in target+ref:
    _,s=toks(p)
    defined|=set(re.findall(r"\b(?:val|fun|and|type)\s+(?:rec\s+)?\(?([A-Za-z_][A-Za-z0-9_']*)",s))
    defined|=set(re.findall(r"\bfn\s+\(?([A-Za-z_][A-Za-z0-9_']*)",s))
used_ref=set()
for p in ref: used_ref|=set(toks(p)[0])
cand=set()
for p in target: cand|=set(toks(p)[0])
rest=sorted(cand-KW-defined-used_ref)
print(len(rest)); print(' '.join(rest))
