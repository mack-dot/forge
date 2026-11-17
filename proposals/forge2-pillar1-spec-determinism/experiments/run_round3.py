"""Round 3 Pillar I runner (U430): shared audit skeleton, its control, and the W2 cost experiment. Dispatch only.

The pinned Dafny decides. This script records exits and the resource numbers that Dafny writes to its CSV log.
Usage: python3 -I -B run_round3.py   (writes records/round3/attempt-NNNN.json)
"""
from pathlib import Path
import collections, csv, hashlib, json, subprocess, tempfile

ROOT = Path(__file__).resolve().parents[3]
P = 'proposals/forge2-pillar1-spec-determinism/'
OPTIONS = ['--solver-path', '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1', '--resource-limit', '1000000',
           '--verification-time-limit', '0', '--cores', '1', '--verify-included-files']   # gate/backends/dafny.py OPTIONS
CASES = [('skeleton and three instances', 'RelationalAuditInstances.dfy', 0, 'verified, 0 errors', None),
         ('control: planted no-frame specification as an instance', 'fixtures/AuditInstanceNoFrame.dfy', 4, 'AuditInstanceNoFrame.dfy(14,2): Error: a postcondition could not be proved', None),
         ('W2 split into four lemmas', 'experiments/W2Split.dfy', 0, 'verified, 0 errors', 'W2Split'),
         ('W2 with map-key assertions only (failed attempt, kept)', 'experiments/W2MapKeysOnly.dfy', 4, 'out of resource', 'W2MapKeysOnly')]
out = ROOT / P / 'records/round3'
out.mkdir(parents=True, exist_ok=True)
number = 1
while (out / f'attempt-{number:04d}.json').exists():
    number += 1
rows, failed = [], False
for name, file, want, needle, module in CASES:
    with tempfile.TemporaryDirectory() as tmp:
        log = Path(tmp) / 'log.csv'
        extra = ['--filter-symbol', module, '--log-format', f'csv;LogFileName={log}'] if module else []
        run = subprocess.run([str(ROOT / '.toolchain/dafny-4.11.0/dafny/dafny'), 'verify', P + file, *OPTIONS, *extra], cwd=ROOT, capture_output=True, text=True)
        text = run.stdout + run.stderr
        resources = {}
        if module and log.is_file():
            by = collections.defaultdict(list)
            for r in csv.DictReader(log.open()):
                by[r['TestResult.DisplayName'].split(' (')[0]].append((int(r['TestResult.ResourceCount']), r['TestResult.Outcome']))
            resources = {k: {'batches': len(v), 'largest': max(x[0] for x in v), 'sum': sum(x[0] for x in v),
                             'outcomes': dict(collections.Counter(x[1] for x in v))} for k, v in sorted(by.items())}
    ok = run.returncode == want and needle in text
    failed = failed or not ok
    last = [l for l in run.stdout.strip().splitlines() if 'finished' in l]
    rows.append({'case': name, 'file': P + file, 'sha256': hashlib.sha256((ROOT / P / file).read_bytes()).hexdigest(), 'checker_exit': run.returncode,
                 'expected_checker_exit': want, 'result': 'AS EXPECTED' if ok else 'UNEXPECTED', 'summary': (last or [''])[-1], 'resources': resources})
    print(name, '| checker exit', run.returncode, '|', rows[-1]['result'], '|', rows[-1]['summary'], flush=True)
    for k, v in resources.items():
        print('   ', k, v, flush=True)
(out / f'attempt-{number:04d}.json').write_text(json.dumps({'rows': rows, 'scenario_exit': 1 if failed else 0, 'end_to_end': False}, indent=1) + '\n')
raise SystemExit(1 if failed else 0)
