(* r6w_prove.sml (worker A33, round 6). Read by R6w-0001.sml only, after r6w_common.sml and r6w_steps.sml. NOT RUN.
   Same semantics as round5/r6_prove.sml (it ran in R6ffi-0002: exit 0): head-goal replay of the shared step lists
   (step_tac/head_replay now live in r6w_common.sml), then save_thm. NEW: after each save the theorem goes into the
   table TH (later lemmas read their prerequisites from it), and the HPROP_INJ helpers are registered as frame theorems.
   A failed REQUIRED lemma is fatal (R6w-0001.sml checks); a failed OPTIONAL lemma is only reported. *)
val optional_failed = ref ([] : string list);
val stored_names = ref ([] : string list);
fun prove_steps ((name, stmt, steps, req) : string * term * step list * bool) : unit =
  (pr ("BEGIN " ^ name ^ (if req then " required" else " optional"));
   let val th0 = Tactical.TAC_PROOF (([], stmt), head_replay name steps)
   in if null (hyp th0) andalso aconv (concl th0) stmt
      then (let val th = save_thm (name, th0)
            in chk name th; set_TH name th; stored_names := name :: !stored_names;
               if Lib.mem name R6W_HPROP_INJ
               then (cfLetAutoLib.export_frame_thms [name]; pr ("FRAME_THM_REGISTERED " ^ name))
               else ()
            end)
      else raise Fail "result has hypotheses or a different conclusion"
   end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ trunc 800 (General.exnMessage e));
               if req then failed := name :: !failed else optional_failed := name :: !optional_failed);
val _ = List.app prove_steps R6W_LEMMAS;
val _ = pr ("OPTIONAL_FAILED " ^ String.concatWith " " (rev (!optional_failed)));
