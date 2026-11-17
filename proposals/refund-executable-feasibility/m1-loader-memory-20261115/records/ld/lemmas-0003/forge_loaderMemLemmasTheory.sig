signature forge_loaderMemLemmasTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val dword_bytes_def : thm
  
  (*  Theorems  *)
    val LENGTH_dword_bytes : thm
    val byte_align_64 : thm
    val byte_align_split : thm
    val bytes_in_mem_iff : thm
    val bytes_in_memory_univ_EL : thm
    val bytes_in_memory_univ_frame : thm
    val dword_bytes_in_memory : thm
    val forall_lt_SUC_word : thm
    val mem_dword_bytes : thm
    val mem_dword_get_byte : thm
    val mem_dword_join : thm
    val mem_dword_word_memory_clause : thm
    val read_bytearray_from_EL : thm
    val word_list_clause_read : thm
    val word_list_exists_0 : thm
    val word_list_fun2set : thm
end
