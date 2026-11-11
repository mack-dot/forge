"""Rerun the frozen Stage 10 benchmark (51 cases, same manifest) against a candidate gate.

  python3 -I rerun_bench.py PATCHED_PLAIN TOOLCHAIN OUTPUT WORK

PATCHED_PLAIN is the base commit's tree with the candidate's changed files applied
(no .git/.toolchain/build). bench/ is read, never changed. The frozen classes.json
predates exit 3, so this script records raw exit codes and gate outcomes and reports
exit 3 as `unsupported` explicitly; the frozen expectations are not altered.
"""
import json
from pathlib import Path
import sys

FORGE = Path('/Users/mackianni/forge')
sys.path.insert(0, str(FORGE / 'bench'))
import run as bench  # noqa: E402

PLAIN, TOOLCHAIN, OUT, WORK = (Path(a).expanduser().resolve() for a in sys.argv[1:5])
manifest = json.loads((FORGE / 'bench/manifest.json').read_text())
classes = json.loads((FORGE / 'bench/classes.json').read_text())
cases = [json.loads((FORGE / name).read_text()) for name in manifest['case_files']]
OUT.mkdir(parents=True, exist_ok=False)
WORK.mkdir(parents=True, exist_ok=False)
base = WORK / 'base'
bench.clone(PLAIN, base)
bench.clone(TOOLCHAIN, base / '.toolchain')
log = {'manifest_sha256': bench.sha256((FORGE / 'bench/manifest.json').read_bytes()), 'candidate_gate': str(PLAIN),
       'note': 'frozen classes.json maps exit 3 to tool_failure (it predates UNSUPPORTED); observed_class_v2 maps exit 3 to unsupported',
       'end_to_end': False}
bench.dump(OUT / 'run.json', log)
with (OUT / 'records.jsonl').open('w') as stream:
    for number in (1, 2):
        for case in cases:
            record = bench.run_case(case, classes, PLAIN, base, WORK / ('pass-%d' % number), OUT / ('pass-%d' % number),
                                    sys.executable, manifest['timeout_seconds'], False)
            record['pass'] = number
            if record.get('status') == 'ran':
                record['observed_class_v2'] = 'unsupported' if record['exit_code'] == 3 else record['observed_class']
                op = OUT / ('pass-%d' % number) / case['id'] / 'build/bench-work/operation.json'
                if op.is_file():
                    record['gate_outcome'] = json.loads(op.read_text()).get('outcome')
            stream.write(json.dumps(record, sort_keys=True) + '\n')
            stream.flush()
            print(number, record['order'], record['id'], record.get('exit_code'), record.get('reason_prefix'),
                  record.get('observed_class_v2'), record.get('gate_outcome'), record.get('wall_seconds'), flush=True)
