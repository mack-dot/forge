#!/usr/bin/env python3
"""Write bench/manifest.json, which freezes every case, expected outcome and script.

  python3 bench/freeze.py

The owner approves the printed SHA-256. bench/run.py refuses any other manifest
and any changed or unlisted bench file. The manifest has no timestamps.
"""

import hashlib
import json
from pathlib import Path
import platform
import sys

BENCH = Path(__file__).resolve().parent
REPO = BENCH.parent
BASE_COMMIT = '624c9fafccd3badaa6a9dd582ae33f1204fb1e3a'
PINS_SHA256 = '74dcc4b81e452c7422698e6032a3fd7f44186aa2ef1e8a85320e2c8eb03ce60c'
CLASSES = ('accept', 'defect', 'missing_evidence', 'policy_reject', 'unsupported', 'tool_failure')
KINDS = ('seed', 'valid_alternative', 'defect', 'policy', 'unsupported', 'tool_failure', 'adversarial_evidence')


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    classes = json.loads((BENCH / 'classes.json').read_text())
    case_files = sorted((BENCH / 'cases').glob('*.json'))
    cases = [json.loads(p.read_text()) for p in case_files]
    ids = [c['id'] for c in cases]
    seeds = {c['id'] for c in cases if c['kind'] == 'seed'}
    for number, (path, case) in enumerate(zip(case_files, cases), 1):
        assert path.name == '%02d-%s.json' % (number, case['id']) and case['order'] == number, path
        assert case['expected_class'] in CLASSES and case['kind'] in KINDS, case['id']
        if case['expected_class'] == 'accept':
            assert case['expected_exit'] == 0 and case['expected_reason_prefix'] is None, case['id']
        elif case['expected_class'] == 'tool_failure':
            assert case['expected_exit'] == 2 and case['expected_reason_prefix'] is None, case['id']
        elif case['expected_class'] == 'unsupported':
            assert case['expected_exit'] is None and case['gate'] == 'incremental', case['id']
        else:
            assert case['expected_exit'] == 1, case['id']
            assert classes['reason_classes'][case['expected_reason_prefix']] == case['expected_class'], case['id']
        if case['supplied_evidence']:
            source = case['supplied_evidence']['from']
            assert source in seeds and ids.index(source) < ids.index(case['id']), case['id']
    assert len(ids) == len(set(ids))
    assert sys.version_info[:3] == (3, 10, 11)
    files = {p.relative_to(REPO).as_posix(): sha256(p)
             for p in sorted(BENCH.rglob('*')) if p.is_file() and p.name != 'manifest.json'
             and '__pycache__' not in p.parts}
    files['scripts/exit_stage_10.py'] = sha256(REPO / 'scripts/exit_stage_10.py')
    counts = {name: sum(c['expected_class'] == name for c in cases) for name in CLASSES}
    manifest = {
        'benchmark': 'forge-stage10-gate-benchmark', 'version': 1,
        'statement': ('Internally authored controlled evaluation of unchanged Forge gates. Not independent '
                      'generalization and not a real-PR shadow study. No case was run through Dafny or any '
                      'Forge gate before this manifest was written.'),
        'base_repository': 'https://github.com/mack-dot/forge.git', 'base_commit': BASE_COMMIT,
        'toolchain_source': str(REPO / '.toolchain'), 'toolchain_pins_sha256': PINS_SHA256,
        'python': {'version': platform.python_version(), 'executable': sys.executable},
        'passes': 2, 'timeout_seconds': 1800,
        'primary_pass': 1,
        'classes_file': 'bench/classes.json',
        'case_files': [p.relative_to(REPO).as_posix() for p in case_files],
        'case_order': ids, 'case_count': len(ids), 'expected_class_counts': counts,
        'files': files, 'end_to_end': False,
    }
    target = BENCH / 'manifest.json'
    target.write_text(json.dumps(manifest, indent=1, sort_keys=True) + '\n')
    print('MANIFEST', target.relative_to(REPO), sha256(target))
    print('cases', len(ids), json.dumps(counts, sort_keys=True))
    return 0


if __name__ == '__main__':
    sys.exit(main())
