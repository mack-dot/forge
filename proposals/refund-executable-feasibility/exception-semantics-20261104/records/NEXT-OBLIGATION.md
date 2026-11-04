# Next smallest obligation — NOT RUN

Keep the exact event list in `refund_error_stdio_semantics`. First prove a
separate extraction lemma using existing basis FFI definitions:

```sml
RTC call_FFI_rel (basis_ffi ext cl fs) st.ffi /\
SPLIT3 (st2heap (basis_proj1,basis_proj2) st) (h1,h2,h3) /\
STDIO fs' h1 ==>
extract_fs ext (cl,fs) st.ffi.io_events =
  SOME (fs' with numchars := fs.numchars)
```

Use `RTC_call_FFI_rel_IMP_basis_events`, `extract_fs_basis_ffi`,
`extract_fs_def`, `STDIO_def`, `IOFS_def`, `basis_proj1_write` and the existing
heap-splitting rules. The same extraction argument appears in the pinned
`basis_ffiScript.sml` normal-return and FFI-divergence bridges. The exception
proof needs its own checked composition; those bridges have different postconditions.

Then instantiate the checked error theorem at `init_state (basis_ffi ext cl fs)`
and retain its exact trace, exception witness and postcondition. Normalize the
`numchars` field with existing `fastForwardFD_with_numchars` and
`with_same_numchars` facts. Discharge declaration, main-name and initial heap
premises for the exact `refund_prog` using U271's unchanged translator state and
basis initialization evidence. Do not assume those obligations merely because
the canonical-success proof discharged similar ones.

Expected target: a nonempty semantics set whose every behavior has the checked
exception and exact modeled event trace, and whose event replay yields
`fastForwardFD fs 0`. No OS exit code appears in this statement. Physical native
I/O, resource and process-exit refinements remain separate obligations.

This file describes an unexecuted experiment. It is not a theorem or exit result.
