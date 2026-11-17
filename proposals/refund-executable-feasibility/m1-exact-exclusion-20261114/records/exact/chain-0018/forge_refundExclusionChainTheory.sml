structure forge_refundExclusionChainTheory :> forge_refundExclusionChainTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundExclusionChainTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundExactExclusionTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundExclusionChain",
        hash = "5247257f56c8cb059aa11aff8f540d7af97ff1f7",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundExclusionChain" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_compile_install_exclusion _ = ()
  val op refund_compile_install_exclusion = TDB.find
    "refund_compile_install_exclusion"
  fun op nip_make_init _ = ()
  val op nip_make_init = TDB.find "nip_make_init"
  fun op nip_goal_def _ = () val op nip_goal_def = TDB.find "nip_goal_def"
  fun op exclusion_mid _ = ()
  val op exclusion_mid = TDB.find "exclusion_mid"
  fun op compile_install_exclusion _ = ()
  val op compile_install_exclusion = TDB.find "compile_install_exclusion"
  fun op IMP_state_rel_make_init _ = ()
  val op IMP_state_rel_make_init = TDB.find "IMP_state_rel_make_init"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundExclusionChain"

end
