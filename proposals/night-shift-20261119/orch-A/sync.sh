#!/bin/zsh
# Copy Orchestrator A evidence into the nightshift/A-proof worktree (no commit).
set -e
F=/Users/USER/forge; W=/private/tmp/claude-501/-Users-USER-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/A-proof; D=$W/proposals/night-shift-20261119
mkdir -p $D/orch-A $D/hol-runs
rsync -a --exclude 'results-snapshot-*.json' --exclude 'results-at-driver-end.json' --exclude 'git-*.txt' --exclude 'fs-sml-sha256.txt' \
  --exclude 'refund' --exclude 'refund.S.fromgit' --exclude '*.o' --exclude 'refund-*' --exclude 'harness_*' --exclude 'refund.S' --exclude 'refund.syms' --exclude '*.dylib' --exclude '__pycache__' --exclude 'run/attempt-0001/stored' \
  $F/results/night-shift-20261119/orch-A/ $D/orch-A/
cp $F/results/night-shift-20261119/PROTOCOL.md $F/results/night-shift-20261119/DIRECTIVE.md $D/
[ -f $F/results/night-shift-20261119/OWNER_REQUIRED.md ] && cp $F/results/night-shift-20261119/OWNER_REQUIRED.md $D/ || true
rsync -a --include '*/' --include '*.sml' --include '*.sh' --include '*.py' --include '*.txt' --include '*.json' --include '*.log' \
  --include '*.sig' --include '*.dat' --include '*.start' --exclude '*' $F/results/m1b-routeA-20261119/attempt-0001/ $D/hol-runs/routeA-attempt-0001/
python3 -I - <<'PY'
import json,pathlib
p=pathlib.Path('/Users/USER/forge/results/round4-m1-replay-20261118/phase3/results.json')
r=json.loads(p.read_text())
out={'read_from':str(p),'claim':r['claim'],'end_to_end':False,'case_run_seconds_used':r['case_run_seconds_used'],'events':r['events'],
 'cases':{k:{x:c.get(x) for x in ('index','verdict','recorded_exit','actual_exit','wall_seconds','start_utc','end_utc','child_max_rss_mib')}|({'rerun':{x:c['rerun'].get(x) for x in ('verdict','actual_exit','wall_seconds','start_utc','end_utc','note')}} if c.get('rerun') else {}) for k,c in r['cases'].items()}}
pathlib.Path('/private/tmp/claude-501/-Users-USER-forge/90d187ef-57dc-4fa3-a5b8-7a6708d00cf2/scratchpad/A-proof/proposals/night-shift-20261119/replay-phase3-verdicts.json').write_text(json.dumps(out,indent=1)+'\n')
PY
cd $W && git add -A proposals/night-shift-20261119 && git status --short | wc -l && du -sh proposals/night-shift-20261119
