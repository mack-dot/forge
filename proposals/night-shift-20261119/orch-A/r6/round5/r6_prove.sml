(* r6_prove.sml (worker A30, round 4). Read by R6ffi-0001.sml only, after r6_common.sml and r6_steps.sml. NOT RUN.
   Head-goal replay of the shared step lists, then save_thm. Same semantics as explore_head in R6x-0004:
   each step acts on the first goal; the candidates (main, then the alternatives in order) are tried one by one,
   each under STEP_LIMIT seconds (= HEAD_SECS of the exploration); the first that does not fail is taken. *)
val STEP_LIMIT = 240;
fun step_tac (lemma : string) (i : int) ((label, t, alts) : string * tactic * tactic list) : tactic =
  fn (g : goal) => fn (ctxt : Context.t) =>
    let
      fun go (_ : int) ([] : tactic list) =
            (showg ("STEP_ALL_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label) g;
             raise mk_HOL_ERR "A30" "step_tac" ("all candidates failed at " ^ lemma ^ " step " ^ Int.toString i))
        | go k (c :: cs) =
            (let val r = tlim STEP_LIMIT c g ctxt
             in pr ("STEP_USED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label ^ " candidate " ^ Int.toString k ^
                    " goals_out " ^ Int.toString (length (#1 r)));
                r
             end
             handle e => (pr ("STEP_CANDIDATE_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " candidate " ^
                              Int.toString k ^ " " ^ trunc 300 (General.exnMessage e));
                          go (k + 1) cs))
    in go 0 (t :: alts) end;
(* candidate 0 = main step; candidate k >= 1 = alternative k (the numbering of ALT_WORKS in the exploration log) *)
fun head_replay (lemma : string) (steps : (string * tactic * tactic list) list) : tactic =
  let fun loop (_ : int) (acc : tactic) [] = acc
        | loop i acc (s :: rest) = loop (i + 1) (Tactical.THEN_LT (acc, HEADGOAL (step_tac lemma i s))) rest
  in loop 1 ALL_TAC steps end;
fun prove_steps (name : string) (stmt : term) (steps : (string * tactic * tactic list) list) : unit =
  (pr ("BEGIN " ^ name);
   let val th0 = Tactical.TAC_PROOF (([], stmt), head_replay name steps)
   in if null (hyp th0) andalso aconv (concl th0) stmt
      then (let val th = save_thm (name, th0) in chk name th end)
      else raise Fail "result has hypotheses or a different conclusion"
   end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ trunc 800 (General.exnMessage e)); failed := name :: !failed);
val _ = prove_steps "IOFS_V_FFI_part_hprop" X9_STMT X9_STEPS;
val _ = prove_steps "IOxV_IMP_IOx" X8_STMT X8_STEPS;
val _ = prove_steps "writei_spec_V" WRITEI_V WRITEI_STEPS;
val _ = prove_steps "read_into_spec_V" READ_INTO_V READ_INTO_STEPS;
