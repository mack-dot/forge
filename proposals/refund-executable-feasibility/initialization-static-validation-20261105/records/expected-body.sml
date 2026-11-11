val expected_code=``(^lab).code=stack_to_lab$compile ^aw (^cfg).stack_conf ^dc
 (2*data_to_word$max_heap_limit (dimindex(:64)) ^dc-1) ^stk (^ac).addr_offset ^stackcode``;
val expected_oracle=``^lo = backendProps$pure_co
 (stack_to_lab$compile_no_stubs ^aw (^cfg).stack_conf.reg_names (^cfg).stack_conf.jump
 (^ac).addr_offset ^stk o FST) o ^so``;
val expected_premises=``
 stack_to_labProof$memory_assumption (^cfg).stack_conf.reg_names ^bitmaps data_sp ^lab /\
 ~((^lab).link_reg IN save_regs) /\
 (!k i n.k IN save_regs ==> (^lab).io_regs n i k=NONE) /\
 (!k n.k IN save_regs ==> (^lab).cc_regs n k=NONE) /\
 (!x.x IN dm ==> w2n(x:64 word) MOD 8=0) /\
 (!x.x IN sdm ==> w2n(x:64 word) MOD 8=0) /\
 stack_to_labProof$good_code ^stk ^stackcode /\
 (!n.stack_to_labProof$good_code ^stk (FST(SND(^so n)))) /\
 find_name (^cfg).stack_conf.reg_names ^stk IN save_regs /\
 find_name (^cfg).stack_conf.reg_names (3+^stk-2) IN save_regs /\
 find_name (^cfg).stack_conf.reg_names (4+^stk-2) IN save_regs /\
 find_name (^cfg).stack_conf.reg_names 4=(^lab).len2_reg /\
 find_name (^cfg).stack_conf.reg_names 3=(^lab).ptr2_reg /\
 find_name (^cfg).stack_conf.reg_names 2=(^lab).len_reg /\
 find_name (^cfg).stack_conf.reg_names 1=(^lab).ptr_reg /\
 find_name (^cfg).stack_conf.reg_names 0=(^lab).link_reg /\
 find_name (^cfg).stack_conf.reg_names PERMUTES UNIV``;
val expected_conclusion=``SND ^initial<>NONE /\
 (stackSem$semantics bvl_to_bvi$InitGlobals_location (FST ^initial)<>Fail ==>
 labSem$semantics ^lab=stackSem$semantics bvl_to_bvi$InitGlobals_location (FST ^initial))``;
val ps=strip_conj expected_premises;
val _=if length ps=17 then () else raise Fail "Expected premise specification has wrong count";
val indexed=ListPair.zip(List.tabulate(length ps,fn i=>i),ps);
val static_ps=map snd(List.filter(fn(i,_)=>i<>7 andalso i<>16)indexed);
val expected_static=mk_imp(list_mk_conj static_ps,expected_conclusion);
val expected_config=``backendProof$backend_config_ok ^ac ^cfg``;
val expected_names=``find_name (^cfg).stack_conf.reg_names PERMUTES UNIV``;
val expected_future=``!n.stack_to_labProof$good_code ^stk (FST(SND(^so n)))``;
val _=Globals.max_print_depth:=1000;
fun assumptions name th=let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM")ors then ()
 else raise Fail("Unexpected assumptions: "^name)end;
val basic=[LET_THM,LAMBDA_PROD,lab_to_targetProofTheory.make_init_def,refund_lab_oracle];
fun norm t=rhs(concl(QCONV(SIMP_CONV(srw_ss())basic)t));
fun exact name e th=(if aconv e(concl th) orelse aconv(norm e)(norm(concl th)) then () else
 (print("EXPECTED "^Parse.term_to_string(norm e)^"\nACTUAL "^Parse.term_to_string(norm(concl th))^"\n");
 raise Fail("Exact statement mismatch: "^name));
 assumptions name th;print("IMPORTED "^name^" EXACT_OR_KERNEL_NORMALIZED true HYPOTHESES 0 TAGGED_AXIOMS 0\n"));
fun contract name count e th=let
 val(ep,ec)=dest_imp(norm e);val(ap,actualc)=dest_imp(norm(concl th))
 val _=if length(strip_conj ep)=count andalso length(strip_conj ap)=count then () else raise Fail("Wrong complete premise count: "^name)
 val _=if aconv ec actualc then () else raise Fail("Exact conclusion mismatch: "^name)
 val eq=prove(mk_eq(ap,ep),EQ_TAC >> strip_tac >> fs basic)
 val _=assumptions name th
 in print("IMPORTED "^name^" KERNEL_NORMALIZED_CONCLUSION true KERNEL_PREMISES_EQUIVALENT true HYPOTHESES 0 TAGGED_AXIOMS 0\n")end;
val _=exact "refund_lab_code" expected_code refund_lab_code;
val _=exact "refund_lab_oracle" expected_oracle refund_lab_oracle;
val _=contract "refund_initialization_sufficient" 17 (mk_imp(expected_premises,expected_conclusion)) refund_initialization_sufficient;
val _=exact "refund_config_ok" expected_config refund_config_ok;
val _=exact "refund_name_permutation" expected_names refund_name_permutation;
val _=exact "refund_stack_oracle_good" expected_future refund_stack_oracle_good;
val _=contract "refund_initialization_static" 15 expected_static refund_initialization_static;
val _=if length(DB.theorems "forge_refundSuccessfulInitialization")=3 andalso
 length(DB.theorems "forge_refundInitializationStatic")=4 then () else raise Fail "Unexpected theorem count";
val closure=Lib.mk_set("forge_refundInitializationStatic"::Theory.ancestry "forge_refundInitializationStatic");
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n"))closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n))closure;
val _=print "TRACE_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;
