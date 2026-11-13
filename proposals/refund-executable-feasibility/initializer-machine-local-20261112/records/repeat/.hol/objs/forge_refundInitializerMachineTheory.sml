structure forge_refundInitializerMachineTheory :> forge_refundInitializerMachineTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundInitializerMachineTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundInitialStackCodeTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundInitializerMachine",
        hash = "bfe3dc9d6995c841ed6f7eb470b9c804aca69182",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundInitializerMachine"
      {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_initialization_machine _ = ()
  val op refund_initialization_machine = TDB.find
    "refund_initialization_machine"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundInitializerMachine"

end
