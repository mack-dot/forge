## L-CHK-01 (2026-11-19T16:47Z) independent launcher re-run: C-ATT-17 and C-ATT-18 fixes
- Fix tree: B commit 88ae6cbf70c5. Control tree: B commit 608b5165 (before the fix).
- Command (cwd = detached worktree of 88ae6cbf, node v24.3.0 /opt/homebrew/bin/node):
  `node --no-warnings --import tsx tests/refund-finality/regress/<T>.ts <TREE> orch-B/h-minter/redteam/c7/shadow/issueonce.cjs`
- | Test | Fix tree exit | Control tree exit |
  |---|---|---|
  | d_att17_lock_theft | 0 PASS | 1 FAIL |
  | d_att17_claim_race | 0 PASS | 1 FAIL (effects r1,r2,r2; total 1200 on 1000) |
  | d_att18_throwing_emit | 0 PASS | 1 FAIL |
- Verdict: tests discriminate; classes C-ATT-17 and C-ATT-18 closed on 88ae6cbf at test level (TESTED-UNPROVED, not a proof).
- Uncertainty: issueonce.cjs path chosen by the launcher (B's shadow copy); C did not state which copy it used.
- L-CHK-01 addendum (16:52Z): C used orch-B/h-minter/build/issueonce.cjs. The launcher's copy (redteam/c7/shadow/issueonce.cjs) has the same SHA-256 (4cf78df8cb0651afcf1f…), so the check used the same issuer module. Uncertainty above is resolved.

## L-CHK-02 (2026-11-19T17:10Z) independent launcher re-run: C-ATT-36 (retry decision + ledger-only restore re-sends)
- Script: B's adapted copy at f67c5c16:results/night-shift-20261119/orch-B/h-sink3/attacks/c19/a1_retry_restore.ts (C states it equals its original except the tree path).
- Env as B's run.sh: env -i, PATH=/opt/homebrew/bin:/usr/bin:/bin, H3_ROOT=<tree>, node v24.3.0, --import tsx, timeout 120.
- | Tree | Issuer | attack | floor | control |
  |---|---|---|---|---|
  | f67c5c16 (fix) | orch-B/h-minter2/build/issueauth.cjs (sha256 1b38b9ab…) | 0 PASS | 0 PASS | 0 PASS |
  | f08a21c1 (before) | orch-B/h-minter/build/issueonce.cjs (sha256 4cf78df8…) | 1 FAIL | 1 FAIL | 0 PASS |
- Setup runs NOT counted: f67c5c16 with issueonce.cjs exit 3 (minter refuses: module lacks IssueAuth); f67c5c16 with h-minter3 issueauth.cjs exit 3 (interface mismatch, dtor_requestId). Issuer choice is the launcher's; the two trees need different issuer builds, so this is not a same-issuer A/B comparison.
- Verdict: C-ATT-36 closed on f67c5c16 at test level (TESTED-UNPROVED).
