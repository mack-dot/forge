(* Fresh import of the exact-program exclusion theories: exact statements, tags, closure, controls. *)
open preamble backendTheory labSemTheory labLangTheory labPropsTheory lab_filterTheory targetSemTheory targetPropsTheory lab_to_targetProofTheory
     forge_targetInstallPrefixTheory forge_simZeroCaseTheory forge_simRootTheory forge_simReplayTheory
     forge_refundLabFilteredTheory forge_refundExactExclusionTheory forge_refundExclusionChainTheory
     forge_installHandlerIrrelevantTheory forge_refundExclusionFinalTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = List.app (fn c => (let val {Name,Thy,...} = dest_thy_const c in Parse.temp_remove_ovl_mapping Name {Name=Name,Thy=Thy} end handle _ => ()))
          (Theory.constants "backend_asm");
val _ = List.app (fn n => (Parse.hide n; ())) ["code", "data", "ffis", "conf", "info", "name"];
fun same a b =
  let fun ok x y = let val (ts, _) = match_term x y in
        List.all (fn {redex, residue} => is_var residue andalso fst (dest_var redex) = fst (dest_var residue)) ts end
  in aconv a b orelse ((ok a b andalso ok b a) handle HOL_ERR _ => false) end;
val L = ``SND (SND (backend$to_lab arm8_config (set_oracle arm8_backend_config refund_alloc_oracle) refund_prog))``;
val F = ``filter_skip ^L``;
val pub_premises = ``mc_conf_ok (mc_conf:(64,'state,'b) machine_config) /\
  (no_share_mem_inst ^L ==> compiler_oracle_ok coracle c'.labels (LENGTH bytes) (asm_conf:asm_config) mc_conf.ffi_names) /\
  good_code mc_conf.target.config LN ^L /\
  asm_conf = mc_conf.target.config /\ c.labels = LN /\ c.pos = 0 /\
  lab_to_target$compile asm_conf (c:lab_to_target$config) ^L = SOME (bytes,c') /\
  c'.ffi_names = SOME mc_conf.ffi_names /\
  good_init_state mc_conf ms bytes cbspace t m dm sdm /\
  MAP (\rec. w2n (mc_conf.target.get_pc ms) + rec.entry_pc) c'.shmem_extra = DROP i (MAP w2n mc_conf.ffi_entry_pcs) /\
  mc_conf.mmio_info = ZIP (GENLIST (\index. index + i) (LENGTH c'.shmem_extra),
                            (MAP (\rec. (rec.nbytes, Addr rec.addr_reg rec.addr_off, rec.reg, n2w rec.exit_pc + mc_conf.target.get_pc ms)) c'.shmem_extra)) /\
  no_install_or_no_share_mem ^L mc_conf.ffi_names /\
  (mmio_pcs_min_index mc_conf.ffi_names = SOME i) /\
  cbspace + LENGTH bytes + ffi_offset * (i + 3) < dimword (:64) /\
  (!ffis. c.ffi_names = SOME ffis ==> EVERY (\x. ?s. x = ExtCall s) ffis) /\
  labSem$semantics (make_init mc_conf (ffi:'ffi ffi_state) t m dm sdm ms ^L (lab_to_target$compile asm_conf)
     (mc_conf.target.get_pc ms + n2w (LENGTH bytes)) cbspace coracle) <> Fail``;
val exact_expected = mk_imp (pub_premises, ``!n. no_install_prefix (mc_conf:(64,'state,'b) machine_config) (ffi:'ffi ffi_state) n ms``);
val final_expected = mk_imp (mk_conj (``same_but_install mc (mc_conf:(64,'state,'b) machine_config)``, pub_premises),
   ``(!j ms' ffi'. targetSem$evaluate (mc:(64,'state,'b) machine_config) (ffi:'ffi ffi_state) j ms = (TimeOut,ms',ffi') ==> mc.target.get_pc ms' <> mc.install_pc) /\
     (!k. targetSem$evaluate mc ffi k ms = targetSem$evaluate (mc_conf:(64,'state,'b) machine_config) ffi k ms)``);
val expected = [
 ("forge_refundExactExclusion", "refund_lab_sharemem_counts",
    ``sm_count ^L = 0 /\ sm_secs ^L = [] /\ sm_free ^L /\ line_count ^L = 33749 /\
      sm_count ^F = 0 /\ sm_free ^F /\ line_count ^F = 33735 /\ lab_stats ^F = (558,[29],553,1206,[29;31])``),
 ("forge_refundExactExclusion", "refund_lab_no_share_mem", ``no_share_mem_inst ^L /\ no_share_mem_inst ^F``),
 ("forge_refundExactExclusion", "region2_lab_step",
    ``!s s'. region_inv2 G D OK lcode s /\ no_share_mem_inst lcode /\ lab_step s = SOME s' ==> region_inv2 G D OK lcode s'``),
 ("forge_refundExactExclusion", "refund_lab_step_closed", ``lab_step_closed (refund_lab_inv : (64,'c,'ffi) labSem$state -> bool)``),
 ("forge_refundExactExclusion", "refund_lab_inv_init",
    ``good_init_state mc0 ms0 bytes0 cbs0 t0 (m:word64 -> 64 word_loc) dm0 sdm0 ==>
      !k. refund_lab_inv (make_init mc0 ffi0 t0 m dm1 sdm1 ms0 ^F cmp0 cbpos0 cbspace0 coracle0 with clock := k)``),
 ("forge_refundExactExclusion", "trivial_invariant_not_closed", ``~lab_step_closed (\s:(64,'c,'ffi) labSem$state. T)``),
 ("forge_refundExclusionChain", "refund_compile_install_exclusion", exact_expected),
 ("forge_installHandlerIrrelevant", "no_install_prefix_same_but_install",
    ``same_but_install mc mc2 /\ (!n. no_install_prefix mc2 ffi n ms) ==>
      (!n. no_install_prefix mc ffi n ms) /\ (!k. targetSem$evaluate mc ffi k ms = targetSem$evaluate mc2 ffi k ms)``),
 ("forge_refundExclusionFinal", "refund_install_exclusion_any_handler", final_expected)];
val _ = List.app (fn (thy, n, tm) =>
  let val th = DB.fetch thy n in
    if same tm (concl th) then () else (pr ("STORED " ^ n ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ n));
    tags n th; pr ("IMPORTED " ^ thy ^ "." ^ n ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end) expected;
val thys = ["forge_refundLabFiltered", "forge_refundExactExclusion", "forge_refundExclusionChain", "forge_installHandlerIrrelevant", "forge_refundExclusionFinal"];
val _ = List.app (fn thy => (List.app (fn (n, th) => tags (thy ^ "." ^ n) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ String.concatWith " " (map fst (DB.theorems thy)));
   pr ("STORED_DEFINITIONS " ^ thy ^ " " ^ String.concatWith " " (map fst (DB.definitions thy))))) thys;
(* The generic chain theorem: its premises are those of the exact theorem plus two, at a variable program. *)
val gen = DB.fetch "forge_refundExclusionChain" "compile_install_exclusion";
val _ = pr ("GENERIC_PREMISES " ^ Int.toString (length (strip_conj (fst (dest_imp (concl gen))))) ^
            " EXACT_PREMISES " ^ Int.toString (length (strip_conj (fst (dest_imp (concl (DB.fetch "forge_refundExclusionChain" "refund_compile_install_exclusion")))))));
(* Fidelity of the replayed published lemma: the exported published semantics_compile has the same premise conjuncts
   except the domain alignment and the non-Fail premise. Report the published conjuncts that are missing here. *)
val pubsc = strip_conj (fst (dest_imp (concl lab_to_targetProofTheory.semantics_compile)));
val mine = strip_conj (fst (dest_imp (concl gen)));
val missing = List.filter (fn p => not (List.exists (fn q => can (match_term p) q andalso can (match_term q) p) mine)) pubsc;
val _ = pr ("PUBLISHED_SEMANTICS_COMPILE_PREMISES " ^ Int.toString (length pubsc) ^ " NOT_MATCHED_HERE " ^ Int.toString (length missing));
val _ = List.app (fn p => pr ("  NOT_MATCHED " ^ term_to_string p)) missing;
val _ = pr ("NEGATIVE_CONTROL_KEPT wraparound " ^ thm_to_string (DB.fetch "forge_simZeroCase" "install_entry_wrap_example"));
val _ = pr ("NEGATIVE_CONTROL_KEPT interior " ^ thm_to_string (DB.fetch "forge_simRoot" "endpoint_correspondence_insufficient"));
val _ = pr ("NEGATIVE_CONTROL_KEPT invariant " ^ thm_to_string (DB.fetch "forge_refundExactExclusion" "trivial_invariant_not_closed"));
val _ = pr ("NEGATIVE_CONTROL_KEPT sharemem " ^ thm_to_string (DB.fetch "forge_refundExactExclusion" "sharemem_line_detected"));
val _ = pr ("NEGATIVE_CONTROL_KEPT region29 " ^ thm_to_string (DB.fetch "forge_refundLabFiltered" "filt_walk_single_eval"));
val _ = pr ("NEGATIVE_CONTROL_KEPT handler " ^ thm_to_string (DB.fetch "forge_installHandlerIrrelevant" "handler_matters_when_installer_reached"));
val _ = pr "AFTER_POSITIVE_AUDIT";
(* Statement controls. *)
val no_init = ``!k. refund_lab_inv (make_init mc0 ffi0 t0 (m:word64 -> 64 word_loc) dm1 sdm1 ms0 ^F cmp0 cbpos0 cbspace0 coracle0 with clock := k)``;
val weak_final = mk_imp (pub_premises, snd (dest_imp final_expected));
val _ = if same no_init (concl (DB.fetch "forge_refundExactExclusion" "refund_lab_inv_init")) orelse
           same weak_final (concl (DB.fetch "forge_refundExclusionFinal" "refund_install_exclusion_any_handler")) orelse
           same (snd (dest_imp exact_expected)) (concl (DB.fetch "forge_refundExclusionChain" "refund_compile_install_exclusion"))
        then pr "UNEXPECTED_CONTROL_ACCEPTANCE" else pr "CONTROL_OK statements without the initial-state, handler-relation or compile-level premises are not the stored ones";
val closure = "forge_refundExclusionFinal" :: Theory.ancestry "forge_refundExclusionFinal";
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = pr "P3_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
