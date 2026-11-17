structure forge_refundEntrySatTheory :> forge_refundEntrySatTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundEntrySatTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundLoaderMemoryTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundEntrySat",
        hash = "f7ade41438076f0a9b509f14a1213c1392f28253",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundEntrySat" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op sat_slot_8 _ = () val op sat_slot_8 = TDB.find "sat_slot_8"
  fun op sat_slot_16 _ = () val op sat_slot_16 = TDB.find "sat_slot_16"
  fun op sat_slot_0 _ = () val op sat_slot_0 = TDB.find "sat_slot_0"
  fun op sat_separation _ = ()
  val op sat_separation = TDB.find "sat_separation"
  fun op sat_mem_image _ = ()
  val op sat_mem_image = TDB.find "sat_mem_image"
  fun op sat_mem_def _ = () val op sat_mem_def = TDB.find "sat_mem_def"
  fun op refund_entry_pre_witness _ = ()
  val op refund_entry_pre_witness = TDB.find "refund_entry_pre_witness"
  fun op refund_entry_pre_satisfiable _ = ()
  val op refund_entry_pre_satisfiable = TDB.find
    "refund_entry_pre_satisfiable"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundEntrySat"

end
