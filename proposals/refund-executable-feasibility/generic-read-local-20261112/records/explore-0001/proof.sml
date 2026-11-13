(* Step-by-step exploration of the unchanged read_error_generic statement.
   It uses the goal manager and stores no theorem. It is not a proof attempt
   by store_thm and exports no theory. *)
val _ = load "cfLib";
open preamble cfLib cfTheory cfHeapsBaseTheory set_sepTheory
  TextIOProofTheory TextIOProgTheory MarshallingTheory ml_translatorTheory;
open proofManagerLib;
val _ = OS.FileSys.chDir (valOf (OS.Process.getEnv "FORGE_READ_OUT"));
val _ = Globals.max_print_depth := 1000;
val _ = show_assums := true;
val _ = new_theory "forge_refundGenericReadExplore";

fun goals_now () = (top_goals ()) handle _ => [];
fun ngoals () = length (goals_now ());
fun show label =
  (print ("STATE " ^ label ^ " goals=" ^ Int.toString (ngoals ()) ^ "\n");
   case goals_now () of
     [] => print "NO_OPEN_GOAL\n"
   | (asms,gl)::_ =>
       (List.app (fn t => print ("ASSUMPTION " ^ term_to_string t ^ "\n")) asms;
        print ("GOAL " ^ term_to_string gl ^ "\nEND_GOAL\n")));
fun step label tac =
  ((e tac; print ("STEP_OK " ^ label ^ "\n"); show label; true)
   handle ex => (print ("STEP_FAIL " ^ label ^ " :: " ^ exn_to_string ex ^ "\n"); false));

val _ = g `
  FD fd fdv ∧ NUM n nv ∧ n < 256**2 ∧ MAX n 2048 <= LENGTH rest ∧
  MEM «read» ns ∧ ¬MEM «» ns ∧
  u «read» (n2w8 fd) (n2w2 n ++ h3::h4::rest) s =
    SOME (FFIreturn (1w::n2w n::h3::h4::rest) s') ⇒
  app (p:'ffi ffi_proj) TextIO_read_v [fdv;nv]
    (W8ARRAY iobuff_loc (h1::h2::h3::h4::rest) *
     one (FFI_part s u ns events))
    (POSTe e.
      &InvalidFD_exn e * W8ARRAY iobuff_loc (1w::n2w n::h3::h4::rest) *
      one (FFI_part s' u ns
        (events ++ [IO_event (ExtCall «read») (n2w8 fd)
          (ZIP (n2w2 n ++ h3::h4::rest,1w::n2w n::h3::h4::rest))])))`;

val _ = step "strip-xcf" (rpt strip_tac >> xcf_with_def TextIO_read_v_def);
val _ = step "xlet-n2w2" (xlet_auto >- xsimpl);
val _ = step "simp-insert" (simp [insert_atI_def,n2w2_def]);
val _ = step "xlet-ffi" (xlet `POSTv v.
    W8ARRAY iobuff_loc (1w::n2w n::h3::h4::rest) *
    one (FFI_part s' u ns
      (events ++ [IO_event (ExtCall «read») (n2w8 fd)
        (ZIP (n2w2 n ++ h3::h4::rest,1w::n2w n::h3::h4::rest))]))`);
val base = ngoals ();
val _ = print ("BASE_GOALS " ^ Int.toString base ^ "\n");
val _ = step "xffi" xffi;
val _ = step "xsimpl" xsimpl;
(* Witness order follows the published read_spec proof. *)
val _ = step "witnesses" (CONV_TAC (RESORT_EXISTS_CONV List.rev) >>
                          map_every qexists_tac [`events`,`ns`,`u`,`s`]);
val _ = if ngoals () >= base then step "xsimpl-frame" xsimpl else true;
val _ = if ngoals () >= base then step "conf" (qexists_tac `n2w8 fd`) else true;
val _ = if ngoals () >= base then step "fs-defs" (fs [FD_def,STRING_TYPE_def,n2w2_def]) else true;
val _ = if ngoals () >= base then step "xsimpl-final" xsimpl else true;
val _ = if ngoals () >= base then step "fallback-conj-xsimpl" (rpt conj_tac >> xsimpl) else true;
val ffi_closed = (ngoals () = base - 1);
val _ = print ("FFI_BRANCH_CLOSED " ^ Bool.toString ffi_closed ^ "\n");
val _ = if ffi_closed then () else
  ((r (ngoals () - 1); print "ROTATED_TO_REST\n"; show "rotated")
   handle ex => print ("ROTATE_FAIL " ^ exn_to_string ex ^ "\n"));

val _ = step "xlets" (rpt (xlet_auto >- xsimpl));
val _ = step "xif" xif;
val _ = step "instantiate" instantiate;
val con_ok = step "xlet-con" (xlet_auto >- (xcon >> xsimpl >> instantiate >> xsimpl));
val _ = if con_ok then true else
  (step "xlet-con-open" xlet_auto; step "xcon" xcon; step "xcon-xsimpl" xsimpl;
   step "xcon-instantiate" instantiate; step "xcon-xsimpl2" xsimpl);
val _ = step "xraise" xraise;
val _ = step "fs-exn" (fs [InvalidFD_exn_def]);
val _ = if ngoals () > 0 then step "xsimpl-end" xsimpl else true;

val _ = print ("FINAL goals=" ^ Int.toString (ngoals ()) ^ "\n");
val _ = (let val th = top_thm () in
           print ("EXPLORE_PROVED\n" ^ thm_to_string th ^ "\n") end)
        handle ex => print ("EXPLORE_NOT_PROVED " ^ exn_to_string ex ^ "\n");
val _ = print "EXPLORE_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
