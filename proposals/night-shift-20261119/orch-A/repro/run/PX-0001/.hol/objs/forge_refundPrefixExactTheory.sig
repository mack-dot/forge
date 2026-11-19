signature forge_refundPrefixExactTheory =
sig
  type thm = Thm.thm
  
  (*  Theorems  *)
    val refund_frame_decision : thm
    val refund_frame_decision_needs_prefix : thm
    val refund_strict_parse_SOME_render : thm
    val refund_strict_parse_accepts_only_one_frame : thm
    val refund_strict_parse_exact : thm
    val refund_strict_parse_extension_needs_nonempty : thm
    val refund_strict_parse_not_reject_all : thm
    val refund_strict_parse_rejects_extension : thm
    val refund_strict_parse_witness : thm
end
