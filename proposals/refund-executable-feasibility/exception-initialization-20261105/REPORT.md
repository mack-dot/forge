# Initialized refund exception semantics — U286

CURRENT none. M1 remains open. Stage12 is unauthorized. `end_to_end=false`.

`forge_refundRejectBasisTheory.refund_error_initialized_semantics` is **PROVED**.
It applies to the existing, exact `refund_prog`. The declaration prefix, main
lookup, initial FFI state, reference store and initial STDIO heap are discharged.
Every modeled source behavior retains the exception witness, full final event
list and filesystem replay with stdin consumed to EOF. The specification and
event requirements are unchanged. This does not establish physical execution.

U286 was reserved before U287–U301. Its journal entry is appended after them.
Those separate compiler, runtime and operational findings remain in force.

## Exact claim and remaining premises

The full independently written import expectation is
[expected-final.sml](records/expected-final.sml). The accepted source is
[accepted-concrete.sml](records/accepted-concrete.sml). The new theorem states:

```sml
(wfFS fs ∧ STD_streams fs) ∧
(stdin_content fs = SOME text ∧ refund_run_wire (implode text) = INL err) ⇒
∃h1 h2.
  (SPLIT (st2heap (basis_proj1,basis_proj2)
     (SexpProg$SexpProg_st_2 (basis_ffi ext cl fs,K (K F)))) (h1,h2) ∧
   STDIO fs h1) ∧
  sem_satisfies
    (semantics_dec_list (init_state (basis_ffi ext cl fs)) init_env refund_prog)
    (λbehavior. ∃st3 exn.
      behavior = Terminate Success st3.ffi.io_events ∧
      (∃h3 h4. SPLIT3 (st2heap (basis_proj1,basis_proj2) st3) (h3,h2,h4) ∧
        (&Fail_exn err exn * STDIO (fastForwardFD fs 0)) h3) ∧
      RTC call_FFI_rel (basis_ffi ext cl fs) st3.ffi ∧
      extract_fs ext (cl,fs) st3.ffi.io_events = SOME (fastForwardFD fs 0))
```

The four conjunctive premises are explicit: well-formed filesystem, standard
streams, available modeled stdin, and the stated wire-evaluation error. They
are not assumptions about finite test fixtures. No Unicode, ID, integer, reason
or caller restriction was added. Valid wire requests that return a refund
response use the separate existing success theorem. This theorem does not
establish the unavailable-stdin branch or arbitrary physical I/O failures.

`sem_satisfies` requires a nonempty set and the stated property for every
source behavior. The inherited proof covers all pointer-equality oracles.
The same initial frame `h2` stays outside the behavior quantification. The
full event list is retained, including the basis FFI relation and exact replay.
No trace is replaced with an empty list or filtered to output bytes.

`Success` is the source semantics' logical constructor for this raised
exception. It is not normal ML return and does not prove OS exit0. Previously
observed native exit0 values remain finite evidence only.

## Checked proof chain

| Theorem | Role |
| --- | --- |
| `refund_stdio_extract_fs` | Full basis events plus final STDIO heap determine filesystem replay, accounting for numchars |
| `refund_sem_satisfies_imp` | Preserve nonempty source behaviors while strengthening their established property |
| `refund_error_basis_semantics` | Compose U284 with exact consumed-stdin replay; retain exception and full trace |
| `refund_basis_parts_ok` | Derive the published basis partition condition by checked state-field reduction |
| `refund_basis_fs_projection` | Prove the projection for every name in the defined filesystem FFI part |
| `refund_split_from_subset` | Construct the complementary heap frame |
| `refund_initial_stdio` | Construct STDIO from exact FFI, reference-store and filesystem premises |
| `refund_error_program_identity` | Exact closed translator declaration prefix plus refund_main equals the existing refund_prog |
| `refund_error_initialized_semantics` | Discharge declaration, lookup and initialization for the exact source program |

The existing translator state supplies a kernel theorem about its declarations.
The existing namespace conversion proves main lookup. Checked evaluation proves
the FFI and reference-store facts. Published list rewrites establish program
identity. No program, semantic definition, proof kernel or upstream library was
changed. `DISCH_ALL STDIO_precond` makes its existing hypotheses visible; the
proof discharges them from the unchanged initial conditions.

## Actual commands and failure accounting

`R` is `records/run.py`; `I` is `records/import_final.py`. Each run retains the
full argv, input source, stdout, stderr, actual child exit and completion marker.
[readback.json](records/readback.json) binds all24 terminal records.

| Executed command/check | Actual exit | Result |
| --- | --- | --- |
| R extraction-0001 / extraction-0002 / extraction-0003 | 1/1/0 | Missing helper, helper load failure, then checked extraction lemma |
| R basis-0001 / basis-diagnostic / basis-0002 | 1/0/0 | Goal-order diagnosis; exact composition passes |
| R basis-repeat accepted-basis.sml / import_audit.py import-audit | 0/0 | Intermediate three-theorem variant reproduces and imports |
| R wrong-final-fs wrong-final-fs.sml | 1 | Unconsumed final filesystem claim refused at composition |
| R initialization-inspection inspect-initialization.sml diagnostic | 0 | Exact stored declarations and their dependency tags inspected |
| R initial-heap-0001 through initial-heap-0005 | 1/1/1/1/0 | Initial heap theorem passes on attempt5 |
| Three initial-heap diagnostics | 0/0/0 | Residual goals preserved before each correction |
| R projection-0001 projection-proof.sml | 0 | Separate universal filesystem projection lemma |
| R concrete-0001 / R concrete-repeat accepted-concrete.sml | 0/0 | Nine-theorem concrete variant; four byte-identical exports |
| R wrong-main wrong-main.sml | 1 | Changed entry declaration fails exact program equality |
| I final-import | 0 | Exact final statement/program identity and all nine theorem tags checked |
| I wrong-premise expected-wrong-premise.sml | 1 | Omitted wfFS premise rejected by exact-statement comparison |
| readback.py | 0 |246 theory nodes,1462 parent files,50 protected paths and prior evidence match |
| Pinned CakeML/HOL/PolyML revisions and selected library diff | 0 | Pins match; six inspected library source/signature files unchanged |
| Native compile, test, signing, clean independent full-chain replay | NOT RUN | No new native or independent assurance claim |

The helper load failed in the existing `helperLib.sml` at its `DECIDE`
initialization. The internal cause remains unestablished. The accepted proof
uses the published SPLIT tactic expression directly with ordinary kernel
tactics. The failed library was not patched or used as accepted proof evidence.
The basis composition failure exposed the generated goal order. Reversing the
conjunction tactic proves the same statement.

The initial heap failures exposed, in order: an unavailable ML helper name;
an unreduced FFI field and partition condition; a missing filesystem-name
projection fact; and hidden explicit hypotheses in `STDIO_precond`. Focused
diagnostics and a separate projection proof preceded correction. The unchanged
heap statement passes on its fifth attempt. Concrete composition passes on its
first attempt. U274's five historical failures and U290/U297's stopped routes
were not retried. No failing theorem exceeded the attempt limit.

The negative controls check claim binding. A failed tactic is not a proof that
the altered theorem is universally false. The omitted-premise check is an
exact-statement refusal, not a proof attempt or a runtime counterexample.
Library/namespace failures are infrastructure failures, not adversarial controls.
All sources, residual goals, intermediate exports and warnings are retained.
The inspection log also preserves a missing filename and root Git diagnostic.
An inferred child exit128 was corrected to unknown because it was not separately
captured; the erroneous initial record remains alongside its correction.

## Artifact and dependency identity

| Artifact | SHA256 |
| --- | --- |
| Accepted concrete source and replay source | `82c4877bb9f298fa440c1657b54e291fcd0377cbd0dc9dfc79f29e8cb37f296c` |
| Final theory data | `3c358b38b4617b8b29349fb90200c639150a582a8da6aad2c78bee092e7a8f28` |
| Final signature | `e7b92d93ed908ca377d6a3d74a30218f2b48271d3212243cd720f782c67ac7ab` |
| Final structure | `dd64eb1166a7e40809abc379bb147d16b5505dc416e5ee26523d942f9c3fbc8a` |
| Final HTML | `12b5a57ff3ab153cefab8e3365e5e307c494c78b84f6bbbd53152cbb22b92757` |
| U284 parent theory data | `cfb0f1aa475e4c08a4f490cef6b0d187c7ac274f06e6cf9e6925da2615f215d0` |
| Standard CakeML heap | `36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247` |
| Existing native executable | `b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8` |

The final theory data is specific to the nine-theorem concrete variant. Earlier
three-theorem and projection-only variants share its theory name but have other
hashes and directories. The final import names `concrete-0001` explicitly.
Do not combine exports from different variants.

The fresh import compares the final statement by HOL alpha-equivalence and
checks the closed program identity and exact appended entry declaration. All
nine theorems have zero explicit hypotheses, zero tagged axioms and only
`DISK_THM` import tags. Implication premises remain substantive.
The246-node theory closure includes the four existing Boolean foundations:
`SELECT_AX`, `INFINITY_AX`, `ETA_AX` and `BOOL_CASES_AX`.

[dependency-snapshot.json](records/dependency-snapshot.json) binds1462 parent
files, the four new exports and eight direct translator macro files. The direct
macro list is not a complete dynamically loaded ML dependency closure. The
failed helper's four file hashes are recorded separately. The frozen mission,
50 protected paths,212 prior packet members, native executable and two original
failed heaps match their recorded identities.

Logic/kernel, Poly/ML, loader, host and cached proof-data trust remain. The
same-host proof repeat and fresh standard-heap import are not an independent,
clean replay of the full source-to-native chain. This packet authenticates no
release, signature authority or deployment. Paths in the original runner are
workspace-specific; replay requires the recorded layout and pinned dependencies.

## Assurance matrix and next obligation

| Claim | Status | Limit |
| --- | --- | --- |
| Existing refund_prog identity and initialized exception source behavior | PROVED | Four modeled input/environment premises above |
| Exception witness, full source events and consumed-stdin replay | PROVED | Basis FFI/heap model, all source behaviors |
| Exact export reproduction, hashes and three controls | TESTED | Same host; actual results above |
| Logic, kernel, loader, cached parents and physical host | ASSUMED | Four foundations explicit; no clean independent full-chain replay |
| Error source theorem composed with exact ARM8 compiler theorem | NOT_ESTABLISHED | Next narrow logical composition |
| Universal installed-machine state, FFI, memory and resource applicability | NOT_ESTABLISHED | U296/U298/U300 premises still open |
| Unavailable stdin, arbitrary physical I/O failures and OS exit contract | NOT_ESTABLISHED | Logical Success does not imply exit0 |
| Independent complete native assurance and admission | NOT_ESTABLISHED | M1 open; end_to_end=false |

The [next exact experiment](records/NEXT-OBLIGATION.md) is to compose this error
behavior with the existing pinned compiler theorem. Preserve the full trace,
exception witness and every runtime/resource premise. Reuse the checked compiled
artifact; do not recompile. U300's separate space/non-error and installer-event
work remains open. No protected change, signing, deployment or Stage12 occurred.
