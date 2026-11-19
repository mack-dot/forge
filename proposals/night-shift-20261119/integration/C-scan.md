# Scan of Orchestrator C records (origin/nightshift/C-redteam 94a1ebe1)

Scope A: all 1909 files under `results/night-shift-20261119/orch-C` (git grep over the branch blob, binary files included).
Scope B: lines added (`^+`) in `git diff 985f5eaf origin/nightshift/C-redteam -- unsure.md ROADMAP.md README.md`.

| Pattern | Scope A files | Scope B lines |
|---|---|---|
| `/Users/` | 0 | 0 |
| `/home/[a-z]` | 0 | 0 |
| `<TMP>/claude` | 0 | 0 |
| `/var/folders` | 0 | 0 |
| `BEGIN [A-Z ]*PRIVATE KEY` | 0 | 0 |
| `ghp_` / `github_pat_` / `sk-ant-` / `AKIA` | 0 / 0 / 0 / 0 | 0 / 0 / 0 / 0 |
| `password` (case-insensitive) | 0 | 0 |
| `secret` (case-insensitive) | 1: `orch-C/c25-provider/s1_scope.ts` | 1 (`unsure.md` line 18399, U601) |

- Both `secret` hits are prose: s1_scope.ts:6 "(request ids are not secret)"; unsure.md:18399 "assumes the stored state is not secret".
- Host paths in orch-C are replaced by placeholders `<REPO>`, `<SCRATCH>`, `<HOME>`. Consequence: scripts that hold a placeholder do not run verbatim, and their SHA-256 differs from the value in ATTACKS.md (c22 test_process_lifecycle.py, c19 judges/blindspots2.sh, c13 and c5 regress.sh; see retests.tsv). Scripts without a placeholder match their recorded SHA-256 (kf_c_own.ts, d2_two_tokens.ts, l1_lock_theft.ts, a6_dup_reqid.ts, x1_crash_journal.ts, s1_hotjournal.ts, p2_invalid_utf8.ts). STATE.md line 29 records it: "Branch copies have home paths replaced by <REPO>/<SCRATCH>; runnable originals are in the main checkout orch-C/ (untracked)."
- File names `.env*`, `*.pem`, `*.key`, `id_*`, `*.sqlite*`, `*.db`: none under orch-C.
- Other bulk under orch-C: a planted test fixture `c24-minter2/plant/home/.node_modules/bignumber.js/{index.js,package.json}` (the C-ATT-14 shim); extracted source trees `c10-judges/{tree,v6,enc}/` (156 files). `c10-judges/BRANCH_NOTE.txt` says those trees are NOT kept in the branch; they are present (contradiction).

## Base commit fact
- `git merge-base origin/nightshift/C-redteam origin/nightshift/B-trust` = `4af09308` (B's commit; 985f5eaf is its ancestor, 44 commits earlier). C's branch starts at 4af09308, not at 985f5eaf.
- So the diff against 985f5eaf includes B's 44 commits: all 89 ROADMAP.md lines and 438 unsure.md lines (U530 to U567) come from B's chain 985f5eaf..4af09308.
- C's own changes (`git diff 4af09308 origin/nightshift/C-redteam`): unsure.md +186 / -13; ROADMAP.md: no change; README.md: no change.

## README.md
- `git diff 985f5eaf origin/nightshift/C-redteam -- README.md` is EMPTY. C did not change README.md.

## The 13 deleted lines in unsure.md
- Yes: C REWROTE existing entries. This breaks the append-only rule for unsure.md.
- One commit: `4432fe1c` (C wave 1 part 1). Each deleted line is replaced by the same line with the home path redacted. B's branch keeps the original lines (0 deletions vs 985f5eaf).
- Lines (number at 985f5eaf = number on C) and entries:
  - 251 (U019): `/Users/USER/forge/.git` -> `<REPO>/.git`
  - 4180 (U170): `/Users/USER/forge` -> `<REPO>`
  - 4663 (U188): `/Users/USER/forge/.toolchain` -> `<REPO>/.toolchain`
  - 4882 (U198), 4894 (U200): `/Users/USER/forge[/build/]` -> `<REPO>[/build/]`
  - 4953, 4955, 4957 (U203): home path -> `<HOME>`; `/Users/USER/forge-backups/...` -> `<REPO>-backups/...`;
    "sanitized archive (`/Users/USER` -> `$HOME`" became "(`<HOME>` -> `$HOME`" (the recorded fact changed meaning)
  - 7213 (U255), 7269 (U256): `/Users/USER/forge-backups/...bundle` -> `<REPO>-backups/...bundle`
  - 10788 (U324), 10830 (U325), 10865 (U326): `mkdir(/Users/USER,0700)` / `/Users/USER` -> `<HOME>`
- No line C added to unsure.md mentions this rewrite (grep of C's added lines for redact/scrub/placeholder/append-only: no such record). ATTACKS.md and FINAL.md do not mention it either.
