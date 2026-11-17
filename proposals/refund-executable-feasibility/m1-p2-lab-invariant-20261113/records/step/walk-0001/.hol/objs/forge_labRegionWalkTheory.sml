structure forge_labRegionWalkTheory :> forge_labRegionWalkTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_labRegionWalkTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_labRegionStepTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_labRegionWalk",
        hash = "73ead041d1c26cf8ce256bd7c5483a7685e9b3c8",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_labRegionWalk" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op loc_good_def _ = () val op loc_good_def = TDB.find "loc_good_def"
  fun op line_ok_step_ok _ = ()
  val op line_ok_step_ok = TDB.find "line_ok_step_ok"
  fun op line_ok_def _ = () val op line_ok_def = TDB.find "line_ok_def"
  fun op hyp_walk_region_hyp _ = ()
  val op hyp_walk_region_hyp = TDB.find "hyp_walk_region_hyp"
  fun op hyp_walk_ind _ = () val op hyp_walk_ind = TDB.find "hyp_walk_ind"
  fun op hyp_walk_fetch _ = ()
  val op hyp_walk_fetch = TDB.find "hyp_walk_fetch"
  fun op hyp_walk_def _ = () val op hyp_walk_def = TDB.find "hyp_walk_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_labRegionWalk"

end
