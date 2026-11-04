structure forge_refund_compileTheory :> forge_refund_compileTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refund_compileTheory ... "
    else ()
  
  open Type Term Thm
  local open dafny_to_cakemlProofTheory forge_refundTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refund_compile",
        hash = "1bb27d4b05172fd01cb8addb63295036d7f186cf",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refund_compile" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_static _ = ()
  val op refund_static = TDB.find "refund_static"
  fun op refund_statement_evaluation _ = ()
  val op refund_statement_evaluation = TDB.find
    "refund_statement_evaluation"
  fun op refund_model_return _ = ()
  val op refund_model_return = TDB.find "refund_model_return"
  fun op refund_compiler_relation _ = ()
  val op refund_compiler_relation = TDB.find "refund_compiler_relation"
  fun op refund_compilation _ = ()
  val op refund_compilation = TDB.find "refund_compilation"
  fun op refund_cml_def _ = ()
  val op refund_cml_def = TDB.find "refund_cml_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refund_compile"

end
