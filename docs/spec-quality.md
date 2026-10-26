# Spec-quality results

These results concern the approved fee spec `2ad0742dcbf81bf24f9235ed88f9728c7b078dfa6ed55632a90b6aa847b35940`.
They measure this fixture set. They do not establish complete intent coverage.

## Successful-execution witness

From balances {0:0,1:11,2:0} with an empty retry map, request 7 transfers 10 from 1 to 2, returns Ok, records the request, and produces balances {0:1,1:0,2:10}.

Dafny verified the actual refinement and the witness together: 13 obligations, exit `0`.
An isolated spec with both validity predicates set to false admitted the reject-all
implementation (verifier exit `0`). The same success witness failed (verifier exit `4`).
The fixture is not an approved production spec. The production gate was not weakened.

## Mutation measurements

Spec-proof kill rate: **8/10 (80.00%)**.
The denominator includes the labeled algebraic rewrite control. One invalid source
and one audit-rejected assumption fixture are excluded. Inconclusive results: 0.

| Mutation | Result | Real checker code | Reported claim or contract |
| --- | --- | --- | --- |
| `self_transfer` | killed | 4 | C1, C5 |
| `off_by_one` | killed | 4 | C4 |
| `retry_double` | killed | 4 | C1, C3 |
| `missing_fee_credit` | killed | 4 | C1 |
| `undercharge_fee` | killed | 4 | C1 |
| `discard_retry_record` | killed | 4 | C4 |
| `reject_all` | killed | 4 | C3, C4 |
| `mutate_rejection` | killed | 4 | spec/LedgerSpec.dfy:15, spec/LedgerSpec.dfy:50, spec/LedgerSpec.dfy:51 |
| `algebraic_rewrite` | survived | 0 | See the labeled control below |
| `print_effect` | survived | 0 | See the labeled control below |
| `sneaky_assume` | audit_rejected | 2 | See the labeled control below |
| `invalid_source` | invalid | 2 | See the labeled control below |

The algebraic rewrite survived as expected. The print-effect mutant also
survived: printed output is outside the declared ledger-state claims. Survival
is not a claim that the mutation satisfies every human requirement. The assumption
fixture was rejected by the real auditor, not counted as a spec-proof kill.
The invalid source failed real parsing, not proof. Unlabeled contract failures
retain their actual source locations rather than being assigned an invented C1–C5 label.

## Reproduce

```sh
python3 scripts/generate_claim_docs.py
python3 scripts/exit_stage_5.py --case vacuity
python3 scripts/exit_stage_5.py --case mutations
python3 scripts/render_spec_report.py
```

[Claim explanations and examples](claims.md) use actual model comparisons.
[Canonical diagnostic summary](../results/stage5/spec-quality.json) binds source hashes,
scope, methods, and tool versions. The [vacuity](../results/stage5/vacuity.json)
and [mutation](../results/stage5/mutations.json) reports retain real commands and codes.
Raw logs are operational records. All evidence keeps `end_to_end=false`.
