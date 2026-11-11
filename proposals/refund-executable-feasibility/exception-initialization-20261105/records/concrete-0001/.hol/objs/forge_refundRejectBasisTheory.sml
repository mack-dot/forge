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
        hash = "e95135c320e20c123e1f91afcfbf602264ed44cb",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundRejectBasis" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_stdio_extract_fs _ = ()
  val op refund_stdio_extract_fs = TDB.find "refund_stdio_extract_fs"
  fun op refund_split_from_subset _ = ()
  val op refund_split_from_subset = TDB.find "refund_split_from_subset"
  fun op refund_sem_satisfies_imp _ = ()
  val op refund_sem_satisfies_imp = TDB.find "refund_sem_satisfies_imp"
  fun op refund_initial_stdio _ = ()
  val op refund_initial_stdio = TDB.find "refund_initial_stdio"
  fun op refund_error_program_identity _ = ()
  val op refund_error_program_identity = TDB.find
    "refund_error_program_identity"
  fun op refund_error_initialized_semantics _ = ()
  val op refund_error_initialized_semantics = TDB.find
    "refund_error_initialized_semantics"
  fun op refund_error_basis_semantics _ = ()
  val op refund_error_basis_semantics = TDB.find
    "refund_error_basis_semantics"
  fun op refund_basis_parts_ok _ = ()
  val op refund_basis_parts_ok = TDB.find "refund_basis_parts_ok"
  fun op refund_basis_fs_projection _ = ()
  val op refund_basis_fs_projection = TDB.find "refund_basis_fs_projection"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundRejectBasis"

end
