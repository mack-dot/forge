structure forge_refundCompileFactsTheory :> forge_refundCompileFactsTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundCompileFactsTheory ... "
    else ()
  
  open Type Term Thm
  local open arm8_configProofTheory forge_refundExclusionFinalTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundCompileFacts",
        hash = "aeacf2bc1281d1caba10928e5bb8f16446c07ddb",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundCompileFacts" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op to_lab_lab_conf _ = ()
  val op to_lab_lab_conf = TDB.find "to_lab_lab_conf"
  fun op refund_prog_cv_thm _ = ()
  val op refund_prog_cv_thm = TDB.find "refund_prog_cv_thm"
  fun op refund_prog_cv_eq _ = ()
  val op refund_prog_cv_eq = TDB.find "refund_prog_cv_eq"
  fun op refund_prog_cv_def _ = ()
  val op refund_prog_cv_def = TDB.find "refund_prog_cv_def"
  fun op refund_lab_good_code _ = ()
  val op refund_lab_good_code = TDB.find "refund_lab_good_code"
  fun op refund_lab_ffi_names _ = ()
  val op refund_lab_ffi_names = TDB.find "refund_lab_ffi_names"
  fun op refund_lab_conf_facts _ = ()
  val op refund_lab_conf_facts = TDB.find "refund_lab_conf_facts"
  fun op refund_lab_conf2_def _ = ()
  val op refund_lab_conf2_def = TDB.find "refund_lab_conf2_def"
  fun op refund_lab_compile _ = ()
  val op refund_lab_compile = TDB.find "refund_lab_compile"
  fun op refund_lab_bitmaps _ = ()
  val op refund_lab_bitmaps = TDB.find "refund_lab_bitmaps"
  fun op refs_ok_def _ = () val op refs_ok_def = TDB.find "refs_ok_def"
  fun op refs_line_def _ = ()
  val op refs_line_def = TDB.find "refs_line_def"
  fun op line_ok_pre8_def _ = ()
  val op line_ok_pre8_def = TDB.find "line_ok_pre8_def"
  fun op lab_defined_def _ = ()
  val op lab_defined_def = TDB.find "lab_defined_def"
  fun op has_label_def _ = ()
  val op has_label_def = TDB.find "has_label_def"
  fun op gc_eval_result _ = ()
  val op gc_eval_result = TDB.find "gc_eval_result"
  fun op gc_eval_def _ = () val op gc_eval_def = TDB.find "gc_eval_def"
  fun op gc_check_rejects_undefined_label _ = ()
  val op gc_check_rejects_undefined_label = TDB.find
    "gc_check_rejects_undefined_label"
  fun op gc_check_good_code _ = ()
  val op gc_check_good_code = TDB.find "gc_check_good_code"
  fun op gc_check_def _ = () val op gc_check_def = TDB.find "gc_check_def"
  fun op ends_label_ind _ = ()
  val op ends_label_ind = TDB.find "ends_label_ind"
  fun op ends_label_def_primitive _ = ()
  val op ends_label_def_primitive = TDB.find "ends_label_def_primitive"
  fun op ends_label_def _ = ()
  val op ends_label_def = TDB.find "ends_label_def"
  fun op cv_sec_labels_ok_thm _ = ()
  val op cv_sec_labels_ok_thm = TDB.find "cv_sec_labels_ok_thm"
  fun op cv_sec_labels_ok_def _ = ()
  val op cv_sec_labels_ok_def = TDB.find "cv_sec_labels_ok_def"
  fun op cv_sec_label_ok_thm _ = ()
  val op cv_sec_label_ok_thm = TDB.find "cv_sec_label_ok_thm"
  fun op cv_sec_label_ok_def _ = ()
  val op cv_sec_label_ok_def = TDB.find "cv_sec_label_ok_def"
  fun op cv_refs_ok'_thm _ = ()
  val op cv_refs_ok'_thm = TDB.find "cv_refs_ok'_thm"
  fun op cv_refs_ok'_def _ = ()
  val op cv_refs_ok'_def = TDB.find "cv_refs_ok'_def"
  fun op cv_refs_line_thm _ = ()
  val op cv_refs_line_thm = TDB.find "cv_refs_line_thm"
  fun op cv_refs_line_def _ = ()
  val op cv_refs_line_def = TDB.find "cv_refs_line_def"
  fun op cv_line_ok_pre8_thm _ = ()
  val op cv_line_ok_pre8_thm = TDB.find "cv_line_ok_pre8_thm"
  fun op cv_line_ok_pre8_def _ = ()
  val op cv_line_ok_pre8_def = TDB.find "cv_line_ok_pre8_def"
  fun op cv_lab_defined_thm _ = ()
  val op cv_lab_defined_thm = TDB.find "cv_lab_defined_thm"
  fun op cv_lab_defined_def _ = ()
  val op cv_lab_defined_def = TDB.find "cv_lab_defined_def"
  fun op cv_has_label_thm _ = ()
  val op cv_has_label_thm = TDB.find "cv_has_label_thm"
  fun op cv_has_label_def _ = ()
  val op cv_has_label_def = TDB.find "cv_has_label_def"
  fun op cv_gc_eval_thm _ = ()
  val op cv_gc_eval_thm = TDB.find "cv_gc_eval_thm"
  fun op cv_gc_eval_def _ = ()
  val op cv_gc_eval_def = TDB.find "cv_gc_eval_def"
  fun op cv_gc_check_thm _ = ()
  val op cv_gc_check_thm = TDB.find "cv_gc_check_thm"
  fun op cv_gc_check_def _ = ()
  val op cv_gc_check_def = TDB.find "cv_gc_check_def"
  fun op cv_extract_labels_thm _ = ()
  val op cv_extract_labels_thm = TDB.find "cv_extract_labels_thm"
  fun op cv_extract_labels_ind _ = ()
  val op cv_extract_labels_ind = TDB.find "cv_extract_labels_ind"
  fun op cv_extract_labels_def_primitive _ = ()
  val op cv_extract_labels_def_primitive = TDB.find
    "cv_extract_labels_def_primitive"
  fun op cv_extract_labels_def _ = ()
  val op cv_extract_labels_def = TDB.find "cv_extract_labels_def"
  fun op cv_ends_label_thm _ = ()
  val op cv_ends_label_thm = TDB.find "cv_ends_label_thm"
  fun op cv_ends_label_def _ = ()
  val op cv_ends_label_def = TDB.find "cv_ends_label_def"
  fun op cv_compile_shmem_thm _ = ()
  val op cv_compile_shmem_thm = TDB.find "cv_compile_shmem_thm"
  fun op cv_compile_shmem_def _ = ()
  val op cv_compile_shmem_def = TDB.find "cv_compile_shmem_def"
  fun op cv_EXISTS_lam_line_CASE_lam_lam_l_thm _ = ()
  val op cv_EXISTS_lam_line_CASE_lam_lam_l_thm = TDB.find
    "cv_EXISTS_lam_line_CASE_lam_lam_l_thm"
  fun op cv_EXISTS_lam_line_CASE_lam_lam_l_def _ = ()
  val op cv_EXISTS_lam_line_CASE_lam_lam_l_def = TDB.find
    "cv_EXISTS_lam_line_CASE_lam_lam_l_def"
  fun op cv_EXISTS_lam______Section_num_ha_thm _ = ()
  val op cv_EXISTS_lam______Section_num_ha_thm = TDB.find
    "cv_EXISTS_lam______Section_num_ha_thm"
  fun op cv_EXISTS_lam______Section_num_ha_def _ = ()
  val op cv_EXISTS_lam______Section_num_ha_def = TDB.find
    "cv_EXISTS_lam______Section_num_ha_def"
  fun op cv_EVERY_sec_labels_ok_thm _ = ()
  val op cv_EVERY_sec_labels_ok_thm = TDB.find "cv_EVERY_sec_labels_ok_thm"
  fun op cv_EVERY_sec_labels_ok_def _ = ()
  val op cv_EVERY_sec_labels_ok_def = TDB.find "cv_EVERY_sec_labels_ok_def"
  fun op cv_EVERY_sec_label_ok_thm _ = ()
  val op cv_EVERY_sec_label_ok_thm = TDB.find "cv_EVERY_sec_label_ok_thm"
  fun op cv_EVERY_sec_label_ok_def _ = ()
  val op cv_EVERY_sec_label_ok_def = TDB.find "cv_EVERY_sec_label_ok_def"
  fun op cv_EVERY_line_ok_pre8_Section_lin_thm _ = ()
  val op cv_EVERY_line_ok_pre8_Section_lin_thm = TDB.find
    "cv_EVERY_line_ok_pre8_Section_lin_thm"
  fun op cv_EVERY_line_ok_pre8_Section_lin_def _ = ()
  val op cv_EVERY_line_ok_pre8_Section_lin_def = TDB.find
    "cv_EVERY_line_ok_pre8_Section_lin_def"
  fun op cv_EVERY_lam_ends_label_Section_l_thm _ = ()
  val op cv_EVERY_lam_ends_label_Section_l_thm = TDB.find
    "cv_EVERY_lam_ends_label_Section_l_thm"
  fun op cv_EVERY_lam_ends_label_Section_l_def _ = ()
  val op cv_EVERY_lam_ends_label_Section_l_def = TDB.find
    "cv_EVERY_lam_ends_label_Section_l_def"
  fun op cv_EVERY_lam______SND_0_lab_defin_thm _ = ()
  val op cv_EVERY_lam______SND_0_lab_defin_thm = TDB.find
    "cv_EVERY_lam______SND_0_lab_defin_thm"
  fun op cv_EVERY_lam______SND_0_lab_defin_def _ = ()
  val op cv_EVERY_lam______SND_0_lab_defin_def = TDB.find
    "cv_EVERY_lam______SND_0_lab_defin_def"
  fun op cv_EVERY_lam_EVERY_line_ok_pre8_S_thm _ = ()
  val op cv_EVERY_lam_EVERY_line_ok_pre8_S_thm = TDB.find
    "cv_EVERY_lam_EVERY_line_ok_pre8_S_thm"
  fun op cv_EVERY_lam_EVERY_line_ok_pre8_S_def _ = ()
  val op cv_EVERY_lam_EVERY_line_ok_pre8_S_def = TDB.find
    "cv_EVERY_lam_EVERY_line_ok_pre8_S_def"
  fun op cv_EVERY_lam_EVERY_lam______SND_0_thm _ = ()
  val op cv_EVERY_lam_EVERY_lam______SND_0_thm = TDB.find
    "cv_EVERY_lam_EVERY_lam______SND_0_thm"
  fun op cv_EVERY_lam_EVERY_lam______SND_0_def _ = ()
  val op cv_EVERY_lam_EVERY_lam______SND_0_def = TDB.find
    "cv_EVERY_lam_EVERY_lam______SND_0_def"
  fun op cv_EVERY_lam_EVERY_lam_EVERY_lam__thm _ = ()
  val op cv_EVERY_lam_EVERY_lam_EVERY_lam__thm = TDB.find
    "cv_EVERY_lam_EVERY_lam_EVERY_lam__thm"
  fun op cv_EVERY_lam_EVERY_lam_EVERY_lam__def _ = ()
  val op cv_EVERY_lam_EVERY_lam_EVERY_lam__def = TDB.find
    "cv_EVERY_lam_EVERY_lam_EVERY_lam__def"
  fun op cv_EVERY_lam_ALL_DISTINCT_extract_thm _ = ()
  val op cv_EVERY_lam_ALL_DISTINCT_extract_thm = TDB.find
    "cv_EVERY_lam_ALL_DISTINCT_extract_thm"
  fun op cv_EVERY_lam_ALL_DISTINCT_extract_def _ = ()
  val op cv_EVERY_lam_ALL_DISTINCT_extract_def = TDB.find
    "cv_EVERY_lam_ALL_DISTINCT_extract_def"
  fun op asm_ok_arm8_link _ = ()
  val op asm_ok_arm8_link = TDB.find "asm_ok_arm8_link"
  fun op EXISTS_lam_line_CASE_lam_lam_l_ho _ = ()
  val op EXISTS_lam_line_CASE_lam_lam_l_ho = TDB.find
    "EXISTS_lam_line_CASE_lam_lam_l_ho"
  fun op EXISTS_lam_line_CASE_lam_lam_l_def _ = ()
  val op EXISTS_lam_line_CASE_lam_lam_l_def = TDB.find
    "EXISTS_lam_line_CASE_lam_lam_l_def"
  fun op EXISTS_lam______Section_num_ha_ho _ = ()
  val op EXISTS_lam______Section_num_ha_ho = TDB.find
    "EXISTS_lam______Section_num_ha_ho"
  fun op EXISTS_lam______Section_num_ha_def _ = ()
  val op EXISTS_lam______Section_num_ha_def = TDB.find
    "EXISTS_lam______Section_num_ha_def"
  fun op EVERY_sec_labels_ok_ho _ = ()
  val op EVERY_sec_labels_ok_ho = TDB.find "EVERY_sec_labels_ok_ho"
  fun op EVERY_sec_labels_ok_def _ = ()
  val op EVERY_sec_labels_ok_def = TDB.find "EVERY_sec_labels_ok_def"
  fun op EVERY_sec_label_ok_ho _ = ()
  val op EVERY_sec_label_ok_ho = TDB.find "EVERY_sec_label_ok_ho"
  fun op EVERY_sec_label_ok_def _ = ()
  val op EVERY_sec_label_ok_def = TDB.find "EVERY_sec_label_ok_def"
  fun op EVERY_line_ok_pre8_Section_lin_ho _ = ()
  val op EVERY_line_ok_pre8_Section_lin_ho = TDB.find
    "EVERY_line_ok_pre8_Section_lin_ho"
  fun op EVERY_line_ok_pre8_Section_lin_def _ = ()
  val op EVERY_line_ok_pre8_Section_lin_def = TDB.find
    "EVERY_line_ok_pre8_Section_lin_def"
  fun op EVERY_lam_ends_label_Section_l_ho _ = ()
  val op EVERY_lam_ends_label_Section_l_ho = TDB.find
    "EVERY_lam_ends_label_Section_l_ho"
  fun op EVERY_lam_ends_label_Section_l_def _ = ()
  val op EVERY_lam_ends_label_Section_l_def = TDB.find
    "EVERY_lam_ends_label_Section_l_def"
  fun op EVERY_lam______SND_0_lab_defin_ho _ = ()
  val op EVERY_lam______SND_0_lab_defin_ho = TDB.find
    "EVERY_lam______SND_0_lab_defin_ho"
  fun op EVERY_lam______SND_0_lab_defin_def _ = ()
  val op EVERY_lam______SND_0_lab_defin_def = TDB.find
    "EVERY_lam______SND_0_lab_defin_def"
  fun op EVERY_lam_EVERY_line_ok_pre8_S_ho _ = ()
  val op EVERY_lam_EVERY_line_ok_pre8_S_ho = TDB.find
    "EVERY_lam_EVERY_line_ok_pre8_S_ho"
  fun op EVERY_lam_EVERY_line_ok_pre8_S_def _ = ()
  val op EVERY_lam_EVERY_line_ok_pre8_S_def = TDB.find
    "EVERY_lam_EVERY_line_ok_pre8_S_def"
  fun op EVERY_lam_EVERY_lam______SND_0_ho _ = ()
  val op EVERY_lam_EVERY_lam______SND_0_ho = TDB.find
    "EVERY_lam_EVERY_lam______SND_0_ho"
  fun op EVERY_lam_EVERY_lam______SND_0_def _ = ()
  val op EVERY_lam_EVERY_lam______SND_0_def = TDB.find
    "EVERY_lam_EVERY_lam______SND_0_def"
  fun op EVERY_lam_EVERY_lam_EVERY_lam__ho _ = ()
  val op EVERY_lam_EVERY_lam_EVERY_lam__ho = TDB.find
    "EVERY_lam_EVERY_lam_EVERY_lam__ho"
  fun op EVERY_lam_EVERY_lam_EVERY_lam__def _ = ()
  val op EVERY_lam_EVERY_lam_EVERY_lam__def = TDB.find
    "EVERY_lam_EVERY_lam_EVERY_lam__def"
  fun op EVERY_lam_ALL_DISTINCT_extract_ho _ = ()
  val op EVERY_lam_ALL_DISTINCT_extract_ho = TDB.find
    "EVERY_lam_ALL_DISTINCT_extract_ho"
  fun op EVERY_lam_ALL_DISTINCT_extract_def _ = ()
  val op EVERY_lam_ALL_DISTINCT_extract_def = TDB.find
    "EVERY_lam_ALL_DISTINCT_extract_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundCompileFacts"

end
