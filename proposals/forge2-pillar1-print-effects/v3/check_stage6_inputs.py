"""Post-run input identity check for a Stage 6 benchmark run (Round 3). A real check of bytes; no proof claim.

For each of the 75 measured pairs, the two materialized snapshots under build/stage6/run-NNNN/<pair>/v0 and v1 are
compared with the frozen fixtures that the benchmark stored (results/stage6/runs/run-NNNN/fixtures) and whose hashes
it recorded in benchmark.json: v0 is the fixture "unchanged", v1 the fixture of the pair's case. Condition "cold"
materializes one flattened All.dfy (the sources without their include prefixes); the other conditions four files.
Writes results/stage6/input-identities.json in the shape that scripts/exit_stage_6.py reads.
Usage (from the checkout that ran the benchmark): python3 <this file>
"""
from pathlib import Path
import hashlib, json, sys

ROOT = Path.cwd()
sys.path.insert(0, str(ROOT / 'scripts'))
sys.path.insert(0, str(ROOT / 'gate'))
import benchmark_reuse as B                       # for SOURCES and PREFIXES only
from common import canonical

sha = lambda data: hashlib.sha256(data).hexdigest()
bench_path = ROOT / 'results/stage6/benchmark.json'
bench = json.loads(bench_path.read_text())
run = Path(bench['setup_commands'][0]['log']).parent           # results/stage6/runs/run-NNNN
work = ROOT / 'build/stage6' / run.name
fixtures = {}
for name, files in bench['fixture_sha256'].items():
    fixtures[name] = {}
    for path, expected in files.items():
        data = (ROOT / run / 'fixtures' / name / path).read_bytes()
        assert sha(data) == expected, 'stored fixture differs from its recorded hash: ' + name + '/' + path
        fixtures[name][path] = data.decode()
inputs, mismatches = [], []
for row in bench['records']:
    pair = work / ('%d-%s-%s' % (row['repeat'], row['condition'], row['case']))
    for index, fixture in enumerate(('unchanged', row['case'])):
        folder = pair / ('v' + str(index))
        if row['condition'] == 'cold':
            expected = {'All.dfy': '\n'.join(fixtures[fixture][n][len(B.PREFIXES[n]):] for n in B.SOURCES)}
        else:
            expected = dict(fixtures[fixture])
        found = sorted(p.relative_to(folder).as_posix() for p in folder.rglob('*') if p.is_file())
        if found != sorted(expected):
            mismatches.append(str(folder.relative_to(ROOT)) + ': file set ' + str(found))
        for name, text in sorted(expected.items()):
            data = (folder / name).read_bytes() if (folder / name).is_file() else b''
            if data != text.encode():
                mismatches.append((folder / name).relative_to(ROOT).as_posix())
            inputs.append({'path': (folder / name).relative_to(ROOT).as_posix(), 'sha256': sha(data)})
record = {'stage': 6, 'kind': 'postrun_input_identity_check', 'proof_claim': False, 'benchmark_sha256': sha(bench_path.read_bytes()),
          'checked_input_files': len(inputs), 'all_match_frozen_fixture_bytes': not mismatches, 'exit_code': 0 if not mismatches else 1, 'inputs': inputs}
if mismatches:
    record['mismatches'] = mismatches
(ROOT / 'results/stage6/input-identities.json').write_bytes(canonical(record))
print(json.dumps({k: record[k] for k in ('checked_input_files', 'all_match_frozen_fixture_bytes', 'exit_code')}))
raise SystemExit(record['exit_code'])
