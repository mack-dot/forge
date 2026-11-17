structure forge_refundAllocBackendTheory :> forge_refundAllocBackendTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundAllocBackendTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundArm8ProofTheory forge_refundLabClosureTheory
  forge_targetInstallPrefixTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundAllocBackend",
        hash = "5dae6d94acc5dba5c31e571e2d0d512cda7cf23f",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundAllocBackend" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_alloc_backend_correct _ = ()
  val op refund_alloc_backend_correct = TDB.find
    "refund_alloc_backend_correct"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundAllocBackend"

end
