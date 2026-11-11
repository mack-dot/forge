signature forge_refundConfigInstallTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_config_no_install : thm
    val to_clos_set_oracle : thm
end
