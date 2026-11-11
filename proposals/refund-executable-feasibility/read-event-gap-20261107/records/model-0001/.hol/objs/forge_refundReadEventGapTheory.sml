structure forge_refundReadEventGapTheory :> forge_refundReadEventGapTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundReadEventGapTheory ... "
    else ()
  
  open Type Term Thm
  local open basis_ffiTheory forge_refundStdinDomainTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundReadEventGap",
        hash = "321c31fee9dbbf3aabb58a77366ef909408378bd",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundReadEventGap" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op stdin_error_event_rejected _ = ()
  val op stdin_error_event_rejected = TDB.find "stdin_error_event_rejected"
  fun op stdin_error_complete_trace_rejected _ = ()
  val op stdin_error_complete_trace_rejected = TDB.find
    "stdin_error_complete_trace_rejected"
  fun op basis_stdin_read_total _ = ()
  val op basis_stdin_read_total = TDB.find "basis_stdin_read_total"
  fun op basis_read_ignores_ext _ = ()
  val op basis_read_ignores_ext = TDB.find "basis_read_ignores_ext"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundReadEventGap"

end
