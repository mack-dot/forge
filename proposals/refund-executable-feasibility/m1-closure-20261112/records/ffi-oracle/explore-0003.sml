(* Exploration only: does the published basis file-system oracle satisfy the
   oracle equation of read_error_generic for an invalid descriptor?
   It stores no theorem and exports no theory. *)
val _ = load "cfLib";
open preamble cfLib cfTheory cfHeapsBaseTheory set_sepTheory
  TextIOProofTheory TextIOProgTheory MarshallingTheory ml_translatorTheory
  fsFFITheory fsFFIPropsTheory forge_refundGenericReadErrorTheory;
open proofManagerLib;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_READ_OUT"));
val _ = new_theory "forge_refundFfiOracleExplore";
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
fun pr s = print (s ^ "\n");
val _ = pr ("FS_FFI_PART_DEF\n" ^ thm_to_string fs_ffi_part_def);
val _ = pr ("MK_FFI_NEXT_DEF\n" ^ thm_to_string mk_ffi_next_def);
val _ = pr ("FFI_READ_DEF\n" ^ thm_to_string ffi_read_def);
val _ = pr ("W22N_N2W2\n" ^ thm_to_string w22n_n2w2);
val _ = pr ("W82N_N2W8\n" ^ thm_to_string w82n_n2w8);
val _ = pr ("DECODE_ENCODE\n" ^ thm_to_string fsFFITheory.decode_encode);
fun goals_now () = (top_goals ()) handle _ => [];
fun proved () = ((top_thm (); true) handle _ => false);
fun show label =
  (pr ("STATE " ^ label ^ " goals=" ^ Int.toString (length (goals_now ())));
   case goals_now () of
     [] => pr "NO_OPEN_GOAL"
   | (asms,gl)::_ =>
       (List.app (fn t => pr ("ASSUMPTION " ^ term_to_string t)) asms;
        pr ("GOAL " ^ term_to_string gl); pr "END_GOAL"));
fun step label mk =
  ((e (mk ()); pr ("STEP_OK " ^ label); show label; true)
   handle ex => (pr ("STEP_FAIL " ^ label ^ " :: " ^ exn_to_string ex); false));
val _ = g `
  fd < 256 ** 8 /\ n < 2 ** (2 * 8) /\ n <= LENGTH rest /\ read fd fs n = NONE ==>
  mk_ffi_next fs_ffi_part «read» (n2w8 fd) (n2w2 n ++ h3::h4::rest) (encode fs) =
  SOME (FFIreturn (1w::n2w n::h3::h4::rest) (encode fs))`;
val _ = step "strip" (fn () => strip_tac);
val _ = step "w22n" (fn () => imp_res_tac w22n_n2w2);
val _ = step "unfold" (fn () => simp [fs_ffi_part_def, mk_ffi_next_def, ffi_read_def, fsFFITheory.decode_encode,
                                     w82n_n2w8, LENGTH_n2w8, n2w2_def, LUPDATE_def]);
val _ = if proved () then true else step "fs" (fn () => fs [n2w2_def, w22n_def, LUPDATE_def, w82n_n2w8, LENGTH_n2w8]);
val _ = if proved () then true else step "rfs" (fn () => rfs [n2w2_def, LUPDATE_def]);
val _ = pr ("FINAL proved=" ^ Bool.toString (proved ()));
val _ = pr "EXPLORE_COMPLETE";
val _ = OS.Process.exit OS.Process.success;
