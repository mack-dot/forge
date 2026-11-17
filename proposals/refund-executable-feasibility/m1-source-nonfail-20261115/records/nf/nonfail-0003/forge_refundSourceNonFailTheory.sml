structure forge_refundSourceNonFailTheory :> forge_refundSourceNonFailTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundSourceNonFailTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_compileCorrectControlTheory
  forge_refundExclusionRealTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundSourceNonFail",
        hash = "52d05e456da73819795e02e1328659c9bf28e3ce",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundSourceNonFail" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op semantics_prog_Fail_expanded _ = ()
  val op semantics_prog_Fail_expanded = TDB.find
    "semantics_prog_Fail_expanded"
  fun op refund_u298_exclusion_valid_request _ = ()
  val op refund_u298_exclusion_valid_request = TDB.find
    "refund_u298_exclusion_valid_request"
  fun op refund_source_nonfail _ = ()
  val op refund_source_nonfail = TDB.find "refund_source_nonfail"
  fun op refund_behavior_valid_request_no_handler _ = ()
  val op refund_behavior_valid_request_no_handler = TDB.find
    "refund_behavior_valid_request_no_handler"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundSourceNonFail"

end
