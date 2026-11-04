structure forge_refund_callTheory :> forge_refund_callTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refund_callTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refund_compileTheory primSemEnvTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refund_call",
        hash = "6ad7f111135ee7f747eb581cac911a56a69b13b7",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refund_call" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_program_def _ = ()
  val op refund_program_def = TDB.find "refund_program_def"
  fun op refund_method_def _ = ()
  val op refund_method_def = TDB.find "refund_method_def"
  fun op refund_method_compilation _ = ()
  val op refund_method_compilation = TDB.find "refund_method_compilation"
  fun op refund_method_cml_def _ = ()
  val op refund_method_cml_def = TDB.find "refund_method_cml_def"
  fun op refund_expected_tuple_def _ = ()
  val op refund_expected_tuple_def = TDB.find "refund_expected_tuple_def"
  fun op refund_caller_returns _ = ()
  val op refund_caller_returns = TDB.find "refund_caller_returns"
  fun op refund_call_def _ = ()
  val op refund_call_def = TDB.find "refund_call_def"
  fun op refund_argument_env_def _ = ()
  val op refund_argument_env_def = TDB.find "refund_argument_env_def"
  fun op concrete_bool_tests _ = ()
  val op concrete_bool_tests = TDB.find "concrete_bool_tests"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refund_call"

end
