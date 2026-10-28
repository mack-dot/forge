#!/usr/bin/env python3
"""Derive test_installed.py from the unchanged test_integrity.py.

The derived suite tests the installed repaired gate under gate/provenance and
compares it with the pre-repair approved bytes. Each replacement must occur an
exact number of times, so the derivation stays auditable.
"""
import hashlib
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'test_integrity.py'
TARGET = HERE / 'test_installed.py'
SOURCE_SHA = '982bdc2f5c18d6162220aa3fc3aa6d6d4aaa3e6f0a504d721e8c088878b92015'

OLD_HEADER = """import release as installed_release  # noqa: E402
import producer as installed_producer  # noqa: E402

LOCK_SHA = '6b43c19370742b02eb05c66b9a9091a6c47431998ef045a09018fa6671459daa'
"""
NEW_HEADER = """import release as candidate_release  # noqa: E402  (installed repaired gate)
import producer as candidate_producer  # noqa: E402  (installed repaired gate)

GATE = ROOT / 'gate/provenance'
PRE = ROOT / 'proposals/provenance-implementation'
PRE_SHA = {'release.py': 'e9f61515ae14300c099f6d2179df0610fe23b5267f3f14361165e2993f039df8',
           'producer.py': 'f3bcc1dc754a4ca423a1746215e12b09c39a7882922b338861c6470c71dd617a'}
LOCK_SHA = '9b10a2376c6b6de46661819a528f3b4e1251f27d76ac21e071b1cfb971224a76'
"""
OLD_LOAD = """candidate_release = load('candidate_release', HERE / 'release.py')
_saved = sys.modules['release']
sys.modules['release'] = candidate_release
candidate_producer = load('candidate_producer', HERE / 'producer.py')
sys.modules['release'] = _saved
IDENT = read(HERE / 'artifact-identities.json')
"""
NEW_LOAD = """for _name, _expected in PRE_SHA.items():
    if digest(PRE / _name) != _expected:
        raise SystemExit('PRE_REPAIR_BASELINE_CHANGED:' + _name)
installed_release = load('pre_repair_release', PRE / 'release.py')
_saved = sys.modules['release']
sys.modules['release'] = installed_release
installed_producer = load('pre_repair_producer', PRE / 'producer.py')
sys.modules['release'] = _saved
IDENT = read(GATE / 'artifact-identities.json')
"""
REPLACEMENTS = [
    ('Adversarial controls for the PROPOSED Stage 9 integrity repair.',
     'Adversarial controls for the INSTALLED Stage 9 integrity repair (post-adoption).', 1),
    ('evidence. Every case runs against both the candidate and the installed code.',
     "evidence. 'repaired' is the installed gate/provenance code; 'pre_repair' is the\n"
     'earlier approved baseline in proposals/provenance-implementation/.', 1),
    (OLD_HEADER, NEW_HEADER, 1),
    (OLD_LOAD, NEW_LOAD, 1),
    ("digest(HERE / 'artifact-identities.json')", "digest(GATE / 'artifact-identities.json')", 2),
    ('digest(HERE / name)', 'digest(GATE / name)', 1),
    ("'candidate'", "'repaired'", None),
    ("'installed'", "'pre_repair'", None),
]


def main():
    text = SOURCE.read_text()
    actual = hashlib.sha256(text.encode()).hexdigest()
    if actual != SOURCE_SHA:
        print('SOURCE_CHANGED', actual)
        return 1
    for old, new, count in REPLACEMENTS:
        found = text.count(old)
        if found == 0 or (count is not None and found != count):
            print('REPLACEMENT_COUNT', repr(old[:60]), found)
            return 1
        text = text.replace(old, new)
    for leftover in ('HERE /', "'candidate'", "'installed'", '6b43c193'):
        if leftover in text:
            print('LEFTOVER', leftover)
            return 1
    TARGET.write_text(text)
    print(TARGET.name, hashlib.sha256(text.encode()).hexdigest())
    return 0


if __name__ == '__main__':
    sys.exit(main())
