structure forge_labRegionInvariantTheory :> forge_labRegionInvariantTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_labRegionInvariantTheory ... "
    else ()
  
  open Type Term Thm
  local open backend_x64_cvTheory labPropsTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_labRegionInvariant",
        hash = "3a51332184ddf088eda166ba5a3fc38985664b0c",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_labRegionInvariant" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op write_bytearray_val_inv _ = ()
  val op write_bytearray_val_inv = TDB.find "write_bytearray_val_inv"
  fun op val_inv_def _ = () val op val_inv_def = TDB.find "val_inv_def"
  fun op step_ok_def _ = () val op step_ok_def = TDB.find "step_ok_def"
  fun op region_inv_def _ = ()
  val op region_inv_def = TDB.find "region_inv_def"
  fun op region_hyp_def _ = ()
  val op region_hyp_def = TDB.find "region_hyp_def"
  fun op asm_inst_val_inv _ = ()
  val op asm_inst_val_inv = TDB.find "asm_inst_val_inv"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_labRegionInvariant"

end
