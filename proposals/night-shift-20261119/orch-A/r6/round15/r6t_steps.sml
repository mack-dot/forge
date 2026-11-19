(* round15 (worker W-top2): ONLY the T4 IOFS_V_init step list changed (CHANGES.txt R15-C1). Nothing else changed.
   Candidate 0 of the new list ran and closed in R6tx-0003 (explore_head); the other candidates are UNCHECKED. *)
(* round14 (worker W-top): T1 PARTS_STEPS replaced and the PART_IN EVAL alternatives changed (CHANGES.txt C3, C4).
   Nothing else changed. UNCHECKED. *)
(* r6t_steps.sml (worker A36, round 11). The ONE file of step lists, read with use by BOTH R6tx-0001.sml (exploration)
   and R6t-0001.sml (proof). Needs r6t_common.sml (read before). Every tactic UNCHECKED (none of them ever ran).
   Method as round9: a step = (label, main, alternatives); exploration prints goals; the proof takes
   FIRST (main :: alternatives) on the head goal. Every alternative of a step leaves the SAME number of goals as the
   main tactic (a closing step closes; no step runs on zero goals). Quotations as Q "..." (ASCII only; no backquotes).
   Theorems of loaded theories are named with their theory prefix. Sources (file:line) are in r6t_common.sml. *)
open preamble cfLib basisFunctionsLib cfLetAutoLib;
open cfHeapsBaseTheory set_sepTheory cfMainTheory;
fun Q (s : string) : term quotation = [QUOTE s];
val _ = pr "R6T_STEPS opened";
fun closing (t : tactic) : tactic = t \\ NO_TAC;
type step = string * tactic * tactic list;

(* ================= (c) INITIAL HEAP ================= *)

(* T1 parts_ok_basis_ffi (round14, worker W-top). The round11 copy of the parts_ok tail of IMP_STDIO_general
   (basis_ffiScript.sml 887-904) is REMOVED: in R6tx-0001 (stdout 170-171) its step 2 ran > 6 min past the 240 s limit.
   New route, no copied proof: the STORED theorem basis_ffiTheory.parts_ok_basis_st (basis_ffiScript.sml 809-829;
   basis_ffiTheory.sig 45) says parts_ok (st).ffi (basis_proj1,basis_proj2) for st = the last TextIOProg state applied to
   (basis_ffi ext cls fs, po) (basis_ffiScript.sml 805-806). CakeML derives the basis_ffi form from it in
   compiler/repl/repl_initScript.sml 170-175 (Theorem parts_ok_basis_ffi: mp_tac basis_ffiTheory.parts_ok_basis_st
   \\ fs (DB.find "TextIOProg_st" |> map (#1 o #2))); repl_initTheory is not built in this toolchain, so the recipe is
   replayed here. Only the ffi term x of the stored fact is rewritten (x = basis_ffi ext cls fs, checked with aconv), then
   EQ_MP gives parts_ok (basis_ffi ext cls fs) (basis_proj1,basis_proj2); GEN_ALL closes it. No EVAL of the oracle. *)
fun is_basis_ffi_app (t : term) : bool =
  (case strip_comb t of
     (c, [_, _, _]) => is_const c andalso fst (dest_const c) = "basis_ffi"
   | _ => false);
(* pobs_from eqf: eqf x bf must prove x = bf; x = the ffi term of the stored fact, bf = its basis_ffi subterm *)
fun pobs_from (tag : string) (eqf : term -> term -> thm) : thm =
  let
    val th = SPEC_ALL basis_ffiTheory.parts_ok_basis_st
    val (f, args) = strip_comb (concl th)
    val (x, p) = (case args of [a, b] => (a, b)
                               | _ => raise mk_HOL_ERR "r6t_steps" "pobs_from" "not parts_ok x p")
    val bf = find_term is_basis_ffi_app x
    val eq = eqf x bf
    val _ = if aconv (concl eq) (mk_eq (x, bf)) then ()
            else raise mk_HOL_ERR "r6t_steps" "pobs_from"
                       (tag ^ " gave " ^ trunc 400 (term_to_string (rhs (concl eq))))
    val th2 = EQ_MP (AP_THM (AP_TERM f eq) p) th
    val _ = pr ("PARTS_STORED_FACT " ^ tag ^ " " ^ trunc 600 (term_to_string (concl th2)))
  in GEN_ALL th2 end;
fun defs_named (s : string) : thm list =
  map (#1 o #2) (List.filter (fn ((_, n), _) => String.isSuffix "_def" n) (DB.find s));
fun eq_by_simp (s : string) (x : term) (_ : term) : thm =
  let val ds = defs_named s
  in pr ("PARTS_DEFS " ^ s ^ " " ^ Int.toString (length ds)); SIMP_CONV (srw_ss ()) ds x end;
fun eq_by_restr_eval (x : term) (_ : term) : thm =
  computeLib.RESTR_EVAL_CONV [prim_mk_const {Thy = "basis_ffi", Name = "basis_ffi"},
                              prim_mk_const {Thy = "basis_ffi", Name = "basis_ffi_oracle"}] x;
val PARTS_STEPS : step list =
  [("intro", rpt strip_tac \\ fs [], []),
   ("stored parts_ok_basis_st (repl_initScript.sml 170-175 recipe)",
      LATE (fn () => assume_tac (pobs_from "simp TextIOProg_st defs" (eq_by_simp "TextIOProg_st"))),
      [LATE (fn () => assume_tac (pobs_from "RESTR_EVAL" eq_by_restr_eval)),
       LATE (fn () => assume_tac (pobs_from "simp Prog_st defs" (eq_by_simp "Prog_st")))]),
   ("close by the stored fact",
      closing (TRY (qpat_x_assum (Q "_ = basis_ffi _ _ _") SUBST1_TAC) \\ first_x_assum MATCH_ACCEPT_TAC),
      [closing (rfs []),
       closing (metis_tac [])])];

(* round14: EVAL with the FFI oracle and parts_ok kept folded (computeLib.RESTR_EVAL_TAC, computeLib.sig 47-49).
   Reason: fsFFI nextFD_def (fsFFIScript.sml 121-122) is LEAST n. ..., so a symbolic EVAL of the oracle (ffi_open_in,
   ffi_open_out) can unfold WHILE without end. Built at run time (LATE). *)
fun SAFE_EVAL_TAC () : tactic =
  computeLib.RESTR_EVAL_TAC [prim_mk_const {Thy = "basis_ffi", Name = "basis_ffi_oracle"},
                             prim_mk_const {Thy = "cfStore", Name = "parts_ok"}];

(* T2 init_fs_part_IN / init_cl_part_IN / init_rt_part_IN: one shared step list.
   The close step is the membership part of IMP_STDIO_general (basis_ffiScript.sml 925-933). *)
val PART_IN_STEPS : step list =
  [("intro + parts_ok", rpt strip_tac \\ LATE (fn () => imp_res_tac (TH "parts_ok_basis_ffi")) \\ fs [], []),
   ("unfold st2heap/ffi2heap",
      simp [cfStoreTheory.st2heap_def, cfStoreTheory.ffi2heap_def, cfStoreTheory.FFI_part_NOT_IN_store2heap],
      [fs [cfStoreTheory.st2heap_def, cfStoreTheory.ffi2heap_def, cfStoreTheory.FFI_part_NOT_IN_store2heap],
       simp [cfStoreTheory.st2heap_def, cfStoreTheory.ffi2heap_def, cfStoreTheory.FFI_part_NOT_IN_store2heap,
             pred_setTheory.GSPECIFICATION, pairTheory.EXISTS_PROD]]),
   ("close (925-933)",
      closing (gvs [SF DNF_ss, basis_ffiTheory.basis_proj1_def, basis_ffiTheory.basis_ffi_def,
                    alistTheory.flookup_fupdate_list, basis_ffiTheory.basis_proj2_def,
                    cfHeapsBaseTheory.mk_proj2_def, cfHeapsBaseTheory.mk_proj1_def, clFFITheory.cl_ffi_part_def,
                    fsFFITheory.fs_ffi_part_def, runtimeFFITheory.runtime_ffi_part_def]),
      (* round14: each EVAL alternative first uses the assumptions (rfs []), and evaluates with the oracle and parts_ok
         NOT unfolded (SAFE_EVAL_TAC), so that no symbolic run of the FFI oracle is started (CHANGES.txt C4) *)
      [closing (rfs [] \\ simp [basis_ffiTheory.basis_ffi_def] \\ LATE SAFE_EVAL_TAC),
       closing (rfs [] \\ rw [] \\ LATE SAFE_EVAL_TAC),
       closing (rfs [] \\
                simp [basis_ffiTheory.basis_ffi_def, basis_ffiTheory.basis_proj2_def, cfHeapsBaseTheory.mk_proj2_def,
                      clFFITheory.cl_ffi_part_def, fsFFITheory.fs_ffi_part_def,
                      runtimeFFITheory.runtime_ffi_part_def] \\ rw [] \\ LATE SAFE_EVAL_TAC)])];

(* T3 init_iobuff_IN (store2heap_aux_def, cfStoreScript.sml 14-17) *)
val IOB_STEPS : step list =
  [("close", closing (rw [cfStoreTheory.st2heap_def, cfStoreTheory.store2heap_def, cfStoreTheory.store2heap_aux_def]),
      [closing (simp [cfStoreTheory.st2heap_def, cfStoreTheory.store2heap_def, cfStoreTheory.store2heap_aux_def]),
       closing (rpt strip_tac \\ fs [cfStoreTheory.st2heap_def, cfStoreTheory.store2heap_def,
                                     cfStoreTheory.store2heap_aux_def])])];

(* T4 IOFS_V_init. Main: the heap is (one X * W8ARRAY iobuff_loc v) by append_hprop (basis_ffiScript.sml 485-489),
   and that hprop implies IOFS_V Inv fs by xsimpl. Alternative of step 2: the IOFS_precond proof (495-505) adapted. *)
val XFS_EV = "FFI_part (fsFFI$encode fs) (mk_ffi_next fs_ffi_part) (MAP FST (SND (SND fs_ffi_part))) events";
val HEAP_Q = "(one (" ^ XFS_EV ^ ") * W8ARRAY iobuff_loc v) ({" ^ XFS_EV ^ "} UNION {Mem 1 (W8array v)})";
val IMP_Q = "one (" ^ XFS_EV ^ ") * W8ARRAY iobuff_loc v ==>> IOFS_V Inv fs";
val W8_SIMPS = [set_sepTheory.one_def, cfHeapsBaseTheory.W8ARRAY_def, cfHeapsBaseTheory.cell_def,
                basis_ffiTheory.iobuff_loc_eq, set_sepTheory.SEP_EXISTS_THM, set_sepTheory.cond_STAR];
(* the IOFS_precond copy, kept for exploration only (run as a separate tactic in r6t_explore_calls.sml) *)
val IOFSI_PRECOND_COPY : tactic =
  rpt strip_tac
  \\ rw [IOFS_V_def, IOxV_def, fsFFITheory.fs_ffi_part_def, set_sepTheory.one_def, cfHeapsBaseTheory.W8ARRAY_def,
         cfHeapsBaseTheory.cell_def]
  \\ rw [set_sepTheory.SEP_EXISTS_THM, set_sepTheory.cond_STAR, set_sepTheory.SEP_CLAUSES, basis_ffiTheory.iobuff_loc_eq]
  \\ qexists_tac (Q "events") \\ qexists_tac (Q "v") \\ qexists_tac (Q "1")
  \\ fs [set_sepTheory.SEP_CLAUSES, set_sepTheory.one_STAR, set_sepTheory.one_def, basis_ffiTheory.append_hprop];
(* round15 (worker W-top2): IOFSI_STEPS REPLACED and moved below IOFSI_PRECOND_COPY (it now uses that value).
   Reason (R6tx-0003 stdout 308-330): step 3 "SEP_IMP by xsimpl" failed with all four candidates (the by-subgoal
   one X * W8ARRAY iobuff_loc v ==>> IOFS_V Inv fs was not closed by xsimpl + simp/EVAL), while the SAME statement
   was closed by IOFSI_PRECOND_COPY in one step (R6tx-0003 stdout 1078-1094: EXPLORE_HEAD_CLOSED after_steps 1).
   New list: ONE closing step from the original goal. Candidate 0 = IOFSI_PRECOND_COPY (the observed closing path).
   Candidates 1-3 = a structured route without xsimpl: unfold IOFS_V only, peel &wfFS fs with cond_STAR, split the
   heap with append_hprop (basis_ffiScript.sml 485-489), then each part (IOxV on {X}, the iobuff cell on {Mem 1 ..},
   DISJOINT) by simp with the definitions (same lemma set that closed old step 2, plus IOxV_def and fs_ffi_part_def).
   Every candidate is a closing tactic (0 goals out). Candidates 1-3 are UNCHECKED. *)
fun iofsi_split (useirule : bool) : tactic =
  rpt strip_tac
  \\ REWRITE_TAC [IOFS_V_def, set_sepTheory.cond_STAR]
  \\ (conj_tac THEN1 first_assum ACCEPT_TAC)
  \\ (if useirule then irule basis_ffiTheory.append_hprop
      else match_mp_tac (REWRITE_RULE [AND_IMP_INTRO] basis_ffiTheory.append_hprop))
  \\ rpt conj_tac;
val IOFSI_PART_SIMPS = [IOxV_def, set_sepTheory.SEP_EXISTS_THM, set_sepTheory.cond_STAR, set_sepTheory.one_def,
                        cfHeapsBaseTheory.W8ARRAY_def, cfHeapsBaseTheory.cell_def, basis_ffiTheory.iobuff_loc_eq,
                        fsFFITheory.fs_ffi_part_def];
val IOFSI_STEPS : step list =
  [("all (IOFS_precond copy, basis_ffiScript.sml 495-505; closed in R6tx-0003 explore_head)",
      closing IOFSI_PRECOND_COPY,
      [closing (iofsi_split true \\ simp IOFSI_PART_SIMPS),
       closing (iofsi_split false \\ fs IOFSI_PART_SIMPS),
       closing (iofsi_split true \\ simp (PULL_EXISTS :: IOFSI_PART_SIMPS) \\
                TRY (qexists_tac (Q "events")) \\ simp [fsFFITheory.fs_ffi_part_def] \\ EVAL_TAC)])];

(* T5 STDIO_V_of_IOFS_V *)
val STDOF_STEPS : step list =
  [("close", closing (rpt strip_tac \\ simp [STDIO_V_def, set_sepTheory.cond_STAR, set_sepTheory.SEP_EXISTS_THM] \\
                      qexists_tac (Q "fs.numchars") \\ simp [fsFFITheory.with_same_numchars]),
      [closing (rw [STDIO_V_def, set_sepTheory.cond_STAR, set_sepTheory.SEP_EXISTS_THM] \\
                metis_tac [fsFFITheory.with_same_numchars]),
       closing (rpt strip_tac \\ fs [STDIO_V_def, set_sepTheory.cond_STAR, set_sepTheory.SEP_EXISTS_THM] \\
                qexists_tac (Q "fs.numchars") \\ fs [fsFFITheory.with_same_numchars])])];

(* T6 init_heap_V = deliverable (c). h1 = {fs part with []} UNION {iobuff cell}; h2 = the rest of st2heap. *)
val H1_Q = "{FFI_part (fsFFI$encode fs) (mk_ffi_next fs_ffi_part) (MAP FST (SND (SND fs_ffi_part))) []} UNION " ^
           "{Mem 1 (W8array bs2)}";
fun not_in_h1 () : tactic =
  simp [pred_setTheory.IN_DIFF] \\
  simp [clFFITheory.cl_ffi_part_def, fsFFITheory.fs_ffi_part_def, runtimeFFITheory.runtime_ffi_part_def];
fun not_in_h1_alt () : tactic =
  fs [pred_setTheory.IN_DIFF, pred_setTheory.IN_UNION, pred_setTheory.IN_SING, clFFITheory.cl_ffi_part_def,
      fsFFITheory.fs_ffi_part_def, runtimeFFITheory.runtime_ffi_part_def];
val INITH_STEPS : step list =
  [("intro", rpt strip_tac, []),
   ("facts",
      LATE (fn () => imp_res_tac (TH "init_fs_part_IN")) \\ LATE (fn () => imp_res_tac (TH "init_cl_part_IN")) \\
      LATE (fn () => imp_res_tac (TH "init_rt_part_IN")) \\ LATE (fn () => imp_res_tac (TH "init_iobuff_IN")), []),
   ("witness", qexists_tac (Q H1_Q) \\
               qexists_tac (Q ("cfStore$st2heap (basis_proj1,basis_proj2) st DIFF (" ^ H1_Q ^ ")")), []),
   ("conj", rpt conj_tac, []),
   ("SPLIT", closing cfHeapsBaseLib.SPLIT_TAC,
      [closing (rw [set_sepTheory.SPLIT_def, pred_setTheory.EXTENSION, pred_setTheory.IN_DISJOINT] \\ metis_tac []),
       closing (simp [set_sepTheory.SPLIT_def, pred_setTheory.EXTENSION, pred_setTheory.IN_DISJOINT,
                      pred_setTheory.IN_UNION, pred_setTheory.IN_DIFF] \\ metis_tac [])]),
   ("STDIO_V h1",
      closing (LATE (fn () => irule (TH "STDIO_V_of_IOFS_V")) \\ rpt conj_tac \\ TRY (first_assum ACCEPT_TAC) \\
               LATE (fn () => irule (TH "IOFS_V_init")) \\ simp []),
      [closing (LATE (fn () => match_mp_tac (TH "STDIO_V_of_IOFS_V")) \\ conj_tac \\ TRY (first_assum ACCEPT_TAC) \\
                LATE (fn () => match_mp_tac (TH "IOFS_V_init")) \\ simp []),
       closing (LATE (fn () => metis_tac [TH "STDIO_V_of_IOFS_V", TH "IOFS_V_init", listTheory.EVERY_DEF]))]),
   ("cl part in h2", closing (LATE not_in_h1), [closing (LATE not_in_h1_alt)]),
   ("rt part in h2", closing (LATE not_in_h1), [closing (LATE not_in_h1_alt)])];

(* ================= (d) EVENT LINK ================= *)

(* D1 FFI_part_IN_st2heap_FILTER; alternative = cfDivScript.sml 3751-3754 adapted *)
val FILT_STEPS : step list =
  [("pair", rpt gen_tac \\ PairCases_on (Q "p"), []),
   ("close",
      closing (strip_tac \\ fs [cfStoreTheory.st2heap_def, cfStoreTheory.FFI_part_NOT_IN_store2heap] \\
               pop_assum mp_tac \\ simp [cfStoreTheory.ffi2heap_def] \\ IF_CASES_TAC \\ simp [] \\ rw [] \\ fs []),
      [closing (strip_tac \\ fs [cfStoreTheory.st2heap_def, cfStoreTheory.FFI_part_NOT_IN_store2heap,
                                 cfStoreTheory.ffi2heap_def] \\
                Cases_on (Q "parts_ok st.ffi (p0,p1)") \\ fs []),
       closing (rw [cfStoreTheory.st2heap_def] \\
                fs [cfStoreTheory.FFI_part_NOT_IN_store2heap, cfStoreTheory.ffi2heap_def] \\
                Cases_on (Q "parts_ok st.ffi (p0,p1)") \\ fs [])])];

(* D2 basis_proj2_names *)
val NAMES_STEPS : step list =
  [("close", closing EVAL_TAC,
      [closing (simp [basis_ffiTheory.basis_proj2_def, cfHeapsBaseTheory.mk_proj2_def, clFFITheory.cl_ffi_part_def,
                      fsFFITheory.fs_ffi_part_def, runtimeFFITheory.runtime_ffi_part_def]),
       closing (rw [basis_ffiTheory.basis_proj2_def, cfHeapsBaseTheory.mk_proj2_def, clFFITheory.cl_ffi_part_def,
                    fsFFITheory.fs_ffi_part_def, runtimeFFITheory.runtime_ffi_part_def] \\ EVAL_TAC)])];

(* D3 every_basis_events: parts_ok gives EVERY ffi_has_index_in of all names (parts_ok_def, cfStoreScript.sml 29-47);
   then every_of_three_parts (forge_refundR6Base) *)
val ALLN_Q = "EVERY (cfStore$ffi_has_index_in ((MAP FST (SND (SND cl_ffi_part))) ++ " ^
             "(MAP FST (SND (SND fs_ffi_part))) ++ (MAP FST (SND (SND runtime_ffi_part))))) f.io_events";
val EVB_STEPS : step list =
  [("intro", rpt strip_tac, []),
   ("all names",
      Q ALLN_Q by (qpat_x_assum (Q "parts_ok _ _") mp_tac \\
                   LATE (fn () => simp [cfStoreTheory.parts_ok_def, TH "basis_proj2_names"])),
      [Q ALLN_Q by (fs [cfStoreTheory.parts_ok_def] \\ LATE (fn () => fs [TH "basis_proj2_names"])),
       Q ALLN_Q by (LATE (fn () => metis_tac [cfStoreTheory.parts_ok_def, TH "basis_proj2_names"]))]),
   ("three parts", closing (metis_tac [EOTP_TH]),
      [closing (irule EOTP_TH \\ metis_tac []),
       closing (match_mp_tac EOTP_TH \\ qexists_tac (Q "MAP FST (SND (SND cl_ffi_part))") \\
                qexists_tac (Q "MAP FST (SND (SND fs_ffi_part))") \\
                qexists_tac (Q "MAP FST (SND (SND runtime_ffi_part))") \\ fs [])])];

(* D5 sem_satisfies_imp_V (basis_ffiScript.sml 569-575, proof copied) *)
val SEMIMP_STEPS : step list =
  [("close", closing (rw [semanticsPropsTheory.sem_satisfies_def] \\ res_tac),
      [closing (fs [semanticsPropsTheory.sem_satisfies_def] \\ metis_tac []),
       closing (rpt strip_tac \\ fs [semanticsPropsTheory.sem_satisfies_def] \\ rw [] \\ res_tac \\ fs [])])];

(* D0 STDIO_V_FFI_part_hprop (pattern of basis_ffiScript.sml 600-608) *)
val SHPROP_STEPS : step list =
  [("close", closing (rw [STDIO_V_def] \\ match_mp_tac cfMainTheory.FFI_part_hprop_STAR \\ disj1_tac \\
                      ho_match_mp_tac cfMainTheory.FFI_part_hprop_SEP_EXISTS \\ metis_tac [IOFS_V_HPROP_TH]),
      [closing (rw [STDIO_V_def, cfMainTheory.FFI_part_hprop_def, set_sepTheory.cond_STAR,
                    set_sepTheory.SEP_EXISTS_THM] \\
                metis_tac [IOFS_V_HPROP_TH, cfMainTheory.FFI_part_hprop_def]),
       closing (simp [cfMainTheory.FFI_part_hprop_def, STDIO_V_def, set_sepTheory.cond_STAR,
                      set_sepTheory.SEP_EXISTS_THM, PULL_EXISTS] \\ rpt strip_tac \\
                mp_tac IOFS_V_HPROP_TH \\ simp [cfMainTheory.FFI_part_hprop_def] \\ metis_tac [])])];

(* IOxV_events_IN: the closed candidate of IOxV_FFI_part_IN (R6w-0004 stdout 225: candidate 0) plus cond_STAR *)
val IOXEV_STEPS : step list =
  [("close", closing (rw [IOxV_def, set_sepTheory.SEP_CLAUSES, set_sepTheory.SEP_EXISTS_THM,
                          GSYM set_sepTheory.STAR_ASSOC, set_sepTheory.one_STAR, set_sepTheory.cond_STAR] \\
                      metis_tac []),
      [closing (fs [IOxV_def, set_sepTheory.SEP_CLAUSES, set_sepTheory.SEP_EXISTS_THM] \\
                fs [GSYM set_sepTheory.STAR_ASSOC, set_sepTheory.one_STAR, set_sepTheory.cond_STAR] \\ metis_tac []),
       closing (rw [IOxV_def, set_sepTheory.SEP_CLAUSES, set_sepTheory.SEP_EXISTS_THM] \\
                fs [set_sepTheory.STAR_def, set_sepTheory.one_def, set_sepTheory.cond_def, set_sepTheory.SPLIT_def] \\
                rw [] \\ metis_tac [pred_setTheory.IN_UNION, pred_setTheory.IN_SING])])];

(* STDIO_V_events *)
val SEV_STEPS : step list =
  [("unfold", simp [STDIO_V_def, IOFS_V_def, set_sepTheory.cond_STAR, set_sepTheory.SEP_EXISTS_THM, PULL_EXISTS] \\
              rpt strip_tac,
      [fs [STDIO_V_def, IOFS_V_def, set_sepTheory.cond_STAR, set_sepTheory.SEP_EXISTS_THM, PULL_EXISTS] \\
       rpt strip_tac]),
   ("events", closing (LATE (fn () => imp_res_tac (TH "IOxV_events_IN")) \\ metis_tac []),
      [closing (LATE (fn () => metis_tac [TH "IOxV_events_IN"])),
       closing (LATE (fn () => drule (TH "IOxV_events_IN")) \\ strip_tac \\ metis_tac [])])];

(* D6 final_heap_events *)
val SUB_Q = "h3 SUBSET cfStore$st2heap (basis_proj1,basis_proj2) st3 /\\ " ^
            "h2 SUBSET cfStore$st2heap (basis_proj1,basis_proj2) st3";
val FINAL_STEPS : step list =
  [("intro + STDIO_V_events",
      rpt strip_tac \\ LATE (fn () => first_x_assum (strip_assume_tac o MATCH_MP (TH "STDIO_V_events"))),
      [rpt strip_tac \\ LATE (fn () => imp_res_tac (TH "STDIO_V_events")) \\ fs []]),
   ("subsets",
      Q SUB_Q by (fs [cfHeapsBaseTheory.SPLIT3_def] \\ cfHeapsBaseLib.SPLIT_TAC),
      [Q SUB_Q by cfHeapsBaseLib.SPLIT_TAC,
       Q SUB_Q by (fs [cfHeapsBaseTheory.SPLIT3_def, pred_setTheory.SUBSET_DEF, pred_setTheory.EXTENSION,
                       pred_setTheory.IN_UNION] \\ metis_tac [])]),
   ("members", fs [pred_setTheory.SUBSET_DEF] \\ res_tac, [imp_res_tac pred_setTheory.SUBSET_DEF]),
   ("FILTER facts", LATE (fn () => imp_res_tac (TH "FFI_part_IN_st2heap_FILTER")) \\ fs [], []),
   ("every_basis_events",
      closing (LATE (fn () => irule (TH "every_basis_events")) \\ fs []),
      [closing (LATE (fn () => metis_tac [TH "every_basis_events"])),
       closing (LATE (fn () => match_mp_tac (TH "every_basis_events")) \\ rfs [])])];

(* D4 whole_prog_spec_V_events = deliverable (d). Steps of whole_prog_spec2_semantics_prog (basis_ffiScript.sml
   597-631) up to sem_satisfies_imp; then final_heap_events instead of the extract_fs part. *)
val MAINV_STEPS : step list =
  [("intro + hprop",
      rpt strip_tac \\ LATE (fn () => qspecl_then [Q "Inv", Q "fs'"] assume_tac (TH "STDIO_V_FFI_part_hprop")), []),
   ("call_main_thm2 (cfMainScript.sml 260-285)",
      drule_all (GEN_ALL cfMainTheory.call_main_thm2) \\ strip_tac,
      [drule (GEN_ALL cfMainTheory.call_main_thm2) \\ rpt (disch_then drule) \\ strip_tac,
       drule (GEN_ALL cfMainTheory.call_main_thm2) \\ rpt (disch_then drule) \\
       disch_then (qspecl_then [Q "h2", Q "h1"] mp_tac) \\ simp [] \\ strip_tac,
       drule (GEN_ALL cfMainTheory.call_main_thm2) \\ rpt (disch_then drule) \\
       disch_then (qspecl_then [Q "h1", Q "h2"] mp_tac) \\ simp [] \\ strip_tac]),
   ("sem_satisfies_imp_V",
      LATE (fn () => drule (TH "sem_satisfies_imp_V")) \\ disch_then match_mp_tac \\ rw [],
      [LATE (fn () => drule (TH "sem_satisfies_imp_V")) \\ disch_then match_mp_tac \\ rpt strip_tac \\ fs []]),
   ("final_heap_events",
      closing (LATE (fn () => metis_tac [TH "final_heap_events"])),
      [closing (LATE (fn () => irule (TH "final_heap_events")) \\ metis_tac []),
       closing (LATE (fn () => drule_all (TH "final_heap_events")) \\ simp [])])];

(* T7 whole_prog_spec_V_init (composite, optional) *)
val INITV_STEPS : step list =
  [("intro", rpt strip_tac, []),
   ("init_heap_V",
      LATE (fn () => qspecl_then [Q "Inv", Q "st2", Q "ext", Q "cl", Q "fs", Q "bs1", Q "bs2", Q "rest"] mp_tac
                       (TH "init_heap_V")) \\ simp [] \\ rpt strip_tac,
      [LATE (fn () => qspecl_then [Q "Inv", Q "st2", Q "ext", Q "cl", Q "fs", Q "bs1", Q "bs2", Q "rest"] mp_tac
                        (TH "init_heap_V")) \\ (impl_tac >- simp []) \\ rpt strip_tac]),
   ("whole_prog_spec_V_events",
      closing (LATE (fn () => drule_all (TH "whole_prog_spec_V_events")) \\ simp []),
      [closing (LATE (fn () => irule (TH "whole_prog_spec_V_events")) \\ metis_tac []),
       closing (LATE (fn () => metis_tac [TH "whole_prog_spec_V_events"]))])];

(* ================= the lemma list (order = dependency order; true = required) ================= *)
val R6T_LEMMAS : (string * term * step list * bool) list =
  [("parts_ok_basis_ffi", PARTS, PARTS_STEPS, true),
   ("init_fs_part_IN", FSIN, PART_IN_STEPS, true),
   ("init_cl_part_IN", CLIN, PART_IN_STEPS, true),
   ("init_rt_part_IN", RTIN, PART_IN_STEPS, true),
   ("init_iobuff_IN", IOBIN, IOB_STEPS, true),
   ("IOFS_V_init", IOFSI, IOFSI_STEPS, true),
   ("STDIO_V_of_IOFS_V", STDOF, STDOF_STEPS, true),
   ("init_heap_V", INITH, INITH_STEPS, true),
   ("FFI_part_IN_st2heap_FILTER", FILT, FILT_STEPS, true),
   ("basis_proj2_names", NAMES, NAMES_STEPS, true),
   ("every_basis_events", EVB, EVB_STEPS, true),
   ("sem_satisfies_imp_V", SEMIMP, SEMIMP_STEPS, true),
   ("STDIO_V_FFI_part_hprop", SHPROP, SHPROP_STEPS, true),
   ("IOxV_events_IN", IOXEV, IOXEV_STEPS, true),
   ("STDIO_V_events", SEV, SEV_STEPS, true),
   ("final_heap_events", FINAL, FINAL_STEPS, true),
   ("whole_prog_spec_V_events", MAINV, MAINV_STEPS, true),
   ("whole_prog_spec_V_init", INITV, INITV_STEPS, false)];
val _ = pr "R6T_STEPS loaded";
