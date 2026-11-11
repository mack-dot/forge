structure forge_refundConfigInstallTheory :> forge_refundConfigInstallTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundConfigInstallTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundClosureInstallTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundConfigInstall",
        hash = "956b6a868d038ab08eb29327d1137fe283430789",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundConfigInstall" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op to_clos_set_oracle _ = ()
  val op to_clos_set_oracle = TDB.find "to_clos_set_oracle"
  fun op refund_config_no_install _ = ()
  val op refund_config_no_install = TDB.find "refund_config_no_install"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundConfigInstall"

end
