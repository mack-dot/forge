# U348: six-step ARM8 error-return composition proved for the native `ffiread` bytes

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Local HOL runs with the pinned tools. No native execution, hosted action,
publication or protected edit. Status of the theorem: PROVED, local scope only.

## Theorem

`forge_refundNativeReadError.ffiread_error_return`, exact text in
[statement.txt](records/statement.txt), SHA256
`95e65d61268c917b538a0b2997ffdef539a4c7f41ded38574d1ce31f03a824ff`.

```
∀s.
  ¬s.SCTLR_EL1.E0E ∧ ¬s.SCTLR_EL1.SA0 ∧ ¬s.TCR_EL1.TBI0 ∧ ¬s.TCR_EL1.TBI1 ∧
  s.PSTATE.EL = 0w ∧ s.exception = NoException ∧
  aligned 2 s.PC ∧ aligned 3 s.SP_EL0 ∧
  word_bit 31 (w2w (s.REG 0w) : word32) ∧
  <24 code-byte equations at s.PC+0..3 and s.PC+24..43> ∧
  <12 inequalities: s.REG 19w ≠ s.PC+32w ... s.PC+43w>
  ⇒
  ∃s1 s2 s3 s4 s5.
    NextStateARM8 s = SOME s1 ∧ NextStateARM8 s1 = SOME s2 ∧
    NextStateARM8 s2 = SOME s3 ∧ NextStateARM8 s3 = SOME s4 ∧
    NextStateARM8 s4 = SOME s5 ∧
    NextStateARM8 s5 = SOME (s with
      <| MEM := (s.REG 19w =+ 1w) s.MEM;
         PC  := mem_dword MEM' (s.SP_EL0 + 24w);
         REG := s.REG with 19 ↦ mem_dword MEM' (SP+8), 20 ↦ mem_dword MEM' SP,
                30 ↦ mem_dword MEM' (SP+24), 29 ↦ mem_dword MEM' (SP+16), 8 ↦ 1w;
         SP_EL0 := s.SP_EL0 + 32w; branch_hint := SOME BranchType_RET |>)
```

`MEM'` is `(s.REG 19w =+ 1w) s.MEM`. `NextStateARM8` is the published L3 ARMv8
model in HOL4. No new semantics is defined. The final state is an exact record,
so every field not named there is unchanged in the model.

Meaning: in the model, when the instruction after the `read` call sees a
negative 32-bit result, the next six instructions write the byte 1 at the
address in register 19, restore registers 29, 30, 20 and 19 from the stack,
add 32 to the stack pointer and return to the restored link address. No other
memory byte changes.

## Binding to the native executable

[make_statement.py](records/make_statement.py) reads the code bytes from the
exact native file and emits the premise text. Result:
[statement-binding.json](records/statement-binding.json).

| Item | Value |
| --- | --- |
| Native executable SHA256 | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |
| `ffiread` fragment, file offset 151920, 112 bytes | SHA256 `ec5f3b8045a2d7038e8645acd7bd72a001bddc75ab24b7fd913c4d36cc163bf4` (equals U316) |
| Branch `tbnz w0,#31` | file offset 151980, VM `0x1000251ac`, word `37f800c0` |
| Error block | VM `0x1000251c4`–`0x1000251d7`, words `52800028 39000268 a9417bfd a8c24ff4 d65f03c0` |
| Branch target | `0x1000251ac + 24 = 0x1000251c4`; equals the taken-branch step theorem `PC + 24w` |
| Instruction alignment | file offset and VM address are multiples of 4; premise `aligned 2 s.PC` |
| Layout source | U316 static LLDB section listing: `__TEXT` VM start `0x100000000`, file offset 0 |

Checked explicitly by the proof, for each of the six steps: the four
instruction bytes at the step's PC, EL0, no pending exception, PC alignment,
the control-register bits, stack alignment for the two loads, and that the
status-byte store does not overwrite the 12 code bytes still to execute.
Control flow: step 1 uses the taken branch (`word_bit 31`); steps 2–5 fall
through by 4; step 6 returns to the value loaded from `SP + 24`.

## Actual results

All commands ran in `results/refund-arm8-compose-local-20261112/attempt-0001`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `python3 -I -B run_arm8_case.py explore-0001 explore-0001.sml` | 0 | Forward exploration; prints each step's reduced hypotheses and the final state. No theorem. |
| `python3 -I -B run_arm8_case.py explore-0002 explore-0002.sml` | 0 | Goal manager proves the explicit statement. Nothing stored. |
| `python3 -I -B run_arm8_case.py compose-0001 compose-0001.sml` | 0 | `CHECKED ffiread_error_return`; `NATIVE_STEP_COMPLETE`; four exports. |
| `python3 -I -B run_arm8_case.py repeat compose-0001.sml` | 0 | Four exports byte-identical. |
| `... import import.sml compose-0001 forge_refundNativeReadError` | 0 | Exact statement by `aconv`; `DISK_THM` only; 0 hypotheses; 0 tagged axioms; 97 closure nodes; four Boolean axioms. |
| `... wrong-status wrong-status.sml compose-0001 forge_refundNativeReadError` | 1 | After the positive audit: `Exact statement mismatch: wrong status byte` (status 0 instead of 1). |
| `... missing-separation ...` / `... untaken-branch ...` (first versions) | 1 / 1 | SCRIPT ERROR: `no current theory when proving`. Not negative controls. Preserved. |
| `... missing-separation-v2 missing-separation-v2.sml compose-0001 forge_refundNativeReadError` | 1 | Harness first proves the original statement, then the statement without one separation premise fails: `first subgoal not solved by second tactic`. |
| `... untaken-branch-v2 untaken-branch-v2.sml compose-0001 forge_refundNativeReadError` | 1 | Same harness check, then the statement with the branch bit negated fails the same way. |
| `python3 -I -B verify_cases.py` (in `results/m1-closure-20261112/attempt-0001`) | 0 | Separate reader binds hashes, exits and markers. |
| Reader on a copy with one altered export byte / one added acceptance marker | 1 / 1 | Both altered copies rejected. |
| Prologue, `read` call, success path, composition with `read_error_generic` | NOT RUN | Separate obligations. |

A control that ends with an unsolved goal shows that the unchanged tactic does
not prove the altered claim. It is not a proof that the altered claim is false.

Proof source [compose-0001.sml](records/compose-0001.sml), SHA256
`3db90e8ac12e112adc75a8eacba110176064d45985b39e652153e20b80353b07`. It instantiates
the six published step theorems on successive states, then discharges every
instantiated hypothesis from the stated premises. No axiom, `cheat` or oracle.

Exports of `compose-0001` and `repeat`: theory data SHA256
`2cd333092554259dfddf6b070791ea7839b87af544745ea40cf082092daec841`; signature
`0858bc7d6f676ca35629d2aca72cbf1253b08cb44e98b521716db3e02d5e293d`.

Tools: HOL revision `9783a49979c94c401ff8c0e51b2eefae7ea95ae3`, ARM8 heap
`787499c5305260a0dcf93cab119e0cb2f830c539ddf9327c433758f0a92350a9`, argv prefix
and cwd of U316. All checked input files (15 for proof cases, 19 for import
cases) and the cwd listing are unchanged after every case. Limits: CPU 600 s, wall 900 s. Each case ran 5–9 s
with at most 795 MB RSS.

## What this does and does not establish

| Claim | Status | Limit |
| --- | --- | --- |
| Six-instruction error return in the published ARMv8 model, exact bytes of the native file | PROVED, local | Same machine, cached heap, no independent replay. |
| Only the status byte changes in memory on this path | PROVED, local | Model statement. It assumes the listed separation of the status address from 12 code bytes. |
| Library availability (U346) versus instruction-level proof | Separate | U346 showed the library loads. This packet is the composed proof. |
| Register 19 holds the buffer address at this point | NOT_RUN | Needs the prologue instructions (`mov x19, x2`) and the `read` call frame. |
| The `read` system call returns negative only on error and leaves the buffer unchanged | ASSUMED | Operating-system behavior. |
| The processor implements the L3 model; control-register premises hold in the process | ASSUMED | Rows T1 and E1 of the runtime matrix. |
| Loader places these file bytes at the stated addresses | ASSUMED | Mach-O loader; U316 static layout only. |

## Next check

Extend the composition backwards over the prologue and the call, so that
register 19 is bound to the FFI buffer argument. Then relate the memory effect
to the returned buffer `1w::n2w n::h3::h4::rest` of `read_error_generic` (U345).
The closure of this theorem has 97 nodes and no CakeML theory. It is the
cheapest candidate for a clean-environment replay.
