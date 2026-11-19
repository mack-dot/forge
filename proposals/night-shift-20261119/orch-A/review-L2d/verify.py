import json,hashlib,os,sys
B='/Users/mackianni/forge/results/m1b-routeA-20261119/attempt-0001/'
def h(p):
    return hashlib.sha256(open(p,'rb').read()).hexdigest()
for c in sys.argv[1:]:
    d=json.load(open(B+c+'/command.json'))
    bad=0
    print('==',c)
    print(' source', h(B+d['source'])==d['source_sha256'], 'proof.sml==source', h(B+c+'/proof.sml')==d['source_sha256'])
    print(' stdout', h(B+c+'/stdout.log')==d['stdout_sha256'], 'stderr', h(B+c+'/stderr.log')==d['stderr_sha256'], os.path.getsize(B+c+'/stderr.log'))
    for k,v in d['objects'].items(): print(' obj',k,h(B+c+'/'+k)==v)
    n=0
    for k,v in d['input_sha256'].items():
        n+=1
        if not os.path.exists(k): print(' MISSING',k); bad+=1; continue
        if os.path.getsize(k)>200e6: continue
        if h(k)!=v: print(' INPUT MISMATCH',k); bad+=1
    print(' inputs checked',n,'bad',bad)
    # parents that are route cases
    for k,v in d['input_sha256'].items():
        if k.startswith(B) and '/.hol/objs/' in k:
            pc=k[len(B):].split('/')[0]
            pj=json.load(open(B+pc+'/command.json'))
            rel=k[len(B+pc)+1:]
            print(' parent',pc,rel, pj['objects'].get(rel)==v, 'parent exit',pj['actual_exit'])
