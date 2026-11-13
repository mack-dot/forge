# U345: `read_error_generic` checked locally; repeat, import and two controls match

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
The owner authorized the local repair and the five-case run after U342.
No hosted action, publication or protected edit occurred.

## Result

`read_error_generic` is a checked HOL theorem under its seven stated premises.
The statement bytes are identical to the frozen candidate of U328/U329.
Statement quotation SHA256
`ae4abbf8cafec57b4058a90e34528c45e31ebe000e787f2b4cf4add9f0b29076`.

```
FD fd fdv ∧ NUM n nv ∧ n < 256² ∧ MAX n 2048 ≤ LENGTH rest ∧
MEM «read» ns ∧ ¬MEM «» ns ∧
u «read» (n2w8 fd) (n2w2 n ++ h3::h4::rest) s =
  SOME (FFIreturn (1w::n2w n::h3::h4::rest) s') ⇒
app p TextIO_read_v [fdv; nv]
  (W8ARRAY iobuff_loc (h1::h2::h3::h4::rest) * one (FFI_part s u ns events))
  (POSTe e.
     &InvalidFD_exn e * W8ARRAY iobuff_loc (1w::n2w n::h3::h4::rest) *
     one (FFI_part s' u ns
            (events ++ [IO_event (ExtCall «read») (n2w8 fd)
               (ZIP (n2w2 n ++ h3::h4::rest,1w::n2w n::h3::h4::rest))])))
```

Meaning: when the `read` FFI call returns status byte 1 for this buffer, the
unchanged library function `TextIO.read` raises `InvalidFD`. The array holds
the returned bytes. The FFI state holds the complete error event. The premise
about `u` is an assumption about the FFI oracle; this theorem does not
discharge it for the native runtime.

## Actual results

All commands ran in `results/refund-generic-read-local-20261112/attempt-0001`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `python3 -I -B run_case.py explore-0001 explore-0001.sml` | 0 | Goal-manager exploration. A goal-count error in the exploration script sent later steps to the wrong goal. No theorem. |
| `python3 -I -B run_case.py explore-0002 explore-0002.sml` | 0 | Witness, `conf` and `fs` steps pass. A second tracking error skipped the closing `xsimpl`. No theorem. |
| `python3 -I -B run_case.py explore-0003 explore-0003.sml` | 0 | Straight-line steps pass through `xraise`. One final goal remains: `n2w2` is unfolded on one side only. No theorem. |
| `python3 -I -B run_case.py proof-0001 generic-read-0002.sml` | 0 | `CHECKED read_error_generic`; `READ_EVENT_GAP_COMPLETE`; four exports. |
| `python3 -I -B run_case.py repeat generic-read-0002.sml` | 0 | Same markers; four exports byte-identical to `proof-0001`. |
| `python3 -I -B run_case.py import import.sml proof-0001 forge_refundGenericReadError` | 0 | Frozen import script. Exact statement match; `DISK_THM` only; 0 hypotheses; 0 tagged axioms; 217 closure nodes; four Boolean axioms. |
| `python3 -I -B run_case.py wrong-exception wrong-exception.sml proof-0001 forge_refundGenericReadError` | 1 | Frozen control. `Exact generic read statement mismatch`; no completion marker. |
| `python3 -I -B run_case.py omitted-event omitted-event.sml proof-0001 forge_refundGenericReadError` | 1 | Frozen control. `Exact generic read statement mismatch`; no completion marker. |
| `python3 -I -B validate_evidence.py` | 0 | Separate reader binds hashes, exits and markers of the five cases. |
| Reader control: copy with one altered stream | 1 | Reader rejects the altered `import/stdout.log`. |
| Hosted job; native read/frame proof; composition; independent replay | NOT RUN | Separate obligations. |

The three explorations exit 0 because the scripts end with a normal exit. They
store no theorem and are not proof passes. Their two tracking errors are
exploration-script defects and are preserved. They are not negative controls.

## Candidate change

[generic-read-0002.sml](records/generic-read-0002.sml), SHA256
`90e827dc782bcfe23f0518cca18facf649d434f59421d593bc436a187f003ae3`.
[Diff against the frozen candidate](records/candidate.diff): two tactic regions.

1. `xffi` branch: reverse the existential order, give `events`, `ns`, `u`, `s`,
   let `xsimpl` resolve the frame, give `n2w8 fd`, unfold `FD`, `STRING_TYPE`
   and `n2w2`, then close with `xsimpl`. This follows the published
   `read_spec` proof in `basis/TextIOProofScript.sml`.
2. Final line: `n2w2_def` is added to the `fs` list after `xraise`.

U342 proposed a change to the `xffi` step only. The exploration showed that
the second change is also necessary. Statement, premises, theory name,
dependency check and export are unchanged. No axiom, `cheat` or oracle is used.

Frozen prepared inputs, byte-identical to U329:
`import.sml` `3018afad63a80620fbf3f4ed04a606d1121da0cb77460c3cfea7542351b2bdc1`,
`wrong-exception.sml` `c47b9f260e3e638a6fe91f75f263b37c4652bc68210447df0d3b898d308f19ee`,
`omitted-event.sml` `d7cd686252cf99d571cee7a764720e7ff5db2ef1121d94416fd455601dee190e`.

## Identities and resources

HOL revision `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`; `bin/hol` SHA256
`736c669e220381ddb6042fda624db79326aaa0075fe6ff9de4751bad75e8c4dd`; CakeML
commit `cd9155694c16831373ab695a670794f23282ed62`; CakeML heap SHA256
`36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247`.
The argv prefix, cwd and 2665 input identities come from U328's
`generic-0001/command.json`. Import cases add the three exported object files.
All input hashes match before and after every case.
Limits per child: CPU 120 s, wall 150 s, zero core dumps. No timeout occurred.

| Case | Wall s | Child CPU s (user + system) | Max RSS bytes |
| --- | --- | --- | --- |
| proof-0001 | 56.301 | 52.580 + 14.833 | 1808613376 |
| repeat | 65.903 | 53.253 + 18.421 | 1818492928 |
| import | 12.764 | 15.169 + 4.257 | 1024425984 |
| wrong-exception | 13.667 | 15.345 + 4.913 | 1057685504 |
| omitted-event | 14.284 | 15.114 + 5.440 | 959594496 |

Exports of `proof-0001` and `repeat`:

- `.hol/objs/forge_refundGenericReadErrorTheory.dat` `0fc131812c25df433dd5bae060e2ef055deee6b4cb7a417dd844818cd32c0044`
- `.hol/objs/forge_refundGenericReadErrorTheory.sig` `f34a802c629ee6eb4a8454924ca9e4cee023c60bd2d15ac50cbbe05ba52f6282`
- `.hol/objs/forge_refundGenericReadErrorTheory.sml` `9c1f9d17598866bbb09c5de6e049fd25324636352c3616cf41ca33d96c840cf9`
- `.hol/docs/forge_refundGenericReadErrorTheory.html`, hash in `records/proof-0001/command.json`

## Assurance

| Claim | Status | Evidence and limit |
| --- | --- | --- |
| `read_error_generic`, exact frozen statement | LOCALLY_VALIDATED | Proof, repeat and fresh import exit 0. Same machine, cached parent theories and saved states. |
| Reproducible export | TESTED | Two runs give four byte-identical files. |
| Statement controls | TESTED | Two frozen altered statements are rejected for the intended reason. |
| Dependency closure | TESTED locally | 217 theory nodes, `DISK_THM` oracle tag only, four standard Boolean axioms. No fresh kernel replay of the parents. |
| FFI oracle premise for the native runtime | NOT_ESTABLISHED | The theorem assumes the `u «read»` equation. |
| Composition through `inputAllFrom`/`refund_main` and the compiler | NOT_ESTABLISHED | Not attempted here. |
| Native read/frame correspondence; independent replay; M1 | NOT_ESTABLISHED | Separate obligations. |

## Limits

Same machine and same agent for production and readback. The saved states and
parent theories are cached producer artifacts, not independent inputs. The
`DISK_THM` tag covers theorems loaded from disk; it is not a fresh kernel
replay. The reader checks bytes, exits and markers only. The reader must run
at the results path, because recorded argv names that path.

## Next check

Compose `read_error_generic` through `inputAllFrom` and `refund_main`, with the
exact exception, event, memory and initialization conditions (U328 next step).
Compare the resulting error behavior with the approved contract. A required
behavior or model change needs a separate proposal. The hosted request of U341
is not necessary for this theorem.
