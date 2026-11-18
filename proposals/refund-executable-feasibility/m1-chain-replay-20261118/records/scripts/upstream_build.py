"""Build ONE missing object of the pinned HOL or CakeML tree, under the coordinator's five conditions.

Usage: python3 -I -B upstream_build.py <label> <cwd relative to the tool tree> <Holmake target> [note]

Order: (1) `Holmake -n` dry run, recorded; (2) dryrun_check.py: stop if a planned output already
exists; (3) the real `nice -n 15 Holmake --no-cache -j1 <target>` under caffeinate, recorded, with a
watch that stops the command if a theory outside the plan appears in the log.
This is a tool build of missing objects. It is not a proof of a Forge theory.
"""
from pathlib import Path
import json, os, subprocess, sys

sys.path.insert(0, str(Path(__file__).resolve().parent))
import runcmd

OUT = Path(__file__).resolve().parent.parent
TC = Path('<HOME>/forge/.toolchain/experiments/refund-cakeml-20261104')
label, cwd, target = sys.argv[1], TC / sys.argv[2], sys.argv[3]
note = sys.argv[4] if len(sys.argv) > 4 else ''
env = {'HOLDIR': str(TC / 'HOL'), 'CAKEMLDIR': str(TC / 'cakeml'),
       'PATH': str(TC / 'poly-install/bin') + os.pathsep + os.environ['PATH']}
(OUT / 'upstream').mkdir(exist_ok=True)
base = ['nice', '-n', '15', str(TC / 'HOL/bin/Holmake'), '--no-cache', '-j1']
dry = runcmd.run(label + '-dryrun', base + ['-n', target], cwd, env_extra=env, kind='upstream-build-dry-run',
                 note='Dry run (-n) before the upstream build. ' + note)
if dry.get('actual_exit') != 0:
    print('DRY RUN FAILED', dry.get('status'), dry.get('actual_exit'))
    raise SystemExit(2)
check_json = OUT / 'upstream' / (label + '-dryrun-check.json')
forbid = OUT / 'upstream' / (label + '-forbid.txt')
chk = subprocess.run([sys.executable, '-I', '-B', str(OUT / 'scripts/dryrun_check.py'), dry['log'], str(check_json), str(forbid)],
                     capture_output=True, text=True)
print(chk.stdout)
runcmd.update_last({'dry_run_check': json.loads(check_json.read_text()) if check_json.exists() else None,
                    'dry_run_check_exit': chk.returncode})
if chk.returncode != 0:
    print('STOP: the dry run plans to make a file that already exists. Nothing was built.')
    raise SystemExit(3)
plan = json.loads(check_json.read_text())
if not plan['planned_files']:
    print('NOTHING TO BUILD: target is up to date according to Holmake')
    raise SystemExit(0)
real = runcmd.run(label, base + [target], cwd, env_extra=env, kind='upstream-build',
                  note='Tool build of missing objects, allowed by the coordinator: -j1, nice, new files only. ' + note,
                  forbid=[l for l in forbid.read_text().splitlines() if l.strip()],
                  extra={'planned_theories': plan['planned_theories'], 'planned_other_objects': plan['planned_other_objects']})
print(json.dumps({k: real.get(k) for k in ('label', 'status', 'actual_exit', 'wall_seconds', 'sleep_gap_seconds', 'watch_line')}))
raise SystemExit(real.get('actual_exit') if isinstance(real.get('actual_exit'), int) and real.get('actual_exit') >= 0 else 1)
