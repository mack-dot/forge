signature forge_refundInstallHandlerTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val arm8_install_handler_exists : thm
    val arm8_install_handler_ok : thm
    val install_exclusion_suffices : thm
    val installed_modulo_install_handler : thm
end
