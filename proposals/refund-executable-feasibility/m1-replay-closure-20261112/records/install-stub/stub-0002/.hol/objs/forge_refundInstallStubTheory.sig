signature forge_refundInstallStubTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val install_stub_has_install : thm
    val stubs_contain_install : thm
end
