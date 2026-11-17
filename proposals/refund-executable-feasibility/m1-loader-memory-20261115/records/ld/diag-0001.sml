(* Diagnostic: form of the stored code and data terms. No theorem is stored. *)
open preamble forge_refundArm8CompileTheory;
fun pr s = print (s ^ "\n");
val code_def = DB.fetch "forge_refundArm8Compile" "code_def"; val data_def = DB.fetch "forge_refundArm8Compile" "data_def";
val codeL = rhs (concl code_def); val dataL = rhs (concl data_def);
val _ = pr ("CODE_TYPE " ^ type_to_string (type_of codeL) ^ " IS_LIST " ^ Bool.toString (listSyntax.is_list codeL));
val (c, args) = strip_comb codeL;
val _ = pr ("CODE_HEAD " ^ term_to_string c ^ " ARGS " ^ Int.toString (length args));
val _ = if listSyntax.is_list codeL then let val (els, _) = listSyntax.dest_list codeL in
   pr ("CODE_LEN " ^ Int.toString (length els)); 
   List.app (fn t => pr ("EL " ^ term_to_string t ^ " RAW " ^ Hol_pp.term_to_string (rand t) ^ " is_word_literal " ^ Bool.toString (wordsSyntax.is_word_literal t)
       ^ " aconv " ^ Bool.toString (aconv t (wordsSyntax.mk_wordii (wordsSyntax.uint_of_word t, 8))))) (List.take (els, 6)) end
   else pr ("CODE_TERM_PREFIX " ^ String.substring (term_to_string codeL, 0, 300));
val _ = pr ("DATA_TYPE " ^ type_to_string (type_of dataL) ^ " IS_LIST " ^ Bool.toString (listSyntax.is_list dataL));
val _ = pr ("DATA_PREFIX " ^ String.substring (term_to_string dataL, 0, 200));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
