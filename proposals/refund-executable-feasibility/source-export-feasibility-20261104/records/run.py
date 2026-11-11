"""Record existing tool invocations. This does not check program semantics."""
from pathlib import Path
import hashlib
import json
import os
import resource
import subprocess
import sys
import time

ROOT = Path('/Users/mackianni/forge')
RAW = Path(__file__).resolve().parent
TC = ROOT / '.toolchain/experiments/refund-dafny-frontend-20261104'
SRC = TC / 'dafny'
PIN = '6eb1ed63544a2e22c151db9b575f4308b8f329b0'
ENV = dict(os.environ, DOTNET_ROOT=str(TC / 'sdk'),
           DOTNET_CLI_HOME=str(TC / 'cli-home'),
           NUGET_PACKAGES=str(TC / 'nuget-packages'),
           DOTNET_CLI_TELEMETRY_OPTOUT='1', DOTNET_NOLOGO='1',
           DOTNET_SKIP_FIRST_TIME_EXPERIENCE='1', DOTNET_MULTILEVEL_LOOKUP='0')
ENV['PATH'] = str(TC / 'sdk') + os.pathsep + ENV['PATH']

def limits():
    resource.setrlimit(resource.RLIMIT_CPU, (7200, 7200))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))

def run(label, argv, cwd=TC):
    folder = RAW / label
    folder.mkdir(exist_ok=False)
    argv = [str(x) for x in argv]
    (folder / 'command.json').write_text(json.dumps({
        'argv': argv, 'cwd': str(cwd),
        'environment_overrides': {k: ENV[k] for k in ENV if k.startswith('DOTNET_') or k == 'NUGET_PACKAGES'},
        'cpu_limit_seconds_per_process': 7200,
    }, indent=2) + '\n')
    start = time.monotonic()
    with (folder / 'stdout.log').open('wb') as out, (folder / 'stderr.log').open('wb') as err:
        p = subprocess.run(argv, cwd=cwd, env=ENV, stdout=out, stderr=err, preexec_fn=limits)
    result = {'actual_exit': p.returncode, 'wall_seconds': time.monotonic() - start}
    (folder / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
    print(label, json.dumps(result), flush=True)
    if p.returncode:
        raise SystemExit(p.returncode)

action = sys.argv[1]
if action == 'source':
    run('git-init', ['git', 'init', SRC])
    run('git-fetch', ['git', 'fetch', '--depth=1', 'https://github.com/dnezam/dafny.git', PIN], SRC)
    run('git-checkout', ['git', 'checkout', '--detach', 'FETCH_HEAD'], SRC)
    run('git-identity', ['git', 'rev-parse', 'HEAD', 'HEAD^{tree}'], SRC)
    run('git-integrity', ['git', 'fsck', '--full', '--strict'], SRC)
    assert (RAW / 'git-identity/stdout.log').read_text().splitlines()[0] == PIN
elif action == 'sdk':
    metadata = RAW / 'dotnet-releases.json'
    run('sdk-metadata', ['curl', '--fail', '--location', '--silent', '--show-error',
                        'https://builds.dotnet.microsoft.com/dotnet/release-metadata/8.0/releases.json', '-o', metadata])
    info = json.loads(metadata.read_text())
    matches = [s for r in info['releases'] for s in r.get('sdks', []) if s['version'] == '8.0.111']
    assert len(matches) == 1
    files = [f for f in matches[0]['files'] if f['rid'] == 'osx-arm64' and f['name'].endswith('.tar.gz')]
    assert len(files) == 1
    selected = files[0]
    assert selected['url'].startswith('https://builds.dotnet.microsoft.com/')
    archive = TC / 'dotnet-sdk-8.0.111-osx-arm64.tar.gz'
    run('sdk-download', ['curl', '--fail', '--location', '--silent', '--show-error', selected['url'], '-o', archive])
    actual = hashlib.sha512(archive.read_bytes()).hexdigest()
    assert actual.lower() == selected['hash'].lower()
    (RAW / 'sdk-identity.json').write_text(json.dumps({
        'source_metadata_sha256': hashlib.sha256(metadata.read_bytes()).hexdigest(),
        'selected_release': selected, 'actual_sha512': actual,
        'trust_boundary': 'HTTPS vendor release metadata; not a signature or proof of tool correctness',
    }, indent=2) + '\n')
    (TC / 'sdk').mkdir(exist_ok=False)
    run('sdk-extract', ['tar', '-xzf', archive, '-C', TC / 'sdk'])
    run('sdk-info', [TC / 'sdk/dotnet', '--info'])
elif action == 'build':
    run('frontend-build', [TC / 'sdk/dotnet', 'build', 'Source/DafnyDriver/DafnyDriver.csproj',
                          '--configuration', 'Release', '--no-self-contained', '-m:2',
                          '-p:RestorePackagesWithLockFile=true'], SRC)
elif action == 'export':
    run('frontend-version', [TC / 'sdk/dotnet', SRC / 'Binaries/net8.0/DafnyDriver.dll', '--version'], SRC)
    run('source-export', [TC / 'sdk/dotnet', SRC / 'Binaries/net8.0/DafnyDriver.dll', 'bake',
                         RAW / 'FlatCore.sexp',
                         ROOT / 'proposals/refund-executable-feasibility/unicode-20261104/transport/FlatCore.dfy'], SRC)
elif action == 'export-with-solver':
    run('source-export-0002', [TC / 'sdk/dotnet', SRC / 'Binaries/net8.0/DafnyDriver.dll', 'bake',
                             RAW / 'FlatCore.sexp',
                             ROOT / 'proposals/refund-executable-feasibility/unicode-20261104/transport/FlatCore.dfy',
                             '--solver-path', ROOT / '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1'], SRC)
elif action == 'export-with-path':
    solver = ROOT / '.toolchain/dafny-4.11.0/dafny/z3/bin/z3-4.12.1'
    (TC / 'solver-bin').mkdir(exist_ok=False)
    (TC / 'solver-bin/z3').symlink_to(solver)
    ENV['PATH'] = str(TC / 'solver-bin') + os.pathsep + ENV['PATH']
    (RAW / 'solver-identity.json').write_text(json.dumps({
        'path': str(solver), 'sha256': hashlib.sha256(solver.read_bytes()).hexdigest(),
        'local_symlink': str(TC / 'solver-bin/z3'),
    }, indent=2) + '\n')
    run('solver-version', [solver, '--version'])
    run('source-export-0003', [TC / 'sdk/dotnet', SRC / 'Binaries/net8.0/DafnyDriver.dll', 'bake',
                             RAW / 'FlatCore.sexp',
                             ROOT / 'proposals/refund-executable-feasibility/unicode-20261104/transport/FlatCore.dfy'], SRC)
elif action in ('example', 'module-control', 'source-repeat', 'module-free-diagnostic'):
    ENV['PATH'] = str(TC / 'solver-bin') + os.pathsep + ENV['PATH']
    example = ROOT / '.toolchain/experiments/refund-cakeml-20261104/cakeml/compiler/dafny/examples/plus_one.dfy'
    if action == 'example':
        source, output = example, RAW / 'upstream-plus-one.sexp'
    elif action == 'module-control':
        source, output = RAW / 'named-module-control.dfy', RAW / 'named-module-control.sexp'
        source.write_bytes(b'module NamedControl {\n' + example.read_bytes() + b'\n}\n')
    elif action == 'module-free-diagnostic':
        original = ROOT / 'proposals/refund-executable-feasibility/unicode-20261104/transport/FlatCore.dfy'
        data = original.read_bytes()
        prefix = b'// Local feasibility implementation. No approved source or policy is replaced.\nmodule FlatRefund {\n'
        suffix = b'}\n'
        assert data.startswith(prefix) and data.endswith(suffix)
        source, output = RAW / 'module-free-diagnostic.dfy', RAW / 'module-free-diagnostic.sexp'
        source.write_bytes(data[len(prefix):-len(suffix)])
        (RAW / 'module-free-diagnostic.json').write_text(json.dumps({
            'scope': 'Unsupported-feature diagnostic only. Not the original source, not an accepted adapter, and no equivalence claim.',
            'original_sha256': hashlib.sha256(data).hexdigest(),
            'diagnostic_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
            'removed_prefix': prefix.decode(), 'removed_suffix': suffix.decode(),
            'method_and_all_contracts_byte_preserved': True,
        }, indent=2) + '\n')
    else:
        source = ROOT / 'proposals/refund-executable-feasibility/unicode-20261104/transport/FlatCore.dfy'
        output = RAW / 'FlatCore-repeat.sexp'
    run(action, [TC / 'sdk/dotnet', SRC / 'Binaries/net8.0/DafnyDriver.dll', 'bake', output, source], SRC)
else:
    raise SystemExit('Unknown action')
