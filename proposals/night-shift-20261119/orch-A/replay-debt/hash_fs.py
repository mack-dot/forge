"""Read-only: sha256 of files matching name patterns under given roots. Writes only to argv[1]."""
import os, sys, hashlib, fnmatch
out = sys.argv[1]; roots = sys.argv[2:]
PAT = ['*.sml', '*.sml.*', '*.sml~', 'proof*', '*base-0003*', '*quick-0001*', '*replay-0026*']
T = {'78c550733b672b4fdc1017f64bcd8f4ecf1cba96a9ef1bf56db0902e3feb285f': 'base-0003.sml',
     '5809a9893b1e30b4cfc5d85356bc4404798177a791e7ac48ace09cfc3f027235': 'quick-0001.sml',
     '4d815de1bef1a2d64b180fcebb31a845c62acf4dc7fd656f3c2263279376099e': 'replay-0026.sml'}
n = hits = 0
with open(out, 'w') as f:
    for r in roots:
        for dp, dns, fns in os.walk(r):
            if dp.startswith(os.path.dirname(out)): continue
            for fn in fns:
                if not any(fnmatch.fnmatch(fn, p) for p in PAT): continue
                p = os.path.join(dp, fn)
                if os.path.islink(p) or not os.path.isfile(p): continue
                try:
                    if os.path.getsize(p) > 64 * 2**20: continue
                    h = hashlib.sha256(open(p, 'rb').read()).hexdigest()
                except OSError as e:
                    f.write(f'ERR {p} {e}\n'); continue
                n += 1; f.write(f'{h} {os.path.getsize(p)} {p}\n')
                if h in T: hits += 1; print('HIT', T[h], p)
print('files hashed', n, 'hits', hits)
