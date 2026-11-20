#!/usr/bin/env python3
"""vault_pipe.py: connect this process's stdin and stdout to the vault's UNIX socket. Python stdlib only.

Runs as the NORMAL user (the agent's side). It holds only the connection; it reads no store file and no key.
Bytes from stdin go to the socket unchanged; bytes from the socket go to stdout unchanged. At stdin EOF it shuts
down the socket's write side (the engine then sees EOF, answers what it has, and ends) and copies the rest of
the answers, then exits. It adds, removes and interprets nothing: the engine's line protocol is unchanged.

  vault_pipe.py [--socket /usr/local/forge_vault/run/vault.sock]

SDK use (sdk/py/forge_airlock.py, no change to the SDK; Store(..., serve_argv=[...]) starts this instead of
`forge-airlock serve`):

    import sys; sys.path.insert(0, 'sdk/py'); import forge_airlock as fa
    pipe = ['/usr/bin/python3', '-I', 'demos/hal_9000/vault/vault_pipe.py', '--socket', SOCK]
    with fa.Store('vault:discovery-one', serve_argv=pipe) as st:
        print(st.get('crew', 'atmo-bay3').line)            # GET through the vault's engine
        print(st.refund('crew', 'atmo-bay3', 'hal-1', h, 'VENT_ATMOSPHERE', 1013).code)

The store_dir argument is then only a label. Store.cosign_message, replay, leases and sweep start LOCAL one-shot
engine commands on store_dir: through the vault they fail (the agent cannot open the store), by design.

Exit: 0 the engine closed the connection; 3 cannot connect; 4 the connection broke.
"""

import argparse
import errno
import os
import select
import socket
import sys

DEFAULT_SOCKET = '/usr/local/forge_vault/run/vault.sock'


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--socket', default=os.environ.get('FORGE_VAULT_SOCKET', DEFAULT_SOCKET))
    a = ap.parse_args()
    s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    try:
        d = os.path.dirname(a.socket)
        if d:
            os.chdir(d)  # connect by base name: macOS limits sun_path to 104 bytes
        s.connect(os.path.basename(a.socket))
    except OSError as e:
        sys.stderr.write('vault_pipe: cannot connect to %s: %s (%s, errno %s)\n'
                         % (a.socket, e.strerror, errno.errorcode.get(e.errno, '?'), e.errno))
        return 3
    inp, out = sys.stdin.fileno(), sys.stdout.fileno()
    sfd = s.fileno()
    stdin_open = True
    try:
        while True:
            r, _, _ = select.select([sfd] + ([inp] if stdin_open else []), [], [])
            if inp in r:
                data = os.read(inp, 1 << 16)
                if data:
                    s.sendall(data)
                else:
                    stdin_open = False
                    s.shutdown(socket.SHUT_WR)
            if sfd in r:
                data = s.recv(1 << 16)
                if not data:
                    return 0
                view = memoryview(data)
                while view:
                    n = os.write(out, view)
                    view = view[n:]
    except (BrokenPipeError, ConnectionResetError) as e:
        sys.stderr.write('vault_pipe: connection broke: %s\n' % e)
        return 4
    finally:
        s.close()


if __name__ == '__main__':
    sys.exit(main())
