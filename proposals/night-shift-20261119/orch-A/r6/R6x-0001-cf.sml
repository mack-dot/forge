(* R6x-0001-cf.sml (worker A25). NOT RUN. Read by R6x-0001.sml with use, inside a handler.
   It needs cfLib. It contains no term quotation (all terms are built in R6x-0001.sml).
   X8: the instrumented IO predicate IOxV Inv fs implies the stock IOx fs_ffi_part fs (forget the event invariant).
   Every tactic UNCHECKED. Nothing is stored. *)
open cfLib;
val _ = pr "XSIMPL_AVAILABLE cfLib opened";
val _ = explore "X8_IOxV_weakens_to_IOx" (fn () => valOf WEAK_TM) (fn () =>
  [("intro", rpt gen_tac \\ BETA_TAC, []),
   ("unfold", simp [IOxD, IOD, FFP], [rw [IOxD, IOD, FFP]]),
   ("xsimpl", xsimpl, [xpull \\ xsimpl, TRY xsimpl \\ metis_tac []])]);
