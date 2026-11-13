(* Search of the loaded published theories: which stored theorems mention
   install_pc, and which CONCLUDE a program-counter inequality with it.
   Observation about the theorem database; proves nothing. *)
load "backendProofTheory"; load "arm8_configProofTheory"; load "targetPropsTheory"; load "lab_to_targetProofTheory";
open HolKernel Parse boolLib bossLib;
fun pr s = print (s ^ "\n");
fun is_install_pc t = (let val (f, _) = dest_comb t in is_const f andalso String.isSuffix "install_pc" (fst (dest_const f)) end) handle _ => false;
fun mentions t = can (find_term is_install_pc) t;
fun final_conclusion t = let val t = snd (strip_forall t) in if is_imp t andalso not (is_neg t) then final_conclusion (snd (dest_imp t)) else t end;
fun pc_inequality t = can (find_term (fn u => is_neg u andalso is_eq (dest_neg u) andalso mentions (dest_neg u))) t;
val thys = "backendProof" :: Theory.ancestry "backendProof";
val _ = pr ("SEARCHED_THEORIES " ^ Int.toString (length thys));
val all = List.concat (map (fn thy => map (fn (n, th) => (thy, n, th)) (DB.theorems thy @ DB.definitions thy)) thys);
val _ = pr ("SEARCHED_THEOREMS " ^ Int.toString (length all));
val hits = List.filter (fn (_, _, th) => mentions (concl th)) all;
val _ = pr ("MENTION_INSTALL_PC " ^ Int.toString (length hits));
val _ = List.app (fn (thy, n, th) =>
  let val c = final_conclusion (concl th) in
    pr ("HIT " ^ thy ^ "." ^ n ^ " conclusion_mentions=" ^ Bool.toString (mentions c) ^
        " conclusion_has_pc_inequality=" ^ Bool.toString (pc_inequality c)) end) hits;
val concl_hits = List.filter (fn (_, _, th) => pc_inequality (final_conclusion (concl th))) hits;
val _ = pr ("CONCLUDE_PC_INEQUALITY " ^ Int.toString (length concl_hits));
val _ = List.app (fn (thy, n, th) => pr ("CONCLUSION_HIT " ^ thy ^ "." ^ n ^ "\n" ^ thm_to_string th)) concl_hits;
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
