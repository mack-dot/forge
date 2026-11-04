structure forge_refundCertifiedProgTheory :> forge_refundCertifiedProgTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundCertifiedProgTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refund_ioTheory mlbasicsProgTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundCertifiedProg",
        hash = "439e5c15ea28cb91e55dc57732c210679bc500e4",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundCertifiedProg" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op refund_verified_v_def _ = ()
  val op refund_verified_v_def = TDB.find "refund_verified_v_def"
  fun op refund_verified_spec _ = ()
  val op refund_verified_spec = TDB.find "refund_verified_spec"
  fun op refund_fields_v_thm _ = ()
  val op refund_fields_v_thm = TDB.find "refund_fields_v_thm"
  fun op refund_fields_v_def _ = ()
  val op refund_fields_v_def = TDB.find "refund_fields_v_def"
  fun op refund_fields_original_method _ = ()
  val op refund_fields_original_method = TDB.find
    "refund_fields_original_method"
  fun op refund_fields_def _ = ()
  val op refund_fields_def = TDB.find "refund_fields_def"
  fun op nsLookup_forge_refundCertifiedProg_env_pfun_eqs _ = ()
  val op nsLookup_forge_refundCertifiedProg_env_pfun_eqs = TDB.find
    "nsLookup_forge_refundCertifiedProg_env_pfun_eqs"
  fun op nsLookup_forge_refundCertifiedProg_env_1_pfun_eqs _ = ()
  val op nsLookup_forge_refundCertifiedProg_env_1_pfun_eqs = TDB.find
    "nsLookup_forge_refundCertifiedProg_env_1_pfun_eqs"
  fun op nsLookup_forge_refundCertifiedProg_env_0_pfun_eqs _ = ()
  val op nsLookup_forge_refundCertifiedProg_env_0_pfun_eqs = TDB.find
    "nsLookup_forge_refundCertifiedProg_env_0_pfun_eqs"
  fun op forge_refundCertifiedProg_env_def _ = ()
  val op forge_refundCertifiedProg_env_def = TDB.find
    "forge_refundCertifiedProg_env_def"
  fun op forge_refundCertifiedProg_env_1_def _ = ()
  val op forge_refundCertifiedProg_env_1_def = TDB.find
    "forge_refundCertifiedProg_env_1_def"
  fun op forge_refundCertifiedProg_env_0_def _ = ()
  val op forge_refundCertifiedProg_env_0_def = TDB.find
    "forge_refundCertifiedProg_env_0_def"
  fun op eligible_v_thm _ = ()
  val op eligible_v_thm = TDB.find "eligible_v_thm"
  fun op eligible_v_def _ = ()
  val op eligible_v_def = TDB.find "eligible_v_def"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundCertifiedProg"

end
