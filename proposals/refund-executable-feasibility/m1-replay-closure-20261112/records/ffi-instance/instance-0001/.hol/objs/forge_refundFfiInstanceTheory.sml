structure forge_refundFfiInstanceTheory :> forge_refundFfiInstanceTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundFfiInstanceTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundFfiOracleTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundFfiInstance",
        hash = "0d8aca9bf367069d0894caa092ebfa30d0e595ad",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundFfiInstance" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op read_error_basis_instance _ = ()
  val op read_error_basis_instance = TDB.find "read_error_basis_instance"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundFfiInstance"

end
