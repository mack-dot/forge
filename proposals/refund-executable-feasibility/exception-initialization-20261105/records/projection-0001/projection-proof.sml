open preamble;
open forge_refundRejectSemanticsTheory forge_refundWholeProgTheory
     forge_refundStdioProgTheory forge_refundWireProgTheory
     basis_ffiTheory TextIOProofTheory fsFFITheory fsFFIPropsTheory
     set_sepTheory cfHeapsBaseTheory cfHeapsTheory cfStoreTheory
     evaluatePropsTheory evaluate_decTheory ml_progTheory
     semanticPrimitivesTheory;
open finite_mapTheory clFFITheory runtimeFFITheory;
val _ = Globals.max_print_depth := 1000;
val _ = new_theory "forge_refundRejectBasis";

val refund_basis_fs_projection = store_thm ("refund_basis_fs_projection", ``
  MEM n (MAP FST (SND (SND fs_ffi_part))) ⇒
  FLOOKUP (basis_proj1 (cl,fs)) n = SOME (encode fs)``,
  rw [fs_ffi_part_def] >> EVAL_TAC);

val checked = [("refund_basis_fs_projection",refund_basis_fs_projection)];
val _ = List.app (fn (name,th) =>
  let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
    if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
    then () else raise Fail ("Unexpected trust dependency: " ^ name);
    print ("CHECKED_THEOREM " ^ name ^ "\n" ^ Parse.thm_to_string th ^ "\n");
    print ("CHECKED_ORACLES " ^ String.concatWith "," ors ^ "\n");
    print "CHECKED_HYPOTHESES 0\nCHECKED_TAGGED_AXIOMS 0\n"
  end) checked;
val _ = export_theory ();
val _ = print "EXCEPTION_BASIS_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
