(* tr2_common.sml (worker W-trace, round 3, 2026-11-19). NOT RUN. Read by TR2-0001.sml only (theory forge_machineTracePrefix),
   AFTER forge_machineTrace (case TR1-0001) is loaded and new_theory. Builds the context that tr_steps_fix.sml needs WITHOUT
   redefining anything: the definitions and the 37 part-1 theorems are FETCHED from forge_machineTrace; every other line
   below is a byte-identical copy of tr_common2.sml (line ranges in each block comment; CHANGES_TR2.txt).
   The four statements are built from the same strings as in tr_common2.sml. ASCII only. *)
(* tr_common2.sml lines 10-11 *)
fun Q (s : string) : term quotation = [QUOTE s];
fun PT (s : string) : term = Parse.Term [QUOTE s];
(* fetched definitions (the SML names of tr_common2.sml); a missing toy definition gives TRUTH and drops the toy lemma *)
val PARENT = "forge_machineTrace";
fun fetch_req (n : string) : thm = DB.fetch PARENT n;
fun fetch_opt (n : string) : thm = DB.fetch PARENT n
  handle e => (pr ("FETCH_FAILED " ^ PARENT ^ "." ^ n ^ " " ^ trunc 200 (General.exnMessage e)); TRUTH);
val step_event_ok_def = fetch_req "step_event_ok_def";
val ffi_event_ok_def = fetch_req "ffi_event_ok_def";
val ffi_post_st_def = fetch_req "ffi_post_st_def";
val ffi_call_event_def = fetch_req "ffi_call_event_def";
val trace_next_interfer_def = fetch_req "trace_next_interfer_def";
val trace_ffi_interfer_def = fetch_req "trace_ffi_interfer_def";
val nffis_def = fetch_req "nffis_def";
val trace_last_def = fetch_req "trace_last_def";
val trace_st_def = fetch_req "trace_st_def";
val trace_events_def = fetch_req "trace_events_def";
val trace_ok_def = fetch_req "trace_ok_def";
val toy_config_def = fetch_opt "toy_config_def";
val toy_target_def = fetch_opt "toy_target_def";
val toy_mc_def = fetch_opt "toy_mc_def";
val toy_st_def = fetch_opt "toy_st_def";
val TOY_DEFS_OK = ref (List.all (fn th => not (aconv (concl th) T)) [toy_config_def, toy_target_def, toy_mc_def, toy_st_def]);
val _ = pr ("TOY_DEFS_OK " ^ Bool.toString (!TOY_DEFS_OK));
type step = string * tactic * tactic list;
(* tr_common2.sml lines 161-190 *)
(* ================= theorem table, replay (round13/r6r_common.sml, unchanged except names) ================= *)
val TR_TH = ref ([] : (string * thm) list);
fun TH (nm : string) : thm =
  case List.find (fn (n, _) => n = nm) (!TR_TH) of
    SOME (_, th) => th
  | NONE => raise mk_HOL_ERR "tr_common" "TH" ("no theorem " ^ nm);
fun set_TH (nm : string) (th : thm) : unit =
  TR_TH := (nm, th) :: List.filter (fn (n, _) => n <> nm) (!TR_TH);
fun LATE (f : unit -> tactic) : tactic = fn g => f () g;
val STEP_LIMIT = 240;
fun step_tac (lemma : string) (i : int) ((label, t, alts) : string * tactic * tactic list) : tactic =
  fn (g : goal) => fn (ctxt : Context.t) =>
    let
      fun go (_ : int) ([] : tactic list) =
            (showg ("STEP_ALL_FAILED " ^ lemma ^ " " ^ Int.toString i ^ " " ^ label) g;
             raise mk_HOL_ERR "WTR" "step_tac" ("all candidates failed at " ^ lemma ^ " step " ^ Int.toString i))
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
fun head_replay (lemma : string) (steps : (string * tactic * tactic list) list) : tactic =
  let fun loop (_ : int) (acc : tactic) [] = acc
        | loop i acc (s :: rest) = loop (i + 1) (Tactical.THEN_LT (acc, HEADGOAL (step_tac lemma i s))) rest
  in loop 1 ALL_TAC steps end;
(* every stored theorem of the parent goes into TH (part 1: the 37 lemmas of TR1-0001) *)
val _ = List.app (fn (n, th) => set_TH n th) (DB.theorems PARENT);
val _ = pr ("TH_FROM_PARENT " ^ Int.toString (length (DB.theorems PARENT)));
(* tr_common2.sml lines 192-210 *)
(* ================= STATEMENTS ================= *)
val _ = pr "MARK STATEMENTS";
(* tr_common2: optional statements (Diverge corollary, controls) are never fatal *)
val OPTIONAL_NAMES = ["div_after", "trace_diverge", "toy_target_fields", "toy_encoded", "toy_trace_ok",
                      "toy_trace_events", "toy_bad_rejected", "toy_bad_not_followed"];
fun tr_term (name : string) (s : string) : term =
  PT s handle e => (pr ("STATEMENT_PARSE_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e));
                    if TR_PROOF_MODE andalso not (Lib.mem name OPTIONAL_NAMES) then raise e else T);
(* typed variable texts, used in every statement so that type variable names agree across theorems *)
val tP = "(P:'s -> 'q)";
val tG = "(G:num # word8 list # 's -> 's -> bool)";
val tg = "(g:num -> num # word8 list # 's -> 's)";
val tMC = "(mc:('w,'s,'p) machine_config)";
val tST = "(st:'ffi ffi_state)";
(* the constructed machine and the machine after the trace *)
val MC_C = "(mc with <| next_interfer := trace_next_interfer P tr; ffi_interfer := trace_ffi_interfer G g ms tr |>)";
val MC_F = "(mc with <| next_interfer := trace_next_interfer P []; ffi_interfer := shift_seq (nffis tr) g |>)";
val ENDST = "(trace_st mc st ms tr) ";
val ENDMS = "(trace_last ms tr)";
val TR_S = [
(* tr_common2.sml lines 300-308 and 313-316 *)
 ("trace_terminate",
  "!" ^ tP ^ " " ^ tG ^ " " ^ tg ^ " tr " ^ tMC ^ " " ^ tST ^ " ms t io. trace_ok P G mc st ms tr /\\ " ^
  "targetSem$machine_sem " ^ MC_C ^ " st ms (ffi$Terminate t io) ==> " ^
  "targetSem$machine_sem " ^ MC_F ^ " " ^ ENDST ^ ENDMS ^ " (ffi$Terminate t io) /\\ " ^
  "isPREFIX (st.io_events ++ trace_events mc ms tr) io"),
 ("trace_fail",
  "!" ^ tP ^ " " ^ tG ^ " " ^ tg ^ " tr " ^ tMC ^ " " ^ tST ^ " ms. trace_ok P G mc st ms tr /\\ " ^
  "targetSem$machine_sem " ^ MC_C ^ " st ms ffi$Fail ==> " ^
  "targetSem$machine_sem " ^ MC_F ^ " " ^ ENDST ^ ENDMS ^ " ffi$Fail"),
 ("trace_diverge",
  "!" ^ tP ^ " " ^ tG ^ " " ^ tg ^ " tr " ^ tMC ^ " " ^ tST ^ " ms l. trace_ok P G mc st ms tr /\\ " ^
  "targetSem$machine_sem " ^ MC_C ^ " st ms (ffi$Diverge l) ==> " ^
  "LPREFIX (fromList (st.io_events ++ trace_events mc ms tr)) l")
];
(* tr_common2.sml lines 334-346 *)
val BAD = "[TrStep (1w:word64); TrFfi 0 [7w:word8] (2w:word64)]";
val GT = "(\\(x:num # word8 list # word64) (s:word64). T)";
val G5 = "(\\(k:num) (x:num # word8 list # word64). 5w:word64)";
val MCB = "(toy_mc with <| next_interfer := trace_next_interfer (\\s:word64. s) " ^ BAD ^
          "; ffi_interfer := trace_ffi_interfer " ^ GT ^ " " ^ G5 ^ " 0w " ^ BAD ^ " |>)";
val MCB1 = "(" ^ MCB ^ " with next_interfer := shift_seq 1 " ^ MCB ^ ".next_interfer)";
val S_NEG =
 ("toy_bad_not_followed",
  "targetSem$evaluate " ^ MCB ^ " toy_st (LENGTH " ^ BAD ^ " + 0) 0w <> " ^
  "targetSem$evaluate (toy_mc with <| next_interfer := trace_next_interfer (\\s:word64. s) []; " ^
  "ffi_interfer := shift_seq (nffis " ^ BAD ^ ") " ^ G5 ^ " |>) (trace_st toy_mc toy_st 0w " ^ BAD ^ ") 0 " ^
  "(trace_last 0w " ^ BAD ^ ")");

val STATEMENTS = map (fn (n, s) => (n, tr_term n s)) (TR_S @ [S_NEG]);
(* tr_common2.sml lines 348-356 *)
fun ST (n : string) : term =
  case List.find (fn (m, _) => m = n) STATEMENTS of SOME (_, t) => t
     | NONE => raise mk_HOL_ERR "tr_common" "ST" ("no statement " ^ n);
val _ =
  let val d = !Globals.max_print_depth
  in Globals.max_print_depth := ~1;
     List.app (fn (n, t) => pr ("STATEMENT " ^ n ^ "\n" ^ term_to_string t)) STATEMENTS;
     Globals.max_print_depth := d
  end;
val _ = pr "TR2_COMMON loaded";
