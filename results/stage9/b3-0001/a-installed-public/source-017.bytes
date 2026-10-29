"""Record handling and policy binding. No signature or proof semantics."""
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


class Rejected(Exception):
    def __init__(self, reason):
        super().__init__(reason)
        self.reason = reason


def require(ok, reason):
    if not ok:
        raise Rejected(reason)


def sha(data):
    return hashlib.sha256(data).hexdigest()


def digest(path):
    return sha(Path(path).read_bytes())


def canonical(value):
    return (json.dumps(value, sort_keys=True, separators=(',', ':'),
                       ensure_ascii=True, allow_nan=False) + '\n').encode()


def parse(data):
    def pairs(items):
        result = {}
        for key, value in items:
            require(key not in result, 'DUPLICATE_JSON_KEY')
            result[key] = value
        return result
    def invalid(_):
        raise Rejected('NONFINITE_JSON_NUMBER')
    return json.loads(data, object_pairs_hook=pairs, parse_constant=invalid)


def read(path):
    return parse(Path(path).read_bytes())


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(canonical(value))


def files(directory):
    directory = Path(directory)
    result = {}
    for p in sorted(directory.rglob('*')):
        require(not p.is_symlink(), 'SYMLINK_INPUT')
        if p.is_file():
            result[p.relative_to(directory).as_posix()] = digest(p)
    return result


class Records:
    def __init__(self, directory):
        self.directory = Path(directory)
        self.directory.mkdir(parents=True, exist_ok=False)
        self.commands = []

    def run(self, argv, label, *, env=None, cwd=ROOT, check=True):
        require(re.fullmatch(r'[a-z0-9-]+', label), 'RECORD_LABEL')
        prefix = self.directory / f'{len(self.commands):03d}-{label}'
        invocation = {'argv': list(map(str, argv)), 'cwd': str(cwd)}
        write(str(prefix) + '.invocation.json', invocation)
        with open(str(prefix) + '.stdout', 'xb') as out, open(str(prefix) + '.stderr', 'xb') as err:
            result = subprocess.run(invocation['argv'], cwd=cwd, env=env,
                                    stdout=out, stderr=err, check=False)
        record = {**invocation, 'exit_code': result.returncode,
                  'stdout': Path(str(prefix) + '.stdout').name,
                  'stderr': Path(str(prefix) + '.stderr').name,
                  'stdout_sha256': digest(str(prefix) + '.stdout'),
                  'stderr_sha256': digest(str(prefix) + '.stderr')}
        self.commands.append(record)
        write(self.directory / 'commands.json', self.commands)
        if check:
            require(result.returncode == 0, 'COMMAND_FAILED:' + label)
        return result.returncode, Path(str(prefix) + '.stdout').read_bytes(), Path(str(prefix) + '.stderr').read_bytes()


def fetch(url, records, label):
    # HTTPS transport/JSON handling only; this does not verify a signature.
    req = urllib.request.Request(url, headers={'Accept': 'application/vnd.github+json',
                                               'User-Agent': 'forge-stage9'})
    with urllib.request.urlopen(req) as response:
        data = response.read()
        require(response.status == 200, 'GITHUB_HTTP_STATUS')
    (records.directory / (label + '.bytes')).write_bytes(data)
    write(records.directory / (label + '.http.json'), {'url': url, 'http_status': 200, 'sha256': sha(data)})
    return data


def context(expected_lock):
    require(re.fullmatch('[0-9a-f]{64}', expected_lock), 'IMPLEMENTATION_LOCK_DIGEST')
    require(digest(HERE / 'implementation.lock') == expected_lock, 'UNAPPROVED_IMPLEMENTATION')
    implementation = read(HERE / 'implementation.lock')
    require(sys.version_info[:3] == (3, 10, 11), 'PYTHON_VERSION')
    require(not sys.flags.optimize, 'OPTIMIZED_PYTHON_FORBIDDEN')
    for path, expected in implementation['files'].items():
        require(digest(ROOT / path) == expected, 'IMPLEMENTATION_INPUT:' + path)
    policy = read(ROOT / 'policy/provenance.json')
    lock = read(ROOT / 'spec/provenance/spec.lock')
    for key in ('contract', 'policy'):
        require(digest(ROOT / lock[key]['path']) == lock[key]['sha256'], 'CONTRACT_IDENTITY')
    for item in lock['locked_existing_files']:
        require(digest(ROOT / item['path']) == item['sha256'], 'LOCKED_INPUT:' + item['path'])
    return policy, lock, implementation


def clean_environment():
    forbidden = [key for key in os.environ if key.startswith(('COSIGN_', 'SIGSTORE_', 'TUF_'))]
    require(not forbidden, 'TRUST_ENVIRONMENT_OVERRIDE')
    require(not any(os.environ.get(k) for k in ['LD_PRELOAD', 'DYLD_INSERT_LIBRARIES', 'PYTHONPATH',
                                               'SSL_CERT_FILE', 'SSL_CERT_DIR']),
            'CODE_LOADING_OVERRIDE')
    return {key: value for key, value in os.environ.items()
            if key in ['PATH', 'HOME', 'TMPDIR',
                       'GITHUB_ACTIONS', 'ACTIONS_ID_TOKEN_REQUEST_URL', 'ACTIONS_ID_TOKEN_REQUEST_TOKEN']}


def cosign_path(policy):
    key = {'Darwin': 'darwin', 'Linux': 'linux'}[platform.system()] + '-' + {
        'arm64': 'arm64', 'aarch64': 'arm64', 'x86_64': 'amd64'}[platform.machine()]
    require(key in policy['signature']['executable_sha256'], 'COSIGN_PLATFORM')
    path = ROOT / '.toolchain/stage9/cosign'
    require(path.is_file() and digest(path) == policy['signature']['executable_sha256'][key], 'COSIGN_PIN')
    return path


def repository_identity(policy, implementation, commit, records):
    require(re.fullmatch('[0-9a-f]{40}', commit), 'EXPECTED_SOURCE_COMMIT')
    repo = policy['signer']['repository']
    info = parse(fetch('https://api.github.com/repos/' + repo, records, 'repository'))
    require(info['full_name'] == repo and info['id'] == policy['signer']['repository_id']
            and info['owner']['id'] == policy['signer']['owner_id'], 'REPOSITORY_IDENTITY')
    for number, (path, expected) in enumerate(sorted(implementation['files'].items())):
        raw = fetch(f'https://raw.githubusercontent.com/{repo}/{commit}/{path}', records,
                    f'source-{number:03d}')
        require(sha(raw) == expected, 'AUTHENTICATED_WORKFLOW_INPUT:' + path)


def signature(policy, bundle, blob, commit, records, *, negative_identity=None):
    # negative_identity is only used to authenticate the wrong-signer fixture
    # under its OWN fixed identity, never by release admission.
    identity = policy['signer']['identity']
    if negative_identity is not None:
        require(negative_identity == identity.replace('provenance.yml', 'provenance-negative.yml'),
                'TEST_IDENTITY_NOT_FIXED')
        identity = negative_identity
    env = clean_environment()
    binary = cosign_path(policy)
    records.run([binary, 'version', '--json'], 'cosign-version', env=env)
    # An online TUF refresh must succeed before any signature verdict is used.
    records.run([binary, 'initialize'], 'tuf-refresh', env=env)
    cache = Path(env['HOME']) / '.sigstore/root'
    require(cache.is_dir(), 'TUF_ARCHIVE_MISSING')
    import shutil
    shutil.copytree(cache, records.directory / 'validated-tuf')
    write(records.directory / 'tuf-identities.json', files(records.directory / 'validated-tuf'))
    argv = [binary, 'verify-blob-attestation', '--bundle', bundle,
            '--type', policy['signature']['predicate_type'],
            '--certificate-identity', identity,
            '--certificate-oidc-issuer', policy['signer']['issuer'],
            '--certificate-github-workflow-repository', policy['signer']['repository'],
            '--certificate-github-workflow-ref', policy['signer']['ref'],
            '--certificate-github-workflow-trigger', policy['signer']['event'],
            '--certificate-github-workflow-sha', commit, blob]
    return records.run(argv, 'cosign-verify', env=env, check=False)
