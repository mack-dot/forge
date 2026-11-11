val refund_config_ok=store_thm("refund_config_ok",``backendProof$backend_config_ok ^ac ^cfg``,
 simp[arm8_configProofTheory.arm8_backend_config_ok]);
val refund_name_permutation=store_thm("refund_name_permutation",``
 backend_common$find_name (^cfg).stack_conf.reg_names PERMUTES UNIV``,
 mp_tac refund_config_ok >> simp[backendProofTheory.backend_config_ok_def] >> metis_tac[]);
val _=print "CONFIGURATION_CHECKED\n";
val witness_ok_tm=``arm8_configProof$is_arm8_machine_config
 (ARB with <|target:=arm8_target$arm8_target;len_reg:=1;ptr_reg:=0;len2_reg:=3;
 ptr2_reg:=2;callee_saved_regs:=[19;20;21;22;23;24;25;26;27;28]|>)``;
val witness=rand witness_ok_tm;
val witness_ok=prove(witness_ok_tm,simp[arm8_configProofTheory.is_arm8_machine_config_def]);
val witness_mc_ok=MATCH_MP arm8_configProofTheory.arm8_machine_config_ok witness_ok;
val synv=find_term(fn tm=>is_var tm andalso fst(dest_var tm)="syn")so;
val oracle_raw=MATCH_MP(REWRITE_RULE[GSYM AND_IMP_INTRO]
 (INST_TYPE[alpha|->``:64``] oracle_stack_good_code))
 (cj 1 forge_refundArm8CompileTheory.refund_arm8_compiled);
val oracle_exact=oracle_raw |> Q.GENL[`reg_count_sub`,`mc`,`syntax`,`f`,`n`]
 |> ISPECL[stk,witness,synv,stackproj,``n:num``]
 |> SIMP_RULE(srw_ss())[refund_config_ok,witness_mc_ok,
  EVAL ``isa_bits ^ac=dimindex(:64)``,arm8_targetTheory.arm8_target_def];
val refund_stack_oracle_good=store_thm("refund_stack_oracle_good",``
 !n.stack_to_labProof$good_code ^stk (FST(SND(^so n)))``,
 gen_tac >> ACCEPT_TAC oracle_exact);
val _=print "FUTURE_STACK_CODE_CHECKED\n";
val reduced=SIMP_RULE(srw_ss())[refund_name_permutation,refund_stack_oracle_good]
 refund_initialization_sufficient |> REWRITE_RULE[AND_IMP_INTRO,GSYM CONJ_ASSOC];
val refund_initialization_static=save_thm("refund_initialization_static",reduced);
val _=print("REMAINING_ANTECEDENTS "^Int.toString(length(strip_conj(fst(dest_imp(concl reduced)))))^"\n");
val _=Globals.max_print_depth:=1000;
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM")ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^"\n"^Parse.thm_to_string th^"\n")end)
 [("refund_config_ok",refund_config_ok),("refund_name_permutation",refund_name_permutation),
  ("refund_stack_oracle_good",refund_stack_oracle_good),("refund_initialization_static",refund_initialization_static)];
val _=export_theory();
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;
