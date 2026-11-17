signature forge_compileCorrectLabFactsTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val lab_facts_def : thm
    val lab_guard_def : thm
    val lab_keep_word_def : thm
  
  (*  Theorems  *)
    val compile_correct_from_guard : thm
    val compile_correct_lab_facts : thm
    val compile_correct_lab_guard : thm
    val determ_not_fail : thm
    val lab_guard_elim : thm
    val lab_guard_true : thm
    val lab_nonfail_unaligned : thm
    val to_word_confs : thm
end
