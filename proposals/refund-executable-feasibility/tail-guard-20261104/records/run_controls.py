import json
from pathlib import Path
import subprocess
import sys

out = Path(__file__).resolve().parent
records = []


def run(name, script, args, required):
    argv = [sys.executable, '-B', str(out / script), *map(str, args)]
    with (out / (name + '-dispatch.log')).open('wb') as log:
        result = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
    records.append(dict(name=name, argv=argv, actual_exit=result.returncode,
                        required_exit=required))
    (out / 'control-progress.json').write_text(json.dumps(records, indent=2) + '\n')
    print(name, result.returncode, flush=True)
    return result.returncode


try:
    code = run('parent-mutant', 'run_parent.py',
               ['parent-mutant', out / 'parent-mutant/forge_refundProgScript.sml'], 0)
    if code == 0:
        run('guard-removed', 'run.py', ['guard-removed'], 1)
finally:
    restored = run('parent-restored', 'run_parent.py',
                   ['parent-restored', out / 'parent-positive/forge_refundProgScript.sml'], 0)
    if restored == 0:
        run('guard-repeat', 'run.py', ['repeat'], 0)

code = 0 if len(records) == 4 and all(
    r['actual_exit'] == r['required_exit'] for r in records) else 1
(out / 'control-commands.json').write_text(json.dumps(
    dict(actual_exit=code, commands=records, end_to_end=False,
         scope='Conditional guard theorem; whole-program behavior remains open'),
    indent=2) + '\n')
sys.exit(code)
