"""Write .toolchain/stage9/controller.json for the Stage 9 EXIT harness.

  python3 -I write_controller_config.py --root CHECKOUT --request REQUEST.json
      --controller CONTROLLER.sqlite --candidate SIGNED_OUTPUT_DIR --implementation-sha256 HEX

Standard library only. Refuses unless the request file is byte-identical to the
pending controller row for its challenge (EXIT report D6), its lock equals the
given lock, and the candidate directory holds a release bundle. Never signs,
dispatches or contacts the network.
"""
import argparse
import json
from pathlib import Path
import sqlite3
import sys


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'), ensure_ascii=True, allow_nan=False) + '\n').encode()


def main():
    parser = argparse.ArgumentParser()
    for name in ['--root', '--request', '--controller', '--candidate', '--implementation-sha256']:
        parser.add_argument(name, required=True)
    args = parser.parse_args()
    root, candidate = Path(args.root).resolve(), Path(args.candidate).resolve()
    request_path, controller = Path(args.request).resolve(), Path(args.controller).resolve()
    data = request_path.read_bytes()
    request = json.loads(data)
    if data != canonical(request):
        sys.exit('CONFIG_REJECTED: REQUEST_NOT_CANONICAL')
    connection = sqlite3.connect(f'file:{controller}?mode=ro', uri=True)
    row = connection.execute('SELECT request, state FROM requests WHERE challenge=?', (request['challenge'],)).fetchone()
    connection.close()
    if row is None or row[0] != data or row[1] != 'pending':
        sys.exit('CONFIG_REJECTED: REQUEST_NOT_THE_PENDING_CONTROLLER_ROW')
    if request['implementation_lock_sha256'] != args.implementation_sha256:
        sys.exit('CONFIG_REJECTED: REQUEST_LOCK')
    if controller.is_relative_to(candidate) or not (candidate / 'release.sigstore.json').is_file():
        sys.exit('CONFIG_REJECTED: CANDIDATE')
    target = root / '.toolchain/stage9/controller.json'
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(canonical({'implementation_sha256': args.implementation_sha256, 'candidate': str(candidate),
                                  'controller': str(controller), 'request': str(request_path),
                                  'challenge': request['challenge']}))
    print('CONFIG_WRITTEN', target)
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
