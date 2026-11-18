"""Build the documents branch for main: queue items Q2, Q3, Q4 of the bootstrap checklist. Dispatch only; no verdict.

Q2  the result packets and round plans that FORGE_MASTER_IDEA.md links to, and that file itself, from the backup commit.
Q3  main's ROADMAP.md with three small changes (CURRENT line, status note plus the Round 4 section, one table row),
    and unsure.md in full from the backup commit (main's file must be a byte prefix of it).
Q4  the path-free Stage 11 records: every file must have the SHA-256 of the owner's sanitized manifest of 2026-11-01
    and must not hold the home path.
Nothing is pushed. The branch docs/master-idea-records is made new in a scratch worktree on the given base commit.
Usage: python3 -I -B build_docs_branch.py <base-commit-of-main> <backup-commit> <stage11-records-folder> <scratch-worktree>
"""
from pathlib import Path
import hashlib, json, os, shutil, subprocess, sys

FORGE = Path(__file__).resolve().parents[2]
base, backup, records, work = sys.argv[1], sys.argv[2], Path(sys.argv[3]).resolve(), Path(sys.argv[4]).resolve()
BRANCH = 'docs/master-idea-records'
Q2 = ['FORGE_MASTER_IDEA.md', 'FORGE_ROUND2_PLAN.md', 'FORGE_ROUND3_PLAN.md',
      'proposals/forge2-pillar1-anchor-diff', 'proposals/forge2-pillar1-print-effects', 'proposals/forge2-pillar1-spec-determinism',
      'proposals/forge2-pillar2-finality-protocol', 'proposals/forge2-pillar2-refund-finality', 'proposals/forge2-pillar3-dual-certificate',
      'proposals/round2-20261117', 'proposals/round3-20261117', 'proposals/round4-20261117']
Q4 = ['results/stage11/eval-0007', 'results/stage11/eval-pr27-0003']
MANIFEST = Path.home() / 'forge-backups/forge-records-sanitized-2026-11-01.manifest.json'
git = lambda cwd, *a: subprocess.run(['git', '-C', str(cwd), *a], capture_output=True, check=True).stdout
sha = lambda data: hashlib.sha256(data).hexdigest()
short = lambda commit: git(FORGE, 'rev-parse', '--short=8', commit).decode().strip()
base, backup = (git(FORGE, 'rev-parse', '--verify', name + '^{commit}').decode().strip() for name in (base, backup))   # names are resolved in the main tree
assert work != FORGE and not work.exists(), 'the scratch worktree must be a new folder'
subprocess.run(['git', '-C', str(FORGE), 'branch', '-D', BRANCH], capture_output=True)
git(FORGE, 'worktree', 'add', '-q', '-b', BRANCH, str(work), base)

# Q2
git(work, 'checkout', '-q', backup, '--', *Q2)

# Q3: unsure.md in full; main's file must be a byte prefix, so no entry of main is changed.
old_unsure, new_unsure = git(FORGE, 'show', base + ':unsure.md'), git(FORGE, 'show', backup + ':unsure.md')
assert new_unsure.startswith(old_unsure), "main's unsure.md is not a byte prefix of the backup's file"
(work / 'unsure.md').write_bytes(new_unsure)

# Q3: ROADMAP.md of main, three changes.
roadmap = git(FORGE, 'show', base + ':ROADMAP.md').decode()
full = git(FORGE, 'show', backup + ':ROADMAP.md').decode()
start = full.index('## Round 4 closeout')
section = full[start:full.index('\n## ', start + 1)].rstrip() + '\n'
HEAD_OLD = '**CURRENT: Stage 9 — PROVENANCE**\n'
ROW_OLD = '| 9 | PROVENANCE | CURRENT |\n'
assert roadmap.count(HEAD_OLD) == 1 and roadmap.count(ROW_OLD) == 1
NOTE = '''**CURRENT: none (Stage 9 deferred)**

Status note of 2026-11-18 (owner decision; `unsure.md` U437 to U442). No
stage is CURRENT. The full record lists Stages 9, 10 and 11 as DONE. For
Stage 9 the renewal of its lock is deferred: it needs a hosted signing
run that is not authorized, and two entries of
`gate/provenance/implementation.lock` (`gate/approval.py`,
`gate/incremental.py`) do not match `main` since pull request 39. Stage
12 is unauthorized. `end_to_end=false`. The eight modules of the PR gate
are frozen: protected paths change only by an exact-diff proposal and
the owner's merge.

Below the Round 4 section, this file is the record as it stood during
Stage 9. It is not updated; its words "Stage 9 is CURRENT" describe
that time. The full record after it (Stages 10 and 11, the M1 work,
Rounds 2 to 4) is `ROADMAP.md` on branch `backup/forge-local-2026-11-11`
(commit `@BACKUP@` when this note was written). It is not copied here,
because 160 of its links have no target on `main`. The uncertainty
entries of that work are in `unsure.md` here. The work direction is
`FORGE_MASTER_IDEA.md`; it approves nothing.

'''.replace('@BACKUP@', short(backup))
roadmap = roadmap.replace(HEAD_OLD, NOTE + section)
roadmap = roadmap.replace(ROW_OLD, '| 9 | PROVENANCE | DONE in the full record; lock renewal DEFERRED (status note at the top) |\n')
(work / 'ROADMAP.md').write_text(roadmap)

# Q4: path-free Stage 11 records, checked against the owner's sanitized manifest.
manifest = json.loads(MANIFEST.read_text())
home = str(Path.home()).encode()
count = 0
for folder in Q4:
    for source in sorted((records / folder).rglob('*')):
        if source.is_file():
            relative = source.relative_to(records).as_posix()
            data = source.read_bytes()
            entry = manifest[relative]
            assert sha(data) == (entry.get('sha256') if isinstance(entry, dict) else entry), 'digest differs from the sanitized manifest: ' + relative
            assert home not in data, 'home path in ' + relative
            target = work / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
            count += 1
assert count == sum(1 for name in manifest if name.startswith(tuple(f + '/' for f in Q4))), 'record count differs from the manifest'

git(work, 'add', '-A', '--', *Q2, 'unsure.md', 'ROADMAP.md', *Q4)
message = '''Documents and records for main: master idea records and round plans, roadmap status, unsure log, path-free Stage 11 records (NOT merged)

Queue items Q2, Q3 and Q4 of proposals/forge2-pillar1-print-effects/v3/BOOTSTRAP_CHECKLIST.md.
Made by proposals/round4-20261117/build_docs_branch.py from backup/forge-local-2026-11-11 at %s on main at %s.
Q2: result packets and round plans that FORGE_MASTER_IDEA.md links to; its note about missing records is gone.
Q3: ROADMAP.md: CURRENT line, status note, Round 4 closeout section, one table row; unsure.md brought forward in full.
Q4: results/stage11/eval-0007 and eval-pr27-0003, %d files, each with the SHA-256 of the sanitized manifest of 2026-11-01.
No protected path changes. Nothing here is an approval. end_to_end=false.

Co-Authored-By: Claude Fable 5.2 <noreply@anthropic.com>''' % (short(backup), short(base), count)
identity = ['-c', 'user.name=' + git(FORGE, 'config', 'user.name').decode().strip(), '-c', 'user.email=' + git(FORGE, 'config', 'user.email').decode().strip()]
subprocess.run(['git', '-C', str(work), *identity, 'commit', '-q', '-m', message], check=True)
status = git(work, 'diff', '--name-status', base, 'HEAD').decode().splitlines()
kinds = {}
for line in status:
    kinds[line.split('\t')[0]] = kinds.get(line.split('\t')[0], 0) + 1
print(json.dumps({'branch': BRANCH, 'commit': git(work, 'rev-parse', 'HEAD').decode().strip(), 'base': short(base), 'backup': short(backup),
                  'files_by_change': kinds, 'modified': [l.split('\t')[1] for l in status if l.startswith('M')],
                  'stage11_record_files': count, 'unsure_bytes_added': len(new_unsure) - len(old_unsure)}, indent=1, sort_keys=True))
