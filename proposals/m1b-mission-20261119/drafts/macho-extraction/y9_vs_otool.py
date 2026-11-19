import json,re,sys
m=json.load(open(sys.argv[1])); txt=open(sys.argv[2]).read()
blocks=re.split(r"\nLoad command \d+\n",txt)[1:]
mine=m["load_commands"]; diffs=0; checked=0
assert len(blocks)==len(mine),(len(blocks),len(mine))
def num(v):
    v=v.split()[0]; return int(v,16) if v.startswith("0x") else int(v)
for b,c in zip(blocks,mine):
    kv=[l.split(None,1) for l in b.splitlines() if l.strip()]
    d={}
    for p in kv:
        if len(p)==2: d.setdefault(p[0],p[1].strip())
    if d["cmd"]!=c["name"]: print("CMD DIFF",d["cmd"],c["name"]); diffs+=1
    checked+=1
    if num(d["cmdsize"])!=c["cmdsize"]: diffs+=1; print("size diff",c)
    if "segment" in c:
        s=c["segment"]
        for k in ["vmaddr","vmsize","fileoff","filesize","nsects"]:
            checked+=1
            if num(d[k])!=s[k]: diffs+=1; print("SEG DIFF",s["segname"],k,d[k],s[k])
        # sections
        secs=re.split(r"\nSection\n",b)[1:]
        for st,x in zip(secs,s["sections"]):
            sd=dict(l.split(None,1) for l in st.splitlines() if len(l.split(None,1))==2)
            for k,ok in [("sectname",x["sectname"]),("addr",x["addr"]),("size",x["size"]),("offset",x["offset"]),("reserved1",x["reserved1"]),("reserved2",x["reserved2"])]:
                checked+=1
                v=sd[k].strip()
                if (v if k=="sectname" else num(v))!=ok: diffs+=1; print("SECT DIFF",x["sectname"],k,v,ok)
    for k in ["symoff","nsyms","stroff","strsize","dataoff","datasize","entryoff","indirectsymoff","nindirectsyms","nlocalsym","nextdefsym","nundefsym"]:
        if k in c and k in d:
            checked+=1
            if num(d[k])!=c[k]: diffs+=1; print("DIFF",c["name"],k,d[k],c[k])
print("checked",checked,"diffs",diffs); sys.exit(1 if diffs else 0)
