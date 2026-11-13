(* Exploration only: forward composition of the six published step theorems.
   It stores no theorem and exports no theory. *)
open HolKernel Parse boolLib bossLib arm8Theory arm8_stepTheory;
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
val words = ["37f800c0","52800028","39000268","a9417bfd","a8c24ff4","d65f03c0"];
val all = map arm8_stepLib.arm8_step_hex words;
fun positive_bit h = not (is_neg h) andalso can (find_term (fn t => same_const t ``word_bit``)) h;
val taken = hd (List.filter (fn th => List.exists positive_bit (hyp th)) (hd all));
val steps = taken :: map hd (tl all);
val s = ``s:arm8_state``;
val simp_thms = [combinTheory.APPLY_UPDATE_THM, wordsTheory.WORD_ADD_0];
fun simp_term t = (rhs (concl (SIMP_CONV (srw_ss()) simp_thms t))) handle UNCHANGED => t;
fun advance (th, (state, n)) =
  let val th1 = INST [s |-> state] th
      val next0 = rand (rhs (concl th1))
      val next = simp_term next0
      val _ = pr ("STEP " ^ Int.toString n)
      val _ = List.app (fn h => pr ("  HYP_RAW " ^ term_to_string h ^ "\n  HYP_SIMP " ^ term_to_string (simp_term h))) (hyp th1)
      val _ = pr ("  NEXT_STATE " ^ term_to_string next)
  in (next, n + 1) end;
val (final, _) = List.foldl advance (s, 1) steps;
val _ = pr ("FINAL_STATE " ^ term_to_string final);
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
