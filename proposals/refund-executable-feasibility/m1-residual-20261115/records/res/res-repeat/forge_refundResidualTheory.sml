structure forge_refundResidualTheory :> forge_refundResidualTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundResidualTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundFfiFactsTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundResidual",
        hash = "d16c69f4391334c7171fe86ab96b0eb84251ffd6",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundResidual" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op wrong_base0_rejected _ = ()
  val op wrong_base0_rejected = TDB.find "wrong_base0_rejected"
  fun op refund_u298_exclusion_from_entry_reduced _ = ()
  val op refund_u298_exclusion_from_entry_reduced = TDB.find
    "refund_u298_exclusion_from_entry_reduced"
  fun op refund_stub_outside_domain _ = ()
  val op refund_stub_outside_domain = TDB.find "refund_stub_outside_domain"
  fun op refund_mc_concrete_fields _ = ()
  val op refund_mc_concrete_fields = TDB.find "refund_mc_concrete_fields"
  fun op refund_installed_rest_reduced _ = ()
  val op refund_installed_rest_reduced = TDB.find
    "refund_installed_rest_reduced"
  fun op refund_installed_rest2_def _ = ()
  val op refund_installed_rest2_def = TDB.find "refund_installed_rest2_def"
  fun op refund_installed_from_entry_reduced _ = ()
  val op refund_installed_from_entry_reduced = TDB.find
    "refund_installed_from_entry_reduced"
  fun op refund_behavior_from_entry_reduced _ = ()
  val op refund_behavior_from_entry_reduced = TDB.find
    "refund_behavior_from_entry_reduced"
  fun op heap_on_halt_stub_rejected _ = ()
  val op heap_on_halt_stub_rejected = TDB.find "heap_on_halt_stub_rejected"
  fun op halt_stub_in_domain_rejected _ = ()
  val op halt_stub_in_domain_rejected = TDB.find
    "halt_stub_in_domain_rejected"
  fun op ffi_entry_stub_in_domain_rejected _ = ()
  val op ffi_entry_stub_in_domain_rejected = TDB.find
    "ffi_entry_stub_in_domain_rejected"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundResidual"

end
