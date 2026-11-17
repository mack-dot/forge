structure forge_refundLabRunInitTheory :> forge_refundLabRunInitTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundLabRunInitTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundLabRunTheory lab_to_targetProofTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundLabRunInit",
        hash = "bfb3fd815183fc8f9387623e6b0c03dbc9c3b013",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundLabRunInit" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_lab_init_run_avoids_install _ = ()
  val op refund_lab_init_run_avoids_install = TDB.find
    "refund_lab_init_run_avoids_install"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundLabRunInit"

end
