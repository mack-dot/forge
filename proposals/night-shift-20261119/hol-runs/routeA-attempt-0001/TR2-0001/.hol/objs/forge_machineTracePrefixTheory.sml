structure forge_machineTracePrefixTheory :> forge_machineTracePrefixTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_machineTracePrefixTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_machineTraceTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_machineTracePrefix",
        hash = "2b5a3b12cbae0a9a589592ac49f5e992dee2e336",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_machineTracePrefix" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op trace_terminate _ = ()
  val op trace_terminate = TDB.find "trace_terminate"
  fun op trace_fail _ = () val op trace_fail = TDB.find "trace_fail"
  fun op trace_diverge _ = ()
  val op trace_diverge = TDB.find "trace_diverge"
  fun op toy_bad_not_followed _ = ()
  val op toy_bad_not_followed = TDB.find "toy_bad_not_followed"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_machineTracePrefix"

end
