"""Prepare a two-file booking experiment after the separately approved repair.

No GitHub write, workflow dispatch, signing, or Node integration is performed.
"""
import ast
import difflib
import hashlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / 'hosted'
OUT.mkdir(exist_ok=True)
text = (HERE / 'regression.py').read_text()
text = text.replace('    parser.add_argument(\'--cross-process\', action=\'store_true\')',
                    "    parser.add_argument('--cross-process', action='store_true')\n"
                    "    parser.add_argument('--candidate', type=Path, required=True)\n"
                    "    parser.add_argument('--preflight', action='store_true')")
text = text.replace('    sys.path.insert(0, str(root / \'gate\'))', '''    candidate = args.candidate.resolve()
    if args.preflight:
        preflight()
        return 0
    if not (os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('RUNNER_ENVIRONMENT') == 'github-hosted' and platform.system() == 'Linux'
            and platform.machine() == 'x86_64' and os.environ.get('GITHUB_REF') == 'refs/heads/main'):
        raise RuntimeError('Requires an authorized GitHub-hosted Linux/main dispatch')
    if os.environ.get('GITHUB_EVENT_NAME') != 'workflow_dispatch':
        raise RuntimeError('Unexpected trigger')
    for directory, expected in ((root, os.environ['GITHUB_SHA']), (candidate, os.environ['BOOKING_HEAD'])):
        if git(directory, 'rev-parse', 'HEAD').strip().decode() != expected:
            raise RuntimeError('Exact checkout identity differs')
        if git(directory, 'diff', '--name-only', 'HEAD', '--'):
            raise RuntimeError('Tracked checkout differs')
    if not args.cross_process:
        # The only cold-case change is the real PR implementation alternative.
        original = (root / 'impl/Booking.dfy').read_text()
        if original.count('other < value') != 1 or (candidate / 'impl/Booking.dfy').read_text() != original.replace('other < value', 'other <= value'):
            raise RuntimeError('Booking PR differs from the approved experiment fixture')
    sys.path.insert(0, str(root / 'gate'))''')
text = text.replace("'candidate_commit': None, 'candidate_kind': 'local uncommitted fixture',",
                    "'candidate_commit': git(candidate, 'rev-parse', 'HEAD').decode().strip(),\n"
                    "               'candidate_kind': 'GitHub PR head' if candidate == args.candidate.resolve() else 'unpublished hosted fixture commit',")
text = text.replace("'hosted_execution': False", "'hosted_execution': True")
text = text.replace("root.parent / (root.name + '-fixtures') / 'A'", 'candidate')
start = text.index("    fixtures = root.parent / (root.name + '-fixtures')")
end = text.index("    a = run('A-cold'", start)
text = text[:start] + '''    fixtures = root / 'build/booking-fixtures'
    fixtures.mkdir(exist_ok=False)
    write(out / 'environment.json', {
        'trusted_commit': os.environ['GITHUB_SHA'], 'pr_head': os.environ['BOOKING_HEAD'],
        'run_id': os.environ['GITHUB_RUN_ID'], 'run_attempt': os.environ['GITHUB_RUN_ATTEMPT'],
        'workflow_ref': os.environ['GITHUB_WORKFLOW_REF'],
        'implementation_lock_sha256': digest((root / 'gate/provenance/implementation.lock').read_bytes()),
        'harness_sha256': digest(Path(__file__).read_bytes()),
        'host': platform.platform(), 'python_version': platform.python_version(),
        'python_sha256': digest(Path(sys.executable).read_bytes()),
        'image_version': os.environ.get('ImageVersion'),
        'runner_environment': os.environ['RUNNER_ENVIRONMENT'],
        'runner_os': os.environ.get('RUNNER_OS'), 'runner_arch': os.environ.get('RUNNER_ARCH'),
        'hosted_execution': True})

''' + text[end:]
text = text.replace('shutil.copytree(candidate, changed)', 'copy_fixture(candidate, changed)')
text = text.replace('shutil.copytree(candidate, uncovered)', 'copy_fixture(candidate, uncovered)')
text = text.replace('shutil.copytree(candidate, harness)', 'copy_fixture(candidate, harness)')
text = text.replace("    c = run('C-invalidation'", "    commit_fixture(changed)\n    c = run('C-invalidation'")
text = text.replace("    run('D-uncovered'", "    commit_fixture(uncovered)\n    run('D-uncovered'")
text = text.replace("    run('D-harness'", "    commit_fixture(harness)\n    run('D-harness'")
text = text.replace("'--out', str(out / 'cross-process'), '--cross-process']",
                    "'--out', str(out / 'cross-process'), '--candidate', str(candidate), '--cross-process']")
text = text.replace("'local_security_acceptance': True", "'hosted_security_acceptance': True")
text = text.replace('Run on the prepared checkout with the existing pinned local toolchain. This\nrecords local executions only.',
                    'Run only from the approved main workflow on GitHub-hosted Linux.')
helpers = '''
def git(directory, *args):
    return subprocess.check_output(['git', '-c', 'core.hooksPath=/dev/null', '-c', 'core.fsmonitor=false',
                                    '-C', str(directory), *args])


def copy_fixture(candidate, destination):
    # Candidate checkout is input data. Never carry its .git or cached toolchain.
    shutil.copytree(candidate, destination, ignore=shutil.ignore_patterns('.git', 'build', '.toolchain', 'node_modules'))


def commit_fixture(directory):
    git(directory, 'init', '-q')
    git(directory, 'add', '--force', '--all')
    env = dict(os.environ, GIT_AUTHOR_NAME='Forge experiment fixture', GIT_AUTHOR_EMAIL='fixture@invalid',
               GIT_COMMITTER_NAME='Forge experiment fixture', GIT_COMMITTER_EMAIL='fixture@invalid',
               GIT_AUTHOR_DATE='2000-01-01T00:00:00Z', GIT_COMMITTER_DATE='2000-01-01T00:00:00Z')
    subprocess.run(['git', '-c', 'core.hooksPath=/dev/null', '-C', str(directory), 'commit',
                    '--no-gpg-sign', '-qm', 'Unpublished booking acceptance fixture'], env=env, check=True)


def preflight():
    import re
    import urllib.request
    if (os.environ.get('GITHUB_REPOSITORY') != 'mack-dot/forge'
            or os.environ.get('GITHUB_REF') != 'refs/heads/main'
            or os.environ.get('GITHUB_EVENT_NAME') != 'workflow_dispatch'):
        raise RuntimeError('Wrong repository, ref, or trigger')
    number, head = os.environ['BOOKING_PR'], os.environ['BOOKING_HEAD']
    if not re.fullmatch('[1-9][0-9]*', number) or not re.fullmatch('[0-9a-f]{40}', head):
        raise RuntimeError('Exact PR number and head required')
    def get(suffix):
        request = urllib.request.Request('https://api.github.com/repos/mack-dot/forge' + suffix,
            headers={'Accept': 'application/vnd.github+json', 'Authorization': 'Bearer ' + os.environ['GH_TOKEN'],
                     'User-Agent': 'forge-booking-experiment'})
        with urllib.request.urlopen(request) as response:
            if response.status != 200:
                raise RuntimeError('GitHub read failed')
            return json.load(response)
    pr = get('/pulls/' + number)
    if not (pr['state'] == 'open' and pr['head']['sha'] == head
            and pr['base']['sha'] == os.environ['GITHUB_SHA'] and pr['base']['ref'] == 'main'
            and pr['base']['repo']['id'] == 1434789853 and pr['head']['repo']['id'] == 1434789853
            and pr['changed_files'] == 1):
        raise RuntimeError('PR identity or approved experiment scope differs')
    changes = get('/pulls/' + number + '/files?per_page=100')
    if len(changes) != 1 or changes[0]['filename'] != 'impl/Booking.dfy' or changes[0]['status'] != 'modified':
        raise RuntimeError('Only the real booking implementation change is in scope')
    # Metadata is an observation, not an approval token or a reusable proof receipt.
    Path('build').mkdir(exist_ok=True)
    write(Path('build/booking-preflight.json'), {'pr': pr['number'], 'head': head,
          'base': pr['base']['sha'], 'changed_files': changes, 'run_id': os.environ['GITHUB_RUN_ID']})

'''
text = text.replace('\ndef main():', '\n' + helpers + '\ndef main():')
ast.parse(text)
(OUT / 'booking_reuse.py').write_text(text)
workflow = '''name: Forge booking reuse experiment

"on":
  workflow_dispatch:
    inputs:
      booking_pr:
        description: Approved experiment PR number (one Booking.dfy change)
        required: true
        type: string
      booking_head:
        description: Exact 40-character head approved for this dispatch
        required: true
        type: string

permissions: {}

jobs:
  experiment:
    if: github.repository == 'mack-dot/forge' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-22.04
    permissions:
      contents: read
      pull-requests: read
    env:
      BOOKING_PR: ${{ inputs.booking_pr }}
      BOOKING_HEAD: ${{ inputs.booking_head }}
    steps:
      - name: Read the approved workflow revision
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          ref: ${{ github.sha }}
          path: trusted
          persist-credentials: false
      - name: Select the pinned Python version
        uses: actions/setup-python@a26af69be951a213d495a4c3e4e4022e16d87065
        with:
          python-version: '3.10.11'
          check-latest: false
      - name: Validate locked producer inputs before setup
        working-directory: trusted
        run: |
          echo '8895a0881586dfcdf844fca8c09ec8bac662cbbc158cadb19084cfc5a5385bbf  gate/provenance/bootstrap.py' | sha256sum -c -
          python -I -S -B gate/provenance/bootstrap.py --implementation-sha256 76b983ac279a80ab42bf15c7446ee997a2bcd9b25a003db829f7e8fb2d4b8cd9 --check
      - name: Bind the exact booking PR
        working-directory: trusted
        env:
          GH_TOKEN: ${{ github.token }}
        run: python -I -B .github/experiments/booking_reuse.py --root . --out build/booking-observations --candidate ../candidate --preflight
      - name: Read the proposed revision as data
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
        with:
          repository: mack-dot/forge
          ref: ${{ inputs.booking_head }}
          path: candidate
          persist-credentials: false
          submodules: false
          lfs: false
      - name: Install the pinned verifier and validator
        working-directory: trusted
        run: |
          python -m venv .toolchain/ci-python
          .toolchain/ci-python/bin/python -m pip install --disable-pip-version-check pip==25.3
          .toolchain/ci-python/bin/python toolchain/install_ci.py
      - name: Run real cold, warm, invalidation, and hostile cases
        working-directory: trusted
        run: .toolchain/ci-python/bin/python -I -B .github/experiments/booking_reuse.py --root . --out build/booking-observations --candidate ../candidate
      - name: Preserve experiment observations, including failures
        if: always()
        uses: actions/upload-artifact@ea165f8d65b6e75b540449e92b4886f43607fa02
        with:
          name: forge-booking-experiment-${{ github.run_id }}-${{ github.run_attempt }}
          if-no-files-found: error
          path: |
            trusted/build/booking-observations/
            trusted/build/booking-preflight.json
            trusted/build/security-cache/
            trusted/build/regression-*/operation.json
            trusted/build/regression-*/obligations/
            trusted/build/regression-*/verify/build/obligations/
            trusted/build/*.json
'''
(OUT / 'booking-reuse.yml').write_text(workflow)
patch = ''.join(''.join(difflib.unified_diff([], data.splitlines(True), fromfile='/dev/null', tofile='b/' + name))
                for name, data in [('.github/experiments/booking_reuse.py', text),
                                   ('.github/workflows/booking-reuse.yml', workflow)])
(HERE / 'booking-ci.patch').write_text(patch)
print('Prepared only: booking-ci.patch sha256=' + hashlib.sha256(patch.encode()).hexdigest())
