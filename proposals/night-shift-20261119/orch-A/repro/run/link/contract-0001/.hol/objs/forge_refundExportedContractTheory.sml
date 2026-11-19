structure forge_refundExportedContractTheory :> forge_refundExportedContractTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundExportedContractTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundCertifiedProgTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundExportedContract",
        hash = "e8ca1d976203bbe7cd391f52af2da153b4809ea1",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundExportedContract" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op exported_ensures_def _ = ()
  val op exported_ensures_def = TDB.find "exported_ensures_def"
  fun op exported_ens3_value _ = ()
  val op exported_ens3_value = TDB.find "exported_ens3_value"
  fun op exported_ens3_def _ = ()
  val op exported_ens3_def = TDB.find "exported_ens3_def"
  fun op exported_ens2_value _ = ()
  val op exported_ens2_value = TDB.find "exported_ens2_value"
  fun op exported_ens2_def _ = ()
  val op exported_ens2_def = TDB.find "exported_ens2_def"
  fun op exported_ens1_value _ = ()
  val op exported_ens1_value = TDB.find "exported_ens1_value"
  fun op exported_ens1_def _ = ()
  val op exported_ens1_def = TDB.find "exported_ens1_def"
  fun op exported_contract_witnesses _ = ()
  val op exported_contract_witnesses = TDB.find
    "exported_contract_witnesses"
  fun op exported_contract_value _ = ()
  val op exported_contract_value = TDB.find "exported_contract_value"
  fun op exported_contract_text_def _ = ()
  val op exported_contract_text_def = TDB.find "exported_contract_text_def"
  fun op exported_contract_state_def _ = ()
  val op exported_contract_state_def = TDB.find
    "exported_contract_state_def"
  fun op exported_contract_shape _ = ()
  val op exported_contract_shape = TDB.find "exported_contract_shape"
  fun op exported_contract_program_def _ = ()
  val op exported_contract_program_def = TDB.find
    "exported_contract_program_def"
  fun op exported_contract_on_refund_fields _ = ()
  val op exported_contract_on_refund_fields = TDB.find
    "exported_contract_on_refund_fields"
  fun op exported_contract_exact _ = ()
  val op exported_contract_exact = TDB.find "exported_contract_exact"
  fun op exported_contract_decode _ = ()
  val op exported_contract_decode = TDB.find "exported_contract_decode"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundExportedContract"

end
