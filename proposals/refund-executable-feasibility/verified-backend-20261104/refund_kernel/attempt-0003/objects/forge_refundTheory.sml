structure forge_refundTheory :> forge_refundTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundTheory ... "
    else ()
  
  open Type Term Thm
  local open dafny_evaluateTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refund",
        hash = "aafcbc1de12297cf04b8a1ef8e1fdea20d19b936",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refund" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_initial_def _ = ()
  val op refund_initial_def = TDB.find "refund_initial_def"
  fun op refund_guard_value _ = ()
  val op refund_guard_value = TDB.find "refund_guard_value"
  fun op refund_guard_def _ = ()
  val op refund_guard_def = TDB.find "refund_guard_def"
  fun op refund_full_result _ = ()
  val op refund_full_result = TDB.find "refund_full_result"
  fun op refund_body_def _ = ()
  val op refund_body_def = TDB.find "refund_body_def"
  fun op eligible_def _ = () val op eligible_def = TDB.find "eligible_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refund"

end
