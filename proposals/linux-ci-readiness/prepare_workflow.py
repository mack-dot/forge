"""Prepare an exact one-file workflow proposal. Never apply it to a checkout."""
from pathlib import Path
import difflib
import hashlib
import json
import subprocess

HEAD = '561d2dda904daf18f17a0fede93f28b502d72884'
SOURCE = Path('/Users/mackianni/forge-linux')
OUT = Path(__file__).resolve().parent
PATH = '.github/workflows/proof-gate.yml'
before = subprocess.check_output(['git', '-C', str(SOURCE), 'show', HEAD + ':' + PATH]).decode()
marker = '      - name: Check exact PR revisions with trusted code\n'
assert before.count(marker) == 1
step = '''      - name: Install the recorded Node and package bytes
        working-directory: trusted
        shell: bash
        run: |
          set -euo pipefail
          forge_node_dir=$(mktemp -d "$RUNNER_TEMP/forge-node.XXXXXX")
          curl --fail --location --silent --show-error --output "$forge_node_dir/node.tar.xz" https://nodejs.org/dist/v24.3.0/node-v24.3.0-linux-x64.tar.xz
          printf '%s  %s\\n' 'a962afadaa8b94bae8bff87ddd6c11f7aae621032424ef05c0a4fe2537fa4de0' "$forge_node_dir/node.tar.xz" | sha256sum --check --strict
          mkdir "$forge_node_dir/runtime"
          tar -xJf "$forge_node_dir/node.tar.xz" -C "$forge_node_dir/runtime" --strip-components=1
          printf '%s  %s\\n' '11ee468e2ac16c11dde59c6897b341968442430439733fdce6ff6f4da8bca38f' "$forge_node_dir/runtime/bin/node" | sha256sum --check --strict
          export PATH="$forge_node_dir/runtime/bin:$PATH"
          printf '%s\\n' "$forge_node_dir/runtime/bin" >> "$GITHUB_PATH"
          test "$(npm --version)" = '11.4.2'
          npm ci --ignore-scripts --no-audit --no-fund
          .toolchain/ci-python/bin/python scripts/javascript_env.py
'''
after = before.replace(marker, step + marker)
(OUT / 'proof-gate.yml.proposed').write_text(after)
(OUT / 'node-workflow.patch').write_text(''.join(difflib.unified_diff(
    before.splitlines(True), after.splitlines(True), fromfile='a/' + PATH, tofile='b/' + PATH)))
manifest = {'source_commit': HEAD, 'target_path': PATH,
            'before_sha256': hashlib.sha256(before.encode()).hexdigest(),
            'after_sha256': hashlib.sha256(after.encode()).hexdigest(),
            'patch_sha256': hashlib.sha256((OUT / 'node-workflow.patch').read_bytes()).hexdigest(),
            'status': 'PROPOSED_NOT_APPLIED_NOT_EXECUTED'}
(OUT / 'workflow-manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
print(json.dumps(manifest, indent=2))
