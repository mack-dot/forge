# U342: local proof context works; the unchanged candidate fails at one tactic step

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
This packet records three local HOL runs. No hosted action, publication or
protected edit occurred. The theorem `read_error_generic` is not established
and not disproved.

## Actual results

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| Read-only `access()` query on `/var/tmp` and `/private/var/tmp` | 0 | Write access reported. U319 recorded EPERM. No file created. |
| Unchanged SAT diagnostic, [records](records/sat-diagnostic-0001/command.json) | 0 | `⊢ probe ∨ ¬probe`; `NATIVE_STEP_COMPLETE`. U316 recorded exit 1 with EPERM. |
| Unchanged candidate, [records](records/generic-local-0001/command.json) | 1 | `load "cfLib"` completes. Theorem goal reached. `store_thm` fails at `THEN1`. |
| Instrumented diagnostic copy, [records](records/generic-instrumented-0001/command.json) | 1 | Same failure. Failing step identified. |
| Tactic repair; repeat; fresh import; two controls; hosted job | NOT RUN | No expected exit is an observed result. |

Each HOL run used the pinned tools and the recorded argv and cwd:

- HOL revision `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`, clean tracked diff.
  `bin/hol` SHA256 `736c669e220381ddb6042fda624db79326aaa0075fe6ff9de4751bad75e8c4dd`.
- SAT diagnostic source SHA256
  `bc3fb212a4037ae8e8ebd500f9843bff9cd93cbfcbc76501c7a152a9004af108`; ARM8 heap
  `787499c5305260a0dcf93cab119e0cb2f830c539ddf9327c433758f0a92350a9`. CPU limit 120 s.
- Candidate source SHA256
  `7e36c4867615e1d7fdce3d49143ced0788f0f28517df49a1f611ef95a684ffc6`; CakeML heap
  `36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247`; CakeML commit
  `cd9155694c16831373ab695a670794f23282ed62`. CPU limit 120 s, zero core dumps.
- All 2665 input hashes from U328's `generic-0001/command.json` match before
  and after both candidate runs. No theory file was exported.

| Run | Wall s | Child CPU s (user + system) | Max RSS bytes |
| --- | --- | --- | --- |
| Unchanged candidate | 97.907 | 54.402 + 24.694 | 1479049216 |
| Instrumented copy | 69.313 | 54.766 + 15.352 | 1226440704 |

Output went to a session scratch directory. Only the streams and command
records were copied here. The runner is [run_candidate.py](records/run_candidate.py).

## Failing step

The [instrumented copy](records/generic-read-instrumented-0001.sml) adds goal
printing only. Its [diff](records/instrumentation.diff) changes no statement
and no proof tactic. SHA256
`1fba080f9272656fb068c984a92f9473504840ae73365945db98c486fcaf014a`.

The failure is in the `xffi` branch of the second `xlet`. After
`xsimpl >> qexists_tac `n2w8 fd` >> fs [FD_def,n2w2_def]` one goal remains:

```
∃frame s'' u' ns' events'.
  MEM «read» ns' ∧
  fdv = Litv (StrLit (implode (MAP (CHR ∘ w2n) (n2w8 fd)))) ∧ ¬MEM «» ns' ∧
  one (FFI_part s u ns events) ==>> frame * one (FFI_part s'' u' ns' events') ∧
  case u' «read» (n2w8 fd) (n2w (n DIV 256)::n2w n::h3::h4::rest) s'' of ...
```

The assumptions at that point include:

```
u «read» (n2w8 fd) (n2w (n DIV 256)::n2w n::h3::h4::rest) s =
  SOME (FFIreturn (1w::n2w n::h3::h4::rest) s')
STRING_TYPE (implode (MAP (CHR ∘ w2n) (n2w8 fd))) fdv
MEM «read» ns        ¬MEM «» ns
```

The script supplies a witness for `conf'` only. It supplies none for `frame`,
`s''`, `u'`, `ns'` and `events'`. The later `xcon` branch was not reached.

Interpretation, not a checked result: the residual is a missing witness
instantiation. The assumptions contain the matching FFI equation. This output
is not evidence that the statement is false. A repair that instantiates the
five variables and unfolds `STRING_TYPE` is a candidate. It was NOT RUN.

## Impact

- U316/U319/U320 blocked local proof work on an EPERM for `/var/tmp`. That
  denial does not occur in this session. The cause of the difference is not
  established. A different agent sandbox is the leading inference.
- U328 stopped at `load "cfLib"`. That load now completes locally.
- [U341's corrected hosted workflow](../proof-loader-fix-20261109/NEXT-RUN-APPROVAL.md)
  runs the same candidate bytes. If the hosted HOL behaves as this local HOL,
  that job exits 1 at the same step. This is an inference; no hosted run
  occurred. Recommendation: hold that approval request.
- Two local executions reached the theorem; both exit 1. Neither is a
  negative control.

## Limits

Same machine, cached parent theories and saved states, one run per case. No
independent replay. Local hashes are not independent source or bootstrap
provenance. A later local pass of this theorem would not establish native
read/frame correspondence, whole-program composition or M1.

## Next check

Write a new candidate file that changes only the `xffi` witness step. Keep the
statement, premises and dependencies. Run proof, same-source repeat, fresh
import, wrong-exception control and omitted-event control locally with the
existing limits. Stop at the first unexpected result. Preserve every attempt.
