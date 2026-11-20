(* APEX-2 (2026-11-19). FC3: the three exported ensures clauses (the exact
   export bytes, read in the logic by the published parser, evaluated by the
   published Dafny semantics) hold exactly when the plain contract flat_plain
   holds on the byte codes. Parents: forge_refundExportedContract (the Holmake
   port in this folder) and forge_refundFlatContract.

   No axiom, no cheat, no mk_thm, no new_axiom, no oracle. *)

open HolKernel boolLib bossLib Parse;
open preamble dafny_astTheory dafny_evaluateTheory dafny_semanticPrimitivesTheory;
open forge_refundExportedContractTheory forge_refundFlatContractTheory;

val _ = new_theory "forge_refundFlatExported";

fun prove (name, tm, tac) =
  (print ("FORGE_BEGIN " ^ name ^ "\n"); store_thm (name, tm, tac));

val exported_contract_flat_plain = prove ("exported_contract_flat_plain", ``
  (evaluate_exps (exported_contract_state h charge request original remaining enabled
       opened candidate amount reason ok a r c q n) env exported_ensures =
   (exported_contract_state h charge request original remaining enabled opened
       candidate amount reason ok a r c q n,
    Rval [BoolV T; BoolV T; BoolV T])) <=>
  flat_plain (codes charge) (codes request) original remaining enabled opened
      candidate amount (codes reason) ok a (codes r) (codes c) (codes q) n``,
  simp [exported_contract_exact, refund_fields_flat_plain]);

val checked = [("exported_contract_flat_plain", exported_contract_flat_plain)];

val _ = List.app (fn (name, th) =>
  let val (ors, axs) = Tag.dest_tag (Thm.tag th) in
    if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
    then ()
    else raise Fail ("Unexpected assumptions or tags: " ^ name);
    print ("FORGE_THEOREM " ^ name ^ "\n");
    print ("FORGE_ORACLES " ^ String.concatWith "," ors ^ "\n");
    print ("FORGE_AXIOMS " ^ String.concatWith "," axs ^ "\n");
    print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
    print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
  end) checked;

val _ = export_theory ();
val _ = print "FLAT_EXPORTED_COMPLETE\n";
