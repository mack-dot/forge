structure forge_refundResourceBindingTheory :> forge_refundResourceBindingTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundResourceBindingTheory ... "
    else ()
  
  open Type Term Thm
  local open arm8_configTheory backendProofTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundResourceBinding",
        hash = "2c2af042746cdd643a141767f4669f27d4d7cfb4",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundResourceBinding" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op recorded_read_limits _ = ()
  val op recorded_read_limits = TDB.find "recorded_read_limits"
  fun op recorded_limits _ = ()
  val op recorded_limits = TDB.find "recorded_limits"
  fun op recorded_config _ = ()
  val op recorded_config = TDB.find "recorded_config"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundResourceBinding"

end
