(* Diagnostic: form of the stored code and data terms; kernel evaluation to list literals. No theorem is stored. *)
open preamble forge_refundArm8CompileTheory;
fun pr s = print (s ^ "\n");
val code_def = DB.fetch "forge_refundArm8Compile" "code_def"; val data_def = DB.fetch "forge_refundArm8Compile" "data_def";
fun describe nm L = let val (c, args) = strip_comb L in
   pr (nm ^ "_HEAD " ^ term_to_string c ^ " : " ^ type_to_string (type_of c));
   List.app (fn a => let val (c2, a2) = strip_comb a in pr (nm ^ "_ARG head " ^ term_to_string c2 ^ " nargs " ^ Int.toString (length a2) ^ " size " ^ Int.toString (term_size a)) end) args end;
val codeL = rhs (concl code_def); val dataL = rhs (concl data_def);
val _ = describe "CODE" codeL; val _ = describe "DATA" dataL;
fun timed nm f = let val t = Time.now () val r = f () in pr (nm ^ " seconds " ^ Time.toString (Time.- (Time.now (), t))); r end;
val ce = timed "EVAL_CODE" (fn () => EVAL codeL);
val (els, _) = listSyntax.dest_list (rhs (concl ce));
val _ = pr ("CODE_LEN " ^ Int.toString (length els));
val _ = List.app (fn t => pr ("EL " ^ term_to_string t ^ " aconv_mk_wordii " ^ Bool.toString (aconv t (wordsSyntax.mk_wordii (wordsSyntax.uint_of_word t, 8))))) (List.take (els, 4));
val (ors, axs) = Tag.dest_tag (Thm.tag ce);
val _ = pr ("EVAL_TAG oracles " ^ String.concatWith "," ors ^ " axioms " ^ Int.toString (length axs) ^ " hyps " ^ Int.toString (length (hyp ce)));
val de = timed "EVAL_DATA" (fn () => EVAL dataL);
val (dels, _) = listSyntax.dest_list (rhs (concl de));
val _ = pr ("DATA_LEN " ^ Int.toString (length dels) ^ " first " ^ term_to_string (hd dels));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
