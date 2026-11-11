Replaces draft #31 with contributor publication so the repository owner can independently review the repair and satisfy the last-push approval rule. PR #30 is already merged at `e7b5b52aad5d020224dd057e1019004b15dc8739`.

Exact head: `9a0247e9b36fa9558df3943333fc9b33ce967544`. Tree: `b3cb9c42bae48ef6ce7239dfcccdcb4560e7e186`, identical to the locally tested repair. Five files: three production files and two permanent regression tests. No source change from #31.

The repair accepts cached evidence only when its complete receipt and associated artifacts match the authority held by the same live trusted producer process. Modified receipts, artifact substitution, coordinated rewrites, stale identity, changed harness, prior-process receipts and missing/invalid anchors are refused. New CLI processes perform fresh verification. Cross-run reuse remains disabled.

Actual local validation: 13/13 acceptance cases, wrapper exit 0. Cold, warm and invalidation gate exits 0; observed booking-process launches 1, 0 and 1 respectively. Tampering and authentication negatives exit 1; uncovered change exits 3. Actual separate-process CLI replay exits 0 and reproduces identical evidence after fresh proof. Original unsafe-adoption control is permanently preserved. These are local macOS executions; the hosted matrix is NOT RUN.

Existing hosted PR gate run 41500184981 correctly refused the protected gate changes with exit 1, UNAPPROVED_PROTECTED_CHANGE, and zero proof commands. That refusal is not represented as successful verification. The Linux booking workflow still needs its own review and approval.

No Node integration, workflow changes, signing-policy changes, protection changes, new infrastructure, or Stage 12. `end_to_end=false`. Request independent owner review of this exact head; do not merge without required review and explicit merge authorization. Off-machine backup and complete protection exports remain pending.
