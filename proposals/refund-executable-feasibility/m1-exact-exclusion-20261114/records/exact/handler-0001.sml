(* The installer handler does not matter for the exclusion: two configurations that differ only in
   install_interfer have the same run while the installer entry is not reached. *)
open preamble targetSemTheory targetPropsTheory forge_targetInstallPrefixTheory forge_simRootTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_installHandlerIrrelevant";
val ev_suc = evaluate_def |> Q.SPECL [`c`,`io`,`SUC n`,`ms`] |> SIMP_RULE (srw_ss()) [apply_oracle_def] |> GEN_ALL;
val ev0 = Q.prove(`targetSem$evaluate c io 0 ms = (TimeOut,ms,io)`, simp[Once evaluate_def]);
val same_def = Define `same_but_install mc mc2 <=> ?h. mc2 = mc with install_interfer := h`;
val run_goal = ``!k mc mc2 ffi ms.
   same_but_install mc mc2 /\
   (!j ms' ffi'. j < k /\ targetSem$evaluate mc2 ffi j ms = (TimeOut,ms',ffi') ==> mc.target.get_pc ms' <> mc.install_pc) ==>
   targetSem$evaluate mc ffi k ms = targetSem$evaluate mc2 ffi k ms``;
val rec_tac =
  qmatch_goalsub_abbrev_tac `targetSem$evaluate mcA ffiA k msA = targetSem$evaluate mcB _ _ _` >>
  first_x_assum (qspecl_then [`mcA`,`mcB`,`ffiA`,`msA`] mp_tac) >>
  impl_tac
  >- (conj_tac
      >- (simp[Abbr `mcA`, Abbr `mcB`, same_def] >> qexists_tac `h` >> simp[])
      >- (unabbrev_all_tac >> rpt gen_tac >> strip_tac >> qpat_x_assum `!j ms' ffi'. _` (qspec_then `SUC j` mp_tac) >> simp[ev_suc] >>
          TRY (disch_then drule >> simp[])))
  >> simp[];
val run_tac =
  Induct >- simp[ev0] >>
  rpt strip_tac >>
  `mc.target.get_pc ms <> mc.install_pc` by (first_x_assum (qspecl_then [`0`,`ms`,`ffi`] mp_tac) >> simp[ev0]) >>
  fs[same_def] >> rveq >>
  ONCE_REWRITE_TAC [ev_suc] >> simp[] >>
  rpt (TOP_CASE_TAC >> gvs[]) >> rec_tac;
val run_thm = store_thm ("evaluate_same_but_install", run_goal, run_tac);
val nip_goal = ``same_but_install mc mc2 /\ (!n. no_install_prefix mc2 ffi n ms) ==>
   (!n. no_install_prefix mc ffi n ms) /\ (!k. targetSem$evaluate mc ffi k ms = targetSem$evaluate mc2 ffi k ms)``;
val nip_thm = store_thm ("no_install_prefix_same_but_install", nip_goal,
  strip_tac >>
  `!k. targetSem$evaluate mc ffi k ms = targetSem$evaluate mc2 ffi k ms` by
     (gen_tac >> irule run_thm >> simp[] >> rpt strip_tac >> fs[no_install_prefix_def, same_def] >> rveq >>
      first_x_assum (qspecl_then [`j`,`j`,`ms'`,`ffi'`] mp_tac) >> simp[]) >>
  simp[] >> fs[no_install_prefix_def, same_def] >> rveq >> fs[] >> metis_tac[]);
val _ = List.app (fn (n, th) => (tags n th; pr ("CHECKED " ^ n ^ "\n" ^ thm_to_string th)))
  [("evaluate_same_but_install", run_thm), ("no_install_prefix_same_but_install", nip_thm)];
(* Negative control: when the installer entry IS reached, the handler matters. *)
val toy3_def = Define `forge_toy_mc3 = forge_toy_mc with install_interfer := (\k x. 3)`;
val control = (SOME (prove (``same_but_install forge_toy_mc forge_toy_mc3 /\
     targetSem$evaluate forge_toy_mc (io:'ffi ffi_state) 3 0 <> targetSem$evaluate forge_toy_mc3 io 3 0``,
   conj_tac >- (simp[same_def, toy3_def] >> metis_tac[]) >>
   rewrite_tac [DECIDE ``3 = SUC (SUC (SUC 0))``] >>
   simp[ev_suc, toy3_def, forge_toy_mc_def, encoded_bytes_in_mem_def, bytes_in_memory_def,
        read_ffi_bytearray_def, read_bytearray_def, ev0, find_index_def]))) handle _ => NONE;
val _ = case control of
    SOME th => (tags "handler_matters_when_installer_reached" th; save_thm ("handler_matters_when_installer_reached", th);
                pr ("CHECKED handler_matters_when_installer_reached\n" ^ thm_to_string th))
  | NONE => pr "CONTROL_NOT_PROVED handler_matters_when_installer_reached";
val _ = export_theory ();
val _ = pr "EXACT_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
