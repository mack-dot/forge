"""c9-x8: X11 row E11 asks whether libSystem/dyld start a helper thread in a plain CLI process.
Spawn the real refund executable blocked in read(0); count its threads with ps -M; then finish the run.
Exit 1 if more than one thread is seen (A-SINGLE-THREAD premise false as stated); 0 otherwise."""
import hashlib, subprocess, sys, time
EXE = '/Users/mackianni/forge/results/night-shift-20261119/orch-A/ffi-c-audit/refund'
assert hashlib.sha256(open(EXE, 'rb').read()).hexdigest().startswith('b8ed5ec2')
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C', 'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}
p = subprocess.Popen([EXE], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=ENV)
time.sleep(0.4)
ps = subprocess.run(['/bin/ps', '-M', '-p', str(p.pid)], capture_output=True, timeout=5).stdout.decode()
lines = [l for l in ps.splitlines()[1:] if l.strip()]
print(ps)
out, err = p.communicate(b'', timeout=20)
print('threads=%d rc=%d out=%d' % (len(lines), p.returncode, len(out)))
sys.exit(1 if len(lines) > 1 else 0)
