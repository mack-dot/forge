(* DRAFT (M1-B wave 4, worker Y2, link S6 extended towards X14). NOT RUN.

   Step H4 of RUN_PLAN.md. Runs only after forge_refundExportedContractScript.sml
   has exit 0. The runner passes the stored theory of that run as two extra
   arguments (.sig and .sml, as U294 bridge-0001 did with SourceBinding).

   Claim: if a reader parses the COMPLETE rendered result text of
   refund_fields with the published parser and reads the six fields with the
   published refund_response_fields, then no bytes remain, the six fields are
   exactly the result of refund_fields, and they satisfy the exported flat
   contract. Premise 1 holds for exactly one tuple for every input
   (refund_fields is total), and premises 2 and 3 then hold by
   refund_render_fields_roundtrip, so the statement is not vacuous.

   It says NOTHING about a cut output (link X13), about the bytes on
   descriptor 1 (X9) or about the real process (X8). *)

fun need name =
  case OS.Process.getEnv name of
    SOME v => v
  | NONE => raise Fail ("Missing environment variable " ^ name);

(* The loads are in preload-render.sml, which runs BEFORE the stored
   forge_refundExportedContractTheory .sig/.sml (their parents must be
   loaded first). *)
open preamble forge_refundTheory forge_refundExportedContractTheory;
open dafny_evaluateTheory dafny_semanticPrimitivesTheory;

val _ = OS.FileSys.chDir (need "FORGE_P3_OUT");
val _ = new_theory "forge_refundExportedRender";

val exported_contract_on_rendered_output = store_thm (
  "exported_contract_on_rendered_output", ``
  forge_refundCertifiedProg$refund_fields charge request original remaining enabled
      opened candidate amount reason = (ok0,a0,r0,c0,q0,n0) /\
  mlsexp$parse (explode (forge_refundWireProg$refund_render_fields
      (ok0,a0,r0,c0,q0,n0))) = INR (se, rest) /\
  forge_refund_io$refund_response_fields se = INR (ok,a,r,c,q,n) ==>
  rest = [] /\ (ok,a,r,c,q,n) = (ok0,a0,r0,c0,q0,n0) /\
  evaluate_exps (exported_contract_state h charge request original remaining enabled
      opened candidate amount reason ok a r c q n) env exported_ensures =
  (exported_contract_state h charge request original remaining enabled opened
      candidate amount reason ok a r c q n,
   Rval [BoolV T; BoolV T; BoolV T])``,
  rpt strip_tac >>
  gvs [forge_refundWireProgTheory.refund_render_fields_roundtrip] >>
  drule exported_contract_on_refund_fields >> simp []);

val _ = let val th = exported_contract_on_rendered_output
            val (ors, axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
  then () else raise Fail "Unexpected assumptions or tags";
  print ("FORGE_THEOREM exported_contract_on_rendered_output\n");
  print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n") end;

val _ = export_theory ();
val _ = print "EXPORTED_RENDER_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
