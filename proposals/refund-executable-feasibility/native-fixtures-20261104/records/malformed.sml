load "forge_refundWireProgTheory";
open HolKernel boolLib bossLib;
val _ = Globals.max_print_depth := 100000;
fun term s = Parse.Term [QUOTE s];
fun inspect name th = let val (ors, axs) = Tag.dest_tag (Thm.tag th) in
  if not (null (hyp th)) orelse not (null axs) then raise Fail "unexpected proof dependencies" else ();
  print ("FIXTURE_THEOREM " ^ name ^ "\n");
  print ("FIXTURE_ORACLES " ^ String.concatWith "," ors ^ "\n");
  print ("FIXTURE_STATEMENT " ^ Parse.thm_to_string th ^ "\n") end;
fun check name source = let val th = EQT_ELIM (computeLib.EVAL_CONV (term source))
  in inspect name th end;
fun emit name path source = let
  val th = computeLib.EVAL_CONV (term source);
  val data = stringSyntax.fromHOLstring (rhs (concl th));
  val _ = inspect name th;
  val stream = BinIO.openOut path;
  val _ = BinIO.output (stream, Byte.stringToBytes data);
  val _ = BinIO.closeOut stream;
  in print ("FIXTURE_BYTES " ^ name ^ " " ^ Int.toString (size data) ^ "\n") end;

val _ = check "trailing_newline:error" "refund_run_wire (strlit (MAP CHR [40;99;104;97;114;103;101;45;49;32;114;101;113;117;101;115;116;45;49;32;49;48;48;32;54;48;32;84;114;117;101;32;84;114;117;101;32;84;114;117;101;32;52;48;32;114;101;116;117;114;110;101;100;95;105;116;101;109;41;10])) = INL (strlit (MAP CHR [114;101;102;117;110;100;58;32;116;114;97;105;108;105;110;103;32;105;110;112;117;116]))";
val _ = emit "trailing_newline:stdin" "/Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0003/wire/trailing_newline.stdin" "explode (strlit (MAP CHR [40;99;104;97;114;103;101;45;49;32;114;101;113;117;101;115;116;45;49;32;49;48;48;32;54;48;32;84;114;117;101;32;84;114;117;101;32;84;114;117;101;32;52;48;32;114;101;116;117;114;110;101;100;95;105;116;101;109;41;10]))";
val _ = check "second_request:error" "refund_run_wire (strlit (MAP CHR [40;99;104;97;114;103;101;45;49;32;114;101;113;117;101;115;116;45;49;32;49;48;48;32;54;48;32;84;114;117;101;32;84;114;117;101;32;84;114;117;101;32;52;48;32;114;101;116;117;114;110;101;100;95;105;116;101;109;41;32;40;99;104;97;114;103;101;45;49;32;114;101;113;117;101;115;116;45;49;32;49;48;48;32;54;48;32;84;114;117;101;32;84;114;117;101;32;84;114;117;101;32;52;48;32;114;101;116;117;114;110;101;100;95;105;116;101;109;41])) = INL (strlit (MAP CHR [114;101;102;117;110;100;58;32;116;114;97;105;108;105;110;103;32;105;110;112;117;116]))";
val _ = emit "second_request:stdin" "/Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0003/wire/second_request.stdin" "explode (strlit (MAP CHR [40;99;104;97;114;103;101;45;49;32;114;101;113;117;101;115;116;45;49;32;49;48;48;32;54;48;32;84;114;117;101;32;84;114;117;101;32;84;114;117;101;32;52;48;32;114;101;116;117;114;110;101;100;95;105;116;101;109;41;32;40;99;104;97;114;103;101;45;49;32;114;101;113;117;101;115;116;45;49;32;49;48;48;32;54;48;32;84;114;117;101;32;84;114;117;101;32;84;114;117;101;32;52;48;32;114;101;116;117;114;110;101;100;95;105;116;101;109;41]))";
val _ = check "unclosed_expression:error" "refund_run_wire (strlit (MAP CHR [40])) = INL (strlit (MAP CHR [114;101;102;117;110;100;58;32;105;110;118;97;108;105;100;32;83;45;101;120;112;114;101;115;115;105;111;110]))";
val _ = emit "unclosed_expression:stdin" "/Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0003/wire/unclosed_expression.stdin" "explode (strlit (MAP CHR [40]))";
val _ = check "empty_input:error" "refund_run_wire (strlit (MAP CHR [])) = INL (strlit (MAP CHR [114;101;102;117;110;100;58;32;105;110;118;97;108;105;100;32;83;45;101;120;112;114;101;115;115;105;111;110]))";
val _ = emit "empty_input:stdin" "/Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0003/wire/empty_input.stdin" "explode (strlit (MAP CHR []))";
val _ = check "missing_fields:error" "refund_run_wire (strlit (MAP CHR [40;41])) = INL (strlit (MAP CHR [100;101;115;116;57;58;32;69;120;112;101;99;116;101;100;32;108;101;110;103;116;104;32;57;44;32;114;101;99;101;105;118;101;100;32;108;101;110;103;116;104;32;48]))";
val _ = emit "missing_fields:stdin" "/Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0003/wire/missing_fields.stdin" "explode (strlit (MAP CHR [40;41]))";
val _ = check "invalid_integer:error" "refund_run_wire (strlit (MAP CHR [40;99;104;97;114;103;101;45;49;32;114;101;113;117;101;115;116;45;49;32;49;48;48;32;54;48;32;84;114;117;101;32;84;114;117;101;32;84;114;117;101;32;110;111;116;45;97;110;45;105;110;116;101;103;101;114;32;114;101;116;117;114;110;101;100;95;105;116;101;109;41])) = INL (strlit (MAP CHR [116;111;95;105;110;116;58;32;102;114;111;109;83;116;114;105;110;103;32;102;97;105;108;101;100]))";
val _ = emit "invalid_integer:stdin" "/Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0003/wire/invalid_integer.stdin" "explode (strlit (MAP CHR [40;99;104;97;114;103;101;45;49;32;114;101;113;117;101;115;116;45;49;32;49;48;48;32;54;48;32;84;114;117;101;32;84;114;117;101;32;84;114;117;101;32;110;111;116;45;97;110;45;105;110;116;101;103;101;114;32;114;101;116;117;114;110;101;100;95;105;116;101;109;41]))";
val _ = print "MALFORMED_BATCH_COMPLETE 6\n";
OS.Process.exit OS.Process.success;
