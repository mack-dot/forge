structure forge_refundInstalledAssemblyTheory :> forge_refundInstalledAssemblyTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundInstalledAssemblyTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundInstalledDomainsTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundInstalledAssembly",
        hash = "65befa1be46055a0e9cc9629527292abd9c0e162",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundInstalledAssembly"
      {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op unaligned_heap_end_not_closed _ = ()
  val op unaligned_heap_end_not_closed = TDB.find
    "unaligned_heap_end_not_closed"
  fun op refund_u298_exclusion_from_entry _ = ()
  val op refund_u298_exclusion_from_entry = TDB.find
    "refund_u298_exclusion_from_entry"
  fun op refund_installed_rest_def _ = ()
  val op refund_installed_rest_def = TDB.find "refund_installed_rest_def"
  fun op refund_installed_from_entry _ = ()
  val op refund_installed_from_entry = TDB.find
    "refund_installed_from_entry"
  fun op refund_installed_from_end_state _ = ()
  val op refund_installed_from_end_state = TDB.find
    "refund_installed_from_end_state"
  fun op refund_entry_and_heap_premises_satisfiable _ = ()
  val op refund_entry_and_heap_premises_satisfiable = TDB.find
    "refund_entry_and_heap_premises_satisfiable"
  fun op refund_behavior_from_entry _ = ()
  val op refund_behavior_from_entry = TDB.find "refund_behavior_from_entry"
  fun op prog_addresses_mismatch_rejected _ = ()
  val op prog_addresses_mismatch_rejected = TDB.find
    "prog_addresses_mismatch_rejected"
  fun op heap_on_code_rejected _ = ()
  val op heap_on_code_rejected = TDB.find "heap_on_code_rejected"
  fun op heap_on_bitmaps_rejected _ = ()
  val op heap_on_bitmaps_rejected = TDB.find "heap_on_bitmaps_rejected"
  fun op code_outside_domain_rejected _ = ()
  val op code_outside_domain_rejected = TDB.find
    "code_outside_domain_rejected"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundInstalledAssembly"

end
