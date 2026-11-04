structure forge_refundArm8CompileTheory :> forge_refundArm8CompileTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundArm8CompileTheory ... "
    else ()
  
  open Type Term Thm
  local open backend_arm8_cvTheory backend_x64_cvTheory
  forge_refundWholeProgTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundArm8Compile",
        hash = "c89854dae52a5b629b8fb1139b664eedf62c9c0b",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundArm8Compile" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op temp_oracle_cv_thm _ = ()
  val op temp_oracle_cv_thm = TDB.find "temp_oracle_cv_thm"
  fun op refund_prog_cv_thm _ = ()
  val op refund_prog_cv_thm = TDB.find "refund_prog_cv_thm"
  fun op refund_prog_cv_eq _ = ()
  val op refund_prog_cv_eq = TDB.find "refund_prog_cv_eq"
  fun op refund_prog_cv_def _ = ()
  val op refund_prog_cv_def = TDB.find "refund_prog_cv_def"
  fun op refund_arm8_compiled _ = ()
  val op refund_arm8_compiled = TDB.find "refund_arm8_compiled"
  fun op ffis_def _ = () val op ffis_def = TDB.find "ffis_def"
  fun op data_def _ = () val op data_def = TDB.find "data_def"
  fun op conf_def _ = () val op conf_def = TDB.find "conf_def"
  fun op compiled _ = () val op compiled = TDB.find "compiled"
  fun op code_def _ = () val op code_def = TDB.find "code_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundArm8Compile"

end
