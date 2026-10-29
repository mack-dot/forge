#!/usr/bin/env python3
"""Build the unapplied v3.3 candidate from installed v3.2 (U128).

V1  Every interpreter that runs before authentication uses -I, so the checkout
    is never on sys.path (all three ensurepip steps).
V2  Every locked `-m`/`-c` child interpreter uses -I (two pip calls, the
    in-container collector).
V3  bootstrap.py and source_tree() reject anything importable at the checkout
    root: modules, extension modules, .pth files, regular packages, symlinks and
    bytecode caches.
V4  provenance.yml names each run after the challenge at dispatch; the receipt
    records the run; release.py checks that run with the GitHub API.
Low The verifier refuses any GitHub Actions marker; git never receives the token
    variable, and a public fetch gets no credential.
EXIT harness: refuses unless started by the bootstrap; launches the verifier
    through the bootstrap; the unsigned fixture removes only the signatures; a
    positive re-check replaces error-string matching.
Contract, policy and contract_approval_commit stay unchanged. Writes only under
this directory.
"""
import difflib
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
OUT = HERE / 'candidate'
INSTALLED_LOCK = 'be23ec85ec2d9652bd1c87f6870c0d7130862af169319af24975b941ac3b5f57'
IMPORTABLE = "ROOT_IMPORTABLE = ('.py', '.pyc', '.pyo', '.pyw', '.pyd', '.so', '.pth')\n"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def dump(value):
    return (json.dumps(value, indent=2, sort_keys=True) + '\n').encode()


def edit(text, pairs):
    for old, new, count in pairs:
        assert text.count(old) == count, ('EDIT_ANCHOR', old[:60], text.count(old))
        text = text.replace(old, new)
    return text


RUN_IDENTITY = '''

def run_identity(policy, request, execution, records):
    """Check with the GitHub API that the receipt's run is the run dispatched for this request.

    GitHub records the run name, which carries the challenge, at dispatch, before
    any job runs. Trust assumption: GitHub executed the locked workflow in that
    run; Forge does not observe the runner itself.
    """
    repo = policy['signer']['repository']
    run = parse(fetch('https://api.github.com/repos/' + repo + '/actions/runs/' + execution['run_id'], records,
                      'proof-run', token_name='FORGE_VERIFIER_GITHUB_TOKEN'))
    require(str(run['id']) == execution['run_id'] and run['run_attempt'] == 1
            and run['path'] == '.github/workflows/provenance.yml'
            and 'refs/heads/' + run['head_branch'] == policy['signer']['ref']
            and run['head_sha'] == request['expected_source_commit'] and run['event'] == policy['signer']['event']
            and run['display_title'] == 'forge-stage9 ' + request['challenge']
            and run['repository']['id'] == policy['signer']['repository_id']
            and run['status'] == 'completed' and run['conclusion'] == 'success', 'PROOF_RUN_IDENTITY')
'''

EDITS = {
    '.github/workflows/provenance.yml': [
        ('"$P/bin/python3" -m ensurepip --default-pip', '"$P/bin/python3" -I -m ensurepip --default-pip', 2),
        ('name: Forge Stage 9 provenance\n',
         'name: Forge Stage 9 provenance\n'
         '# GitHub records this name at dispatch; the verifier checks it (V4).\n'
         'run-name: forge-stage9 ${{ fromJSON(inputs.request).challenge }}\n', 1)],
    '.github/workflows/provenance-negative.yml': [
        ('"$P/bin/python3" -m ensurepip --default-pip', '"$P/bin/python3" -I -m ensurepip --default-pip', 1)],
    'gate/provenance/hosted_setup.py': [
        ("records.run([sys.executable, '-m', 'pip', 'install', '--disable-pip-version-check',",
         "# -I: a child interpreter does not inherit isolation; keep the checkout off sys.path.\n"
         "    records.run([sys.executable, '-I', '-m', 'pip', 'install', '--disable-pip-version-check',", 1),
        ("records.run([link, '-m', 'pip', 'install', '--require-hashes',",
         "records.run([link, '-I', '-m', 'pip', 'install', '--require-hashes',", 1)],
    'gate/provenance/producer.py': [
        ("    collector = ['python3', '-c', '\\n'.join([",
         "    collector = ['python3', '-I', '-c', '\\n'.join([", 1),
        ("    manifest = {'challenge': request['challenge'], 'source_commit': request['expected_source_commit'],\n"
         "                'files': files(proof), 'end_to_end': False}\n",
         "    manifest = {'challenge': request['challenge'], 'source_commit': request['expected_source_commit'],\n"
         "                'execution': {'run_id': os.environ.get('GITHUB_RUN_ID', ''),\n"
         "                              'run_attempt': os.environ.get('GITHUB_RUN_ATTEMPT', '')},\n"
         "                'files': files(proof), 'end_to_end': False}\n", 1)],
    'gate/provenance/bootstrap.py': [
        ("                 '.glob', '.c', '.h', '.sh')\n",
         "                 '.glob', '.c', '.h', '.sh')\n" + IMPORTABLE, 1),
        ("def check(expected):\n",
         "def root_entries():\n"
         "    # A child started with -m or -c in the checkout has the root on sys.path, so\n"
         "    # nothing importable may live there (U128 V1-V3).\n"
         "    for name in sorted(os.listdir(ROOT)):\n"
         "        full = os.path.join(ROOT, name)\n"
         "        mode = os.lstat(full).st_mode\n"
         "        if stat.S_ISLNK(mode) or name == '__pycache__' or name.endswith(ROOT_IMPORTABLE) or (\n"
         "                stat.S_ISDIR(mode) and any(entry.startswith('__init__.') for entry in os.listdir(full))):\n"
         "            fail('ROOT_IMPORTABLE:' + name)\n"
         "\n"
         "\n"
         "def check(expected):\n", 1),
        ("        files = json.loads(stream.read())['files']\n",
         "        files = json.loads(stream.read())['files']\n"
         "    root_entries()\n", 1)],
    'gate/provenance/common.py': [
        ("                 '.glob', '.c', '.h', '.sh')\n",
         "                 '.glob', '.c', '.h', '.sh')\n" + IMPORTABLE, 1),
        ("    for path, (mode, kind, obj) in sorted(entries.items()):\n"
         "        if path.startswith(EXECUTABLE_ROOTS)",
         "    for path, (mode, kind, obj) in sorted(entries.items()):\n"
         "        top, _, rest = path.partition('/')\n"
         "        # The same root rule as bootstrap.py: nothing importable at the checkout root.\n"
         "        require(top != '__pycache__' and not top.endswith(ROOT_IMPORTABLE) and (rest or mode != '120000')\n"
         "                and not (rest.startswith('__init__.') and '/' not in rest), 'ROOT_IMPORTABLE:' + top)\n"
         "        if path.startswith(EXECUTABLE_ROOTS)", 1),
        ("    require(os.environ.get('GITHUB_ACTIONS') != 'true', 'VERIFIER_NOT_INDEPENDENT')\n",
         "    require(not os.environ.get('GITHUB_ACTIONS') and not os.environ.get('ACTIONS_ID_TOKEN_REQUEST_URL'),\n"
         "            'VERIFIER_NOT_INDEPENDENT')\n", 1),
        ("    # The credential reaches git only through the environment, never argv or records.\n"
         "    basic = base64.b64encode(('x-access-token:' + os.environ['FORGE_VERIFIER_GITHUB_TOKEN']).encode()).decode()\n"
         "    env = dict(os.environ, GIT_TERMINAL_PROMPT='0', GIT_CONFIG_COUNT='1',\n"
         "               GIT_CONFIG_KEY_0='http.https://github.com/.extraheader',\n"
         "               GIT_CONFIG_VALUE_0='AUTHORIZATION: basic ' + basic)\n",
         "    # git never gets the token variable. It gets one header value, only for a\n"
         "    # private repository; a public fetch needs no credential.\n"
         "    env = {key: value for key, value in os.environ.items() if key != 'FORGE_VERIFIER_GITHUB_TOKEN'}\n"
         "    env['GIT_TERMINAL_PROMPT'] = '0'\n"
         "    if info['private']:\n"
         "        basic = base64.b64encode(('x-access-token:' + os.environ['FORGE_VERIFIER_GITHUB_TOKEN']).encode()).decode()\n"
         "        env.update(GIT_CONFIG_COUNT='1', GIT_CONFIG_KEY_0='http.https://github.com/.extraheader',\n"
         "                   GIT_CONFIG_VALUE_0='AUTHORIZATION: basic ' + basic)\n", 1),
        ("    source_tree(git_dir, commit, implementation, records)\n",
         "    source_tree(git_dir, commit, implementation, records)\n" + RUN_IDENTITY, 1)],
    'gate/provenance/release.py': [
        ("                    parse, read, repository_identity, require, sha, signature, write)\n",
         "                    parse, read, repository_identity, require, run_identity, sha, signature, write)\n", 1),
        ("    require(set(manifest) == {'challenge', 'source_commit', 'files', 'end_to_end'}\n"
         "            and manifest['end_to_end'] is False and isinstance(manifest['files'], dict), 'PROOF_RECEIPT_FIELDS')\n",
         "    require(set(manifest) == {'challenge', 'source_commit', 'execution', 'files', 'end_to_end'}\n"
         "            and manifest['end_to_end'] is False and isinstance(manifest['files'], dict), 'PROOF_RECEIPT_FIELDS')\n"
         "    # The run that made this receipt; verify() checks it with the GitHub API (V4).\n"
         "    execution = manifest['execution']\n"
         "    require(isinstance(execution, dict) and set(execution) == {'run_id', 'run_attempt'}\n"
         "            and re.fullmatch('[1-9][0-9]{0,19}', execution['run_id']) and execution['run_attempt'] == '1',\n"
         "            'PROOF_RECEIPT_EXECUTION')\n", 1),
        ("    repository_identity(policy, implementation, request['expected_source_commit'], records)\n",
         "    repository_identity(policy, implementation, request['expected_source_commit'], records)\n"
         "    run_identity(policy, request, read(root / 'proof/receipt.json')['execution'], records)\n", 1),
        ("'kernel_execution_here': False, 'producer_fresh_kernel_receipt_verified': True,",
         "'kernel_execution_here': False, 'producer_receipt_labels_consistent': True,\n"
         "            'proof_run_identity_checked_with_github_api': True,\n"
         "            'freshness_trust_assumption': 'GitHub executed the locked workflow in the recorded run',", 1)],
    'scripts/exit_stage_9.py': [
        ('"""Run real Stage 9 controls. Never treat setup errors as security rejections."""\n'
         'import argparse\n',
         '"""Run real Stage 9 controls. Never treat setup errors as security rejections."""\n'
         'import sys\n'
         '\n'
         '# Run only as a child of the authenticated bootstrap (U127 D3, U131). Refuse before\n'
         '# any import can resolve from the checkout; sys is built in.\n'
         "if not (sys.flags.ignore_environment and sys.flags.no_user_site and sys.flags.dont_write_bytecode\n"
         "        and 'forge-pycache-' in (sys.pycache_prefix or '')):\n"
         "    raise SystemExit('EXIT_SETUP_NOT_ESTABLISHED: run through gate/provenance/bootstrap.py')\n"
         'import argparse\n', 1),
        ("                bundle['dsseEnvelope']['signatures'] = []\n"
         "                unsigned = parse(base64.b64decode(bundle['dsseEnvelope']['payload'], validate=True))\n"
         "                unsigned['predicate']['purpose'] = 'security-control'\n"
         "                bundle['dsseEnvelope']['payload'] = base64.b64encode(canonical(unsigned)).decode()\n",
         "                # Only the signatures change, so Cosign's rejection can come only from their absence.\n"
         "                bundle['dsseEnvelope']['signatures'] = []\n", 1),
        ("            raw = (result_dir / checks[0]['stderr']).read_text() + (result_dir / checks[0]['stdout']).read_text()\n"
         "            require(any(marker in raw for marker in markers), 'NOT_THE_INTENDED_SECURITY_REJECTION')\n",
         "            # Cosign decides. The same positive check must pass again right after the\n"
         "            # rejection, so the rejection comes from the mutation, not from Cosign, TUF or\n"
         "            # the network. Error text is recorded, never required (U127 D1).\n"
         "            _, after = gate(candidate, 'positive-after', 0)\n"
         "            require_signature_success(after)\n"
         "            raw = (result_dir / checks[0]['stderr']).read_text() + (result_dir / checks[0]['stdout']).read_text()\n"
         "            outcomes[-2]['matched_known_cosign_text'] = any(marker in raw for marker in markers)\n", 1),
        ("            command = ['python3', str(ROOT / 'gate/provenance' / script), '--candidate', str(path),\n",
         "            # Launch through the authenticated bootstrap: isolated Python, no bytecode.\n"
         "            command = ['python3', '-I', '-S', '-B', str(ROOT / 'gate/provenance/bootstrap.py'),\n"
         "                       '--implementation-sha256', config['implementation_sha256'], '--',\n"
         "                       str(ROOT / 'gate/provenance' / script), '--candidate', str(path),\n", 1),
        ("                markers = ['exactly one signature is required']\n",
         "                # Cosign 3.1.4 rejects an emptied envelope at the log-inclusion check\n"
         "                # (results/stage9/cosign-offline-0001); older releases at the count check.\n"
         "                markers = ['exactly one signature is required',\n"
         "                           'failed to verify log inclusion: transparency log signature does not match']\n",
         1)],
}


def main():
    assert sha((ROOT / 'gate/provenance/implementation.lock').read_bytes()) == INSTALLED_LOCK, 'INSTALLED_LOCK'
    base = {path: (ROOT / path).read_bytes() for path in EDITS}
    lock = json.loads((ROOT / 'gate/provenance/implementation.lock').read_bytes())
    for path, data in base.items():
        assert lock['files'][path] == sha(data), ('BASE_NOT_INSTALLED', path)
    new = {path: edit(base[path].decode(), pairs).encode() for path, pairs in EDITS.items()}
    for path, data in new.items():
        lock['files'][path] = sha(data)
    new['gate/provenance/implementation.lock'] = dump(lock)
    patch, manifest = [], {'base_lock_sha256': INSTALLED_LOCK, 'base_main_commit': 'd43f5f4de55573a17f4f9cf4d41528dd159e9f2f',
                           'contract_unchanged': True, 'end_to_end': False, 'files': {}}
    for path in sorted(new):
        old = (ROOT / path).read_bytes()
        target = OUT / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(new[path])
        lines = list(difflib.unified_diff(old.decode().splitlines(True), new[path].decode().splitlines(True),
                                          'a/' + path, 'b/' + path, n=3))
        patch.append(''.join([f'diff --git a/{path} b/{path}\n'] + lines))
        manifest['files'][path] = {'old_sha256': sha(old), 'new_sha256': sha(new[path])}
    diff = ''.join(patch).encode()
    (HERE / 'proposed.diff').write_bytes(diff)
    manifest.update(diff_sha256=sha(diff), new_lock_sha256=sha(new['gate/provenance/implementation.lock']),
                    locked_files=len(lock['files']))
    (HERE / 'approval-manifest.json').write_bytes(dump(manifest))
    print(json.dumps({k: manifest[k] for k in ('diff_sha256', 'new_lock_sha256', 'locked_files')}, indent=2))
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
