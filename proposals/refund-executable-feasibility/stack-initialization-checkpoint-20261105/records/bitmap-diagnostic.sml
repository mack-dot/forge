load "forge_refundArm8ProofTheory";
open preamble backendProofTheory;
val _=Globals.max_print_depth:=1000;
val _=Globals.show_types:=true;
val ac=``arm8_target$arm8_config``;
val bitmap_map=backendProofTheory.MAP_upper_n2w_eq_upper_w2w
 |> INST_TYPE[alpha|->``:64``] |> SPEC_ALL |> Q.INST[`asm_conf`|->`^ac`]
 |> SIMP_RULE(srw_ss())[EVAL ``isa_bits ^ac``];
val target=``MAP wordSem$upper_w2w (MAP n2w ns:64 word list) =
 MAP(backend_common$upper_n2w (arch_wordsize (^ac).ISA)) ns``;
val result=QCONV(SIMP_CONV(srw_ss())[bitmap_map])target;
val _=print("GENERIC "^Parse.thm_to_string backendProofTheory.MAP_upper_n2w_eq_upper_w2w^"\nSPECIALIZED "^Parse.thm_to_string bitmap_map^"\nTARGET "^Parse.term_to_string target^"\nNORMALIZED "^Parse.thm_to_string result^"\n");
val _=print "BITMAP_DIAGNOSTIC_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;
