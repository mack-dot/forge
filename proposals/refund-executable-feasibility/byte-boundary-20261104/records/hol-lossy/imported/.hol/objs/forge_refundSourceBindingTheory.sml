structure forge_refundSourceBindingTheory :> forge_refundSourceBindingTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_refundSourceBindingTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundTheory sexp_to_dafnyTheory in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_refundSourceBinding",
        hash = "2677fe6830467fd05c52227378bef67ac05dd931",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_refundSourceBinding" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op source_signature _ = ()
  val op source_signature = TDB.find "source_signature"
  fun op source_program_def _ = ()
  val op source_program_def = TDB.find "source_program_def"
  fun op source_postconditions _ = ()
  val op source_postconditions = TDB.find "source_postconditions"
  fun op source_initial_def _ = ()
  val op source_initial_def = TDB.find "source_initial_def"
  fun op source_full_result _ = ()
  val op source_full_result = TDB.find "source_full_result"
  fun op source_export_text_def _ = ()
  val op source_export_text_def = TDB.find "source_export_text_def"
  fun op source_ensures_def _ = ()
  val op source_ensures_def = TDB.find "source_ensures_def"
  fun op source_decode _ = ()
  val op source_decode = TDB.find "source_decode"
  fun op source_body_def _ = ()
  val op source_body_def = TDB.find "source_body_def"
  fun op mapped_operators _ = ()
  val op mapped_operators = TDB.find "mapped_operators"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_refundSourceBinding"

end
