"""Benign synthetic canaries. No real secrets, protected paths or candidates."""
import errno
import json
from pathlib import Path
import socket
import subprocess
import sys

own, peer, checker = map(Path, sys.argv[1:])
checks = []


def denied(name, action):
    try:
        action()
    except OSError as error:
        checks.append({'name': name, 'denied': error.errno in (errno.EPERM, errno.EACCES),
                       'errno': error.errno})
    else:
        checks.append({'name': name, 'denied': False, 'errno': None})


(own / 'output.txt').write_text('own output works\n')
denied('peer_read', lambda: (peer / 'canary.txt').read_bytes())
denied('peer_write', lambda: (peer / 'canary.txt').write_bytes(b'canary changed'))
denied('checker_read', lambda: (checker / 'canary.txt').read_bytes())
denied('checker_write', lambda: (checker / 'canary.txt').write_bytes(b'canary changed'))
denied('readonly_write', lambda: (own / 'readonly.txt').write_bytes(b'canary changed'))
denied('traversal_read', lambda: (own / '../peer/canary.txt').read_bytes())
denied('symlink_write', lambda: (own / 'link-to-peer').write_bytes(b'canary changed'))
denied('hardlink', lambda: (own / 'hardlink').hardlink_to(peer / 'canary.txt'))
with socket.socket() as connection:
    denied('loopback_connection', lambda: connection.connect(('127.0.0.1', 9)))
child_code = '''from pathlib import Path
import errno, json, sys
target = sys.argv[1]
try:
    Path(target).read_bytes()
except OSError as error:
    print(json.dumps({'target': target, 'errno': error.errno}))
    sys.exit(73 if error.errno in (errno.EPERM, errno.EACCES) else 74)
sys.exit(0)
'''
child = subprocess.run([sys.executable, '-I', '-B', '-c', child_code,
                        str(checker / 'canary.txt')], capture_output=True)
try:
    child_observation = json.loads(child.stdout)
except (ValueError, UnicodeError):
    child_observation = {}
checks.append({'name': 'child_inherits_denial',
               'denied': child.returncode == 73
                   and child_observation.get('target') == str(checker / 'canary.txt')
                   and child_observation.get('errno') in (errno.EPERM, errno.EACCES),
               'actual_exit': child.returncode})
passed = all(check['denied'] for check in checks)
print(json.dumps({'all_expected_observations': passed, 'own_write': True, 'checks': checks}))
sys.exit(0 if passed else 1)
