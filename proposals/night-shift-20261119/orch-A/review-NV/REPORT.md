# Review of NV-0003 (condensed by A, 2026-11-19T16:29:05Z); verdict HOLDS WITH LIMITS; full text `nonvacuity2/review_NV-0003.txt`
Machine-checked: for every request, the 12-conjunct antecedent of `refund_profile_a_sl_shape` (= the antecedent of
`refund_model_frame_decision_shape`) holds jointly at one constructed state, with the ABSTRACT environment (identity
interference, ideal FFI `refund_abs_ffi`). MODEL-only witness. Run record, digests, harness: in order.
Limits: NV2 is weak (request existential; the outcome is not fixed to Success; nothing shows that a frame is written);
the valid-call predicate is never exercised (the witness works for any predicate); no stored witness for MT-0001 MT1
(implied, not stored) and none for MG-0001 (R6 unwitnessed and open). One control is true by construction.
The red team's note "a joint non-vacuity witness is missing" is closed for L2d and the decision-shape theorem only.
NOT shown: anything about the real machine; a run that ends in Terminate Success with a strict frame.
