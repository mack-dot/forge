(* Evaluate the published arm8 compiler on the exact checked source program.
   Assembly output is unsigned. Native linking/execution are separate steps. *)
Theory forge_refundArm8Compile
Ancestors
  forge_refundWholeProg
Libs
  preamble eval_cake_compile_arm8Lib

Theorem refund_arm8_compiled =
  eval_cake_compile_arm8 "" refund_prog_def "refund.S";

val _ = Globals.max_print_depth := 1000;
val _ =
  let val th = refund_arm8_compiled;
      val (oracles,axioms) = Tag.dest_tag (Thm.tag th) in
    print ("FORGE_THEOREM refund_arm8_compiled\n");
    print ("FORGE_ORACLES " ^ String.concatWith "," oracles ^ "\n");
    print ("FORGE_AXIOMS " ^ String.concatWith "," axioms ^ "\n");
    print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
    print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
  end;
