structure forge_refundInstallStubTheory :> forge_refundInstallStubTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundInstallStubTheory ... "
    else ()
  
  open Type Term Thm
  local open basis_ffiTheory data_to_wordTheory
  forge_refundStdinDomainTheory wordPropsTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundInstallStub",
        hash = "e79c2878000818e378a0de7abc2790160578ad18",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundInstallStub" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op stubs_contain_install _ = ()
  val op stubs_contain_install = TDB.find "stubs_contain_install"
  fun op install_stub_has_install _ = ()
  val op install_stub_has_install = TDB.find "install_stub_has_install"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundInstallStub"

end
