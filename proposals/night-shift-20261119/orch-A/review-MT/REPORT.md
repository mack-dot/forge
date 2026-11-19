# Review of MT-0001 (condensed by A, 2026-11-19T15:57:32Z); verdict HOLDS WITH LIMITS; full text `mt/review_MT-0001.txt`
MT-0001: actual exit 0, EXACT_COMPLETE, stderr empty. MT1 = the conclusion of MF-0002 (M3) for
`refund_mc (sl+0x1000040D0w) (envmc with ffi_interfer := refund_ffi_tot Vok envmc.ffi_interfer)`, for every `Vok`.
12 premises: entry state (`refund_entry_pre_sl`), alignment and size of the heap range, `refund_heap_clear_sl`,
`envmc.prog_addresses = refund_mem_dm_sl sl h e`, `interference_ok envmc.next_interfer …`,
`refund_ffi_contract_on … Vok envmc.ffi_interfer`, stdin content = the request, `wfcl`, `wfFS`, `STD_streams`.
Only `refund_env_ok_sl` is removed, discharged by L1C. No `ffi_calls_ok`, no `refund_valid_event`, no R6.
Limits: MODEL level only (totalised machine; `basis_ffi` file system); nothing about the real machine; `interference_ok`
and `contract_on` for a constructed environment are NOT proved (shown only for the empty predicate, where the machine is
the abstract one); MT1 concludes only if the output parses strictly; MT2 only for Terminate Success; non-vacuity of the
premises not shown (NV not run). MT-0001 does not use MG-0001 (no decision-event result on this route).
Low defects: two self-referential controls (lines 189, 192); one control is a surface-text check (line 195); the
used-files lists are empty (the case reads no file with `use`: A checked).
