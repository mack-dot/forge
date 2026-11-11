from pathlib import Path
import json, subprocess, sys

OUT = Path(__file__).resolve().parent
results = {}
for name in ['wrong-code', 'missing-space', 'short-trace']:
    argv = [sys.executable, '-B', str(OUT / 'import.py'), name, name + '.sml', 'import']
    with (OUT / (name + '-dispatch.log')).open('wb') as log:
        result = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
    results[name] = {'argv': argv, 'actual_wrapper_exit': result.returncode}
    (OUT / 'control-dispatch.json').write_text(json.dumps(results, indent=2) + '\n')
    print(name, 'actual exit', result.returncode, flush=True)
    if result.returncode != 1:
        raise SystemExit('Unexpected control result; inspect before continuing')
