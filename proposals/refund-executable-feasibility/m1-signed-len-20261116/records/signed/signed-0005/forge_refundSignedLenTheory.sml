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
        hash = "d258ab21cb0caff2f9f36a10fbac2c4a8873594e",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundSignedLen" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op read_bytearray_below_half_bound _ = ()
  val op read_bytearray_below_half_bound = TDB.find
    "read_bytearray_below_half_bound"
  fun op heap_premises_admit_huge_heap _ = ()
  val op heap_premises_admit_huge_heap = TDB.find
    "heap_premises_admit_huge_heap"
  fun op close_call_site_signed_alen _ = ()
  val op close_call_site_signed_alen = TDB.find
    "close_call_site_signed_alen"
  fun op close_call_alen_below_half _ = ()
  val op close_call_alen_below_half = TDB.find "close_call_alen_below_half"
  fun op addresses_below_half_def _ = ()
  val op addresses_below_half_def = TDB.find "addresses_below_half_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundSignedLen"

end
