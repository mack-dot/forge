load "labSemTheory"; load "labPropsTheory";
open preamble labSemTheory labLangTheory forge_labRegionInvariantTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name) end;
(* Control: without the premise that G holds of every Word, the instruction lemma must not be the stored statement. *)
val th = DB.fetch "forge_labRegionInvariant" "asm_inst_val_inv";
val original = ``!i s. (!w. G (Word w)) /\ val_inv G s ==> val_inv G (labSem$asm_inst i s)``;
val _ = if aconv original (concl th) then () else raise Fail "Harness: original statement does not match";
val _ = pr "AFTER_POSITIVE_AUDIT";
val weaker = ``!i s. val_inv G s ==> val_inv G (labSem$asm_inst i s)``;
val _ = if aconv weaker (concl th) then pr "UNEXPECTED_CONTROL_ACCEPTANCE"
        else raise Fail "Exact statement mismatch: missing Word premise";
val _ = OS.Process.exit OS.Process.success;
