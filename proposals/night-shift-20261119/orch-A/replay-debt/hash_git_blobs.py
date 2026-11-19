"""Read-only: sha256 of every blob listed by git cat-file --batch-all-objects. Writes only to argv[2]."""
import subprocess, hashlib, sys
repo, out = sys.argv[1], sys.argv[2]
TARGETS = {
 '78c550733b672b4fdc1017f64bcd8f4ecf1cba96a9ef1bf56db0902e3feb285f': 'base-0003.sml',
 '5809a9893b1e30b4cfc5d85356bc4404798177a791e7ac48ace09cfc3f027235': 'quick-0001.sml',
 '4d815de1bef1a2d64b180fcebb31a845c62acf4dc7fd656f3c2263279376099e': 'replay-0026.sml',
}
blobs = [l.split()[1] for l in open(sys.argv[3]) if l.startswith('blob ')]
p = subprocess.Popen(['git', '-C', repo, 'cat-file', '--batch'], stdin=subprocess.PIPE, stdout=subprocess.PIPE)
hits = 0
with open(out, 'w') as f:
    for oid in blobs:
        p.stdin.write((oid + '\n').encode()); p.stdin.flush()
        hdr = p.stdout.readline().split()
        size = int(hdr[2]); data = p.stdout.read(size); p.stdout.read(1)
        h = hashlib.sha256(data).hexdigest()
        f.write(f'{oid} {size} {h}\n')
        if h in TARGETS:
            hits += 1; print('HIT', TARGETS[h], oid, size)
p.stdin.close(); p.wait()
print('blobs hashed', len(blobs), 'hits', hits)
