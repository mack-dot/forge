#!/usr/bin/env python3
"""Safe installed-byte/syntax checks. No runner, Docker, Cosign or proof run."""
import ast
import hashlib
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.dont_write_bytecode = True
sys.path.insert(0, str(ROOT / 'gate/provenance'))
from common import context, digest, files


def main():
    manifest = json.loads((ROOT / 'proposals/provenance-implementation/approval-manifest.json').read_text())
    for item in manifest['changes']:
        p = ROOT / item['target']
        assert p.read_bytes() == (ROOT / item['candidate']).read_bytes()
        assert digest(p) == item['sha256'] and p.stat().st_size == item['bytes']
        if p.suffix == '.py':
            ast.parse(p.read_text())
            compile(p.read_text(), str(p), 'exec')
    _, _, implementation = context(manifest['implementation_lock_sha256'])
    assert files(ROOT / '.toolchain/stage7/pydeps') == implementation['python_container_dependencies']
    sys.path.insert(0, str(ROOT / '.toolchain/stage7/pydeps-host'))
    import yaml
    assert yaml.__version__ == '6.0.3'
    workflows = [yaml.safe_load((ROOT / '.github/workflows' / n).read_text())
                 for n in ['provenance.yml', 'provenance-negative.yml']]
    assert all(set(w['on']) == {'workflow_dispatch'} for w in workflows)
    assert workflows[0]['permissions'] == {'contents': 'read'}
    assert workflows[0]['jobs']['sign']['needs'] == 'proof'
    assert workflows[0]['jobs']['sign']['permissions']['id-token'] == 'write'
    assert workflows[1]['permissions']['id-token'] == 'write'
    print(json.dumps({'result': 'installed_bytes_and_syntax_match', 'installed_files': 11,
                      'locked_files': len(implementation['files']),
                      'upstream_python_files': len(implementation['python_container_dependencies']),
                      'signature_execution': 'not_run', 'proof_execution': 'not_run',
                      'workflow_execution': 'not_run', 'end_to_end': False}, sort_keys=True))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
