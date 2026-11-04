Theory forge_native_corpus
Ancestors
  forge_refund_call mlstring
Libs
  preamble

Theorem native_case_eligible_return:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv T; Litv (IntLit (40)); Litv (StrLit (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109]))); Litv (StrLit (strlit (MAP CHR [99;104;97;114;103;101;45;49]))); Litv (StrLit (strlit (MAP CHR [114;101;113;117;101;115;116;45;49]))); Litv (IntLit (1))]
Proof
  EVAL_TAC
QED

Theorem native_case_eligible_duplicate:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T T T (40) (strlit (MAP CHR [100;117;112;108;105;99;97;116;101;95;99;104;97;114;103;101])) =
    Conv NONE [Boolv T; Litv (IntLit (40)); Litv (StrLit (strlit (MAP CHR [100;117;112;108;105;99;97;116;101;95;99;104;97;114;103;101]))); Litv (StrLit (strlit (MAP CHR [99;104;97;114;103;101;45;49]))); Litv (StrLit (strlit (MAP CHR [114;101;113;117;101;115;116;45;49]))); Litv (IntLit (1))]
Proof
  EVAL_TAC
QED

Theorem native_case_eligible_service:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T T T (40) (strlit (MAP CHR [115;101;114;118;105;99;101;95;110;111;116;95;100;101;108;105;118;101;114;101;100])) =
    Conv NONE [Boolv T; Litv (IntLit (40)); Litv (StrLit (strlit (MAP CHR [115;101;114;118;105;99;101;95;110;111;116;95;100;101;108;105;118;101;114;101;100]))); Litv (StrLit (strlit (MAP CHR [99;104;97;114;103;101;45;49]))); Litv (StrLit (strlit (MAP CHR [114;101;113;117;101;115;116;45;49]))); Litv (IntLit (1))]
Proof
  EVAL_TAC
QED

Theorem native_case_eligible_zero:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T T T (0) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv T; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109]))); Litv (StrLit (strlit (MAP CHR [99;104;97;114;103;101;45;49]))); Litv (StrLit (strlit (MAP CHR [114;101;113;117;101;115;116;45;49]))); Litv (IntLit (1))]
Proof
  EVAL_TAC
QED

Theorem native_case_eligible_maximum:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (9223372036854775807) (9223372036854775807) T T T (9223372036854775807) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv T; Litv (IntLit (9223372036854775807)); Litv (StrLit (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109]))); Litv (StrLit (strlit (MAP CHR [99;104;97;114;103;101;45;49]))); Litv (StrLit (strlit (MAP CHR [114;101;113;117;101;115;116;45;49]))); Litv (IntLit (1))]
Proof
  EVAL_TAC
QED

Theorem native_case_unicode_ids:
  refund_expected_tuple (strlit (MAP CHR [196;128])) (strlit (MAP CHR [244;143;191;191])) (100) (60) T T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv T; Litv (IntLit (40)); Litv (StrLit (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109]))); Litv (StrLit (strlit (MAP CHR [196;128]))); Litv (StrLit (strlit (MAP CHR [244;143;191;191]))); Litv (IntLit (1))]
Proof
  EVAL_TAC
QED

Theorem native_case_nul_id:
  refund_expected_tuple (strlit (MAP CHR [0])) (strlit (MAP CHR [114;101;113;117;101;115;116;0;116;97;105;108])) (100) (60) T T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv T; Litv (IntLit (40)); Litv (StrLit (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109]))); Litv (StrLit (strlit (MAP CHR [0]))); Litv (StrLit (strlit (MAP CHR [114;101;113;117;101;115;116;0;116;97;105;108]))); Litv (IntLit (1))]
Proof
  EVAL_TAC
QED

Theorem native_case_escaped_ids:
  refund_expected_tuple (strlit (MAP CHR [97;10;34;92;98])) (strlit (MAP CHR [9;40;41;13])) (100) (60) T T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv T; Litv (IntLit (40)); Litv (StrLit (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109]))); Litv (StrLit (strlit (MAP CHR [97;10;34;92;98]))); Litv (StrLit (strlit (MAP CHR [9;40;41;13]))); Litv (IntLit (1))]
Proof
  EVAL_TAC
QED

Theorem native_case_empty_charge:
  refund_expected_tuple (strlit (MAP CHR [])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_empty_request:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [])) (100) (60) T T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_negative_amount:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T T T (~1) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_over_remaining:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T T T (61) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_original_over_money:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (9223372036854775808) (60) T T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_remaining_over_original:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (101) T T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_disabled:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) F T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_closed_request:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T F T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_noncandidate:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T T F (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_negative_remaining:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (~1) T T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_unapproved_reason:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T T T (40) (strlit (MAP CHR [111;116;104;101;114])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_reason_suffix:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109;0;101;118;105;108])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_unbounded_positive:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (100) (60) T T T (115792089237316195423570985008687907853269984665640564039457584007913129639936) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

Theorem native_case_unbounded_negative:
  refund_expected_tuple (strlit (MAP CHR [99;104;97;114;103;101;45;49])) (strlit (MAP CHR [114;101;113;117;101;115;116;45;49])) (~115792089237316195423570985008687907853269984665640564039457584007913129639936) (60) T T T (40) (strlit (MAP CHR [114;101;116;117;114;110;101;100;95;105;116;101;109])) =
    Conv NONE [Boolv F; Litv (IntLit (0)); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (StrLit (strlit (MAP CHR []))); Litv (IntLit (0))]
Proof
  EVAL_TAC
QED

val _ = List.app (fn (name,th) =>
  let val (oracles,axioms) = Tag.dest_tag (Thm.tag th) in
    print ("CORPUS_THEOREM " ^ name ^ "\n");
    print ("CORPUS_ORACLES " ^ String.concatWith "," oracles ^ "\n");
    print ("CORPUS_AXIOMS " ^ String.concatWith "," axioms ^ "\n");
    print ("CORPUS_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n")
  end) (Theory.current_theorems ());
