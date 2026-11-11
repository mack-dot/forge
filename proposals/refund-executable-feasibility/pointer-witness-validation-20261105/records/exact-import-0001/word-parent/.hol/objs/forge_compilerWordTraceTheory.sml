structure forge_compilerWordTraceTheory :> forge_compilerWordTraceTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_compilerWordTraceTheory ... "
    else ()
  
  open Type Term Thm
  local open data_to_wordProofTheory forge_spaceInstallTraceTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_compilerWordTrace",
        hash = "915780452f45e90f98404ef2dd4094a1f7889877",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_compilerWordTrace" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op semantics_nonerror _ = ()
  val op semantics_nonerror = TDB.find "semantics_nonerror"
  fun op extended_nonfailure _ = ()
  val op extended_nonfailure = TDB.find "extended_nonfailure"
  fun op error_implies_failure _ = ()
  val op error_implies_failure = TDB.find "error_implies_failure"
  fun op compiled_word_single_epoch _ = ()
  val op compiled_word_single_epoch = TDB.find "compiled_word_single_epoch"
  fun op compiled_word_nonerror _ = ()
  val op compiled_word_nonerror = TDB.find "compiled_word_nonerror"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_compilerWordTrace"

end
