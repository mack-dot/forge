structure forge_refundSignedLenTheory :> forge_refundSignedLenTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundSignedLenTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundCallSiteTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundSignedLen",
        hash = "6addaefb79fb31d1a5957ae40caa9fe89eacf659",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundSignedLen" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op universe_not_below_half _ = ()
  val op universe_not_below_half = TDB.find "universe_not_below_half"
  fun op refund_mem_dm_below_half _ = ()
  val op refund_mem_dm_below_half = TDB.find "refund_mem_dm_below_half"
  fun op read_bytearray_below_half_bound _ = ()
  val op read_bytearray_below_half_bound = TDB.find
    "read_bytearray_below_half_bound"
  fun op negative_alen_not_covered _ = ()
  val op negative_alen_not_covered = TDB.find "negative_alen_not_covered"
  fun op high_heap_end_not_below_half _ = ()
  val op high_heap_end_not_below_half = TDB.find
    "high_heap_end_not_below_half"
  fun op heap_premises_admit_huge_heap _ = ()
  val op heap_premises_admit_huge_heap = TDB.find
    "heap_premises_admit_huge_heap"
  fun op fficlose_call_pre_no_len_sign_def _ = ()
  val op fficlose_call_pre_no_len_sign_def = TDB.find
    "fficlose_call_pre_no_len_sign_def"
  fun op fficlose_call_pre_no_len_from_no_sign _ = ()
  val op fficlose_call_pre_no_len_from_no_sign = TDB.find
    "fficlose_call_pre_no_len_from_no_sign"
  fun op close_call_site_signed_alen_model _ = ()
  val op close_call_site_signed_alen_model = TDB.find
    "close_call_site_signed_alen_model"
  fun op close_call_site_signed_alen _ = ()
  val op close_call_site_signed_alen = TDB.find
    "close_call_site_signed_alen"
  fun op close_call_alen_below_half _ = ()
  val op close_call_alen_below_half = TDB.find "close_call_alen_below_half"
  fun op cake_fficlose_path_at_reachable_call_signed _ = ()
  val op cake_fficlose_path_at_reachable_call_signed = TDB.find
    "cake_fficlose_path_at_reachable_call_signed"
  fun op arbitrary_state_can_violate_arguments _ = ()
  val op arbitrary_state_can_violate_arguments = TDB.find
    "arbitrary_state_can_violate_arguments"
  fun op addresses_below_half_def _ = ()
  val op addresses_below_half_def = TDB.find "addresses_below_half_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundSignedLen"

end
