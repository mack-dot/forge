structure forge_refundLabFilteredTheory :> forge_refundLabFilteredTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundLabFilteredTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_labRegionAlignedTheory forge_refundLabRunTheory
  forge_simReplayTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundLabFiltered",
        hash = "e774bec256b70952d4d8d99ed3caf729c45dd7b0",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundLabFiltered" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op sm_secs_def _ = () val op sm_secs_def = TDB.find "sm_secs_def"
  fun op sm_free_def _ = () val op sm_free_def = TDB.find "sm_free_def"
  fun op sm_count_def _ = () val op sm_count_def = TDB.find "sm_count_def"
  fun op refund_prog_cv_thm _ = ()
  val op refund_prog_cv_thm = TDB.find "refund_prog_cv_thm"
  fun op refund_prog_cv_eq _ = ()
  val op refund_prog_cv_eq = TDB.find "refund_prog_cv_eq"
  fun op refund_prog_cv_def _ = ()
  val op refund_prog_cv_def = TDB.find "refund_prog_cv_def"
  fun op line_is_sharemem_def _ = ()
  val op line_is_sharemem_def = TDB.find "line_is_sharemem_def"
  fun op line_count_def _ = ()
  val op line_count_def = TDB.find "line_count_def"
  fun op filt_walk_single_eval _ = ()
  val op filt_walk_single_eval = TDB.find "filt_walk_single_eval"
  fun op filt_walk_pair_eval _ = ()
  val op filt_walk_pair_eval = TDB.find "filt_walk_pair_eval"
  fun op filt_walk_def _ = ()
  val op filt_walk_def = TDB.find "filt_walk_def"
  fun op filt_info_eval _ = ()
  val op filt_info_eval = TDB.find "filt_info_eval"
  fun op filt_info_def _ = ()
  val op filt_info_def = TDB.find "filt_info_def"
  fun op cv_sm_secs_thm _ = ()
  val op cv_sm_secs_thm = TDB.find "cv_sm_secs_thm"
  fun op cv_sm_secs_def _ = ()
  val op cv_sm_secs_def = TDB.find "cv_sm_secs_def"
  fun op cv_sm_free_thm _ = ()
  val op cv_sm_free_thm = TDB.find "cv_sm_free_thm"
  fun op cv_sm_free_def _ = ()
  val op cv_sm_free_def = TDB.find "cv_sm_free_def"
  fun op cv_sm_count_thm _ = ()
  val op cv_sm_count_thm = TDB.find "cv_sm_count_thm"
  fun op cv_sm_count_def _ = ()
  val op cv_sm_count_def = TDB.find "cv_sm_count_def"
  fun op cv_line_is_sharemem_thm _ = ()
  val op cv_line_is_sharemem_thm = TDB.find "cv_line_is_sharemem_thm"
  fun op cv_line_is_sharemem_def _ = ()
  val op cv_line_is_sharemem_def = TDB.find "cv_line_is_sharemem_def"
  fun op cv_line_count_thm _ = ()
  val op cv_line_count_thm = TDB.find "cv_line_count_thm"
  fun op cv_line_count_def _ = ()
  val op cv_line_count_def = TDB.find "cv_line_count_def"
  fun op cv_filt_walk_thm _ = ()
  val op cv_filt_walk_thm = TDB.find "cv_filt_walk_thm"
  fun op cv_filt_walk_def _ = ()
  val op cv_filt_walk_def = TDB.find "cv_filt_walk_def"
  fun op cv_filt_info_thm _ = ()
  val op cv_filt_info_thm = TDB.find "cv_filt_info_thm"
  fun op cv_filt_info_def _ = ()
  val op cv_filt_info_def = TDB.find "cv_filt_info_def"
  fun op cv_MAP_lam_LENGTH_Section_lines_thm _ = ()
  val op cv_MAP_lam_LENGTH_Section_lines_thm = TDB.find
    "cv_MAP_lam_LENGTH_Section_lines_thm"
  fun op cv_MAP_lam_LENGTH_Section_lines_ind _ = ()
  val op cv_MAP_lam_LENGTH_Section_lines_ind = TDB.find
    "cv_MAP_lam_LENGTH_Section_lines_ind"
  fun op cv_MAP_lam_LENGTH_Section_lines_def_primitive _ = ()
  val op cv_MAP_lam_LENGTH_Section_lines_def_primitive = TDB.find
    "cv_MAP_lam_LENGTH_Section_lines_def_primitive"
  fun op cv_MAP_lam_LENGTH_Section_lines_def _ = ()
  val op cv_MAP_lam_LENGTH_Section_lines_def = TDB.find
    "cv_MAP_lam_LENGTH_Section_lines_def"
  fun op cv_MAP_lam_LENGTH_FILTER_line_is_'_thm _ = ()
  val op cv_MAP_lam_LENGTH_FILTER_line_is_'_thm = TDB.find
    "cv_MAP_lam_LENGTH_FILTER_line_is_'_thm"
  fun op cv_MAP_lam_LENGTH_FILTER_line_is_'_ind _ = ()
  val op cv_MAP_lam_LENGTH_FILTER_line_is_'_ind = TDB.find
    "cv_MAP_lam_LENGTH_FILTER_line_is_'_ind"
  fun op cv_MAP_lam_LENGTH_FILTER_line_is_'_def_primitive _ = ()
  val op cv_MAP_lam_LENGTH_FILTER_line_is_'_def_primitive = TDB.find
    "cv_MAP_lam_LENGTH_FILTER_line_is_'_def_primitive"
  fun op cv_MAP_lam_LENGTH_FILTER_line_is_'_def _ = ()
  val op cv_MAP_lam_LENGTH_FILTER_line_is_'_def = TDB.find
    "cv_MAP_lam_LENGTH_FILTER_line_is_'_def"
  fun op cv_FILTER_line_is_sharemem_Sectio_thm _ = ()
  val op cv_FILTER_line_is_sharemem_Sectio_thm = TDB.find
    "cv_FILTER_line_is_sharemem_Sectio_thm"
  fun op cv_FILTER_line_is_sharemem_Sectio_ind _ = ()
  val op cv_FILTER_line_is_sharemem_Sectio_ind = TDB.find
    "cv_FILTER_line_is_sharemem_Sectio_ind"
  fun op cv_FILTER_line_is_sharemem_Sectio_def_primitive _ = ()
  val op cv_FILTER_line_is_sharemem_Sectio_def_primitive = TDB.find
    "cv_FILTER_line_is_sharemem_Sectio_def_primitive"
  fun op cv_FILTER_line_is_sharemem_Sectio_def _ = ()
  val op cv_FILTER_line_is_sharemem_Sectio_def = TDB.find
    "cv_FILTER_line_is_sharemem_Sectio_def"
  fun op cv_FILTER_lam_EXISTS_line_is_shar_thm _ = ()
  val op cv_FILTER_lam_EXISTS_line_is_shar_thm = TDB.find
    "cv_FILTER_lam_EXISTS_line_is_shar_thm"
  fun op cv_FILTER_lam_EXISTS_line_is_shar_ind _ = ()
  val op cv_FILTER_lam_EXISTS_line_is_shar_ind = TDB.find
    "cv_FILTER_lam_EXISTS_line_is_shar_ind"
  fun op cv_FILTER_lam_EXISTS_line_is_shar_def_primitive _ = ()
  val op cv_FILTER_lam_EXISTS_line_is_shar_def_primitive = TDB.find
    "cv_FILTER_lam_EXISTS_line_is_shar_def_primitive"
  fun op cv_FILTER_lam_EXISTS_line_is_shar_def _ = ()
  val op cv_FILTER_lam_EXISTS_line_is_shar_def = TDB.find
    "cv_FILTER_lam_EXISTS_line_is_shar_def"
  fun op cv_EXISTS_line_is_sharemem_Sectio_thm _ = ()
  val op cv_EXISTS_line_is_sharemem_Sectio_thm = TDB.find
    "cv_EXISTS_line_is_sharemem_Sectio_thm"
  fun op cv_EXISTS_line_is_sharemem_Sectio_def _ = ()
  val op cv_EXISTS_line_is_sharemem_Sectio_def = TDB.find
    "cv_EXISTS_line_is_sharemem_Sectio_def"
  fun op cv_EVERY_lam___line_is_sharemem_S_thm _ = ()
  val op cv_EVERY_lam___line_is_sharemem_S_thm = TDB.find
    "cv_EVERY_lam___line_is_sharemem_S_thm"
  fun op cv_EVERY_lam___line_is_sharemem_S_def _ = ()
  val op cv_EVERY_lam___line_is_sharemem_S_def = TDB.find
    "cv_EVERY_lam___line_is_sharemem_S_def"
  fun op cv_EVERY_lam_EVERY_lam___line_is__thm _ = ()
  val op cv_EVERY_lam_EVERY_lam___line_is__thm = TDB.find
    "cv_EVERY_lam_EVERY_lam___line_is__thm"
  fun op cv_EVERY_lam_EVERY_lam___line_is__def _ = ()
  val op cv_EVERY_lam_EVERY_lam___line_is__def = TDB.find
    "cv_EVERY_lam_EVERY_lam___line_is__def"
  fun op MAP_lam_LENGTH_Section_lines_ho _ = ()
  val op MAP_lam_LENGTH_Section_lines_ho = TDB.find
    "MAP_lam_LENGTH_Section_lines_ho"
  fun op MAP_lam_LENGTH_Section_lines_def _ = ()
  val op MAP_lam_LENGTH_Section_lines_def = TDB.find
    "MAP_lam_LENGTH_Section_lines_def"
  fun op MAP_lam_LENGTH_FILTER_line_is__ho _ = ()
  val op MAP_lam_LENGTH_FILTER_line_is__ho = TDB.find
    "MAP_lam_LENGTH_FILTER_line_is__ho"
  fun op MAP_lam_LENGTH_FILTER_line_is__def _ = ()
  val op MAP_lam_LENGTH_FILTER_line_is__def = TDB.find
    "MAP_lam_LENGTH_FILTER_line_is__def"
  fun op FILTER_line_is_sharemem_Sectio_ho _ = ()
  val op FILTER_line_is_sharemem_Sectio_ho = TDB.find
    "FILTER_line_is_sharemem_Sectio_ho"
  fun op FILTER_line_is_sharemem_Sectio_def _ = ()
  val op FILTER_line_is_sharemem_Sectio_def = TDB.find
    "FILTER_line_is_sharemem_Sectio_def"
  fun op FILTER_lam_EXISTS_line_is_shar_ho _ = ()
  val op FILTER_lam_EXISTS_line_is_shar_ho = TDB.find
    "FILTER_lam_EXISTS_line_is_shar_ho"
  fun op FILTER_lam_EXISTS_line_is_shar_def _ = ()
  val op FILTER_lam_EXISTS_line_is_shar_def = TDB.find
    "FILTER_lam_EXISTS_line_is_shar_def"
  fun op EXISTS_line_is_sharemem_Sectio_ho _ = ()
  val op EXISTS_line_is_sharemem_Sectio_ho = TDB.find
    "EXISTS_line_is_sharemem_Sectio_ho"
  fun op EXISTS_line_is_sharemem_Sectio_def _ = ()
  val op EXISTS_line_is_sharemem_Sectio_def = TDB.find
    "EXISTS_line_is_sharemem_Sectio_def"
  fun op EVERY_lam___line_is_sharemem_S_ho _ = ()
  val op EVERY_lam___line_is_sharemem_S_ho = TDB.find
    "EVERY_lam___line_is_sharemem_S_ho"
  fun op EVERY_lam___line_is_sharemem_S_def _ = ()
  val op EVERY_lam___line_is_sharemem_S_def = TDB.find
    "EVERY_lam___line_is_sharemem_S_def"
  fun op EVERY_lam_EVERY_lam___line_is__ho _ = ()
  val op EVERY_lam_EVERY_lam___line_is__ho = TDB.find
    "EVERY_lam_EVERY_lam___line_is__ho"
  fun op EVERY_lam_EVERY_lam___line_is__def _ = ()
  val op EVERY_lam_EVERY_lam___line_is__def = TDB.find
    "EVERY_lam_EVERY_lam___line_is__def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundLabFiltered"

end
