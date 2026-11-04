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
val _ = check "eligible_return:fields" "refund_fields (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) = (T,(41),(strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])),(strlit (MAP CHR [99;104;97;114;103;101;45;49])),(strlit (MAP CHR [114;101;113;117;101;115;116;45;49])),(1))";
OS.Process.exit OS.Process.success;
