"""Read-only check: every tracked file of the three pinned source checkouts
hashes to its Git index entry, and HEAD's commit and tree equal the saved
upstream API responses. No Git state is written.

Usage: python3 -I -B verify_sources.py <directory with HOL.json cakeml.json polyml.json>
"""
from pathlib import Path
import json, subprocess, sys

TC = Path('/Users/mackianni/forge/.toolchain/experiments/refund-cakeml-20261104')
PINS = {'HOL': '9783a49979c94c401ff8c0e51b2eefae7ea95ae3',
        'cakeml': 'cd9155694c16831373ab695a670794f23282ed62',
        'polyml': '4557554077078decce4ce5f90da00a713cfc32e4'}
api = Path(sys.argv[1])
report, failed = {}, False


def git(repo, *args, data=None):
    return subprocess.run(['git', '-C', str(repo), *args], input=data, capture_output=True, check=True).stdout


for name, pin in PINS.items():
    repo = TC / name
    head = git(repo, 'rev-parse', 'HEAD').decode().strip()
    tree = git(repo, 'rev-parse', 'HEAD^{tree}').decode().strip()
    index_tree_entries = {}
    for line in git(repo, 'ls-files', '-s', '-z').split(b'\0'):
        if line:
            meta, path = line.split(b'\t', 1)
            mode, blob, stage = meta.split()
            index_tree_entries[path] = (mode, blob.decode())
    head_entries = {}
    for line in git(repo, 'ls-tree', '-r', '-z', 'HEAD').split(b'\0'):
        if line:
            meta, path = line.split(b'\t', 1)
            mode, kind, blob = meta.split()
            head_entries[path] = (mode, blob.decode())
    regular = [p for p, (mode, _) in index_tree_entries.items() if mode in (b'100644', b'100755')]
    hashed = git(repo, 'hash-object', '--stdin-paths', data=b'\n'.join(regular) + b'\n').decode().split()
    mismatched = [p.decode(errors='replace') for p, h in zip(regular, hashed) if index_tree_entries[p][1] != h]
    links = [p for p, (mode, _) in index_tree_entries.items() if mode == b'120000']
    upstream = json.loads((api / (name + '.json')).read_text())
    entry = {
        'pin': pin, 'head': head, 'tree': tree,
        'upstream_commit': upstream.get('sha'), 'upstream_tree': upstream.get('commit', {}).get('tree', {}).get('sha'),
        'tracked_entries': len(index_tree_entries), 'regular_files_hashed': len(regular),
        'symlinks_or_submodules_not_hashed': len(index_tree_entries) - len(regular),
        'index_equals_head': index_tree_entries == head_entries,
        'worktree_files_differing_from_index': mismatched[:20], 'differing_count': len(mismatched),
    }
    entry['ok'] = (head == pin == entry['upstream_commit'] and tree == entry['upstream_tree']
                   and entry['index_equals_head'] and not mismatched and len(hashed) == len(regular))
    failed = failed or not entry['ok']
    report[name] = entry
print(json.dumps(report, indent=1))
raise SystemExit(1 if failed else 0)
