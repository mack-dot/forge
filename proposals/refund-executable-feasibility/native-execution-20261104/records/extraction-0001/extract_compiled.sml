(* Run only after the exact compiler theory succeeds. Existing HOL evaluation
   and syntax libraries materialize the code bytes and bitmap numerals. *)
load "forge_refundArm8CompileTheory";
open HolKernel boolLib bossLib;
val _ = Globals.max_print_depth := 100000;
val out = "/Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0004/compiled-extraction/";
val _ = OS.FileSys.mkDir out;
fun write name data = let val stream = BinIO.openOut (out ^ name)
  in BinIO.output (stream, Byte.stringToBytes data); BinIO.closeOut stream end;
fun inspect name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (Thm.hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
  then () else raise Fail "Unexpected theorem dependency";
  write (name ^ ".theorem.txt") (Parse.thm_to_string th ^ "\n");
  print ("ARTIFACT_THEOREM " ^ name ^ " oracles=" ^ String.concatWith "," ors ^ " hypotheses=0\n")
end;
val code_def = DB.fetch "forge_refundArm8Compile" "code_def";
val data_def = DB.fetch "forge_refundArm8Compile" "data_def";
val compiled = DB.fetch "forge_refundArm8Compile" "refund_arm8_compiled";
val code_rhs = rhs (concl code_def);
val data_rhs = rhs (concl data_def);
val code_bytes = computeLib.EVAL_CONV ``MAP (\b:word8. CHR (w2n b)) ^code_rhs``;
val data_nums = computeLib.EVAL_CONV data_rhs;
val code_string = stringSyntax.fromHOLstring (rhs (concl code_bytes));
val numbers = fst (listSyntax.dest_list (rhs (concl data_nums)));
val number_strings = List.map (Arbnum.toString o numSyntax.dest_numeral) numbers;
val _ = inspect "compiled" compiled;
val _ = inspect "code_bytes" code_bytes;
val _ = inspect "data_nums" data_nums;
val _ = write "code.bin" code_string;
val _ = write "data.nums" (String.concatWith "\n" number_strings ^ "\n");
val _ = print ("ARTIFACT_CODE_BYTES " ^ Int.toString (size code_string) ^ "\n");
val _ = print ("ARTIFACT_DATA_NUMERALS " ^ Int.toString (length numbers) ^ "\n");
val _ = print "ARTIFACT_EXTRACTION_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
