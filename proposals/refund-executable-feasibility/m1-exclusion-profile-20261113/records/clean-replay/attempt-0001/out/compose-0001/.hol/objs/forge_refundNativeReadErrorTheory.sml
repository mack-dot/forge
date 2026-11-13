structure forge_refundNativeReadErrorTheory :> forge_refundNativeReadErrorTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundNativeReadErrorTheory ... "
    else ()
  
  open Type Term Thm
  local open arm8_stepTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundNativeReadError",
        hash = "8b6218cf52f7f149961302a5af2a6602d7a8f7eb",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundNativeReadError" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op ffiread_error_return _ = ()
  val op ffiread_error_return = TDB.find "ffiread_error_return"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundNativeReadError"

end
