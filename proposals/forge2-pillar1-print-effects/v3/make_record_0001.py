"""Make ratification record 0001 (print effects) from two commits. Dispatch only; no verdict.

The digests come from the trusted commit's own gate/incremental.py:protected_manifest, applied to an export of
the trusted commit and to an export of the candidate commit. The record names every protected file that
differs. Controls: the two planted print bugs of the candidate commit. The record authorizes nothing on a
branch; it has effect only on main by the owner's merge.
Usage: python3 -I -B make_record_0001.py <trusted-commit> <candidate-commit> <output.json>
"""
from pathlib import Path
import hashlib, io, json, subprocess, sys, tarfile, tempfile

HERE = Path(__file__).resolve().parent
FORGE = HERE.parents[2]
PROPOSAL = 'proposals/forge2-pillar1-print-effects/v3/PROPOSAL-V3.md'
CONTROLS = ('bugs/print_effect.dfy', 'bugs/print_effect_marked.dfy')
READ = ("import json, sys\nsys.path.insert(0, 'gate')\nfrom pathlib import Path\nimport incremental\n"
        "print(json.dumps(incremental.protected_manifest(Path(sys.argv[1]).resolve()), sort_keys=True))\n")
sha = lambda data: hashlib.sha256(data).hexdigest()
trusted, candidate, output = sys.argv[1], sys.argv[2], Path(sys.argv[3])


def export(commit, folder):
    data = subprocess.run(['git', '-C', str(FORGE), 'archive', '--format=tar', commit], capture_output=True, check=True).stdout
    with tarfile.open(fileobj=io.BytesIO(data)) as archive:
        archive.extractall(folder)


with tempfile.TemporaryDirectory() as work:
    old, new = Path(work) / 'trusted', Path(work) / 'candidate'
    export(trusted, old)
    export(candidate, new)
    manifest = lambda tree: json.loads(subprocess.run([sys.executable, '-I', '-B', '-c', READ, str(tree)], cwd=old,
                                                      capture_output=True, text=True, check=True).stdout)
    a, b = manifest(old), manifest(new)
    files = {name: {'old_sha256': a.get(name), 'new_sha256': b.get(name)}
             for name in sorted(a.keys() | b.keys()) if a.get(name) != b.get(name)}
    record = {
        'id': '0001-print-effects', 'tier': 0, 'decision': 'ratified_as_written', 'end_to_end': False,
        'files': files,
        'controls': [{'path': path, 'sha256': sha((new / path).read_bytes()), 'expect': 'rejected'} for path in CONTROLS],
        'proposal': PROPOSAL, 'proposal_sha256': sha((HERE / 'PROPOSAL-V3.md').read_bytes()),
        'effective': "Only when this file and the proposal text are on main by the owner's merge. On a branch it authorizes nothing.",
        'trusted_origin': 'Maintainer-controlled base checkout; candidate-owned metadata is not authorization',
    }
output.write_text(json.dumps(record, indent=1, sort_keys=True) + '\n')
print(json.dumps({'files': sorted(files), 'controls': list(CONTROLS), 'proposal_sha256': record['proposal_sha256']}))
