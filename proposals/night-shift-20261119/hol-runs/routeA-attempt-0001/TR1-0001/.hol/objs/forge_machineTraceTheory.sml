structure forge_machineTraceTheory :> forge_machineTraceTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_machineTraceTheory ... "
    else ()
  
  open Type Term Thm
  local open arm8_configProofTheory forge_refundArm8CompileTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_machineTrace",
        hash = "e42330345a0f43197f8fc1785de597ee07ec12e4",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_machineTrace" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op trace_st_upd _ = () val op trace_st_upd = TDB.find "trace_st_upd"
  fun op trace_st_ind _ = () val op trace_st_ind = TDB.find "trace_st_ind"
  fun op trace_st_def _ = () val op trace_st_def = TDB.find "trace_st_def"
  fun op trace_ok_upd _ = () val op trace_ok_upd = TDB.find "trace_ok_upd"
  fun op trace_ok_ind _ = () val op trace_ok_ind = TDB.find "trace_ok_ind"
  fun op trace_ok_def _ = () val op trace_ok_def = TDB.find "trace_ok_def"
  fun op trace_next_interfer_shift _ = ()
  val op trace_next_interfer_shift = TDB.find "trace_next_interfer_shift"
  fun op trace_next_interfer_proj _ = ()
  val op trace_next_interfer_proj = TDB.find "trace_next_interfer_proj"
  fun op trace_next_interfer_ok _ = ()
  val op trace_next_interfer_ok = TDB.find "trace_next_interfer_ok"
  fun op trace_next_interfer_ind _ = ()
  val op trace_next_interfer_ind = TDB.find "trace_next_interfer_ind"
  fun op trace_next_interfer_ffi _ = ()
  val op trace_next_interfer_ffi = TDB.find "trace_next_interfer_ffi"
  fun op trace_next_interfer_def _ = ()
  val op trace_next_interfer_def = TDB.find "trace_next_interfer_def"
  fun op trace_last_ind _ = ()
  val op trace_last_ind = TDB.find "trace_last_ind"
  fun op trace_last_def _ = ()
  val op trace_last_def = TDB.find "trace_last_def"
  fun op trace_io _ = () val op trace_io = TDB.find "trace_io"
  fun op trace_gen _ = () val op trace_gen = TDB.find "trace_gen"
  fun op trace_ffi_interfer_step _ = ()
  val op trace_ffi_interfer_step = TDB.find "trace_ffi_interfer_step"
  fun op trace_ffi_interfer_shift _ = ()
  val op trace_ffi_interfer_shift = TDB.find "trace_ffi_interfer_shift"
  fun op trace_ffi_interfer_off _ = ()
  val op trace_ffi_interfer_off = TDB.find "trace_ffi_interfer_off"
  fun op trace_ffi_interfer_nil _ = ()
  val op trace_ffi_interfer_nil = TDB.find "trace_ffi_interfer_nil"
  fun op trace_ffi_interfer_ind _ = ()
  val op trace_ffi_interfer_ind = TDB.find "trace_ffi_interfer_ind"
  fun op trace_ffi_interfer_guard _ = ()
  val op trace_ffi_interfer_guard = TDB.find "trace_ffi_interfer_guard"
  fun op trace_ffi_interfer_def _ = ()
  val op trace_ffi_interfer_def = TDB.find "trace_ffi_interfer_def"
  fun op trace_events_ind _ = ()
  val op trace_events_ind = TDB.find "trace_events_ind"
  fun op trace_events_def _ = ()
  val op trace_events_def = TDB.find "trace_events_def"
  fun op trace_event_wit _ = ()
  val op trace_event_wit = TDB.find "trace_event_wit"
  fun op trace_event_size_def _ = ()
  val op trace_event_size_def = TDB.find "trace_event_size_def"
  fun op trace_event_size_MAP _ = ()
  val op trace_event_size_MAP = TDB.find "trace_event_size_MAP"
  fun op trace_event_nchotomy _ = ()
  val op trace_event_nchotomy = TDB.find "trace_event_nchotomy"
  fun op trace_event_inh _ = ()
  val op trace_event_inh = TDB.find "trace_event_inh"
  fun op trace_event_induction _ = ()
  val op trace_event_induction = TDB.find "trace_event_induction"
  fun op trace_event_distinct _ = ()
  val op trace_event_distinct = TDB.find "trace_event_distinct"
  fun op trace_event_case_eq _ = ()
  val op trace_event_case_eq = TDB.find "trace_event_case_eq"
  fun op trace_event_case_def _ = ()
  val op trace_event_case_def = TDB.find "trace_event_case_def"
  fun op trace_event_case_cong _ = ()
  val op trace_event_case_cong = TDB.find "trace_event_case_cong"
  fun op trace_event_bnd _ = ()
  val op trace_event_bnd = TDB.find "trace_event_bnd"
  fun op trace_event_TY_DEF _ = ()
  val op trace_event_TY_DEF = TDB.find "trace_event_TY_DEF"
  fun op trace_event_MAP_O _ = ()
  val op trace_event_MAP_O = TDB.find "trace_event_MAP_O"
  fun op trace_event_MAP_IMAGE _ = ()
  val op trace_event_MAP_IMAGE = TDB.find "trace_event_MAP_IMAGE"
  fun op trace_event_MAP_ID _ = ()
  val op trace_event_MAP_ID = TDB.find "trace_event_MAP_ID"
  fun op trace_event_MAP_CONG _ = ()
  val op trace_event_MAP_CONG = TDB.find "trace_event_MAP_CONG"
  fun op trace_event_CONS_def _ = ()
  val op trace_event_CONS_def = TDB.find "trace_event_CONS_def"
  fun op trace_event_Axiom _ = ()
  val op trace_event_Axiom = TDB.find "trace_event_Axiom"
  fun op trace_event_ABSREP _ = ()
  val op trace_event_ABSREP = TDB.find "trace_event_ABSREP"
  fun op trace_event_11 _ = ()
  val op trace_event_11 = TDB.find "trace_event_11"
  fun op trace_eventSET_thm _ = ()
  val op trace_eventSET_thm = TDB.find "trace_eventSET_thm"
  fun op trace_eventSET_ind _ = ()
  val op trace_eventSET_ind = TDB.find "trace_eventSET_ind"
  fun op trace_eventSET_def _ = ()
  val op trace_eventSET_def = TDB.find "trace_eventSET_def"
  fun op trace_eventREL_def _ = ()
  val op trace_eventREL_def = TDB.find "trace_eventREL_def"
  fun op trace_eventMAP_thm _ = ()
  val op trace_eventMAP_thm = TDB.find "trace_eventMAP_thm"
  fun op trace_eventMAP_ind _ = ()
  val op trace_eventMAP_ind = TDB.find "trace_eventMAP_ind"
  fun op trace_eventMAP_def _ = ()
  val op trace_eventMAP_def = TDB.find "trace_eventMAP_def"
  fun op toy_trace_ok _ = () val op toy_trace_ok = TDB.find "toy_trace_ok"
  fun op toy_trace_events _ = ()
  val op toy_trace_events = TDB.find "toy_trace_events"
  fun op toy_target_fields _ = ()
  val op toy_target_fields = TDB.find "toy_target_fields"
  fun op toy_target_def _ = ()
  val op toy_target_def = TDB.find "toy_target_def"
  fun op toy_st_def _ = () val op toy_st_def = TDB.find "toy_st_def"
  fun op toy_mc_def _ = () val op toy_mc_def = TDB.find "toy_mc_def"
  fun op toy_encoded _ = () val op toy_encoded = TDB.find "toy_encoded"
  fun op toy_config_def _ = ()
  val op toy_config_def = TDB.find "toy_config_def"
  fun op toy_bad_rejected _ = ()
  val op toy_bad_rejected = TDB.find "toy_bad_rejected"
  fun op term_after _ = () val op term_after = TDB.find "term_after"
  fun op step_event_ok_upd _ = ()
  val op step_event_ok_upd = TDB.find "step_event_ok_upd"
  fun op step_event_ok_def _ = ()
  val op step_event_ok_def = TDB.find "step_event_ok_def"
  fun op shift_seq_shift_seq _ = ()
  val op shift_seq_shift_seq = TDB.find "shift_seq_shift_seq"
  fun op shift_seq_1_pred _ = ()
  val op shift_seq_1_pred = TDB.find "shift_seq_1_pred"
  fun op shift_seq_0 _ = () val op shift_seq_0 = TDB.find "shift_seq_0"
  fun op prefix_of_halt _ = ()
  val op prefix_of_halt = TDB.find "prefix_of_halt"
  fun op nffis_ind _ = () val op nffis_ind = TDB.find "nffis_ind"
  fun op nffis_def_primitive _ = ()
  val op nffis_def_primitive = TDB.find "nffis_def_primitive"
  fun op nffis_def _ = () val op nffis_def = TDB.find "nffis_def"
  fun op fst_error _ = () val op fst_error = TDB.find "fst_error"
  fun op ffi_post_st_upd _ = ()
  val op ffi_post_st_upd = TDB.find "ffi_post_st_upd"
  fun op ffi_post_st_io _ = ()
  val op ffi_post_st_io = TDB.find "ffi_post_st_io"
  fun op ffi_post_st_def _ = ()
  val op ffi_post_st_def = TDB.find "ffi_post_st_def"
  fun op ffi_event_ok_upd _ = ()
  val op ffi_event_ok_upd = TDB.find "ffi_event_ok_upd"
  fun op ffi_event_ok_def _ = ()
  val op ffi_event_ok_def = TDB.find "ffi_event_ok_def"
  fun op ffi_call_event_def _ = ()
  val op ffi_call_event_def = TDB.find "ffi_call_event_def"
  fun op fail_after _ = () val op fail_after = TDB.find "fail_after"
  fun op evaluate_zero _ = ()
  val op evaluate_zero = TDB.find "evaluate_zero"
  fun op evaluate_one_step_event _ = ()
  val op evaluate_one_step_event = TDB.find "evaluate_one_step_event"
  fun op evaluate_one_ffi_event _ = ()
  val op evaluate_one_ffi_event = TDB.find "evaluate_one_ffi_event"
  fun op evaluate_follows_trace _ = ()
  val op evaluate_follows_trace = TDB.find "evaluate_follows_trace"
  fun op evaluate_cong _ = ()
  val op evaluate_cong = TDB.find "evaluate_cong"
  fun op div_after _ = () val op div_after = TDB.find "div_after"
  fun op datatype_trace_event _ = ()
  val op datatype_trace_event = TDB.find "datatype_trace_event"
  fun op call_FFI_return_io _ = ()
  val op call_FFI_return_io = TDB.find "call_FFI_return_io"
  fun op add_clock_swap _ = ()
  val op add_clock_swap = TDB.find "add_clock_swap"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_machineTrace"

end
