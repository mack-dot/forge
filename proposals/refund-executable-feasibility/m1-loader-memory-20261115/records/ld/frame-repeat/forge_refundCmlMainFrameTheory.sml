structure forge_refundCmlMainFrameTheory :> forge_refundCmlMainFrameTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundCmlMainFrameTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundCmlMainStepTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundCmlMainFrame",
        hash = "6ba6653f3520b8e0d0d3d12f4b9c92b647247e7c",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundCmlMainFrame" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op cml_main_run_frame _ = ()
  val op cml_main_run_frame = TDB.find "cml_main_run_frame"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundCmlMainFrame"

end
