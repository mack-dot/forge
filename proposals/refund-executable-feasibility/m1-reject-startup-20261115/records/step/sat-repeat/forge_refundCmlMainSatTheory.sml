structure forge_refundCmlMainSatTheory :> forge_refundCmlMainSatTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundCmlMainSatTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundCmlMainStepTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundCmlMainSat",
        hash = "301d4dbe170fe546900e8e106b7b79cb0ad53a62",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundCmlMainSat" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op cml_main_pre_satisfiable _ = ()
  val op cml_main_pre_satisfiable = TDB.find "cml_main_pre_satisfiable"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundCmlMainSat"

end
