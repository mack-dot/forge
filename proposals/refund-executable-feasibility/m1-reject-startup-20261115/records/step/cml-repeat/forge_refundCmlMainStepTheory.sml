structure forge_refundCmlMainStepTheory :> forge_refundCmlMainStepTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundCmlMainStepTheory ... "
    else ()
  
  open Type Term Thm
  local open arm8_stepTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundCmlMainStep",
        hash = "85519aca13af857cffb82044c2b464d2ec86fc14",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundCmlMainStep" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op cml_main_wrong_target_refuted _ = ()
  val op cml_main_wrong_target_refuted = TDB.find
    "cml_main_wrong_target_refuted"
  fun op cml_main_startup_conditions _ = ()
  val op cml_main_startup_conditions = TDB.find
    "cml_main_startup_conditions"
  fun op cml_main_run _ = () val op cml_main_run = TDB.find "cml_main_run"
  fun op cml_main_pre_def _ = ()
  val op cml_main_pre_def = TDB.find "cml_main_pre_def"
  fun op cml_main_post_def _ = ()
  val op cml_main_post_def = TDB.find "cml_main_post_def"
  fun op arm8_run_def _ = () val op arm8_run_def = TDB.find "arm8_run_def"
  fun op arm8_run_compute _ = ()
  val op arm8_run_compute = TDB.find "arm8_run_compute"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundCmlMainStep"

end
