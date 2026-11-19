(* L-EXIT-0 and the halt instance, v2 (worker Z6, graph link X10). DRAFT: NOT RUN. No HOL process was started.
   Needs the theory forge_refundLOut (L_OUT_v2.sml) in the deps: run it AFTER a passing L-OUT run.
   Kind: MODEL. What this file can give: at every Halt of the M1 machine run from the stored entry state,
   the PC is sl + 0x1000040C0w and (x0 = 0w, Success, fd1 bytes = R) or (x0 <> 0w, Resource_limit_hit,
   fd1 bytes a prefix of R). It does NOT give the value range of x0 (L-EXIT-V): see the OPEN block below.
   It says nothing about the real exit status: the native half (_cml_exit: cbz w0, exit(x0), status = low 8
   bits) is an ASSUMPTION, written here only as two definitions for the negative controls N-E1, N-E2.
   Exit status 0 is NOT evidence of complete output (N-E1: x0 = 0x100000000w gives status 0, no stderr line).
   Base: Y4 draft L_EXIT_DRAFT.sml. Changes:
   - evaluate_Halt_reg (Y4's statement; k moved to the front of the quantifier list only) gets a proof by
     complete induction on the clock; one alternative by the stored evaluate_ind;
   - refund_profile_a_sl_halt (Y4: NOT WRITTEN) is written; its premise is BUILT from the stored theorem;
   - N-E3 is written as a proved existence statement (Success with the halt register 0w).
   Stored items used: targetSem.evaluate_def (CK/compiler/backend/semantics/targetSemScript.sml 118-218),
   targetSem.machine_sem_def (220-232), targetSem.apply_oracle_def (52-55), lab_to_target.ffi_offset_def,
   forge_refundStartupBridge.refund_mc_fields (target = arm8_target, halt_pc = base - n2w ffi_offset),
   forge_refundSlideProfileA.refund_mc_register_fields_sl (ptr_reg = 0),
   forge_refundLOut.refund_profile_a_sl_fd1 (this mission, L_OUT_v2.sml), arm8_target.arm8_target_def. *)
open preamble targetSemTheory arm8_targetTheory lab_to_targetTheory wordsLib;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (500, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (2500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundLExit";
val failed = ref ([] : string list);
val problems = ref ([] : string list);
fun bad s = (pr ("UNEXPECTED_CONTROL_ACCEPTANCE " ^ s); problems := s :: !problems);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
fun thm name goalf tacf = (let val g = goalf () val th = save_thm (name, Tactical.TAC_PROOF (([], g), tacf ())) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
fun try_all name tacs =
  FIRST (map (fn t => t \\ NO_TAC) tacs)
  ORELSE (hd tacs \\ show_tac ("REMAINING " ^ name) \\ NO_TAC);
fun defn name q = (let val th = Define q in pr ("DEFINITION " ^ name ^ "\n" ^ thm_to_string th); th end)
  handle e => (pr ("DEFINITION_FAILED " ^ name ^ " " ^ General.exnMessage e); raise e);
val SPE = DB.fetch "forge_refundSlideProfileA" "refund_profile_a_sl_every_machine_run";
val REGF = DB.fetch "forge_refundSlideProfileA" "refund_mc_register_fields_sl";
val MCF = DB.fetch "forge_refundStartupBridge" "refund_mc_fields";
val FD1 = DB.fetch "forge_refundLOut" "refund_profile_a_sl_fd1";
val _ = List.app (fn (n, th) => pr ("USED " ^ n ^ "\n" ^ thm_to_string th))
  [("refund_mc_register_fields_sl", REGF), ("refund_mc_fields", MCF), ("refund_profile_a_sl_fd1", FD1)];
val tg = prove (``arm8_target.get_pc (ms:arm8_state) = ms.PC /\ arm8_target.get_reg ms r = ms.REG (n2w r)``,
  simp [arm8_target_def, FUN_EQ_THM]);

(* ================= L-EXIT-0, generic (any machine_config) ================= *)
val leaf_ih = first_x_assum (qspec_then `k - 1` mp_tac) \\ simp[] \\ disch_then drule \\ simp[];
val EHR = thm "evaluate_Halt_reg"
  (fn () => ``!k mc ffi ms t ms' ffi'.
       evaluate mc ffi k ms = (Halt t, ms', ffi') ==>
       (?e. t = FFI_outcome e) \/
       (mc.target.get_pc ms' = mc.halt_pc /\
        ((t = Success /\ mc.target.get_reg ms' mc.ptr_reg = 0w) \/
         (t = Resource_limit_hit /\ mc.target.get_reg ms' mc.ptr_reg <> 0w)))``)
  (fn () => try_all "evaluate_Halt_reg"
     [completeInduct_on `k` \\ rpt gen_tac
        \\ simp[Once targetSemTheory.evaluate_def, targetSemTheory.apply_oracle_def]
        \\ rpt ((IF_CASES_TAC ORELSE TOP_CASE_TAC) \\ simp[targetSemTheory.apply_oracle_def])
        \\ rpt strip_tac \\ gvs[]
        \\ TRY (leaf_ih \\ NO_TAC),
      completeInduct_on `k` \\ rpt gen_tac
        \\ simp[Once targetSemTheory.evaluate_def, targetSemTheory.apply_oracle_def]
        \\ rpt (IF_CASES_TAC \\ simp[targetSemTheory.apply_oracle_def])
        \\ rpt (TOP_CASE_TAC \\ simp[targetSemTheory.apply_oracle_def])
        \\ rpt strip_tac \\ gvs[] \\ TRY (leaf_ih \\ NO_TAC),
      completeInduct_on `k` \\ rpt gen_tac \\ strip_tac
        \\ qpat_x_assum `evaluate _ _ _ _ = _` mp_tac
        \\ simp[Once targetSemTheory.evaluate_def, targetSemTheory.apply_oracle_def, AllCaseEqs()]
        \\ rpt strip_tac \\ gvs[] \\ rpt (pairarg_tac \\ gvs[]) \\ TRY (leaf_ih \\ NO_TAC)]);

(* ================= instance at the M1 record ================= *)
val (PREM, _) = dest_imp (concl (SPEC_ALL SPE));
val R = find_term (fn t => (fst (dest_const (fst (strip_comb t))) = "refund_render_fields") handle _ => false) (concl SPE);
val HADDR = thm "refund_halt_address"
  (fn () => ``!sl:word64. sl + 0x1000040D0w - n2w ffi_offset = sl + 0x1000040C0w``)
  (fn () => try_all "refund_halt_address"
     [simp[lab_to_targetTheory.ffi_offset_def, wordsTheory.WORD_ADD_SUB_ASSOC] \\ EVAL_TAC,
      simp[lab_to_targetTheory.ffi_offset_def] \\ srw_tac[wordsLib.WORD_ARITH_ss][],
      simp[lab_to_targetTheory.ffi_offset_def] \\ blastLib.BBLAST_TAC]);
val HALT = thm "refund_profile_a_sl_halt"
  (fn () => ``^PREM ==>
     ?ms. (arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w) /\
       !k t ms' st'.
         evaluate (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi no_ext cl fs) k ms = (Halt t, ms', st') ==>
         ms'.PC = sl + 0x1000040C0w /\
         ((ms'.REG 0w = 0w /\ t = Success /\ fd1_written st'.io_events = explode ^R) \/
          (ms'.REG 0w <> 0w /\ t = Resource_limit_hit /\ fd1_written st'.io_events <<= explode ^R))``)
  (fn () => strip_tac
     \\ mp_tac FD1 \\ impl_tac >- simp[]
     \\ strip_tac \\ qexists_tac `ms` \\ simp[]
     \\ rpt gen_tac \\ strip_tac
     \\ `machine_sem (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi no_ext cl fs) ms (Terminate t st'.io_events)`
          by (simp[targetSemTheory.machine_sem_def] \\ metis_tac[])
     \\ qpat_x_assum `!b. _` drule \\ strip_tac
     \\ drule EHR \\ strip_tac
     \\ gvs[MCF, REGF, tg, HADDR]);

(* ================= L-EXIT-V: OPEN (statement only; NOT attempted; no theorem is claimed) ================= *)
val LEXITV = ``^PREM ==>
     ?ms. (arm8_run 27 s = SOME ms /\ ms.PC = sl + 0x1000040D0w) /\
       !k t ms' st'.
         evaluate (refund_mc (sl + 0x1000040D0w) envmc) (basis_ffi no_ext cl fs) k ms = (Halt t, ms', st') ==>
         ms'.REG 0w IN {0w; 1w; 2w}``;
val _ = pr ("OPEN_STATEMENT L-EXIT-V (type-checked only; not a theorem)\n" ^ term_to_string LEXITV);

(* ================= native half: an ASSUMPTION, as definitions only ================= *)
val st_def = defn "cml_exit_status" `cml_exit_status (x0:word64) = w2n ((w2w x0):word8)`;
val se_def = defn "cml_exit_stderr"
  `cml_exit_stderr (x0:word64) = if ((w2w x0):word32) = 0w then "" else "Program exited with nonzero exit code.\n"`;

(* ================= NEGATIVE CONTROLS ================= *)
(* N-E1: the native status map is not injective at 0: a model resource stop can give status 0. *)
val NE1 = thm "N_E1_status_collision"
  (fn () => ``cml_exit_status 256w = 0 /\ cml_exit_status 0x100000000w = 0 /\
              (256w:word64) <> 0w /\ (0x100000000w:word64) <> 0w``)
  (fn () => simp[st_def] \\ EVAL_TAC);
(* N-E2: x0 = 2^32 is also silent on stderr (cannot be told from Success by status or stderr). *)
val NE2 = thm "N_E2_silent_stop"
  (fn () => ``cml_exit_stderr 0x100000000w = "" /\ cml_exit_stderr 256w <> ""``)
  (fn () => simp[se_def] \\ EVAL_TAC);
(* N-E3: the swapped L-EXIT-0 (Success iff reg <> 0w) is refuted: Success happens with the register 0w. *)
val NE3 = thm "N_E3_success_with_zero_register"
  (fn () => ``!(ffi:'ffi ffi_state) (ms:'b) (x:'a word).
       ?(mc:('a,'b,'c) machine_config). mc.target.get_pc ms = mc.halt_pc /\ mc.target.get_reg ms mc.ptr_reg = 0w /\
          evaluate mc ffi 1 ms = (Halt Success, ms, ffi)``)
  (fn () => rpt gen_tac \\
     qexists_tac `(ARB:('a,'b,'c) machine_config) with
        <| prog_addresses := {}; ffi_entry_pcs := []; halt_pc := x;
           target := (ARB:('a,'b,'c) target) with <| get_pc := K x; get_reg := K (K 0w) |> |>` \\
     simp[Once targetSemTheory.evaluate_def]);

(* ================= checks ================= *)
val _ = pr "MARK CHECKS";
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = if aconv (fst (dest_imp (concl HALT))) PREM then pr "CONTROL_OK refund_profile_a_sl_halt premise is the stored premise term"
        else bad "HALT-premise";
val _ = if Lib.mem "LEXITV" (map fst (DB.thms "forge_refundLExit")) then bad "LEXITV-stored" else
          pr "CONTROL_OK L-EXIT-V is not stored as a theorem";
val _ = if null (!problems) then () else raise Fail ("problems: " ^ String.concatWith " " (rev (!problems)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundLExit" @ DB.definitions "forge_refundLExit");
val closure = "forge_refundLExit" :: Theory.ancestry "forge_refundLExit";
val axs = List.concat (map (fn n => map (fn (a, _) => n ^ "." ^ a) (DB.axioms n)) closure);
val _ = List.app (fn a => pr ("CLOSURE_AXIOM " ^ a)) axs;
val _ = if length axs = 4 then () else raise Fail "closure axioms are not the four of bool";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundLExit")));
val _ = pr ("STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions "forge_refundLExit")));
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
