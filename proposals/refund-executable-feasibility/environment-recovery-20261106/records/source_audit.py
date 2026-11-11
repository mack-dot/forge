"""Read-only source identity audit. This does not run a verifier or solver."""
from pathlib import Path
import hashlib
import json
import subprocess

ROOT = Path('/Users/mackianni/forge')
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
OUT = Path(__file__).resolve().parent
OLD = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0011'
PINS = {
    'HOL': '9783a49979c94c401ff8c0e51b2eefae7ea95ae3',
    'polyml': '4557554077078decce4ce5f90da00a713cfc32e4',
}
SOURCES = {
    'HOL': [
        'src/HolSat/minisatProve.sml', 'src/HolSat/satConfig.sml',
        'src/HolSat/dimacsTools.sml', 'src/HolSat/satTools.sml',
        'src/HolSat/SatSolvers.sml', 'tools-poly/Holmake/unix-systeml.sml',
    ],
    'polyml': [
        'basis/OS.sml', 'basis/PolyMLException.sml',
        'libpolyml/basicio.cpp', 'libpolyml/process_env.cpp',
        'libpolyml/run_time.cpp', 'libpolyml/run_time.h',
    ],
}

def digest(data):
    return hashlib.sha256(data).hexdigest()

def sha(path):
    return digest(Path(path).read_bytes())

commands = []
def git(repo, *args):
    argv = ['git', '-C', str(TC / repo), *args]
    proc = subprocess.run(argv, capture_output=True)
    commands.append({'argv': argv, 'actual_exit': proc.returncode,
                     'stdout_sha256': digest(proc.stdout),
                     'stderr': proc.stderr.decode()})
    assert proc.returncode == 0, argv
    return proc.stdout

files = {}
for repo, paths in SOURCES.items():
    assert git(repo, 'rev-parse', 'HEAD').decode().strip() == PINS[repo]
    for rel in paths:
        data = (TC / repo / rel).read_bytes()
        assert data == git(repo, 'show', PINS[repo] + ':' + rel), (repo, rel)
        dest = OUT / 'sources' / repo / rel
        dest.parent.mkdir(parents=True, exist_ok=True)
        with dest.open('xb') as handle:
            handle.write(data)
        files[repo + '/' + rel] = sha(dest)

retained = {}
for name in ['proof.sml', 'preload.sml', 'command.json', 'invocation.json',
             'stdout.log', 'stderr.log']:
    data = (OLD / 'dependency-diagnostic' / name).read_bytes()
    dest = OUT / 'historical-diagnostic' / name
    dest.parent.mkdir(parents=True, exist_ok=True)
    with dest.open('xb') as handle:
        handle.write(data)
    retained[name] = sha(dest)
assert retained['proof.sml'] == 'bc3fb212a4037ae8e8ebd500f9843bff9cd93cbfcbc76501c7a152a9004af108'
old_result = json.loads((OLD / 'dependency-diagnostic/command.json').read_text())
assert old_result['actual_exit'] == 1 and not old_result['completion_marker']
assert 'SysErr ("Operation not permitted", SOME EPERM)' in (OLD / 'dependency-diagnostic/stdout.log').read_text()

# Check only the relevant existing launcher and heap identities. No full-chain replay.
baseline = json.loads((OLD / 'baseline.json').read_text())
arm8 = json.loads((OLD / 'arm8-tool-inputs.json').read_text())
tool_files = {}
for path, expected in {**baseline['step_tools'], **arm8['files']}.items():
    assert sha(path) == expected, path
    tool_files[path] = expected
protection = json.loads((OLD.parent / 'attempt-0001/baseline.json').read_text())
for rel, expected in protection['protected'].items():
    assert sha(ROOT / rel) == expected, rel
assert sha(ROOT / 'FORGE_MISSION.md') == protection['mission_sha256']

result = {
    'scope': 'Local source identity and retained diagnostic readback only.',
    'pins': PINS, 'sources': files, 'source_git_commands': commands,
    'historical_diagnostic_files': retained, 'historical_diagnostic_exit': 1,
    'relevant_tool_files': tool_files,
    'protected_files_unchanged': len(protection['protected']),
    'new_verifier_solver_or_native_execution': 'NOT_RUN',
    'denied_operation': 'NOT_ESTABLISHED',
    'exception_location_from_failed_run': 'NOT_RECORDED',
    'authorized_replacement_environment': 'NOT_ESTABLISHED',
    'independent_full_chain_replay': 'NOT_RUN',
    'goal_status': 'blocked', 'end_to_end': False,
}
with (OUT / 'source-audit.json').open('x') as handle:
    json.dump(result, handle, indent=2)
    handle.write('\n')
print(json.dumps({'source_files_matching_pins': len(files),
                  'retained_diagnostic_files': len(retained),
                  'protected_files_unchanged': len(protection['protected']),
                  'denied_operation': 'NOT_ESTABLISHED', 'end_to_end': False}))
