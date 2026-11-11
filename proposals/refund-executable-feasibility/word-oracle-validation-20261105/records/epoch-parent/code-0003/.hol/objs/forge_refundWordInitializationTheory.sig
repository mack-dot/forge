signature forge_refundWordInitializationTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val compiled_raw_code_rel : thm
    val compiled_word_code_rel : thm
    val make_init_static : thm
    val refund_data_labels : thm
    val refund_word_code_rel : thm
    val to_word_code_rel : thm
end
