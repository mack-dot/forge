open preamble;
open forge_refundRejectDirectTheory forge_refundWholeProgTheory
     forge_refundStdioProgTheory forge_refundWireProgTheory cfMainTheory
     semanticPrimitivesTheory ml_translatorTheory ml_progTheory cfHeapsTheory
     cfTheory cfAppTheory evaluatePropsTheory evaluateTheory evaluate_decTheory
     namespaceTheory cfHeapsBaseTheory semanticsTheory;
val _ = Globals.max_print_depth := 1000;
open proofManagerLib;
val _ = g (``
  evaluate_dec_list (st with clock := ck1) env prog = (s1,r1) ∧
  r1 ≠ Rerr (Rabort Rtimeout_error) ∧
  evaluate_dec_list (st with clock := ck2) env prog = (s2,r2) ∧
  r2 ≠ Rerr (Rabort Rtimeout_error) ⇒
  s1.ffi = s2.ffi ∧ r1 = r2``);
val _ = e (  strip_tac
  \\ qspecl_then [‘st with clock := ck1’,‘env’,‘prog’,‘s1’,‘r1’,‘ck2’]
       mp_tac evaluate_dec_list_add_to_clock
  \\ qspecl_then [‘st with clock := ck2’,‘env’,‘prog’,‘s2’,‘r2’,‘ck1’]
       mp_tac evaluate_dec_list_add_to_clock
  \\ simp [] \\ rpt strip_tac
  \\ gvs [AC arithmeticTheory.ADD_COMM arithmeticTheory.ADD_ASSOC,
          state_component_equality]);
val _ = List.app (fn (hs,tm) =>
 (List.app (fn h => print ("DIAG_HYP " ^ Parse.term_to_string h ^ "\n")) hs;
  print ("DIAG_GOAL " ^ Parse.term_to_string tm ^ "\n"))) (top_goals ());
val _ = print ("UNQUALIFIED_STATE_EQUALITY " ^ Parse.thm_to_string state_component_equality ^ "\n");
val _ = print ("SEMANTIC_PRIMITIVE_STATE_EQUALITY " ^ Parse.thm_to_string semanticPrimitivesTheory.state_component_equality ^ "\n");
val _ = print "DIAGNOSTIC_COMPLETE\n";
val _ = OS.Process.exit OS.Process.success;
