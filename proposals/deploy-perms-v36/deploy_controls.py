"""Real-container controls for the deployment observer (observe.observe) on v3.6.

  python3 -I -B deploy_controls.py CODE_ROOT LOCK OUTPUT V36_IMAGE V35_IMAGE SUBSTITUTED_IMAGE

Each case creates a container with the exact flags of observe.py main(), changes
only what the case names, starts it, and lets the checkout's observe() decide.
Every fixture is labelled forge.stage9.role=v36-control and removed afterwards.
Exit 0 when every case gets its expected outcome.
"""
import json
from pathlib import Path
import subprocess
import sys

code, lock, OUT = sys.argv[1], sys.argv[2], Path(sys.argv[3]).resolve()
V36, V35, SUBST = sys.argv[4], sys.argv[5], sys.argv[6]
sys.path.insert(0, code + '/gate/provenance')
import common  # noqa: E402
from common import Records, Rejected, context  # noqa: E402
import observe  # noqa: E402

policy, _, _ = context(lock)
TARGET = policy['deployment']['path']
ELF = Path(code) / policy['release_artifact']['path']
OUT.mkdir(parents=True, exist_ok=False)
exact = OUT / 'exact.elf'
exact.write_bytes(ELF.read_bytes())
exact.chmod(0o444)
wrong = OUT / 'substituted.elf'
wrong.write_bytes(b'Actual Stage 9 deployed substitution control\n')
wrong.chmod(0o444)
BASE = ['docker', 'create', '--platform', 'linux/amd64', '--network', 'none',
        '--read-only', '--user', '1000:1000', '--cap-drop', 'ALL',
        '--security-opt', 'no-new-privileges:true', '--cpuset-cpus', '0',
        '--memory', '256m', '--memory-swap', '256m', '--pids-limit', '64',
        '--label', 'forge.stage9.role=v36-control']


def without(flags, *names):
    out, skip = [], 0
    for i, f in enumerate(flags):
        if skip:
            skip -= 1
            continue
        if f in names:
            skip = 0 if f == '--read-only' else 1
            continue
        out.append(f)
    return out


def replace_user(flags, user):
    i = flags.index('--user')
    return flags[:i + 1] + [user] + flags[i + 2:]


CASES = [
    # name, create flags, image, request package, start?, race?, expected
    ('v3.5 package: UID 1000 cannot read the ELF (original failure)', BASE, V35, V35, True, False,
     'COMMAND_FAILED:observed-elf'),
    ('v3.6 package: accepted, exact ELF read by UID 1000', BASE, V36, V36, True, False, 'ACCEPTED'),
    ('bind mount of substituted bytes over the target', BASE + ['--mount', f'type=bind,source={wrong},target={TARGET},readonly'],
     V36, V36, True, False, 'DEPLOYED_ARTIFACT_MISMATCH'),
    ('bind mount of the exact ELF bytes over the target', BASE + ['--mount', f'type=bind,source={exact},target={TARGET},readonly'],
     V36, V36, True, False, 'DEPLOYMENT_MOUNT_OBSCURES_IDENTITY'),
    ('tmpfs hides /opt/forge (unobserved target)', BASE + ['--tmpfs', '/opt/forge:ro'], V36, V36, True, False,
     'COMMAND_FAILED:observed-elf'),
    ('image with substituted ELF bytes (same Dockerfile)', BASE, SUBST, SUBST, True, False, 'DEPLOYED_ARTIFACT_MISMATCH'),
    ('deployed image differs from the requested package', BASE, V36, V35, True, False, 'DEPLOYED_PACKAGE_MISMATCH'),
    ('network not disabled', without(BASE, '--network'), V36, V36, True, False, 'DEPLOYMENT_ISOLATION'),
    ('root filesystem writable', without(BASE, '--read-only'), V36, V36, True, False, 'DEPLOYMENT_ISOLATION'),
    ('container user is root', replace_user(BASE, '0:0'), V36, V36, True, False, 'DEPLOYMENT_ISOLATION'),
    ('privileged container', BASE + ['--privileged'], V36, V36, True, False, 'DEPLOYMENT_ISOLATION'),
    ('container created but not started', BASE, V36, V36, False, False, 'DEPLOYMENT_NOT_RUNNING'),
    ('container stops between read and after-inspection (race)', BASE, V36, V36, True, True, 'DEPLOYMENT_CHANGED'),
]
results = []
for n, (name, flags, image, requested, start, race, expected) in enumerate(CASES, 1):
    records = Records(OUT / ('case-%02d' % n))
    request = {'artifact_sha256': policy['release_artifact']['sha256'], 'package_sha256': requested.removeprefix('sha256:'),
               'challenge': 'v36-deployment-control-%02d' % n}
    container = subprocess.run(flags + [image], capture_output=True, text=True, check=True).stdout.strip()
    try:
        if start:
            subprocess.run(['docker', 'start', container], capture_output=True, check=True)
        if race:
            real = records.run

            def run(argv, label, **kw):
                result = real(argv, label, **kw)
                if label == 'observed-elf':
                    subprocess.run(['docker', 'stop', container], capture_output=True)
                return result
            records.run = run
        try:
            observation = observe.observe(policy, request, container, records)
            observed = 'ACCEPTED'
        except Rejected as error:
            observation, observed = None, error.reason
        whoami = subprocess.run(['docker', 'exec', '--user', '1000:1000', container, 'id', '-u'],
                                capture_output=True, text=True).stdout.strip() if start and not race else None
    finally:
        subprocess.run(['docker', 'rm', '-f', container], capture_output=True)
    ok = observed == expected and (observed != 'ACCEPTED' or (
        observation['observed_sha256'] == policy['release_artifact']['sha256'] and whoami == '1000'))
    results.append({'case': name, 'image': image, 'requested_package': requested, 'expected': expected,
                    'observed': observed, 'observed_sha256': (observation or {}).get('observed_sha256'),
                    'exec_uid': whoami, 'pass': ok})
    print('PASS' if ok else 'FAIL', '|', name, '| expected', expected, '| observed', observed, flush=True)
(OUT / 'results.json').write_text(json.dumps({'results': results, 'end_to_end': False}, indent=2) + '\n')
bad = [r for r in results if not r['pass']]
print('cases', len(results), 'not passing', len(bad))
sys.exit(1 if bad else 0)
