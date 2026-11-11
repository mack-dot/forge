structure forge_refundWordInitializationTheory :> forge_refundWordInitializationTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundWordInitializationTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundArm8ProofTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundWordInitialization",
        hash = "fbe8f56dc3d65c733f6daaf03bf8a0e5fe19118b",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundWordInitialization"
      {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op to_word_code_rel _ = ()
  val op to_word_code_rel = TDB.find "to_word_code_rel"
  fun op refund_word_code_rel _ = ()
  val op refund_word_code_rel = TDB.find "refund_word_code_rel"
  fun op refund_data_labels _ = ()
  val op refund_data_labels = TDB.find "refund_data_labels"
  fun op make_init_static _ = ()
  val op make_init_static = TDB.find "make_init_static"
  fun op compiled_word_code_rel _ = ()
  val op compiled_word_code_rel = TDB.find "compiled_word_code_rel"
  fun op compiled_raw_code_rel _ = ()
  val op compiled_raw_code_rel = TDB.find "compiled_raw_code_rel"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundWordInitialization"

end
