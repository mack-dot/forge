structure forge_compileCorrectControlTheory :> forge_compileCorrectControlTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_compileCorrectControlTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundExclusionArm8Theory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_compileCorrectControl",
        hash = "d016bd37447464d8cc2828b15c4692d1bf95cfec",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_compileCorrectControl" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op compile_correct' _ = ()
  val op compile_correct' = TDB.find "compile_correct'"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_compileCorrectControl"

end
