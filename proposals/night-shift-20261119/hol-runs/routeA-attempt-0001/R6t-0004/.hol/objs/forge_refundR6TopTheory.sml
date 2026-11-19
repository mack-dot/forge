structure forge_refundR6TopTheory :> forge_refundR6TopTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundR6TopTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundR6WriteTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundR6Top",
        hash = "a0af1147ef384c1707a06cdcc3693fcd889eac11",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundR6Top" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op whole_prog_spec_V_init _ = ()
  val op whole_prog_spec_V_init = TDB.find "whole_prog_spec_V_init"
  fun op whole_prog_spec_V_events _ = ()
  val op whole_prog_spec_V_events = TDB.find "whole_prog_spec_V_events"
  fun op sem_satisfies_imp_V _ = ()
  val op sem_satisfies_imp_V = TDB.find "sem_satisfies_imp_V"
  fun op parts_ok_basis_ffi _ = ()
  val op parts_ok_basis_ffi = TDB.find "parts_ok_basis_ffi"
  fun op init_rt_part_IN _ = ()
  val op init_rt_part_IN = TDB.find "init_rt_part_IN"
  fun op init_iobuff_IN _ = ()
  val op init_iobuff_IN = TDB.find "init_iobuff_IN"
  fun op init_heap_V _ = () val op init_heap_V = TDB.find "init_heap_V"
  fun op init_fs_part_IN _ = ()
  val op init_fs_part_IN = TDB.find "init_fs_part_IN"
  fun op init_cl_part_IN _ = ()
  val op init_cl_part_IN = TDB.find "init_cl_part_IN"
  fun op final_heap_events _ = ()
  val op final_heap_events = TDB.find "final_heap_events"
  fun op every_basis_events _ = ()
  val op every_basis_events = TDB.find "every_basis_events"
  fun op basis_proj2_names _ = ()
  val op basis_proj2_names = TDB.find "basis_proj2_names"
  fun op STDIO_V_of_IOFS_V _ = ()
  val op STDIO_V_of_IOFS_V = TDB.find "STDIO_V_of_IOFS_V"
  fun op STDIO_V_events _ = ()
  val op STDIO_V_events = TDB.find "STDIO_V_events"
  fun op STDIO_V_FFI_part_hprop _ = ()
  val op STDIO_V_FFI_part_hprop = TDB.find "STDIO_V_FFI_part_hprop"
  fun op IOxV_events_IN _ = ()
  val op IOxV_events_IN = TDB.find "IOxV_events_IN"
  fun op IOFS_V_init _ = () val op IOFS_V_init = TDB.find "IOFS_V_init"
  fun op FFI_part_IN_st2heap_FILTER _ = ()
  val op FFI_part_IN_st2heap_FILTER = TDB.find "FFI_part_IN_st2heap_FILTER"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundR6Top"

end
