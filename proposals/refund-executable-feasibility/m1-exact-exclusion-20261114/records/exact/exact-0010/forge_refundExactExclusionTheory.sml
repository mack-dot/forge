structure forge_refundExactExclusionTheory :> forge_refundExactExclusionTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundExactExclusionTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundLabFilteredTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundExactExclusion",
        hash = "643e65d66faa076c6db5b06a4782269a8337c009",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundExactExclusion" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op trivial_invariant_not_closed _ = ()
  val op trivial_invariant_not_closed = TDB.find
    "trivial_invariant_not_closed"
  fun op sm_free_no_share_mem_inst _ = ()
  val op sm_free_no_share_mem_inst = TDB.find "sm_free_no_share_mem_inst"
  fun op sharemem_line_detected _ = ()
  val op sharemem_line_detected = TDB.find "sharemem_line_detected"
  fun op region2_lab_step _ = ()
  val op region2_lab_step = TDB.find "region2_lab_step"
  fun op refund_target_install_exclusion _ = ()
  val op refund_target_install_exclusion = TDB.find
    "refund_target_install_exclusion"
  fun op refund_lab_step_closed _ = ()
  val op refund_lab_step_closed = TDB.find "refund_lab_step_closed"
  fun op refund_lab_sharemem_counts _ = ()
  val op refund_lab_sharemem_counts = TDB.find "refund_lab_sharemem_counts"
  fun op refund_lab_no_share_mem _ = ()
  val op refund_lab_no_share_mem = TDB.find "refund_lab_no_share_mem"
  fun op refund_lab_inv_init _ = ()
  val op refund_lab_inv_init = TDB.find "refund_lab_inv_init"
  fun op refund_lab_inv_def _ = ()
  val op refund_lab_inv_def = TDB.find "refund_lab_inv_def"
  fun op refund_filtered_walk_not_closed_29 _ = ()
  val op refund_filtered_walk_not_closed_29 = TDB.find
    "refund_filtered_walk_not_closed_29"
  fun op refund_filtered_region_hyp _ = ()
  val op refund_filtered_region_hyp = TDB.find "refund_filtered_region_hyp"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundExactExclusion"

end
