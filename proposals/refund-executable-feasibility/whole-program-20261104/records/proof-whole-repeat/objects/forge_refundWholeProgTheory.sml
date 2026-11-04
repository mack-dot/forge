structure forge_refundWholeProgTheory :> forge_refundWholeProgTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundWholeProgTheory ... "
    else ()
  
  open Type Term Thm
  local open ArrayProofTheory ListProofTheory basisProgTheory
  basis_ffiTheory forge_refundStdioProgTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundWholeProg",
        hash = "06977cded9cf029346ecb9db1111c31c12544215",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundWholeProg" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_whole_prog_spec _ = ()
  val op refund_whole_prog_spec = TDB.find "refund_whole_prog_spec"
  fun op refund_semantics _ = ()
  val op refund_semantics = TDB.find "refund_semantics"
  fun op refund_request_whole_prog_spec _ = ()
  val op refund_request_whole_prog_spec = TDB.find
    "refund_request_whole_prog_spec"
  fun op refund_prog_def _ = ()
  val op refund_prog_def = TDB.find "refund_prog_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundWholeProg"

end
