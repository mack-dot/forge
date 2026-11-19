(* tr_common.sml (worker W-trace, Night-Shift Orchestrator A, 2026-11-19). NOT RUN. Every definition and tactic is
   UNCHECKED by HOL. Shared by TRx-0001.sml (exploration) and trace_v1.sml (proof, case TR-0001); both read it with
   use AFTER new_theory. The caller must define: pr, trunc, showg, tlim, TR_PROOF_MODE.
   Content: the datatype of observed events, the trace definitions, the theorem table TH, the step replay
   (copied from round13/r6r_common.sml: step_tac, head_replay), and the statements.
   GENERIC: no refund constant, no arm8 constant. Parents: targetSem, targetProps, ffi, misc, asmProps only.
   ASCII only. Quotations as [QUOTE "..."]. *)

fun Q (s : string) : term quotation = [QUOTE s];
fun PT (s : string) : term = Parse.Term [QUOTE s];

(* ================= DATATYPE ================= *)
val _ = pr "MARK DATATYPE";
(* One observed event per model transition of targetSem$evaluate (targetSemScript.sml 118-219):
   TrStep s       : one normal instruction (the "pc IN prog_addresses DIFF set ffi_entry_pcs" branch, 122-136);
                    s = the OBSERVED state after the instruction and after the minor interference.
   TrFfi i nb s   : one ExtCall FFI call (branch 207-218); i = the ffi index, nb = the bytes returned to the
                    program (the trace's own post-call bytes), s = the OBSERVED state after the return.
   NOT covered (by construction, not by hypothesis): install_pc (141-149) and SharedMem (153-206) events, the halt
   branch (138-140; it ends the run, so it is not a transition). trace_ok below demands, at each FFI event, an ExtCall
   name and no mmio_info entry, so a trace can never pass through an Install or SharedMem branch. The pinned CakeML
   has no ccache_pc (machine_config fields, targetSemScript.sml 20-46). *)
val _ = (Datatype [QUOTE "trace_event = TrStep 'a | TrFfi num (word8 list) 'a"]; pr "DATATYPE_OK trace_event")
  handle e => (pr ("DATATYPE_FAILED trace_event " ^ trunc 600 (General.exnMessage e));
               if TR_PROOF_MODE then raise e else ());

(* ================= DEFINITIONS ================= *)
val _ = pr "MARK DEFS";
fun tr_define (name : string) (q : string) : thm =
  (let val th = Define [QUOTE q] in pr ("DEFINITION " ^ name ^ "\n" ^ thm_to_string th); th end)
  handle e => (pr ("DEFINITION_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e));
               if TR_PROOF_MODE then raise e else TRUTH);

(* one normal step: exactly the tests of evaluate_def 122-133 (the k <> 0 test is the clock) *)
val step_event_ok_def = tr_define "step_event_ok_def"
  ("step_event_ok (mc:('w,'s,'p) machine_config) (ms:'s) (s:'s) <=> " ^
   "mc.target.get_pc ms IN (mc.prog_addresses DIFF set mc.ffi_entry_pcs) /\\ " ^
   "encoded_bytes_in_mem mc.target.config (mc.target.get_pc ms) (mc.target.get_byte ms) mc.prog_addresses /\\ " ^
   "EVERY mc.target.state_ok [ms; mc.target.next ms; s] /\\ " ^
   "(!x. x NOTIN mc.prog_addresses ==> mc.target.get_byte (mc.target.next ms) x = mc.target.get_byte ms x)");

(* one ExtCall FFI event: the tests of evaluate_def 121, 137, 141, 150-152, 207-213 in their order.
   MEM pc ffi_entry_pcs makes the test of line 121 false (it implies pc NOTIN prog_addresses DIFF set ffi_entry_pcs). *)
val ffi_event_ok_def = tr_define "ffi_event_ok_def"
  ("ffi_event_ok (mc:('w,'s,'p) machine_config) (st:'ffi ffi_state) (ms:'s) (i:num) (nb:word8 list) <=> " ^
   "MEM (mc.target.get_pc ms) mc.ffi_entry_pcs /\\ " ^
   "mc.target.get_pc ms <> mc.halt_pc /\\ mc.target.get_pc ms <> mc.install_pc /\\ " ^
   "find_index (mc.target.get_pc ms) mc.ffi_entry_pcs 0 = SOME i /\\ " ^
   "ALOOKUP mc.mmio_info i = NONE /\\ " ^
   "?nm b1 b2 st1. EL i mc.ffi_names = ExtCall nm /\\ " ^
   "read_ffi_bytearrays mc ms = (SOME b1, SOME b2) /\\ " ^
   "call_FFI st (ExtCall nm) b1 b2 = FFI_return st1 nb");

(* the FFI state after a call (deterministic: call_FFI is a function) *)
val ffi_post_st_def = tr_define "ffi_post_st_def"
  ("ffi_post_st (mc:('w,'s,'p) machine_config) (st:'ffi ffi_state) (ms:'s) (i:num) = " ^
   "case read_ffi_bytearrays mc ms of " ^
   "  (SOME b1, SOME b2) => (case call_FFI st (EL i mc.ffi_names) b1 b2 of " ^
   "                           FFI_return st1 nb => st1 | FFI_final e => st) " ^
   "| _ => st");

(* the io event that one call adds (call_FFI_def, ffiScript.sml 64-80: none for the empty name) *)
val ffi_call_event_def = tr_define "ffi_call_event_def"
  ("ffi_call_event (mc:('w,'s,'p) machine_config) (ms:'s) (i:num) (nb:word8 list) = " ^
   "case read_ffi_bytearrays mc ms of " ^
   "  (SOME b1, SOME b2) => (if EL i mc.ffi_names = ExtCall (strlit \"\") then [] " ^
   "                         else [IO_event (EL i mc.ffi_names) b1 (ZIP (b2, nb))]) " ^
   "| _ => []");

(* the constructed minor-interference oracle: index m = number of earlier NORMAL steps (evaluate shifts next_interfer
   only in the normal-step branch, 127-129). Guarded identity: the m-th TrStep's observed state when it agrees with the
   model's computed state on P, else the computed state itself. *)
val trace_next_interfer_def = tr_define "trace_next_interfer_def"
  ("(trace_next_interfer (P:'s -> 'q) ([]:'s trace_event list) (m:num) (ms1:'s) = ms1) /\\ " ^
   "(trace_next_interfer P (TrStep s :: tr) m ms1 = " ^
   "   if m = 0 then (if P ms1 = P s then s else ms1) else trace_next_interfer P tr (m - 1) ms1) /\\ " ^
   "(trace_next_interfer P (TrFfi i nb s :: tr) m ms1 = trace_next_interfer P tr m ms1)");

(* the constructed FFI-interference oracle: index k = number of earlier FFI events (evaluate shifts ffi_interfer only
   in the FFI branches, 214-218). At the k-th TrFfi i nb s with pre-state ms0: s when the argument is (i,nb,ms0) and
   G accepts, else the default g (shifted so that the default always sees the GLOBAL index k). *)
val trace_ffi_interfer_def = tr_define "trace_ffi_interfer_def"
  ("(trace_ffi_interfer (G:num # word8 list # 's -> 's -> bool) (g:num -> num # word8 list # 's -> 's) (ms0:'s) " ^
   "    ([]:'s trace_event list) (k:num) (x:num # word8 list # 's) = g k x) /\\ " ^
   "(trace_ffi_interfer G g ms0 (TrStep s :: tr) k x = trace_ffi_interfer G g s tr k x) /\\ " ^
   "(trace_ffi_interfer G g ms0 (TrFfi i nb s :: tr) k x = " ^
   "   if k = 0 then (if x = (i,nb,ms0) /\\ G x s then s else g 0 x) " ^
   "   else trace_ffi_interfer G (shift_seq 1 g) s tr (k - 1) x)");

val nffis_def = tr_define "nffis_def"
  ("(nffis ([]:'s trace_event list) = 0) /\\ (nffis (TrStep s :: tr) = nffis tr) /\\ " ^
   "(nffis (TrFfi i nb s :: tr) = nffis tr + 1)");

val trace_last_def = tr_define "trace_last_def"
  ("(trace_last (ms:'s) ([]:'s trace_event list) = ms) /\\ (trace_last ms (TrStep s :: tr) = trace_last s tr) /\\ " ^
   "(trace_last ms (TrFfi i nb s :: tr) = trace_last s tr)");

val trace_st_def = tr_define "trace_st_def"
  ("(trace_st (mc:('w,'s,'p) machine_config) (st:'ffi ffi_state) (ms:'s) ([]:'s trace_event list) = st) /\\ " ^
   "(trace_st mc st ms (TrStep s :: tr) = trace_st mc st s tr) /\\ " ^
   "(trace_st mc st ms (TrFfi i nb s :: tr) = trace_st mc (ffi_post_st mc st ms i) s tr)");

val trace_events_def = tr_define "trace_events_def"
  ("(trace_events (mc:('w,'s,'p) machine_config) (ms:'s) ([]:'s trace_event list) = []) /\\ " ^
   "(trace_events mc ms (TrStep s :: tr) = trace_events mc s tr) /\\ " ^
   "(trace_events mc ms (TrFfi i nb s :: tr) = ffi_call_event mc ms i nb ++ trace_events mc s tr)");

(* trace_ok: one clause per event; P = the projection of the step guard, G = the guard of the FFI effect *)
val trace_ok_def = tr_define "trace_ok_def"
  ("(trace_ok (P:'s -> 'q) (G:num # word8 list # 's -> 's -> bool) (mc:('w,'s,'p) machine_config) " ^
   "    (st:'ffi ffi_state) (ms:'s) ([]:'s trace_event list) <=> T) /\\ " ^
   "(trace_ok P G mc st ms (TrStep s :: tr) <=> " ^
   "   step_event_ok mc ms s /\\ P (mc.target.next ms) = P s /\\ trace_ok P G mc st s tr) /\\ " ^
   "(trace_ok P G mc st ms (TrFfi i nb s :: tr) <=> " ^
   "   ffi_event_ok mc st ms i nb /\\ G (i,nb,ms) s /\\ trace_ok P G mc (ffi_post_st mc st ms i) s tr)");

(* controls: a toy machine (word64 states, the state is its own pc) *)
val toy_target_def = tr_define "toy_target_def"
  ("toy_target = ARB with <| config := (ARB with <| encode := (\\i. [0w:word8]); code_alignment := 0 |>); " ^
   "next := (\\s:word64. s + 1w); get_pc := (\\s:word64. s); get_reg := (\\(s:word64) (r:num). 0w:word64); " ^
   "get_byte := (\\(s:word64) (a:word64). 0w:word8); state_ok := (\\s:word64. T); " ^
   "proj := (\\(d:word64 set) (s:word64). s) |>");
val toy_mc_def = tr_define "toy_mc_def"
  ("toy_mc = ARB with <| prog_addresses := {0w:word64}; ffi_entry_pcs := [1w:word64]; " ^
   "ffi_names := [ExtCall (strlit \"f\")]; ptr_reg := 0; len_reg := 0; ptr2_reg := 0; len2_reg := 0; " ^
   "halt_pc := 2w:word64; install_pc := 3w:word64; mmio_info := []; target := toy_target |>");
val toy_st_def = tr_define "toy_st_def"
  ("toy_st = <| oracle := (\\(n:ffiname) (s:unit) (c:word8 list) (b:word8 list). Oracle_return s b); " ^
   "ffi_state := (); io_events := [] |>");

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

(* ================= STATEMENTS ================= *)
val _ = pr "MARK STATEMENTS";
fun tr_term (name : string) (s : string) : term =
  PT s handle e => (pr ("STATEMENT_PARSE_FAILED " ^ name ^ " " ^ trunc 600 (General.exnMessage e));
                    if TR_PROOF_MODE then raise e else T);
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
 ("shift_seq_shift_seq", "!m n (f:num -> 'b). shift_seq m (shift_seq n f) = shift_seq (m + n) f"),
 ("shift_seq_0", "!(f:num -> 'b). shift_seq 0 f = f"),
 ("shift_seq_1_pred", "!(g:num -> 'b) k. k <> 0 ==> shift_seq 1 g (k - 1) = g k"),
 ("trace_next_interfer_ffi",
  "!" ^ tP ^ " i nb (s:'s) tr. trace_next_interfer P (TrFfi i nb s :: tr) = trace_next_interfer P tr"),
 ("trace_next_interfer_shift",
  "!" ^ tP ^ " (s:'s) tr. shift_seq 1 (trace_next_interfer P (TrStep s :: tr)) = trace_next_interfer P tr"),
 ("trace_ffi_interfer_nil", "!" ^ tG ^ " " ^ tg ^ " (ms0:'s). trace_ffi_interfer G g ms0 [] = g"),
 ("trace_ffi_interfer_step",
  "!" ^ tG ^ " " ^ tg ^ " (ms0:'s) s tr. trace_ffi_interfer G g ms0 (TrStep s :: tr) = trace_ffi_interfer G g s tr"),
 ("trace_ffi_interfer_shift",
  "!" ^ tG ^ " " ^ tg ^ " (ms0:'s) i nb s tr. shift_seq 1 (trace_ffi_interfer G g ms0 (TrFfi i nb s :: tr)) = " ^
  "trace_ffi_interfer G (shift_seq 1 g) s tr"),
 ("trace_next_interfer_proj",
  "!" ^ tP ^ " tr m (ms1:'s). P (trace_next_interfer P tr m ms1) = P ms1"),
 ("trace_next_interfer_ok", "!" ^ tP ^ " tr. interference_ok (trace_next_interfer P tr) P"),
 ("trace_ffi_interfer_guard",
  "!" ^ tG ^ " tr " ^ tg ^ " (ms0:'s) k x. trace_ffi_interfer G g ms0 tr k x = g k x \\/ " ^
  "G x (trace_ffi_interfer G g ms0 tr k x)"),
 ("trace_ffi_interfer_off",
  "!" ^ tG ^ " " ^ tg ^ " (ms0:'s) tr k x. ~G x (trace_ffi_interfer G g ms0 tr k x) ==> " ^
  "trace_ffi_interfer G g ms0 tr k x = g k x"),
 ("step_event_ok_upd",
  "!" ^ tMC ^ " ms s f f'. (step_event_ok (mc with next_interfer := f) ms s <=> step_event_ok mc ms s) /\\ " ^
  "(step_event_ok (mc with ffi_interfer := f') ms s <=> step_event_ok mc ms s)"),
 ("ffi_event_ok_upd",
  "!" ^ tMC ^ " " ^ tST ^ " ms i nb f f'. " ^
  "(ffi_event_ok (mc with next_interfer := f) st ms i nb <=> ffi_event_ok mc st ms i nb) /\\ " ^
  "(ffi_event_ok (mc with ffi_interfer := f') st ms i nb <=> ffi_event_ok mc st ms i nb)"),
 ("ffi_post_st_upd",
  "!" ^ tMC ^ " " ^ tST ^ " ms i f f'. ffi_post_st (mc with next_interfer := f) st ms i = ffi_post_st mc st ms i /\\ " ^
  "ffi_post_st (mc with ffi_interfer := f') st ms i = ffi_post_st mc st ms i"),
 ("trace_ok_upd",
  "!" ^ tP ^ " " ^ tG ^ " tr " ^ tMC ^ " " ^ tST ^ " ms f f'. " ^
  "(trace_ok P G (mc with next_interfer := f) st ms tr <=> trace_ok P G mc st ms tr) /\\ " ^
  "(trace_ok P G (mc with ffi_interfer := f') st ms tr <=> trace_ok P G mc st ms tr)"),
 ("trace_st_upd",
  "!tr " ^ tMC ^ " " ^ tST ^ " ms f f'. trace_st (mc with next_interfer := f) st ms tr = trace_st mc st ms tr /\\ " ^
  "trace_st (mc with ffi_interfer := f') st ms tr = trace_st mc st ms tr"),
 ("evaluate_cong",
  "!(mc1:('w,'s,'p) machine_config) mc2 (st1:'ffi ffi_state) st2 (ms1:'s) ms2 k. " ^
  "mc1 = mc2 /\\ st1 = st2 /\\ ms1 = ms2 ==> " ^
  "targetSem$evaluate mc1 st1 k ms1 = targetSem$evaluate mc2 st2 k ms2"),
 ("evaluate_zero",
  "!" ^ tMC ^ " " ^ tST ^ " ms. targetSem$evaluate mc st 0 ms = (targetSem$TimeOut,ms,st)"),
 ("evaluate_one_step_event",
  "!" ^ tMC ^ " " ^ tST ^ " ms s k. step_event_ok mc ms s /\\ mc.next_interfer 0 (mc.target.next ms) = s ==> " ^
  "targetSem$evaluate mc st (SUC k) ms = " ^
  "targetSem$evaluate (mc with next_interfer := shift_seq 1 mc.next_interfer) st k s"),
 ("evaluate_one_ffi_event",
  "!" ^ tMC ^ " " ^ tST ^ " ms i nb s k. ffi_event_ok mc st ms i nb /\\ mc.ffi_interfer 0 (i,nb,ms) = s ==> " ^
  "targetSem$evaluate mc st (SUC k) ms = " ^
  "targetSem$evaluate (mc with ffi_interfer := shift_seq 1 mc.ffi_interfer) (ffi_post_st mc st ms i) k s"),
 ("trace_gen",
  "!" ^ tP ^ " " ^ tG ^ " tr " ^ tMC ^ " " ^ tST ^ " ms " ^ tg ^ " k. " ^
  "trace_ok P G mc st ms tr /\\ mc.next_interfer = trace_next_interfer P tr /\\ " ^
  "mc.ffi_interfer = trace_ffi_interfer G g ms tr ==> " ^
  "targetSem$evaluate mc st (LENGTH tr + k) ms = targetSem$evaluate " ^ MC_F ^ " " ^ ENDST ^ "k " ^ ENDMS),
 ("evaluate_follows_trace",
  "!" ^ tP ^ " " ^ tG ^ " " ^ tg ^ " tr " ^ tMC ^ " " ^ tST ^ " ms k. trace_ok P G mc st ms tr ==> " ^
  "targetSem$evaluate " ^ MC_C ^ " st (LENGTH tr + k) ms = targetSem$evaluate " ^ MC_F ^ " " ^ ENDST ^ "k " ^ ENDMS),
 ("call_FFI_return_io",
  "!" ^ tST ^ " n b1 b2 st1 nb. call_FFI st n b1 b2 = FFI_return st1 nb ==> " ^
  "st1.io_events = st.io_events ++ (if n = ExtCall (strlit \"\") then [] else [IO_event n b1 (ZIP (b2, nb))])"),
 ("ffi_post_st_io",
  "!" ^ tMC ^ " " ^ tST ^ " ms i nb. ffi_event_ok mc st ms i nb ==> " ^
  "(ffi_post_st mc st ms i).io_events = st.io_events ++ ffi_call_event mc ms i nb"),
 ("trace_io",
  "!" ^ tP ^ " " ^ tG ^ " tr " ^ tMC ^ " " ^ tST ^ " ms. trace_ok P G mc st ms tr ==> " ^
  "(trace_st mc st ms tr).io_events = st.io_events ++ trace_events mc ms tr"),
 ("add_clock_swap",
  "!" ^ tMC ^ " " ^ tST ^ " k ms r a b. targetSem$evaluate mc st k ms = (r,a,b) ==> r <> targetSem$TimeOut ==> " ^
  "!k1. targetSem$evaluate mc st (k1 + k) ms = (r,a,b)"),
 ("prefix_of_halt",
  "!" ^ tMC ^ " " ^ tST ^ " k ms t a b. targetSem$evaluate mc st k ms = (targetSem$Halt t,a,b) ==> " ^
  "isPREFIX st.io_events b.io_events"),
 ("fst_error",
  "!(x:machine_result # 's # 'ffi ffi_state). FST x = targetSem$Error ==> ?a b. x = (targetSem$Error,a,b)"),
 ("term_after",
  "!" ^ tMC ^ " " ^ tST ^ " ms mc2 st2 ms2 n t io. " ^
  "(!k. targetSem$evaluate mc st (n + k) ms = targetSem$evaluate mc2 st2 k ms2) /\\ " ^
  "targetSem$machine_sem mc st ms (ffi$Terminate t io) ==> " ^
  "targetSem$machine_sem mc2 st2 ms2 (ffi$Terminate t io) /\\ isPREFIX st2.io_events io"),
 ("fail_after",
  "!" ^ tMC ^ " " ^ tST ^ " ms mc2 st2 ms2 n. " ^
  "(!k. targetSem$evaluate mc st (n + k) ms = targetSem$evaluate mc2 st2 k ms2) /\\ " ^
  "targetSem$machine_sem mc st ms ffi$Fail ==> targetSem$machine_sem mc2 st2 ms2 ffi$Fail"),
 ("trace_terminate",
  "!" ^ tP ^ " " ^ tG ^ " " ^ tg ^ " tr " ^ tMC ^ " " ^ tST ^ " ms t io. trace_ok P G mc st ms tr /\\ " ^
  "targetSem$machine_sem " ^ MC_C ^ " st ms (ffi$Terminate t io) ==> " ^
  "targetSem$machine_sem " ^ MC_F ^ " " ^ ENDST ^ ENDMS ^ " (ffi$Terminate t io) /\\ " ^
  "isPREFIX (st.io_events ++ trace_events mc ms tr) io"),
 ("trace_fail",
  "!" ^ tP ^ " " ^ tG ^ " " ^ tg ^ " tr " ^ tMC ^ " " ^ tST ^ " ms. trace_ok P G mc st ms tr /\\ " ^
  "targetSem$machine_sem " ^ MC_C ^ " st ms ffi$Fail ==> " ^
  "targetSem$machine_sem " ^ MC_F ^ " " ^ ENDST ^ ENDMS ^ " ffi$Fail"),
 ("div_after",
  "!" ^ tMC ^ " " ^ tST ^ " ms mc2 st2 ms2 n l. " ^
  "(!k. targetSem$evaluate mc st (n + k) ms = targetSem$evaluate mc2 st2 k ms2) /\\ " ^
  "targetSem$machine_sem mc st ms (ffi$Diverge l) ==> LPREFIX (fromList st2.io_events) l"),
 ("trace_diverge",
  "!" ^ tP ^ " " ^ tG ^ " " ^ tg ^ " tr " ^ tMC ^ " " ^ tST ^ " ms l. trace_ok P G mc st ms tr /\\ " ^
  "targetSem$machine_sem " ^ MC_C ^ " st ms (ffi$Diverge l) ==> " ^
  "LPREFIX (fromList (st.io_events ++ trace_events mc ms tr)) l"),
 (* ---- controls ---- *)
 ("toy_target_fields",
  "toy_target.next = (\\s:word64. s + 1w) /\\ toy_target.get_pc = (\\s:word64. s) /\\ " ^
  "toy_target.get_reg = (\\(s:word64) (r:num). 0w:word64) /\\ toy_target.get_byte = (\\(s:word64) (a:word64). 0w:word8) /\\ " ^
  "toy_target.state_ok = (\\s:word64. T)"),
 ("toy_encoded",
  "!(pc:word64) (m:word64 -> word8) md. pc IN md /\\ m pc = 0w ==> encoded_bytes_in_mem toy_target.config pc m md"),
 ("toy_trace_ok",
  "trace_ok (\\s:word64. s) (\\(x:num # word8 list # word64) (s:word64). T) toy_mc toy_st 0w " ^
  "[TrStep 1w; TrFfi 0 [] 2w]"),
 ("toy_trace_events",
  "trace_events toy_mc 0w [TrStep (1w:word64); TrFfi 0 [] 2w] = [IO_event (ExtCall (strlit \"f\")) [] []]"),
 ("toy_bad_rejected",
  "~trace_ok (\\s:word64. s) (\\(x:num # word8 list # word64) (s:word64). T) toy_mc toy_st 0w " ^
  "[TrStep 1w; TrFfi 0 [7w] 2w]")];

(* the negative control on the CONCLUSION: the constructed machine for the bad trace does not reproduce it *)
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
fun ST (n : string) : term =
  case List.find (fn (m, _) => m = n) STATEMENTS of SOME (_, t) => t
     | NONE => raise mk_HOL_ERR "tr_common" "ST" ("no statement " ^ n);
val _ =
  let val d = !Globals.max_print_depth
  in Globals.max_print_depth := ~1;
     List.app (fn (n, t) => pr ("STATEMENT " ^ n ^ "\n" ^ term_to_string t)) STATEMENTS;
     Globals.max_print_depth := d
  end;
val _ = pr "TR_COMMON loaded";
