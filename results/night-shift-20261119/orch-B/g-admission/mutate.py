#!/usr/bin/env python3
"""Make mutant copies of the draft admission.py and run the suite on each (task g-admission).
A mutant is KILLED when a test that PASSES on the original FAILS on the mutant. No network, no credential."""

import json
from pathlib import Path
import subprocess
import sys

HERE = Path(__file__).resolve().parent
ORIGINAL = Path('<REPO>/proposals/m1b-mission-20261119/drafts/enforcement/unapplied-proposal/gate/admission.py')
SUITE = HERE / 'test_admission_suite.py'
ENV = {'PATH': '/usr/bin:/bin', 'HOME': str(HERE), 'PYTHONDONTWRITEBYTECODE': '1'}

CONTROLS = {   # whole-function replacements: both must FAIL the suite
    'C1-reject-all': ('def admission(code, coverage):\n',
                      'def admission(code, coverage):\n    return False, "reject all"\n'),
    'C2-accept-all': ('def admission(code, coverage):\n',
                      'def admission(code, coverage):\n    return True, "accept all"\n'),
}
MUTANTS = {
    'M01-exit1-like-exit3': ("if code != 3 or not isinstance(coverage, dict):",
                             "if code not in (1, 3) or not isinstance(coverage, dict):"),
    'M02-drop-affected-check': (" or coverage.get('affected_obligations') != ['ledger-proof']):", "):"),
    'M03-match-not-fullmatch': ("not DOCUMENT_PATH.fullmatch(path)", "not DOCUMENT_PATH.match(path)"),
    'M04-drop-reason-check': ("item.get('reason') != 'UNCOVERED_CHANGE' or ", ""),
    'M05-drop-dotdot': ("'..' in path.split('/') or ", ""),
    'M06-case-sensitive-prefix': ("path.lower().startswith(NEVER_DOCUMENT)", "path.startswith(NEVER_DOCUMENT)"),
    'M07-allow-empty-rows': ("not isinstance(rows, list) or not rows or", "not isinstance(rows, list) or"),
    'M08-drop-finding-path-check': (" or item.get('path') not in paths", ""),
    'M09-drop-stale-head': ("if current['head']['sha'] != receipt['head_sha'] or", "if"),
    'M10-always-success': ("'state': 'success' if admitted else 'failure'", "'state': 'success'"),
    'M11-bind-drop-head': ("'base_sha': expected['base']['sha'], 'head_sha': expected['head']['sha']}",
                           "'base_sha': expected['base']['sha']}"),
    'M12-drop-gate-prefix': ("('.github/', 'gate/', ", "('.github/', "),
    'M13-drop-double-slash': (" or '//' in path", ""),
    'M14-drop-int-type-check': ("if type(code) is not int or receipt", "if receipt"),
    'M15-drop-scope-check': ("if repository != 'mack-dot/forge' or expected['base']['ref'] != 'main':", "if False:"),
    'M16-drop-findings-nonempty': ("not isinstance(findings, list) or not findings", "not isinstance(findings, list)"),
}


def run(path, tag):
    out = HERE / 'mutants' / (tag + '.json')
    log = HERE / 'mutants' / (tag + '.log')
    child = subprocess.run(['/usr/bin/env', 'python3', '-B', str(SUITE), str(path), '--json', str(out)],
                           capture_output=True, text=True, env=ENV, timeout=120)
    log.write_text(child.stdout + child.stderr + 'exit %d\n' % child.returncode)
    return child.returncode, {r['id']: r['pass'] for r in json.loads(out.read_text())}


def main():
    (HERE / 'mutants').mkdir(exist_ok=True)
    source = ORIGINAL.read_text()
    code, base = run(ORIGINAL, 'original')
    passing = {k for k, v in base.items() if v}
    print('original exit %d, %d pass, %d fail' % (code, len(passing), len(base) - len(passing)))
    summary = {}
    for group, table in (('control', CONTROLS), ('mutant', MUTANTS)):
        for tag, (old, new) in table.items():
            if source.count(old) != 1:
                print('NOT APPLIED', tag, 'pattern count', source.count(old))
                summary[tag] = 'NOT APPLIED'
                continue
            path = HERE / 'mutants' / (tag + '.py')
            path.write_text(source.replace(old, new))
            exit_code, res = run(path, tag)
            killers = sorted(k for k in passing if not res.get(k, False))
            state = 'KILLED' if killers else 'SURVIVED'
            summary[tag] = {'state': state, 'exit': exit_code, 'killed_by': killers}
            print(group, tag, state, 'exit', exit_code, 'by', ','.join(killers[:8]) + (' ...' if len(killers) > 8 else ''))
    (HERE / 'mutation-summary.json').write_text(json.dumps(summary, indent=1))
    return 0


if __name__ == '__main__':
    sys.exit(main())
