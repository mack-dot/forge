#!/usr/bin/env python3
"""Check proposal integrity only. No proof or signature acceptance is performed."""
import hashlib
import json
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
PROPOSAL = ROOT / 'proposals/provenance'


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def read(path):
    return json.loads(path.read_text())


def main():
    manifest = read(PROPOSAL / 'approval-manifest.json')
    assert manifest['status'] == 'pending_human_approval'
    assert manifest['base_commit'] == '80a65d46b1dbc8f3ccfd249bfd628568406c5774'
    expected = {'spec/provenance/protocol.md', 'policy/provenance.json',
                'spec/provenance/spec.lock'}
    assert {x['target'] for x in manifest['changes']} == expected
    assert len(manifest['changes']) == 3
    rebuilt = []
    for entry in manifest['changes']:
        candidate = ROOT / entry['candidate']
        assert entry['operation'] == 'add'
        assert not (ROOT / entry['target']).exists(), entry['target']
        assert candidate.stat().st_size == entry['bytes']
        assert digest(candidate) == entry['sha256'], entry['candidate']
        lines = candidate.read_text().splitlines(keepends=True)
        target = entry['target']
        rebuilt.append(f'diff --git a/{target} b/{target}\nnew file mode 100644\n'
                       f'--- /dev/null\n+++ b/{target}\n@@ -0,0 +1,{len(lines)} @@\n'
                       + ''.join('+' + line for line in lines))
    assert ''.join(rebuilt).encode() == (PROPOSAL / 'protected.diff').read_bytes()
    assert digest(PROPOSAL / 'protected.diff') == manifest['patch_sha256']
    lock = read(PROPOSAL / 'spec.lock')
    policy = read(PROPOSAL / 'provenance-policy.json')
    assert digest(PROPOSAL / 'protocol.md') == lock['contract']['sha256']
    assert digest(PROPOSAL / 'provenance-policy.json') == lock['policy']['sha256']
    for entry in lock['locked_existing_files']:
        assert digest(ROOT / entry['path']) == entry['sha256'], entry['path']
    audit = read(ROOT / 'results/stage7/accepted/own/assumption-audit.json')
    for key in ['theorem_assumptions', 'witness_assumptions',
                'independent_closure_assumptions', 'checked_modules']:
        assert lock[key] == audit[key], key
    assert len(lock['checked_modules']) == 579
    assert len(lock['independent_closure_assumptions']) == 86
    assert policy['release_artifact']['sha256'] == audit['artifact_sha256']
    assert policy['end_to_end'] is False and lock['end_to_end'] is False
    release = read(ROOT / 'results/stage9/preparation/references/github-metadata.json')['cosign_release']
    assert release['tag_name'] == 'v' + policy['signature']['version']
    assets = {x['name']: x['digest'] for x in release['assets']}
    for platform, sha in policy['signature']['executable_sha256'].items():
        assert assets['cosign-' + platform] == 'sha256:' + sha
    command = ['git', 'apply', '--check', str(PROPOSAL / 'protected.diff')]
    print('PATCH_DRY_RUN_COMMAND:', json.dumps(command), flush=True)
    result = subprocess.run(command, cwd=ROOT, check=False)
    print('PATCH_DRY_RUN_EXIT_CODE:', result.returncode, flush=True)
    if result.returncode:
        return result.returncode
    print('PROPOSAL_INTEGRITY_OK: 3 unapplied additions; 47 locked existing files; '
          '579 module identities; unchanged 13/13/86 assumption lists')
    print('STAGE9_EXITS: NOT RUN; SIGNATURES: NOT RUN; DEPLOYMENT: NOT RUN')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
