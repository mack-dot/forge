structure forge_refundSourceRelationTheory :> forge_refundSourceRelationTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundSourceRelationTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundSourceBindingTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundSourceRelation",
        hash = "34b25a33cd4e6509c909d77bc09eeda357696049",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundSourceRelation" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op source_model_result _ = ()
  val op source_model_result = TDB.find "source_model_result"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundSourceRelation"

end
