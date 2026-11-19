(* R6x-0002-x8.sml (worker A25). NOT RUN. Read by R6x-0002.sml with use, inside a handler. Needs cfLib.
   X8r: IOxV Inv fs ==>> IOx fs_ffi_part fs. R6x-0001 steps 1-3 (log 1525-1557) + a new close step for the printed goal
   (log 1557-1577: for all x. EVERY Inv x ==> ?x'. one (FFI_part ... x) ==>> one (FFI_part ... x')). UNCHECKED. *)
open cfLib;
val X8 = tm_opt "X8r" (fn () => Parse.Term [QUOTE "!(Inv:io_event -> bool) fs. IOxV Inv fs ==>> IOx fs_ffi_part fs"]);
val _ = explore "X8r_IOxV_weakens_to_IOx" (goal_of X8) (fn () =>
  [("intro", rpt gen_tac, []),
   ("unfold", simp [IOxV_def, IOxD, IOD, FFP], [rw [IOxV_def, IOxD, IOD, FFP]]),
   ("xsimpl", xsimpl, []),
   ("close", rpt strip_tac \\ qexists_tac (([QUOTE "x"]) : term quotation) \\ simp [SIR],
      [metis_tac [SIR], rw [SIR] \\ metis_tac [SIR]])]);
