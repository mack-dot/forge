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
        hash = "2ffe2785b8a7cf330d04e32cc0aae5ee6918388c",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRejectBasis" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_stdio_extract_fs _ = ()
  val op refund_stdio_extract_fs = TDB.find "refund_stdio_extract_fs"
  fun op refund_sem_satisfies_imp _ = ()
  val op refund_sem_satisfies_imp = TDB.find "refund_sem_satisfies_imp"
  fun op refund_error_basis_semantics _ = ()
  val op refund_error_basis_semantics = TDB.find
    "refund_error_basis_semantics"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRejectBasis"

end
