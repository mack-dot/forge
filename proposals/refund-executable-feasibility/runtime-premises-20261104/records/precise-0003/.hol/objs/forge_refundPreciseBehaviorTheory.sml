structure forge_refundPreciseBehaviorTheory :> forge_refundPreciseBehaviorTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundPreciseBehaviorTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundArm8ProofTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundPreciseBehavior",
        hash = "e18e21ba6d999ebd06f633767b6a2f7482f0b85a",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundPreciseBehavior" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_compiled_precise _ = ()
  val op refund_compiled_precise = TDB.find "refund_compiled_precise"
  fun op precise_sem_satisfies_IMP_Terminate _ = ()
  val op precise_sem_satisfies_IMP_Terminate = TDB.find
    "precise_sem_satisfies_IMP_Terminate"
  fun op empty_resource_prefix_allowed _ = ()
  val op empty_resource_prefix_allowed = TDB.find
    "empty_resource_prefix_allowed"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundPreciseBehavior"

end
