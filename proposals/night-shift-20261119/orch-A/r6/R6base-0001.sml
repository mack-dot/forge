(* R6base-0001.sml: worker A25 (Night-Shift Orchestrator A). PROOF script. NOT RUN. Every tactic UNCHECKED until run.
   Theory forge_refundR6Base. Parents by loading: deps-R6x.txt (deps-L2c.txt + forge_refundRouteA2c).
   FAITHFUL REPLAY of what closed in exploration R6x-0001 (actual exit 0, EXPLORE_COMPLETE; source sha256 5b4a9809...6074;
   log attempt-0001/R6x-0001/stdout.log). Statements = R6x-0001 statements, except where marked CHANGED.
   Stored (required): every_prefix (X1, log 757-779), clock_prefix_of_terminate (X2, 781-858; only steps 1-5 kept: steps 6-7
   ran on 0 goals), bad_read_event_replays_to_the_same_state (X4, 1014-1036), bad_read_event_is_not_valid (X6, 1100-1111),
   bad_read_event_is_not_valid_w (X6w, 1113-1131), refund_valid_event_implies_weak (X6c, 1133-1279), ffi_has_index_in_APPEND
   (X7a, 1281-1319), every_of_three_parts (X7, 1321-1429; there X7a was ASSUMEd, here it is the stored X7a).
   Optional (REPAIRED from printed open goals, never explored): every_clock_events (L-CLK, X3; open goals log 937-1012),
   extract_fs_ignores_bad_read_event (X5; open goal log 1086-1098). An optional failure prints OPTIONAL_FAILED and does not
   block the export; nothing with a hypothesis is ever stored.
   replay_cannot_exclude_error_return_events: strong form (needs X5) if X5 closed, else the weak form (X4 /\ X6).
   Harness: L2d-0001.sml lines 33-93 (helpers, ASSUME fallback never stored, tag checks), names A24 -> A25. *)
open preamble targetSemTheory targetPropsTheory ffiTheory semanticsPropsTheory fsFFITheory basis_ffiTheory TextIOProofTheory
     set_sepTheory;
val _ = Globals.max_print_depth := 60;
(* ===== harness (copied from L2d-0001.sml lines 34-93; names A24 -> A25 only) ===== *)
fun pr s = (print (s ^ "\n"); TextIO.flushOut TextIO.stdOut);
val _ = (load "Timeout"; pr "TIMEOUT_HELPER Timeout.apply loaded")
  handle e => (pr ("TIMEOUT_LOAD_FAILED " ^ General.exnMessage e); raise e);
val _ = metisTools.limit := {time = SOME 30.0, infs = NONE};
val ALT_SECS = 180;
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun trunc n s = if size s <= n then s else String.substring (s, 0, n) ^ " ...";
fun showg tag ((asl, w) : goal) = (pr ("SHOW " ^ tag);
   List.app (fn a => pr ("  ASM " ^ trunc 600 (term_to_string a))) asl;
   pr ("  GOAL " ^ trunc 2500 (term_to_string w)));
fun show_tac tag (g : goal) (ctxt : Context.t) = (showg tag g; ALL_TAC g ctxt);
fun ST tag (tac : tactic) (g : goal) (ctxt : Context.t) = tac g ctxt
  handle e => (showg ("STAGE_FAILED " ^ tag ^ " : " ^ trunc 300 (General.exnMessage e)) g; raise e);
fun CL tag (tac : tactic) (g : goal) (ctxt : Context.t) =
  let val r as (gs, _) = ST tag tac g ctxt in
    if null gs then r
    else (List.app (showg ("UNSOLVED " ^ tag)) gs; raise mk_HOL_ERR "A25" "CL" ("unsolved goals at " ^ tag))
  end;
fun tlim secs (tac : tactic) (g : goal) (ctxt : Context.t) =
  Timeout.apply (Time.fromSeconds (Int.toLarge secs)) (fn () => tac g ctxt) ()
  handle Timeout.TIMEOUT _ => (pr ("TIMEOUT_ALT after " ^ Int.toString secs ^ " s");
                               raise mk_HOL_ERR "A25" "tlim" "time limit");
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundR6Base";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
val failed_stmts = ref ([] : (string * term) list);
val diag = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
fun names_of_hyps th = map (fn h => case List.find (fn (_, t) => aconv t h) (!failed_stmts) of
                                      SOME (n, _) => n | NONE => "?" ^ trunc 80 (term_to_string h)) (hyp th);
fun tryall name goal tacs =
  let fun go _ [] = raise Fail "all listed tactics failed"
        | go i (t :: ts) =
            (let val th = Tactical.TAC_PROOF (([], goal), tlim ALT_SECS t) in pr ("TACTIC_USED " ^ name ^ " " ^ Int.toString i); th end
             handle e => (pr ("TACTIC_ATTEMPT_FAILED " ^ name ^ " " ^ Int.toString i ^ " " ^ General.exnMessage e); go (i + 1) ts))
  in go 1 tacs end;
fun thmA name goal tacs =
  let val _ = pr ("BEGIN " ^ name)
      fun fail_with msg = (pr ("LEMMA_FAILED " ^ name ^ " " ^ msg); failed := name :: !failed;
                           failed_stmts := (name, goal) :: !failed_stmts; ASSUME goal)
  in (let val th0 = tryall name goal tacs in
        if null (hyp th0) then (let val th = save_thm (name, th0) in chk name th; th end)
        else (pr ("DIAG_OK_UNDER " ^ name ^ " assumed: " ^ String.concatWith " " (names_of_hyps th0));
              diag := name :: !diag; fail_with "(diagnostic only: proved only under failed lemmas)") end)
     handle e => fail_with (General.exnMessage e)
  end;
fun thmO name goal tacs =
  (pr ("BEGIN " ^ name);
   let val th0 = tryall name goal tacs in
     if null (hyp th0) then (let val th = save_thm (name, th0) in chk name th; SOME th end)
     else (pr ("OPTIONAL_FAILED " ^ name ^ " DIAG_OK_UNDER " ^ String.concatWith " " (names_of_hyps th0)); NONE) end)
  handle e => (pr ("OPTIONAL_FAILED " ^ name ^ " " ^ General.exnMessage e); NONE);
fun fwd (f : unit -> thm) (g : goal) (ctxt : Context.t) = ACCEPT_TAC (f ()) g ctxt;
(* ================= stored inputs (same names as R6x-0001 part 3) ================= *)
val _ = pr "MARK INPUTS";
val MSD = DB.fetch "targetSem" "machine_sem_def";
val MST = DB.fetch "targetProps" "machine_sem_total";
val EAC = DB.fetch "targetProps" "evaluate_add_clock";
val EAM = DB.fetch "targetProps" "evaluate_add_clock_io_events_mono";
val EWRL = DB.fetch "semanticsProps" "extend_with_resource_limit_def";
val SUBD = DB.fetch "pred_set" "SUBSET_DEF";
val IND = DB.fetch "bool" "IN_DEF";
val EVA = DB.fetch "list" "EVERY_APPEND";
val MEMA = DB.fetch "list" "MEM_APPEND";
val LUPD = DB.fetch "list" "LUPDATE_def";
val IPA = DB.fetch "rich_list" "IS_PREFIX_APPEND";
val IPT = DB.fetch "rich_list" "IS_PREFIX_TRANS";
val IPR = DB.fetch "rich_list" "IS_PREFIX_REFL";
val EFN = DB.fetch "basis_ffi" "extract_fs_with_numchars_def";
val EFA = DB.fetch "basis_ffi" "extract_fs_with_numchars_APPEND";
val EFD = DB.fetch "basis_ffi" "extract_fs_def";
val FFP = DB.fetch "fsFFI" "fs_ffi_part_def";
val FREAD = DB.fetch "fsFFI" "ffi_read_def";
val N2W8 = DB.fetch "Marshalling" "n2w8_def";
val N2W2 = DB.fetch "Marshalling" "n2w2_def";
val W22N = DB.fetch "Marshalling" "w22n_def";
val DIM8 = DB.fetch "words" "dimword_8";
val W2NN = DB.fetch "words" "w2n_n2w";
val FHI = DB.fetch "cfStore" "ffi_has_index_in_def";
val RVE = DB.fetch "forge_refundRouteA2c" "refund_valid_event_def";
val RVE_C = prim_mk_const {Thy = "forge_refundRouteA2c", Name = "refund_valid_event"};
(* the weaker predicate: the R6x-0001 P0 lambda (TYPECHECK_OK, log 545); kept as a lambda, no definition *)
val RVEW =
  ``\e. (?ab nb. e = IO_event (ExtCall «read») (n2w8 0) (ZIP (ab,nb)) /\ LENGTH nb = LENGTH ab /\
                 4 <= LENGTH ab /\ LENGTH ab < 65536 /\ w22n [EL 0 ab; EL 1 ab] + 4 <= LENGTH ab /\ HD nb = 0w) \/
        (?ab nb. e = IO_event (ExtCall «write») (n2w8 1) (ZIP (ab,nb)) /\ LENGTH ab = 2052 /\
                 LENGTH nb = LENGTH ab /\ w22n [EL 0 ab; EL 1 ab] + w22n [EL 2 ab; EL 3 ab] <= 2048 /\ HD nb = 0w)``;
val _ = pr ("WEAK_PREDICATE " ^ term_to_string RVEW);

(* ================= L-CLK parts ================= *)
val _ = pr "MARK CLOCK";
(* X1: steps intro / rw_prefix / every_append (log 763-776) *)
val EVP = thmA "every_prefix"
  ``!(P:'a -> bool) (l1:'a list) l2. l1 <<= l2 /\ EVERY P l2 ==> EVERY P l1``
  [rpt gen_tac \\ rw [IPA] \\ fs [EVA]];
(* X2: steps intro / unfold / case_split / le_A / gt_A (log 792-851; goals 0 after gt_A) *)
val CLKA = thmA "clock_prefix_of_terminate"
  ``!mc (ffi:'ffi ffi_state) ms t iob j.
      targetSem$machine_sem mc ffi ms (Terminate t iob) ==>
      (SND (SND (targetSem$evaluate mc ffi j ms))).io_events <<= iob``
  [rpt gen_tac \\ (simp [MSD] \\ strip_tac) \\ Cases_on `j <= k`
     \\ TRY (qspecl_then [`mc`, `ffi`, `j`, `ms`, `k`] mp_tac EAM \\ asm_simp_tac (srw_ss()) [IPR] \\ NO_TAC)
     \\ TRY (`k + (j - k) = j` by decide_tac \\
             qspecl_then [`mc`, `ffi`, `k`, `ms`, `j - k`, `Halt t`, `ms'`, `st'`] mp_tac EAC \\
             asm_simp_tac (srw_ss()) [] \\ strip_tac \\ asm_simp_tac (srw_ss()) [IPR] \\ NO_TAC)];
(* X3 = L-CLK, OPTIONAL. REPAIRED (not explored): steps 1-5 of R6x-0001 reach the two printed goals (log 937-961):
   #1 ASM machine_sem mc ffi ms (Terminate Success io), EVERY P io;
   #2 ASM io_list <<= io, machine_sem mc ffi ms (Terminate Resource_limit_hit io_list), EVERY P io.
   New closing step: drule the stored X2 (no ASSUMEd theorem), then EVP with witness io. *)
val CLK = thmO "every_clock_events"
  ``!mc (ffi:'ffi ffi_state) ms io (P:io_event -> bool).
      targetSem$machine_sem mc ffi ms SUBSET semanticsProps$extend_with_resource_limit {Terminate Success io} /\
      EVERY P io ==>
      !j. EVERY P (SND (SND (targetSem$evaluate mc ffi j ms))).io_events``
  [rpt strip_tac \\ qspecl_then [`ffi`, `ms`, `mc`] strip_assume_tac (GEN_ALL MST)
     \\ `b IN semanticsProps$extend_with_resource_limit {Terminate Success io}` by fs [SUBD, IND]
     \\ pop_assum mp_tac \\ simp [EWRL] \\ strip_tac \\ rveq
     \\ drule CLKA \\ strip_tac
     \\ irule EVP \\ qexists_tac `io` \\ asm_simp_tac (srw_ss()) []
     \\ metis_tac [IPT],
   rpt strip_tac \\ qspecl_then [`ffi`, `ms`, `mc`] strip_assume_tac (GEN_ALL MST)
     \\ `b IN semanticsProps$extend_with_resource_limit {Terminate Success io}` by fs [SUBD, IND]
     \\ pop_assum mp_tac \\ simp [EWRL] \\ strip_tac \\ rveq
     \\ metis_tac [EVP, CLKA, IPT, IPR]];

(* ================= replay shortcut refuted (model level) ================= *)
val _ = pr "MARK REPLAY";
(* E_BAD: read with an EMPTY conf; C aborts (basis_ffi.c assert(clen == 8)); the model answers the error byte. *)
val E_BAD = ``IO_event (ExtCall «read») [] (ZIP ([0w;0w;0w;0w],[1w;0w;0w;0w]))``;
(* X4: steps intro / eval_replay (log 1023-1033) *)
val X4 = thmA "bad_read_event_replays_to_the_same_state"
  ``!ext cls fs. basis_ffi$extract_fs_with_numchars ext (cls,fs) [^E_BAD] = SOME (cls,fs)``
  [rpt gen_tac \\ simp [EFN, FFP, FREAD, LUPD]];
(* X6: step simp (log 1108) *)
val X6 = thmA "bad_read_event_is_not_valid" ``~refund_valid_event ^E_BAD`` [simp [RVE, N2W8]];
(* X6w: step simp (log 1128) *)
val X6w = thmA "bad_read_event_is_not_valid_w" ``~(^RVEW ^E_BAD)`` [simp [N2W8]];
(* X6c: steps unfold / subst / beta / write_case / read_case (log 1149-1274) *)
val X6c = thmA "refund_valid_event_implies_weak"
  ``!e. refund_valid_event e ==> ^RVEW e``
  [(simp [RVE] \\ rpt strip_tac) \\ rveq \\ TRY BETA_TAC
     \\ TRY (disj2_tac \\ qexistsl_tac [`ab`, `nb`] \\ asm_simp_tac (srw_ss()) [] \\ NO_TAC)
     \\ TRY (disj1_tac \\ qexistsl_tac [`ab`, `nb`] \\
             `?a0 a1 rest. ab = a0::a1::rest` by (Cases_on `ab` \\ fs [] \\ Cases_on `t` \\ fs []) \\
             rveq \\ fs [N2W2, W22N, DIM8, W2NN] \\ NO_TAC)];
(* X5, OPTIONAL. REPAIRED from the printed goal (log 1086-1098): the event there is simp-normal
   [(0w,1w); (0w,0w); (0w,0w); (0w,0w)], so the ZIP form of X4 did not match. X4N = X4 in simp-normal form. *)
val X4N = SIMP_RULE (srw_ss()) [] X4;
val _ = pr ("X4_SIMP_NORMAL " ^ thm_to_string X4N);
val X5o = thmO "extract_fs_ignores_bad_read_event"
  ``!ext cl fs io. basis_ffi$extract_fs ext (cl,fs) (io ++ [^E_BAD]) = basis_ffi$extract_fs ext (cl,fs) io``
  [rpt gen_tac \\ simp [EFD, EFA] \\ Cases_on `extract_fs_with_numchars ext (cl,fs) io` \\ simp []
     \\ rename1 `SOME stv` \\ PairCases_on `stv` \\ simp [X4N],
   rpt gen_tac \\ simp [EFD, EFA] \\ Cases_on `extract_fs_with_numchars ext (cl,fs) io` \\ simp []
     \\ rename1 `SOME stv` \\ PairCases_on `stv` \\ qexists_tac `(stv0, stv1)` \\ simp [X4N, X4]];
val REPLAY =
  case X5o of
    SOME X5 => thmA "replay_cannot_exclude_error_return_events"
      ``(!ext cl fs io. basis_ffi$extract_fs ext (cl,fs) (io ++ [^E_BAD]) = basis_ffi$extract_fs ext (cl,fs) io) /\
        ~refund_valid_event ^E_BAD /\ ~(^RVEW ^E_BAD)``
      [fwd (fn () => LIST_CONJ [X5, X6, X6w])]
  | NONE => thmA "replay_cannot_exclude_error_return_events"
      ``(!ext cls fs. basis_ffi$extract_fs_with_numchars ext (cls,fs) [^E_BAD] = SOME (cls,fs)) /\
        ~refund_valid_event ^E_BAD /\ ~(^RVEW ^E_BAD)``
      [fwd (fn () => LIST_CONJ [X4, X6, X6w])];
val _ = pr ("REPLAY_FORM " ^ (case X5o of SOME _ => "STRONG (extract_fs of io ++ [E_BAD] = extract_fs of io)"
                                         | NONE => "WEAK (one-event replay is the identity)"));

(* ================= three parts ================= *)
val _ = pr "MARK PARTS";
(* X7a: steps intro / cases_event / cases_name / simp (log 1288-1316) *)
val X7a = thmA "ffi_has_index_in_APPEND"
  ``!a b e. cfStore$ffi_has_index_in (a ++ b) e <=>
            cfStore$ffi_has_index_in a e \/ cfStore$ffi_has_index_in b e``
  [rpt gen_tac \\ namedCases_on `e` ["nm conf bs"] \\ Cases_on `nm` \\ simp [FHI, MEMA]];
(* X7: steps intro / induct / simp / strip / cases / close (log 1332-1426) *)
val X7 = thmA "every_of_three_parts"
  ``!(P:io_event -> bool) ns1 ns2 ns3 evs.
      EVERY (cfStore$ffi_has_index_in (ns1 ++ ns2 ++ ns3)) evs /\
      FILTER (cfStore$ffi_has_index_in ns1) evs = [] /\
      FILTER (cfStore$ffi_has_index_in ns3) evs = [] /\
      EVERY P (FILTER (cfStore$ffi_has_index_in ns2) evs) ==> EVERY P evs``
  [ntac 4 gen_tac \\ Induct \\ simp [] \\ rpt strip_tac
     \\ Cases_on `ffi_has_index_in ns1 h` \\ Cases_on `ffi_has_index_in ns3 h`
     \\ Cases_on `ffi_has_index_in ns2 h` \\ fs [X7a] \\ TRY (metis_tac [])];

(* ================= controls ================= *)
val _ = pr "MARK CONTROLS";
val _ = if has_const "refund_valid_event" (concl X6c) then pr "CONTROL_OK X6c mentions the stored refund_valid_event"
        else bad "X6c-scope";
val _ = if is_neg (concl X6) then pr "CONTROL_OK the bad event is rejected by refund_valid_event" else bad "X6-form";
val _ = (case CLK of SOME th =>
           if has_const "machine_sem" (concl th) andalso has_const "evaluate" (concl th)
           then pr "CONTROL_OK L-CLK stored (every_clock_events)" else bad "CLK-form"
         | NONE => pr "OPTIONAL_NOT_STORED every_clock_events");
(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = pr ("FAILED_LIST " ^ String.concatWith " " (rev (!failed)));
val _ = pr ("DIAG_OK_UNDER_LIST " ^ String.concatWith " " (rev (!diag)));
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = pr ("PARENTS " ^ String.concatWith " " (Theory.parents "forge_refundR6Base"));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundR6Base" @ DB.definitions "forge_refundR6Base");
val closure = "forge_refundR6Base" :: Theory.ancestry "forge_refundR6Base";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = if List.exists (fn n => n = "forge_refundRouteA2c") closure
        then pr "CONTROL_OK closure contains forge_refundRouteA2c" else raise Fail "parents missing";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundR6Base")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundR6Base")));
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
