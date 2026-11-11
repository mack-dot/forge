load "forge_refundArm8ProofTheory";
load "arm8_targetLib";
open preamble forge_refundArm8CompileTheory;
val _=OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_RUNTIME_OUT"));
val _=new_theory "forge_refundInstallPremise";
val _=computeLib.add_funs [code_def];
val emitted_install_jump = store_thm("emitted_install_jump",``
  TAKE 4 (DROP 4660 forge_refundArm8Compile$code) =
  arm8_target$arm8_enc (asm$Jump (-4692))``,
  CONV_TAC (RAND_CONV arm8_targetLib.arm8_encode_conv) >> EVAL_TAC);
val install_jump_offset = store_thm("install_jump_offset",``
  lab_to_target$get_jump_offset labLang$Install ffis labs 4660 = -4692``,
  EVAL_TAC);
val install_jump_destination = store_thm("install_jump_destination",``
  (asmSem$asm (asm$Jump (-4692)) next_pc
    ((s:64 asm_state) with pc := entry + 4660w)).pc = entry - 32w``,
  simp[asmSemTheory.asm_def,asmSemTheory.jump_to_offset_def,asmSemTheory.upd_pc_def] >>
  wordsLib.WORD_DECIDE_TAC);
val stub_contains_install = store_thm("stub_contains_install",``
  ~wordConvs$no_install (data_to_word$Install_code c)``,
  simp[data_to_wordTheory.Install_code_def,wordLangTheory.list_Seq_def,
       wordConvsTheory.no_install_def]);
val standard_stubs_require_reachability = store_thm("standard_stubs_require_reachability",``
  ~EVERY (\(name,arity,body). wordConvs$no_install body) (data_to_word$stubs c)``,
  `MEM (data_to_word$Install_location,3,data_to_word$Install_code c) (data_to_word$stubs c)`
    by simp[data_to_wordTheory.stubs_def] >>
  simp[EVERY_MEM] >> metis_tac[stub_contains_install]);
val install_safety_cannot_recover = store_thm("install_safety_cannot_recover",``
  dataSem$evaluate (prog,dataSem$install_sfs closLang$Install s) = (res,s1) ==>
  ~s1.safe_for_space``,
  rpt strip_tac >> imp_res_tac dataPropsTheory.evaluate_safe_for_space_mono >>
  fs[dataSemTheory.install_sfs_def]);
val _=Globals.max_print_depth:=1000;
val checks=[("emitted_install_jump",emitted_install_jump),
  ("install_jump_offset",install_jump_offset),("install_jump_destination",install_jump_destination),
  ("stub_contains_install",stub_contains_install),
  ("standard_stubs_require_reachability",standard_stubs_require_reachability),
  ("install_safety_cannot_recover",install_safety_cannot_recover)];
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n") end) checks;
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;
