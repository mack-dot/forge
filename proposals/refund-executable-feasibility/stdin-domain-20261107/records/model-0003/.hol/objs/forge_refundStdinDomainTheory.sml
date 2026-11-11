structure forge_refundStdinDomainTheory :> forge_refundStdinDomainTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundStdinDomainTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundReadBoundaryTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundStdinDomain",
        hash = "b552b1a696486903772b707c8a91c5c9d2f6da0a",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundStdinDomain" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op wf_read_inputs _ = ()
  val op wf_read_inputs = TDB.find "wf_read_inputs"
  fun op stdin_read_inputs _ = ()
  val op stdin_read_inputs = TDB.find "stdin_read_inputs"
  fun op stdin_ffi_read_status_zero _ = ()
  val op stdin_ffi_read_status_zero = TDB.find "stdin_ffi_read_status_zero"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundStdinDomain"

end
