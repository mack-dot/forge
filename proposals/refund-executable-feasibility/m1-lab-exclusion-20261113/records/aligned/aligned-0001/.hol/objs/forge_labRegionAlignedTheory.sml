structure forge_labRegionAlignedTheory :> forge_labRegionAlignedTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_labRegionAlignedTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_labRegionInvariantTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_labRegionAligned",
        hash = "3b01c1b5d473dcbce1af7994a6c65bfff292ea4f",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_labRegionAligned" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op write_bytearray_mval_inv _ = ()
  val op write_bytearray_mval_inv = TDB.find "write_bytearray_mval_inv"
  fun op region_inv2_def _ = ()
  val op region_inv2_def = TDB.find "region_inv2_def"
  fun op region2_step_sharemem _ = ()
  val op region2_step_sharemem = TDB.find "region2_step_sharemem"
  fun op region2_step_locvalue _ = ()
  val op region2_step_locvalue = TDB.find "region2_step_locvalue"
  fun op region2_step_label _ = ()
  val op region2_step_label = TDB.find "region2_step_label"
  fun op region2_step_jumpreg _ = ()
  val op region2_step_jumpreg = TDB.find "region2_step_jumpreg"
  fun op region2_step_jumpcmp _ = ()
  val op region2_step_jumpcmp = TDB.find "region2_step_jumpcmp"
  fun op region2_step_jump _ = ()
  val op region2_step_jump = TDB.find "region2_step_jump"
  fun op region2_step_install _ = ()
  val op region2_step_install = TDB.find "region2_step_install"
  fun op region2_step_inst _ = ()
  val op region2_step_inst = TDB.find "region2_step_inst"
  fun op region2_step_halt _ = ()
  val op region2_step_halt = TDB.find "region2_step_halt"
  fun op region2_step_callffi _ = ()
  val op region2_step_callffi = TDB.find "region2_step_callffi"
  fun op region2_step_call _ = ()
  val op region2_step_call = TDB.find "region2_step_call"
  fun op region2_run _ = () val op region2_run = TDB.find "region2_run"
  fun op region2_prefix _ = ()
  val op region2_prefix = TDB.find "region2_prefix"
  fun op region2_one_step _ = ()
  val op region2_one_step = TDB.find "region2_one_step"
  fun op region2_inv_next _ = ()
  val op region2_inv_next = TDB.find "region2_inv_next"
  fun op region2_inv_facts _ = ()
  val op region2_inv_facts = TDB.find "region2_inv_facts"
  fun op mval_inv_def _ = () val op mval_inv_def = TDB.find "mval_inv_def"
  fun op load_covered_def _ = ()
  val op load_covered_def = TDB.find "load_covered_def"
  fun op load_covered_byte_align_64 _ = ()
  val op load_covered_byte_align_64 = TDB.find "load_covered_byte_align_64"
  fun op asm_inst_mval_inv _ = ()
  val op asm_inst_mval_inv = TDB.find "asm_inst_mval_inv"
  fun op all_address_premise_not_implied _ = ()
  val op all_address_premise_not_implied = TDB.find
    "all_address_premise_not_implied"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_labRegionAligned"

end
