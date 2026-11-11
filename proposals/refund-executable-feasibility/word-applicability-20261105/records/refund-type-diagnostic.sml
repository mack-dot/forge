open preamble forge_refundWordPremisesTheory;
val _=new_theory "forge_refundClaimImport";
val contract = ``stdin_content fs = SOME(explode(sexp_to_string
 (refund_request charge request original remaining enabled opened candidate amount reason))) /\
 wfcl cl /\ wfFS fs /\ STD_streams fs``;
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
 |> Q.GEN `t` |> ISPEC ``(t:(64,num # lab_to_target$config,mlstring list # IO_fs)wordSem$state)
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
 val (ap,ac)=dest_imp(concl th);val(ep,ec)=dest_imp expected;
 fun show tag tm=List.app(fn v=>print(tag^" "^Parse.term_to_string v^":"^Parse.type_to_string(type_of v)^"\n"))(free_vars tm);
 in print("CLAIM "^name^"\n");show "ACTUAL" ac;show "EXPECTED" ec;
 (case total (match_term ac) ec of NONE=>print "MATCH NONE\n" | SOME(ts,tys)=>
 (List.app(fn{redex,residue}=>print("TERM_SUB "^Parse.term_to_string redex^" -> "^Parse.term_to_string residue^"\n"))ts;
 List.app(fn{redex,residue}=>print("TYPE_SUB "^Parse.type_to_string redex^" -> "^Parse.type_to_string residue^"\n"))tys)) end) checks;
val _=print "RUNTIME_PROOF_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;
