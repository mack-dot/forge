signature forge_refundLabExclusionTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_lab_aligned_init_avoids_install : thm
    val refund_lab_good_init_avoids_install : thm
end
