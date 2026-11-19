import sys, shutil, os, difflib
W, name, rel, old, new = sys.argv[1:6]
src=os.path.join(W,'proof','inputs'); dst=os.path.join(W,'negative',name,'inputs')
if os.path.exists(os.path.join(W,'negative',name)): shutil.rmtree(os.path.join(W,'negative',name))
shutil.copytree(src,dst)
p=os.path.join(dst,rel); s=open(p).read()
old=old.encode().decode('unicode_escape'); new=new.encode().decode('unicode_escape')
assert s.count(old)==1, (name, old)
t=s.replace(old,new); open(p,'w').write(t)
d=''.join(difflib.unified_diff(s.splitlines(1),t.splitlines(1),'a/'+rel,'b/'+rel))
open(os.path.join(W,'negative',name,'mutation.diff'),'w').write(d); print(d)
