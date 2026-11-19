structure forge_refundEligibleLinkTheory :> forge_refundEligibleLinkTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundEligibleLinkTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundTheory sexp_to_dafnyTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundEligibleLink",
        hash = "cfc271a5f1ee439a28d1b63f3abf0ca88f164db0",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundEligibleLink" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op eligible_link_text_def _ = ()
  val op eligible_link_text_def = TDB.find "eligible_link_text_def"
  fun op eligible_link_shape _ = ()
  val op eligible_link_shape = TDB.find "eligible_link_shape"
  fun op eligible_link_program_def _ = ()
  val op eligible_link_program_def = TDB.find "eligible_link_program_def"
  fun op eligible_link_operators _ = ()
  val op eligible_link_operators = TDB.find "eligible_link_operators"
  fun op eligible_link_matches_compiled_guard _ = ()
  val op eligible_link_matches_compiled_guard = TDB.find
    "eligible_link_matches_compiled_guard"
  fun op eligible_link_initial_def _ = ()
  val op eligible_link_initial_def = TDB.find "eligible_link_initial_def"
  fun op eligible_link_guard_value _ = ()
  val op eligible_link_guard_value = TDB.find "eligible_link_guard_value"
  fun op eligible_link_guard_def _ = ()
  val op eligible_link_guard_def = TDB.find "eligible_link_guard_def"
  fun op eligible_link_decode _ = ()
  val op eligible_link_decode = TDB.find "eligible_link_decode"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundEligibleLink"

end
