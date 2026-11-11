"""Phase 1: rerun the four frozen Stage 10 false-accept cases against the original gate.

  python3 repro_original.py BASE_WITH_TOOLCHAIN PLAIN_BASE OUTPUT

BASE_WITH_TOOLCHAIN and PLAIN_BASE are checkouts of 624c9faf (the trusted gate and
the PR tree). The four case files in bench/cases are read, never changed.
"""
import json
from pathlib import Path
import subprocess
import sys

FORGE = Path('/Users/mackianni/forge')
sys.path.insert(0, str(FORGE / 'bench'))
import run as bench  # noqa: E402  (frozen runner: only its edit helpers are used)

BASE, PLAIN, OUT = Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]).resolve()
CASES = ['18-ledger-pr-unsupported-ts-fee-bug', '19-ledger-pr-unsupported-app-change',
         '20-ledger-pr-unsupported-new-dafny-module', '21-ledger-pr-unsupported-refund-wrapper']
OUT.mkdir(parents=True, exist_ok=False)
rows = []
for name in CASES:
    case = json.loads((FORGE / 'bench/cases' / (name + '.json')).read_text())
    work = OUT / name
    root, candidate = work / 'root', work / 'candidate'
    work.mkdir()
    bench.clone(BASE, root)
    bench.clone(PLAIN, candidate)
    for change in case['changes']:
        bench.apply_change(change, {'root': root, 'candidate': candidate})
    argv = [sys.executable, 'gate/incremental.py', '--candidate', str(candidate),
            '--evidence', 'build/repro-evidence.json', '--work', 'build/repro-work']
    child = subprocess.run(argv, cwd=root, capture_output=True, text=True)
    operation = json.loads((root / 'build/repro-work/operation.json').read_text())
    row = {'case': case['id'], 'frozen_expected_class': case['expected_class'], 'exit_code': child.returncode,
           'stdout_last_line': (child.stdout.strip().splitlines() or [''])[-1],
           'evidence_written': (root / 'build/repro-evidence.json').is_file(),
           'operation_result': operation.get('result'),
           'candidate_checked': operation['snapshots'][1]['checked_count'] if 'snapshots' in operation else None}
    rows.append(row)
    (work / 'stdout.txt').write_text(child.stdout)
    (work / 'stderr.txt').write_text(child.stderr)
    subprocess.run(['/bin/rm', '-rf', str(root), str(candidate)])
    print(json.dumps(row), flush=True)
(OUT / 'results.json').write_text(json.dumps({'base': '624c9faf', 'rows': rows, 'end_to_end': False}, indent=1) + '\n')
