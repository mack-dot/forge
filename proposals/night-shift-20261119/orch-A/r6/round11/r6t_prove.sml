(* r6t_prove.sml (worker A36, round 11). Read by R6t-0001.sml only, after r6t_common.sml and r6t_steps.sml. NOT RUN.
   = round9/r6w_prove.sml (ran in R6w-0004: exit 0) with names R6W -> R6T and without the hprop_inj frame
   registration. Head-goal replay of the shared step lists, then save_thm; after each save the theorem goes into the
   table TH (later lemmas read their prerequisites from it). A failed REQUIRED lemma is fatal (R6t-0001.sml checks);
   a failed OPTIONAL lemma is only reported. *)
val optional_failed = ref ([] : string list);
val stored_names = ref ([] : string list);
fun prove_steps ((name, stmt, steps, req) : string * term * step list * bool) : unit =
  (pr ("BEGIN " ^ name ^ (if req then " required" else " optional"));
   let val th0 = Tactical.TAC_PROOF (([], stmt), head_replay name steps)
   in if null (hyp th0) andalso aconv (concl th0) stmt
      then (let val th = save_thm (name, th0)
            in chk name th; set_TH name th; stored_names := name :: !stored_names end)
      else raise Fail "result has hypotheses or a different conclusion"
   end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ trunc 800 (General.exnMessage e));
               if req then failed := name :: !failed else optional_failed := name :: !optional_failed);
val _ = List.app prove_steps R6T_LEMMAS;
val _ = pr ("OPTIONAL_FAILED " ^ String.concatWith " " (rev (!optional_failed)));
