structure forge_refundReadBoundaryTheory :> forge_refundReadBoundaryTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundReadBoundaryTheory ... "
    else ()
  
  open Type Term Thm
  local open fsFFIPropsTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundReadBoundary",
        hash = "ab8a4f6b6ac182c5bfa6a0c03b19b37d068e8695",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundReadBoundary" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op read_ready _ = () val op read_ready = TDB.find "read_ready"
  fun op ffi_read_unavailable _ = ()
  val op ffi_read_unavailable = TDB.find "ffi_read_unavailable"
  fun op ffi_read_ready_status _ = ()
  val op ffi_read_ready_status = TDB.find "ffi_read_ready_status"
  fun op ffi_read_ready _ = ()
  val op ffi_read_ready = TDB.find "ffi_read_ready"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundReadBoundary"

end
