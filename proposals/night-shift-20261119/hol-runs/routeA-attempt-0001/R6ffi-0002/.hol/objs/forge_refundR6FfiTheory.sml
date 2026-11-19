structure forge_refundR6FfiTheory :> forge_refundR6FfiTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundR6FfiTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundR6BaseTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundR6Ffi",
        hash = "6d96877e82be1e418202ba46b4dbb5b13bec1b6e",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundR6Ffi" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op writei_spec_V _ = ()
  val op writei_spec_V = TDB.find "writei_spec_V"
  fun op read_into_spec_V _ = ()
  val op read_into_spec_V = TDB.find "read_into_spec_V"
  fun op STDIO_V_def _ = () val op STDIO_V_def = TDB.find "STDIO_V_def"
  fun op IOxV_def _ = () val op IOxV_def = TDB.find "IOxV_def"
  fun op IOxV_IMP_IOx _ = () val op IOxV_IMP_IOx = TDB.find "IOxV_IMP_IOx"
  fun op IOFS_V_def _ = () val op IOFS_V_def = TDB.find "IOFS_V_def"
  fun op IOFS_V_FFI_part_hprop _ = ()
  val op IOFS_V_FFI_part_hprop = TDB.find "IOFS_V_FFI_part_hprop"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundR6Ffi"

end
