signature forge_refundLabFilteredTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val EVERY_lam_EVERY_lam___line_is__def : thm
    val EVERY_lam___line_is_sharemem_S_def : thm
    val EXISTS_line_is_sharemem_Sectio_def : thm
    val FILTER_lam_EXISTS_line_is_shar_def : thm
    val FILTER_line_is_sharemem_Sectio_def : thm
    val MAP_lam_LENGTH_FILTER_line_is__def : thm
    val MAP_lam_LENGTH_Section_lines_def : thm
    val cv_EVERY_lam_EVERY_lam___line_is__def : thm
    val cv_EVERY_lam___line_is_sharemem_S_def : thm
    val cv_EXISTS_line_is_sharemem_Sectio_def : thm
    val cv_FILTER_lam_EXISTS_line_is_shar_def_primitive : thm
    val cv_FILTER_line_is_sharemem_Sectio_def_primitive : thm
    val cv_MAP_lam_LENGTH_FILTER_line_is_'_def_primitive : thm
    val cv_MAP_lam_LENGTH_Section_lines_def_primitive : thm
    val cv_filt_info_def : thm
    val cv_filt_walk_def : thm
    val cv_line_count_def : thm
    val cv_line_is_sharemem_def : thm
    val cv_sm_count_def : thm
    val cv_sm_free_def : thm
    val cv_sm_secs_def : thm
    val filt_info_def : thm
    val filt_walk_def : thm
    val line_count_def : thm
    val line_is_sharemem_def : thm
    val refund_prog_cv_def : thm
    val sm_count_def : thm
    val sm_free_def : thm
    val sm_secs_def : thm
  
  (*  Theorems  *)
    val EVERY_lam_EVERY_lam___line_is__ho : thm
    val EVERY_lam___line_is_sharemem_S_ho : thm
    val EXISTS_line_is_sharemem_Sectio_ho : thm
    val FILTER_lam_EXISTS_line_is_shar_ho : thm
    val FILTER_line_is_sharemem_Sectio_ho : thm
    val MAP_lam_LENGTH_FILTER_line_is__ho : thm
    val MAP_lam_LENGTH_Section_lines_ho : thm
    val cv_EVERY_lam_EVERY_lam___line_is__thm : thm
    val cv_EVERY_lam___line_is_sharemem_S_thm : thm
    val cv_EXISTS_line_is_sharemem_Sectio_thm : thm
    val cv_FILTER_lam_EXISTS_line_is_shar_def : thm
    val cv_FILTER_lam_EXISTS_line_is_shar_ind : thm
    val cv_FILTER_lam_EXISTS_line_is_shar_thm : thm
    val cv_FILTER_line_is_sharemem_Sectio_def : thm
    val cv_FILTER_line_is_sharemem_Sectio_ind : thm
    val cv_FILTER_line_is_sharemem_Sectio_thm : thm
    val cv_MAP_lam_LENGTH_FILTER_line_is_'_def : thm
    val cv_MAP_lam_LENGTH_FILTER_line_is_'_ind : thm
    val cv_MAP_lam_LENGTH_FILTER_line_is_'_thm : thm
    val cv_MAP_lam_LENGTH_Section_lines_def : thm
    val cv_MAP_lam_LENGTH_Section_lines_ind : thm
    val cv_MAP_lam_LENGTH_Section_lines_thm : thm
    val cv_filt_info_thm : thm
    val cv_filt_walk_thm : thm
    val cv_line_count_thm : thm
    val cv_line_is_sharemem_thm : thm
    val cv_sm_count_thm : thm
    val cv_sm_free_thm : thm
    val cv_sm_secs_thm : thm
    val filt_info_eval : thm
    val filt_walk_pair_eval : thm
    val filt_walk_single_eval : thm
    val refund_prog_cv_eq : thm
    val refund_prog_cv_thm : thm
end
