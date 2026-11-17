structure forge_refundRejectNonFailTheory :> forge_refundRejectNonFailTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundRejectNonFailTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundSourceNonFailTheory
  forge_refundStartupClauseTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundRejectNonFail",
        hash = "c640dbc320f1cd8990326c7abbcb41ff825b2db3",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRejectNonFail" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op star_split_lemma _ = ()
  val op star_split_lemma = TDB.find "star_split_lemma"
  fun op sem_sat_weaken _ = ()
  val op sem_sat_weaken = TDB.find "sem_sat_weaken"
  fun op refund_u298_exclusion_stdin _ = ()
  val op refund_u298_exclusion_stdin = TDB.find
    "refund_u298_exclusion_stdin"
  fun op refund_stdin_semantics _ = ()
  val op refund_stdin_semantics = TDB.find "refund_stdin_semantics"
  fun op refund_source_nonfail_stdin _ = ()
  val op refund_source_nonfail_stdin = TDB.find
    "refund_source_nonfail_stdin"
  fun op refund_source_nonfail_reject _ = ()
  val op refund_source_nonfail_reject = TDB.find
    "refund_source_nonfail_reject"
  fun op refund_reject_semantics _ = ()
  val op refund_reject_semantics = TDB.find "refund_reject_semantics"
  fun op refund_behavior_stdin_no_handler _ = ()
  val op refund_behavior_stdin_no_handler = TDB.find
    "refund_behavior_stdin_no_handler"
  fun op refund_accept_semantics _ = ()
  val op refund_accept_semantics = TDB.find "refund_accept_semantics"
  fun op exn_spec_IMP _ = () val op exn_spec_IMP = TDB.find "exn_spec_IMP"
  fun op call_main_exn2 _ = ()
  val op call_main_exn2 = TDB.find "call_main_exn2"
  fun op call_main_exn1 _ = ()
  val op call_main_exn1 = TDB.find "call_main_exn1"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRejectNonFail"

end
