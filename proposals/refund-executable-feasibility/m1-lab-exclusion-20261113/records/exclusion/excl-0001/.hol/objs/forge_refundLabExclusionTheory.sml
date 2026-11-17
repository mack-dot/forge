structure forge_refundLabExclusionTheory :> forge_refundLabExclusionTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundLabExclusionTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_labRegionAlignedTheory forge_refundLabRunTheory
  lab_to_targetProofTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundLabExclusion",
        hash = "f2e69144a61f9dc39b64b1f8ab789bb9194cb648",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundLabExclusion" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_lab_good_init_avoids_install _ = ()
  val op refund_lab_good_init_avoids_install = TDB.find
    "refund_lab_good_init_avoids_install"
  fun op refund_lab_aligned_init_avoids_install _ = ()
  val op refund_lab_aligned_init_avoids_install = TDB.find
    "refund_lab_aligned_init_avoids_install"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundLabExclusion"

end
