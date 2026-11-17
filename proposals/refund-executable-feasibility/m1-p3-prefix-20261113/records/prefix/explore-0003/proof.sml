load "targetPropsTheory";
open preamble targetSemTheory targetPropsTheory;
val _ = Globals.max_print_depth := 80;
fun pr s = print (s ^ "\n");
fun tags name th = let val (ors,axs) = Tag.dest_tag (Thm.tag th) in
  if null (hyp th) andalso null axs andalso List.all (fn x => x = "DISK_THM") ors then ()
  else raise Fail ("Unexpected assumptions: " ^ name ^ " oracles=" ^ String.concatWith "," ors) end;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_P3_OUT"));
val _ = new_theory "forge_p3Explore";
(* Every TimeOut prefix of the published target evaluator, up to clock n, has a program
   counter different from the installer entry. For all n this is the U298 exclusion. *)
val nip_def = Define `
  no_install_prefix mc ffi n ms <=>
    !j ms' ffi'. j <= n /\ targetSem$evaluate mc ffi j ms = (TimeOut,ms',ffi') ==>
                 mc.target.get_pc ms' <> mc.install_pc`;
val zero_goal = ``no_install_prefix mc ffi 0 ms <=> mc.target.get_pc ms <> mc.install_pc``;
val mono_goal = ``!n m. no_install_prefix mc ffi n ms /\ m <= n ==> no_install_prefix mc ffi m ms``;
val all_goal = ``(!n. no_install_prefix mc ffi n ms) <=>
   (!j ms' ffi'. targetSem$evaluate mc ffi j ms = (TimeOut,ms',ffi') ==> mc.target.get_pc ms' <> mc.install_pc)``;
val halt_goal = ``mc.target.get_pc ms = mc.halt_pc /\ mc.halt_pc NOTIN mc.prog_addresses /\ mc.halt_pc <> mc.install_pc ==>
   !n. no_install_prefix mc ffi n ms``;
val next_goal = ``mc.target.get_pc ms IN (mc.prog_addresses DIFF set mc.ffi_entry_pcs) /\
   encoded_bytes_in_mem mc.target.config (mc.target.get_pc ms) (mc.target.get_byte ms) mc.prog_addresses /\
   mc.install_pc NOTIN mc.prog_addresses ==>
   (no_install_prefix mc ffi (SUC n) ms <=>
      (EVERY mc.target.state_ok [ms; mc.target.next ms; mc.next_interfer 0 (mc.target.next ms)] /\
       (!x. x NOTIN mc.prog_addresses ==> mc.target.get_byte (mc.target.next ms) x = mc.target.get_byte ms x) ==>
       no_install_prefix (mc with next_interfer := shift_seq 1 mc.next_interfer) ffi n (mc.next_interfer 0 (mc.target.next ms))))``;
val segment_goal = ``(!k. targetSem$evaluate c io (k + l) ms1 = targetSem$evaluate c2 io2 k ms2) /\ c2.install_pc = c.install_pc /\ c2.target = c.target /\
   no_install_prefix c io l ms1 /\ no_install_prefix c2 io2 n ms2 ==> no_install_prefix c io (l + n) ms1``;
open proofManagerLib;
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun clip s = if size s > 1300 then String.substring (s, 0, 500) ^ "\n  ...\n" ^ String.substring (s, size s - 700, 700) else s;
fun goal_string (asl, w) = String.concatWith "\n" (map (fn a => "  ASM " ^ term_to_string a) asl) ^ "\n  GOAL " ^ term_to_string w;
fun show label = (pr ("AFTER " ^ label ^ ": " ^ Int.toString (length (goals_now ())) ^ " goals, proved=" ^ Bool.toString (proved ()));
                  List.app (fn gl => pr (clip (goal_string gl) ^ "\n----")) (List.take (goals_now (), Int.min (2, length (goals_now ())))));
(* Run stages in order on the top goal; stop at the first failure. Returns the theorem if proved. *)
fun run name goal stages =
  let val _ = (proofManagerLib.g `^goal`; ())
      fun go [] = ()
        | go ((label, tac) :: rest) =
            ((e tac; if proved () then pr ("STAGE_OK " ^ name ^ "/" ^ label ^ " (proved)") else (pr ("STAGE_OK " ^ name ^ "/" ^ label); go rest))
             handle ex => (pr ("STAGE_FAILED " ^ name ^ "/" ^ label ^ " :: " ^ exn_to_string ex); show (name ^ "/" ^ label)))
      val _ = go stages
  in if proved () then (pr ("LEMMA_PROVED " ^ name); SOME (top_thm ()))
     else (pr ("LEMMA_OPEN " ^ name); show (name ^ " end"); NONE) end;
val z = run "zero" zero_goal [("all", rw[nip_def, EQ_IMP_THM] >- (first_x_assum (qspecl_then [`ms`,`ffi`] mp_tac) >> simp[Once evaluate_def]) >>
     pop_assum mp_tac >> simp[Once evaluate_def] >> rw[] >> gvs[])];
val m = run "mono" mono_goal [("all", rw[nip_def] >> first_x_assum irule >> qexistsl_tac [`ffi'`,`j`] >> simp[])];
val a = run "all" all_goal [("all", rw[nip_def, EQ_IMP_THM] >> metis_tac[LESS_EQ_REFL])];
val hl = run "halt" halt_goal [("all", rw[nip_def] >> Cases_on `j` >> qpat_x_assum `evaluate _ _ _ _ = _` mp_tac >> simp[Once evaluate_def] >> rw[] >> gvs[])];
val next_tac =
  strip_tac >> simp[nip_def, EQ_IMP_THM] >> rpt strip_tac
  >- (`evaluate mc ffi (SUC j) ms = (TimeOut,ms',ffi')` by (simp[Once evaluate_def, apply_oracle_def] >> gvs[]) >>
      first_x_assum (qspecl_then [`SUC j`,`ms'`,`ffi'`] mp_tac) >> simp[])
  >- (Cases_on `j`
      >- (qpat_x_assum `evaluate _ _ _ _ = _` mp_tac >> simp[Once evaluate_def] >> strip_tac >> gvs[] >> metis_tac[])
      >- (qpat_x_assum `evaluate _ _ _ _ = _` mp_tac >> simp[Once evaluate_def, apply_oracle_def] >> gvs[] >>
          rw[] >> gvs[] >> res_tac >> gvs[]));
val nx = run "next" next_goal
  [("n1", strip_tac >> simp[nip_def, EQ_IMP_THM] >> rpt strip_tac),
   ("a1", `evaluate mc ffi (SUC j) ms = (TimeOut,ms',ffi')` by (simp[Once evaluate_def, apply_oracle_def] >> gvs[])),
   ("a2", first_x_assum (qspecl_then [`SUC j`,`ms'`,`ffi'`] mp_tac) >> simp[]),
   ("b1", Cases_on `j`),
   ("b2", qpat_x_assum `evaluate _ _ _ _ = _` mp_tac >> simp[Once evaluate_def] >> strip_tac >> gvs[] >> metis_tac[]),
   ("b3", qpat_x_assum `evaluate _ _ _ _ = _` mp_tac >> simp[Once evaluate_def, apply_oracle_def] >> gvs[]),
   ("b4", rw[] >> gvs[] >> res_tac >> gvs[])];
val sg = run "segment" segment_goal
  [("all", rw[nip_def] >> Cases_on `j <= l` >- metis_tac[] >>
           `?k. j = k + l /\ k <= n` by (qexists_tac `j - l` >> simp[]) >> gvs[] >> metis_tac[])];
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
