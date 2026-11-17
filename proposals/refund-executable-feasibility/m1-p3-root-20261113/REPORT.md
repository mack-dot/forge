# U382: strengthened root lemma; every interior target state of a simulation segment is ordinary

CURRENT none; M1 open; Stage12 unauthorized; no profile approved; end_to_end=false.
The U298 exclusion premise is not adopted and not used. Nothing committed.
Local results: same machine, same agent, cached parents. No clean replay.

## 1. Exact strengthened root theorem (theory `forge_simRoot`, run `root-0005`)

```
asm_step_IMP_evaluate_step_find_next_prefix
⊢ ∀c s1 ms1 io i.
    encoder_correct c.target ∧ c.prog_addresses = s1.mem_domain ∧
    ffi_entry_pcs_disjoint c s1 (LENGTH (c.target.config.encode i)) ∧
    interference_ok c.next_interfer (c.target.proj s1.mem_domain) ∧
    asm_step c.target.config s1 i
      (asm i (s1.pc + n2w (LENGTH (c.target.config.encode i))) s1) ∧
    target_state_rel c.target s1 ms1 ⇒
    ∃l ms2.
      (∀k. evaluate c io (k + l) ms1 = evaluate (shift_interfer l c) io k ms2 ∧
           find_next_interference c io (k + l) ms1 =
           find_next_interference (shift_interfer l c) io k ms2 ∧
           target_state_rel c.target
             (asm i (s1.pc + n2w (LENGTH (c.target.config.encode i))) s1) ms2 ∧
           l ≠ 0) ∧
      (∀j ms' io'.
         j < l ∧ evaluate c io j ms1 = (TimeOut,ms',io') ⇒
         c.target.get_pc ms' ∈ c.prog_addresses DIFF set c.ffi_entry_pcs) ∧
      (c.install_pc ∉ c.prog_addresses ⇒
       no_install_prefix c io (l − 1) ms1 ∧
       ((asm i (s1.pc + n2w (LENGTH (c.target.config.encode i))) s1).pc ≠
        c.install_pc ⇒ no_install_prefix c io l ms1))
```

The first conjunct is the complete published conclusion. A machine check
recovers the published statement by removing the two added conjuncts. The
same strengthening is proved for `asm_step_IMP_evaluate_step` and for
`asm_step_IMP_evaluate_step_nop` (`…_prefix`).

## 2. How target sequences, clocks and counters are represented

The published lemma gives a segment length `l` and an end state `ms2` with
`evaluate c io (k + l) ms1 = evaluate (shift_interfer l c) io k ms2` for every
`k`. The intermediate states are the TimeOut results of `evaluate c io j ms1`
for `j < l`. The published `encoder_correct` puts each intermediate counter
in `all_pcs` of the instruction encoding, inside `prog_addresses`. The
published lemma also gives the same equation for
`find_next_interference`, the published clone of `evaluate` that stops at the
first FFI or installer application.

## 3. Generic lemmas

- `run_interior_ordinary`: a clock-`l` run that ends in TimeOut with
  `find_next_interference = NONE` has every state at `j < l` in
  `prog_addresses DIFF set ffi_entry_pcs`.
- `segment_interior_ordinary`: any segment with both equations has only
  ordinary interior states. This applies to every published segment lemma.
- `segment_end_no_install_prefix`, `segment_compose_no_install_prefix`,
  `state_rel_segment_compose`: prefix facts with clock offsets `l − 1`, `l`
  and `l + n`.

## 4. Can an intermediate counter equal the installer entry?

| Question | Answer | Status |
| --- | --- | --- |
| Interior state of one segment | No. It is in `prog_addresses`; `state_rel` states that `install_pc` is not | PROVED |
| Word wraparound for interior states | Not relevant: the fact is set membership, not arithmetic | PROVED |
| End state of a segment | Not decided by the segment. It needs a fact about the next state (layout bound, U381, or the next segment) | by composition |
| Rule "both ends safe and evaluate equation ⇒ prefix safe" | False | `endpoint_correspondence_insufficient` |

Correction found by the prover: the `l − 1` form is false without `l ≠ 0`.

## 5. Negative controls

- 8-bit wrap example (U380): kept, re-read in the import.
- `interior_install_example`, `endpoint_correspondence_insufficient`: model
  `forge_toy_mc` with one ordinary step into the installer entry and one
  installer step out. Both ends are off the entry; the evaluate equation
  holds for every clock; `no_install_prefix` fails; the interference
  equation fails.

## 6. Executed commands

Run directory: `results/refund-p3-root-local-20261113/attempt-0001`.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| `explore-0001`, `0002`, `0006`–`0010`, `0013`, `0015` | 1 each | my load, typing and tactic errors, and the false `l − 1` form |
| `explore-0003`–`0005`, `0011`, `0012`, `0014`, `0016`, `0017` | 0 each | staged explorations |
| `root-0001`–`root-0003` | 1 each | tactic errors; not counted |
| `root-0004` | 0 | ten theorems |
| `root-0005` | 0 | eleven theorems, final |
| `root-import` | 0 | 11 exact statements, 296 closure nodes, two statement controls, both negative controls |
| `root-repeat` | 0 | exports byte-identical |

Source SHA256 `728469058d988c125c1241210b4eab854383d9ae5e717a6d7b29bbac21ef66c2`;
theory data `adbadc58fa0816e9f514278d78bc072df68af9c60138b01eefff8f49a084de05`.
No separate evidence reader; `MANIFEST.json` lists every member. Clean
replay: NOT_RUN.
