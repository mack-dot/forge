(* nv_prove.sml (worker W-nv). Read by NV-0001.sml only, after nv_common.sml and nv_steps.sml. NOT RUN. UNCHECKED.
   = round13 r6r_prove.sml without the frame-theorem registration. Head-goal replay of the shared step lists, then
   save_thm; after each save the theorem goes into the table TH. A failed REQUIRED lemma is fatal (NV-0001.sml checks);
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
val _ = List.app prove_steps NV_LEMMAS;
val _ = pr ("OPTIONAL_FAILED " ^ String.concatWith " " (rev (!optional_failed)));
