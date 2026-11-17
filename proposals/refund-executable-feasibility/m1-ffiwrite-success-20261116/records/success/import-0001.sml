(* U398: narrow import and control case for the successful-write path. Not a proof of anything new. *)
open preamble targetSemTheory arm8Theory arm8_targetTheory arm8_stepTheory alignmentTheory miscTheory
     forge_refundCmlMainStepTheory forge_refundImageTheory forge_refundFficloseStepTheory forge_refundCallSiteTheory
     forge_refundFfiwriteStepTheory forge_refundFfiwritePathTheory forge_refundFfiwriteComposeTheory forge_refundFfiwriteSiteTheory
     forge_refundFfiwriteUnalignedTheory forge_refundFfiwriteSuccessTheory forge_refundFfiwriteFaultTheory;
val _ = Globals.max_print_depth := 60;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
fun same a b = aconv a b;
fun has_const n tm = can (find_term (fn t => is_const t andalso fst (dest_const t) = n)) tm;
val s = ``s:arm8_state``; val s1 = ``s1:arm8_state``; val s2 = ``s2:arm8_state``; val s3 = ``s3:arm8_state``;
val b = ``b:word64``; val c = ``c:word64``; val a = ``a:word64``; val g = ``g:word64``; val dm = ``dm:word64 set``;
val regs = ``[19w;20w;21w;22w;23w;24w;25w;26w;27w;28w] : word5 list``;
val preT = ``ffiwrite_call_pre ^dm ^s ^b ^c ^a ^g``;
val failbit = ``word_bit 31 (w2w ((^s2).REG 0w) : word32)``;
val nA = ``~(^s2).SCTLR_EL1.A``;
val mem_ok = ``s3.MEM ^a = 0w /\ s3.MEM (^a + 1w) = (15 >< 8) ((^s2).REG 0w) /\ s3.MEM (^a + 2w) = (7 >< 0) ((^s2).REG 0w)``;
val common = ``s3.PC = s.REG 30w /\ s3.SP_EL0 = s.SP_EL0 /\ arm8_user s3 /\ (!r. MEM r ^regs ==> s3.REG r = s.REG r) /\
               (!q. q IN dm /\ q <> ^a /\ q <> a + 1w /\ q <> a + 2w ==> s3.MEM q = s.MEM q)``;
val concl_ok = mk_conj (common, mem_ok);
val prem = ``^preT /\ ffiwrite_at_call s b a g ^s1 /\ write_call_rel dm s1 ^s2 /\ ^nA /\ ~^failbit``;
val wpost = ``s3.PC = s.REG 30w /\ s3.SP_EL0 = s.SP_EL0 /\ arm8_user s3 /\ (!r. MEM r ^regs ==> s3.REG r = s.REG r) /\
              (!q. q IN dm ==> s3.MEM q = if q = (a:word64) then 1w else s.MEM q)``;
val bytes = ``s.MEM s.PC = 105w /\ s.MEM (s.PC + 1w) = 18w /\ s.MEM (s.PC + 2w) = 0w /\ s.MEM (s.PC + 3w) = 120w``;
val n = ref 0;
val _ = List.app (fn (thy, nm, tm) =>
  let val th = DB.fetch thy nm in
    if same tm (concl th) then () else (pr ("STORED " ^ nm ^ "\n" ^ thm_to_string th); raise Fail ("Exact statement mismatch: " ^ nm));
    tags nm th; n := !n + 1; pr ("IMPORTED " ^ thy ^ "." ^ nm ^ " EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0") end)
  [("forge_refundFfiwriteUnaligned", "check_alignment_no_fault",
      ``s.PSTATE.EL = 0w /\ ~s.SCTLR_EL1.A /\ acctype <> AccType_ATOMIC /\ acctype <> AccType_ORDERED ==>
        CheckAlignment (address:word64, n, acctype, iswrite) s = s``),
   ("forge_refundFfiwriteUnaligned", "check_alignment_fault",
      ``s.PSTATE.EL = 0w /\ s.SCTLR_EL1.A /\ ~aligned 1 (address:word64) /\ s.exception = NoException ==>
        CheckAlignment (address, 2, acctype, iswrite) s = s with exception := ALIGNMENT_FAULT``),
   ("forge_refundFfiwriteUnaligned", "sturh_w9_x19_1_step_no_alignment",
      ``s.exception = NoException /\ s.PSTATE.EL = 0w /\ ~s.SCTLR_EL1.E0E /\ ~s.SCTLR_EL1.A /\ aligned 2 s.PC /\ ^bytes ==>
        NextStateARM8 s = SOME (s with <| MEM := (s.REG 19w + 2w =+ (15 >< 8) (w2w (s.REG 9w) : word16))
                                                   ((s.REG 19w + 1w =+ (7 >< 0) (w2w (s.REG 9w) : word16)) s.MEM);
                                          PC := s.PC + 4w; branch_hint := NONE |>)``),
   ("forge_refundFfiwriteSuccess", "cake_ffiwrite_path_successful_write",
      ``^preT ==> ?s1. arm8_run 23 s = SOME s1 /\ s1.PC = g /\ s1.REG 30w = 0x10002522Cw /\
           !s2. write_call_rel dm s1 s2 /\ ^nA /\ ~^failbit ==> ?s3. arm8_run 10 s2 = SOME s3 /\ ^concl_ok``),
   ("forge_refundFfiwriteSuccess", "cake_ffiwrite_path_returns",
      ``^preT ==> ?s1. arm8_run 23 s = SOME s1 /\ s1.PC = g /\ s1.REG 30w = 0x10002522Cw /\
           !s2. write_call_rel dm s1 s2 /\ ^nA ==>
                ?n s3. arm8_run n s2 = SOME s3 /\ ^common /\
                       (if ^failbit then n = 6 /\ (a IN dm ==> s3.MEM a = 1w) else n = 10 /\ ^mem_ok)``),
   ("forge_refundFfiwriteSuccess", "write_success_result_bytes_exact", ``^prem /\ arm8_run 10 s2 = SOME ^s3 ==> ^mem_ok``),
   ("forge_refundFfiwriteSuccess", "write_return_to_wrong_address_not_in_relation",
      ``ffiwrite_at_call s b a g ^s1 /\ s2.PC <> 0x10002522Cw ==> ~write_call_rel ^dm s1 ^s2``),
   ("forge_refundFfiwriteSuccess", "write_result_bytes_in_image_not_covered",
      ``i < 3 /\ 0x100000000w <=+ ^a + n2w i /\ ^a + n2w i <+ 0x100030F30w ==> ~^preT``),
   ("forge_refundFfiwriteSuccess", "cake_ffiwrite_success_path_inhabited",
      ``?dm s b c a g s1 s2 s3. ffiwrite_call_pre dm s b c a g /\ arm8_run 23 s = SOME s1 /\ write_call_rel dm s1 s2 /\ ~s2.SCTLR_EL1.A /\
           ~word_bit 31 (w2w (s2.REG 0w) : word32) /\ arm8_run 10 s2 = SOME s3 /\ s3.MEM a = 0w /\ s3.MEM (a + 2w) = 5w``),
   ("forge_refundFfiwriteFault", "sturh_w9_x19_1_alignment_fault",
      ``aligned 2 s.PC /\ s.exception = NoException /\ s.PSTATE.EL = 0w /\ s.MEM (s.PC + 2w) = 0w /\ s.MEM (s.PC + 3w) = 120w /\
        s.MEM (s.PC + 1w) = 18w /\ s.MEM s.PC = 105w /\ ~aligned 1 (s.REG 19w + 1w) /\ ~s.SCTLR_EL1.E0E /\ s.SCTLR_EL1.A ==>
        NextStateARM8 s = NONE``),
   (* preserved from U397 *)
   ("forge_refundFfiwriteCompose", "cake_ffiwrite_path_failed_write", ``^preT ==>
        ?s1. arm8_run 23 s = SOME s1 /\ s1.PC = g /\ s1.REG 30w = 0x10002522Cw /\
             !s2. write_call_rel dm s1 s2 /\ ^failbit ==> ?s3. arm8_run 6 s2 = SOME s3 /\ ^wpost``),
   ("forge_refundFfiwritePath", "write_call_rel_def", ``!dm s1 s2. write_call_rel dm s1 s2 <=>
        arm8_user s2 /\ s2.PC = s1.REG 30w /\ s2.SP_EL0 = s1.SP_EL0 /\ (!r. MEM r ^regs ==> s2.REG r = s1.REG r) /\
        (!i. i < 32 ==> s2.MEM (s1.SP_EL0 + n2w i) = s1.MEM (s1.SP_EL0 + n2w i)) /\
        (!q. 0x100000000w <=+ q /\ q <+ 0x100030F30w ==> s2.MEM q = s1.MEM q) /\ (!q. q IN dm ==> s2.MEM q = s1.MEM q)``),
   ("forge_refundFfiwriteSite", "ffi_write_accepts_wrong_clen",
      ``ffi_write ([]:word8 list) [0w; 0w; 0w; 0w] fsys = SOME (FFIreturn [1w; 0w; 0w; 0w] fsys)``),
   ("forge_refundFfiwriteSite", "write_wrong_clen_not_covered", ``s.REG 1w <> 8w ==> ~ffiwrite_call_pre dm s b c a g``),
   ("forge_refundFfiwriteSite", "corrupted_return_state_not_in_write_relation",
      ``(s2.PC <> s1.REG 30w \/ s2.SP_EL0 <> s1.SP_EL0 \/ s2.REG 19w <> s1.REG 19w \/
         (?i. i < 32 /\ s2.MEM (s1.SP_EL0 + n2w i) <> s1.MEM (s1.SP_EL0 + n2w i))) ==> ~write_call_rel dm s1 s2``),
   ("forge_refundFfiwriteSite", "write_frame_in_protected_domain_not_covered", ``i < 32 /\ b + n2w i IN dm ==> ~ffiwrite_call_pre dm s b c a g``),
   ("forge_refundFfiwriteSite", "write_result_bytes_in_frame_not_covered", ``i < 3 /\ j < 32 /\ a + n2w i = b + n2w j ==> ~ffiwrite_call_pre dm s b c a g``),
   ("forge_refundFfiwriteStep", "ffiwrite_ok_alignment_conflict", ``~(aligned 1 (a:word64) /\ aligned 1 (a + 1w))``)];
val _ = pr ("IMPORTED_COUNT " ^ Int.toString (!n));
val u398 = ["forge_refundFfiwriteUnaligned", "forge_refundFfiwriteSuccess", "forge_refundFfiwriteFault"];
val _ = List.app (fn thy => (List.app (fn (nm, th) => tags (thy ^ "." ^ nm) th) (DB.theorems thy @ DB.definitions thy);
   pr ("STORED_THEOREMS " ^ thy ^ " " ^ Int.toString (length (DB.theorems thy)) ^ " STORED_DEFINITIONS " ^ Int.toString (length (DB.definitions thy)) ^
       " AXIOMS " ^ Int.toString (length (DB.axioms thy))))) u398;
val thms = List.concat (map DB.theorems u398);
fun f nm = concl (valOf (Option.map #2 (List.find (fn (m, _) => m = nm) thms)));
fun is_al1 t = (let val (c, args) = strip_comb t in fst (dest_const c) = "aligned" andalso aconv (hd args) ``1n`` end) handle _ => false;
val _ = if not (can (find_term is_al1) (f "sturh_w9_x19_1_step_no_alignment")) andalso
           not (can (find_term is_al1) (f "ffiwrite_suffix_ok_unaligned_run")) andalso
           not (can (find_term is_al1) (concl (DB.fetch "forge_refundFfiwriteUnaligned" "ffiwrite_return_ok_na_pre_def")))
        then pr "CONTROL_OK the new step theorem, the new suffix theorem and its pre-state carry no 2-byte alignment condition"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = if can (find_term (same ``aligned 1 (a:word64)``)) (concl (DB.fetch "forge_refundFfiwritePath" "ffiwrite_call_pre_def")) andalso
           same (fst (dest_imp (f "cake_ffiwrite_path_successful_write"))) preT
        then pr "CONTROL_OK the success theorem has the unchanged U397 call pre-state (aligned 1 a, so a + 1 is NOT 2-aligned) as its only premise"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = if can (find_term (same nA)) (f "cake_ffiwrite_path_successful_write") andalso can (find_term (same nA)) (f "cake_ffiwrite_path_returns")
        then pr "CONTROL_OK the SCTLR_EL1.A premise on the return state is explicit in both composed theorems"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val wrel = Lib.sort (fn x => fn y => x <= y) (map fst (List.filter (fn (_, th) => has_const "write_call_rel" (concl th)) thms));
val _ = pr ("WRITE_CALL_REL_OCCURS_IN " ^ String.concatWith " " wrel);
val _ = if List.all (fn (nm, th) => not (has_const "write_call_rel" (concl th)) orelse
             Lib.mem nm ["write_call_rel_inhabited_ok", "cake_ffiwrite_success_path_inhabited", "write_return_to_wrong_address_not_in_relation"] orelse
             is_imp (snd (strip_forall (concl th)))) thms
        then pr "CONTROL_OK write_call_rel occurs only under an implication, in a refutation, or with constructed inhabitants"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val _ = if not (List.exists (fn (_, th) => has_const "machine_reach" (concl th) orelse has_const "ffi_interfer_ok" (concl th) orelse
                  has_const "refund_ffi_contract" (concl th) orelse has_const "ffi_write" (concl th) orelse has_const "machine_sem" (concl th)) thms)
        then pr "CONTROL_OK no U398 theorem mentions machine_reach, machine_sem, ffi_interfer_ok, refund_ffi_contract or ffi_write: no reachability, contract or oracle claim"
        else pr "UNEXPECTED_CONTROL_ACCEPTANCE";
val closure = "forge_refundFfiwriteFault" :: "forge_refundFfiwriteSuccess" :: Theory.ancestry "forge_refundFfiwriteSuccess" @ Theory.ancestry "forge_refundFfiwriteFault";
val closure = Lib.mk_set closure;
val _ = pr ("CLOSURE_NODES " ^ Int.toString (length closure));
val _ = List.app (fn nd => List.app (fn (ax,_) => pr ("CLOSURE_AXIOM " ^ nd ^ "." ^ ax)) (DB.axioms nd)) closure;
val _ = pr "AFTER_POSITIVE_AUDIT";
val _ = pr "P3_IMPORT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
