(* Diagnostic: atom finder on a small term. No theorem is stored. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory wordsTheory wordsLib;
fun pr s = print (s ^ "\n");
val tm = ``w2w ((s:arm8_state).MEM (a + 1w) @@ s.MEM a) <=+ s.REG 3w``;
val ts = find_terms (fn t => true) tm;
val _ = List.app (fn t => let val (c, args) = strip_comb t in
     pr ("SUB " ^ term_to_string t ^ " HEAD " ^ (if is_const c then fst (dest_const c) else "<nonconst>") ^ " NARGS " ^ Int.toString (length args)) end) ts;
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
