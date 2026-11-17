structure forge_refundFfiFactsTheory :> forge_refundFfiFactsTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundFfiFactsTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundInstalledAssemblyTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundFfiFacts",
        hash = "b3798efe627924d1d5eb9e39778c00b6d21c3ae7",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundFfiFacts" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_prog_cv_thm _ = ()
  val op refund_prog_cv_thm = TDB.find "refund_prog_cv_thm"
  fun op refund_prog_cv_eq _ = ()
  val op refund_prog_cv_eq = TDB.find "refund_prog_cv_eq"
  fun op refund_prog_cv_def _ = ()
  val op refund_prog_cv_def = TDB.find "refund_prog_cv_def"
  fun op refund_lab_conf2_ffis _ = ()
  val op refund_lab_conf2_ffis = TDB.find "refund_lab_conf2_ffis"
  fun op refund_ffi_names _ = ()
  val op refund_ffi_names = TDB.find "refund_ffi_names"
  fun op mmio_index_LENGTH_all_ExtCall _ = ()
  val op mmio_index_LENGTH_all_ExtCall = TDB.find
    "mmio_index_LENGTH_all_ExtCall"
  fun op ffinames_to_string_list_LENGTH _ = ()
  val op ffinames_to_string_list_LENGTH = TDB.find
    "ffinames_to_string_list_LENGTH"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundFfiFacts"

end
