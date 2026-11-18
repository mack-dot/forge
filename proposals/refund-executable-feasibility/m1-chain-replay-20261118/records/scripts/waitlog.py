"""Wait until the driver log has more than N lines, or the driver stopped. Prints the new lines.
Usage: python3 -I -B waitlog.py <log name> <known line count> [max seconds] [new lines needed]"""
from pathlib import Path
import subprocess, sys, time

OUT = Path(__file__).resolve().parent.parent
log = OUT / 'logs' / sys.argv[1]
known = int(sys.argv[2])
limit = float(sys.argv[3]) if len(sys.argv) > 3 else 165
need = int(sys.argv[4]) if len(sys.argv) > 4 else 1
start = time.time()
while True:
    lines = log.read_text(errors='replace').splitlines() if log.exists() else []
    alive = 'driver.py' in subprocess.run(['ps', '-axo', 'command'], capture_output=True, text=True).stdout
    if len(lines) >= known + need or not alive or time.time() - start > limit:
        break
    time.sleep(4)
for line in lines[known:]:
    print(line[:400])
print('LINES', len(lines), 'DRIVER_ALIVE', alive, time.strftime('%H:%M:%SZ', time.gmtime()))
