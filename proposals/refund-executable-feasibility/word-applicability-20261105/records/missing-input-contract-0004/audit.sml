open preamble forge_refundWordPremisesTheory;
val _=new_theory "forge_refundClaimImport";
val contract = ``wfcl cl /\ wfFS fs /\ STD_streams fs``;
val source_behavior = ``semantics$semantics_determ
 (ml_prog$init_state (basis_ffi$basis_ffi ext cl fs) with ptr_eq_oracle := po)
 ml_prog$init_env forge_refundWholeProg$refund_prog``;
val data_result = ``dataSem$semantics (basis_ffi$basis_ffi ext cl fs)
 (sptree$fromAList(SND(backend$to_data
   (backend$set_oracle arm8_config$arm8_backend_config oracle) forge_refundWholeProg$refund_prog)))
 (backendProof$cake_orac (:'a) arm8_target$arm8_config info syn
   (SND o SND o SND o SND o SND o backendProof$config_tuple2) (\ps. ps.data_prog))
 (backendProof$backend_from_data_tuple_cc (:'a) arm8_target$arm8_config
   (backend$set_oracle arm8_config$arm8_backend_config oracle)) po
 dataProps$zero_limits sptree$LN bvl_to_bvi$InitGlobals_location``;

val (data_head,data_args) = strip_comb data_result;
val data_general = list_mk_comb(data_head,List.take(data_args,5) @
 [``lims:dataSem$limits``,``frames:num sptree$num_map``,List.nth(data_args,7)]);
val data_zero_frames = list_mk_comb(data_head,List.take(data_args,6) @
 [``frames:num sptree$num_map``,List.nth(data_args,7)]);
val data64 = Term.inst [alpha |-> ``:64``] data_zero_frames;
val expected_nonfailure = ``^contract ==> ^data_general <> ffi$Fail``;
(* Reconstruct all remaining premises from the pinned public compiler theorem. *)
val public = data_to_wordProofTheory.compile_semantics
 |> Q.INST [`fs` |-> `frames`]
 |> Q.GEN `t` |> ISPEC ``(t:(64,num # lab_to_target$config,'ffi)wordSem$state)
     with ffi := basis_ffi$basis_ffi ext cl fs``
 |> PURE_REWRITE_RULE [wordSemTheory.state_accfupds,combinTheory.K_THM];
val (compiler_pre,compiler_post)=dest_imp(concl public);
val (space,word_space)=dest_imp(fst(dest_conj compiler_post));
val compiler_clauses=strip_conj compiler_pre;
val substitution=match_term (List.last compiler_clauses) ``ffi$Fail <> ^data64``;
fun instantiate tm = subst (fst substitution) (Term.inst (snd substitution) tm);
val state_and_start=snd(strip_comb word_space);
val word_state=List.nth(state_and_start,0);
val word_start=List.nth(state_and_start,1);
val trace_result=instantiate ``!k. LENGTH(wordProps$ptr_eq_trace
 (wordLang$Call NONE (SOME ^word_start) [0] NONE) (^word_state with clock := k)) = 1``;
val retained=map instantiate (strip_conj space @ List.take(compiler_clauses,length compiler_clauses-1));
val expected_trace=mk_imp(list_mk_conj(strip_conj contract @ retained),trace_result);
val checks=[("refund_data_nonfailure",expected_nonfailure,refund_data_nonfailure),
 ("refund_word_single_epoch",expected_trace,refund_word_single_epoch)];
val _=List.app(fn(name,expected,th)=>let
 val (ap,ac)=dest_imp(concl th); val(ep,ec)=dest_imp expected;
 val _=if aconv ac ec then () else raise Fail("Exact conclusion mismatch: "^name);
 (* HOL checks the equivalence; only conjunction order/duplicates may differ. *)
 val eq=prove(mk_eq(ap,ep),EQ_TAC >> strip_tac >> asm_simp_tac bool_ss [wordSemTheory.state_fupdcanon,markerTheory.Abbrev_def]);
 val (ors,axs)=Tag.dest_tag(Thm.tag th);
 val _=if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
       else raise Fail("Unexpected assumptions: "^name);
 in print("IMPORTED "^name^" EXACT_CONCLUSION true KERNEL_PREMISES_EQUIVALENT true HYPOTHESES 0 TAGGED_AXIOMS 0
") end) checks;
val _=if length(DB.theorems "forge_refundWordPremises")=2 then () else raise Fail "Unexpected theorem count";
val closure=Lib.mk_set("forge_refundWordPremises"::Theory.ancestry "forge_refundWordPremises");
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"
")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"
"))(DB.axioms n)) closure;
val _=print "CONFIG_IMPORT_COMPLETE
";
val _=OS.Process.exit OS.Process.success;
