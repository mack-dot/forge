structure forge_compileCorrectLabFactsTheory :> forge_compileCorrectLabFactsTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_compileCorrectLabFactsTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundExclusionArm8Theory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_compileCorrectLabFacts",
        hash = "c759986115b1a3fd35f10a2e273d04c55b3d1126",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_compileCorrectLabFacts" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op to_word_confs _ = ()
  val op to_word_confs = TDB.find "to_word_confs"
  fun op lab_nonfail_unaligned _ = ()
  val op lab_nonfail_unaligned = TDB.find "lab_nonfail_unaligned"
  fun op lab_keep_word_def _ = ()
  val op lab_keep_word_def = TDB.find "lab_keep_word_def"
  fun op lab_guard_true _ = ()
  val op lab_guard_true = TDB.find "lab_guard_true"
  fun op lab_guard_elim _ = ()
  val op lab_guard_elim = TDB.find "lab_guard_elim"
  fun op lab_guard_def _ = ()
  val op lab_guard_def = TDB.find "lab_guard_def"
  fun op lab_facts_def _ = ()
  val op lab_facts_def = TDB.find "lab_facts_def"
  fun op determ_not_fail _ = ()
  val op determ_not_fail = TDB.find "determ_not_fail"
  fun op compile_correct_lab_guard _ = ()
  val op compile_correct_lab_guard = TDB.find "compile_correct_lab_guard"
  fun op compile_correct_lab_facts _ = ()
  val op compile_correct_lab_facts = TDB.find "compile_correct_lab_facts"
  fun op compile_correct_from_guard _ = ()
  val op compile_correct_from_guard = TDB.find "compile_correct_from_guard"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_compileCorrectLabFacts"

end
