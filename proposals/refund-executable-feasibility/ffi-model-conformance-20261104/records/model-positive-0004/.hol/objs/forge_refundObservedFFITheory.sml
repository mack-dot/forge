structure forge_refundObservedFFITheory :> forge_refundObservedFFITheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundObservedFFITheory ... "
    else ()
  
  open Type Term Thm
  local open basis_ffiTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundObservedFFI",
        hash = "f8c17b50a9345896ae89d2a4632f955cc015a874",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundObservedFFI" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op observed_ffi_3 _ = ()
  val op observed_ffi_3 = TDB.find "observed_ffi_3"
  fun op observed_ffi_2 _ = ()
  val op observed_ffi_2 = TDB.find "observed_ffi_2"
  fun op observed_ffi_1 _ = ()
  val op observed_ffi_1 = TDB.find "observed_ffi_1"
  fun op observed_ffi_0 _ = ()
  val op observed_ffi_0 = TDB.find "observed_ffi_0"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundObservedFFI"

end
