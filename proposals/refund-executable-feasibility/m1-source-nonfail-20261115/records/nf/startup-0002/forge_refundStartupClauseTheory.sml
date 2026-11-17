structure forge_refundStartupClauseTheory :> forge_refundStartupClauseTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundStartupClauseTheory ... "
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
        thyname = "forge_refundStartupClause",
        hash = "d14f1315db7d641d3a2fc016a9c2ae2bc2874bf4",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundStartupClause" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_startup_clause_def _ = ()
  val op refund_startup_clause_def = TDB.find "refund_startup_clause_def"
  fun op refund_startup_clause_arm8 _ = ()
  val op refund_startup_clause_arm8 = TDB.find "refund_startup_clause_arm8"
  fun op refund_installed_startup _ = ()
  val op refund_installed_startup = TDB.find "refund_installed_startup"
  fun op is_arm8_iff_fix _ = ()
  val op is_arm8_iff_fix = TDB.find "is_arm8_iff_fix"
  fun op arm8_startup_fields _ = ()
  val op arm8_startup_fields = TDB.find "arm8_startup_fields"
  fun op arm8_fix_is_arm8 _ = ()
  val op arm8_fix_is_arm8 = TDB.find "arm8_fix_is_arm8"
  fun op arm8_fix_def _ = () val op arm8_fix_def = TDB.find "arm8_fix_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundStartupClause"

end
