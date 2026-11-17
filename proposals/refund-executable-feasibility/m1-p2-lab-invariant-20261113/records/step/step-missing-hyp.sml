load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory forge_labRegionStepTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
val one_step_expected = ``!s res t. region_inv G OK code s /\ labSem$evaluate s = (res,t) ==>
   (?s2. labSem$evaluate s2 = (res,t) /\ region_inv G OK code s2 /\ s2.clock < s.clock) \/ t = s``;
val prefix_expected = ``!s k res t. region_inv G OK code s /\ labSem$evaluate (s with clock := k) = (res,t) ==>
   region_inv G OK code t /\ OK t.pc /\ t.code = code /\ (!i bs n. labSem$asm_fetch t <> SOME (LabAsm Install i bs n))``;
(* Control: the prefix statement without the static hypothesis (region_inv replaced by its dynamic parts) must not be the stored one. *)
val th = DB.fetch "forge_labRegionStep" "region_prefix";
val _ = if aconv prefix_expected (concl th) then () else raise Fail "Harness: original statement does not match";
val _ = pr "AFTER_POSITIVE_AUDIT";
val weaker = ``!s k res t. s.code = code /\ val_inv G s /\ OK s.pc /\ labSem$evaluate (s with clock := k) = (res,t) ==> OK t.pc``;
val _ = if aconv weaker (concl th) then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else raise Fail "Exact statement mismatch: missing static hypothesis";
val _ = OS.Process.exit OS.Process.success;
