# Profile A and Profile B: assumption-by-assumption comparison (U360)

CURRENT none; M1 open; Stage12 unauthorized; end_to_end=false.
Neither profile is approved by this document. The choice is the owner's.
Source of the profile text: [U356](../m1-replay-closure-20261112/REPORT.md), Phase 5.
Matrix row names (S, C, E, M, F, I, R, X, T) are those of
[CORRESPONDENCE.md](../runtime-premises-20261104/CORRESPONDENCE.md).

Statuses: PROVED (HOL kernel, local scope), OBSERVED (finite capture),
ASSUMED (premise of the claim), OPEN (obligation with no result).

## 1. Assumptions

| # | Assumption | Profile A | Profile B | Evidence today |
| --- | --- | --- | --- | --- |
| 1 | FFI oracle for `read` | Published `basis_ffi`: status 1 only when `read fd fs n = NONE` | New oracle: status 1 is also possible on a readable descriptor | A: `basis_read_error_oracle`, `read_error_basis_instance` PROVED. B: no definition exists |
| 2 | Operating-system read errors on an open, readable descriptor (`EIO`, `EINTR`, `EAGAIN`, `EFAULT`) | ASSUMED absent | In scope. Narrower assumption: on a negative result the buffer is unchanged | No native read-error run exists (U327, U328) |
| 3 | Other threads, processes or signal handlers do not change descriptor state | ASSUMED | ASSUMED (unchanged) | None |
| 4 | Initial state: `wfcl`, `wfFS`, `STD_streams`, `live_numchars` (S4–S7) | ASSUMED | ASSUMED, restated for the new oracle | OBSERVED pipe behavior only |
| 5 | Wire input is the canonical nine-field request on standard input (S3) | ASSUMED for the external producer | Same | Model round trip PROVED; fixtures OBSERVED |
| 6 | Machine state satisfies `installed` for an `is_arm8_machine_config` record (E, M rows) | ASSUMED | ASSUMED | Model instance PROVED (U358); physical state: see [INSTALLED-STATE.md](INSTALLED-STATE.md) |
| 7 | Installer entry: `install_interfer_ok`, or installer exclusion (F4, U298) | Same question in both | Same question in both | New in U360: exclusion suffices (PROVED); exclusion itself OPEN |
| 8 | Native FFI code `basis_ffi.c` meets `ffi_interfer_ok` (F2, F3) | ASSUMED for all FFI functions | `ffiread`: obligation, not assumption. Others ASSUMED | Six-instruction error return PROVED at model level (U348); prologue, call frame and success path OPEN |
| 9 | Between-step interference preserves the projected state (I1) | ASSUMED | ASSUMED | None |
| 10 | Processor behaves as the L3 ARMv8 model; Mach-O loader gives the stated layout (T1, M1, M9) | ASSUMED | ASSUMED | Code bytes OBSERVED equal |
| 11 | Resource condition `is_safe_for_space` (R2) | Not assumed: the conclusion allows a resource-limit prefix | Same | `read_limits` PROVED (U291) |
| 12 | Approved contract | Unchanged | New clause for behavior after a read error. Needs owner approval | The contract has no such clause (U328) |
| 13 | HOL kernel, PolyML, published CakeML and L3 definitions, cached parent theories (T2) | Trusted | Trusted, plus the new oracle definition | Clean replay: two ARM8 theorems only (U360) |

## 2. Trusted boundaries

| Boundary | Profile A | Profile B |
| --- | --- | --- |
| Specification that a reviewer must read | Approved Dafny contract; published `basis_ffi` oracle | The same, plus a new oracle definition and a new error clause. Both are new, unpublished and unreviewed |
| Environment model | Published and used by every CakeML basis proof | Forge-specific. No external use or review |
| Native C code | Whole `basis_ffi.c` trusted | `ffiread` moves from trusted to proved, if obligations 5 and 6 of U356 are met. The rest stays trusted |
| Operating system | `read` never fails on an open readable descriptor | `read` can fail; on failure it leaves the buffer unchanged |
| Proof base | Existing chain; no Forge theorem changes | Library proofs for the call path, a new whole-program theorem, restatement of each Forge theorem that names `basis_ffi` |

## 3. Consequences for the final theorem

Profile A. The statement keeps its current form: for each request in the
approved domain, under assumptions 1–10, the behaviors of the machine model
are within `extend_with_resource_limit` of the specified six-field result.
A run in which the operating system returns a read error is outside the
claim: the theorem says nothing about it, neither success nor failure. With
U327, a read on well-formed standard input never returns status 1, so the
`InvalidFD` branch is not reachable inside the claim.

Profile B. The statement changes: the oracle becomes a parameter with an
error case, and the conclusion gains a second case for the behavior after a
read error. That case needs contract text that does not exist. Every Forge
theorem that names `basis_ffi` must be restated and proved again. The theorems
`read_error_generic` (U345), `ffiread_error_return` (U348) and
`read_error_basis_instance` (U353) are on the critical path under B and only
supporting evidence under A.

In both profiles the theorem is about the machine model. Assumptions 6, 9 and
10 connect it to the physical process and are not proved in either profile.
Neither profile gives end-to-end verification.

## 4. Recommendation (not an approval)

Recommend Profile A for M1, with assumption 2 written into the claim as a
named exclusion. Reasons:

1. A needs no model or contract change. B needs both, and each needs a
   separate owner approval before proof work can start.
2. B adds a new, unreviewed oracle to the trusted specification. That
   enlarges what a consumer must trust in order to remove one environment
   assumption.
3. The open blockers of M1 (assumptions 6 and 7, clean replay, resource
   condition) are the same in both profiles. B does not reduce them.
4. A's main risk is stated and testable: a real read error is outside the
   claim. B stays available later as a separate proposal; the U345, U348 and
   U353 results keep their value for it.

Independent of A or B, recommend the exclusion form of assumption 7. See
[REPORT.md](REPORT.md), section 2: the native installer routine is compiled
without `EVAL`, so `install_interfer_ok` is likely false for a faithful model
of the physical machine (inference from U296; no faulting run exists).
