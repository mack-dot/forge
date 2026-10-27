#!/usr/bin/env python3
"""Proposal integrity and syntax only. Does not execute a candidate gate."""
import ast
import hashlib
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
P = ROOT / 'proposals/provenance-implementation'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    manifest = json.loads((P / 'approval-manifest.json').read_text())
    assert manifest['status'] == 'pending_exact_human_approval'
    assert len(manifest['changes']) == 11
    expected_targets = {
        'gate/provenance/' + x for x in ['common.py', 'release.py', 'producer.py', 'observe.py',
                                         'preflight.py', 'Dockerfile', 'runtime.json', 'implementation.lock']}
    expected_targets |= {'.github/workflows/provenance.yml', '.github/workflows/provenance-negative.yml',
                         'scripts/exit_stage_9.py'}
    assert {x['target'] for x in manifest['changes']} == expected_targets
    rebuilt = []
    candidates = {}
    for entry in manifest['changes']:
        file = ROOT / entry['candidate']
        assert entry['operation'] == 'add' and not (ROOT / entry['target']).exists()
        assert sha(file) == entry['sha256'] and file.stat().st_size == entry['bytes']
        candidates[entry['target']] = file
        if file.suffix == '.py':
            ast.parse(file.read_text())
            compile(file.read_text(), str(file), 'exec')
        lines = file.read_text().splitlines(keepends=True)
        target = entry['target']
        rebuilt.append(f'diff --git a/{target} b/{target}\nnew file mode 100644\n'
                       f'--- /dev/null\n+++ b/{target}\n@@ -0,0 +1,{len(lines)} @@\n'
                       + ''.join('+' + line for line in lines))
    assert ''.join(rebuilt).encode() == (P / 'proposed.diff').read_bytes()
    assert sha(P / 'proposed.diff') == manifest['patch_sha256']
    assert sha(P / 'implementation.lock') == manifest['implementation_lock_sha256']
    lock = json.loads((P / 'implementation.lock').read_text())
    assert len(lock['files']) == 60 and len(lock['python_container_dependencies']) == 45
    for target, expected in lock['files'].items():
        assert sha(candidates.get(target, ROOT / target)) == expected, target
    for path, expected in lock['python_container_dependencies'].items():
        assert sha(ROOT / '.toolchain/stage7/pydeps' / path) == expected, path
    approved = json.loads((ROOT / 'proposals/provenance/approval-manifest.json').read_text())
    for entry in approved['changes']:
        assert sha(ROOT / entry['target']) == entry['sha256']
    # Use the already pinned local YAML library for structural inspection only.
    sys.path.insert(0, str(ROOT / '.toolchain/stage7/pydeps-host'))
    import yaml
    assert yaml.__version__ == '6.0.3'
    workflows = [yaml.safe_load((P / name).read_text())
                 for name in ['provenance.yml', 'provenance-negative.yml']]
    for workflow in workflows:
        assert set(workflow['on']) == {'workflow_dispatch'}
        assert workflow['concurrency']['cancel-in-progress'] is False
        for job in workflow['jobs'].values():
            assert job['runs-on'] == ['self-hosted', 'macOS', 'ARM64', 'forge-stage9']
            for step in job['steps']:
                if 'uses' in step:
                    assert len(step['uses'].split('@')[1]) == 40
    assert workflows[0]['permissions'] == {'contents': 'read'}
    assert workflows[0]['jobs']['sign']['needs'] == 'proof'
    assert workflows[0]['jobs']['sign']['permissions']['id-token'] == 'write'
    assert workflows[1]['permissions']['id-token'] == 'write'
    command = ['git', 'apply', '--check', str(P / 'proposed.diff')]
    print('PATCH_DRY_RUN_COMMAND:', json.dumps(command), flush=True)
    result = subprocess.run(command, cwd=ROOT)
    print('PATCH_DRY_RUN_EXIT_CODE:', result.returncode, flush=True)
    if result.returncode:
        return result.returncode
    print('PROPOSAL_INTEGRITY_OK: 11 unapplied additions; 60 locked files; 45 dependency files; '
          '6 Python files parsed; 2 manual workflows inspected.')
    print('STAGE9_EXITS: NOT RUN; SIGNATURES: NOT RUN; NEW_PROOFS: NOT RUN; DEPLOYMENT: NOT RUN')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
