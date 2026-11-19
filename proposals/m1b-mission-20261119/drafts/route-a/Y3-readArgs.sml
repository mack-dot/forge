(* DRAFT. NOT RUN. Worker Y3, 2026-11-19. Theory forge_refundReadArgs (proposed name).
   The read analogue of U400 (forge_refundWriteArgs, args-0006): a RETURNING read call of the basis oracle
   whose answer has result byte 0 carries clen = 8 and the bound n + 4 <= alen.
   NOT proved here: failed read events (result byte 1); not word_msb x3; any fact about the real C code.
   Method copied from results/refund-write-args-local-20261116/attempt-0001/args-0006/proof.sml (same helper style).
   Names checked by reading proof.sml of args-0006 and callsite site-0005; NOT checked against a live HOL session.
   Parents (cached, stored): forge_refundCallSite (refund_static_def), forge_refundWriteArgs (write_call_arrays_are_the_register_arguments). *)
open preamble targetSemTheory ffiTheory fsFFITheory fsFFIPropsTheory basis_ffiTheory MarshallingTheory miscTheory
     arm8Theory arm8_targetTheory forge_refundCallSiteTheory forge_refundWriteArgsTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun show_tac tag (g as (asl, w)) = (pr ("SHOW " ^ tag);
   List.app (fn a => let val t = term_to_string a in pr ("  ASM " ^ String.substring (t, 0, Int.min (400, size t))) end) asl;
   pr ("  GOAL " ^ String.substring (term_to_string w, 0, Int.min (1500, size (term_to_string w)))); ALL_TAC g);
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_refundReadArgs";
val failed = ref ([] : string list);
fun chk name th = (tags name th; pr ("CHECKED " ^ name ^ "\n" ^ thm_to_string th));
(* No mk_thm fallback: a failed lemma returns TRUTH, so later lemmas that use it fail too; the run raises Fail before export. *)
fun thm name goal tac = (let val th = save_thm (name, Tactical.TAC_PROOF (([], goal), tac)) in chk name th; th end)
  handle e => (pr ("LEMMA_FAILED " ^ name ^ " " ^ General.exnMessage e); failed := name :: !failed; TRUTH);
val static_def = DB.fetch "forge_refundCallSite" "refund_static_def";
val RL = DB.fetch "forge_refundWriteArgs" "write_call_arrays_are_the_register_arguments";
val _ = pr ("USED " ^ thm_to_string RL);
val mcty = fst (dom_rng (type_of ``is_arm8_machine_config``));
val mc = mk_var ("mc", mcty); val mc1 = mk_var ("mc1", mcty);
val bty = type_of ``basis_ffi ext cl fs``;

(* ---- 1. The oracle: a read call that returns either failed silently or had valid arguments. ---- *)
val _ = pr "MARK R1";
val R1 = thm "ffi_read_return_cases"
  ``ffi_read c bytes fs = SOME (FFIreturn bytes' fs') ==>
    (bytes' = LUPDATE 1w 0 bytes /\ fs' = fs) \/
    (LENGTH c = 8 /\ ?n1 n0 p1 p2 tll rest. bytes = n1::n0::p1::p2::tll /\ bytes' = 0w :: rest /\
        w22n [n1; n0] + 4 <= LENGTH bytes)``
  (strip_tac >> Cases_on `bytes` >- fs [ffi_read_def] >> rename1 `h1::t1` >>
   Cases_on `t1` >- fs [ffi_read_def] >> rename1 `h1::h2::t2` >>
   Cases_on `t2` >- fs [ffi_read_def] >> rename1 `h1::h2::h3::t3` >>
   Cases_on `t3` >- fs [ffi_read_def] >> rename1 `h1::h2::h3::h4::t4` >>
   qpat_x_assum `ffi_read _ _ _ = _` mp_tac >> simp [ffi_read_def, OPTION_CHOICE_EQUALS_OPTION] >> strip_tac >> gvs [] >>
   rpt (pairarg_tac >> gvs []) >> gvs [AllCaseEqs(), LUPDATE_def] >> show_tac "R1");

(* ---- 2. The basis oracle on the name read. ---- *)
val _ = pr "MARK BR";
val BR = thm "basis_read_call_is_ffi_read"
  ``(ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\ call_FFI ffi1 (ExtCall «read») c ab = FFI_return ffi2 nb ==>
    ?fs'. ffi_read c ab (SND ffi1.ffi_state) = SOME (FFIreturn nb fs') /\ LENGTH nb = LENGTH ab``
  (strip_tac >> pop_assum mp_tac >> simp [call_FFI_def, basis_ffi_oracle_def] >>
   Cases_on `ffi1.ffi_state` >> simp [] >> rpt (CASE_TAC >> simp []) >> rpt strip_tac >> gvs [] >> show_tac "BR");
(* RISK: simp must decide ExtCall «read» <> ExtCall «write» (the first test of basis_ffi_oracle_def). If it does not,
   add mlstringTheory.strlit_11 / implode_def to the simp list. *)

(* ---- 3. The arrays and the registers, WITHOUT refund_static (slide-free premises). ---- *)
val regs = ``(^mc).target = arm8_target /\ mc.ptr_reg = 0 /\ mc.len_reg = 1 /\ mc.ptr2_reg = 2 /\ mc.len2_reg = 3``;
(* RL (stored) needs refund_static, which fixes the slide-0 PCs. RG copies the body of RL's proof without static_def. *)
val _ = pr "MARK RG";
val RG = thm "ffi_call_arrays_are_the_register_arguments_g"
  ``^regs /\ read_ffi_bytearrays mc (ms:arm8_state) = (SOME c, SOME ab) ==>
    LENGTH c = w2n (ms.REG 1w) /\ LENGTH ab = w2n (ms.REG 3w) /\
    (!n1 n0 o1 o0 tll. ab = n1::n0::o1::o0::tll ==>
        ms.MEM (ms.REG 2w) = n1 /\ ms.MEM (ms.REG 2w + 1w) = n0 /\ ms.MEM (ms.REG 2w + 2w) = o1 /\ ms.MEM (ms.REG 2w + 3w) = o0)``
  (simp [read_ffi_bytearrays_def, read_ffi_bytearray_def] >> strip_tac >> fs [arm8_target_def] >>
   imp_res_tac read_bytearray_LENGTH >> rpt conj_tac >> TRY (fs [] >> NO_TAC) >> rpt gen_tac >> strip_tac >> rveq >>
   imp_res_tac (DB.fetch "forge_refundWriteArgs" "read_bytearray_first_four") >> fs [arm8_target_def] >> rfs [] >> show_tac "RG");

(* ---- 4. The first theorem (X7's statement, exact) and its slide-free form. ---- *)
val ok_read = ``(ms1:arm8_state).REG 1w = 8w /\
    w22n [ms1.MEM (ms1.REG 2w); ms1.MEM (ms1.REG 2w + 1w)] + 4 <= w2n (ms1.REG 3w)``;
val _ = pr "MARK A0G";
val A0G = thm "successful_read_call_state_has_valid_arguments_g"
  ``^(subst [mc |-> mc1] regs) /\ (ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\
    read_ffi_bytearrays mc1 ms1 = (SOME c, SOME ab) /\
    call_FFI ffi1 (ExtCall «read») c ab = FFI_return ffi2 (0w :: rest) ==> ^ok_read``
  (strip_tac >> drule_all BR >> strip_tac >> drule_all RG >> strip_tac >> imp_res_tac R1
   >- (Cases_on `ab` >> fs [LUPDATE_def] >> show_tac "A0G-fail")
   >- (first_x_assum (qspecl_then [`n1`, `n0`, `p1`, `p2`, `tll`] mp_tac) >> (impl_tac >- asm_rewrite_tac []) >> strip_tac >>
       `ms1.REG 1w = 8w` by (rewrite_tac [GSYM w2n_11] >> fs [] >> show_tac "A0G-reg") >>
       rveq >> fs [] >> show_tac "A0G-ok"));
val _ = pr "MARK A0";
val A0 = thm "successful_read_call_state_has_valid_arguments"
  ``refund_static ^mc1 dm /\ (ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\
    read_ffi_bytearrays mc1 ms1 = (SOME c, SOME ab) /\
    call_FFI ffi1 (ExtCall «read») c ab = FFI_return ffi2 (0w :: rest) ==> ^ok_read``
  (strip_tac >> irule A0G >> fs [static_def] >> metis_tac []);
(* RISK: irule leaves existentials for ffi1/ext/c/ab/ffi2/rest; metis_tac must close them from the assumptions. *)

(* ---- 5. Negative controls. ---- *)
val _ = pr "MARK controls";
val KS = thm "wrong_clen_read_never_succeeds"
  ``LENGTH (c:word8 list) <> 8 /\ ffi_read c bytes fs = SOME (FFIreturn bytes' fs') ==> bytes' = LUPDATE 1w 0 bytes /\ fs' = fs``
  (strip_tac >> imp_res_tac R1 >> fs []);
val KB = thm "out_of_bounds_read_never_succeeds"
  ``LENGTH (bytes:word8 list) < w22n [n1; n0] + 4 /\ bytes = n1::n0::p1::p2::tll /\
    ffi_read c bytes fs = SOME (FFIreturn bytes' fs') ==> bytes' = LUPDATE 1w 0 bytes /\ fs' = fs``
  (strip_tac >> imp_res_tac R1 >> gvs []);
val KR = thm "short_array_read_is_rejected" ``LENGTH (bytes:word8 list) < 4 ==> ffi_read c bytes fs = NONE``
  (strip_tac >> simp [ffi_read_def] >> every_case_tac >> fs []);
(* The GAP, as a theorem: the model RETURNS at a call state at which the C code aborts (clen = 7). *)
val KG = thm "model_read_returns_where_c_aborts"
  ``ffi_read [0w;0w;0w;0w;0w;0w;0w] [0w;1w;0w;0w;0w] fs = SOME (FFIreturn [1w;1w;0w;0w;0w] fs)``
  (simp [ffi_read_def, LUPDATE_def]);
val KW = thm "wrong_clen_register_gives_no_successful_read"
  ``refund_static ^mc1 dm /\ (ffi1:^(ty_antiq bty)).oracle = basis_ffi_oracle ext /\ read_ffi_bytearrays mc1 ms1 = (SOME c, SOME ab) /\
    ms1.REG 1w <> 8w /\ call_FFI ffi1 (ExtCall «read») c ab = FFI_return ffi2 nb ==> !rest. nb <> 0w :: rest``
  (rpt strip_tac >> rveq >> drule_all A0 >> fs []);
(* Scope control: the conclusion does NOT contain word_msb (the signed bound is not claimed). *)
val _ = if can (find_term (fn t => is_const t andalso fst (dest_const t) = "word_msb")) (concl A0) then raise Fail "scope" else ();
val _ = if null (!failed) then () else raise Fail ("failed: " ^ String.concatWith " " (rev (!failed)));
val _ = List.app (fn (n, th) => tags n th) (DB.theorems "forge_refundReadArgs");
val closure = "forge_refundReadArgs" :: Theory.ancestry "forge_refundReadArgs";
val _ = pr ("STORED_THEOREMS " ^ Int.toString (length (DB.theorems "forge_refundReadArgs")));
val _ = List.app (fn n => List.app (fn (a,_) => pr ("CLOSURE_AXIOM " ^ n ^ "." ^ a)) (DB.axioms n)) closure;
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
