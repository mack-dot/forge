structure forge_refundLabResolveTheory :> forge_refundLabResolveTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundLabResolveTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundLabClosureTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundLabResolve",
        hash = "1daafc5680070eee9cd03e5802a3aa671889b63d",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundLabResolve" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op sec_at_def _ = () val op sec_at_def = TDB.find "sec_at_def"
  fun op resolve_stats_def _ = ()
  val op resolve_stats_def = TDB.find "resolve_stats_def"
  fun op resolve_info_def _ = ()
  val op resolve_info_def = TDB.find "resolve_info_def"
  fun op resolve_check_def _ = ()
  val op resolve_check_def = TDB.find "resolve_check_def"
  fun op refund_prog_cv_thm _ = ()
  val op refund_prog_cv_thm = TDB.find "refund_prog_cv_thm"
  fun op refund_prog_cv_eq _ = ()
  val op refund_prog_cv_eq = TDB.find "refund_prog_cv_eq"
  fun op refund_prog_cv_def _ = ()
  val op refund_prog_cv_def = TDB.find "refund_prog_cv_def"
  fun op refund_lab_resolve_stats _ = ()
  val op refund_lab_resolve_stats = TDB.find "refund_lab_resolve_stats"
  fun op refund_lab_resolve_not_closed_29 _ = ()
  val op refund_lab_resolve_not_closed_29 = TDB.find
    "refund_lab_resolve_not_closed_29"
  fun op refund_lab_resolve_closed _ = ()
  val op refund_lab_resolve_closed = TDB.find "refund_lab_resolve_closed"
  fun op refund_lab_refs_resolve_outside _ = ()
  val op refund_lab_refs_resolve_outside = TDB.find
    "refund_lab_refs_resolve_outside"
  fun op refs_ok_resolve _ = ()
  val op refs_ok_resolve = TDB.find "refs_ok_resolve"
  fun op refs_ok_def _ = () val op refs_ok_def = TDB.find "refs_ok_def"
  fun op ref_ok_def _ = () val op ref_ok_def = TDB.find "ref_ok_def"
  fun op pc_ok_def _ = () val op pc_ok_def = TDB.find "pc_ok_def"
  fun op loc_pc_thm _ = () val op loc_pc_thm = TDB.find "loc_pc_thm"
  fun op loc_pc_ind _ = () val op loc_pc_ind = TDB.find "loc_pc_ind"
  fun op loc_pc_def _ = () val op loc_pc_def = TDB.find "loc_pc_def"
  fun op line_refs_ok_def _ = ()
  val op line_refs_ok_def = TDB.find "line_refs_ok_def"
  fun op line_is_call_def _ = ()
  val op line_is_call_def = TDB.find "line_is_call_def"
  fun op line_has_ref_def _ = ()
  val op line_has_ref_def = TDB.find "line_has_ref_def"
  fun op flat_lines_def _ = ()
  val op flat_lines_def = TDB.find "flat_lines_def"
  fun op fall_pairs_ind _ = ()
  val op fall_pairs_ind = TDB.find "fall_pairs_ind"
  fun op fall_pairs_def _ = ()
  val op fall_pairs_def = TDB.find "fall_pairs_def"
  fun op cv_sec_at_thm _ = ()
  val op cv_sec_at_thm = TDB.find "cv_sec_at_thm"
  fun op cv_sec_at_def _ = ()
  val op cv_sec_at_def = TDB.find "cv_sec_at_def"
  fun op cv_resolve_stats_thm _ = ()
  val op cv_resolve_stats_thm = TDB.find "cv_resolve_stats_thm"
  fun op cv_resolve_stats_def _ = ()
  val op cv_resolve_stats_def = TDB.find "cv_resolve_stats_def"
  fun op cv_resolve_info_thm _ = ()
  val op cv_resolve_info_thm = TDB.find "cv_resolve_info_thm"
  fun op cv_resolve_info_def _ = ()
  val op cv_resolve_info_def = TDB.find "cv_resolve_info_def"
  fun op cv_resolve_check_thm _ = ()
  val op cv_resolve_check_thm = TDB.find "cv_resolve_check_thm"
  fun op cv_resolve_check_def _ = ()
  val op cv_resolve_check_def = TDB.find "cv_resolve_check_def"
  fun op cv_refs_ok_thm _ = ()
  val op cv_refs_ok_thm = TDB.find "cv_refs_ok_thm"
  fun op cv_refs_ok_def _ = ()
  val op cv_refs_ok_def = TDB.find "cv_refs_ok_def"
  fun op cv_ref_ok_thm _ = ()
  val op cv_ref_ok_thm = TDB.find "cv_ref_ok_thm"
  fun op cv_ref_ok_def _ = ()
  val op cv_ref_ok_def = TDB.find "cv_ref_ok_def"
  fun op cv_pc_ok_thm _ = () val op cv_pc_ok_thm = TDB.find "cv_pc_ok_thm"
  fun op cv_pc_ok_def _ = () val op cv_pc_ok_def = TDB.find "cv_pc_ok_def"
  fun op cv_loc_pc_thm _ = ()
  val op cv_loc_pc_thm = TDB.find "cv_loc_pc_thm"
  fun op cv_loc_pc_ind _ = ()
  val op cv_loc_pc_ind = TDB.find "cv_loc_pc_ind"
  fun op cv_loc_pc_def _ = ()
  val op cv_loc_pc_def = TDB.find "cv_loc_pc_def"
  fun op cv_line_refs_ok_thm _ = ()
  val op cv_line_refs_ok_thm = TDB.find "cv_line_refs_ok_thm"
  fun op cv_line_refs_ok_def _ = ()
  val op cv_line_refs_ok_def = TDB.find "cv_line_refs_ok_def"
  fun op cv_line_is_call_thm _ = ()
  val op cv_line_is_call_thm = TDB.find "cv_line_is_call_thm"
  fun op cv_line_is_call_def _ = ()
  val op cv_line_is_call_def = TDB.find "cv_line_is_call_def"
  fun op cv_line_has_ref_thm _ = ()
  val op cv_line_has_ref_thm = TDB.find "cv_line_has_ref_thm"
  fun op cv_line_has_ref_def _ = ()
  val op cv_line_has_ref_def = TDB.find "cv_line_has_ref_def"
  fun op cv_is_Label_thm _ = ()
  val op cv_is_Label_thm = TDB.find "cv_is_Label_thm"
  fun op cv_is_Label_def _ = ()
  val op cv_is_Label_def = TDB.find "cv_is_Label_def"
  fun op cv_flat_lines_thm _ = ()
  val op cv_flat_lines_thm = TDB.find "cv_flat_lines_thm"
  fun op cv_flat_lines_def _ = ()
  val op cv_flat_lines_def = TDB.find "cv_flat_lines_def"
  fun op cv_fall_pairs_thm _ = ()
  val op cv_fall_pairs_thm = TDB.find "cv_fall_pairs_thm"
  fun op cv_fall_pairs_def _ = ()
  val op cv_fall_pairs_def = TDB.find "cv_fall_pairs_def"
  fun op cv_MAP_lam___Section_num_FILTER_l_thm _ = ()
  val op cv_MAP_lam___Section_num_FILTER_l_thm = TDB.find
    "cv_MAP_lam___Section_num_FILTER_l_thm"
  fun op cv_MAP_lam___Section_num_FILTER_l_ind _ = ()
  val op cv_MAP_lam___Section_num_FILTER_l_ind = TDB.find
    "cv_MAP_lam___Section_num_FILTER_l_ind"
  fun op cv_MAP_lam___Section_num_FILTER_l_def _ = ()
  val op cv_MAP_lam___Section_num_FILTER_l_def = TDB.find
    "cv_MAP_lam___Section_num_FILTER_l_def"
  fun op cv_MAP_lam_MAP_lam___Section_num__thm _ = ()
  val op cv_MAP_lam_MAP_lam___Section_num__thm = TDB.find
    "cv_MAP_lam_MAP_lam___Section_num__thm"
  fun op cv_MAP_lam_MAP_lam___Section_num__ind _ = ()
  val op cv_MAP_lam_MAP_lam___Section_num__ind = TDB.find
    "cv_MAP_lam_MAP_lam___Section_num__ind"
  fun op cv_MAP_lam_MAP_lam___Section_num__def_primitive _ = ()
  val op cv_MAP_lam_MAP_lam___Section_num__def_primitive = TDB.find
    "cv_MAP_lam_MAP_lam___Section_num__def_primitive"
  fun op cv_MAP_lam_MAP_lam___Section_num__def _ = ()
  val op cv_MAP_lam_MAP_lam___Section_num__def = TDB.find
    "cv_MAP_lam_MAP_lam___Section_num__def"
  fun op cv_FILTER_lam_pair_CASE_lam_lam_l_thm _ = ()
  val op cv_FILTER_lam_pair_CASE_lam_lam_l_thm = TDB.find
    "cv_FILTER_lam_pair_CASE_lam_lam_l_thm"
  fun op cv_FILTER_lam_pair_CASE_lam_lam_l_ind _ = ()
  val op cv_FILTER_lam_pair_CASE_lam_lam_l_ind = TDB.find
    "cv_FILTER_lam_pair_CASE_lam_lam_l_ind"
  fun op cv_FILTER_lam_pair_CASE_lam_lam_l_def_primitive _ = ()
  val op cv_FILTER_lam_pair_CASE_lam_lam_l_def_primitive = TDB.find
    "cv_FILTER_lam_pair_CASE_lam_lam_l_def_primitive"
  fun op cv_FILTER_lam_pair_CASE_lam_lam_l_def _ = ()
  val op cv_FILTER_lam_pair_CASE_lam_lam_l_def = TDB.find
    "cv_FILTER_lam_pair_CASE_lam_lam_l_def"
  fun op cv_FILTER_lam_pair_CASE_lam_lam_l_1_thm _ = ()
  val op cv_FILTER_lam_pair_CASE_lam_lam_l_1_thm = TDB.find
    "cv_FILTER_lam_pair_CASE_lam_lam_l_1_thm"
  fun op cv_FILTER_lam_pair_CASE_lam_lam_l_1_ind _ = ()
  val op cv_FILTER_lam_pair_CASE_lam_lam_l_1_ind = TDB.find
    "cv_FILTER_lam_pair_CASE_lam_lam_l_1_ind"
  fun op cv_FILTER_lam_pair_CASE_lam_lam_l_1_def_primitive _ = ()
  val op cv_FILTER_lam_pair_CASE_lam_lam_l_1_def_primitive = TDB.find
    "cv_FILTER_lam_pair_CASE_lam_lam_l_1_def_primitive"
  fun op cv_FILTER_lam_pair_CASE_lam_lam_l_1_def _ = ()
  val op cv_FILTER_lam_pair_CASE_lam_lam_l_1_def = TDB.find
    "cv_FILTER_lam_pair_CASE_lam_lam_l_1_def"
  fun op cv_FILTER_lam___is_Label_Section__thm _ = ()
  val op cv_FILTER_lam___is_Label_Section__thm = TDB.find
    "cv_FILTER_lam___is_Label_Section__thm"
  fun op cv_FILTER_lam___is_Label_Section__ind _ = ()
  val op cv_FILTER_lam___is_Label_Section__ind = TDB.find
    "cv_FILTER_lam___is_Label_Section__ind"
  fun op cv_FILTER_lam___is_Label_Section__def_primitive _ = ()
  val op cv_FILTER_lam___is_Label_Section__def_primitive = TDB.find
    "cv_FILTER_lam___is_Label_Section__def_primitive"
  fun op cv_FILTER_lam___is_Label_Section__def _ = ()
  val op cv_FILTER_lam___is_Label_Section__def = TDB.find
    "cv_FILTER_lam___is_Label_Section__def"
  fun op cv_EVERY_line_refs_ok_Section_lin_thm _ = ()
  val op cv_EVERY_line_refs_ok_Section_lin_thm = TDB.find
    "cv_EVERY_line_refs_ok_Section_lin_thm"
  fun op cv_EVERY_line_refs_ok_Section_lin_def _ = ()
  val op cv_EVERY_line_refs_ok_Section_lin_def = TDB.find
    "cv_EVERY_line_refs_ok_Section_lin_def"
  fun op cv_EVERY_lam____IN_Section_num_LI'_thm _ = ()
  val op cv_EVERY_lam____IN_Section_num_LI'_thm = TDB.find
    "cv_EVERY_lam____IN_Section_num_LI'_thm"
  fun op cv_EVERY_lam____IN_Section_num_LI'_def _ = ()
  val op cv_EVERY_lam____IN_Section_num_LI'_def = TDB.find
    "cv_EVERY_lam____IN_Section_num_LI'_def"
  fun op MAP_lam___Section_num_FILTER_l_ho _ = ()
  val op MAP_lam___Section_num_FILTER_l_ho = TDB.find
    "MAP_lam___Section_num_FILTER_l_ho"
  fun op MAP_lam___Section_num_FILTER_l_def _ = ()
  val op MAP_lam___Section_num_FILTER_l_def = TDB.find
    "MAP_lam___Section_num_FILTER_l_def"
  fun op MAP_lam_MAP_lam___Section_num__ho _ = ()
  val op MAP_lam_MAP_lam___Section_num__ho = TDB.find
    "MAP_lam_MAP_lam___Section_num__ho"
  fun op MAP_lam_MAP_lam___Section_num__def _ = ()
  val op MAP_lam_MAP_lam___Section_num__def = TDB.find
    "MAP_lam_MAP_lam___Section_num__def"
  fun op FILTER_lam_pair_CASE_lam_lam_l_ho _ = ()
  val op FILTER_lam_pair_CASE_lam_lam_l_ho = TDB.find
    "FILTER_lam_pair_CASE_lam_lam_l_ho"
  fun op FILTER_lam_pair_CASE_lam_lam_l_def _ = ()
  val op FILTER_lam_pair_CASE_lam_lam_l_def = TDB.find
    "FILTER_lam_pair_CASE_lam_lam_l_def"
  fun op FILTER_lam_pair_CASE_lam_lam_l_1_ho _ = ()
  val op FILTER_lam_pair_CASE_lam_lam_l_1_ho = TDB.find
    "FILTER_lam_pair_CASE_lam_lam_l_1_ho"
  fun op FILTER_lam_pair_CASE_lam_lam_l_1_def _ = ()
  val op FILTER_lam_pair_CASE_lam_lam_l_1_def = TDB.find
    "FILTER_lam_pair_CASE_lam_lam_l_1_def"
  fun op FILTER_lam___is_Label_Section__ho _ = ()
  val op FILTER_lam___is_Label_Section__ho = TDB.find
    "FILTER_lam___is_Label_Section__ho"
  fun op FILTER_lam___is_Label_Section__def _ = ()
  val op FILTER_lam___is_Label_Section__def = TDB.find
    "FILTER_lam___is_Label_Section__def"
  fun op EVERY_line_refs_ok_Section_lin_ho _ = ()
  val op EVERY_line_refs_ok_Section_lin_ho = TDB.find
    "EVERY_line_refs_ok_Section_lin_ho"
  fun op EVERY_line_refs_ok_Section_lin_def _ = ()
  val op EVERY_line_refs_ok_Section_lin_def = TDB.find
    "EVERY_line_refs_ok_Section_lin_def"
  fun op EVERY_lam____IN_Section_num_LI_ho _ = ()
  val op EVERY_lam____IN_Section_num_LI_ho = TDB.find
    "EVERY_lam____IN_Section_num_LI_ho"
  fun op EVERY_lam____IN_Section_num_LI_def _ = ()
  val op EVERY_lam____IN_Section_num_LI_def = TDB.find
    "EVERY_lam____IN_Section_num_LI_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundLabResolve"

end
