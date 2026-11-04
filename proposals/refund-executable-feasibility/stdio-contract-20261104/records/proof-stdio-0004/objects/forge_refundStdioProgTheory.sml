structure forge_refundStdioProgTheory :> forge_refundStdioProgTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundStdioProgTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundWireProgTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundStdioProg",
        hash = "45237790d1aba35f288f37274cf1728758a64c77",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundStdioProg" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_main_valid _ = ()
  val op refund_main_valid = TDB.find "refund_main_valid"
  fun op refund_main_v_def _ = ()
  val op refund_main_v_def = TDB.find "refund_main_v_def"
  fun op refund_main_error _ = ()
  val op refund_main_error = TDB.find "refund_main_error"
  fun op nsLookup_forge_refundStdioProg_env_pfun_eqs _ = ()
  val op nsLookup_forge_refundStdioProg_env_pfun_eqs = TDB.find
    "nsLookup_forge_refundStdioProg_env_pfun_eqs"
  fun op forge_refundStdioProg_env_def _ = ()
  val op forge_refundStdioProg_env_def = TDB.find
    "forge_refundStdioProg_env_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundStdioProg"

end
