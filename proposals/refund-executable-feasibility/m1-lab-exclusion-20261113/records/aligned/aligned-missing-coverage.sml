load "labSemTheory"; load "labPropsTheory"; load "blastLib";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory forge_labRegionAlignedTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val prefix_expected = ``!s k res t. region_inv2 G D OK code s /\ labSem$evaluate (s with clock := k) = (res,t) ==>
   region_inv2 G D OK code t /\ OK t.pc /\ t.code = code /\ (!i bs n. labSem$asm_fetch t <> SOME (LabAsm Install i bs n))``;
(* Control: without the coverage condition on D (inside region_inv2) the prefix statement must not be the stored one. *)
val th = DB.fetch "forge_labRegionAligned" "region2_prefix";
val _ = if aconv prefix_expected (concl th) then () else raise Fail "Harness: original statement does not match";
val _ = pr "AFTER_POSITIVE_AUDIT";
val weaker = ``!s k res t. s.code = code /\ region_hyp G OK code /\ mval_inv G D s /\ OK s.pc /\
   labSem$evaluate (s with clock := k) = (res,t) ==> OK t.pc``;
val _ = if aconv weaker (concl th) then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else raise Fail "Exact statement mismatch: missing coverage condition";
val _ = OS.Process.exit OS.Process.success;
