load "forge_refundWireProgTheory";
open preamble forge_refundTheory forge_refundCertifiedProgTheory;
open forge_refund_ioTheory forge_refundWireProgTheory mlstringTheory stringTheory;
val _ = OS.FileSys.chDir(valOf(OS.Process.getEnv "FORGE_SOURCE_PROOF_OUT"));
val _ = new_theory "forge_refundByteBoundary";
(* Projections between existing types, not a UTF-8 codec. *)
val byte_string_def = new_definition("byte_string_def", ``
  byte_string bytes = implode(MAP CHR bytes)``);
val byte_codes_def = new_definition("byte_codes_def", ``
  byte_codes text = MAP ORD (explode text)``);
val byte_roundtrip = store_thm("byte_roundtrip", ``
  !bytes. EVERY (\n. n < 256) bytes ==> byte_codes(byte_string bytes) = bytes``,
  Induct >> simp[byte_codes_def,byte_string_def,ORD_CHR_RWT]);
val byte_string_codes = store_thm("byte_string_codes", ``
  !s. byte_string(byte_codes s) = s``,
  simp[byte_codes_def,byte_string_def,MAP_MAP_o,o_DEF,MAP_ID]);
val byte_string_eq = store_thm("byte_string_eq", ``
  EVERY (\n. n < 256) bytes ==> (byte_string bytes = text <=> bytes = byte_codes text)``,
  metis_tac[byte_roundtrip,byte_string_codes]);
val byte_codes_empty = store_thm("byte_codes_empty", ``byte_codes «» = []``,
  EVAL_TAC);
val byte_fields_result = store_thm("byte_fields_result", ``
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
     n = (if ok then 1 else 0)``,
  strip_tac >> simp[refund_fields_def,eligible_def,LET_THM,byte_string_eq,byte_codes_empty] >>
  rpt(IF_CASES_TAC >> fs[byte_roundtrip,byte_codes_empty]));
val byte_wire_inputs = store_thm("byte_wire_inputs", ``
  EVERY (\n. n < 256) cb /\ EVERY (\n. n < 256) qb /\ EVERY (\n. n < 256) rb ==>
  ?c q r. byte_codes c = cb /\ byte_codes q = qb /\ byte_codes r = rb /\
    refund_decode_wire (mlsexp$sexp_to_string
      (refund_request c q original remaining enabled opened candidate amount r)) =
      INR(c,q,original,remaining,enabled,opened,candidate,amount,r)``,
  strip_tac >> qexists_tac `byte_string cb` >> qexists_tac `byte_string qb` >>
  qexists_tac `byte_string rb` >> simp[byte_roundtrip,refund_wire_roundtrip]);
val byte_wire_outputs = store_thm("byte_wire_outputs", ``
  EVERY (\n. n < 256) rb /\ EVERY (\n. n < 256) cb /\ EVERY (\n. n < 256) qb ==>
  ?r c q. byte_codes r = rb /\ byte_codes c = cb /\ byte_codes q = qb /\
    mlsexp$parse (explode(refund_render_fields(ok,a,r,c,q,n))) =
      INR(refund_response ok a r c q n,[]) /\
    refund_response_fields(refund_response ok a r c q n) = INR(ok,a,r,c,q,n)``,
  strip_tac >> qexists_tac `byte_string rb` >> qexists_tac `byte_string cb` >>
  qexists_tac `byte_string qb` >> simp[byte_roundtrip,refund_render_fields_roundtrip]);
val checked = [("byte_roundtrip",byte_roundtrip),("byte_string_codes",byte_string_codes),
 ("byte_string_eq",byte_string_eq),("byte_codes_empty",byte_codes_empty),
 ("byte_fields_result",byte_fields_result),("byte_wire_inputs",byte_wire_inputs),
 ("byte_wire_outputs",byte_wire_outputs)];
val _=List.app(fn(name,th)=>let val(ors,axs)=Tag.dest_tag(Thm.tag th) in
 if null(hyp th) andalso null axs andalso List.all(fn s=>s="DISK_THM") ors then ()
 else raise Fail("Unexpected assumptions: "^name);
 print("CHECKED "^name^" "^Parse.thm_to_string th^"\n") end) checked;
val _=export_theory();
val _=print "BYTE_BOUNDARY_COMPLETE\n";
val _=OS.Process.exit OS.Process.success;
