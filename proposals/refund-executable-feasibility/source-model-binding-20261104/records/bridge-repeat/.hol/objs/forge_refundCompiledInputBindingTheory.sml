structure forge_refundCompiledInputBindingTheory :> forge_refundCompiledInputBindingTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundCompiledInputBindingTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundCertifiedProgTheory
  forge_refundSourceBindingTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundCompiledInputBinding",
        hash = "d026079a9322ccc0618057e9fc865d13e719c342",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundCompiledInputBinding"
      {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op source_compiled_fields _ = ()
  val op source_compiled_fields = TDB.find "source_compiled_fields"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundCompiledInputBinding"

end
