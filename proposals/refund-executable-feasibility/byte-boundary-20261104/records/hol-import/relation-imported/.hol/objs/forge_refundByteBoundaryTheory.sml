structure forge_refundByteBoundaryTheory :> forge_refundByteBoundaryTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundByteBoundaryTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundSourceBindingTheory forge_refundWireProgTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundByteBoundary",
        hash = "0bae6d111078970222e14dad7b21b662c1609327",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundByteBoundary" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op byte_wire_outputs _ = ()
  val op byte_wire_outputs = TDB.find "byte_wire_outputs"
  fun op byte_wire_inputs _ = ()
  val op byte_wire_inputs = TDB.find "byte_wire_inputs"
  fun op byte_string_eq _ = ()
  val op byte_string_eq = TDB.find "byte_string_eq"
  fun op byte_string_def _ = ()
  val op byte_string_def = TDB.find "byte_string_def"
  fun op byte_string_codes _ = ()
  val op byte_string_codes = TDB.find "byte_string_codes"
  fun op byte_roundtrip _ = ()
  val op byte_roundtrip = TDB.find "byte_roundtrip"
  fun op byte_fields_result _ = ()
  val op byte_fields_result = TDB.find "byte_fields_result"
  fun op byte_codes_empty _ = ()
  val op byte_codes_empty = TDB.find "byte_codes_empty"
  fun op byte_codes_def _ = ()
  val op byte_codes_def = TDB.find "byte_codes_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundByteBoundary"

end
