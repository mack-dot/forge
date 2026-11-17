structure forge_refundLabRunTheory :> forge_refundLabRunTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundLabRunTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_labRegionWalkTheory forge_refundLabResolveTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundLabRun",
        hash = "7049a61f0e21cb5277aabffc35600f95995d41fa",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundLabRun" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op walk_check_def _ = ()
  val op walk_check_def = TDB.find "walk_check_def"
  fun op refund_prog_cv_thm _ = ()
  val op refund_prog_cv_thm = TDB.find "refund_prog_cv_thm"
  fun op refund_prog_cv_eq _ = ()
  val op refund_prog_cv_eq = TDB.find "refund_prog_cv_eq"
  fun op refund_prog_cv_def _ = ()
  val op refund_prog_cv_def = TDB.find "refund_prog_cv_def"
  fun op refund_lab_walk_not_closed_29 _ = ()
  val op refund_lab_walk_not_closed_29 = TDB.find
    "refund_lab_walk_not_closed_29"
  fun op refund_lab_run_avoids_install _ = ()
  val op refund_lab_run_avoids_install = TDB.find
    "refund_lab_run_avoids_install"
  fun op refund_lab_region_hyp _ = ()
  val op refund_lab_region_hyp = TDB.find "refund_lab_region_hyp"
  fun op line_ok1_eq _ = () val op line_ok1_eq = TDB.find "line_ok1_eq"
  fun op line_ok1_def _ = () val op line_ok1_def = TDB.find "line_ok1_def"
  fun op hyp_walk1_ind _ = ()
  val op hyp_walk1_ind = TDB.find "hyp_walk1_ind"
  fun op hyp_walk1_eq _ = () val op hyp_walk1_eq = TDB.find "hyp_walk1_eq"
  fun op hyp_walk1_def _ = ()
  val op hyp_walk1_def = TDB.find "hyp_walk1_def"
  fun op cv_walk_check_thm _ = ()
  val op cv_walk_check_thm = TDB.find "cv_walk_check_thm"
  fun op cv_walk_check_def _ = ()
  val op cv_walk_check_def = TDB.find "cv_walk_check_def"
  fun op cv_line_ok1_thm _ = ()
  val op cv_line_ok1_thm = TDB.find "cv_line_ok1_thm"
  fun op cv_line_ok1_def _ = ()
  val op cv_line_ok1_def = TDB.find "cv_line_ok1_def"
  fun op cv_hyp_walk1_thm _ = ()
  val op cv_hyp_walk1_thm = TDB.find "cv_hyp_walk1_thm"
  fun op cv_hyp_walk1_def _ = ()
  val op cv_hyp_walk1_def = TDB.find "cv_hyp_walk1_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundLabRun"

end
