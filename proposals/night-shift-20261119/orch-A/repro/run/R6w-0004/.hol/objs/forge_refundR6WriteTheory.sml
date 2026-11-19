structure forge_refundR6WriteTheory :> forge_refundR6WriteTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundR6WriteTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundR6FfiTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundR6Write",
        hash = "52750b83426e1db5efc12a51ecd6f3aaf2f18d56",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundR6Write" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op writei_spec_W _ = ()
  val op writei_spec_W = TDB.find "writei_spec_W"
  fun op write_spec_V _ = () val op write_spec_V = TDB.find "write_spec_V"
  fun op write_event_ok_writei _ = ()
  val op write_event_ok_writei = TDB.find "write_event_ok_writei"
  fun op write_event_ok_refund _ = ()
  val op write_event_ok_refund = TDB.find "write_event_ok_refund"
  fun op write_event_ok_def _ = ()
  val op write_event_ok_def = TDB.find "write_event_ok_def"
  fun op print_spec_refund _ = ()
  val op print_spec_refund = TDB.find "print_spec_refund"
  fun op print_spec_V _ = () val op print_spec_V = TDB.find "print_spec_V"
  fun op output_spec_V _ = ()
  val op output_spec_V = TDB.find "output_spec_V"
  fun op output_aux_spec_V _ = ()
  val op output_aux_spec_V = TDB.find "output_aux_spec_V"
  fun op output_STDIO_spec_V _ = ()
  val op output_STDIO_spec_V = TDB.find "output_STDIO_spec_V"
  fun op UNIQUE_STDIO_V _ = ()
  val op UNIQUE_STDIO_V = TDB.find "UNIQUE_STDIO_V"
  fun op UNIQUE_IOFS_V _ = ()
  val op UNIQUE_IOFS_V = TDB.find "UNIQUE_IOFS_V"
  fun op STDIO_V_numchars _ = ()
  val op STDIO_V_numchars = TDB.find "STDIO_V_numchars"
  fun op STDIO_V_HPROP_INJ _ = ()
  val op STDIO_V_HPROP_INJ = TDB.find "STDIO_V_HPROP_INJ"
  fun op SEG_APPEND3_W _ = ()
  val op SEG_APPEND3_W = TDB.find "SEG_APPEND3_W"
  fun op IOxV_FFI_part_IN _ = ()
  val op IOxV_FFI_part_IN = TDB.find "IOxV_FFI_part_IN"
  fun op IOFS_V_HPROP_INJ _ = ()
  val op IOFS_V_HPROP_INJ = TDB.find "IOFS_V_HPROP_INJ"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundR6Write"

end
