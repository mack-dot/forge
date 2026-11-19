structure forge_m1bErasureV2Theory :> forge_m1bErasureV2Theory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_m1bErasureV2Theory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundSlideProfileATheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_m1bErasureV2",
        hash = "e2b1425f86f7fdbe030ae98da5fbe149b6b04877",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_m1bErasureV2" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op untagged_def _ = () val op untagged_def = TDB.find "untagged_def"
  fun op untagged_bits _ = ()
  val op untagged_bits = TDB.find "untagged_bits"
  fun op tbi_pc_untagged _ = ()
  val op tbi_pc_untagged = TDB.find "tbi_pc_untagged"
  fun op tbi_pc_erased _ = ()
  val op tbi_pc_erased = TDB.find "tbi_pc_erased"
  fun op tbi_pc_def _ = () val op tbi_pc_def = TDB.find "tbi_pc_def"
  fun op restore_erase _ = ()
  val op restore_erase = TDB.find "restore_erase"
  fun op restore_def _ = () val op restore_def = TDB.find "restore_def"
  fun op erase_restore _ = ()
  val op erase_restore = TDB.find "erase_restore"
  fun op erase_fields _ = () val op erase_fields = TDB.find "erase_fields"
  fun op erase_e0e_def _ = ()
  val op erase_e0e_def = TDB.find "erase_e0e_def"
  fun op erase_def _ = () val op erase_def = TDB.find "erase_def"
  fun op bits_of_def _ = () val op bits_of_def = TDB.find "bits_of_def"
  fun op arm8_ok_erase _ = ()
  val op arm8_ok_erase = TDB.find "arm8_ok_erase"
  fun op P1_bit55_without_TBI1_is_fine _ = ()
  val op P1_bit55_without_TBI1_is_fine = TDB.find
    "P1_bit55_without_TBI1_is_fine"
  fun op N5_lo55_holds_at_slide_zero_and_fails_at_N4_slide _ = ()
  val op N5_lo55_holds_at_slide_zero_and_fails_at_N4_slide = TDB.find
    "N5_lo55_holds_at_slide_zero_and_fails_at_N4_slide"
  fun op N4_slide_ok_admits_tagged_code _ = ()
  val op N4_slide_ok_admits_tagged_code = TDB.find
    "N4_slide_ok_admits_tagged_code"
  fun op N3_e0e_not_erasable _ = ()
  val op N3_e0e_not_erasable = TDB.find "N3_e0e_not_erasable"
  fun op N2_misaligned_sp_breaks _ = ()
  val op N2_misaligned_sp_breaks = TDB.find "N2_misaligned_sp_breaks"
  fun op N1b_bit55_branch_breaks _ = ()
  val op N1b_bit55_branch_breaks = TDB.find "N1b_bit55_branch_breaks"
  fun op N1a_tagged_branch_breaks _ = ()
  val op N1a_tagged_branch_breaks = TDB.find "N1a_tagged_branch_breaks"
  fun op CheckSPAlignment_erase_fault _ = ()
  val op CheckSPAlignment_erase_fault = TDB.find
    "CheckSPAlignment_erase_fault"
  fun op CheckSPAlignment_erase _ = ()
  val op CheckSPAlignment_erase = TDB.find "CheckSPAlignment_erase"
  fun op BranchTo_erase_untagged _ = ()
  val op BranchTo_erase_untagged = TDB.find "BranchTo_erase_untagged"
  fun op BranchTo_EL0_pc _ = ()
  val op BranchTo_EL0_pc = TDB.find "BranchTo_EL0_pc"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_m1bErasureV2"

end
