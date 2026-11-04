import json
from pathlib import Path
import subprocess
import sys

out = Path(__file__).resolve().parent
records = []
for name, args, required in [
    ('prefix-rest-substitution', ['prefix-rest-substitution',
      str(out / 'negative-prefix-rest/forge_refundEntryScript.sml')], 1),
    ('entry-repeat', ['entry-repeat'], 0),
]:
    argv = [sys.executable, '-B', str(out / 'run_entry.py'), *args]
    with (out / (name + '-dispatch.log')).open('wb') as log:
        result = subprocess.run(argv, stdout=log, stderr=subprocess.STDOUT)
    records.append(dict(name=name, argv=argv, actual_exit=result.returncode,
                        required_exit=required))
    print(name, result.returncode, flush=True)
code = 0 if all(r['actual_exit'] == r['required_exit'] for r in records) else 1
(out / 'entry-control-commands.json').write_text(json.dumps(
    dict(actual_exit=code, commands=records, end_to_end=False), indent=2) + '\n')
sys.exit(code)
