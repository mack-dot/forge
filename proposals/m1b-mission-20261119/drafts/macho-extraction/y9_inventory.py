import json,sys
m=json.load(open(sys.argv[1])); d=open(sys.argv[2],"rb").read()
R=[]
def add(a,b,what): R.append((a,b,what))
add(0,32,"mach_header_64"); add(32,32+m["header"]["sizeofcmds"],"load commands (18)")
for c in m["load_commands"]:
    s=c.get("segment")
    if s:
        for x in s["sections"]:
            if x["offset"]: add(x["offset"],x["offset"]+x["size"],"%s,%s"%(x["segname"],x["sectname"]))
    if "dataoff" in c and c["datasize"]: add(c["dataoff"],c["dataoff"]+c["datasize"],c["name"])
    if c["name"]=="LC_SYMTAB":
        add(c["symoff"],c["symoff"]+16*c["nsyms"],"symtab nlist_64"); add(c["stroff"],c["stroff"]+c["strsize"],"string table")
    if c["name"]=="LC_DYSYMTAB": add(c["indirectsymoff"],c["indirectsymoff"]+4*c["nindirectsyms"],"indirect symbol table")
R.sort()
# split __text by symbols of interest
out=[];pos=0
for a,b,w in R:
    if a>pos: out.append((pos,a,"GAP","zeros" if not any(d[pos:a]) else "NONZERO"))
    out.append((a,b,w,"zeros" if not any(d[a:b]) else "data")); pos=max(pos,b)
if pos<len(d): out.append((pos,len(d),"GAP","zeros" if not any(d[pos:]) else "NONZERO"))
for a,b,w,z in out: print("%7d %7d %7d  %-40s %s"%(a,b,b-a,w,z))
# __text sub-ranges
T=[(16384,16492,"cml_main stub (108)"),(16492,16592,"NOP pad + 6 FFI trampolines (100)"),(16592,147028,"CODE SLICE"),
   (147028,147456,"cake codebuffer (428)"),(147456,151552,".space 4096 after codebuffer_end"),(151552,153800,"C run-time + main (basis_ffi.c)")]
print("__text split:")
for a,b,w in T: print("%7d %7d %7d  %-40s %s"%(a,b,b-a,w,"zeros" if not any(d[a:b]) else "data"))
print("bitmap tail pad 200496..212992 zeros:", not any(d[200496:212992]), " heap/stack slots 180224..180248 zeros:", not any(d[180224:180248]))
