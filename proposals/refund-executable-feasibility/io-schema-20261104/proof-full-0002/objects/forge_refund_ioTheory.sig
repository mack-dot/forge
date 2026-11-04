signature forge_refund_ioTheory =
sig
  type thm = Thm.thm
  
  (*  Definitions  *)
    val refund_decode_def : thm
    val refund_decode_wire_def : thm
    val refund_request_def : thm
    val refund_response_def : thm
    val refund_response_fields_def : thm
    val refund_wire_model_def : thm
  
  (*  Theorems  *)
    val refund_appended_request_rejected : thm
    val refund_bad_integer_rejected : thm
    val refund_missing_field_rejected : thm
    val refund_parser_failure_rejected : thm
    val refund_response_parse : thm
    val refund_response_roundtrip : thm
    val refund_schema_roundtrip : thm
    val refund_stream_parse : thm
    val refund_trailing_input_rejected : thm
    val refund_wire_model_result : thm
    val refund_wire_roundtrip : thm
    val refund_wrong_type_rejected : thm
end
