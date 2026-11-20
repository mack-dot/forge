# Report E: closure roadmap (detection first)

"No HW" = needs no attestation hardware. Sizes are estimates with a stated basis, or "not shown". Each acceptance criterion names a command, a file, or an exit code that a third party can check.

## Division 1: detection (answers the owner's question)
| Id | Closes | Acceptance (third-party checkable) | Remaining trust | Deps | Size (basis) | Main risk | No HW |
| --- | --- | --- | --- | --- | --- | --- | --- |
| V1 Verified recheck verifier + evidence package over the silicon WAL | A9.10, A9.3 (content), A9.4 | Report F, "Definition of done", items 1–8 | H_SPEC' (unapproved until V1-S), H_VTOOLS, H_LOG | none | W (Report F) | the format transcription F differs from the sink; Dafny target behaviour | yes |
| V1-S Owner approval of N2' + F | A1.5 | an approval record over the SHA-256 of the N2' and F files under `gate/approvals`; `gate/pr_check.py` exit 1 on a one-byte change of either file | owner key (A1.4) | V1 text | owner decision | protected gate modules | yes |
| V2 Witness under a second uid | A9.2, A7.2 (evidence), H_LOG.1 | (1) the witness runs as uid U2 ≠ the engine uid; (2) a process of the engine uid gets EACCES on `sk_W` (recorded exit); (3) the witness signs (store id, epoch, head) only after V exit 0; (4) a WAL rewritten or cut after signing gives V exit 4 against the signed head | H_KEY, H_CRYPTO, witness host | V1, U894 design | W (not measured) | macOS service-user setup | yes |
| V3 External anchor | A9.5, A8.4 (joint), H_LOG.1–2 | a joint restore of W and P to an earlier valid state gives V exit 4 with the anchor; a fresh head gives exit 0; a second store for the same charge id gives exit 4 | anchor operator | V2 | W (not measured) | availability of the anchor | yes |
| V4 Provider reconciliation | A8.5, H_LOG.3–4 | a script joins the (simulated) provider's list, keyed by request id, with V's accepted records: an extra provider effect → exit 1; a missing one → exit 1; an amount mismatch → exit 1; equal → exit 0 | provider report | V1 | W (not measured) | a real provider API is out of scope; a simulated dispatcher first | yes |
| V5 Trust root and provenance | A9.6, A9.7 | a signed trust-root file (spec hashes, `pk_W`, anchor id) outside the store; V refuses a package whose spec hash differs (exit 3); the request line carries a requester signature that V checks (exit 1 on a bad one) | requester key custody | V1 | W (not measured) | format change in the sink (protected 249-line limit, `exit_silicon_sink.py:52`) | yes |

## Division 2: existing proof closure
| Id | Closes | Acceptance | Remaining trust | Deps | Size | Main risk | No HW |
| --- | --- | --- | --- | --- | --- | --- | --- |
| P0 Source inventory for M1 and the top layer | precondition of P1 | a tracked list. For each theory of the 71 + 24 chain, the top layer (LOut, ModelFrame, RouteAFlat, FlatContract, PrefixFree, PrefixExact, m1bErase*) and their parents: source path, SHA-256, location (`main`, `backup/forge-local-2026-11-11` `c003a982`, or untracked). The count of untracked items is stated | — | none | not shown | parents in 34 untracked `results/` folders | yes |
| P1 M1-R: rebuild from a clean clone, one machine | A4.2; clean replay of A3.5, A4.1, A5.1, A6.6, A6.8a | Report F, "Second task", DoD 1–3 (one machine; NO second operator) | H_TOOLS, upstream pins | P0 | not shown | the path problem (`CLEAN_REPLAY_PLAN.md` s.2); tool build time | yes |
| P2 Independent replay | same → INDEPENDENTLY_REPLAYED | a second operator on another machine follows `INDEPENDENT_REPLAY_PLAN.md` s.6; statement hashes equal those of P1 | operator honesty | P1 | not shown | macOS-only steps (plan s.5) | yes |
| P3 Drop the library axiom | A3.2 | `dafny audit` of the LinkedRefund closure lists no `{:axiom}`/`@Axiom`; `dafny verify` exit 0 | Dafny | none | D (one module) | Std dependency | yes |
| P4 Run lift ML-08/ML-09 | A6.2 | stored HOL theorem M-d; the tag check of `e4-0001.sml:17-19` passes; replayed as in P1 | H_ISA | P1 | W | lift through FFI steps | yes |
| P5 FFI witness | A6.4 | repaired `basis_ffi.c` pinned by SHA-256; HOL theorem M-e stored; Wave Gate 1 `--case conformance` exit 0 | C compiler, kernel | P1 | W–R | review-L2d: no witness for the present C | yes |
| P6 Printer narrowing | A3.4 | HOL theorem M-l stored; the 32 printer controls give their recorded exits | HOL | P1 | W | coverage of CakeML's Dafny semantics | yes |
| P7 Mach-O rebuild | A4.3 | two rebuilds from `refund.S` give `b8ed5ec2…`, or a new digest with A5.1 re-proved | `as`, `ld`, clang | P1 | D | ad hoc signature bytes differ | yes |
| P8 Signed refund approval | A1.2, A1.4 | approval record over `90a21c71…` under `gate/approvals`; `gate/pr_check.py` exit 1 on a one-byte change | owner key | owner diff | D | protected gate modules | yes |
| P9 Image read check | A5.1 | a script hashes the byte literal of `refund_file` in the `forge_refundImage` `.dat` and compares it with `b8ed5ec2…` (exit 0); a one-byte-changed copy gives exit 1 | the script | P0 | D | the `.dat` term format | yes |

## Division 3: prevention (D-2)
| Id | Closes | Acceptance | Remaining trust | Deps | Size | Risk | No HW |
| --- | --- | --- | --- | --- | --- | --- | --- |
| E1 Silicon repairs (pin, D7; optionally flags under the lock) | A5.3, A8.4 (partly), A6.7 | new tests `pin`, `d7_ratchet` (and `flags_locked` if chosen) fail on `058eabcb` and pass after; each new mutant is killed; a fresh bundle pins the new `sink.rs`; line count ≤ 249 | Rust | none | D | the 249-line limit | yes |
| E2 Rust frame and wire link | A6.8b, A6.7 | a differential test of Rust `frame()` and the wire against HOL `refund_render_fields`/`sexp_to_string`, computed by the binary over the 2,466 vectors: exit 0; or a string lemma | — | none | D | 8-bit vs UTF-8 | yes |
| E3 WAL model + crash model | A7.1 (model), A8.3, A3.7's A3 | Dafny M-f, M-g, M-h, M-i, M-j: `dafny verify` exit 0; `dafny audit` lists no `assume`, `{:axiom}` or `{:verify false}` (none is allowed in E3) | Dafny | V1-S | W (basis: `SinkCore` 412 lines; not measured) | crash model too weak (prefix-closed only) | yes |
| E4 H_WAL differential link | A3.6, A7.1 (code) | the compiled Dafny fold and Rust `scan` give equal verdicts and states on generated, torn and mutated WALs (exit 0); a planted Rust bug gives exit 1 | H_WAL stays a hypothesis | E3 | D | coverage | yes |
| E5 Composition D-2 (C1–C3) | Report D-2 | `D2_Prevention` C1–C3 verify. A script extracts the `requires` clauses of the top lemma and compares them with a tracked list (exit 1 on a difference). `dafny audit` lists exactly the tracked `{:axiom}` names. An `ensures false` control variant makes the audit script exit 1. Each axiom module has an exhibited model (a proved instance) | named hypotheses | E1, E3, E4 | W | the logic crossing (only for C4/D-2b) | yes |
| E6 Power-loss rig | A8.2 (evidence only) | N = 100 cut-power trials (proposed; no statistical basis claimed); each acked record is present; raw logs hashed | drive | E1 | W + rig | rig cost | needs a rig, not attestation |
| E7 C4 / D-2b | D-2 C4, or D-2b | as E5, plus the C4 hypotheses in the tracked list | the C4 column | P1, P4, P5, E2, E5 | M | as P4/P5 | yes |

## Division 4: hardware-backed assurance
| Id | Closes | Acceptance | Remaining trust | Deps | Size | Risk | No HW |
| --- | --- | --- | --- | --- | --- | --- | --- |
| H0 Kernel code identity | A5.2/A5.4 → stronger evidence | A3 s.5 H0 criteria: the receipt has `b8ed5ec2…` and cdhash `7c0eef46…`; a one-byte copy is refused with a recorded exit; `DYLD_INSERT_LIBRARIES` refused | XNU, Apple, root | none | D | `csops` access for non-root (UNCONFIRMED) | uses OS only |
| H1 Commodity attestation | A5.4 for an outside verifier | A3 s.5 H1 criteria; offline quote check exit 0; a one-byte ELF change fails | vendor root, firmware | P1 redone for an ELF image | W + new M1 chain | the theorem is per image | no |

## Division 5: silicon-rooted assurance
| Id | Closes | Acceptance | Remaining trust | Deps | Size | Risk |
| --- | --- | --- | --- | --- | --- | --- |
| S1 Silver/ag32 FPGA decision | A6.3 for an FPGA core only | A3 s.5 H2 criteria | Verilog semantics, FPGA tools, board | P1 | R | Silver does not build at its latest commit (A3) |

None of H0, H1 or S1 changes a conclusion of D-1.

## Order
1. V1, with V1-S in parallel (owner).
2. V2, V3, V4, V5.
3. P0 → P1 → P2.
4. E1–E5.
5. P3–P9 and E7 as needed.
6. Hardware last.
