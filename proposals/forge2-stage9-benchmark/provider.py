"""LOCAL FAKE payment provider of the Stage 9 benchmark. It pays whatever it is asked to pay. It checks nothing.

Usage: python3 provider.py STATE_DIR ORDER REQUEST_ID REASON AMOUNT
It waits 50 ms (a stand-in for a network call), then appends one line to STATE_DIR/provider.log and prints PAID.
The hidden oracle of the benchmark reads only this log.
"""
import os, sys, time

state, order, request_id, reason, amount = sys.argv[1:6]
int(amount)
time.sleep(0.05)
line = ('%s %s %s %s\n' % (order, request_id, reason, amount)).encode()
fd = os.open(os.path.join(state, 'provider.log'), os.O_WRONLY | os.O_APPEND | os.O_CREAT, 0o600)
os.write(fd, line)
os.close(fd)
print('PAID')
