signature forge_m1bErasureV2Theory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val bits_of_def : thm
    val erase_def : thm
    val erase_e0e_def : thm
    val restore_def : thm
    val tbi_pc_def : thm
    val untagged_def : thm
  
  (*  Theorems  *)
    val BranchTo_EL0_pc : thm
    val BranchTo_erase_untagged : thm
    val CheckSPAlignment_erase : thm
    val CheckSPAlignment_erase_fault : thm
    val N1a_tagged_branch_breaks : thm
    val N1b_bit55_branch_breaks : thm
    val N2_misaligned_sp_breaks : thm
    val N3_e0e_not_erasable : thm
    val N4_slide_ok_admits_tagged_code : thm
    val N5_lo55_holds_at_slide_zero_and_fails_at_N4_slide : thm
    val P1_bit55_without_TBI1_is_fine : thm
    val arm8_ok_erase : thm
    val erase_fields : thm
    val erase_restore : thm
    val restore_erase : thm
    val tbi_pc_erased : thm
    val tbi_pc_untagged : thm
    val untagged_bits : thm
end
