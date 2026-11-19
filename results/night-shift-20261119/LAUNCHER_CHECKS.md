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
