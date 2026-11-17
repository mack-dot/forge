structure forge_loaderMemLemmasTheory :> forge_loaderMemLemmasTheory =
struct
  
  val _ = if !Globals.print_thy_loads
    then TextIO.print "Loading forge_loaderMemLemmasTheory ... "
    else ()
  
  open Type Term Thm
  local open forge_refundCmlMainFrameTheory forge_refundStartupBridgeTheory
  in end;
  
  structure TDB = struct
    val path =
      OS.Path.base (#(FILE)) ^ ".dat"
    val timestamp = HOLFileSys.modTime path
    val thydata = 
      TheoryReader.load_thydata {
        thyname = "forge_loaderMemLemmas",
        hash = "0d3c5567ce184ff18ff88d13892cca5653992f1f",
        path = path
      }
    fun find s = #1 (valOf (Symtab.lookup thydata s))
  end
  val () = Theory.record_metadata
    "forge_loaderMemLemmas" {timestamp=TDB.timestamp, path=TDB.path}
  
  fun op word_list_fun2set _ = ()
  val op word_list_fun2set = TDB.find "word_list_fun2set"
  fun op word_list_exists_0 _ = ()
  val op word_list_exists_0 = TDB.find "word_list_exists_0"
  fun op word_list_clause_read _ = ()
  val op word_list_clause_read = TDB.find "word_list_clause_read"
  fun op read_bytearray_from_EL _ = ()
  val op read_bytearray_from_EL = TDB.find "read_bytearray_from_EL"
  fun op mem_dword_word_memory_clause _ = ()
  val op mem_dword_word_memory_clause = TDB.find
    "mem_dword_word_memory_clause"
  fun op mem_dword_join _ = ()
  val op mem_dword_join = TDB.find "mem_dword_join"
  fun op mem_dword_get_byte _ = ()
  val op mem_dword_get_byte = TDB.find "mem_dword_get_byte"
  fun op mem_dword_bytes _ = ()
  val op mem_dword_bytes = TDB.find "mem_dword_bytes"
  fun op forall_lt_SUC_word _ = ()
  val op forall_lt_SUC_word = TDB.find "forall_lt_SUC_word"
  fun op dword_bytes_in_memory _ = ()
  val op dword_bytes_in_memory = TDB.find "dword_bytes_in_memory"
  fun op dword_bytes_def _ = ()
  val op dword_bytes_def = TDB.find "dword_bytes_def"
  fun op bytes_in_memory_univ_frame _ = ()
  val op bytes_in_memory_univ_frame = TDB.find "bytes_in_memory_univ_frame"
  fun op bytes_in_memory_univ_EL _ = ()
  val op bytes_in_memory_univ_EL = TDB.find "bytes_in_memory_univ_EL"
  fun op bytes_in_mem_iff _ = ()
  val op bytes_in_mem_iff = TDB.find "bytes_in_mem_iff"
  fun op byte_align_split _ = ()
  val op byte_align_split = TDB.find "byte_align_split"
  fun op byte_align_64 _ = ()
  val op byte_align_64 = TDB.find "byte_align_64"
  fun op LENGTH_dword_bytes _ = ()
  val op LENGTH_dword_bytes = TDB.find "LENGTH_dword_bytes"
  
val _ = if !Globals.print_thy_loads then TextIO.print "done\n" else ()
val _ = Theory.load_complete "forge_loaderMemLemmas"

end
