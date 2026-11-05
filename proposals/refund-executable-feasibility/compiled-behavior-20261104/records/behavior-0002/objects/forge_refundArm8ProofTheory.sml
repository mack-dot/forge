structure forge_refundArm8ProofTheory :> forge_refundArm8ProofTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundArm8ProofTheory ... "
    else ()
  
  open Type Term Thm
  local open arm8_configProofTheory forge_refundArm8CompileTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundArm8Proof",
        hash = "9bdbc3b3b8a698a89fac83a5b2b4ba3eb396f30c",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundArm8Proof" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_compiled_behavior _ = ()
  val op refund_compiled_behavior = TDB.find "refund_compiled_behavior"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundArm8Proof"

end
