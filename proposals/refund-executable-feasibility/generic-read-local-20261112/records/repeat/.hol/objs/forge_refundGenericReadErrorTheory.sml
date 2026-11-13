structure forge_refundGenericReadErrorTheory :> forge_refundGenericReadErrorTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundGenericReadErrorTheory ... "
    else ()
  
  open Type Term Thm
  local open basis_ffiTheory forge_refundStdinDomainTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundGenericReadError",
        hash = "22a9362a022fcfc652a9b59bfafb3fca75fc1b46",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundGenericReadError" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op read_error_generic _ = ()
  val op read_error_generic = TDB.find "read_error_generic"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundGenericReadError"

end
