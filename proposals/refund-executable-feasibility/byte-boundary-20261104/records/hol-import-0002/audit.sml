open preamble forge_refundByteBoundaryTheory forge_refundCertifiedProgTheory forge_refund_ioTheory forge_refundWireProgTheory mlstringTheory stringTheory;
val checks = [
("byte_string_def", ``
  byte_string bytes = implode(MAP CHR bytes)``, byte_string_def),
("byte_codes_def", ``
  byte_codes text = MAP ORD (explode text)``, byte_codes_def),
("byte_roundtrip", ``
  !bytes. EVERY (\n. n < 256) bytes ==> byte_codes(byte_string bytes) = bytes``, byte_roundtrip),
("byte_string_codes", ``
  !s. byte_string(byte_codes s) = s``, byte_string_codes),
("byte_string_eq", ``
  EVERY (\n. n < 256) bytes ==> (byte_string bytes = text <=> bytes = byte_codes text)``, byte_string_eq),
("byte_codes_empty", ``byte_codes «» = []``, byte_codes_empty),
("byte_fields_result", ``
  EVERY (\n. n < 256) cb /\ EVERY (\n. n < 256) qb /\ EVERY (\n. n < 256) rb ==>
  let (ok,a,r,c,q,n) = refund_fields (byte_string cb) (byte_string qb)
      original remaining enabled opened candidate amount (byte_string rb)
  in (ok <=> cb <> [] /\ qb <> [] /\ enabled /\ opened /\
        0 <= original /\ original <= 9223372036854775807 /\
        0 <= remaining /\ remaining <= original /\ candidate /\
        0 <= amount /\ amount <= remaining /\
        (rb = byte_codes «duplicate_charge» \/ rb = byte_codes «service_not_delivered» \/
         rb = byte_codes «returned_item»)) /\
     a = (if ok then amount else 0) /\ byte_codes r = (if ok then rb else []) /\
     byte_codes c = (if ok then cb else []) /\ byte_codes q = (if ok then qb else []) /\
     n = (if ok then 1 else 0)``, byte_fields_result),
("byte_wire_inputs", ``
  EVERY (\n. n < 256) cb /\ EVERY (\n. n < 256) qb /\ EVERY (\n. n < 256) rb ==>
  ?c q r. byte_codes c = cb /\ byte_codes q = qb /\ byte_codes r = rb /\
    refund_decode_wire (mlsexp$sexp_to_string
      (refund_request c q original remaining enabled opened candidate amount r)) =
      INR(c,q,original,remaining,enabled,opened,candidate,amount,r)``, byte_wire_inputs),
("byte_wire_outputs", ``
  EVERY (\n. n < 256) rb /\ EVERY (\n. n < 256) cb /\ EVERY (\n. n < 256) qb ==>
  ?r c q. byte_codes r = rb /\ byte_codes c = cb /\ byte_codes q = qb /\
    mlsexp$parse (explode(refund_render_fields(ok,a,r,c,q,n))) =
      INR(refund_response ok a r c q n,[]) /\
    refund_response_fields(refund_response ok a r c q n) = INR(ok,a,r,c,q,n)``, byte_wire_outputs)];
val _=List.app(fn(name,expected,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if aconv (snd(strip_forall expected)) (concl(SPEC_ALL th)) then () else raise Fail("Exact statement mismatch: "^name);
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("IMPORTED "^name^" EXACT true HYPOTHESES 0 TAGGED_AXIOMS 0\n") end) checks;
val _=if length(DB.theorems "forge_refundByteBoundary")=7 then () else raise Fail "Unexpected theorem count";
val closure="forge_refundByteBoundary"::Theory.ancestry "forge_refundByteBoundary";
val _=List.app(fn n=>print("CLOSURE_NODE "^n^":"^String.concatWith ","(Theory.parents n)^"\n")) closure;
val _=List.app(fn n=>List.app(fn(a,_)=>print("CLOSURE_AXIOM "^n^"."^a^"\n"))(DB.axioms n)) closure;
val _=print "SOURCE_IMPORT_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;
