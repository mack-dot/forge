(* Exploration only: why did the instance attempt of U351 end with
   "MATCH_MP_TAC: No match"?  It stores no theorem and exports no theory. *)
val _ = load "cfLib";
open preamble cfLib cfTheory cfHeapsBaseTheory set_sepTheory
  TextIOProofTheory TextIOProgTheory MarshallingTheory ml_translatorTheory
  fsFFITheory fsFFIPropsTheory forge_refundGenericReadErrorTheory forge_refundFfiOracleTheory;
open proofManagerLib;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_READ_OUT"));
val _ = new_theory "forge_refundFfiInstanceExplore";
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
val inst = Q.INST [`u` |-> `mk_ffi_next fs_ffi_part`, `s` |-> `encode fs`, `s'` |-> `encode fs`]
             forge_refundGenericReadErrorTheory.read_error_generic;
fun vars label t = List.app (fn v => pr (label ^ " " ^ fst (dest_var v) ^ " : " ^ type_to_string (type_of v)))
                     (Lib.sort (fn a => fn b => fst (dest_var a) <= fst (dest_var b)) (free_vars t));
(* 1. The goal term exactly as oracle-0001 built it: two separate parses. *)
val old_goal = mk_imp (``
  FD fd fdv /\ NUM n nv /\ n < 256**2 /\ MAX n 2048 <= LENGTH rest /\
  MEM «read» ns /\ ~MEM «» ns /\ read fd fs n = NONE``, snd (dest_imp (concl inst)));
val _ = vars "OLD_GOAL_VAR" old_goal;
(* 2. The intended statement as one quotation: every variable is parsed once. *)
val new_goal = ``
  FD fd fdv /\ NUM n nv /\ n < 256**2 /\ MAX n 2048 <= LENGTH rest /\
  MEM «read» ns /\ ~MEM «» ns /\ read fd fs n = NONE ==>
  app (p:'ffi ffi_proj) TextIO_read_v [fdv;nv]
    (W8ARRAY iobuff_loc (h1::h2::h3::h4::rest) *
     one (FFI_part (encode fs) (mk_ffi_next fs_ffi_part) ns events))
    (POSTe e.
      &InvalidFD_exn e * W8ARRAY iobuff_loc (1w::n2w n::h3::h4::rest) *
      one (FFI_part (encode fs) (mk_ffi_next fs_ffi_part) ns
        (events ++ [IO_event (ExtCall «read») (n2w8 fd)
          (ZIP (n2w2 n ++ h3::h4::rest,1w::n2w n::h3::h4::rest))])))``;
val _ = vars "NEW_GOAL_VAR" new_goal;
val _ = pr ("CONCLUSIONS_ACONV " ^ Bool.toString (aconv (snd (dest_imp old_goal)) (snd (dest_imp new_goal))));
val _ = pr ("GOALS_ACONV " ^ Bool.toString (aconv old_goal new_goal));
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun show label =
  (pr ("STATE " ^ label ^ " goals=" ^ Int.toString (length (goals_now ())));
   List.app (fn (asms,gl) => pr ("OPEN_GOAL " ^
     String.substring (term_to_string gl, 0, Int.min (300, size (term_to_string gl))))) (goals_now ()));
fun step label mk =
  ((e (mk ()); pr ("STEP_OK " ^ label); show label; true)
   handle ex => (pr ("STEP_FAIL " ^ label ^ " :: " ^ exn_to_string ex); false));
fun run tag goal =
 (pr ("SEQUENCE_BEGIN " ^ tag);
  set_goal ([], goal);
  step (tag ^ ":strip") (fn () => strip_tac);
  step (tag ^ ":match-inst") (fn () => match_mp_tac inst);
  step (tag ^ ":split-accept") (fn () => rpt conj_tac >> TRY (first_assum ACCEPT_TAC));
  step (tag ^ ":match-oracle") (fn () => match_mp_tac basis_read_error_oracle);
  (if proved () then true else step (tag ^ ":fs") (fn () => fs [FD_def]));
  pr ("SEQUENCE_END " ^ tag ^ " proved=" ^ Bool.toString (proved ())));
val _ = run "old" old_goal;
val _ = run "new" new_goal;
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
