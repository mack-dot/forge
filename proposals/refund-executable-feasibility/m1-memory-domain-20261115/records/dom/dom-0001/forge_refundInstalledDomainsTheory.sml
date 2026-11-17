structure forge_refundInstalledDomainsTheory :> forge_refundInstalledDomainsTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundInstalledDomainsTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundEntrySatTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundInstalledDomains",
        hash = "f1a6acf05cfaa49965c371977c2fb758c44f8f1d",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundInstalledDomains" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_t_target_state_rel _ = ()
  val op refund_t_target_state_rel = TDB.find "refund_t_target_state_rel"
  fun op refund_t_target_configured _ = ()
  val op refund_t_target_configured = TDB.find "refund_t_target_configured"
  fun op refund_t_def _ = () val op refund_t_def = TDB.find "refund_t_def"
  fun op refund_mem_dm_def _ = ()
  val op refund_mem_dm_def = TDB.find "refund_mem_dm_def"
  fun op refund_heap_clear_def _ = ()
  val op refund_heap_clear_def = TDB.find "refund_heap_clear_def"
  fun op refund_heap_clear_IMP_header_separation _ = ()
  val op refund_heap_clear_IMP_header_separation = TDB.find
    "refund_heap_clear_IMP_header_separation"
  fun op refund_heap_bitmaps_subset _ = ()
  val op refund_heap_bitmaps_subset = TDB.find "refund_heap_bitmaps_subset"
  fun op refund_heap_bitmaps_disjoint _ = ()
  val op refund_heap_bitmaps_disjoint = TDB.find
    "refund_heap_bitmaps_disjoint"
  fun op refund_heap_bitmaps_closed _ = ()
  val op refund_heap_bitmaps_closed = TDB.find "refund_heap_bitmaps_closed"
  fun op refund_end_state_established _ = ()
  val op refund_end_state_established = TDB.find
    "refund_end_state_established"
  fun op refund_end_state_def _ = ()
  val op refund_end_state_def = TDB.find "refund_end_state_def"
  fun op refund_code_loaded _ = ()
  val op refund_code_loaded = TDB.find "refund_code_loaded"
  fun op refund_code_dm_def _ = ()
  val op refund_code_dm_def = TDB.find "refund_code_dm_def"
  fun op refund_code_bytes_in_mem _ = ()
  val op refund_code_bytes_in_mem = TDB.find "refund_code_bytes_in_mem"
  fun op refund_code_buffer_in_dm _ = ()
  val op refund_code_buffer_in_dm = TDB.find "refund_code_buffer_in_dm"
  fun op refund_code_addr_not_excluded _ = ()
  val op refund_code_addr_not_excluded = TDB.find
    "refund_code_addr_not_excluded"
  fun op refund_code_addr_in_dm _ = ()
  val op refund_code_addr_in_dm = TDB.find "refund_code_addr_in_dm"
  fun op refund_bitmaps_dm_range _ = ()
  val op refund_bitmaps_dm_range = TDB.find "refund_bitmaps_dm_range"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundInstalledDomains"

end
