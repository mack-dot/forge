"""Run the real PR gate on the final branch commits of version 3 (Round 4 closeout). Dispatch only; the gate decides.

Each case: a fresh clone at the trusted commit (with the untracked local tool links .toolchain and node_modules), a
fresh clone at the candidate commit, then from the trusted clone:
    python3 gate/incremental.py --profile local --candidate <clone> --evidence build/case-evidence.json --work build/case
This is the command of gate/pr_check.py with the local profile. The hosted wrapper and the linux profile are NOT run
here. Exit classes of main's gate: 0 VERIFIED, 1 REJECTED, 2 NOT_ESTABLISHED, 3 UNSUPPORTED.
No expected code is stored as a result: "expected" is printed beside the actual exit code.
Usage: python3 -B run_bootstrap_gate_cases.py <label> <name>=<trusted-commit>:<candidate-commit>:<expected-exit> ...
"""
from pathlib import Path
import json, shutil, subprocess, sys

FORGE = Path(__file__).resolve().parents[2]
label, cases = sys.argv[1], sys.argv[2:]
out = FORGE / 'results/round4-closeout-20261117/bootstrap-gate' / label
out.mkdir(parents=True, exist_ok=False)
git = lambda cwd, *a: subprocess.run(['git', '-C', str(cwd), *a], capture_output=True, text=True, check=True).stdout
summary = {'label': label, 'gate': "gate/incremental.py --profile local, run from a clone of the trusted commit",
           'wrapper_gate_pr_check_py': 'NOT RUN', 'profile_linux': 'NOT RUN', 'end_to_end': False, 'cases': []}
failed = False
for index, case in enumerate(cases):
    name, spec = case.split('=', 1)
    trusted_commit, candidate_commit, expected = spec.split(':')
    trusted, candidate = out / ('trusted-%02d' % index), out / ('candidate-%02d' % index)
    for path, commit in ((trusted, trusted_commit), (candidate, candidate_commit)):
        subprocess.run(['git', 'clone', '-q', '--no-checkout', str(FORGE), str(path)], check=True, capture_output=True)
        git(path, 'checkout', '-q', '--detach', commit)
    for local_only in ('.toolchain', 'node_modules'):
        (trusted / local_only).symlink_to(FORGE / local_only, target_is_directory=True)
    run = subprocess.run([sys.executable, 'gate/incremental.py', '--profile', 'local', '--candidate', str(candidate),
                          '--evidence', 'build/case-evidence.json', '--work', 'build/case'], cwd=trusted, capture_output=True, text=True)
    text = (run.stdout + run.stderr).replace(str(Path.home()), '<HOME>')
    (out / ('case-%02d.log' % index)).write_text(text)
    lines = [line for line in text.strip().splitlines() if line.strip()]
    operation = json.loads((trusted / 'build/case/operation.json').read_text()) if (trusted / 'build/case/operation.json').is_file() else {}
    replay = None
    if run.returncode == 0 and (trusted / 'build/case-evidence.json').is_file():      # what gate/pr_check.py does next
        bundle = json.loads((trusted / 'build/case-evidence.json').read_text())
        again = subprocess.run(bundle['evidence'][0]['reproduce_cmd'].split(), cwd=trusted, capture_output=True, text=True)
        replay = {'exit': again.returncode, 'byte_identical': again.returncode == 0 and
                  (trusted / 'build/change-evidence.json').read_bytes() == (trusted / 'build/case-evidence.json').read_bytes()}
    ok = run.returncode == int(expected) and (replay is None or replay['byte_identical'])
    failed = failed or not ok
    summary['cases'].append({
        'name': name, 'trusted_commit': git(trusted, 'rev-parse', 'HEAD').strip(), 'candidate_commit': git(candidate, 'rev-parse', 'HEAD').strip(),
        'gate_exit': run.returncode, 'expected_gate_exit': int(expected), 'outcome': operation.get('outcome'),
        'gate_last_line': (lines[-1] if lines else '')[:600].replace(str(out), '<OUT>'),
        'ratification_controls': [(c['path'], c['kind'], c['exit_code']) for c in operation.get('ratification_controls', [])],
        'gate_ratification_record': (operation.get('gate_ratification') or {}).get('record'),
        'obligations': {key: value.get('result') for key, value in (operation.get('obligations') or {}).items()},
        'coverage_findings': (operation.get('coverage') or {}).get('findings'),
        'replay_of_saved_command': replay, 'matches_expectation': ok})
    shutil.rmtree(trusted)
    shutil.rmtree(candidate)
    print('%02d gate exit %d (expected %s) %s | %s | %s' % (index, run.returncode, expected, 'AS EXPECTED' if ok else 'DIFFERENT', name,
                                                            (lines[-1] if lines else '')[:160]), flush=True)
summary['scenario_exit'] = 1 if failed else 0
(out / 'summary.json').write_text(json.dumps(summary, indent=1, sort_keys=True) + '\n')
print(json.dumps({'label': label, 'scenario_exit': summary['scenario_exit']}))
raise SystemExit(summary['scenario_exit'])
