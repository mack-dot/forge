set -euo pipefail
.toolchain/ci-python/bin/python - <<'PYOBS'
import json
import pathlib
import shutil
receipt = json.loads(pathlib.Path('build/pr/receipt.json').read_text())
if receipt['exit_code'] == 0:
    paths = list(pathlib.Path('build').glob('change-run-*/operation.json'))
    if len(paths) != 1:
        raise RuntimeError('Expected one replay operation in this fresh runner')
    operation = json.loads(paths[0].read_text())
    if operation['exit_code'] != 0 or not operation['coverage']['covered']:
        raise RuntimeError('Replay observations do not establish coverage')
    destination = pathlib.Path('build/pr/observations')
    destination.mkdir(exist_ok=False)
    shutil.copyfile(paths[0], destination / 'replay-operation.json')
PYOBS
