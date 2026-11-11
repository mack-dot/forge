structure forge_refundRejectCompiledTheory :> forge_refundRejectCompiledTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundRejectCompiledTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundPreciseBehaviorTheory
  forge_refundRejectBasisTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundRejectCompiled",
        hash = "8129103b80285db4174a83cabe74debebedc2a2b",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRejectCompiled" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_error_compiled_precise _ = ()
  val op refund_error_compiled_precise = TDB.find
    "refund_error_compiled_precise"
  fun op exception_event_witness _ = ()
  val op exception_event_witness = TDB.find "exception_event_witness"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRejectCompiled"

end
