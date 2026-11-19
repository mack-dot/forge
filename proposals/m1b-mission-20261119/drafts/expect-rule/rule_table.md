| submission | ideal | before (present gate, all tiers) | new rule alone | after | rprint scan |
|---|---|---|---|---|---|
| C0-repo-impl | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| C1-table | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| C2-recursion | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| C3-early-returns | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| C4-arith | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| C5-helper-lemmas | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| C6-function-pair | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| C7-loop-plan | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| C8-isolate-attr | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| C9-comment-word-include | ADMITTED | REFUSED | pass | REFUSED | clean |
| C10-induction-attr | ADMITTED | REFUSED | pass | REFUSED | clean |
| C11-at-in-string | ADMITTED | REFUSED | pass | REFUSED | clean |
| C12-crlf-header | ADMITTED | REFUSED | pass | REFUSED | clean |
| A01-wrong-amount-one-input | REFUSED | REFUSED | pass | REFUSED | clean |
| A02-assume-false | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A03-axiom-lemma | REFUSED | REFUSED | pass | REFUSED | clean |
| A04-verify-false | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A05-extern-body | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A06-bodiless-function | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A07-bodiless-lemma-concrete | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A08-abstract-trap-toplevel-call | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A09-abstract-trap-nested-call | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A10-abstract-trap-import | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A11-abstract-trap-dead | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| A12-redefine-eligible | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A13-shadow-spec-nested | REFUSED | REFUSED | pass | REFUSED | clean |
| A14-include-altered-spec | REFUSED | REFUSED | pass | REFUSED | resolve exit 1 |
| A15-second-include-hatch | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A16-decreases-star | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A17-print-effect | REFUSED | REFUSED | pass | REFUSED | clean |
| A18-runtime-exhaustion | REFUSED | NO-VERDICT | pass | NO-VERDICT | clean |
| A19-verifier-exhaustion | REFUSED | REFUSED | pass | REFUSED | clean |
| A20-unicode-module | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A21-unicode-predicate | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A22-requires-false-assess | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A23-requires-false-helper | REFUSED | REFUSED | pass | REFUSED | clean |
| A24-expect-halt-one-input | REFUSED | REFUSED | REFUSE | REFUSED | expect x1 |
| A25-expect-as-assume-wrong-value | REFUSED | REFUSED | REFUSE | REFUSED | expect x1 |
| A26-forall-no-body | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A27-while-no-body | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A28-space-attribute | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A29-by-method-mismatch | REFUSED | REFUSED | pass | REFUSED | clean |
| A30-dfyconfig-cwd | REFUSED | REFUSED | pass | REFUSED | clean |
| A31-dfyconfig-impl-dir | REFUSED | REFUSED | pass | REFUSED | clean |
| A32-dead-main-decreases-star | REFUSED | REFUSED | pass | REFUSED | clean |
| A33-const-alloc-exhaustion | REFUSED | REFUSED | pass | REFUSED | clean |
| A34-nested-comment-hide | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| A35-assume-in-ghost-helper | REFUSED | REFUSED | pass | REFUSED | resolve exit 2 |
| A36-reveal-opaque-escape | REFUSED | REFUSED | pass | REFUSED | clean |
| A37-uncompilable-such-that | REFUSED | ADMITTED | pass | ADMITTED | clean |
| A38-expect-always-halt | REFUSED | REFUSED | REFUSE | REFUSED | expect x1 |
| A39-expect-in-helper-method | REFUSED | REFUSED | REFUSE | REFUSED | expect x1 |
| A38n-control-without-expect | REFUSED | REFUSED | pass | REFUSED | clean |
| Z24-expect-halt-amount-61 | REFUSED | ADMITTED | REFUSE | REFUSED | expect x1 |
| Z24-expect-halt-amount-1000 | REFUSED | ADMITTED | REFUSE | REFUSED | expect x1 |
| Z24-expect-halt-amount-123456789 | REFUSED | ADMITTED | REFUSE | REFUSED | expect x1 |
| Z24-expect-halt-amount-9223372036854775805 | REFUSED | ADMITTED | REFUSE | REFUSED | expect x1 |
| E01-colon-dash-expect | REFUSED | ADMITTED | REFUSE | REFUSED | expect x1 |
| E02-array-oob | REFUSED | REFUSED | pass | REFUSED | clean |
| E03-div-zero | REFUSED | REFUSED | pass | REFUSED | clean |
| E04-assert-by | REFUSED | REFUSED | pass | REFUSED | clean |
| E05-test-attr | REFUSED | REFUSED | REFUSE | REFUSED | expect x1 |
| E06-stack-overflow-keyed | REFUSED | ADMITTED | pass | ADMITTED | clean |
| E07-oom-keyed | REFUSED | ADMITTED | pass | ADMITTED | clean |
| E08-time-keyed | REFUSED | ADMITTED | pass | ADMITTED | clean |
| E12-expect-in-by-method | REFUSED | ADMITTED | REFUSE | REFUSED | expect x1 |
| C13-comment-expect | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| C14-string-char-expect | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| C15-ident-expected | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| N1a-nested-comment-closed | ADMITTED | ADMITTED | pass | ADMITTED | clean |
| N1b-nested-comment-reopen | REFUSED | REFUSED | REFUSE | REFUSED | resolve exit 2 |
| S1-cr-ends-line-comment | REFUSED | REFUSED | REFUSE | REFUSED | expect x1 |
| S2-cr-comment-hides-keyed-expect | REFUSED | ADMITTED | REFUSE | REFUSED | expect x1 |
| S3-u2028-in-line-comment | REFUSED | REFUSED | REFUSE | REFUSED | clean |
| S4-formfeed-in-line-comment | REFUSED | REFUSED | REFUSE | REFUSED | clean |
