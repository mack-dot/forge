"""Wave Gate 1: copies of scripts/exit_m1_conformance.py with ONE check removed each must fail.

For each check, this runner writes a copy of the EXIT script in which that one check does nothing,
runs the copy with `--case record-controls`, and records the real exit code. The case holds one
planted fault for every check. With the check removed, the planted fault is not found, so the copy
must exit non-zero. The unchanged script must exit 0 before and after.

A copy is the script with one text replacement (the call of `check` or `require` becomes a call that
does nothing). It is written as scripts/_removed_check.py INSIDE THE GIVEN TREE and is deleted after
each run. Use a scratch clone, not the owner's working tree.

Usage: python3 proposals/forge2-m1-conformance/run_removed_checks.py <tree> <record.json>
Environment: the pinned Node must be first in PATH. The tree needs the links .toolchain and node_modules.
"""
import json, subprocess, sys
from pathlib import Path

tree, record_path = Path(sys.argv[1]).resolve(), Path(sys.argv[2]).resolve()
SCRIPT = tree / 'scripts/exit_m1_conformance.py'
COPY = tree / 'scripts/_removed_check.py'
NOTHING = '(lambda *arguments: None)('
CHECKS = ['M-EXIT', 'M-CLASS', 'REF', 'A-CALLS', 'A-PLAN', 'A-BYTES', 'F-VERDICT', 'F-TOKEN', 'F-POST', 'F-BIND', 'F-TAMPER',
          'I-VERDICT', 'I-TOKEN', 'W-RULE', 'R-STDIN', 'R-RENDER', 'R-STDOUT', 'R-MALFORMED']
# (name, exact text of the script, replacement). Each text must occur the stated number of times.
REQUIRES = [
    ('EXECUTABLE (identity of the M1 executable before a run)',
     "require(digest(data) == EXECUTABLE_SHA256, 'EXECUTABLE: the file is not", 1),
    ('CORE_MODULE (identity of the compiled core)',
     "require(digest(Path(module).read_bytes()) == recorded,", 1),
    ('VACUITY (both sides of the comparison are not empty)',
     "require(authorized > 0 and rejected > 0", 1),
    ('VACUITY (every check was evaluated)',
     "require(not never,", 1),
    ('RECORDED (identity of the fixture file)',
     "require(digest(Path(path).read_bytes()) == RECORDED_SHA256,", 1),
]
source = SCRIPT.read_text()
rows = []


def run(label, text):
    COPY.write_text(text)
    try:
        child = subprocess.run(['python3', 'scripts/_removed_check.py', '--case', 'record-controls'], cwd=tree,
                               capture_output=True, text=True)
    finally:
        COPY.unlink()
    lines = (child.stdout + child.stderr).replace(str(tree), '<tree>').strip().splitlines()
    rows.append({'removed': label, 'exit_code': child.returncode, 'last_line': (lines[-1] if lines else '')[:300]})
    print('%s: exit %d' % (label, child.returncode), flush=True)
    return child.returncode


before = run('nothing (the unchanged script)', source)
for name in CHECKS:
    target = "check(findings, '%s'," % name
    count = source.count(target)
    if count < 1:
        raise SystemExit('check not found in the script: ' + name)
    run('check %s (%d call%s)' % (name, count, '' if count == 1 else 's'), source.replace(target, NOTHING + "findings, '%s'," % name))
for name, target, expected in REQUIRES:
    if source.count(target) != expected:
        raise SystemExit('text not found exactly %d time(s): %s' % (expected, target))
    run('require ' + name, source.replace(target, NOTHING + target[len('require('):]))
after = run('nothing (the unchanged script, again)', source)
copies = rows[1:-1]
record = {
    'what': 'Wave Gate 1: copies of scripts/exit_m1_conformance.py with one check removed, each run with --case record-controls',
    'unchanged_script_exit_codes': [before, after],
    'copies': len(copies), 'copies_with_exit_not_0': sum(row['exit_code'] != 0 for row in copies),
    'copies_with_exit_1': sum(row['exit_code'] == 1 for row in copies),
    'rows': rows, 'end_to_end': False,
    'note': 'A copy that exits 1 failed a control (the planted fault was not found). Exit 2 would be a crash, not a control result.',
}
record_path.write_text(json.dumps(record, indent=1, sort_keys=True) + '\n')
print(json.dumps({key: record[key] for key in ('unchanged_script_exit_codes', 'copies', 'copies_with_exit_not_0', 'copies_with_exit_1')}))
raise SystemExit(0 if before == 0 and after == 0 and record['copies_with_exit_1'] == len(copies) else 1)
