load "forge_refundArm8CompileTheory";
load "lab_to_targetProofTheory";
open preamble targetSemTheory;
val _ = OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_ENTRY_MODEL_OUT"));
val _ = new_theory "forge_refundEntryLayout";
val compiled_ffi_names = store_thm("compiled_ffi_names",
 ``forge_refundArm8Compile$ffis = [«read»;«write»;«close»;«open_in»]``, REWRITE_TAC[forge_refundArm8CompileTheory.ffis_def] >> EVAL_TAC >> simp[cvTheory.cv_snd_def] >> EVAL_TAC);
val observed_mmio_index = store_thm("observed_mmio_index",
 ``mmio_pcs_min_index [ExtCall «read»;ExtCall «write»;ExtCall «close»;ExtCall «open_in»] = SOME 4``,
 MP_TAC (Q.INST [`l |-> []`,`ffis |-> [ExtCall «read»;ExtCall «write»;ExtCall «close»;ExtCall «open_in»]`] lab_to_targetProofTheory.mmio_pcs_min_index_APPEND_thm) >> simp[]);
val required = ``start_pc_ok (mc with <| prog_addresses := (\a:word64. (4300243152 <= w2n a /\ w2n a < 4300374016) \/ (496542679040 <= w2n a /\ w2n a < 497079549952) \/ (4300406808 <= w2n a /\ w2n a < 4300427056)); shared_addresses := {}; halt_pc := 4300243136w; install_pc := 4300243120w; ffi_names := [ExtCall «read»;ExtCall «write»;ExtCall «close»;ExtCall «open_in»]; ffi_entry_pcs := [4300243104w;4300243088w;4300243072w;4300243056w] |>) (4300243152w:word64)``;
val _ = print "CHECKING_RECORDED_ENTRY_LAYOUT\n";
val recorded_entry_layout = store_thm("recorded_entry_layout", required,
 simp[start_pc_ok_def,lab_to_targetTheory.ffi_offset_def,observed_mmio_index,GSYM NOT_LESS,IN_DEF] >>
 CONV_TAC(REDEPTH_CONV(numLib.BOUNDED_FORALL_CONV EVAL)) >> EVAL_TAC);
val _ = List.app(fn th => let val (ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s => s="DISK_THM") ors then ()
 else raise Fail "Unexpected hypotheses, axioms or oracle tags" end)
 [compiled_ffi_names,observed_mmio_index,recorded_entry_layout];
val _ = export_theory();
val _ = print "ENTRY_LAYOUT_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
