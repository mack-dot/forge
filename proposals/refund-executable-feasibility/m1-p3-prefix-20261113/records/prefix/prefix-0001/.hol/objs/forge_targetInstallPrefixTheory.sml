structure forge_targetInstallPrefixTheory :> forge_targetInstallPrefixTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_targetInstallPrefixTheory ... "
    else ()
  
  open Type Term Thm
  local open backend_x64_cvTheory targetPropsTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_targetInstallPrefix",
        hash = "ab2d16446695e59e88dfb3a8401c1980e7f910f3",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_targetInstallPrefix" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op no_install_prefix_zero _ = ()
  val op no_install_prefix_zero = TDB.find "no_install_prefix_zero"
  fun op no_install_prefix_segment _ = ()
  val op no_install_prefix_segment = TDB.find "no_install_prefix_segment"
  fun op no_install_prefix_next _ = ()
  val op no_install_prefix_next = TDB.find "no_install_prefix_next"
  fun op no_install_prefix_mono _ = ()
  val op no_install_prefix_mono = TDB.find "no_install_prefix_mono"
  fun op no_install_prefix_halt _ = ()
  val op no_install_prefix_halt = TDB.find "no_install_prefix_halt"
  fun op no_install_prefix_def _ = ()
  val op no_install_prefix_def = TDB.find "no_install_prefix_def"
  fun op no_install_prefix_all _ = ()
  val op no_install_prefix_all = TDB.find "no_install_prefix_all"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_targetInstallPrefix"

end
