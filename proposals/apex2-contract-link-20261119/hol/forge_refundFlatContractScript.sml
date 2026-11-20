(* APEX-2 (2026-11-19). The flat 6-field refund contract as ONE plain HOL
   formula over integers, booleans and lists of integers (byte codes), and
   the proof that it is exactly forge_refundCertifiedProg$refund_fields. (That it is also exactly
   the three exported ensures clauses: forge_refundFlatExportedScript.sml.)

   Purpose: the cross-tool boundary to Dafny then carries only a formula made
   of  /\  \/  ==>  <=>  ~  =  <=  integer literals and integer-list
   literals. No Dafny semantics in HOL, no export reader and no exporter is on
   that boundary. The formula is printed by `dafny_of_term` below into
   HolFlatGenerated.dfy. THAT PRINTING STEP IS NOT MACHINE-CHECKED: it is ML
   code outside the kernel. It is the named translation boundary of this
   package (see ../README.md).

   No axiom, no cheat, no mk_thm, no new_axiom, no oracle. The final check
   refuses any theorem with hypotheses, axiom tags or a tag other than DISK_THM. *)

open HolKernel boolLib bossLib Parse;
open preamble mlstringTheory integerTheory;
open forge_refundTheory forge_refundCertifiedProgTheory;

val _ = new_theory "forge_refundFlatContract";

fun prove (name, tm, tac) =
  (print ("FORGE_BEGIN " ^ name ^ "\n"); store_thm (name, tm, tac));

(* The byte codes of an mlstring, as integers. mlstring has 8-bit characters. *)
val codes_def = new_definition ("codes_def",
  ``codes (s:mlstring) = MAP (\c. (&(ORD c)):int) (explode s)``);

(* THE CONTRACT, plain. Argument order: the nine inputs in the order of the
   exported signature (chargeId, requestId, original, remaining, enabled,
   requestOpen, candidate, amount, reason), then the six outputs
   (authorized, outputAmount, outputReason, outputCharge, outputRequest,
   intentCount). 9223372036854775807 is MaxMoney. The three integer lists are
   the bytes of "duplicate_charge", "service_not_delivered", "returned_item". *)
val flat_plain_def = new_definition ("flat_plain_def", ``
  flat_plain (chargeId:int list) (requestId:int list) (original:int) (remaining:int)
      (enabled:bool) (requestOpen:bool) (candidate:bool) (amount:int) (reason:int list)
      (authorized:bool) (outputAmount:int) (outputReason:int list)
      (outputCharge:int list) (outputRequest:int list) (intentCount:int) <=>
    (authorized <=>
       ~(chargeId = []) /\ ~(requestId = []) /\ enabled /\ requestOpen /\
       0 <= original /\ original <= 9223372036854775807 /\
       0 <= remaining /\ remaining <= original /\ candidate /\
       0 <= amount /\ amount <= remaining /\
       (reason = [100; 117; 112; 108; 105; 99; 97; 116; 101; 95; 99; 104; 97; 114; 103; 101] \/
        reason = [115; 101; 114; 118; 105; 99; 101; 95; 110; 111; 116; 95; 100; 101; 108;
                  105; 118; 101; 114; 101; 100] \/
        reason = [114; 101; 116; 117; 114; 110; 101; 100; 95; 105; 116; 101; 109])) /\
    (authorized ==>
       outputAmount = amount /\ outputReason = reason /\ outputCharge = chargeId /\
       outputRequest = requestId /\ intentCount = 1) /\
    (~authorized ==>
       outputAmount = 0 /\ outputReason = [] /\ outputCharge = [] /\
       outputRequest = [] /\ intentCount = 0)``);

(* ---- The byte-code map is a bijection between mlstrings and lists of
        integers in 0..255. So "same codes" is "same string". ---- *)

val code_map_11 = prove ("code_map_11", ``
  !l1 l2. MAP (\c. (&(ORD c)):int) l1 = MAP (\c. &(ORD c)) l2 <=> l1 = l2``,
  Induct >> Cases_on `l2` >> rw [stringTheory.ORD_11]);

val codes_11 = prove ("codes_11", ``
  !s t. codes s = codes t <=> s = t``,
  rw [codes_def, code_map_11, mlstringTheory.explode_11]);

val codes_bytes = prove ("codes_bytes", ``
  !s. EVERY (\x. 0 <= x /\ x < 256) (codes s)``,
  simp [codes_def, EVERY_MAP] >> simp [EVERY_MEM, stringTheory.ORD_BOUND]);

val codes_onto = prove ("codes_onto", ``
  !l. EVERY (\x. 0 <= x /\ x < 256) l ==> ?s. codes s = l``,
  rw [codes_def] >>
  qexists_tac `implode (MAP (\x. CHR (Num x)) l)` >>
  simp [MAP_MAP_o, combinTheory.o_DEF] >>
  pop_assum mp_tac >> qid_spec_tac `l` >> Induct >> rw [] >>
  `Num h < 256` by intLib.ARITH_TAC >>
  simp [stringTheory.ORD_CHR_RWT] >> intLib.ARITH_TAC);

val codes_literals = prove ("codes_literals", ``
  codes «» = [] /\
  codes «duplicate_charge» =
    [100; 117; 112; 108; 105; 99; 97; 116; 101; 95; 99; 104; 97; 114; 103; 101] /\
  codes «service_not_delivered» =
    [115; 101; 114; 118; 105; 99; 101; 95; 110; 111; 116; 95; 100; 101; 108;
     105; 118; 101; 114; 101; 100] /\
  codes «returned_item» = [114; 101; 116; 117; 114; 110; 101; 100; 95; 105; 116; 101; 109]``,
  REWRITE_TAC [codes_def] >> EVAL_TAC);

(* ---- FC1 = THE THEOREM. refund_fields gives six values exactly when the
        plain contract holds on the byte codes. For ALL integers, ALL booleans
        and ALL mlstrings (every finite sequence of 8-bit values). The map to
        Dafny is byte = character code. It is NOT a UTF-8 decoding: the UTF-8
        bytes of a text are one such sequence, and the Dafny side holds them
        as a string whose characters are those bytes (RefundUnicode.Encoded). ---- *)
val refund_fields_flat_plain = prove ("refund_fields_flat_plain", ``
  forge_refundCertifiedProg$refund_fields charge request original remaining enabled
      opened candidate amount reason = (ok,a,r,c,q,n) <=>
  flat_plain (codes charge) (codes request) original remaining enabled opened
      candidate amount (codes reason) ok a (codes r) (codes c) (codes q) n``,
  simp [flat_plain_def, GSYM codes_literals, codes_11,
        forge_refundCertifiedProgTheory.refund_fields_def,
        forge_refundTheory.eligible_def, LET_THM] >>
  Cases_on `ok` >> simp [] >> metis_tac []);

(* FC2. The same statement for the eligibility guard alone (R1-R5 guard). *)
val eligible_flat_plain = prove ("eligible_flat_plain", ``
  eligible charge request original remaining enabled opened candidate amount reason <=>
  ?a r c q n.
    flat_plain (codes charge) (codes request) original remaining enabled opened
      candidate amount (codes reason) T a r c q n``,
  simp [flat_plain_def, GSYM codes_literals, codes_11,
        forge_refundTheory.eligible_def] >> metis_tac []);

(* FC3 (the exported clauses) is in forge_refundFlatExportedScript.sml. *)

(* FC4. The plain contract is a FUNCTION of the nine inputs, on all integer
   lists (not only byte codes): at most one six-tuple, and one always exists. *)
val flat_plain_functional = prove ("flat_plain_functional", ``
  flat_plain ch rq original remaining enabled opened candidate amount rs ok a r c q n /\
  flat_plain ch rq original remaining enabled opened candidate amount rs ok' a' r' c' q' n' ==>
  ok' = ok /\ a' = a /\ r' = r /\ c' = c /\ q' = q /\ n' = n``,
  simp [flat_plain_def] >> Cases_on `ok` >> Cases_on `ok'` >> simp [] >> metis_tac []);

val flat_plain_total = prove ("flat_plain_total", ``
  ?ok a r c q n.
    flat_plain ch rq original remaining enabled opened candidate amount rs ok a r c q n``,
  Cases_on `flat_plain ch rq original remaining enabled opened candidate amount rs
              T amount rs ch rq 1`
  >- metis_tac [] >>
  MAP_EVERY qexists_tac [`F`, `0`, `[]`, `[]`, `[]`, `0`] >>
  fs [flat_plain_def]);

(* FC5. The fallback: when the guard is false, the six fields are the zero
   answer, whatever the inputs are. *)
val flat_plain_fallback = prove ("flat_plain_fallback", ``
  flat_plain ch rq original remaining enabled opened candidate amount rs F a r c q n ==>
  a = 0 /\ r = [] /\ c = [] /\ q = [] /\ n = 0``,
  simp [flat_plain_def]);

(* FC6. Witnesses, on refund_fields itself (non-vacuity; order of the two
   identifiers; the MaxMoney edge on both sides). *)
val flat_plain_witnesses = prove ("flat_plain_witnesses", ``
  (* accepted; charge and request differ, so their order is visible *)
  refund_fields «ch_1» «rq_1» 100 60 T T T 40 «duplicate_charge» =
    (T, 40, «duplicate_charge», «ch_1», «rq_1», 1) /\
  flat_plain [99; 104; 95; 49] [114; 113; 95; 49] 100 60 T T T 40 (codes «duplicate_charge»)
    T 40 (codes «duplicate_charge») [99; 104; 95; 49] [114; 113; 95; 49] 1 /\
  ~flat_plain [99; 104; 95; 49] [114; 113; 95; 49] 100 60 T T T 40 (codes «duplicate_charge»)
    T 40 (codes «duplicate_charge») [114; 113; 95; 49] [99; 104; 95; 49] 1 /\
  (* amount above remaining: the zero answer *)
  refund_fields «ch_1» «rq_1» 100 60 T T T 61 «duplicate_charge» = (F, 0, «», «», «», 0) /\
  (* MaxMoney: accepted at 9223372036854775807, refused at 9223372036854775808 *)
  refund_fields «ch_1» «rq_1» 9223372036854775807 60 T T T 40 «returned_item» =
    (T, 40, «returned_item», «ch_1», «rq_1», 1) /\
  refund_fields «ch_1» «rq_1» 9223372036854775808 60 T T T 40 «returned_item» =
    (F, 0, «», «», «», 0)``,
  REWRITE_TAC [codes_def, flat_plain_def] >> EVAL_TAC);

val checked =
  [("codes_def", codes_def),
   ("flat_plain_def", flat_plain_def),
   ("code_map_11", code_map_11),
   ("codes_11", codes_11),
   ("codes_bytes", codes_bytes),
   ("codes_onto", codes_onto),
   ("codes_literals", codes_literals),
   ("refund_fields_flat_plain", refund_fields_flat_plain),
   ("eligible_flat_plain", eligible_flat_plain),
   ("flat_plain_functional", flat_plain_functional),
   ("flat_plain_total", flat_plain_total),
   ("flat_plain_fallback", flat_plain_fallback),
   ("flat_plain_witnesses", flat_plain_witnesses)];

val _ = List.app (fn (name, th) =>
  let val (ors, axs) = Tag.dest_tag (Thm.tag th) in
    if null (hyp th) andalso null axs andalso List.all (fn s => s = "DISK_THM") ors
    then ()
    else raise Fail ("Unexpected assumptions or tags: " ^ name);
    print ("FORGE_THEOREM " ^ name ^ "\n");
    print ("FORGE_ORACLES " ^ String.concatWith "," ors ^ "\n");
    print ("FORGE_AXIOMS " ^ String.concatWith "," axs ^ "\n");
    print ("FORGE_HYPOTHESES " ^ Int.toString (length (hyp th)) ^ "\n");
    print ("FORGE_STATEMENT " ^ Parse.thm_to_string th ^ "\n")
  end) checked;

(* ------------------------------------------------------------------------
   THE TRANSLATION BOUNDARY (NOT MACHINE-CHECKED).
   `dafny_of_term` prints the right-hand side of flat_plain_def as a Dafny
   expression. It accepts ONLY the term forms in the table below and fails on
   anything else. Every binary form is printed inside its own brackets, so no
   operator precedence is used.

     HOL term                          Dafny text
     variable (bool, int, int list)    its name
     a /\ b                            (a && b)
     a \/ b                            (a || b)
     a ==> b                           (a ==> b)
     ~a                                (!a)
     a = b  (a, b : bool)              (a <==> b)
     a = b  (a, b : int or int list)   (a == b)
     a <= b (int)                      (a <= b)
     integer literal n >= 0            its decimal digits
     [x1; ...; xn] (int list, n >= 0)  [x1, ..., xn]
   Types: bool -> bool, int -> int, int list -> seq<int>.
   ------------------------------------------------------------------------ *)
val int_list_ty = listSyntax.mk_list_type intSyntax.int_ty;

fun dafny_type ty =
  if ty = bool then "bool"
  else if ty = intSyntax.int_ty then "int"
  else if ty = int_list_ty then "seq<int>"
  else raise Fail "dafny_type: type outside the table";

fun dafny_of_term tm =
  if is_var tm then (dafny_type (type_of tm); #1 (dest_var tm))
  else if is_conj tm then bin "&&" (dest_conj tm)
  else if is_disj tm then bin "||" (dest_disj tm)
  else if is_imp_only tm then bin "==>" (dest_imp tm)
  else if is_neg tm then "(!" ^ dafny_of_term (dest_neg tm) ^ ")"
  else if is_eq tm then
    let val (l, r) = dest_eq tm
        val ty = type_of l
    in if ty = bool then bin "<==>" (l, r)
       else if ty = intSyntax.int_ty orelse ty = int_list_ty then bin "==" (l, r)
       else raise Fail "dafny_of_term: equality at a type outside the table"
    end
  else if intSyntax.is_leq tm then bin "<=" (intSyntax.dest_leq tm)
  else if intSyntax.is_int_literal tm then
    let val i = intSyntax.int_of_term tm
    in if Arbint.< (i, Arbint.zero)
       then raise Fail "dafny_of_term: negative literal"
       else
         let val t = Arbint.toString i
             (* Arbint.toString may add a final "i": drop it; then digits only *)
             val d = if String.isSuffix "i" t then String.substring (t, 0, size t - 1) else t
         in if d <> "" andalso List.all Char.isDigit (String.explode d) then d
            else raise Fail "dafny_of_term: literal is not all digits"
         end
    end
  else if listSyntax.is_list tm andalso type_of tm = int_list_ty then
    "[" ^ String.concatWith ", " (map dafny_of_term (#1 (listSyntax.dest_list tm))) ^ "]"
  else raise Fail ("dafny_of_term: term outside the table: " ^ term_to_string tm)
and bin opr (l, r) = "(" ^ dafny_of_term l ^ " " ^ opr ^ " " ^ dafny_of_term r ^ ")";

val (flat_lhs, flat_rhs) = dest_eq (#2 (strip_forall (concl flat_plain_def)));
val (_, flat_args) = strip_comb flat_lhs;
val _ = if length flat_args = 15 andalso List.all is_var flat_args then ()
        else raise Fail "flat_plain_def: unexpected left-hand side";
val _ = if HOLset.isSubset (FVL [flat_rhs] empty_tmset, HOLset.addList (empty_tmset, flat_args))
        then () else raise Fail "flat_plain_def: free variable outside the arguments";
val params = String.concatWith ", "
  (map (fn v => #1 (dest_var v) ^ ": " ^ dafny_type (type_of v)) flat_args);
val body = dafny_of_term flat_rhs;
val _ = if List.all (fn c => Char.isAlphaNum c orelse Char.contains " ()[],&|=<>!" c)
                    (String.explode body) andalso
           List.all (fn c => Char.isAlphaNum c orelse Char.contains " ,:<>" c)
                    (String.explode params)
        then () else raise Fail "printed body has a character outside the table";

val out = TextIO.openOut "HolFlatGenerated.dfy";
val _ = TextIO.output (out, String.concat [
  "// GENERATED FILE. Do not edit.\n",
  "// Source: HOL4 definition forge_refundFlatContract.flat_plain_def, printed by\n",
  "// dafny_of_term in forge_refundFlatContractScript.sml (APEX-2).\n",
  "// The printing step is NOT machine-checked.\n",
  "module HolFlat {\n",
  "  predicate FlatPlain(", params, ")\n",
  "  {\n",
  "    ", body, "\n",
  "  }\n",
  "}\n"]);
val _ = TextIO.closeOut out;
val _ = print ("FORGE_DAFNY_PARAMS " ^ params ^ "\n");
val _ = print ("FORGE_DAFNY_BODY " ^ body ^ "\n");

val _ = export_theory ();
val _ = print "FLAT_CONTRACT_COMPLETE\n";
