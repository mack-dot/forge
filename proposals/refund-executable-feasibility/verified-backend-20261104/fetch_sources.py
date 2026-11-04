"""Fetch exact upstream source commits for an isolated local experiment."""
import json
from pathlib import Path
import subprocess

OUT = Path(__file__).resolve().parent
ROOT = Path('/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104')
ROOT.mkdir(parents=True, exist_ok=False)
sources = [
    ('polyml', 'https://github.com/polyml/polyml.git', '4557554077078decce4ce5f90da00a713cfc32e4'),
    ('HOL', 'https://github.com/HOL-Theorem-Prover/HOL.git', '9783a49979c94c401ff8c0e51b2eefae7ea95ae3'),
    ('cakeml', 'https://github.com/CakeML/cakeml.git', 'cd9155694c16831373ab695a670794f23282ed62'),
]
records = []
for name, url, commit in sources:
    directory = ROOT / name
    directory.mkdir()
    for argv in [
        ['git', 'init', '--quiet'],
        ['git', 'remote', 'add', 'origin', url],
        ['git', 'fetch', '--depth=1', 'origin', commit],
        ['git', 'checkout', '--quiet', '--detach', commit],
        ['git', 'rev-parse', 'HEAD'],
        ['git', 'rev-parse', 'HEAD^{tree}'],
        ['git', 'fsck', '--full'],
    ]:
        p = subprocess.run(argv, cwd=directory, capture_output=True, text=True)
        records.append(dict(argv=argv, cwd=str(directory), actual_exit=p.returncode,
                            stdout=p.stdout, stderr=p.stderr))
        (OUT / 'source-fetch-commands.json').write_text(json.dumps(records, indent=2) + '\n')
        if p.returncode:
            print(p.stdout + p.stderr, flush=True)
            raise SystemExit(p.returncode)
        if argv == ['git', 'rev-parse', 'HEAD']:
            assert p.stdout.strip() == commit
    print(name + ' pinned checkout and Git object check: exit 0', flush=True)
print('All source fetches complete.', flush=True)
