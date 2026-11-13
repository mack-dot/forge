structure forge_refundFfiOracleTheory :> forge_refundFfiOracleTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundFfiOracleTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundGenericReadErrorTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundFfiOracle",
        hash = "728a59e998809b3d4b7e70245ee8ff0bfb39224a",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundFfiOracle" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op basis_read_error_oracle _ = ()
  val op basis_read_error_oracle = TDB.find "basis_read_error_oracle"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundFfiOracle"

end
