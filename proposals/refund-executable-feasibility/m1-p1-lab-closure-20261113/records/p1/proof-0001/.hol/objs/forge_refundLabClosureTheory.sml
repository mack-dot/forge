structure forge_refundLabClosureTheory :> forge_refundLabClosureTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundLabClosureTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundArm8CompileTheory labPropsTheory wordConvsTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundLabClosure",
        hash = "7e78e735a3f8d80c29846db3101d290829a0957c",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundLabClosure" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op word_to_word_inlogic_forge8_link _ = ()
  val op word_to_word_inlogic_forge8_link = TDB.find
    "word_to_word_inlogic_forge8_link"
  fun op word_to_word_inlogic_forge8_def _ = ()
  val op word_to_word_inlogic_forge8_def = TDB.find
    "word_to_word_inlogic_forge8_def"
  fun op word_alloc_inlogic_forge8_link _ = ()
  val op word_alloc_inlogic_forge8_link = TDB.find
    "word_alloc_inlogic_forge8_link"
  fun op word_alloc_inlogic_forge8_def _ = ()
  val op word_alloc_inlogic_forge8_def = TDB.find
    "word_alloc_inlogic_forge8_def"
  fun op sec_ends_exit_def _ = ()
  val op sec_ends_exit_def = TDB.find "sec_ends_exit_def"
  fun op refund_prog_cv_thm _ = ()
  val op refund_prog_cv_thm = TDB.find "refund_prog_cv_thm"
  fun op refund_prog_cv_eq _ = ()
  val op refund_prog_cv_eq = TDB.find "refund_prog_cv_eq"
  fun op refund_prog_cv_def _ = ()
  val op refund_prog_cv_def = TDB.find "refund_prog_cv_def"
  fun op refund_lab_stats _ = ()
  val op refund_lab_stats = TDB.find "refund_lab_stats"
  fun op refund_lab_not_closed_29 _ = ()
  val op refund_lab_not_closed_29 = TDB.find "refund_lab_not_closed_29"
  fun op refund_lab_install_closure _ = ()
  val op refund_lab_install_closure = TDB.find "refund_lab_install_closure"
  fun op refund_lab_closed _ = ()
  val op refund_lab_closed = TDB.find "refund_lab_closed"
  fun op refund_alloc_target _ = ()
  val op refund_alloc_target = TDB.find "refund_alloc_target"
  fun op refund_alloc_oracle_def _ = ()
  val op refund_alloc_oracle_def = TDB.find "refund_alloc_oracle_def"
  fun op refund_alloc_oracle_cv_thm _ = ()
  val op refund_alloc_oracle_cv_thm = TDB.find "refund_alloc_oracle_cv_thm"
  fun op refund_alloc_oracle_cv_eq _ = ()
  val op refund_alloc_oracle_cv_eq = TDB.find "refund_alloc_oracle_cv_eq"
  fun op refund_alloc_oracle_cv_def _ = ()
  val op refund_alloc_oracle_cv_def = TDB.find "refund_alloc_oracle_cv_def"
  fun op refund_alloc_compiled _ = ()
  val op refund_alloc_compiled = TDB.find "refund_alloc_compiled"
  fun op no_fall_ind _ = () val op no_fall_ind = TDB.find "no_fall_ind"
  fun op no_fall_def _ = () val op no_fall_def = TDB.find "no_fall_def"
  fun op line_no_label_def _ = ()
  val op line_no_label_def = TDB.find "line_no_label_def"
  fun op line_is_locvalue_def _ = ()
  val op line_is_locvalue_def = TDB.find "line_is_locvalue_def"
  fun op line_is_jumpreg_def _ = ()
  val op line_is_jumpreg_def = TDB.find "line_is_jumpreg_def"
  fun op line_is_install_def _ = ()
  val op line_is_install_def = TDB.find "line_is_install_def"
  fun op line_is_exit_def _ = ()
  val op line_is_exit_def = TDB.find "line_is_exit_def"
  fun op lab_stats_def _ = ()
  val op lab_stats_def = TDB.find "lab_stats_def"
  fun op lab_names_def _ = ()
  val op lab_names_def = TDB.find "lab_names_def"
  fun op lab_info_def _ = () val op lab_info_def = TDB.find "lab_info_def"
  fun op lab_forge8_to_lab _ = ()
  val op lab_forge8_to_lab = TDB.find "lab_forge8_to_lab"
  fun op lab_forge8_def _ = ()
  val op lab_forge8_def = TDB.find "lab_forge8_def"
  fun op lab_closed_labels _ = ()
  val op lab_closed_labels = TDB.find "lab_closed_labels"
  fun op lab_closed_def _ = ()
  val op lab_closed_def = TDB.find "lab_closed_def"
  fun op lab_check_def _ = ()
  val op lab_check_def = TDB.find "lab_check_def"
  fun op is_label_def _ = () val op is_label_def = TDB.find "is_label_def"
  fun op inst_select_forge8_pre_strongind _ = ()
  val op inst_select_forge8_pre_strongind = TDB.find
    "inst_select_forge8_pre_strongind"
  fun op inst_select_forge8_pre_rules _ = ()
  val op inst_select_forge8_pre_rules = TDB.find
    "inst_select_forge8_pre_rules"
  fun op inst_select_forge8_pre_ind _ = ()
  val op inst_select_forge8_pre_ind = TDB.find "inst_select_forge8_pre_ind"
  fun op inst_select_forge8_pre_cases _ = ()
  val op inst_select_forge8_pre_cases = TDB.find
    "inst_select_forge8_pre_cases"
  fun op inst_select_forge8_pre _ = ()
  val op inst_select_forge8_pre = TDB.find "inst_select_forge8_pre"
  fun op inst_select_forge8_link _ = ()
  val op inst_select_forge8_link = TDB.find "inst_select_forge8_link"
  fun op inst_select_forge8_def _ = ()
  val op inst_select_forge8_def = TDB.find "inst_select_forge8_def"
  fun op inst_select_exp_forge8_pre_strongind _ = ()
  val op inst_select_exp_forge8_pre_strongind = TDB.find
    "inst_select_exp_forge8_pre_strongind"
  fun op inst_select_exp_forge8_pre_rules _ = ()
  val op inst_select_exp_forge8_pre_rules = TDB.find
    "inst_select_exp_forge8_pre_rules"
  fun op inst_select_exp_forge8_pre_ind _ = ()
  val op inst_select_exp_forge8_pre_ind = TDB.find
    "inst_select_exp_forge8_pre_ind"
  fun op inst_select_exp_forge8_pre_cases _ = ()
  val op inst_select_exp_forge8_pre_cases = TDB.find
    "inst_select_exp_forge8_pre_cases"
  fun op inst_select_exp_forge8_pre _ = ()
  val op inst_select_exp_forge8_pre = TDB.find "inst_select_exp_forge8_pre"
  fun op inst_select_exp_forge8_link _ = ()
  val op inst_select_exp_forge8_link = TDB.find
    "inst_select_exp_forge8_link"
  fun op inst_select_exp_forge8_def _ = ()
  val op inst_select_exp_forge8_def = TDB.find "inst_select_exp_forge8_def"
  fun op get_forced_forge8_pre_strongind _ = ()
  val op get_forced_forge8_pre_strongind = TDB.find
    "get_forced_forge8_pre_strongind"
  fun op get_forced_forge8_pre_rules _ = ()
  val op get_forced_forge8_pre_rules = TDB.find
    "get_forced_forge8_pre_rules"
  fun op get_forced_forge8_pre_ind _ = ()
  val op get_forced_forge8_pre_ind = TDB.find "get_forced_forge8_pre_ind"
  fun op get_forced_forge8_pre_cases _ = ()
  val op get_forced_forge8_pre_cases = TDB.find
    "get_forced_forge8_pre_cases"
  fun op get_forced_forge8_pre _ = ()
  val op get_forced_forge8_pre = TDB.find "get_forced_forge8_pre"
  fun op get_forced_forge8_link _ = ()
  val op get_forced_forge8_link = TDB.find "get_forced_forge8_link"
  fun op get_forced_forge8_def _ = ()
  val op get_forced_forge8_def = TDB.find "get_forced_forge8_def"
  fun op forge8_links _ = () val op forge8_links = TDB.find "forge8_links"
  fun op forge8_config_def _ = ()
  val op forge8_config_def = TDB.find "forge8_config_def"
  fun op each_inlogic_forge8_pre_strongind _ = ()
  val op each_inlogic_forge8_pre_strongind = TDB.find
    "each_inlogic_forge8_pre_strongind"
  fun op each_inlogic_forge8_pre_rules _ = ()
  val op each_inlogic_forge8_pre_rules = TDB.find
    "each_inlogic_forge8_pre_rules"
  fun op each_inlogic_forge8_pre_ind _ = ()
  val op each_inlogic_forge8_pre_ind = TDB.find
    "each_inlogic_forge8_pre_ind"
  fun op each_inlogic_forge8_pre_cases _ = ()
  val op each_inlogic_forge8_pre_cases = TDB.find
    "each_inlogic_forge8_pre_cases"
  fun op each_inlogic_forge8_pre _ = ()
  val op each_inlogic_forge8_pre = TDB.find "each_inlogic_forge8_pre"
  fun op each_inlogic_forge8_link _ = ()
  val op each_inlogic_forge8_link = TDB.find "each_inlogic_forge8_link"
  fun op each_inlogic_forge8_def _ = ()
  val op each_inlogic_forge8_def = TDB.find "each_inlogic_forge8_def"
  fun op cv_word_to_word_inlogic_forge8_thm _ = ()
  val op cv_word_to_word_inlogic_forge8_thm = TDB.find
    "cv_word_to_word_inlogic_forge8_thm"
  fun op cv_word_to_word_inlogic_forge8_def _ = ()
  val op cv_word_to_word_inlogic_forge8_def = TDB.find
    "cv_word_to_word_inlogic_forge8_def"
  fun op cv_word_alloc_inlogic_forge8_thm _ = ()
  val op cv_word_alloc_inlogic_forge8_thm = TDB.find
    "cv_word_alloc_inlogic_forge8_thm"
  fun op cv_word_alloc_inlogic_forge8_def _ = ()
  val op cv_word_alloc_inlogic_forge8_def = TDB.find
    "cv_word_alloc_inlogic_forge8_def"
  fun op cv_sec_ends_exit_thm _ = ()
  val op cv_sec_ends_exit_thm = TDB.find "cv_sec_ends_exit_thm"
  fun op cv_sec_ends_exit_def _ = ()
  val op cv_sec_ends_exit_def = TDB.find "cv_sec_ends_exit_def"
  fun op cv_no_fall_thm _ = ()
  val op cv_no_fall_thm = TDB.find "cv_no_fall_thm"
  fun op cv_no_fall_def _ = ()
  val op cv_no_fall_def = TDB.find "cv_no_fall_def"
  fun op cv_line_no_label_thm _ = ()
  val op cv_line_no_label_thm = TDB.find "cv_line_no_label_thm"
  fun op cv_line_no_label_def _ = ()
  val op cv_line_no_label_def = TDB.find "cv_line_no_label_def"
  fun op cv_line_is_locvalue_thm _ = ()
  val op cv_line_is_locvalue_thm = TDB.find "cv_line_is_locvalue_thm"
  fun op cv_line_is_locvalue_def _ = ()
  val op cv_line_is_locvalue_def = TDB.find "cv_line_is_locvalue_def"
  fun op cv_line_is_jumpreg_thm _ = ()
  val op cv_line_is_jumpreg_thm = TDB.find "cv_line_is_jumpreg_thm"
  fun op cv_line_is_jumpreg_def _ = ()
  val op cv_line_is_jumpreg_def = TDB.find "cv_line_is_jumpreg_def"
  fun op cv_line_is_install_thm _ = ()
  val op cv_line_is_install_thm = TDB.find "cv_line_is_install_thm"
  fun op cv_line_is_install_def _ = ()
  val op cv_line_is_install_def = TDB.find "cv_line_is_install_def"
  fun op cv_line_is_exit_thm _ = ()
  val op cv_line_is_exit_thm = TDB.find "cv_line_is_exit_thm"
  fun op cv_line_is_exit_def _ = ()
  val op cv_line_is_exit_def = TDB.find "cv_line_is_exit_def"
  fun op cv_lab_stats_thm _ = ()
  val op cv_lab_stats_thm = TDB.find "cv_lab_stats_thm"
  fun op cv_lab_stats_def _ = ()
  val op cv_lab_stats_def = TDB.find "cv_lab_stats_def"
  fun op cv_lab_names_thm _ = ()
  val op cv_lab_names_thm = TDB.find "cv_lab_names_thm"
  fun op cv_lab_names_def _ = ()
  val op cv_lab_names_def = TDB.find "cv_lab_names_def"
  fun op cv_lab_info_thm _ = ()
  val op cv_lab_info_thm = TDB.find "cv_lab_info_thm"
  fun op cv_lab_info_def _ = ()
  val op cv_lab_info_def = TDB.find "cv_lab_info_def"
  fun op cv_lab_forge8_thm _ = ()
  val op cv_lab_forge8_thm = TDB.find "cv_lab_forge8_thm"
  fun op cv_lab_forge8_def _ = ()
  val op cv_lab_forge8_def = TDB.find "cv_lab_forge8_def"
  fun op cv_lab_closed_thm _ = ()
  val op cv_lab_closed_thm = TDB.find "cv_lab_closed_thm"
  fun op cv_lab_closed_def _ = ()
  val op cv_lab_closed_def = TDB.find "cv_lab_closed_def"
  fun op cv_lab_check_thm _ = ()
  val op cv_lab_check_thm = TDB.find "cv_lab_check_thm"
  fun op cv_lab_check_def _ = ()
  val op cv_lab_check_def = TDB.find "cv_lab_check_def"
  fun op cv_is_label_thm _ = ()
  val op cv_is_label_thm = TDB.find "cv_is_label_thm"
  fun op cv_is_label_def _ = ()
  val op cv_is_label_def = TDB.find "cv_is_label_def"
  fun op cv_inst_select_forge8_thm _ = ()
  val op cv_inst_select_forge8_thm = TDB.find "cv_inst_select_forge8_thm"
  fun op cv_inst_select_forge8_ind _ = ()
  val op cv_inst_select_forge8_ind = TDB.find "cv_inst_select_forge8_ind"
  fun op cv_inst_select_forge8_def _ = ()
  val op cv_inst_select_forge8_def = TDB.find "cv_inst_select_forge8_def"
  fun op cv_inst_select_exp_forge8_thm _ = ()
  val op cv_inst_select_exp_forge8_thm = TDB.find
    "cv_inst_select_exp_forge8_thm"
  fun op cv_inst_select_exp_forge8_ind _ = ()
  val op cv_inst_select_exp_forge8_ind = TDB.find
    "cv_inst_select_exp_forge8_ind"
  fun op cv_inst_select_exp_forge8_def _ = ()
  val op cv_inst_select_exp_forge8_def = TDB.find
    "cv_inst_select_exp_forge8_def"
  fun op cv_get_forced_forge8_thm _ = ()
  val op cv_get_forced_forge8_thm = TDB.find "cv_get_forced_forge8_thm"
  fun op cv_get_forced_forge8_ind _ = ()
  val op cv_get_forced_forge8_ind = TDB.find "cv_get_forced_forge8_ind"
  fun op cv_get_forced_forge8_def _ = ()
  val op cv_get_forced_forge8_def = TDB.find "cv_get_forced_forge8_def"
  fun op cv_each_inlogic_forge8_thm _ = ()
  val op cv_each_inlogic_forge8_thm = TDB.find "cv_each_inlogic_forge8_thm"
  fun op cv_each_inlogic_forge8_ind _ = ()
  val op cv_each_inlogic_forge8_ind = TDB.find "cv_each_inlogic_forge8_ind"
  fun op cv_each_inlogic_forge8_def_primitive _ = ()
  val op cv_each_inlogic_forge8_def_primitive = TDB.find
    "cv_each_inlogic_forge8_def_primitive"
  fun op cv_each_inlogic_forge8_def _ = ()
  val op cv_each_inlogic_forge8_def = TDB.find "cv_each_inlogic_forge8_def"
  fun op cv_compile_word_to_stack_forge8_thm _ = ()
  val op cv_compile_word_to_stack_forge8_thm = TDB.find
    "cv_compile_word_to_stack_forge8_thm"
  fun op cv_compile_word_to_stack_forge8_ind _ = ()
  val op cv_compile_word_to_stack_forge8_ind = TDB.find
    "cv_compile_word_to_stack_forge8_ind"
  fun op cv_compile_word_to_stack_forge8_def _ = ()
  val op cv_compile_word_to_stack_forge8_def = TDB.find
    "cv_compile_word_to_stack_forge8_def"
  fun op cv_compile_prog_forge8_thm _ = ()
  val op cv_compile_prog_forge8_thm = TDB.find "cv_compile_prog_forge8_thm"
  fun op cv_compile_prog_forge8_def _ = ()
  val op cv_compile_prog_forge8_def = TDB.find "cv_compile_prog_forge8_def"
  fun op cv_comp_forge8_thm _ = ()
  val op cv_comp_forge8_thm = TDB.find "cv_comp_forge8_thm"
  fun op cv_comp_forge8_ind _ = ()
  val op cv_comp_forge8_ind = TDB.find "cv_comp_forge8_ind"
  fun op cv_comp_forge8_def _ = ()
  val op cv_comp_forge8_def = TDB.find "cv_comp_forge8_def"
  fun op cv_asm_no_label_thm _ = ()
  val op cv_asm_no_label_thm = TDB.find "cv_asm_no_label_thm"
  fun op cv_asm_no_label_def _ = ()
  val op cv_asm_no_label_def = TDB.find "cv_asm_no_label_def"
  fun op cv_Section_lines_thm _ = ()
  val op cv_Section_lines_thm = TDB.find "cv_Section_lines_thm"
  fun op cv_Section_lines_def _ = ()
  val op cv_Section_lines_def = TDB.find "cv_Section_lines_def"
  fun op cv_MAP_lam_LENGTH_FILTER_line_is__thm _ = ()
  val op cv_MAP_lam_LENGTH_FILTER_line_is__thm = TDB.find
    "cv_MAP_lam_LENGTH_FILTER_line_is__thm"
  fun op cv_MAP_lam_LENGTH_FILTER_line_is__ind _ = ()
  val op cv_MAP_lam_LENGTH_FILTER_line_is__ind = TDB.find
    "cv_MAP_lam_LENGTH_FILTER_line_is__ind"
  fun op cv_MAP_lam_LENGTH_FILTER_line_is__def_primitive _ = ()
  val op cv_MAP_lam_LENGTH_FILTER_line_is__def_primitive = TDB.find
    "cv_MAP_lam_LENGTH_FILTER_line_is__def_primitive"
  fun op cv_MAP_lam_LENGTH_FILTER_line_is__def _ = ()
  val op cv_MAP_lam_LENGTH_FILTER_line_is__def = TDB.find
    "cv_MAP_lam_LENGTH_FILTER_line_is__def"
  fun op cv_MAP_lam_LENGTH_FILTER_line_is__1_thm _ = ()
  val op cv_MAP_lam_LENGTH_FILTER_line_is__1_thm = TDB.find
    "cv_MAP_lam_LENGTH_FILTER_line_is__1_thm"
  fun op cv_MAP_lam_LENGTH_FILTER_line_is__1_ind _ = ()
  val op cv_MAP_lam_LENGTH_FILTER_line_is__1_ind = TDB.find
    "cv_MAP_lam_LENGTH_FILTER_line_is__1_ind"
  fun op cv_MAP_lam_LENGTH_FILTER_line_is__1_def_primitive _ = ()
  val op cv_MAP_lam_LENGTH_FILTER_line_is__1_def_primitive = TDB.find
    "cv_MAP_lam_LENGTH_FILTER_line_is__1_def_primitive"
  fun op cv_MAP_lam_LENGTH_FILTER_line_is__1_def _ = ()
  val op cv_MAP_lam_LENGTH_FILTER_line_is__1_def = TDB.find
    "cv_MAP_lam_LENGTH_FILTER_line_is__1_def"
  fun op cv_MAP_Section_num_FILTER_lam___E_thm _ = ()
  val op cv_MAP_Section_num_FILTER_lam___E_thm = TDB.find
    "cv_MAP_Section_num_FILTER_lam___E_thm"
  fun op cv_MAP_Section_num_FILTER_lam___E_ind _ = ()
  val op cv_MAP_Section_num_FILTER_lam___E_ind = TDB.find
    "cv_MAP_Section_num_FILTER_lam___E_ind"
  fun op cv_MAP_Section_num_FILTER_lam___E_def_primitive _ = ()
  val op cv_MAP_Section_num_FILTER_lam___E_def_primitive = TDB.find
    "cv_MAP_Section_num_FILTER_lam___E_def_primitive"
  fun op cv_MAP_Section_num_FILTER_lam___E_def _ = ()
  val op cv_MAP_Section_num_FILTER_lam___E_def = TDB.find
    "cv_MAP_Section_num_FILTER_lam___E_def"
  fun op cv_FILTER_line_is_locvalue_Sectio_thm _ = ()
  val op cv_FILTER_line_is_locvalue_Sectio_thm = TDB.find
    "cv_FILTER_line_is_locvalue_Sectio_thm"
  fun op cv_FILTER_line_is_locvalue_Sectio_ind _ = ()
  val op cv_FILTER_line_is_locvalue_Sectio_ind = TDB.find
    "cv_FILTER_line_is_locvalue_Sectio_ind"
  fun op cv_FILTER_line_is_locvalue_Sectio_def_primitive _ = ()
  val op cv_FILTER_line_is_locvalue_Sectio_def_primitive = TDB.find
    "cv_FILTER_line_is_locvalue_Sectio_def_primitive"
  fun op cv_FILTER_line_is_locvalue_Sectio_def _ = ()
  val op cv_FILTER_line_is_locvalue_Sectio_def = TDB.find
    "cv_FILTER_line_is_locvalue_Sectio_def"
  fun op cv_FILTER_line_is_jumpreg_Section_thm _ = ()
  val op cv_FILTER_line_is_jumpreg_Section_thm = TDB.find
    "cv_FILTER_line_is_jumpreg_Section_thm"
  fun op cv_FILTER_line_is_jumpreg_Section_ind _ = ()
  val op cv_FILTER_line_is_jumpreg_Section_ind = TDB.find
    "cv_FILTER_line_is_jumpreg_Section_ind"
  fun op cv_FILTER_line_is_jumpreg_Section_def_primitive _ = ()
  val op cv_FILTER_line_is_jumpreg_Section_def_primitive = TDB.find
    "cv_FILTER_line_is_jumpreg_Section_def_primitive"
  fun op cv_FILTER_line_is_jumpreg_Section_def _ = ()
  val op cv_FILTER_line_is_jumpreg_Section_def = TDB.find
    "cv_FILTER_line_is_jumpreg_Section_def"
  fun op cv_FILTER_lam___is_label_Section__thm _ = ()
  val op cv_FILTER_lam___is_label_Section__thm = TDB.find
    "cv_FILTER_lam___is_label_Section__thm"
  fun op cv_FILTER_lam___is_label_Section__ind _ = ()
  val op cv_FILTER_lam___is_label_Section__ind = TDB.find
    "cv_FILTER_lam___is_label_Section__ind"
  fun op cv_FILTER_lam___is_label_Section__def_primitive _ = ()
  val op cv_FILTER_lam___is_label_Section__def_primitive = TDB.find
    "cv_FILTER_lam___is_label_Section__def_primitive"
  fun op cv_FILTER_lam___is_label_Section__def _ = ()
  val op cv_FILTER_lam___is_label_Section__def = TDB.find
    "cv_FILTER_lam___is_label_Section__def"
  fun op cv_FILTER_lam___EVERY_line_no_lab_thm _ = ()
  val op cv_FILTER_lam___EVERY_line_no_lab_thm = TDB.find
    "cv_FILTER_lam___EVERY_line_no_lab_thm"
  fun op cv_FILTER_lam___EVERY_line_no_lab_ind _ = ()
  val op cv_FILTER_lam___EVERY_line_no_lab_ind = TDB.find
    "cv_FILTER_lam___EVERY_line_no_lab_ind"
  fun op cv_FILTER_lam___EVERY_line_no_lab_def_primitive _ = ()
  val op cv_FILTER_lam___EVERY_line_no_lab_def_primitive = TDB.find
    "cv_FILTER_lam___EVERY_line_no_lab_def_primitive"
  fun op cv_FILTER_lam___EVERY_line_no_lab_def _ = ()
  val op cv_FILTER_lam___EVERY_line_no_lab_def = TDB.find
    "cv_FILTER_lam___EVERY_line_no_lab_def"
  fun op cv_FILTER_lam_EXISTS_line_is_inst_thm _ = ()
  val op cv_FILTER_lam_EXISTS_line_is_inst_thm = TDB.find
    "cv_FILTER_lam_EXISTS_line_is_inst_thm"
  fun op cv_FILTER_lam_EXISTS_line_is_inst_ind _ = ()
  val op cv_FILTER_lam_EXISTS_line_is_inst_ind = TDB.find
    "cv_FILTER_lam_EXISTS_line_is_inst_ind"
  fun op cv_FILTER_lam_EXISTS_line_is_inst_def_primitive _ = ()
  val op cv_FILTER_lam_EXISTS_line_is_inst_def_primitive = TDB.find
    "cv_FILTER_lam_EXISTS_line_is_inst_def_primitive"
  fun op cv_FILTER_lam_EXISTS_line_is_inst_def _ = ()
  val op cv_FILTER_lam_EXISTS_line_is_inst_def = TDB.find
    "cv_FILTER_lam_EXISTS_line_is_inst_def"
  fun op cv_EXISTS_line_is_install_Section_thm _ = ()
  val op cv_EXISTS_line_is_install_Section_thm = TDB.find
    "cv_EXISTS_line_is_install_Section_thm"
  fun op cv_EXISTS_line_is_install_Section_def _ = ()
  val op cv_EXISTS_line_is_install_Section_def = TDB.find
    "cv_EXISTS_line_is_install_Section_def"
  fun op cv_EVERY_line_no_label_Section_li_thm _ = ()
  val op cv_EVERY_line_no_label_Section_li_thm = TDB.find
    "cv_EVERY_line_no_label_Section_li_thm"
  fun op cv_EVERY_line_no_label_Section_li_def _ = ()
  val op cv_EVERY_line_no_label_Section_li_def = TDB.find
    "cv_EVERY_line_no_label_Section_li_def"
  fun op cv_EVERY_lam____IN_Section_num_LI_thm _ = ()
  val op cv_EVERY_lam____IN_Section_num_LI_thm = TDB.find
    "cv_EVERY_lam____IN_Section_num_LI_thm"
  fun op cv_EVERY_lam____IN_Section_num_LI_def _ = ()
  val op cv_EVERY_lam____IN_Section_num_LI_def = TDB.find
    "cv_EVERY_lam____IN_Section_num_LI_def"
  fun op compile_word_to_stack_forge8_pre_strongind _ = ()
  val op compile_word_to_stack_forge8_pre_strongind = TDB.find
    "compile_word_to_stack_forge8_pre_strongind"
  fun op compile_word_to_stack_forge8_pre_rules _ = ()
  val op compile_word_to_stack_forge8_pre_rules = TDB.find
    "compile_word_to_stack_forge8_pre_rules"
  fun op compile_word_to_stack_forge8_pre_ind _ = ()
  val op compile_word_to_stack_forge8_pre_ind = TDB.find
    "compile_word_to_stack_forge8_pre_ind"
  fun op compile_word_to_stack_forge8_pre_cases _ = ()
  val op compile_word_to_stack_forge8_pre_cases = TDB.find
    "compile_word_to_stack_forge8_pre_cases"
  fun op compile_word_to_stack_forge8_pre _ = ()
  val op compile_word_to_stack_forge8_pre = TDB.find
    "compile_word_to_stack_forge8_pre"
  fun op compile_word_to_stack_forge8_link _ = ()
  val op compile_word_to_stack_forge8_link = TDB.find
    "compile_word_to_stack_forge8_link"
  fun op compile_word_to_stack_forge8_def _ = ()
  val op compile_word_to_stack_forge8_def = TDB.find
    "compile_word_to_stack_forge8_def"
  fun op compile_prog_forge8_link _ = ()
  val op compile_prog_forge8_link = TDB.find "compile_prog_forge8_link"
  fun op compile_prog_forge8_def _ = ()
  val op compile_prog_forge8_def = TDB.find "compile_prog_forge8_def"
  fun op comp_forge8_pre_strongind _ = ()
  val op comp_forge8_pre_strongind = TDB.find "comp_forge8_pre_strongind"
  fun op comp_forge8_pre_rules _ = ()
  val op comp_forge8_pre_rules = TDB.find "comp_forge8_pre_rules"
  fun op comp_forge8_pre_ind _ = ()
  val op comp_forge8_pre_ind = TDB.find "comp_forge8_pre_ind"
  fun op comp_forge8_pre_cases _ = ()
  val op comp_forge8_pre_cases = TDB.find "comp_forge8_pre_cases"
  fun op comp_forge8_pre _ = ()
  val op comp_forge8_pre = TDB.find "comp_forge8_pre"
  fun op comp_forge8_link _ = ()
  val op comp_forge8_link = TDB.find "comp_forge8_link"
  fun op comp_forge8_def _ = ()
  val op comp_forge8_def = TDB.find "comp_forge8_def"
  fun op asm_no_label_def _ = ()
  val op asm_no_label_def = TDB.find "asm_no_label_def"
  fun op MAP_lam_LENGTH_FILTER_line_is__ho _ = ()
  val op MAP_lam_LENGTH_FILTER_line_is__ho = TDB.find
    "MAP_lam_LENGTH_FILTER_line_is__ho"
  fun op MAP_lam_LENGTH_FILTER_line_is__def _ = ()
  val op MAP_lam_LENGTH_FILTER_line_is__def = TDB.find
    "MAP_lam_LENGTH_FILTER_line_is__def"
  fun op MAP_lam_LENGTH_FILTER_line_is__1_ho _ = ()
  val op MAP_lam_LENGTH_FILTER_line_is__1_ho = TDB.find
    "MAP_lam_LENGTH_FILTER_line_is__1_ho"
  fun op MAP_lam_LENGTH_FILTER_line_is__1_def _ = ()
  val op MAP_lam_LENGTH_FILTER_line_is__1_def = TDB.find
    "MAP_lam_LENGTH_FILTER_line_is__1_def"
  fun op MAP_Section_num_FILTER_lam___E_ho _ = ()
  val op MAP_Section_num_FILTER_lam___E_ho = TDB.find
    "MAP_Section_num_FILTER_lam___E_ho"
  fun op MAP_Section_num_FILTER_lam___E_def _ = ()
  val op MAP_Section_num_FILTER_lam___E_def = TDB.find
    "MAP_Section_num_FILTER_lam___E_def"
  fun op FILTER_line_is_locvalue_Sectio_ho _ = ()
  val op FILTER_line_is_locvalue_Sectio_ho = TDB.find
    "FILTER_line_is_locvalue_Sectio_ho"
  fun op FILTER_line_is_locvalue_Sectio_def _ = ()
  val op FILTER_line_is_locvalue_Sectio_def = TDB.find
    "FILTER_line_is_locvalue_Sectio_def"
  fun op FILTER_line_is_jumpreg_Section_ho _ = ()
  val op FILTER_line_is_jumpreg_Section_ho = TDB.find
    "FILTER_line_is_jumpreg_Section_ho"
  fun op FILTER_line_is_jumpreg_Section_def _ = ()
  val op FILTER_line_is_jumpreg_Section_def = TDB.find
    "FILTER_line_is_jumpreg_Section_def"
  fun op FILTER_lam___is_label_Section__ho _ = ()
  val op FILTER_lam___is_label_Section__ho = TDB.find
    "FILTER_lam___is_label_Section__ho"
  fun op FILTER_lam___is_label_Section__def _ = ()
  val op FILTER_lam___is_label_Section__def = TDB.find
    "FILTER_lam___is_label_Section__def"
  fun op FILTER_lam___EVERY_line_no_lab_ho _ = ()
  val op FILTER_lam___EVERY_line_no_lab_ho = TDB.find
    "FILTER_lam___EVERY_line_no_lab_ho"
  fun op FILTER_lam___EVERY_line_no_lab_def _ = ()
  val op FILTER_lam___EVERY_line_no_lab_def = TDB.find
    "FILTER_lam___EVERY_line_no_lab_def"
  fun op FILTER_lam_EXISTS_line_is_inst_ho _ = ()
  val op FILTER_lam_EXISTS_line_is_inst_ho = TDB.find
    "FILTER_lam_EXISTS_line_is_inst_ho"
  fun op FILTER_lam_EXISTS_line_is_inst_def _ = ()
  val op FILTER_lam_EXISTS_line_is_inst_def = TDB.find
    "FILTER_lam_EXISTS_line_is_inst_def"
  fun op EXISTS_line_is_install_Section_ho _ = ()
  val op EXISTS_line_is_install_Section_ho = TDB.find
    "EXISTS_line_is_install_Section_ho"
  fun op EXISTS_line_is_install_Section_def _ = ()
  val op EXISTS_line_is_install_Section_def = TDB.find
    "EXISTS_line_is_install_Section_def"
  fun op EVERY_line_no_label_Section_li_ho _ = ()
  val op EVERY_line_no_label_Section_li_ho = TDB.find
    "EVERY_line_no_label_Section_li_ho"
  fun op EVERY_line_no_label_Section_li_def _ = ()
  val op EVERY_line_no_label_Section_li_def = TDB.find
    "EVERY_line_no_label_Section_li_def"
  fun op EVERY_lam____IN_Section_num_LI_ho _ = ()
  val op EVERY_lam____IN_Section_num_LI_ho = TDB.find
    "EVERY_lam____IN_Section_num_LI_ho"
  fun op EVERY_lam____IN_Section_num_LI_def _ = ()
  val op EVERY_lam____IN_Section_num_LI_def = TDB.find
    "EVERY_lam____IN_Section_num_LI_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundLabClosure"

end
