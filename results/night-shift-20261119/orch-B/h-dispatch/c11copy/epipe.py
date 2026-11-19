# c11-host: run a CLI with stdout = a pipe whose reader is closed before the CLI writes (EPIPE).
# Usage: python3 -I epipe.py <target root> <home> <delay ms> -- <cli.ts> args... (the literal START is replaced by now+delay)
# Prints the CLI's exit code and stderr tail as JSON. Exit 0 always (the caller judges).
import json, os, subprocess, sys, time
root, home, delay = sys.argv[1], sys.argv[2], int(sys.argv[3])
args = sys.argv[5:]
start = str(int(time.time() * 1000) + delay)
args = [start if a == 'START' else a for a in args]
env = {'PATH': '/opt/homebrew/bin:/usr/bin:/bin', 'HOME': home, 'LANG': 'C', 'NODE_PATH': '<REPO>/node_modules'}
r, w = os.pipe()
p = subprocess.Popen(['/opt/homebrew/bin/node', '--import', 'tsx', *args], cwd=root, env=env, stdout=w, stderr=subprocess.PIPE, stdin=subprocess.DEVNULL)
os.close(w); os.close(r)   # the reader is gone before the CLI writes its result line
err = p.stderr.read().decode(errors='replace'); p.wait(timeout=120)
print(json.dumps({'exit': p.returncode, 'epipe_in_stderr': 'EPIPE' in err, 'stderr_tail': [l for l in err.splitlines() if 'Warning' not in l and 'trace-warnings' not in l][-3:]}))
