structure forge_refundStartupBridgeTheory :> forge_refundStartupBridgeTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundStartupBridgeTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundCmlMainStepTheory forge_refundRejectNonFailTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundStartupBridge",
        hash = "521d5c9a536f047b066118ee0023dab5eb15baea",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundStartupBridge" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op stdin_absent_characterised _ = ()
  val op stdin_absent_characterised = TDB.find "stdin_absent_characterised"
  fun op refund_startup_from_cml_main _ = ()
  val op refund_startup_from_cml_main = TDB.find
    "refund_startup_from_cml_main"
  fun op refund_startup_established _ = ()
  val op refund_startup_established = TDB.find "refund_startup_established"
  fun op refund_mc_u298_exclusion_stdin _ = ()
  val op refund_mc_u298_exclusion_stdin = TDB.find
    "refund_mc_u298_exclusion_stdin"
  fun op refund_mc_is_arm8 _ = ()
  val op refund_mc_is_arm8 = TDB.find "refund_mc_is_arm8"
  fun op refund_mc_fields _ = ()
  val op refund_mc_fields = TDB.find "refund_mc_fields"
  fun op refund_mc_def _ = ()
  val op refund_mc_def = TDB.find "refund_mc_def"
  fun op refund_mc_behavior_stdin_no_handler _ = ()
  val op refund_mc_behavior_stdin_no_handler = TDB.find
    "refund_mc_behavior_stdin_no_handler"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundStartupBridge"

end
