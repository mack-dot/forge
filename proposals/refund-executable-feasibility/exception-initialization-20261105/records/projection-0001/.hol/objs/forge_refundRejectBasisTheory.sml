structure forge_refundRejectBasisTheory :> forge_refundRejectBasisTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundRejectBasisTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundRejectSemanticsTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundRejectBasis",
        hash = "c51e986adaa4879a5fd8364fe09601fe403c1011",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRejectBasis" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_basis_fs_projection _ = ()
  val op refund_basis_fs_projection = TDB.find "refund_basis_fs_projection"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRejectBasis"

end
